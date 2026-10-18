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
def ocean(size=400.0, wave=1.0, chop=1.0, wind=10.0, res=14, color=(0.004, 0.018, 0.022), seed=7, foam=0.6):
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
    mix.inputs["B"].default_value = (0.75, 0.8, 0.8, 1)
    nt.links.new(mulf.outputs["Value"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    rmix = nt.nodes.new("ShaderNodeMapRange")
    rmix.inputs["To Min"].default_value = 0.035
    rmix.inputs["To Max"].default_value = 0.6
    nt.links.new(mulf.outputs["Value"], rmix.inputs["Value"])
    nt.links.new(rmix.outputs["Result"], b.inputs["Roughness"])
    o.data.materials.append(m)
    return o


def wood_table(size=3.0, z=0.0, tone=(0.16, 0.085, 0.04)):
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


def lightning(start, end, seed=1, strength=60.0, width=0.08, branches=3, color=(0.75, 0.82, 1.0)):
    rng = random.Random(seed)
    m = mat("Bolt", color=(0, 0, 0), rough=1, emit=color, emit_strength=strength)

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
    reset()
    bpy.context.scene.view_settings.exposure = 0.5
    sea = ocean(size=160, wave=9.0, chop=1.6, wind=36, res=16, seed=11, foam=0.45, color=(0.003, 0.014, 0.018))
    rib, objs = vehicle("M_Veh_RIB")
    rib.rotation_euler = (0, 0, math.radians(-35))
    float_on(sea, rib, objs, draft=0.3, follow=0.9)
    storm_sky(1.4)
    lo, hi = bbox(objs)
    L = hi.y - lo.y
    area("Key", (-L, -L, L), (0, 0, 2), 90 * L * L, size=L * 0.5, color=(1.0, 0.9, 0.75))
    cam = frame(objs, 30, 1, lens=30, fill=0.75, lift=0.4)
    q = cam.matrix_world.to_quaternion()
    back, side = q @ Vector((0, 0, -1)), q @ Vector((1, 0, 0))
    for sgn, seed, st in ((-1, 8, 320), (1, 3, 240)):
        far = cam.location + back * L * 9 + side * sgn * L * 2.2
        top = far + Vector((0, 0, L * 4.5))
        lightning(top, (top.x + L * 0.3, top.y, -1), seed=seed, strength=st, width=L * 0.02, branches=3)


def s_sea_vehicle(kind, az, el, lens=45, calm=True, livery=None, bolt=False, wake=False, fill=0.92):
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
    veh.rotation_euler = (0, 0, math.radians(0 if wake else -20))
    float_on(sea, veh, objs, draft=0.25, follow=0.6)
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
    ramp.color_ramp.elements[0].position = 0.12
    ramp.color_ramp.elements[1].position = 0.3
    nt.links.new(fade.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf(m).inputs["Alpha"])
    w = (hi.x - lo.x) * 1.3
    L = (hi.y - lo.y) * 5
    bpy.ops.mesh.primitive_plane_add(size=1)
    o = bpy.context.active_object
    o.scale = (w, L, 1)
    bpy.ops.object.transform_apply(scale=True)
    for v in o.data.vertices:  # V shape widening behind the stern
        t = (v.co.y + L / 2) / L
        v.co.x *= 0.4 + 1.8 * (1 - t)
    o.location = ((lo.x + hi.x) / 2, lo.y - L / 2 + (hi.y - lo.y) * 0.1, 0.05)
    o.data.materials.append(m)


def s_bosun(variants):
    reset()
    product_studio(key_power=50, back=(0.2, 0.21, 0.22), scale=2.5)
    area("DogRim", (0, 6, 4), (0, 0, 1), 900, size=2.5, color=(0.9, 0.93, 1.0))
    pts = []
    n = len(variants)
    for i, tint in enumerate(variants):
        dog, objs = lod0_asset("characters", "M_Chr_Bosun", tint)
        x = (i - (n - 1) / 2) * 1.9
        dog.location = (x * 1.25, abs(i - (n - 1) / 2) * 1.2, 0)
        dog.rotation_euler = (0, 0, math.radians(-30 + 30 * (i - (n - 1) / 2)))
        pts += objs
    bpy.context.view_layer.update()
    lo, hi = bbox(pts)
    frame(pts, 20, 12, lens=60, fill=0.96, fstop=8)


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


SCENES = {
    "SmallBonus": s_small,
    "CrewPayroll": s_payroll,
    "StationBudget": s_budget,
    "HarborFund": s_fund,
    "CashBoost": s_cashboost,
    "CrewBoost": s_crewboost,
    "CallTheStorm": s_storm,
    "CallTheGreatStorm": s_greatstorm,
    "ChallengeReroll": lambda: s_logbook(False),
    "SeasonLogbook": lambda: s_logbook(True),
    "DoubleCash": s_double,
    "VipCrewCard": s_card,
    "QuickLaunch": lambda: s_sea_vehicle("M_Veh_RIB", 35, 9),
    "StarterKit": lambda: s_sea_vehicle("M_Veh_JetSki", 40, 10, fill=0.84),
    "BosunsWardrobe": lambda: s_bosun([None]),
    "WaterDogFriends": lambda: s_bosun([(0.5, 0.35, 1.9), None, (0.5, 0.2, 0.25)]),
    "StormChaserLiveries": lambda: s_sea_vehicle("M_Veh_JetSki", 35, 8, calm=False, bolt=True, fill=0.82,
                                                 livery=({"PWCOrange", "PWCOrangeDark", "SledOrange"}, (0.02, 0.06, 0.2))),
    "CaptainsLocker": s_locker,
    "SeaShantyRadio": s_radio,
    "HornPack": s_horns,
    "SirenPack": lambda: s_beacon(((0.05, 0.25, 1.0),)),
    "LightBars": lambda: s_beacon(((1.0, 0.04, 0.02), (0.05, 0.25, 1.0)), bar=True),
    "WakeTrails": lambda: s_sea_vehicle("M_Veh_JetSki", 165, 30, wake=True, fill=0.70),
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
