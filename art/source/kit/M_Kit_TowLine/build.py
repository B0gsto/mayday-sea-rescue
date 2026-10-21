"""E2 M_Kit_TowLine: 50 m tow line coiled on deck with a spliced eye, thimble and bow shackle (docs/12 2.8).

Coiled ~20 m of 20 mm cream 3-strand polyester tow line (docs/12: 16 to 20 mm, coil about 0.5 m OD): a two-layer
flat flake with the bottom layer spiralling in, a bight round the centre hole climbing one layer, the top layer
spiralling back out, and the free end draped over the outer edge onto the deck (whipped). The working end leaves
the flake at the +X side with a long splice throat, a spliced eye round a galvanised thimble, and a 16 mm screw-pin
bow shackle standing in the eye, moused with wire. Everything lies on deck: base at Z 0, front -Y.

Rope geometry from tools/blender/rope.py (rope.tube, plain profile: at this triangle budget the tiling rope trim
carries the strand twist, the tube stays round). Two own PBR sets generated at build time by maketex.py under the
run's out-root: T_TowLine_Rope_* (1024 tiling trim, red marker yarn) and T_TowLine_Hardware_* (512 galvanised).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/kit/M_Kit_TowLine/build.py \
        --out-root build/prod/M_Kit_TowLine --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import maketex  # noqa: E402
import rope  # noqa: E402

S = common.STUDS_PER_METRE
NAME = "M_Kit_TowLine"
D = 0.020                      # 20 mm tow line (docs/12: 16 to 20 mm)
R_IN, R_OUT = 0.115, 0.225     # flake radii (0.45 m OD)
TURNS = 5                      # per layer, bottom in + top out
ZB = D * 0.55                  # bottom layer rope centre (resting on deck)
ZT = ZB + D * 0.95             # top layer rope centre
SQUASH = 0.96                  # very slightly oval flake
EYE = (0.300, -0.190)          # eye splice centre
RE = 0.055                     # eye centreline radius
SHACKLE_Z = 0.068              # pin axis height
BOW_R = 0.019                  # bow leg spacing / crown radius
STOCK = 0.0065                 # bow stock radius
COIL_TRIS = 1856               # budget share of the flake (row ceiling 2,500 with the hardware)


# ---------------------------------------------------------------- helpers
def smoothstep(t):
    t = 0.0 if t < 0.0 else 1.0 if t > 1.0 else t
    return t * t * (3.0 - 2.0 * t)


def catmull(ctrl, n=12):
    """Uniform Catmull-Rom through the control points (metres), n samples per span."""
    P = [np.asarray(p, float) for p in ctrl]
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    out = []
    for i in range(len(P) - 3):
        p0, p1, p2, p3 = P[i:i + 4]
        for j in range(n):
            t = j / float(n)
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-2])
    return np.array(out)


def tube(points_m, max_tris, sides=6, caps=True):
    return rope.tube(points_m, D, "plain", sides=sides, max_tris=max_tris, caps=caps)


def tube_var(points_m, rfun, sides=6, rings=12, caps=False):
    """Rope tube with a radius that varies along the path (the splice swelling). Same UV convention as rope.tube."""
    p = rope.resample(np.asarray(points_m, float), rings + 1)
    length = rope.polyline_length(p)
    c = p * S
    t, n, b = rope.frames(c)
    th = np.arange(sides) / sides * 2 * np.pi
    R = rfun(np.linspace(0.0, 1.0, rings + 1)) * S
    ring = np.cos(th)[None, :, None] * n[:, None, :] + np.sin(th)[None, :, None] * b[:, None, :]
    verts = (c[:, None, :] + R[:, None, None] * ring).reshape(-1, 3)
    tile = math.pi * D
    v = np.linspace(0.0, length, rings + 1) / tile
    faces, uvs = [], []
    for i in range(rings):
        for j in range(sides):
            j1 = (j + 1) % sides
            faces.append((i * sides + j, i * sides + j1, (i + 1) * sides + j1, (i + 1) * sides + j))
            u0, u1 = j / sides, (j + 1) / sides
            uvs.append(((u0, v[i]), (u1, v[i]), (u1, v[i + 1]), (u0, v[i + 1])))
    if caps:
        extra = []
        for ring_i, outward in ((0, False), (rings, True)):
            centre = len(verts) + len(extra)
            extra.append(c[ring_i])
            for j in range(sides):
                j1 = (j + 1) % sides
                ia, ib = ring_i * sides + j, ring_i * sides + j1
                ua = (0.5 + 0.25 * math.cos(2 * math.pi * j / sides), v[ring_i] + 0.25 * math.sin(2 * math.pi * j / sides))
                ub = (0.5 + 0.25 * math.cos(2 * math.pi * j1 / sides), v[ring_i] + 0.25 * math.sin(2 * math.pi * j1 / sides))
                faces.append((ia, ib, centre) if outward else (ib, ia, centre))
                uvs.append((ua, ub, (0.5, v[ring_i])) if outward else (ub, ua, (0.5, v[ring_i])))
        verts = np.concatenate([verts, np.array(extra)])
    return verts, faces, uvs


def remap_v(uvs, v_end):
    return [[(u, v / max(v_end, 1e-9)) for u, v in poly] for poly in uvs]


# ---------------------------------------------------------------- the flake
def coil_path():
    """Working end -> bottom layer in -> centre bight up -> top layer out -> draped free end on deck (metres)."""
    a0 = 0.0
    pts = []
    # run-out from the eye's near point N up to the flake's outer edge
    N = (EYE[0] - RE, EYE[1], ZB)
    P0 = (R_OUT, 0.0, ZB)
    pts.extend(catmull([N, (0.2470, -0.130, ZB), (0.2445, -0.075, ZB), (0.2375, -0.030, ZB), (0.2255, -0.004, ZB), P0], 10))
    # bottom layer: spiral inward, CCW
    n = TURNS * 24
    for i in range(1, n + 1):
        t = i / float(n)
        th = a0 + 2 * math.pi * TURNS * t
        r = R_OUT + (R_IN - R_OUT) * t + 0.0010 * math.sin(2 * th + 0.9)
        z = ZB + 0.0006 * math.sin(2 * th + 1.7)
        pts.append((r * math.cos(th), SQUASH * r * math.sin(th), z))
    # centre bight: climb one layer round the hole
    th0 = a0 + 2 * math.pi * TURNS
    for i in range(1, 13):
        t = i / 12.0
        th = th0 + math.pi * t
        r = R_IN - 0.020 * math.sin(math.pi * t)
        z = ZB + (ZT - ZB) * smoothstep(t)
        pts.append((r * math.cos(th), SQUASH * r * math.sin(th), z))
    # top layer: spiral back out, CCW
    th1 = th0 + math.pi
    for i in range(1, n + 1):
        t = i / float(n)
        th = th1 + 2 * math.pi * TURNS * t
        r = (R_IN + (R_OUT - R_IN) * t) + 0.0010 * math.sin(2 * th + 2.2)
        z = ZT + 0.0006 * math.sin(2 * th + 2.6)
        pts.append((r * math.cos(th), SQUASH * r * math.sin(th), z))
    # free end: drape over the outer turns and lie on the deck
    th2 = th1 + 2 * math.pi * TURNS
    for i in range(1, 21):
        t = i / 20.0
        th = th2 + 0.45 * math.pi * t
        r = R_OUT + 0.085 * t
        drop = smoothstep((r - 0.245) / 0.030)
        z = ZT + 0.002 - (ZT + 0.002 - ZB) * drop
        pts.append((r * math.cos(th), SQUASH * r * math.sin(th), z))
    # a short slack run on the deck to the whipped end
    th3 = th2 + 0.45 * math.pi
    last = np.array(pts[-1])
    ahead = np.array([-math.sin(th3), SQUASH * math.cos(th3), 0.0])
    ahead /= np.linalg.norm(ahead)
    side = np.array([ahead[1], -ahead[0], 0.0])
    pts.extend(list(catmull([tuple(last), tuple(last + ahead * 0.055 + side * 0.012),
                             tuple(last + ahead * 0.105 + side * 0.006),
                             tuple(last + ahead * 0.145 - side * 0.010)], 6))[1:])
    return np.array(pts), float(rope.polyline_length(np.array(pts)))


def eye_parts(coil_pts):
    """Spliced eye round the thimble (closed loop), the splice swelling and the whipped tail end."""
    # eye loop: a full circle in the deck plane, tangent to the standing part at N
    th = np.linspace(0.0, 2 * math.pi, 29)
    ring = [(EYE[0] + RE * math.cos(t), EYE[1] + RE * math.sin(t), ZB) for t in th]
    v, f, u, _tris, _ = tube(ring, 150, caps=False)

    # splice swelling: 50 mm along the eye's near arc, then 140 mm along the standing part
    arc = [(EYE[0] + RE * math.cos(t), EYE[1] + RE * math.sin(t), ZB)
           for t in np.linspace(math.pi + 0.9, math.pi, 9)]
    cum = [0.0]
    for a, b in zip(coil_pts[:-1], coil_pts[1:]):
        cum.append(cum[-1] + float(np.linalg.norm(b - a)))
    run = [tuple(p) for s, p in zip(cum, coil_pts) if 0.0 < s <= 0.140]
    path = np.array(arc + run, float)
    fv, ff, fu = tube_var(path, lambda t: D / 2 * (1.0 + 0.42 * np.sin(np.pi * t) ** 1.3), rings=9)

    # whipping band on the free end
    wv, wf, wu, _tris, _ = rope.tube(list(coil_pts[-2:]), D + 0.0028, "plain", sides=6, max_tris=36, caps=True)
    return [(v, f, u), (fv, ff, fu), (wv, wf, wu)]


# ---------------------------------------------------------------- shackle and thimble (galvanised set)
def hardware_parts():
    cx, cy = EYE[0] + 0.006, EYE[1]
    parts = []
    # bow: two vertical legs and a crown semicircle, in the XZ plane (crown resting on deck)
    arc = [(cx + BOW_R * math.cos(a), cy, 0.026 - BOW_R * math.sin(a)) for a in np.linspace(math.pi, 0.0, 15)]
    bow = [(cx - BOW_R, cy, SHACKLE_Z), (cx - BOW_R, cy, 0.044)] + arc + [(cx + BOW_R, cy, 0.044), (cx + BOW_R, cy, SHACKLE_Z)]
    v, f, u, _tris, ve = rope.tube(bow, 2 * STOCK, "plain", sides=6, max_tris=108, caps=True)
    parts.append((v, f, remap_v(u, ve)))
    # lugs round the pin
    for sx in (-1, 1):
        x0 = cx + sx * BOW_R
        p = [(x0 - sx * 0.010, cy, SHACKLE_Z), (x0 + sx * 0.010, cy, SHACKLE_Z)]
        v, f, u, _tris, ve = rope.tube(p, 0.021, "plain", sides=6, max_tris=24, caps=True)
        parts.append((v, f, remap_v(u, ve)))
    # screw pin, hex head (starboard) and collar (port)
    p = [(cx - 0.031, cy, SHACKLE_Z), (cx + 0.031, cy, SHACKLE_Z)]
    v, f, u, _tris, ve = rope.tube(p, 0.015, "plain", sides=6, max_tris=36, caps=True)
    parts.append((v, f, remap_v(u, ve)))
    p = [(cx + 0.031, cy, SHACKLE_Z), (cx + 0.045, cy, SHACKLE_Z)]
    v, f, u, _tris, ve = rope.tube(p, 0.026, "plain", sides=6, max_tris=24, caps=True)
    parts.append((v, f, remap_v(u, ve)))
    p = [(cx - 0.043, cy, SHACKLE_Z), (cx - 0.031, cy, SHACKLE_Z)]
    v, f, u, _tris, ve = rope.tube(p, 0.022, "plain", sides=6, max_tris=24, caps=True)
    parts.append((v, f, remap_v(u, ve)))
    # mousing wire round the starboard leg
    wire = [(cx + 0.040, cy, SHACKLE_Z), (cx + 0.036, cy + 0.015, SHACKLE_Z + 0.004),
            (cx + 0.030, cy + 0.017, SHACKLE_Z + 0.004), (cx + 0.017, cy + 0.013, SHACKLE_Z),
            (cx + 0.017, cy - 0.013, SHACKLE_Z), (cx + 0.030, cy - 0.017, SHACKLE_Z + 0.004),
            (cx + 0.036, cy - 0.015, SHACKLE_Z + 0.004), (cx + 0.040, cy, SHACKLE_Z)]
    v, f, u, _tris, ve = rope.tube(wire, 0.0016, "plain", sides=3, max_tris=36, caps=False)
    parts.append((v, f, remap_v(u, ve)))
    # thimble seated in the eye
    th = np.linspace(0.0, 2 * math.pi, 15)
    ring = [(EYE[0] + 0.041 * math.cos(t), EYE[1] + 0.041 * math.sin(t), ZB) for t in th]
    v, f, u, _tris, ve = rope.tube(ring, 0.0045, "plain", sides=4, max_tris=80, caps=False)
    parts.append((v, f, remap_v(u, ve)))
    return parts


# ---------------------------------------------------------------- scene assembly
def material(name, rgb, rough, metal):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return m


def assemble(name, parts, mat):
    verts, faces, uvs, off = [], [], [], 0
    for v, f, u in parts:
        verts.extend(tuple(float(c) for c in p) for p in v)
        faces.extend(tuple(int(i) + off for i in face) for face in f)
        uvs.extend(u)
        off += len(v)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    uvl = me.uv_layers.new(name=common.UV_NAME)
    flat = [c for poly in uvs for c in poly]
    uvl.data.foreach_set("uv", [x for c in flat for x in c])
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    me.update()
    return ob


def box_col(name, lo, hi):
    bm = bmesh.new()
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    vs = [bm.verts.new((x * S, y * S, z * S)) for z in (z0, z1) for y in (y0, y1) for x in (x0, x1)]
    for f in [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def att(name, p_m, off):
    e = bpy.data.objects.new(name, None)
    e.location = tuple((c + o) * S for c, o in zip(p_m, off))
    bpy.context.scene.collection.objects.link(e)
    return e


def build():
    maketex.write_all(NAME)
    coil, length = coil_path()
    print("[M_Kit_TowLine] flake centreline %.2f m, outer diameter %.3f m" % (length, 2 * R_OUT))

    rope_parts = [tube(coil, COIL_TRIS, caps=True)[:3]]
    rope_parts += eye_parts(coil)
    hw_parts = hardware_parts()

    # base origin at the LOD0 bbox centre, z 0
    pts = [p for v, _f, _u in rope_parts + hw_parts for p in v]
    lo = np.array([min(p[i] for p in pts) for i in range(3)]) / S
    hi = np.array([max(p[i] for p in pts) for i in range(3)]) / S
    off = np.array([-(lo[0] + hi[0]) / 2.0, -(lo[1] + hi[1]) / 2.0, -lo[2]], float)

    def shifted(parts):
        return [(v + off * S, f, u) for v, f, u in parts]

    rope_parts, hw_parts = shifted(rope_parts), shifted(hw_parts)
    rope_ob = assemble(NAME + "_LOD0", rope_parts, material("MI_TowLine_Rope", (0.66, 0.63, 0.57), 0.72, 0.0))
    hw_ob = assemble(NAME + "_Hardware_LOD0", hw_parts, material("MI_TowLine_Hardware", (0.55, 0.56, 0.57), 0.42, 1.0))

    # collision: flat box under the flake
    c_lo = np.array([-R_OUT, -R_OUT * SQUASH, 0.0]) + off
    c_hi = np.array([R_OUT, R_OUT * SQUASH, ZT + D * 1.5]) + off
    col = box_col(NAME + "_COL", tuple(c_lo + 0.004), tuple(c_hi - 0.004))

    def tri(ob):
        ob.data.calc_loop_triangles()
        return len(ob.data.loop_triangles)

    tr, th = tri(rope_ob), tri(hw_ob)
    print("[M_Kit_TowLine] LOD0 %d tris (rope %d, hardware %d), ceiling %d" % (tr + th, tr, th, 2500))

    cx, cy = EYE[0] + 0.006, EYE[1]
    end = tuple(coil[-1])
    attachments = [
        att("ATT_Grip", (0.0, 0.0, ZT + D), off),
        att("ATT_Eye", (EYE[0], EYE[1], ZB), off),
        att("ATT_Shackle", (cx, cy, SHACKLE_Z + 0.006), off),
        att("ATT_LineEnd", end, off),
    ]
    dims = tuple(round(float(v), 3) for v in (hi - lo))
    print("[M_Kit_TowLine] dims m %s, flake %.3f m OD" % (dims, 2 * R_OUT))

    return {
        "name": NAME,
        "budget": "large_prop",
        "tris": 2500,
        "tier": "hero",
        "dims_m": dims,
        "size_note": ("flake 0.45 m OD per docs/12; the bbox also holds the eye splice and the standing bow shackle "
                      "laid beside it"),
        "origin": "base",
        "tiling": True,
        "atlas": None,
        "sets": [
            {"name": "TowLine", "set": "Rope", "size": maketex.ROPE_SIZE, "wet": True},
            {"name": "TowLine", "set": "Hardware", "size": maketex.HW_SIZE, "wet": True},
        ],
        "meshes": [{"object": rope_ob, "set": "Rope"}, {"object": hw_ob, "set": "Hardware"}, {"object": col}],
        "attachments": attachments,
        "waivers": {
            "LOD UV layout": ("collapse decimation of a two-layer rope flake merges UV islands and drops area; both LODs "
                              "still sample the same tiling trim"),
        },
        "closeups": [
            {"name": "splice_shackle", "target": [(EYE[0] + off[0]) * S, (EYE[1] + off[1]) * S, (ZB + 0.035) * S],
             "dist": 3.4, "az": 24.0, "el": 18.0},
            {"name": "flake_top", "target": [(off[0]) * S, (off[1]) * S, (ZT + D) * S],
             "dist": 4.6, "az": 205.0, "el": 46.0},
        ],
    }
