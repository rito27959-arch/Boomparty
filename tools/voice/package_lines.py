"""Transforme les répliques enregistrées/générées (un WAV par réplique, voix
naturelle) en ressources du jeu pour les quatre voix de la bombe :

  assets/voice/<voix>/<profil>/<id>.ogg  (Vorbis mono 22 kHz)
  assets/voice/<voix>/<profil>/<id>.vis.json  (synchro labiale, 40 ms)

- classique : voix naturelle
- drole     : +3 demi-tons (formants préservés, durée inchangée)
- serieuse  : −2 demi-tons
- robot     : modulation en anneau (voice_fx.robotize)

Usage : python3 package_lines.py <dossier_wav> <racine_projet>
"""
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from pregen_lines import PROFILES  # noqa: E402
from voice_fx import FRAME_MS, robotize, visemes  # noqa: E402

FILTERS = {
    'classique': '',
    'drole': 'rubberband=pitch=1.189:formant=preserved,',
    'serieuse': 'rubberband=pitch=0.891:formant=preserved,',
    'robot': '',
}
# nettoyage commun : silences de début/fin retirés, volume homogène
CLEAN = ('silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,'
         'silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse,'
         'highpass=f=60,loudnorm=I=-16:TP=-1.5:LRA=9')


def read_wav(p):
    with wave.open(str(p)) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').astype(np.float32) / 32768
    return x, sr


def write_wav(p, x, sr):
    with wave.open(str(p), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())


def main():
    src, root = Path(sys.argv[1]), Path(sys.argv[2])
    report = json.loads((src / 'report.json').read_text())
    out_root = root / 'assets/voice'
    n = 0
    for lid, info in sorted(report.items()):
        wav = src / f'{lid}.wav'
        if not wav.exists():
            continue
        profile = PROFILES[lid.split('_')[0]]
        for voice, filt in FILTERS.items():
            with tempfile.TemporaryDirectory() as td:
                tmp = Path(td) / 'v.wav'
                subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(wav), '-ac', '1',
                                '-af', filt + CLEAN, '-ar', '22050', str(tmp)], check=True)
                x, sr = read_wav(tmp)
                if voice == 'robot':
                    x = robotize(x, sr)
                    write_wav(tmp, x, sr)
                d = out_root / voice / profile
                d.mkdir(parents=True, exist_ok=True)
                subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(tmp), '-c:a', 'libvorbis', '-q:a', '3',
                                str(d / f'{lid}.ogg')], check=True)
                (d / f'{lid}.vis.json').write_text(json.dumps({'frameMs': FRAME_MS, 'v': visemes(x, sr), 'text': info['text']},
                                                              ensure_ascii=False))
        n += 1
    (out_root / 'CREDITS.txt').write_text(
        'Voix de la bombe : voix du concepteur de BOOM PARTY, utilisée avec son accord,\n'
        'mise en scène par le modèle de synthèse Chatterbox Multilingual (Resemble AI, licence MIT).\n'
        'Chaque fichier porte le filigrane audio inaudible Perth de Resemble AI.\n'
        'Voix de secours (répliques dynamiques) : Piper fr_FR siwis, corpus SIWIS, CC BY 4.0.\n', encoding='utf-8')
    print(n, 'répliques ×', len(FILTERS), 'voix')


if __name__ == '__main__':
    main()
