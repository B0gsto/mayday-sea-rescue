"""M_Veh_Ambulance: invented UK box-body paramedic ambulance (Sprinter / Ducato class), batch V4.

6.8 x 2.3 x 2.9 m (20.4 x 6.9 x 8.7 studs; the row width is over the mirrors, body 2.2 m). White base paint with
high-vis yellow / green chequer bands, the Cottage Hospital's heart-over-waves roundel and "AMBULANCE" mirrored on
the front; no cross of any kind. Blue roof beacons, grille strobes, high side windows, nearside sliding door, rear
doors with windows, chevron rear, rear step. Light road grime and salt spray.

Matches the code-built ambulance in src/shared/Car/Builder.luau (ambulanceBody) and LandVehicleConfig.Ambulance:
four separate wheel meshes at the physics hub positions (wheelbase 4.33 m, track 1.71 m, wheel 0.72 m), RHD seats at
W * 0.24, blue beacon light bar, rear-door handover point for src/client/Mechanics/handover.luau.

Sets (docs/12 row, 4): Body (cab exterior, bumpers, lamps, mirrors, cab chequer), Box (box shell, sliding door, rear
doors, roof gear, beacons, livery), Cab (interior + glass), Wheels (four wheels + underbody); every set has _Wet.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/vehicles/M_Veh_Ambulance/build.py --out-root build/prod/M_Veh_Ambulance \
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
import geo as G  # noqa: E402
import vehgeo as V  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Veh_Ambulance"
TEX = "Ambulance"
M = G.STUDS_M

# chassis (physics) origin in the model frame: 1.0 m front overhang + 4.33 m x (1 - 0.45) of wheelbase behind the
# front axle, cgHeight 1.1 m above the ground (Builder.luau / LandVehicleConfig.Ambulance)
CHASSIS = (0.0, G.AX_F + M * 4.33 * (1 - 0.45), 1.1 * M)


def collision():
    bm = bmesh.new()
    pts = []
    for y in (0.5, 1.6, 3.0, 4.6, 6.2, 7.8, 9.2, 11.0, 12.8, 14.6, 16.4, 18.2, 19.6, 20.4):
        for x in (-3.30, -1.7, 0.0, 1.7, 3.30):
            pts.append((x, y, 1.0))
            pts.append((x, y, 3.0))
        pts.append((0.0, y, 7.4))
        pts.append((0.0, y, 8.7))
    for y in (1.6, 3.0, 5.0, 7.0):
        pts += [(-2.6, y, 2.2), (2.6, y, 2.2)]
    for y in (9.4, 12.0, 15.0, 18.0, 20.1):
        pts += [(-3.34, y, 2.0), (3.34, y, 2.0), (-3.34, y, 8.6), (3.34, y, 8.6), (0.0, y, 8.72)]
    pts += [(-3.30, 0.9, 1.2), (3.30, 0.9, 1.2), (-3.30, 20.6, 1.2), (3.30, 20.6, 1.2)]
    for hy in (G.AX_F, G.AX_R):
        for sx in (-1, 1):
            for a in range(0, 360, 60):
                t = math.radians(a)
                pts.append((sx * 2.9, hy + 1.2 * math.cos(t), G.WHEEL_Z + 1.2 * math.sin(t)))
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
    # wheels: physics hub centres (Builder: Wheel_FL/FR/RL/RR, track 1.71 m, wheelbase 4.33 m)
    "ATT_Wheel_FL": (G.HUB_X, G.AX_F, G.WHEEL_Z),
    "ATT_Wheel_FR": (-G.HUB_X, G.AX_F, G.WHEEL_Z),
    "ATT_Wheel_RL": (G.HUB_X, G.AX_R, G.WHEEL_Z),
    "ATT_Wheel_RR": (-G.HUB_X, G.AX_R, G.WHEEL_Z),
    # seats: RHD, driver on Roblox +X (Blender -X); Builder puts the pair at W * 0.24, 1.6 m behind the nose
    "ATT_DriverSeat": (-G.SEAT_X, 6.62, 2.72),
    "ATT_Seat2": (G.SEAT_X, 6.62, 2.72),
    # driver's eye: DriverSeat + (0, 2.4, -0.2) studs (LandVehicleConfig.Ambulance.eyePoint)
    "ATT_EyePoint": (-G.SEAT_X, 6.42, 4.98),
    # rear doors and the stretcher / handover points behind them (handover.luau reads HandoverPoint)
    "ATT_RearDoor_L": (2.95, G.BOX_R + 0.10, 4.80),
    "ATT_RearDoor_R": (-2.95, G.BOX_R + 0.10, 4.80),
    "ATT_StretcherLoad": (0.0, G.BOX_R + 0.40, 2.90),
    "ATT_HandoverPoint": (0.0, G.BOX_R + 4.50, 3.60),
    "ATT_SideDoor": (G.HW_BOX - 0.07, (G.SLIDE[0] + G.SLIDE[1]) / 2, 4.60),
    # lamps and beacons
    "ATT_LightBar": (0.0, 7.34, G.ROOF_CAB + 0.30),
    "ATT_Beacon_01": (-1.62, 7.34, G.ROOF_CAB + 0.55),
    "ATT_Beacon_02": (-0.54, 7.34, G.ROOF_CAB + 0.55),
    "ATT_Beacon_03": (0.54, 7.34, G.ROOF_CAB + 0.55),
    "ATT_Beacon_04": (1.62, 7.34, G.ROOF_CAB + 0.55),
    "ATT_Beacon_05": (-2.34, 9.62, G.ROOF_BOX + 0.26),
    "ATT_Beacon_06": (2.34, 9.62, G.ROOF_BOX + 0.26),
    "ATT_Beacon_07": (-2.34, 19.86, G.ROOF_BOX + 0.26),
    "ATT_Beacon_08": (2.34, 19.86, G.ROOF_BOX + 0.26),
    "ATT_GrilleLamp_L": (0.86, 0.60, 2.74),
    "ATT_GrilleLamp_R": (-0.86, 0.60, 2.74),
    "ATT_Headlamp_L": (1.74, 0.58, 2.60),
    "ATT_Headlamp_R": (-1.74, 0.58, 2.60),
    "ATT_TailLamp_L": (2.86, G.BOX_R + 0.48, 2.50),
    "ATT_TailLamp_R": (-2.86, G.BOX_R + 0.48, 2.50),
    "ATT_BrakeLamp_L": (2.86, G.BOX_R + 0.48, 2.14),
    "ATT_BrakeLamp_R": (-2.86, G.BOX_R + 0.48, 2.14),
    "ATT_ReverseLamp_L": (2.58, G.BOX_R + 0.48, 1.86),
    "ATT_ReverseLamp_R": (-2.58, G.BOX_R + 0.48, 1.86),
    "ATT_DriveAttachment": CHASSIS,
}


def build():
    unwrap = rbxkit.smart_uv
    def cab_all(g):
        G.cab_shell(g)
        G.livery_cab(g)

    def box_all(g):
        G.box_body(g)
        G.livery_box(g)

    body_set = V.build_set("Body", [(NAME + "_Body_LOD0", cab_all),
                                    (NAME + "_BodyDetail_LOD0", G.cab_detail)], unwrap, "MI_Ambulance_Body", angle=62)
    box_set = V.build_set("Box", [(NAME + "_Box_LOD0", box_all),
                                  (NAME + "_BoxDetail_LOD0", G.box_detail)], unwrap, "MI_Ambulance_Box", angle=60)
    cab_set = V.build_set("Cab", [(NAME + "_Cab_LOD0", G.cab_interior),
                                  (NAME + "_Glass_LOD0", G.cabin_glass),
                                  (NAME + "_Windscreen_LOD0", G.windscreen)], unwrap, "MI_Ambulance_Cab", angle=55)
    wheels_set = V.build_set("Wheels", [(NAME + "_Wheel_FL_LOD0", lambda g: G.wheel(g, 1, True)),
                                        (NAME + "_Wheel_FR_LOD0", lambda g: G.wheel(g, -1, True)),
                                        (NAME + "_Wheel_RL_LOD0", lambda g: G.wheel(g, 1, False)),
                                        (NAME + "_Wheel_RR_LOD0", lambda g: G.wheel(g, -1, False)),
                                        (NAME + "_Underbody_LOD0", G.underbody)], unwrap,
                             "MI_Ambulance_Wheels", angle=50)

    hps = [
        V.build_hp(NAME + "_Body_HP", [cab_all], bevel=dict(width=0.012, segments=1, angle=40)),
        V.build_hp(NAME + "_BodyDetail_HP", [G.cab_detail], bevel=dict(width=0.010, segments=1, angle=40)),
        V.build_hp(NAME + "_Box_HP", [box_all], bevel=dict(width=0.012, segments=1, angle=40)),
        V.build_hp(NAME + "_BoxDetail_HP", [G.box_detail], bevel=dict(width=0.010, segments=1, angle=40)),
        V.build_hp(NAME + "_Cab_HP", [G.cab_interior], bevel=dict(width=0.008, segments=1, angle=40)),
        V.build_hp(NAME + "_Glass_HP", [G.cabin_glass]),
        V.build_hp(NAME + "_Windscreen_HP", [G.windscreen]),
        V.build_hp(NAME + "_Wheel_FL_HP", [lambda g: G.wheel(g, 1, True)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_FR_HP", [lambda g: G.wheel(g, -1, True)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_RL_HP", [lambda g: G.wheel(g, 1, False)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_RR_HP", [lambda g: G.wheel(g, -1, False)], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Underbody_HP", [G.underbody], bevel=dict(width=0.008, segments=1, angle=40)),
    ]
    col = collision()

    atts = []
    for name, p in ATTACHMENTS.items():
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    lod0 = body_set + box_set + cab_set + wheels_set
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
    for objs, s in ((body_set, "Body"), (box_set, "Box"), (cab_set, "Cab"), (wheels_set, "Wheels")):
        for o in objs:
            meshes.append({"object": o, "set": s})
    meshes += [{"object": h} for h in hps]
    meshes.append({"object": col})

    streak = {"rust": 0.10, "rust_color": (0.32, 0.26, 0.20), "rust_rough": 0.8, "rust_length": 0.42, "rust_fingers": 5,
              "salt": 0.20, "salt_range": (0.32, 0.78), "salt_color": (0.70, 0.69, 0.64),
              "edge_color": (0.78, 0.78, 0.76), "edge_metal": 0.0, "ao_strength": 0.10}   # worn paint: chips are not metal
    sets = [
        {"name": TEX, "set": "Body", "size": 4096, "wet": True, "wet_darken": 0.30, "wet_gloss": 0.32,
         "wet_streaks": 0.45, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.8,
         "wear": dict(streak, edge=0.26, edge_color=(0.60, 0.60, 0.58), salt=0.24)},
        {"name": TEX, "set": "Box", "size": 4096, "wet": True, "wet_darken": 0.28, "wet_gloss": 0.30,
         "wet_streaks": 0.42, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.8,
         "wear": dict(streak, edge=0.22, salt=0.26)},
        {"name": TEX, "set": "Cab", "size": 4096, "wet": True, "wet_darken": 0.20, "wet_gloss": 0.18,
         "wet_streaks": 0.22, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.2,
         "wear": dict(streak, edge=0.10, rust=0.0, salt=0.08)},
        {"name": TEX, "set": "Wheels", "size": 4096, "wet": True, "wet_darken": 0.30, "wet_gloss": 0.30,
         "wet_streaks": 0.40, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.4,
         "wear": dict(streak, edge=0.16, rust=0.16, salt=0.22, edge_color=(0.62, 0.61, 0.57))},
    ]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    return {
        "name": NAME,
        "budget": "land_vehicle",
        "tris": 30000,
        "tier": "standard",
        "dims_m": (2.3, 6.8, 2.9),
        "size_note": "X 2.30 m is over the mirrors (body 2.2 m); Z 2.90 m is the box roof and the beacons stay "
                     "under it (light bar domes reach 2.68 m). Both axes are inside the row as written.",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [
            {"name": "front_livery", "target": at((0.0, 0.30, 2.55)), "dist": 8, "az": 26, "el": 6},
            {"name": "bonnet_text", "target": at((0.0, 9.16, 8.10)), "dist": 7, "az": 4, "el": 24},
            {"name": "side_livery", "target": at((3.30, 16.4, 4.60)), "dist": 8, "az": 92, "el": 6},
            {"name": "sliding_door", "target": at((3.34, 13.90, 5.20)), "dist": 7, "az": 78, "el": 8},
            {"name": "rear_doors", "target": at((0.0, 20.60, 4.60)), "dist": 8, "az": 168, "el": 10},
            {"name": "beacons_roof", "target": at((0.0, 9.60, 8.30)), "dist": 7, "az": 340, "el": 22},
            {"name": "cab_interior", "target": at((-1.10, 6.60, 4.20)), "dist": 6, "az": 282, "el": 8},
            {"name": "wheel_arch", "target": at((3.10, 15.99, 1.70)), "dist": 5, "az": 82, "el": 12},
        ],
        "waivers": {
            "LOD UV layout": "collapse decimation shifts small lamp, beacon, grille and text islands at LOD1/LOD2 "
                             "(area up to 35%); LOD1 is seen beyond 150 studs and LOD2 beyond 500, where the maps "
                             "are mip-mapped far below the island size. LOD0 sets are unchanged.",
            "geometry": "Wheel / underbody LOD2: a few slivers and loose verts left by collapse decimation of thin "
                        "spokes, straps and tread blocks (not rendered at LOD2 distance); LOD0 and LOD1 are clean.",
        },
    }
