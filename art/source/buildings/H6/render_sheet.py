"""H6 review renders (Blender, EEVEE, overcast-sea HDRI): each asset dry and wet beside the 5.5-stud mannequin, plus
close-ups, into assets/review/H6/renders/. Then `python3 art/source/buildings/H6/contact.py` makes the sheet.
    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/H6/render_sheet.py
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import template  # noqa: E402
import turntable  # noqa: E402

S = 3.0
TAG = os.environ.get("H6_REVIEW", "b")                     # H6b fix round: renders_b -> contact_b.png
OUT = os.path.join(REPO, "assets", "review", "H6", "renders_" + TAG if TAG else "renders")
os.makedirs(OUT, exist_ok=True)
ASSETS = {
    "M_Bld_HarbourLight": {"tex": "HarbourLight", "sets": {"Tower": "Tower", "Lantern": "Lantern", "Lens": "Lantern", "Glass": "Lantern"},
                           "man": (0.9, -2.6), "az": 30, "el": 6,
                           "close": [("door_plaque", (0.55, -1.85, 1.55), 2.3, 22, 4), ("lantern", (0.0, 0.0, 10.1), 4.6, 28, 10),
                                     ("band_drips", (0.0, -1.6, 7.3), 3.6, 15, 4)]},
    "M_Bld_LifeguardTower": {"tex": "LifeguardTower", "sets": {"Hut": "Hut", "Glass": "Hut", "Frame": "Frame"},
                             "man": (-0.4, -3.4), "az": 32, "el": 8,
                             "close": [("sign_door", (0.25, -1.5, 4.55), 3.0, 12, 4), ("door_hardware", (1.12, -1.45, 4.0), 1.1, 18, 3),
                                       ("feet", (1.6, -2.2, 0.45), 1.7, 55, 8), ("deck_rail", (-0.3, -2.0, 3.8), 5.0, 325, 16)]},
}


def look(cam, target, dist, az, el):
    d = Vector((math.cos(math.radians(el)) * math.sin(math.radians(az)), -math.cos(math.radians(el)) * math.cos(math.radians(az)),
                math.sin(math.radians(el))))
    cam.location = Vector(target) + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def render(path, w, h):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = w, h, 100
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    for name, cfg in ASSETS.items():
        blend = os.path.join(REPO, "art", "source", "buildings", name, name + ".blend")
        bpy.ops.wm.open_mainfile(filepath=blend)
        sc = bpy.context.scene
        template.set_eevee(sc, samples=48)
        template.set_world("WLD_OvercastSea")
        man = bpy.data.objects.get("TPL_Mannequin")
        for o in sc.objects:
            keep = o.type == "MESH" and o.name.startswith(name + "_") and o.name.endswith("_LOD0")
            o.hide_render = not keep
        water = bpy.data.objects.get("TPL_Water")
        if man:
            man.hide_render = False
            man.location = (cfg["man"][0] * S, cfg["man"][1] * S, 0.0)
        objs = [o for o in sc.objects if not o.hide_render and o != man]
        tdir = os.path.join(REPO, "assets", "textures", name)
        cam = sc.camera or bpy.data.objects.new("CAM_Review", bpy.data.cameras.new("CAM_Review"))
        if cam.name not in sc.objects:
            sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.lens = 50
        cam.data.sensor_fit = "VERTICAL"
        if water:
            water.hide_render = True
        for wet in (False, True):
            mats = {}
            for o in objs:
                key = o.name[len(name) + 1:-len("_LOD0")]
                st = cfg["sets"].get(key, key)
                if st not in mats or key == "Glass":
                    maps = {k: os.path.join(tdir, "T_%s_%s_%s%s.png" % (cfg["tex"], st, k, "_Wet" if wet and k in ("ALB", "RGH") else ""))
                            for k in ("ALB", "NOR", "RGH", "MET")}
                    m = turntable.pbr_material("MI_Review_%s_%s_%d" % (key if key == "Glass" else st, name, wet), maps)
                    if key == "Glass":          # Roblox Glass-like: see-through, reflective
                        b = m.node_tree.nodes.get("Principled BSDF")
                        if b:
                            b.inputs["Alpha"].default_value = 0.35
                        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
                        mats["Glass"] = m
                    else:
                        mats[st] = m
                o.data.materials.clear()
                o.data.materials.append(mats["Glass" if key == "Glass" else st])
            pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
            lo = Vector([min(p[i] for p in pts) for i in range(3)])
            hi = Vector([max(p[i] for p in pts) for i in range(3)])
            size = max(hi.z - lo.z, (hi.x - lo.x) * 1.3, (hi.y - lo.y) * 1.0)
            look(cam, (lo + hi) / 2, size * 2.25 + 2.0, cfg["az"], cfg["el"])
            render(os.path.join(OUT, "%s_%s.png" % (name, "wet" if wet else "dry")), 400, 600)
            if not wet:
                if man:
                    man.hide_render = True
                for cname, tgt, dist, az, el in cfg["close"]:
                    look(cam, Vector(tgt) * S, dist * S, az, el)
                    render(os.path.join(OUT, "close_%s_%s.png" % (name, cname)), 600, 450)
                if man:
                    man.hide_render = False
        print("[H6] rendered", name)


main()
