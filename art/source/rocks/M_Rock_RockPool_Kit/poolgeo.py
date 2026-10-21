"""M_Rock_RockPool_Kit geometry (K1 rocks, docs/12 2.6): four low intertidal granite outcrops with a pool each.

Form: a polar surface around the pool centre - a knuckled ridge ring, the bowl inside it (dished floor, plunging
walls) and a wave-cut outer slope that meets the ground plane at z = 0, closed by a bottom cap (hidden in the
terrain, like the K1 scans' undersides). Cornish granite jointing is displaced along Z: macro erosion, sub-horizontal
sheet partings, two near-vertical cross-joint sets, voronoi block relief and grain, sea-smoothed in the wet band,
with one spillway notch per ridge and a few knuckle peaks. The pool's water is a flat fan whose boundary follows the
displaced rim (r_water(theta)), tucked 0.10 studs under the rock lip, so the decimated LOD0 never shows a gap.

The rock pipeline is K1's: the HP is a displaced surface, LOD0 is a collapse decimation of it, the Granite set is
graded from the K1 CC0 scans (a projector skin of scan blocks, pooltex.py) and the zonation is compose_maps.py.

Units: studs (1 m = 3 studs). Deterministic: random.Random(seed) plus position-based mathutils.noise.
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils import noise as mnoise

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
LIB = os.path.join(REPO, "tools/blender")
for p in (LIB, HERE):
    if p not in sys.path:
        sys.path.insert(0, p)
import versions  # noqa: E402

KIT_WORK = os.path.join(REPO, "build/k1/work/")
PIECES = ("M_Rock_Boulder_04", "M_Rock_Boulder_05", "M_Rock_Ledge_03", "M_Rock_Cliff_04", "M_Rock_Boulder_01")

# variant table: the four outcrops. rp = pool radius (studs, to the bowl edge), kR = outer radius / pool radius,
# wl_frac = pool water level as a share of the height, depth = water depth (studs), spill = (theta, strength) of the
# spillway notch, knuck = (theta, sigma, height) peaks on the ridge, tris = LOD0 budget (docs/12: 3,000 to 6,000).
VARIANTS = [
    dict(nn="01", seed=1101, size_m=(2.6, 2.4, 0.85), rp=1.32, kR=3.05, wl_frac=0.34, depth=0.50,
         spill=(2.35, 0.62), knuck=((0.85, 0.55, 0.62), (4.30, 0.42, 0.40)),
         spurs=((0.55, 0.42, 0.80, 0.13, 0.30), (3.90, 0.35, 0.74, 0.14, 0.22)),
         nubs=((1.35, 0.22, 0.85, 0.22), (5.05, 0.18, 0.70, 0.14)),
         tris=3400, n_th=200, n_r=104),
    dict(nn="02", seed=1207, size_m=(3.4, 3.0, 1.05), rp=1.72, kR=3.00, wl_frac=0.32, depth=0.70,
         spill=(0.72, 0.55), knuck=((2.35, 0.50, 0.70), (5.55, 0.36, 0.34)),
         spurs=((1.60, 0.40, 0.78, 0.16, 0.28), (4.60, 0.30, 0.70, 0.12, 0.20), (3.35, 0.24, 0.86, 0.10, 0.16)),
         nubs=((3.85, 0.20, 0.90, 0.26), (1.05, 0.16, 0.62, 0.15)),
         tris=3600, n_th=216, n_r=108),
    dict(nn="03", seed=1319, size_m=(4.2, 3.6, 1.35), rp=2.18, kR=2.95, wl_frac=0.30, depth=0.92,
         spill=(4.55, 0.60), knuck=((1.30, 0.60, 0.78), (3.55, 0.40, 0.46), (5.90, 0.30, 0.32)),
         spurs=((2.60, 0.45, 0.82, 0.17, 0.34), (5.40, 0.34, 0.72, 0.13, 0.24), (0.35, 0.26, 0.88, 0.11, 0.18)),
         nubs=((2.05, 0.20, 0.92, 0.30), (5.85, 0.17, 0.66, 0.18), (3.40, 0.14, 0.75, 0.12)),
         tris=3800, n_th=232, n_r=114),
    dict(nn="04", seed=1423, size_m=(3.0, 3.2, 0.95), rp=1.95, kR=2.55, wl_frac=0.32, depth=0.55,
         spill=(1.55, 0.50), knuck=((3.05, 0.45, 0.70), (5.20, 0.35, 0.46)),
         spurs=((0.90, 0.38, 0.80, 0.15, 0.26), (3.80, 0.34, 0.74, 0.14, 0.22)),
         nubs=((2.55, 0.20, 0.88, 0.24), (0.35, 0.15, 0.70, 0.14)),
         tris=3400, n_th=224, n_r=110),
]


def variant(nn):
    for V in VARIANTS:
        if V["nn"] == nn:
            return V
    raise KeyError(nn)


def v_name(V):
    return "M_Rock_RockPool_" + V["nn"]


def w_name(V):
    return "M_Rock_RockPool_Water_" + V["nn"]


# ---------------------------------------------------------------- numeric helpers

def ss(e0, e1, x):
    """Smoothstep (scalar or numpy)."""
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0) if e1 != e0 else (x >= e0) * 1.0
    return t * t * (3.0 - 2.0 * t)


def harm(kmax, rnd, decay=0.8, lo=0.6, hi=1.0):
    return [(rnd.uniform(lo, hi) / (k ** decay), rnd.uniform(0.0, 2.0 * math.pi)) for k in range(1, kmax + 1)]


def ev(th, hs, norm=True):
    """Cosine harmonic series at th (arrays or scalars), normalised to about -1..1."""
    s = sum(a * np.cos(k * th + p) for k, (a, p) in enumerate(hs, start=1))
    return s / sum(a for a, _ in hs) if norm else s


def adiff(a, b):
    return np.abs((a - b + math.pi) % (2.0 * math.pi) - math.pi)


def fbm(p, octaves=3, off=Vector((0.0, 0.0, 0.0)), lac=2.03, gain=0.5):
    """Summed Perlin (mathutils.noise), normalised to about -1..1."""
    q = p + off
    s, amp, tot = 0.0, 1.0, 0.0
    for _ in range(octaves):
        s += amp * mnoise.noise(q)
        tot += amp
        amp *= gain
        q = q * lac
    return s / tot


def new_object(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def clean(ob, triangulate=False):
    """Drop loose verts / edges and degenerate faces; keeps the surface manifold."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    if triangulate:
        bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def close_holes(ob):
    """Fill any boundary loop a collapse decimation left (a _COL must be closed)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    open_edges = [e for e in bm.edges if len(e.link_faces) == 1]
    if open_edges:
        bmesh.ops.holes_fill(bm, edges=open_edges, sides=0)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(ob.data)
    bm.free()


def recalc(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


# ---------------------------------------------------------------- the outcrop form

def grid(V, n_th=None, n_r=None):
    """The polar grid around the pool centre: (th, r, x, y, z, R_out, rim, wl) before displacement."""
    n_th = n_th or V["n_th"]
    n_r = n_r or V["n_r"]
    rnd = random.Random(V["seed"])
    hs = {k: harm(n, rnd) for k, n in (("R1", 3), ("R2", 7), ("P", 4), ("Rim", 5), ("Z", 6))}
    th = np.linspace(0.0, 2.0 * math.pi, n_th, endpoint=False)[:, None]
    j = np.linspace(0.0, 1.0, n_r)[None, :]
    H = V["size_m"][2] * 3.0
    wl = V["wl_frac"] * H
    free = max(H - wl, 0.5)
    R_pool = V["rp"] * (1.0 + 0.30 * ev(th, hs["P"]))
    R_out = V["rp"] * V["kR"] * (1.0 + 0.28 * ev(th, hs["R1"]) + 0.12 * ev(th, hs["R2"]))
    rim = R_pool * (1.45 + 0.42 * ev(th, hs["Rim"]))
    zr = wl + free * (0.34 + 0.36 * (0.5 + 0.5 * ev(th, hs["Z"])))
    for (t0, sig, hgt) in V["knuck"]:
        zr = zr + free * hgt * np.exp(-0.5 * (adiff(th, t0) / sig) ** 2)
    zr = zr - free * V["spill"][1] * np.exp(-0.5 * (adiff(th, V["spill"][0]) / 0.30) ** 2)
    zr = wl + np.maximum(zr - wl, 0.10)                      # no matter what, the ridge holds the pool
    r = R_out * j
    x = r * np.cos(th)
    y = r * np.sin(th)
    u = np.clip(r / np.maximum(rim, 1e-6), 0.0, 1.0)
    z_in = (wl - V["depth"]) + 0.06 * u ** 2 + (zr - (wl - V["depth"])) * u ** 2.2
    t = np.clip((r - rim) / np.maximum(R_out - rim, 1e-6), 0.0, 1.0)
    prof = (1.0 - t ** 1.7) ** 1.25                                   # wave-cut platform: flat shoulder, steep outer edge
    prof = prof - 0.22 * np.exp(-0.5 * ((t - 0.52) / 0.13) ** 2)     # terrace step
    prof = prof - 0.09 * np.exp(-0.5 * ((t - 0.83) / 0.09) ** 2)     # low notch above the base
    z_out = zr * np.maximum(prof, 0.0) * ss(1.0, 0.955, r / R_out) * ss(1.0, 0.985, r / R_out)
    q = r / np.maximum(R_out, 1e-6)
    for (t0, sig, qc, wq, hgt) in V.get("spurs", ()):                 # ridges running out of the ring: no ring plan
        z_out = z_out * (1.0 + 1.35 * hgt * np.exp(-0.5 * (adiff(th, t0) / sig) ** 2)
                         * np.exp(-0.5 * ((q - qc) / wq) ** 2) * ss(0.0, 0.26, t))
    z = np.where(r < rim, z_in, z_out).astype(np.float64)
    for (t0, sig, ru, poke) in V.get("nubs", ()):                     # nubs breaking the pool surface
        m = np.exp(-0.5 * (adiff(th, t0) / sig) ** 2) * np.exp(-0.5 * ((r - ru) / 0.24) ** 2)
        z = z + np.where(r < rim, np.maximum(0.0, wl + poke - z) * m, 0.0)
    return dict(V=V, th=th, r=r, x=x, y=y, z=z, R_out=R_out, rim=rim, zr=zr, wl=wl, H=H,
                n_th=n_th, n_r=n_r, hs=hs, R_pool=R_pool)


def displace(g):
    """Cornish granite jointing displaced along Z (only jointed rock, no mud cracks), sea-smoothed in the wet band."""
    V, z, x, y, wl = g["V"], g["z"], g["x"], g["y"], g["wl"]
    knife = ss(wl + 1.15, wl + 0.10, z)                       # 1 in the wet band: joints worn down by the sea
    bowl = (g["r"] < g["rim"]) * 1.0
    seed = V["seed"] * 0.37
    off_m = Vector((seed + 11.3, 4.1, 7.7))
    off_f = Vector((seed + 3.9, 8.8, 1.2))
    off_c = Vector((seed + 6.2, 2.4, 9.1))
    off_a = Vector((seed + 1.7, 12.6, 3.3))
    off_b = Vector((seed + 9.4, 5.5, 11.8))
    ca, sa = math.cos(0.55), math.sin(0.55)
    cb, sb = math.cos(2.05), math.sin(2.05)
    cellk = 1.0 / 1.30                                        # voronoi cross joints: ~1.3-stud blocks
    out = np.empty_like(z)
    for i in range(g["n_th"]):
        for j in range(g["n_r"]):
            p = Vector((x[i, j], y[i, j], z[i, j]))
            macro = 0.42 * fbm(p * 0.145, 3, off_m)
            grain = 0.07 * fbm(p * 0.85, 2, off_f)
            c = z[i, j] * 1.35 + 0.60 * fbm(p * 0.30, 2, off_c)      # sub-horizontal sheet partings
            sheet = -0.26 * (1.0 - ss(0.0, 0.075, abs(c - round(c))))
            a = (x[i, j] * ca + y[i, j] * sa) * 0.52 + 0.55 * fbm(p * 0.33, 2, off_a)
            b = (x[i, j] * cb + y[i, j] * sb) * 0.48 + 0.55 * fbm(p * 0.30, 2, off_b)
            joint = -0.20 * max(1.0 - ss(0.0, 0.09, abs(a - round(a))), 1.0 - ss(0.0, 0.075, abs(b - round(b))))
            q = Vector((x[i, j] * cellk, y[i, j] * cellk, z[i, j] * cellk / 1.7))
            dist = mnoise.voronoi(q)[0]
            cell = 0.20 * (mnoise.cell(q) - 0.5) - 0.14 * (1.0 - ss(0.0, 0.16, max(dist[1] - dist[0], 0.0)))
            d = (macro + grain + sheet + joint + cell) * (1.0 - 0.40 * knife[i, j])
            d *= (0.45 + 0.55 * (1.0 - bowl[i, j]))               # the pool floor stays smooth: still water
            out[i, j] = d
    z = z + out * ss(1.0, 0.90, g["r"] / g["R_out"])              # no displacement at the ground contact
    limit = wl - 0.06
    deep = (g["r"] < 0.88 * g["rim"]) * (z > limit)               # the bowl holds water: soft-clamp its floor
    z = np.where(deep, limit + 0.35 * (z - limit), z)
    z = np.maximum(z, 0.0)
    z[:, -1] = 0.0                                                # the ground ring is exactly at z = 0
    g["z"] = z
    return g


def surface_mesh(g, name):
    """The closed outcrop surface: the polar grid plus the bottom cap (a fan at z = 0, inside the terrain)."""
    n_th, n_r = g["n_th"], g["n_r"]
    verts = [(float(g["x"][i, j]), float(g["y"][i, j]), float(g["z"][i, j])) for i in range(n_th) for j in range(n_r)]
    verts.append((0.0, 0.0, 0.0))
    cap = len(verts) - 1
    faces = []
    for i in range(n_th):
        i2 = (i + 1) % n_th
        for j in range(n_r - 1):
            faces.append((i * n_r + j, i * n_r + j + 1, i2 * n_r + j + 1, i2 * n_r + j))
        faces.append((i * n_r + n_r - 1, i2 * n_r + n_r - 1, cap))
    ob = new_object(name, verts, faces)
    recalc(ob)
    return ob


def water_radius(g, tuck=0.08, span=1.15):
    """r_water(theta): the pool shoreline - the radius where the surface climbs out of the water on the way out from
    the pool centre. The sheet can never cover rock that stands above the water level (no floating plates)."""
    z, r, wl = g["z"], g["r"], g["wl"]
    below = (z < wl) & (r < g["rim"] * span)
    idx = below.argmin(axis=1)                               # first texel above water going out = the shoreline
    out = np.full(g["n_th"], 0.35, np.float64)
    for i in range(g["n_th"]):
        k = int(idx[i])
        if k == 0:
            continue                                         # a dry column (a hump in the basin)
        k = min(k, g["n_r"] - 1)
        z0, z1 = z[i, k - 1], z[i, k]
        f = 0.0 if z1 == z0 else (wl - z0) / (z1 - z0)
        out[i] = r[i, k - 1] + np.clip(f, 0.0, 1.0) * (r[i, k] - r[i, k - 1])
    k3 = np.ones(3) / 3.0
    sm = np.convolve(np.concatenate([out[-1:], out, out[:1]]), k3, mode="same")[1:-1]
    out = np.minimum(out, sm)                                # smoothing may only pull the sheet in
    out = np.minimum(out, 0.88 * g["R_out"][:, 0])
    return np.maximum(out + tuck, 0.35)


def water_mesh(g, r_water, name, n_th_w=48, drop=0.035):
    """A flat fan at the water level, boundary at r_water(theta), tucked under the rock lip."""
    th = np.linspace(0.0, 2.0 * math.pi, n_th_w, endpoint=False)
    rw = np.interp(th, g["th"][:, 0], r_water, period=2.0 * math.pi)
    z = g["wl"] - drop
    rmax = float(rw.max())
    verts = []
    for f in (1.0, 0.52):
        for i in range(n_th_w):
            t = th[i]
            verts.append((float(np.cos(t) * rw[i] * f), float(np.sin(t) * rw[i] * f), float(z)))
    verts.append((0.0, 0.0, float(z)))
    cap = len(verts) - 1
    faces = []
    for i in range(n_th_w):
        i2 = (i + 1) % n_th_w
        faces.append((i, i2, n_th_w + i2, n_th_w + i))
        faces.append((n_th_w + i, n_th_w + i2, cap))
    ob = new_object(name, verts, faces)
    recalc(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    if sum(f.normal.z for f in bm.faces) < 0.0:                # the water faces up, always
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    uv = ob.data.uv_layers.new(name="UVMap")
    me = ob.data
    for poly in me.polygons:
        for li in poly.loop_indices:
            vx, vy, _ = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (0.5 + vx / (2.0 * rmax * 1.06), 0.5 + vy / (2.0 * rmax * 1.06))
    return ob, rmax


# ---------------------------------------------------------------- transforms and placement

def bbox(ob):
    co = np.empty(len(ob.data.vertices) * 3, np.float32)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return co.min(axis=0), co.max(axis=0)


def normalise(ob, dims):
    """Scale (per axis) and move the mesh so its bounding box is exactly dims (studs), base at z = 0, centred."""
    lo, hi = bbox(ob)
    scale = dims / np.maximum(hi - lo, 1e-6)
    off = (lo + hi) / 2.0
    off[2] = lo[2]
    apply_affine(ob, off, scale)
    return off, scale


def apply_affine(ob, off, scale):
    co = np.empty(len(ob.data.vertices) * 3, np.float32)
    ob.data.vertices.foreach_get("co", co)
    co = ((co.reshape(-1, 3) - off) * scale).reshape(-1)
    ob.data.vertices.foreach_set("co", co)
    ob.data.update()


def mirror_x(ob):
    """Mirror across X (variety without a new seed: a different rock, still one surface)."""
    co = np.empty(len(ob.data.vertices) * 3, np.float32)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    co[:, 0] = -co[:, 0]
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()
    recalc(ob)


def pool_data_attr(ob, cx, cy, wl, r_water_local, th_arr):
    """Vertex attribute on the LOD0: R = wet pool zone flag, G = distance to the pool shoreline (studs, +-2)."""
    me = ob.data
    attr = me.color_attributes.new(name="PoolData", type="FLOAT_COLOR", domain="POINT")
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    dx, dy = co[:, 0] - cx, co[:, 1] - cy
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    rw = np.interp(th, th_arr, r_water_local, period=2.0 * math.pi)
    d = r - rw
    flag = ((d < 0.06) & (co[:, 2] < wl + 0.30)).astype(np.float32)
    col = np.zeros((len(co), 4), np.float32)
    col[:, 0] = flag
    col[:, 1] = np.clip(d / 2.0, -1.0, 1.0) * 0.5 + 0.5
    col[:, 3] = 1.0
    attr.data.foreach_set("color", col.ravel())
    return attr


def pool_flag_obj(ob):
    """A material that emits the PoolData attribute (R flag, G shoreline distance) so pooltex can bake it."""
    mat = bpy.data.materials.new("_pool_attr")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "PoolData"
    nt.links.new(at.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs["Output"], out.inputs["Surface"])
    return mat


# ---------------------------------------------------------------- the scan projector

def mesh_arrays(me):
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    tri = np.empty(n * 3, np.int32)
    me.loop_triangles.foreach_get("vertices", tri)
    loop_uv = np.empty(len(me.loops) * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", loop_uv)
    loops = np.empty(n * 3, np.int32)
    me.loop_triangles.foreach_get("loops", loops)
    return co.reshape(-1, 3), tri.reshape(-1, 3), loop_uv.reshape(-1, 2)[loops].reshape(-1, 3, 2)


def load_pieces(max_tris=800):
    """The K1 CC0 scan LPs as placement primitives: centred verts, principal axes (flattest first), semi-extents."""
    out = []
    for name in PIECES:
        path = KIT_WORK + name + "_lp.blend"
        if not os.path.isfile(path):
            continue
        with bpy.data.libraries.load(path) as (src, dst):
            dst.meshes = list(src.meshes)
        me = dst.meshes[0]
        tmp = new_object("_piece", [], [])
        tmp.data = me
        versions.decimate(tmp, max_tris)
        co, tri, uvs = mesh_arrays(tmp.data)
        a, b, c = co[tri[:, 0]], co[tri[:, 1]], co[tri[:, 2]]
        if np.einsum("ij,ij->i", a, np.cross(b, c)).sum() < 0.0:
            tri = tri[:, ::-1].copy()
        co = co - (co.min(0) + co.max(0)) / 2.0
        w, v = np.linalg.eigh(np.cov(co.T))
        ax = v[:, ::-1]
        ext = np.abs(co @ ax).max(0)
        out.append({"co": (co @ ax).astype(np.float32), "tri": tri, "uv": uvs, "ext": ext})
        leftover = tmp.data
        bpy.data.objects.remove(tmp, do_unlink=True)
        for m in (leftover, me):
            try:
                if m.users == 0:
                    bpy.data.meshes.remove(m)
            except ReferenceError:
                pass
    return out


def unit(rnd):
    v = np.array([rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1)], np.float32)
    return v / max(float(np.linalg.norm(v)), 1e-6)


def assemble_projector(surface, V, spacing=1.35, seed=None, lift=0.05):
    """Skin the outcrop with scanned granite blocks (each flattest-side-on the surface, a little proud): the mesh the
    scan's diffuse and shading normal are baked through, so the LOD0 keeps real Cornish granite detail."""
    import bmesh as _bm
    rnd = random.Random(V["seed"] + 77 if seed is None else seed)
    pieces = load_pieces()
    bm = _bm.new()
    bm.from_mesh(surface.data)
    bm.normal_update()
    co = np.array([tuple(v.co) for v in bm.verts], np.float32)
    no = np.array([tuple(v.normal) for v in bm.verts], np.float32)
    bm.free()
    seen = {}
    for i in range(len(co)):
        key = tuple(np.floor(co[i] / spacing).astype(int))
        seen.setdefault(key, i)
    keep = np.array(sorted(seen.values()))
    Vs, Ts, Us = [], [], []
    base = 0
    for p, n in zip(co[keep], no[keep]):
        ln = float(np.linalg.norm(n))
        if ln < 0.5:
            continue
        n = n / ln
        pc = pieces[rnd.randrange(len(pieces))]
        t = np.cross(n, unit(rnd))
        t /= max(float(np.linalg.norm(t)), 1e-6)
        R = np.stack([t, np.cross(n, t), n], 1)
        mid = rnd.uniform(1.7, 2.9) * (0.75 if p[2] < 0.5 else 1.0)
        s = mid / max(pc["ext"][1], 1e-6)
        s = min(s, 0.9 / max(pc["ext"][2], 1e-6))
        half = pc["ext"][2] * s
        prot = min(rnd.uniform(0.12, 0.30), 0.5 * half)
        X = (pc["co"] * s) @ R.T + p + n * (prot - half)
        Vs.append(X.astype(np.float32))
        Ts.append(pc["tri"] + base)
        Us.append(pc["uv"])
        base += len(X)
    ob = new_object("_projector", np.concatenate(Vs).tolist(), np.concatenate(Ts).tolist())
    uvl = ob.data.uv_layers.new(name="UVMap")
    uvl.data.foreach_set("uv", np.concatenate(Us).reshape(-1))
    ob.data.update()
    bm = _bm.new()
    bm.from_mesh(ob.data)
    for _ in range(2):                                       # drop the block facets: the bake should read their maps
        _bm.ops.smooth_vert(bm, verts=bm.verts, factor=0.4, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        v.co = v.co + v.normal * lift
    bm.to_mesh(ob.data)
    bm.free()
    return ob
