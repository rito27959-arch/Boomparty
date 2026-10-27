"""Mesure les parties du personnage (yeux, iris, bouche, langue, gants, pieds)
en unités du corps : origine = centre du corps, 1 = rayon horizontal.
Usage : python face_metrics.py image.png [fond: auto]"""
import json, sys
import numpy as np
from PIL import Image
from scipy import ndimage


def load(path):
    im = Image.open(path).convert('RGBA')
    a = np.asarray(im).astype(float)
    rgb, al = a[..., :3], a[..., 3] / 255
    if al.min() < 0.99:  # rendu transparent : on compose sur crème comme la référence
        rgb = rgb * al[..., None] + np.array([253, 246, 229]) * (1 - al[..., None])
    return rgb


def comps(mask, min_px):
    lab, n = ndimage.label(mask)
    out = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if len(xs) >= min_px:
            out.append((xs.min(), xs.max(), ys.min(), ys.max(), len(xs)))
    return out


def measure(path):
    rgb = load(path)
    H, W = rgb.shape[:2]
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = rgb.mean(-1)
    sat = rgb.max(-1) - rgb.min(-1)
    dark = (lum < 75) & (sat < 80)
    dark = ndimage.binary_opening(dark, iterations=2)
    lab, n = ndimage.label(dark)
    sizes = ndimage.sum(dark, lab, range(1, n + 1))
    body = lab == (np.argmax(sizes) + 1)
    body = ndimage.binary_fill_holes(body)
    # fond : région connectée aux coins, de couleur proche du coin
    corner = rgb[2, 2]
    near = np.abs(rgb - corner).max(-1) < 30
    blab, _ = ndimage.label(near)
    bg = np.isin(blab, [blab[0, 0], blab[0, -1], blab[-1, 0], blab[-1, -1]]) & near
    # silhouette = tout sauf le fond ; cercle inscrit maximal = corps (bras, pieds, mèche ignorés)
    fg = ndimage.binary_fill_holes(~bg)
    edt = ndimage.distance_transform_edt(fg)
    cy, cx = np.unravel_index(np.argmax(edt), edt.shape)
    r = float(edt.max())
    ys = np.nonzero(fg.any(1))[0]
    top, bot = ys.min(), ys.max()
    S = lambda x0, x1, y0, y1: [round((x0 - cx) / r, 3), round((x1 - cx) / r, 3), round((cy - y1) / r, 3), round((cy - y0) / r, 3)]
    res = {'size_px': [W, H], 'body': {'cx': round(cx / W, 3), 'cy': round(cy / H, 3), 'r_frac_w': round(r / W, 3),
                                        'top': round((cy - top) / r, 3), 'bottom': round((bot - cy) / r, 3)}}
    min_px = int((r * 0.08) ** 2)
    white = (lum > 195) & (sat < 70) & ~bg
    w_comps = comps(white, min_px)
    eyes = [c for c in w_comps if abs((c[0] + c[1]) / 2 - cx) < r * 0.85 and (c[2] + c[3]) / 2 < cy + r * 0.2]
    gloves = [c for c in w_comps if c not in eyes and c[4] > min_px * 4]
    eyes.sort(key=lambda c: c[0])
    res['eyes'] = [S(*c[:4]) for c in eyes[:2]]
    res['gloves'] = [S(*c[:4]) for c in sorted(gloves, key=lambda c: c[0])]
    iris = (R > 120) & (G > 30) & (G < 150) & (B < 70) & (R - G > 50)
    ir = [c for c in comps(iris, min_px // 4) if (c[2] + c[3]) / 2 < cy + r * 0.1 and abs((c[0] + c[1]) / 2 - cx) < r * 0.8]
    res['iris'] = [S(*c[:4]) for c in sorted(ir, key=lambda c: -c[4])[:2]]
    tongue = (R > 150) & (G < 120) & (B < 120) & (R - G > 70)
    tg = [c for c in comps(tongue, min_px // 2) if (c[2] + c[3]) / 2 > cy - r * 0.3 and abs((c[0] + c[1]) / 2 - cx) < r * 0.8]
    res['tongue'] = [S(*c[:4]) for c in sorted(tg, key=lambda c: -c[4])[:1]]
    # bouche = région sombre-rouge / sombre entourant langue et dents : on prend l'enveloppe langue + dents blanches proches
    teeth = [c for c in w_comps if (c[2] + c[3]) / 2 > cy - r * 0.15 and abs((c[0] + c[1]) / 2 - cx) < r * 0.6 and c not in eyes]
    res['teeth'] = [S(*c[:4]) for c in sorted(teeth, key=lambda c: -c[4])[:1]]
    # pieds : composantes sombres sous le corps
    below = dark.copy(); below[: int(cy + r * 0.75)] = False
    ft = comps(below, min_px)
    res['feet'] = [S(*c[:4]) for c in sorted(ft, key=lambda c: c[0])[:2]]
    return res


if __name__ == '__main__':
    print(json.dumps(measure(sys.argv[1])))
