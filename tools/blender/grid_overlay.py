"""Superpose une grille en unités du corps (centre = cercle inscrit, pas 0.25)."""
import sys
import numpy as np
from PIL import Image, ImageDraw
from face_metrics import load
from scipy import ndimage

def frame(path):
    rgb = load(path)
    corner = rgb[2, 2]
    near = np.abs(rgb - corner).max(-1) < 30
    lab, _ = ndimage.label(near)
    bg = np.isin(lab, [lab[0, 0], lab[0, -1], lab[-1, 0], lab[-1, -1]]) & near
    fg = ndimage.binary_fill_holes(~bg)
    edt = ndimage.distance_transform_edt(fg)
    cy, cx = np.unravel_index(np.argmax(edt), edt.shape)
    return Image.fromarray(rgb.astype(np.uint8)), cx, cy, float(edt.max())

out = []
for p in sys.argv[2:]:
    im, cx, cy, r = frame(p)
    S = 700 / (r * 4.4)
    im = im.resize((int(im.width * S), int(im.height * S)), Image.LANCZOS)
    cx, cy, r = cx * S, cy * S, r * S
    crop = im.crop((int(cx - 2.2 * r), int(cy - 2.2 * r), int(cx + 2.2 * r), int(cy + 2.2 * r))).convert('RGB')
    d = ImageDraw.Draw(crop)
    o = 2.2 * r
    for k in range(-8, 9):
        v = k * 0.25 * r
        col = (0, 200, 255) if k % 4 == 0 else (120, 220, 255)
        d.line([(o + v, 0), (o + v, crop.height)], fill=col, width=2 if k % 4 == 0 else 1)
        d.line([(0, o + v), (crop.width, o + v)], fill=col, width=2 if k % 4 == 0 else 1)
        if k % 2 == 0:
            d.text((o + v + 2, 2), f'{k*0.25:+.1f}', fill=(255, 0, 120))
            d.text((2, o - v + 2), f'{k*0.25:+.1f}', fill=(255, 0, 120))
    d.ellipse([o - r, o - r, o + r, o + r], outline=(255, 0, 120), width=2)
    out.append(crop)
W = sum(c.width + 10 for c in out)
s = Image.new('RGB', (W, max(c.height for c in out)), 'white'); x = 0
for c in out: s.paste(c, (x, 0)); x += c.width + 10
s.save(sys.argv[1])
