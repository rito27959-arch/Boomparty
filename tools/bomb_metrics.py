"""Mesure le corps de la bombe (plus grande zone sombre) dans la référence et la
capture : centre et largeur en fraction de l'écran. Sert à recaler les placements."""
import sys, json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

def body(path, size, y0=0.12, y1=0.76, lmax=50):
    im = np.asarray(Image.open(path).convert('RGB').resize(size)).astype(int)
    lum = im.mean(-1); sat = im.max(-1) - im.min(-1)
    m = (lum < lmax) & (sat < 60)
    H0 = m.shape[0]; m[:int(H0 * y0)] = False; m[int(H0 * y1):] = False
    m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    if n == 0: return None
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    b = lab == (np.argmax(sizes) + 1)
    ys, xs = np.nonzero(b)
    # largeur = largeur médiane des 20 % de lignes les plus larges (ignore mains/pieds fins)
    rows = b.sum(1); w = np.percentile(rows[rows > 0], 90)
    W, H = size
    return {'cx': round(xs.mean() / W, 3), 'cy': round(ys.mean() / H, 3), 'w': round(w / W, 3)}

ref, cap = Path(sys.argv[1]), Path(sys.argv[2])
out = {}
for n in sys.argv[3].split(','):
    r = Image.open(ref / f'{n}.png'); size = r.size
    out[n] = {'ref': body(ref / f'{n}.png', size), 'cap': body(cap / f'{n}.png', size)}
print(json.dumps(out, indent=1))
