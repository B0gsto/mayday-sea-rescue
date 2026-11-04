"""Runs the pipeline for the nine pieces inside the live Blender MCP session, one log per piece (import pipeline; pipeline.run_all())."""
import contextlib
import os
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))


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


def run_one(short, steps="build,lod,validate,export"):
    _window_export()
    asset = "M_Upg_JetSki_" + short
    log = os.path.join(GAME, "build/prod", asset, "run.log")
    os.makedirs(os.path.dirname(log), exist_ok=True)
    sys.argv = ["blender", "--", "--build", os.path.join(GAME, "art/source/vehicles", asset, "build.py"),
                "--out-root", os.path.join(GAME, "build/prod", asset), "--steps", steps]
    code = "?"
    with open(log, "w") as f, contextlib.redirect_stdout(f), contextlib.redirect_stderr(f):
        try:
            runpy.run_path(os.path.join(GAME, "tools/blender/run.py"), run_name="__main__")
        except SystemExit as e:
            code = e.code
    keep = [ln.rstrip()[:150] for ln in open(log) if any(k in ln for k in ("zfight", "FAIL", "Traceback", "Error", "[validate] PASS:", "LOD0 triangles", "LOD1 triangles", "LOD2 triangles"))]
    return asset, code, keep[-7:]


def run_all(names=None):
    import pieces
    for s in names or [p[1] for p in pieces.PIECES]:
        print(*run_one(s), sep="\n  ")
