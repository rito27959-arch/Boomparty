"""BOOM PARTY — bombe 3D construite et animée dans Blender (bpy).

Un seul personnage, un seul éclairage, des expressions paramétriques :
chaque frame d'animation est un *rendu* du même modèle 3D, jamais un collage
d'images. Usage (voir render_bomb.py) :

    rig = BombRig(); rig.set_pose(POSES['idle']); rig.render('out.png')
"""
import math
from dataclasses import dataclass, field, replace

import bpy  # doit précéder bmesh/mathutils en mode module
import bmesh
from mathutils import Euler, Matrix, Vector

# ---------------------------------------------------------------- constantes
BODY_R = 1.0
BODY_SCALE = Vector((1.0, 0.95, 0.97))   # sphère légèrement aplatie (maquette 800×740 px)
BODY_Z = 1.08                            # centre du corps au-dessus du sol (pieds à z=0)
FACE_YAW = math.radians(12)              # visage tourné vers la droite (3/4 léger)

# couleurs relevées sur l'image de référence HD (1000055067.png)
C_BODY = (0.010, 0.008, 0.016, 1)        # noir légèrement violacé
C_GLOVE = (0.93, 0.90, 0.88, 1)
C_IRIS_IN = (0.95, 0.42, 0.08, 1)
C_IRIS_OUT = (0.38, 0.09, 0.03, 1)
C_CHEEK = (0.42, 0.05, 0.07, 1)
C_TONGUE = (0.78, 0.05, 0.04, 1)
C_MOUTH = (0.08, 0.0, 0.0, 1)
C_FUSE = (0.55, 0.16, 0.03, 1)
C_NOSE = (1.0, 0.45, 0.0, 1)
C_SWEAT = (0.35, 0.75, 1.0, 1)


# ------------------------------------------------------------------- pose
@dataclass
class Hand:
    pos: tuple = (1.05, -0.25, 1.0)     # poignet (côté du corps)
    rot: tuple = (0.0, 0.0, 0.0)        # orientation du gant (radians)
    curl: tuple = (0.2, 0.2, 0.2, 0.2)  # index → auriculaire (0 droit, 1.6 replié)
    thumb: float = 0.0                  # 0 pouce le long, -1 pouce levé (écarté)
    spread: float = 0.15


@dataclass
class Pose:
    # corps
    squash: float = 0.0       # >0 écrase, <0 étire (conserve le volume)
    lift: float = 0.0         # saut (unités)
    tilt: float = 0.0         # inclinaison gauche/droite (radians, axe Y)
    lean: float = 0.0         # vers l'avant (axe X)
    turn: float = 0.0         # rotation du visage (axe Z)
    shake: float = 0.0        # tremblement déjà appliqué via tilt/translate
    # yeux
    lid: float = 0.0          # 0 ouvert → 1 fermé
    lid_angle: float = 0.0    # paupière inclinée (colère >0)
    look: tuple = (0.0, 0.0)  # direction du regard (-1..1)
    pupil: float = 1.0        # taille relative de la pupille
    x_eyes: bool = False      # yeux en X (K.O.)
    eye_scale: float = 1.0
    happy_eyes: bool = False  # yeux fermés en « ^ »
    # sourcils : hauteur, angle (rad, >0 = froncé vers le centre)
    brow_h: tuple = (0.0, 0.0)
    brow_a: tuple = (0.0, 0.0)
    # bouche (coordonnées faciales, unités du corps)
    m_width: float = 0.33
    m_open: float = 0.30
    m_smile: float = 0.08      # coins relevés (>0) / tombants (<0)
    m_arch: float = 0.02       # bombement de la lèvre supérieure
    m_teeth: float = 0.07
    m_lower_teeth: float = 0.0
    m_tongue: float = 0.6      # proportion de la langue
    m_tongue_out: float = 0.0  # langue tirée
    m_dx: float = 0.0          # décalage latéral (moue)
    m_tongue_dx: float = -0.17  # langue décalée vers la gauche (référence)
    # mains
    left: Hand = field(default_factory=lambda: Hand(pos=(-1.05, -0.25, 1.0)))
    right: Hand = field(default_factory=Hand)
    # pieds : (dx, dz, rot) gauche et droite
    foot_l: tuple = (0.0, 0.0, 0.0)
    foot_r: tuple = (0.0, 0.0, 0.0)
    # extras
    sweat: float = 0.0        # gouttes de sueur
    soot: float = 0.0         # suie / fissures (après explosion)
    spark: float = 1.0        # intensité de l'étincelle
    spark_phase: float = 0.0  # scintillement
    fuse_len: float = 1.0     # mèche restante (1 = entière)
    cheek: float = 1.0
    boom: float = -1.0        # progression de l'explosion 0..1 (<0 : pas d'explosion)
    stars: float = 0.0        # étoiles d'étourdissement (0..1)
    stars_phase: float = 0.0
    smoke: float = 0.0        # fumée qui s'échappe de la mèche


def lerp(a, b, t):
    if isinstance(a, tuple):
        return tuple(lerp(x, y, t) for x, y in zip(a, b))
    if isinstance(a, bool):
        return b if t >= 0.5 else a
    if isinstance(a, Hand):
        return Hand(*(lerp(getattr(a, f), getattr(b, f), t) for f in ('pos', 'rot', 'curl', 'thumb', 'spread')))
    return a + (b - a) * t


def blend(a: Pose, b: Pose, t: float) -> Pose:
    return Pose(**{f: lerp(getattr(a, f), getattr(b, f), t) for f in a.__dataclass_fields__})


# --------------------------------------------------------------- matériaux
def _bsdf(name, color, rough=0.3, coat=0.0, emit=None, emit_strength=0.0, metallic=0.0, sss=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = color
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metallic
    if coat:
        p.inputs['Coat Weight'].default_value = coat
        p.inputs['Coat Roughness'].default_value = 0.05
    if sss:
        p.inputs['Subsurface Weight'].default_value = sss
        p.inputs['Subsurface Radius'].default_value = (0.3, 0.15, 0.1)
    if emit:
        p.inputs['Emission Color'].default_value = emit
        p.inputs['Emission Strength'].default_value = emit_strength
    return m


def _body_material():
    """Noir brillant légèrement violacé + suie animable (valeur 'soot')."""
    m = _bsdf('Body', C_BODY, rough=0.38, coat=1.0)
    m.node_tree.nodes['Principled BSDF'].inputs['Coat Roughness'].default_value = 0.18
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 14.0
    noise.inputs['Detail'].default_value = 8.0
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.5
    ramp.color_ramp.elements[1].position = 0.6
    soot = nt.nodes.new('ShaderNodeValue')
    soot.name = 'soot'
    soot.outputs[0].default_value = 0.0
    mul = nt.nodes.new('ShaderNodeMath')
    mul.operation = 'MULTIPLY'
    nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], mul.inputs[0])
    nt.links.new(soot.outputs[0], mul.inputs[1])
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.inputs['A'].default_value = C_BODY
    mix.inputs['B'].default_value = (0.055, 0.04, 0.035, 1)  # suie brune mate
    nt.links.new(mul.outputs[0], mix.inputs['Factor'])
    nt.links.new(mix.outputs['Result'], p.inputs['Base Color'])
    rough = nt.nodes.new('ShaderNodeMath')
    rough.operation = 'MULTIPLY_ADD'
    rough.inputs[1].default_value = 0.6
    rough.inputs[2].default_value = 0.38
    nt.links.new(mul.outputs[0], rough.inputs[0])
    nt.links.new(rough.outputs[0], p.inputs['Roughness'])
    return m


def _iris_material():
    m = _bsdf('Iris', C_IRIS_IN, rough=0.15, coat=1.0)
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord')
    grad = nt.nodes.new('ShaderNodeTexGradient')
    grad.gradient_type = 'SPHERICAL'
    mp = nt.nodes.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (1.0, 1.0, 1.0)
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, C_IRIS_OUT
    e[1].position, e[1].color = 0.55, C_IRIS_IN
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
    nt.links.new(mp.outputs['Vector'], grad.inputs['Vector'])
    nt.links.new(grad.outputs['Color'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], p.inputs['Base Color'])
    return m


def _halo_material():
    """Halo radial émissif et transparent pour l'étincelle."""
    m = bpy.data.materials.new('Halo')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    tc = nt.nodes.new('ShaderNodeTexCoord')
    grad = nt.nodes.new('ShaderNodeTexGradient')
    grad.gradient_type = 'SPHERICAL'
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (1.0, 0.75, 0.25, 1)
    em.inputs['Strength'].default_value = 4.0
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    mix = nt.nodes.new('ShaderNodeMixShader')
    pw = nt.nodes.new('ShaderNodeMath')
    pw.operation = 'POWER'
    pw.inputs[1].default_value = 2.2
    nt.links.new(tc.outputs['Object'], grad.inputs['Vector'])
    nt.links.new(grad.outputs['Fac'], pw.inputs[0])
    nt.links.new(pw.outputs[0], mix.inputs['Fac'])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs['Surface'])
    m.blend_method = 'BLEND' if hasattr(m, 'blend_method') else None
    return m


# ------------------------------------------------------------ géométrie
def _mesh_obj(name, bm, mat=None, parent=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    if parent:
        ob.parent = parent
    return ob


def _sphere(name, radius=1.0, seg=48, rings=32, mat=None, parent=None, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    return _mesh_obj(name, bm, mat, parent)


def _cylinder(name, r1, r2, depth, seg=40, mat=None, parent=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    return _mesh_obj(name, bm, mat, parent)


def _empty(name, parent=None, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    return e


def _curve_tube(name, pts, radius, mat, parent=None, res=12, taper=None):
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    cu.use_fill_caps = True
    sp = cu.splines.new('BEZIER')
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    sp.resolution_u = res
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    ob.parent = parent
    return ob


def _set_curve(ob, pts):
    sp = ob.data.splines[0]
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = 'AUTO'


# ---------------------------------------------------------------- le rig
# Repères du visage (coordonnées d'arc sur la sphère, relevées sur la référence)
# (u, v, rx, ry) par œil, relevés sur la référence (grille en unités du corps)
EYES = ((-0.371, 0.218, 0.39, 0.395), (0.406, 0.163, 0.37, 0.43))
EYE_U = (EYES[0][0], EYES[1][0])
EYE_V = 0.19
EYE_RX, EYE_RY = 0.36, 0.39
# sourcils : (u centre, v centre, demi-largeur)
BROWS = ((-0.47, 0.86, 0.38), (0.62, 0.77, 0.42))
EYE_BULGE = 0.11
MOUTH_U, MOUTH_V = -0.06, -0.29
MOUTH_TILT = -0.11   # milieu du bord supérieur de la bouche
NOSE_UV = (0.02, -0.11)
GLOVE_SCALE = 1.3
CHEEK_UV = ((-0.806, -0.118), (0.688, -0.309))


class BombRig:
    def __init__(self, res=(420, 500), samples=48, camera='sprite'):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.scene = bpy.context.scene
        self._setup_render(res, samples)
        self.mat = {
            'body': _body_material(),
            'rim': _bsdf('EyeRim', (0.012, 0.010, 0.018, 1), rough=0.35, coat=1.0),
            'glove': _bsdf('Glove', C_GLOVE, rough=0.45, coat=0.2, sss=0.1),
            'eye': _bsdf('EyeWhite', (1.0, 0.98, 0.97, 1), rough=0.15, coat=1.0, emit=(1, 0.97, 0.96, 1), emit_strength=0.25),
            'iris': _iris_material(),
            'pupil': _bsdf('Pupil', (0.004, 0.003, 0.005, 1), rough=0.05, coat=1.0),
            'hl': _bsdf('Highlight', (1, 1, 1, 1), emit=(1, 1, 1, 1), emit_strength=3.0),
            'cheek': _bsdf('Cheek', C_CHEEK, rough=0.55),
            'mouth': _bsdf('Mouth', C_MOUTH, rough=0.6),
            'teeth': _bsdf('Teeth', (0.97, 0.96, 0.95, 1), rough=0.3, coat=0.4, emit=(1, 0.98, 0.97, 1), emit_strength=0.2),
            'tongue': _bsdf('Tongue', C_TONGUE, rough=0.3, coat=0.6, emit=(0.8, 0.05, 0.03, 1), emit_strength=0.25),
            'fuse': _bsdf('Fuse', C_FUSE, rough=0.5),
            'fuse_dark': _bsdf('FuseDark', (0.22, 0.05, 0.01, 1), rough=0.6),
            'iris_out': _bsdf('IrisOut', (0.22, 0.04, 0.01, 1), rough=0.15, coat=1.0),
            'iris_mid': _bsdf('IrisMid', (0.62, 0.17, 0.02, 1), rough=0.15, coat=1.0, emit=(0.6, 0.15, 0.02, 1), emit_strength=0.4),
            'iris_in': _bsdf('IrisIn', (1.0, 0.45, 0.05, 1), rough=0.15, coat=1.0, emit=(1.0, 0.42, 0.04, 1), emit_strength=0.9),
            'nose': _bsdf('Nose', C_NOSE, rough=0.2, emit=C_NOSE, emit_strength=1.2),
            'spark': _bsdf('Spark', (1, 0.7, 0.05, 1), emit=(1, 0.62, 0.02, 1), emit_strength=1.6),
            'spark_glow': _bsdf('SparkGlow', (1, 0.5, 0.0, 1), emit=(1, 0.45, 0.0, 1), emit_strength=0.9),
            'spark_core': _bsdf('SparkCore', (1, 1, 0.85, 1), emit=(1, 1, 0.75, 1), emit_strength=3.0),
            'sweat': _bsdf('Sweat', C_SWEAT, rough=0.05, coat=1.0, emit=C_SWEAT, emit_strength=0.4),
            'xeye': _bsdf('XEye', (0.02, 0.02, 0.03, 1), rough=0.3),
            'crease': _bsdf('Crease', (0.06, 0.05, 0.08, 1), rough=0.2, coat=1.0),
        }
        self.decals = {}
        self._build()
        self._lights()
        self._camera(camera)

    # ---------------------------------------------------------- rendu
    def _setup_render(self, res, samples):
        s = self.scene
        s.render.engine = 'CYCLES'
        s.cycles.device = 'CPU'
        s.cycles.samples = samples
        s.cycles.use_denoising = True
        s.cycles.max_bounces = 6
        s.render.film_transparent = True
        s.render.resolution_x, s.render.resolution_y = res
        s.render.resolution_percentage = 100
        s.render.image_settings.file_format = 'PNG'
        s.render.image_settings.color_mode = 'RGBA'
        s.view_settings.view_transform = 'Standard'
        s.view_settings.look = 'None'
        world = bpy.data.worlds.new('W')
        world.use_nodes = True
        bg = world.node_tree.nodes['Background']
        bg.inputs['Color'].default_value = (0.30, 0.24, 0.34, 1)
        bg.inputs['Strength'].default_value = 0.18
        s.world = world

    def _lights(self):
        def area(name, loc, energy, color, size, target=(0, 0, 1.2)):
            ld = bpy.data.lights.new(name, 'AREA')
            ld.energy, ld.color, ld.size = energy, color, size
            ob = bpy.data.objects.new(name, ld)
            self.scene.collection.objects.link(ob)
            ob.location = loc
            d = Vector(target) - Vector(loc)
            ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
            return ob
        area('Key', (-1.5, -5.0, 4.5), 420, (1.0, 0.94, 0.9), 4.5)
        area('RimBlue', (-4.5, -2.0, 2.2), 900, (0.25, 0.42, 1.0), 3.5)
        area('RimOrange', (3.6, 1.8, 0.4), 1500, (1.0, 0.40, 0.08), 2.5)
        area('RimOrange2', (1.5, 2.5, -0.5), 500, (1.0, 0.35, 0.05), 2.0, target=(0, 0, 0.6))
        area('Top', (-0.5, 0.8, 6.0), 160, (1.0, 0.95, 0.9), 3.0)
        area('Fill', (0.5, -6.0, 0.6), 18, (1.0, 0.85, 0.85), 6.0)

    def _camera(self, mode):
        cam_d = bpy.data.cameras.new('Cam')
        cam_d.type = 'ORTHO'
        rx, ry = self.scene.render.resolution_x, self.scene.render.resolution_y
        if mode == 'sprite':
            # frame 420×500 : corps (2 u) = 244 px, pieds à 97 % de la hauteur
            w = 2.0 * 420 / 244
            h = w * ry / rx
            cz = h / 2 - h * 0.045
        else:  # 'portrait' : bombe plein cadre (illustrations HD)
            w = 3.3
            h = w * ry / rx
            cz = 1.3
        cam_d.ortho_scale = max(w, h)
        cam = bpy.data.objects.new('Cam', cam_d)
        self.scene.collection.objects.link(cam)
        cam.location = (0, -12, cz)
        cam.rotation_euler = (math.radians(90), 0, 0)
        self.scene.camera = cam
        self.cam = cam

    # ------------------------------------------------------ surface faciale
    def _face_point(self, u, v, eps=0.0):
        phi = FACE_YAW + u / BODY_R
        th = v / BODY_R
        d = Vector((math.sin(phi) * math.cos(th), -math.cos(phi) * math.cos(th), math.sin(th)))
        p = Vector((d.x * BODY_SCALE.x, d.y * BODY_SCALE.y, d.z * BODY_SCALE.z)) * BODY_R
        n = Vector((d.x / BODY_SCALE.x, d.y / BODY_SCALE.y, d.z / BODY_SCALE.z)).normalized()
        return p + n * eps, n

    def _strip(self, name, mat, xs, lo, hi, height, uc=0.0, vc=0.0, rows=6, hidden=False):
        """Surface entre deux courbes v=lo(x) et v=hi(x), épousant la sphère
        avec un relief height(x, v)."""
        bm = bmesh.new()
        grid = []
        for x in xs:
            a, b = lo(x), hi(x)
            if b < a:
                b = a
            col = []
            for r in range(rows + 1):
                v = a + (b - a) * r / rows
                col.append(bm.verts.new(self._face_point(uc + x, vc + v, height(x, v))[0]))
            grid.append(col)
        for c0, c1 in zip(grid, grid[1:]):
            for r in range(rows):
                bm.faces.new((c0[r], c1[r], c1[r + 1], c0[r + 1]))
        ob = self.decals.get(name)
        if ob is None:
            ob = _mesh_obj(name, bm, mat, self.bodyc)
            self.decals[name] = ob
        else:
            bm.to_mesh(ob.data)
            bm.free()
            for poly in ob.data.polygons:
                poly.use_smooth = True
        ob.hide_render = hidden
        return ob

    def _ellipse(self, name, mat, uc, vc, rx, ry, height, n=40, rows=8, hidden=False, vmin=None, vmax=None):
        xs = [rx * math.sin(-math.pi / 2 + math.pi * k / n) for k in range(n + 1)]

        def half(x):
            return ry * math.sqrt(max(0.0, 1 - (x / rx) ** 2))
        lo = (lambda x: max(-half(x), vmin(x))) if vmin else (lambda x: -half(x))
        hi = (lambda x: min(half(x), vmax(x))) if vmax else half
        return self._strip(name, mat, xs, lo, hi, lambda x, v: height(x, v), uc, vc, rows, hidden)

    # ------------------------------------------------------ construction
    def _build(self):
        m = self.mat
        self.root = _empty('Root')
        self.pivot = _empty('Pivot', self.root, (0, 0, BODY_Z - BODY_SCALE.z * BODY_R))
        self.bodyc = _empty('BodyCenter', self.pivot, (0, 0, BODY_SCALE.z * BODY_R))
        self.body = _sphere('Body', BODY_R, 72, 48, m['body'], self.bodyc, BODY_SCALE)
        top = BODY_SCALE.z * BODY_R
        cap = _cylinder('Cap', 0.3, 0.31, 0.18, 56, m['body'], self.bodyc)
        cap.location = (0.08, 0.0, top + 0.06)
        cap.rotation_euler = (0, math.radians(7), 0)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=56, radius1=0.315, radius2=0.30, depth=0.05)
        _mesh_obj('CapLip', bm, m['body'], cap).location = (0, 0, 0.1)
        self.cap = cap
        self.fuse_path = [Vector((0.0, 0.0, 0.1)), Vector((0.03, 0.0, 0.36)), Vector((0.2, 0.0, 0.52)),
                          Vector((0.46, 0.0, 0.47))]
        self.fuse_strands = [
            _curve_tube(f'Fuse{i}', self._strand(i, 1.0), 0.05, m['fuse'] if i == 0 else m['fuse_dark'], cap, res=4)
            for i in range(2)
        ]
        self.spark = _empty('Spark', cap)
        self.spark_glow = self._star('SparkGlow', 12, 0.42, 0.2, m['spark_glow'], self.spark)
        self.spark_glow.rotation_euler = (math.radians(90), 0.13, 0)
        self.spark_glow.location = (0, 0.03, 0)
        self.spark_glow.visible_shadow = False
        self.spark_star = self._star('SparkStar', 9, 0.36, 0.11, m['spark'], self.spark)
        self.spark_star2 = self._star('SparkStar2', 7, 0.15, 0.07, m['spark_core'], self.spark)
        self.spark_star.rotation_euler = (math.radians(90), 0, 0)
        self.spark_star2.rotation_euler = (math.radians(90), math.radians(20), 0)
        self.spark_star2.location = (0, -0.03, 0)
        for ob in (self.spark_star, self.spark_star2):
            ob.visible_shadow = False
        self.brows = [_curve_tube(f'Brow{i}', [Vector()] * 5, 0.068, m['body'], self.bodyc, res=16) for i in range(2)]
        self.crease = [_curve_tube(f'Crease{i}', [Vector()] * 5, 0.05, m['body'], self.bodyc, res=16) for i in range(2)]
        p, n = self._face_point(*NOSE_UV, 0.0)
        self.nose = _sphere('Nose', 0.045, 16, 12, m['nose'], self.bodyc)
        self.nose.location = p
        self.arms = [_curve_tube(f'Arm{i}', [Vector()] * 3, 0.085, m['body'], self.bodyc) for i in range(2)]
        self.hands = [self._glove(i) for i in range(2)]
        self.feet = []
        for side in (-1, 1):
            f = _empty(f'Foot{side}', self.root, (side * 0.52, -0.05, 0.0))
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=32, radius=1.0)
            for v in bm.verts:
                if v.co.z < -0.35:      # semelle plate
                    v.co.z = -0.35 - (v.co.z + 0.35) * 0.15
                if v.co.y < 0:           # bout arrondi et plus large
                    v.co.x *= 1.0 + 0.12 * (-v.co.y)
            bmesh.ops.scale(bm, vec=Vector((0.42, 0.52, 0.24)), verts=bm.verts)
            shoe = _mesh_obj('Shoe', bm, m['body'], f)
            shoe.location = (0, -0.14, 0.1)
            ankle = _cylinder('Ankle', 0.11, 0.14, 0.2, 24, m['body'], f)
            ankle.location = (0, 0.06, 0.24)
            self.feet.append(f)
        self._build_fx()
        # objets permanents du personnage (masqués pendant l'explosion)
        fx_names = {ob.name for ob in self.dizzy + self.wisp}
        self.static = [ob for ob in self.pivot.children_recursive + [c for f in self.feet for c in f.children_recursive]
                       if ob.type in ('MESH', 'CURVE') and ob.name not in fx_names
                       and ob.parent is not self.spark and not ob.name.startswith('Crease')]
        self.sweat = []
        for i, (u, v) in enumerate(((0.95, 0.55), (-0.95, 0.5), (1.1, 0.15))):
            d = self._drop(f'Sweat{i}')
            d.parent = self.bodyc
            p, n = self._face_point(u, v, 0.12)
            d.location = p
            self.sweat.append(d)

    def _build_fx(self):
        import random
        rnd = random.Random(7)
        m = self.mat
        m['fire_core'] = _bsdf('FireCore', (1, 0.9, 0.35, 1), emit=(1, 0.85, 0.25, 1), emit_strength=1.4)
        m['fire_mid'] = _bsdf('FireMid', (1, 0.45, 0.0, 1), emit=(1, 0.4, 0.0, 1), emit_strength=1.1)
        m['fire_out'] = _bsdf('FireOut', (0.9, 0.15, 0.0, 1), emit=(0.9, 0.13, 0.0, 1), emit_strength=0.9)
        m['smoke'] = _bsdf('Smoke', (0.045, 0.03, 0.022, 1), rough=1.0)
        m['smoke2'] = _bsdf('Smoke2', (0.13, 0.08, 0.05, 1), rough=1.0, emit=(0.5, 0.15, 0.0, 1), emit_strength=0.08)
        m['debris'] = _bsdf('Debris', (0.03, 0.025, 0.035, 1), rough=0.5, coat=0.6)
        m['flash'] = _bsdf('Flash', (1, 1, 0.9, 1), emit=(1, 0.98, 0.85, 1), emit_strength=4.0)
        m['star'] = _bsdf('Star', (1, 0.65, 0.0, 1), emit=(1, 0.6, 0.0, 1), emit_strength=0.9)
        self.fx = _empty('FX', self.root, (0, 0, BODY_Z))
        self.flash = _sphere('Flash', 1.0, 32, 16, m['flash'], self.fx)
        self.fire = []
        for k in range(16):
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.6, 0.2), rnd.uniform(-0.7, 1))).normalized()
            mat = m['fire_core'] if k < 4 else (m['fire_mid'] if k < 10 else m['fire_out'])
            ob = _sphere(f'Fire{k}', 1.0, 24, 16, mat, self.fx)
            self.fire.append((ob, d * rnd.uniform(0.25, 1.0), rnd.uniform(0.5, 0.8), rnd.uniform(0.6, 1.2)))
        self.smoke_balls = []
        for k in range(18):
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.2, 0.6), rnd.uniform(-0.4, 1))).normalized()
            ob = _sphere(f'Smoke{k}', 1.0, 24, 16, m['smoke'] if k % 3 else m['smoke2'], self.fx)
            self.smoke_balls.append((ob, d * rnd.uniform(0.15, 1.0), rnd.uniform(0.45, 0.7), rnd.uniform(0.9, 1.5)))
        self.debris = []
        for k in range(12):
            bm = bmesh.new()
            bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
            for v in bm.verts:
                v.co *= rnd.uniform(0.75, 1.2)
            ob = _mesh_obj(f'Debris{k}', bm, m['debris'], self.fx, smooth=False)
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.5, 0.2), rnd.uniform(-0.1, 1))).normalized()
            self.debris.append((ob, d, rnd.uniform(0.06, 0.12), rnd.uniform(2.0, 3.2), Vector((rnd.random(), rnd.random(), rnd.random()))))
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, cap_ends=False, segments=64, radius=1.0)
        self.ring = _mesh_obj('Shock', bm, m['flash'], self.fx, smooth=False)
        ring_mod = self.ring.modifiers.new('sk', 'SKIN')
        for v in self.ring.data.skin_vertices[0].data:
            v.radius = (0.03, 0.03)
        self.ring.rotation_euler = (math.radians(90), 0, 0)
        # étoiles d'étourdissement + fumée de la mèche
        self.dizzy = []
        for k in range(3):
            st = self._star(f'Dizzy{k}', 5, 0.2, 0.09, m['star'], self.bodyc)
            st.data.update()
            self.dizzy.append(st)
        self.wisp = [_sphere(f'Wisp{k}', 1.0, 16, 12, m['smoke2'], self.cap) for k in range(5)]

    def _pose_fx(self, p):
        b = p.boom
        on = b >= 0
        for ob in [self.flash, self.ring] + [f[0] for f in self.fire] + [s[0] for s in self.smoke_balls] + [d[0] for d in self.debris]:
            ob.hide_render = not on
        if on:
            # flash bref
            ft = b / 0.14
            self.flash.hide_render = not (0 <= ft <= 1)
            self.flash.scale = Vector((1, 1, 1)) * (0.6 + 1.4 * min(ft, 1))
            # onde de choc
            rt = b / 0.35
            self.ring.hide_render = rt > 1
            self.ring.scale = Vector((1, 1, 1)) * (0.8 + 1.4 * rt)
            # boule de feu : gonfle puis se rétracte
            for ob, d, r0, sp in self.fire:
                g = min(1.0, b / 0.25)
                fade = max(0.0, 1 - max(0.0, b - 0.35) / 0.45)
                rad = r0 * (0.3 + 0.9 * g) * fade
                ob.hide_render = rad < 0.02
                ob.location = d * (0.25 + 0.75 * g * sp)
                ob.scale = Vector((rad, rad, rad))
            # fumée : apparaît après le feu, grossit et monte
            for ob, d, r0, sp in self.smoke_balls:
                t = max(0.0, (b - 0.22) / 0.78)
                rad = r0 * (0.2 + 1.0 * t) * (1 if b < 0.92 else max(0.0, 1 - (b - 0.92) / 0.08))
                ob.hide_render = t <= 0 or rad < 0.02
                ob.location = d * (0.4 + 0.7 * t * sp) + Vector((0, 0, 0.35 * t))
                ob.scale = Vector((rad, rad, rad))
            # débris balistiques
            for ob, d, sz, sp, rot in self.debris:
                t = b
                pos = d * sp * t + Vector((0, 0, -2.5 * t * t))
                ob.location = pos
                ob.scale = Vector((sz, sz, sz)) * (1 if b < 0.85 else max(0.0, 1 - (b - 0.85) / 0.15))
                ob.rotation_euler = rot * 12 * t
        # étoiles
        for k, st in enumerate(self.dizzy):
            a = p.stars_phase * 2 * math.pi + k * 2 * math.pi / 3
            st.hide_render = p.stars <= 0.01
            st.location = (math.cos(a) * 0.75, -math.sin(a) * 0.4, BODY_SCALE.z + 0.35 + 0.08 * math.sin(a * 2))
            st.rotation_euler = (math.radians(90), a * 2, 0)
            st.scale = Vector((1, 1, 1)) * p.stars * (0.85 + 0.25 * (-math.sin(a) + 1) / 2)
        # fumée de la mèche
        tip = self._strand(0, max(0.15, p.fuse_len))[-1]
        for k, w in enumerate(self.wisp):
            t = (k / len(self.wisp) + p.stars_phase * 0.5) % 1.0
            w.hide_render = p.smoke <= 0.01
            w.location = tip + Vector((0.12 * math.sin(t * 9 + k), 0, 0.15 + 0.9 * t))
            r = (0.09 + 0.16 * t) * p.smoke * (1 - t * 0.5)
            w.scale = Vector((r, r, r))

    def _strand(self, i, length):
        path = self.fuse_path
        segs = 26
        out = []
        for k in range(segs + 1):
            t = k / segs * length
            seg_t = t * (len(path) - 1)
            j = min(int(seg_t), len(path) - 2)
            f = seg_t - j
            c = path[j].lerp(path[j + 1], f)
            tang = (path[j + 1] - path[j]).normalized()
            side = tang.cross(Vector((0, 1, 0))).normalized()
            up = Vector((0, 1, 0))
            a = k * 1.25 + i * math.pi
            out.append(c + (side * math.cos(a) + up * math.sin(a)) * 0.035)
        return out

    def _star(self, name, n, r_out, r_in, mat, parent):
        bm = bmesh.new()
        verts = []
        for k in range(n * 2):
            a = k * math.pi / n
            r = r_out * (1.0 if k % 4 == 0 else 0.78) if k % 2 == 0 else r_in
            verts.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0)))
        c = bm.verts.new((0, 0, 0.03))
        for k in range(n * 2):
            bm.faces.new((c, verts[k], verts[(k + 1) % (n * 2)]))
        return _mesh_obj(name, bm, mat, parent, smooth=False)

    def _drop(self, name):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=0.09)
        for v in bm.verts:
            if v.co.z > 0:
                k = v.co.z / 0.09
                v.co.x *= (1 - k * 0.85)
                v.co.y *= (1 - k * 0.85)
                v.co.z *= 1.8
        return _mesh_obj(name, bm, self.mat['sweat'])

    def _glove(self, i):
        """Gant cartoon à 4 doigts. Repère local : Z = direction des doigts,
        X = empilement des doigts (index en +X), -Y = intérieur de la paume."""
        m = self.mat
        side = -1 if i == 0 else 1
        g = _empty(f'Glove{side}', self.bodyc)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.17, radius2=0.2, depth=0.13)
        _mesh_obj('Cuff', bm, m['glove'], g).location = (0, 0, -0.05)
        palm = _sphere('Palm', 1.0, 32, 24, m['glove'], g, (0.25, 0.19, 0.24))
        palm.location = (0, 0, 0.16)
        fingers = []
        for k in range(4):
            x = (1.5 - k) * 0.1
            base = _empty(f'F{k}', g, (x, 0.0, 0.31 - abs(k - 1) * 0.015))
            s1 = _sphere('F1', 1.0, 20, 14, m['glove'], base, (0.085, 0.085, 0.11))
            s1.location = (0, 0, 0.07)
            j2 = _empty('J2', base, (0, 0, 0.12))
            s2 = _sphere('F2', 1.0, 20, 14, m['glove'], j2, (0.082, 0.082, 0.095))
            s2.location = (0, 0, 0.05)
            fingers.append((base, j2))
        tb = _empty('Thumb', g, (0.2, -0.07, 0.12))
        t1 = _sphere('T1', 1.0, 20, 14, m['glove'], tb, (0.1, 0.1, 0.14))
        t1.location = (0, 0, 0.08)
        tj = _empty('TJ', tb, (0, 0, 0.13))
        t2 = _sphere('T2', 1.0, 20, 14, m['glove'], tj, (0.095, 0.095, 0.11))
        t2.location = (0, 0, 0.055)
        return {'root': g, 'fingers': fingers, 'thumb': (tb, tj), 'side': side}

    # ------------------------------------------------------------ pose
    def set_pose(self, p: Pose):
        sz = 1 - p.squash
        sxy = 1 / math.sqrt(max(sz, 0.2))
        self.pivot.scale = (sxy, sxy, sz)
        self.pivot.location.z = BODY_Z - BODY_SCALE.z * BODY_R + p.lift
        self.pivot.rotation_euler = (p.lean, p.tilt, p.turn)
        self.mat['body'].node_tree.nodes['soot'].outputs[0].default_value = p.soot
        for i in range(2):
            self._pose_eye(i, p)
        for i, b in enumerate(self.brows):
            side = -1 if i == 0 else 1
            bu, bv, bh = BROWS[i]
            h, a = p.brow_h[i], p.brow_a[i]
            pts = []
            for t in (-1, -0.5, 0, 0.5, 1):
                inner = t * (-side)
                v = bv + h + 0.07 * (1 - t * t) - 0.07 - a * 0.11 * inner + (p.eye_scale - 1) * 0.3
                pts.append(self._face_point(bu + t * bh, v, 0.05)[0])
            _set_curve(b, pts)
            for bp, rad in zip(b.data.splines[0].bezier_points, (0.4, 0.9, 1.0, 0.9, 0.4)):
                bp.radius = rad
        for i, (u, v) in enumerate(CHEEK_UV):
            self._ellipse(f'Cheek{i}', self.mat['cheek'], u, v, 0.1, 0.075, lambda x, y: 0.004, n=24, rows=3,
                          hidden=p.cheek < 0.5)
        self._build_mouth(p)
        for i, (hand, spec) in enumerate(zip(self.hands, (p.left, p.right))):
            self._pose_hand(hand, spec)
            side = hand['side']
            shoulder = Vector((side * 0.9, 0.08, -0.2))
            wrist = Vector(spec.pos) + Vector((0, 0.02, -0.04))
            mid = shoulder.lerp(wrist, 0.5) + Vector((side * 0.06, 0, -0.05))
            _set_curve(self.arms[i], [shoulder, mid, wrist])
        for f, (dx, dz, rot), side in zip(self.feet, (p.foot_l, p.foot_r), (-1, 1)):
            f.location = (side * 0.6 + dx, -0.05, dz)
            f.rotation_euler = (rot, 0, side * -0.18)
        for k, d in enumerate(self.sweat):
            d.hide_render = p.sweat <= k / len(self.sweat) + 0.01
        self._pose_fx(p)
        # pendant l'explosion, la bombe disparaît derrière le flash
        hide = p.boom >= 0.08
        for ob in self.static:
            ob.hide_render = hide
        if hide:
            for ob in list(self.decals.values()) + list(self.spark.children) + self.crease + self.sweat:
                ob.hide_render = True
        L = max(0.15, p.fuse_len)
        for i, s in enumerate(self.fuse_strands):
            _set_curve(s, self._strand(i, L))
        self.spark.location = self._strand(0, L)[-1].lerp(self._strand(1, L)[-1], 0.5) + Vector((0.04, -0.02, 0.0))
        fl = 1 + 0.15 * math.sin(p.spark_phase * 6.28) + 0.07 * math.sin(p.spark_phase * 17.0)
        self.spark.scale = Vector((1, 1, 1)) * max(p.spark, 0.001) * fl
        self.spark_star.rotation_euler = (math.radians(90), p.spark_phase * 1.3, 0)
        self.spark_star2.rotation_euler = (math.radians(90), 0.4 - p.spark_phase * 1.7, 0)
        self.spark.hide_render = p.spark <= 0.01
        for ob in self.spark.children:
            ob.hide_render = p.spark <= 0.01

    def _pose_eye(self, i, p: Pose):
        m = self.mat
        side = -1 if i == 0 else 1
        uc, vc, rx0, ry0 = EYES[i]
        rx, ry = rx0 * p.eye_scale, ry0 * p.eye_scale
        bul = EYE_BULGE * p.eye_scale

        def dome(x, v):
            return 0.006 + bul * max(0.0, 1 - (x / rx) ** 2 - (v / ry) ** 2)

        # orbite sombre en relief + blanc de l'œil
        self._ellipse(f'Rim{i}', m['rim'], uc, vc, rx * 1.12, ry * 1.09, lambda x, v: 0.002)
        closed = 0.0 if p.happy_eyes else p.lid
        self._ellipse(f'White{i}', m['eye'], uc, vc, rx, ry, dome, hidden=p.happy_eyes)
        # iris / pupille / reflets : décalcomanies posées sur le dôme, décalées par le regard
        gx, gy = p.look
        base = (0.055 if side < 0 else -0.04, -0.05)
        iu = base[0] + gx * 0.12
        iv = base[1] + gy * 0.12
        on_eye = lambda du, dv, e: (lambda x, v: dome(x + du, v + dv) + e)
        show_iris = not (p.x_eyes or p.happy_eyes)
        ir = 0.215
        for k, (key, rr, e, dv) in enumerate((('iris_out', 1.0, 0.006, 0.0), ('iris_mid', 0.84, 0.008, -0.01),
                                               ('iris_in', 0.62, 0.0095, -0.035))):
            self._ellipse(f'Iris{i}{k}', m[key], uc + iu, vc + iv + dv * ir, ir * rr, ir * rr * 1.08,
                          on_eye(iu, iv + dv * ir, e), n=32, rows=6, hidden=not show_iris)
        pr = 0.105 * p.pupil
        self._ellipse(f'Pupil{i}', m['pupil'], uc + iu, vc + iv + 0.012, pr, pr * 1.1, on_eye(iu, iv + 0.012, 0.012),
                      n=28, rows=5, hidden=not show_iris)
        for k, (du, dv, r) in enumerate(((0.06, 0.075, 0.05), (0.0, 0.02, 0.022))):
            self._ellipse(f'HL{i}{k}', m['hl'], uc + iu + du, vc + iv + dv, r, r, on_eye(iu + du, iv + dv, 0.016),
                          n=16, rows=3, hidden=not show_iris)
        # yeux en X
        for k, sgn in enumerate((1, -1)):
            xs = [t / 10 * 0.42 - 0.21 for t in range(11)]
            self._strip(f'X{i}{k}', m['xeye'], xs, lambda x, s=sgn: s * x * 1.05 - 0.035, lambda x, s=sgn: s * x * 1.05 + 0.035,
                        lambda x, v: dome(x, v) + 0.012, uc, vc, rows=2, hidden=not p.x_eyes)
        # paupière (corps) : couvre le haut de l'œil jusqu'à la ligne de coupe inclinée
        ang = p.lid_angle * (-side)
        cut = ry - closed * (2 * ry + 0.02)
        self._ellipse(f'Lid{i}', m['body'], uc, vc, rx * 1.02, ry * 1.03,
                      lambda x, v: dome(x, v) + 0.016 if abs(x) < rx else 0.02,
                      vmin=lambda x: cut + x * math.tan(ang), hidden=(closed <= 0.01 and p.lid_angle == 0) or p.happy_eyes)
        # pli « ^ » des yeux rieurs
        cr = self.crease[i]
        if p.happy_eyes:
            pts = [self._face_point(uc + t * rx * 0.75, vc - 0.1 + 0.2 * (1 - t * t), 0.03)[0] for t in (-1, -0.5, 0, 0.5, 1)]
            _set_curve(cr, pts)
            for bp, rad in zip(cr.data.splines[0].bezier_points, (0.4, 0.9, 1.0, 0.9, 0.4)):
                bp.radius = rad
        cr.hide_render = not p.happy_eyes

    def _pose_hand(self, h, spec: Hand):
        """Les mains sont toujours décrites comme une main DROITE ; la gauche
        est son reflet exact (même gant, échelle X = -1)."""
        g = h['root']
        k = GLOVE_SCALE
        if h['side'] < 0:
            x, y, z = spec.pos
            g.location = (-abs(x), y, z)
            ax, ay, az = spec.rot
            g.rotation_euler = (ax, -ay, -az)
            g.scale = (k, k, k)
        else:
            x, y, z = spec.pos
            g.location = (abs(x), y, z)
            g.rotation_euler = spec.rot
            g.scale = (-k, k, k)  # gant modélisé en main gauche : miroir pour la droite
        for k, (base, j2) in enumerate(h['fingers']):
            c = spec.curl[k]
            # courbure vers l'intérieur de la paume (-Y local)
            base.rotation_euler = (c * 0.95, (1.5 - k) * spec.spread * -0.3, 0)
            j2.rotation_euler = (c * 1.2, 0, 0)
        tb, tj = h['thumb']
        t = spec.thumb
        # t = -1 : pouce dressé (le long de +X local) ; t = 1 : replié sur l'index
        up = max(0.0, -t)
        fold = max(0.0, t)
        tb.rotation_euler = (0.3 + fold * 0.9, math.radians(90) * up + 0.35 * (1 - up), 0)
        tj.rotation_euler = (fold * 1.0, 0, 0)

    def _build_mouth(self, p: Pose):
        a = p.m_width
        n = 44
        uc, vc = MOUTH_U + p.m_dx, MOUTH_V

        tilt = MOUTH_TILT

        def top(x):
            t = x / a
            return tilt * x + p.m_smile * 0.6 * t * t + p.m_arch * math.sqrt(max(0.0, 1 - t * t))

        def bot(x):
            t = x / a
            return tilt * x + p.m_smile * 0.6 * t * t - max(p.m_open, 0.025) * math.sqrt(max(0.0, 1 - t * t)) ** 0.75

        flat = lambda e: (lambda x, v: e)
        xs = [a * math.sin(-math.pi / 2 + math.pi * k / n) for k in range(n + 1)]
        self._strip('Mouth', self.mat['mouth'], xs, bot, top, flat(0.006), uc, vc, rows=4)
        tw = a * 0.66
        xt = [x for x in xs if abs(x) <= tw] or [0.0]
        th = p.m_teeth
        self._strip('Teeth', self.mat['teeth'], xt,
                    lambda x: max(top(x) - th * math.sqrt(max(0.0, 1 - (x / tw) ** 2)) - 0.012, bot(x)), top,
                    lambda x, v: 0.010, uc, vc, rows=3, hidden=th <= 0.005)
        lt = p.m_lower_teeth
        self._strip('LTeeth', self.mat['teeth'], xt, bot, lambda x: min(bot(x) + lt, top(x)),
                    lambda x, v: 0.010, uc, vc, rows=3, hidden=lt <= 0.005)
        tgw = a * 0.6
        tdx = p.m_tongue_dx
        xg = [x for x in xs if abs(x - tdx) <= tgw] or [tdx]
        depth = max(p.m_open, 0.025)
        out = p.m_tongue_out

        def t_lo(x):
            return bot(x) + 0.03 * (1 - out) - out * 0.4 * math.sqrt(max(0.0, 1 - ((x - tdx) / tgw) ** 2))

        def t_hi(x):
            k = math.sqrt(max(0.0, 1 - ((x - tdx) / tgw) ** 2))
            return min(bot(x) + depth * p.m_tongue * k, top(x) - th - 0.015)

        self._strip('Tongue', self.mat['tongue'], xg, t_lo, t_hi,
                    lambda x, v: 0.014 + 0.03 * max(0.0, 1 - ((x - tdx) / tgw) ** 2), uc, vc, rows=5,
                    hidden=p.m_tongue <= 0.01 and out <= 0.01)

    def write_body_meta(self, path):
        """Centre et rayon horizontal du corps en pixels dans le dernier rendu."""
        import json
        from bpy_extras.object_utils import world_to_camera_view
        bpy.context.view_layer.update()
        sc = self.scene
        rx, ry = sc.render.resolution_x, sc.render.resolution_y
        m = self.bodyc.matrix_world

        def px(v):
            c = world_to_camera_view(sc, self.cam, v)
            return c.x * rx, (1 - c.y) * ry
        c = px(m.translation)
        e = px(m @ Vector((BODY_R * BODY_SCALE.x, 0, 0)))
        json.dump({'cx': c[0], 'cy': c[1], 'r': abs(e[0] - c[0])}, open(path, 'w'))

    def render(self, path):
        self.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
