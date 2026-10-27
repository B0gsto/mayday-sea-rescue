"""Lv2 and Lv2+Lv3 review renders on a grey proxy of the code-built lookout tower (DockPieces.luau `lookout()`).

The tower itself is Lv1 and stays code-built, so it is shown as a flat grey proxy at its final 1.5x frame (24 x 24
stud lot, ground z 0, front -Y): only its shape matters, the add-ons keep their palette colours. Each state gets the
3/4 front, side and top read that the levels sheet asks for, then a detail row (deck, lantern, searchlight). Neutral
HDRI; views_sheet.py composes the contact sheet.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_LookoutAddons/views.py
    python3 art/source/buildings/M_Bld_LookoutAddons/views_sheet.py
"""
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

BLEND = os.path.join(HERE, "M_Bld_LookoutAddons.blend")
OUT = os.path.join(G, "build/prod/M_Bld_LookoutAddons/review/M_Bld_LookoutAddons/levels")
SIZE = 640
DECK, RAIL_Z0 = 31.2, 31.32


def prism_y(b, profile, y0, y1, c):
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def proxy_meshes():
    """The code tower as flat grey proxies, at the final 1.5x frame (the .blend keeps only the add-ons)."""
    low = lego.B()
    low.box((-8.25, -8.25, 0.0), (8.25, 8.25, 0.9), P.LBG)                         # plinth (top 0.9)
    for x in (-6.0, 6.0):
        for y in (-6.0, 6.0):
            low.box((x - 1.05, y - 1.05, 0.9), (x + 1.05, y + 1.05, 30.9), P.LBG)  # legs
    for z in (10.5, 21.0):
        for y in (-6.0, 6.0):
            low.box((-6.0, y - 0.6, z - 0.6), (6.0, y + 0.6, z + 0.6), P.LBG)      # cross braces
    for x in (-1.3, 1.3):                                                          # the back ladder (TrussPart)
        low.box((x - 0.2, 8.05, 0.0), (x + 0.2, 8.45, 30.0), P.DBG)
    for z in range(1, 30, 2):
        low.box((-1.3, 8.05, z), (1.3, 8.45, z + 0.3), P.DBG)

    top = lego.B()
    top.box((-8.25, -8.25, 30.0), (8.25, 8.25, DECK), P.LBG)                       # platform
    top.box((-7.2, -7.5, DECK), (7.2, -6.9, 33.3), P.LBG)                          # cabin front wall
    for s in (-1, 1):
        top.box((s * 7.5, -7.2, DECK), (s * 6.9, 7.2, 33.3), P.LBG)                # cabin side walls
    for x in (-6.9, 6.9):
        for y in (-6.9, 6.9):
            top.box((x - 0.75, y - 0.75, DECK), (x + 0.75, y + 0.75, 37.8), P.LBG)  # cabin posts
    prism_y(top, [(-9.0, 37.8), (9.0, 37.8), (0.0, 43.8)], -9.0, 9.0, P.LBG)       # roof, ridge along Y
    for s in (-1, 1):
        top.box((s * 10.5, -9.3, 37.35), (s * 8.4, 9.3, 38.7), P.LBG)               # eaves trim
    top.box((-0.9, -9.0, 43.5), (0.9, 9.0, 44.7), P.LBG)                           # ridge cap
    top.box((-0.3, -0.3, 44.1), (0.3, 0.3, 53.1), P.LBG)                           # flag pole

    glass = lego.B()
    glass.box((-7.2, -7.5, 33.3), (7.2, -6.9, 37.5), P.GLASS)                      # window band
    for s in (-1, 1):
        glass.box((s * 7.5, -7.2, 33.3), (s * 6.9, 7.2, 37.5), P.GLASS)

    flag = lego.B()
    flag.box((-0.1125, 0.225, 46.95), (0.1125, 9.975, 52.95), P.WHITE)             # flag, +Y (back)

    mat = template.material("MI_VIEWS_Proxy", rgb=(0.42, 0.43, 0.44), roughness=0.9)
    dark = template.material("MI_VIEWS_ProxyDark", rgb=(0.18, 0.19, 0.20), roughness=0.9)
    gl = template.material("MI_VIEWS_Glass", rgb=(0.10, 0.14, 0.16), roughness=0.35)
    return ([low.to_object("VIEWS_ProxyLow", dark)],
            [top.to_object("VIEWS_ProxyTop", mat)],
            [glass.to_object("VIEWS_ProxyGlass", gl)],
            [flag.to_object("VIEWS_ProxyFlag", mat)])


bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene

objs = [o for o in scene.objects if o.type == "MESH"
        and not any(s in o.name for s in ("_LOD1", "_LOD2", "_COL")) and not o.name.startswith(("TPL_", "VIEWS_"))]
assert objs, "no meshes in %s" % BLEND
# render only: the warm lens cell (palette 13) glows a little; in game it stays a plain flat colour
lamp = template.material("MI_VIEWS_Lamp", rgb=(1.0, 0.85, 0.40), roughness=0.3, emission=2.0)
for o in objs:
    uv = o.data.uv_layers["UVMap"].data
    for poly in o.data.polygons:
        u, v = uv[poly.loop_indices[0]].uv
        if int(u * P.GRID) + P.GRID * int(v * P.GRID) == P.WARM:
            if lamp.name not in o.data.materials:
                o.data.materials.append(lamp)
            poly.material_index = o.data.materials.find(lamp.name)
low, top, glass, flag = proxy_meshes()
proxy_top = top + glass + flag
lv2 = [o for o in objs if not o.name.startswith("Lv3_")]
lv3 = [o for o in objs if o.name.startswith("Lv3_")]
pick = lambda prefixes: [o for o in objs if o.name.startswith(prefixes)]
deck = pick(("Lv2_L04",))
deck_ctx = pick(("Lv2_L01", "Lv2_L04"))
lantern = pick(("Lv2_L03",))
searchlight = pick(("Lv3_L01", "Lv3_L02", "Lv3_L04"))
EXTRA = {
    "Lantern": [Vector((s * 5.5, y, 43.8 - (5.5 / 9.0) * 6.0)) for s in (-1, 1) for y in (-7.6, -2.0)],
    "Searchlight": [Vector((9.0, y, 37.8)) for y in (3.4, 7.0)],
}
RENDERS = (
    ("Lv2_Front", lv2, 35.0, 12.0, lv2),
    ("Lv2_Side", lv2, 90.0, 8.0, lv2),
    ("Lv2_Top", lv2, 35.0, 75.0, lv2),
    ("Lv2Lv3_Front", objs, 35.0, 12.0, objs),
    ("Lv2Lv3_Side", objs, 90.0, 8.0, objs),
    ("Lv2Lv3_Top", objs, 35.0, 75.0, objs),
    ("Deck", deck_ctx, 12.0, 20.0, deck),
    ("Lantern", lantern, 25.0, 16.0, lantern),
    ("Searchlight", searchlight, 35.0, 14.0, searchlight),
)
assert all(r[1] for r in RENDERS), "empty render group: %s" % [r[0] for r in RENDERS if not r[1]]

os.makedirs(OUT, exist_ok=True)
template.set_eevee(scene, 24)
template.set_world(template.NEUTRAL)
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

bpy.ops.mesh.primitive_circle_add(vertices=64, radius=90.0, fill_type="NGON", location=(0, 0, -0.002))
ground = bpy.context.active_object
ground.name = "VIEWS_Ground"
ground.data.materials.append(template.material("MI_VIEWS_Ground", rgb=(0.16, 0.16, 0.155), roughness=0.9))

cam_data = bpy.data.cameras.new("VIEWS_Cam")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 50.0, 36.0, 0.05
cam = bpy.data.objects.new("VIEWS_Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

for name, show, az, el, fit_on in RENDERS:
    detail = name in ("Deck", "Lantern", "Searchlight")
    want = set(show) | set(proxy_top) | (set() if detail else set(low) | {ground})
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in want
    d = turntable.view_dir(az, el)
    pts = turntable.corners(fit_on + ([] if detail else proxy_top)) + EXTRA.get(name, [])
    turntable.fit(cam, pts, d)
    scene.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[views] %s" % name)
print("[views] done ->", OUT)
