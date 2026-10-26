"""Game icon (Roblox experience icon), Lego style, rendered in Cycles. Same render setup as tools/item_icons_blender.py.

    tools/blender-run.sh tools/store_icon_blender.py -- <outdir> <size> <samples> A,B,C[,final] [--sheet]

`final` is option C with the art-director round applied (scene_final, plus a saturation/contrast/vignette grade).

Writes <outdir>/_raw/<key>.png at <size>, then <outdir>/icon_<key>.png at size/2 (2x2 box downsample) and,
with --sheet, <outdir>/_sheet.png (icon_A/B/C side by side). Every model is code-built Lego (bricks, plates, studs).
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HDRI = os.path.join(ROOT, "art", "blender", "hdri")
argv = sys.argv[sys.argv.index("--") + 1:]
OUT, SIZE, SAMPLES, KEYS = argv[0], int(argv[1]), int(argv[2]), argv[3].split(",")
RAW = os.path.join(OUT, "_raw")


# ------------------------------------------------------------------ scene basics (as item_icons_blender.py)
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception as e:  # CPU fallback
        print("[icon] GPU unavailable:", e)
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 8
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "AgX"
    for look in ("AgX - Punchy", "AgX - Medium High Contrast"):
        try:
            sc.view_settings.look = look
            break
        except TypeError:
            pass
    print("[icon] look", sc.view_settings.look, flush=True)
    return sc


def node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


_mats = {}


def mat(name, color, rough=0.28, coat=0.25, emit=None, emit_strength=0.0, transmission=0.0, alpha=1.0, spec=0.5):
    key = (name, color, rough, emit_strength, transmission, alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.08
    b.inputs["Transmission Weight"].default_value = transmission
    b.inputs["Specular IOR Level"].default_value = spec
    b.inputs["Alpha"].default_value = alpha
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = emit_strength
    _mats[key] = m
    return m


# Lego palette (linear RGB)
ORANGE = (1.0, 0.24, 0.0)
WHITE = (0.86, 0.87, 0.86)
GREEN = (0.05, 0.42, 0.04)
LIME = (0.3, 0.6, 0.02)
YELLOW = (0.95, 0.62, 0.02)
RED = (0.62, 0.008, 0.008)
TAN = (0.62, 0.46, 0.24)
BROWN = (0.16, 0.05, 0.015)
NAVY = (0.012, 0.04, 0.16)
BLACK = (0.012, 0.012, 0.014)
DGREY = (0.06, 0.065, 0.07)


def plastic(c):
    return mat("abs", c)


def trans(c):
    return mat("trans", c, rough=0.05, coat=0.0, transmission=1.0)


def finish(o, m=None, bevel=0.0, smooth=True):
    if m:
        o.data.materials.append(m)
    if smooth:
        o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))
    if bevel:
        bv = o.modifiers.new("Bevel", "BEVEL")
        bv.width, bv.segments, bv.limit_method, bv.harden_normals = bevel, 3, "ANGLE", True
    return o


def prim(kind, m=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), bevel=0.0, parent=None, smooth=True, **kw):
    getattr(bpy.ops.mesh, "primitive_%s_add" % kind)(location=(0, 0, 0), **kw)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    o.location, o.rotation_euler = loc, rot
    o.parent = parent
    return finish(o, m, bevel, smooth)


def box(m, center, size, bevel=0.06, rot=(0, 0, 0), parent=None):
    return prim("cube", m, center, rot, (size[0] / 2, size[1] / 2, size[2] / 2), bevel, parent)


def cyl(m, center, r, h, rot=(0, 0, 0), bevel=0.04, parent=None, verts=32):
    return prim("cylinder", m, center, rot, bevel=bevel, parent=parent, vertices=verts, radius=r, depth=h)


def ball(m, center, r, scale=(1, 1, 1), parent=None, seg=24):
    return prim("uv_sphere", m, center, scale=(r * scale[0], r * scale[1], r * scale[2]), parent=parent,
                segments=seg, ring_count=seg // 2, radius=1.0)


def mesh_obj(name, m, verts, faces, bevel=0.06, parent=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    return finish(o, m, bevel)


def loft(name, m, ring_a, za, ring_b, zb, bevel=0.08, parent=None):
    n = len(ring_a)
    verts = [(x, y, za) for x, y in ring_a] + [(x, y, zb) for x, y in ring_b]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh_obj(name, m, verts, faces, bevel, parent)


def empty(name, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, scale=1.0):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location, o.rotation_euler, o.scale, o.parent = loc, rot, (scale,) * 3, parent
    return o


def studs(m, x0, y0, z, nx, ny, r=0.3, h=0.18, pitch=1.0, parent=None):
    """nx*ny stud grid, first stud centred at (x0, y0), sitting on z."""
    o = cyl(m, (x0, y0, z + h / 2), r, h, bevel=0.035, parent=parent, verts=24)
    for axis, n in ((0, nx), (1, ny)):
        if n > 1:
            a = o.modifiers.new("A%d" % axis, "ARRAY")
            a.count, a.use_relative_offset, a.use_constant_offset = n, False, True
            d = [0.0, 0.0, 0.0]
            d[axis] = pitch
            a.constant_offset_displace = d
    return o


def brick(m, x, y, z, nx, ny, h=1.2, parent=None, top=True):
    """Brick/plate with its min corner at (x, y, z), nx*ny studs; h=0.4 is a plate."""
    box(m, (x + nx / 2, y + ny / 2, z + h / 2), (nx - 0.02, ny - 0.02, h - 0.01), bevel=0.04, parent=parent)
    if top:
        studs(m, x + 0.5, y + 0.5, z + h, nx, ny, parent=parent)


def look(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()


def camera(target, az, el, dist, lens=50.0, shift=(0, 0)):
    c = bpy.data.cameras.new("Cam")
    c.lens, c.sensor_width = lens, 36
    c.shift_x, c.shift_y = shift
    o = bpy.data.objects.new("Cam", c)
    bpy.context.collection.objects.link(o)
    a, e = math.radians(az), math.radians(el)
    t = Vector(target)
    o.location = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    look(o, t)
    bpy.context.scene.camera = o
    return o


def sun(el, az, strength, color=(1.0, 0.95, 0.86), soft=3.0):
    d = bpy.data.lights.new("Sun", "SUN")
    d.energy, d.color, d.angle = strength, color, math.radians(soft)
    o = bpy.data.objects.new("Sun", d)
    bpy.context.collection.objects.link(o)
    o.rotation_euler = Euler((math.radians(90 - el), 0, math.radians(az)))
    return o


def area(loc, target, power, size=4.0, color=(0.85, 0.92, 1.0)):
    d = bpy.data.lights.new("Rim", "AREA")
    d.energy, d.size, d.color = power, size, color
    o = bpy.data.objects.new("Rim", d)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.visible_camera = False
    look(o, target)
    return o


def world_sky(top=(0.02, 0.17, 0.85), horizon=(0.28, 0.62, 1.0), light=0.6):
    """HDRI lights the scene (diffuse); camera and reflections see a clean bright gradient sky."""
    w = bpy.data.worlds.new("W")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(os.path.join(HDRI, "dalkey_view_2k.hdr"), check_existing=True)
    lit = node(nt, "ShaderNodeBackground", Strength=light)
    nt.links.new(env.outputs["Color"], lit.inputs["Color"])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    e0, e1 = ramp.color_ramp.elements
    e0.position, e0.color = 0.0, (*horizon, 1)
    e1.position, e1.color = 0.35, (*top, 1)
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    seen = node(nt, "ShaderNodeBackground", Strength=1.0)
    nt.links.new(ramp.outputs["Color"], seen.inputs["Color"])
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMath")
    mx.operation = "MAXIMUM"
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
    nt.links.new(lp.outputs["Is Glossy Ray"], mx.inputs[1])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(mx.outputs["Value"], mix.inputs["Fac"])
    nt.links.new(lit.outputs["Background"], mix.inputs[1])
    nt.links.new(seen.outputs["Background"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def sea(color=(0.0, 0.42, 0.36), deep=(0.0, 0.12, 0.3), size=600, wave=0.35):
    m = bpy.data.materials.new("Sea")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.06
    b.inputs["Specular IOR Level"].default_value = 0.2
    noise = node(nt, "ShaderNodeTexNoise", Scale=0.06, Detail=3.0)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    e0, e1 = ramp.color_ramp.elements
    e0.position, e0.color = 0.35, (*deep, 1)
    e1.position, e1.color = 0.65, (*color, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    wn = node(nt, "ShaderNodeTexNoise", Scale=0.9, Detail=6.0)
    nt.links.new(tc.outputs["Object"], wn.inputs["Vector"])
    bm = node(nt, "ShaderNodeBump", Strength=wave, Distance=0.25)
    nt.links.new(wn.outputs["Fac"], bm.inputs["Height"])
    nt.links.new(bm.outputs["Normal"], b.inputs["Normal"])
    return prim("plane", m, (0, 0, 0), size=size)


# ------------------------------------------------------------------ Lego models
def face(head_parent, r, zc, smile_w=1.0):
    """Eyes and a big smile on a minifig head (cylinder radius r, centre height zc), facing -Y."""
    k = BLACK
    for sx in (-1, 1):
        ball(mat("ink", k, rough=0.15, coat=0.6), (sx * 0.22 * r / 0.62, -r * 0.97, zc + 0.12), 1.0,
             (0.065, 0.04, 0.1), parent=head_parent, seg=16)
    cu = bpy.data.curves.new("Smile", "CURVE")
    cu.dimensions, cu.bevel_depth, cu.bevel_resolution, cu.use_fill_caps = "3D", 0.032, 3, True
    sp = cu.splines.new("POLY")
    n = 15
    sp.points.add(n - 1)
    rs = 0.27 * smile_w
    for i in range(n):
        a = math.radians(205 + 130 * i / (n - 1))
        x, z = rs * math.cos(a), zc + 0.1 + rs * math.sin(a)
        sp.points[i].co = (x, -math.sqrt(max(r * r - x * x, 0)) - 0.004, z, 1)
    o = bpy.data.objects.new("Smile", cu)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("ink", k, rough=0.15, coat=0.6))
    o.parent = head_parent


def minifig(name, vest=ORANGE, legs=NAVY, helmet=WHITE, seated=False, legs_on=True):
    """Minifig, origin = torso bottom centre, faces -Y. Returns (root, right_arm_pivot, left_arm_pivot)."""
    root = empty(name)
    skin = plastic(YELLOW)
    # torso (trapezoid) + life-vest stripes
    wb, wt, d, h = 1.95, 1.45, 1.0, 1.6
    v = [(-wb / 2, -d / 2, 0), (wb / 2, -d / 2, 0), (wb / 2, d / 2, 0), (-wb / 2, d / 2, 0),
         (-wt / 2, -d / 2, h), (wt / 2, -d / 2, h), (wt / 2, d / 2, h), (-wt / 2, d / 2, h)]
    mesh_obj("Torso", plastic(vest), v, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6),
                                         (3, 0, 4, 7)], bevel=0.07, parent=root)
    for z in (0.42, 0.85):
        w = wb + (wt - wb) * z / h - 0.16
        box(mat("reflect", (0.9, 0.9, 0.88), rough=0.35), (0, -d / 2 - 0.01, z), (w, 0.04, 0.16), bevel=0.015,
            parent=root)
    box(plastic(WHITE), (0, -d / 2 - 0.02, 1.25), (0.18, 0.05, 0.62), bevel=0.02, parent=root)  # zip
    # neck, head, helmet
    cyl(skin, (0, 0, 1.7), 0.34, 0.22, parent=root)
    head = empty("Head", (0, 0, 2.35), parent=root)
    cyl(skin, (0, 0, 0), 0.62, 1.08, bevel=0.16, parent=head, verts=48)
    face(head, 0.62, -0.05)
    hm = prim("uv_sphere", plastic(helmet), (0, 0.04, 0.28), scale=(0.7, 0.72, 0.62), parent=head,
              segments=48, ring_count=24, radius=1.0)
    bm = bmesh.new()
    bm.from_mesh(hm.data)
    bmesh.ops.delete(bm, geom=[x for x in bm.verts if x.co.z < -0.02], context="VERTS")
    bm.to_mesh(hm.data)
    bm.free()
    sol = hm.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.06
    box(plastic(ORANGE), (0, 0.04, 0.28 + 0.6), (0.2, 1.3, 0.12), bevel=0.04, parent=head)  # helmet ridge
    box(plastic(helmet), (0, -0.62, 0.3), (1.1, 0.25, 0.08), bevel=0.03, parent=head)  # brim
    # hips + legs
    box(plastic(legs), (0, 0, -0.2), (wb, d, 0.4), bevel=0.05, parent=root)
    if legs_on:
        for sx in (-1, 1):
            if seated:
                box(plastic(legs), (sx * 0.49, -0.6, -0.15), (0.92, 1.9, 0.62), bevel=0.06, parent=root)
                box(plastic(legs), (sx * 0.49, -1.25, -0.9), (0.92, 0.75, 1.3), bevel=0.06, parent=root)
            else:
                box(plastic(legs), (sx * 0.49, -0.05, -1.15), (0.92, 1.0, 1.5), bevel=0.06, parent=root)
    arms = []
    for sx in (-1, 1):
        p = empty("Arm", (sx * 0.95, 0, 1.3), parent=root)
        box(plastic(vest), (sx * 0.08, 0, -0.5), (0.5, 0.55, 1.25), bevel=0.2, parent=p)
        cyl(skin, (sx * 0.08, 0, -1.22), 0.21, 0.3, parent=p)
        arms.append(p)
    return root, arms[0], arms[1]


def aim(pivot, target):
    bpy.context.view_layer.update()
    p = pivot.matrix_world.translation
    local = pivot.parent.matrix_world.to_3x3().inverted() @ (Vector(target) - p)
    pivot.rotation_euler = local.to_track_quat("-Z", "Y").to_euler()


def thumbs_up(arm):
    """Replace the C-hand with a fist + thumb; call upright(fist) after aiming the arm."""
    for c in list(arm.children):
        if c.type == "MESH" and c.location.z < -1.0:
            bpy.data.objects.remove(c)
    skin = plastic(YELLOW)
    f = empty("Fist", (0, 0, -1.35), parent=arm)
    box(skin, (0, 0, 0), (0.62, 0.56, 0.52), bevel=0.17, parent=f)
    for z in (-0.12, 0.05):
        box(skin, (0.0, -0.29, z), (0.5, 0.04, 0.02), bevel=0.0, parent=f).hide_render = True
    cyl(skin, (0.17, -0.04, 0.42), 0.15, 0.55, bevel=0.08, parent=f)
    return f


def upright(o, yaw=0.0):
    bpy.context.view_layer.update()
    o.rotation_euler = (o.parent.matrix_world.to_3x3().inverted() @ Euler((0, 0, yaw)).to_matrix()).to_euler()


def lifebuoy(parent, loc, rot, R=1.0, r=0.32, bands=8, rough=0.28, rope=False):
    o = prim("torus", None, loc, rot, parent=parent, major_radius=R, minor_radius=r, major_segments=96,
             minor_segments=32)
    o.data.materials.append(mat("abs", ORANGE, rough=rough, coat=0.5))
    o.data.materials.append(mat("abs", WHITE, rough=rough, coat=0.5))
    if rope:  # grab rope scalloped around the outer edge, held at 4 points
        cu = bpy.data.curves.new("Rope", "CURVE")
        cu.dimensions, cu.bevel_depth, cu.bevel_resolution = "3D", 0.045 * r / 0.5, 3
        sp = cu.splines.new("POLY")
        n = 160
        sp.points.add(n - 1)
        sp.use_cyclic_u = True
        for i in range(n):
            a = math.tau * i / n
            rho = R + r * 0.92 + 0.45 * r * abs(math.sin(2 * a))
            sp.points[i].co = (rho * math.cos(a), rho * math.sin(a), 0.15 * r * abs(math.sin(2 * a)), 1)
        ro = bpy.data.objects.new("Rope", cu)
        bpy.context.collection.objects.link(ro)
        ro.data.materials.append(mat("rope", (0.75, 0.72, 0.62), rough=0.7, coat=0.0))
        ro.parent = o
    for p in o.data.polygons:
        a = math.atan2(p.center.y, p.center.x) + math.pi / bands / 2
        p.material_index = int((a + math.pi) / (2 * math.pi) * bands) % 2
    return finish(o)


def jetski(name):
    """Lego jet ski, origin at the waterline centre, bow towards -Y."""
    root = empty(name)
    o, w = plastic(ORANGE), plastic(WHITE)
    top = [(1.35, 3.2), (1.35, -0.6), (1.05, -2.4), (0.45, -3.6), (-0.45, -3.6), (-1.05, -2.4), (-1.35, -0.6),
           (-1.35, 3.2)]
    bot = [(0.95, 3.1), (0.95, -0.6), (0.65, -2.1), (0.15, -2.8), (-0.15, -2.8), (-0.65, -2.1), (-0.95, -0.6),
           (-0.95, 3.1)]
    loft("Hull", o, bot, -0.45, top, 0.75, bevel=0.1, parent=root)
    deck = [(x * 0.97, y * 0.97) for x, y in top]
    loft("Deck", w, deck, 0.74, deck, 1.12, bevel=0.06, parent=root)
    box(plastic(RED), (0, 0, 0.5), (2.74, 3.0, 0.12), bevel=0.02, parent=root)  # side stripe
    # cowl wedge + windscreen + handlebar
    v = [(-0.6, -2.5, 1.1), (0.6, -2.5, 1.1), (0.95, -0.15, 1.1), (-0.95, -0.15, 1.1),
         (-0.6, -2.5, 1.32), (0.6, -2.5, 1.32), (0.95, -0.15, 2.0), (-0.95, -0.15, 2.0)]
    mesh_obj("Cowl", o, v, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)],
             bevel=0.08, parent=root)
    box(trans((0.45, 0.75, 0.95)), (0, -0.35, 2.25), (1.5, 0.08, 0.6), rot=(math.radians(-25), 0, 0),
        bevel=0.03, parent=root)
    cyl(plastic(RED), (0, -1.6, 1.62), 0.16, 0.2, rot=(math.radians(-15), 0, 0), parent=root)  # beacon
    cyl(plastic(DGREY), (0, 0.05, 2.15), 0.09, 2.1, rot=(0, math.pi / 2, 0), parent=root)
    for sx in (-1, 1):
        cyl(plastic(BLACK), (sx * 0.95, 0.05, 2.15), 0.14, 0.45, rot=(0, math.pi / 2, 0), parent=root)
        studs(w, sx * 1.0, -0.2, 1.12, 1, 4, r=0.22, h=0.14, pitch=0.85, parent=root)
    box(plastic(BLACK), (0, 1.5, 1.32), (1.3, 2.6, 0.45), bevel=0.18, parent=root)  # seat
    studs(o, -0.5, 2.95, 1.12, 2, 1, r=0.24, h=0.15, pitch=1.0, parent=root)
    return root


def tower(parent, x, y, z):
    """Lookout tower: 4 posts, white deck, red hut, orange roof, flag."""
    t = empty("Tower", (x, y, z), parent=parent)
    for px in (-1, 1):
        for py in (-1, 1):
            box(plastic(BROWN), (px * 1.05, py * 1.05, 1.6), (0.8, 0.8, 3.2), bevel=0.05, parent=t)
    brick(plastic(WHITE), -1.5, -1.5, 3.2, 3, 3, h=0.4, parent=t, top=False)
    box(plastic(RED), (0, 0, 4.3), (2.6, 2.6, 1.8), bevel=0.06, parent=t)
    box(trans((0.5, 0.8, 1.0)), (0, -1.31, 4.5), (1.6, 0.06, 0.8), bevel=0.02, parent=t)
    box(plastic(WHITE), (0, 0, 4.0), (2.64, 2.64, 0.3), bevel=0.03, parent=t)
    prim("cone", plastic(ORANGE), (0, 0, 5.75), (0, 0, math.pi / 4), parent=t, bevel=0.06, smooth=False,
         vertices=4, radius1=2.3, radius2=0.12, depth=1.1)
    cyl(plastic(DGREY), (0, 0, 6.8), 0.06, 1.4, parent=t, verts=12)
    box(plastic(ORANGE), (0.45, 0, 7.25), (0.8, 0.06, 0.5), bevel=0.02, parent=t)
    return t


def palm(parent, x, y, z, s=1.0):
    p = empty("Palm", (x, y, z), parent=parent, scale=s)
    for i in range(6):
        cyl(plastic(BROWN), (0.08 * i, 0, 0.3 + 0.55 * i), 0.32, 0.5, parent=p)
    for i in range(6):
        a = i * math.tau / 6
        box(plastic(LIME if i % 2 else GREEN), (math.cos(a) * 1.0, math.sin(a) * 1.0, 3.5), (2.0, 0.7, 0.18),
            rot=(0, math.radians(18), a), bevel=0.06, parent=p)
    ball(plastic(GREEN), (0.4, 0, 3.55), 0.4, parent=p)


def house(parent, x, y, z, wall=WHITE, roof=RED, s=1.0, rot=0.0):
    hs = empty("House", (x, y, z), (0, 0, rot), parent=parent, scale=s)
    box(plastic(wall), (0, 0, 0.9), (3.0, 2.0, 1.8), bevel=0.05, parent=hs)
    box(trans((0.5, 0.8, 1.0)), (0.6, -1.01, 1.0), (0.7, 0.06, 0.6), bevel=0.02, parent=hs)
    box(plastic(BROWN), (-0.6, -1.01, 0.6), (0.6, 0.06, 1.2), bevel=0.02, parent=hs)
    prim("cylinder", plastic(roof), (0, 0, 2.2), (0, math.pi / 2, 0), (1.0, 1.55, 1.0), bevel=0.05,
         parent=hs, smooth=False, vertices=3, radius=1.0, depth=3.3)


def island(name, loc, n=12, rot=0.0, sand=TAN):
    """Square Lego island: sand brick base (n+2 wide) with a green stud plate on top. Top surface at local z=0.8."""
    r = empty(name, loc, (0, 0, rot))
    m = n + 2
    box(plastic(sand), (0, 0, -0.6), (m, m, 2.4 - 0.02), bevel=0.08, parent=r)
    studs(plastic(sand), -m / 2 + 0.5, -m / 2 + 0.5, 0.6, m, m, parent=r)
    box(plastic(GREEN), (0, 0, 0.6), (n, n, 0.4 - 0.01), bevel=0.04, parent=r)
    studs(plastic(GREEN), -n / 2 + 0.5, -n / 2 + 0.5, 0.8, n, n, parent=r)
    return r


def helicopter(name, rotor_blur=False):
    """Orange rescue helicopter, nose towards -Y, origin at skid bottom."""
    h = empty(name)
    o, w = plastic(ORANGE), plastic(WHITE)
    box(o, (0, 0, 2.2), (2.6, 4.6, 2.4), bevel=0.45, parent=h)
    ball(o, (0, -2.1, 2.0), 1.25, (1.0, 1.0, 0.95), parent=h)
    ball(trans((0.3, 0.6, 0.9)), (0, -2.45, 2.45), 1.0, (1.05, 0.9, 0.75), parent=h)
    box(w, (0, 0.2, 1.6), (2.66, 3.6, 0.35), bevel=0.04, parent=h)
    box(o, (0, 4.3, 2.7), (0.8, 5.0, 0.8), bevel=0.2, parent=h)
    box(w, (0, 6.6, 3.5), (0.3, 1.0, 2.0), rot=(math.radians(-15), 0, 0), bevel=0.1, parent=h)
    cyl(plastic(DGREY), (0.25, 6.7, 3.5), 0.12, 0.2, rot=(0, math.pi / 2, 0), parent=h)
    box(plastic(BLACK), (0.35, 6.7, 3.5), (0.08, 0.25, 2.0), bevel=0.02, parent=h)
    cyl(plastic(DGREY), (0, 0.2, 3.55), 0.35, 0.5, parent=h)
    if rotor_blur:
        cyl(mat("blur", (0.05, 0.05, 0.06), rough=0.5, coat=0.0, alpha=0.28), (0, 0.2, 3.85), 5.5, 0.03, parent=h,
            bevel=0.0, verts=64)
        box(plastic(BLACK), (0, 0.2, 3.86), (0.4, 11.0, 0.05), rot=(0, 0, math.radians(25)), bevel=0.02, parent=h)
    else:
        for a in (20, 110):
            box(plastic(BLACK), (0, 0.2, 3.85), (0.5, 11.0, 0.08), rot=(0, 0, math.radians(a)), bevel=0.03,
                parent=h)
    for sx in (-1, 1):
        cyl(plastic(DGREY), (sx * 1.1, 0, 0.15), 0.15, 5.0, rot=(math.pi / 2, 0, 0), parent=h)
        for py in (-1.2, 1.2):
            cyl(plastic(DGREY), (sx * 1.1, py, 0.6), 0.09, 0.9, parent=h, verts=12)
    return h


_drop = {}


def droplet(loc, r, m):
    me = _drop.get("m")
    if me is None:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0)
        src = bpy.context.active_object
        src.data.polygons.foreach_set("use_smooth", [True] * len(src.data.polygons))
        me = _drop["m"] = src.data
        me.materials.append(m)
        bpy.data.objects.remove(src)
    o = bpy.data.objects.new("Drop", me)
    bpy.context.collection.objects.link(o)
    o.location, o.scale = loc, (r, r, r)
    o.material_slots[0].link = "OBJECT"  # shared mesh, per-drop material
    o.material_slots[0].material = m
    return o


def foam_mats():
    return (mat("foam", (0.95, 0.97, 0.98), rough=0.35, coat=0.0),
            mat("spray", (0.8, 0.95, 1.0), rough=0.03, coat=0.0, transmission=1.0))


def spray(world, origin, side, rng, n=90, spread=1.0, up=1.0, back=1.0):
    """Droplets thrown up and out on ballistic arcs (side=+-1, in `world` frame) from origin."""
    foam, clear = foam_mats()
    mw = world.matrix_world
    for _ in range(n):
        t = rng.random() ** 0.8
        vx, vy, vz = rng.uniform(2.0, 4.5) * spread, rng.uniform(0.3, 3.0) * back, rng.uniform(5.0, 8.0) * up
        p = Vector(origin) + Vector((side * vx * t, vy * t, max(vz * t - 6.5 * t * t, 0.05)))
        p += Vector([rng.uniform(-0.15, 0.15) for _ in range(3)])
        r = rng.uniform(0.06, 0.2) * (1.3 - 0.7 * t)
        droplet(mw @ p, r, foam if rng.random() < 0.5 else clear)


def foam_patch(center, rx, ry, rng, n=60, rot=0.0):
    foam, _ = foam_mats()
    c, s = math.cos(rot), math.sin(rot)
    for _ in range(n):
        a = rng.uniform(0, math.tau)
        k = math.sqrt(rng.random())
        x, y = math.cos(a) * rx * k, math.sin(a) * ry * k
        o = droplet((center[0] + x * c - y * s, center[1] + x * s + y * c, 0.02), rng.uniform(0.25, 0.6), foam)
        o.scale.z *= 0.22


def wake(points, rng, width=0.6, density=7):
    """Foam trail along a polyline (water level); widens with distance from the first point."""
    foam, _ = foam_mats()
    total = 0.0
    for a, b in zip(points, points[1:]):
        a, b = Vector((*a, 0)), Vector((*b, 0))
        seg = (b - a)
        n = max(1, int(seg.length * density))
        side = Vector((-seg.y, seg.x, 0)).normalized()
        for i in range(n):
            p = a + seg * (i / n)
            d = total + seg.length * i / n
            w = width + d * 0.12
            for sgn in (-1, 1, 0):
                if sgn == 0 and rng.random() < 0.5:
                    continue
                q = p + side * (sgn * w * rng.uniform(0.6, 1.0)) + Vector((rng.uniform(-.2, .2), rng.uniform(-.2, .2), .02))
                o = droplet(q, rng.uniform(0.25, 0.5) * (1.0 + d * 0.015), foam)
                o.scale.z *= 0.22
        total += seg.length


def cloud(loc, s=1.0):
    c = empty("Cloud", loc, scale=s)
    m = mat("cloud", (0.95, 0.97, 1.0), rough=0.6, coat=0.0)
    for x, z, r in ((0, 0, 1.6), (1.7, -0.3, 1.2), (-1.8, -0.4, 1.1), (0.8, 0.9, 1.15), (-0.7, 0.6, 1.0)):
        ball(m, (x, 0, z), r, (1, 0.8, 1), parent=c)


def flare(loc):
    f = empty("Flare", loc)
    cyl(plastic(ORANGE), (0, 0, 0.1), 0.55, 0.5, parent=f)
    cyl(plastic(DGREY), (0, 0, 0.6), 0.12, 0.8, parent=f, verts=12)
    ball(mat("flare", (1.0, 0.1, 0.05), emit=(1.0, 0.08, 0.02), emit_strength=40.0), (0, 0, 1.15), 0.32, parent=f)
    smoke = mat("smoke", (0.9, 0.05, 0.03), rough=0.9, coat=0.0, emit=(1.0, 0.1, 0.03), emit_strength=0.6)
    for i in range(5):
        ball(smoke, (0.04 * i * i, 0.1 * i, 1.7 + 0.6 * i), 0.3 + 0.1 * i, parent=f, seg=20)
    d = bpy.data.lights.new("FlareL", "POINT")
    d.energy, d.color, d.shadow_soft_size = 3000, (1.0, 0.15, 0.05), 0.4
    lo = bpy.data.objects.new("FlareL", d)
    bpy.context.collection.objects.link(lo)
    lo.location, lo.parent = (0, 0, 1.4), f
    return f


# ------------------------------------------------------------------ scenes
def lights(sun_el=48, sun_az=-35, sun_k=4.2, rim=(0, 14, 9), rim_target=(0, 0, 2), rim_k=2500, sky_k=0.8):
    world_sky(light=sky_k)
    sun(sun_el, sun_az, sun_k)
    area(rim, rim_target, rim_k, size=6.0)


def rider_on(ski, rng):
    fig, ra, la = minifig("Rider", seated=True)
    fig.parent = ski
    fig.location = (0, 1.25, 1.95)
    fig.rotation_euler = (math.radians(14), 0, 0)
    for arm, sx in ((ra, -1), (la, 1)):
        bpy.context.view_layer.update()
        aim(arm, ski.matrix_world @ Vector((sx * 0.95, 0.05, 2.15)))
    return fig


def scene_A(fix=None):
    fix = fix or {}
    rng = random.Random(3)
    lights(sun_az=fix.get("sun_az", -40), rim_k=fix.get("rim_k", 2500))
    sea()
    ski = jetski("Ski")
    ski.location = (0, 0, 0.35)
    ski.rotation_euler = (math.radians(-9), math.radians(fix.get("bank", 12)), math.radians(fix.get("yaw", 8)))
    rider_on(ski, rng)
    bpy.context.view_layer.update()
    spray(ski, (0.9, -1.4, 0.0), 1, rng, n=70, up=0.8, back=1.4)  # camera side: keep the hull readable
    spray(ski, (-0.9, -1.8, 0.0), -1, rng, n=170)
    mw = ski.matrix_world
    for sx in (-1, 1):  # foam hugging the hull sides
        for y in np.linspace(-2.6, 3.0, 14):
            q = mw @ Vector((sx * (1.35 - 0.5 * max(0, -y - 0.6) / 3.0), y, 0))
            o = droplet((q.x, q.y, 0.03), rng.uniform(0.3, 0.45), foam_mats()[0])
            o.scale.z *= 0.3
    pts = [tuple((mw @ Vector((0, y, 0)))[:2]) for y in (3.0, 8, 13)]
    wake(pts, rng, width=1.0, density=5)
    # survivor in a lifebuoy, mid-left
    sv = empty("Survivor", fix.get("survivor", (-4.8, 5.0, 0)), (0, 0, math.radians(30)))
    fig, ra, la = minifig("Swimmer", vest=RED, legs=NAVY, helmet=BROWN, legs_on=False)
    fig.parent = sv
    fig.location = (0, 0, -1.1)
    lifebuoy(sv, (0, 0, -0.05), (0, 0, 0), R=1.55, r=0.42)
    bpy.context.view_layer.update()
    aim(ra, sv.matrix_world @ Vector((-1.6, -0.4, 3.6)))
    aim(la, sv.matrix_world @ Vector((1.7, -0.6, 0.4)))
    foam_patch((sv.location.x, sv.location.y), 2.4, 2.4, rng, n=26)
    # island with lookout tower
    isl = island("Island", (17, 22, -0.2), n=12, rot=math.radians(-25))
    tower(isl, -2.0, 1.0, 0.98)
    palm(isl, 3.5, -2.5, 0.98, s=1.1)
    palm(isl, 4.0, 3.5, 0.98, s=0.9)
    cloud((-30, 110, 30), 3.2)
    cloud((26, 120, 38), 3.8)
    camera(fix.get("target", (1.0, 2.0, 1.9)), fix.get("az", -18), fix.get("el", 9), fix.get("dist", 12.5),
           lens=fix.get("lens", 28))


def scene_B(fix=None):
    fix = fix or {}
    rng = random.Random(5)
    lights(sun_el=55, sun_az=-30, rim=(0, 50, 30), rim_target=(0, 0, 0), rim_k=9000)
    sea(color=(0.0, 0.5, 0.48), deep=(0.0, 0.2, 0.36))
    R = 15.0
    walls = [WHITE, YELLOW, (0.02, 0.25, 0.6), WHITE, TAN, (0.8, 0.8, 0.8)]
    roofs = [RED, ORANGE, RED, (0.02, 0.25, 0.6), RED, ORANGE]
    for i in range(6):
        a = math.radians(90 + 60 * i)
        isl = island("Isl%d" % i, (R * math.cos(a), R * math.sin(a), -0.2), n=8, rot=a + math.pi / 2)
        house(isl, -1.2, 0.8, 0.98, wall=walls[i], roof=roofs[i], s=0.8, rot=math.radians(180))
        if i % 2:
            palm(isl, 2.2, -1.8, 0.98, s=0.7)
        else:
            tower(isl, 2.2, -1.6, 0.98).scale = (0.5, 0.5, 0.5)
        # bridge to the next island
        b = math.radians(90 + 60 * i + 30)
        br = empty("Bridge", (R * 0.866 * math.cos(b), R * 0.866 * math.sin(b), 0.55), (0, 0, b + math.pi / 2))
        brick(plastic(BROWN), -2.5, -0.8, 0.0, 5, 2, h=0.4, parent=br, top=False)
        studs(plastic(BROWN), -2.0, -0.3, 0.4, 5, 2, pitch=1.0, parent=br)
        for sx in (-2.2, 2.2):
            cyl(plastic(BROWN), (sx, 0, -0.6), 0.3, 1.4, parent=br)
    fl = flare((1.5, 3.0, 0))
    fl.scale = (1.5,) * 3
    foam_patch((1.5, 3.0), 1.2, 1.2, rng, n=14)
    ski = jetski("Ski")
    ski.location = (-4.0, -5.5, 0.15)
    ski.rotation_euler = (0, math.radians(-8), math.radians(fix.get("ski_yaw", 150)))
    ski.scale = (1.0,) * 3
    rider_on(ski, rng)
    bpy.context.view_layer.update()
    mw = ski.matrix_world
    pts = [tuple((mw @ Vector((x, y, 0)))[:2]) for x, y in ((0, 3.0), (0, 9), (1.0, 15), (3.5, 21), (7, 26))]
    wake(pts, rng, width=0.7, density=4)
    spray(ski, (0.9, -2.4, 0.2), 1, rng, n=50, up=0.7)
    spray(ski, (-0.9, -2.4, 0.2), -1, rng, n=50, up=0.7)
    camera(fix.get("target", (0, 0.5, 0)), fix.get("az", 12), fix.get("el", 52), fix.get("dist", 41), lens=35)


def scene_C(fix=None):
    fix = fix or {}
    rng = random.Random(9)
    lights(sun_az=-30, rim=(4, 12, 9), rim_target=(0, 0, 3), rim_k=1800)
    sea()
    fig, ra, la = minifig("Hero", legs_on=False)
    fig.location = (0, 0, 0.0)
    fig.rotation_euler = (0, 0, math.radians(-10))
    fist = thumbs_up(ra)
    bpy.context.view_layer.update()
    aim(ra, fig.matrix_world @ Vector((-2.3, -1.4, 2.6)))
    upright(fist, math.radians(-10))
    aim(la, fig.matrix_world @ Vector((1.3, -0.5, -1.0)))
    cam_target = Vector((0, 0, 2.2))
    camera(cam_target, 0, fix.get("el", 4), fix.get("dist", 11.5), lens=fix.get("lens", 45))
    cam = bpy.context.scene.camera
    # lifebuoy just in front of the hero, facing the camera, filling the frame
    lb = empty("Buoy", cam.location.lerp(cam_target, 0.42))
    lb.rotation_euler = cam.rotation_euler
    lifebuoy(lb, (0, 0, 0), (0, 0, math.radians(12)), R=fix.get("buoy_R", 1.95), r=0.62, bands=8)
    heli = helicopter("Heli")
    heli.location = fix.get("heli", (3.5, 34, 6.5))
    heli.scale = (1.1,) * 3
    heli.rotation_euler = (math.radians(-6), math.radians(8), math.radians(-70))
    isl = island("Island", (-12, 46, -0.2), n=12, rot=math.radians(15))
    tower(isl, 1.0, 1.0, 0.98)
    palm(isl, -3.0, -2.5, 0.98)
    cloud((18, 110, 30), 3.0)


def at_screen(cam, dist, dx, dy):
    """World point `dist` in front of the camera, offset dx/dy (tan units) right/up."""
    return cam.location + cam.matrix_world.to_3x3() @ Vector((dx * dist, dy * dist, -dist))


def scene_final(fix=None):
    """C after the art-director round: hero rides the jet ski (bow + splash in front), 1.2x, thumbs up beside the
    face, heli banked inside the hole with rotor blur, tilted roped buoy, warm key + cool rim, light DOF."""
    rng = random.Random(9)
    world_sky(top=(0.01, 0.09, 0.7), horizon=(0.18, 0.52, 1.0), light=0.6)
    sun(48, -30, 4.2)
    area((5, 12, 9), (0, 0, 3.5), 4000, size=6.0)
    area((-6, -7, 8), (0, 0, 4.0), 1100, size=3.0, color=(1.0, 0.84, 0.62))
    sea(color=(0.0, 0.52, 0.42))
    ski = jetski("Ski")
    ski.location = (0, 0, 0.35)
    ski.rotation_euler = (math.radians(-7), math.radians(5), math.radians(18))
    fig, ra, la = minifig("Hero", seated=True)
    fig.parent = ski
    fig.location, fig.rotation_euler = (0, 1.25, 1.95), (math.radians(6), 0, 0)
    fist = thumbs_up(ra)
    bpy.context.view_layer.update()
    head = next(c for c in fig.children if c.name.startswith("Head")).matrix_world.translation.copy()
    aim(la, ski.matrix_world @ Vector((0.95, 0.05, 2.15)))
    aim(ra, head + Vector((-1.35, -0.7, 0.05)))
    upright(fist, math.radians(-15))
    spray(ski, (0.85, -1.9, 0.0), 1, rng, n=90, up=0.85)
    spray(ski, (-0.85, -1.9, 0.0), -1, rng, n=110, up=0.9)
    mw = ski.matrix_world
    for sx in (-1, 1):
        for y in np.linspace(-2.6, 3.0, 14):
            q = mw @ Vector((sx * (1.35 - 0.5 * max(0, -y - 0.6) / 3.0), y, 0))
            droplet((q.x, q.y, 0.03), rng.uniform(0.3, 0.45), foam_mats()[0]).scale.z *= 0.3
    # the hole can't hold a 1.2x hero AND the ski, so the face sits a little above centre and the cowl + spray show
    D = 12.5
    cam = camera(head - Vector((0, 0, 1.8)), 0, 10, D, lens=45)
    cam.data.dof.use_dof, cam.data.dof.focus_distance, cam.data.dof.aperture_fstop = True, D, 1.8
    lb = empty("Buoy", cam.location.lerp(head - Vector((0, 0, 1.8)), 0.42), scale=D / 11.5)
    lb.rotation_euler = cam.rotation_euler
    lifebuoy(lb, (0, 0, 0), (math.radians(10), math.radians(-12), math.radians(12)), R=2.1, r=0.52, rough=0.15,
             rope=True)
    heli = helicopter("Heli", rotor_blur=True)
    heli.location = at_screen(cam, 80, 0.15, 0.22)
    heli.scale = (1.45,) * 3
    heli.rotation_euler = (math.radians(-8), math.radians(15), math.radians(-70))
    d = cam.matrix_world.to_3x3() @ Vector((-0.2, 0.08, -1))
    p = cam.location - d * (cam.location.z / d.z)  # where that view ray meets the sea
    isl = island("Island", (p.x, p.y, -0.2), n=12, rot=math.radians(15))
    tower(isl, 1.0, 1.0, 0.98)
    palm(isl, -3.0, -2.5, 0.98)
    cloud((18, 110, 30), 3.0)


def grade(px):
    """+15% saturation, a touch of contrast, soft vignette (art-director round)."""
    lum = (px @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
    px = lum + (px - lum) * 1.15
    px = 0.5 + (px - 0.5) * 1.06
    h, w, _ = px.shape
    y, x = np.mgrid[0:h, 0:w]
    d = np.hypot((x - w / 2) / (w / 2), (y - h / 2) / (h / 2))
    px = px * (1 - 0.2 * np.clip((d - 0.55) / 0.85, 0, 1) ** 2)[..., None]
    return np.clip(px, 0, 1).astype(np.float32)


SCENES = {"A": scene_A, "B": scene_B, "C": scene_C, "final": scene_final}


def render(key, fn, fix=None):
    reset()
    _mats.clear()
    _drop.clear()
    fn(fix)
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(RAW, key + ".png")
    bpy.ops.render.render(write_still=True)
    print("[icon] rendered", key, flush=True)


def load_rgb(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, :3]
    bpy.data.images.remove(im)
    return px


def save_rgb(px, path):
    h, w, _ = px.shape
    im = bpy.data.images.new("out", w, h, alpha=False)
    im.pixels.foreach_set(np.concatenate([px, np.ones((h, w, 1), np.float32)], 2).ravel())
    im.filepath_raw, im.file_format = path, "PNG"
    im.save()
    bpy.data.images.remove(im)


def downsample(key):
    px = load_rgb(os.path.join(RAW, key + ".png"))
    h, w, _ = px.shape
    px = px.reshape(h // 2, 2, w // 2, 2, 3).mean(axis=(1, 3))
    if key == "final":
        px = grade(px)
    save_rgb(px, os.path.join(OUT, "icon_%s.png" % key))


def sheet():
    tiles = [load_rgb(os.path.join(OUT, "icon_%s.png" % k)) for k in "ABC"]
    gap = np.ones((tiles[0].shape[0], 16, 3), np.float32)
    save_rgb(np.concatenate([tiles[0], gap, tiles[1], gap, tiles[2]], 1), os.path.join(OUT, "_sheet.png"))


if __name__ == "__main__":
    os.makedirs(RAW, exist_ok=True)
    for k in KEYS:
        render(k, SCENES[k])
        downsample(k)
    if "--sheet" in argv:
        sheet()
