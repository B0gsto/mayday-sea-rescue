"""AD sheet for the animal refinement rounds (build/status/2026-11-01/perfect/animals/BRIEF.md). Runs in the live
Blender session (MCP), never headless; objects are in studs, Z up, facing -Y.

    sys.path.insert(0, W + "/art/source/characters/_Pets"); import adsheet
    adsheet.render(objs, "H/<Asset>/rN_sheet.png", poses=[("sit", fn), ...])   # fn() poses objs in place
    adsheet.lineup([("Otter", objs), ...], "H/Pets/rN_sheet.png")

Rows: GAME (sea, grass; 5-stud figure, camera 18 back 7 up, 70 deg FOV), PHONE (25 % then back up), CLOSE (ortho
front, 3/4, side, back), POSES (3/4 ortho, one per pose). Lineup: one row per pet (game, phone, 3 close-ups).
"""
import math
import os
import tempfile

import bpy
import numpy as np
from mathutils import Vector

SC = "ADSheet"
TMP = tempfile.mkdtemp(prefix="adsheet_")
GROUNDS = {"sea": ((0.02, 0.33, 0.38), 0.12), "grass": ((0.16, 0.42, 0.10), 0.9), "studio": ((0.42, 0.43, 0.45), 0.8)}
CLOSE = {"front": (0, -1, 0.15), "3q": (0.75, -0.75, 0.35), "side": (1, 0, 0.1), "back": (0, 1, 0.2)}


def _mat(name, rgb, rough):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def _stage():
    sc = bpy.data.scenes.get(SC)
    if sc:
        return sc
    sc = bpy.data.scenes.new(SC)
    sc.render.engine = "BLENDER_EEVEE"
    sc.eevee.taa_render_samples = 32
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.render.image_settings.file_format = "PNG"
    w = bpy.data.worlds.new("W_ADSheet")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.72, 0.92, 1)    # soft daylight sky
    bg.inputs["Strength"].default_value = 0.9
    sc.world = w
    sun = bpy.data.objects.new("AD_Sun", bpy.data.lights.new("AD_Sun", "SUN"))
    sun.data.energy, sun.data.angle = 4.0, math.radians(4)
    sun.rotation_euler = (math.radians(45), 0, math.radians(30))
    cam = bpy.data.objects.new("AD_Cam", bpy.data.cameras.new("AD_Cam"))
    cam.data.sensor_fit, cam.data.clip_end = "VERTICAL", 2000
    sc.camera = cam
    bpy.ops.mesh.primitive_plane_add(size=400)
    ground = bpy.context.active_object
    for c in ground.users_collection:
        c.objects.unlink(ground)
    ground.name = "AD_Ground"
    for o in (sun, cam, ground):
        sc.collection.objects.link(o)
    fig = []                                       # blocky R15-height figure, 5 studs
    for name, size, at in (("LegL", (0.9, 0.9, 2), (-0.5, 0, 1)), ("LegR", (0.9, 0.9, 2), (0.5, 0, 1)),
                           ("Torso", (2, 1, 2), (0, 0, 3)), ("ArmL", (0.9, 0.9, 2), (-1.5, 0, 3)),
                           ("ArmR", (0.9, 0.9, 2), (1.5, 0, 3)), ("Head", (1.1, 1.1, 1), (0, 0, 4.5))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=at)
        o = bpy.context.active_object
        for c in o.users_collection:
            c.objects.unlink(o)
        o.name, o.scale, o["x0"] = "AD_Fig_" + name, size, at[0]
        o.data.materials.append(_mat("AD_Fig", (0.45, 0.46, 0.48), 0.6))
        sc.collection.objects.link(o)
        fig.append(o)
    return sc


def _bounds(sc, objs):
    dg = sc.view_layers[0].depsgraph
    dg.update()
    pts = []
    for o in objs:
        if o.type != "MESH" or o.hide_render:
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        pts += [o.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def _settle(sc, objs):
    """Centre the animal on the origin, feet on z = 0 (moves only the roots of objs)."""
    lo, hi = _bounds(sc, objs)
    d = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for o in objs:
        if o.parent not in objs:
            o.matrix_world.translation += d
    return _bounds(sc, objs)


def _shot(sc, w, h):
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.filepath = os.path.join(TMP, "shot.png")
    bpy.ops.render.render(write_still=True, scene=sc.name)
    img = bpy.data.images.load(sc.render.filepath)
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1, :, :3]


def _aim(cam, eye, target):
    cam.location = eye
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()


def _game(sc, lo, hi, ground, w, h):
    sc.objects["AD_Ground"].data.materials.clear()
    sc.objects["AD_Ground"].data.materials.append(_mat("AD_" + ground, *GROUNDS[ground]))
    fx = lo.x - 3.0                                   # figure stands left of the animal
    for o in sc.objects:
        if o.name.startswith("AD_Fig_"):
            o.hide_render = False
            o.location.x = o["x0"] + fx
    cam = sc.camera
    cam.data.type, cam.data.angle_y = "PERSP", math.radians(70)
    target = Vector(((fx + hi.x) / 2, 0, 2.0))
    _aim(cam, target + Vector((0.5, -1, 0)).normalized() * 18 + Vector((0, 0, 7)), target)
    return _shot(sc, w, h)


def _close(sc, lo, hi, view, size):
    for o in sc.objects:
        if o.name.startswith("AD_Fig_"):
            o.hide_render = True
    sc.objects["AD_Ground"].data.materials.clear()
    sc.objects["AD_Ground"].data.materials.append(_mat("AD_studio", *GROUNDS["studio"]))
    cam = sc.camera
    d = Vector(CLOSE[view]).normalized()
    c = (lo + hi) / 2
    _aim(cam, c + d * ((hi - lo).length * 3 + 10), c)
    cam.data.type = "ORTHO"
    sc.view_layers[0].update()                        # matrix_world is stale until the scene re-evaluates
    m = cam.matrix_world.to_3x3()
    corners = [Vector((x, y, z)) - c for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    cam.data.ortho_scale = 1.15 * max(max(abs(m.col[i].dot(p)) for p in corners) * 2 for i in (0, 1))
    return _shot(sc, size, size)


def _phone(img):
    h, w, _ = img.shape
    small = img.reshape(h // 4, 4, w // 4, 4, 3).mean((1, 3))
    return small.repeat(4, 0).repeat(4, 1)


def _save(rows, path):
    width = max(r.shape[1] for r in rows)
    pad = [np.concatenate([r, np.full((r.shape[0], width - r.shape[1], 3), 0.12, np.float32)], 1) for r in rows]
    out = np.concatenate(pad, 0)
    h, w, _ = out.shape
    rgba = np.concatenate([out, np.ones((h, w, 1), np.float32)], 2)[::-1]
    img = bpy.data.images.new("AD_Sheet", w, h, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.filepath_raw, img.file_format = path, "PNG"
    img.save()
    bpy.data.images.remove(img)
    print("[adsheet] wrote %s (%dx%d)" % (path, w, h))


def _use(sc, objs):
    col = bpy.data.collections.get("AD_Asset") or bpy.data.collections.new("AD_Asset")
    if col.name not in sc.collection.children:
        sc.collection.children.link(col)
    for o in list(col.objects):
        col.objects.unlink(o)
    for o in objs:
        col.objects.link(o)


def render(objs, out_png, poses=None):
    sc = _stage()
    _use(sc, objs)
    lo, hi = _settle(sc, objs)
    game = [_game(sc, lo, hi, g, 1536, 864) for g in ("sea", "grass")]
    rows = [np.concatenate(game, 1), np.concatenate([_phone(g) for g in game], 1),
            np.concatenate([_close(sc, lo, hi, v, 768) for v in CLOSE], 1)]
    shots = []
    for _name, fn in poses or []:
        fn()
        plo, phi = _settle(sc, objs)
        shots.append(_close(sc, plo, phi, "3q", 768))
    if shots:
        rows.append(np.concatenate(shots, 1))
    _save(rows, out_png)


def lineup(groups, out_png):
    """groups: [(label, objs)], one row per pet: game (sea), phone, front / 3/4 / side close-ups."""
    sc = _stage()
    rows = []
    for _label, objs in groups:
        _use(sc, objs)
        lo, hi = _settle(sc, objs)
        g = _game(sc, lo, hi, "sea", 768, 432)
        rows.append(np.concatenate([g, _phone(g)] + [_close(sc, lo, hi, v, 432) for v in ("front", "3q", "side")], 1))
    _save(rows, out_png)
