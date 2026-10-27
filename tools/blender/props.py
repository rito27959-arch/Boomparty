"""Accessoires et variantes de matière pour la bombe (skins, mascottes)."""
import math

import bpy  # doit précéder bmesh
import bmesh
from mathutils import Vector

from bomb_rig import BODY_SCALE, _bsdf, _cylinder, _empty, _mesh_obj, _sphere


# ------------------------------------------------------------ skins (matière)
def set_body_skin(rig, skin):
    """Modifie la matière du corps (et des chaussures/bras/capuchon qui la partagent)."""
    p = rig.mat['body'].node_tree.nodes['Principled BSDF']
    nt = rig.mat['body'].node_tree
    mix = next(n for n in nt.nodes if n.type == 'MIX')
    defaults = dict(color=(0.010, 0.008, 0.016, 1), metallic=0.0, rough=0.38, emit=(0, 0, 0, 1), emit_s=0.0,
                    transmission=0.0, coat=1.0)
    cfg = {
        'classique': {},
        'glace': dict(color=(0.35, 0.75, 1.0, 1), rough=0.12, transmission=0.35, emit=(0.2, 0.55, 1.0, 1), emit_s=0.15),
        'ninja': dict(color=(0.02, 0.02, 0.03, 1), rough=0.6, coat=0.2),
        'citrouille': dict(color=(1.0, 0.33, 0.02, 1), rough=0.45),
        'arc': dict(color=(1.0, 0.4, 0.8, 1), rough=0.25),
        'galaxie': dict(color=(0.18, 0.05, 0.45, 1), rough=0.3, emit=(0.25, 0.08, 0.6, 1), emit_s=0.25),
        'acier': dict(color=(0.55, 0.57, 0.62, 1), metallic=1.0, rough=0.28),
        'bonbon': dict(color=(1.0, 0.45, 0.72, 1), rough=0.2),
        'lave': dict(color=(0.05, 0.02, 0.02, 1), rough=0.55, emit=(1.0, 0.25, 0.0, 1), emit_s=0.0),
        'diable': dict(color=(0.22, 0.05, 0.55, 1), rough=0.3),
        'robot': dict(color=(0.5, 0.52, 0.6, 1), metallic=1.0, rough=0.3),
        'serieuse': dict(color=(0.28, 0.27, 0.32, 1), rough=0.35),
        'drole': dict(color=(0.75, 0.1, 0.12, 1), rough=0.3),
    }[skin]
    c = {**defaults, **cfg}
    mix.inputs['A'].default_value = c['color']
    p.inputs['Metallic'].default_value = c['metallic']
    p.inputs['Emission Color'].default_value = c['emit']
    p.inputs['Emission Strength'].default_value = c['emit_s']
    p.inputs['Transmission Weight'].default_value = c['transmission']
    p.inputs['Coat Weight'].default_value = c['coat']
    # rugosité : le nœud 'rough' (MULTIPLY_ADD) pilote la valeur de base
    for n in nt.nodes:
        if n.type == 'MATH' and n.operation == 'MULTIPLY_ADD':
            n.inputs[2].default_value = c['rough']
    _special_patterns(rig, skin)


def _special_patterns(rig, skin):
    """Motifs procéduraux : arc-en-ciel, étoiles de galaxie, fissures de lave."""
    nt = rig.mat['body'].node_tree
    p = nt.nodes['Principled BSDF']
    for n in list(nt.nodes):
        if n.name.startswith('skinfx'):
            nt.nodes.remove(n)
    mix = next(n for n in nt.nodes if n.type == 'MIX')
    if skin == 'arc':
        tc = nt.nodes.new('ShaderNodeTexCoord'); tc.name = 'skinfx_tc'
        sep = nt.nodes.new('ShaderNodeSeparateXYZ'); sep.name = 'skinfx_sep'
        ramp = nt.nodes.new('ShaderNodeValToRGB'); ramp.name = 'skinfx_ramp'
        cols = [(1, 0.2, 0.3, 1), (1, 0.6, 0.1, 1), (1, 0.95, 0.2, 1), (0.3, 0.9, 0.4, 1), (0.2, 0.6, 1, 1), (0.6, 0.3, 1, 1)]
        ramp.color_ramp.elements[0].color = cols[0]
        ramp.color_ramp.elements[1].color = cols[-1]
        for i, col in enumerate(cols[1:-1], 1):
            e = ramp.color_ramp.elements.new(i / (len(cols) - 1))
            e.color = col
        mr = nt.nodes.new('ShaderNodeMapRange'); mr.name = 'skinfx_mr'
        mr.inputs['From Min'].default_value = -1.0
        mr.inputs['From Max'].default_value = 1.0
        nt.links.new(tc.outputs['Object'], sep.inputs[0])
        nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
        nt.links.new(mr.outputs['Result'], ramp.inputs['Fac'])
        nt.links.new(ramp.outputs['Color'], mix.inputs['A'])
    elif skin in ('galaxie', 'lave'):
        vor = nt.nodes.new('ShaderNodeTexVoronoi'); vor.name = 'skinfx_vor'
        vor.inputs['Scale'].default_value = 26.0 if skin == 'galaxie' else 5.0
        if skin == 'lave':
            vor.feature = 'DISTANCE_TO_EDGE'
        ramp = nt.nodes.new('ShaderNodeValToRGB'); ramp.name = 'skinfx_ramp'
        e0, e1 = ramp.color_ramp.elements
        if skin == 'galaxie':
            e0.position, e0.color = 0.0, (1, 1, 1, 1)
            e1.position, e1.color = 0.06, (0, 0, 0, 1)
            src = vor.outputs['Distance']
        else:
            e0.position, e0.color = 0.0, (1, 0.35, 0.0, 1)
            e1.position, e1.color = 0.05, (0, 0, 0, 1)
            src = vor.outputs['Distance']
        nt.links.new(src, ramp.inputs['Fac'])
        nt.links.new(ramp.outputs['Color'], p.inputs['Emission Color'])
        p.inputs['Emission Strength'].default_value = 3.0 if skin == 'galaxie' else 2.5
    else:
        # recâble l'émission en couleur fixe
        for l in list(p.inputs['Emission Color'].links):
            nt.links.remove(l)
        for l in list(mix.inputs['A'].links):
            nt.links.remove(l)


# ------------------------------------------------------------ accessoires
def crown(rig, scale=1.0, tilt=0.25):
    m = _bsdf('Gold', (1.0, 0.72, 0.1, 1), metallic=1.0, rough=0.25)
    gem = _bsdf('Ruby', (0.9, 0.05, 0.1, 1), rough=0.1, coat=1.0, emit=(0.6, 0.0, 0.05, 1), emit_strength=0.3)
    root = _empty('Crown', rig.bodyc, (-0.38, -0.1, BODY_SCALE.z * 0.92))
    root.rotation_euler = (0.15, -tilt, 0)
    root.scale = (scale, scale, scale)
    bm = bmesh.new()
    n = 10
    bot, top = [], []
    for k in range(n * 2):
        a = k * math.pi / n
        r = 0.32
        bot.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0)))
        h = 0.36 if k % 4 == 0 else (0.18 if k % 2 == 0 else 0.14)
        top.append(bm.verts.new((math.cos(a) * r * 1.08, math.sin(a) * r * 1.08, h)))
    for k in range(n * 2):
        bm.faces.new((bot[k], bot[(k + 1) % (n * 2)], top[(k + 1) % (n * 2)], top[k]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.04)
    _mesh_obj('CrownMesh', bm, m, root, smooth=False)
    for k in range(5):
        a = k * 2 * math.pi / 5
        g = _sphere('Gem', 0.045, 16, 12, gem, root)
        g.location = (math.cos(a) * 0.35, math.sin(a) * 0.35, 0.09)
    return root


def horns(rig):
    m = _bsdf('Horn', (0.35, 0.08, 0.6, 1), rough=0.3, coat=1.0)
    out = []
    for side in (-1, 1):
        bm = bmesh.new()
        prev = None
        rings = []
        for i in range(9):
            t = i / 8
            r = 0.13 * (1 - t) + 0.008
            c = Vector((side * (0.1 + 0.18 * t * t), 0, 0.42 * t))
            ring = [bm.verts.new(c + Vector((math.cos(a) * r, math.sin(a) * r, 0))) for a in [j * math.pi / 8 for j in range(16)]]
            rings.append(ring)
        for r0, r1 in zip(rings, rings[1:]):
            for j in range(16):
                bm.faces.new((r0[j], r0[(j + 1) % 16], r1[(j + 1) % 16], r1[j]))
        ob = _mesh_obj('Horn', bm, m, rig.bodyc)
        ob.location = (side * 0.45, 0.05, BODY_SCALE.z * 0.78)
        ob.rotation_euler = (0, side * -0.35, 0)
        out.append(ob)
    return out


def headband(rig, color=(0.85, 0.05, 0.08, 1)):
    m = _bsdf('Band', color, rough=0.5)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=64, radius1=1.0, radius2=1.0, depth=0.16)
    ob = _mesh_obj('Headband', bm, m, rig.bodyc)
    ob.scale = (1.02, 0.97, 1.0)
    ob.location = (0, 0, 0.62)
    parts = [ob]
    # nœud et pans à l'arrière droit
    for k, (dx, dz, rz) in enumerate(((0.0, 0.0, 0.0), (0.12, -0.12, -0.5), (0.18, -0.02, 0.4))):
        t = _sphere('Knot', 1.0, 16, 12, m, rig.bodyc, (0.1, 0.06, 0.06) if k == 0 else (0.18, 0.03, 0.06))
        t.location = (0.85 + dx, 0.45, 0.62 + dz)
        t.rotation_euler = (0, rz, 0)
        parts.append(t)
    return parts


def pumpkin_stem(rig):
    m = _bsdf('Stem', (0.2, 0.45, 0.1, 1), rough=0.6)
    st = _cylinder('Stem', 0.06, 0.09, 0.3, 12, m, rig.bodyc)
    st.location = (-0.3, 0.1, BODY_SCALE.z + 0.05)
    st.rotation_euler = (0, -0.4, 0)
    leaf = _sphere('Leaf', 1.0, 16, 8, m, rig.bodyc, (0.22, 0.12, 0.02))
    leaf.location = (-0.5, 0.0, BODY_SCALE.z + 0.02)
    leaf.rotation_euler = (0.3, 0.6, 0.4)
    return [st, leaf]


def antenna(rig):
    m = _bsdf('Antenna', (0.6, 0.62, 0.7, 1), metallic=1.0, rough=0.25)
    bulb = _bsdf('Bulb', (1, 0.2, 0.2, 1), emit=(1, 0.15, 0.1, 1), emit_strength=1.5)
    a = _cylinder('Antenna', 0.025, 0.025, 0.4, 12, m, rig.bodyc)
    a.location = (-0.45, 0.1, BODY_SCALE.z + 0.1)
    a.rotation_euler = (0, -0.4, 0)
    b = _sphere('Bulb', 0.07, 16, 12, bulb, rig.bodyc)
    b.location = (-0.53, 0.1, BODY_SCALE.z + 0.3)
    return [a, b]


def microphone(rig, hand):
    """Micro tenu dans la main gauche (hand = rig.hands[0])."""
    dark = _bsdf('MicBody', (0.08, 0.1, 0.25, 1), rough=0.3, coat=1.0)
    grill = _bsdf('MicGrill', (0.65, 0.68, 0.75, 1), metallic=1.0, rough=0.35)
    root = _empty('Mic', hand['root'], (0.0, -0.12, 0.2))
    root.rotation_euler = (0, math.radians(110), 0)
    h = _cylinder('MicHandle', 0.07, 0.05, 0.55, 24, dark, root)
    h.location = (0, 0, -0.1)
    g = _sphere('MicHead', 0.13, 24, 16, grill, root)
    g.location = (0, 0, 0.25)
    return root


def remove(objs):
    for ob in objs if isinstance(objs, (list, tuple)) else [objs]:
        for c in list(ob.children_recursive) + [ob]:
            bpy.data.objects.remove(c, do_unlink=True)
