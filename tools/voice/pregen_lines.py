"""Prégénère les répliques fixes de la bombe (sans variable) pour chaque voix.

Sortie : assets/voice/<voix>/<profil>/<id>.ogg (Vorbis mono 22 kHz) + <id>.vis.json
(piste de visèmes, 40 ms par pas). Voix de base : Piper fr_FR siwis medium (CC BY 4.0).

Usage : python3 pregen_lines.py <dossier_piper_siwis> <racine_du_projet>
"""
import json
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
import sherpa_onnx

from voice_fx import FRAME_MS, VOICES, process, visemes

PROFILES = {'c': 'classic', 'z': 'crazy', 'd': 'drama'}


def static_lines(dart: Path):
    src = dart.read_text(encoding='utf-8')
    for m in re.finditer(r"Line\('([a-z]+)_([a-z0-9_]+)',\s*'((?:[^'\\]|\\.)*)'", src):
        text = m.group(3).replace("\\'", "'")
        if '{' in text:
            continue
        yield PROFILES[m.group(1)], f'{m.group(1)}_{m.group(2)}', text


def main():
    piper, root = Path(sys.argv[1]), Path(sys.argv[2])
    tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(
        vits=sherpa_onnx.OfflineTtsVitsModelConfig(model=str(next(piper.glob('*.onnx'))), tokens=str(piper / 'tokens.txt'),
                                                   data_dir=str(piper / 'espeak-ng-data')), num_threads=4)))
    lines = list(static_lines(root / 'lib/personality/personality_engine.dart'))
    out_root = root / 'assets/voice'
    n = 0
    for voice, (speed, _, _) in VOICES.items():
        for profile, lid, text in lines:
            a = tts.generate(text, sid=0, speed=speed)
            x = process(np.array(a.samples, dtype=np.float32), a.sample_rate, voice)
            peak = float(np.abs(x).max()) or 1.0
            x = x / peak * 0.89
            d = out_root / voice / profile
            d.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
                with wave.open(tmp.name, 'wb') as w:
                    w.setnchannels(1)
                    w.setsampwidth(2)
                    w.setframerate(a.sample_rate)
                    w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())
                subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', tmp.name, '-ac', '1', '-ar', '22050',
                                '-c:a', 'libvorbis', '-q:a', '2', str(d / f'{lid}.ogg')], check=True)
            (d / f'{lid}.vis.json').write_text(json.dumps({'frameMs': FRAME_MS, 'v': visemes(x, a.sample_rate), 'text': text},
                                                          ensure_ascii=False))
            n += 1
    (out_root / 'CREDITS.txt').write_text(
        'Voix de la bombe : synthèse Piper (modèle fr_FR-siwis-medium), corpus SIWIS\n'
        '(https://datashare.is.ed.ac.uk/handle/10283/2353), licence CC BY 4.0.\n'
        'Synthèse : sherpa-onnx (Apache-2.0). Traitements (hauteur, robot) : BOOM PARTY.\n', encoding='utf-8')
    print(n, 'répliques générées pour', len(VOICES), 'voix')


if __name__ == '__main__':
    main()
