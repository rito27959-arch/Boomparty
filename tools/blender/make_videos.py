"""Vidéos de contrôle des animations (directive §9) :
- une vidéo par état (3 boucles) ;
- la séquence de transitions IDLE → LISTENING → HAPPY → TALKING → PANIC → EXPLOSION → DEFEATED ;
- une planche de cohérence (toutes les frames d'un état superposées en transparence)
  pour repérer les déplacements involontaires.

    python make_videos.py <frames_dir> <out_dir>
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

BG = (253, 246, 229, 255)


def compose(frames, label, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    for i, f in enumerate(frames):
        im = Image.open(f).convert('RGBA')
        bg = Image.new('RGBA', im.size, BG)
        bg.alpha_composite(im)
        d = ImageDraw.Draw(bg)
        d.text((8, 8), label(i), fill=(60, 40, 80, 255))
        bg.convert('RGB').save(out_dir / f'{i:04d}.png')


def encode(seq_dir, fps, out):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', str(seq_dir / '%04d.png'),
                    '-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-vf', 'scale=420:500', str(out)], check=True)


def main(src, dst):
    src, dst = Path(src), Path(dst)
    dst.mkdir(parents=True, exist_ok=True)
    meta = json.loads((src / 'frames.json').read_text())
    for st, m in meta.items():
        files = [src / f for f in m['files']]
        seq = files * (1 if not m['loop'] else 3)
        with tempfile.TemporaryDirectory() as tmp:
            compose(seq, lambda i, st=st, n=len(files): f'{st}  {i % n + 1}/{n}', Path(tmp))
            encode(Path(tmp), m['fps'], dst / f'{st}.mp4')
        # planche de cohérence : superposition de toutes les frames
        acc = None
        for f in files:
            im = Image.open(f).convert('RGBA')
            im.putalpha(im.split()[3].point(lambda a, n=len(files): int(a / n * 1.6)))
            acc = im if acc is None else Image.alpha_composite(acc, im)
        bg = Image.new('RGBA', acc.size, BG)
        bg.alpha_composite(acc)
        bg.convert('RGB').save(dst / f'{st}_onion.png')
    order = ['idle', 'listening', 'happy', 'talking', 'panic', 'countdown', 'explosion', 'defeated']
    seq, labels = [], []
    for st in order:
        if st not in meta:
            continue
        files = [src / f for f in meta[st]['files']]
        reps = 1 if not meta[st]['loop'] else 2
        seq += files * reps
        labels += [st.upper()] * len(files) * reps
    with tempfile.TemporaryDirectory() as tmp:
        compose(seq, lambda i: labels[i], Path(tmp))
        encode(Path(tmp), 12, dst / 'transitions_idle_to_explosion.mp4')
    print('vidéos écrites dans', dst)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
