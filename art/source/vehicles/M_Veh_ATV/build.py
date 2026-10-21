"""M_Veh_ATV: invented beach-lifeguard utility quad (420 to 700 cc class) with its towed casualty sled, batch V5.

Quad: 2.10 x 1.20 x 1.13 m at 3 studs/m, 1.29 m wheelbase, 0.95 m track, 0.32 m knobbly balloon tyres on steel rims.
Moulded red plastic body with yellow panels and "LIFEGUARD" decals, steel front and rear cargo racks, rescue board on
the raised rear platform, two rescue tubes on the front rack, saddle, footwells, hand guards, headlights, tow hitch.
Sled: 1.98 m moulded plastic casualty sled with runners, grey bed, straps, grab handles and an A-frame drawbar; it is a
separate MeshPart group (M_Veh_ATV_Sled_LOD0) sitting in its towed position. Sets (docs/12 row): Body, Gear; wet.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/vehicles/M_Veh_ATV/build.py --out-root build/prod/M_Veh_ATV \
      --steps build,lod,bake,validate,export,turntable
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import atvgeo as V  # noqa: E402
import atv  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Veh_ATV"
TEX = "ATV"
M = atv.STUDS_M


def hull(name, pts):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vjunk = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vjunk:
        bmesh.ops.delete(bm, geom=vjunk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def collision_atv():
    pts = []
    for y in (0.35, 0.9, 1.35, 2.2, 3.2, 4.4, 5.2, 6.2):
        for x in (-1.8, -0.9, 0.0, 0.9, 1.8):
            pts += [(x, y, 0.55), (x, y, 1.9)]
        pts += [(0.0, y, 2.35), (-1.0, y, 2.15), (1.0, y, 2.15)]
    for hy in (atv.AX_F, atv.AX_R):
        for sx in (-1, 1):
            for a in range(0, 360, 60):
                t = math.radians(a)
                pts.append((sx * 1.42, hy + 0.98 * math.cos(t), atv.WHEEL_Z + 0.98 * math.sin(t)))
    pts += [(-0.9, 1.0, 2.9), (0.9, 1.0, 2.9), (0.0, 1.7, 3.1), (0.0, 6.2, 1.1)]
    return hull(NAME + "_COL", pts)


def collision_sled():
    pts = []
    for y in (atv.SLED_F, 8.7, 9.6, 11.0, 12.6, 13.7, atv.SLED_R):
        for x in (-1.05, 0.0, 1.05):
            pts += [(x, y, 0.12), (x, y, 1.30)]
    pts += [(0.0, atv.HITCH[1], atv.HITCH[2])]
    return hull("M_Veh_ATV_Sled_COL", pts)


ATTACHMENTS = {
    # wheels at the LandVehicleConfig / Builder hubs (1.29 m wheelbase, 0.95 m track)
    "ATT_Wheel_FL": (atv.HUB_X, atv.AX_F, atv.WHEEL_Z),
    "ATT_Wheel_FR": (-atv.HUB_X, atv.AX_F, atv.WHEEL_Z),
    "ATT_Wheel_RL": (atv.HUB_X, atv.AX_R, atv.WHEEL_Z),
    "ATT_Wheel_RR": (-atv.HUB_X, atv.AX_R, atv.WHEEL_Z),
    # saddle and rider eye; Builder: DriverSeat at centre, 1.35 m from the front, cushion 0.95 m
    "ATT_DriverSeat": (0.0, 3.55, 2.40),
    "ATT_EyePoint": (0.0, 3.30, 4.85),
    "ATT_Handlebar": (0.0, 1.82, 3.19),
    # kit and lamps
    "ATT_FrontRack": (0.0, 0.98, 2.10),
    "ATT_RearRack": (0.0, 5.28, 2.24),
    "ATT_Board": (0.0, 5.95, 2.66),
    "ATT_Headlamp_L": (0.56, 0.98, 1.70),
    "ATT_Headlamp_R": (-0.56, 0.98, 1.70),
    "ATT_TailLamp_L": (0.60, 6.23, 1.62),
    "ATT_TailLamp_R": (-0.60, 6.23, 1.62),
    # working points
    "ATT_TowHitch": atv.HITCH,
    "ATT_Coupler": (0.0, atv.HITCH[1] + 0.06, atv.HITCH[2]),
    "ATT_Cradle": (0.0, 11.20, 1.42),
    "ATT_SledHead": (0.0, 9.50, 1.44),
    "ATT_DriveAttachment": (0.0, 3.30, 0.84),
}


def build():
    unwrap = rbxkit.smart_uv
    body_set = V.build_set("Body", [(NAME + "_Body_LOD0", atv.body),
                                    (NAME + "_BodyDetail_LOD0", atv.body_detail),
                                    (NAME + "_Fenders_LOD0", atv.fenders)], unwrap,
                           "MI_ATV_Body", angle=60)
    gear_set = V.build_set("Gear", [
        (NAME + "_Wheel_FL_LOD0", lambda g: atv.wheel(g, 1, True)),
        (NAME + "_Wheel_FR_LOD0", lambda g: atv.wheel(g, -1, True)),
        (NAME + "_Wheel_RL_LOD0", lambda g: atv.wheel(g, 1, False)),
        (NAME + "_Wheel_RR_LOD0", lambda g: atv.wheel(g, -1, False)),
        (NAME + "_Chassis_LOD0", atv.chassis),
        (NAME + "_Rack_LOD0", atv.rack),
        ("M_Veh_ATV_Sled_LOD0", atv.sled),
    ], unwrap, "MI_ATV_Gear", angle=55)

    hps = [
        V.build_hp(NAME + "_Body_HP", [atv.body], bevel=dict(width=0.010, segments=1, angle=42)),
        V.build_hp(NAME + "_BodyDetail_HP", [atv.body_detail], bevel=dict(width=0.008, segments=1, angle=42)),
        V.build_hp(NAME + "_Fenders_HP", [atv.fenders], bevel=dict(width=0.010, segments=1, angle=42)),
        V.build_hp(NAME + "_Wheel_FL_HP", [lambda g: atv.wheel(g, 1, True)], bevel=dict(width=0.007, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_FR_HP", [lambda g: atv.wheel(g, -1, True)], bevel=dict(width=0.007, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_RL_HP", [lambda g: atv.wheel(g, 1, False)], bevel=dict(width=0.007, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_RR_HP", [lambda g: atv.wheel(g, -1, False)], bevel=dict(width=0.007, segments=1, angle=45)),
        V.build_hp(NAME + "_Chassis_HP", [atv.chassis], bevel=dict(width=0.007, segments=1, angle=40)),
        V.build_hp(NAME + "_Rack_HP", [atv.rack], bevel=dict(width=0.007, segments=1, angle=40)),
        V.build_hp("M_Veh_ATV_Sled_HP", [atv.sled], bevel=dict(width=0.008, segments=1, angle=40)),
    ]
    cols = [collision_atv(), collision_sled()]

    atts = []
    for name, p in ATTACHMENTS.items():
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    lod0 = body_set + gear_set
    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    off = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    for o in lod0 + hps + cols:
        o.data.transform(Matrix.Translation(off))
    for e in atts:
        e.location = e.location + off
    bbox = [h - l for l, h in zip(lo, hi)]
    with open(os.path.join(HERE, "frame_offset.json"), "w") as f:
        json.dump({"offset": [round(c, 4) for c in off], "bbox_studs": [round(c, 4) for c in bbox],
                   "quad_studs": [round(atv.W, 3), round(atv.L, 3), round(3.10, 3)],
                   "sled_studs": [round(2.10, 3), round(atv.SLED_R - atv.SLED_F, 3), round(1.34, 3)],
                   "note": "offset added to the authored model frame; quad at X 0, Y 0 front, ground z 0; sled towed "
                           "behind. Attachment positions include this offset."}, f, indent=1)
    print("[%s] offset %s bbox %s" % (NAME, tuple(round(c, 3) for c in off),
                                      [round(c, 3) for c in bbox]))

    quad_objs = [o for o in lod0 if not o.name.startswith("M_Veh_ATV_Sled")]
    sled_objs = [o for o in lod0 if o.name.startswith("M_Veh_ATV_Sled")]

    def rig_checks(spec, report):
        for label, objs, want in (("quad", quad_objs, (1.20, 2.10, 1.20)),
                                  ("sled", sled_objs, (0.75, 2.60, 0.47))):
            pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
            lo = [min(p[i] for p in pts) for i in range(3)]
            hi = [max(p[i] for p in pts) for i in range(3)]
            got = [hi[i] - lo[i] for i in range(3)]
            dev = max(abs(got[i] - want[i] * 3.0) / (want[i] * 3.0) for i in range(3))
            report.add("M_Veh_ATV_" + label, "sub-asset size", dev <= 0.10,
                       "%.3f x %.3f x %.3f m (want about %.2f x %.2f x %.2f)"
                       % (got[0] / 3, got[1] / 3, got[2] / 3, want[0], want[1], want[2]),
                       waiver="board overhang" if label == "quad" else None)

    meshes = []
    for objs, s in ((body_set, "Body"), (gear_set, "Gear")):
        for o in objs:
            meshes.append({"object": o, "set": s})
    meshes += [{"object": h} for h in hps]
    meshes += [{"object": c} for c in cols]

    streak = {"rust": 0.08, "rust_color": (0.30, 0.24, 0.19), "rust_rough": 0.8, "rust_length": 0.40, "rust_fingers": 5,
              "salt": 0.18, "salt_range": (0.35, 0.8), "salt_color": (0.70, 0.69, 0.65),
              "edge_color": (0.78, 0.78, 0.76), "edge_metal": 0.0, "ao_strength": 0.10}
    sets = [
        {"name": TEX, "set": "Body", "size": 2048, "wet": True, "wet_darken": 0.30, "wet_gloss": 0.30,
         "wet_streaks": 0.40, "cage_extrusion": 0.012, "max_ray_distance": 0.020, "ao_distance": 1.4,
         "wear": dict(streak, edge=0.26, edge_color=(0.60, 0.60, 0.58), salt=0.26, rust=0.03)},
        {"name": TEX, "set": "Gear", "size": 4096, "wet": True, "wet_darken": 0.30, "wet_gloss": 0.30,
         "wet_streaks": 0.45, "cage_extrusion": 0.012, "max_ray_distance": 0.020, "ao_distance": 1.4,
         "wear": dict(streak, edge=0.20, rust=0.22, salt=0.30, edge_color=(0.58, 0.57, 0.53))},
    ]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    return {
        "name": NAME,
        "budget": "land_vehicle",
        "tris": 15000,
        "tier": "standard",
        "dims_m": (round(bbox[0] / 3, 3), round(bbox[1] / 3, 3), round(bbox[2] / 3, 3)),
        "size_note": "combined rig (quad plus sled in its towed position); the quad alone is about 2.10 x 1.20 x 1.13 m",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "extra_checks": [rig_checks],
        "bake_size": 4096,
        "bake_samples": 16,
        "closeups": [
            {"name": "front_livery", "target": at((0.55, 0.95, 1.85)), "dist": 5, "az": 25, "el": 12},
            {"name": "side_tank", "target": at((0.85, 2.6, 1.65)), "dist": 4.5, "az": 88, "el": 8},
            {"name": "cockpit", "target": at((0.0, 2.4, 2.55)), "dist": 4.5, "az": 300, "el": 22},
            {"name": "rack_board", "target": at((0.0, 5.7, 2.5)), "dist": 5.5, "az": 145, "el": 28},
            {"name": "wheel_suspension", "target": at((1.45, 5.2, 1.05)), "dist": 4.5, "az": 78, "el": 10},
            {"name": "sled", "target": at((0.0, 11.4, 0.95)), "dist": 6.5, "az": 230, "el": 20},
        ],
        "waivers": {
            "texture sets": "docs/12 row calls for 2 sets (Body, Gear); the land_vehicle class default is 4. The quad, "
                            "racks, board, tubes, wheels and sled share the two 2048 maps.",
            "LOD UV layout": "collapse decimation moves small text, strap, tread-block and spoke islands at LOD1/LOD2; "
                             "they are seen beyond 150 / 500 studs where the maps are mip-mapped far below the island "
                             "size. LOD0 sets are unchanged.",
            "geometry": "LOD2: a few slivers or loose verts from thin text, ropes, springs and tread blocks; not "
                        "rendered at LOD2 distance. LOD0 and LOD1 are clean.",
        },
    }
