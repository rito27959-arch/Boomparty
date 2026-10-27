"""Assemble les frames rendues par Blender en spritesheets (grille ≤ 8 colonnes,
largeur ≤ 3360 px) + bomb_animations.json pour Flame.

    python pack_blender.py <frames_dir> <assets/sprites>
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image

MAX_COLS = 8


def main(src, dst):
    src, dst = Path(src), Path(dst)
    meta = json.loads((src / 'frames.json').read_text())
    dst.mkdir(parents=True, exist_ok=True)
    for old in dst.glob('bomb_*.png'):
        old.unlink()
    out = {'source': 'blender', 'states': {}}
    fw = fh = None
    for st, m in meta.items():
        frames = [Image.open(src / f).convert('RGBA') for f in m['files']]
        fw, fh = frames[0].size
        cols = min(MAX_COLS, len(frames))
        rows = math.ceil(len(frames) / cols)
        sheet = Image.new('RGBA', (fw * cols, fh * rows), (0, 0, 0, 0))
        for i, im in enumerate(frames):
            sheet.paste(im, ((i % cols) * fw, (i // cols) * fh))
        name = f'bomb_{st}.png'
        sheet.save(dst / name, optimize=True)
        out['states'][st] = {'image': name, 'frames': len(frames), 'columns': cols,
                             'stepTime': round(1 / m['fps'], 4), 'loop': m['loop']}
        print(st, len(frames), 'frames', sheet.size)
    out['frameWidth'], out['frameHeight'] = fw, fh
    # ancre : pieds au sol à 95,5 % de la hauteur, corps = 244 px de large
    out['anchor'] = [fw / 2, round(fh * 0.955)]
    out['bodyWidthPx'] = round(2 * fw / (2.0 * 420 / 244))
    (dst / 'bomb_animations.json').write_text(json.dumps(out, indent=1))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
