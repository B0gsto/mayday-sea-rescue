"""Blender half of tools/make-item-icons.py: one photoreal Cycles render per Robux item.

    tools/blender-run.sh tools/item_icons_blender.py -- <texdir> <outdir> <size> <samples> Key,Key,...

Scenes use the real in-game source assets where one exists (RIB and jet ski high-poly with their shader materials,
Bosun and the North cardinal buoy with their baked PBR maps) and otherwise clean modelled product shots (banknote
bundles, brass stopwatch, logbook, horns, beacon, light bar, radio, crew card). Textures for the procedural props
(banknote face, band, dial, card) are painted by make-item-icons.py into <texdir> before this runs.
"""
import math
import os
import random
import sys

import bpy
from mathutils import Euler, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "source")
TEXROOT = os.path.join(ROOT, "assets", "textures")
HDRI = os.path.join(ROOT, "art", "blender", "hdri")
argv = sys.argv[sys.argv.index("--") + 1:]
TEX, OUT, SIZE, SAMPLES, KEYS = argv[0], argv[1], int(argv[2]), int(argv[3]), argv[4].split(",")


# ------------------------------------------------------------------ scene basics
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
        print("[icons] GPU unavailable:", e)
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 8
    sc.cycles.transmission_bounces = 8
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    return sc


def node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def mat(name, color=(0.8, 0.8, 0.8), rough=0.5, metal=0.0, emit=None, emit_strength=0.0, transmission=0.0,
        coat=0.0, ior=1.45, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["IOR"].default_value = ior
    b.inputs["Transmission Weight"].default_value = transmission
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Alpha"].default_value = alpha
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = emit_strength
    return m


def bsdf(m):
    return m.node_tree.nodes["Principled BSDF"]


def image_mat(name, path, rough=0.5, metal=0.0, bump=0.0, coat=0.0):
    m = mat(name, rough=rough, metal=metal, coat=coat)
    nt = m.node_tree
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(path, check_existing=True)
    t.extension = "EXTEND"
    nt.links.new(t.outputs["Color"], bsdf(m).inputs["Base Color"])
    if bump:
        bm = node(nt, "ShaderNodeBump", Strength=bump, Distance=0.0005)
        nt.links.new(t.outputs["Color"], bm.inputs["Height"])
        nt.links.new(bm.outputs["Normal"], bsdf(m).inputs["Normal"])
    return m


def add_noise_bump(m, scale=200.0, strength=0.15, dist=0.0003):
    nt = m.node_tree
    n = node(nt, "ShaderNodeTexNoise", Scale=scale, Detail=8.0)
    bm = node(nt, "ShaderNodeBump", Strength=strength, Distance=dist)
    nt.links.new(n.outputs["Fac"], bm.inputs["Height"])
    nt.links.new(bm.outputs["Normal"], bsdf(m).inputs["Normal"])


def obj_from(prim, name, m=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), bevel=0.0, smooth=False, **kw):
    getattr(bpy.ops.mesh, "primitive_%s_add" % prim)(location=loc, rotation=rot, **kw)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bv = o.modifiers.new("Bevel", "BEVEL")
        bv.width, bv.segments, bv.limit_method = bevel, 3, "ANGLE"
    if smooth:
        bpy.ops.object.shade_smooth()
    if m:
        o.data.materials.append(m)
    return o


def world_hdri(fname, strength=1.0, rot=0.0, cam_color=None, cam_strength=1.0, sky=None):
    """HDRI lights the scene; the camera sees `cam_color` (flat), `sky` (procedural storm sky) or the HDRI."""
    w = bpy.data.worlds.new("W")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0, 0, math.radians(rot))
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(os.path.join(HDRI, fname), check_existing=True)
    nt.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], env.inputs["Vector"])
    light = node(nt, "ShaderNodeBackground", Strength=strength)
    nt.links.new(env.outputs["Color"], light.inputs["Color"])
    if cam_color is None and sky is None:
        nt.links.new(light.outputs["Background"], out.inputs["Surface"])
        return
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    seen = nt.nodes.new("ShaderNodeBackground")
    seen.inputs["Strength"].default_value = cam_strength
    if sky is not None:
        top, horizon, cloud = sky
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.0, (*horizon, 1)
        ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.45, (*top, 1)
        nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
        noise = node(nt, "ShaderNodeTexNoise", Scale=2.2, Detail=12.0, Roughness=0.62)
        nt.links.new(tc.outputs["Generated"], noise.inputs["Vector"])
        cr = nt.nodes.new("ShaderNodeValToRGB")
        cr.color_ramp.elements[0].position, cr.color_ramp.elements[0].color = 0.38, (0.25, 0.25, 0.25, 1)
        cr.color_ramp.elements[1].position, cr.color_ramp.elements[1].color = 0.72, (*cloud, 1)
        nt.links.new(noise.outputs["Fac"], cr.inputs["Fac"])
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type, mul.blend_type = "RGBA", "MULTIPLY"
        mul.inputs["Factor"].default_value = 1.0
        nt.links.new(ramp.outputs["Color"], mul.inputs["A"])
        nt.links.new(cr.outputs["Color"], mul.inputs["B"])
        nt.links.new(mul.outputs["Result"], seen.inputs["Color"])
    else:
        seen.inputs["Color"].default_value = (*cam_color, 1)
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(light.outputs["Background"], mix.inputs[1])
    nt.links.new(seen.outputs["Background"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def area(name, loc, target, power, size=1.0, color=(1, 1, 1)):
    d = bpy.data.lights.new(name, "AREA")
    d.energy, d.size, d.color = power, size, color
    o = bpy.data.objects.new(name, d)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.visible_camera = False
    look(o, Vector(target))
    return o


def sun(angle_deg_el, az_deg, strength, color=(1, 1, 1), soft=2.0):
    d = bpy.data.lights.new("Sun", "SUN")
    d.energy, d.color, d.angle = strength, color, math.radians(soft)
    o = bpy.data.objects.new("Sun", d)
    bpy.context.collection.objects.link(o)
    o.rotation_euler = Euler((math.radians(90 - angle_deg_el), 0, math.radians(az_deg)))
    return o


def look(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()


def camera(target, az, el, dist, lens=50.0, fstop=None, focus=None):
    c = bpy.data.cameras.new("Cam")
    c.lens = lens
    c.sensor_width = 36
    o = bpy.data.objects.new("Cam", c)
    bpy.context.collection.objects.link(o)
    a, e = math.radians(az), math.radians(el)
    t = Vector(target)
    o.location = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    look(o, t)
    if fstop:
        c.dof.use_dof = True
        c.dof.aperture_fstop = fstop
        c.dof.focus_distance = focus or dist
    bpy.context.scene.camera = o
    return o


def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def fit_dist(objs, lens, fill=0.92):
    lo, hi = bbox(objs)
    r = (hi - lo).length / 2
    half = math.atan(18.0 / lens)
    return r / math.sin(half) / fill * 0.62


def frame(objs, az, el, lens=50.0, fill=0.94, fstop=None, target=None, lift=0.0):
    """Camera at (az, el) looking at the objects' bbox centre, pulled back until every bbox corner sits inside
    the central `fill` share of the frame."""
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    lo, hi = bbox(objs)
    pts = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    t = Vector(target) if target else (lo + hi) / 2 + Vector((0, 0, lift * (hi.z - lo.z)))
    cam = camera(t, az, el, 1.0, lens=lens)
    d = (cam.location - t).normalized()
    sc = bpy.context.scene
    a, b = 0.01, (hi - lo).length * 200
    for _ in range(40):
        mid = (a + b) / 2
        cam.location = t + d * mid
        bpy.context.view_layer.update()
        ok = all(v.z > 0 and abs(v.x - 0.5) <= fill / 2 and abs(v.y - 0.5) <= fill / 2
                 for v in (world_to_camera_view(sc, cam, p) for p in pts))
        a, b = (a, mid) if ok else (mid, b)
    cam.location = t + d * b
    if fstop:
        cam.data.dof.use_dof = True
        cam.data.dof.aperture_fstop = fstop
        cam.data.dof.focus_distance = b
    return cam


def frame_tight(objs, az, el, lens=50.0, fill=0.94, fstop=None, max_pts=40000):
    """Like frame() but fits the evaluated mesh vertices (not bbox corners) and re-centres on them, so flat-lays
    and groups of characters fill the square instead of floating in the middle of their bounding box."""
    import numpy as np
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    chunks = []
    for o in objs:
        if o.type not in ("MESH", "CURVE"):
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        if me is None:
            continue
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        mw = np.array(o.matrix_world)
        chunks.append(co @ mw[:3, :3].T + mw[:3, 3])
        ev.to_mesh_clear()
    P = np.concatenate(chunks)
    if len(P) > max_pts:
        P = P[:: len(P) // max_pts + 1]
    t = Vector(((P.min(0) + P.max(0)) / 2).tolist())
    cam = camera(t, az, el, 1.0, lens=lens)
    bpy.context.view_layer.update()
    d = (cam.location - t).normalized()
    R = np.array(cam.matrix_world.to_3x3())
    lim = math.tan(math.atan(18.0 / lens)) * fill
    D = 1.0
    for _ in range(3):
        a, b = 0.01, float(np.ptp(P, 0).max()) * 200
        for _ in range(50):
            mid = (a + b) / 2
            pc = (P - np.array(t + d * mid)) @ R
            ok = (pc[:, 2] < 0).all() and (np.abs(pc[:, :2] / -pc[:, 2:3]) <= lim).all()
            a, b = (a, mid) if ok else (mid, b)
        D = b
        pc = (P - np.array(t + d * D)) @ R
        sx, sy = pc[:, 0] / -pc[:, 2], pc[:, 1] / -pc[:, 2]
        cx, cy = (sx.min() + sx.max()) / 2, (sy.min() + sy.max()) / 2
        right, up = cam.matrix_world.to_3x3() @ Vector((1, 0, 0)), cam.matrix_world.to_3x3() @ Vector((0, 1, 0))
        t = t + right * (cx * D) + up * (cy * D)
    cam.location = t + d * D
    if fstop:
        cam.data.dof.use_dof = True
        cam.data.dof.aperture_fstop = fstop
        cam.data.dof.focus_distance = D
    return cam


def float_on(sea, empty, objs, draft=0.25, follow=0.8):
    """Sit `empty` on the evaluated ocean surface under its footprint and pitch/roll it with the local slope."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = sea.evaluated_get(dg)
    me = ev.to_mesh()
    lo, hi = bbox(objs)
    pts = [sea.matrix_world @ v.co for v in me.vertices]
    pts = [p for p in pts if lo.x <= p.x <= hi.x and lo.y <= p.y <= hi.y]
    ev.to_mesh_clear()
    if len(pts) < 4:
        return
    n = len(pts)
    mx, my, mz = (sum(p.x for p in pts) / n, sum(p.y for p in pts) / n, sum(p.z for p in pts) / n)
    sxx = sum((p.x - mx) ** 2 for p in pts) or 1e-6
    syy = sum((p.y - my) ** 2 for p in pts) or 1e-6
    gx = sum((p.x - mx) * (p.z - mz) for p in pts) / sxx
    gy = sum((p.y - my) * (p.z - mz) for p in pts) / syy
    empty.location.z += mz - (lo.z + draft * (hi.z - lo.z))
    r = empty.rotation_euler
    empty.rotation_euler = (r.x + math.atan(gy) * follow, r.y - math.atan(gx) * follow, r.z)
    bpy.context.view_layer.update()


def render(key):
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(OUT, key + ".png")
    bpy.ops.render.render(write_still=True)
    print("[icons] rendered", key, flush=True)


# ------------------------------------------------------------------ real assets
def append_objects(blend, pred):
    with bpy.data.libraries.load(blend, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if pred(n)]
    objs = []
    for o in dst.objects:
        if o is None:
            continue
        bpy.context.collection.objects.link(o)
        o.parent = None
        for m in list(o.modifiers):
            if m.type == "ARMATURE":
                o.modifiers.remove(m)
        o.hide_render = o.hide_viewport = False
        objs.append(o)
    return objs


def group(objs, name):
    """Parent `objs` to an empty at their bottom centre; returns the empty (move/rotate that)."""
    lo, hi = bbox(objs)
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    bpy.context.view_layer.update()
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = e
        o.matrix_parent_inverse = e.matrix_world.inverted()
        o.matrix_world = mw
    return e


def vehicle(kind):
    blend = os.path.join(SRC, "vehicles", kind, kind + ".blend")
    objs = append_objects(blend, lambda n: n.startswith(kind + "_") and n.endswith("_HP"))
    return group(objs, kind), objs


def pbr_from_maps(o, asset, tint=None):
    """Replace MI_<Short>_<Set> materials with the baked T_<Short>_<Set>_<ALB|NOR|RGH|MET> maps."""
    for i, m in enumerate(o.data.materials):
        if not m or not m.name.startswith("MI_"):
            continue
        stem = "T_" + m.name[3:].split(".")[0] + "_"
        d = os.path.join(TEXROOT, asset)
        if not os.path.exists(os.path.join(d, stem + "ALB.png")):  # e.g. Bosun's fur/harness maps live with the source
            for folder in os.listdir(SRC):
                sd = os.path.join(SRC, folder, asset, "textures")
                if os.path.exists(os.path.join(sd, stem + "ALB.png")):
                    d = sd
                    break
        p = lambda k: os.path.join(d, stem + k + ".png")
        if not os.path.exists(p("ALB")):  # kits share one atlas: T_<Short>_Atlas_*
            stem = "T_" + m.name[3:].split(".")[0].split("_")[0] + "_Atlas_"
        if not os.path.exists(p("ALB")):
            print("[icons] no maps for", m.name)
            continue
        nm = bpy.data.materials.new(m.name + "_icon")
        nm.use_nodes = True
        nt = nm.node_tree
        b = nt.nodes["Principled BSDF"]
        alb = nt.nodes.new("ShaderNodeTexImage")
        alb.image = bpy.data.images.load(p("ALB"), check_existing=True)
        col = alb.outputs["Color"]
        if tint:
            hsv = node(nt, "ShaderNodeHueSaturation", Hue=tint[0], Saturation=tint[1], Value=tint[2], Fac=1.0)
            nt.links.new(col, hsv.inputs["Color"])
            col = hsv.outputs["Color"]
        nt.links.new(col, b.inputs["Base Color"])
        nt.links.new(alb.outputs["Alpha"], b.inputs["Alpha"])
        for k, inp in (("RGH", "Roughness"), ("MET", "Metallic")):
            if os.path.exists(p(k)):
                t = nt.nodes.new("ShaderNodeTexImage")
                t.image = bpy.data.images.load(p(k), check_existing=True)
                t.image.colorspace_settings.name = "Non-Color"
                nt.links.new(t.outputs["Color"], b.inputs[inp])
        if os.path.exists(p("NOR")):
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = bpy.data.images.load(p("NOR"), check_existing=True)
            t.image.colorspace_settings.name = "Non-Color"
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(t.outputs["Color"], nmap.inputs["Color"])
            nt.links.new(nmap.outputs["Normal"], b.inputs["Normal"])
        o.data.materials[i] = nm


def lod0_asset(folder, asset, tint=None):
    blend = os.path.join(SRC, folder, asset, asset + ".blend")
    objs = append_objects(blend, lambda n: n.startswith(asset + "_") and n.endswith("_LOD0"))
    for o in objs:
        pbr_from_maps(o, asset, tint)
    return group(objs, asset), objs


def recolor(objs, names, color):
    """Set the base colour of the named HP shader materials (livery variants)."""
    for o in objs:
        for m in o.data.materials:
            if m and m.name.split(".")[0] in names and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "BSDF_PRINCIPLED":
                        sock = n.inputs["Base Color"]
                        for l in list(sock.links):
                            m.node_tree.links.remove(l)
                        sock.default_value = (*color, 1)
                    elif n.type == "RGB":
                        n.outputs[0].default_value = (*color, 1)


# ------------------------------------------------------------------ environments
def ocean(size=400.0, wave=1.0, chop=1.0, wind=10.0, res=14, color=(0.004, 0.018, 0.022), seed=7, foam=0.6,
          foam_color=(0.75, 0.8, 0.8), foam_rough=0.6):
    bpy.ops.mesh.primitive_plane_add(size=2)
    o = bpy.context.active_object
    o.name = "Ocean"
    md = o.modifiers.new("Ocean", "OCEAN")
    md.geometry_mode = "GENERATE"
    md.size = 1.0
    md.spatial_size = int(size)
    md.resolution = res
    md.wave_scale = wave
    md.choppiness = chop
    md.wind_velocity = wind
    md.random_seed = seed
    md.use_normals = True
    md.use_foam = True
    md.foam_coverage = foam
    md.foam_layer_name = "foam"
    bpy.ops.object.shade_smooth()
    m = mat("Water", color=color, rough=0.035, ior=1.333)
    nt = m.node_tree
    b = bsdf(m)
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "foam"
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.15
    ramp.color_ramp.elements[1].position = 0.7
    nz = node(nt, "ShaderNodeTexNoise", Scale=0.9, Detail=10.0)
    mulf = nt.nodes.new("ShaderNodeMath")
    mulf.operation = "MULTIPLY"
    nt.links.new(attr.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mulf.inputs[0])
    nt.links.new(nz.outputs["Fac"], mulf.inputs[1])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*color, 1)
    mix.inputs["B"].default_value = (*foam_color, 1)
    nt.links.new(mulf.outputs["Value"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    rmix = nt.nodes.new("ShaderNodeMapRange")
    rmix.inputs["To Min"].default_value = 0.035
    rmix.inputs["To Max"].default_value = foam_rough
    nt.links.new(mulf.outputs["Value"], rmix.inputs["Value"])
    nt.links.new(rmix.outputs["Result"], b.inputs["Roughness"])
    o.data.materials.append(m)
    return o


def wood_table(size=3.0, z=0.0, tone=(0.085, 0.042, 0.02)):
    """Oiled oak planks: fine grain along X, per-plank tone, plank seams."""
    m = mat("Oak", color=tone, rough=0.38, coat=0.2)
    nt = m.node_tree
    b = bsdf(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    grain = node(nt, "ShaderNodeTexWave", Scale=70.0, Distortion=3.5, Detail=4.0, **{"Detail Scale": 1.5})
    grain.bands_direction = "Y"
    nt.links.new(tc.outputs["Object"], grain.inputs["Vector"])
    fmap = nt.nodes.new("ShaderNodeMapping")
    fmap.inputs["Scale"].default_value = (6.0, 160.0, 6.0)
    nt.links.new(tc.outputs["Object"], fmap.inputs["Vector"])
    fib = node(nt, "ShaderNodeTexNoise", Scale=4.0, Detail=8.0)
    nt.links.new(fmap.outputs["Vector"], fib.inputs["Vector"])
    brick = node(nt, "ShaderNodeTexBrick", Scale=1.0, **{"Mortar Size": 0.0025, "Mortar Smooth": 0.3, "Brick Width": 1.6,
                                                          "Row Height": 0.14, "Color1": (1.0, 1.0, 1.0, 1), "Color2": (0.62, 0.6, 0.58, 1),
                                                          "Mortar": (0.25, 0.25, 0.25, 1)})
    brick.offset = 0.37
    nt.links.new(tc.outputs["Object"], brick.inputs["Vector"])
    g = nt.nodes.new("ShaderNodeMath")
    g.operation = "MULTIPLY_ADD"
    g.inputs[1].default_value = 0.6
    nt.links.new(grain.outputs["Fac"], g.inputs[0])
    nt.links.new(fib.outputs["Fac"], g.inputs[2])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[1].position = 0.35, 1.25
    ramp.color_ramp.elements[0].color = (tone[0] * 0.55, tone[1] * 0.5, tone[2] * 0.45, 1)
    ramp.color_ramp.elements[1].color = (tone[0] * 1.6, tone[1] * 1.55, tone[2] * 1.4, 1)
    nt.links.new(g.outputs["Value"], ramp.inputs["Fac"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type, mul.blend_type = "RGBA", "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(ramp.outputs["Color"], mul.inputs["A"])
    nt.links.new(brick.outputs["Color"], mul.inputs["B"])
    nt.links.new(mul.outputs["Result"], b.inputs["Base Color"])
    h = nt.nodes.new("ShaderNodeMath")
    h.operation = "MULTIPLY_ADD"
    h.inputs[1].default_value = 0.08
    nt.links.new(fib.outputs["Fac"], h.inputs[0])
    nt.links.new(brick.outputs["Fac"], h.inputs[2])
    bm = node(nt, "ShaderNodeBump", Strength=0.4, Distance=0.002)
    nt.links.new(h.outputs["Value"], bm.inputs["Height"])
    nt.links.new(bm.outputs["Normal"], b.inputs["Normal"])
    return obj_from("plane", "Table", m, loc=(0, 0, z), size=size)


def backdrop(color=(0.05, 0.055, 0.06), rough=0.55, size=6.0):
    """Curved studio sweep."""
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = "Sweep"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=24)
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in o.data.vertices:
        y = v.co.y
        if y > 0.2 * size / 2:
            t = (y - 0.2 * size / 2) / (0.8 * size / 2)
            v.co.z = (t ** 2) * size * 0.45
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat("Sweep", color=color, rough=rough))
    return o


# ------------------------------------------------------------------ props
def banknote_mats():
    face = image_mat("NoteFace", os.path.join(TEX, "note_face.png"), rough=0.75, bump=0.02)
    edge = mat("NoteEdge", color=(0.70, 0.74, 0.66), rough=0.85)
    nt = edge.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    w = node(nt, "ShaderNodeTexWave", Scale=180.0, Distortion=1.5, Detail=2.0)
    w.bands_direction = "Z"
    nt.links.new(tc.outputs["Object"], w.inputs["Vector"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].color = (0.40, 0.46, 0.40, 1)
    r.color_ramp.elements[1].color = (0.78, 0.81, 0.72, 1)
    nt.links.new(w.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], bsdf(edge).inputs["Base Color"])
    band = image_mat("NoteBand", os.path.join(TEX, "band.png"), rough=0.6)
    return face, edge, band


NOTE = (0.156, 0.068)


def bundle(mats, loc, rot_z=0.0, h=0.012, band=True, tilt=(0.0, 0.0)):
    face, edge, bandm = mats
    parts = []
    body = obj_from("cube", "Stack", edge, loc=(0, 0, h / 2), scale=(NOTE[0] / 2 * 0.995, NOTE[1] / 2 * 0.99, h / 2 - 0.0004), bevel=0.0006)
    parts.append(body)
    top = obj_from("plane", "Face", face, loc=(0, 0, h + 0.0001), scale=(NOTE[0] / 2, NOTE[1] / 2, 1), size=2)
    parts.append(top)
    bot = obj_from("plane", "FaceB", face, loc=(0, 0, 0.0001), rot=(math.pi, 0, 0), scale=(NOTE[0] / 2, NOTE[1] / 2, 1), size=2)
    parts.append(bot)
    if band:
        bd = obj_from("cube", "Band", bandm, loc=(0, 0, h / 2), scale=(0.019, NOTE[1] / 2 + 0.0008, h / 2 + 0.0007), bevel=0.0004)
        # box UVs: project the band texture across the whole strap
        parts.append(bd)
    e = bpy.data.objects.new("Bundle", None)
    bpy.context.collection.objects.link(e)
    for p in parts:
        p.parent = e
    e.location = loc
    e.rotation_euler = (tilt[0], tilt[1], rot_z)
    return e, parts


def loose_note(mats, loc, rot, bend=0.15):
    face = mats[0]
    o = obj_from("plane", "Note", face, loc=(0, 0, 0), scale=(NOTE[0] / 2, NOTE[1] / 2, 1), size=2)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=12)
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in o.data.vertices:
        v.co.z = bend * 0.02 * math.sin((v.co.x / NOTE[0] + 0.5) * math.pi) + 0.0015 * math.sin(v.co.y * 90)
    sol = o.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = 0.0002
    o.location, o.rotation_euler = loc, rot
    bpy.ops.object.shade_smooth()
    return o


def cash_lighting(warm=True):
    world_hdri("studio_small_08_2k.hdr", strength=0.35, cam_color=(0.02, 0.018, 0.016))
    area("Key", (-0.55, -0.45, 0.75), (0, 0, 0.02), 16, size=0.6, color=(1.0, 0.93, 0.82) if warm else (1, 1, 1))
    area("Rim", (0.5, 0.55, 0.35), (0, 0, 0.02), 9, size=0.4, color=(0.8, 0.88, 1.0))
    area("Fill", (0.6, -0.5, 0.25), (0, 0, 0.02), 1.5, size=1.0)


def meshes(*empties):
    return [c for e in empties for c in ([e] + list(e.children_recursive)) if c.type in ("MESH", "CURVE")]


def cash_scene(layout, az=24, el=36, lens=70, fill=0.92, fstop=4.0, extra=None, jitter=0.0):
    reset()
    wood_table()
    mats = banknote_mats()
    rng = random.Random(4)
    subjects = []
    for (x, y, z, rz) in layout:
        e, _ = bundle(mats, (x + rng.uniform(-jitter, jitter), y + rng.uniform(-jitter, jitter), z),
                      rz + rng.uniform(-0.04, 0.04) + rng.uniform(-jitter, jitter) * 8)
        subjects.append(e)
    if extra:
        subjects += [o for o in (extra(mats) or [])]
    cash_lighting()
    frame(meshes(*subjects), az, el, lens=lens, fill=fill, fstop=fstop)


def pyramid(nx, ny, layers, h=0.0125, gap=(0.004, 0.003)):
    out = []
    for L in range(layers):
        cx, cy = nx - L, ny - L if ny - L > 0 else 1
        cy = max(cy, 1)
        for i in range(max(cx, 1)):
            for j in range(cy):
                x = (i - (max(cx, 1) - 1) / 2) * (NOTE[0] + gap[0])
                y = (j - (cy - 1) / 2) * (NOTE[1] + gap[1])
                out.append((x, y, L * h, 0.0))
    return out


def stopwatch(loc, rot=(0, 0, 0), r=0.032):
    brass = mat("Brass", color=(0.82, 0.62, 0.32), rough=0.22, metal=1.0)
    add_noise_bump(brass, 400, 0.05)
    chrome = mat("Steel", color=(0.85, 0.85, 0.86), rough=0.12, metal=1.0)
    face = image_mat("Dial", os.path.join(TEX, "dial.png"), rough=0.35)
    glass = mat("Glass", color=(1, 1, 1), rough=0.0, transmission=1.0, ior=1.5)
    parts = [
        obj_from("cylinder", "Case", brass, vertices=96, radius=r, depth=r * 0.38, loc=(0, 0, r * 0.19), bevel=r * 0.08, smooth=True),
        obj_from("cylinder", "Face", face, vertices=96, radius=r * 0.86, depth=0.0004, loc=(0, 0, r * 0.385)),
        obj_from("uv_sphere", "Crystal", glass, segments=64, ring_count=24, radius=r * 0.9, loc=(0, 0, r * 0.33), scale=(1, 1, 0.13), smooth=True),
        obj_from("cylinder", "Stem", brass, vertices=32, radius=r * 0.12, depth=r * 0.32, loc=(0, r * 1.1, r * 0.19), rot=(math.pi / 2, 0, 0), smooth=True),
        obj_from("cylinder", "Crown", chrome, vertices=32, radius=r * 0.2, depth=r * 0.18, loc=(0, r * 1.33, r * 0.19), rot=(math.pi / 2, 0, 0), bevel=r * 0.03, smooth=True),
        obj_from("torus", "Bow", brass, major_radius=r * 0.3, minor_radius=r * 0.06, loc=(0, r * 1.6, r * 0.19), rot=(0, 0, 0), smooth=True),
    ]
    # hands (start at 12, sweep to 10 o'clock = 50 s)
    black = mat("Hand", color=(0.02, 0.02, 0.02), rough=0.4)
    red = mat("HandRed", color=(0.6, 0.03, 0.02), rough=0.4)
    h1 = obj_from("cube", "HandSec", red, loc=(0, r * 0.32, r * 0.392), scale=(r * 0.018, r * 0.62, 0.0003))
    h2 = obj_from("cube", "HandMin", black, loc=(0, r * 0.2, r * 0.390), scale=(r * 0.03, r * 0.38, 0.0003))
    pin = obj_from("cylinder", "Pin", brass, vertices=24, radius=r * 0.06, depth=r * 0.02, loc=(0, 0, r * 0.395))
    piv = bpy.data.objects.new("Pivot", None)
    bpy.context.collection.objects.link(piv)
    for p in (h1, h2):
        p.parent = piv
    piv.rotation_euler = (0, 0, math.radians(60))
    e = bpy.data.objects.new("Stopwatch", None)
    bpy.context.collection.objects.link(e)
    for p in parts + [pin, piv]:
        p.parent = e
    e.location, e.rotation_euler = loc, rot
    return e


def lightning(start, end, seed=1, strength=60.0, width=0.08, branches=3, color=(0.75, 0.82, 1.0), glow=0.0):
    rng = random.Random(seed)
    m = mat("Bolt", color=(0, 0, 0), rough=1, emit=color, emit_strength=strength)
    halo = None
    if glow:  # soft ionised-air halo: a fat, mostly transparent emissive sleeve round the channel
        halo = bpy.data.materials.new("BoltHalo")
        halo.use_nodes = True
        nt = halo.node_tree
        nt.nodes.clear()
        o_ = nt.nodes.new("ShaderNodeOutputMaterial")
        em = node(nt, "ShaderNodeEmission", Color=(*color, 1), Strength=strength * glow)
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        lw = nt.nodes.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.35
        mx = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(lw.outputs["Facing"], mx.inputs["Fac"])
        nt.links.new(em.outputs["Emission"], mx.inputs[1])
        nt.links.new(tr.outputs["BSDF"], mx.inputs[2])
        nt.links.new(mx.outputs["Shader"], o_.inputs["Surface"])

    def path(a, b, depth):
        pts = [Vector(a), Vector(b)]
        disp = (Vector(b) - Vector(a)).length * 0.18
        for _ in range(depth):
            new = [pts[0]]
            for p, q in zip(pts, pts[1:]):
                mid = (p + q) / 2 + Vector((rng.uniform(-1, 1) * disp, rng.uniform(-1, 1) * disp * 0.3, 0))
                new += [mid, q]
            pts = new
            disp *= 0.55
        return pts

    def curve(pts, w):
        cd = bpy.data.curves.new("Bolt", "CURVE")
        cd.dimensions, cd.bevel_depth, cd.bevel_resolution = "3D", w, 2
        sp = cd.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for i, p in enumerate(pts):
            sp.points[i].co = (*p, 1)
            sp.points[i].radius = 1.0 - 0.6 * i / len(pts)
        o = bpy.data.objects.new("Bolt", cd)
        bpy.context.collection.objects.link(o)
        o.data.materials.append(m)
        o.visible_shadow = False
        return o

    main = path(start, end, 6)
    curve(main, width)
    if halo:
        h = curve(main, width * 7)
        h.data.materials[0] = halo
        h.visible_diffuse = h.visible_glossy = False
    for i in range(branches):
        k = rng.randint(len(main) // 5, len(main) * 3 // 4)
        a = main[k]
        b = a + Vector((rng.uniform(-1, 1) * 0.35, 0, -rng.uniform(0.2, 0.4))) * (Vector(start) - Vector(end)).length
        curve(path(a, b, 5), width * 0.45)


def logbook(loc, rot_z=0.0, open_=False):
    leather = mat("Leather", color=(0.035, 0.05, 0.09), rough=0.55, coat=0.15)
    add_noise_bump(leather, 260, 0.35, 0.0004)
    pages = mat("Pages", color=(0.86, 0.82, 0.7), rough=0.8)
    nt = pages.node_tree
    w = node(nt, "ShaderNodeTexWave", Scale=600.0)
    w.bands_direction = "Z"
    bm = node(nt, "ShaderNodeBump", Strength=0.3)
    nt.links.new(w.outputs["Fac"], bm.inputs["Height"])
    nt.links.new(bm.outputs["Normal"], bsdf(pages).inputs["Normal"])
    brass = mat("BrassC", color=(0.8, 0.6, 0.3), rough=0.3, metal=1.0)
    gold = image_mat("Emboss", os.path.join(TEX, "logbook_cover.png"), rough=0.5, coat=0.15)
    W, D, H = 0.21, 0.29, 0.034
    parts = [
        obj_from("cube", "CoverB", leather, loc=(0, 0, 0.002), scale=(W / 2, D / 2, 0.002), bevel=0.0015),
        obj_from("cube", "Block", pages, loc=(0.003, 0, H / 2), scale=(W / 2 - 0.006, D / 2 - 0.006, H / 2 - 0.003)),
        obj_from("cube", "CoverT", leather, loc=(0, 0, H - 0.002), scale=(W / 2, D / 2, 0.002), bevel=0.0015),
        obj_from("cylinder", "Spine", leather, vertices=32, radius=H / 2, depth=D, loc=(-W / 2, 0, H / 2), rot=(math.pi / 2, 0, 0), scale=(0.35, 1, 1), smooth=True),
        obj_from("plane", "Title", gold, loc=(0, 0, H + 0.0002), scale=(W / 2 * 0.98, D / 2 * 0.98, 1), size=2),
    ]
    for cx in (1, -1):
        parts.append(obj_from("cube", "Corner", brass, loc=(W / 2 - 0.012, cx * (D / 2 - 0.012), H - 0.001), scale=(0.014, 0.014, 0.0025), bevel=0.001))
    e = bpy.data.objects.new("Logbook", None)
    bpy.context.collection.objects.link(e)
    for p in parts:
        p.parent = e
    e.location, e.rotation_euler = loc, (0, 0, rot_z)
    return e


def pencil(loc, rot_z):
    paint = mat("PencilPaint", color=(0.55, 0.32, 0.02), rough=0.35, coat=0.5)
    wood = mat("PencilWood", color=(0.7, 0.5, 0.3), rough=0.7)
    p = obj_from("cylinder", "Pencil", paint, vertices=6, radius=0.0038, depth=0.17, loc=(0, 0, 0), rot=(0, math.pi / 2, 0))
    t = obj_from("cone", "Tip", wood, vertices=6, radius1=0.0038, radius2=0.0005, depth=0.018, loc=(0.094, 0, 0), rot=(0, math.pi / 2, 0))
    e = bpy.data.objects.new("PencilE", None)
    bpy.context.collection.objects.link(e)
    p.parent = t.parent = e
    e.location, e.rotation_euler = loc, (0, 0, rot_z)


def product_studio(key_power=120, back=(0.035, 0.04, 0.045), cam_color=None, scale=1.0, world=0.5):
    backdrop(back, size=6.0 * scale)
    world_hdri("studio_small_08_2k.hdr", strength=world, cam_color=cam_color)
    k = scale
    area("Key", (-1.2 * k, -1.0 * k, 1.4 * k), (0, 0, 0.1 * k), key_power * k * k, size=1.2 * k, color=(1.0, 0.95, 0.88))
    area("Rim", (1.1 * k, 1.0 * k, 0.8 * k), (0, 0, 0.1 * k), key_power * 0.6 * k * k, size=0.8 * k, color=(0.8, 0.88, 1.0))


# ------------------------------------------------------------------ scenes
def s_small():
    def extra(m):
        return [loose_note(m, (0.075, -0.05, 0.0015), (0, 0, 0.5), 0.3), loose_note(m, (0.1, -0.02, 0.003), (0.03, 0, 0.85), 0.5)]
    cash_scene([(-0.03, 0.02, 0, 0.25)], fill=0.90, extra=extra)


def s_payroll():
    cash_scene([(-0.04, 0.02, 0, 0.2), (-0.035, 0.022, 0.0125, 0.32), (0.06, -0.045, 0, -0.35)], fill=0.92,
               extra=lambda m: [loose_note(m, (0.1, 0.05, 0.0015), (0, 0, 1.1), 0.3)])


def s_budget():
    cash_scene(pyramid(2, 3, 3), fill=0.92, jitter=0.004)


def s_fund():
    cash_scene(pyramid(3, 4, 5), el=30, fill=0.96, fstop=5.6, jitter=0.005)


def s_double():
    lay = [(x, 0, i * 0.0125, 0) for x in (-0.085, 0.085) for i in range(6)]
    cash_scene(lay, az=20, el=26, fill=0.90, fstop=5.6, jitter=0.002)


def s_cashboost():
    cash_scene([(-0.06, 0.04, 0, 0.3), (-0.058, 0.042, 0.0125, 0.4)], az=18, el=34, fill=0.92,
               extra=lambda m: [stopwatch((0.045, -0.04, 0.03), (math.radians(38), 0, math.radians(-10)), r=0.05)])


def s_crewboost():
    lay = [(0.0, 0.035, i * 0.0126, a) for i, a in enumerate((-0.45, 0.0, 0.45))]
    cash_scene(lay, az=10, el=40, fill=0.92,
               extra=lambda m: [stopwatch((0.06, -0.06, 0.03), (math.radians(38), 0, math.radians(-20)), r=0.045)])


def storm_sky(dark=1.0):
    k = dark
    world_hdri("gray_pier_2k.hdr", strength=0.45 / k, sky=((0.016 / k, 0.02 / k, 0.027 / k), (0.16 / k, 0.18 / k, 0.2 / k), (1, 1, 1)))
    sun(18, 200, 0.8 / k, color=(0.75, 0.82, 0.95), soft=10)


def s_storm():
    reset()
    bpy.context.scene.view_settings.exposure = 0.6
    sea = ocean(size=90, wave=2.4, chop=1.5, wind=20, res=15, seed=3, foam=0.5)
    buoy, objs = lod0_asset("harbour", "M_Hbr_NavMark_North")
    buoy.rotation_euler = (math.radians(7), math.radians(-10), math.radians(30))
    float_on(sea, buoy, objs, draft=0.12, follow=0.5)
    storm_sky(1.0)
    lo, hi = bbox(objs)
    h = hi.z - lo.z
    area("Rim", (h * 0.6, h * 1.6, h * 1.2), (0, 0, h * 0.5), 400 * h * h, size=h * 0.6, color=(0.75, 0.85, 1.0))
    area("Key", (-h * 1.4, -h * 1.2, h * 0.9), (0, 0, h * 0.5), 60 * h * h, size=h, color=(0.9, 0.95, 1.0))
    cam = frame(objs, 18, 4, lens=35, fill=0.74, lift=0.05)
    # bolt behind the buoy, in frame: left of it and far away
    back = cam.matrix_world.to_quaternion() @ Vector((0, 0, -1))
    far = cam.location + back * (cam.location - Vector((0, 0, h / 2))).length * 3.0
    side = cam.matrix_world.to_quaternion() @ Vector((1, 0, 0))
    top = far - side * h * 1.3 + Vector((0, 0, h * 2.6))
    lightning(top, (top.x + h * 0.3, top.y, -0.5), seed=5, strength=260, width=h * 0.035, branches=4)


def s_greatstorm():
    """Bigger and darker than Call the Storm: the RIB small and low in a huge black sky split by one great bolt."""
    reset()
    bpy.context.scene.view_settings.exposure = 0.35
    # dark storm water: sparse grey-white streaks of foam, never a lit white sheet (it blew out under the flash)
    sea = ocean(size=200, wave=11.0, chop=1.7, wind=40, res=16, seed=11, foam=0.18, color=(0.0008, 0.004, 0.006),
                foam_color=(0.16, 0.18, 0.19), foam_rough=0.75)
    rib, objs = vehicle("M_Veh_RIB")
    rib.rotation_euler = (0, 0, math.radians(-35))
    float_on(sea, rib, objs, draft=0.3, follow=0.9)
    storm_sky(3.2)
    lo, hi = bbox(objs)
    L = hi.y - lo.y
    area("Key", (-L, -L, L), (0, 0, 2), 110 * L * L, size=L * 0.5, color=(1.0, 0.9, 0.75))
    cam = frame(objs, 30, 1, lens=26, fill=0.55, lift=1.6)
    q = cam.matrix_world.to_quaternion()
    back, side = q @ Vector((0, 0, -1)), q @ Vector((1, 0, 0))
    far = cam.location + back * L * 8 + side * L * 0.5
    top = far + Vector((0, 0, L * 9.0))
    lightning(top, (top.x - L * 0.4, top.y, -1), seed=8, strength=700, width=L * 0.03, branches=7, glow=0.012,
              color=(0.62, 0.72, 1.0))
    far = cam.location + back * L * 14 - side * L * 4.0
    top = far + Vector((0, 0, L * 7.0))
    lightning(top, (top.x + L * 0.3, top.y, -1), seed=3, strength=160, width=L * 0.02, branches=2)
    # the bolt lights the sea and the cloud base around it
    area("Flash", tuple(cam.location + back * L * 8 + Vector((0, 0, L * 5))), tuple(rib.location), 900 * L * L,
         size=L * 4, color=(0.75, 0.82, 1.0))


def s_sea_vehicle(kind, az, el, lens=45, calm=True, livery=None, bolt=False, wake=False, fill=0.92, pitch=0.0, yaw=None):
    reset()
    if calm:
        sea = ocean(size=160, wave=0.8, chop=1.0, wind=8, res=15, seed=2, foam=0.2, color=(0.006, 0.03, 0.035))
        world_hdri("dalkey_view_2k.hdr", strength=1.0, rot=140)
        sun(35, 150, 3.0, color=(1.0, 0.96, 0.9))
    else:
        bpy.context.scene.view_settings.exposure = 0.5
        sea = ocean(size=140, wave=3.5, chop=1.5, wind=24, res=15, seed=4, foam=0.5)
        storm_sky(1.2)
    veh, objs = vehicle(kind)
    if livery:
        recolor(objs, livery[0], livery[1])
    veh.rotation_euler = (0, 0, math.radians(yaw if yaw is not None else (0 if wake else -20)))
    float_on(sea, veh, objs, draft=0.25 if not pitch else 0.12, follow=0.6)
    veh.rotation_euler.x -= math.radians(pitch)  # bow (-Y) up when planing
    if wake:
        wake_trail(objs)
    cam = frame(objs, az, el, lens=lens, fill=fill)
    if bolt:
        lo, hi = bbox(objs)
        L = hi.y - lo.y
        q = cam.matrix_world.to_quaternion()
        far = cam.location + (q @ Vector((0, 0, -1))) * L * 7 - (q @ Vector((1, 0, 0))) * L * 1.5
        top = far + Vector((0, 0, L * 3))
        lightning(top, (top.x, top.y, -1), seed=9, strength=260, width=L * 0.02)
        area("Rim", (0, L * 1.5, L), ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, hi.z), 200 * L * L, size=L * 0.4, color=(0.75, 0.85, 1.0))


def wake_trail(objs):
    lo, hi = bbox(objs)
    m = mat("Wake", color=(0.85, 0.9, 0.9), rough=0.6)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = node(nt, "ShaderNodeTexNoise", Scale=6.0, Detail=12.0)
    nt.links.new(tc.outputs["UV"], nz.inputs["Vector"])
    grad = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["UV"], grad.inputs["Vector"])
    edge = nt.nodes.new("ShaderNodeMath")
    edge.operation = "PINGPONG"
    edge.inputs[1].default_value = 0.5
    nt.links.new(grad.outputs["X"], edge.inputs[0])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(edge.outputs["Value"], mul.inputs[0])
    nt.links.new(nz.outputs["Fac"], mul.inputs[1])
    fade = nt.nodes.new("ShaderNodeMath")
    fade.operation = "MULTIPLY"
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(grad.outputs["Y"], inv.inputs[1])
    nt.links.new(mul.outputs["Value"], fade.inputs[0])
    nt.links.new(inv.outputs["Value"], fade.inputs[1])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.04
    ramp.color_ramp.elements[1].position = 0.16
    nt.links.new(fade.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf(m).inputs["Alpha"])
    w = (hi.x - lo.x) * 1.2
    L = (hi.y - lo.y) * 7
    bpy.ops.mesh.primitive_plane_add(size=1)
    o = bpy.context.active_object
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=20)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.scale = (w, L, 1)
    bpy.ops.object.transform_apply(scale=True)
    for v in o.data.vertices:  # V shape widening behind the stern
        t = (v.co.y + L / 2) / L
        v.co.x *= 0.5 + 2.2 * t
    o.location = ((lo.x + hi.x) / 2, hi.y + L / 2 - (hi.y - lo.y) * 0.15, 0.08)
    o.data.materials.append(m)


def s_card():
    reset()
    product_studio(key_power=30, back=(0.03, 0.03, 0.035), world=1.4)
    gold = image_mat("CardFace", os.path.join(TEX, "vip_card.png"), rough=0.32, metal=0.6, coat=0.6)
    c = obj_from("cube", "Card", gold, loc=(0, 0, 0.0008), scale=(0.0428, 0.027, 0.0004), bevel=0.003)
    c.modifiers["Bevel"].limit_method = "NONE"
    c.modifiers["Bevel"].affect = "VERTICES"
    face = obj_from("plane", "Face", gold, loc=(0, 0, 0.00125), scale=(0.0425, 0.0268, 1), size=2)
    for o in (c, face):
        o.rotation_euler = (0, 0, 0.35)
    lanyard = mat("Lanyard", color=(0.02, 0.05, 0.15), rough=0.7)
    obj_from("cube", "Strap", lanyard, loc=(-0.02, 0.07, 0.0006), scale=(0.006, 0.05, 0.0005), rot=(0, 0, 0.6))
    area("Top", (0.05, -0.12, 0.35), (0, 0, 0), 8, size=0.5, color=(1.0, 0.96, 0.9))
    camera((0, 0.005, 0), 12, 48, 0.36, lens=85, fstop=5.6)


def s_horns():
    reset()
    product_studio(key_power=90)
    chrome = mat("Chrome", color=(0.92, 0.92, 0.94), rough=0.06, metal=1.0)
    black = mat("BlackP", color=(0.02, 0.02, 0.022), rough=0.4)
    for i, (L, y) in enumerate(((0.32, 0.0), (0.24, 0.12))):
        obj_from("cone", "Bell", chrome, vertices=96, radius1=0.006, radius2=0.055 + 0.01 * (1 - i), depth=L, loc=(0, y, 0.07 + i * 0.01), rot=(0, math.pi / 2, 0), smooth=True)
        obj_from("cylinder", "Lip", chrome, vertices=96, radius=0.06 + 0.01 * (1 - i), depth=0.006, loc=(L / 2, y, 0.07 + i * 0.01), rot=(0, math.pi / 2, 0), bevel=0.002, smooth=True)
        obj_from("cylinder", "Driver", black, vertices=48, radius=0.03, depth=0.06, loc=(-L / 2 - 0.03, y, 0.07 + i * 0.01), rot=(0, math.pi / 2, 0), bevel=0.004, smooth=True)
    obj_from("cube", "Bracket", chrome, loc=(-0.12, 0.06, 0.015), scale=(0.07, 0.11, 0.008), bevel=0.003)
    camera((0.0, 0.06, 0.07), 50, 18, 0.75, lens=70, fstop=8)


def s_beacon(colors=((0.05, 0.25, 1.0),), bar=False):
    reset()
    product_studio(key_power=50, back=(0.02, 0.022, 0.026))
    black = mat("BlackP", color=(0.02, 0.02, 0.022), rough=0.35)
    chrome = mat("Chrome", color=(0.9, 0.9, 0.92), rough=0.08, metal=1.0)
    if not bar:
        c = colors[0]
        obj_from("cylinder", "Base", black, vertices=96, radius=0.07, depth=0.04, loc=(0, 0, 0.02), bevel=0.006, smooth=True)
        lens = mat("Lens", color=c, rough=0.05, transmission=0.9, emit=c, emit_strength=4.0)
        obj_from("uv_sphere", "Dome", lens, segments=96, ring_count=48, radius=0.062, loc=(0, 0, 0.04), scale=(1, 1, 1.5), smooth=True)
        inner = mat("LED", color=(0, 0, 0), emit=tuple(min(1, x * 1.5 + 0.2) for x in c), emit_strength=60)
        obj_from("cylinder", "Reflector", chrome, vertices=48, radius=0.03, depth=0.08, loc=(0, 0, 0.09), smooth=True)
        obj_from("cube", "LEDs", inner, loc=(0.0, -0.032, 0.09), scale=(0.012, 0.004, 0.03))
        # coloured light spill on the sweep
        pl = bpy.data.lights.new("Spill", "POINT")
        pl.energy, pl.color, pl.shadow_soft_size = 25, c, 0.05
        o = bpy.data.objects.new("Spill", pl)
        bpy.context.collection.objects.link(o)
        o.location = (0, -0.1, 0.12)
        camera((0, 0, 0.08), 20, 14, 0.55, lens=70, fstop=5.6)
    else:
        obj_from("cube", "Bar", black, loc=(0, 0, 0.035), scale=(0.42, 0.06, 0.03), bevel=0.012)
        for i in range(8):
            c = colors[i % len(colors)]
            x = (i - 3.5) * 0.1
            lens = mat("Lens%d" % i, color=c, rough=0.05, transmission=0.85, emit=c, emit_strength=18 if i in (0, 3, 4, 7) else 3)
            obj_from("cube", "Lens", lens, loc=(x, -0.061, 0.037), scale=(0.045, 0.004, 0.022), bevel=0.003)
        for x in (-0.3, 0.3):
            obj_from("cube", "Foot", chrome, loc=(x, 0, 0.003), scale=(0.03, 0.05, 0.004), bevel=0.002)
        for i, c in enumerate(colors[:2]):
            pl = bpy.data.lights.new("Spill", "POINT")
            pl.energy, pl.color, pl.shadow_soft_size = 30, c, 0.05
            o = bpy.data.objects.new("Spill", pl)
            bpy.context.collection.objects.link(o)
            o.location = ((-0.3 if i == 0 else 0.3), -0.2, 0.05)
        frame([o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(("Bar", "Lens", "Foot"))], 22, 18, lens=70, fill=0.96, fstop=8)


def s_radio():
    reset()
    product_studio(key_power=90, back=(0.05, 0.045, 0.04))
    wood_table(size=3.0)
    body = mat("RadioBody", color=(0.6, 0.53, 0.40), rough=0.4, coat=0.4)
    grille = image_mat("Grille", os.path.join(TEX, "grille.png"), rough=0.8, bump=0.3)
    chrome = mat("Chrome", color=(0.9, 0.9, 0.92), rough=0.1, metal=1.0)
    dial = image_mat("RDial", os.path.join(TEX, "radio_dial.png"), rough=0.2)
    obj_from("cube", "Case", body, loc=(0, 0, 0.09), scale=(0.15, 0.065, 0.09), bevel=0.025)
    obj_from("plane", "Grille", grille, loc=(-0.045, -0.0662, 0.095), rot=(math.pi / 2, 0, 0), scale=(0.085, 0.065, 1), size=2)
    obj_from("plane", "Dial", dial, loc=(0.085, -0.0662, 0.115), rot=(math.pi / 2, 0, 0), scale=(0.045, 0.035, 1), size=2)
    for x in (0.06, 0.11):
        obj_from("cylinder", "Knob", chrome, vertices=48, radius=0.014, depth=0.018, loc=(x, -0.075, 0.045), rot=(math.pi / 2, 0, 0), bevel=0.003, smooth=True)
    obj_from("torus", "Handle", chrome, major_radius=0.09, minor_radius=0.006, loc=(0, 0, 0.18), rot=(math.pi / 2, 0, 0), smooth=True)
    camera((0, 0, 0.1), 28, 12, 0.85, lens=70, fstop=5.6)


def s_locker():
    reset()
    blend = os.path.join(SRC, "props", "M_Prop_Chandlery", "M_Prop_Chandlery.blend")
    objs = append_objects(blend, lambda n: n == "M_Prop_Chandlery_RackMid_LOD0")
    for o in objs:
        pbr_from_maps(o, "M_Prop_Chandlery")
    g = group(objs, "Rack")
    g.location = (0, 0, 0)
    product_studio(key_power=60, back=(0.05, 0.05, 0.05), scale=5.0)
    bpy.context.view_layer.update()
    lo, hi = bbox(objs)
    frame(objs, 22, 8, lens=50, fill=0.96, fstop=11)


def s_logbook(season):
    reset()
    wood_table(tone=(0.16, 0.09, 0.05))
    subj = [logbook((0, 0, 0), 0.25)]
    pencil((0.14, -0.1, 0.004), 1.2)
    if season:
        subj.append(stopwatch((-0.15, -0.12, 0.02), (math.radians(30), 0, math.radians(-25)), r=0.035))
    cash_lighting()
    frame(meshes(*subj), 18, 46, lens=70, fill=0.96, fstop=5.6)


def crate(inner=(0.48, 0.30, 0.15), t=0.016):
    wood = bpy.data.materials.get("Oak")
    steel = mat("CrateBand", color=(0.25, 0.25, 0.26), rough=0.45, metal=1.0)
    W, D, H = inner
    parts = [obj_from("cube", "Floor", wood, loc=(0, 0, t / 2), scale=(W / 2 + t, D / 2 + t, t / 2), bevel=0.002)]
    for sx in (-1, 1):
        parts.append(obj_from("cube", "WallX", wood, loc=(sx * (W / 2 + t / 2), 0, H / 2 + t), scale=(t / 2, D / 2 + t, H / 2), bevel=0.002))
    for sy in (-1, 1):
        parts.append(obj_from("cube", "WallY", wood, loc=(0, sy * (D / 2 + t / 2), H / 2 + t), scale=(W / 2 + t, t / 2, H / 2), bevel=0.002))
        for sx in (-1, 1):
            parts.append(obj_from("cube", "Band", steel, loc=(sx * W * 0.32, sy * (D / 2 + t + 0.001), H / 2 + t), scale=(0.012, 0.0015, H / 2 + 0.002)))
    parts.append(obj_from("cube", "Filler", bpy.data.materials["NoteEdge"], loc=(0, 0, H / 2), scale=(W / 2, D / 2, H / 2 - 0.02)))
    return parts


def cashbox(W=0.30, D=0.21, H=0.085):
    paint = mat("BoxPaint", color=(0.08, 0.13, 0.1), rough=0.35, metal=0.6, coat=0.3)
    add_noise_bump(paint, 300, 0.05)
    chrome = mat("BoxChrome", color=(0.85, 0.85, 0.86), rough=0.15, metal=1.0)
    t = 0.004
    parts = [obj_from("cube", "Base", paint, loc=(0, 0, t / 2), scale=(W / 2, D / 2, t / 2), bevel=0.002)]
    for sx in (-1, 1):
        parts.append(obj_from("cube", "Side", paint, loc=(sx * (W / 2 - t / 2), 0, H / 2), scale=(t / 2, D / 2, H / 2), bevel=0.0015))
    for sy in (-1, 1):
        parts.append(obj_from("cube", "End", paint, loc=(0, sy * (D / 2 - t / 2), H / 2), scale=(W / 2, t / 2, H / 2), bevel=0.0015))
    lid = obj_from("cube", "Lid", paint, loc=(0, 0, 0), scale=(W / 2 + 0.003, D / 2 + 0.003, 0.012), bevel=0.004)
    for v in lid.data.vertices:  # hinge along the back edge
        v.co.y += D / 2
    lid.location = (0, D / 2, H)
    lid.rotation_euler = (math.radians(105), 0, 0)
    parts.append(lid)
    parts.append(obj_from("torus", "Handle", chrome, major_radius=0.035, minor_radius=0.005, loc=(0, -D / 2 - 0.004, H * 0.7), scale=(1, 0.4, 1), smooth=True))
    parts.append(obj_from("cube", "Filler", bpy.data.materials["NoteEdge"], loc=(0, 0, H / 2), scale=(W / 2 - t, D / 2 - t, H / 2 - 0.02)))
    return parts


def s_fund_crate():
    reset()
    wood_table()
    mats = banknote_mats()
    rng = random.Random(7)
    subj = crate()
    H = 0.15
    for layer, (nx, ny) in enumerate(((3, 4), (2, 3), (1, 2))):
        for i in range(nx):
            for j in range(ny):
                x = (i - (nx - 1) / 2) * (NOTE[0] + 0.002)
                y = (j - (ny - 1) / 2) * (NOTE[1] + 0.002)
                e, parts = bundle(mats, (x + rng.uniform(-0.004, 0.004), y, H - 0.012 + layer * 0.0125), rng.uniform(-0.06, 0.06))
                subj += parts
    for (x, y, rz) in ((0.18, -0.26, 0.5), (-0.12, -0.27, -0.3), (0.02, -0.25, 0.1)):
        e, parts = bundle(mats, (x, y, 0), rz)
        subj += parts
    cash_lighting()
    frame(subj, 24, 34, lens=70, fill=0.94, fstop=5.6)


def s_double_box():
    reset()
    wood_table()
    mats = banknote_mats()
    subj = cashbox()
    rng = random.Random(2)
    for i in range(2):
        for j in range(3):
            x = (i - 0.5) * NOTE[0] * 0.86
            y = (j - 1) * NOTE[1] * 0.9
            e, parts = bundle(mats, (x, y, 0.079 + (i + j) % 2 * 0.004), rng.uniform(-0.05, 0.05))
            e.scale = (0.9, 0.9, 1)
            subj += parts
    for (x, y, z, rz) in ((0.2, -0.13, 0, 0.6), (0.2, -0.13, 0.0125, 0.75)):
        e, parts = bundle(mats, (x, y, z), rz)
        subj += parts
    cash_lighting()
    frame(subj, 22, 38, lens=70, fill=0.94, fstop=5.6)


def s_cashboost_hero():
    reset()
    wood_table()
    mats = banknote_mats()
    e1, p1 = bundle(mats, (-0.03, 0.06, 0), 0.25)
    e2, p2 = bundle(mats, (-0.025, 0.062, 0.0125), 0.35)
    sw = stopwatch((0.0, -0.01, 0.045), (math.radians(58), 0, math.radians(-8)), r=0.06)
    cash_lighting()
    frame(p1 + p2 + meshes(sw), 14, 30, lens=70, fill=0.96, fstop=4.0)


def vhf(loc, rot):
    body = mat("VHFBody", color=(0.025, 0.025, 0.028), rough=0.45)
    add_noise_bump(body, 500, 0.08)
    yellow = mat("VHFYellow", color=(0.85, 0.6, 0.02), rough=0.4)
    rubber = mat("VHFRubber", color=(0.02, 0.02, 0.02), rough=0.8)
    face = image_mat("VHFFace", os.path.join(TEX, "vhf_face.png"), rough=0.3)
    W, D, H = 0.062, 0.034, 0.13
    parts = [
        obj_from("cube", "Body", body, loc=(0, 0, H / 2), scale=(W / 2, D / 2, H / 2), bevel=0.008),
        obj_from("cube", "Bumper", yellow, loc=(0, 0, H * 0.22), scale=(W / 2 + 0.002, D / 2 + 0.002, H * 0.2), bevel=0.006),
        obj_from("plane", "Face", face, loc=(0, -D / 2 - 0.0012, H * 0.6), rot=(math.pi / 2, 0, 0), scale=(W / 2 * 0.86, H * 0.36, 1), size=2),
        obj_from("cylinder", "Antenna", rubber, vertices=24, radius=0.006, depth=0.15, loc=(W * 0.28, 0, H + 0.075), bevel=0.002, smooth=True),
        obj_from("cylinder", "Knob", rubber, vertices=24, radius=0.008, depth=0.012, loc=(-W * 0.25, 0, H + 0.006), bevel=0.002, smooth=True),
    ]
    e = bpy.data.objects.new("VHF", None)
    bpy.context.collection.objects.link(e)
    for p in parts:
        p.parent = e
    e.location, e.rotation_euler = loc, rot
    return e


def s_crewboost_vhf():
    reset()
    wood_table()
    mats = banknote_mats()
    subj = []
    for i, a in enumerate((-0.5, 0.0, 0.5)):
        e, p = bundle(mats, (0.0, 0.03, i * 0.0126), a)
        subj += p
    # handheld crew VHF lying face-up across the fan, antenna away from camera
    r = vhf((0.03, -0.05, 0.04), (math.radians(-80), 0, math.radians(-160)))
    cash_lighting()
    frame(subj + meshes(r), 12, 40, lens=70, fill=0.94, fstop=4.0)


def s_starter_kit():
    reset()
    wood_table()
    mats = banknote_mats()
    e, notes = bundle(mats, (-0.07, 0.05, 0), 0.15)
    e2, notes2 = bundle(mats, (-0.065, 0.052, 0.0125), 0.22)
    bandana = image_mat("Bandana", os.path.join(TEX, "bandana.png"), rough=0.85)
    add_noise_bump(bandana, 900, 0.25, 0.0003)
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.12, radius2=0.0, depth=0.008, location=(0.09, 0.07, 0.004))
    b = bpy.context.active_object
    b.scale = (1.0, 0.62, 1.0)
    b.rotation_euler = (0, 0, 0.5)
    bv = b.modifiers.new("Bevel", "BEVEL")
    bv.width, bv.segments = 0.003, 3
    b.data.materials.append(bandana)
    bpy.ops.object.shade_smooth()
    # Station Orange livery swatch: gelcoat chip with a retroreflective band
    orange = mat("Gelcoat", color=(0.9, 0.22, 0.02), rough=0.12, coat=0.8)
    refl = mat("Reflective", color=(0.75, 0.76, 0.78), rough=0.35, metal=0.5)
    sw = obj_from("cube", "Swatch", orange, loc=(0.06, -0.08, 0.003), scale=(0.075, 0.045, 0.003), rot=(0, 0, -0.25), bevel=0.003)
    st = obj_from("cube", "Stripe", refl, loc=(0.06, -0.08, 0.0062), scale=(0.075, 0.009, 0.0002), rot=(0, 0, -0.25))
    cash_lighting()
    frame(notes + notes2 + [b, sw, st], 10, 62, lens=70, fill=0.94, fstop=8)


def s_clipboard():
    reset()
    wood_table()
    board = mat("Masonite", color=(0.32, 0.2, 0.1), rough=0.5)
    add_noise_bump(board, 500, 0.08)
    steel = mat("ClipSteel", color=(0.8, 0.8, 0.82), rough=0.2, metal=1.0)
    c1 = image_mat("Task1", os.path.join(TEX, "tasking.png"), rough=0.8)
    c2 = image_mat("Task2", os.path.join(TEX, "tasking2.png"), rough=0.8)
    subj = [obj_from("cube", "Board", board, loc=(0, 0, 0.002), scale=(0.115, 0.16, 0.002), bevel=0.004),
            obj_from("plane", "Card1", c1, loc=(0, -0.01, 0.0045), scale=(0.1, 0.14, 1), size=2),
            obj_from("cube", "Clip", steel, loc=(0, 0.148, 0.008), scale=(0.05, 0.016, 0.004), bevel=0.003),
            obj_from("cylinder", "Roll", steel, vertices=32, radius=0.006, depth=0.1, loc=(0, 0.16, 0.01), rot=(0, math.pi / 2, 0), smooth=True)]
    card = obj_from("plane", "Card2", c2, scale=(0.1, 0.14, 1), size=2)
    card.location, card.rotation_euler = (0.13, -0.05, 0.012), (0, math.radians(-4), 0.32)
    subj.append(card)
    cash_lighting()
    frame(subj, 12, 58, lens=70, fill=0.94, fstop=8)


# ------------------------------------------------------------------ RP-M5: dog wardrobe flat-lay, water dog friends
def ribbon(name, pts, width, thick, m, z=0.0, closed=False):
    """Flat webbing strip along a 2D polyline `pts` (x, y) lying at height z, solidified to `thick`."""
    n = len(pts)
    verts, faces = [], []
    for i, (x, y) in enumerate(pts):
        a = pts[(i - 1) % n] if (closed or i > 0) else pts[i]
        b = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln * width / 2, dx / ln * width / 2
        verts += [(x + nx, y + ny, z), (x - nx, y - ny, z)]
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        faces.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    so = o.modifiers.new("Solid", "SOLIDIFY")
    so.thickness, so.offset = thick, 1.0
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width, bv.segments = thick * 0.4, 2
    me.materials.append(m)
    for pg in me.polygons:
        pg.use_smooth = True
    return o


def webbing_mat(name, color):
    m = mat(name, color=color, rough=0.72)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    w = node(nt, "ShaderNodeTexWave", Scale=900.0, Distortion=0.4)
    w.bands_direction = "X"
    nt.links.new(tc.outputs["Object"], w.inputs["Vector"])
    bm = node(nt, "ShaderNodeBump", Strength=0.25, Distance=0.0002)
    nt.links.new(w.outputs["Fac"], bm.inputs["Height"])
    nt.links.new(bm.outputs["Normal"], bsdf(m).inputs["Normal"])
    bsdf(m).inputs["Sheen Weight"].default_value = 0.4
    return m


def quilted_mat(name, color, scale=60.0):
    """Padded nylon: diagonal quilting channels plus a fine ripstop weave."""
    m = mat(name, color=color, rough=0.55, coat=0.05)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    q1 = node(nt, "ShaderNodeTexWave", Scale=scale, Distortion=0.0)
    q1.wave_profile = "TRI"
    q1.bands_direction = "DIAGONAL"
    nt.links.new(tc.outputs["Object"], q1.inputs["Vector"])
    fine = node(nt, "ShaderNodeTexNoise", Scale=2500.0, Detail=2.0)
    nt.links.new(tc.outputs["Object"], fine.inputs["Vector"])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "MULTIPLY_ADD"
    add.inputs[1].default_value = 0.08
    nt.links.new(fine.outputs["Fac"], add.inputs[0])
    nt.links.new(q1.outputs["Fac"], add.inputs[2])
    bm = node(nt, "ShaderNodeBump", Strength=0.5, Distance=0.002)
    nt.links.new(add.outputs["Value"], bm.inputs["Height"])
    nt.links.new(bm.outputs["Normal"], bsdf(m).inputs["Normal"])
    bsdf(m).inputs["Sheen Weight"].default_value = 0.3
    return m


def side_release(name, loc, rot_z, z):
    """Black acetal side-release buckle (female body + male tongue), lying flat."""
    blk = mat("Acetal", color=(0.012, 0.012, 0.013), rough=0.35)
    ca, sa = math.cos(rot_z), math.sin(rot_z)
    out = []
    for off, sx, sy, sz in ((-0.016, 0.018, 0.016, 0.006), (0.014, 0.013, 0.013, 0.0045)):
        p = (loc[0] + off * ca, loc[1] + off * sa, z + sz)
        out.append(obj_from("cube", name, blk, loc=p, rot=(0, 0, rot_z), scale=(sx, sy, sz), bevel=0.003))
    return out


def flat_harness(loc, rot_z, color, z0=0.0, name="H"):
    """An H-style dog harness laid flat: padded saddle with a dark binding and grab handle, girth strap through it,
    a spine strap forward to a padded chest plate, the neck strap across it, side-release buckles, D-ring at the back."""
    c, s = math.cos(rot_z), math.sin(rot_z)
    W = lambda x, y: (loc[0] + x * c - y * s, loc[1] + x * s + y * c)
    pad_m = quilted_mat(name + "Pad", color)
    web_m = webbing_mat(name + "Web", tuple(v * 0.6 for v in color))
    bind_m = webbing_mat(name + "Bind", (0.015, 0.015, 0.017))
    objs = []
    # girth strap: runs across under the saddle, buckle near one end
    objs.append(ribbon(name + "Girth", [W(-0.02, -0.25 + 0.5 * t) for t in (0, 0.25, 0.5, 0.75, 1)], 0.032, 0.004,
                       web_m, z=z0))
    objs += side_release(name + "Bk", W(-0.02, 0.19), rot_z + math.pi / 2, z0)
    # spine strap forward to the chest plate, neck strap across it with its own buckle
    objs.append(ribbon(name + "Spine", [W(0.08, 0.0), W(0.16, 0.0), W(0.23, 0.0)], 0.028, 0.004, web_m, z=z0))
    objs.append(ribbon(name + "Neck", [W(0.23, -0.2 + 0.4 * t) for t in (0, 0.25, 0.5, 0.75, 1)], 0.028, 0.004,
                       web_m, z=z0))
    objs += side_release(name + "Bk2", W(0.23, -0.15), rot_z - math.pi / 2, z0)
    objs.append(obj_from("cube", name + "Chest", pad_m, loc=(*W(0.23, 0.0), z0 + 0.008), rot=(0, 0, rot_z),
                         scale=(0.032, 0.06, 0.007), bevel=0.01, smooth=True))
    # padded saddle with a dark binding all round
    objs.append(obj_from("cube", name + "Pad", pad_m, loc=(*W(0.0, 0.0), z0 + 0.014), rot=(0, 0, rot_z),
                         scale=(0.11, 0.095, 0.010), bevel=0.012, smooth=True))
    rim = [W(0.115 * math.copysign(abs(math.cos(a)) ** 0.35, math.cos(a)), 0.1 * math.copysign(abs(math.sin(a)) ** 0.35, math.sin(a)))
           for a in [i / 64 * math.tau for i in range(64)]]
    objs.append(ribbon(name + "Rim", rim, 0.012, 0.022, bind_m, z=z0 + 0.003, closed=True))
    # low webbing grab handle along the spine, D-ring at the back
    hx, hy = W(-0.01, 0.0)
    objs.append(obj_from("torus", name + "Handle", bind_m, loc=(hx, hy, z0 + 0.02), rot=(math.pi / 2, 0, rot_z),
                         major_radius=0.045, minor_radius=0.005, smooth=True, scale=(1.0, 0.45, 2.6)))
    dx, dy = W(-0.13, 0.0)
    steel = mat("Steel", color=(0.75, 0.75, 0.74), rough=0.18, metal=1.0)
    objs.append(obj_from("torus", name + "D", steel, loc=(dx, dy, z0 + 0.004), major_radius=0.018, minor_radius=0.0028,
                         smooth=True))
    return objs


def bandana_fold(path, loc, rot_z, z, name, size=0.13):
    m = image_mat(name, path, rough=0.85)
    add_noise_bump(m, 900, 0.25, 0.0003)
    o = obj_from("plane", name, m, loc=(loc[0], loc[1], z), rot=(0, 0, rot_z), size=size)
    so = o.modifiers.new("Solid", "SOLIDIFY")
    so.thickness, so.offset = 0.007, 1.0
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width, bv.segments = 0.0025, 3
    bpy.ops.object.shade_smooth()
    return o


def life_jacket(loc, rot_z, color, scale=1.0):
    """Small dog buoyancy aid laid out flat: a curved foam back panel with quilted channels, a chin float at the neck,
    reflective piping across the back, a black webbing grab handle along the spine, D-ring, short belly straps with
    side-release buckles."""
    shell_m = quilted_mat("JacketShell", color, scale=14.0)
    bsdf(shell_m).inputs["Roughness"].default_value = 0.45
    bind_m = webbing_mat("JacketBind", (0.012, 0.012, 0.014))
    # reflective piping: a dull grey microprism tape (kept well below the reserved retroreflective silver)
    tape = mat("JacketTape", color=(0.24, 0.25, 0.26), rough=0.28, metal=0.55)
    add_noise_bump(tape, 3000, 0.3, 0.0002)
    R, L, A, T = 0.16, 0.36, 1.0, 0.022  # opened out flat-ish on the table, as it would be laid out in a shop

    def arc_patch(name, x0, x1, off, thick, m, nx=48, ny=32, rim=None):
        bpy.ops.mesh.primitive_grid_add(x_subdivisions=nx, y_subdivisions=ny, size=1.0)
        o = bpy.context.active_object
        o.name = name
        for v in o.data.vertices:
            x = x0 + (v.co.x + 0.5) * (x1 - x0)
            u = min(1.0, abs(x) / (L / 2))
            th = v.co.y * 2.0 * A * (0.45 + 0.55 * (1 - u ** 4) ** 0.25)  # rounded saddle outline, not a tube
            rx = R * (0.78 + 0.22 * (1 - (x / L + 0.5)))  # narrower towards the neck (+x)
            v.co = Vector((x, (rx + off) * math.sin(th), 0.004 - rx * math.cos(A) + (rx + off) * math.cos(th)))
        so = o.modifiers.new("Solid", "SOLIDIFY")
        so.thickness, so.offset = thick, 1.0
        if rim is not None:
            so.material_offset_rim = 1
        o.modifiers.new("Sub", "SUBSURF").levels = 1
        o.data.materials.append(m)
        if rim is not None:
            o.data.materials.append(rim)
        bpy.ops.object.shade_smooth()
        return o

    objs = [arc_patch("Jacket", -L / 2, L / 2, 0.0, T, shell_m, rim=bind_m)]
    for xc in (-0.105, 0.075):  # two bands of piping across the back
        objs.append(arc_patch("JTape", xc - 0.012, xc + 0.012, T - 0.003, 0.004, tape, nx=4, ny=40))
    top = R * (1 - math.cos(A)) + 0.004 + T
    # rolled foam collar arching over the neck opening, with a black binding edge
    objs.append(obj_from("torus", "JCollar", shell_m, loc=(L / 2 + 0.02, 0, 0.0), rot=(0, math.pi / 2, 0),
                         major_radius=0.1, minor_radius=0.026, smooth=True, scale=(1.0, 1.25, 1.0)))
    objs.append(obj_from("torus", "JCollarBind", bind_m, loc=(L / 2 + 0.047, 0, 0.0), rot=(0, math.pi / 2, 0),
                         major_radius=0.1, minor_radius=0.007, smooth=True, scale=(1.0, 1.25, 1.0)))
    # grab handle: a flat black webbing loop standing up along the spine, stitched down at both ends
    h = obj_from("torus", "JHandle", bind_m, loc=(-0.015, 0, top - 0.012), rot=(math.pi / 2, 0, 0),
                 major_radius=0.07, minor_radius=0.0065, smooth=True, scale=(1.0, 0.85, 3.2))
    objs.append(h)
    for xe in (-0.075, 0.045):
        objs.append(obj_from("cube", "JTab", bind_m, loc=(xe, 0, top + 0.001), scale=(0.022, 0.018, 0.003), bevel=0.002))
    steel = mat("JSteel", color=(0.75, 0.75, 0.74), rough=0.18, metal=1.0)
    objs.append(obj_from("torus", "JD", steel, loc=(-0.13, 0, top - 0.006), rot=(0, math.radians(-25), 0),
                         major_radius=0.016, minor_radius=0.0028, smooth=True))
    web = webbing_mat("JWeb", (0.014, 0.014, 0.016))
    side = R * math.sin(A)
    for sx in (-0.09, 0.08):  # short belly straps folded out, buckles clipped
        for sg in (1, -1):
            objs.append(ribbon("JStrap", [(sx, sg * (side + 0.004 + t * 0.06)) for t in (0, 0.5, 1)], 0.03, 0.004, web))
        objs += side_release("JBk", (sx, side + 0.075), math.pi / 2, 0.0)
        objs += side_release("JBk", (sx, -side - 0.075), -math.pi / 2, 0.0)
    e = group(objs, "LifeJacket")
    e.location = (loc[0], loc[1], 0)
    e.rotation_euler = (0, 0, rot_z)
    e.scale = (scale, scale, scale)
    return objs


def captains_hat(loc, rot_z, r=0.06, scale=1.0):
    white = mat("HatCotton", color=(0.78, 0.78, 0.76), rough=0.8)
    add_noise_bump(white, 1500, 0.2, 0.0002)
    black = mat("HatBand", color=(0.01, 0.01, 0.012), rough=0.55)
    patent = mat("HatVisor", color=(0.006, 0.006, 0.007), rough=0.12, coat=1.0)
    gold = mat("Gold", color=(0.9, 0.62, 0.25), rough=0.28, metal=1.0)
    objs = [obj_from("cylinder", "Band", black, loc=(0, 0, 0.021), scale=(r, r, 0.021), vertices=64, bevel=0.002, smooth=True)]
    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=r * 1.02, radius2=r * 1.42, depth=0.03, location=(0, 0, 0.057))
    crown = bpy.context.active_object
    crown.name = "Crown"
    b = crown.modifiers.new("Bevel", "BEVEL")
    b.width, b.segments = 0.011, 5
    bpy.ops.object.shade_smooth()
    crown.data.materials.append(white)
    objs.append(crown)
    # visor: a crescent off the front of the band, tipped down
    pts_o = [(math.sin(a) * r * 1.0, -math.cos(a) * r * 1.62) for a in [(-1.25 + 2.5 * i / 30) for i in range(31)]]
    pts_i = [(math.sin(a) * r * 0.99, -math.cos(a) * r * 0.99) for a in [(1.25 - 2.5 * i / 30) for i in range(31)]]
    me = bpy.data.meshes.new("Visor")
    me.from_pydata([(x, y, 0) for x, y in pts_o + pts_i], [], [tuple(range(62))])
    vis = bpy.data.objects.new("Visor", me)
    bpy.context.collection.objects.link(vis)
    vis.location, vis.rotation_euler = (0, 0, 0.004), (math.radians(-14), 0, 0)
    so = vis.modifiers.new("Solid", "SOLIDIFY")
    so.thickness = 0.003
    bv = vis.modifiers.new("Bevel", "BEVEL")
    bv.width, bv.segments = 0.001, 2
    me.materials.append(patent)
    objs.append(vis)
    # gold chin cord across the front and a badge
    for zc in (0.016, 0.022):
        cd = bpy.data.curves.new("Cord", "CURVE")
        cd.dimensions, cd.bevel_depth, cd.bevel_resolution = "3D", 0.0018, 3
        sp = cd.splines.new("POLY")
        arc = [(math.sin(a) * r * 1.03, -math.cos(a) * r * 1.03, zc) for a in [(-1.1 + 2.2 * i / 24) for i in range(25)]]
        sp.points.add(len(arc) - 1)
        for i, p in enumerate(arc):
            sp.points[i].co = (*p, 1)
        co = bpy.data.objects.new("Cord", cd)
        bpy.context.collection.objects.link(co)
        cd.materials.append(gold)
        objs.append(co)
    objs.append(obj_from("cylinder", "Badge", gold, loc=(0, -r * 1.02, 0.036), rot=(math.pi / 2, 0, 0), vertices=32,
                         scale=(0.011, 0.014, 0.002), bevel=0.001, smooth=True))
    e = group(objs, "Hat")
    e.location = (loc[0], loc[1], 0)
    e.rotation_euler = (0, 0, rot_z)
    e.scale = (scale, scale, scale)
    return objs


def s_wardrobe():
    """Neat shop flat-lay: four harnesses in a 2x2 block, the red dog life jacket, captain's hat, fanned bandanas."""
    reset()
    wood_table(tone=(0.085, 0.043, 0.02))
    subj = []
    colors = ((0.03, 0.06, 0.20), (0.05, 0.15, 0.06), (0.42, 0.25, 0.03), (0.2, 0.02, 0.03))  # navy, forest, mustard, burgundy
    for i, col in enumerate(colors):
        objs = flat_harness((0.0, 0.0), math.pi / 2, col, name="H%d" % i)  # chest plate away from the camera
        e = group(objs, "Harness%d" % i)  # empty sits at the bbox bottom centre
        e.location = (-0.54 + (i % 2) * 0.37, 0.21 - (i // 2) * 0.40, 0)
        e.scale = (0.68, 0.68, 0.68)
        subj += objs
    # life jacket: deep marine red (not SOLAS orange or distress red, docs/05 3.2), collar away from the camera
    subj += life_jacket((0.29, 0.16), math.pi / 2, (0.36, 0.028, 0.018), scale=1.05)
    subj += captains_hat((0.15, -0.26), 0.25, scale=1.6)
    for i, (fn, rz) in enumerate((("bandana_green.png", 0.45), ("bandana_navy.png", 0.15), ("bandana.png", -0.15))):
        subj.append(bandana_fold(os.path.join(TEX, fn), (0.39 + i * 0.07, -0.17 - i * 0.08), rz, i * 0.0075,
                                 "Bandana%d" % i, size=0.17))
    world_hdri("studio_small_08_2k.hdr", strength=0.35, cam_color=(0.02, 0.018, 0.016))
    area("Key", (-1.1, -0.9, 1.6), (0, 0, 0.02), 95, size=1.0, color=(1.0, 0.93, 0.84))
    area("Rim", (0.9, 1.2, 0.8), (0, 0, 0.02), 45, size=0.8, color=(0.82, 0.88, 1.0))
    area("Fill", (1.2, -1.1, 0.7), (0, 0, 0.02), 16, size=1.6)
    frame_tight(subj, 0, 62, lens=70, fill=0.92, fstop=11)


def dog(coat=None, fur=True, harness=True, curl=False, muzzle=None):
    """Bosun's LOD0 with his baked maps; `coat` recolours body + fur by luminance (keeps every strand of detail),
    `curl` adds tight Portuguese Water Dog curls (bump + crest albedo + sheen), `muzzle` lightens the muzzle."""
    asset = "M_Chr_Bosun"
    keep = lambda n: (n.startswith(asset + "_") and n.endswith("_LOD0") and (fur or "_Fur" not in n)
                      and (harness or "_Harness" not in n))
    objs = append_objects(os.path.join(SRC, "characters", asset, asset + ".blend"), keep)
    coords = []  # texture-coordinate nodes that must live in the group's space (set once the group exists)
    for o in objs:
        pbr_from_maps(o, asset)
        for m in o.data.materials:
            if not m or "Harness" in m.name or not coat:
                continue
            nt = m.node_tree
            b = nt.nodes["Principled BSDF"]
            src = b.inputs["Base Color"].links[0].from_socket
            bw = nt.nodes.new("ShaderNodeRGBToBW")
            nt.links.new(src, bw.inputs["Color"])
            g = nt.nodes.new("ShaderNodeMath")
            g.operation, g.inputs[1].default_value = "MULTIPLY", (50.0 if "Fur" in m.name else 90.0)
            nt.links.new(bw.outputs["Val"], g.inputs[0])
            pw = nt.nodes.new("ShaderNodeMath")
            pw.operation, pw.inputs[1].default_value = "POWER", 0.8
            nt.links.new(g.outputs["Value"], pw.inputs[0])
            tc = nt.nodes.new("ShaderNodeTexCoord")
            coords.append(tc)
            tint = nt.nodes.new("ShaderNodeMix")
            tint.data_type = "RGBA"
            tint.inputs["A"].default_value = (*coat, 1)
            tint.inputs["B"].default_value = (*(muzzle or coat), 1)
            if muzzle:  # lighter muzzle: the front of the head in the dog's own space (the head points to -Y)
                sep = nt.nodes.new("ShaderNodeSeparateXYZ")
                nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
                mr = node(nt, "ShaderNodeMapRange", **{"From Min": -1.36, "From Max": -1.62})
                nt.links.new(sep.outputs["Y"], mr.inputs["Value"])
                nt.links.new(mr.outputs["Result"], tint.inputs["Factor"])
            else:
                tint.inputs["Factor"].default_value = 0.0
            mx = nt.nodes.new("ShaderNodeMix")
            mx.data_type, mx.blend_type = "RGBA", "MULTIPLY"
            mx.inputs["Factor"].default_value = 1.0
            nt.links.new(pw.outputs["Value"], mx.inputs["A"])
            nt.links.new(tint.outputs["Result"], mx.inputs["B"])
            out = mx.outputs["Result"]
            if curl:  # tight curls: bumped cells whose crests catch light, darker hollows, a soft sheen on the coat
                vo = node(nt, "ShaderNodeTexVoronoi", Scale=11.0)
                nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
                cr = node(nt, "ShaderNodeMapRange", **{"From Min": 0.0, "From Max": 0.75, "To Min": 1.6, "To Max": 0.5})
                nt.links.new(vo.outputs["Distance"], cr.inputs["Value"])
                cm = nt.nodes.new("ShaderNodeMix")
                cm.data_type, cm.blend_type = "RGBA", "MULTIPLY"
                cm.inputs["Factor"].default_value = 1.0
                nt.links.new(out, cm.inputs["A"])
                nt.links.new(cr.outputs["Result"], cm.inputs["B"])
                out = cm.outputs["Result"]
                bm = node(nt, "ShaderNodeBump", Strength=1.0, Distance=0.08)
                nt.links.new(vo.outputs["Distance"], bm.inputs["Height"])
                if b.inputs["Normal"].links:
                    nt.links.new(b.inputs["Normal"].links[0].from_socket, bm.inputs["Normal"])
                nt.links.new(bm.outputs["Normal"], b.inputs["Normal"])
                b.inputs["Sheen Weight"].default_value = 0.2
                b.inputs["Sheen Roughness"].default_value = 0.35
                b.inputs["Sheen Tint"].default_value = (0.75, 0.75, 0.75, 1)
            nt.links.new(out, b.inputs["Base Color"])
    e = group(objs, asset)
    for tc in coords:
        tc.object = e
    return e, objs


DOGS = (  # name, coat, fur shells, harness, curls, muzzle, x, y, rot_z, scale
    ("Lab", (0.27, 0.165, 0.02), True, False, False, None, -2.35, 0.2, -14, 0.96),  # yellow Labrador
    ("PWD", (0.011, 0.0105, 0.0098), True, False, True, (0.045, 0.042, 0.038), 2.3, 0.2, 14, 0.92),  # curly black
    ("Bosun", None, True, True, False, None, 0.0, -0.2, -4, 0.96))  # Bosun, front and centre


def s_dog_friends():
    """Three dogs side by side on a pale sea-blue sweep: yellow Labrador, Bosun front and centre, black curly
    Portuguese Water Dog. The side dogs stand back and turn their heads outwards so no one hides behind Bosun."""
    reset()
    backdrop((0.028, 0.037, 0.047), size=15.0)  # muted slate sea-blue sweep, a soft halo behind the group
    world_hdri("studio_small_08_2k.hdr", strength=0.45)
    area("Back", (0, 1.0, 1.2), (0, 6.5, 3.5), 650, size=5.0, color=(0.95, 0.98, 1.0))
    area("DogKey", (-4.5, -5.5, 5.0), (0, 0, 1), 2200, size=2.5, color=(1.0, 0.94, 0.85))
    area("DogRim", (0.5, 2.5, 7.0), (0, 0, 1.2), 2000, size=2.0, color=(0.9, 0.93, 1.0))
    area("DogFill", (4, -5, 2.0), (0, 0, 1), 400, size=4, color=(1.0, 0.97, 0.92))
    area("RimPWD", (4.6, 3.6, 4.4), (2.3, 0.2, 1.6), 5200, size=1.4, color=(0.85, 0.9, 1.0))
    area("RimLab", (-4.6, 3.6, 4.4), (-2.35, 0.2, 1.6), 2200, size=1.4, color=(0.9, 0.93, 1.0))
    area("Catch", (0.6, -9.0, 2.8), (0, 0, 2.0), 450, size=1.2, color=(1.0, 0.98, 0.95))
    pts, dogs = [], []
    for name, coat, fur, harn, curl, muz, x, y, rz, sc in DOGS:
        e, objs = dog(coat, fur, harn, curl, muz)
        e.location, e.rotation_euler, e.scale = (x, y, 0), (0, 0, math.radians(rz)), (sc, sc, sc)
        pts += objs
        dogs.append((name, e))
    cam = frame_tight(pts, 4, 9, lens=70, fill=0.91, fstop=9)
    if os.environ.get("ICON_PROBE"):  # debug: which dog each cell of a 96x96 grid sees, for numeric colour checks
        import json
        bpy.context.view_layer.update()
        sc, dg = bpy.context.scene, bpy.context.evaluated_depsgraph_get()
        fr = [cam.matrix_world @ v for v in cam.data.view_frame(scene=sc)]  # tr, br, bl, tl
        owner = {o.name: n for n, e in dogs for o in e.children}
        grid = []
        for j in range(96):
            row = ""
            for i in range(96):
                u, v = (i + 0.5) / 96, (j + 0.5) / 96
                q = fr[3] + (fr[0] - fr[3]) * u + (fr[2] - fr[3]) * v
                hit, _, _, _, ob, _ = sc.ray_cast(dg, cam.location, (q - cam.location).normalized())
                row += owner.get(ob.name, ".")[0] if hit and ob else "."
            grid.append(row)
        json.dump(grid, open(os.path.join(OUT, "WaterDogFriends_probe.json"), "w"))


# ------------------------------------------------------------------ vehicle passes + day passes (transparent cut-outs)
# make-item-icons.py lays these on a coloured rounded-square card (finish_card); the shadow catcher keeps the floor
# shadow in the alpha.
def cutout_studio(objs, cam_az, premium=False):
    sc = bpy.context.scene
    sc.render.film_transparent = True
    try:
        sc.view_settings.look = "AgX - Punchy"
    except TypeError:
        pass
    world_hdri("studio_small_08_2k.hdr", strength=0.9)
    sun(62, cam_az - 35, 3.4, color=(1.0, 0.97, 0.92), soft=9)
    rim = sun(28, cam_az + 150, 3.0 if premium else 1.6, color=(1.0, 0.72, 0.3) if premium else (0.85, 0.92, 1.0))
    rim.data.use_shadow = False
    lo, hi = bbox(objs)
    s = (hi - lo).length * 6
    floor = obj_from("plane", "ShadowCatcher", loc=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z), scale=(s, s, 1))
    floor.is_shadow_catcher = True


def s_pass(kind, premium=False, az=35, el=17, fill=0.8, objs=None):
    if objs is None:
        reset()
        _, objs = vehicle(kind)
    cutout_studio(objs, az, premium)
    frame_tight(objs, az, el, lens=50, fill=fill)


def lifeboat():
    """Severn-class all-weather lifeboat (17.3 m x 5.9 m), bow to -Y, after the in-game code-built Builder hull:
    navy hull, orange topsides and wheelhouse, white roof, mast with a blue beacon. No Blender asset exists yet."""
    import bmesh
    navy, orange = mat("Navy", (0.01, 0.03, 0.12), rough=0.35, coat=0.5), mat("Orange", (0.95, 0.22, 0.02), rough=0.35, coat=0.4)
    white, grey = mat("White", (0.85, 0.86, 0.88), rough=0.4), mat("Deck", (0.35, 0.37, 0.4), rough=0.7)
    glass = mat("Glass", (0.01, 0.015, 0.02), rough=0.08, coat=1.0)
    blue = mat("Beacon", (0.1, 0.3, 1.0), emit=(0.1, 0.35, 1.0), emit_strength=12)
    me = bpy.data.meshes.new("Hull")
    bm = bmesh.new()
    secs = []
    for i in range(17):
        t = i / 16  # 0 stern .. 1 bow
        y = 8.6 - t * 17.2
        hb = 2.95 * (1.0 if t < 0.45 else math.sqrt(max(0.0, 1 - ((t - 0.45) / 0.55) ** 2.2)))
        hb = max(hb, 0.05)
        keel = 0.0 if t < 0.8 else (t - 0.8) * 4.0
        deck = 2.3 + 0.9 * t ** 3
        ring = [(0, keel), (hb * 0.7, keel + 0.45), (hb, 1.25), (hb, 1.75), (hb, deck), (-hb, deck), (-hb, 1.75), (-hb, 1.25),
                (-hb * 0.7, keel + 0.45)]
        secs.append([bm.verts.new((x, y, z)) for x, z in ring])
    n = len(secs[0])
    for a, b in zip(secs, secs[1:]):
        for j in range(n):
            f = bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
            zc = f.calc_center_median().z
            f.material_index = 2 if j == 4 else (1 if zc > 1.8 else 0)
    bm.faces.new(secs[0][::-1]).material_index = 1
    bm.faces.new(secs[-1]).material_index = 1
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    hull = bpy.data.objects.new("Lifeboat_Hull", me)
    bpy.context.collection.objects.link(hull)
    for m in (navy, orange, grey):
        me.materials.append(m)
    objs = [hull]
    D = 2.35
    objs.append(obj_from("cube", "Wheelhouse", orange, loc=(0, -0.4, D + 1.05), scale=(2.1, 3.0, 1.05), bevel=0.12))
    objs.append(obj_from("cube", "Roof", white, loc=(0, -0.3, D + 2.2), scale=(2.35, 3.4, 0.12), bevel=0.06))
    objs.append(obj_from("cube", "WinFront", glass, loc=(0, -3.38, D + 1.35), scale=(1.8, 0.05, 0.42), bevel=0.04))
    for sx in (-1, 1):
        for k in range(3):
            objs.append(obj_from("cube", "WinSide", glass, loc=(sx * 2.08, -2.2 + k * 1.5, D + 1.35), scale=(0.05, 0.55, 0.38), bevel=0.03))
        objs.append(obj_from("cylinder", "Rail", white, loc=(sx * 2.75, 3.2, D + 0.55), rot=(math.pi / 2, 0, 0), scale=(0.05, 0.05, 4.8), vertices=12))
        for k in range(5):
            objs.append(obj_from("cylinder", "Stanchion", white, loc=(sx * 2.75, 0.9 + k * 1.15, D + 0.3), scale=(0.04, 0.04, 0.3), vertices=8))
        objs.append(obj_from("cylinder", "Fender", orange, loc=(sx * 2.98, 0.5, 1.75), rot=(math.pi / 2, 0, 0), scale=(0.2, 0.2, 5.5), vertices=16, smooth=True))
    objs.append(obj_from("cylinder", "Mast", white, loc=(0, 0.2, D + 3.3), scale=(0.1, 0.1, 1.0), vertices=12))
    objs.append(obj_from("cube", "Yard", white, loc=(0, 0.2, D + 3.7), scale=(1.4, 0.07, 0.07)))
    objs.append(obj_from("uv_sphere", "Beacon", blue, loc=(0, 0.2, D + 4.45), scale=(0.22, 0.22, 0.2), smooth=True))
    objs.append(obj_from("uv_sphere", "Radome", white, loc=(0.9, -1.6, D + 2.45), scale=(0.45, 0.45, 0.22), smooth=True))
    objs.append(obj_from("cube", "Tow", white, loc=(0, 6.2, D + 0.7), scale=(0.25, 0.25, 0.7)))
    return objs


def s_lifeboat_pass():
    reset()
    s_pass(None, objs=lifeboat())


def coin(m, loc, rot=(0, 0, 0), r=1.0):
    """Gold coin with a raised rim ring and centre boss on both faces, joined into one mesh."""
    parts = [obj_from("cylinder", "Coin", m, scale=(r, r, 0.1 * r), vertices=64, bevel=0.03 * r, smooth=True)]
    for sz in (1, -1):
        parts.append(obj_from("torus", "Rim", m, loc=(0, 0, sz * 0.09 * r), major_radius=0.84 * r, minor_radius=0.04 * r,
                              major_segments=64, minor_segments=12, smooth=True))
        parts.append(obj_from("cylinder", "Boss", m, loc=(0, 0, sz * 0.1 * r), scale=(0.55 * r, 0.55 * r, 0.025 * r),
                              vertices=48, smooth=True))
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    c = parts[0]
    c.location, c.rotation_euler = loc, rot
    return [c]


def s_day_cash():
    reset()
    gold = mat("Gold", (1.0, 0.68, 0.1), rough=0.3, metal=1.0, coat=0.2)
    objs = []
    for (x, y, n) in ((-1.15, 1.0, 7), (1.15, 1.15, 5), (0.0, -0.85, 3)):
        for i in range(n):
            objs += coin(gold, (x + 0.04 * math.sin(i * 1.7), y + 0.04 * math.cos(i * 2.3), 0.13 + i * 0.25),
                         rot=(0, 0, i * 0.4))
    objs += coin(gold, (-1.75, -1.0, 0.95), rot=(math.radians(72), 0, math.radians(-30)))
    objs += coin(gold, (1.7, -0.75, 0.7), rot=(math.radians(65), 0, math.radians(30)), r=0.75)
    bpy.context.view_layer.update()
    cutout_studio(objs, 20)
    frame_tight(objs, 20, 32, lens=60, fill=0.86)


def s_day_launch():
    reset()
    _, objs = vehicle("M_Veh_JetSki")
    cutout_studio(objs, -48)
    frame_tight(objs, -48, 20, lens=50, fill=0.9)


SCENES = {
    "SmallBonus": s_small,
    "CrewPayroll": s_payroll,
    "StationBudget": s_budget,
    "HarborFund": s_fund_crate,
    "CashBoost": s_cashboost_hero,
    "CrewBoost": s_crewboost_vhf,
    "CallTheStorm": s_storm,
    "CallTheGreatStorm": s_greatstorm,
    "ChallengeReroll": s_clipboard,
    "SeasonLogbook": lambda: s_logbook(True),
    "DoubleCash": s_double_box,
    "VipCrewCard": s_card,
    "QuickLaunch": lambda: s_sea_vehicle("M_Veh_RIB", 32, 5, wake=True, pitch=7, yaw=-25, fill=0.9),
    "StarterKit": s_starter_kit,
    "BosunsWardrobe": s_wardrobe,
    "WaterDogFriends": s_dog_friends,
    "StormChaserLiveries": lambda: s_sea_vehicle("M_Veh_JetSki", 35, 8, calm=False, bolt=True, fill=0.82,
                                                 livery=({"PWCOrange", "PWCOrangeDark", "SledOrange"}, (0.02, 0.06, 0.2))),
    "CaptainsLocker": s_locker,
    "SeaShantyRadio": s_radio,
    "HornPack": s_horns,
    "SirenPack": lambda: s_beacon(((0.05, 0.25, 1.0),)),
    "LightBars": lambda: s_beacon(((1.0, 0.04, 0.02), (0.05, 0.25, 1.0)), bar=True),
    "WakeTrails": lambda: s_sea_vehicle("M_Veh_JetSki", 165, 30, wake=True, fill=0.70),
    "RIBPass": lambda: s_pass("M_Veh_RIB"),
    "LifeboatPass": s_lifeboat_pass,
    "BeachATVPass": lambda: s_pass("M_Veh_ATV"),
    "CoastguardResponsePass": lambda: s_pass("M_Veh_Coastguard4x4"),
    "StormRunnerPass": lambda: s_pass("M_Veh_StormRunner", premium=True),
    "TidewalkerPass": lambda: s_pass("M_Veh_Tidewalker", premium=True),
    "RiptideXPass": lambda: s_pass("M_Veh_JetSki_RiptideX", premium=True),
    "GildedGullPass": lambda: s_pass("M_Veh_JetSki_GildedGull", premium=True),
    "HarbourGTPass": lambda: s_pass("M_Veh_HarbourGT", premium=True),
    "LighthouseCruiserPass": lambda: s_pass("M_Veh_LighthouseCruiser", premium=True),
    "DayDoubleCash": s_day_cash,
    "DayQuickLaunch": s_day_launch,
}

os.makedirs(OUT, exist_ok=True)
failed = []
for k in KEYS:
    if k not in SCENES:
        print("[icons] no scene for", k)
        failed.append(k)
        continue
    try:
        SCENES[k]()
        render(k)
    except Exception as e:
        import traceback
        traceback.print_exc()
        failed.append(k)
print("[icons] FAILED:", ",".join(failed) if failed else "none", flush=True)
