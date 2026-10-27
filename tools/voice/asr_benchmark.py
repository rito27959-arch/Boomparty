"""Banc d'essai ASR français pour BOOM PARTY (sherpa-onnx, hors ligne).

Jeu de test : réponses courtes de jeu synthétisées avec 4 voix françaises Piper
(2 vitesses), en version propre puis mélangées à un bruit de soirée (brouhaha de
conversations synthétiques + musique) à 10 dB et 5 dB de RSB.

Limite assumée : des voix synthétiques ne remplacent pas de vraies voix
(accents, enfants, prononciation spontanée). Un test terrain est prévu.

Mesures par modèle : justesse « concept » (la transcription normalisée contient
le mot attendu ou un de ses synonymes), CER, facteur temps réel (RTF) sur ce
processeur x86, taille sur disque, mémoire résidente.

    python asr_benchmark.py <models_dir> <out_dir>
"""
import json
import math
import os
import random
import resource
import sys
import time
from pathlib import Path

import numpy as np
import sherpa_onnx

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'kb'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from normalize import fold, normalize, singular  # noqa: E402
from game_matcher import Matcher  # noqa: E402

SR = 16000

# (texte prononcé, formes acceptées)
ITEMS = [
    ('Un réfrigérateur.', ['refrigerateur', 'frigo']), ('Le frigo.', ['frigo', 'refrigerateur']),
    ('Une télé.', ['tele', 'television']), ('Des casseroles.', ['casserole']), ('Le Cameroun.', ['cameroun']),
    ('Une voiture.', ['voiture']), ('Un ordinateur portable.', ['ordinateur portable', 'ordinateur']),
    ('Une table à manger.', ['table a manger', 'table']), ('Casserole !', ['casserole']), ('Fourchette !', ['fourchette']),
    ('Éléphant !', ['elephant']), ('Une girafe.', ['girafe']), ('Le Sénégal.', ['senegal']),
    ("La Côte d'Ivoire.", ["cote d' ivoire", 'cote d ivoire', 'cote divoire']), ('Pompier !', ['pompier']),
    ('Boulanger.', ['boulanger']), ('Une trompette.', ['trompette']), ('Le djembé.', ['djembe']),
    ('Une mangue.', ['mangue']), ('Ananas !', ['ananas']), ('Le basket.', ['basket']), ('Le ping-pong.', ['ping pong']),
    ('Une pirogue.', ['pirogue']), ('Un hélicoptère.', ['helicoptere']), ('Le bissap.', ['bissap']),
    ('Le makossa.', ['makossa']), ('Une chaussette.', ['chaussette']), ('Une écharpe.', ['echarpe']),
    ('Violet !', ['violet']), ('Le genou.', ['genou']), ('Le coude.', ['coude']), ('Yaoundé !', ['yaounde']),
    ('Marseille.', ['marseille']), ("L'oxygène.", ['oxygene']), ('Une comédie.', ['comedie']),
    ('Le western.', ['western']), ('Un zèbre.', ['zebre']), ('Un hippopotame.', ['hippopotame']),
    ('Un kangourou.', ['kangourou']), ('Une poêle.', ['poele', 'poil', 'poile']), ('Le Mali.', ['mali']),
    ('Une banane.', ['banane']), ('Un tracteur.', ['tracteur']), ('Infirmière !', ['infirmiere']),
    ('Le saxophone.', ['saxophone', 'saxo']), ('Une pastèque.', ['pasteque']), ('Le tennis.', ['tennis']),
    ('Un chameau.', ['chameau']),
]
BABBLE_TEXT = [
    "Tu as vu le match hier soir, c'était incroyable.", "Passe-moi les chips s'il te plaît.",
    "Je crois qu'on devrait commander une autre pizza.", "Attends, c'est à qui le tour maintenant ?",
    "Mets la musique un peu plus fort !", "Non mais sérieusement, ce jeu est trop drôle.",
]
VOICES = ['vits-piper-fr_FR-siwis-medium', 'vits-piper-fr_FR-upmc-medium', 'vits-piper-fr_FR-tom-medium',
          'vits-piper-fr_FR-gilles-low']


def tts_engine(models, name):
    d = Path(models) / name
    onnx = next(d.glob('*.onnx'))
    cfg = sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(
        vits=sherpa_onnx.OfflineTtsVitsModelConfig(model=str(onnx), tokens=str(d / 'tokens.txt'), data_dir=str(d / 'espeak-ng-data')),
        num_threads=2))
    return sherpa_onnx.OfflineTts(cfg)


def resample(x, sr):
    if sr == SR:
        return x.astype(np.float32)
    n = int(len(x) * SR / sr)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def synth(tts, text, sid=0, speed=1.0):
    a = tts.generate(text, sid=sid, speed=speed)
    return resample(np.array(a.samples, dtype=np.float32), a.sample_rate)


def party_noise(n, babble, rng):
    out = np.zeros(n, np.float32)
    for k in range(4):                       # 4 conversations superposées
        b = babble[rng.randrange(len(babble))]
        off = rng.randrange(0, max(1, len(b) - 1))
        seg = np.resize(np.roll(b, -off), n)
        out += seg * rng.uniform(0.4, 1.0)
    t = np.arange(n) / SR                     # musique : accords + grosse caisse
    for f in (110, 138.6, 164.8, 220):
        out += 0.08 * np.sin(2 * np.pi * f * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 2 * t))
    beat = (np.sin(2 * np.pi * 2.0 * t) > 0.95).astype(np.float32) * np.sin(2 * np.pi * 60 * t) * 0.5
    return out + beat


def mix(speech, noise, snr_db):
    ps = np.mean(speech ** 2) + 1e-9
    pn = np.mean(noise ** 2) + 1e-9
    k = math.sqrt(ps / (pn * 10 ** (snr_db / 10)))
    y = speech + k * noise
    return (y / max(1.0, np.abs(y).max())).astype(np.float32)


def build_testset(models, out):
    rng = random.Random(3)
    cache = Path(out) / 'testset.npz'
    if cache.exists():
        z = np.load(cache, allow_pickle=True)
        return list(z['items'])
    engines = {v: tts_engine(models, v) for v in VOICES}
    babble = [synth(engines[VOICES[i % 4]], s) for i, s in enumerate(BABBLE_TEXT)]
    items = []
    for i, (text, ok) in enumerate(ITEMS):
        v = VOICES[i % len(VOICES)]
        speed = 0.85 if i % 2 else 1.15
        clean = synth(engines[v], text, speed=speed)
        pad = np.zeros(int(0.3 * SR), np.float32)
        clean = np.concatenate([pad, clean, pad])
        noise = party_noise(len(clean), babble, rng)
        for cond, audio in (('propre', clean), ('bruit_10dB', mix(clean, noise, 10)), ('bruit_5dB', mix(clean, noise, 5))):
            items.append({'text': text, 'ok': ok, 'voice': v, 'cond': cond, 'audio': audio})
    np.savez_compressed(cache, items=np.array(items, dtype=object))
    return items


def du(path):
    return sum(f.stat().st_size for f in Path(path).rglob('*') if f.is_file())


def recognizers(models):
    m = Path(models)
    out = {}
    for size in ('tiny', 'base'):
        d = m / f'sherpa-onnx-whisper-{size}'
        if d.exists():
            out[f'whisper-{size}-int8'] = (lambda d=d, size=size: sherpa_onnx.OfflineRecognizer.from_whisper(
                encoder=str(d / f'{size}-encoder.int8.onnx'), decoder=str(d / f'{size}-decoder.int8.onnx'),
                tokens=str(d / f'{size}-tokens.txt'), language='fr', task='transcribe', num_threads=2),
                [d / f'{size}-encoder.int8.onnx', d / f'{size}-decoder.int8.onnx'])
    d = m / 'sherpa-onnx-nemo-canary-180m-flash-en-es-de-fr-int8'
    if d.exists():
        out['canary-180m-flash-int8'] = (lambda d=d: sherpa_onnx.OfflineRecognizer.from_nemo_canary(
            encoder=str(next(d.glob('encoder*.onnx'))), decoder=str(next(d.glob('decoder*.onnx'))),
            tokens=str(d / 'tokens.txt'), src_lang='fr', tgt_lang='fr', num_threads=2), [d])
    d = m / 'sherpa-onnx-streaming-zipformer-fr-2023-04-14'
    if d.exists():
        def zf(d=d):
            enc = next(d.glob('encoder*.int8.onnx'), None) or next(d.glob('encoder*.onnx'))
            dec = next(d.glob('decoder*.onnx'))
            joi = next(d.glob('joiner*.int8.onnx'), None) or next(d.glob('joiner*.onnx'))
            return sherpa_onnx.OnlineRecognizer.from_transducer(tokens=str(d / 'tokens.txt'), encoder=str(enc), decoder=str(dec),
                                                                joiner=str(joi), num_threads=2, sample_rate=SR, feature_dim=80)
        files = [next(d.glob('encoder*.int8.onnx'), None), next(d.glob('decoder*.onnx'), None), next(d.glob('joiner*.int8.onnx'), None)]
        out['zipformer-fr-streaming-int8'] = (zf, [f for f in files if f])

        def zf_hot(d=d):
            enc = next(d.glob('encoder*.int8.onnx'))
            dec = next(d.glob('decoder*.onnx'))
            joi = next(d.glob('joiner*.int8.onnx'))
            r = sherpa_onnx.OnlineRecognizer.from_transducer(tokens=str(d / 'tokens.txt'), encoder=str(enc), decoder=str(dec),
                                                             joiner=str(joi), num_threads=2, sample_rate=SR, feature_dim=80,
                                                             decoding_method='modified_beam_search', max_active_paths=4,
                                                             hotwords_score=2.5)
            r._boom_vocab = load_tokens(d / 'tokens.txt')
            return r
        out['zipformer-fr-int8 + vocabulaire catégorie'] = (zf_hot, [f for f in files if f])
    return out


def load_tokens(path):
    return [l.split(' ')[0] for l in Path(path).read_text().splitlines() if l and not l.startswith('<')]


def tokenize(word, vocab):
    """Découpage glouton (plus long morceau) d'un mot en pièces BPE majuscules."""
    w = '▁' + fold(word).upper().replace(' ', '▁').replace("'", "'")
    w = w.replace('E', 'E')
    out, i = [], 0
    vs = sorted(set(vocab), key=len, reverse=True)
    while i < len(w):
        for v in vs:
            if w.startswith(v, i):
                out.append(v)
                i += len(v)
                break
        else:
            i += 1
    return ' '.join(out)


def transcribe(rec, audio, hot=None):
    if isinstance(rec, sherpa_onnx.OnlineRecognizer):
        s = rec.create_stream(hot) if hot else rec.create_stream()
        s.accept_waveform(SR, audio)
        s.accept_waveform(SR, np.zeros(int(0.6 * SR), np.float32))
        s.input_finished()
        while rec.is_ready(s):
            rec.decode_stream(s)
        return rec.get_result(s)
    s = rec.create_stream()
    s.accept_waveform(SR, audio)
    rec.decode_stream(s)
    return s.result.text


def cer(ref, hyp):
    a, b = fold(ref), fold(hyp)
    d = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(b) + 1):
            cur = d[j]
            d[j] = min(d[j] + 1, d[j - 1] + 1, prev + (a[i - 1] != b[j - 1]))
            prev = cur
    return d[len(b)] / max(1, len(a))


def hit(hyp, ok):
    h = ' ' + normalize(hyp) + ' '
    hs = ' ' + singular(normalize(hyp)) + ' '
    return any((' ' + o + ' ') in h or (' ' + o + ' ') in hs for o in ok)


def main():
    models, out = sys.argv[1], Path(sys.argv[2])
    kb = Matcher(sys.argv[3]) if len(sys.argv) > 3 else None
    out.mkdir(parents=True, exist_ok=True)
    items = build_testset(models, out)
    print('jeu de test :', len(items), 'extraits', flush=True)
    results = {}
    for name, (factory, files) in recognizers(models).items():
        t0 = time.time()
        rec = factory()
        load = time.time() - t0
        rows = []
        audio_s = proc_s = 0.0
        for it in items:
            t = time.time()
            hot = None
            if hasattr(rec, '_boom_vocab') and kb:
                cats, _ = kb.categories_of(it['ok'][0])
                words = sorted({a for c in cats for (a, _, _) in kb.cat_alias.get(c, [])})[:800]
                hot = '/'.join(tokenize(w, rec._boom_vocab) for w in words)
            hyp = transcribe(rec, it['audio'], hot)
            proc_s += time.time() - t
            audio_s += len(it['audio']) / SR
            row = {'cond': it['cond'], 'voice': it['voice'].split('-')[3] if it['voice'].count('-') >= 3 else it['voice'], 'ref': it['text'], 'hyp': hyp, 'hit': hit(hyp, it['ok']), 'cer': cer(it['text'], hyp)}
            if kb:
                cats, target = kb.categories_of(it['ok'][0])
                row['game'] = any(kb.resolve(hyp, c) in target for c in cats) if cats else row['hit']
            rows.append(row)
        by = {}
        for c in ('propre', 'bruit_10dB', 'bruit_5dB'):
            rs = [r for r in rows if r['cond'] == c]
            by[c] = {'justesse': round(sum(r['hit'] for r in rs) / len(rs), 3), 'cer': round(float(np.mean([r['cer'] for r in rs])), 3),
                     'justesse_jeu': round(sum(r.get('game', r['hit']) for r in rs) / len(rs), 3)}
        by_voice = {}
        for r in rows:
            by_voice.setdefault(r['voice'], []).append(r.get('game', r['hit']))
        by_voice = {v: round(sum(x) / len(x), 3) for v, x in by_voice.items()}
        size = sum(du(f) if Path(f).is_dir() else Path(f).stat().st_size for f in files)
        results[name] = {'par_condition': by, 'par_voix_jeu': by_voice, 'rtf': round(proc_s / audio_s, 3), 'chargement_s': round(load, 2),
                         'taille_mo': round(size / 1e6, 1), 'erreurs': [r for r in rows if not r['hit']][:25]}
        print(name, json.dumps({k: v for k, v in results[name].items() if k != 'erreurs'}, ensure_ascii=False), flush=True)
        del rec
    results['_memoire_max_mo'] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1)
    (out / 'asr_benchmark.json').write_text(json.dumps(results, ensure_ascii=False, indent=1))
    md = ['# Banc d\'essai ASR (français, réponses courtes)', '',
          '| modèle | brut propre | brut 10 dB | brut 5 dB | **en jeu** propre | **en jeu** 10 dB | **en jeu** 5 dB | CER propre | RTF (x86, 2 cœurs) | taille |',
          '|---|---|---|---|---|---|---|---|---|---|']
    for k, r in results.items():
        if k.startswith('_'):
            continue
        p = r['par_condition']
        md.append(f"| {k} | {p['propre']['justesse']:.0%} | {p['bruit_10dB']['justesse']:.0%} | {p['bruit_5dB']['justesse']:.0%} | "
                  f"**{p['propre']['justesse_jeu']:.0%}** | **{p['bruit_10dB']['justesse_jeu']:.0%}** | **{p['bruit_5dB']['justesse_jeu']:.0%}** | "
                  f"{p['propre']['cer']:.2f} | {r['rtf']} | {r['taille_mo']} Mo |")
    voices = sorted({v for k, r in results.items() if not k.startswith('_') for v in r['par_voix_jeu']})
    md += ['', '## Justesse en jeu par voix de synthèse (toutes conditions)', '',
           '| modèle | ' + ' | '.join(voices) + ' |', '|---|' + '---|' * len(voices)]
    for k, r in results.items():
        if not k.startswith('_'):
            md.append(f'| {k} | ' + ' | '.join(f"{r['par_voix_jeu'].get(v, 0):.0%}" for v in voices) + ' |')
    md += ['', '> Voix de test synthétiques (Piper). Une voix de mauvaise qualité fait échouer tous les modèles :',
           '> ces chiffres sont un classement relatif, pas une mesure de la justesse sur de vraies voix.']
    (out / 'asr_benchmark.md').write_text('\n'.join(md) + '\n')
    print('\n'.join(md))


if __name__ == '__main__':
    main()
