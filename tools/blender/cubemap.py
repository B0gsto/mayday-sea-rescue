#!/usr/bin/env python3
"""Sky cubemaps for Mayday Sea Rescue: procedural presets and HDRI -> six Roblox `Sky` faces (docs/12 section 1.1,
docs/06 section 2.4). Moved here from art/ocean/bake_skies.py, which is now a shim with the same CLI.

Pure numpy + Pillow (system python3; no heavy slot). The one Blender use is converting an OpenEXR to Radiance first
(see --exr-to-hdr below), because system python3 here has no EXR reader.

Procedural presets (art direction doc 05, section 6.2): every pixel of every face is turned into a world direction and
the sky is evaluated as a function of that direction only, so the six faces of a cube are seamless by construction.
No third-party imagery (no licence). No sun or moon disc (Roblox draws those). Skies are azimuth-uniform at the
horizon (golden hour has a mild warm side) so any sun direction works. Below the horizon every sky is its horizon
colour fading slightly darker (never black); the sea and Atmosphere cover it.

HDRI mode: an equirectangular .hdr (Radiance RGBE, read by read_hdr below) or .exr is sampled per face direction
(bilinear, supersampled when the source is denser than the face), optionally sun-clamped (luminance capped, hue
kept, so Roblox's own sun is the only disc), exposed (EV), tone mapped (aces / reinhard / clip) and sRGB-encoded.
Equirect convention: image centre (u = 0.5) looks at Roblox Front (-Z), u grows turning right (+X at u = 0.75),
image top is +Y; --yaw <deg> turns the panorama (positive = the image content moves to the right of Ft).

Usage:
  python3 tools/blender/cubemap.py [Preset ...] [--out DIR] [--size N]          (default: all five presets, 1024)
  python3 tools/blender/cubemap.py --hdri sky.hdr --name Kloofendal [--out DIR] [--size 1024] [--exposure EV]
          [--tonemap aces|reinhard|clip] [--sun-clamp auto|<linear luminance>] [--yaw DEG]
  ~/RobloxProjects/tools/blender-run.sh tools/blender/cubemap.py -- --exr-to-hdr in.exr out.hdr   (then --hdri out.hdr)
Output: <out>/<Name>_<Face>.png (default out assets/ocean/sky), RGB, Face in Bk Dn Ft Lf Rt Up.
Prints mean colour per face and a numeric seam check (mean |diff| 0-255 across each cube edge, vs the
1-pixel gradient just inside the edge); HDRI mode also prints the source's luminance stats and the sun direction.

Roblox Sky face convention (Roblox world axes: +Y up, right-handed, NormalId Front = -Z, Right = +X).
Each face is a 90-degree pinhole view from the origin, image top = camera up, image right = camera right
(right = look x up), i.e. exactly what a camera with that CFrame would capture:
    SkyboxFt: look -Z, up +Y   (right +X)
    SkyboxBk: look +Z, up +Y   (right -X)
    SkyboxLf: look +X, up +Y   (right +Z)    <- Roblox "Lf" is the +X side (to the right of Ft)
    SkyboxRt: look -X, up +Y   (right -Z)
    SkyboxUp: look +Y, up +X   (image top borders Lf, right -Z)
    SkyboxDn: look -Y, up -X   (image top borders Rt, right -Z)
Source: DevForum "Rendering skyboxes in Studio" capture script (lf = Right normal, rt = Left normal,
up = direction(Top, Right), dn = direction(Bottom, Left)), cross-checked with "Custom Skyboxes 101"
(three.js cubemap nz->Ft, pz->Bk, nx->Lf, px->Rt, py->Up rotated 90 CW, ny->Dn rotated 90 CCW), which
resolves to the same mapping.
"""
import argparse
import math
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

N = 1024                       # literal: the procedural presets were tuned at this size (not SHIP_SIZE / EXPORT_CAP)
ROOT = common.REPO_DIR
OUT = os.path.join(ROOT, "assets", "ocean", "sky")

# face: (look, up); right = look x up
FACES = {
    "Ft": ((0, 0, -1), (0, 1, 0)),
    "Bk": ((0, 0, 1), (0, 1, 0)),
    "Lf": ((1, 0, 0), (0, 1, 0)),
    "Rt": ((-1, 0, 0), (0, 1, 0)),
    "Up": ((0, 1, 0), (1, 0, 0)),
    "Dn": ((0, -1, 0), (-1, 0, 0)),
}


def basis(face):
    look, up = (np.array(a, dtype=np.float64) for a in FACES[face])
    return look, np.cross(look, up), up


def face_dirs(face, n=N):
    look, right, up = basis(face)
    c = (np.arange(n) + 0.5) / n * 2.0 - 1.0
    u = c[None, :]
    v = -c[:, None]
    d = look[None, None, :] + u[..., None] * right + v[..., None] * up
    r = np.linalg.norm(d, axis=-1, keepdims=True)
    # pixel angular size (radians) shrinks toward face corners
    pix = (2.0 / n) / (r[..., 0] ** 2)
    return d / r, pix


# ---------------------------------------------------------------- noise
def _hash(ix, iy, seed):
    h = (ix * np.int64(374761393) + iy * np.int64(668265263) + np.int64(seed) * np.int64(1442695041)) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * np.int64(1274126177)) & 0xFFFFFFFF
    return (h ^ (h >> 16)).astype(np.float64) * (2.0 * np.pi / 4294967296.0)


def perlin(x, y, seed):
    xi = np.floor(x)
    yi = np.floor(y)
    fx = x - xi
    fy = y - yi
    xi = xi.astype(np.int64)
    yi = yi.astype(np.int64)

    def g(ox, oy):
        a = _hash(xi + ox, yi + oy, seed)
        return np.cos(a) * (fx - ox) + np.sin(a) * (fy - oy)

    u = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
    v = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
    a = g(0, 0) + u * (g(1, 0) - g(0, 0))
    b = g(0, 1) + u * (g(1, 1) - g(0, 1))
    return 1.414 * (a + v * (b - a))


def fbm(x, y, octaves, seed, fp, gain=0.5, lac=2.03, ridged=False, billow=False):
    """fBm with per-octave footprint fade (fp = pixel footprint in noise units at frequency 1)."""
    s = np.zeros_like(x)
    amp, f = 1.0, 1.0
    norm = sum(gain ** o for o in range(octaves))
    ca, sa = np.cos(0.62), np.sin(0.62)
    for o in range(octaves):
        w = np.clip(1.0 - (f * fp - 0.2) / 0.3, 0.0, 1.0)
        if not np.any(w > 0):
            break
        n = perlin(x * f + 17.3 * o, y * f - 9.1 * o, seed + 101 * o)
        if ridged:
            n = 1.0 - 2.0 * np.abs(n)
        elif billow:
            n = 2.0 * np.abs(n) - 1.0
        s += amp * w * n
        x, y = x * ca - y * sa, x * sa + y * ca
        amp *= gain
        f *= lac
    return s / norm


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def gradient(stops, elev_deg):
    """Kink-free colour ramp over elevation (degrees); stops = [(deg, hex)], below horizon darkens."""
    grid = np.linspace(-90, 90, 3601)
    degs = [s[0] for s in stops]
    cols = np.array([hexc(s[1]) for s in stops])
    tab = np.stack([np.interp(grid, degs, cols[:, c]) for c in range(3)], -1)
    hor = cols[0]
    below = grid < 0
    tab[below] = hor * (1.0 - 0.14 * smooth(0, 1, -grid[below][:, None] / 50.0))
    k = np.exp(-0.5 * (np.arange(-40, 41) / 14.0) ** 2)
    k /= k.sum()
    pad = np.pad(tab, ((40, 40), (0, 0)), mode="edge")
    tab = np.stack([np.convolve(pad[:, c], k, mode="valid") for c in range(3)], -1)
    return np.stack([np.interp(elev_deg, grid, tab[:, c]) for c in range(3)], -1)


def dome(d, pix, height, offset):
    """Project directions onto a curved cloud layer; returns coords and pixel footprint."""
    dy = np.maximum(d[..., 1], 0.0)
    k = height / (dy + offset)
    fp = pix * k * (1.0 + 0.6 / (dy + offset))
    return d[..., 0] * k, d[..., 2] * k, fp


def streaks(x, z, fp, seed, angle, stretch, cover, octaves=8):
    """Cirrus-like streaked layer density 0..1."""
    ca, sa = np.cos(angle), np.sin(angle)
    rx, rz = x * ca - z * sa, x * sa + z * ca
    wx = fbm(rx * 0.35, rz * 0.35, 4, seed + 1, fp * 0.35)
    wz = fbm(rx * 0.35 + 5.2, rz * 0.35 - 3.1, 4, seed + 2, fp * 0.35)
    qx = (rx + 1.6 * wx) / stretch
    qz = (rz + 1.6 * wz) * 1.3
    fpq = fp * 1.3
    n = fbm(qx, qz, octaves, seed + 3, fpq, gain=0.55)
    fib = fbm(qx * 3.0, qz * 7.0, 5, seed + 4, fpq * 7.0)
    big = fbm(x * 0.12, z * 0.12, 3, seed + 5, fp * 0.12)
    dens = smooth(0.0, 0.55, n + 0.9 * big + (cover - 0.5)) * (0.75 + 0.25 * fib)
    dens *= smooth(-0.1, 0.35, n + 0.12 * fib)
    return np.clip(dens, 0, 1)


# ---------------------------------------------------------------- presets
def sky_clear(d, pix, face):
    e = np.degrees(np.arcsin(np.clip(d[..., 1], -1, 1)))
    col = gradient([(0, "#C9D3D8"), (2, "#C1CDD6"), (6, "#AFC3D4"), (14, "#93B1CF"), (28, "#759DC8"),
                    (50, "#5C88BD"), (90, "#4B78B0")], e)
    x, z, fp = dome(d, pix, 1.0, 0.05)
    c1 = streaks(x * 0.9, z * 0.9, fp * 0.9, 11, 0.5, 3.2, 0.42)
    c2 = streaks(x * 1.7 + 30, z * 1.7, fp * 1.7, 37, 0.62, 2.4, 0.30, 7) * 0.6
    a = np.clip(c1 * 0.62 + c2 * 0.4, 0, 0.8)
    dy = d[..., 1]
    a *= smooth(0.0, 0.10, dy) * (0.55 + 0.45 * smooth(0.02, 0.4, dy))
    cloud = np.array([0.965, 0.975, 0.985]) * (0.97 + 0.03 * smooth(0, 0.5, dy))[..., None]
    cloud = cloud * (1 - 0.35 * smooth(0.3, 0.0, dy))[..., None] + hexc("#C9D3D8") * (0.35 * smooth(0.3, 0.0, dy))[..., None]
    return col * (1 - a[..., None]) + cloud * a[..., None]


def sky_calm(d, pix, face):
    e = np.degrees(np.arcsin(np.clip(d[..., 1], -1, 1)))
    col = gradient([(0, "#E8B48A"), (2.5, "#E2AB81"), (6, "#D9A27A"), (12, "#C2A18C"), (22, "#A2A2A8"),
                    (38, "#8B98AB"), (60, "#7B8DA7"), (90, "#7186A3")], e)
    phi = np.arctan2(d[..., 2], d[..., 0])
    warm = 0.5 + 0.5 * np.cos(phi - 0.7)
    low = np.exp(-np.abs(e) / 14.0)[..., None]
    col = col + (warm - 0.5)[..., None] * low * np.array([0.05, 0.028, 0.008])
    x, z, fp = dome(d, pix, 1.0, 0.045)
    c1 = streaks(x, z, fp, 53, 0.25, 3.8, 0.58)
    c2 = streaks(x * 1.9 - 12, z * 1.9, fp * 1.9, 71, 0.31, 2.6, 0.38, 7) * 0.6
    dens = np.clip(c1 * 0.7 + c2 * 0.45, 0, 1)
    dy = d[..., 1]
    a = dens * 0.95 * smooth(0.0, 0.09, dy)
    lowlit = smooth(0.45, 0.02, dy)[..., None]
    lit = hexc("#FFDAB0") * lowlit + hexc("#E0BFAE") * (1 - lowlit)
    lit = lit + (warm - 0.5)[..., None] * np.array([0.05, 0.025, 0.0])
    under = hexc("#9C8E8E") * (1 - lowlit) + hexc("#D7A07C") * lowlit
    thick = smooth(0.35, 0.9, dens)[..., None]
    cloud = lit * (1 - 0.45 * thick) + under * 0.45 * thick
    return col * (1 - a[..., None]) + cloud * a[..., None]


def sky_overcast(d, pix, face):
    e = np.degrees(np.arcsin(np.clip(d[..., 1], -1, 1)))
    col = gradient([(0, "#A9B0B4"), (4, "#ACB3B7"), (15, "#B2B8BC"), (40, "#B8BEC2"), (90, "#BDC3C6")], e)
    x, z, fp = dome(d, pix, 1.0, 0.035)
    broad = fbm(x * 1.1, z * 1.1, 6, 201, fp * 1.1)
    lumps = fbm(x * 4.5, z * 4.5, 8, 207, fp * 4.5, billow=True, gain=0.52)
    wisp = fbm(x * 2.4 / 2.5, z * 2.4, 6, 211, fp * 2.4)
    dy = d[..., 1]
    contrast = smooth(-0.005, 0.03, dy) * (0.5 + 0.5 * smooth(0.0, 0.35, dy))
    lum = 1.0 + contrast * (0.085 * broad - 0.07 * lumps + 0.035 * wisp)
    return col * lum[..., None]


def sky_storm(d, pix, face):
    e = np.degrees(np.arcsin(np.clip(d[..., 1], -1, 1)))
    col = gradient([(0, "#6F777D"), (3, "#6B7379"), (9, "#646C72"), (20, "#5E666C"), (45, "#555C62"),
                    (90, "#4D5459")], e)
    dy = d[..., 1]
    x, z, fp = dome(d, pix, 1.0, 0.03)
    broad = fbm(x * 0.9, z * 0.9, 6, 301, fp * 0.9)
    rag = fbm(x * 3.5, z * 3.5, 8, 307, fp * 3.5, ridged=True, gain=0.55)
    billow = fbm(x * 2.0, z * 2.0, 7, 311, fp * 2.0, billow=True)
    masses = smooth(-0.35, 0.45, broad + 0.25 * billow)
    contrast = smooth(-0.005, 0.03, dy) * (0.5 + 0.5 * smooth(0.0, 0.3, dy))
    lum = 1.0 + contrast * (0.34 * (0.5 - masses) + 0.10 * rag - 0.06 * billow)
    col = col * lum[..., None]
    # ragged low scud fragments (lower layer => stronger perspective)
    sx, sz, sfp = dome(d, pix, 0.45, 0.02)
    sc = fbm(sx * 1.3, sz * 1.3 * 0.6, 8, 331, sfp * 1.3, gain=0.56)
    sc2 = fbm(sx * 4.0, sz * 4.0, 5, 337, sfp * 4.0, ridged=True)
    sa = smooth(0.02, 0.45, sc + 0.15 * sc2) * 0.8 * smooth(0.0, 0.06, dy) * (0.4 + 0.6 * smooth(0.0, 0.3, dy))
    scud = hexc("#474E54") * (1 + 0.06 * sc2)[..., None]
    col = col * (1 - sa[..., None]) + scud * sa[..., None]
    # lighter rim at the horizon (distant thinner cloud), azimuth-uniform
    col = col + (smooth(0.12, 0.0, np.abs(dy)) * 0.015)[..., None]
    return col


STARS = None


def star_catalog():
    global STARS
    if STARS is not None:
        return STARS
    rng = np.random.default_rng(2026)
    # Milky Way plane: tilted great circle
    mwn = np.array([0.42, 0.55, 0.72])
    mwn /= np.linalg.norm(mwn)

    def rand_dirs(n):
        v = rng.normal(size=(n, 3))
        return v / np.linalg.norm(v, axis=1, keepdims=True)

    d1 = rand_dirs(44000)
    b1 = 0.02 * rng.random(44000) ** (-1 / 1.3)
    # patchy density (star clouds / voids) so the field is not uniform
    cc = rand_dirs(60)
    clus = np.exp(-(1 - d1 @ cc.T) / 0.02).sum(1)
    keep1 = (rng.random(len(d1)) < 0.3 + 0.7 * np.minimum(clus, 1)) | (b1 > 0.3)
    d1, b1 = d1[keep1], b1[keep1]
    # extra faint stars concentrated toward the band
    d2 = rand_dirs(120000)
    w = np.exp(-(d2 @ mwn) ** 2 / (2 * 0.12 ** 2))
    keep = rng.random(len(d2)) < w * 0.22
    d2 = d2[keep]
    b2 = 0.02 * rng.random(len(d2)) ** (-1 / 1.7)
    dirs = np.concatenate([d1, d2])
    b = np.minimum(np.concatenate([b1, b2]), 1.6)
    # colour temperature tint
    t = rng.random(len(b))
    tint = np.where(t[:, None] < 0.2, [0.82, 0.88, 1.0], np.where(t[:, None] > 0.85, [1.0, 0.86, 0.70], [0.95, 0.95, 1.0]))
    STARS = (dirs, b, tint, mwn)
    return STARS


def splat_stars(face, N=N):
    dirs, b, tint, _ = star_catalog()
    look, right, up = basis(face)
    zc = dirs @ look
    ok = zc > 0.3
    dd, bb, tt, zc = dirs[ok], b[ok], tint[ok], zc[ok]
    u = (dd @ right) / zc
    v = (dd @ up) / zc
    m = 1.0 + 6.0 / N
    ok = (np.abs(u) < m) & (np.abs(v) < m)
    dd, bb, tt, u, v = dd[ok], bb[ok], tt[ok], u[ok], v[ok]
    # extinction near horizon
    bb = bb * smooth(-0.01, 0.28, dd[:, 1]) ** 1.5
    px = (u + 1) / 2 * N - 0.5
    py = (1 - v) / 2 * N - 0.5
    img = np.zeros((N + 20, N + 20, 3))
    sig = 0.5 + 0.35 * np.clip(bb, 0, 1.6)
    ix0 = np.floor(px).astype(int)
    iy0 = np.floor(py).astype(int)
    for oy in range(-2, 4):
        for ox in range(-2, 4):
            ix = ix0 + ox
            iy = iy0 + oy
            r2 = (ix - px) ** 2 + (iy - py) ** 2
            g = np.exp(-r2 / (2 * sig ** 2)) + 0.06 * np.clip(bb - 0.4, 0, None) * np.exp(-r2 / (2 * 1.8 ** 2))
            val = (bb * g)[:, None] * tt
            np.add.at(img, (iy + 10, ix + 10), val)
    return img[10:-10, 10:-10]


def sky_night(d, pix, face):
    e = np.degrees(np.arcsin(np.clip(d[..., 1], -1, 1)))
    col = gradient([(0, "#1A2230"), (3, "#161E2B"), (9, "#111824"), (20, "#0C121B"), (45, "#080C13"),
                    (90, "#05080D")], e)
    dy = d[..., 1]
    _, _, _, mwn = star_catalog()
    # faint Milky Way band with dust lanes (direction-based 3D-ish noise via two projections)
    dist = d @ mwn
    band = np.exp(-dist ** 2 / (2 * 0.10 ** 2))
    a = np.arctan2(d[..., 2], d[..., 0])
    mx, mz = d[..., 0] * 6.0 + d[..., 1] * 2.0, d[..., 2] * 6.0 - d[..., 1] * 3.0
    lane = fbm(mx, mz, 6, 401, pix * 6.0 * 1.4)
    clump = fbm(mx * 2.1 + 3, mz * 2.1, 6, 409, pix * 12.0)
    mw = band * np.clip(0.55 + 0.45 * clump - 0.6 * np.clip(lane, 0, 1) * smooth(0.12, 0.0, np.abs(dist)), 0, 1.2)
    mw *= smooth(0.0, 0.35, dy)
    col = col + mw[..., None] * np.array([0.130, 0.145, 0.175])
    stars = splat_stars(face, d.shape[0])
    # thin moonlit cloud wisps that veil stars
    x, z, fp = dome(d, pix, 1.0, 0.05)
    wisp = streaks(x * 0.8, z * 0.8, fp * 0.8, 421, 0.9, 3.5, 0.38, 7)
    wa = np.clip(wisp * 0.9, 0, 0.75) * smooth(0.0, 0.1, dy)
    wc = hexc("#333B47") * (0.85 + 0.25 * smooth(0, 0.6, dy))[..., None]
    col = col + stars * (1 - 0.85 * wa)[..., None] * (dy > -0.02)[..., None]
    col = col * (1 - wa[..., None]) + wc * wa[..., None]
    return col


PRESETS = {"Clear": sky_clear, "Calm": sky_calm, "Overcast": sky_overcast, "Storm": sky_storm, "Night": sky_night}


def to8(col, seed):
    rng = np.random.default_rng(seed)
    v = np.clip(col, 0, 1) * 255.0 + (rng.random(col.shape) + rng.random(col.shape) - 1.0)
    return np.clip(np.round(v), 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- checks
@np.errstate(all="ignore")
def seam_check(imgs):
    """For every face edge, sample the pixel just across the edge on the neighbouring face."""
    N = imgs["Ft"].shape[0]
    worst, across_all, inside_all = 0.0, [], []
    c = (np.arange(N) + 0.5) / N * 2.0 - 1.0
    for f in FACES:
        look, right, up = basis(f)
        for name, (uu, vv, inner) in {
            "top": (c, np.full(N, 1 + 1.0 / N), (0, slice(None))),
            "bot": (c, np.full(N, -1 - 1.0 / N), (N - 1, slice(None))),
            "left": (np.full(N, -1 - 1.0 / N), -c, (slice(None), 0)),
            "right": (np.full(N, 1 + 1.0 / N), -c, (slice(None), N - 1)),
        }.items():
            p = look + uu[:, None] * right + vv[:, None] * up
            p /= np.linalg.norm(p, axis=1, keepdims=True)
            samp = np.zeros((N, 3))
            for g in FACES:
                if g == f:
                    continue
                gl, gr, gu = basis(g)
                z = p @ gl
                mask = z > 0
                gu_ = np.where(mask, (p @ gr) / np.where(mask, z, 1), 9)
                gv_ = np.where(mask, (p @ gu) / np.where(mask, z, 1), 9)
                mask &= (np.abs(gu_) <= 1.0001) & (np.abs(gv_) <= 1.0001)
                if not mask.any():
                    continue
                col = np.clip(((gu_[mask] + 1) / 2 * N).astype(int), 0, N - 1)
                row = np.clip(((1 - gv_[mask]) / 2 * N).astype(int), 0, N - 1)
                samp[mask] = imgs[g][row, col]
            a = imgs[f][inner].astype(np.float64)
            if name == "top":
                b_in = imgs[f][1, :]
            elif name == "bot":
                b_in = imgs[f][N - 2, :]
            elif name == "left":
                b_in = imgs[f][:, 1]
            else:
                b_in = imgs[f][:, N - 2]
            across = np.abs(a - samp).mean()
            inside = np.abs(a - b_in.astype(np.float64)).mean()
            across_all.append(across)
            inside_all.append(inside)
            worst = max(worst, across)
    return float(np.mean(across_all)), worst, float(np.mean(inside_all))


def report_line(name, imgs):
    N = imgs["Ft"].shape[0]
    means = " ".join(f"{f}:#%02X%02X%02X" % tuple(int(x) for x in imgs[f].reshape(-1, 3).mean(0)) for f in FACES)
    hz = imgs["Ft"][N // 2 - 2:N // 2 + 2].reshape(-1, 3).mean(0)
    mean_x, worst, inside = seam_check(imgs)
    return (f"{name}: {means} | horizon Ft #%02X%02X%02X | seam across mean {mean_x:.2f} worst {worst:.2f} "
            f"(inside-edge gradient {inside:.2f})" % tuple(int(x) for x in hz)), (mean_x, worst, inside)


def save_faces(name, imgs, out):
    from PIL import Image
    os.makedirs(out, exist_ok=True)
    for f in FACES:
        Image.fromarray(imgs[f]).save(os.path.join(out, f"{name}_{f}.png"), optimize=True)


@np.errstate(all="ignore")
def bake_presets(names, out=OUT, n=N):
    """The procedural presets, exactly as art/ocean/bake_skies.py made them (dither seed 1000 * index + face)."""
    for pi, name in enumerate(names):
        fn = PRESETS[name]
        imgs = {}
        for fi, f in enumerate(FACES):
            d, pix = face_dirs(f, n)
            col = fn(d, pix, f)
            imgs[f] = to8(col, 1000 * pi + fi)
        save_faces(name, imgs, out)
        print(report_line(name, imgs)[0], flush=True)


# ---------------------------------------------------------------- Radiance RGBE (.hdr)
def _hdr_header(f):
    if not f.readline().startswith(b"#?"):
        raise ValueError("not a Radiance file (no #? magic)")
    fmt = None
    while True:
        line = f.readline()
        if not line:
            raise ValueError("truncated header")
        line = line.strip()
        if not line:
            break
        if line.startswith(b"FORMAT="):
            fmt = line[7:].decode()
    if fmt not in (None, "32-bit_rle_rgbe"):
        raise ValueError("unsupported FORMAT %s (only 32-bit_rle_rgbe)" % fmt)
    m = re.match(rb"([-+])Y (\d+) ([-+])X (\d+)", f.readline().strip())
    if not m:
        raise ValueError("unsupported resolution line (need -Y H +X W or similar)")
    return m.group(1), int(m.group(2)), m.group(3), int(m.group(4))


def read_hdr(path):
    """Radiance .hdr -> float32 (H, W, 3) linear RGB, row 0 = top. New-style RLE and flat scanlines."""
    with open(path, "rb") as f:
        ysign, h, xsign, w = _hdr_header(f)
        data = f.read()
    buf = np.frombuffer(data, dtype=np.uint8)
    rgbe = np.empty((h, w, 4), dtype=np.uint8)
    pos = 0
    for y in range(h):
        if 8 <= w < 32768 and data[pos] == 2 and data[pos + 1] == 2 and (data[pos + 2] << 8 | data[pos + 3]) == w:
            pos += 4
            for ch in range(4):
                row = rgbe[y, :, ch]
                x = 0
                while x < w:
                    count = data[pos]
                    pos += 1
                    if count > 128:
                        count -= 128
                        row[x:x + count] = data[pos]
                        pos += 1
                    else:
                        if count == 0:
                            raise ValueError("bad RLE run at scanline %d" % y)
                        row[x:x + count] = buf[pos:pos + count]
                        pos += count
                    x += count
        else:  # flat (uncompressed) scanline
            rgbe[y] = buf[pos:pos + 4 * w].reshape(w, 4)
            pos += 4 * w
    e = rgbe[..., 3].astype(np.int32)
    scale = np.where(e > 0, np.ldexp(1.0, e - 136), 0.0).astype(np.float32)
    img = (rgbe[..., :3].astype(np.float32) + 0.5) * scale[..., None]
    if ysign == b"+":
        img = img[::-1]
    if xsign == b"-":
        img = img[:, ::-1]
    return np.ascontiguousarray(img)


def write_hdr(path, img, rle=True):
    """float (H, W, 3) -> Radiance .hdr (-Y H +X W). Used by the tests and as a debug output."""
    img = np.maximum(np.asarray(img, dtype=np.float64), 0.0)
    h, w = img.shape[:2]
    mx = img.max(-1)
    mant, ex = np.frexp(mx)
    ok = mx > 1e-32
    sc = np.where(ok, mant * 256.0 / np.where(ok, mx, 1.0), 0.0)
    rgbe = np.zeros((h, w, 4), dtype=np.uint8)
    rgbe[..., :3] = np.clip(np.floor(img * sc[..., None]), 0, 255).astype(np.uint8)
    rgbe[..., 3] = np.where(ok, ex + 128, 0).astype(np.uint8)
    out = bytearray(b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y %d +X %d\n" % (h, w))
    for y in range(h):
        if not rle or not 8 <= w < 32768:
            out += rgbe[y].tobytes()
            continue
        out += bytes((2, 2, w >> 8, w & 255))
        for ch in range(4):
            row = rgbe[y, :, ch].tobytes()
            x = 0
            while x < w:
                run = 1
                while x + run < w and run < 127 and row[x + run] == row[x]:
                    run += 1
                if run >= 4:
                    out += bytes((128 + run, row[x]))
                    x += run
                    continue
                start = x
                while x < w and x - start < 128 and not (x + 3 < w and row[x] == row[x + 1] == row[x + 2] == row[x + 3]):
                    x += 1
                out += bytes((x - start,)) + row[start:x]
    with open(path, "wb") as f:
        f.write(bytes(out))


def read_hdri(path):
    if path.lower().endswith(".exr"):
        hdr = os.path.splitext(path)[0] + ".hdr"
        if os.path.isfile(hdr):
            return read_hdr(hdr)
        raise SystemExit("no EXR reader in system python3; convert first:\n  ~/RobloxProjects/tools/blender-run.sh "
                         "tools/blender/cubemap.py -- --exr-to-hdr %s %s" % (path, hdr))
    return read_hdr(path)


# ---------------------------------------------------------------- equirect -> faces
LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def equirect_uv(d, yaw_deg=0.0):
    """Roblox world direction(s) -> equirect (u, v) in 0..1; u = 0.5 looks at -Z (Ft), u grows towards +X, v = 0 top."""
    lon = np.arctan2(d[..., 0], -d[..., 2]) - math.radians(yaw_deg)
    u = (lon / (2 * np.pi) + 0.5) % 1.0
    v = 0.5 - np.arcsin(np.clip(d[..., 1], -1, 1)) / np.pi
    return u, v


def sample_bilinear(img, u, v):
    h, w = img.shape[:2]
    x = u * w - 0.5
    y = np.clip(v * h - 0.5, 0, h - 1)
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = (x - x0)[..., None].astype(np.float32)
    fy = (y - y0)[..., None].astype(np.float32)
    x0 %= w
    x1 = (x0 + 1) % w
    y1 = np.minimum(y0 + 1, h - 1)
    top = img[y0, x0] * (1 - fx) + img[y0, x1] * fx
    bot = img[y1, x0] * (1 - fx) + img[y1, x1] * fx
    return top * (1 - fy) + bot * fy


def sun_clamp(img, limit):
    """Cap luminance at `limit` (hue kept). 'auto' = 4 x the 99.5th percentile of the upper hemisphere.
    Returns (img, limit, clamped pixel count)."""
    lum = img @ LUMA
    if limit == "auto":
        upper = lum[: img.shape[0] // 2]
        limit = float(np.percentile(upper, 99.5)) * 4.0
    limit = float(limit)
    over = lum > limit
    scale = np.where(over, limit / np.maximum(lum, 1e-12), 1.0).astype(np.float32)
    return img * scale[..., None], limit, int(over.sum())


def tonemap(x, mode):
    if mode == "aces":      # Narkowicz 2015 fit
        x = x * 0.6
        return np.clip((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0, 1)
    if mode == "reinhard":
        return x / (1.0 + x)
    return np.clip(x, 0, 1)


def srgb_encode(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * np.power(x, 1 / 2.4) - 0.055)


def hdri_face(src, face, n, yaw=0.0, ss=None):
    """Linear radiance (n, n, 3) for one face, supersampled ss x ss (auto from source density)."""
    if ss is None:
        ss = int(min(4, max(1, math.ceil(src.shape[1] / (4.0 * n)))))
    acc = np.zeros((n, n, 3), dtype=np.float32)
    for sy in range(ss):
        for sx in range(ss):
            look, right, up = basis(face)
            c_u = (np.arange(n) + (sx + 0.5) / ss) / n * 2.0 - 1.0
            c_v = (np.arange(n) + (sy + 0.5) / ss) / n * 2.0 - 1.0
            d = look[None, None, :] + c_u[None, :, None] * right - c_v[:, None, None] * up
            d /= np.linalg.norm(d, axis=-1, keepdims=True)
            u, v = equirect_uv(d, yaw)
            acc += sample_bilinear(src, u, v)
    return acc / (ss * ss)


def sun_direction(src, yaw=0.0):
    """Brightest equirect pixel -> Roblox direction (x, y, z), elevation and azimuth (deg, 0 = Ft, + towards +X)."""
    lum = src @ LUMA
    iy, ix = np.unravel_index(int(np.argmax(lum)), lum.shape)
    h, w = lum.shape
    lon = ((ix + 0.5) / w - 0.5) * 2 * np.pi + math.radians(yaw)
    lat = (0.5 - (iy + 0.5) / h) * np.pi
    d = (math.cos(lat) * math.sin(lon), math.sin(lat), -math.cos(lat) * math.cos(lon))
    return d, math.degrees(lat), math.degrees(lon), float(lum[iy, ix])


@np.errstate(all="ignore")
def bake_hdri(path, name, out=OUT, n=N, exposure=0.0, tone="aces", clamp=None, yaw=0.0):
    src = read_hdri(path)
    lum = src @ LUMA
    d, el, az, peak = sun_direction(src, yaw)
    print(f"{os.path.basename(path)}: {src.shape[1]}x{src.shape[0]} lum median {np.median(lum):.3f} "
          f"p99.5 {np.percentile(lum, 99.5):.3f} max {peak:.1f} | sun dir ({d[0]:.3f}, {d[1]:.3f}, {d[2]:.3f}) "
          f"elev {el:.1f} az {az:.1f}", flush=True)
    if clamp is not None:
        src, limit, count = sun_clamp(src, clamp)
        print(f"sun clamp: luminance <= {limit:.3f}, {count} source pixels clamped", flush=True)
    imgs = {}
    gain = 2.0 ** exposure
    for fi, f in enumerate(FACES):
        lin = hdri_face(src, f, n, yaw) * gain
        imgs[f] = to8(srgb_encode(tonemap(lin, tone)), fi)
    save_faces(name, imgs, out)
    line, seams = report_line(name, imgs)
    print(line, flush=True)
    return imgs, seams


# ---------------------------------------------------------------- CLI
def _exr_to_hdr(src, dst):
    """Inside Blender only: load an OpenEXR and save it as Radiance HDR (float, linear)."""
    import bpy
    img = bpy.data.images.load(os.path.abspath(src))
    img.filepath_raw = os.path.abspath(dst)
    img.file_format = "HDR"
    img.save()
    print("wrote", dst, tuple(img.size))


def main(argv=None):
    if argv is None:
        argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("presets", nargs="*", help="procedural presets (%s); default all" % ", ".join(PRESETS))
    ap.add_argument("--out", default=OUT, help="output folder (default assets/ocean/sky)")
    ap.add_argument("--size", type=int, default=N, help="face size in pixels (default 1024, the tuned size)")
    ap.add_argument("--hdri", help="equirect .hdr (or .exr with a converted .hdr beside it)")
    ap.add_argument("--name", help="sky name for --hdri outputs (<name>_<Face>.png), PascalCase")
    ap.add_argument("--exposure", type=float, default=0.0, help="EV applied before tone mapping")
    ap.add_argument("--tonemap", choices=("aces", "reinhard", "clip"), default="aces")
    ap.add_argument("--sun-clamp", default=None, help="'auto' or a linear luminance cap (removes the sun disc)")
    ap.add_argument("--yaw", type=float, default=0.0, help="turn the panorama (degrees)")
    ap.add_argument("--exr-to-hdr", nargs=2, metavar=("EXR", "HDR"), help="(inside Blender) convert and exit")
    a = ap.parse_args(argv)
    if a.exr_to_hdr:
        return _exr_to_hdr(*a.exr_to_hdr)
    if a.hdri:
        name = a.name or re.sub(r"[^A-Za-z0-9]", "", os.path.splitext(os.path.basename(a.hdri))[0].title())
        clamp = None if a.sun_clamp is None else (a.sun_clamp if a.sun_clamp == "auto" else float(a.sun_clamp))
        bake_hdri(a.hdri, name, a.out, a.size, a.exposure, a.tonemap, clamp, a.yaw)
        return
    unknown = [p for p in a.presets if p not in PRESETS]
    if unknown:
        ap.error("unknown preset(s) %s; choose from %s" % (", ".join(unknown), ", ".join(PRESETS)))
    bake_presets(a.presets or list(PRESETS), a.out, a.size)


if __name__ == "__main__":
    main()
