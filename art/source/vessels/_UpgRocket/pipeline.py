"""Runs the pipeline for the hull and pieces inside the live Blender MCP session, one log per asset (exec this file's run_all())."""
import contextlib
import os
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
ASSETS = ["M_Veh_RocketCutter"] + ["M_Upg_Rocket_" + s for s in ("Pilot", "SideBoosters", "GoldPlating", "WaveWall", "GoldEagle", "RocketFins",
                                                                  "GoldThrone", "PartyCannons", "MegaTrophy", "SunBooster")]


def _window_export():
    """The MCP add-on runs code without a window context, and the FBX exporter reads context.selected_objects."""
    import bpy
    sys.path.insert(0, os.path.expanduser("~/RobloxProjects/tools/blender"))
    import rbxkit
    if getattr(rbxkit, "_mcp_patched", False):
        return
    plain = rbxkit.export_fbx

    def export_fbx(*a, **kw):
        win = bpy.context.window_manager.windows[0]
        with bpy.context.temp_override(window=win, screen=win.screen):
            return plain(*a, **kw)
    rbxkit.export_fbx, rbxkit._mcp_patched = export_fbx, True
    sys.path.insert(0, os.path.join(GAME, "tools/blender"))
    import versions
    import zfight_check
    plain_lod = versions.run_lod

    def run_lod(spec):      # run.py only nudges LOD0; decimation can make new coplanar pairs in the LODs
        made = plain_lod(spec)
        zfight_check.fix([e["object"] for e in spec["meshes"] if e.get("lod") in ("LOD1", "LOD2")])
        return made
    versions.run_lod = run_lod


def run_one(asset, steps="build,lod,validate,export"):
    _window_export()
    log = os.path.join(GAME, "build/prod", asset, "run.log")
    os.makedirs(os.path.dirname(log), exist_ok=True)
    sys.argv = ["blender", "--", "--build", os.path.join(GAME, "art/source/vessels", asset, "build.py"),
                "--out-root", os.path.join(GAME, "build/prod", asset), "--steps", steps]
    code = "?"
    with open(log, "w") as f, contextlib.redirect_stdout(f), contextlib.redirect_stderr(f):
        try:
            runpy.run_path(os.path.join(GAME, "tools/blender/run.py"), run_name="__main__")
        except SystemExit as e:
            code = e.code
    keep = [ln.rstrip() for ln in open(log) if any(k in ln for k in ("zfight", "FAIL", "Traceback", "Error"))]
    return asset, code, keep[-8:]


def run_all(names=None):
    for a in names or ASSETS:
        print(*run_one(a), sep="\n  ")
