"""Illustrations HD de la bombe rendues dans Blender (même modèle que les
animations) : héros de l'accueil, mascottes des modes, skins, voix.

    python render_illustrations.py <assets/illustrations> [noms,séparés] [samples]
"""
import os
import sys
from dataclasses import replace

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402
from bomb_rig import BombRig  # noqa: E402
from poses import H_FIST, H_THUMB, POSES  # noqa: E402

RUN = replace(POSES['hero'], left=replace(H_FIST, pos=(1.0, -0.45, -0.05)), right=replace(H_THUMB, pos=(1.0, -0.4, -0.1)),
              foot_l=(-0.15, 0.25, 0.6), tilt=0.12, lean=0.08, look=(0.2, 0.1), spark=1.3)

# nom : (pose, skin, accessoires, résolution)
ITEMS = {
    'hero_home': (RUN, 'classique', ['mic'], 1024),
    'hero_thumbs': (POSES['hero'], 'classique', [], 1024),
    'mode_culture': (POSES['happy'], 'classique', [], 512),
    'mode_fou': (replace(POSES['laugh'], m_tongue_out=0.7, m_tongue=0.8, happy_eyes=False, look=(0.3, 0.2)), 'classique', ['crown'], 512),
    'mode_amis': (replace(POSES['happy'], look=(-0.2, 0.1)), 'classique', [], 512),
    'mode_reflexes': (POSES['celebrate'], 'classique', [], 512),
    'mode_extreme': (replace(POSES['angry'], m_open=0.32, m_smile=0.18, m_teeth=0.09, m_lower_teeth=0.07), 'diable', ['horns'], 512),
    'skin_classique': (POSES['happy'], 'classique', [], 512),
    'skin_glace': (POSES['happy'], 'glace', [], 512),
    'skin_ninja': (replace(POSES['angry'], m_open=0.2, m_smile=0.1), 'ninja', ['headband'], 512),
    'skin_citrouille': (POSES['happy'], 'citrouille', ['stem'], 512),
    'skin_arc': (POSES['laugh'], 'arc', [], 512),
    'skin_galaxie': (POSES['happy'], 'galaxie', [], 512),
    'skin_acier': (POSES['idle'], 'acier', [], 512),
    'skin_bonbon': (POSES['happy'], 'bonbon', [], 512),
    'skin_lave': (replace(POSES['angry'], m_open=0.3, m_smile=-0.05), 'lave', [], 512),
    'voice_classique': (POSES['happy'], 'classique', [], 384),
    'voice_drole': (replace(POSES['laugh'], m_tongue_out=0.6), 'drole', [], 384),
    'voice_serieuse': (replace(POSES['idle'], brow_h=(-0.05, -0.05), brow_a=(0.3, 0.3), m_smile=0.0), 'serieuse', [], 384),
    'voice_robot': (replace(POSES['idle'], m_open=0.12, m_smile=0.0, m_teeth=0.05), 'robot', ['antenna'], 384),
}


def main():
    out = sys.argv[1]
    names = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] != 'all' else list(ITEMS)
    samples = int(sys.argv[3]) if len(sys.argv) > 3 else 64
    os.makedirs(out, exist_ok=True)
    by_res = {}
    for n in names:
        by_res.setdefault(ITEMS[n][3], []).append(n)
    for res, group in by_res.items():
        res = int(os.environ.get('ILLU_RES', res))
        rig = BombRig(res=(res, res), samples=samples, camera='portrait')
        for n in group:
            pose, skin, extras, _ = ITEMS[n]
            props.set_body_skin(rig, skin)
            added = []
            for e in extras:
                if e == 'crown':
                    added.append(props.crown(rig))
                elif e == 'horns':
                    added += props.horns(rig)
                elif e == 'headband':
                    added += props.headband(rig)
                elif e == 'stem':
                    added += props.pumpkin_stem(rig)
                elif e == 'antenna':
                    added += props.antenna(rig)
                elif e == 'mic':
                    added.append(props.microphone(rig, rig.hands[0]))
            rig.set_pose(pose)
            rig.render(os.path.join(out, f'{n}.png'))
            props.remove(added)
            print(n, flush=True)


if __name__ == '__main__':
    main()
