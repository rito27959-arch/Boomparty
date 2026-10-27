"""Compare un rendu à la référence HD : [référence | rendu | superposition 50 %],
le rendu étant calé sur le corps de la référence (centre (601,650), rayon 375 px)."""
import sys
import numpy as np
from PIL import Image
sys.path.insert(0, '.')
REF = '/mnt/user-data/uploads/1000055067.png'
RC, RR = (601, 650), 375.0


def body_px(path):
    """Centre et rayon du corps dans le rendu, lus depuis le fichier .json écrit à côté."""
    import json
    return json.load(open(path.replace('.png', '.json')))


def main(out, render):
    ref = Image.open(REF).convert('RGB')
    meta = body_px(render)
    im = Image.open(render).convert('RGBA')
    k = RR / meta['r']
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    cx, cy = meta['cx'] * k, meta['cy'] * k
    canvas = Image.new('RGBA', ref.size, (253, 246, 229, 255))
    canvas.alpha_composite(im, (round(RC[0] - cx), round(RC[1] - cy)) if RC[0] - cx >= 0 and RC[1] - cy >= 0 else (0, 0))
    if RC[0] - cx < 0 or RC[1] - cy < 0:
        canvas = Image.new('RGBA', ref.size, (253, 246, 229, 255))
        tmp = Image.new('RGBA', (ref.width + 2000, ref.height + 2000), (0, 0, 0, 0))
        tmp.alpha_composite(im, (round(RC[0] - cx) + 1000, round(RC[1] - cy) + 1000))
        canvas.alpha_composite(tmp.crop((1000, 1000, 1000 + ref.width, 1000 + ref.height)))
    rend = canvas.convert('RGB')
    blend = Image.blend(ref, rend, 0.5)
    H = 560
    tiles = [x.resize((H, H)) for x in (ref, rend, blend)]
    s = Image.new('RGB', (H * 3 + 20, H), 'white')
    for i, t in enumerate(tiles):
        s.paste(t, (i * (H + 10), 0))
    s.save(out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
