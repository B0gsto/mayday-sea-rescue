"""Island fit check: every Lv2/Lv3 mesh (visual LODs + COL) and ATT mark, in island (right, fwd) studs.

SubPen spot = island (right 90, fwd 128); export flips Blender X, so right = 90 - x, fwd = 128 - y. Each object's
bbox must stay on the plate (RingLayout.IslandPlate rects: chamfered corners, the cove notch), off the streets
(DockPieces.STREETS, 8 wide; the cove walk is right 52, fwd 22..148) and off every other DockConfig lot.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_SubPenAddons/fit_check.py
"""
import math
import os
import re

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
SR, SF = 90.0, 128.0
E, C, NH, NW = 160.0, 47.0, 30.0, 45.0           # RingLayout: edge, chamfer, notch head, notch half-width
PLATE = [(-E + C, -NW, -E + C, E - C), (NW, E - C, -E + C, E - C), (-NW, NW, -E + C, NH), (-E + C, E - C, -E, -E + C),
         (-E, -E + C, -E + C, E - C), (E - C, E, -E + C, E - C), (-E + C, -NW, E - C, E), (NW, E - C, E - C, E)]
STREETS = [((-121, -78), (121, -78)), ((0, -78), (0, -28)), ((-152, 22), (-44, 22)), ((44, 22), (152, 22)),
           ((-52, 22), (-52, 148)), ((-52, 148), (-96, 148)), ((52, 22), (52, 148))]
KEEP_OUT = {}
for a, b in STREETS:                              # path(): 8 wide, +4 past each end
    KEEP_OUT["street %s-%s" % (a, b)] = (min(a[0], b[0]) - 4, max(a[0], b[0]) + 4,
                                         min(a[1], b[1]) - 4, max(a[1], b[1]) + 4)
src = open(os.path.join(G, "src/shared/Config/DockConfig.luau")).read()
for m in re.finditer(r"\n\t(\w+) = \{.*?spot = isle\(([-\d.]+), ([-\d.]+)(?:, ([-\d.]+))?\).*?"
                     r"size = Vector2\.new\(([\d.]+), ([\d.]+)\)", src, re.S):
    name, r, f, yaw, w, d = m.group(1), *(float(g or 0) for g in m.groups()[1:])
    if name == "SubPen":
        continue
    if abs(math.sin(math.radians(yaw))) > 0.5:
        w, d = d, w
    KEEP_OUT["lot " + name] = (r - w / 2, r + w / 2, f - d / 2, f + d / 2)
assert len([k for k in KEEP_OUT if k.startswith("lot ")]) >= 12, "DockConfig parse found too few lots"


def on_plate(r, f):
    return any(r0 <= r <= r1 and f0 <= f <= f1 for r0, r1, f0, f1 in PLATE)


bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "M_Bld_SubPenAddons.blend"))
bad, ext = [], {}
for o in bpy.context.scene.objects:
    if not (o.name.startswith(("Lv2_", "Lv3_")) and o.type == "MESH" or o.name.startswith("ATT_")):
        continue
    pts = [o.matrix_world @ v.co for v in o.data.vertices] if o.type == "MESH" else [o.matrix_world.translation]
    if not pts:
        continue
    x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
    y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
    r0, r1, f0, f1 = SR - x1, SR - x0, SF - y1, SF - y0
    lv = o.name[:3] if o.name.startswith("Lv") else "ATT"
    e = ext.setdefault(lv, [1e9, -1e9, 1e9, -1e9])
    ext[lv] = [min(e[0], r0), max(e[1], r1), min(e[2], f0), max(e[3], f1)]
    n = 8
    grid = [(r0 + (r1 - r0) * i / n, f0 + (f1 - f0) * j / n) for i in range(n + 1) for j in range(n + 1)]
    if not all(on_plate(r, f) for r, f in grid):
        bad.append("%s off plate: right %.1f..%.1f fwd %.1f..%.1f" % (o.name, r0, r1, f0, f1))
    for k, (a0, a1, b0, b1) in KEEP_OUT.items():
        if r0 < a1 and r1 > a0 and f0 < b1 and f1 > b0:
            bad.append("%s overlaps %s (right %.1f..%.1f fwd %.1f..%.1f)" % (o.name, k, r0, r1, f0, f1))
for lv, (r0, r1, f0, f1) in sorted(ext.items()):
    print("[fit] %s right %.2f..%.2f fwd %.2f..%.2f" % (lv, r0, r1, f0, f1))
print("\n".join("[fit] FAIL " + b for b in bad) or "[fit] PASS")
