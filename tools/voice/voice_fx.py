"""Traitements de voix de la bombe — identiques à SpeechEngine (lib/speech/speech_engine.dart)
et à la piste de visèmes de lib/speech/lip_sync.dart. Toute modification doit être
reportée des deux côtés (les tests comparent les deux implémentations)."""
import math

import numpy as np

# BombVoice → (vitesse de synthèse, facteur de hauteur, robot)
VOICES = {
    'classique': (1.0, 1.0, False),
    'drole': (1.12, 1.18, False),
    'serieuse': (0.9, 0.88, False),
    'robot': (1.0, 1.0, True),
}
FRAME_MS = 40


def robotize(x, sr):
    i = np.arange(len(x))
    m = 0.5 + 0.5 * np.sin(2 * math.pi * 55 * i / sr)
    return (x * (0.35 + 0.65 * m)).astype(np.float32)


def pitch_shift(x, factor):
    n = int(math.floor(len(x) / factor))
    p = np.arange(n) * factor
    j = np.floor(p).astype(int)
    f = p - j
    a = x[np.clip(j, 0, len(x) - 1)]
    b = x[np.clip(j + 1, 0, len(x) - 1)]
    return (a + (b - a) * f).astype(np.float32)


def process(x, sr, voice):
    _, pitch, robot = VOICES[voice]
    if robot:
        x = robotize(x, sr)
    if pitch != 1.0:
        x = pitch_shift(x, pitch)
    return x


def visemes(x, sr):
    """Même algorithme que VisemeTrack.fromSamples : 0=repos 1=é 2=a 3=o 4=m."""
    hop = round(sr * FRAME_MS / 1000)
    n = len(x) // hop
    rms, zcr = [], []
    for f in range(n):
        s = x[f * hop:(f + 1) * hop].astype(np.float64)
        rms.append(math.sqrt(float(np.sum(s * s)) / hop))
        sign = s >= 0
        zcr.append(int(np.count_nonzero(sign[1:] != sign[:-1])) / hop)
    peak = max(rms) if rms else 1.0
    out = []
    for f in range(n):
        level = rms[f] / peak if peak > 0 else 0.0
        prev = rms[f - 1] / peak if f > 0 and peak > 0 else 0.0
        if level < 0.08:
            v = 0
        elif prev < 0.08 and level > 0.25:
            v = 4
        elif level > 0.55:
            v = 3 if zcr[f] < 0.045 else 2
        elif level > 0.25:
            v = 1 if zcr[f] > 0.12 else (3 if zcr[f] < 0.04 else 2)
        else:
            v = 1
        out.append(v)
    return ''.join(str(v) for v in out)
