"""Assemble les frames par état en spritesheets horizontales + métadonnées JSON pour Flame."""
import json, sys
from pathlib import Path
from PIL import Image
src, dst = Path(sys.argv[1]), Path(sys.argv[2])
man = json.loads((src / 'manifest.json').read_text())
fw, fh = man['frame_size']
# durée par frame (s) et bouclage, choisis par état
TIMING = {'idle': (0.55, True), 'talking': (0.11, True), 'happy': (0.22, True), 'laughing': (0.16, True),
          'celebration': (0.25, True), 'angry': (0.18, True), 'panic': (0.09, True),
          'countdown': (0.14, True), 'explosion': (0.12, False), 'defeated': (0.45, False)}
out = {'frameWidth': fw, 'frameHeight': fh, 'anchor': man['anchor'], 'states': {}, 'missing': man['missing']}
dst.mkdir(parents=True, exist_ok=True)
for st, frames in man['states'].items():
    sheet = Image.new('RGBA', (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.open(src / f['file']), (i * fw, 0))
    sheet.save(dst / f'bomb_{st}.png', optimize=True)
    step, loop = TIMING[st]
    out['states'][st] = {'image': f'bomb_{st}.png', 'frames': len(frames), 'stepTime': step, 'loop': loop,
                         'sources': [f['source'] for f in frames]}
(dst / 'bomb_animations.json').write_text(json.dumps(out, indent=1, ensure_ascii=False))
print({k: v['frames'] for k, v in out['states'].items()})
