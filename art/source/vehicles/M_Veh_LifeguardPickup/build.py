"""M_Veh_LifeguardPickup: invented double-cab lifeguard 4x4 pickup (Hilux / Ranger class), batch V3.

5.33 m x 1.855 m x 1.815 m (16 x 5.6 x 5.4 studs). Off-white service paint with red / yellow battenburg (the
LandVehicleConfig LifeguardPickup livery: stripeColor red, stripeColor2 yellow), dark tinted glass, amber rotator
light bar, rescue board on the bed rack, kit lockers, tow hitch, AT tyres.

Matches the code-built car in src/shared/Car/Builder.luau so the mesh can replace it: four separate wheel meshes at
the physics hub positions, seats at the greybox seat frames (RHD, driver on Blender -X), lamps, tow hitch and light
bar as ATT_* empties, and the chassis drive root as ATT_DriveAttachment.

Sets (docs/12 row): Body (exterior, decals), Cab (interior + glass), Wheels (four wheels, underbody), Rack (roll hoop,
bed rack, board, light bar, lockers); every set has _Wet.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/vehicles/M_Veh_LifeguardPickup/build.py --out-root build/prod/M_Veh_LifeguardPickup \
      --steps build,lod,validate,export,turntable
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import vehgeo as V  # noqa: E402
import truck as T  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Veh_LifeguardPickup"
TEX = "LifeguardPickup"
M = T.STUDS_M

# chassis (physics) origin in the model frame: 0.92 m front overhang + 3.085 m x (1 - 0.57) of wheelbase behind the
# front axle, cgHeight 0.8 m above the ground (Builder.luau / LandVehicleConfig.LifeguardPickup)
CHASSIS = (0.0, T.AX_F + T.STUDS_M * 3.085 * (1 - 0.57), 0.8 * T.STUDS_M)


def collision():
    bm = bmesh.new()
    pts = []
    for y in (0.05, 0.5, 1.5, 2.8, 4.2, 5.4, 7.0, 8.6, 10.2, 11.4, 12.4, 13.8, 15.2, 15.95):
        for x in (-2.72, -1.4, 0.0, 1.4, 2.72):
            pts.append((x, y, 1.0))
            pts.append((x, y, 2.6))
        pts.append((0.0, y, 3.3))
    for y in (5.2, 6.4, 8.0, 9.6, 11.0):
        pts += [(-2.6, y, 5.3), (2.6, y, 5.3), (0.0, y, 5.42)]
    pts += [(-2.68, 11.7, 4.4), (2.68, 11.7, 4.4), (-2.68, 15.7, 4.4), (2.68, 15.7, 4.4)]
    pts += [(-2.3, 12.2, 5.5), (2.3, 12.2, 5.5), (-2.3, 15.4, 5.5), (2.3, 15.4, 5.5), (0.0, 13.7, 5.6)]
    pts += [(-2.72, 0.3, 1.4), (2.72, 0.3, 1.4), (-2.72, 15.9, 1.4), (2.72, 15.9, 1.4)]
    for hy in (T.AX_F, T.AX_R):
        for sx in (-1, 1):
            for a in range(0, 360, 60):
                t = math.radians(a)
                pts.append((sx * 2.65, hy + 1.2 * math.cos(t), T.WHEEL_Z + 1.2 * math.sin(t)))
        pts.append((0.0, hy, 0.5))
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vjunk = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vjunk:
        bmesh.ops.delete(bm, geom=vjunk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(NAME + "_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(NAME + "_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


ATTACHMENTS = {
    # wheels: physics hub centres (Builder: Wheel_FL/FR/RL/RR, track 1.54 m, wheelbase 3.085 m)
    "ATT_Wheel_FL": (T.HUB_X, T.AX_F, T.WHEEL_Z),
    "ATT_Wheel_FR": (-T.HUB_X, T.AX_F, T.WHEEL_Z),
    "ATT_Wheel_RL": (T.HUB_X, T.AX_R, T.WHEEL_Z),
    "ATT_Wheel_RR": (-T.HUB_X, T.AX_R, T.WHEEL_Z),
    # seats: RHD, driver on Roblox +X (Blender -X); front at 2.35 m behind the bumper, rear bench at +0.95 m
    "ATT_DriverSeat": (-T.SEAT_X, 7.05, 2.58),
    "ATT_Seat2": (T.SEAT_X, 7.05, 2.58),
    "ATT_Seat3": (1.67, 9.98, 2.61),
    "ATT_Seat4": (0.0, 9.98, 2.61),
    "ATT_Seat5": (-1.67, 9.98, 2.61),
    # driver's eye: DriverSeat + (0, 2.25, -0.3) Roblox studs (LandVehicleConfig.eyePoint); eye 0.75 m over the cushion
    "ATT_EyePoint": (-T.SEAT_X, 6.75, 4.83),
    # lights and the light bar
    "ATT_LightBar": (0.0, 6.24, 5.50),
    "ATT_Beacon_01": (-1.62, 6.24, 5.86),
    "ATT_Beacon_02": (-0.54, 6.24, 5.86),
    "ATT_Beacon_03": (0.54, 6.24, 5.86),
    "ATT_Beacon_04": (1.62, 6.24, 5.86),
    "ATT_Headlamp_L": (1.78, 0.40, 2.78),
    "ATT_Headlamp_R": (-1.78, 0.40, 2.78),
    "ATT_TailLamp_L": (2.48, 15.99, 3.16),
    "ATT_TailLamp_R": (-2.48, 15.99, 3.16),
    "ATT_BrakeLamp_L": (2.48, 15.99, 3.02),
    "ATT_BrakeLamp_R": (-2.48, 15.99, 3.02),
    "ATT_ReverseLamp_L": (2.48, 15.99, 2.64),
    "ATT_ReverseLamp_R": (-2.48, 15.99, 2.64),
    # working points
    "ATT_TowHitch": (0.0, 16.12, 1.38),
    "ATT_DriveAttachment": CHASSIS,
    "ATT_Board": (0.0, 13.70, 5.62),
    "ATT_KitLocker_L": (1.55, 12.55, 3.40),
    "ATT_KitLocker_R": (-1.55, 12.55, 3.40),
    "ATT_WorkLamp_L": (1.30, 11.37, 5.30),
    "ATT_WorkLamp_R": (-1.30, 11.37, 5.30),
}


def build():
    unwrap = rbxkit.smart_uv
    body_set = V.build_set("Body", [(NAME + "_Body_LOD0", T.body),
                                    (NAME + "_BodyDetail_LOD0", T.body_detail)], unwrap, "MI_LifeguardPickup_Body", angle=62)
    cab_set = V.build_set("Cab", [(NAME + "_Cab_LOD0", T.cab_interior),
                                  (NAME + "_Glass_LOD0", T.glass)], unwrap, "MI_LifeguardPickup_Cab", angle=55)
    wheels_set = V.build_set("Wheels", [(NAME + "_Wheel_FL_LOD0", lambda g: T.wheel(g, 1, True)),
                                        (NAME + "_Wheel_FR_LOD0", lambda g: T.wheel(g, -1, True)),
                                        (NAME + "_Wheel_RL_LOD0", lambda g: T.wheel(g, 1, False)),
                                        (NAME + "_Wheel_RR_LOD0", lambda g: T.wheel(g, -1, False)),
                                        (NAME + "_Underbody_LOD0", T.underbody)], unwrap,
                             "MI_LifeguardPickup_Wheels", angle=50)
    def rack_and_kit(g):
        T.rack(g)
        T.kit(g)
    rack_set = V.build_set("Rack", [(NAME + "_Rack_LOD0", rack_and_kit)], unwrap, "MI_LifeguardPickup_Rack", angle=50)

    hps = [
        V.build_hp(NAME + "_Body_HP", [T.body], bevel=dict(width=0.012, segments=1, angle=40)),
        V.build_hp(NAME + "_BodyDetail_HP", [T.body_detail], bevel=dict(width=0.012, segments=1, angle=40)),
        V.build_hp(NAME + "_Cab_HP", [T.cab_interior], bevel=dict(width=0.008, segments=1, angle=40)),
        V.build_hp(NAME + "_Glass_HP", [T.glass]),
        V.build_hp(NAME + "_Wheel_FL_HP", [lambda g: T.wheel(g, 1, True)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_FR_HP", [lambda g: T.wheel(g, -1, True)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_RL_HP", [lambda g: T.wheel(g, 1, False)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_RR_HP", [lambda g: T.wheel(g, -1, False)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Underbody_HP", [T.underbody], bevel=dict(width=0.008, segments=1, angle=40)),
        V.build_hp(NAME + "_Rack_HP", [rack_and_kit], bevel=dict(width=0.010, segments=1, angle=40)),
    ]
    col = collision()

    atts = []
    for name, p in ATTACHMENTS.items():
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    lod0 = body_set + cab_set + wheels_set + rack_set
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
                   "chassis": [round(c, 4) for c in (Vector(CHASSIS) + off)],
                   "note": "offset added to the authored model frame; chassis = LandVehicleConfig / Builder root, "
                           "Blender studs, equal to the ATT_DriveAttachment position"}, f, indent=1)
    print("[%s] offset %s bbox %s chassis %s" % (NAME, tuple(round(c, 3) for c in off),
                                                 [round(c, 3) for c in bbox],
                                                 tuple(round(c, 3) for c in (Vector(CHASSIS) + off))))

    meshes = []
    for objs, s in ((body_set, "Body"), (cab_set, "Cab"), (wheels_set, "Wheels"), (rack_set, "Rack")):
        for o in objs:
            meshes.append({"object": o, "set": s})
    meshes += [{"object": h} for h in hps]
    meshes.append({"object": col})

    streak = {"rust": 0.08, "rust_color": (0.30, 0.24, 0.19), "rust_rough": 0.8, "rust_length": 0.40, "rust_fingers": 5,
              "salt": 0.16, "salt_range": (0.35, 0.8), "salt_color": (0.70, 0.69, 0.65),
              "edge_color": (0.78, 0.78, 0.76), "edge_metal": 0.0, "ao_strength": 0.10}   # worn paint / primer: chipped paint is not metal
    # wet: off-white and red service paint darken and gloss up (05 5.4); underbody stays matt
    sets = [
        {"name": TEX, "set": "Body", "size": 4096, "wet": True, "wet_darken": 0.32, "wet_gloss": 0.34,
         "wet_streaks": 0.45, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.6,
         "wear": dict(streak, edge=0.28, edge_color=(0.60, 0.60, 0.58), salt=0.22)},
        {"name": TEX, "set": "Cab", "size": 2048, "wet": True, "wet_darken": 0.22, "wet_gloss": 0.20,
         "wet_streaks": 0.25, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.2,
         "wear": dict(streak, edge=0.10, rust=0.0, salt=0.10)},
        {"name": TEX, "set": "Wheels", "size": 4096, "wet": True, "wet_darken": 0.30, "wet_gloss": 0.30,
         "wet_streaks": 0.40, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.4,
         "wear": dict(streak, edge=0.16, rust=0.25, salt=0.30, edge_color=(0.58, 0.57, 0.53))},
        {"name": TEX, "set": "Rack", "size": 2048, "wet": True, "wet_darken": 0.28, "wet_gloss": 0.28,
         "wet_streaks": 0.40, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.2,
         "wear": dict(streak, edge=0.20, rust=0.12, salt=0.26)},
    ]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    return {
        "name": NAME,
        "budget": "land_vehicle",
        "tris": 30000,
        "tier": "standard",
        "dims_m": (1.855, 5.33, 1.815),
        "size_note": "Z is 1.97 m to the top of the amber rotator light bar (the roof is 1.81 m); the reference board "
                      "gives the light-bar top as about 2.0 m and the docs/12 row lists the bar as a fitting on the "
                      "1.8 m-high cab.",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [
            {"name": "front_livery", "target": at((0.35, 0.75, 2.62)), "dist": 6, "az": 22, "el": 8},
            {"name": "door_livery", "target": at((2.7, 7.0, 2.6)), "dist": 6, "az": 90, "el": 8},
            {"name": "cab_interior", "target": at((-1.05, 7.05, 3.95)), "dist": 6, "az": 278, "el": 6},
            {"name": "light_bar_rack", "target": at((0.0, 7.6, 5.45)), "dist": 6, "az": 350, "el": 18},
            {"name": "bed_kit", "target": at((0.0, 12.9, 3.5)), "dist": 7, "az": 168, "el": 30},
            {"name": "wheel_arch", "target": at((2.5, 12.0, 1.5)), "dist": 5, "az": 80, "el": 12},
        ],
        "waivers": {
            "LOD UV layout": "collapse decimation shifts small lamp, grille, text and tyre-tread islands at LOD1/LOD2 "
                             "(area up to 35%); LOD1 is seen beyond 150 studs and LOD2 beyond 500, where the maps are "
                             "mip-mapped far below the island size. LOD0 sets are unchanged.",
            "geometry": "Wheel / rack LOD2: a few slivers and loose verts left by collapse decimation of thin spokes, "
                        "straps and tread blocks (not rendered at LOD2 distance); LOD0 and LOD1 are clean.",
        },
    }
