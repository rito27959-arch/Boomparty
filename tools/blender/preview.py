"""Rend une ou plusieurs poses fixes : python preview.py hero,idle out_dir [échelle] [samples]"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bomb_rig import BombRig
from poses import POSES
names = sys.argv[1].split(','); out = sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
samples = int(sys.argv[4]) if len(sys.argv) > 4 else 32
os.makedirs(out, exist_ok=True)
rig = BombRig(res=(int(420 * scale), int(500 * scale)), samples=samples)
for n in names:
    t = time.time()
    rig.set_pose(POSES[n])
    rig.render(os.path.join(out, f'{n}.png'))
    rig.write_body_meta(os.path.join(out, f'{n}.json'))
    print(n, round(time.time() - t, 1), 's', flush=True)
