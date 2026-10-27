"""Découpe les planches de sprites en frames propres (alpha nettoyé, ancrage commun)."""
import sys, json, numpy as np
from pathlib import Path
from PIL import Image
from scipy import ndimage

FRAME_W, FRAME_H = 420, 500       # taille de frame commune
ANCHOR_X, ANCHOR_Y = 210, 485     # bas des pieds, centre du corps

def clean_alpha(rgba):
    a = rgba.astype(np.float32)
    al = a[..., 3] / 255.0
    al[al < 0.07] = 0                       # supprime le voile résiduel du fond
    al[al > 0.94] = 1                       # corps opaque (était à 253)
    # décontamination : retire la frange blanche (couleur mêlée au fond blanc)
    m = (al > 0) & (al < 1)
    for c in range(3):
        ch = a[..., c]
        ch[m] = np.clip((ch[m] - 255 * (1 - al[m])) / np.maximum(al[m], 1e-3), 0, 255)
    a[..., 3] = al * 255
    return a.astype(np.uint8)

def body_anchor(fr):
    al = fr[..., 3] > 200
    lum = fr[..., :3].mean(-1)
    dark = al & (lum < 90)
    lab, n = ndimage.label(dark)
    if n == 0: return None
    sizes = ndimage.sum(dark, lab, range(1, n + 1))
    big = lab == (np.argmax(sizes) + 1)
    ys, xs = np.nonzero(big)
    opaque_rows = np.nonzero(al.any(1))[0]
    return xs.mean(), ys.max(), np.sqrt(big.sum())

TARGET_BODY = 210.0   # taille de référence du corps (px) commune à toutes les planches

def slice_sheet(path, out_dir, name, cols=4, rows=2, align=True):
    im = np.array(Image.open(path).convert('RGBA'))
    im = clean_alpha(im)
    # normalisation d'échelle par planche (médiane des corps détectés)
    H, W = im.shape[:2]; cw, ch = W // cols, H // rows
    sizes = [body_anchor(im[r*ch:(r+1)*ch, c*cw:(c+1)*cw]) for r in range(rows) for c in range(cols)]
    sizes = [s[2] for s in sizes if s and s[2] > 120]
    k = TARGET_BODY / float(np.median(sizes))
    if abs(k - 1) > 0.02:
        im = np.array(Image.fromarray(im).resize((round(W*k), round(H*k)), Image.LANCZOS))
    H, W = im.shape[:2]
    cw, ch = W // cols, H // rows
    out_dir.mkdir(parents=True, exist_ok=True)
    meta = []
    for r in range(rows):
        for c in range(cols):
            i = r * cols + c
            cell = im[r*ch:(r+1)*ch, c*cw:(c+1)*cw].copy()
            # supprime les débordements des cellules voisines : composantes touchant le bord
            lab, n = ndimage.label(cell[..., 3] > 0)
            if n:
                sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
                main = int(np.argmax(sizes)) + 1
                edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0, main}
                for e in edge: cell[lab == e] = 0
            canvas = np.zeros((FRAME_H, FRAME_W, 4), np.uint8)
            anc = body_anchor(cell) if align else None
            if anc and anc[2] < 120: anc = None   # frame sans corps (explosion/fumée)
            if anc:
                cx, by, size = anc
                dx, dy = int(round(ANCHOR_X - cx)), int(round(ANCHOR_Y - by))
            else:
                ys, xs = np.nonzero(cell[..., 3] > 0)
                dx = int(FRAME_W/2 - (xs.min()+xs.max())/2); dy = int(FRAME_H/2 - (ys.min()+ys.max())/2)
                size = None
            # coller la cellule décalée dans le canvas
            y0, x0 = max(0, dy), max(0, dx)
            sy0, sx0 = max(0, -dy), max(0, -dx)
            hh = min(FRAME_H - y0, ch - sy0); ww = min(FRAME_W - x0, cw - sx0)
            canvas[y0:y0+hh, x0:x0+ww] = cell[sy0:sy0+hh, sx0:sx0+ww]
            # contrôle de coupure : alpha opaque perdu ?
            lost = int((cell[..., 3] > 128).sum() - (canvas[..., 3] > 128).sum())
            fn = f'{name}_{i:02d}.png'
            Image.fromarray(canvas).save(out_dir / fn, optimize=True)
            meta.append({'file': fn, 'shift': [dx, dy], 'body_size': None if size is None else round(float(size),1), 'clipped_px': lost})
    return meta

if __name__ == '__main__':
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    plan = json.loads(sys.argv[3])
    report = {}
    for fname, (name, align) in plan.items():
        report[name] = slice_sheet(src / fname, out / name, name, align=align)
    print(json.dumps(report, indent=1))
