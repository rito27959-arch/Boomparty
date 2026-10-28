"""Laboratoire de voix expressives : Chatterbox Multilingual (MIT) en français,
timbres de référence sous licence libre (dépôt kyutai/tts-voices : CC0 / CC BY 4.0).

Usage : python voice_lab.py <sortie>
"""
import json
import sys
import time
from pathlib import Path

import torchaudio as ta
from huggingface_hub import hf_hub_download, list_repo_files

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

LINES = {
    'classic': (0.6, 0.45, [
        'Ah non ! Pas encore ce mot !',
        'Excellent ! C\'est validé !',
        'Trop lent… ça va exploser !',
    ]),
    'crazy': (0.95, 0.3, [
        'NON NON NON ! DÉJÀ DIT !',
        'BOUM ! Euh non… VALIDÉ !',
        'ÇA VA PÉTER ! ÇA VA PÉTER !',
    ]),
    'drama': (0.8, 0.35, [
        'Hélas… ce mot a déjà été prononcé. Quelle tragédie !',
        'Le public est en larmes. Validé !',
        'Le temps s\'écoule… inexorablement…',
    ]),
}

files = list_repo_files('kyutai/tts-voices')
fr = sorted(f for f in files if f.startswith('cml-tts/fr/') and f.endswith('_enhanced.wav'))
donations = sorted(f for f in files if f.startswith('voice-donations/') and f.endswith('.wav'))
print('voix FR disponibles :', len(fr), '— dons :', len(donations), flush=True)
refs = fr[:6]
(OUT / 'refs.json').write_text(json.dumps({'fr': fr, 'donations': donations[:50], 'used': refs}, indent=1))

from chatterbox.mtl_tts import ChatterboxMultilingualTTS  # noqa: E402

t0 = time.time()
model = ChatterboxMultilingualTTS.from_pretrained(device='cpu')
print('modèle chargé en', round(time.time() - t0), 's', flush=True)

report = []
for vi, ref in enumerate(refs):
    path = hf_hub_download('kyutai/tts-voices', ref)
    for profile, (exa, cfg, lines) in LINES.items():
        for li, text in enumerate(lines):
            t = time.time()
            try:
                wav = model.generate(text, language_id='fr', audio_prompt_path=path, exaggeration=exa, cfg_weight=cfg)
                name = f'v{vi + 1}_{profile}_{li + 1}.wav'
                ta.save(str(OUT / name), wav, model.sr)
                dur = wav.shape[-1] / model.sr
                report.append({'file': name, 'ref': ref, 'profile': profile, 'text': text, 'seconds': round(time.time() - t, 1), 'audio_s': round(dur, 2)})
                print(name, report[-1]['seconds'], 's', flush=True)
            except Exception as e:  # noqa: BLE001
                print('ERREUR', ref, profile, li, e, flush=True)
    (OUT / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=1))
