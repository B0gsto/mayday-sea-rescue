"""Lv3 quick-launch bay review renders with grey Lv1/Lv2 stand-ins (levels sheet).

The code boathouse (Lv1) and its code lifeboat slip (Lv2) are grey massing here so the bay's placement and size
read against them; only Lv3 is ours. A grey quay plate and dark water show the cove edge. Renders: front 3Q, side
and top with the stand-ins, plus four Lv3 detail renders. views_sheet.py composes the contact sheet.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_BoathouseAddons/views.py
    python3 art/source/buildings/M_Bld_BoathouseAddons/views_sheet.py
"""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
sys.path.insert(0, HERE)
import lego  # noqa: E402
import template  # noqa: E402
import turntable  # noqa: E402

BLEND = os.path.join(HERE, "M_Bld_BoathouseAddons.blend")
OUT = os.path.join(G, "build/prod/M_Bld_BoathouseAddons/review/M_Bld_BoathouseAddons/levels")
SIZE = 640

bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene

GREY = template.material("MI_VIEWS_Standin", rgb=(0.45, 0.46, 0.47), roughness=0.85)
PLATE_M = template.material("MI_VIEWS_Quay", rgb=(0.28, 0.29, 0.30), roughness=0.90)
WATER_M = template.material("MI_VIEWS_Water", rgb=(0.03, 0.06, 0.08), roughness=0.20)


def prism_y(b, y0, y1, prof):
    """A closed (x, z) profile extruded along Y (a gable with its ridge along Y)."""
    n = len(prof)
    verts = [(x, y0, z) for x, z in prof] + [(x, y1, z) for x, z in prof]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, 7)


def boxpts(lo, hi):
    return [Vector((x, y, z)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]


# Lv1 code boathouse massing: 39.6 x 46.8 shed at 1.2 scale, gable ridge along Y to 25.2
b = lego.B()
b.box((-19.8, -23.4, 0.0), (19.8, 23.4, 16.8), 7)
prism_y(b, -23.04, 23.04, [(-19.44, 16.8), (0.0, 25.2), (19.44, 16.8)])
lv1 = b.to_object("VIEWS_Lv1_Standin", GREY)

# Lv2 code lifeboat slip massing: 50 x 22 shed at fwd 112 = Blender x +54 (the export flips X), slipway on to the sea
b = lego.B()
b.box((29.0, -11.0, 0.0), (79.0, 11.0, 16.8), 7)
b.prof_x(29.0, 79.0, [(-11.0, 16.8), (0.0, 21.8), (11.0, 16.8)], 7)
b.box((79.0, -3.5, -4.0), (105.0, 3.5, 0.6), 7)
b.beam((105.0, 0.0, 0.2), (123.0, 0.0, -5.2), 7.0, 0.8, 7)
lv2 = b.to_object("VIEWS_Lv2_Standin", GREY)

# the code island plate (cove edge at y -35 from x -28 on, the plaza plate behind it) and the Harbour pontoon
b = lego.B()
b.box((-28.0, -35.0, -4.4), (110.0, 40.0, 0.0), 7)
b.box((-90.0, -125.0, -4.4), (-28.0, 40.0, 0.0), 7)
plate = b.to_object("VIEWS_Quay", PLATE_M)
b = lego.B()
b.box((2.0, -56.0, -1.0), (82.0, -48.0, 0.3), 7)
pont = b.to_object("VIEWS_Pontoon", GREY)
b = lego.B()
b.cyl(0.0, 0.0, -4.02, -4.0, 400.0, 7, 48)
water = b.to_object("VIEWS_Water", WATER_M)

objs = [o for o in scene.objects if o.type == "MESH"
        and not any(s in o.name for s in ("_LOD1", "_LOD2", "_COL"))
        and not o.name.startswith(("TPL_", "VIEWS_"))]
assert objs, "no meshes in %s" % BLEND
assert all(o.name.startswith("Lv3_") for o in objs), "unexpected meshes: %s" % [o.name for o in objs]
standins = [lv1, lv2, pont]
env = [plate, water]

RENDERS = (
    ("Lv3_Front", objs + standins + env, boxpts((-30.0, -50.0, 0.0), (56.0, -33.0, 29.0)), 58.0, 16.0),
    ("Lv3_Side", objs + standins + env, boxpts((-30.0, -50.0, 0.0), (56.0, -33.0, 29.0)), 90.0, 14.0),
    ("Lv3_Top", objs + standins + env, boxpts((-30.0, -50.0, 0.0), (56.0, -33.0, 29.0)), 90.0, 86.0),
    ("Detail_ReadyRoom", objs + env, boxpts((-26.0, -37.0, 0.4), (-13.0, -34.0, 7.2)), -150.0, 10.0),
    ("Detail_Lifeboat", objs + env, boxpts((9.0, -47.0, -2.0), (44.0, -35.0, 8.0)), 40.0, 18.0),
    ("Detail_GoLight", objs + env, boxpts((27.0, -44.0, 15.0), (35.0, -38.0, 29.0)), 55.0, 8.0),
    ("Detail_Roof", objs + env, boxpts((-28.0, -48.0, 11.0), (34.0, -34.0, 29.0)), 62.0, 26.0),
)
assert all(r[1] for r in RENDERS), "empty render group: %s" % [r[0] for r in RENDERS if not r[1]]

MANUAL = {}

os.makedirs(OUT, exist_ok=True)
template.set_eevee(scene, 24)
template.set_world(template.NEUTRAL)
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

cam_data = bpy.data.cameras.new("VIEWS_Cam")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start, cam_data.clip_end = 50.0, 36.0, 0.05, 3000.0
cam = bpy.data.objects.new("VIEWS_Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

for name, show, focus, az, el in RENDERS:
    want = set(show)
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in want
    cam.data.lens = 50.0
    if name in MANUAL:
        loc, tgt = MANUAL[name]
        cam.matrix_world = template.look_matrix((tgt - loc).normalized(), location=loc)
        cam.data.clip_end = 2000.0
    else:
        d = turntable.view_dir(az, el)
        turntable.fit(cam, focus, d)
    scene.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[views] %s" % name)
print("[views] done ->", OUT)
