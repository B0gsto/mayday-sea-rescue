"""Lv2, Lv3 and detail review renders on a flat-grey proxy of the code-built Air Station (DockPieces.luau `airStation()`).

The Lv1 station stays code-built, so it is shown as grey proxies at its real 1x frame (the AirStation row has no
scale): the 37 x 31 stud hangar plinth (top 0.4) with its white walls, 14-tall front opening and five-course arched
roof (apex ~23.5), and the 36 x 36 helipad at Blender (-38, -27) with its 1-wide rim, white H and corner windsock.
Only their shape matters; the add-ons keep their palette colours. Two state rows (Lv2, Lv2+Lv3) with front 3/4, side
and top reads, then a detail row (refuel pad, patrol hut, crew room). Neutral HDRI; views_sheet.py composes the sheet.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_AirStationAddons/views.py
    python3 art/source/buildings/M_Bld_AirStationAddons/views_sheet.py
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(G, "tools/blender"))
import lego  # noqa: E402
import palette as P  # noqa: E402
import template  # noqa: E402
import turntable  # noqa: E402

BLEND = os.path.join(HERE, "M_Bld_AirStationAddons.blend")
OUT = os.path.join(G, "build/prod/M_Bld_AirStationAddons/review/M_Bld_AirStationAddons/levels")
SIZE = 640


def prism_y(b, y0, y1, profile, c):
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def proxy_meshes():
    """The code station as flat proxies: plinth + hangar shell + arch, helipad slab, H and windsock."""
    dark = lego.B()
    dark.box((-18.5, -15.5, 0.0), (18.5, 15.5, 0.4), P.LBG)                        # hangar plinth (top 0.4)
    dark.box((-17.0, -14.0, 0.4), (17.0, 14.0, 0.52), P.LBG)                       # dark hangar floor

    shell = lego.B()
    shell.box((-57.0, -46.0, 0.0), (-19.0, -8.0, 0.6), P.LBG)                       # helipad slab 38 x 38
    shell.box((-17.0, 13.6, 0.4), (17.0, 14.4, 14.4), P.LBG)                       # back wall
    for x in (-17.4, 16.6):
        shell.box((x, -14.0, 0.4), (x + 0.8, 14.0, 14.4), P.LBG)                   # side walls
    for a in (-48, -24, 0, 24, 48):
        ang = math.radians(a)
        cx, cz = 25 * math.sin(ang), 23.5 - 25 * (1 - math.cos(ang))
        tx, tz = math.cos(ang), -math.sin(ang)
        nx, nz = math.sin(ang), math.cos(ang)
        profile = [(cx - 5.3 * tx - 0.6 * nx, cz - 5.3 * tz - 0.6 * nz),
                   (cx - 5.3 * tx + 0.6 * nx, cz - 5.3 * tz + 0.6 * nz),
                   (cx + 5.3 * tx + 0.6 * nx, cz + 5.3 * tz + 0.6 * nz),
                   (cx + 5.3 * tx - 0.6 * nx, cz + 5.3 * tz - 0.6 * nz)]
        prism_y(shell, -15.5, 15.5, profile, P.LBG)                                # five roof courses
    shell.box((-60.5, -49.5, 0.0), (-59.5, -48.5, 19.0), P.LBG)                    # code windsock post
    shell.box((-59.5, -49.4, 17.6), (-56.0, -48.6, 19.2), P.LBG)                   # code windsock sock

    marks = lego.B()
    marks.box((-17.0, -14.4, 11.0), (17.0, -13.6, 14.0), P.LBG)                    # open-front header
    marks.box((-17.3, -14.3, 14.0), (17.3, 14.3, 15.0), P.LBG)                     # white top course
    marks.box((-5.5, -14.8, 11.4), (5.5, -14.4, 13.6), P.LBG)                      # Hangar sign board
    for p in ((-57.0, -46.0, -19.0, -45.0), (-57.0, -9.0, -19.0, -8.0),
              (-57.0, -45.0, -56.0, -9.0), (-20.0, -45.0, -19.0, -9.0)):
        marks.box((p[0], p[1], 0.0), (p[2], p[3], 0.8), P.LBG)                     # white rim, lip above the pad
    for x0, x1, y0, y1 in ((-41.6, -39.8, -32.25, -21.75), (-36.2, -34.4, -32.25, -21.75),
                           (-41.6, -34.4, -27.9, -26.1)):
        marks.box((x0, y0, 0.6), (x1, y1, 0.72), P.WHITE)                          # the code pad H

    mat = template.material("MI_VIEWS_Proxy", rgb=(0.42, 0.43, 0.44), roughness=0.9)
    dk = template.material("MI_VIEWS_ProxyDark", rgb=(0.20, 0.21, 0.22), roughness=0.9)
    li = template.material("MI_VIEWS_ProxyLight", rgb=(0.72, 0.73, 0.74), roughness=0.8)
    return ([dark.to_object("VIEWS_ProxyDark", dk)],
            [shell.to_object("VIEWS_ProxyShell", mat)],
            [marks.to_object("VIEWS_ProxyMarks", li)])


bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene

objs = [o for o in scene.objects if o.type == "MESH"
        and not any(s in o.name for s in ("_LOD1", "_LOD2", "_COL")) and not o.name.startswith(("TPL_", "VIEWS_"))]
assert objs, "no meshes in %s" % BLEND
lv2 = [o for o in objs if o.name.startswith("Lv2_")]
lv3 = [o for o in objs if o.name.startswith("Lv3_")]
assert lv2 and lv3, "missing Lv2 / Lv3 meshes"
proxy_low, proxy_shell, proxy_marks = proxy_meshes()
proxy_all = proxy_low + proxy_shell + proxy_marks
RENDERS = (
    ("Lv2_Front", lv2, 35.0, 12.0, lv2 + proxy_all, True),
    ("Lv2_Rear", lv2, 145.0, 14.0, lv2 + proxy_all, True),
    ("Lv2_Top", lv2, 35.0, 68.0, lv2 + proxy_all, True),
    ("Lv2Lv3_Front", objs, -35.0, 12.0, objs + proxy_all, True),
    ("Lv2Lv3_Rear", objs, 145.0, 14.0, objs + proxy_all, True),
    ("Lv2Lv3_Top", objs, 35.0, 68.0, objs + proxy_all, True),
    ("Refuel", lv2, -35.0, 22.0, lv2, False),
    ("Hut", lv3, -28.0, 14.0, lv3, False),
)
assert all(r[1] for r in RENDERS), "empty render group: %s" % [r[0] for r in RENDERS if not r[1]]
DETAILS = (
    ("Crew", lv3, (-36.5, -0.5, 4.5), (-47.0, 19.0, 3.0), 38.0),
)

os.makedirs(OUT, exist_ok=True)
turntable.MARGIN = 1.03                 # tighter than the turntable default, the cells are square and the asset wide
template.set_eevee(scene, 24)
template.set_world(template.NEUTRAL)
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

pts = turntable.corners(objs)
lo, hi = turntable.bounds(pts)
size = max(hi.x - lo.x, hi.y - lo.y, 1.0)
bpy.ops.mesh.primitive_circle_add(vertices=64, radius=size * 4.0, fill_type="NGON", location=(0, 0, lo.z - 0.002))
ground = bpy.context.active_object
ground.name = "VIEWS_Ground"
ground.data.materials.append(template.material("MI_VIEWS_Ground", rgb=(0.16, 0.16, 0.155), roughness=0.9))
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=size * 3.0, depth=size * 10.0, end_fill_type="NOTHING",
                                    location=(0, 0, lo.z + size * 5.0))       # hides the HDRI softbox behind the asset
back = bpy.context.active_object
back.name = "VIEWS_Backdrop"
back_mat = bpy.data.materials.new("MI_VIEWS_Backdrop")            # emission only: a flat studio wall, no HDRI patches
back_mat.use_nodes = True
bsdf = back_mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
bsdf.inputs["Roughness"].default_value = 1.0
bsdf.inputs["Specular IOR Level"].default_value = 0.0
bsdf.inputs["Emission Color"].default_value = (0.092, 0.092, 0.088, 1.0)
bsdf.inputs["Emission Strength"].default_value = 1.0
back.data.materials.append(back_mat)

cam_data = bpy.data.cameras.new("VIEWS_Cam")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 50.0, 36.0, 0.05
cam = bpy.data.objects.new("VIEWS_Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

for name, show, az, el, fit_on, proxy in RENDERS:
    want = set(show) | (set(proxy_all) if proxy else set()) | {ground, back}
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in want
    d = turntable.view_dir(az, el)
    turntable.fit(cam, turntable.corners(fit_on), d)
    scene.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[views] %s" % name)

for name, show, loc, target, lens in DETAILS:
    want = set(show) | {ground, back}
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in want
    cam.data.lens = lens
    cam.data.clip_end = 1000.0
    d = (Vector(loc) - Vector(target)).normalized()
    cam.matrix_world = template.look_matrix(-d, location=loc)
    scene.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[views] %s" % name)
print("[views] done ->", OUT)
