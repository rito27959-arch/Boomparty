"""Compare chaque capture à sa référence : SSIM, ΔE moyen (CIELAB), F1 des contours.
Produit des planches [référence | capture | superposition | carte des écarts]."""
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from skimage.metrics import structural_similarity
from skimage.color import rgb2lab, rgb2gray
from skimage.feature import canny
from scipy.ndimage import binary_dilation

ref_dir, cap_dir, out_dir = map(Path, sys.argv[1:4])
out_dir.mkdir(parents=True, exist_ok=True)
rows = []
for cap in sorted(cap_dir.glob('*.png')):
    ref_p = ref_dir / cap.name
    if not ref_p.exists():
        continue
    ref = Image.open(ref_p).convert('RGB')
    capi = Image.open(cap).convert('RGB').resize(ref.size, Image.LANCZOS)
    a, b = np.asarray(ref) / 255.0, np.asarray(capi) / 255.0
    ssim = structural_similarity(a, b, channel_axis=2, data_range=1.0)
    de_map = np.linalg.norm(rgb2lab(a) - rgb2lab(b), axis=2)
    ea, eb = canny(rgb2gray(a), sigma=1.5), canny(rgb2gray(b), sigma=1.5)
    prec = (eb & binary_dilation(ea, iterations=2)).sum() / max(eb.sum(), 1)
    rec = (ea & binary_dilation(eb, iterations=2)).sum() / max(ea.sum(), 1)
    f1 = 2 * prec * rec / max(prec + rec, 1e-9)
    # écarts par bandes horizontales (10 bandes) pour localiser les problèmes
    bands = [round(float(x), 1) for x in np.array_split(de_map, 10, axis=0) for x in [x.mean()]]
    rows.append({'screen': cap.stem, 'ssim': round(float(ssim), 3), 'deltaE_mean': round(float(de_map.mean()), 2),
                 'deltaE_p90': round(float(np.percentile(de_map, 90)), 1), 'edge_f1': round(float(f1), 3),
                 'deltaE_by_band_top_to_bottom': bands})
    S = 2
    W, H = ref.width * S, ref.height * S
    heat = Image.fromarray((np.clip(de_map / 40, 0, 1) * 255).astype(np.uint8)).resize((W, H))
    heat = Image.merge('RGB', (heat, Image.new('L', heat.size, 0), Image.new('L', heat.size, 40)))
    over = Image.blend(ref, capi, 0.5)
    sheet = Image.new('RGB', (W * 4 + 30, H + 24), 'white')
    for i, im in enumerate([ref, capi, over, heat]):
        sheet.paste(im.resize((W, H), Image.LANCZOS), (i * (W + 10), 24))
    d = ImageDraw.Draw(sheet)
    for i, t in enumerate(['reference', 'capture', 'superposition 50%', 'ecart deltaE (rouge = fort)']):
        d.text((i * (W + 10) + 4, 6), t, fill='black')
    sheet.save(out_dir / f'{cap.stem}_compare.png')
(out_dir / 'report.json').write_text(json.dumps(rows, indent=1))
md = ['| écran | SSIM | ΔE moyen | ΔE p90 | F1 contours |', '|---|---|---|---|---|']
md += [f"| {r['screen']} | {r['ssim']} | {r['deltaE_mean']} | {r['deltaE_p90']} | {r['edge_f1']} |" for r in rows]
(out_dir / 'report.md').write_text('\n'.join(md) + '\n')
print('\n'.join(md))
