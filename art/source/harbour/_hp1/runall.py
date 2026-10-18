"""HP1 driver: run tools/blender/run.py on several HP1 build files in ONE Blender process (one heavy slot), then
render the review shots (overcast HDRI, dry and _Wet maps) to assets/review/HP1/shots/.

    ~/RobloxProjects/tools/blender-run.sh art/source/harbour/_hp1/runall.py -- --steps build,lod,validate,export [--shots] A B ...
"""
import math
import os
import sys

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
sys.path.insert(0, G + "tools/blender")
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import run as R  # noqa: E402
import template  # noqa: E402
import turntable as TT  # noqa: E402

SHOTS = G + "assets/review/HP1/shots"
# per asset: (az, el) of the main 3/4 view; optional close-up (target m, dist m, az, el)
VIEW = {"M_Hbr_QuayKit_Steps": (-30, 18), "M_Hbr_QuayKit_Head": (-20, 22), "M_Hbr_QuayKit_Armour": (-35, 20),
        "M_Hbr_Pontoon_Gangway": (-50, 22)}
CLOSE = {"M_Hbr_QuayKit_Straight": ((0.3, -0.2, -1.0), 2.6, -25, 6),
         "M_Hbr_Pontoon_Straight6": ((1.1, 0.6, 0.0), 2.0, -60, 30),
         "M_Hbr_Ladder": ((0.0, 0.0, -1.6), 2.0, -30, 8)}


def maps_for(spec, e, wet):
    sets = {s.get("set"): s for s in spec.get("sets", [])}
    s = sets.get(e.get("set"))
    if not s:
        return None
    stem = "T_%s_%s_" % (s["name"], s["set"])
    out = {}
    for k in common.MAP_KINDS:
        p = common.map_file(s["dir"], stem + k + ("_Wet" if wet and k in ("ALB", "RGH") else ""))
        if p:
            out[k] = p
    return out


def shots(spec):
    os.makedirs(SHOTS, exist_ok=True)
    scene = bpy.context.scene
    name = spec["name"]
    meshes = [e for e in spec["meshes"] if e.get("role") == "visual" and e.get("lod") == "LOD0"]
    objs = [e["object"] for e in meshes]
    template.set_eevee(scene, 48)
    template.set_world("WLD_OvercastSea")
    scene.render.resolution_x = scene.render.resolution_y = 640
    for o in scene.objects:
        if o.type != "CAMERA":
            o.hide_render = o not in objs
    # water plane at sea level for the quay / ladder / pontoon (semi-dark, glossy) to read the waterline
    lo, hi = TT.bounds(TT.corners(objs))
    sea_z = (-0.5 if "Pontoon" in name else -1.333) * 3.0
    bpy.ops.mesh.primitive_plane_add(size=1, location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2 - 6, sea_z))
    water = bpy.context.active_object
    water.scale = ((hi.x - lo.x) + 60, (hi.y - lo.y) + 60, 1)
    wm = bpy.data.materials.new("MI_HP1_Water")
    wm.use_nodes = True
    b = wm.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.02, 0.05, 0.05, 1)
    b.inputs["Roughness"].default_value = 0.08
    b.inputs["Alpha"].default_value = 0.72
    try:
        wm.surface_render_method = "BLENDED"
    except Exception:
        pass
    water.data.materials.append(wm)
    if "Gangway" in name:
        water.hide_render = True
    cam_data = bpy.data.cameras.new("CAM_HP1")
    cam_data.lens = 50
    cam = bpy.data.objects.new("CAM_HP1", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    restore = [(o, list(o.data.materials)) for o in objs]
    for wet in (False, True):
        for e in meshes:
            mp = maps_for(spec, e, wet)
            if mp and "ALB" in mp:
                e["object"].data.materials.clear()
                e["object"].data.materials.append(TT.pbr_material("MI_HP1_%s_%d" % (e["object"].name, wet), mp))
        az, el = VIEW.get(name, (-35, 20))
        d = TT.view_dir(az, el)
        TT.fit(cam, TT.corners(objs), d)
        scene.render.filepath = os.path.join(SHOTS, "%s_%s.png" % (name, "wet" if wet else "dry"))
        bpy.ops.render.render(write_still=True)
        if name in CLOSE:
            t, dist, az2, el2 = CLOSE[name]
            d2 = TT.view_dir(az2, el2)
            tv = Vector(t) * 3.0
            cam.matrix_world = template.look_matrix(-d2, location=tv + d2 * dist * 3.0)
            scene.render.filepath = os.path.join(SHOTS, "%s_close_%s.png" % (name, "wet" if wet else "dry"))
            bpy.ops.render.render(write_still=True)
    for o, ms in restore:
        o.data.materials.clear()
        for m in ms:
            o.data.materials.append(m)
    bpy.data.objects.remove(water)
    bpy.data.objects.remove(cam)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    steps = "build,lod,validate,export"
    do_shots = False
    names = []
    i = 0
    while i < len(argv):
        if argv[i] == "--steps":
            steps = argv[i + 1]
            i += 2
            continue
        if argv[i] == "--shots":
            do_shots = True
        else:
            names.append(argv[i])
        i += 1
    steps = [s for s in steps.split(",") if s]

    class A:
        no_template = False
    results = {}
    orig_load = R.load_build
    for n in names:
        bf = os.path.join(common.find_asset_dir(n), "build.py")
        spec_box = {}

        def load(build_file, _box=spec_box):
            mod = orig_load(build_file)
            fn = mod.build

            def wrapped():
                s = fn()
                _box["spec"] = s
                return s
            mod.build = wrapped
            return mod
        R.load_build = load
        try:
            ok = R.run(bf, steps, A)
        except Exception:
            import traceback
            traceback.print_exc()
            ok = False
        R.load_build = orig_load
        results[n] = ok
        if do_shots and "spec" in spec_box:
            try:
                shots(spec_box["spec"])
            except Exception:
                import traceback
                traceback.print_exc()
    print("[HP1] results", results)
    sys.exit(0 if all(results.values()) else 1)


main()
