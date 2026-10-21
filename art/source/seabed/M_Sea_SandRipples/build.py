"""M_Sea_SandRipples (S2, docs/12 2.7): seabed sand-ripple decal kit for the harbour approaches.

Four low, thin patches of rippled sand that feather into the terrain, 2.0 to 6.4 m across:
  PatchA  a small 2.4 x 1.7 m train of gentle swells.
  PatchB  a medium 3.7 x 2.6 m field with a softer, muddier train.
  PatchC  the large 6.0 x 4.1 m sheet, the hero decal.
  PatchD  a 4.4 x 3.0 m patch carrying shell grit and a few pebbles in the troughs (ShellGrit and Pebbles
          are separate MeshParts so each gets its own albedo, packed into the same set).
The large bedform undulation (0.8 to 1.2 m swells, 1 to 2 cm high) is LOD0 geometry; the 11 to 16 cm sand
ripples and grain live in a dense _HP and reach the NOR map through the bake. Planar top UVs keep one texel
density across every piece. Origin: base, kit bbox centred on x = y = 0. No attachments: scenery decals.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
sys.path.insert(0, os.path.join(HERE, "../_S1a"))
import budgets  # noqa: E402
import common  # noqa: E402
import names  # noqa: E402
import versions  # noqa: E402
import wreckgeo as W  # noqa: E402
from wreckgeo import Buf  # noqa: E402

NAME = "M_Sea_SandRipples"
S = 3.0
SET = "Seabed"
rnd = random.Random(4093)

SAND = "MI_SandRipples_Sand"
SHELL = "MI_SandRipples_Shell"
STONE = "MI_SandRipples_Stone"

MATS = [(SAND, (0.360, 0.333, 0.275), 0.82),
        (SHELL, (0.640, 0.600, 0.505), 0.55),
        (STONE, (0.315, 0.298, 0.255), 0.62)]

PATCHES = [
    dict(key="PatchA", rx=1.20, ry=0.85, loc=(-2.00, -3.20), yaw=26.0, rings=11, seg=34,
         cell=(0.010, 0.310, 0.120, 0.336), h=0.048, amp=0.018, L1=0.86, L2=2.10,
         wav=0.125, phase=1.7, seed=3.1),
    dict(key="PatchB", rx=1.85, ry=1.30, loc=(2.90, 1.70), yaw=-17.0, rings=13, seg=44,
         cell=(0.010, 0.410, 0.360, 0.644), h=0.052, amp=0.021, L1=1.04, L2=2.60,
         wav=0.142, phase=4.2, seed=7.4),
    dict(key="PatchC", rx=3.00, ry=2.05, loc=(-2.40, 0.90), yaw=10.0, rings=16, seg=56,
         cell=(0.010, 0.490, 0.660, 0.990), h=0.058, amp=0.024, L1=1.18, L2=2.90,
         wav=0.118, phase=0.9, seed=11.2),
    dict(key="PatchD", rx=2.20, ry=1.50, loc=(2.90, -2.50), yaw=-7.0, rings=14, seg=46,
         cell=(0.430, 0.850, 0.360, 0.652), h=0.050, amp=0.020, L1=0.94, L2=2.35,
         wav=0.152, phase=2.8, seed=15.8),
]
SHELL_CELL = (0.870, 0.990, 0.480, 0.594)
PEBBLE_CELL = (0.870, 0.990, 0.610, 0.724)
WOBBLE = (0.090, 0.045, 0.022)
WOB_MAX = 1.0 + sum(WOBBLE)


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def wobble(th, p):
    return (1.0 + WOBBLE[0] * math.sin(3.0 * th + p["seed"])
            + WOBBLE[1] * math.sin(5.0 * th - p["seed"] * 1.7)
            + WOBBLE[2] * math.sin(9.0 * th + p["seed"] * 2.3)) / WOB_MAX


def surface(x, y, p, fine=False):
    """Height (m) of the patch above the seabed. The crown and the broad swell train fade to 0 at the rim."""
    rx, ry = p["rx"], p["ry"]
    r = math.hypot(x / rx, y / ry)
    if r > 1.25:
        return 0.0
    inner = smoothstep(1.0, 0.66, r)
    crown = p["h"] * max(0.0, 1.0 - r * r) ** 1.22
    a = p["yaw"] * math.pi / 180.0 + p["seed"] * 0.13
    ca, sa = math.cos(a), math.sin(a)
    s = x * ca + y * sa
    q = -x * sa + y * ca
    ph = p["phase"]
    sw = (math.sin(2.0 * math.pi * s / p["L1"] + ph)
          + 0.48 * math.sin(2.0 * math.pi * q / (p["L1"] * 2.3) + ph * 1.9)
          + 0.30 * math.sin(2.0 * math.pi * s / p["L2"] + ph * 1.3))
    h = crown + p["amp"] * sw * inner
    if fine:
        h += fine_detail(x, y, p) * smoothstep(1.0, 0.82, r)
    return max(0.0, h)


def fine_detail(x, y, p):
    """8 to 16 cm wind ripples and grain: the bake NOR detail, never in the LOD0 silhouette."""
    a = p["yaw"] * math.pi / 180.0 + 0.42
    ca, sa = math.cos(a), math.sin(a)
    s = x * ca + y * sa
    q = -x * sa + y * ca
    lam = p["wav"] * (0.92 + 0.16 * math.sin(q * 1.9 + p["seed"]))
    train = math.sin(2.0 * math.pi * s / lam + 0.55 * math.sin(q * 3.1 + p["seed"]))
    fork = 0.45 * math.sin(2.0 * math.pi * (s * 0.86 + q * 0.51) / (lam * 1.63) + p["seed"] * 2.0)
    patchy = 0.88 + 0.18 * math.sin(x * 0.83 - y * 0.57 + p["seed"])
    grain = noise.noise(Vector((x * 13.0 + p["seed"], y * 13.0, p["seed"] * 3.0)))
    return 0.0096 * patchy * train + 0.0032 * fork + 0.0006 * grain


def uv_of(x, y, p):
    x0, x1, y0, y1 = p["cell"]
    m = 0.004
    u = x0 + m + (x / (2.0 * p["rx"]) + 0.5) * (x1 - x0 - 2.0 * m)
    v = y0 + m + (y / (2.0 * p["ry"]) + 0.5) * (y1 - y0 - 2.0 * m)
    return (u, v)


def build_patch(p, rings, seg, fine):
    b = Buf()
    rows = []
    for k in range(1, rings + 1):
        t = k / float(rings)
        row = []
        for i in range(seg):
            th = 2.0 * math.pi * i / seg
            w = wobble(th, p)
            x, y = p["rx"] * t * w * math.cos(th), p["ry"] * t * w * math.sin(th)
            z = surface(x, y, p, fine)
            uv = uv_of(x, y, p)
            row.append((b.add_vert((x, y, z)), uv))
        rows.append(row)
    cz = surface(0.0, 0.0, p, fine)
    cuv = uv_of(0.0, 0.0, p)
    c = b.add_vert((0.0, 0.0, cz))
    for i in range(seg):
        a, ua = rows[0][i]
        d, ud = rows[0][(i + 1) % seg]
        b.face([c, a, d], [cuv, ua, ud], True)
    for k in range(rings - 1):
        for i in range(seg):
            j = (i + 1) % seg
            a, ua = rows[k][i]
            d, ud = rows[k][j]
            e, ue = rows[k + 1][j]
            f, uf = rows[k + 1][i]
            b.face([a, f, e, d], [ua, uf, ue, ud], True)
    return b


def patch_matrix(p):
    return (Matrix.Translation(Vector((p["loc"][0] * S, p["loc"][1] * S, 0.0)))
            @ Matrix.Rotation(math.radians(p["yaw"]), 4, "Z"))


# ---------------------------------------------------------------- materials (procedural bake slots)
def _ci(node, k):
    return [i for i in node.inputs if i.type == "RGBA"][k]


def _co(node):
    return [o for o in node.outputs if o.type == "RGBA"][0]


def _hex(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _noise(nt, coord, scale, detail, rough=0.55):
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    nt.links.new(coord, n.inputs["Vector"])
    return n


def _mix(nt, fac, a, b):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    if isinstance(fac, float):
        m.inputs["Factor"].default_value = fac
    else:
        nt.links.new(fac, m.inputs["Factor"])
    if isinstance(a, tuple):
        _ci(m, 0).default_value = a + (1.0,)
    else:
        nt.links.new(a, _ci(m, 0))
    if isinstance(b, tuple):
        _ci(m, 1).default_value = b + (1.0,)
    else:
        nt.links.new(b, _ci(m, 1))
    return _co(m)


def _sand_base(nt, coord):
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.30
    ramp.color_ramp.elements[0].color = _hex("#4A4130") + (1.0,)
    ramp.color_ramp.elements[1].position = 0.70
    ramp.color_ramp.elements[1].color = _hex("#7D7157") + (1.0,)
    nt.links.new(_noise(nt, coord, 6.5, 4.0, 0.62).outputs["Fac"], ramp.inputs["Fac"])
    col = ramp.outputs["Color"]
    mottle = nt.nodes.new("ShaderNodeMapRange")
    mottle.inputs["To Max"].default_value = 0.35
    nt.links.new(_noise(nt, coord, 2.3, 2.0).outputs["Fac"], mottle.inputs["Value"])
    col = _mix(nt, mottle.outputs["Result"], col, _hex("#423925"))
    # sparse, soft shell / gravel patches at 3 to 8 cm (one texel is about 6 mm at this density)
    g = nt.nodes.new("ShaderNodeValToRGB")
    g.color_ramp.elements[0].position = 0.70
    g.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
    g.color_ramp.elements[1].position = 0.82
    g.color_ramp.elements[1].color = (0.35, 0.35, 0.35, 1.0)
    nt.links.new(_noise(nt, coord, 16.0, 2.0, 0.45).outputs["Fac"], g.inputs["Fac"])
    col = _mix(nt, g.outputs["Color"], col, _hex("#8C7F63"))
    return col


def make_material(name, rgb, rough, kind):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    lin = [srgb_to_lin(c) for c in rgb]
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = 0.0
    m.diffuse_color = (lin[0], lin[1], lin[2], 1.0)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    coord = tc.outputs["Object"]
    if kind == "sand":
        col = _sand_base(nt, coord)
        rg = nt.nodes.new("ShaderNodeMapRange")
        rg.inputs["To Min"].default_value = 0.76
        rg.inputs["To Max"].default_value = 0.88
        nt.links.new(_noise(nt, coord, 8.0, 2.0).outputs["Fac"], rg.inputs["Value"])
        rough_out = rg.outputs["Result"]
    elif kind == "shell":
        col = _mix(nt, _noise(nt, coord, 55.0, 3.0).outputs["Fac"], _hex("#837862"), _hex("#B2A78F"))
        rough_out = 0.52
    else:
        col = _mix(nt, _noise(nt, coord, 24.0, 4.0, 0.6).outputs["Fac"], _hex("#3A372F"), _hex("#625C4F"))
        rough_out = 0.62
    out = nt.nodes.new("ShaderNodeGamma")
    out.name = "BAKE_BASE"
    out.inputs["Gamma"].default_value = 1.0
    nt.links.new(col, out.inputs["Color"])
    mr = nt.nodes.new("ShaderNodeCombineXYZ")
    mr.name = "BAKE_MR"
    mr.inputs["X"].default_value = 0.0
    if isinstance(rough_out, float):
        mr.inputs["Y"].default_value = rough_out
    else:
        nt.links.new(rough_out, mr.inputs["Y"])
    m["bake_custom"] = 1
    return m


# ---------------------------------------------------------------- shell grit and pebbles (patch D)
def shell_cell_uv(x, y, size, idx, cols=8):
    x0, x1, y0, y1 = SHELL_CELL
    sw, sh = (x1 - x0) / cols, (y1 - y0) / cols
    cx, cy = x0 + (idx % cols + 0.5) * sw, y0 + (idx // cols + 0.5) * sh
    return (cx + 0.42 * sw * (x / size), cy + 0.42 * sh * (y / size))


def add_shard(b, x, y, z, yaw, size, idx):
    ca, sa = math.cos(yaw), math.sin(yaw)
    n = 5
    ring = []
    for i in range(n):
        a = 2.0 * math.pi * i / n + 0.35
        rr = size * (0.55 + 0.45 * ((i * 37 + idx * 11) % 7) / 6.0)
        lx, ly = rr * math.cos(a), rr * 0.62 * math.sin(a)
        wx, wy = x + lx * ca - ly * sa, y + lx * sa + ly * ca
        wu, wv = shell_cell_uv(lx, ly, size, idx)
        ring.append((b.add_vert((wx, wy, max(z + 0.0004, 0.0005))), (wu, wv)))
    cx, cy = shell_cell_uv(0.0, 0.0, size, idx)
    c = b.add_vert((x, y, z + 0.0015))
    for i in range(n):
        a, ua = ring[i]
        d, ud = ring[(i + 1) % n]
        b.face([c, a, d], [(cx, cy), ua, ud], True)


def add_scallop(b, x, y, z, yaw, size, idx, n=9):
    ca, sa = math.cos(yaw), math.sin(yaw)
    x0, x1, y0, y1 = SHELL_CELL
    sw, sh = (x1 - x0) / 8.0, (y1 - y0) / 8.0
    cx, cy = x0 + (idx % 8 + 0.5) * sw, y0 + (idx // 8 + 0.5) * sh
    rings = []
    for rr, lift in ((0.45, 0.010), (0.88, 0.0035), (1.0, 0.0)):
        row = []
        for i in range(n + 1):
            a = -0.95 + 1.90 * i / n
            lx, ly = size * rr * math.cos(a), size * rr * 0.55 * math.sin(a)
            wx, wy = x + lx * ca - ly * sa, y + lx * sa + ly * ca
            u = cx + 0.42 * sw * (math.cos(a) * rr)
            v = cy + 0.42 * sh * (math.sin(a) * rr * 0.9)
            row.append((b.add_vert((wx, wy, max(z + 0.0005 + size * lift, 0.0005))), (u, v)))
        rings.append(row)
    for k in range(2):
        for i in range(n):
            a, ua = rings[k][i]
            d, ud = rings[k][i + 1]
            e, ue = rings[k + 1][i + 1]
            f, uf = rings[k + 1][i]
            b.face([a, f, e, d], [ua, uf, ue, ud], True)


def add_pebble(b, x, y, z, yaw, size, tilt, idx):
    ca, sa = math.cos(yaw), math.sin(yaw)
    ct, st = math.cos(tilt), math.sin(tilt)
    x0, x1, y0, y1 = PEBBLE_CELL
    sw, sh = (x1 - x0) / 4.0, (y1 - y0) / 3.0
    cx, cy = x0 + (idx % 4 + 0.5) * sw, y0 + (idx // 4 + 0.5) * sh
    lat = (-0.95, -0.55, 0.0, 0.55)
    rows = []
    for lz in lat:
        row = []
        rr = math.sqrt(max(0.0, 1.0 - lz * lz)) * size
        for i in range(8):
            a = 2.0 * math.pi * i / 8
            wob = 1.0 + 0.13 * math.sin(3.0 * a + idx) + 0.06 * math.sin(5.0 * a - idx * 2.0)
            lx = rr * wob * math.cos(a)
            ly = rr * 0.78 * wob * math.sin(a)
            lz2 = lz * size * 0.55
            # tilt about the local X axis, then yaw
            ty = ly * ct - lz2 * st
            tz = ly * st + lz2 * ct
            wx = x + lx * ca - ty * sa
            wy = y + lx * sa + ty * ca
            u = cx + 0.46 * sw * (lx / size)
            v = cy + 0.46 * sh * (ly / size)
            row.append((b.add_vert((wx, wy, max(z + tz - 0.07 * size, 0.0005))), (u, v)))
        rows.append(row)
    for k in range(len(rows) - 1):
        for i in range(8):
            j = (i + 1) % 8
            a, ua = rows[k][i]
            d, ud = rows[k][j]
            e, ue = rows[k + 1][j]
            f, uf = rows[k + 1][i]
            b.face([a, d, e, f], [ua, ud, ue, uf], True)
    # top cap and bottom cap fans keep the pebble closed for the bake
    top = b.add_vert((x + 0.02 * size * ca, y + 0.02 * size * sa, max(z + size * 0.50 - 0.07 * size, 0.0005)))
    bot = b.add_vert((x, y, 0.0005))
    for i in range(8):
        a, ua = rows[-1][i]
        d, ud = rows[-1][(i + 1) % 8]
        b.face([a, d, top], [ua, ud, (cx, cy)], True)
        aa, uaa = rows[0][(i + 1) % 8]
        dd, udd = rows[0][i]
        b.face([aa, dd, bot], [uaa, udd, (cx, cy)], True)


def trough_spots(p, target, min_gap, attempts=400):
    pts = []
    for _ in range(attempts):
        a = 2.0 * math.pi * rnd.random()
        rr = math.sqrt(rnd.random()) * 0.74
        x, y = p["rx"] * rr * math.cos(a), p["ry"] * rr * math.sin(a)
        h = surface(x, y, p)
        if h < 0.006:
            continue
        avg = sum(surface(x + dx, y + dy, p) for dx, dy in ((0.10, 0), (-0.10, 0), (0, 0.10), (0, -0.10))) / 4.0
        if h > avg - 0.0015:
            continue
        if any((x - qx) ** 2 + (y - qy) ** 2 < min_gap ** 2 for qx, qy, _ in pts):
            continue
        pts.append((x, y, h))
        if len(pts) >= target:
            break
    return pts


# ---------------------------------------------------------------- LOD hygiene (decals: no loose verts, no UV area loss)
def _uv_area(me):
    uvl = me.uv_layers["UVMap"].data
    a = 0.0
    for p in me.polygons:
        pts = [uvl[li].uv for li in p.loop_indices]
        for i in range(1, len(pts) - 1):
            a += abs((pts[i].x - pts[0].x) * (pts[i + 1].y - pts[0].y)
                     - (pts[i + 1].x - pts[0].x) * (pts[i].y - pts[0].y)) / 2.0
    return a


def _uv_islands(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.active
    seen, groups = set(), []

    def joined(f, g, edge):
        for v in edge.verts:
            a = next(l[uvl].uv for l in f.loops if l.vert == v)
            b = next(l[uvl].uv for l in g.loops if l.vert == v)
            if abs(a.x - b.x) > 1e-6 or abs(a.y - b.y) > 1e-6:
                return False
        return True

    for f in bm.faces:
        if f.index in seen:
            continue
        seen.add(f.index)
        stack, group = [f], []
        while stack:
            cur = stack.pop()
            group.append(cur.index)
            for e in cur.edges:
                for o in e.link_faces:
                    if o.index not in seen and joined(cur, o, e):
                        seen.add(o.index)
                        stack.append(o)
        groups.append(group)
    bm.free()
    return groups


def _match_uv_area(lod_ob, src_ob):
    want = _uv_area(src_ob.data)
    me = lod_ob.data
    uvl = me.uv_layers["UVMap"].data
    for _ in range(5):
        have = _uv_area(me)
        if have <= 1e-9 or abs(have - want) / want < 0.01:
            break
        k = min(1.6, math.sqrt(want / have))
        for g in _uv_islands(me):
            lis = [li for fi in g for li in me.polygons[fi].loop_indices]
            us = [uvl[li].uv.x for li in lis]
            vs = [uvl[li].uv.y for li in lis]
            cu, cv = (min(us) + max(us)) / 2, (min(vs) + max(vs)) / 2
            for li in lis:
                uvl[li].uv = (cu + (uvl[li].uv.x - cu) * k, cv + (uvl[li].uv.y - cv) * k)
        me.update()
    for d in uvl:
        d.uv = (min(max(d.uv.x, 0.0005), 0.9995), min(max(d.uv.y, 0.0005), 0.9995))
    me.update()


def _run_lod(spec):
    made = versions._stock_run_lod(spec)
    for e in spec["meshes"]:
        if e.get("role") != "visual" or e.get("lod") not in ("LOD1", "LOD2"):
            continue
        ob = e["object"]
        src = bpy.data.objects.get(names.mesh_base(ob.name) + "_LOD0")
        if src is None:
            continue
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
            bm.to_mesh(ob.data)
            ob.data.update()
        bm.free()
        _match_uv_area(ob, src)
    return made


versions._stock_run_lod = versions.run_lod
versions.run_lod = _run_lod


def centre_trough(p, radius=0.85):
    best = None
    for _ in range(500):
        a = 2.0 * math.pi * rnd.random()
        rr = math.sqrt(rnd.random()) * radius
        x, y = p["rx"] * rr * math.cos(a), p["ry"] * rr * math.sin(a)
        h = surface(x, y, p)
        if h < 0.006:
            continue
        avg = sum(surface(x + dx, y + dy, p) for dx, dy in ((0.09, 0), (-0.09, 0), (0, 0.09), (0, -0.09))) / 4.0
        score = h - avg
        if best is None or score < best[0]:
            best = (score, x, y, h)
    return best[1], best[2], best[3]


# ---------------------------------------------------------------- build
def build():
    for name, rgb, rough in MATS:
        make_material(name, rgb, rough, "sand" if name == SAND else "shell" if name == SHELL else "stone")

    meshes, hps = [], []
    for p in PATCHES:
        b = build_patch(p, p["rings"], p["seg"], fine=False)
        ob = b.to_object("%s_%s_LOD0" % (NAME, p["key"]), SAND)
        ob.data.transform(patch_matrix(p))
        ob.data.update()
        versions.weighted_normals(ob)
        meshes.append(ob)

        hb = build_patch(p, p["rings"] * 7, min(180, p["seg"] * 4), fine=True)
        hp = hb.to_object("%s_%s_HP" % (NAME, p["key"]), SAND)
        hp.data.transform(patch_matrix(p))
        hp.data.update()
        for poly in hp.data.polygons:
            poly.use_smooth = True
        hps.append(hp)
        print("[%s] %s %d tris, HP %d tris" % (NAME, ob.name, versions.triangles(ob.data),
                                               versions.triangles(hp.data)))

    d = PATCHES[3]
    hx, hy, hz = centre_trough(d)
    sb = Buf()
    for k in range(10):
        x = hx + rnd.gauss(0.0, 0.085)
        y = hy + rnd.gauss(0.0, 0.085)
        add_shard(sb, x, y, surface(x, y, d), 2.0 * math.pi * rnd.random(), rnd.uniform(0.008, 0.017), k)
    for j in range(2):
        x, y = hx + rnd.gauss(0.0, 0.10), hy + rnd.gauss(0.0, 0.10)
        add_scallop(sb, x, y, surface(x, y, d), 2.0 * math.pi * rnd.random(), rnd.uniform(0.030, 0.040), 10 + j)
    k = 12
    for cx, cy, cz in trough_spots(d, 6, 0.42):
        for _ in range(6):
            x = min(d["rx"] * 0.80, max(-d["rx"] * 0.80, cx + rnd.gauss(0.0, 0.075)))
            y = min(d["ry"] * 0.80, max(-d["ry"] * 0.80, cy + rnd.gauss(0.0, 0.075)))
            z = surface(x, y, d)
            add_shard(sb, x, y, z, 2.0 * math.pi * rnd.random(), rnd.uniform(0.007, 0.016), k)
            k += 1
    for j in range(2):
        spots = trough_spots(d, 1, 0.40)
        if spots:
            x, y, z = spots[0]
            add_scallop(sb, x, y, z, 2.0 * math.pi * rnd.random(), rnd.uniform(0.028, 0.038), 48 + j)
    shell_ob = sb.to_object("%s_ShellGrit_LOD0" % NAME, SHELL)
    shell_ob.data.transform(patch_matrix(d))
    shell_ob.data.update()
    versions.weighted_normals(shell_ob)
    meshes.append(shell_ob)

    pb = Buf()
    for k, (dx, dy) in enumerate(((0.26, 0.16), (-0.30, 0.20))):
        x, y = hx + dx, hy + dy
        add_pebble(pb, x, y, surface(x, y, d), 2.0 * math.pi * rnd.random(), rnd.uniform(0.028, 0.040),
                   rnd.uniform(-0.2, 0.2), k)
    for k, (x, y, z) in enumerate(trough_spots(d, 7, 0.22), start=2):
        add_pebble(pb, x, y, z, 2.0 * math.pi * rnd.random(), rnd.uniform(0.020, 0.042),
                   rnd.uniform(-0.25, 0.25), k)
    stone_ob = pb.to_object("%s_Pebbles_LOD0" % NAME, STONE)
    stone_ob.data.transform(patch_matrix(d))
    stone_ob.data.update()
    versions.weighted_normals(stone_ob)
    meshes.append(stone_ob)
    for ob in (shell_ob, stone_ob):
        hp = versions.copy_object(ob, names.mesh_base(ob.name) + "_HP")
        hp.data.name = hp.name
        for poly in hp.data.polygons:
            poly.use_smooth = True
        hps.append(hp)
    print("[%s] %s %d tris, %s %d tris" % (NAME, shell_ob.name, versions.triangles(shell_ob.data),
                                           stone_ob.name, versions.triangles(stone_ob.data)))

    off = W.shift_to_base(meshes)
    for hp in hps:
        hp.data.transform(Matrix.Translation(off))
        hp.data.update()

    lo, hi = W.bbox(meshes)
    dims_m = ((hi.x - lo.x) / S, (hi.y - lo.y) / S, (hi.z - lo.z) / S)
    print("[%s] bbox m %.3f x %.3f x %.3f, min z %.4f" % ((NAME,) + dims_m + (lo.z / S,)))
    tris = sum(versions.triangles(o.data) for o in meshes)
    print("[%s] LOD0 total %d tris" % (NAME, tris))

    entries = [{"object": o, "set": SET} for o in meshes]
    entries += [{"object": o, "role": "hp"} for o in hps]
    shift = Vector(off)
    hero = patch_matrix(d) @ Vector((hx, hy, 0.0)) + shift
    return {
        "name": NAME, "budget": "large_prop", "tris": 6000, "tier": "standard",
        "dims_m": (round(dims_m[0], 2), round(dims_m[1], 2), round(dims_m[2], 2)), "origin": "base",
        "size_note": "four-piece seabed decal kit laid out side by side, not one object",
        "sets": [{"name": "SandRipples", "set": SET, "size": 2048, "wet": True,
                  "wet_darken": 0.12, "wet_gloss": 0.14,
                  "wear": {"edge": 0.04, "edge_range": (0.55, 0.90), "edge_color": (0.33, 0.31, 0.26),
                           "salt": 0.0, "rust": 0.0, "ao_strength": 0.55}}],
        "bake_size": 2048,
        "meshes": entries,
        "waivers": {"_COL proxy": "flat seabed decals lie on the terrain; collision comes from the terrain"},
        "closeups": [{"name": "grit", "target": [round(hero.x, 2), round(hero.y, 2), 0.10],
                      "dist": 5.2, "az": 28, "el": 44},
                     {"name": "grit_wide", "target": [round(hero.x, 2), round(hero.y, 2), 0.10],
                      "dist": 9.5, "az": 210, "el": 52},
                     {"name": "swells", "target": [round(-2.4 * S + shift.x, 2), round(0.9 * S + shift.y, 2), 0.15],
                      "dist": 8.0, "az": 145, "el": 26}],
    }
