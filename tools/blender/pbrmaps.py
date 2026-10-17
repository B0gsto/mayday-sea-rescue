"""Pure numpy maths for PBR maps, shared by bake.py (inside Blender) and scan_ingest.py (system python3).

No Blender, no Pillow: imports in Blender's bundled Python (numpy only) and in the system python3. Arrays are float32,
row 0 at the top (image order), values 0..1 unless said otherwise. Albedo maths runs in sRGB-encoded values (what the
PNG stores); `srgb_to_linear` / `linear_to_srgb` convert at the edges.

  write_png            8-bit L / RGB / RGBA PNG writer (zlib, Sub filter), used where Pillow is missing
  downsize             power-of-two box downsample (masters at MASTER -> maps at the set size, at most EXPORT_CAP)
  dilate_index         nearest-covered-texel index for bake padding (one pass shared by every map of a set)
  wear masks           edge wear from curvature, salt crust from AO + cavity, rust streaks running down from edges
  compose              base colour / metal / roughness + masks -> ALB, RGH, MET (docs/12 1.1, 05 5.4; no random grunge)
  clamp_albedo         sRGB luma into check_textures' ranges (non-metal 30..240, metal 180..250)
  wet                  _Wet variants: albedo value x0.75, roughness -0.3 (tune)
  flip_green, unpack_packed, classify_map_name    scan ingest helpers (DirectX -> OpenGL, ARM / ORM, file-name tokens)
"""
import os
import re
import struct
import zlib

import numpy as np

# ---------------------------------------------------------------- colour

def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float32)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4).astype(np.float32)


def linear_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=np.float32), 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055).astype(np.float32)


def parse_color(value):
    """'#RRGGBB', (r, g, b) in 0..1 or (r, g, b) in 0..255 -> sRGB tuple in 0..1."""
    if isinstance(value, str):
        h = value.lstrip("#")
        if len(h) != 6:
            raise ValueError("colour '%s' is not #RRGGBB" % value)
        return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    rgb = tuple(float(v) for v in value[:3])
    return tuple(v / 255.0 for v in rgb) if max(rgb) > 1.0 else rgb


def luma(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / max(e1 - e0, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def to_u8(a):
    return np.clip(np.rint(np.asarray(a, dtype=np.float32) * 255.0), 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- PNG

def write_png(path, arr):
    """Write an 8-bit PNG. arr: uint8 (H, W) -> L, (H, W, 3) -> RGB, (H, W, 4) -> RGBA; float arrays are taken as 0..1."""
    a = np.asarray(arr)
    if a.dtype != np.uint8:
        a = to_u8(a)
    if a.ndim == 2:
        a = a[..., None]
    h, w, c = a.shape
    color_type = {1: 0, 3: 2, 4: 6}[c]
    rows = a.reshape(h, w * c).astype(np.int16)
    sub = rows.copy()
    sub[:, c:] = rows[:, c:] - rows[:, :-c]          # filter 1 (Sub): difference to the pixel on the left
    raw = np.empty((h, w * c + 1), dtype=np.uint8)
    raw[:, 0] = 1
    raw[:, 1:] = (sub & 0xFF).astype(np.uint8)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw.tobytes(), 6)))
        f.write(chunk(b"IEND", b""))
    return path


# ---------------------------------------------------------------- resampling and padding

def downsize(arr, size):
    """Box-downsample a square-ish (H, W[, C]) array so its longer side is `size` (integer factor; power-of-two sizes)."""
    a = np.asarray(arr, dtype=np.float32)
    h, w = a.shape[:2]
    f = max(h, w) // size if size < max(h, w) else 1
    if f <= 1:
        return a
    if h % f or w % f:
        raise ValueError("%dx%d does not divide by %d" % (w, h, f))
    shape = (h // f, f, w // f, f) + a.shape[2:]
    return a.reshape(shape).mean(axis=(1, 3))


def upsample(arr, factor):
    """Nearest-neighbour upsample by an integer factor."""
    if factor <= 1:
        return arr
    return np.repeat(np.repeat(arr, factor, axis=0), factor, axis=1)


def dilate_index(covered, iterations):
    """Flat index of a covered texel for every texel within `iterations` steps (4-neighbour growth), -1 elsewhere.
    Bake padding: maps = flat[idx] where idx >= 0. covered: bool (H, W)."""
    h, w = covered.shape
    idx = np.where(covered.ravel(), np.arange(h * w, dtype=np.int64), -1).reshape(h, w)
    for _ in range(iterations):
        empty = idx < 0
        if not empty.any():
            break
        grown = idx.copy()
        for src, dst in (((slice(None), slice(1, None)), (slice(None), slice(None, -1))),
                         ((slice(None), slice(None, -1)), (slice(None), slice(1, None))),
                         ((slice(1, None), slice(None)), (slice(None, -1), slice(None))),
                         ((slice(None, -1), slice(None)), (slice(1, None), slice(None)))):
            take = empty[dst] & (grown[dst] < 0) & (idx[src] >= 0)
            grown[dst][take] = idx[src][take]
        if (grown == idx).all():
            break
        idx = grown
    return idx


def uv_coverage(tris, size, grow=0.5):
    """Bool (size, size) mask, image order (row 0 = V 1), of the texels whose centre lies inside any UV triangle,
    grown by `grow` pixels so thin slivers count. tris: (N, 3, 2) UVs. Used instead of the bake's alpha, which a
    same-object Cycles bake sets on every texel."""
    mask = np.zeros((size, size), dtype=bool)
    t = np.asarray(tris, dtype=np.float64) * size
    t[..., 1] = size - t[..., 1]                     # V up -> rows down
    for (ax, ay), (bx, by), (cx, cy) in t:
        x0, x1 = int(max(np.floor(min(ax, bx, cx) - 1), 0)), int(min(np.ceil(max(ax, bx, cx) + 1), size))
        y0, y1 = int(max(np.floor(min(ay, by, cy) - 1), 0)), int(min(np.ceil(max(ay, by, cy) + 1), size))
        if x1 <= x0 or y1 <= y0:
            continue
        px, py = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        inside = np.ones(px.shape, dtype=bool)
        area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
        if abs(area) < 1e-12:
            continue
        for (ux, uy), (vx, vy) in (((ax, ay), (bx, by)), ((bx, by), (cx, cy)), ((cx, cy), (ax, ay))):
            ex, ey = vx - ux, vy - uy
            d = (ex * (py - uy) - ey * (px - ux)) * np.sign(area)
            inside &= d >= -grow * np.hypot(ex, ey)
        mask[y0:y1, x0:x1] |= inside
    return mask


def pad(arr, idx, fill):
    """Apply a dilate_index result: texels with idx >= 0 copy their source texel, the rest get `fill`."""
    a = np.asarray(arr, dtype=np.float32)
    h, w = a.shape[:2]
    flat = a.reshape(h * w, -1)
    out = np.empty_like(flat)
    ok = idx.ravel() >= 0
    out[ok] = flat[idx.ravel()[ok]]
    out[~ok] = np.asarray(fill, dtype=np.float32)
    return out.reshape(a.shape)


# ---------------------------------------------------------------- wear masks

WEAR_DEFAULTS = {
    "edge": 0.5,                      # edge-wear amount (0 off): convex curvature reveals edge_color
    "edge_range": (0.12, 0.45),       # convexity smoothstep (curvature 0.5 = flat, 1 = sharp convex)
    "edge_color": (0.55, 0.55, 0.53), # sRGB: worn paint / primer / bare metal
    "edge_rough": 0.4,
    "edge_metal": None,               # None keeps the base metalness; 1 for painted steel chipping to bare metal
    "salt": 0.35,                     # salt crust in cavities and occluded corners
    "salt_range": (0.3, 0.75),
    "salt_color": (0.80, 0.79, 0.75),
    "salt_rough": 0.9,
    "rust": 0.3,                      # rust streaks running down from edges on side-facing surfaces
    "rust_color": (0.40, 0.29, 0.21),
    "rust_rough": 0.85,
    "rust_length": 0.35,              # streak fall-off length as a share of the object's height
    "rust_fingers": 9,                # streak stripes across the bbox (deterministic, from world position)
    "ao_strength": 0.35,              # AO multiplied into albedo (light: the engine adds its own)
    "metal_snap": True,               # MET snapped to 0 / 1 at 0.5 (metalness is binary in PBR; keeps albedo classes clean)
}


def wear_params(wear):
    """WEAR_DEFAULTS updated with a set's "wear" dict; wear False or None turns every mask off."""
    p = dict(WEAR_DEFAULTS)
    if wear is False:
        p.update(edge=0.0, salt=0.0, rust=0.0)
    elif isinstance(wear, dict):
        unknown = set(wear) - set(WEAR_DEFAULTS)
        if unknown:
            raise KeyError("unknown wear field(s) %s; fields are %s" % (", ".join(sorted(unknown)), ", ".join(sorted(WEAR_DEFAULTS))))
        p.update(wear)
    return p


def edge_mask(curv, p):
    convex = np.clip((curv - 0.5) * 2.0, 0.0, 1.0)
    return smoothstep(p["edge_range"][0], p["edge_range"][1], convex)


def salt_mask(ao, curv, p):
    cavity = np.clip((0.5 - curv) * 2.0, 0.0, 1.0)
    return smoothstep(p["salt_range"][0], p["salt_range"][1], (1.0 - ao) * 0.8 + cavity * 0.7)


def rust_streaks(pos, wn, source, covered, p, grid=(48, 48, 96)):
    """Streaks that start at `source` texels (edges) and run down world -Z with an exponential fall-off.
    pos: (H, W, 3) world position normalised to the bbox (0..1); wn: (H, W, 3) world normal (-1..1); source: (H, W).
    The texels are scattered into a voxel grid, propagated downwards, sampled back and kept on side-facing surfaces.
    Deterministic: the only pattern is the stripe `fingers` term from world X / Y."""
    gx, gy, gz = grid
    ix = np.clip((pos[..., 0] * gx).astype(np.int32), 0, gx - 1)
    iy = np.clip((pos[..., 1] * gy).astype(np.int32), 0, gy - 1)
    iz = np.clip((pos[..., 2] * gz).astype(np.int32), 0, gz - 1)
    g = np.zeros(grid, dtype=np.float32)
    m = covered & (source > 0.01)
    np.maximum.at(g, (ix[m], iy[m], iz[m]), source[m].astype(np.float32))
    gp = np.pad(g, ((1, 1), (1, 1), (0, 0)))          # 3x3 max in X / Y: bevelled edges sit a voxel in from the face
    g = np.max([gp[i:i + gx, j:j + gy] for i in range(3) for j in range(3)], axis=0)
    decay = float(np.exp(-1.0 / max(p["rust_length"] * gz, 1e-3)))
    for z in range(gz - 2, -1, -1):
        np.maximum(g[:, :, z], g[:, :, z + 1] * decay, out=g[:, :, z])
    streak = g[ix, iy, iz]
    k = float(p["rust_fingers"])
    fingers = 0.5 + 0.25 * (np.sin(2 * np.pi * k * pos[..., 0] + 1.3) + np.sin(2 * np.pi * k * 1.37 * pos[..., 1] + 0.4))
    side = np.clip(1.0 - np.abs(wn[..., 2]), 0.0, 1.0) ** 2
    return np.clip(streak * smoothstep(0.3, 0.75, fingers) * side, 0.0, 1.0) * covered


def compose(base, metal, rough, ao, curv, pos, wn, covered, wear=None):
    """ALB (sRGB 0..1, H x W x 3), RGH, MET (0..1) and the masks from baked inputs. base is sRGB 0..1."""
    p = wear_params(wear)
    lerp = lambda a, b, t: a + (b - a) * t
    edge_src = edge_mask(curv, p)
    edge = edge_src * p["edge"]
    salt = salt_mask(ao, curv, p) * p["salt"]
    rust = rust_streaks(pos, wn, edge_src, covered, p) * p["rust"] if p["rust"] > 0 else np.zeros_like(ao)
    col = np.asarray(base, dtype=np.float32).copy()
    rgh = np.asarray(rough, dtype=np.float32).copy()
    met = np.asarray(metal, dtype=np.float32).copy()
    for mask, colour, r, mval in ((rust, p["rust_color"], p["rust_rough"], 0.0),
                                  (salt, p["salt_color"], p["salt_rough"], 0.0),
                                  (edge, p["edge_color"], p["edge_rough"], p["edge_metal"])):
        col = lerp(col, np.asarray(parse_color(colour), dtype=np.float32), mask[..., None])
        rgh = lerp(rgh, r, mask)
        if mval is not None:
            met = lerp(met, float(mval), mask)
    col = col * lerp(1.0, np.clip(ao, 0.0, 1.0), p["ao_strength"])[..., None]
    if p["metal_snap"]:
        met = (met >= 0.5).astype(np.float32)
    return {"alb": clamp_albedo(col, met), "rgh": np.clip(rgh, 0.02, 1.0), "met": np.clip(met, 0.0, 1.0),
            "edge": edge, "salt": salt, "rust": rust}


ALB_NONMETAL = (32.0, 238.0)     # a little inside check_textures' 30..240 / 180..250 so 8-bit rounding passes
ALB_METAL = (182.0, 248.0)


def fit_range(y, lo, hi, pct=(1, 99)):
    """Luma values (0..255) moved into [lo, hi] keeping their variation: when the 1st..99th percentile span fits, the
    whole distribution is shifted in; when it does not, it is scaled into the range. Outliers are clamped after."""
    if y.size == 0:
        return y
    p1, p99 = np.percentile(y, pct)
    span = p99 - p1
    if p1 >= lo and p99 <= hi:
        out = y
    elif span <= hi - lo:
        out = y + (min(max(p1, lo), hi - span) - p1)
    else:
        out = lo + (y - p1) * (hi - lo) / span
    return np.clip(out, lo, hi)


def clamp_albedo(rgb, metal):
    """Move sRGB luma (0..255) into the non-metal or metal range (metal = MET above 0.5), per class with fit_range so
    texture variation survives, keeping each pixel's chroma ratios."""
    rgb = np.clip(np.asarray(rgb, dtype=np.float32), 0.0, 1.0)
    y = luma(rgb) * 255.0
    is_metal = np.asarray(metal) > 0.5
    target = y.copy()
    for mask, (lo, hi) in ((~is_metal, ALB_NONMETAL), (is_metal, ALB_METAL)):
        if mask.any():
            target[mask] = fit_range(y[mask], lo, hi)
    scale = np.where(y > 1e-3, target / np.maximum(y, 1e-3), 1.0)
    out = np.clip(rgb * scale[..., None], 0.0, 1.0)
    dark = y <= 1e-3
    if dark.any():
        out[dark] = (target[dark] / 255.0)[..., None]
    return out


def limit_saturation(rgb, s_max):
    """Cap HSV saturation at s_max keeping each pixel's value (max channel) and hue: the other channels move towards
    the max by s_max / sat. Returns (rgb, share of pixels changed)."""
    rgb = np.asarray(rgb, dtype=np.float32)
    mx = rgb.max(axis=2, keepdims=True)
    sat = (mx - rgb.min(axis=2, keepdims=True)) / np.maximum(mx, 1e-6)
    k = np.where(sat > s_max, s_max / np.maximum(sat, 1e-6), 1.0)
    return mx - (mx - rgb) * k, float(np.mean(sat > s_max))


def wet(alb, rgh, darken=0.25, gloss=0.3, floor=0.04):
    """_Wet variants: albedo value scaled by (1 - darken), roughness minus `gloss` (never above dry, floor 0.04)."""
    a = np.asarray(alb, dtype=np.float32) * (1.0 - darken)
    r = np.asarray(rgh, dtype=np.float32)
    return a, np.minimum(r, np.clip(r - gloss, floor, 1.0))


# ---------------------------------------------------------------- scan helpers

def flip_green(nor):
    """DirectX -> OpenGL tangent normal (or back): invert the green channel. nor: (H, W, 3) 0..1 or uint8."""
    a = np.array(nor, copy=True)
    a[..., 1] = (255 - a[..., 1]) if a.dtype == np.uint8 else 1.0 - a[..., 1]
    return a


PACKED_ORDER = {"ARM": ("AO", "RGH", "MET"), "ORM": ("AO", "RGH", "MET")}


def unpack_packed(rgb, kind="ARM"):
    """ARM / ORM (R occlusion, G roughness, B metalness) -> {'AO', 'RGH', 'MET'} single-channel arrays."""
    return {k: np.asarray(rgb)[..., i] for i, k in enumerate(PACKED_ORDER[kind])}


_TOKENS = [   # (alternatives, our kind); packed and DX / GL before the plain names
    ("arm", "ARM"),
    ("orm|occlusion_roughness_metallic", "ORM"),
    ("nor_dx|normal_dx|nrm_dx|dx_normal", "NOR_DX"),
    ("nor_gl|normal_gl|nrm_gl|gl_normal", "NOR_GL"),
    ("nor|normal|nrm|norm|normals", "NOR"),
    ("diff|diffuse|albedo|basecolor|base_color|basecolour|base_colour|color|colour|col|alb", "ALB"),
    ("rough|roughness|rgh", "RGH"),
    ("metal|metallic|metalness|met", "MET"),
    ("ao|ambientocclusion|occlusion|ambient_occlusion", "AO"),
    ("disp|displacement|height|bump", "DISP"),
    ("opacity|alpha|mask", "ALPHA"),
]


def classify_map_name(filename):
    """Our map kind for a scan file name (Poly Haven `rock_wall_diff_2k.png`, ambientCG `Metal032_2K-PNG_NormalGL.png`),
    one of ALB NOR NOR_GL NOR_DX RGH MET AO ARM ORM DISP ALPHA, or None. Resolution tokens (2k, 1K-PNG) are ignored;
    the map token at the end of the name wins (so `metal_plate_ao` is AO), then a token anywhere."""
    stem = os.path.splitext(os.path.basename(filename))[0]
    stem = re.sub(r"([a-z])([A-Z])", r"\1_\2", stem).lower().replace("-", "_").replace(" ", "_")
    stem = re.sub(r"(^|_)\d+k(_png|_jpg|_exr)?(?=$|_)", "", stem).strip("_")
    for tail in (r"$", r"($|_)"):
        for alts, kind in _TOKENS:
            if re.search(r"(^|_)(%s)%s" % (alts, tail), stem):
                return kind
    return None
