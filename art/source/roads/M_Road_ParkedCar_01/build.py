"""M_Road_ParkedCar_01: invented 2010s European 5-door supermini, parked set dressing for the Gale Isles roads.

4.0 m x 1.75 m x 1.48 m (12 x 5.25 x 4.44 studs). Muted blue-grey metallic paint, black plastic bumpers and trim,
tinted glass, alloy wheels, UK plates ("GI15 KXR", invented), light road grime and salt spray. Two sets: Body
(panels, glass, interior, lamps, plates) and Wheels (four wheels, wheel wells, underbody). No badges or brand marks.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/roads/M_Road_ParkedCar_01/build.py --out-root build/prod/M_Road_ParkedCar_01 \
      --steps build,lod,bake,validate,export,turntable
"""
import json
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import car as C  # noqa: E402
import cargeo as V  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Road_ParkedCar_01"
P = "M_Road_ParkedCar"   # mesh bases carry the two-digit number last (names.py), asset name does not
TEX = "ParkedCar01"

ATTACHMENTS = {
    "ATT_Wheel_FL": (C.HUB_X, C.AX_F, C.WHEEL_R),
    "ATT_Wheel_FR": (-C.HUB_X, C.AX_F, C.WHEEL_R),
    "ATT_Wheel_RL": (C.HUB_X, C.AX_R, C.WHEEL_R),
    "ATT_Wheel_RR": (-C.HUB_X, C.AX_R, C.WHEEL_R),
}


def build():
    unwrap = rbxkit.smart_uv
    body_set = V.build_set("Body", [
        (P + "_Body_01_LOD0", C.body),
        (P + "_Detail_01_LOD0", C.body_detail),
        (P + "_Glass_01_LOD0", C.glass),
        (P + "_Interior_01_LOD0", C.interior),
    ], unwrap, "MI_ParkedCar01_Body", angle=62)
    wheels_set = V.build_set("Wheels", [
        (P + "_WheelFL_01_LOD0", lambda g: C.wheel(g, 1, True)),
        (P + "_WheelFR_01_LOD0", lambda g: C.wheel(g, -1, True)),
        (P + "_WheelRL_01_LOD0", lambda g: C.wheel(g, 1, False)),
        (P + "_WheelRR_01_LOD0", lambda g: C.wheel(g, -1, False)),
        (P + "_Underbody_01_LOD0", C.underbody),
    ], unwrap, "MI_ParkedCar01_Wheels", angle=50)

    hps = [
        V.build_hp(P + "_Body_01_HP", [C.body], bevel=dict(width=0.012, segments=1, angle=40)),
        V.build_hp(P + "_Detail_01_HP", [C.body_detail], bevel=dict(width=0.008, segments=1, angle=40)),
        V.build_hp(P + "_Glass_01_HP", [C.glass]),
        V.build_hp(P + "_Interior_01_HP", [C.interior], bevel=dict(width=0.008, segments=1, angle=40)),
        V.build_hp(P + "_WheelFL_01_HP", [lambda g: C.wheel(g, 1, True)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(P + "_WheelFR_01_HP", [lambda g: C.wheel(g, -1, True)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(P + "_WheelRL_01_HP", [lambda g: C.wheel(g, 1, False)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(P + "_WheelRR_01_HP", [lambda g: C.wheel(g, -1, False)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(P + "_Underbody_01_HP", [C.underbody], bevel=dict(width=0.008, segments=1, angle=40)),
    ]
    col = C.collision()

    atts = []
    for name, p in ATTACHMENTS.items():
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    lod0 = body_set + wheels_set
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
                   "note": "offset added to the authored model frame; Blender studs, origin bottom-centre"},
                  f, indent=1)
    print("[%s] offset %s bbox %s" % (NAME, tuple(round(c, 3) for c in off),
                                      [round(c, 3) for c in bbox]))

    meshes = []
    for objs, s in ((body_set, "Body"), (wheels_set, "Wheels")):
        for o in objs:
            meshes.append({"object": o, "set": s})
    meshes += [{"object": h} for h in hps]
    meshes.append({"object": col})

    wear = {"edge": 0.0, "edge_color": (0.46, 0.50, 0.52), "edge_rough": 0.48, "edge_metal": 0.0,
            "salt": 0.06, "salt_range": (0.62, 0.90), "salt_color": (0.71, 0.70, 0.66),
            "rust": 0.0, "ao_strength": 0.10}
    sets = [
        # rays reach the smooth _HP shell (LOD0 chords sit up to ~0.03 off it) and lamp recesses (0.035-0.06 deep, slanted at creases)
        {"name": TEX, "set": "Body", "size": 4096, "wet": False, "cage_extrusion": 0.03,
         "max_ray_distance": 0.16, "ao_distance": 1.4, "wear": dict(wear)},
        {"name": TEX, "set": "Wheels", "size": 4096, "wet": False, "cage_extrusion": 0.03,
         "max_ray_distance": 0.06, "ao_distance": 1.1,
         "wear": dict(wear, edge=0.10, salt=0.26, rust=0.10, edge_color=(0.55, 0.54, 0.51))},
    ]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    return {
        "name": NAME,
        "budget": "parked_car",
        "tris": 15000,
        "tier": "standard",
        "dims_m": (1.75, 4.0, 1.48),
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_size": 4096,
        "bake_samples": 16,
        "closeups": [
            {"name": "front_3q", "target": at((1.85, 0.65, 1.9)), "dist": 6, "az": 28, "el": 10},
            {"name": "headlamp_plate", "target": at((1.55, 0.35, 2.25)), "dist": 4.2, "az": 35, "el": 8},
            {"name": "rear_3q", "target": at((-1.8, 11.4, 2.1)), "dist": 6, "az": 205, "el": 12},
            {"name": "wheel_arch", "target": at((2.42, 9.85, 0.95)), "dist": 4.4, "az": 88, "el": 8},
            {"name": "glass_roof", "target": at((1.5, 4.6, 3.7)), "dist": 6, "az": 120, "el": 18},
            {"name": "rear_plate", "target": at((0.0, 11.9, 1.2)), "dist": 4.4, "az": 178, "el": 6},
        ],
        "waivers": {
            "LOD UV layout": "collapse decimation moves the small lamp, plate, spoke and tread islands at LOD1/LOD2 "
                             "(up to 62% area on the wheel spokes); LOD0 layouts are unchanged, and the maps are "
                             "mip-mapped far below island size at those LOD distances.",
            "geometry": "LOD2 collapse leaves a few loose verts and open edges on the thin lamp, tread and card "
                        "geometry; not visible at the LOD2 cull distance, LOD0/LOD1 are clean.",
        },
    }
