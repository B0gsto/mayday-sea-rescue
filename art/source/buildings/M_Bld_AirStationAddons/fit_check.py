"""Island fit check: every Lv2/Lv3 mesh (visual LODs + COL) and ATT mark, in island (right, fwd) studs.

AirStation spot = island (right 88, fwd -124); export flips Blender X, so right = 88 - x, fwd = -124 - y.
Must land in right (27, 113), fwd (-150, -82) and clear of the code hangar plinth and helipad (DockPieces.luau).

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_AirStationAddons/fit_check.py
"""
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "M_Bld_AirStationAddons.blend"))
KEEP_OUT = {"hangar plinth": (-18.5, 18.5, -15.5, 15.5), "helipad": (-57.0, -19.0, -46.0, -8.0)}  # Blender x0 x1 y0 y1
bad, ext = [], {}
for o in bpy.context.scene.objects:
    if not (o.name.startswith(("Lv2_", "Lv3_")) and o.type == "MESH" or o.name.startswith("ATT_")):
        continue
    pts = [o.matrix_world @ v.co for v in o.data.vertices] if o.type == "MESH" else [o.matrix_world.translation]
    if not pts:
        continue
    x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
    y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
    r0, r1, f0, f1 = 88 - x1, 88 - x0, -124 - y1, -124 - y0
    lv = o.name[:3] if o.name.startswith("Lv") else "ATT"
    e = ext.setdefault(lv, [1e9, -1e9, 1e9, -1e9])
    ext[lv] = [min(e[0], r0), max(e[1], r1), min(e[2], f0), max(e[3], f1)]
    if not (27 < r0 and r1 < 113 and -150 < f0 and f1 < -82):
        bad.append("%s off plate: right %.1f..%.1f fwd %.1f..%.1f" % (o.name, r0, r1, f0, f1))
    for k, (a0, a1, b0, b1) in KEEP_OUT.items():
        if x0 < a1 and x1 > a0 and y0 < b1 and y1 > b0:
            bad.append("%s overlaps %s" % (o.name, k))
for lv, (r0, r1, f0, f1) in sorted(ext.items()):
    print("[fit] %s right %.2f..%.2f fwd %.2f..%.2f" % (lv, r0, r1, f0, f1))
print("\n".join("[fit] FAIL " + b for b in bad) or "[fit] PASS")
