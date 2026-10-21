"""M_Veh_Coastguard4x4: invented Gale Isles coastguard cliff-rescue 4x4, batch V5.

5.10 x 2.06 x 2.37 m (15.3 x 6.2 x 7.1 studs; width over the mirrors, height to the beacon domes). White body with
navy lower panels, high-vis yellow / navy chequer bands, an invented cliff-and-wave crest and "GALE ISLES
COASTGUARD / RESCUE" lettering. High-roof station wagon with a roof rack carrying a stowed pneumatic floodlight
mast, rope bags, a folded A-frame tripod and a stretcher; blue beacons and light bar, snorkel, winch bumper, side
steps, spare on the rear door. Mud and salt on the lower panels.

Matches LandVehicleConfig.CoastguardResponse: four separate wheel meshes at the physics hubs (wheelbase 2.794 m,
track 1.486 m, wheel 0.78 m), RHD five seats, five ATT_Seat markers, blue beacon positions and the chassis drive root.

Sets (docs/12 row, 4): Body (shell, bumpers, livery), Rack (roof rack, mast, kit, beacons, snorkel),
Cab (interior + glass), Wheels (four wheels, spare, underbody); every set has _Wet.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/vehicles/M_Veh_Coastguard4x4/build.py --out-root build/prod/M_Veh_Coastguard4x4 \
      --steps build,lod,bake,validate,export,turntable
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

NAME = "M_Veh_Coastguard4x4"
TEX = "Coastguard4x4"
M = G.STUDS_M

# chassis (physics) origin: 0.75 m front overhang + 2.794 m x (1 - 0.5) of wheelbase behind the front axle,
# cgHeight 0.88 m above the ground (LandVehicleConfig.CoastguardResponse)
CHASSIS = (0.0, G.AX_F + M * 2.794 * (1 - 0.5), 0.88 * M)


def collision():
    bm = bmesh.new()
    pts = []
    for y in (-0.2, 0.6, 1.4, 2.4, 3.6, 4.8, 6.0, 7.2, 8.4, 9.6, 10.8, 12.0, 13.2, 14.2, 14.8):
        for x in (-2.62, -1.2, 0.0, 1.2, 2.62):
            pts.append((x, y, 1.0))
            pts.append((x, y, 2.8))
        pts.append((0.0, y, 5.9))
    for y in (4.4, 5.6, 6.8, 8.0):
        pts += [(-2.6, y, 5.85), (2.6, y, 5.85), (0.0, y, 5.96)]
    for y in (4.3, 6.4, 9.0, 11.6, 13.6):
        pts += [(-2.55, y, 6.4), (2.55, y, 6.4)]
    pts += [(-2.55, 6.4, 6.6), (2.55, 6.4, 6.6), (0.0, 4.3, 7.05)]
    pts += [(-3.04, 3.5, 4.6), (3.04, 3.5, 4.6)]
    pts += [(-2.62, -0.2, 1.2), (2.62, -0.2, 1.2), (-2.62, 14.4, 1.2), (2.62, 14.4, 1.2)]
    for hy in (G.AX_F, G.AX_R):
        for sx in (-1, 1):
            for a in range(0, 360, 60):
                t = math.radians(a)
                pts.append((sx * 2.55, hy + 1.2 * math.cos(t), G.WHEEL_Z + 1.2 * math.sin(t)))
        pts.append((0.0, hy, 0.55))
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
    # wheels: physics hub centres (wheelbase 2.794 m, track 1.486 m)
    "ATT_Wheel_FL": (G.HUB_X, G.AX_F, G.WHEEL_Z),
    "ATT_Wheel_FR": (-G.HUB_X, G.AX_F, G.WHEEL_Z),
    "ATT_Wheel_RL": (G.HUB_X, G.AX_R, G.WHEEL_Z),
    "ATT_Wheel_RR": (-G.HUB_X, G.AX_R, G.WHEEL_Z),
    # seats: RHD, driver on Blender -X; front pair, three across the rear bench
    "ATT_DriverSeat": (-G.SEAT_X, 6.15, 2.50),
    "ATT_Seat2": (G.SEAT_X, 6.15, 2.50),
    "ATT_Seat3": (1.55, 8.62, 2.56),
    "ATT_Seat4": (0.0, 8.62, 2.56),
    "ATT_Seat5": (-1.55, 8.62, 2.56),
    "ATT_EyePoint": (-G.SEAT_X, 5.95, 4.72),
    # doors and working points
    "ATT_Door_L": (G.HW + 0.03, 5.10, 2.55),
    "ATT_Door_R": (-(G.HW + 0.03), 5.10, 2.55),
    "ATT_Door_RL": (G.HW + 0.03, 7.55, 2.55),
    "ATT_Door_RR": (-(G.HW + 0.03), 7.55, 2.55),
    "ATT_RearDoor": (0.0, G.BODY_R + 0.12, 2.55),
    "ATT_Snorkel": (-2.83, 3.20, 4.60),
    "ATT_Winch": (0.0, -0.04, 1.96),
    "ATT_TowHitch": (0.0, G.BODY_R + 0.62, 1.12),
    "ATT_SpareWheel": (0.0, G.BODY_R + 0.70, 2.95),
    # roof rack, mast and cliff kit
    "ATT_RoofRack": (0.0, 9.00, G.RACK_Z),
    "ATT_Mast": (-1.52, G.RACK_R - 0.50, G.RACK_Z + 0.28),
    "ATT_Floodlight": (-1.52, 9.02, G.RACK_Z + 0.22),
    "ATT_RopeKit": (0.82, 9.60, G.RACK_Z + 0.52),
    "ATT_Tripod": (-0.42, 12.00, G.RACK_Z + 0.22),
    "ATT_Stretcher": (1.42, 11.62, G.RACK_Z + 0.26),
    # beacons and lamps
    "ATT_LightBar": (0.0, 4.26, G.RACK_Z + 0.30),
    "ATT_Beacon_01": (-1.44, 4.26, G.RACK_Z + 0.70),
    "ATT_Beacon_02": (-0.48, 4.26, G.RACK_Z + 0.70),
    "ATT_Beacon_03": (0.48, 4.26, G.RACK_Z + 0.70),
    "ATT_Beacon_04": (1.44, 4.26, G.RACK_Z + 0.70),
    "ATT_Beacon_05": (-2.30, G.RACK_R - 0.32, G.RACK_Z + 0.44),
    "ATT_Beacon_06": (2.30, G.RACK_R - 0.32, G.RACK_Z + 0.44),
    "ATT_Headlamp_L": (1.90, 0.20, 2.54),
    "ATT_Headlamp_R": (-1.90, 0.20, 2.54),
    "ATT_TailLamp_L": (2.38, G.BODY_R + 0.24, 3.34),
    "ATT_TailLamp_R": (-2.38, G.BODY_R + 0.24, 3.34),
    "ATT_BrakeLamp_L": (2.38, G.BODY_R + 0.24, 3.34),
    "ATT_BrakeLamp_R": (-2.38, G.BODY_R + 0.24, 3.34),
    "ATT_ReverseLamp_L": (2.38, G.BODY_R + 0.24, 2.64),
    "ATT_ReverseLamp_R": (-2.38, G.BODY_R + 0.24, 2.64),
    "ATT_DriveAttachment": CHASSIS,
}


def build():
    unwrap = rbxkit.smart_uv
    body_set = V.build_set("Body", [(NAME + "_Body_LOD0", G.body_shell),
                                    (NAME + "_BodyDetail_LOD0", G.body_detail)], unwrap,
                           "MI_Coastguard4x4_Body", angle=62)
    rack_set = V.build_set("Rack", [(NAME + "_Rack_LOD0", G.rack)], unwrap,
                           "MI_Coastguard4x4_Rack", angle=55)
    cab_set = V.build_set("Cab", [(NAME + "_Cab_LOD0", G.cab),
                                  (NAME + "_Glass_LOD0", G.glass)], unwrap,
                          "MI_Coastguard4x4_Cab", angle=55)
    wheels_set = V.build_set("Wheels", [(NAME + "_Wheel_FL_LOD0", lambda g: G.wheel(g, 1, True)),
                                        (NAME + "_Wheel_FR_LOD0", lambda g: G.wheel(g, -1, True)),
                                        (NAME + "_Wheel_RL_LOD0", lambda g: G.wheel(g, 1, False)),
                                        (NAME + "_Wheel_RR_LOD0", lambda g: G.wheel(g, -1, False)),
                                        (NAME + "_Spare_LOD0", G.spare_wheel),
                                        (NAME + "_Underbody_LOD0", G.wheels_underbody)], unwrap,
                             "MI_Coastguard4x4_Wheels", angle=50)

    hps = [
        V.build_hp(NAME + "_Body_HP", [G.body_shell], bevel=dict(width=0.012, segments=1, angle=40)),
        V.build_hp(NAME + "_BodyDetail_HP", [G.body_detail], bevel=dict(width=0.010, segments=1, angle=40)),
        V.build_hp(NAME + "_Rack_HP", [G.rack], bevel=dict(width=0.010, segments=1, angle=40)),
        V.build_hp(NAME + "_Cab_HP", [G.cab], bevel=dict(width=0.008, segments=1, angle=40)),
        V.build_hp(NAME + "_Glass_HP", [G.glass]),
        V.build_hp(NAME + "_Wheel_FL_HP", [lambda g: G.wheel(g, 1, True)],
                   bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_FR_HP", [lambda g: G.wheel(g, -1, True)],
                   bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_RL_HP", [lambda g: G.wheel(g, 1, False)],
                   bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Wheel_RR_HP", [lambda g: G.wheel(g, -1, False)],
                   bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Spare_HP", [G.spare_wheel], bevel=dict(width=0.008, segments=1, angle=45)),
        V.build_hp(NAME + "_Underbody_HP", [G.wheels_underbody], bevel=dict(width=0.008, segments=1, angle=40)),
    ]
    col = collision()

    atts = []
    for name, p in ATTACHMENTS.items():
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    lod0 = body_set + rack_set + cab_set + wheels_set
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
    for objs, s in ((body_set, "Body"), (rack_set, "Rack"), (cab_set, "Cab"), (wheels_set, "Wheels")):
        for o in objs:
            meshes.append({"object": o, "set": s})
    meshes += [{"object": h} for h in hps]
    meshes.append({"object": col})

    streak = {"rust": 0.16, "rust_color": (0.28, 0.22, 0.16), "rust_rough": 0.82, "rust_length": 0.46,
              "rust_fingers": 5, "salt": 0.30, "salt_range": (0.30, 0.76), "salt_color": (0.72, 0.70, 0.64),
              "edge_color": (0.80, 0.78, 0.72), "edge_metal": 0.0, "ao_strength": 0.10}
    sets = [
        {"name": TEX, "set": "Body", "size": 4096, "wet": True, "wet_darken": 0.30, "wet_gloss": 0.32,
         "wet_streaks": 0.48, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.8,
         "wear": dict(streak, edge=0.30, salt=0.26)},
        {"name": TEX, "set": "Rack", "size": 4096, "wet": True, "wet_darken": 0.28, "wet_gloss": 0.30,
         "wet_streaks": 0.42, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.4,
         "wear": dict(streak, edge=0.24, rust=0.22, salt=0.30)},
        {"name": TEX, "set": "Cab", "size": 2048, "wet": True, "wet_darken": 0.20, "wet_gloss": 0.18,
         "wet_streaks": 0.24, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.2,
         "wear": dict(streak, edge=0.12, rust=0.0, salt=0.10)},
        {"name": TEX, "set": "Wheels", "size": 4096, "wet": True, "wet_darken": 0.32, "wet_gloss": 0.30,
         "wet_streaks": 0.44, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.4,
         "wear": dict(streak, edge=0.18, rust=0.20, salt=0.32, edge_color=(0.64, 0.62, 0.56))},
    ]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    return {
        "name": NAME,
        "budget": "land_vehicle",
        "tris": 30000,
        "tier": "standard",
        "dims_m": (2.06, 5.10, 2.37),
        "size_note": "X 2.06 m is over the door mirrors, Z 2.37 m to the beacon domes (roof 1.95 m, rack 2.13 m); "
                     "both are inside the row as written.",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [
            {"name": "front_livery", "target": at((0.0, -0.10, 2.60)), "dist": 8, "az": 20, "el": 6},
            {"name": "bonnet_winch", "target": at((0.0, 1.10, 2.90)), "dist": 8, "az": 8, "el": 20},
            {"name": "side_livery", "target": at((2.75, 6.10, 3.10)), "dist": 9, "az": 88, "el": 5},
            {"name": "rear_kit", "target": at((0.0, 13.30, 3.60)), "dist": 8, "az": 168, "el": 8},
            {"name": "roof_kit", "target": at((0.2, 11.40, 6.60)), "dist": 8, "az": 300, "el": 28},
            {"name": "mast_head", "target": at((-1.52, 9.30, 6.70)), "dist": 5, "az": 250, "el": 18},
            {"name": "cab_interior", "target": at((-1.20, 6.20, 3.90)), "dist": 6, "az": 282, "el": 8},
            {"name": "wheel_arch", "target": at((2.60, 10.73, 1.80)), "dist": 5, "az": 82, "el": 12},
        ],
        "waivers": {
            "LOD UV layout": "collapse decimation shifts small lettering, chequer, beacon and kit islands at LOD1 and "
                             "LOD2 (area up to 35%); LOD1 is seen beyond 150 studs and LOD2 beyond 500, where the maps "
                             "are mip-mapped far below the island size. LOD0 sets are unchanged.",
            "geometry": "Wheel / underbody LOD2: a few slivers and loose verts left by collapse decimation of thin "
                        "tread blocks, cables and straps (not rendered at LOD2 distance); LOD0 and LOD1 are clean.",
        },
    }
