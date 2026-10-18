"""Blender: build + validate + export every strand-line asset in one heavy-slot run (tools/blender/run.py per asset).
usage: ~/RobloxProjects/tools/blender-run.sh art/source/veg/Strand/run_all.py -- [--steps build,validate,export] [--only A,B]
Run atlas.py first (system python3): it writes cells.json, which strandkit.py reads."""
import argparse, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path[:0] = [os.path.join(GAME, "tools/blender"), HERE]
import run as runmod  # tools/blender/run.py
import strandkit
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--steps", default="build,validate,export")
ap.add_argument("--only", default="")
a = ap.parse_args(argv)
args = argparse.Namespace(no_template=False, out_root=None)
res = {}
for asset in strandkit.VARIANTS:
    if a.only and asset not in a.only.split(","):
        continue
    try:
        res[asset] = runmod.run(os.path.join(GAME, "art/source/veg", asset, "build.py"), a.steps.split(","), args)
    except Exception as e:
        import traceback; traceback.print_exc(); res[asset] = False
print("STRAND RESULT", " ".join("%s=%s" % (k, "OK" if v else "FAIL") for k, v in res.items()))
