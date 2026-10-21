"""M_Ani_GreySeal ("Old Ned") textures: two sets, painted in geometry space (pure numpy, no bpy).

  T_Seal_Coat_*   2048  BODY   the body, tail and the four flippers + claws   (heavy, dark, blotched bull coat)
  T_Seal_Face_*   1024  HEAD   the neck folds, skull, Roman-nose muzzle, eyes, whiskers

Both sets ship a `_Wet` twin (albedo about 20% darker, roughness about 45% of the dry value) for the runtime
surface swap; check_textures.py checks that the wet maps are darker / glossier.

Every pixel is painted by evaluating the *same* shape maths the mesh was lofted from (seal_shape.py): a texel is
mapped through its region rectangle back to a surface point in metres, so the mouth line, the nostrils, the whisker
pores, the neck creases and the scars land exactly on the geometry (no UV guesswork), and the blotches are 3D noise
over that point, so nothing seams at the wrap.

Regions (u0, v0, u1, v1; v0 is the bottom of the image, the Blender UV convention), aspect matched to the surface so
the texel density is the same along and around:
  COAT  7.05 studs long, up to 1.66 studs around      FACE  2.27 studs long, up to 2.0 studs around
"""
import math
import os
import struct
import zlib

import numpy as np

import seal_shape as S

COAT_SIZE = 2048
FACE_SIZE = 1024

COAT_REGIONS = {
    "BODY": (0.004, 0.884, 0.488, 0.998),      # u along the spine (tail tip -> neck), v around
    "FORE": (0.512, 0.884, 0.700, 0.998),      # u root -> tip, v around; left and right share it
    "HIND": (0.712, 0.884, 0.900, 0.998),
    "CLAW": (0.928, 0.884, 0.992, 0.948),
}
FACE_REGIONS = {
    "HEAD": (0.010, 0.400, 0.674, 0.990),      # u neck split -> nose tip, v around
    "EYE": (0.700, 0.890, 0.780, 0.970),       # the eyeball seen from outside
    "WHISK": (0.010, 0.020, 0.300, 0.060),
}

# ---- palette (sRGB values written straight into the 8-bit maps; p1 >= 30 and p99 <= 240 with room to spare)
COAT_DARK = (0.185, 0.178, 0.170)              # the dark phase of the blotches, an old bull's back
COAT_MID = (0.335, 0.322, 0.302)
COAT_PALE = (0.560, 0.542, 0.512)              # the pale phase: big irregular blotches over the flank
COAT_MOTTLE = (0.452, 0.436, 0.412)            # the small pale-grey mottle between the blotches
BELLY = (0.420, 0.404, 0.380)                  # worn pale-grey underside
SCAR = (0.610, 0.590, 0.560)
SCAR_PINK = (0.470, 0.360, 0.315)
FLIP_TIP = (0.235, 0.228, 0.222)
CLAW = (0.150, 0.146, 0.142)
WHISKER = (0.600, 0.596, 0.586)               # pale grey, not white
EYE_IRIS = (0.085, 0.078, 0.070)
EYE_PUPIL = (0.045, 0.042, 0.040)
NOSE = (0.190, 0.183, 0.178)
PAD = (0.430, 0.415, 0.398)                    # the whisker pads: paler puffier lobes
LIP = (0.400, 0.385, 0.368)


def write_png(path, arr):
    """arr uint8 HxW (L), HxWx3 (RGB) or HxWx4 (RGBA); row 0 is the top of the image."""
    a = np.ascontiguousarray(arr, dtype=np.uint8)
    h, w = a.shape[:2]
    ch = 1 if a.ndim == 2 else a.shape[2]
    ctype = {1: 0, 3: 2, 4: 6}[ch]
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def u8(x):
    return np.clip(np.round(x * 255.0), 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- noise
def vnoise(p, period, rng):
    """Seamless-in-space value noise at points p (..., 3) in metres: a random grid of cell size `period`."""
    g = rng.random((16, 16, 16))
    q = np.asarray(p, float) / period
    i = np.floor(q).astype(int)
    f = q - i
    f = f * f * (3.0 - 2.0 * f)
    i0, i1 = np.mod(i, 16), np.mod(i + 1, 16)
    c = np.zeros(q.shape[:-1])
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                ix = i1[..., 0] if dx else i0[..., 0]
                iy = i1[..., 1] if dy else i0[..., 1]
                iz = i1[..., 2] if dz else i0[..., 2]
                wx = f[..., 0] if dx else 1.0 - f[..., 0]
                wy = f[..., 1] if dy else 1.0 - f[..., 1]
                wz = f[..., 2] if dz else 1.0 - f[..., 2]
                c += g[ix, iy, iz] * wx * wy * wz
    return c


def fbm3(p, period, rng, octaves=4, gain=0.5):
    out = np.zeros(np.asarray(p).shape[:-1])
    amp, tot = 1.0, 0.0
    per = period
    for _ in range(octaves):
        out += amp * vnoise(p, per, rng)
        tot += amp
        amp *= gain
        per *= 0.5
    return out / tot


def ridge(p, period, rng, octaves=3):
    """1 on the crest lines of a noise field (scars, wrinkles, stretched skin)."""
    n = fbm3(p, period, rng, octaves)
    return np.clip(1.0 - np.abs(n - 0.5) * 6.0, 0.0, 1.0)


def region_grid(regions, name, size):
    """(r0, r1, c0, c1, u, v, tu, tv): pixel range and per-pixel parameters in image row order (row 0 on top)."""
    u0, v0, u1, v1 = regions[name]
    r0, r1 = int(round((1.0 - v1) * size)), int(round((1.0 - v0) * size))
    c0, c1 = int(round(u0 * size)), int(round(u1 * size))
    tu = (np.arange(c1 - c0) + 0.5) / float(c1 - c0)
    tv_img = 1.0 - (np.arange(r1 - r0) + 0.5) / float(r1 - r0)      # row 0 is the top: v = 1 at the top
    u = u0 + tu * (u1 - u0)
    v = v0 + tv_img * (v1 - v0)
    return r0, r1, c0, c1, u[None, :], v[:, None], tu[None, :], tv_img[:, None]


def points_of(which, tu, tv):
    """Surface points (rows, cols, 3) for a region's normalised u, v."""
    x, y, z = S.surface(which, np.broadcast_to(tu, (tv.shape[0], tu.shape[1])),
                        np.broadcast_to(tv, (tv.shape[0], tu.shape[1])))
    return np.stack([x, y, z], axis=-1)


def ss(e0, e1, x):
    d = float(e1) - float(e0)
    t = np.zeros_like(np.asarray(x, float)) if abs(d) < 1e-12 else np.clip((np.asarray(x, float) - e0) / d, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, k):
    """a, b: (3,) colours; k: broadcastable 0..1 (scalar or per-point)."""
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    k = np.asarray(k, float)[..., None]
    return a * (1.0 - k) + b * k


def seg_dist(p, a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
    return np.linalg.norm(p - (a[None, :] + t[:, None] * ab[None, :]), axis=1)


def polyline_dist(p, pts):
    d = None
    for i in range(len(pts) - 1):
        s = seg_dist(p, pts[i], pts[i + 1])
        d = s if d is None else np.minimum(d, s)
    return d


def _scar_path(which, y0, a0, y1, a1, side, bow=0.0, n=8):
    out = []
    for i in range(n):
        t = i / (n - 1.0)
        out.append(S._pt_at(y0 + (y1 - y0) * t, a0 + (a1 - a0) * t + bow * 4.0 * t * (1.0 - t), side, which=which))
    return out


# the old bull's fight record: rakes across the neck and shoulders (a0 in degrees, side +1 / -1)
SCARS = [   # (which, y0, a0, y1, a1, side, half width, kind, bow: degrees of curve at the middle)
    ("body", -0.300, 30.0, -0.520, 96.0, +1, 0.0060, 0, +14.0),
    ("body", -0.180, 42.0, -0.470, 128.0, +1, 0.0048, 1, -10.0),
    ("body", -0.360, 318.0, -0.590, 262.0, -1, 0.0055, 0, +12.0),
    ("body", 0.120, 24.0, -0.090, 70.0, +1, 0.0050, 0, -8.0),
    ("body", 0.640, 40.0, 0.360, 96.0, -1, 0.0045, 2, +10.0),
    ("body", -0.100, 330.0, 0.150, 292.0, -1, 0.0040, 1, -6.0),
    ("head", -0.640, 60.0, -0.830, 104.0, +1, 0.0050, 0, +9.0),
    ("head", -0.960, 300.0, -1.120, 258.0, -1, 0.0040, 0, -7.0),
    ("head", -1.060, 130.0, -1.230, 118.0, +1, 0.0034, 1, +4.0),
    ("head", -0.870, 66.0, -0.930, 82.0, -1, 0.0038, 0, -5.0),
]
_SCAR_CACHE = {}


def scar_paths(key):
    if key not in _SCAR_CACHE:
        out = []
        for which, y0, a0, y1, a1, side, w, kind, bow in SCARS:
            if which != key:
                continue
            out.append((np.array(_scar_path(which, y0, a0, y1, a1, side, bow)), w, kind))
        _SCAR_CACHE[key] = out
    return _SCAR_CACHE[key]


def skin_fields(p, up, which, rng):
    """(rgb, hgt, rgh) for skin points p (N,3): the bull's blotched grey-brown coat, its neck folds and its scars.
    `up` is 1 on the back and -1 on the belly; `which` selects the scar set. The same fields paint the body and the
    head, so the coat runs unbroken across the neck seam."""
    n = p.shape[0]
    b1 = fbm3(p, 0.62, rng, 3)                 # broad tonal drift
    b2 = fbm3(p, 0.30, rng, 4)                 # the blotch field
    b3 = fbm3(p, 0.115, rng, 3)                # ragged blotch edges and mottle
    fine = fbm3(p, 0.028, rng, 3)
    grain = fbm3(p, 0.011, rng, 2)
    t = 0.55 * b1 + 0.45 * b2
    col = mix(np.array(COAT_DARK), np.array(COAT_MID), ss(0.400, 0.610, t))
    # the pale blotches: irregular, two scales, their edges eaten by the fine noise so they read as fur patches
    blot = 0.55 * b2 + 0.45 * b3
    edge = ss(0.520, 0.585, blot) * ss(0.34, 0.56, 0.55 * b1 + 0.45 * b3)
    col = mix(col, np.array(COAT_PALE), 0.88 * edge)
    # mottling everywhere: a pale wash and dark flecks at the blotch scale and below
    mott = ss(0.535, 0.635, 0.55 * b3 + 0.45 * fine)
    col = mix(col, np.array(COAT_MOTTLE), 0.34 * mott)
    col = mix(col, np.array(COAT_DARK), 0.30 * ss(0.560, 0.660, 0.60 * b2 + 0.40 * grain))
    belly = ss(0.20, 0.95, -up)
    col = mix(col, np.array(BELLY), 0.62 * belly)
    col = mix(col, np.array(COAT_DARK), 0.26 * ss(0.25, 0.85, up))
    col *= (1.0 - 0.055 * ss(0.35, 0.75, fine))[..., None]
    col *= (0.955 + 0.075 * grain)[..., None]
    peb = fbm3(p, 0.055, rng, 2)
    hgt = 0.34 * grain + 0.20 * fine + 0.20 * (peb - 0.5)
    rgh = 0.640 + 0.075 * ss(0.25, 0.90, up) - 0.050 * edge + 0.045 * (grain - 0.5) - 0.030 * belly \
        + 0.030 * (mott - 0.5) + 0.070 * (peb - 0.5)
    # fine scratches in the same coat (an old bull is covered in small marks): short and faint, back and flanks only
    scratch = ridge(p, 0.058, rng, 3)
    k = ss(0.76, 0.97, scratch) * (0.20 + 0.80 * ss(-0.3, 0.6, up))
    col = mix(col, np.array(SCAR), 0.12 * k)
    rgh = rgh - 0.05 * k
    # the long rakes
    rag = fbm3(p, 0.022, rng, 2)
    for pts, w, kind in scar_paths(which):
        d = polyline_dist(p, pts)
        kk = ss(w, w * 0.25, d)
        kk = kk * (0.25 + 0.75 * ss(0.34, 0.62, rag))          # broken up along its length: a scratch, not tape
        if kind == 0:
            col = mix(col, np.array(SCAR), 0.45 * kk)
            rgh = rgh - 0.12 * kk
            hgt = hgt + 0.14 * kk
        elif kind == 1:
            col = mix(col, np.array(SCAR_PINK), 0.38 * kk)
            rgh = rgh - 0.16 * kk
            hgt = hgt - 0.30 * kk
        else:
            col = mix(col, np.array(COAT_DARK), 0.45 * kk)
            rgh = rgh + 0.06 * kk
            hgt = hgt - 0.50 * kk
    # the neck folds: a crease in every valley of the ripple that is built into the geometry
    taper = S.folds(p[:, 1])[1]
    crease = taper * (0.5 - 0.5 * np.cos(2.0 * np.pi * (p[:, 1] + 0.6175) / 0.115))
    col *= (1.0 - 0.26 * crease)[..., None]
    rgh = rgh + 0.090 * crease
    hgt = hgt - 0.70 * crease
    # throat and chin pleats, a low tucked fold under the jaw
    pleat = ss(-0.30, -0.55, -p[:, 1]) * ss(0.16, 0.26, p[:, 2]) * (0.5 - 0.5 * np.cos(2.0 * np.pi * p[:, 1] / 0.16))
    hgt = hgt - 0.25 * pleat
    col *= (1.0 - 0.08 * pleat)[..., None]
    return np.clip(col, 0.0, 1.0), hgt, np.clip(rgh, 0.28, 0.95)


# ---------------------------------------------------------------- region painters
def put(alb, hgt, rgh, used, box, col, h, rg):
    r0, r1, c0, c1 = box
    rows, cols = r1 - r0, c1 - c0
    alb[r0:r1, c0:c1] = col.reshape(rows, cols, 3)
    hgt[r0:r1, c0:c1] = h.reshape(rows, cols)
    rgh[r0:r1, c0:c1] = rg.reshape(rows, cols)
    used[r0:r1, c0:c1] = True


def paint_body(alb, hgt, rgh, used, rng):
    r0, r1, c0, c1, u, v, tu, tv = region_grid(COAT_REGIONS, "BODY", COAT_SIZE)
    p = points_of("body", tu, tv)
    up = np.broadcast_to(np.cos(2.0 * np.pi * v), (r1 - r0, c1 - c0)).reshape(-1, 1)[:, 0]
    col, h, rg = skin_fields(p.reshape(-1, 3), up, "body", rng)
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def paint_flipper(alb, hgt, rgh, used, rng, region):
    spec = [s for s in S.FLIPPERS if s["region"] == region][0]
    r0, r1, c0, c1, u, v, tu, tv = region_grid(COAT_REGIONS, region, COAT_SIZE)
    p = S.flipper_point(spec, tu, tv)
    fore = (region == "FORE")
    up = np.broadcast_to(np.sin(2.0 * np.pi * tv) if fore else np.cos(2.0 * np.pi * tv),
                         (r1 - r0, c1 - c0)).reshape(-1, 1)[:, 0]
    col, h, rg = skin_fields(np.ascontiguousarray(p).reshape(-1, 3), up, "flip", rng)
    # the five digits: separations at chord q = +-0.2, +-0.6, deepening toward the tip
    dline = np.zeros((r1 - r0, c1 - c0))
    for q in (0.2, 0.6, -0.2, -0.6):
        vk = (math.asin(q) / (2.0 * math.pi)) % 1.0
        dv = np.minimum(np.abs(v - vk), 1.0 - np.abs(v - vk))
        dline = np.maximum(dline, ss(0.018, 0.004, dv))
    dline = dline * ss(0.26, 0.60, np.broadcast_to(tu, (r1 - r0, c1 - c0))) * \
        (1.0 - 0.55 * ss(0.92, 1.0, np.broadcast_to(tu, (r1 - r0, c1 - c0))))
    dl = dline.reshape(-1)
    col = mix(col, np.array(COAT_DARK), 0.60 * dl)
    h = h - 0.90 * dl
    rg = rg + 0.08 * dl
    tuf = np.broadcast_to(tu, (r1 - r0, c1 - c0)).reshape(-1)
    col = mix(col, np.array(FLIP_TIP), 0.34 * ss(0.48, 0.96, tuf))
    # the blade edges wear pale (callus) on both flippers
    rim = np.maximum(ss(0.032, 0.007, np.abs(v - 0.25)), ss(0.032, 0.007, np.abs(v - 0.75)))
    rim = np.broadcast_to(rim, (r1 - r0, c1 - c0)).reshape(-1)
    col = mix(col, np.array((0.455, 0.438, 0.415)), 0.42 * rim)
    rg = rg - 0.06 * rim
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def paint_claw(alb, hgt, rgh, used, rng):
    r0, r1, c0, c1, u, v, tu, tv = region_grid(COAT_REGIONS, "CLAW", COAT_SIZE)
    tu_b = np.broadcast_to(tu, (r1 - r0, c1 - c0))
    col = mix(np.array(CLAW), np.array((0.400, 0.386, 0.366)), ss(0.35, 0.95, tu_b)).reshape(-1, 3)
    h = (0.10 * ss(0.2, 0.9, tu_b)).reshape(-1)
    rg = np.full(tu_b.size, 0.46)
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def paint_head(alb, hgt, rgh, used, rng):
    r0, r1, c0, c1, u, v, tu, tv = region_grid(FACE_REGIONS, "HEAD", FACE_SIZE)
    shape = (r1 - r0, c1 - c0)
    p3 = points_of("head", tu, tv)
    p = np.ascontiguousarray(p3).reshape(-1, 3)
    up = np.broadcast_to(np.cos(2.0 * np.pi * v), shape).reshape(-1)
    col, h, rg = skin_fields(p, up, "head", rng)
    y, z = p[:, 1], p[:, 2]
    col *= 0.94                                  # the head sits on the neck: match the body's tone, no pale cap
    col *= (1.0 - 0.03 * ss(-1.02, -0.70, y))[..., None]   # ... and no step at the Body | Head seam
    # the grey muzzle and the rubbery nose pads
    col = mix(col, np.array((0.360, 0.350, 0.336)), 0.24 * ss(-0.945, -1.150, y))
    col = mix(col, np.array(NOSE), 0.70 * ss(-1.240, -1.312, y))
    rg = rg - 0.10 * ss(-1.240, -1.312, y)
    # the whisker pads: pale puffy lobes, with a dark pore at every root
    pads = np.zeros(len(p))
    pores = np.zeros(len(p))
    for side in (+1.0, -1.0):
        for (wy, wa) in S.WHISKER_ROWS:
            root = np.array(warp_root(S.whisker_root(wy, wa, side)))
            d = np.linalg.norm(p - root[None, :], axis=1)
            pads = np.maximum(pads, ss(0.042, 0.010, d))
            pores = np.maximum(pores, ss(0.0075, 0.0016, d))
    col = mix(col, np.array(PAD), 0.52 * pads)
    h = h + 0.24 * pads
    rg = rg - 0.07 * pads
    col = mix(col, np.array((0.145, 0.140, 0.134)), 0.70 * pores)
    h = h - 0.45 * pores
    # the closed mouth: a deep dark line with a pale lip outside it
    md = S.mouth_distance(p)
    kl = ss(0.0105, 0.0016, md)
    col = mix(col, np.array((0.098, 0.093, 0.089)), 0.85 * kl)
    h = h - 0.85 * kl
    rg = rg - 0.16 * kl
    lip = ss(0.011, 0.018, md) * ss(0.032, 0.024, md)
    col = mix(col, np.array(LIP), 0.42 * lip)
    # the nostrils: two dark slits on the top of the nose
    for side in (+1.0, -1.0):
        c = np.array(S.nostril_point(side))
        d = np.linalg.norm(p - c[None, :], axis=1)
        kn = ss(0.017, 0.004, d)
        col = mix(col, np.array((0.070, 0.067, 0.064)), 0.85 * kn)
        h = h - 0.95 * kn
    # the eyes: a dark rim and a pale lid ring on the skin (the ball itself is the EYE region)
    for side in (+1.0, -1.0):
        c = np.array(S.eye_surface_point(side))
        d = np.linalg.norm(p - c[None, :], axis=1)
        rim = ss(0.034, 0.018, d)
        col = mix(col, np.array((0.105, 0.100, 0.094)), 0.78 * rim)
        h = h - 0.55 * rim
        rg = rg - 0.14 * rim
        lid = ss(0.058, 0.032, d) * ss(0.022, 0.034, d)
        col = mix(col, np.array((0.470, 0.455, 0.435)), 0.40 * lid)
        h = h + 0.20 * lid
        wrinkle = ss(0.062, 0.034, d) * ridge(p, 0.010, rng, 2) * 0.8
        h = h + 0.30 * wrinkle
    # pale speckle on the crown of an old head
    crown = ss(0.60, 0.95, up) * ss(0.56, 0.78, fbm3(p, 0.055, rng, 2))
    col = mix(col, np.array(SCAR), 0.20 * crown)
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def warp_root(root):
    """The whisker roots are built on the warped skin (seal.py), so the paint must use the same position."""
    return S.warp_points(np.asarray(root, float).reshape(1, 3))[0]


def paint_eye(alb, hgt, rgh, used, rng):
    r0, r1, c0, c1, u, v, tu, tv = region_grid(FACE_REGIONS, "EYE", FACE_SIZE)
    shape = (r1 - r0, c1 - c0)
    uu = np.broadcast_to(tu, shape).reshape(-1)
    vv = np.broadcast_to(tv, shape).reshape(-1)
    r = np.hypot(uu - 0.5, vv - 0.5) / 0.5
    col = np.tile(np.array(EYE_IRIS), (r.size, 1))
    col = mix(col, np.array((0.145, 0.125, 0.105)), 0.55 * ss(0.55, 0.28, r))     # a brown iris ring
    col = mix(col, np.array(EYE_PUPIL), ss(0.34, 0.20, r))                        # the pupil
    glint = ss(0.22, 0.05, np.hypot(uu - 0.38, vv - 0.64) / 0.5)
    col = mix(col, np.array((0.72, 0.74, 0.76)), 0.16 * glint)
    col = mix(col, np.array((0.070, 0.066, 0.062)), ss(0.80, 0.95, r))            # the lid shadow at the rim
    h = 0.35 * ss(0.60, 0.0, r)
    rg = np.full(r.size, 0.085) + 0.10 * ss(0.80, 0.98, r)
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def paint_whisker(alb, hgt, rgh, used, rng):
    r0, r1, c0, c1, u, v, tu, tv = region_grid(FACE_REGIONS, "WHISK", FACE_SIZE)
    shape = (r1 - r0, c1 - c0)
    tu_b = np.broadcast_to(tu, shape).reshape(-1)
    col = mix(np.array(WHISKER) * 0.66, np.array(WHISKER), ss(0.05, 0.55, tu_b)).reshape(-1, 3)
    h = (0.05 * (1.0 - ss(0.0, 0.4, tu_b))).reshape(-1)
    rg = np.full(tu_b.size, 0.54)
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def normal_from_height(hgt, used, strength=2.4):
    hs = hgt * strength
    hu = (np.roll(hs, -1, 1) - np.roll(hs, 1, 1)) * 0.5
    hv = -(np.roll(hs, -1, 0) - np.roll(hs, 1, 0)) * 0.5
    n = np.stack([-hu, -hv, np.ones_like(hs)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    nor = u8(n * 0.5 + 0.5)
    nor[~used] = (128, 128, 255)
    return nor


def _finish(alb, hgt, rgh, used, met=None):
    """Pad the unused atlas area with the set's own mean, then derive the normal map."""
    mean = alb[used].mean(axis=0) if used.any() else np.array([0.4, 0.39, 0.38])
    alb[~used] = mean
    rgh[~used] = float(rgh[used].mean()) if used.any() else 0.7
    hgt[~used] = 0.0
    nor = normal_from_height(hgt, used)
    met = np.zeros(alb.shape[:2], np.uint8) if met is None else met
    return u8(alb), nor, u8(rgh), met


def paint_coat(seed=17):
    rng = np.random.default_rng(seed)
    S_ = COAT_SIZE
    alb = np.zeros((S_, S_, 3))
    hgt = np.zeros((S_, S_))
    rgh = np.full((S_, S_), 0.7)
    used = np.zeros((S_, S_), bool)
    paint_body(alb, hgt, rgh, used, rng)
    paint_flipper(alb, hgt, rgh, used, rng, "FORE")
    paint_flipper(alb, hgt, rgh, used, rng, "HIND")
    paint_claw(alb, hgt, rgh, used, rng)
    return _finish(alb, hgt, rgh, used)


def paint_face(seed=23):
    rng = np.random.default_rng(seed)
    S_ = FACE_SIZE
    alb = np.zeros((S_, S_, 3))
    hgt = np.zeros((S_, S_))
    rgh = np.full((S_, S_), 0.7)
    used = np.zeros((S_, S_), bool)
    paint_head(alb, hgt, rgh, used, rng)
    paint_eye(alb, hgt, rgh, used, rng)
    paint_whisker(alb, hgt, rgh, used, rng)
    return _finish(alb, hgt, rgh, used)


def wet(alb, rgh):
    """The runtime wet state: a darker, glossier skin (validate wants an ALB_Wet and an RGH_Wet per set)."""
    return np.clip(alb.astype(np.float32) * 0.785, 0, 255).astype(np.uint8), \
        np.clip(rgh.astype(np.float32) * 0.45, 0, 255).astype(np.uint8)


def write_sets(out_dir, asset_dir=None, name="Seal"):
    """T_Seal_Coat_* (2048) and T_Seal_Face_* (1024), each with its _Wet twins, into out_dir."""
    written = {}
    for set_name, (alb, nor, rgh, met) in (("Coat", paint_coat()), ("Face", paint_face())):
        alb_w, rgh_w = wet(alb, rgh)
        for kind, arr in (("ALB", alb), ("NOR", nor), ("RGH", rgh), ("MET", met),
                          ("ALB_Wet", alb_w), ("NOR_Wet", nor), ("RGH_Wet", rgh_w), ("MET_Wet", met)):
            path = os.path.join(out_dir, "T_%s_%s_%s.png" % (name, set_name, kind))
            write_png(path, arr)
            written["T_%s_%s_%s" % (name, set_name, kind)] = arr.shape
    return written


if __name__ == "__main__":                     # standalone: python3 sealtex.py <out dir>
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for stem, shape in sorted(write_sets(out).items()):
        print("wrote %s %s" % (stem, shape))


