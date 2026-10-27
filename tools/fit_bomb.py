"""Trouve le placement de la bombe (pieds x/y en fraction d'écran, largeur du
corps en fraction) qui superpose au mieux la silhouette du sprite sur la
maquette. Même convention que BombGame._layout : frame 420×500, ancre
(0.5, 0.97), corps = 244 px de large dans la frame."""
import json, sys
import numpy as np
from PIL import Image

def dark(rgb):
    a = rgb.astype(int); lum = a.mean(-1); sat = a.max(-1) - a.min(-1)
    return ((lum < 75) & (sat < 70)).astype(np.float32)

def sprite_mask(sheet, idx):
    im = np.asarray(Image.open(sheet).convert('RGBA'))[:, idx * 420:(idx + 1) * 420]
    m = (im[..., 3] > 200) & (im[..., :3].astype(int).mean(-1) < 90)
    return Image.fromarray((m * 255).astype(np.uint8))

def fit(ref_path, sheet, idx, y_max=1.0):
    ref = np.asarray(Image.open(ref_path).convert('RGB'))
    H, W = ref.shape[:2]
    D = dark(ref); D[int(H * y_max):] = 0
    M0 = sprite_mask(sheet, idx)
    best = (-1, None)
    for bw in np.arange(0.30, 0.85, 0.02):
        k = W * bw / 244.0
        fw, fh = max(1, round(420 * k)), max(1, round(500 * k))
        M = np.asarray(M0.resize((fw, fh))) > 127
        for fx in np.arange(0.30, 0.70, 0.01):
            for fy in np.arange(0.40, 1.0, 0.01):
                x0 = round(W * fx - fw * 0.5); y0 = round(H * fy - fh * 0.97)
                cx0, cy0 = max(0, x0), max(0, y0); cx1, cy1 = min(W, x0 + fw), min(H, y0 + fh)
                if cx1 <= cx0 or cy1 <= cy0: continue
                sub = M[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0]
                d = D[cy0:cy1, cx0:cx1]
                inter = (sub * d).sum(); union = sub.sum() + D.sum() * 0 + (d.sum() - inter) + 1e-6
                # IoU local : silhouette vs zones sombres sous la silhouette + débord
                iou = inter / (M.sum() + (D[cy0:cy1, cx0:cx1].sum() - inter) + 1e-6)
                if iou > best[0]: best = (iou, (round(fx, 3), round(fy, 3), round(bw, 3)))
    return best

if __name__ == '__main__':
    jobs = json.loads(sys.argv[1])
    for name, (state, idx, ymax) in jobs.items():
        iou, p = fit(f'reference/{name}.png', f'assets/sprites/bomb_{state}.png', idx, ymax)
        print(name, 'feet=(%.3f, %.3f) bodyWidth=%.3f' % p, 'IoU=%.2f' % iou)
