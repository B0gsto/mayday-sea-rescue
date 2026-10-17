"""The `turntable` step (docs/12 section 1.1 preview row, 1.4 item 6): EEVEE renders of the asset's LOD0 beside the
5.5-stud mannequin, 4 angles under the neutral studio HDRI and the overcast sea HDRI (template.WORLDS), with the
asset's PBR maps applied when they exist (framed so the asset fills at least MIN_FILL of the cell), close-ups at hero
distance (spec["closeups"], default bbox corners + centre; common.closeup_targets) at CLOSEUP_SIZE, plus one alpha render
of the asset alone for the 64 px silhouette.
Called by run.py as turntable.run(spec, report, ok); writes <review>/<Asset>/turntable/ (8 views, silhouette.png,
turntable.json). sheet.py (system python3 + Pillow) lays out the contact sheet from that folder and the report.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset <Asset> --steps build,lod,validate,export,turntable

Works from the template scene (art/blender/_template.blend) or a factory scene (--no-template): a missing mannequin
or world is built for the run and removed again. Everything it changes (visibility, materials, world, camera, render
settings) is restored, so the .blend run.py saves afterwards is the build's.
"""
import json
import math
import os
import time

import bpy
from mathutils import Vector

import common
import template

# name -> (azimuth in degrees, 0 = camera in front of the asset on -Y, positive towards +X; elevation in degrees)
VIEWS = (("Front3Q", 35.0, 12.0), ("Side", 90.0, 5.0), ("Rear3Q", 215.0, 12.0), ("High", 325.0, 45.0))
WORLDS = ((template.NEUTRAL, "neutral"), (template.OVERCAST, "overcast"))
LENS_MM = 50.0
SAMPLES = 32
MARGIN = 1.08
MIN_FILL = 0.70           # the asset spans at least this share of the cell (its larger screen extent); else the
                          # mannequin is left partly out of frame so the asset can fill it
CLOSEUP_SIZE = 1024       # detail renders (common.closeup_targets) at hero distance, neutral HDRI


def corners(objs):
    pts = []
    for o in objs:
        pts.extend(o.matrix_world @ Vector(c) for c in o.bound_box)
    return pts


def bounds(pts):
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def view_dir(az, el):
    a, e = math.radians(az), math.radians(el)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def basis(d):
    """(right, up) of a camera looking along -d."""
    m = template.look_matrix(-d)
    return m.col[0].xyz, m.col[1].xyz


def fit(cam, pts, d):
    """Places the perspective camera along d so every point is in frame (exact for a square frame)."""
    lo, hi = bounds(pts)
    c = (lo + hi) / 2.0
    right, up = basis(d)
    t = math.tan(cam.data.angle / 2.0) / MARGIN
    dist = 0.0
    for p in pts:
        q = p - c
        qz = q.dot(d)
        dist = max(dist, abs(q.dot(right)) / t + qz, abs(q.dot(up)) / t + qz)
    loc = c + d * dist
    cam.matrix_world = template.look_matrix(-d, location=loc)
    cam.data.clip_end = max(1000.0, dist * 4.0)


def place_mannequin(man, asset_pts, d, az):
    """Stands the mannequin to the camera's left of the asset, on the asset's base, facing the camera."""
    lo, hi = bounds(asset_pts)
    c = (lo + hi) / 2.0
    right, _ = basis(Vector((d.x, d.y, 0.0)).normalized() if Vector((d.x, d.y)).length > 1e-6 else d)
    right = Vector((right.x, right.y, 0.0)).normalized()
    left_extent = max(-(p - c).dot(right) for p in asset_pts)
    span = max((p - c).dot(right) for p in asset_pts) + left_extent
    man.rotation_euler = (0.0, 0.0, math.radians(az))
    man.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    mlo, mhi = bounds(corners([man]))
    half = max(mhi.x - mlo.x, mhi.y - mlo.y) / 2.0
    gap = max(1.0, 0.15 * span)
    pos = c - right * (left_extent + gap + half)
    man.location = (pos.x, pos.y, lo.z)
    bpy.context.view_layer.update()


def fill(box):
    """Share of the frame the asset spans along its larger screen axis (box from frame_box)."""
    return round(max(box[2] - box[0], box[3] - box[1]), 3)


def frame_box(scene, cam, pts):
    """Normalised (0..1) screen box [x0, y0, x1, y1] of the points: in frame when all four lie in 0..1."""
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    ndc = [world_to_camera_view(scene, cam, p) for p in pts]
    return [round(min(v.x for v in ndc), 3), round(min(v.y for v in ndc), 3),
            round(max(v.x for v in ndc), 3), round(max(v.y for v in ndc), 3)]


def pbr_material(name, maps):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = common.UV_NAME
    for kind, path in maps.items():
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path, check_existing=True)
        tex.image.colorspace_settings.name = "sRGB" if kind == "ALB" else "Non-Color"
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        if kind == "ALB":
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        elif kind == "RGH":
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Roughness"])
        elif kind == "MET":
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Metallic"])
        elif kind == "NOR":
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nm.space, nm.uv_map = "TANGENT", common.UV_NAME
            nt.links.new(tex.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def apply_maps(spec, meshes):
    """Assigns a PBR material built from the set's maps (T_<Name>_<Set>_<ALB|NOR|RGH|MET>) to each LOD0 mesh that
    has them. Returns (restore list, {mesh: [kinds]}, temporary materials)."""
    asset = spec.get("asset", spec["name"])
    sets = {s.get("set"): s for s in spec.get("sets", [])}
    restore, applied, made = [], {}, []
    for e in meshes:
        s = sets.get(e.get("set")) or (list(sets.values())[0] if len(sets) == 1 else None)
        if not s:
            continue
        directory = s.get("dir") or common.textures_dir(asset)
        stem = "T_%s_%s_" % (s.get("name", spec["name"]), s.get("set"))
        maps = {k: common.map_file(directory, stem + k) for k in common.MAP_KINDS}
        maps = {k: p for k, p in maps.items() if p}
        if "ALB" not in maps:
            continue
        obj = e["object"]
        mat = pbr_material("MI_TT_" + obj.name, maps)
        made.append(mat)
        restore.append((obj, list(obj.data.materials)))
        if obj.data.materials:
            for i in range(len(obj.data.materials)):
                obj.data.materials[i] = mat
        else:
            obj.data.materials.append(mat)
        applied[obj.name] = sorted(maps)
    return restore, applied, made


def run(spec, report, validation_ok):
    t0 = time.time()
    scene = bpy.context.scene
    asset = spec.get("asset", spec["name"])
    out_dir = os.path.join(common.review_dir(asset), "turntable")
    os.makedirs(out_dir, exist_ok=True)
    meshes = [e for e in spec["meshes"] if e.get("role") == "visual" and e.get("lod") in ("LOD0", None)]
    objs = [e["object"] for e in meshes]
    if not objs:
        report.add(asset, "turntable", False, "no visual LOD0 mesh to render")
        return {"dir": out_dir, "images": {}, "error": "no LOD0 mesh"}

    temp_objs, temp_worlds = [], []
    man = bpy.data.objects.get("TPL_Mannequin")
    if man is None or man.name not in scene.objects:
        man = template.build_mannequin()
        temp_objs.append(man)
    for wname, _ in WORLDS:
        if bpy.data.worlds.get(wname) is None:
            temp_worlds.append(template.set_world(wname))

    saved = {
        "hide": {o.name: o.hide_render for o in scene.objects},
        "world": scene.world, "camera": scene.camera, "engine": scene.render.engine,
        "film": scene.render.film_transparent, "res": (scene.render.resolution_x, scene.render.resolution_y,
                                                       scene.render.resolution_percentage),
        "path": scene.render.filepath, "man": (man.location.copy(), man.rotation_euler.copy()),
        "view": scene.view_settings.view_transform, "look": scene.view_settings.look,
        "fmt": (scene.render.image_settings.file_format, scene.render.image_settings.color_mode),
    }
    saved["samples"] = scene.eevee.taa_render_samples

    images, applied, frames, closeups = {}, {}, {}, []
    restore_mats, made_mats = [], []
    try:
        template.set_eevee(scene, SAMPLES)
        restore_mats, applied, made_mats = apply_maps(spec, meshes)

        asset_pts = corners(objs)
        lo, hi = bounds(asset_pts)
        size = max(hi.x - lo.x, hi.y - lo.y, common.MANNEQUIN_STUDS)
        bpy.ops.mesh.primitive_circle_add(vertices=64, radius=size * 4.0, fill_type="NGON", location=(0, 0, lo.z - 0.002))
        ground = bpy.context.active_object
        ground.name = "TPL_TT_Ground"
        ground.data.materials.append(template.material("MI_TPL_TT_Ground", rgb=(0.16, 0.16, 0.155), roughness=0.9))
        temp_objs.append(ground)

        cam_data = bpy.data.cameras.new("CAM_Turntable")
        cam_data.lens, cam_data.sensor_width, cam_data.clip_start = LENS_MM, 36.0, 0.05
        cam = bpy.data.objects.new("CAM_Turntable", cam_data)
        scene.collection.objects.link(cam)
        temp_objs.append(cam)
        scene.camera = cam

        show = set(objs) | {man, ground}
        for o in scene.objects:
            if o.type not in ("CAMERA",):
                o.hide_render = o not in show

        for wname, short in WORLDS:
            template.set_world(wname)
            for vname, az, el in VIEWS:
                d = view_dir(az, el)
                place_mannequin(man, asset_pts, d, az)
                fit(cam, asset_pts + corners([man]), d)
                if fill(frame_box(scene, cam, asset_pts)) < MIN_FILL:
                    fit(cam, asset_pts, d)          # small asset: frame it, the mannequin stays as a partial scale cue
                if short == WORLDS[0][1]:
                    box = frame_box(scene, cam, asset_pts)
                    frames[vname] = {"asset": box, "mannequin": frame_box(scene, cam, corners([man])), "fill": fill(box)}
                fn = "%s_%s.png" % (vname, short)
                scene.render.filepath = os.path.join(out_dir, fn)
                bpy.ops.render.render(write_still=True)
                images["%s_%s" % (vname, short)] = fn

        # Detail row: close-ups at hero distance of the spec's points of interest (default: bbox corners and centre),
        # asset alone under the neutral HDRI at CLOSEUP_SIZE.
        man.hide_render = True
        template.set_world(WORLDS[0][0])
        scene.render.resolution_x = scene.render.resolution_y = CLOSEUP_SIZE
        for c in common.closeup_targets(spec.get("closeups"), list(lo), list(hi)):
            t = Vector(c["target"])
            d = view_dir(c["az"], c["el"])
            cam.matrix_world = template.look_matrix(-d, location=t + d * c["dist"])
            fn = "closeup_%s.png" % c["name"]
            scene.render.filepath = os.path.join(out_dir, fn)
            bpy.ops.render.render(write_still=True)
            closeups.append(dict(c, file=fn))
        scene.render.resolution_x = scene.render.resolution_y = template.RENDER_SIZE

        # Silhouette: the asset alone, transparent film, side-on three-quarter view.
        man.hide_render = ground.hide_render = True
        scene.render.film_transparent = True
        scene.eevee.taa_render_samples = 4
        fit(cam, asset_pts, view_dir(VIEWS[0][1], VIEWS[0][2]))
        scene.render.filepath = os.path.join(out_dir, "silhouette.png")
        bpy.ops.render.render(write_still=True)
        images["silhouette"] = "silhouette.png"
    finally:
        for obj, mats in restore_mats:
            for i, m in enumerate(mats):
                obj.data.materials[i] = m
        for mat in made_mats:
            bpy.data.materials.remove(mat)
        man.location, man.rotation_euler = saved["man"]
        for o in scene.objects:
            if o.name in saved["hide"]:
                o.hide_render = saved["hide"][o.name]
        scene.world, scene.camera = saved["world"], saved["camera"]
        scene.render.engine = saved["engine"]
        scene.render.film_transparent = saved["film"]
        scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = saved["res"]
        scene.render.filepath = saved["path"]
        scene.render.image_settings.file_format, scene.render.image_settings.color_mode = saved["fmt"]
        scene.view_settings.view_transform, scene.view_settings.look = saved["view"], saved["look"]
        scene.eevee.taa_render_samples = saved["samples"]
        for o in temp_objs:
            data = o.data
            bpy.data.objects.remove(o)
            if data is not None and data.users == 0:
                (bpy.data.meshes if isinstance(data, bpy.types.Mesh) else bpy.data.cameras).remove(data)
        for w in temp_worlds:
            bpy.data.worlds.remove(w)
        gm = bpy.data.materials.get("MI_TPL_TT_Ground")
        if gm is not None and gm.users == 0:
            bpy.data.materials.remove(gm)

    sets = ["T_%s_%s" % (s.get("name", spec["name"]), s.get("set")) for s in spec.get("sets", [])]
    result = {
        "dir": out_dir, "images": images, "views": [v[0] for v in VIEWS], "worlds": {s: w for w, s in WORLDS},
        "hdri": {s: template.WORLDS[w][0] for w, s in WORLDS}, "size_px": template.RENDER_SIZE, "samples": SAMPLES,
        "mannequin_studs": common.MANNEQUIN_STUDS, "maps_applied": applied, "sets": sets, "frames": frames,
        "closeups": closeups, "closeup_px": CLOSEUP_SIZE, "min_fill": min((f["fill"] for f in frames.values()), default=0.0),
        "in_frame": all(0.0 <= v <= 1.0 for f in frames.values() for v in f["asset"]),
        "dims_m": spec.get("dims_m"), "validation_ok": bool(validation_ok), "seconds": round(time.time() - t0, 1),
    }
    with open(os.path.join(out_dir, "turntable.json"), "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1, default=str)
    report.add(asset, "turntable", True, "%s; %d renders in %.0f s, maps %s" % (
               ("asset in frame, fill >= %.2f" % result["min_fill"]) if result["in_frame"] else "NOT ALL IN FRAME", len(images) + len(closeups), result["seconds"],
               ", ".join("%s: %s" % (k, "/".join(v)) for k, v in applied.items()) or "none (flat materials)"), info=True)
    print("[turntable] %d renders + %d close-ups in %.0f s -> %s" % (len(images), len(closeups), result["seconds"], out_dir))
    return result
