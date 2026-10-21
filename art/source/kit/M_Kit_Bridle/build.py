"""E2 M_Kit_Bridle: the two-leg tow bridle from the RIB's tow kit (docs/12 2.8, docs/09 Op 2 step 5).

About 5.0 m of 20 mm cream 3-strand polyester, laid out on deck ready to rig: one spliced hard eye at the apex
round a galvanised thimble, the two legs opening at 56 degrees, and a soft eye spliced at the end of each leg to
drop over the casualty's bow cleats. The apex thimble carries a 16 mm galvanised bow shackle, moused with wire,
for the tow line's own shackle to take. Both legs are served with a chafing wrap behind the cleat eyes, seized
with twine at the apex fork and at each eye throat, and lie on deck with the slack a hand-thrown line keeps.

The rope's own weight and the cleat chafe live in the geometry (splice swells, the served section, the whipping
seizings); the sun, salt and deck grime live in two PBR sets written at build time by maketex.py under the run's
out-root: T_Bridle_Rope_* (1024 tiling trim, red tracer pair, navy marker) and T_Bridle_Hardware_* (1024 hot-dip
galvanised steel). Rope geometry comes from tools/blender/rope.py; profile "plain" at this triangle budget, so the
tiling trim carries the strand twist.

Everything lies flat: base at Z 0, the apex and the tow line's end at -Y. ATT_Apex is the bow of the shackle the
tow line takes, ATT_Grip the throat where a hand carries the bridle, ATT_Cleat_Port / ATT_Cleat_Stbd the two soft
eye centres for the casualty's cleats.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/kit/M_Kit_Bridle/build.py \
        --out-root build/prod/M_Kit_Bridle --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import maketex  # noqa: E402
import rope  # noqa: E402

S = common.STUDS_PER_METRE
NAME = "M_Kit_Bridle"

# ---------------------------------------------------------------- real dimensions (metres)
D = 0.020                       # 20 mm 3-strand polyester (docs/12 row: 16 to 20 mm, verify)
ZB = D * 0.47                   # rope centreline lying on deck (a rope squashes a little flat)
APEX = np.array([0.0, -0.95, ZB])       # apex hard eye centre
RA_A, RA_B, RA_T = 0.062, 0.070, 0.10   # apex eye: along the axis / across / teardrop throat
RE_A, RE_B, RE_T = 0.062, 0.072, 0.14   # cleat eye: along the axis / across / teardrop throat
EYE_TILT = -0.10                # cleat eyes lift a touch off the deck at the far end (radians)
HALF = math.radians(28.0)       # half angle between the two legs (56 degrees total)
L_LEG = 1.93                    # each leg, apex throat to the cleat eye's throat
TILE = math.pi * D              # trim tile: one full strand twist per rope circumference
SERVE_IN, SERVE_OUT = 0.20, 0.64    # served chafe wrap, metres back from the cleat eye's throat
SEIZE_D = 0.045                 # apex fork seizing: out along the legs from the throat

# Each leg's centreline: (distance along the leg, offset across it, lift off the deck) in metres. Two different
# lays, so the bridle is a line thrown down on deck and not a mirror pair.
LEG_CTRL = {
    -1: [(0.00, 0.000, 0.0000), (0.24, 0.020, 0.0006), (0.55, 0.048, 0.0010), (0.90, 0.052, 0.0002),
         (1.22, 0.018, 0.0012), (1.52, -0.026, 0.0006), (1.75, -0.020, 0.0010), (1.93, 0.000, 0.0000)],
    1: [(0.00, 0.000, 0.0000), (0.28, -0.024, 0.0008), (0.62, -0.014, 0.0004), (0.98, 0.040, 0.0012),
        (1.30, 0.034, 0.0004), (1.60, -0.016, 0.0012), (1.93, 0.000, 0.0000)],
}

# the apex shackle: 16 mm galvanised bow shackle lying flat in the hard eye (stock radius, crown radius, pin axis)
ST = 0.0086                     # shackle stock / pin radius (17 mm galvanised bow shackle)
SHACKLE_W = 0.030               # inside width between the bow legs (vertical, the pin drops through it)


# ---------------------------------------------------------------- helpers
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


def path_slice(path, s0, s1):
    """The piece of a polyline (metres) between arc lengths s0 and s1, ends interpolated."""
    seg = np.linalg.norm(np.diff(path, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])

    def at(x):
        i = min(max(int(np.searchsorted(s, x)), 1), len(s) - 1)
        w = (x - s[i - 1]) / max(s[i] - s[i - 1], 1e-12)
        return path[i - 1] + (path[i] - path[i - 1]) * w
    return np.array([at(s0)] + [p for p, x in zip(path, s) if s0 < x < s1] + [at(s1)])


def tube(points_m, sides=6, segs=40, caps=True, flat=0.90, r_m=None):
    """Rope tube along a centreline: constant radius (r_m in metres) or a radius function of t in 0..1. Lying on
    deck the cross-section is squashed a little (flat) under the centreline. Vertices in studs, UVs in trim tiles."""
    p = rope.resample(np.asarray(points_m, float), segs + 1)
    length = rope.polyline_length(p)
    c = p * S
    _t, n, b = rope.frames(c)
    th = np.arange(sides) / sides * 2 * np.pi
    rad = (np.asarray(r_m(np.linspace(0.0, 1.0, segs + 1)), float) if callable(r_m)
           else np.full(segs + 1, float(D / 2 if r_m is None else r_m)))
    ring = np.cos(th)[None, :, None] * n[:, None, :] + np.sin(th)[None, :, None] * b[:, None, :]
    off = (rad[:, None, None] * S) * ring
    if flat:
        off[:, :, 2] = np.where(off[:, :, 2] < 0.0, off[:, :, 2] * flat, off[:, :, 2])
    verts = (c[:, None, :] + off).reshape(-1, 3)
    v = np.linspace(0.0, length, segs + 1) / TILE
    faces, uvs = [], []
    for i in range(segs):
        for j in range(sides):
            j1 = (j + 1) % sides
            faces.append((i * sides + j, i * sides + j1, (i + 1) * sides + j1, (i + 1) * sides + j))
            u0, u1 = j / sides, (j + 1) / sides
            uvs.append(((u0, v[i]), (u1, v[i]), (u1, v[i + 1]), (u0, v[i + 1])))
    if caps:
        extra = []
        for ring_i, outward in ((0, False), (segs, True)):
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


def remap_v(uvs):
    v_end = max((v for poly in uvs for _u, v in poly), default=1.0)
    return [[(u, v / max(v_end, 1e-9)) for u, v in poly] for poly in uvs]


def eye_loop(throat, out_dir, r_along, r_across, r_throat, segs, tilt=0.0):
    """A spliced eye on deck: its throat (small end) at `throat` (metres), the eye reaching out along `out_dir`
    (a 2D unit vector), a teardrop narrowing towards the throat the way a splice does. `tilt` lifts the far end
    off the deck about the throat (radians, negative raises it), so an eye reads as rope and not as a flat ring."""
    d = np.asarray(out_dir, float)
    u = -d                                                          # from the eye centre out through the throat
    w = np.array([-d[1], d[0]])
    t = np.linspace(0.0, 2 * math.pi, segs + 1)
    k = 1.0 - r_throat * np.cos(t)
    centre = np.asarray(throat, float)[:2] + d * (r_along * (1.0 - r_throat))
    pts = (centre[None, :] + (r_along * k * np.cos(t))[:, None] * u[None, :]
           + (r_across * k * np.sin(t))[:, None] * w[None, :])
    pts3 = np.stack([pts[:, 0], pts[:, 1], np.full(len(t), ZB)], -1)
    # seal the loop's UV seam: stretch it about the throat so the loop is a whole number of trim tiles long,
    # then the strand lay runs round the eye without a step (a couple of per cent of radius, invisible)
    pivot = np.array([throat[0], throat[1], ZB])
    length = float(np.linalg.norm(np.diff(np.concatenate([pts3, pts3[:1]]), axis=0), axis=1).sum())
    pts3 = pivot + (pts3 - pivot) * (max(1.0, round(length / TILE)) * TILE / max(length, 1e-9))
    if tilt:
        axis = np.array([w[0], w[1], 0.0])
        piv = np.asarray(throat, float)
        rel = pts3 - piv
        pts3 = piv + (rel * math.cos(tilt) + np.cross(axis, rel) * math.sin(tilt)
                      + axis[None, :] * (rel @ axis)[:, None] * (1.0 - math.cos(tilt)))
    return pts3


def twine_ring(centre, ax, ay, a, b, twine_r, sides=4, segs=10):
    """A seizing: thin twine wound once round a fork of rope, in the plane spanned by ax and ay (metres). The
    ring's ends meet at the same point, so remove_doubles closes the seam."""
    t = np.linspace(0.0, 2 * math.pi, segs + 1)
    pts = (np.asarray(centre, float)[None, :] + a * np.cos(t)[:, None] * np.asarray(ax, float)[None, :]
           + b * np.sin(t)[:, None] * np.asarray(ay, float)[None, :])
    return tube(pts, sides=sides, segs=segs, caps=False, flat=0.0, r_m=twine_r)


def thimble(centre, a, b, rx, ry, sides=5, segs=14):
    """Galvanised thimble lying flat: an oval ring whose cross-section is an ellipse (rx radial, ry up), metres."""
    t = np.linspace(0.0, 2 * math.pi, segs + 1)
    xy = np.stack([centre[0] + a * np.cos(t), centre[1] + b * np.sin(t)], -1)
    rad = np.stack([np.cos(t) / a, np.sin(t) / b], -1)
    rad /= np.linalg.norm(rad, axis=-1, keepdims=True)
    th = np.arange(sides) / sides * 2 * np.pi
    pts = (np.concatenate([xy, np.full((len(t), 1), centre[2])], -1)[:, None, :]
           + rx * np.cos(th)[None, :, None] * np.concatenate([rad, np.zeros((len(t), 1))], -1)[:, None, :]
           + ry * np.sin(th)[None, :, None] * np.array([0.0, 0.0, 1.0])[None, None, :])
    verts = pts.reshape(-1, 3) * S
    faces, uvs = [], []
    for i in range(segs):
        for j in range(sides):
            j1 = (j + 1) % sides
            faces.append((i * sides + j, i * sides + j1, (i + 1) * sides + j1, (i + 1) * sides + j))
            u0, u1, v0, v1 = j / sides, (j + 1) / sides, i / float(segs), (i + 1) / float(segs)
            uvs.append(((u0, v0), (u1, v0), (u1, v1), (u0, v1)))
    return verts, faces, uvs


def box_col(parts):
    """One _COL mesh of oriented boxes: parts are (centre, u, n, half extents) in metres."""
    bm = bmesh.new()
    for centre, u, n, half in parts:
        c, ax, ay, az = np.asarray(centre, float), np.asarray(u, float), np.asarray(n, float), np.array([0.0, 0.0, 1.0])
        idx = {}
        for su in (-1, 1):
            for sn in (-1, 1):
                for sz in (-1, 1):
                    p = c + ax * (su * half[0]) + ay * (sn * half[1]) + az * (sz * half[2])
                    idx[(su, sn, sz)] = bm.verts.new(tuple((p * S).tolist()))
        for f in [((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)),
                  ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)),
                  ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)),
                  ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)),
                  ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)),
                  ((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1))]:
            bm.faces.new([idx[k] for k in f])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(NAME + "_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(NAME + "_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


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


def att(name, p_m, off):
    e = bpy.data.objects.new(name, None)
    e.location = tuple((float(c) + float(o)) * S for c, o in zip(p_m, off))
    bpy.context.scene.collection.objects.link(e)
    return e


# ---------------------------------------------------------------- the rope
def leg_frame(sign):
    u = np.array([sign * math.sin(HALF), math.cos(HALF)], float)
    return u, np.array([-u[1], u[0]])


def apex_throat():
    return np.array([APEX[0], APEX[1] + RA_A * (1.0 - RA_T), ZB])


def leg_path(sign):
    u, n = leg_frame(sign)
    start = apex_throat()
    return catmull([(start[0] + u[0] * d + n[0] * v, start[1] + u[1] * d + n[1] * v, ZB + dz)
                    for d, v, dz in LEG_CTRL[sign]], 12), u, n


def leg_rfun(span):
    """Radius along a leg: the apex and cleat-eye splice tucks swell each end, a laid line is never a cylinder."""
    def r(t):
        s = t * span
        return (D / 2 * (1.0 + 0.24 * np.exp(-((s / 0.17) ** 2))
                         + 0.20 * np.exp(-(((span - s) / 0.20) ** 2))
                         + 0.030 * np.sin(2 * math.pi * s / 0.62 + 0.7)))
    return r


def serve_rfun():
    """The served chafing wrap: proud of the rope, tapering into it, with the wraps of the serving showing."""
    def r(t):
        win = np.sin(math.pi * np.clip(t, 0.0, 1.0)) ** 0.5
        return D / 2 * (1.13 + 0.30 * win) * (1.0 + 0.065 * win * np.cos(2 * math.pi * 8.0 * t))
    return r


def rope_parts():
    parts, lengths = [], {}
    throat = apex_throat()
    apex = eye_loop(throat, np.array([0.0, -1.0]), RA_A, RA_B, RA_T, 16)
    parts.append(tube(apex, sides=6, segs=16, caps=False))
    lengths["apex eye"] = rope.polyline_length(apex)

    for sign in (-1, 1):
        side = "port" if sign < 0 else "stbd"
        path, u, n = leg_path(sign)
        parts.append(tube(path, sides=6, segs=35, caps=True, r_m=leg_rfun(L_LEG)))
        lengths["leg " + side] = rope.polyline_length(path)

        base = path[-1]                                             # the cleat eye: soft, lying flat
        loop = eye_loop(base, u, RE_A, RE_B, RE_T, 16, tilt=EYE_TILT)
        parts.append(tube(loop, sides=6, segs=16, caps=False))
        lengths["eye " + side] = rope.polyline_length(loop)

        serve = path_slice(path, L_LEG - SERVE_OUT, L_LEG - SERVE_IN)
        parts.append(tube(serve, sides=4, segs=16, caps=True, r_m=serve_rfun()))
        tail = serve[-1] - serve[-2]
        tail /= max(np.linalg.norm(tail), 1e-9)
        parts.append(tube([serve[-1] - tail * 0.011, serve[-1] + tail * 0.011], sides=5, segs=2, caps=True,
                          flat=0.0, r_m=D * 0.80))

        # seizing round the leg and the eye's throat, sitting on deck (the twine cannot go through the planks)
        c = np.array([base[0] + u[0] * 0.012, base[1] + u[1] * 0.012, 0.0135])
        parts.append(twine_ring(c, np.array([-u[1], u[0], 0.0]), np.array([0.0, 0.0, 1.0]), 0.036, 0.0125, 0.0024,
                                sides=4, segs=9))
    c = throat + np.array([0.0, SEIZE_D * 0.97, 0.0065])
    parts.append(twine_ring(c, np.array([1.0, 0.0, 0.0]), np.array([0.0, 0.0, 1.0]), 0.040, 0.014, 0.0026,
                            sides=4, segs=10))
    return parts, lengths


# ---------------------------------------------------------------- the apex hardware
def hardware_parts():
    """The apex thimble, and the 16 mm galvanised bow shackle standing in the hard eye: its pin drops through
    the thimble, its bow lies across the bridle with the crown on the deck, moused with wire at the head."""
    parts = [thimble(APEX + np.array([0.0, -0.008, 0.0]), 0.046, 0.046, 0.0040, 0.0085, sides=5, segs=12)]
    pin_xy = np.array([APEX[0], APEX[1] + 0.010])                   # the pin drops through the eye here
    u2 = np.array([-math.cos(math.radians(35.0)), -math.sin(math.radians(35.0))])
    z_lo, z_hi = ST, ST + SHACKLE_W                                 # the two bow legs, one above the other on deck
    c_xy, r_c = pin_xy + u2 * 0.038, SHACKLE_W / 2.0                # crown centre and bend radius
    arc = [(c_xy + u2 * (-r_c * math.cos(math.radians(a))), z_lo + r_c + r_c * math.sin(math.radians(a)))
           for a in np.linspace(-90.0, 90.0, 7)]
    bow = [(pin_xy, z_lo), (c_xy, z_lo)] + arc[1:-1] + [(c_xy, z_hi), (pin_xy, z_hi)]
    parts.append(tube([(p[0], p[1], z) for p, z in bow], sides=5, segs=18, caps=True, flat=0.0, r_m=ST))
    for z in (z_lo, z_hi):                                          # lug bosses round the pin, one per leg end
        parts.append(tube([(pin_xy[0], pin_xy[1], z - 0.005), (pin_xy[0], pin_xy[1], z + 0.005)],
                          sides=4, segs=1, caps=True, flat=0.0, r_m=ST * 1.6))
    parts.append(tube([(pin_xy[0], pin_xy[1], z_lo - 0.005), (pin_xy[0], pin_xy[1], z_hi + 0.005)],
                      sides=4, segs=3, caps=True, flat=0.0, r_m=ST))
    parts.append(tube([(pin_xy[0], pin_xy[1], z_hi + 0.005), (pin_xy[0], pin_xy[1], z_hi + 0.013)],
                      sides=6, segs=1, caps=True, flat=0.0, r_m=0.0125))
    # mousing wire: out of the pin head, once round the upper bow leg, tucked back at the head
    wc = pin_xy + u2 * 0.020                                        # round the upper bow leg
    wp = np.array([-u2[1], u2[0]])
    ring = [(wc[0] + wp[0] * 0.011 * math.cos(a), wc[1] + wp[1] * 0.011 * math.cos(a), z_hi + 0.011 * math.sin(a))
            for a in np.linspace(-0.6, 2.0 * math.pi + 0.6, 8)]
    wire = [(pin_xy[0], pin_xy[1], z_hi + 0.011),
            (pin_xy[0] + u2[0] * 0.006, pin_xy[1] + u2[1] * 0.006 + 0.004, z_hi + 0.009)] + ring
    parts.append(tube(wire, sides=3, segs=9, caps=False, flat=0.0, r_m=0.0015))
    return [(v, f, remap_v(u)) for v, f, u in parts]


# ---------------------------------------------------------------- scene assembly
def build():
    maketex.write_all(NAME)
    rparts, lengths = rope_parts()
    hparts = hardware_parts()
    total_rope = sum(lengths.values())
    print("[%s] rope %.2f m (%s)" % (NAME, total_rope, ", ".join("%s %.2f" % kv for kv in lengths.items())))

    pts = [p for v, _f, _u in rparts + hparts for p in np.asarray(v)]
    lo = np.array([min(p[i] for p in pts) for i in range(3)]) / S
    hi = np.array([max(p[i] for p in pts) for i in range(3)]) / S
    off = np.array([-(lo[0] + hi[0]) / 2.0, -(lo[1] + hi[1]) / 2.0, -lo[2]], float)

    rope_ob = assemble(NAME + "_LOD0", [(np.asarray(v) + off * S, f, u) for v, f, u in rparts],
                       material("MI_Bridle_Rope", (0.62, 0.60, 0.55), 0.72, 0.0))
    hw_ob = assemble(NAME + "_Hardware_LOD0", [(np.asarray(v) + off * S, f, u) for v, f, u in hparts],
                     material("MI_Bridle_Hardware", (0.55, 0.56, 0.57), 0.40, 1.0))

    def tri(ob):
        ob.data.calc_loop_triangles()
        return len(ob.data.loop_triangles)

    tr, th = tri(rope_ob), tri(hw_ob)
    print("[%s] LOD0 %d tris (rope %d, hardware %d), row ceiling 2500" % (NAME, tr + th, tr, th))

    # collision: low boxes along the apex and each leg (a deck prop's proxy only has to stop feet and a dragged line)
    u_p, n_p = leg_frame(-1)
    u_s, n_s = leg_frame(1)
    throat = apex_throat()
    col = box_col([
        (np.array([APEX[0], APEX[1] + 0.004, 0.028]), np.array([1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0]),
         (RA_B + D, RA_A + RA_T * RA_A + 0.02, 0.028)),
        (np.array([throat[0], throat[1], 0.014]) + np.array([u_p[0], u_p[1], 0.0]) * (L_LEG * 0.5 + 0.05),
         np.array([u_p[0], u_p[1], 0.0]), np.array([n_p[0], n_p[1], 0.0]), (L_LEG * 0.5 + 0.06, 0.055, 0.014)),
        (np.array([throat[0], throat[1], 0.014]) + np.array([u_s[0], u_s[1], 0.0]) * (L_LEG * 0.5 + 0.05),
         np.array([u_s[0], u_s[1], 0.0]), np.array([n_s[0], n_s[1], 0.0]), (L_LEG * 0.5 + 0.06, 0.055, 0.014)),
    ])

    def cleat(sign):
        u, _n = leg_frame(sign)
        return np.array([throat[0], throat[1], ZB]) + np.array([u[0], u[1], 0.0]) * (L_LEG + RE_A * (1.0 - RE_T))
    atts = [
        att("ATT_Grip", tuple(throat + np.array([0.0, 0.012, 0.030])), off),
        att("ATT_Apex", (APEX[0], APEX[1] + 0.010 - 0.024, ST + 0.015), off),
        att("ATT_Cleat_Port", tuple(cleat(-1)), off),
        att("ATT_Cleat_Stbd", tuple(cleat(1)), off),
    ]
    dims = tuple(round(float(v), 3) for v in (hi - lo))
    print("[%s] laid out %.3f x %.3f x %.3f m, %.2f m of rope" % (NAME, dims[0], dims[1], dims[2], total_rope))

    return {
        "name": NAME,
        "budget": "large_prop",
        "tris": 2500,
        "tier": "hero",
        "dims_m": dims,
        "size_note": None,
        "origin": "base",
        "tiling": True,
        "atlas": None,
        "sets": [
            {"name": "Bridle", "set": "Rope", "size": maketex.ROPE_SIZE, "wet": True},
            {"name": "Bridle", "set": "Hardware", "size": maketex.HW_SIZE, "wet": True},
        ],
        "meshes": [{"object": rope_ob, "set": "Rope"}, {"object": hw_ob, "set": "Hardware"}, {"object": col}],
        "attachments": atts,
        "waivers": {
            "LOD UV layout": ("collapse decimation of 6-sided rope tubes and of the sub-centimetre shackle parts "
                              "re-writes loop UVs (the rope's tile V bounds move 0.03 of 31 tiles, the hardware "
                              "area 29% at 128 tris); every LOD samples the same tiling rope trim and the same "
                              "flat hardware square, and LOD2 is only seen from a distance"),
        },
        "closeups": [
            {"name": "apex_shackle", "target": [(APEX[0] + off[0]) * S, (APEX[1] + 0.03 + off[1]) * S, 0.045],
             "dist": 4.5, "az": 22.0, "el": 11.0},
            {"name": "cleat_eye_serve", "target": [
                (throat[0] + u_p[0] * 1.72 + off[0]) * S, (throat[1] + u_p[1] * 1.72 + off[1]) * S, 0.045],
             "dist": 4.0, "az": -128.0, "el": 30.0},
        ],
    }
