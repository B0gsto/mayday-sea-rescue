"""M_Veh_JetSki: generic three-seat rescue PWC with a rescue sled, Gale Isles Coastguard livery (batch V1).

Hull 3.37 m x 1.27 m (rub rail), 4.98 m overall with the sled (14.9 x 3.8 studs). Geometry in pwc.py (shared with
M_Veh_JetSki_CloseUp). Sets (docs/12 row, 2 sets + _Wet): Hull (hull, saddle, livery decal panels; 2048) and Sled
(sled, fittings, base bars; 2048). The Bars MeshPart is the one the first-person close-up set replaces for the rider.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Veh_JetSki --steps build,lod,validate,export
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
import pwcgeo as R  # noqa: E402
import pwc as P  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Veh_JetSki"
TEX = "JetSki"


def boosted_uv(boost):
    """smart_uv, then scale the UV islands of the parts in `boost` ({part index: factor}) and re-pack, so decal
    panels / screens get more texels than their surface area would give them."""
    def unwrap(obj, angle=55, margin=0.004):
        rbxkit.smart_uv(obj, angle=angle, margin=margin)
        me = obj.data
        part = me.attributes["part"].data
        uv = me.uv_layers.active.data
        for poly in me.polygons:
            k = boost.get(part[poly.index].value)
            if k:
                for li in poly.loop_indices:
                    uv[li].uv = uv[li].uv * k
        rbxkit.select_only(obj)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.select_all(action="SELECT")
        bpy.ops.uv.pack_islands(margin=0.004, rotate=True, shape_method="CONCAVE", scale=True)
        bpy.ops.object.mode_set(mode="OBJECT")
    return unwrap


def collision():
    bm = bmesh.new()
    pts = []
    for y in (P.NOSE, -4.2, -3.0, -1.5, 0.0, 2.0, 4.0, P.TRANSOM):
        for x, z in [P.profile(y)[k] for k in (0, 2, 5, 9, 14)]:
            pts += [(x, y, z), (-x, y, z)]
    for y in (P.SLED_Y0, P.SLED_Y1):
        for sx in (1, -1):
            pts += [(sx * P.SLED_HX, y, P.SLED_Z0), (sx * P.SLED_HX, y, P.SLED_Z1 + 0.25)]
    pts += [(0, -1.3, 3.3), (0.9, -1.2, 3.3), (-0.9, -1.2, 3.3)]
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = [v for v in set(res.get("geom_interior", []) + res.get("geom_unused", [])) if isinstance(v, bmesh.types.BMVert)]
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(NAME + "_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(NAME + "_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def gb(rx, ry, rz):
    """Greybox model space (Builder.luau buildJetSki) -> this build frame."""
    return (-rx, rz, ry + 1.1)


ATTACHMENTS = {
    "ATT_DriverSeat": (0.0, 1.4, 2.62),
    "ATT_EyePoint": tuple(P.EYE),
    "ATT_SurvivorSlot1": (0.0, 7.4, P.SLED_Z1 + 0.05),
    "ATT_TowHitch": (0.0, P.TRANSOM + 0.14, 1.18),
    "ATT_BowPoint": (0.0, P.NOSE - 0.1, 1.62),
    "ATT_DriveAttachment": gb(0, 0, 0),
    "ATT_NavPort": tuple(P.nav_light_pos(1) + Vector((0.1, -0.03, 0))),
    "ATT_NavStarboard": tuple(P.nav_light_pos(-1) + Vector((-0.1, -0.03, 0))),
    "ATT_NavMasthead": tuple(P.MAST + Vector((0, 0, 0.04))),
    "ATT_KillCord": tuple(P.KILL),
    "ATT_Display": tuple(P.DISPLAY_C),
    "ATT_Prop1": (0.0, P.TRANSOM + 0.55, 0.5),
}
FLOATS = [(-0.8, -3.6), (0.8, -3.6), (-1.4, 0.0), (1.4, 0.0), (-1.5, 3.6), (1.5, 3.6)]


def build():
    hull_set = R.build_set("Hull", [(NAME + "_Hull_LOD0", P.hull), (NAME + "_Seat_LOD0", P.seat),
                                    (NAME + "_Decals_LOD0", P.decals)], boosted_uv({2: 2.0}), "MI_JetSki_Hull")
    sled_set = R.build_set("Sled", [(NAME + "_Sled_LOD0", P.sled), (NAME + "_Fittings_LOD0", P.fittings),
                                    (NAME + "_Bars_LOD0", P.base_bars)], rbxkit.smart_uv, "MI_JetSki_Sled")
    hps = [
        R.build_hp(NAME + "_Hull_HP", [P.hull]),
        R.build_hp(NAME + "_Seat_HP", [P.seat]),
        R.build_hp(NAME + "_Decals_HP", [P.decals]),
        R.build_hp(NAME + "_Sled_HP", [P.sled, P.rescue_text], bevel=dict(width=0.012, segments=2, angle=40)),
        R.build_hp(NAME + "_Fittings_HP", [P.fittings], bevel=dict(width=0.01, segments=2, angle=40)),
        R.build_hp(NAME + "_Bars_HP", [P.base_bars, P.display_screen], bevel=dict(width=0.006, segments=2, angle=40)),
    ]
    col = collision()
    atts = []
    for name, p in list(ATTACHMENTS.items()) + [("ATT_Float%d" % (i + 1), gb(x, -1.05, z)) for i, (x, z) in enumerate(FLOATS)]:
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    lod0 = hull_set + sled_set
    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    off = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    for o in lod0 + hps + [col]:
        o.data.transform(Matrix.Translation(off))
    for e in atts:
        e.location = e.location + off
    with open(os.path.join(HERE, "frame_offset.json"), "w") as f:
        json.dump({"offset": list(off), "bbox_studs": [h - l for l, h in zip(lo, hi)],
                   "eye": list(P.EYE + off), "display": list(P.DISPLAY_C + off)}, f)
    print("[M_Veh_JetSki] offset %s bbox %s" % (tuple(round(c, 3) for c in off), [round(h - l, 3) for l, h in zip(lo, hi)]))

    meshes = [{"object": o, "set": "Hull"} for o in hull_set] + [{"object": o, "set": "Sled"} for o in sled_set]
    meshes += [{"object": h} for h in hps] + [{"object": col}]
    streak = {"rust": 0.08, "rust_color": (0.28, 0.26, 0.24), "rust_rough": 0.7, "rust_length": 0.4, "rust_fingers": 5,
              "salt": 0.12, "salt_range": (0.35, 0.8), "salt_color": (0.6, 0.59, 0.56), "edge_color": (0.56, 0.56, 0.55)}
    wet = {"wet": True, "wet_darken": 0.35, "wet_gloss": 0.2,   # Studio pass 1: 0.5 made Clear wet a sky mirror (wet_rough.py fixed the shipped maps)
           "wet_streaks": 0.45, "cage_extrusion": 0.05,
           "max_ray_distance": 0.12}
    sets = [
        dict(wet, name=TEX, set="Hull", size=2048, wear=dict(streak, edge=0.15, edge_color=(0.5, 0.42, 0.38))),
        dict(wet, name=TEX, set="Sled", size=2048, wear=dict(streak, edge=0.2, salt=0.12)),
    ]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    eye, disp = P.EYE + off, P.DISPLAY_C + off
    d = eye - disp
    return {
        "name": NAME,
        "budget": "jetski",
        "tier": "hero",
        "dims_m": (1.24, 4.98, 1.20),
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [
            {"name": "rider_eye_bars", "target": at(P.DISPLAY_C), "dist": round(d.length, 3), "az": 180,
             "el": round(math.degrees(math.asin(d.z / d.length)), 2)},
            {"name": "sled", "target": at((0.0, 7.6, 1.3)), "dist": 7, "az": 140, "el": 35},
            {"name": "side_decals", "target": at((2.0, 0.6, 1.25)), "dist": 7, "az": 90, "el": 5},
            {"name": "bow_number_crest", "target": at((1.5, -3.3, 1.6)), "dist": 4, "az": 70, "el": 10},
            {"name": "stern_jet_tow_eye", "target": at((0.0, 5.2, 1.0)), "dist": 4.5, "az": 200, "el": 20},
            {"name": "hood_nav_mirror", "target": at((1.1, -3.0, 2.6)), "dist": 4, "az": 50, "el": 30},
        ],
        "waivers": {
            "LOD UV layout": "LOD1 / LOD2 collapse decimation shifts the borders of small fitting, handle and bar UV "
                             "islands (bounds 0.02 to 0.1, area up to 40%); LOD1 is seen beyond 150 studs and LOD2 "
                             "beyond 500, where the maps are mip-mapped far below the island size. Hull LODs pass.",
            "geometry": "Bars LOD2: a few loose verts and slivers left by collapse decimation of the thin bar / lanyard "
                        "tubes (not rendered at LOD2 distance); LOD0 and LOD1 pass.",
        },
    }
