"""Island fit check: every Lv2/Lv3 mesh (visual + COL) and ATT mark, in island (right, fwd) studs.

TrophyHall spot = island (right 0, fwd -122); export flips Blender X, so right = -x, fwd = -122 - y.
Must be on the plate (RingLayout.IslandPlate: back edge fwd -160, |right| <= 113 there), behind the bridge road
(fwd < -82; the road runs at fwd -78, 8 wide) and inside the hall's own 50 x 28 lot (right +-25, fwd -136..-108),
which keeps clear of the Air Station lot (right 67..109) and the Lookout lot (right 54..70).

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_TrophyHallAddons/fit_check.py
"""
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "M_Bld_TrophyHallAddons.blend"))
bad, ext = [], {}
for o in bpy.context.scene.objects:
    if not (o.name.startswith(("Lv2_", "Lv3_")) and o.type == "MESH" or o.name.startswith("ATT_")):
        continue
    pts = [o.matrix_world @ v.co for v in o.data.vertices] if o.type == "MESH" else [o.matrix_world.translation]
    if not pts:
        continue
    r0, r1 = -max(p.x for p in pts), -min(p.x for p in pts)
    f0, f1 = -122 - max(p.y for p in pts), -122 - min(p.y for p in pts)
    lv = o.name[:3] if o.name.startswith("Lv") else "ATT"
    e = ext.setdefault(lv, [1e9, -1e9, 1e9, -1e9])
    ext[lv] = [min(e[0], r0), max(e[1], r1), min(e[2], f0), max(e[3], f1)]
    if not (-25 <= r0 and r1 <= 25 and -136 <= f0 and f1 <= -108 and f0 > -158 and f1 < -82):
        bad.append("%s off lot/plate: right %.2f..%.2f fwd %.2f..%.2f" % (o.name, r0, r1, f0, f1))
for lv, (r0, r1, f0, f1) in sorted(ext.items()):
    print("[fit] %s right %.2f..%.2f fwd %.2f..%.2f" % (lv, r0, r1, f0, f1))
print("\n".join("[fit] FAIL " + b for b in bad) or "[fit] PASS")
