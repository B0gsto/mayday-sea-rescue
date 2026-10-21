"""M_Rock_IslandProxy_Kit (P1, docs/12 2.7; docs/10 6.3): far-distance proxies for the two islands the bake window
contains, meshed from map/generated/terrain_height.i16, sliced by the land mask, decimated to 1,000 to 3,000 triangles,
skirted below the waterline, sunk 1 stud and coloured from the real Terrain material maps (terrain_material.u8).
The kit is authored in world space (Blender (x, y, z) = (-world x, world z, height)); placing the model at the map origin
lines every piece up. placements.json records each piece's world box and centre.
"""
import json
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
LIB = os.path.join(REPO, "tools/blender")
for p in (LIB, HERE):
    if p not in sys.path:
        sys.path.insert(0, p)
import common  # noqa: E402
import names  # noqa: E402
import pbrmaps  # noqa: E402
import proxygeo as G  # noqa: E402
import versions  # noqa: E402

NAME = "M_Rock_IslandProxy_Kit"
TEX = "IslandProxy"
SET = "Terrain"
ATLAS = 2048
PIECE_NAMES = ("GreatGale", "SkerryIsle")
PIECE_TRIS = (3000, 2350)
TEX_MAX = 3000
TEX_MIN = 1000


def nearest_land(comp, meta, wx, wz):
    i = int(round((wx - meta["originX"]) / meta["cell"]))
    j = int(round((wz - meta["originZ"]) / meta["cell"]))
    if 0 <= i < meta["nx"] and 0 <= j < meta["nz"] and comp["mask"][j, i]:
        return j, i
    best, at = 1e18, None
    j0, j1 = comp["j0"], comp["j1"]
    i0, i1 = comp["i0"], comp["i1"]
    for jj in range(max(j0, j - 60), min(j1, j + 60) + 1, 3):
        for ii in range(max(i0, i - 60), min(i1, i + 60) + 1, 3):
            if comp["mask"][jj, ii]:
                d = (ii - i) ** 2 + (jj - j) ** 2
                if d < best:
                    best, at = d, (jj, ii)
    return at


def build():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith("M_Rock_IslandProxy") or o.name.startswith("ATT_IslandProxy"):
            bpy.data.objects.remove(o, do_unlink=True)

    meta, h, mat = G.load_terrain()
    comps = G.components(meta, h)
    if not comps:
        raise RuntimeError("no land components found")
    comps = comps[:4]
    medians = G.variant_medians()
    colour_path = os.path.join(common.out_root(), "masters", NAME, "terrain_colour.png")
    colour_path = G.terrain_colour_image(meta, mat, medians, colour_path)
    image = bpy.data.images.load(colour_path, check_existing=True)
    image.colorspace_settings.name = "Non-Color"
    material = G.bake_material("MI_IslandProxy_Terrain", image, meta)

    rects = ((0.002, 0.336, 0.660, 0.998), (0.002, 0.002, 0.310, 0.310), (0.68, 0.002, 0.998, 0.31), (0.68, 0.336, 0.998, 0.66))
    pieces = []
    for k, comp in enumerate(comps):
        label = PIECE_NAMES[k] if k < len(PIECE_NAMES) else "Islet%02d" % (k - 1)
        comp["name"] = "M_Rock_IslandProxy_" + label
        stride = 3 if comp["area"] > 100000 else 1
        target = min(TEX_MAX, PIECE_TRIS[k] if k < len(PIECE_TRIS) else 1800)
        obj = G.top_mesh(meta, h, comp, stride)
        before = G.tris(obj)
        versions.decimate(obj, int(target * 1.12))
        G.skirt(obj)
        if G.tris(obj) > target:
            versions.decimate(obj, target)
        print("[proxy] %s top %d -> %d triangles, skirted %d" % (label, before, G.tris(obj), G.tris(obj)))
        G.unwrap(obj)
        G.fit_rect(obj, rects[k if k < len(rects) else 2])
        obj.data.materials.clear()
        obj.data.materials.append(material)
        hp = obj.copy()
        hp.data = obj.data.copy()
        hp.name = hp.data.name = comp["name"] + "_HP"
        bpy.context.scene.collection.objects.link(hp)
        lo, hi = G.bounds(obj)
        pieces.append({"object": obj, "hp": hp, "comp": comp, "lo": lo, "hi": hi, "label": label})

    lo = np.min([p["lo"] for p in pieces], axis=0)
    hi = np.max([p["hi"] for p in pieces], axis=0)
    dims = hi - lo

    placements = []
    for p in pieces:
        lo_b, hi_b = p["lo"], p["hi"]
        rb_lo = [-hi_b[0], lo_b[2], lo_b[1]]
        rb_hi = [-lo_b[0], hi_b[2], hi_b[1]]
        placements.append({
            "name": p["object"].name.replace("_LOD0", ""),
            "lod0_tris": int(G.tris(p["object"])),
            "world_position_studs": [round(float(-(lo_b[0] + hi_b[0]) / 2.0), 2), 0.0, round(float((lo_b[1] + hi_b[1]) / 2.0), 2)],
            "world_bbox_studs": {"min": [round(float(v), 2) for v in rb_lo], "max": [round(float(v), 2) for v in rb_hi]},
        })
    out = os.path.join(common.out_root(), NAME + ".placements.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump({
            "asset": NAME,
            "axes": "world studs: x east, y up, z south",
            "note": "FBX is authored in world space; place the whole Model at the map origin. The kit sits 1 stud low "
                    "so streamed Terrain covers it.",
            "pieces": placements,
        }, f, indent=1)
    print("[proxy] placements %s" % out)

    closeups = []
    for label, wx, wz, dist in (("havenhead", 1600, 665, 1200), ("skerry", 1800, 1900, 1000), ("westgate", -1850, -150, 1200)):
        comp = min(comps, key=lambda c: (max(c["i0"] * meta["cell"] + meta["originX"] - wx, 0, wx - (c["i1"] * meta["cell"] + meta["originX"])) ** 2
                                        + max(c["j0"] * meta["cell"] + meta["originZ"] - wz, 0, wz - (c["j1"] * meta["cell"] + meta["originZ"])) ** 2))
        at = nearest_land(comp, meta, wx, wz)
        if at is None:
            continue
        j, i = at
        closeups.append({"name": label,
                         "target": [round(-(meta["originX"] + meta["cell"] * i), 1),
                                    round(meta["originZ"] + meta["cell"] * j, 1),
                                    round(float(h[j, i]) - G.SINK, 1)],
                         "dist": dist, "az": 35.0, "el": 18.0})

    meshes = []
    for p in pieces:
        meshes += [{"object": p["object"], "set": SET}, {"object": p["hp"]}]

    tris0 = sum(G.tris(p["object"]) for p in pieces)
    print("[proxy] %d pieces, %d LOD0 triangles, %.1f x %.1f x %.1f studs" % (len(pieces), tris0, *dims))
    return {
        "name": NAME,
        "budget": "rock",
        "tier": "background",
        "dims_m": tuple(round(float(d) / common.STUDS_PER_METRE, 2) for d in dims),
        "origin": "free",
        "sets": [{"name": TEX, "set": SET, "size": ATLAS, "wet": False, "wear": False, "roughness": 0.9, "metal": 0.0}],
        "bake_size": ATLAS,
        "bake_samples": 8,
        "meshes": meshes,
        "attachments": [],
        "closeups": closeups,
        "waivers": {
            "texel density": "far proxy for islands 3 to 5 km across: one 2048 baked colour set, 05 5.3 tiers do not apply at this scale",
            "LOD UV layout": "collapse decimation of a terrain shell moves UV area; every LOD samples the same atlas",
            "_COL proxy": "non-collidable far proxy; the streamed Terrain owns collision",
        },
        "tiling": False,
        "lod_symmetry": None,
    }
