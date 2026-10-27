"""Rend toutes les animations de la bombe depuis le modèle 3D Blender et
produit les spritesheets + métadonnées lues par Flame.

Chaque frame est un rendu du même personnage 3D (aucun collage d'images) :
les poses clés viennent de poses.py, l'animation (anticipation, squash &
stretch, follow-through, clignements, tremblements) est calculée ici.

    python render_anims.py <dossier_sortie> [états,séparés,par,virgule] [samples]
"""
import json
import math
import os
import sys
from dataclasses import replace

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bomb_rig import BombRig, blend  # noqa: E402
from poses import POSES, H_OPEN, H_REST  # noqa: E402

FPS = 12


def ease(t):
    return t * t * (3 - 2 * t)


def ping(t):
    """0→1→0 sur un cycle."""
    return 0.5 - 0.5 * math.cos(2 * math.pi * t)


def hop(t, height=0.28):
    """Saut cartoon sur un cycle : anticipation (squash), envol (stretch),
    réception (squash) puis retour."""
    if t < 0.18:          # anticipation
        k = ease(t / 0.18)
        return 0.0, 0.12 * k
    if t < 0.62:          # en l'air
        k = (t - 0.18) / 0.44
        y = height * 4 * k * (1 - k)
        st = -0.10 * (1 - abs(2 * k - 1))   # étiré en montée/descente
        return y, st
    if t < 0.8:           # réception
        k = (t - 0.62) / 0.18
        return 0.0, 0.14 * math.sin(math.pi * k)
    return 0.0, 0.0


def anim_idle(n=24):
    base = POSES['idle']
    out = []
    for f in range(n):
        t = f / n
        b = math.sin(2 * math.pi * t)
        lid = {16: 0.6, 17: 1.0, 18: 0.55}.get(f, 0.0)          # clignement naturel
        look = (0.12 * math.sin(2 * math.pi * t), 0.04)
        out.append(replace(base, squash=0.03 * b, lid=lid, look=look, spark_phase=t * 3,
                           tilt=0.02 * math.sin(2 * math.pi * t + 1)))
    return out


def anim_listening(n=16):
    base = POSES['listening']
    out = []
    for f in range(n):
        t = f / n
        gx = 0.55 * math.sin(2 * math.pi * t)
        lid = 0.9 if f == 11 else 0.0
        out.append(replace(base, look=(gx, 0.25 + 0.08 * math.sin(4 * math.pi * t)), lid=lid,
                           tilt=-0.06 + 0.03 * math.sin(2 * math.pi * t), squash=0.02 * math.sin(4 * math.pi * t),
                           brow_h=(0.05 + 0.03 * ping(t), 0.0), spark_phase=t * 2))
    return out


VISEMES = ['talk_a', 'talk_e', 'talk_o', 'talk_m', 'talk_a', 'talk_o', 'talk_e', 'talk_a',
           'talk_m', 'talk_o', 'talk_a', 'talk_e', 'talk_m', 'talk_a', 'talk_o', 'talk_m']


def anim_talking(n=16):
    out = []
    for f in range(n):
        t = f / n
        p = POSES[VISEMES[f % len(VISEMES)]]
        hand_z = -0.22 + 0.12 * math.sin(2 * math.pi * t * 2)
        right = replace(H_OPEN, pos=(1.18, -0.3, hand_z))
        out.append(replace(p, right=right, squash=0.025 * math.sin(4 * math.pi * t),
                           tilt=0.03 * math.sin(2 * math.pi * t), spark_phase=t * 2,
                           brow_h=(0.03 * ping(t), 0.03 * ping(t + 0.25))))
    return out


def anim_happy(n=12):
    base = POSES['happy']
    out = []
    for f in range(n):
        t = f / n
        y, sq = hop(t)
        out.append(replace(base, lift=y, squash=sq, spark_phase=t * 2, tilt=0.04 * math.sin(2 * math.pi * t)))
    return out


def anim_laughing(n=12):
    base = POSES['laugh']
    out = []
    for f in range(n):
        t = f / n
        shake = math.sin(2 * math.pi * t * 3)
        out.append(replace(base, squash=0.07 * abs(shake), tilt=0.07 * math.sin(2 * math.pi * t),
                           lift=0.04 * abs(shake), m_open=0.5 + 0.12 * abs(shake), spark_phase=t * 2))
    return out


def anim_angry(n=12):
    a, b = POSES['angry'], POSES['angry_shout']
    out = []
    for f in range(n):
        t = f / n
        k = ease(ping(t))
        p = blend(a, b, k)
        tremble = 0.025 * math.sin(2 * math.pi * t * 6)
        stomp = (0.0, 0.12 * max(0.0, math.sin(2 * math.pi * t)), -0.25 * max(0.0, math.sin(2 * math.pi * t)))
        out.append(replace(p, tilt=tremble, squash=0.05 * k, foot_r=stomp, spark_phase=t * 3))
    return out


def anim_confused(n=16):
    base = POSES['confused']
    out = []
    for f in range(n):
        t = f / n
        k = ease(min(1.0, t * 3))
        out.append(replace(base, tilt=0.14 * k + 0.02 * math.sin(2 * math.pi * t),
                           look=(-0.4 + 0.8 * ping(t), 0.4), brow_h=(0.1 + 0.03 * ping(t), -0.06),
                           m_dx=0.08 * math.sin(2 * math.pi * t), spark_phase=t * 2))
    return out


def anim_panic(n=12):
    base = POSES['panic']
    out = []
    for f in range(n):
        t = f / n
        tr = math.sin(2 * math.pi * t * 4)
        out.append(replace(base, tilt=0.05 * tr, squash=0.03 * math.sin(2 * math.pi * t * 2),
                           look=(0.25 * math.sin(2 * math.pi * t * 2), 0.1), m_open=0.5 + 0.08 * tr,
                           spark=1.2, spark_phase=t * 4))
    return out


def anim_countdown(n=12):
    """Nervosité : boucle sans raccord (mèche courte, étincelle qui pulse,
    tremblement). L'accélération progressive est faite dans Flame (vitesse
    de lecture qui augmente avec le temps passé dans l'état)."""
    a, b = POSES['scared'], POSES['panic']
    out = []
    for f in range(n):
        t = f / n
        k = ping(t)
        p = blend(a, b, 0.4 + 0.4 * k)
        tr = math.sin(2 * math.pi * t * 4)
        out.append(replace(p, tilt=0.05 * tr, fuse_len=0.55, spark=1.3 + 0.35 * k, spark_phase=t * 6,
                           squash=-0.03 * k, sweat=0.7, look=(0.3 * math.sin(2 * math.pi * t), 0.15)))
    return out


def anim_explosion(n=12):
    """Anticipation (gonfle, yeux exorbités) → flash → boule de feu → fumée."""
    sc = POSES['scared']
    out = []
    for f in range(n):
        t = f / (n - 1)
        if t < 0.25:                       # anticipation : la bombe enfle
            k = ease(t / 0.25)
            out.append(replace(sc, squash=-0.12 * k, eye_scale=1.1 + 0.15 * k, pupil=0.6, fuse_len=0.3,
                               spark=1.8, spark_phase=f, tilt=0.05 * math.sin(f * 3), boom=-1.0))
        else:
            b = (t - 0.25) / 0.75
            out.append(replace(sc, boom=b, fuse_len=0.3, spark=0.0))
    return out


def anim_defeated(n=12):
    base = POSES['defeated']
    out = []
    for f in range(n):
        t = f / n
        out.append(replace(base, stars=1.0, stars_phase=t, smoke=1.0, tilt=0.18 + 0.05 * math.sin(2 * math.pi * t),
                           squash=0.12 + 0.02 * math.sin(4 * math.pi * t)))
    return out


def anim_celebration(n=12):
    base = POSES['celebrate']
    out = []
    for f in range(n):
        t = f / n
        y, sq = hop(t, 0.34)
        arm = 0.12 * math.sin(2 * math.pi * t)
        L = replace(base.left, pos=(1.1, -0.4, 0.3 + arm))
        R = replace(base.right, pos=(1.1, -0.4, 0.3 - arm))
        out.append(replace(base, lift=y, squash=sq, left=L, right=R, spark_phase=t * 2,
                           tilt=0.05 * math.sin(2 * math.pi * t)))
    return out


def anim_thinking(n=16):
    base = POSES['thinking']
    out = []
    for f in range(n):
        t = f / n
        out.append(replace(base, look=(0.35 + 0.1 * math.sin(2 * math.pi * t), 0.45), tilt=-0.08 + 0.03 * math.sin(2 * math.pi * t),
                           brow_h=(0.12 + 0.03 * ping(t), 0.0), lid=0.85 if f == 10 else 0.0, spark_phase=t * 2,
                           m_dx=0.1 + 0.04 * math.sin(4 * math.pi * t)))
    return out


def anim_visemes(n=5):
    """5 formes de bouche fixes, sélectionnées en temps réel par la synchro labiale."""
    return [POSES[k] for k in ('vis_rest', 'vis_e', 'vis_a', 'vis_o', 'vis_m')]


ANIMS = {
    'thinking': (anim_thinking, True),
    'visemes': (anim_visemes, False),
    'idle': (anim_idle, True),
    'listening': (anim_listening, True),
    'talking': (anim_talking, True),
    'happy': (anim_happy, True),
    'laughing': (anim_laughing, True),
    'angry': (anim_angry, True),
    'confused': (anim_confused, True),
    'panic': (anim_panic, True),
    'countdown': (anim_countdown, True),
    'explosion': (anim_explosion, False),
    'defeated': (anim_defeated, True),
    'celebration': (anim_celebration, True),
}


def main():
    out = sys.argv[1]
    states = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] != 'all' else list(ANIMS)
    samples = int(sys.argv[3]) if len(sys.argv) > 3 else 24
    rig = BombRig(res=(420, 500), samples=samples)
    meta_path = os.path.join(out, 'frames.json')
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    for st in states:
        fn, loop = ANIMS[st]
        frames = fn()
        d = os.path.join(out, st)
        os.makedirs(d, exist_ok=True)
        files = []
        for i, p in enumerate(frames):
            path = os.path.join(d, f'{st}_{i:02d}.png')
            rig.set_pose(p)
            rig.render(path)
            files.append(f'{st}/{st}_{i:02d}.png')
            print(st, i + 1, '/', len(frames), flush=True)
        meta[st] = {'files': files, 'loop': loop, 'fps': FPS}
        json.dump(meta, open(meta_path, 'w'), indent=1)


if __name__ == '__main__':
    main()
