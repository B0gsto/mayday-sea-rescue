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
    (+1.105, 0.226, 0.045, 0.040, 0.00),    # 0  tail tip (r6: a blunt end, no pinched point between the flippers)
    (+1.080, 0.224, 0.075, 0.068, 0.00),    #    tail stub
    (+1.035, 0.218, 0.118, 0.115, 0.04),    # 2  tail root, hind flipper root
    (+0.975, 0.210, 0.172, 0.168, 0.10),    #    hips (r6: boxy to the hips, then a short taper)
    (+0.905, 0.206, 0.230, 0.220, 0.17),
    (+0.830, 0.205, 0.268, 0.254, 0.22),
    (+0.740, 0.205, 0.286, 0.268, 0.235),
    (+0.600, 0.206, 0.291, 0.272, 0.24),
    (+0.420, 0.206, 0.292, 0.272, 0.24),
    (+0.240, 0.206, 0.292, 0.272, 0.24),
    (+0.060, 0.206, 0.292, 0.272, 0.24),    # 10 heaviest girth: chest and shoulders (r6: a flat back to the hips)
    (-0.140, 0.206, 0.291, 0.272, 0.24),    #    fore-flipper root
    (-0.290, 0.206, 0.286, 0.267, 0.23),
    (-0.420, 0.207, 0.294, 0.260, 0.21),    #    neck base (r4: the neck ~15 % wider, so the head flows out of it)
    (-0.520, 0.216, 0.294, 0.242, 0.17),    #    r5: the neck ~10 % wider at the torso
    (-0.610, 0.228, 0.272, 0.214, 0.14),
    (-0.680, 0.245, 0.246, 0.192, 0.11),    # 16 SPLIT: body mesh | head mesh
    (-0.740, 0.262, 0.258, 0.226, 0.08),    #    occiput (r4: the skull 8 % narrower, a rounded back edge)
    (-0.800, 0.272, 0.269, 0.246, 0.06),
    (-0.860, 0.276, 0.278, 0.252, 0.05),    # 19 skull widest
    (-0.920, 0.276, 0.278, 0.252, 0.04),
    (-0.975, 0.274, 0.274, 0.248, 0.03),
    (-1.015, 0.272, 0.263, 0.236, 0.02),    # 22 the front bevel (~0.035 m, 0.1 stud)
    (-1.040, 0.271, 0.232, 0.204, 0.01),
    (-1.052, 0.270, 0.175, 0.150, 0.00),
    (-1.058, 0.270, 0.101, 0.088, 0.00),    #    the flat face plane: the eyes sit on it, the muzzle box sticks out
    (-1.060, 0.270, 0.028, 0.025, 0.00),    # 26 face centre (a small closing cap)
]
N_CTRL = len(PROFILE)
SPLIT = 16.0                                  # control index where the body mesh ends and the head mesh begins

# loft station fractions (control index space): even along the body, a little denser through the neck and muzzle
BODY_FRACS = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0,
              8.5, 9.0, 9.5, 10.0, 10.5, 11.0, 11.5, 12.0, 12.5, 13.0, 13.5, 14.0, 14.5, 15.0, 15.5, 16.0]
HEAD_FRACS = [16.0 + 0.4 * i for i in range(20)] + [24.0, 25.0, 26.0]     # r3: the flat face needs few rings


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
    """r5: one shallow crease round the neck (a ~4 % dip on the y -0.645 ring, between the torso and the skull);
    r6: a small collar ledge (the y -0.61 ring 3.5 % proud) just behind it. Returns (scale, taper)."""
    y = np.asarray(y, dtype=float)
    return (1.0 - 0.04 * ss(0.03, 0.0, np.abs(y + 0.645)) + 0.035 * ss(0.02, 0.0, np.abs(y + 0.61)),
            np.zeros_like(y))


def se(x, p):
    """Superellipse factor: sign(x) |x|^p (p < 1 squares a round section off into a bevelled block)."""
    x = np.asarray(x, dtype=float)
    return np.sign(x) * np.abs(x) ** p


BEVEL = 0.036                                 # r6: the torso's crisp corner radius (0.11 stud), hips to the neck
CORNER_K = 3.5                                # r6: ring points crowd the corners (weighted arc length) so they stay crisp
CROWN = 0.004                                 # a hair of crown on the flat panels: collinear rings break the LOD decimate


def corner(rx, rz, y):
    """r6: the section's corner radius: a crisp BEVEL on the torso, rounder toward the tail tip, the head's r5 30 %."""
    m = np.minimum(rx, rz)
    y = np.asarray(y, dtype=float)
    return BEVEL + (0.45 * m - BEVEL) * ss(0.75, 1.0, y) + (0.30 * m - BEVEL) * ss(-0.55, -0.68, y)


def _belly(c, oz, flat):
    """The belly half shorter (`flat`, the hauled-out animal sits flat) and the belly cell stepped in (r3 seam)."""
    kz = np.where(oz >= 0.0, 1.0, 1.0 - flat)
    k = 1.0 - SEAM_STEP * ss(SEAM_UP[0], SEAM_UP[1], c)
    return k, kz * k


def section(a, rx, rz, flat, y=None):
    """Section factors (sin-like, cos-like) at ray angle a (0 top, pi belly) through the rounded-rectangle section;
    used for single surface points (dapple centres, the ear). The loft samples it by `rr_arc` instead."""
    a = np.asarray(a, dtype=float)
    b = 0.30 * np.minimum(rx, rz) if y is None else corner(rx, rz, y)
    ox, oz = rr(a, rx, rz, b)
    k, kz = _belly(np.cos(a), oz, flat)
    return ox / np.maximum(rx, 1e-9) * k, oz / np.maximum(rz, 1e-9) * kz


def rr_arc(v, w, h, b):
    """r6: the rounded rectangle (half size w x h, corner radius b) sampled by weighted arc length: v 0 top centre,
    .25 the right flank's middle, .5 belly, .75 left; the corners get CORNER_K x their share of points."""
    w, h = np.asarray(w, float), np.asarray(h, float)
    b = np.minimum(b, 0.9 * np.minimum(w, h))
    v4 = (np.asarray(v, float) % 1.0) * 4.0
    k = np.floor(v4)
    q = np.where(k % 2 == 1, 1.0 - (v4 - k), v4 - k)
    L1, L2, L3 = w - b, 0.5 * np.pi * b * CORNER_K, h - b
    s = q * (L1 + L2 + L3)
    phi = np.clip((s - L1) / np.maximum(L2, 1e-12), 0.0, 1.0) * 0.5 * np.pi
    t = np.clip((s - L1 - L2) / np.maximum(L3, 1e-12), 0.0, 1.0)
    x = np.where(s < L1, s, np.where(s < L1 + L2, L1 + b * np.sin(phi), w + CROWN * (1.0 - (1.0 - t) ** 2)))
    z = np.where(s < L1, h + CROWN * (1.0 - (s / np.maximum(L1, 1e-12)) ** 2),
                 np.where(s < L1 + L2, L3 + b * np.cos(phi), L3 - (s - L1 - L2)))
    return np.where(k >= 2, -x, x), np.where((k == 1) | (k == 2), -z, z)


SEAM_UP = (-0.17, -0.24)                      # cos(angle) band of the grey / cream step (one loft face at N 48)
SEAM_STEP = 0.06                              # the belly inset, relative (~0.017 m = 0.05 stud on the body)


# ------------------------------------------------------------------ stations (the loft: the one source of truth)
def _stations(fracs):
    rows = []
    for f in fracs:
        y, zc, rx, rz, flat = _profile_frac(f)
        fold, taper = folds(y)
        fold = float(fold)
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
    ox, oz = rr_arc(v, rx, rz, corner(rx, rz, y))          # r6: crisp corners, flat panels
    k, kz = _belly(np.cos(2.0 * np.pi * v), oz, flat)
    return ox * k, y, zc + oz * kz


def surface(which, u, v):
    return point(stations(which), u, v)


# ------------------------------------------------------------------ head landmarks
# r3: the skull ends in a flat face plane (y ~ -1.05); the eyes sit on it above a separate cream muzzle box with a
# black nose block (MUZZLE / NOSE below, lofted like the flippers). The mouth is a painted line round the muzzle box
# at MOUTH_Z; under it the box is the jaw.
EYE_R = 0.081                                     # r4: 90 % of r3 (0.49 stud across)
EYE_C = (0.142, -1.028, 0.388)                    # on the face plane, 2/3 of the ball proud, 0.1 stud clear of the nose
MOUTH_Z = 0.120                                   # the jaw line on the muzzle box (straight build space)
EAR_Y, EAR_A, EAR_R = -0.855, 64.0, 0.011         # no external ear: a small hole behind the eye


def _pt_at(y, a_deg, side=1.0, which="head"):
    zc, rx, rz, flat, u = rows_at_y(which, y)
    a = math.radians(a_deg)
    sx, cz = section(a, rx, rz, flat, y)
    return (side * rx * float(sx), y, zc + rz * float(cz))


MOUTH_HALF = 0.135                                # r5: the painted "w" 1.5x (r4 spanned the nose block only)


def mouth_z(x):
    """The painted "w" smile: a small cusp under the nose, two arcs rising to the corners (r5: r4's 1.5x)."""
    return MOUTH_Z + 2.0 * (np.abs(np.asarray(x, float)) - 0.0675) ** 2


def chan_at_y(which, y):
    """(zc, rx, rz, flat, u) as arrays at body y values (the warps need a whole vertex array at once)."""
    rows = stations(which)
    ys = np.array([r["y"] for r in rows])[::-1]
    out = [np.interp(np.asarray(y, dtype=float), ys, np.array([r[k] for r in rows])[::-1])
           for k in ("zc", "rx", "rz", "flat", "u")]
    return tuple(out)


def eye_centre(side=1.0):
    return (side * EYE_C[0], EYE_C[1], EYE_C[2])


def ear_point(side=1.0):
    return _pt_at(EAR_Y, EAR_A, side)


# ------------------------------------------------------------------ flippers (the loft and the paint share these)
def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-9)


FLIPPERS = [
    # r3: fore 1.22x longer / 1.25x wider paddles splayed out and down to prop the chest; hind a wider (~2 stud) fan
    # of thick wedges in a V. Hard bevels (FLIP_SQ).
    # r4: fore 1.3x thicker; every blade a rounded-rectangle section with a crisp ~0.07 stud bevel (`bevel`, m).
    dict(part="foreL", side=+1.0, root=(0.170, -0.120, 0.118), axis=(0.440, 0.880, -0.190), length=0.500,
         chord="H", droop=0.008, claws=0, scallop=0.0, region="FORE", bevel=0.030,      # r6: 1.12x, squared tips
         secs=[(0.00, 0.098, 0.078), (0.20, 0.122, 0.078), (0.45, 0.134, 0.074), (0.70, 0.136, 0.068),
               (0.90, 0.134, 0.060), (1.00, 0.124, 0.052)]),
    dict(part="hindL", side=+1.0, root=(0.055, 0.860, 0.190), axis=(0.340, 0.940, -0.080), length=0.480,
         chord="X", droop=0.010, claws=0, scallop=0.014, region="HIND", bevel=0.028,     # r6: 1.15x chord
         secs=[(0.00, 0.068, 0.058), (0.20, 0.098, 0.056), (0.40, 0.126, 0.053), (0.60, 0.150, 0.050),
               (0.80, 0.166, 0.047), (0.92, 0.172, 0.045), (1.00, 0.164, 0.042)]),
]

# r3: the muzzle box and the black nose block on its front top edge, lofted with the flipper code (a straight axis,
# flat front faces lofted down to a small cap so they carry paint). r4: the box 1.15x (1.04 x 0.69 studs, top edge
# kept, grown down), a crisp ~0.075 stud front and edge bevel.
MUZZLE = dict(part="head", side=+1.0, root=(0.0, -0.980, 0.145), axis=(0.0, -1.0, 0.0), length=0.280,
              chord="X", droop=0.0, claws=0, scallop=0.0, region="MUZZLE", bevel=0.030, front="MUZZLE_F",
              secs=[(0.00, 0.1725, 0.115), (0.911, 0.1725, 0.115), (0.945, 0.1665, 0.109), (0.975, 0.1575, 0.100),
                    (1.00, 0.1475, 0.090)])           # r4: the flat front is a planar-mapped cap (`front` region)
NOSE = dict(part="head", side=+1.0, root=(0.0, -1.214, 0.231), axis=(0.0, -1.0, 0.0), length=0.063,
            chord="X", droop=0.0, claws=0, scallop=0.0, region="NOSE", bevel=0.020,     # r5: 20 % smaller, top kept,
            secs=[(0.00, 0.072, 0.0425), (0.70, 0.072, 0.0425), (0.85, 0.067, 0.0375), (0.95, 0.059, 0.030),
                  (1.00, 0.020, 0.012)])                                                # rounder corners


def rr(ang, w, h, b):
    """r4 blade section: where the ray at angle ang (0 = +u2 face, a quarter turn = +u1 edge) meets a rounded
    rectangle of half size w x h with corner radius b. Returns (along u1, along u2); scalars or arrays."""
    ang, w, h = np.asarray(ang, float), np.asarray(w, float), np.asarray(h, float)
    s, c = np.sin(ang), np.cos(ang)
    dx, dz = np.abs(s) + 1e-12, np.abs(c) + 1e-12
    b = np.minimum(b, 0.9 * np.minimum(w, h))
    cx, cz = w - b, h - b
    t1, t2 = w / dx, h / dz
    dc = dx * cx + dz * cz
    tc = dc + np.sqrt(np.maximum(dc * dc - (cx * cx + cz * cz) + b * b, 0.0))
    t = np.where(t1 * dz <= cz, t1, np.where(t2 * dx <= cx, t2, tc))
    return np.sign(s) * t * dx, np.sign(c) * t * dz


def ring_tus(spec):
    """r4: UV u of each lofted ring of a flipper / box (the -0.2 root ring + secs), by arc length along the
    (axis, half chord) profile, so tiny bevel rings get little texture and the flat front face gets its share."""
    ts = [-0.20] + [q[0] for q in spec["secs"]]
    ws = [spec["secs"][0][1] * 0.72] + [q[1] for q in spec["secs"]]
    d = np.concatenate([[0.0], np.cumsum(np.hypot(np.diff(ts) * spec["length"], np.diff(ws)))])
    return d / d[-1]


def flipper_frame(spec):
    a = _n(spec["axis"])
    if spec["chord"] == "H":                             # a flat paddle: the chord horizontal, square to the axis
        u1 = _n(np.cross([0.0, 0.0, spec.get("side", 1.0)], a))
        return a, u1, _n(np.cross(a, u1))
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
    ox, oz = rr(2.0 * np.pi * tv, w, h, spec["bevel"])
    return c + u1[None, None, :] * ox[..., None] + u2[None, None, :] * oz[..., None]


# ------------------------------------------------------------------ warps (the face features a loft cannot give)
EAR_DENT = 0.0070


def warp_points(V):
    """The ear holes (r3: the eyes, nose and mouth moved onto the face plane and the muzzle box)."""
    V = np.asarray(V, float).copy()
    zc, rx, rz, flat, _ = chan_at_y("head", V[:, 1])
    n = np.stack([V[:, 0] / np.maximum(rx, 1e-6), np.zeros(len(V)), (V[:, 2] - zc) / np.maximum(rz, 1e-6)], axis=1)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    for side in (+1.0, -1.0):
        de = np.linalg.norm(V - np.array(ear_point(side)), axis=1)
        V -= n * (EAR_DENT * ss(0.016, 0.004, de))[:, None]
    return V


# ------------------------------------------------------------------ r2 rest pose: the raised head and chest
# In game the seal is the static rest mesh, so the rest pose carries the haul-out arch: the spine bends nose-up from
# the chest through the neck, then eases back over the head (a banana arch with the face near level). Applied to the
# finished vertices and the bones; weights and paint stay in the straight build space (UVs are unchanged).
BEND_ZREF = 0.20                                  # the spine line the bend rolls along
BEND_UP = (42.0, 0.05, -0.68)                     # degrees nose-up, ramped over this y range (chest -> neck)
BEND_BACK = (24.0, -0.68, -0.98)                  # eased back over the head (r3: a taller S-curve)


def bend_angle(y):
    y = np.asarray(y, float)
    return np.radians(BEND_UP[0] * ss(BEND_UP[1], BEND_UP[2], y) - BEND_BACK[0] * ss(BEND_BACK[1], BEND_BACK[2], y))


_BG = None


def _bend_grid():
    global _BG
    if _BG is None:
        y = np.arange(BEND_UP[1], -1.6, -0.001)
        f = bend_angle(y)
        dt = np.abs(np.diff(y))
        fm = 0.5 * (f[1:] + f[:-1])
        Y = np.concatenate([[y[0]], y[0] - np.cumsum(np.cos(fm) * dt)])
        Z = np.concatenate([[BEND_ZREF], BEND_ZREF + np.cumsum(np.sin(fm) * dt)])
        _BG = (y[::-1], f[::-1], Y[::-1], Z[::-1])
    return _BG


def bend(P):
    """Points (N,3) in the straight build space -> the arched rest pose (identity behind BEND_UP[1])."""
    P = np.asarray(P, float).reshape(-1, 3).copy()
    yg, fg, Yg, Zg = _bend_grid()
    m = P[:, 1] < BEND_UP[1]
    y = P[m, 1]
    f, Y, Z = np.interp(y, yg, fg), np.interp(y, yg, Yg), np.interp(y, yg, Zg)
    h = P[m, 2] - BEND_ZREF
    P[m, 1] = Y + h * np.sin(f)
    P[m, 2] = Z + h * np.cos(f)
    return P
