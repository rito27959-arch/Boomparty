"""Bibliothèque d'expressions de la bombe (paramètres du rig, pas d'images).

Toutes les mains sont décrites comme des mains DROITES (x > 0) ; le rig
applique la symétrie pour la main gauche.
"""
import math
from dataclasses import replace

from mathutils import Matrix, Vector

from bomb_rig import Hand, Pose


def orient(fingers, palm, tilt=0.0):
    """Euler du gant à partir de deux directions monde : 'fingers' = où
    pointent les doigts tendus (Z local), 'palm' = où regarde l'intérieur de
    la paume (-Y local)."""
    z = Vector(fingers).normalized()
    y = -Vector(palm).normalized()
    y = (y - z * y.dot(z)).normalized()
    x = y.cross(z)
    m = Matrix((x, y, z)).transposed()
    return tuple((m @ Matrix.Rotation(tilt, 3, 'Z')).to_euler())


# poing pouce levé : doigts vers l'extérieur, paume vers l'arrière (phalanges face caméra)
THUMB = orient(fingers=(1, -0.25, -0.15), palm=(0, -1, 0))
# main ouverte : doigts vers le haut, dos de la main vers la caméra
OPEN = orient(fingers=(0.35, -0.1, 1), palm=(0, 1, 0))
# index pointé vers le haut
POINT = orient(fingers=(0.1, -0.2, 1), palm=(-0.4, 1, 0))
# mains plaquées sur les joues : doigts vers le haut, paume vers le visage
CHEEK = orient(fingers=(-0.15, -0.1, 1), palm=(-1, -0.3, 0))
# poing serré au repos
FIST = orient(fingers=(0.6, -0.5, -0.3), palm=(-0.3, 1, 0.2))
REST = orient(fingers=(0.3, -0.3, -1), palm=(-1, 0.2, 0))

CURLED = (1.6, 1.6, 1.6, 1.6)
H_REST = Hand(pos=(1.0, -0.3, -0.3), rot=THUMB, curl=(1.2, 1.3, 1.4, 1.5), thumb=0.6)
H_FIST = Hand(pos=(1.0, -0.35, -0.22), rot=THUMB, curl=CURLED, thumb=1.0)
H_THUMB = Hand(pos=(1.12, -0.35, -0.2), rot=THUMB, curl=CURLED, thumb=-1.0)
H_POINT = Hand(pos=(1.1, -0.45, 0.25), rot=POINT, curl=(0.0, 1.6, 1.6, 1.6), thumb=1.0)
H_OPEN = Hand(pos=(1.18, -0.3, -0.22), rot=OPEN, curl=(0.1, 0.05, 0.05, 0.1), thumb=-0.3, spread=0.6)
H_CHEEK = Hand(pos=(0.92, -0.55, -0.05), rot=CHEEK, curl=(0.15, 0.1, 0.1, 0.15), thumb=-0.2, spread=0.3)

BASE = Pose(left=H_REST, right=H_REST)

POSES = {
    'hero': replace(BASE, m_width=0.515, m_open=0.49, m_smile=0.0, m_arch=0.095, m_teeth=0.12, m_tongue=0.5,
                    left=replace(H_THUMB, pos=(0.8, -0.45, -0.3)), right=replace(H_THUMB, pos=(0.98, -0.35, -0.3))),
    'idle': replace(BASE, m_open=0.05, m_smile=0.12, m_teeth=0.0, m_tongue=0.0, m_arch=0.0),
    'listening': replace(BASE, m_open=0.05, m_smile=0.05, m_teeth=0.0, m_tongue=0.0, look=(0.5, 0.25),
                         brow_h=(0.04, -0.01), tilt=-0.06),
    'talk_a': replace(BASE, m_width=0.42, m_open=0.5, m_smile=0.06, m_teeth=0.08, m_tongue=0.55, right=H_OPEN, left=H_REST),
    'talk_o': replace(BASE, m_open=0.36, m_width=0.2, m_smile=-0.02, m_arch=0.12, m_teeth=0.03, m_tongue=0.45,
                      right=H_OPEN, left=H_REST),
    'talk_e': replace(BASE, m_open=0.22, m_width=0.34, m_smile=0.08, m_teeth=0.07, m_tongue=0.3, right=H_OPEN, left=H_REST),
    'talk_m': replace(BASE, m_open=0.04, m_smile=0.06, m_teeth=0.0, m_tongue=0.0, m_arch=0.0, right=H_OPEN, left=H_REST),
    'happy': replace(BASE, m_width=0.46, m_open=0.55, m_smile=0.1, m_teeth=0.09, m_tongue=0.55, left=H_FIST,
                     right=H_THUMB, brow_h=(0.05, 0.05)),
    'laugh': replace(BASE, happy_eyes=True, m_width=0.46, m_open=0.6, m_smile=0.14, m_teeth=0.09, m_tongue=0.6,
                     left=H_FIST, right=H_FIST, brow_h=(0.06, 0.06)),
    'angry': replace(BASE, lid=0.34, lid_angle=0.5, brow_h=(-0.1, -0.1), brow_a=(1.0, 1.0), m_open=0.18,
                     m_width=0.26, m_smile=-0.12, m_arch=0.06, m_teeth=0.06, m_lower_teeth=0.06, m_tongue=0.0,
                     left=H_FIST, right=H_FIST),
    'angry_shout': replace(BASE, lid=0.28, lid_angle=0.5, brow_h=(-0.1, -0.1), brow_a=(1.0, 1.0), m_open=0.5,
                           m_width=0.38, m_smile=-0.14, m_arch=0.06, m_teeth=0.06, m_tongue=0.55,
                           left=H_FIST, right=H_FIST),
    'confused': replace(BASE, brow_h=(0.1, -0.06), brow_a=(-0.3, 0.4), m_open=0.08, m_width=0.16, m_dx=0.08,
                        m_smile=-0.04, m_arch=0.04, m_teeth=0.0, m_tongue=0.0, look=(-0.4, 0.4), tilt=0.12,
                        right=H_POINT),
    'panic': replace(BASE, eye_scale=1.08, pupil=0.72, brow_h=(0.1, 0.1), brow_a=(-0.6, -0.6), m_open=0.55,
                     m_width=0.38, m_smile=-0.14, m_arch=0.1, m_teeth=0.06, m_tongue=0.5, left=H_CHEEK,
                     right=H_CHEEK, sweat=1.0),
    'scared': replace(BASE, eye_scale=1.1, pupil=0.7, brow_h=(0.1, 0.1), brow_a=(-0.6, -0.6), m_open=0.3,
                      m_width=0.22, m_smile=-0.08, m_arch=0.1, m_teeth=0.05, m_tongue=0.45, left=H_OPEN,
                      right=H_OPEN, sweat=0.5),
    'defeated': replace(BASE, x_eyes=True, m_open=0.25, m_width=0.24, m_smile=-0.06, m_tongue=0.8,
                        m_tongue_out=0.5, m_teeth=0.0, soot=0.55, spark=0.0, fuse_len=0.45, tilt=0.18, squash=0.12,
                        brow_h=(-0.02, 0.04), cheek=0.0),
    # réflexion : regard en l'air, sourcil levé, main au menton
    'thinking': replace(BASE, look=(0.35, 0.45), brow_h=(0.12, 0.0), brow_a=(-0.2, 0.2), m_open=0.05, m_width=0.18,
                        m_dx=0.1, m_smile=-0.02, m_arch=0.02, m_teeth=0.0, m_tongue=0.0, tilt=-0.08,
                        # main sous le menton (pose « je réfléchis »)
                        right=Hand(pos=(0.3, -1.0, -0.8), rot=CHEEK, curl=(0.9, 1.3, 1.4, 1.5), thumb=0.4),
                        left=H_REST),
    # visèmes (synchronisation labiale) : même pose, seule la bouche change
    'vis_rest': replace(BASE, m_open=0.04, m_width=0.3, m_smile=0.08, m_teeth=0.0, m_tongue=0.0, m_arch=0.0, right=H_OPEN),
    'vis_e': replace(BASE, m_open=0.2, m_width=0.38, m_smile=0.1, m_teeth=0.08, m_tongue=0.25, right=H_OPEN),
    'vis_a': replace(BASE, m_open=0.5, m_width=0.42, m_smile=0.06, m_teeth=0.08, m_tongue=0.5, right=H_OPEN),
    'vis_o': replace(BASE, m_open=0.36, m_width=0.2, m_smile=-0.02, m_arch=0.12, m_teeth=0.03, m_tongue=0.4, right=H_OPEN),
    'vis_m': replace(BASE, m_open=0.025, m_width=0.24, m_smile=0.02, m_teeth=0.0, m_tongue=0.0, m_arch=0.0, right=H_OPEN),
    'celebrate': replace(BASE, m_width=0.48, m_open=0.6, m_smile=0.15, m_teeth=0.09, m_tongue=0.6,
                         left=replace(H_THUMB, pos=(1.1, -0.4, 0.3)), right=replace(H_THUMB, pos=(1.1, -0.4, 0.3)),
                         brow_h=(0.06, 0.06)),
}
