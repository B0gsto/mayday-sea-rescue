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

SHOTS = os.environ.get("HP1_SHOTS", G + "assets/review/HP1/shots_b")   # HP1b fix round; POL1: HP1_SHOTS=.../POL1/shots_A
# per asset: (az, el) of the main 3/4 view; optional close-up (target m, dist m, az, el)
VIEW = {"M_Hbr_QuayKit_Steps": (-30, 18), "M_Hbr_QuayKit_Head": (-20, 22), "M_Hbr_QuayKit_Armour": (-35, 20),
        "M_Hbr_Pontoon_Gangway": (-50, 22)}
CLOSE = {"M_Hbr_QuayKit_Straight": ((0.3, -0.12, -1.6), 1.5, -18, 4),       # POL1: barnacle band at the tide zone
         "M_Hbr_QuayKit_Armour": (None, 2.0, -30, 14),                       # POL1: toe block on the seabed (auto target)
         "M_Hbr_Pontoon_Straight6": ((1.1, 0.6, 0.0), 2.0, -60, 30),
         "M_Hbr_Ladder": ((0.0, 0.0, -1.6), 2.0, -30, 8)}
CLOSE_LABEL = {"M_Hbr_QuayKit_Straight": "M_Hbr_QuayKit_Straight_barnacles", "M_Hbr_QuayKit_Armour": "M_Hbr_QuayKit_Armour_contact"}


def seabed(lo, hi, z):
    """POL1: CC0 seabed sand plane at the armour pivot plane (the rocks must read as resting on the ground)."""
    size = max(hi.x - lo.x, hi.y - lo.y) + 30
    bpy.ops.mesh.primitive_plane_add(size=size, location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, z))
    pl = bpy.context.active_object
    pl.data.uv_layers.active.name = common.UV_NAME
    for d in pl.data.uv_layers.active.data:
        d.uv = d.uv * (size / 6.0)                     # ~2 m tile (6 studs)
    return pl


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
    print("[POL1] %s bounds m" % name, tuple(round(c / 3, 3) for c in lo), tuple(round(c / 3, 3) for c in hi))
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
    if "Gangway" in name or "Armour" in name:
        water.hide_render = True        # POL1: armour shown dry on its seabed (the 72 % water plane ghosted it)
    bed = seabed(lo, hi, lo.z) if "Armour" in name else None
    if bed is not None:
        ct = None
        vs = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
        toe = min((v for v in vs if v.z < lo.z + 1.2), key=lambda v: v.y)
        ct = Vector((toe.x, toe.y + 0.6, lo.z + 0.5))
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
        if bed is not None:
            sd = G + "assets/textures/Materials"
            bm_ = {k: common.map_file(sd, "T_Mat_SeabedSand_" + k + ("_Wet" if wet and k in ("ALB", "RGH") else ""))
                   for k in common.MAP_KINDS}
            bed.data.materials.clear()
            bed.data.materials.append(TT.pbr_material("MI_HP1_Seabed_%d" % wet, {k: v for k, v in bm_.items() if v}))
        az, el = VIEW.get(name, (-35, 20))
        d = TT.view_dir(az, el)
        TT.fit(cam, TT.corners(objs), d)
        scene.render.filepath = os.path.join(SHOTS, "%s_%s.png" % (name, "wet" if wet else "dry"))
        bpy.ops.render.render(write_still=True)
        if name in CLOSE:
            t, dist, az2, el2 = CLOSE[name]
            d2 = TT.view_dir(az2, el2)
            tv = ct if t is None else Vector(t) * 3.0
            cam.matrix_world = template.look_matrix(-d2, location=tv + d2 * dist * 3.0)
            wh = water.hide_render
            water.hide_render = True    # close-ups are texture / contact checks: no water plane in front
            scene.render.filepath = os.path.join(SHOTS, "%s_%s.png" % (CLOSE_LABEL.get(name, name + "_close"), "wet" if wet else "dry"))
            bpy.ops.render.render(write_still=True)
            water.hide_render = wh
    for o, ms in restore:
        o.data.materials.clear()
        for m in ms:
            o.data.materials.append(m)
    bpy.data.objects.remove(water)
    if bed is not None:
        bpy.data.objects.remove(bed)
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
