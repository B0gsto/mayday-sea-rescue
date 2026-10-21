"""M_Veh_BoatTrailer_JetSki: single-axle hot-dip galvanised PWC trailer (about 4.5 m overall), batch V5.

Single axle, A-frame drawbar, ball coupling, jockey wheel, manual winch with bow stop, carpeted bunks for the
M_Veh_JetSki hull, galvanised mudguards, rear light board with an invented plate, side markers and reflectors.
One 2048 texture set (galvanised steel, carpet, rubber, lamps) with white-rust bloom and salt staining.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/vehicles/M_Veh_BoatTrailer_JetSki/build.py --out-root build/prod/M_Veh_BoatTrailer_JetSki \
      --steps build,lod,bake,validate,export,turntable
"""
import json
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import trailergeo as V  # noqa: E402
import trailerlib as T  # noqa: E402
import rbxkit  # noqa: E402

S = T.JETSKI
NAME = S["name"]


def build():
    unwrap = rbxkit.smart_uv
    lod0 = V.build_set("Galv", T.part_names(S), unwrap, "MI_BoatTrailer_Galv", angle=58)
    hps = [V.build_hp(n, fns, bevel=dict(width=0.008, segments=1, angle=42)) for n, fns in T.hp_names(S)]
    col = T.collision(S)
    atts = []
    for name, p in T.attachments(S).items():
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    off = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    for o in lod0 + hps + [col]:
        o.data.transform(Matrix.Translation(off))
    for e in atts:
        e.location = e.location + off
    bbox = [h - l for l, h in zip(lo, hi)]
    with open(os.path.join(HERE, "frame_offset.json"), "w") as f:
        json.dump({"offset": [round(c, 4) for c in off], "bbox_studs": [round(c, 4) for c in bbox],
                   "coupler": [round(c, 4) for c in (Vector(T.attachments(S)["ATT_Coupler"]) + off)],
                   "note": "offset added to the authored nose-at-Y0 frame; Blender studs"}, f, indent=1)
    print("[%s] offset %s bbox %s" % (NAME, tuple(round(c, 3) for c in off),
                                      [round(c, 3) for c in bbox]))

    meshes = [{"object": o, "set": "Galv"} for o in lod0]
    meshes += [{"object": h} for h in hps] + [{"object": col}]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    wear = {"edge": 0.40, "edge_color": (0.72, 0.73, 0.71), "edge_rough": 0.42,
            "salt": 0.60, "salt_color": (0.87, 0.86, 0.81), "salt_rough": 0.92,
            "rust": 0.10, "rust_color": (0.42, 0.31, 0.23), "rust_length": 0.24, "rust_fingers": 7,
            "ao_strength": 0.16}
    return {
        "name": NAME,
        "budget": "trailer",
        "tris": 8000,
        "tier": "standard",
        "dims_m": S["dims"],
        "origin": "base",
        "bake_size": 2048,
        "sets": [{"name": S["tex"], "set": S["set"], "size": 2048, "wet": False,
                  "cage_extrusion": 0.06, "max_ray_distance": 0.10,
                  "ao_distance": 1.4, "bevel_radius": 0.10, "wear": wear}],
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [
            {"name": "coupling_jockey", "target": at((0.0, 1.0, 1.35)), "dist": 5, "az": 32, "el": 18},
            {"name": "winch_bow_stop", "target": at((0.0, 4.8, 2.6)), "dist": 5, "az": 325, "el": 16},
            {"name": "bunks_carpet", "target": at((0.0, 8.8, 2.1)), "dist": 6, "az": 155, "el": 30},
            {"name": "wheel_fender", "target": at((2.1, 9.2, 1.0)), "dist": 4, "az": 75, "el": 10},
            {"name": "light_board", "target": at((0.0, 13.1, 2.0)), "dist": 5, "az": 178, "el": 12},
            {"name": "drawbar_frame", "target": at((0.0, 3.0, 1.3)), "dist": 6, "az": 225, "el": 24},
        ],
        "waivers": {
            "LOD UV layout": "collapse decimation of the thin winch handle, JockeyWheel, plate letters and lamp bezels "
                             "shifts those small UV islands at LOD1/LOD2; seen beyond 150/500 studs where the maps are "
                             "mip-mapped below the island size. LOD0 is unchanged.",
            "geometry": "LOD2 slivers on the thin crank, cable and reflector triangles left by collapse decimation; "
                        "not visible at LOD2 distance, LOD0/LOD1 clean.",
        },
    }
