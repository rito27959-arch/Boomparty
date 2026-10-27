"""Dessine le sprite placé (contour cyan) sur la référence pour contrôler un calage."""
import sys, json
import numpy as np
sys.path.insert(0, 'tools')
from fit_bomb import frame_box
from PIL import Image, ImageFilter
jobs = json.loads(sys.argv[1]); out = sys.argv[2]
tiles = []
for name, (state, idx, fx, fy, bw) in jobs.items():
    ref = Image.open(f'reference/{name}.png').convert('RGB'); W, H = ref.size
    sheet = f'assets/sprites/bomb_{state}.png'
    sp = Image.open(sheet).convert('RGBA').crop(frame_box(sheet, idx))
    k = W * bw / 244.0; fw, fh = round(420 * k), round(500 * k)
    sp = sp.resize((fw, fh))
    a = sp.split()[3].point(lambda v: 255 if v > 128 else 0)
    edge = a.filter(ImageFilter.FIND_EDGES)
    canvas = ref.copy().convert('RGBA')
    ghost = sp.copy(); ghost.putalpha(a.point(lambda v: v * 90 // 255))
    pos = (round(W * fx - fw * 0.5), round(H * fy - fh * 0.955))
    canvas.alpha_composite(ghost, (max(pos[0],0), max(pos[1],0)) if min(pos) >= 0 else (0, 0)) if min(pos) >= 0 else None
    cyan = Image.new('RGBA', (fw, fh), (0, 255, 255, 255)); cyan.putalpha(edge)
    canvas.paste(cyan, pos, cyan)
    tiles.append(canvas.resize((W * 2, H * 2)))
Hm = max(t.height for t in tiles)
s = Image.new('RGB', (sum(t.width + 10 for t in tiles), Hm), 'white'); x = 0
for t in tiles: s.paste(t, (x, 0)); x += t.width + 10
s.save(out)
