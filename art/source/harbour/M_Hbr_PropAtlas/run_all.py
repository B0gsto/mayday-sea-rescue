"""HP2a batch driver (inside Blender): build, lod, validate, export every HP2a prop in ONE Blender process.

    ~/RobloxProjects/tools/blender-run.sh art/source/harbour/M_Hbr_PropAtlas/run_all.py -- [--only A,B] [--steps ...]
Writes build/hp2a/results.json (asset -> ok)."""
import argparse, json, os, sys, traceback
HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
sys.path.insert(0, HERE)
import run  # noqa: E402
from refs import REFS  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--only", default="")
ap.add_argument("--steps", default="build,lod,validate,export")
a = ap.parse_args(argv)
assets = [x for x in REFS if not a.only or x in a.only.split(",")]
res = {}
for asset in assets:
    bf = os.path.join(G, "art/source/harbour", asset, "build.py")
    ns = argparse.Namespace(asset=asset, build=None, steps=a.steps, out_root=None, no_template=False)
    for m in [k for k in sys.modules if k in ("props", "build")]:
        pass
    try:
        ok = run.run(bf, [s for s in a.steps.split(",") if s], ns)
    except Exception:
        traceback.print_exc()
        ok = False
    res[asset] = bool(ok)
    print("[HP2a] RESULT %s %s" % (asset, "OK" if ok else "FAIL"), flush=True)
os.makedirs(os.path.join(G, "build/hp2a"), exist_ok=True)
old = {}
p = os.path.join(G, "build/hp2a/results.json")
if os.path.exists(p):
    old = json.load(open(p))
old.update(res)
json.dump(old, open(p, "w"), indent=1)
