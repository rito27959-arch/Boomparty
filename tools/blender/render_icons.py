"""Icônes 3D HD (catégories, trophée, médailles, gemme) rendues dans Blender,
même éclairage cartoon que la bombe.

    python render_icons.py <assets/illustrations> [noms] [samples]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402  (doit précéder bmesh)
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

from bomb_rig import _bsdf, _cylinder, _empty, _mesh_obj, _sphere  # noqa: E402


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
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.9, 0.85, 0.85, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.35
    s.world = w
    for name, loc, e, col, size in (('Key', (2.5, -5, 5), 600, (1, 0.95, 0.9), 4), ('Rim', (-4, 2, 2), 300, (0.7, 0.8, 1), 3),
                                    ('Fill', (0, -6, -1), 80, (1, 0.9, 0.9), 6)):
        ld = bpy.data.lights.new(name, 'AREA')
        ld.energy, ld.color, ld.size = e, col, size
        ob = bpy.data.objects.new(name, ld)
        s.collection.objects.link(ob)
        ob.location = loc
        ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cd = bpy.data.cameras.new('C')
    cd.type = 'ORTHO'
    cd.ortho_scale = 2.4
    cam = bpy.data.objects.new('C', cd)
    s.collection.objects.link(cam)
    cam.location = (0, -10, 2.2)
    cam.rotation_euler = (math.radians(77), 0, 0)
    s.camera = cam
    return s


def rbox(name, size, radius, mat, parent=None, loc=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = _mesh_obj(name, bm, mat, parent, smooth=False)
    mod = ob.modifiers.new('bev', 'BEVEL')
    mod.width = radius
    mod.segments = 6
    ob.location = loc
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.modifiers.new('ws', 'WEIGHTED_NORMAL')
    return ob


def star_mesh(name, r_out, r_in, depth, mat, n=5):
    bm = bmesh.new()
    top, bot = [], []
    for k in range(n * 2):
        a = math.pi / 2 + k * math.pi / n
        r = r_out if k % 2 == 0 else r_in
        top.append(bm.verts.new((math.cos(a) * r, 0, math.sin(a) * r)))
    c_f = bm.verts.new((0, -depth, 0))
    c_b = bm.verts.new((0, depth * 0.6, 0))
    for k in range(n * 2):
        bm.faces.new((c_f, top[k], top[(k + 1) % (n * 2)]))
        bm.faces.new((c_b, top[(k + 1) % (n * 2)], top[k]))
    ob = _mesh_obj(name, bm, mat, smooth=False)
    ob.modifiers.new('bev', 'BEVEL').width = 0.03
    return ob


def tube(name, pts, r, mat):
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = r
    cu.bevel_resolution = 6
    cu.use_fill_caps = True
    sp = cu.splines.new('BEZIER')
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


# ------------------------------------------------------------------ icônes
def paw():
    m = _bsdf('Paw', (1.0, 0.55, 0.85, 1), rough=0.3, coat=1.0)
    rim = _bsdf('PawRim', (0.55, 0.15, 0.75, 1), rough=0.3, coat=1.0)
    pad = _sphere('Pad', 1, 48, 32, m, None, (0.48, 0.25, 0.4))
    pad.location = (0, 0, -0.3)
    _sphere('PadRim', 1, 48, 32, rim, None, (0.52, 0.22, 0.44)).location = (0, 0.04, -0.3)
    for x, z, s in ((-0.55, 0.15, 0.2), (-0.22, 0.48, 0.22), (0.22, 0.48, 0.22), (0.55, 0.15, 0.2)):
        _sphere('Toe', 1, 32, 24, m, None, (s, 0.2, s * 1.15)).location = (x, 0, z)
        _sphere('ToeRim', 1, 32, 24, rim, None, (s * 1.12, 0.17, s * 1.27)).location = (x, 0.04, z)


def _pattern_mat(name, col_a, col_b, kind, scale, lo, hi, rough=0.25):
    """Matière à deux couleurs pilotée par une texture procédurale (bruit ou Voronoï)."""
    m = _bsdf(name, col_a, rough=rough, coat=1.0)
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    if kind == 'noise':
        tex = nt.nodes.new('ShaderNodeTexNoise')
        tex.inputs['Scale'].default_value = scale
        tex.inputs['Detail'].default_value = 4.0
        fac = tex.outputs['Fac']
    else:
        tex = nt.nodes.new('ShaderNodeTexVoronoi')
        tex.inputs['Scale'].default_value = scale
        fac = tex.outputs['Distance']
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    e0, e1 = ramp.color_ramp.elements
    e0.position, e0.color = lo, col_b
    e1.position, e1.color = hi, col_a
    nt.links.new(fac, ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], p.inputs['Base Color'])
    return m


def globe():
    m = _pattern_mat('Globe', (0.1, 0.5, 1.0, 1), (0.25, 0.78, 0.3, 1), 'noise', 1.6, 0.43, 0.46)
    _sphere('Globe', 0.85, 64, 48, m).location = (0, 0, 0.05)


def box():
    m = _bsdf('Box', (1.0, 0.62, 0.15, 1), rough=0.45)
    d = _bsdf('BoxD', (0.85, 0.42, 0.05, 1), rough=0.5)
    b = rbox('Box', (1.2, 1.0, 0.85), 0.06, m, None, (0, 0, -0.2))
    b.rotation_euler = (0, 0, math.radians(-30))
    for side, rot in ((-1, 0.6), (1, -0.6)):
        f = rbox('Flap', (0.6, 1.0, 0.05), 0.02, d)
        f.parent = b
        f.location = (side * 0.55, 0, 0.5)
        f.rotation_euler = (0, side * -rot, 0)
    tape = _bsdf('Tape', (0.95, 0.85, 0.55, 1), rough=0.3)
    t = rbox('Tape', (0.15, 1.02, 0.87), 0.01, tape)
    t.parent = b


def burger():
    bun = _bsdf('Bun', (0.95, 0.6, 0.2, 1), rough=0.45, coat=0.4)
    meat = _bsdf('Meat', (0.35, 0.15, 0.06, 1), rough=0.7)
    salad = _bsdf('Salad', (0.35, 0.8, 0.15, 1), rough=0.5)
    cheese = _bsdf('Cheese', (1.0, 0.78, 0.1, 1), rough=0.3)
    tomato = _bsdf('Tomato', (0.9, 0.15, 0.1, 1), rough=0.3, coat=0.5)
    seed = _bsdf('Seed', (1, 0.95, 0.8, 1), rough=0.4)
    _sphere('BunBot', 1, 48, 24, bun, None, (0.85, 0.85, 0.22)).location = (0, 0, -0.55)
    _sphere('Meat', 1, 48, 24, meat, None, (0.88, 0.88, 0.16)).location = (0, 0, -0.32)
    rbox('Cheese', (1.5, 1.5, 0.05), 0.02, cheese, None, (0, 0, -0.16)).rotation_euler = (0, 0, 0.78)
    _sphere('Tomato', 1, 48, 16, tomato, None, (0.8, 0.8, 0.07)).location = (0, 0, -0.09)
    sal = _sphere('Salad', 1, 64, 16, salad, None, (0.95, 0.95, 0.07))
    sal.location = (0, 0, -0.02)
    w = sal.modifiers.new('w', 'WAVE')
    w.height, w.width, w.narrowness = 0.05, 0.25, 1.0
    top = _sphere('BunTop', 1, 64, 32, bun, None, (0.86, 0.86, 0.62))
    top.location = (0, 0, 0.0)
    bm = bmesh.new()
    bm.from_mesh(top.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0], context='VERTS')
    bm.to_mesh(top.data)
    import random
    rnd = random.Random(2)
    for k in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.1, 0.65)
        z = 0.62 * math.sqrt(max(0, 1 - (r / 0.86) ** 2))
        s = _sphere('Seed', 1, 12, 8, seed, None, (0.05, 0.03, 0.025))
        s.location = (math.cos(a) * r, math.sin(a) * r - 0.0, z)
        s.rotation_euler = (0, 0, a)


def briefcase():
    m = _bsdf('Case', (0.15, 0.45, 1.0, 1), rough=0.3, coat=1.0)
    d = _bsdf('CaseD', (0.08, 0.25, 0.7, 1), rough=0.3, coat=1.0)
    clasp = _bsdf('Clasp', (1, 1, 1, 1), rough=0.2, emit=(1, 1, 1, 1), emit_strength=0.3)
    rbox('Case', (1.5, 0.6, 1.05), 0.12, m, None, (0, 0, -0.25))
    rbox('Band', (1.52, 0.62, 0.08), 0.03, d, None, (0, 0, -0.05))
    tube('Handle', [Vector((-0.3, 0, 0.27)), Vector((-0.25, 0, 0.55)), Vector((0.25, 0, 0.55)), Vector((0.3, 0, 0.27))], 0.07, d)
    _sphere('Clasp', 1, 24, 16, clasp, None, (0.1, 0.05, 0.1)).location = (0, -0.31, -0.05)


def ball():
    m = _pattern_mat('Ball', (0.96, 0.96, 0.96, 1), (0.03, 0.03, 0.04, 1), 'voronoi', 3.0, 0.3, 0.32, rough=0.3)
    _sphere('Ball', 0.85, 64, 48, m)


def clapper():
    m = _bsdf('Clap', (0.55, 0.2, 0.9, 1), rough=0.35, coat=1.0)
    k = _bsdf('ClapK', (0.1, 0.06, 0.15, 1), rough=0.35, coat=1.0)
    w = _bsdf('ClapW', (1, 1, 1, 1), rough=0.3)
    rbox('Board', (1.4, 0.35, 0.95), 0.08, m, None, (0, 0, -0.35))
    top = _empty('Top', None, (-0.7, 0, 0.2))
    top.rotation_euler = (0, math.radians(-18), 0)
    b = rbox('Stick', (1.42, 0.3, 0.25), 0.03, k, top, (0.71, 0, 0.12))
    for i in range(4):
        s = rbox('Stripe', (0.16, 0.31, 0.26), 0.01, w, top, (0.25 + i * 0.32, 0, 0.12))
        s.rotation_euler = (0, 0.45, 0)
    rbox('Stick2', (1.42, 0.3, 0.2), 0.03, k, None, (0, 0, 0.18))
    for i in range(2):
        rbox('Line', (0.4, 0.36, 0.06), 0.02, w, None, (0, 0, -0.3 - i * 0.18))


def note():
    m = _bsdf('Note', (1.0, 0.5, 0.85, 1), rough=0.3, coat=1.0)
    _sphere('H1', 1, 48, 32, m, None, (0.32, 0.22, 0.25)).location = (-0.42, 0, -0.55)
    _sphere('H2', 1, 48, 32, m, None, (0.32, 0.22, 0.25)).location = (0.45, 0, -0.35)
    rbox('S1', (0.1, 0.12, 1.15), 0.04, m, None, (-0.17, 0, 0.0))
    rbox('S2', (0.1, 0.12, 1.15), 0.04, m, None, (0.7, 0, 0.2))
    beam = rbox('Beam', (0.98, 0.14, 0.24), 0.04, m, None, (0.27, 0, 0.66))
    beam.rotation_euler = (0, -0.2, 0)


def car():
    red = _bsdf('Car', (0.95, 0.15, 0.12, 1), rough=0.25, coat=1.0)
    glass = _bsdf('Glass', (0.55, 0.85, 1.0, 1), rough=0.1, coat=1.0)
    tire = _bsdf('Tire', (0.07, 0.07, 0.08, 1), rough=0.6)
    hub = _bsdf('Hub', (0.85, 0.85, 0.9, 1), metallic=1.0, rough=0.3)
    light = _bsdf('Light', (1, 0.9, 0.5, 1), emit=(1, 0.9, 0.5, 1), emit_strength=1.0)
    rbox('Body', (1.7, 0.85, 0.5), 0.2, red, None, (0, 0, -0.35))
    rbox('Cabin', (1.0, 0.75, 0.55), 0.25, red, None, (-0.05, 0, 0.05))
    rbox('Win1', (0.38, 0.77, 0.32), 0.08, glass, None, (-0.28, 0, 0.1))
    rbox('Win2', (0.38, 0.77, 0.32), 0.08, glass, None, (0.2, 0, 0.1))
    for x in (-0.55, 0.55):
        t = _cylinder('Tire', 0.27, 0.27, 0.22, 32, tire)
        t.rotation_euler = (math.radians(90), 0, 0)
        t.location = (x, -0.35, -0.6)
        h = _cylinder('Hub', 0.12, 0.12, 0.24, 24, hub)
        h.rotation_euler = (math.radians(90), 0, 0)
        h.location = (x, -0.36, -0.6)
    _sphere('Lamp', 1, 16, 12, light, None, (0.08, 0.05, 0.07)).location = (0.84, -0.3, -0.3)


def star():
    m = _bsdf('StarM', (1.0, 0.78, 0.1, 1), rough=0.25, coat=1.0)
    s = star_mesh('Star', 0.95, 0.42, 0.28, m)
    s.location = (0, 0, -0.05)


def trophy():
    g = _bsdf('Gold', (1.0, 0.72, 0.1, 1), metallic=1.0, rough=0.22)
    base = _bsdf('Base', (0.85, 0.5, 0.08, 1), metallic=1.0, rough=0.3)
    cup = _sphere('Cup', 1, 64, 32, g, None, (0.6, 0.6, 0.62))
    cup.location = (0, 0, 0.2)
    bm = bmesh.new()
    bm.from_mesh(cup.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.3], context='VERTS')
    bm.to_mesh(cup.data)
    cup.modifiers.new('sol', 'SOLIDIFY').thickness = 0.04
    _cylinder('Rim', 0.62, 0.62, 0.06, 64, g).location = (0, 0, 0.4)
    _cylinder('Stem', 0.08, 0.14, 0.4, 32, g).location = (0, 0, -0.5)
    rbox('Base', (0.8, 0.6, 0.22), 0.05, base, None, (0, 0, -0.8))
    for s in (-1, 1):
        tube('Handle', [Vector((s * 0.55, 0, 0.3)), Vector((s * 0.9, 0, 0.3)), Vector((s * 0.85, 0, -0.05)), Vector((s * 0.4, 0, -0.2))], 0.06, g)


def medal(n):
    cols = {1: ((1.0, 0.75, 0.15, 1), (0.25, 0.45, 0.95, 1)), 2: ((0.85, 0.87, 0.92, 1), (0.9, 0.3, 0.5, 1)),
            3: ((0.9, 0.5, 0.2, 1), (0.9, 0.3, 0.5, 1))}[n]
    m = _bsdf('Medal', cols[0], metallic=1.0, rough=0.25)
    rib = _bsdf('Rib', cols[1], rough=0.5)
    for s in (-1, 1):
        r = rbox('Ribbon', (0.32, 0.05, 0.75), 0.02, rib, None, (s * 0.25, 0.1, -0.55))
        r.rotation_euler = (0, s * 0.35, 0)
    d = _cylinder('Disc', 0.62, 0.62, 0.14, 64, m)
    d.rotation_euler = (math.radians(90), 0, 0)
    d.location = (0, 0, 0.1)
    d.modifiers.new('bev', 'BEVEL').width = 0.04
    txt = bpy.data.curves.new('T', 'FONT')
    txt.body = str(n)
    txt.size = 0.75
    txt.extrude = 0.04
    txt.align_x = 'CENTER'
    txt.align_y = 'CENTER'
    ob = bpy.data.objects.new('Num', txt)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(_bsdf('Num', (0.45, 0.25, 0.05, 1) if n != 2 else (0.35, 0.36, 0.45, 1), rough=0.3))
    ob.rotation_euler = (math.radians(90), 0, 0)
    ob.location = (0, -0.1, 0.1)


def gem():
    m = _bsdf('Gem', (0.3, 0.8, 1.0, 1), rough=0.05, coat=1.0, emit=(0.2, 0.6, 1.0, 1), emit_strength=0.25)
    bm = bmesh.new()
    n = 8
    top = [bm.verts.new((math.cos(k * 2 * math.pi / n) * 0.5, math.sin(k * 2 * math.pi / n) * 0.5, 0.3)) for k in range(n)]
    mid = [bm.verts.new((math.cos((k + 0.5) * 2 * math.pi / n) * 0.85, math.sin((k + 0.5) * 2 * math.pi / n) * 0.85, 0.05)) for k in range(n)]
    tip = bm.verts.new((0, 0, -0.85))
    bm.faces.new(top)
    for k in range(n):
        bm.faces.new((top[k], mid[k], top[(k + 1) % n]))
        bm.faces.new((top[(k + 1) % n], mid[k], mid[(k + 1) % n]))
        bm.faces.new((mid[k], tip, mid[(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _mesh_obj('Gem', bm, m, smooth=False)
    ob.rotation_euler = (0.35, 0, 0.2)


def hearts():
    back = _bsdf('HeartB', (0.65, 0.4, 1.0, 1), rough=0.25, coat=1.0)
    front = _bsdf('HeartF', (1.0, 0.25, 0.35, 1), rough=0.25, coat=1.0)

    def heart(name, mat, s, loc):
        root = _empty(name, None, loc)
        for side in (-1, 1):
            b = _sphere('Lobe', 1, 32, 24, mat, root, (0.33 * s, 0.22 * s, 0.33 * s))
            b.location = (side * 0.22 * s, 0, 0.12 * s)
        bm = bmesh.new()
        pts = [Vector((-0.5 * s, 0, 0.08 * s)), Vector((0.5 * s, 0, 0.08 * s)), Vector((0, 0, -0.6 * s))]
        top_f = [bm.verts.new(p + Vector((0, -0.2 * s, 0))) for p in pts]
        top_b = [bm.verts.new(p + Vector((0, 0.2 * s, 0))) for p in pts]
        bm.faces.new(top_f)
        bm.faces.new(list(reversed(top_b)))
        for k in range(3):
            bm.faces.new((top_f[k], top_b[k], top_b[(k + 1) % 3], top_f[(k + 1) % 3]))
        ob = _mesh_obj('Tip', bm, mat, root, smooth=False)
        ob.modifiers.new('sub', 'SUBSURF').levels = 2
        return root
    heart('Back', back, 0.85, (-0.3, 0.3, 0.25))
    heart('Front', front, 1.0, (0.2, -0.2, -0.15))


def bolt(top, bot):
    m = _bsdf('Bolt', top, rough=0.25, coat=1.0, emit=bot, emit_strength=0.25)
    pts = [(0.15, 0.95), (-0.5, -0.05), (-0.05, -0.05), (-0.25, -0.95), (0.5, 0.1), (0.05, 0.1)]
    bm = bmesh.new()
    f = [bm.verts.new((x, -0.15, z)) for x, z in pts]
    b = [bm.verts.new((x, 0.15, z)) for x, z in pts]
    bm.faces.new(f)
    bm.faces.new(list(reversed(b)))
    n = len(pts)
    for k in range(n):
        bm.faces.new((f[k], b[k], b[(k + 1) % n], f[(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _mesh_obj('Bolt', bm, m, smooth=False)
    ob.modifiers.new('bev', 'BEVEL').width = 0.05


def crown_icon():
    g = _bsdf('Gold', (1.0, 0.72, 0.1, 1), metallic=1.0, rough=0.22)
    gem = _bsdf('Ruby', (0.9, 0.05, 0.1, 1), rough=0.1, coat=1.0, emit=(0.6, 0.0, 0.05, 1), emit_strength=0.3)
    bm = bmesh.new()
    n = 10
    bot, top = [], []
    for k in range(n * 2):
        a = k * math.pi / n
        bot.append(bm.verts.new((math.cos(a) * 0.75, math.sin(a) * 0.75, -0.45)))
        h = 0.55 if k % 4 == 0 else (0.15 if k % 2 == 0 else 0.1)
        top.append(bm.verts.new((math.cos(a) * 0.82, math.sin(a) * 0.82, h)))
    for k in range(n * 2):
        bm.faces.new((bot[k], bot[(k + 1) % (n * 2)], top[(k + 1) % (n * 2)], top[k]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.08)
    ob = _mesh_obj('Crown', bm, g, smooth=False)
    ob.modifiers.new('bev', 'BEVEL').width = 0.02
    for k in range(5):
        a = -math.pi / 2 + (k - 2) * 0.55
        _sphere('Gem', 0.09, 16, 12, gem).location = (math.cos(a) * 0.8, math.sin(a) * 0.8, -0.15)
    for k in range(5):
        a = k * 2 * math.pi / 5
        _sphere('Ball', 0.07, 16, 12, g).location = (math.cos(a) * 0.82, math.sin(a) * 0.82, 0.6)


ICONS = {
    'icon_hearts': hearts, 'icon_bolt': lambda: bolt((1.0, 0.85, 0.15, 1), (1.0, 0.6, 0.0, 1)),
    'icon_bolt_purple': lambda: bolt((0.85, 0.75, 1.0, 1), (0.6, 0.4, 1.0, 1)), 'crown': crown_icon,
    'cat_animaux': paw, 'cat_pays': globe, 'cat_objets': box, 'cat_nourriture': burger, 'cat_metiers': briefcase,
    'cat_sports': ball, 'cat_films': clapper, 'cat_musique': note, 'cat_vehicules': car, 'cat_autres': star,
    'trophy': trophy, 'medal_1': lambda: medal(1), 'medal_2': lambda: medal(2), 'medal_3': lambda: medal(3),
    'gem': gem,
}


def main():
    out = sys.argv[1]
    names = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] != 'all' else list(ICONS)
    samples = int(sys.argv[3]) if len(sys.argv) > 3 else 48
    res = int(sys.argv[4]) if len(sys.argv) > 4 else 384
    os.makedirs(out, exist_ok=True)
    for n in names:
        s = scene(res, samples)
        ICONS[n]()
        s.render.filepath = os.path.join(out, f'{n}.png')
        bpy.ops.render.render(write_still=True)
        print(n, flush=True)


if __name__ == '__main__':
    main()
