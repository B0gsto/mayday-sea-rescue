"""M_Veh_JetSki_CloseUp: the rider's first-person set for the rescue PWC (batch V1). Same frame as M_Veh_JetSki
(reads ../M_Veh_JetSki/frame_offset.json): PivotTo the jet ski's pivot and hide its Bars MeshPart for the rider.

One set (CloseUp, 2048, hero): steering pod with seams and screws, aluminium bar with ribbed grips and flanged ends,
switch housings (start / stop), finger throttle and reverse levers, kill switch with the coiled lanyard and its clip,
mirror heads with a glass face, the tilted display binnacle (speed 27 KN, fuel bars, heading NW 312, clock) and a
rescue VHF handset upright in its clip. The display glass is its own MeshPart so its UV island can take 3x texels.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Veh_JetSki_CloseUp --steps build,validate,export
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
JET = os.path.join(os.path.dirname(HERE), "M_Veh_JetSki")
sys.path.insert(0, JET)
import pwcgeo as R  # noqa: E402
import pwc as P  # noqa: E402
import rbxkit  # noqa: E402
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location("jet_build", os.path.join(JET, "build.py"))
_jet = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_jet)

NAME = "M_Veh_JetSki_CloseUp"
TEX = "JetSkiCloseUp"


def build():
    with open(os.path.join(JET, "frame_offset.json")) as f:
        off = Vector(json.load(f)["offset"])
    parts = R.build_set("CloseUp", [(NAME + "_Bars_LOD0", P.closeup_bars), (NAME + "_Console_LOD0", P.closeup_console),
                                    (NAME + "_Display_LOD0", P.display_screen)], _jet.boosted_uv({2: 3.0}),
                        "MI_JetSkiCloseUp")
    hps = [R.build_hp(NAME + "_Bars_HP", [P.closeup_bars], bevel=dict(width=0.005, segments=2, angle=40)),
           R.build_hp(NAME + "_Console_HP", [P.closeup_console], bevel=dict(width=0.005, segments=2, angle=40)),
           R.build_hp(NAME + "_Display_HP", [P.display_screen])]
    atts = []
    for name, p in (("ATT_EyePoint", P.EYE), ("ATT_KillCord", P.KILL), ("ATT_Display", P.DISPLAY_C),
                    ("ATT_GripLeft", (0.9, P.BAR_Y + 0.13, P.BAR_Z + 0.04)),
                    ("ATT_GripRight", (-0.9, P.BAR_Y + 0.13, P.BAR_Z + 0.04)),
                    ("ATT_Throttle", (-0.85, P.BAR_Y - 0.15, P.BAR_Z - 0.02)), ("ATT_VHF", (P.VHF.x, P.VHF.y, P.top_z(0.62, -1.5) + 0.32))):
        e = bpy.data.objects.new(name, None)
        e.location = Vector(p) + off
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)
    for o in parts + hps:
        o.data.transform(Matrix.Translation(off))
    lo = [min(v.co[k] for o in parts for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in parts for v in o.data.vertices) for k in range(3)]
    dims = tuple(round((h - l) / 3.0, 3) for l, h in zip(lo, hi))
    print("[M_Veh_JetSki_CloseUp] bbox studs %s dims_m %s" % ([round(h - l, 3) for l, h in zip(lo, hi)], dims))
    meshes = [{"object": o, "set": "CloseUp"} for o in parts] + [{"object": h} for h in hps]
    wear = {"rust": 0.0, "edge": 0.2, "salt": 0.1, "salt_color": (0.6, 0.6, 0.58), "edge_color": (0.56, 0.56, 0.55),
            "ao_strength": 0.2}

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    d = P.EYE - P.DISPLAY_C
    return {
        "name": NAME,
        "budget": "jetski_closeup",
        "tier": "hero",
        "dims_m": dims,
        "origin": "free",
        "sets": [{"name": TEX, "set": "CloseUp", "size": 2048, "wet": True, "wet_darken": 0.35, "wet_gloss": 0.45,
                  "wet_streaks": 0.35, "cage_extrusion": 0.03, "max_ray_distance": 0.08, "wear": wear}],
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [
            {"name": "rider_eye", "target": at(P.DISPLAY_C), "dist": round(d.length, 3), "az": 180,
             "el": round(math.degrees(math.asin(d.z / d.length)), 2)},
            {"name": "display", "target": at(P.DISPLAY_C), "dist": 1.3, "az": 180,
             "el": round(math.degrees(math.asin(P.DISPLAY_N.z)), 2)},
            {"name": "throttle_grip", "target": at((-0.85, P.BAR_Y, P.BAR_Z)), "dist": 1.6, "az": 215, "el": 35},
            {"name": "kill_cord", "target": at((0.25, -0.9, 3.1)), "dist": 1.8, "az": 120, "el": 30},
            {"name": "mirror", "target": at((1.08, -2.08, 3.25)), "dist": 1.6, "az": 160, "el": 15},
            {"name": "vhf_clip", "target": at((0.62, -1.5, 3.25)), "dist": 1.6, "az": 120, "el": 20},
        ],
        "waivers": {},
    }
