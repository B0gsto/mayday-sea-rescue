"""Lego-toy VFX flipbook sheets (docs/26-vfx.md, docs/05-art-direction.md 7).

Ten square RGBA sprite sheets, frames left-to-right / top-to-bottom (Roblox ParticleEmitter
FlipbookLayout Grid2x2 / Grid4x4), transparent film, straight alpha with edge RGB bled so
there are no dark halos. Rendered with EEVEE (headless-safe, seconds per sheet).

  ~/RobloxProjects/tools/blender-run.sh art/source/vfx/render.py

Writes build/prod/vfx/<name>.png, build/prod/vfx/sheet.png (contact sheet on mid-blue and
light) and prints per-cell alpha coverage. Run from anywhere; paths are repo-relative.
"""
import math
import os
import random
import shutil
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT = os.path.join(REPO, "build", "prod", "vfx")
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
from rope import write_png  # noqa: E402  (zlib PNG writer; no Pillow in Blender)

TAU = math.pi * 2
SHEET = 1024

# sRGB palette (converted to linear for Blender inputs)
FOAM = "#F4FBFF"
SEA = "#2E9DC4"
SEA_DEEP = "#1E7FA6"
PALE = "#BFE9F4"
GOLD = "#F0B429"
GOLD_LIGHT = "#FFD35A"
GOLD_DEEP = "#C98C18"
SMOKE = "#DCE1E5"
PLASTIC = "#F2F2EF"
RAIN = "#D8EEF8"
BLUE_BG = "#3E7FA8"
LIGHT_BG = "#EFEFEA"
INK = "#E8EBEE"


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# ---------------------------------------------------------------- scene


def scene(res, ortho, elev=14, yaw=0, target=(0, 0, 0.15), top=False, dist=14):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    sc.render.image_settings.compression = 15
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.eevee.taa_render_samples = 48
    try:
        sc.eevee.use_raytracing = True
    except AttributeError:
        pass
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.data.clip_start = 0.1
    cam.data.clip_end = 200
    e, y = math.radians(elev), math.radians(yaw)
    cam.location = (target[0] + dist * math.cos(e) * math.sin(y),
                    target[1] - dist * math.cos(e) * math.cos(y),
                    target[2] + dist * math.sin(e))
    cam.rotation_euler = (math.radians(90) - e, 0, y)
    sc.camera = cam

    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*lin("#7E93A6"), 1)
    bg.inputs["Strength"].default_value = 0.55
    sc.world = world

    if top:
        area(sc, "Key", (-4, -4, 9), 900, 6, "#FFF4E2")
        area(sc, "Fill", (4.5, -3, 7), 300, 6, "#D9EAFF")
        area(sc, "Rim", (0.5, 5, 8), 650, 5, "#FFFFFF")
    else:
        area(sc, "Key", (-4.5, -5.5, 6.5), 800, 5, "#FFF4E2")
        area(sc, "Fill", (5.5, -3, 3), 280, 6, "#D9EAFF")
        area(sc, "Rim", (0.5, 5.5, 4.5), 650, 4, "#FFFFFF")
    return sc


def area(sc, name, loc, energy, size, hexcol):
    d = bpy.data.lights.new(name, "AREA")
    d.energy = energy
    d.shape = "SQUARE"
    d.size = size
    d.color = lin(hexcol)
    o = bpy.data.objects.new(name, d)
    sc.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


# ---------------------------------------------------------------- materials


def plastic(name, hexcol, rough=0.32, alpha=1.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Alpha"].default_value = alpha
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(hexcol), 1)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        m.surface_render_method = "BLENDED"
    return m


def water_mat(name, zmax=0.62):
    """Sea-blue at the base, white foam at the tip: reads on both mid-blue and light backgrounds."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = zmax
    mr.inputs["To Min"].default_value = 0.0
    mr.inputs["To Max"].default_value = 1.0
    mr.clamp = True
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    cr = ramp.color_ramp
    cr.interpolation = "EASE"
    cr.elements[0].position, cr.elements[0].color = 0.0, (*lin(SEA_DEEP), 1)
    cr.elements[1].position, cr.elements[1].color = 0.88, (*lin(FOAM), 1)
    for pos, col in ((0.38, "#57C1DE"), (0.62, "#C9EEF8")):
        e = cr.elements.new(pos)
        e.color = (*lin(col), 1)
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.28
    b.inputs["Emission Color"].default_value = (*lin(FOAM), 1)
    b.inputs["Emission Strength"].default_value = 0.04
    return m


def key_alpha(m, keys):
    b = m.node_tree.nodes["Principled BSDF"]
    for f, a in keys:
        b.inputs["Alpha"].default_value = a
        b.inputs["Alpha"].keyframe_insert("default_value", frame=f)


# ---------------------------------------------------------------- geometry


def empty(name, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = loc
    return e


def sphere(name, loc, scale, mat, seg=32, rings=16):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    return o


def cube(name, loc, size, mat, bevel=0.03, rot=(0, 0, 0)):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(40)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=b.name)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    o.data.materials.append(mat)
    return o


def cylinder(name, loc, radius, depth, mat, verts=32, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(40)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=b.name)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    else:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    o.data.materials.append(mat)
    return o


def torus(name, loc, major, minor, mat, rot=(0, 0, 0), scale=(1, 1, 1), maj_seg=64, min_seg=14):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=maj_seg, minor_segments=min_seg,
                                     location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    return o


def annulus(name, r_in, r_out, mat, z=0.0, seg=96):
    """Flat ring in XY with radial alpha gradient in its material (top-down shockwave)."""
    verts, faces = [], []
    for i in range(seg):
        a = TAU * i / seg
        verts.append((r_in * math.cos(a), r_in * math.sin(a), z))
        verts.append((r_out * math.cos(a), r_out * math.sin(a), z))
    for i in range(seg):
        j = (i + 1) % seg
        faces.append((2 * i, 2 * i + 1, 2 * j + 1, 2 * j))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def ring_mat(name, hexcol, r_in, r_peak, r_out, strength=1.0):
    """Emission ring whose alpha fades in to r_peak and out to r_out; Value node keyed per frame."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord")
    ln = nt.nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    mr1 = nt.nodes.new("ShaderNodeMapRange")
    mr1.inputs["From Min"].default_value = r_in
    mr1.inputs["From Max"].default_value = r_peak
    mr1.clamp = True
    mr2 = nt.nodes.new("ShaderNodeMapRange")
    mr2.inputs["From Min"].default_value = r_peak
    mr2.inputs["From Max"].default_value = r_out
    mr2.inputs["To Min"].default_value = 1.0
    mr2.inputs["To Max"].default_value = 0.0
    mr2.clamp = True
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    val = nt.nodes.new("ShaderNodeValue")
    mul2 = nt.nodes.new("ShaderNodeMath")
    mul2.operation = "MULTIPLY"
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*lin(hexcol), 1)
    em.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tc.outputs["Object"], ln.inputs[0])
    nt.links.new(ln.outputs["Value"], mr1.inputs["Value"])
    nt.links.new(mr1.outputs["Result"], mr2.inputs["Value"])
    nt.links.new(mr1.outputs["Result"], mul.inputs[0])
    nt.links.new(mr2.outputs["Result"], mul.inputs[1])
    nt.links.new(mul.outputs[0], mul2.inputs[0])
    nt.links.new(val.outputs[0], mul2.inputs[1])
    nt.links.new(mul2.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    m.surface_render_method = "BLENDED"
    return m, val


def key_val(node, keys):
    for f, v in keys:
        node.outputs[0].default_value = v
        node.outputs[0].keyframe_insert("default_value", frame=f)


def lathe(name, profile, mat, loc=(0, 0, 0), steps=40, subsurf=2):
    """Spin an (r, z) profile around local Z: chunky water drops / spikes in one smooth mesh."""
    me = bpy.data.meshes.new(name)
    verts = [(r, 0.0, z) for r, z in profile]
    edges = [(i, i + 1) for i in range(len(verts) - 1)]
    me.from_pydata(verts, edges, [])
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    s = o.modifiers.new("Screw", "SCREW")
    s.axis = "Z"
    s.angle = TAU
    s.steps = steps
    s.render_steps = steps
    s.use_merge_vertices = True
    s.use_normal_calculate = True
    if subsurf:
        sub = o.modifiers.new("Sub", "SUBSURF")
        sub.levels = subsurf
        sub.render_levels = subsurf
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    return o


def arc(name, radius, a0, a1, thick, mat, center=(0, 0, 0), steps=36, taper=True):
    """Tapered round tube along an arc in the XZ plane (front view)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(steps)
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(a0 + (a1 - a0) * t)
        sp.points[i].co = (center[0] + radius * math.cos(a), center[1], center[2] + radius * math.sin(a), 1)
        sp.points[i].radius = (0.16 + 0.84 * math.sin(math.pi * t)) if taper else 1.0
    cu.bevel_depth = thick
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def streak(name, p0, p1, thick, mat, taper=(0.18, 1.0, 0.18)):
    """Tapered straight tube with capped ends (rain / motion streak)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(2)
    pts = [p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2), p1]
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1)
        sp.points[i].radius = taper[i]
    cu.bevel_depth = thick
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def key(o, path, keys):
    for f, v in keys:
        setattr(o, path, v)
        o.keyframe_insert(data_path=path, frame=f)


def key_quat(o, tangent, keys):
    o.rotation_mode = "QUATERNION"
    for f, deg in keys:
        o.rotation_quaternion = Quaternion(Vector(tangent), math.radians(deg))
        o.keyframe_insert("rotation_quaternion", frame=f)


def radial_keys(o, th, keys, z=0.0):
    for f, r in keys:
        o.location = (r * math.cos(th), r * math.sin(th), z)
        o.keyframe_insert("location", frame=f)


# ---------------------------------------------------------------- 1 splash crown


def build_splash(sc):
    sc = scene(256, 1.75, elev=14, target=(0, 0, 0.20))
    water = water_mat("Water", 0.62)
    foam = plastic("Foam", FOAM, 0.42)
    sea = plastic("Sea", SEA, 0.35)

    sphere("base", (0, 0, -0.04), (0.46, 0.46, 0.11), sea, seg=40)
    torus("basering", (0, 0, 0.02), 0.48, 0.10, foam, scale=(1, 1, 0.55))

    prof = [(0, 0.0), (0.12, 0.02), (0.155, 0.10), (0.145, 0.24), (0.10, 0.40), (0.045, 0.52), (0, 0.57)]
    for i in range(9):
        th = TAU * i / 9 + 0.18
        o = lathe("spike%d" % i, prof, water, loc=(0.30 * math.cos(th), 0.30 * math.sin(th), 0))
        tangent = (-math.sin(th), math.cos(th), 0)
        key_quat(o, tangent, [(1, 12 + 3 * (i % 3)), (7, 22 + 6 * (i % 3)), (16, 30 + 4 * (i % 2))])
        key(o, "scale", [(1, (1, 1, 0.12)), (4, (1, 1, 0.55)), (7, (1, 1, 1.0)),
                         (10, (1, 1, 0.92)), (13, (1, 1, 0.50)), (16, (1, 1, 0.22))])
        radial_keys(o, th, [(1, 0.30), (7, 0.36), (16, 0.44)])

    prof2 = [(0, -0.05), (0.15, 0.0), (0.18, 0.12), (0.16, 0.30), (0.11, 0.48), (0.05, 0.62), (0, 0.68)]
    col = lathe("column", prof2, water)
    key(col, "scale", [(1, (0.9, 0.9, 0.20)), (5, (1, 1, 0.80)), (7, (1, 1, 1.0)),
                       (10, (1, 1, 0.82)), (14, (1, 1, 0.32)), (16, (0.9, 0.9, 0.18))])
    cap = sphere("cap", (0, 0, 0.46), (0.13, 0.13, 0.11), foam)
    key(cap, "scale", [(1, (0.07, 0.07, 0.06)), (5, (0.14, 0.14, 0.11)), (7, (0.15, 0.15, 0.12)),
                       (11, (0.12, 0.12, 0.10)), (15, (0.04, 0.04, 0.03))])
    key(cap, "location", [(1, (0, 0, 0.30)), (5, (0, 0, 0.55)), (7, (0, 0, 0.62)),
                          (11, (0, 0, 0.58)), (15, (0, 0, 0.32))])

    for i in range(9):
        th = TAU * i / 9 + 0.5
        m = foam if i % 3 else sea
        d = sphere("drop%d" % i, (0, 0, 0), (0.06, 0.06, 0.085), m, seg=16, rings=10)
        key(d, "location", [(3, (0.28 * math.cos(th), 0.28 * math.sin(th), 0.10)),
                            (7, (0.48 * math.cos(th), 0.48 * math.sin(th), 0.46 + 0.08 * (i % 3))),
                            (11, (0.62 * math.cos(th), 0.62 * math.sin(th), 0.28)),
                            (15, (0.70 * math.cos(th), 0.70 * math.sin(th), -0.02))])
        key(d, "scale", [(1, (0, 0, 0)), (4, (0.06, 0.06, 0.085)), (12, (0.06, 0.06, 0.085)),
                         (15, (0, 0, 0))])

    return sc


# ---------------------------------------------------------------- 2 droplets


DROP_PROFILE = [(0, -0.48), (0.26, -0.44), (0.44, -0.28), (0.50, 0.0),
                (0.44, 0.20), (0.28, 0.40), (0.12, 0.54), (0, 0.60)]


def build_droplet(sc, i):
    sc = scene(512, 1.85, elev=6, target=(0, 0, 0.04))
    water = water_mat("Water", 0.60)
    tilt = (0, 14, -12, 7)[i]
    spin = (0, 40, -30, 90)[i]
    scale = (1.0, 0.88, 0.94, 0.82)[i]
    o = lathe("drop", DROP_PROFILE, water, loc=(0, 0, 0.02), steps=48, subsurf=2)
    o.rotation_euler = (math.radians(4 * (i % 2)), math.radians(tilt), math.radians(spin))
    o.scale = (scale, scale, scale)
    b = (0.30, -0.34, 0.38, 0.30)[i]
    sphere("bit", (0.42 * (1 if i % 2 else -1), -0.05, b), (0.075, 0.075, 0.10), water, seg=16, rings=10)
    return sc


# ---------------------------------------------------------------- 3 foam ring


def build_foam(sc):
    sc = scene(256, 3.2, elev=90, target=(0, 0, 0), top=True)
    foam = plastic("Foam", FOAM, 0.42)
    shade = plastic("FoamShade", "#BFDDEA", 0.48)
    early = plastic("FoamEarly", "#DCEFF7", 0.50, alpha=0.90)
    key_alpha(early, [(1, 0.90), (6, 0), (16, 0)])
    torus("inner", (0, 0, 0.03), 0.36, 0.10, early, scale=(1, 1, 0.22))

    rnd = random.Random(11)
    # biggest ring ~85% of the cell (half-width 1.6): outer blobs end at r ~1.12 + blob size; bursts pop over 7..16
    rows = ((24, 0.52, 0.05, 0.160, 0.215, 1.12, 9, 16),
            (15, 0.38, 0.04, 0.100, 0.140, 0.92, 6, 14))
    for row, (count, rbase, rj, smin, smax, rmax, bmin, bmax) in enumerate(rows):
        for i in range(count):
            th = TAU * (i + 0.35 * row) / count + rnd.uniform(-0.07, 0.07)
            r0 = rbase + rnd.uniform(-rj, rj)
            r1 = rmax + rnd.uniform(-0.05, 0.05)
            s = rnd.uniform(smin, smax)
            br = rnd.randint(bmin, bmax)
            z = 0.04 + rnd.uniform(0, 0.03)
            main = sphere("foam%d_%d" % (row, i), (r0 * math.cos(th), r0 * math.sin(th), z),
                          (s, s, s * 0.40), foam if i % 4 == 0 else shade, seg=20, rings=12)
            top = sphere("foamtop%d_%d" % (row, i), (r0 * math.cos(th), r0 * math.sin(th), z + s * 0.22),
                         (s * 0.55, s * 0.55, s * 0.34), foam, seg=16, rings=10)
            for o, base in ((main, (s, s, s * 0.40)), (top, (s * 0.55, s * 0.55, s * 0.34))):
                radial_keys(o, th, [(1, r0), (16, r1)], z=o.location.z)
                key(o, "scale", [(1, tuple(v * 0.45 for v in base)), (4, base), (br, base),
                                 (br + 3, (0.01, 0.01, 0.01))])
    return sc


# ---------------------------------------------------------------- 4 puff smoke


def build_puff(sc):
    sc = scene(256, 1.9, elev=12, target=(0, 0, 0.36))
    smoke = plastic("Smoke", SMOKE, 0.52)  # opaque: the emitter's Transparency does the fade, no soft blur here
    # 5 big studded toy balls (x, z, r, pop frame): each shrinks, then pops out in one frame
    balls = [(0.0, 0.10, 0.42, 14), (0.44, 0.04, 0.30, 12), (-0.42, 0.08, 0.31, 16),
             (0.16, 0.58, 0.27, 11), (-0.22, 0.56, 0.23, 13)]
    dirs = [Vector((0, 0, 1)), Vector((0.62, 0.1, 0.78)), Vector((-0.55, 0.15, 0.82)),
            Vector((0.2, -0.65, 0.73))]
    for i, (x, z, r, pop) in enumerate(balls):
        e = empty("ball%d" % i, (x, 0, z))
        s_ = sphere("blob%d" % i, (0, 0, 0), (r, r, r * 0.96), smoke, seg=24, rings=14)
        s_.parent = e
        for j, n in enumerate(dirs[:2 + (i % 3)]):
            n = n.normalized()
            stud = cylinder("stud%d_%d" % (i, j), n * (r * 0.99 + 0.03), 0.10, 0.11, smoke, verts=20, bevel=0.015)
            stud.rotation_euler = n.to_track_quat("Z", "Y").to_euler()
            stud.parent = e
        key(e, "scale", [(1, (0.5, 0.5, 0.5)), (4, (1, 1, 1)), (8, (1, 1, 1)),
                         (pop, (0.62, 0.62, 0.62)), (pop + 1, (0.01, 0.01, 0.01))])
        key(e, "location", [(1, (x, 0, z)), (16, (x, 0, z + 0.16))])
    return sc


# ---------------------------------------------------------------- 5/6 lego pieces


def lego_piece(name, cells_x, cells_y, height, mat, studs=True, round_=False):
    e = empty(name)
    if round_:
        base = cylinder(name + "_base", (0, 0, height / 2), 0.78, height, mat, verts=48, bevel=0.035)
        base.parent = e
        if studs:
            s = cylinder(name + "_stud", (0, 0, height + 0.075), 0.24, 0.17, mat, verts=32, bevel=0.02)
            s.parent = e
        return e
    base = cube(name + "_base", (0, 0, height / 2), (cells_x * 0.8, cells_y * 0.8, height), mat, bevel=0.03)
    base.parent = e
    if studs:
        for ix in range(cells_x):
            for iy in range(cells_y):
                x = (ix - (cells_x - 1) / 2) * 0.8
                y = (iy - (cells_y - 1) / 2) * 0.8
                s = cylinder(name + "_stud%d%d" % (ix, iy), (x, y, height + 0.075),
                             0.235, 0.17, mat, verts=28, bevel=0.02)
                s.parent = e
    return e


def build_plate(sc, i):
    specs = [((1, 1), False, 1.40, 24, 12), ((2, 1), False, 2.00, -26, 10),
             ((2, 2), False, 2.55, 32, 14), ((2, 2), True, 2.55, -18, 10)]
    (cx, cy), rnd, ortho, yaw, tilt = specs[i]
    sc = scene(512, ortho, elev=38, target=(0, 0, 0.22))
    e = lego_piece("plate%d" % i, cx, cy, 0.32, plastic("Plate", PLASTIC, 0.33), True, rnd)
    e.location = (0, 0, 0.22)
    e.rotation_euler = (math.radians(tilt), 0, math.radians(yaw))
    return sc


def build_brick(sc, i):
    specs = [((1, 1), 0.96, True, 2.30, 28, 12, 0.60), ((2, 1), 0.96, True, 2.60, -22, 14, 0.60),
             ((2, 1), 0.32, False, 2.60, 34, 10, 0.20), ((4, 1), 0.32, False, 3.90, -14, 12, 0.20)]
    (cx, cy), h, studs, ortho, yaw, tilt, tz = specs[i]
    sc = scene(512, ortho, elev=32, target=(0, 0, tz))
    e = lego_piece("brick%d" % i, cx, cy, h, plastic("Brick", PLASTIC, 0.33), studs)
    e.location = (0, 0, tz)
    e.rotation_euler = (math.radians(tilt), 0, math.radians(yaw))
    return sc


# ---------------------------------------------------------------- 7 coin


def build_coin(sc):
    sc = scene(256, 1.85, elev=16, target=(0, 0, 0.08))
    gold = plastic("Gold", GOLD, 0.28, emit=0.05)
    hi = plastic("GoldHi", GOLD_LIGHT, 0.26, emit=0.05)
    deep = plastic("GoldDeep", GOLD_DEEP, 0.30)

    spin = empty("spin")
    coin = cylinder("coin", (0, 0, 0), 0.72, 0.18, gold, verts=64, bevel=0.035, rot=(math.radians(90), 0, 0))
    coin.parent = spin
    for sy in (-1, 1):
        y = 0.10 * sy
        rim = torus("rim%d" % sy, (0, y, 0), 0.63, 0.025, deep, rot=(math.radians(90), 0, 0))
        rim.parent = spin
        ring = torus("anchorring%d" % sy, (0, 0.115 * sy, 0.40), 0.10, 0.028, hi, rot=(math.radians(90), 0, 0))
        ring.parent = spin
        shank = cube("shank%d" % sy, (0, 0.115 * sy, -0.01), (0.075, 0.05, 0.58), hi, bevel=0.015)
        shank.parent = spin
        bar = cube("bar%d" % sy, (0, 0.115 * sy, 0.17), (0.34, 0.05, 0.06), hi, bevel=0.012)
        bar.parent = spin
        arms = arc("arms%d" % sy, 0.19, 205, 335, 0.032, hi, center=(0, 0.115 * sy, -0.12), steps=28)
        arms.parent = spin
        for sx in (-1, 1):
            a = math.radians(205 if sx < 0 else 335)
            tip = sphere("tip%d%d" % (sy, sx),
                         (0.19 * math.cos(a), 0.115 * sy, -0.12 + 0.19 * math.sin(a)),
                         (0.05, 0.04, 0.05), hi, seg=16, rings=10)
            tip.parent = spin

    for f in range(1, 17):
        spin.rotation_euler.z = TAU * (f - 1) / 16
        spin.keyframe_insert("rotation_euler", frame=f)
    return sc


# ---------------------------------------------------------------- 8 shockwave


def solid_ring_mat(name, hexcol):
    """Flat opaque emission; the keyed Value is the whole alpha (crisp toy band, no radial gradient)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    val = nt.nodes.new("ShaderNodeValue")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*lin(hexcol), 1)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(val.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    m.surface_render_method = "BLENDED"
    return m, val


def build_shockwave(sc):
    sc = scene(256, 3.4, elev=90, target=(0, 0, 0), top=True)
    # one chunky white band (inner/outer 0.58): outer radius 1.42 of the 1.7 half-cell = 84%
    m, v = solid_ring_mat("shock", FOAM)
    o = annulus("shock", 0.58, 1.0, m, z=0.05, seg=128)
    key_val(v, [(1, 1.0), (10, 1.0), (16, 0.45)])
    key(o, "scale", [(1, (0.30, 0.30, 1)), (4, (0.72, 0.72, 1)), (8, (1.08, 1.08, 1)),
                     (12, (1.28, 1.28, 1)), (16, (1.42, 1.42, 1))])
    return sc


# ---------------------------------------------------------------- 9 spin streaks


def build_spin(sc, i):
    sc = scene(512, 2.4, elev=0, target=(0, 0, 0))
    white = plastic("Streak", "#FFFFFF", 0.45, alpha=0.95, emit=1.0)
    # same centre, radius and mid-angle (90 deg) every frame, only the sweep varies; the emitter rotates it
    half = (50, 62, 75, 62)[i]
    arc("streak", 0.86, 90 - half, 90 + half, 0.09, white, steps=36)
    return sc


# ---------------------------------------------------------------- 10 rain streak


def build_rain(sc, i):
    sc = scene(512, 1.5, elev=0, target=(0, 0, 0))
    m = plastic("Rain", RAIN, 0.40, alpha=0.95, emit=0.10)
    tilt = (8, 12, 6, 10)[i]
    length = (0.90, 1.00, 1.05, 0.95)[i]
    th = (0.075, 0.085, 0.080, 0.090)[i]
    a = math.radians(tilt)
    p0 = (-math.sin(a) * length / 2, 0, -math.cos(a) * length / 2)
    p1 = (math.sin(a) * length / 2, 0, math.cos(a) * length / 2)
    streak("rain", p0, p1, th, m, taper=(1.0, 0.9, 0.18))
    sphere("head", p0, (0.105, 0.08, 0.11), m, seg=20, rings=12)
    return sc


# ---------------------------------------------------------------- 11 studded ring (FX1 spectacle)


def build_stud_ring(sc):
    sc = scene(256, 3.4, elev=90, target=(0, 0, 0), top=True)
    # a crisp band with a ring of round studded 1x1 plates riding it; it races out, then the plates pop one by one
    m, v = solid_ring_mat("studband", FOAM)
    band = annulus("studband", 0.86, 1.0, m, z=0.0, seg=128)
    key_val(v, [(1, 1.0), (11, 1.0), (16, 0.35)])
    white = plastic("StudPlate", "#B9BEC4", 0.38)  # lit, not emissive: the studs must shade to read as Lego
    n = 14
    radius = [0.32 + 1.0 * (1 - (1 - (f - 1) / 15) ** 2.4) for f in range(1, 17)]
    for f in range(1, 17):
        band.scale = (radius[f - 1] * 1.04, radius[f - 1] * 1.04, 1)
        band.keyframe_insert("scale", frame=f)
    for i in range(n):
        a = TAU * i / n
        p = lego_piece("sp%d" % i, 1, 1, 0.32, white, round_=True)
        pop = 11 + (i * 7 % n) * 5 / n  # pops spread over frames 11-16
        for f in range(1, 17):
            r = radius[f - 1] * 0.93
            p.location = (r * math.cos(a), r * math.sin(a), 0.02)
            p.rotation_euler = (0.35 * math.sin(a), -0.35 * math.cos(a), 0)  # tipped outward: the stud side shows
            p.keyframe_insert("location", frame=f)
            s = 0.25 if f < pop else (0.3 if f < pop + 1 else 0.0)
            p.scale = (s, s, s)
            p.keyframe_insert("scale", frame=f)
    return sc


# ---------------------------------------------------------------- sheet render / tile


def render_cells(sc, n, cell, tmp, prefix):
    sc.render.resolution_x = sc.render.resolution_y = cell
    files = []
    for i in range(n):
        sc.frame_set(i + 1)
        path = os.path.join(tmp, "%s_%02d.png" % (prefix, i))
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        files.append(path)
    return files


def bleed(rgba, rounds=2):
    """Copy edge RGB into transparent pixels so filtering / mips never pull in black."""
    rgb = rgba[..., :3].astype(np.float32)
    a = rgba[..., 3]
    for _ in range(rounds):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(a.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(rgb, (dy, dx), (0, 1)) * np.roll(a > 0, (dy, dx), (0, 1))[..., None]
            cnt += np.roll(a > 0, (dy, dx), (0, 1))
        fill = (a == 0) & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill, None]
    rgba[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)


def load_cell(path, cell):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"   # raw sRGB bytes; no linear round-trip
    px = np.array(img.pixels[:], dtype=np.float32).reshape(cell, cell, 4)[::-1]
    bpy.data.images.remove(img)
    c8 = np.round(np.clip(px, 0, 1) * 255).astype(np.uint8)
    bleed(c8)
    return c8


FLAT = {"shockwave_ring": (244, 251, 255)}  # one RGB for the whole sheet: no grey/orange fringe, tint in the emitter


def tile(name, files, grid, cell):
    size = grid * cell
    sheet = np.zeros((size, size, 4), np.uint8)
    cover, pads = [], []
    for i, f in enumerate(files):
        c8 = load_cell(f, cell)
        if name in FLAT:
            c8[..., :3] = FLAT[name]
        r, c = divmod(i, grid)
        sheet[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] = c8
        a = c8[..., 3]
        cover.append(round(float((a > 2).mean()), 3))
        ys, xs = np.nonzero(a > 2)
        if len(ys):
            pad = min(ys.min(), xs.min(), cell - 1 - ys.max(), cell - 1 - xs.max()) / cell
            if pad < 0.05:
                print("  WARN %s cell %d padding %.1f%%" % (name, i, pad * 100), flush=True)
            pads.append(round(float(pad), 3))
    path = os.path.join(OUT, name + ".png")
    write_png(path, sheet)
    print("SHEET %-16s %dpx %dx%d cover %s pad %s" % (name, size, grid, grid, cover, pads), flush=True)
    return path


# ---------------------------------------------------------------- contact sheet


def emis_mat(name, hexcol):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*lin(hexcol), 1)
    e.inputs["Strength"].default_value = 1.0
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs["Surface"])
    return m


def image_mat(name, path):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "sRGB"
    tex.image = img
    em = nt.nodes.new("ShaderNodeEmission")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(tex.outputs["Color"], em.inputs["Color"])
    nt.links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    m.surface_render_method = "BLENDED"
    return m


def plane(sc, name, x, y_top, w, h, mat, z=0.0, W=1120, H=1560):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(x + w / 2, H - y_top - h / 2, z))
    o = bpy.context.active_object
    o.name = name
    o.scale = (w, h, 1)
    o.data.materials.append(mat)
    return o


def text(sc, name, body, x, y_top, size, mat, align="CENTER", W=1120, H=1560):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = align
    cu.align_y = "CENTER"
    o = bpy.data.objects.new(name, cu)
    sc.collection.objects.link(o)
    o.location = (x, H - y_top, 0.05)
    o.data.materials.append(mat)
    return o


def contact_sheet(sheets):
    W, H = 1120, 1560
    TILE, GAP, PAIR_GAP, MARGIN = 250, 8, 34, 35
    ROW_H = 294
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.render.image_settings.color_depth = "8"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.eevee.taa_render_samples = 32
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.ortho_scale = W
    cam.location = (W / 2, H / 2, 50)
    cam.rotation_euler = (0, 0, 0)
    sc.camera = cam
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (*lin("#22262C"), 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    sc.world = w

    plane(sc, "bg", 0, 0, W, H, emis_mat("bg", "#22262C"), W=W, H=H)
    ink = emis_mat("ink", INK)
    sub = emis_mat("sub", "#9AA3AD")
    text(sc, "title", "Mayday - Lego VFX flipbooks", MARGIN, 26, 20, ink, align="LEFT", W=W, H=H)
    text(sc, "subtitle", "build/prod/vfx  |  1024 px  |  straight alpha", W - MARGIN, 26, 13, sub,
         align="RIGHT", W=W, H=H)

    content = 2 * (2 * TILE + GAP) + PAIR_GAP
    x0 = (W - content) / 2
    for idx, (name, path, grid) in enumerate(sheets):
        row, col = divmod(idx, 2)
        bx = x0 + col * (2 * TILE + GAP + PAIR_GAP)
        yt = 58 + row * ROW_H
        for j, bg in enumerate((BLUE_BG, LIGHT_BG)):
            x = bx + j * (TILE + GAP)
            plane(sc, "tile%d_%d" % (idx, j), x, yt, TILE, TILE, emis_mat("bg%d_%d" % (idx, j), bg), W=W, H=H)
            plane(sc, "img%d_%d" % (idx, j), x, yt, TILE, TILE, image_mat("im%d_%d" % (idx, j), path),
                  z=0.02, W=W, H=H)
        text(sc, "label%d" % idx, "%s - %dx%d" % (name, grid, grid),
             bx + (2 * TILE + GAP) / 2, yt + TILE + 14, 13, ink, W=W, H=H)

    path = os.path.join(OUT, "sheet.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("CONTACT %s" % path, flush=True)
    return path


# ---------------------------------------------------------------- main


EFFECTS = (
    ("splash_crown", 4, 256, build_splash, 0),
    ("droplets", 2, 512, build_droplet, 4),
    ("foam_ring", 4, 256, build_foam, 0),
    ("puff_smoke", 4, 256, build_puff, 0),
    ("lego_plates", 2, 512, build_plate, 4),
    ("confetti_bricks", 2, 512, build_brick, 4),
    ("coin", 4, 256, build_coin, 0),
    ("shockwave_ring", 4, 256, build_shockwave, 0),
    ("spin_streak", 2, 512, build_spin, 4),
    ("rain_streak", 2, 512, build_rain, 4),
    ("stud_ring", 4, 256, build_stud_ring, 0),
)


def main():
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = args[args.index("--only") + 1] if "--only" in args else None
    if "--contact" in args:
        contact_sheet([(n, os.path.join(OUT, n + ".png"), g) for n, g, *_ in EFFECTS])
        return
    tmp = tempfile.mkdtemp(prefix="_frames_", dir=OUT)
    sheets = []
    try:
        for name, grid, cell, builder, variants in EFFECTS:
            if only and name not in only.split(","):
                continue
            files = []
            n = grid * grid
            if variants:
                for i in range(n):
                    sc = builder(None, i)
                    files.extend(render_cells(sc, 1, cell, tmp, "%s_%d" % (name, i)))
            else:
                sc = builder(None)
                files = render_cells(sc, n, cell, tmp, name)
            sheets.append((name, tile(name, files, grid, cell), grid))
            print("done %s" % name, flush=True)
        if not only:
            contact_sheet(sheets)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
