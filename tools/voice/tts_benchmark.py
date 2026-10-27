"""Banc d'essai TTS hors ligne (sherpa-onnx) pour la voix de la bombe.

Pour chaque voix : temps de chargement, RTF (temps de calcul / durée audio),
intelligibilité mesurée en re-transcrivant l'audio avec un ASR indépendant
(canary-180m) et en comparant au texte (taux d'erreur caractères), échantillons WAV.

Usage : python3 tts_benchmark.py <dossier_modèles> <dossier_sortie>
"""
import json
import sys
import time
import wave
from pathlib import Path

import numpy as np
import sherpa_onnx

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'kb'))
from normalize import fold  # noqa: E402

LINES = [
    "Bon, mes petits génies ! Catégorie : les animaux ! Emma, commence !",
    "AHAHA ! Tu pensais vraiment m'avoir ? Frigo, réfrigérateur, c'est exactement la même chose !",
    "Casserole ? Validé ! Au suivant !",
    "Je n'ai pas bien compris… Tu peux répéter ?",
    "Trop lent… ça va exploser !",
    "BOOOOM ! Désolé Léo, c'était inévitable.",
]

# (nom, licence, fabrique)
def voices(m: Path):
    out = []
    for name, lic in (('siwis-medium', 'CC BY 4.0 (corpus SIWIS)'), ('upmc-medium', 'CC BY-SA 4.0'),
                      ('gilles-low', 'CC0'), ('tom-medium', 'AGPL-3.0 — incompatible avec une app fermée')):
        d = m / f'vits-piper-fr_FR-{name}'
        if d.exists():
            def f(d=d, name=name):
                return sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(
                    vits=sherpa_onnx.OfflineTtsVitsModelConfig(model=str(d / f'fr_FR-{name}.onnx'), tokens=str(d / 'tokens.txt'),
                                                               data_dir=str(d / 'espeak-ng-data')), num_threads=2)))
            files = [d / f'fr_FR-{name}.onnx']
            sids = [0, 1] if name == 'upmc-medium' else [0]
            for sid in sids:
                out.append((f'piper {name}' + (f' #{sid}' if len(sids) > 1 else ''), lic, f, sid, files))
    d = m / 'kokoro-int8-multi-lang-v1_0'
    if d.exists():
        def k(d=d):
            return sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(
                kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(model=str(d / 'model.int8.onnx'), voices=str(d / 'voices.bin'),
                                                               tokens=str(d / 'tokens.txt'), data_dir=str(d / 'espeak-ng-data'),
                                                               dict_dir=str(d / 'dict'),
                                                               lexicon=f"{d / 'lexicon-us-en.txt'},{d / 'lexicon-zh.txt'}",
                                                               lang='fr'), num_threads=2)))
        out.append(('kokoro v1.0 ff_siwis (int8)', 'Apache-2.0 (modèle) ; voix entraînée sur SIWIS (CC BY 4.0)', k, 30,
                    [d / 'model.int8.onnx', d / 'voices.bin']))
    return out


def save(path, x, sr):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())


def resample16(x, sr):
    if sr == 16000:
        return x
    n = int(len(x) * 16000 / sr)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def cer(a, b):
    a, b = fold(a), fold(b)
    a = ''.join(c for c in a if c.isalnum())
    b = ''.join(c for c in b if c.isalnum())
    d = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(b) + 1):
            cur = d[j]
            d[j] = min(d[j] + 1, d[j - 1] + 1, prev + (a[i - 1] != b[j - 1]))
            prev = cur
    return d[len(b)] / max(1, len(a))


def main():
    m, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    c = m / 'sherpa-onnx-nemo-canary-180m-flash-en-es-de-fr-int8'
    asr = sherpa_onnx.OfflineRecognizer.from_nemo_canary(encoder=str(next(c.glob('encoder*.onnx'))), decoder=str(next(c.glob('decoder*.onnx'))),
                                                         tokens=str(c / 'tokens.txt'), src_lang='fr', tgt_lang='fr', num_threads=2)
    res = {}
    for name, lic, factory, sid, files in voices(m):
        t0 = time.time()
        tts = factory()
        load = time.time() - t0
        gen = dur = 0.0
        cers, hyps = [], []
        slug = ''.join(ch if ch.isalnum() else '_' for ch in name)
        for i, text in enumerate(LINES):
            t = time.time()
            a = tts.generate(text, sid=sid, speed=1.0)
            gen += time.time() - t
            x = np.array(a.samples, dtype=np.float32)
            dur += len(x) / a.sample_rate
            save(out / f'{slug}_{i + 1}.wav', x, a.sample_rate)
            s = asr.create_stream()
            s.accept_waveform(16000, resample16(x, a.sample_rate))
            asr.decode_stream(s)
            hyps.append(s.result.text.strip())
            cers.append(cer(text, s.result.text))
        size = sum(Path(f).stat().st_size for f in files)
        res[name] = {'licence': lic, 'chargement_s': round(load, 2), 'rtf': round(gen / dur, 3), 'cer_reecoute': round(float(np.mean(cers)), 3),
                     'taille_mo': round(size / 1e6, 1), 'transcriptions': hyps, 'sample_rate': a.sample_rate}
        print(name, json.dumps({k: v for k, v in res[name].items() if k != 'transcriptions'}, ensure_ascii=False), flush=True)
        del tts
    (out / 'tts_benchmark.json').write_text(json.dumps(res, ensure_ascii=False, indent=1))
    md = ['# Banc d\'essai TTS (voix française de la bombe)', '',
          '| voix | licence | RTF (x86, 2 cœurs) | erreurs à la réécoute (CER) | taille |', '|---|---|---|---|---|']
    for k, r in res.items():
        md.append(f"| {k} | {r['licence']} | {r['rtf']} | {r['cer_reecoute']:.0%} | {r['taille_mo']} Mo |")
    md += ['', 'CER à la réécoute : l\'audio généré est retranscrit par canary-180m ; plus c\'est bas, plus la voix est intelligible.']
    (out / 'tts_benchmark.md').write_text('\n'.join(md) + '\n')
    print('\n'.join(md))


if __name__ == '__main__':
    main()
