"""One-command build of one asset (docs/12-asset-list.md section 1.1). Always through the heavy-slot wrapper:

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset <Asset> [--steps build,lod,validate,export]
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build <path/to/build.py> [--out-root <dir>]

Steps: build, lod, bake, validate, export, turntable (clips and clips-rbxm are reserved for rigged assets). They always
run in that order, whatever order they are listed in, so validate checks what lod and bake made. Nothing is exported
when validate fails (export requires validate). bake and turntable run bake.py / turntable.py when present (batch B01)
and are skipped with a note otherwise. Exit status 1 on any failure.

A build file is art/source/<kind>/<Asset>/build.py with build() -> spec (see README.md for the spec fields).
The report goes to assets/review/<Asset>/<date>_report.json; the .blend is saved next to build.py (masters in art/).
"""
import argparse
import importlib
import importlib.util
import json
import os
import resource
import sys
import traceback

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
if LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)

import bpy  # noqa: E402

import common  # noqa: E402
import export  # noqa: E402
import validate  # noqa: E402
import versions  # noqa: E402
import zfight_check  # noqa: E402

STEPS = ("build", "lod", "bake", "validate", "export", "turntable", "clips", "clips-rbxm")
DEFAULT_STEPS = "build,lod,bake,validate,export,turntable"
TEMPLATE_BLEND = os.path.join(common.ART_DIR, "blender", "_template.blend")   # written by template.py (B01)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="run.py")
    parser.add_argument("--asset", help="folder name under art/source/<kind>/")
    parser.add_argument("--build", help="path to a build.py (instead of --asset)")
    parser.add_argument("--steps", default=DEFAULT_STEPS)
    parser.add_argument("--out-root", help="write fbx/, textures/, review/ under this folder instead of assets/")
    parser.add_argument("--no-template", action="store_true", help="start from an empty factory scene")
    args = parser.parse_args(argv)
    steps = [s.strip() for s in args.steps.split(",") if s.strip()]
    unknown = [s for s in steps if s not in STEPS]
    if unknown:
        raise SystemExit("unknown step(s): %s. Steps are %s" % (", ".join(unknown), ", ".join(STEPS)))
    if args.build:
        build_file = os.path.abspath(args.build)
    elif args.asset:
        build_file = os.path.join(common.find_asset_dir(args.asset), "build.py")
    else:
        raise SystemExit("--asset <Asset> or --build <build.py> is required")
    if args.out_root:
        common.set_out_root(args.out_root)
    return build_file, steps, args


def load_build(build_file):
    spec = importlib.util.spec_from_file_location("mayday_asset_build", build_file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def open_scene(use_template):
    if use_template and os.path.isfile(TEMPLATE_BLEND):
        bpy.ops.wm.open_mainfile(filepath=TEMPLATE_BLEND)
        return os.path.relpath(TEMPLATE_BLEND, common.REPO_DIR)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return "factory empty scene"


def optional_step(name):
    """bake.py / turntable.py arrive with batch B01; until then the step is skipped."""
    if not os.path.isfile(os.path.join(LIB_DIR, name + ".py")):
        print("[run] step '%s': tools/blender/%s.py not written yet (batch B01): skipped" % (name, name))
        return None
    return importlib.import_module(name)


def run(build_file, steps, args):
    asset_dir = os.path.dirname(build_file)
    asset = os.path.basename(asset_dir)
    for step in steps:
        if step in ("clips", "clips-rbxm"):
            print("[run] step '%s' is for rigged assets and is not ported yet: skipped" % step)
    scene_from = open_scene(not args.no_template)
    spec = load_build(build_file).build()
    spec.setdefault("asset", asset)
    validate.classify(spec)
    print("[run] built %s (%s) in %s" % (spec["name"], asset, scene_from))
    zfight_check.fix([e["object"] for e in spec["meshes"] if e["role"] == "visual"])   # no coplanar overlaps ship

    if "lod" in steps:
        versions.run_lod(spec)
    report = validate.Report()
    result = {"asset": asset, "name": spec["name"], "date": common.today(), "commit": common.git_commit(),
              "blender": bpy.app.version_string, "steps": steps, "scene": scene_from, "out_root": common.out_root(),
              "export_settings": export.recorded_settings()}
    if "bake" in steps:
        mod = optional_step("bake")
        if mod:
            result["bake"] = mod.run(spec, report)
    ok = report.ok
    if "validate" in steps:
        vreport = validate.run(spec)
        report.rows = report.rows + vreport.rows
        ok = report.ok
    if "export" in steps:
        if "validate" not in steps:
            print("[run] export needs validate in the same run: nothing exported")
            ok = False
        elif ok:
            result["exports"] = export.run(spec, report)
            for row in report.failures():
                print("[export] FAIL %s %s %s" % (row["subject"], row["check"], row["detail"]))
            ok = report.ok
        else:
            print("[run] validation failed: nothing exported")
    if "turntable" in steps:
        mod = optional_step("turntable")
        if mod:
            result["turntable"] = mod.run(spec, report, ok)
    if "build" in steps:
        under_source = os.path.commonpath([asset_dir, common.SOURCE_DIR]) == common.SOURCE_DIR
        blend = os.path.join(asset_dir if under_source else common.review_dir(asset), asset + ".blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend, check_existing=False, copy=True)
        result["blend"] = blend

    result["ok"] = ok
    result["checks"] = report.rows
    result["meshes"] = [{"name": e["object"].name, "role": e["role"], "lod": e.get("lod"), "triangles": e.get("tris"),
                         "texel_density": e.get("texel_density")} for e in spec["meshes"]]
    result["bbox_studs"] = spec.get("bbox_studs")
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    result["peak_rss_mb"] = round(peak / (1024.0 * 1024.0) if sys.platform == "darwin" else peak / 1024.0, 1)
    out = os.path.join(common.review_dir(asset), "%s_report.json" % common.today())
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1, default=str)
    print("[run] report %s" % out)
    print("[run] peak memory %.0f MB" % result["peak_rss_mb"])
    print("[run] %s %s" % (spec["name"], "OK" if ok else "FAILED"))
    return ok


def main():
    try:
        build_file, steps, args = parse_args()
        ok = run(build_file, steps, args)
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("[run] FAILED with an error")
        sys.exit(1)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
