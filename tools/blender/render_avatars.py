"""Avatars 3D des joueurs (bustes d'enfants cartoon) rendus dans Blender.

    python render_avatars.py <assets/illustrations> [samples] [res]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402  (doit précéder bmesh)
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

from bomb_rig import _bsdf, _empty, _mesh_obj, _sphere  # noqa: E402

KIDS = [
    # nom, peau, cheveux, style, accessoire, tee-shirt
    ('emma', (0.98, 0.78, 0.66, 1), (0.22, 0.12, 0.07, 1), 'pigtails', (1.0, 0.6, 0.1, 1), (0.95, 0.35, 0.6, 1)),
    ('leo', (0.72, 0.45, 0.28, 1), (0.08, 0.05, 0.04, 1), 'short', None, (0.25, 0.5, 0.95, 1)),
    ('sarah', (0.98, 0.8, 0.7, 1), (0.35, 0.16, 0.08, 1), 'buns', (0.6, 0.3, 0.9, 1), (0.3, 0.7, 0.95, 1)),
    ('max', (0.6, 0.36, 0.2, 1), (0.06, 0.04, 0.03, 1), 'curly', None, (0.45, 0.78, 0.3, 1)),
    ('ines', (0.97, 0.78, 0.65, 1), (0.55, 0.2, 0.07, 1), 'side', (1.0, 0.45, 0.1, 1), (1.0, 0.7, 0.15, 1)),
]


def scene(res, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = samples
    s.cycles.use_denoising = True
    s.render.film_transparent = True
    s.render.resolution_x = s.render.resolution_y = res
    s.render.image_settings.color_mode = 'RGBA'
    s.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new('W')
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.95, 0.9, 0.9, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.45
    s.world = w
    for name, loc, e, col, size in (('Key', (2.5, -5, 4), 500, (1, 0.95, 0.9), 4), ('Rim', (-4, 2, 3), 250, (0.7, 0.8, 1), 3),
                                    ('Fill', (-1, -6, 0), 120, (1, 0.92, 0.9), 6)):
        ld = bpy.data.lights.new(name, 'AREA')
        ld.energy, ld.color, ld.size = e, col, size
        ob = bpy.data.objects.new(name, ld)
        s.collection.objects.link(ob)
        ob.location = loc
        ob.rotation_euler = (Vector((0, 0, 0.2)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cd = bpy.data.cameras.new('C')
    cd.type = 'ORTHO'
    cd.ortho_scale = 2.7
    cam = bpy.data.objects.new('C', cd)
    s.collection.objects.link(cam)
    cam.location = (0, -10, 0.05)
    cam.rotation_euler = (math.radians(90), 0, 0)
    s.camera = cam
    return s


def decal(name, shape_pts, mat, target, z_off=0.004):
    """Plaque plane (contour 2D dans le plan XZ) collée sur la tête par shrinkwrap."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -2.0, z)) for x, z in shape_pts]
    bm.faces.new(vs)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    ob = _mesh_obj(name, bm, mat)
    sw = ob.modifiers.new('sw', 'SHRINKWRAP')
    sw.target = target
    sw.wrap_method = 'PROJECT'
    sw.use_project_y = True
    sw.use_negative_direction = True
    sw.use_positive_direction = True
    sw.offset = z_off
    return ob


def ellipse(cx, cz, rx, rz, n=40, a0=0.0, a1=2 * math.pi):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * k / n), cz + rz * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)][:-1] \
        if a1 - a0 >= 2 * math.pi - 1e-6 else \
        [(cx + rx * math.cos(a0 + (a1 - a0) * k / n), cz + rz * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]


def kid(name, skin, hair, style, acc, shirt):
    sk = _bsdf('Skin', skin, rough=0.45, sss=0.15)
    hr = _bsdf('Hair', tuple(c * 0.55 for c in hair[:3]) + (1,), rough=0.45, coat=0.3)
    sh = _bsdf('Shirt', shirt, rough=0.6)
    white = _bsdf('White', (1, 1, 1, 1), rough=0.2, coat=1.0)
    iris = _bsdf('Iris', (0.35, 0.18, 0.06, 1), rough=0.2, coat=1.0)
    black = _bsdf('Black', (0.02, 0.015, 0.015, 1), rough=0.1, coat=1.0)
    hl = _bsdf('HL', (1, 1, 1, 1), emit=(1, 1, 1, 1), emit_strength=2.0)
    mouth = _bsdf('Mouth', (0.45, 0.06, 0.08, 1), rough=0.5)
    tongue = _bsdf('Tongue', (0.95, 0.4, 0.42, 1), rough=0.4)
    teeth = _bsdf('Teeth', (1, 1, 1, 1), rough=0.3)
    blush = _bsdf('Blush', (1.0, 0.5, 0.5, 1), rough=0.6)
    head = _sphere('Head', 0.78, 64, 48, sk, None, (1.0, 0.95, 1.0))
    head.location = (0, 0, 0.15)
    for s in (-1, 1):
        _sphere('Ear', 0.16, 24, 16, sk, None, (0.7, 1, 1)).location = (s * 0.76, 0.05, 0.12)
    body = _sphere('Torso', 1, 48, 32, sh, None, (0.82, 0.55, 0.55))
    body.location = (0, 0.15, -0.92)
    _sphere('Neck', 0.24, 24, 16, sk, None, (1, 1, 1.2)).location = (0, 0.05, -0.55)
    # yeux en relief
    for s in (-1, 1):
        e = _sphere('Eye', 1, 32, 24, white, None, (0.17, 0.08, 0.21))
        e.location = (s * 0.27, -0.7, 0.2)
        i = _sphere('Iris', 1, 24, 16, iris, None, (0.12, 0.05, 0.14))
        i.location = (s * 0.27 + 0.01, -0.765, 0.18)
        p = _sphere('Pupil', 1, 24, 16, black, None, (0.07, 0.04, 0.08))
        p.location = (s * 0.27 + 0.01, -0.79, 0.18)
        h = _sphere('HL', 0.032, 12, 8, hl)
        h.location = (s * 0.27 + 0.05, -0.81, 0.24)
        # sourcils
        bm = bmesh.new()
        prev = None
        cu = bpy.data.curves.new('Brow', 'CURVE')
        cu.dimensions = '3D'
        cu.bevel_depth = 0.03
        sp = cu.splines.new('BEZIER')
        sp.bezier_points.add(2)
        for bp, (x, z) in zip(sp.bezier_points, ((-0.13, 0.42), (0.0, 0.47), (0.13, 0.44))):
            bp.co = (s * 0.27 + x * (1 if s > 0 else -1) * -1, -0.72, z)
            bp.handle_left_type = bp.handle_right_type = 'AUTO'
        ob = bpy.data.objects.new('Brow', cu)
        bpy.context.scene.collection.objects.link(ob)
        ob.data.materials.append(hr)
    _sphere('Nose', 0.075, 16, 12, sk, None, (1, 1, 0.8)).location = (0, -0.78, 0.02)
    # bouche ouverte souriante + dents + langue (plaques collées)
    m_pts = ellipse(0, -0.2, 0.24, 0.17, 40, math.pi, 2 * math.pi) + [(0.24, -0.17), (-0.24, -0.17)]
    decal('Mouth', m_pts, mouth, head, 0.003)
    decal('Teeth', [(-0.2, -0.17), (0.2, -0.17), (0.17, -0.24), (-0.17, -0.24)], teeth, head, 0.006)
    decal('Tongue', ellipse(0.02, -0.33, 0.12, 0.06, 24), tongue, head, 0.006)
    for s in (-1, 1):
        decal('Blush', ellipse(s * 0.45, -0.07, 0.1, 0.06, 24), blush, head, 0.003)
    # cheveux
    rnd = random.Random(name)
    cap = _sphere('HairCap', 0.83, 64, 48, hr, None, (1.03, 1.0, 1.02))
    cap.location = (0, 0.04, 0.2)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    # garde le dessus et l'arrière ; dégage le visage
    kill = [v for v in bm.verts if (v.co.y < -0.25 and v.co.z < 0.35) or v.co.z < -0.25]
    bmesh.ops.delete(bm, geom=kill, context='VERTS')
    bm.to_mesh(cap.data)
    cap.modifiers.new('sol', 'SOLIDIFY').thickness = 0.04
    # frange
    for k in range(7):
        x = -0.5 + k * 0.165
        f = _sphere('Fringe', 1, 20, 14, hr, None, (0.16, 0.12, 0.12 + rnd.uniform(0, 0.04)))
        f.location = (x, -0.6 + abs(x) * 0.35, 0.62 - abs(x) * 0.25)
        f.rotation_euler = (0.3, 0, -x * 0.8)
    if style == 'curly':
        for k in range(26):
            a = rnd.uniform(-math.pi * 0.95, math.pi * 0.95)
            el = rnd.uniform(0.15, 1.2)
            d = Vector((math.sin(a) * math.cos(el), math.cos(a) * math.cos(el) * 0.9 + 0.1, math.sin(el)))
            if d.y < -0.4 and d.z < 0.6:
                continue
            _sphere('Curl', 0.17, 16, 12, hr).location = Vector((0, 0.04, 0.2)) + d * 0.8
    if style == 'short':
        for k in range(10):
            a = rnd.uniform(-1.2, 1.2)
            _sphere('Tuft', 1, 16, 12, hr, None, (0.18, 0.18, 0.12)).location = (math.sin(a) * 0.6, 0.1 + math.cos(a) * 0.3, 0.82)
    acc_m = _bsdf('Acc', acc, rough=0.4, coat=0.6) if acc else None
    if style == 'pigtails':
        for s in (-1, 1):
            _sphere('Tail', 1, 32, 24, hr, None, (0.22, 0.22, 0.3)).location = (s * 0.95, 0.15, -0.15)
            _sphere('Tie', 0.1, 16, 12, acc_m).location = (s * 0.82, 0.12, 0.08)
    if style == 'buns':
        for s in (-1, 1):
            _sphere('Bun', 0.24, 32, 24, hr).location = (s * 0.62, 0.2, 0.78)
            _sphere('Tie', 0.09, 16, 12, acc_m).location = (s * 0.52, 0.0, 0.62)
    if style == 'side':
        for s in (-1, 1):
            _sphere('Tail', 1, 32, 24, hr, None, (0.24, 0.24, 0.34)).location = (s * 0.9, 0.2, -0.35)
            _sphere('Tie', 0.1, 16, 12, acc_m).location = (s * 0.85, 0.05, -0.05)


def main():
    out = sys.argv[1]
    samples = int(sys.argv[2]) if len(sys.argv) > 2 else 48
    res = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    os.makedirs(out, exist_ok=True)
    for k in KIDS:
        s = scene(res, samples)
        kid(*k)
        s.render.filepath = os.path.join(out, f'avatar_{k[0]}.png')
        bpy.ops.render.render(write_still=True)
        print(k[0], flush=True)


if __name__ == '__main__':
    main()
