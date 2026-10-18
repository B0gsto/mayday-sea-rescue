"""HP2b review renders (Blender, EEVEE, overcast-sea HDRI): every buoy dry and wet, plus close-ups, into
assets/review/HP2b/renders/. Then `python3 art/source/harbour/HP2b/contact.py` makes the sheet.
    ~/RobloxProjects/tools/blender-run.sh art/source/harbour/HP2b/render_sheet.py
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, HERE)
import marks  # noqa: E402
import template  # noqa: E402
import turntable  # noqa: E402

OUT = os.path.join(REPO, "assets", "review", "HP2b", os.environ.get("HP2B_RENDERS", "renders_b"))
os.makedirs(OUT, exist_ok=True)
TOP = ("top", (0.0, 0.0, 3.95), 2.6, 35, 6)
CLOSE = {"North": [TOP], "South": [TOP], "East": [TOP, ("waterline", (0.0, 0.0, 0.05), 2.6, 30, 8)],
         "West": [TOP, ("cage", (0.0, 0.0, 1.0), 3.0, 40, 10)], "MooringBuoy": [("moor", (0.0, 0.0, 0.1), 2.2, 30, 15)]}


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
    for kind in marks.ALL:
        name = marks.asset_name(kind)
        tex = marks.tex_name(kind)
        blend = os.path.join(REPO, "art", "source", "harbour", name, name + ".blend")
        bpy.ops.wm.open_mainfile(filepath=blend)
        sc = bpy.context.scene
        template.set_eevee(sc, samples=48)
        template.set_world("WLD_OvercastSea")
        for o in sc.objects:
            o.hide_render = not (o.type == "MESH" and o.name.endswith("_LOD0") and o.name.startswith("M_"))
        objs = [o for o in sc.objects if not o.hide_render]
        tdir = os.path.join(REPO, "assets", "textures", name)
        for wet in (False, True):
            maps = {k: os.path.join(tdir, "T_%s_Buoy_%s%s.png" % (tex, k, "_Wet" if wet and k in ("ALB", "RGH") else ""))
                    for k in ("ALB", "NOR", "RGH", "MET")}
            mat = turntable.pbr_material("MI_Review_%s_%d" % (tex, wet), maps)
            for o in objs:
                o.data.materials.clear()
                o.data.materials.append(mat)
            cam = sc.camera or bpy.data.objects.new("CAM_Review", bpy.data.cameras.new("CAM_Review"))
            if cam.name not in sc.objects:
                sc.collection.objects.link(cam)
            sc.camera = cam
            pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
            lo = Vector([min(p[i] for p in pts) for i in range(3)])
            hi = Vector([max(p[i] for p in pts) for i in range(3)])
            cam.data.lens = 50
            cam.data.sensor_fit = "VERTICAL"
            h = hi.z - lo.z
            look(cam, (lo + hi) / 2, h * 2.35 + 2.0, 35, 8)
            render(os.path.join(OUT, "%s_%s.png" % (kind, "wet" if wet else "dry")), 400, 600)
            if not wet:
                for cname, tgt, dist, az, el in CLOSE.get(kind, []):
                    look(cam, Vector(tgt) * 3.0, dist * 3.0, az, el)
                    render(os.path.join(OUT, "close_%s_%s.png" % (kind, cname)), 600, 400)
        print("[HP2b] rendered", kind)


main()
