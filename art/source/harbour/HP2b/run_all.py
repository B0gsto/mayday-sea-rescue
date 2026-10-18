"""HP2b batch driver: tools/blender/run.py for every buoy in one Blender process (one heavy slot).
    ~/RobloxProjects/tools/blender-run.sh art/source/harbour/HP2b/run_all.py -- [Kind ...] [--steps build,lod,validate,export]
Env: HP2B_BAKE=1 re-bakes the G-buffer; HP2B_COMPOSE=0 keeps existing maps.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, HERE)
import marks  # noqa: E402
import run as R  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("kinds", nargs="*")
ap.add_argument("--steps", default="build,lod,validate,export")
a = ap.parse_args(argv)
kinds = a.kinds or marks.ALL
steps = a.steps.split(",")
results = {}
for k in kinds:
    bf = os.path.join(REPO, "art", "source", "harbour", marks.asset_name(k), "build.py")
    try:
        results[k] = R.run(bf, steps, argparse.Namespace(no_template=False))
    except Exception:
        import traceback
        traceback.print_exc()
        results[k] = False
print("[HP2b] results", results)
sys.exit(0 if all(results.values()) else 1)
