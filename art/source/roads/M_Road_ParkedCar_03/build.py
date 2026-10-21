"""M_Road_ParkedCar_03: invented 2010s European small panel van, parked set dressing for the Gale Isles roads.

4.41 m x 1.80 m (1.91 m over the mirrors) x 1.85 m (13.22 x 5.40 x 5.55 studs). Plain white paint with light
grime on the sills and lower doors, an invented "GALE ISLE PLUMBING" trade livery with a short fake phone number,
windowless load sides, a sliding side door (visible track and handle), twin rear barn doors, tall vertical tail
lamps and steel wheels with plastic hub caps. UK plates "GI16 VNX" (invented), front white / rear yellow.
Two sets: Body (panels, glass, interior, lamps, plates, livery) and Wheels (four wheels, wheel wells, underbody).
No badges or brand marks.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/roads/M_Road_ParkedCar_03/build.py --out-root build/prod/M_Road_ParkedCar_03 \
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
import van as C  # noqa: E402  (geometry; reuses cargeo helpers from _01, read-only)
import cargeo as V  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Road_ParkedCar_03"
P = "M_Road_ParkedCar"   # mesh bases carry the two-digit number last (names.py), asset name does not
TEX = "ParkedCar03"

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
    ], unwrap, "MI_ParkedCar03_Body", angle=62)
    wheels_set = V.build_set("Wheels", [
        (P + "_WheelFL_01_LOD0", lambda g: C.wheel(g, 1, True)),
        (P + "_WheelFR_01_LOD0", lambda g: C.wheel(g, -1, True)),
        (P + "_WheelRL_01_LOD0", lambda g: C.wheel(g, 1, False)),
        (P + "_WheelRR_01_LOD0", lambda g: C.wheel(g, -1, False)),
        (P + "_Underbody_01_LOD0", C.underbody),
    ], unwrap, "MI_ParkedCar03_Wheels", angle=50)
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

    wear = {"edge": 0.06, "edge_color": (0.55, 0.55, 0.51), "edge_rough": 0.55, "edge_metal": 0.0,
            "salt": 0.16, "salt_range": (0.55, 0.80), "salt_color": (0.72, 0.71, 0.66),
            "rust": 0.0, "ao_strength": 0.10}
    sets = [
        # rays reach the smooth _HP shell (LOD0 chords sit up to ~0.03 off it) and lamp recesses (0.035-0.06 deep, slanted at creases)
        {"name": TEX, "set": "Body", "size": 4096, "wet": False, "cage_extrusion": 0.03,
         "max_ray_distance": 0.16, "ao_distance": 1.5, "wear": dict(wear)},
        {"name": TEX, "set": "Wheels", "size": 4096, "wet": False, "cage_extrusion": 0.03,
         "max_ray_distance": 0.06, "ao_distance": 1.1,
         "wear": dict(wear, edge=0.10, salt=0.30, edge_color=(0.58, 0.56, 0.50))},
    ]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    return {
        "name": NAME,
        "budget": "parked_car",
        "tris": 15000,
        "tier": "standard",
        "dims_m": (1.92, 4.41, 1.86),
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_size": 4096,
        "bake_samples": 16,
        "closeups": [
            {"name": "front_3q", "target": at((1.95, 1.15, 2.35)), "dist": 7.0, "az": 28, "el": 12},
            {"name": "headlamp_plate", "target": at((1.35, 0.60, 2.20)), "dist": 4.2, "az": 38, "el": 8},
            {"name": "rear_3q", "target": at((-2.2, 12.8, 2.9)), "dist": 7.0, "az": 205, "el": 14},
            {"name": "rear_doors", "target": at((0.0, 13.3, 3.0)), "dist": 5.2, "az": 180, "el": 8},
            {"name": "livery", "target": at((2.65, 11.0, 2.85)), "dist": 4.4, "az": 88, "el": 4},
            {"name": "wheel_arch", "target": at((2.65, 10.35, 1.0)), "dist": 4.4, "az": 88, "el": 8},
        ],
        "waivers": {
            "LOD UV layout": "collapse decimation moves the small lamp, plate, letter and hub-cap islands at "
                             "LOD1/LOD2; LOD0 layouts are unchanged and the maps are mip-mapped far below "
                             "island size at those LOD distances.",
            "geometry": "The cab canopy and load box are single-sided lofted skins, open only at their hidden "
                        "lower and rear edges (the closed lower body and the barn doors cover them), as in _02; "
                        "LOD2 collapse adds a few loose verts on the thin letter and vent-slot geometry, not "
                        "visible at its cull distance.",
            "UV faces": "LOD2 collapse squeezes 6 of ~445 Body faces to zero UV area; sub-pixel at the LOD2 "
                        "distance, LOD0 / LOD1 have none.",
        },
    }
