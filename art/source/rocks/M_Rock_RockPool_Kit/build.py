"""M_Rock_RockPool_Kit (K1, docs/12 2.6): four low intertidal granite outcrops with a rock pool each, one Granite
atlas (T_Pool_Granite at 4096: 4 variants + their water sheets in one set, the docs/12 row's "1 atlas").

Geometry is poolgeo.py (a polar form per variant: ridge ring with knuckle peaks and a spillway, the pool bowl, a
wave-cut outer slope, granite jointing displaced and sea-smoothed in the wet band, a decimated LOD0 and a closed
_COL); each rock gets a flat water sheet whose boundary follows the displaced pool shoreline, an `ATT_Pool_NN`
empty at the water surface centre and a baked "PoolData" vertex attribute (wet pool zone + distance to the pool
shoreline) that pooltex.py bakes into the atlas for the zonation in compose_maps.py.

The four variants sit as one rock-pool group (a 2 x 2 cluster, gaps of 1.2 studs); dims_m is the group, each rock is
2.6 to 4.2 m across per the docs/12 row. Build: run.py --steps build,lod,validate,export,turntable, then pooltex.py
(heavy slot) and compose_maps.py (system python3), then run.py again so validate sees the maps.
"""
import json
import math
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
import poolgeo as G  # noqa: E402
import texgen  # noqa: E402
import uvlayout  # noqa: E402
import versions  # noqa: E402

NAME = "M_Rock_RockPool_Kit"
TEX = "Pool"                 # T_Pool_Granite_*
SET = "Granite"
CELL = 2048                  # each variant's cell in the atlas (2 x 2 cells)
ATLAS = 4096
GAP = 1.2                    # studs between the outcrops in the group
WATER_TARGET = 70.0          # px per stud the water sheets aim for (standard tier passes at 46)
ROCK_TARGET = 84.0           # px per stud the rocks aim for
MARGIN = 76                  # px gutter inside a cell (>= texgen.margin_px(ATLAS) = 64)


def duplicate(src, name):
    ob = src.copy()
    ob.data = src.data.copy()
    ob.name = ob.data.name = name
    bpy.context.scene.collection.objects.link(ob)
    return ob


def translate(ob, dx, dy):
    co = np.empty(len(ob.data.vertices) * 3, np.float32)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    co[:, 0] += dx
    co[:, 1] += dy
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()


def unwrap(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.002)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=0.002, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def uv_array(ob, setter=None):
    me = ob.data if isinstance(ob, bpy.types.Object) else ob
    uv = me.uv_layers.active.data
    if setter is None:
        arr = np.empty(len(uv) * 2, np.float32)
        uv.foreach_get("uv", arr)
        return arr.reshape(-1, 2)
    uv.foreach_set("uv", setter.ravel())


def fit_rect(me, rect):
    """Scales the packed 0..1 UVs (uniform, aspect kept) to sit centred inside rect (cell px, y up)."""
    arr = uv_array(me)
    lo, hi = arr.min(0), arr.max(0)
    rw = (rect[2] - rect[0]) / float(CELL)
    rh = (rect[3] - rect[1]) / float(CELL)
    s = min(rw / max(hi[0] - lo[0], 1e-6), rh / max(hi[1] - lo[1], 1e-6))
    cx, cy = (lo[0] + hi[0]) / 2.0, (lo[1] + hi[1]) / 2.0
    out = np.empty_like(arr)
    out[:, 0] = (rect[0] / float(CELL) + rw / 2.0) + (arr[:, 0] - cx) * s
    out[:, 1] = (rect[1] / float(CELL) + rh / 2.0) + (arr[:, 1] - cy) * s
    uv_array(me, out)


def to_atlas(me, cell_col, cell_row):
    arr = uv_array(me)
    arr = arr * (CELL / float(ATLAS)) + np.array([cell_col * CELL / float(ATLAS), cell_row * CELL / float(ATLAS)], np.float32)
    uv_array(me, arr)


def area3d(mesh):
    return sum(p.area for p in mesh.polygons)


def material(name, rgb, rough, metal=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return mat


def build():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith("M_Rock_RockPool") or o.name.startswith("ATT_Pool"):
            bpy.data.objects.remove(o, do_unlink=True)

    info = []
    for V in G.VARIANTS:
        dims = np.array(V["size_m"], np.float32) * 3.0
        g = G.grid(V)
        G.displace(g)
        hp = G.surface_mesh(g, G.v_name(V) + "_HP")
        lod0 = duplicate(hp, G.v_name(V) + "_LOD0")
        G.clean(lod0, triangulate=True)
        versions.decimate(lod0, V["tris"])
        G.clean(lod0)
        G.recalc(lod0)
        for p in lod0.data.polygons:
            p.use_smooth = True
        gc = G.grid(V, 56, 34)
        col = G.surface_mesh(gc, G.v_name(V) + "_COL")
        G.clean(col, triangulate=True)
        versions.decimate(col, 420)
        G.clean(col)
        G.close_holes(col)
        G.recalc(col)
        rw = G.water_radius(g)
        water, rmax_pre = G.water_mesh(g, rw, G.w_name(V) + "_LOD0")

        off, scale = G.normalise(lod0, dims)
        for o in (hp, col, water):
            G.apply_affine(o, off, scale)
        pcx = (0.0 - off[0]) * scale[0]
        pcy = (0.0 - off[1]) * scale[1]
        wl = g["wl"] * scale[2]

        # distance to the pool shoreline in the placed (post-normalise) frame, for the PoolData attribute
        th = g["th"][:, 0]
        rpx = rw * np.cos(th) * scale[0]
        rpy = rw * np.sin(th) * scale[1]
        th_post = np.arctan2(rpy, rpx)
        r_post = np.hypot(rpx, rpy)
        order = np.argsort(th_post)
        th_u = np.linspace(-math.pi, math.pi, 257)
        r_u = np.interp(th_u, np.concatenate([th_post[order] - 2 * math.pi, th_post[order], th_post[order] + 2 * math.pi]),
                        np.concatenate([r_post[order], r_post[order], r_post[order]]))
        G.pool_data_attr(lod0, float(pcx), float(pcy), float(wl), r_u, th_u)

        # atlas cell + rects: the water square fitted to its own density, the rock takes the rest of the 2048 cell
        area_r = area3d(lod0.data)
        area_water = area3d(water.data)
        w0 = uvlayout.mesh_stats(water.data)                  # the disc's own uv area, before the fit
        arr0 = uv_array(water.data)
        lo0, hi0 = arr0.min(0), arr0.max(0)
        cen0 = (lo0 + hi0) / 2.0
        s_w = int(round(WATER_TARGET * math.sqrt(max(area_water, 1.0))))
        s_w = int(np.clip(s_w, int(0.14 * CELL), int(0.34 * CELL)))
        dens = 0.0
        sfit = 1.0
        water_rect = (0, 0, 1, 1)
        for _ in range(7):                                    # the square size that hits the water's texel target
            wx0 = (CELL - s_w) // 2
            water_rect = (wx0, MARGIN, wx0 + s_w, MARGIN + s_w)
            su = max(s_w - 16, 8) / float(CELL)
            sfit = min(su / max(hi0[0] - lo0[0], 1e-6), su / max(hi0[1] - lo0[1], 1e-6))
            dens = texgen.texel_density_px_per_stud(w0["uv_area"] * sfit ** 2 * (CELL / float(ATLAS)) ** 2,
                                                    area_water, ATLAS)
            if abs(dens - WATER_TARGET) / WATER_TARGET < 0.03:
                break
            s_w = int(np.clip(round(s_w * WATER_TARGET / max(dens, 1e-3)), int(0.14 * CELL), int(0.34 * CELL)))
        cuv = np.array([(water_rect[0] + water_rect[2]) / 2.0 / CELL,
                        (water_rect[1] + water_rect[3]) / 2.0 / CELL], np.float32)
        uv_array(water.data, cuv + (arr0 - cen0) * sfit)
        centre_uv = cuv + (0.5 - cen0) * sfit                 # the pool centre (its pre-fit uv is 0.5, 0.5)
        per_stud = sfit / (2.0 * rmax_pre * 1.06)             # water-square uv per pre-transform stud
        th64 = np.linspace(-math.pi, math.pi, 65)[:-1]
        r64 = np.interp(th64, g["th"][:, 0], rw, period=2.0 * math.pi)
        water_uv = {"centre": [float(centre_uv[0]), float(centre_uv[1])], "per_stud": float(per_stud),
                    "r": [round(float(v), 4) for v in r64]}
        rock_rect = (MARGIN, MARGIN + s_w + MARGIN, CELL - MARGIN, CELL - MARGIN)
        unwrap(lod0)
        fit_rect(lod0, rock_rect)

        rock_uv = uvlayout.mesh_stats(lod0.data)
        scale_uv = (CELL / float(ATLAS)) ** 2                 # above the atlas conversion: cell uv -> atlas uv
        dens = texgen.texel_density_px_per_stud(rock_uv["uv_area"] * scale_uv, area_r, ATLAS)
        wdens = dens
        print("[pool] %s tris %d, area %.0f studs2, uv fill %.2f, rock %.1f px/stud, water %.1f px/stud (area %.1f)"
              % (G.v_name(V), G.tri_count(lod0), area_r,
                 rock_uv["uv_area"] / max((rock_rect[2] - rock_rect[0]) * (rock_rect[3] - rock_rect[1]) / float(CELL * CELL), 1e-6),
                 dens, wdens, area_water))

        gm = material("MI_Pool_Granite", (0.25, 0.24, 0.23), 0.8)
        wm = material("MI_Pool_Water", (0.055, 0.10, 0.105), 0.10)
        for o, m in ((lod0, gm), (col, gm), (water, wm)):
            o.data.materials.clear()
            o.data.materials.append(m)

        rmax = max(math.hypot((v.co[0] - pcx), (v.co[1] - pcy)) for v in water.data.vertices)
        b = G.bbox(hp)
        info.append(dict(V=V, hp=hp, lod0=lod0, col=col, water=water, dims=dims, pcx=float(pcx), pcy=float(pcy),
                         wl=float(wl), rmax=float(rmax), area3d=float(area_r), area_water=float(area_water),
                         rock_rect=rock_rect, water_rect=water_rect, col_i=None, row_i=None, water_uv=water_uv,
                         lo=[float(b[0][0]), float(b[0][1]), float(b[0][2])],
                         span=[float(b[1][0] - b[0][0]), float(b[1][1] - b[0][1]), float(b[1][2] - b[0][2])]))

    # ---- the group: a 2 x 2 cluster, gaps of GAP studs (each variant sits centred in its cell)
    cells = ((0, 1), (1, 1), (0, 0), (1, 0))          # (col, row) per variant: 01 top-left, 02 top-right, ...
    col_w = [max(info[i]["dims"][0] for i in range(4) if cells[i][0] == c) for c in (0, 1)]
    row_d = [max(info[i]["dims"][1] for i in range(4) if cells[i][1] == r) for r in (0, 1)]
    cx = [-(col_w[0] / 2.0 + GAP / 2.0), col_w[1] / 2.0 + GAP / 2.0]
    cy = [-(row_d[0] / 2.0 + GAP / 2.0), row_d[1] / 2.0 + GAP / 2.0]
    for i, it in enumerate(info):
        it["col_i"], it["row_i"] = cells[i]
        it["dx"], it["dy"] = cx[cells[i][0]], cy[cells[i][1]]
        it["pcx"] += it["dx"]
        it["pcy"] += it["dy"]
        for o in (it["hp"], it["lod0"], it["col"], it["water"]):
            translate(o, it["dx"], it["dy"])
    lo = np.array([1e9] * 3, np.float64)
    hi = np.array([-1e9] * 3, np.float64)
    for it in info:
        b = G.bbox(it["lod0"])
        lo = np.minimum(lo, b[0])
        hi = np.maximum(hi, b[1])
    shift = np.array([-(lo[0] + hi[0]) / 2.0, -(lo[1] + hi[1]) / 2.0, 0.0], np.float64)
    for it in info:
        for o in (it["hp"], it["lod0"], it["col"], it["water"]):
            translate(o, float(shift[0]), float(shift[1]))
        it["pcx"] += shift[0]
        it["pcy"] += shift[1]
    dims = hi - lo
    print("[pool] group %.1f x %.1f x %.1f studs (%.2f x %.2f x %.2f m)"
          % (dims[0], dims[1], dims[2], dims[0] / 3.0, dims[1] / 3.0, dims[2] / 3.0))

    atts = []
    for it in info:
        att = bpy.data.objects.new("ATT_Pool_" + it["V"]["nn"], None)
        att.empty_display_type = "PLAIN_AXES"
        att.location = (it["pcx"], it["pcy"], it["wl"])
        bpy.context.scene.collection.objects.link(att)
        atts.append(att)

    # ---- the atlas cells: 4 variants on one 4096 set, the two axes baked in atlas space
    for i, it in enumerate(info):
        to_atlas(it["lod0"].data, it["col_i"], it["row_i"])
        to_atlas(it["water"].data, it["col_i"], it["row_i"])

    meshes = []
    for it in info:
        meshes += [{"object": it["lod0"], "set": SET}, {"object": it["hp"]}, {"object": it["col"]},
                   {"object": it["water"], "set": SET}]

    pools = {"atlas": ATLAS, "cell": CELL, "margin": MARGIN, "variants": []}
    for it in info:
        pools["variants"].append(dict(
            name=G.v_name(it["V"]), nn=it["V"]["nn"],
            water=G.w_name(it["V"]), cell_col=it["col_i"], cell_row=it["row_i"],
            rock_rect=list(it["rock_rect"]), water_rect=list(it["water_rect"]), water_uv=it["water_uv"],
            lo=it["lo"], span=it["span"], centre=[it["pcx"], it["pcy"]], wl=it["wl"], rmax=it["rmax"],
            depth=it["V"]["depth"], dims=[float(d) for d in it["dims"]], seed=it["V"]["seed"]))
    with open(os.path.join(HERE, "pool.json"), "w") as f:
        json.dump(pools, f, indent=1)

    # close-ups: the four pools from outside the group, one shoreline and the spillway
    closeups = []
    for it in info:
        dxc, dyc = it["pcx"], it["pcy"]
        az = math.degrees(math.atan2(dxc, -dyc)) % 360.0
        closeups.append({"name": "pool_" + it["V"]["nn"], "target": [dxc, dyc, it["wl"] + 0.20],
                         "dist": 7.2, "az": round(az, 1), "el": 60.0})
    v1 = info[0]
    a1 = 0.0                                     # v01's shoreline on the +X side of its pool
    closeups.append({"name": "shore01", "target": [v1["pcx"] + 2.4 * math.cos(a1), v1["pcy"] + 2.4 * math.sin(a1), v1["wl"]],
                     "dist": 4.4, "az": round(math.degrees(math.atan2(math.cos(a1), -math.sin(a1))) % 360.0, 1), "el": 12.0})
    v3 = info[2]
    a3 = math.radians(v3["V"]["spill"][0])
    closeups.append({"name": "spill03", "target": [v3["pcx"] + 3.4 * math.cos(a3), v3["pcy"] + 3.4 * math.sin(a3), v3["wl"]],
                     "dist": 4.8, "az": round(math.degrees(math.atan2(math.cos(a3), -math.sin(a3))) % 360.0, 1), "el": 14.0})

    return {
        "name": NAME,
        "budget": "rock",
        "tier": "standard",
        "dims_m": tuple(round(float(d) / 3.0, 3) for d in dims),
        "size_note": "dims_m is the four-variant rock-pool group (a 2 x 2 cluster); each outcrop is 2.6 to 4.2 m "
                     "across, the docs/12 2.6 rock row",
        "origin": "base",
        "sets": [{"name": TEX, "set": SET, "size": ATLAS, "wet": True}],
        "meshes": meshes,
        "attachments": atts,
        "waivers": {
            "LOD UV layout": "collapse decimation of a rough outcrop redistributes UV area a little; every LOD "
                             "samples the same atlas cell and the maps are baked in 3D",
        },
        "tiling": False,
        "lod_symmetry": None,
        "closeups": closeups,
    }
