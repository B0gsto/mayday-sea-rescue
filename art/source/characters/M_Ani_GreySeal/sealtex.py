"""M_Ani_GreySeal ("Old Ned") textures: two sets, painted in geometry space (pure numpy, no bpy).

  T_Seal_Coat_*   2048  BODY, FORE, HIND, STUD   the body, tail, the four flippers and the back stud
  T_Seal_Face_*   1024  HEAD, EYE                the neck, skull, muzzle block and the bead eyes

r6 (2026-11-01): neutral stone grey (darker top panel, lighter flanks), near-white bib and muzzle, slate flippers with
a lighter rim, eight printed dapples (back, flanks, rump, nape), a light-grey eye ring, roughness ~0.45, darker flipper tips, whisker-pad dots, a black nose pad, glossy black eyes with a white catch-light. No realistic
mottle, scars or skin noise; the height map only carries the mouth, nostrils, dots and digit grooves.

Both sets ship a `_Wet` twin (albedo about 20% darker, roughness about 45% of the dry value) for the runtime
surface swap; check_textures.py checks that the wet maps are darker / glossier.

Every pixel is painted by evaluating the *same* shape maths the mesh was lofted from (seal_shape.py): a texel is
mapped through its region rectangle back to a surface point in metres, so the mouth, the nose and the dots land
exactly on the geometry and nothing seams.
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
    "STUD": (0.928, 0.884, 0.992, 0.948),
    "GROOVE": (0.928, 0.952, 0.948, 0.968),    # r7: the dark seam under the plate, stud rings (small: LOD2 drops them, UV area check)
}
FACE_REGIONS = {
    "HEAD": (0.010, 0.400, 0.674, 0.990),      # u neck split -> nose tip, v around
    "EYE": (0.700, 0.890, 0.780, 0.970),       # the eyeball: u latitude (top -> bottom), v longitude
    "MUZZLE": (0.010, 0.010, 0.300, 0.390),    # r4: the muzzle box sides (u root -> front bevel, v around)
    "MUZZLE_F": (0.330, 0.020, 0.660, 0.223),  # r4: its flat front, projected straight on (x right, z up)
    "NOSE": (0.800, 0.890, 0.900, 0.970),      # r3: the nose block
}

# ---- palette (sRGB values written straight into the 8-bit maps): clean toy plastic cells
# r6: NEUTRAL stone grey, very slightly cool (never brown): a darker top panel, lighter flanks (the step sits on the
# crisp corner bevel), charcoal dapples, a near-white bib, slate flippers with a lighter bevel rim; the plate and studs
# two steps LIGHTER than the back so they pop on it. Body roughness ~0.45 (a soft wet sheen, not a hot streak).
# r7: the sheet's sky adds a blue cast, so the back's albedo sits a touch warm to render neutral (~#7A7E84)
COAT = (0.451, 0.424, 0.408)                   # #736C68 the back (top panel)
FLANK = (0.475, 0.443, 0.427)                  # #79716D the flanks (side panels)
DAPPLE = (0.271, 0.286, 0.302)                 # #45494D printed spots
SEAM = (0.227, 0.243, 0.259)                   # #3A3E42 the stepped seam line between the coat and the belly
BELLY = (0.973, 0.922, 0.824)                  # #F8EBD2 r7: warm off-white bib, belly and throat
MUZZLE = BELLY                                 # the muzzle box, same cell
FLIP = (0.235, 0.251, 0.275)                   # #3C4046 dark slate flippers
FLIP_TIP = (0.200, 0.212, 0.231)               # #33363B a shade darker at the tips
FLIP_RIM = (0.357, 0.376, 0.404)               # #5B6067 the lighter bevel edge round each blade
STUD = (0.620, 0.612, 0.608)                   # #9E9C9B the back plate and studs (r7: renders one step lighter, neutral)
DOT = DAPPLE                                   # whisker dots
NOSE = (0.060, 0.062, 0.066)
MOUTH = (0.165, 0.173, 0.184)
EYE = (0.030, 0.030, 0.040)                    # glossy black bead
GLINT = (0.960, 0.960, 0.955)                  # the white catch-lights
EYE_RING = (0.788, 0.796, 0.800)               # #C9CBCC a light-grey ring round each eye
ROUGH = 0.44                                   # coat; the belly +0.04, flippers 0.42, plate 0.40
# dapples: (y, angle from the top in degrees, radius m) on the body loft, mirrored on both flanks; r5: 6 bigger spots
# (0.6-0.75 stud across) on the back / flanks, clear of the plate
DAPPLES = [(0.66, 62.0, 0.100), (0.33, 60.0, 0.125), (-0.02, 64.0, 0.110),
           (0.88, 40.0, 0.075), (-0.50, 36.0, 0.080)]          # r6: + one on the rump and one on the nape
# whisker dots on the muzzle box's front, beside the nose block: (x, z), mirrored; r5: 1.3x
WHISKER_DOTS = [(0.100, 0.205), (0.072, 0.163), (0.117, 0.160)]
DOT_R = 0.021


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
    """Surface points (rows, cols, 3) for a region's normalised u, v. The mesh UVs space the stations evenly (tu = i /
    (n - 1)) while the loft places them by arc length, so tu goes through the station table (r3)."""
    rows = S.stations(which)
    u = np.interp(tu, np.linspace(0.0, 1.0, len(rows)), [r["u"] for r in rows])
    x, y, z = S.surface(which, np.broadcast_to(u, (tv.shape[0], tu.shape[1])),
                        np.broadcast_to(tv, (tv.shape[0], tu.shape[1])))
    return np.stack([x, y, z], axis=-1)


def flip_t(spec, tu):
    """A flipper / box region's tu -> the blade parameter t (seal.flipper lofts [-0.2] + the secs)."""
    ts = [-0.20] + [s[0] for s in spec["secs"]]
    return np.interp(tu, S.ring_tus(spec), ts)          # r4: the mesh spaces the rings by arc length (ring_tus)


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


# ---------------------------------------------------------------- region painters
def put(alb, hgt, rgh, used, box, col, h, rg):
    r0, r1, c0, c1 = box
    rows, cols = r1 - r0, c1 - c0
    alb[r0:r1, c0:c1] = col.reshape(rows, cols, 3)
    hgt[r0:r1, c0:c1] = h.reshape(rows, cols)
    rgh[r0:r1, c0:c1] = rg.reshape(rows, cols)
    used[r0:r1, c0:c1] = True


def skin_fields(p, up, belly=True, dapples=(), which="body"):
    """(rgb, hgt, rgh) for skin points p (N,3): flat warm-grey plastic, flat darker dapples (body only), a cream belly
    cell stepped in under a dark seam line (the step is geometry: seal_shape.SEAM_*). `up` is 1 on the back and -1 on
    the belly. Matte (roughness >= 0.5) so no glossy streak runs down the spine."""
    col = np.tile(np.array(COAT), (len(p), 1))
    if belly:                                                       # r6: lighter flanks, the step on the corner bevel
        col = mix(col, np.array(FLANK), ss(0.74, 0.66, up))
    for y, a, r in dapples:
        for side in (+1.0, -1.0):
            c = np.array(S._pt_at(y, a, side, which))
            col = mix(col, np.array(DAPPLE), ss(r, r - 0.005, np.linalg.norm(p - c[None, :], axis=1)))
    if not belly:
        return col, np.zeros(len(p)), np.full(len(p), ROUGH - 0.02)
    # r6: on the head the bib rises toward the muzzle (a V under the chin that joins the cream muzzle box)
    lift = 0.0 if which == "body" else 0.30 * ss(-0.82, -1.02, p[:, 1])
    kb = ss(0.0, 1.0, (up - lift - S.SEAM_UP[0]) / (S.SEAM_UP[1] - S.SEAM_UP[0]))
    col = mix(col, np.array(BELLY), kb)
    kl = ss(0.030, 0.012, np.abs(up - 0.5 * (S.SEAM_UP[0] + S.SEAM_UP[1])))   # the line along the step face
    col = mix(col, np.array(SEAM), 0.8 * kl * ss(0.03, 0.0, lift))
    return col, -0.5 * kl, ROUGH + 0.04 * kb


def paint_body(alb, hgt, rgh, used, rng):
    r0, r1, c0, c1, u, v, tu, tv = region_grid(COAT_REGIONS, "BODY", COAT_SIZE)
    p = points_of("body", tu, tv)
    up = np.broadcast_to(np.cos(2.0 * np.pi * tv), (r1 - r0, c1 - c0)).reshape(-1)     # tv: around the loft
    col, h, rg = skin_fields(p.reshape(-1, 3), up, dapples=DAPPLES)
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def paint_flipper(alb, hgt, rgh, used, rng, region):
    spec = [s for s in S.FLIPPERS if s["region"] == region][0]
    r0, r1, c0, c1, u, v, tu, tv = region_grid(COAT_REGIONS, region, COAT_SIZE)
    shape = (r1 - r0, c1 - c0)
    tu = flip_t(spec, tu)
    p = S.flipper_point(spec, tu, tv)
    col, h, rg = skin_fields(np.ascontiguousarray(p).reshape(-1, 3), np.ones(shape[0] * shape[1]), belly=False)
    tuf = np.broadcast_to(tu, shape).reshape(-1)
    # three soft digit grooves near the tip (toy moulding), darker tips
    dline = np.zeros(shape)
    for q in (0.45, 0.0, -0.45):
        vk = (math.asin(q) / (2.0 * math.pi)) % 1.0
        for vv in (vk, (0.5 - vk) % 1.0):
            dv = np.minimum(np.abs(v - vv), 1.0 - np.abs(v - vv))
            dline = np.maximum(dline, ss(0.012, 0.004, dv))
    dl = (dline * ss(0.62, 0.80, np.broadcast_to(tu, shape)) * ss(1.0, 0.94, np.broadcast_to(tu, shape))).reshape(-1)
    col = mix(col, np.array(FLIP), ss(0.0, 0.18, tuf))
    col = mix(col, np.array(FLIP_TIP), ss(0.60, 0.85, tuf))
    de = np.minimum(np.abs(tv - 0.25), np.abs(tv - 0.75))           # r6: a lighter rim along the bevelled edges
    col = mix(col, np.array(FLIP_RIM), (ss(0.065, 0.045, np.broadcast_to(de, shape)) *
                                        ss(0.10, 0.25, np.broadcast_to(tu, shape))).reshape(-1))
    col = mix(col, np.array(NOSE), 0.45 * dl)
    h = h - 0.6 * dl
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def paint_stud(alb, hgt, rgh, used, rng):
    for region, colour in (("STUD", STUD), ("GROOVE", SEAM)):
        r0, r1, c0, c1, u, v, tu, tv = region_grid(COAT_REGIONS, region, COAT_SIZE)
        n = (r1 - r0) * (c1 - c0)
        put(alb, hgt, rgh, used, (r0, r1, c0, c1), np.tile(np.array(colour), (n, 1)), np.zeros(n), np.full(n, ROUGH - 0.04))


def paint_head(alb, hgt, rgh, used, rng):
    """The skull: coat on top, cream throat, a dark ring where each bead eye meets the face plane."""
    r0, r1, c0, c1, u, v, tu, tv = region_grid(FACE_REGIONS, "HEAD", FACE_SIZE)
    shape = (r1 - r0, c1 - c0)
    p = np.ascontiguousarray(points_of("head", tu, tv)).reshape(-1, 3)
    up = np.broadcast_to(np.cos(2.0 * np.pi * tv), shape).reshape(-1)
    col, h, rg = skin_fields(p, up, which="head")              # r5: head and neck clean
    for side in (+1.0, -1.0):
        d = np.linalg.norm(p - np.array(S.eye_centre(side))[None, :], axis=1)
        col = mix(col, np.array(EYE_RING), ss(S.EYE_R + 0.017, S.EYE_R + 0.013, d))     # r5: ~0.045 stud wide
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, h, rg)


def paint_box(alb, hgt, rgh, used, region):
    """The muzzle box (cream, a "w" smile under the nose, three whisker dots a side) and the nose block (black)."""
    spec = S.NOSE if region == "NOSE" else S.MUZZLE
    r0, r1, c0, c1, u, v, tu, tv = region_grid(FACE_REGIONS, region, FACE_SIZE)
    shape = (r1 - r0, c1 - c0)
    n = shape[0] * shape[1]
    if region != "MUZZLE_F":
        col = NOSE if region == "NOSE" else MUZZLE
        put(alb, hgt, rgh, used, (r0, r1, c0, c1), np.tile(np.array(col), (n, 1)), np.zeros(n),
            np.full(n, 0.22 if region == "NOSE" else ROUGH + 0.02))
        return
    w, h = spec["secs"][-1][1], spec["secs"][-1][2]           # the planar front: seal.flipper's `front` cap
    x = np.broadcast_to((tu - 0.5) * 2.0 * w, shape).reshape(-1)
    z = np.broadcast_to(spec["root"][2] + (tv - 0.5) * 2.0 * h, shape).reshape(-1)
    col = np.tile(np.array(MUZZLE), (n, 1))
    dots = np.zeros(n)
    for dx, dz in WHISKER_DOTS:
        for side in (+1.0, -1.0):
            dots = np.maximum(dots, ss(DOT_R, DOT_R - 0.003, np.hypot(x - side * dx, z - dz)))
    col = mix(col, np.array(DOT), dots)
    front = ss(S.MOUTH_HALF + 0.004, S.MOUTH_HALF - 0.004, np.abs(x))   # the "w" spans the nose block's width
    kl = ss(0.0105, 0.0080, np.abs(z - S.mouth_z(x))) * front           # r5: ~0.06 stud thick
    col = mix(col, np.array(MOUTH), 0.9 * kl)
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, -0.30 * dots - 0.6 * kl, np.full(n, ROUGH + 0.02))


def paint_eye(alb, hgt, rgh, used, rng):
    """Glossy black bead with a white catch-light up front-outward (both eyes share it: the right one is mirrored)."""
    r0, r1, c0, c1, u, v, tu, tv = region_grid(FACE_REGIONS, "EYE", FACE_SIZE)
    shape = (r1 - r0, c1 - c0)
    lat = 22.5 + 135.0 * np.broadcast_to(tu, shape).reshape(-1)   # degrees from the top pole (rings 1..7 of 8)
    lon = np.broadcast_to(tv, shape).reshape(-1) * 360.0

    def spot(la, lo, r):
        dlo = (lon - lo + 180.0) % 360.0 - 180.0
        return ss(r, r * 0.7, np.hypot(lat - la, dlo * np.sin(np.radians(np.clip(lat, 10, 170)))))
    col = np.tile(np.array(EYE), (lat.size, 1))
    col = mix(col, np.array(GLINT), np.maximum(spot(40.0, 292.0, 17.0), spot(88.0, 322.0, 9.0)))   # r4: 2nd glint
    put(alb, hgt, rgh, used, (r0, r1, c0, c1), col, np.zeros(lat.size), np.full(lat.size, 0.06))


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
    edge = used.copy()                      # bleed each region 6 texels out, so filtering at a region edge
    for _ in range(6):                      # (the loft's v seam on the back) never picks up the padding colour
        for ax, sh in ((0, 1), (0, -1), (1, 1), (1, -1)):
            src = np.roll(edge, sh, ax)
            grow = src & ~edge
            alb[grow] = np.roll(alb, sh, ax)[grow]
            rgh[grow] = np.roll(rgh, sh, ax)[grow]
            edge = edge | grow
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
    paint_stud(alb, hgt, rgh, used, rng)
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
    paint_box(alb, hgt, rgh, used, "MUZZLE")
    paint_box(alb, hgt, rgh, used, "MUZZLE_F")
    paint_box(alb, hgt, rgh, used, "NOSE")
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


