"""M_Ani_GreySeal ("Old Ned"): the shared shape maths (pure python + numpy, no bpy).

Imported by seal.py (Blender: loft, rig, weights) and sealtex.py (the two texture sets painted in geometry space).
Everything is in metres, build space: front is -Y (the nose tip at y -1.325), up is +Z, the centre line is x 0, the
belly sits around z 0.06. build.py moves the origin to the bbox centre.

Grey seal bull (Halichoerus grypus), 2.5 m nose to hind-flipper tip, 170 to 310 kg: a heavy spindle-shaped body,
thickest across the chest and shoulders, with no waist and a thick folded neck; a big long head with a straight,
broad Roman nose (no stop), a wide blunt muzzle, two V-shaped nostril slits on top and large dark eyes set high.
The belly is squared off and sits flat on the ground when hauled out.

The profile is a list of control stations along the spine (tail tip first, nose tip last). seal.py lofts it at the
station fractions in BODY_FRACS / HEAD_FRACS with a Catmull-Rom spline; sealtex.py evaluates the same functions, so
the paint (mouth line, nostrils, whisker pores, scars) cannot drift from the geometry.
"""
import math

import numpy as np

# ------------------------------------------------------------------ profile
# (y, zc, rx, rz, flat): y along the body, zc the spine height, rx / rz the half width / half height of a section,
# flat how much shorter the belly half is than the back half (0 round, .22 noticeably flatter).
PROFILE = [
    (+1.105, 0.217, 0.014, 0.013, 0.00),    # 0  tail tip
    (+1.060, 0.213, 0.040, 0.035, 0.00),    #    tail stub
    (+1.000, 0.204, 0.072, 0.076, 0.02),    # 2  tail root, hind flipper root
    (+0.930, 0.192, 0.104, 0.123, 0.05),    #    hips
    (+0.850, 0.183, 0.145, 0.169, 0.10),
    (+0.750, 0.180, 0.188, 0.210, 0.16),
    (+0.640, 0.187, 0.222, 0.233, 0.20),
    (+0.510, 0.195, 0.249, 0.251, 0.22),
    (+0.360, 0.200, 0.270, 0.264, 0.24),
    (+0.190, 0.205, 0.283, 0.269, 0.24),
    (+0.020, 0.206, 0.290, 0.272, 0.24),    # 10 heaviest girth: chest and shoulders
    (-0.140, 0.206, 0.291, 0.272, 0.24),    #    fore-flipper root
    (-0.290, 0.206, 0.284, 0.267, 0.23),
    (-0.420, 0.207, 0.271, 0.258, 0.21),    #    neck base
    (-0.520, 0.214, 0.256, 0.242, 0.18),
    (-0.610, 0.223, 0.240, 0.224, 0.15),
    (-0.680, 0.245, 0.225, 0.195, 0.12),    # 16 SPLIT: body mesh | head mesh
    (-0.740, 0.248, 0.216, 0.192, 0.10),    #    occiput (thick: no waist at the neck)
    (-0.800, 0.252, 0.211, 0.187, 0.08),
    (-0.860, 0.256, 0.206, 0.181, 0.06),    # 19 skull widest
    (-0.915, 0.258, 0.200, 0.173, 0.05),    #    brow, eye level
    (-0.965, 0.258, 0.193, 0.163, 0.04),
    (-1.010, 0.258, 0.185, 0.153, 0.03),    # 22 muzzle base, no stop
    (-1.050, 0.258, 0.176, 0.143, 0.02),    #    Roman nose bridge (long, broad, convex)
    (-1.090, 0.258, 0.166, 0.133, 0.01),
    (-1.125, 0.257, 0.155, 0.122, 0.00),    #    nose pads
    (-1.155, 0.256, 0.143, 0.111, 0.00),    #    nostril slits
    (-1.180, 0.255, 0.130, 0.100, 0.00),    #    blunt nose front
    (-1.198, 0.263, 0.113, 0.085, 0.00),    #    rounded lip, still wide
    (-1.209, 0.276, 0.080, 0.060, 0.00),    # 29 nose tip (a small rounded cap)
]
N_CTRL = len(PROFILE)
SPLIT = 16.0                                  # control index where the body mesh ends and the head mesh begins

# loft station fractions (control index space): even along the body, a little denser through the neck and muzzle
BODY_FRACS = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0,
              8.5, 9.0, 9.5, 10.0, 10.5, 11.0, 11.5, 12.0, 12.5, 13.0, 13.5, 14.0, 14.5, 15.0, 15.5, 16.0]
HEAD_FRACS = [16.0 + 0.4 * i for i in range(int(round((N_CTRL - 1 - 16.0) / 0.4)) + 1)]


def _cr(p0, p1, p2, p3, t):
    """Catmull-Rom at t in 0..1 between p1 and p2."""
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
                  + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


def _profile_frac(f):
    """(y, zc, rx, rz, flat) at control fraction f, per channel Catmull-Rom."""
    n = N_CTRL
    f = min(max(float(f), 0.0), n - 1.0)
    i = int(math.floor(f))
    t = f - i
    out = []
    for k in range(5):
        p0 = PROFILE[max(i - 1, 0)][k]
        p1 = PROFILE[i][k]
        p2 = PROFILE[min(i + 1, n - 1)][k]
        p3 = PROFILE[min(i + 2, n - 1)][k]
        out.append(_cr(p0, p1, p2, p3, t))
    return tuple(out)


def _profile_np(fracs):
    """Vectorised profile: fracs (any shape) -> five stacked arrays."""
    n = N_CTRL
    f = np.clip(np.asarray(fracs, dtype=float), 0.0, n - 1.0)
    i = np.floor(f).astype(int)
    t = f - i
    i0 = np.clip(i - 1, 0, n - 1)
    i1 = i
    i2 = np.clip(i + 1, 0, n - 1)
    i3 = np.clip(i + 2, 0, n - 1)
    P = np.asarray(PROFILE, dtype=float)
    p0, p1, p2, p3 = P[i0], P[i1], P[i2], P[i3]
    tt = t[..., None]
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * tt + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * tt * tt
                  + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * tt * tt * tt)


def ss(e0, e1, x):
    """Smoothstep (e0 > e1 makes it a falling edge). Scalars or numpy arrays."""
    x = np.asarray(x, dtype=float)
    d = float(e1) - float(e0)
    t = np.zeros_like(x) if abs(d) < 1e-12 else np.clip((x - float(e0)) / d, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def folds(y):
    """No ripple: bands across the neck read as stripes and a bull's neck is a smooth, thick mass.
    Kept as a hook (returns a flat 1.0 and no taper) so the paint and rig code that calls it stay valid."""
    return 1.0, np.zeros_like(np.asarray(y, dtype=float))


def section(a, rx, rz, flat):
    """Section factors (sin-like, cos-like) for angle a (0 top, pi belly). The belly half is a superellipse: fuller
    sides and a squared-off bottom, so the hauled-out animal sits flat. Scalars or arrays."""
    s = np.sin(a)
    c = np.cos(a)
    p = 1.0 - 0.18 * ss(0.05, 0.60, -np.asarray(c, dtype=float))       # 1 on the back, 0.76 at the belly
    sx = np.sign(s) * np.abs(s) ** p
    cz = np.sign(c) * np.abs(c) ** p
    kz = np.where(c >= 0.0, 1.0, 1.0 - flat)
    return sx, cz * kz


def _muzzle(y):
    """(top flatten, pad widen) for the Roman nose: a broad flat bridge and swollen whisker pads, no beak."""
    y = np.asarray(y, dtype=float)
    return 1.0 - 0.04 * ss(-0.965, -1.160, y), 1.0 + 0.075 * ss(-0.965, -1.160, y)


# ------------------------------------------------------------------ stations (the loft: the one source of truth)
def _stations(fracs):
    rows = []
    for f in fracs:
        y, zc, rx, rz, flat = _profile_frac(f)
        fold, taper = folds(y)
        rows.append({"frac": f, "y": y, "zc": zc, "rx": rx * fold, "rz": rz * fold,
                     "flat": flat, "fold": fold, "taper": float(taper)})
    acc, last, dist = 0.0, None, []
    total = 0.0
    for r in rows:
        p = (r["y"], r["zc"])
        if last is not None:
            total += math.hypot(p[0] - last[0], p[1] - last[1])
        dist.append(total)
        last = p
    for r, d in zip(rows, dist):
        r["u"] = d / total if total else 0.0
        r["s"] = d
    return rows


_BODY_ROWS = None
_HEAD_ROWS = None


def stations(which):
    """[{'frac','y','zc','rx','rz','flat','fold','u','s'}] for 'body' (tail tip -> the neck split) or 'head'
    (the neck split -> the nose tip). Cached: the same rows drive the loft, the rig and the paint."""
    global _BODY_ROWS, _HEAD_ROWS
    if which == "body":
        if _BODY_ROWS is None:
            _BODY_ROWS = _stations(BODY_FRACS)
        return _BODY_ROWS
    if _HEAD_ROWS is None:
        _HEAD_ROWS = _stations(HEAD_FRACS)
    return _HEAD_ROWS


def _chan(rows, u, key):
    """Piecewise-linear channel lookup by u (matches how the loft spaces its rings)."""
    us = np.array([r["u"] for r in rows])
    vs = np.array([r[key] for r in rows])
    return np.interp(np.asarray(u, dtype=float), us, vs)


def rows_at_y(which, y):
    """(zc, rx, rz, flat, u) interpolated at a body y (the warps and the rig need this, not a station index)."""
    rows = stations(which)
    ys = np.array([r["y"] for r in rows])[::-1]
    out = []
    for key in ("zc", "rx", "rz", "flat", "u"):
        vs = np.array([r[key] for r in rows])[::-1]
        out.append(float(np.interp(y, ys, vs)))
    return tuple(out)


def point(rows, u, v):
    """Surface point(s): u along the loft (0 at the first station), v around (0 top, .25 right, .5 belly, .75 left).
    Scalars or arrays; returns (x, y, z) arrays."""
    u = np.asarray(u, dtype=float)
    v = np.asarray(v, dtype=float)
    zc = _chan(rows, u, "zc")
    rx = _chan(rows, u, "rx")
    rz = _chan(rows, u, "rz")
    flat = _chan(rows, u, "flat")
    y = _chan(rows, u, "y")
    a = 2.0 * np.pi * v
    sx, cz = section(a, rx, rz, flat)
    tf, wide = _muzzle(y)
    x = rx * sx * wide
    z = zc + rz * cz * np.where(np.cos(a) > 0.0, tf, 1.0)
    return x, y, z


def surface(which, u, v):
    return point(stations(which), u, v)


# ------------------------------------------------------------------ head landmarks (all on the undented surface)
# mouth line: (y, angle from the top in degrees) - short, along the low side of the muzzle only, ending under the eye
MOUTH_LINE = [(-1.200, 108.0), (-1.175, 106.0), (-1.145, 104.0), (-1.110, 101.5), (-1.070, 99.0),
              (-1.030, 96.5), (-0.998, 94.0)]
EYE_Y, EYE_A, EYE_R = -0.972, 55.0, 0.0265        # large and dark, high on the head, 45% back from the nose
NOSTRIL_Y, NOSTRIL_A = -1.168, 27.0               # angle from the top: the slits face up and forward
WHISKER_ROWS = [(-1.045, 97.0), (-1.070, 101.0), (-1.095, 105.0), (-1.120, 109.0),
                (-1.145, 113.0), (-1.166, 116.5), (-1.183, 119.5), (-1.196, 122.0)]
BROW_ROWS = [(-0.960, 48.0), (-0.982, 52.0), (-1.004, 56.0)]
EAR_Y, EAR_A, EAR_R = -0.855, 64.0, 0.011         # no external ear: a small hole behind the eye


def _pt_at(y, a_deg, side=1.0, which="head"):
    zc, rx, rz, flat, u = rows_at_y(which, y)
    a = math.radians(a_deg)
    sx, cz = section(a, rx, rz, flat)
    tf, wide = _muzzle(y)
    return (side * rx * float(sx) * wide, y, zc + rz * float(cz) * (float(tf) if math.cos(a) > 0 else 1.0))


def mouth_point(y, side=1.0):
    ys = [p[0] for p in MOUTH_LINE]
    angs = [p[1] for p in MOUTH_LINE]
    a = float(np.interp(y, ys[::-1], angs[::-1]))
    return _pt_at(y, a, side)


def mouth_z(y):
    return np.asarray(mouth_point(y)).reshape(3)[2]


def _u_of_y(which, y):
    rows = stations(which)
    ys = np.array([r["y"] for r in rows])
    us = np.array([r["u"] for r in rows])
    return np.interp(np.asarray(y, dtype=float), ys[::-1], us[::-1])


def chan_at_y(which, y):
    """(zc, rx, rz, flat, u) as arrays at body y values (the warps need a whole vertex array at once)."""
    rows = stations(which)
    ys = np.array([r["y"] for r in rows])[::-1]
    out = [np.interp(np.asarray(y, dtype=float), ys, np.array([r[k] for r in rows])[::-1])
           for k in ("zc", "rx", "rz", "flat", "u")]
    return tuple(out)


def mouth_distance(p):
    """Approximate distance of points p (..., 3) from the mouth line, in the section plane."""
    p = np.asarray(p, dtype=float)
    y = p[..., 1]
    ys = np.array([q[0] for q in MOUTH_LINE])
    angs = np.array([q[1] for q in MOUTH_LINE])
    a_deg = np.interp(np.clip(y, ys[-1], ys[0]), ys[::-1], angs[::-1])
    zc, rx, rz, flat, _ = [_chan(stations("head"), _u_of_y("head", y), k)
                           for k in ("zc", "rx", "rz", "flat", "u")]
    a = np.radians(a_deg)
    sx, cz = section(a, rx, rz, flat)
    mx = rx * sx
    mz = zc + rz * cz
    return np.hypot(np.abs(p[..., 0]) - mx, p[..., 2] - mz)


def eye_centre(side=1.0):
    """Eyeball centre: on the surface point pushed 16 mm radially in, so the ball sits in the socket."""
    p = _pt_at(EYE_Y, EYE_A, side)
    a = math.radians(EYE_A)
    n = np.array([math.sin(a), 0.0, math.cos(a)])
    return (p[0] - 0.016 * n[0], p[1], p[2] - 0.016 * n[2])


def eye_surface_point(side=1.0):
    return _pt_at(EYE_Y, EYE_A, side)


def nostril_point(side=1.0):
    return _pt_at(NOSTRIL_Y, NOSTRIL_A, side)


def ear_point(side=1.0):
    return _pt_at(EAR_Y, EAR_A, side)


def nostril_slits(side=1.0):
    """The three points of one V-shaped nostril slit (apex behind, two arms forward), on the muzzle's top."""
    y0, a0 = NOSTRIL_Y, NOSTRIL_A
    apex = np.array(_pt_at(y0 + 0.006, a0 - 3.0, side))
    outer = np.array(_pt_at(y0 - 0.020, a0 + 7.0, side))
    inner = np.array(_pt_at(y0 - 0.020, a0 - 11.0, side))
    return apex, outer, inner


def whisker_root(y, a_deg, side=1.0):
    return _pt_at(y, a_deg, side)


# ------------------------------------------------------------------ flippers (the loft and the paint share these)
def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-9)


FLIPPERS = [
    dict(part="foreL", side=+1.0, root=(0.190, -0.140, 0.132), axis=(0.220, 0.900, -0.200), length=0.400,
         chord="Z", droop=0.010, claws=5, claw_len=0.024, claw_r=0.0080, scallop=0.0, region="FORE",
         secs=[(0.00, 0.080, 0.045), (0.15, 0.092, 0.042), (0.35, 0.098, 0.036), (0.55, 0.094, 0.028),
               (0.75, 0.080, 0.020), (0.90, 0.058, 0.013), (1.00, 0.028, 0.007)]),
    dict(part="hindL", side=+1.0, root=(0.060, 0.850, 0.185), axis=(0.100, 0.985, -0.120), length=0.470,
         chord="X", droop=0.012, claws=5, claw_len=0.032, claw_r=0.0080, scallop=0.030, region="HIND",
         secs=[(0.00, 0.055, 0.030), (0.18, 0.080, 0.026), (0.38, 0.108, 0.021), (0.58, 0.132, 0.016),
               (0.78, 0.150, 0.012), (0.92, 0.158, 0.008), (1.00, 0.150, 0.005)]),
]


def flipper_frame(spec):
    a = _n(spec["axis"])
    ref = np.array([0.0, 0.0, 1.0]) if spec["chord"] == "Z" else np.array([1.0, 0.0, 0.0])
    u1 = _n(ref - a * float(ref @ a))                    # the chord (the blade's width)
    u2 = _n(np.cross(a, u1))                             # the thickness
    return a, u1, u2


def flipper_centre(spec, t, a=None, u1=None):
    """The blade's centre line: a straight axis with a gentle bow along the chord (a swept paddle)."""
    if a is None or u1 is None:
        a, u1, _ = flipper_frame(spec)
    root = np.asarray(spec["root"], float)
    bow = spec["droop"] * math.sin(math.pi * min(max(t, 0.0), 1.0))
    return root + a * (spec["length"] * t) - u1 * bow


def flipper_section(spec, t):
    """(w, h) half chord / half thickness at t, clamped outside the section list."""
    secs = spec["secs"]
    ts = np.array([s[0] for s in secs])
    w = float(np.interp(t, ts, [s[1] for s in secs]))
    h = float(np.interp(t, ts, [s[2] for s in secs]))
    return w, h


def flipper_point(spec, tu, tv):
    """Surface point(s) of a flipper (tu 0 at the root, tv around: .0 the +u2 face, .25 the +u1 edge, ...)."""
    a, u1, u2 = flipper_frame(spec)
    tu = np.asarray(tu, float)
    tv = np.asarray(tv, float)
    ts = np.array([s[0] for s in spec["secs"]])
    w = np.interp(tu, ts, [s[1] for s in spec["secs"]])
    h = np.interp(tu, ts, [s[2] for s in spec["secs"]])
    bow = spec["droop"] * np.sin(np.pi * np.clip(tu, 0.0, 1.0))
    c = (np.asarray(spec["root"], float)[None, None, :] + a[None, None, :] * (spec["length"] * tu)[..., None]
         - u1[None, None, :] * bow[..., None])
    ang = 2.0 * np.pi * tv
    return c + u1[None, None, :] * (w[..., None] * np.sin(ang)[..., None]) + \
        u2[None, None, :] * (h[..., None] * np.cos(ang)[..., None])


def claw_points(spec, k):
    """(base, direction) of claw k (0..claws-1) at the blade's trailing tip, spread across the chord."""
    a, u1, u2 = flipper_frame(spec)
    n = spec["claws"]
    q = (k - (n - 1) / 2.0) / max(1.0, (n - 1) / 2.0)
    w, _ = flipper_section(spec, 1.0)
    centre = flipper_centre(spec, 1.0, a, u1)
    base = centre + u1 * (q * 0.86 * w) - a * 0.014
    direction = _n(a + u1 * (q * 0.24) - u2 * 0.16)
    return base, direction


# ------------------------------------------------------------------ warps (the face features a loft cannot give)
EYE_SOCKET, EYE_DENT = 0.058, 0.0130
BROW_OUT = 0.0090
NOSTRIL_DENT = 0.0045
MOUTH_DENT = 0.0090
EAR_DENT = 0.0070


def _seg_dist(P, a, b):
    """Distance of points P (N,3) to segment a-b."""
    ab = b - a
    t = np.clip(((P - a[None, :]) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
    return np.linalg.norm(P - (a[None, :] + t[:, None] * ab[None, :]), axis=1)


def warp_points(V):
    """Eye sockets, the brow ridge, the V nostril slits, the ear holes and the mouth line. Applied to the head
    loft's vertices (and to the whisker roots, so the hairs stay planted in the crease)."""
    V = np.asarray(V, float).copy()
    y = V[:, 1]
    zc, rx, rz, flat, _ = chan_at_y("head", y)
    n = np.stack([V[:, 0] / np.maximum(rx, 1e-6), np.zeros_like(y), (V[:, 2] - zc) / np.maximum(rz, 1e-6)], axis=1)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    for side in (+1.0, -1.0):
        c = np.array(eye_centre(side))
        d = np.linalg.norm(V - c, axis=1)
        V -= n * (EYE_DENT * ss(EYE_SOCKET, 0.018, d))[:, None]
        up = V[:, 2] > c[2] + 0.004
        V += n * (BROW_OUT * ss(0.078, 0.034, d) * up)[:, None]
        apex, outer, inner = [np.asarray(q, float) for q in nostril_slits(side)]
        ds = np.minimum(_seg_dist(V, apex, outer), _seg_dist(V, apex, inner))
        V -= n * (NOSTRIL_DENT * ss(0.013, 0.0025, ds))[:, None]
        e = np.array(ear_point(side))
        de = np.linalg.norm(V - e, axis=1)
        V -= n * (EAR_DENT * ss(0.016, 0.004, de))[:, None]
    k = ss(0.016, 0.003, mouth_distance(V))
    V -= n * (MOUTH_DENT * k)[:, None]
    return V
