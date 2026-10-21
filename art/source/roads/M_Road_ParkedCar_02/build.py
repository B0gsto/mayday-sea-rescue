"""M_Road_ParkedCar_02: invented 2010s European family estate, parked set dressing for the Gale Isles roads.

4.62 m x 1.80 m x 1.49 m (13.86 x 5.40 x 4.47 studs). Dark metallic red paint, long bonnet, long flat roof with
rails, near-vertical tailgate, tall wrap-around tail lamps, three side windows, tinted glass, different alloy wheels,
UK plates ("GI18 WNE", invented), light grime on the sills only. Two sets: Body (panels, glass, interior, lamps,
plates) and Wheels (four wheels, wheel wells, underbody). No badges or brand marks.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/roads/M_Road_ParkedCar_02/build.py --out-root build/prod/M_Road_ParkedCar_02 \
      --steps build,lod,bake,validate,export,turntable
"""
import json
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
CAR01 = os.path.join(os.path.dirname(HERE), "M_Road_ParkedCar_01")
sys.path.insert(0, HERE)
sys.path.insert(0, CAR01)
import wagon as C  # noqa: E402  (geometry; reuses cargeo helpers from _01, read-only)
import cargeo as V  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Road_ParkedCar_02"
P = "M_Road_ParkedCar"   # mesh bases carry the two-digit number last (names.py), asset name does not
TEX = "ParkedCar02"

ATTACHMENTS = {
    "ATT_Wheel_FL": (C.HUB_X, C.AX_F, C.WHEEL_R),
    "ATT_Wheel_FR": (-C.HUB_X, C.AX_F, C.WHEEL_R),
    "ATT_Wheel_RL": (C.HUB_X, C.AX_R, C.WHEEL_R),
    "ATT_Wheel_RR": (-C.HUB_X, C.AX_R, C.WHEEL_R),
}


def weighted_normals(objs):
    for o in objs:
        for x in bpy.context.view_layer.objects:
            x.select_set(False)
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        mod = o.modifiers.new("WN", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        mod.weight = 60
        bpy.ops.object.modifier_apply(modifier=mod.name)


def build():
    unwrap = rbxkit.smart_uv
    body_set = V.build_set("Body", [
        (P + "_Body_01_LOD0", C.body),
        (P + "_Detail_01_LOD0", C.body_detail),
        (P + "_Glass_01_LOD0", C.glass),
        (P + "_Interior_01_LOD0", C.interior),
    ], unwrap, "MI_ParkedCar02_Body", angle=62)
    wheels_set = V.build_set("Wheels", [
        (P + "_WheelFL_01_LOD0", lambda g: C.wheel(g, 1, True)),
        (P + "_WheelFR_01_LOD0", lambda g: C.wheel(g, -1, True)),
        (P + "_WheelRL_01_LOD0", lambda g: C.wheel(g, 1, False)),
        (P + "_WheelRR_01_LOD0", lambda g: C.wheel(g, -1, False)),
        (P + "_Underbody_01_LOD0", C.underbody),
    ], unwrap, "MI_ParkedCar02_Wheels", angle=50)
    weighted_normals(body_set + wheels_set)

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

    wear = {"edge": 0.0, "edge_color": (0.40, 0.13, 0.15), "edge_rough": 0.46, "edge_metal": 0.0,
            "salt": 0.0, "salt_range": (0.50, 0.80), "salt_color": (0.71, 0.70, 0.66),
            "rust": 0.0, "ao_strength": 0.10}
    sets = [
        # rays reach the smooth _HP shell (LOD0 chords sit up to ~0.02 off it) and lamp recesses (0.035-0.06 deep, slanted at creases)
        {"name": TEX, "set": "Body", "size": 4096, "wet": False, "cage_extrusion": 0.03,
         "max_ray_distance": 0.16, "ao_distance": 1.4,
         # no AO in the albedo: cavity-darkened trims fell under the 32 luma floor and the bake lifted the whole
         # set (paint came out ~122,16,22 instead of 110,14,20)
         "wear": dict(wear, ao_strength=0.0)},
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
        "dims_m": (1.87, 4.66, 1.49),
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_size": 4096,
        "bake_samples": 16,
        "closeups": [
            {"name": "front_3q", "target": at((2.05, 1.10, 2.0)), "dist": 6.4, "az": 28, "el": 10},
            {"name": "headlamp_plate", "target": at((1.70, 0.65, 2.30)), "dist": 4.6, "az": 35, "el": 8},
            {"name": "rear_3q", "target": at((-2.0, 13.0, 2.2)), "dist": 6.4, "az": 205, "el": 12},
            {"name": "wheel_arch", "target": at((2.62, 10.6, 0.98)), "dist": 4.6, "az": 88, "el": 8},
            {"name": "glass_roof", "target": at((1.6, 8.0, 3.8)), "dist": 6.4, "az": 120, "el": 18},
            {"name": "rear_plate", "target": at((0.0, 14.4, 1.2)), "dist": 4.6, "az": 178, "el": 6},
        ],
        "waivers": {
            "LOD UV layout": "collapse decimation moves the small lamp, plate, spoke and tread islands at LOD1/LOD2 "
                             "(up to 62% area on the wheel spokes); LOD0 layouts are unchanged, and the maps are "
                             "mip-mapped far below island size at those LOD distances.",
            "geometry": "LOD2 collapse leaves a few loose verts and open edges on the thin lamp, tread and card "
                        "geometry; not visible at the LOD2 cull distance, LOD0/LOD1 are clean.",
        },
    }
