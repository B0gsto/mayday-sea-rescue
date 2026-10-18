"""H3: build / validate / export all six cottages in one Blender session (one heavy slot):
    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_Cottage_Kit/run_all.py -- [--only 1,3] [--steps build,validate,export]"""
import os
import sys

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
sys.path.insert(0, G + "tools/blender")
import run as R  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = [1, 2, 3, 4, 5, 6]
steps = "build,validate,export"
if "--only" in argv:
    only = [int(x) for x in argv[argv.index("--only") + 1].split(",")]
if "--steps" in argv:
    steps = argv[argv.index("--steps") + 1]
res = {}
for i in only:
    a = "M_Bld_Cottage_%02d" % i
    sys.argv = ["run.py", "--", "--asset", a, "--steps", steps]
    bf, st, args = R.parse_args()
    try:
        res[a] = R.run(bf, st, args)
    except Exception:
        import traceback
        traceback.print_exc()
        res[a] = False
print("[H3] results", res)
