"""Runs the pipeline for the hull and the nine pieces inside the live Blender MCP session, one log per asset (run_all())."""
import contextlib
import importlib.util
import os
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
SHORT = ["GiantJets", "TTail", "SkyStilts", "NeedleNose", "SkyWings", "Afterburners", "RadarDish", "TopJet", "TurboHalo"]
ASSETS = ["M_Veh_Hydrofoil"] + ["M_Upg_Hydrofoil_" + s for s in SHORT]
_s = importlib.util.spec_from_file_location("upg_pipeline_base", os.path.join(HERE, "../_UpgLifeboat/pipeline.py"))
_base = importlib.util.module_from_spec(_s)
_s.loader.exec_module(_base)


def run_one(asset, steps="build,lod,validate,export"):
    _base._window_export()
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
