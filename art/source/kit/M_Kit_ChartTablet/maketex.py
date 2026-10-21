"""M_Kit_ChartTablet: procedural PBR maps for the asset's one set, T_ChartTablet_Kit_* (dry + _Wet).

Called by build.py (inside Blender, numpy only) with the textures directory, before validate looks for the maps.
Every lane of layout.py is painted at its own physical scale (pixels per metre comes from layout.lane_ppm), so a
2 mm slot, a 0.12 mm moulding grain or a 3 mm printed glyph lands where the geometry says it does:

  wall    the case edge unrolled: u = arc fraction (periodic, so the wrap seam is invisible), v = z. Brim shadow,
          polycarbonate shell, the TPE overmould's hi-vis band with its two seams and a groove, the bezel band,
          the port flap's recess, the button recesses, abraded corners (arc positions from layout.u_at)
  back    the polycarbonate back: moulding grain and flow lines, water-shed streaks off the top edge, recess
          shadows around the hatch, the grip pad, the plate and the camera, four worn dock contacts, scuffs
  bezel   the black bezel ring: anti-glare frame, the gasket bead band (inset 14 to 16.6 mm), printed "CHARTPLOT"
          and "MX-10" microtext, the speaker slots, the sensor and mic pinholes, polished patches, salt
  screen  the glass: dark neutral (the game surfaces the chart UI on it), reflection streak, fingerprint smudges,
          dust and dried salt, a bright 2 px polished edge - no baked UI
  grip    the TPE pad: 2.6 mm dot pattern, worn smooth in the middle, dirty at the edges
  label   the moulded brand plate: invented brand text (GALE ISLES MARINE / CHARTPLOT MX-10 / IPX8 SN 2417-018),
          a life-ring mark, scuffed print
  metal   brushed stainless: collars, screw heads, ring, dock contacts; one dark lens glass patch
  rubber  black rubber: hatch seal, button pads, ribbed port flap, gasket bead, lanyard pad

ALB is fitted to the luma ranges check_textures.py wants (non-metal 30..240, metal 180..250), the hi-vis band goes
into signal_mask.png (written next to this file), _Wet albedo / roughness are pbrmaps.wet of the dry maps.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "tools/blender"))
import layout  # noqa: E402
import pbrmaps  # noqa: E402

SIZE = layout.SIZE

D = 1.0 / 255.0                    # the palette is written in 8-bit sRGB so the luma checks are readable
PC = tuple(v * D for v in (50, 53, 57))              # polycarbonate, dark grey
PC_LIT = tuple(v * D for v in (88, 92, 97))          # scuffed / sun-bleached polycarbonate
HIVIS = tuple(v * D for v in (198, 214, 40))         # hi-vis yellow TPE overmould (signal colour)
HIVIS_FADE = tuple(v * D for v in (176, 184, 96))    # sun-faded, chalky overmould
HIVIS_DIRT = tuple(v * D for v in (96, 96, 60))      # dirt in the groove and the seams
BEZEL = tuple(v * D for v in (56, 58, 62))           # dark grey bezel and lens surround
GLASS = tuple(v * D for v in (42, 47, 55))           # the dark glass (the game surfaces the UI on it)
STEEL = tuple(v * D for v in (198, 202, 206))        # brushed stainless (metal luma 180..250)
RUBBER = tuple(v * D for v in (42, 42, 45))          # black rubber
SALT = tuple(v * D for v in (206, 206, 198))         # dried salt bloom
GRIME = tuple(v * D for v in (58, 55, 48))           # handling grime

FONT = {
    " ": (0, 0, 0, 0, 0, 0, 0),
    "A": (0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001),
    "C": (0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110),
    "E": (0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111),
    "G": (0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01111),
    "H": (0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001),
    "I": (0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111),
    "L": (0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111),
    "M": (0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001),
    "N": (0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001),
    "O": (0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110),
    "P": (0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000),
    "R": (0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001),
    "S": (0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110),
    "T": (0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100),
    "X": (0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001),
    "0": (0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110),
    "1": (0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110),
    "2": (0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111),
    "4": (0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010),
    "7": (0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000),
    "8": (0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110),
    "-": (0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000),
    ".": (0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b01100, 0b01100),
}


# ---------------------------------------------------------------- numpy helpers
def box1(a, k, axis, wrap=False):
    """Box blur along one axis (cumsum), edge-clamped or wrapped."""
    k = int(max(1, k))
    if wrap:
        am = np.concatenate([a[-k:], a, a[:k]], 0) if axis == 0 else np.concatenate([a[:, -k:], a, a[:, :k]], 1)
    else:
        am = (np.concatenate([np.repeat(a[:1], k, 0), a, np.repeat(a[-1:], k, 0)], 0) if axis == 0 else
              np.concatenate([np.repeat(a[:, :1], k, 1), a, np.repeat(a[:, -1:], k, 1)], 1))
    c = np.cumsum(am, axis=axis, dtype=np.float32)
    cs = np.concatenate([np.zeros_like(c[:1] if axis == 0 else c[:, :1]), c], axis=axis)
    n = a.shape[axis]
    if axis == 0:
        return (cs[2 * k + 1:] - cs[:-(2 * k + 1)])[:n] / (2 * k + 1)
    return (cs[:, 2 * k + 1:] - cs[:, :-(2 * k + 1)])[:, :n] / (2 * k + 1)


def blur2(a, k, wrap_x=False):
    return box1(box1(a, k, 0), k, 1, wrap_x)


def rnoise(h, w, seed):
    return np.random.RandomState(seed & 0x7FFFFFFF).rand(h, w).astype(np.float32)


def vnoise(h, w, cells, seed, wrap_x=False, octaves=1, gain=0.5):
    """Smooth value noise in 0..1 (periodic along x when wrap_x)."""
    out = np.zeros((h, w), np.float32)
    amp, tot, c = 1.0, 0.0, float(max(cells, 2))
    for o in range(octaves):
        n = max(int(c), 2)
        g = np.random.RandomState((seed + 31 * o) & 0x7FFFFFFF).rand(n + 1, n + 1).astype(np.float32)
        if wrap_x:
            g[-1, :] = g[0, :]
        iy = np.clip((np.arange(h) * n / max(h - 1, 1)).astype(int), 0, n)
        ix = np.clip((np.arange(w) * n / max(w - 1, 1)).astype(int), 0, n)
        img = g[iy][:, ix]
        out += amp * blur2(img, max(2, int(round(h / float(n) * 0.7))), wrap_x)
        tot += amp
        amp *= gain
        c *= 2.0
    return out / tot


def mix(a, b, k):
    """a/b (H, W, 3) or (H, W), k (H, W) weight."""
    kk = k[..., None] if (a.ndim == 3 and k.ndim == 2) else k
    return a * (1.0 - kk) + b * kk


def patch(arr, lane, val=None, ch=None):
    """View of a lane's inner rect of the atlas array (rows are v-up)."""
    x0, y0, x1, y1 = layout.lane_px(lane)
    v = arr[y0:y1, x0:x1]
    return v


def text(arr, cx, cy, s, scale, colour, centre=True, gap=1):
    """Draw uppercase text into arr (in place). (cx, cy) is the anchor in atlas px; glyph rows run down (-y)."""
    adv = (5 + gap) * scale
    w = adv * len(s) - gap * scale
    x = int(round(cx - w / 2.0)) if centre else int(round(cx))
    y_top = int(round(cy))
    for ch in s:
        g = FONT.get(ch, FONT[" "])
        for r, bits in enumerate(g):
            for cbit in range(5):
                if bits & (1 << (4 - cbit)):
                    x0, y0 = x + cbit * scale, y_top - r * scale
                    arr[max(y0 - scale + 1, 0):y0 + 1, max(x0, 0):x0 + scale] = colour
        x += adv


def text_size(s, scale, gap=1):
    return ((5 + gap) * scale * len(s) - gap * scale, 7 * scale)


# ---------------------------------------------------------------- atlas
def new_maps():
    """A neutral base under every lane, so the atlas margins (never sampled) stay out of the map statistics."""
    alb = np.full((SIZE, SIZE, 3), 0.30, np.float32)
    rgh = np.full((SIZE, SIZE), 0.55, np.float32)
    met = np.zeros((SIZE, SIZE), np.float32)
    hgt = np.zeros((SIZE, SIZE), np.float32)        # mm
    return alb, rgh, met, hgt


def paint_wall(alb, rgh, met, hgt):
    x0, y0, x1, y1 = layout.lane_px("wall")
    w, h = x1 - x0, y1 - y0
    ppm_u, ppm_v = layout.lane_ppm("wall")           # px per metre along u / v
    a = alb[y0:y1, x0:x1]
    r = rgh[y0:y1, x0:x1]
    m = met[y0:y1, x0:x1]
    hh = hgt[y0:y1, x0:x1]
    grain = (vnoise(h, w, 3, 11, wrap_x=True, octaves=3) - 0.5) * 0.05
    stipple = (rnoise(h, w, 12) - 0.5) * 0.05
    a[:] = np.asarray(PC, np.float32)
    a += (grain + stipple)[..., None]

    # bands by z (metres): brim shadow, shell, bumper, bevel, bezel
    def band(z0_, z1_, colour, rgh_v, jitter=0.03):
        i0, i1 = int(z0_ * ppm_v), int(z1_ * ppm_v)
        a[i0:i1] = colour
        a[i0:i1] += ((vnoise(i1 - i0, w, 2, 21, wrap_x=True, octaves=3) - 0.5) * jitter)[..., None]
        r[i0:i1] = rgh_v
    zb = layout.TZ[3][1]                                                            # overmould seams
    zt = layout.TZ[5][1]
    band(0.0, 0.0003, np.asarray(PC, np.float32) * 0.70, 0.70)                      # contact rim
    band(0.0003, zb, np.asarray(PC, np.float32), 0.60)                             # shell wall
    band(zb, zt, np.asarray(HIVIS, np.float32), 0.44, 0.05)                        # TPE overmould
    band(zt, 0.0170, np.asarray(PC, np.float32), 0.58)
    band(0.0170, 0.0200, np.asarray(BEZEL, np.float32), 0.50)
    # the two overmould seams and the parting line
    for zs in (zb, zt):
        i = int(zs * ppm_v)
        a[max(i - 2, 0):i + 2] *= 0.45
        hh[max(i - 2, 0):i + 2] -= 0.25
    ipart = int(layout.TZ[4][1] * ppm_v)
    a[ipart - 1:ipart + 1] *= 1.10
    hh[ipart - 1:ipart + 1] += 0.03
    # UV fade and grime on the bumper (top of the band caught the sun, the groove collects dirt)
    ib0, ib1 = int(zb * ppm_v), int(zt * ppm_v)
    fade = np.clip((np.arange(ib1 - ib0, dtype=np.float32) / (ib1 - ib0)) * 1.5 - 0.45, 0, 1)
    a[ib0:ib1] = mix(a[ib0:ib1], np.asarray(HIVIS_FADE, np.float32)[None, None, :], (fade * 0.55)[:, None])
    grime = np.clip((vnoise(ib1 - ib0, w, 4, 23, wrap_x=True, octaves=3) - 0.55) * 2.4, 0, 1) * 0.5
    grime[:4] *= 1.6
    grime[-4:] *= 1.6
    a[ib0:ib1] = mix(a[ib0:ib1], np.asarray(HIVIS_DIRT, np.float32)[None, None, :], grime[..., None])
    # TPE stipple in the height map
    hh[ib0:ib1] += 0.012 * rnoise(ib1 - ib0, w, 24)
    # abraded corners: scuffs where the case is put down on quay and deck
    for px, py in ((0.122, 0.077), (-0.122, 0.077), (-0.122, -0.077), (0.122, -0.077)):
        cu = layout.u_at(px, py)
        j = int(cu * (w - 1))
        for k in range(-14, 15):
            jj = (j + k) % w
            kk = math.exp(-(k / 7.0) ** 2)
            a[ib0:ib1, jj] = mix(a[ib0:ib1, jj], np.asarray((0.36, 0.36, 0.30), np.float32),
                                 np.full((ib1 - ib0, 1), kk * 0.55, np.float32))
            hh[ib0:ib1, jj] -= 0.05 * kk
    # port flap recess + slots behind the flap, and the button recesses
    for px0, px1, zc, name in ((layout.PORT_X[0], layout.PORT_X[1], 0.0128, "port"),):
        u0, u1 = layout.u_at(px0, layout.D / 2 - 0.002), layout.u_at(px1, layout.D / 2 - 0.002)
        i0, i1 = int(min(u0, u1) * (w - 1)), int(max(u0, u1) * (w - 1))
        r_i0, r_i1 = int((zc - 0.0035) * ppm_v), int((zc + 0.0035) * ppm_v)
        a[r_i0:r_i1, i0:i1] *= 0.55
        hh[r_i0:r_i1, i0:i1] -= 0.35
        for k in range(3):
            xx = i0 + int((k + 0.5) * (i1 - i0) / 3.0)
            a[r_i0 + 3:r_i1 - 3, xx - 2:xx + 2] *= 0.35
            hh[r_i0 + 3:r_i1 - 3, xx - 2:xx + 2] -= 0.6
    for y0_, y1_ in ((layout.VOL_Y[0], layout.VOL_Y[0] + 0.008), (layout.VOL_Y[0] + 0.0095, layout.VOL_Y[0] + 0.0175)):
        uu = layout.u_at(layout.W / 2 - 0.002, (y0_ + y1_) / 2.0)
        j = int(uu * (w - 1))
        j0, j1 = j - int(0.0055 * ppm_u), j + int(0.0055 * ppm_u)
        a[:, j0:j1] *= 0.72
    uu = layout.u_at((layout.PWR_X[0] + layout.PWR_X[1]) / 2.0, layout.D / 2 - 0.002)
    j = int(uu * (w - 1))
    j0, j1 = j - int(0.0110 * ppm_u), j + int(0.0110 * ppm_u)
    a[:, j0:j1] *= 0.72
    # salt bloom along the bezel seam and dried streaks off the bumper
    salt = np.clip((vnoise(h, w, 6, 31, wrap_x=True, octaves=3) - 0.60) * 2.6, 0, 1)
    ibez = int(0.0170 * ppm_v)
    salt[ibez:ibez + 4] = np.maximum(salt[ibez:ibez + 4] * 1.4, 0.35)
    a = mix(a, np.asarray(SALT, np.float32)[None, None, :], (salt * 0.45)[..., None])
    r += 0.10 * salt
    alb[y0:y1, x0:x1] = np.clip(a, 0.0, 1.0)
    return (x0, y0, x1, y1, ib0, ib1)


def paint_back(alb, rgh, met, hgt):
    x0, y0, x1, y1 = layout.lane_px("back")
    w, h = x1 - x0, y1 - y0
    ppm_u, ppm_v = layout.lane_ppm("back")
    a, r, m, hh = alb[y0:y1, x0:x1], rgh[y0:y1, x0:x1], met[y0:y1, x0:x1], hgt[y0:y1, x0:x1]
    px = (np.arange(w, dtype=np.float32) + 0.5) / ppm_u - 0.266 / 2.0
    py = (np.arange(h, dtype=np.float32) + 0.5) / ppm_v - 0.176 / 2.0
    gx, gy = np.meshgrid(px, py)
    grain = (vnoise(h, w, 4, 41, octaves=3) - 0.5) * 0.04 + (rnoise(h, w, 42) - 0.5) * 0.035
    a[:] = np.asarray(PC, np.float32) + grain[..., None]
    r[:] = 0.60
    # moulding flow lines + a subtle dish toward the rim
    flow = 0.5 + 0.5 * np.sin(gy * 240.0 + 2.0 * np.sin(gx * 60.0))
    a *= (0.985 + 0.03 * flow)[..., None]
    dish = np.clip(layout_gap(gx, gy) * 9.0, 0, 1)          # darker toward the rim
    a *= (1.0 - 0.20 * dish)[..., None]
    hh += 0.05 * dish
    # water-shed streaks off the top edge (gravity -Y): salt and grime
    st = np.clip((vnoise(h, w, 5, 51) - 0.52) * 2.2, 0, 1) * np.clip((0.045 - gy) * 12.0, 0, 1)
    a = mix(a, np.asarray(SALT, np.float32)[None, None, :], (st * 0.30)[..., None])
    gr = np.clip((vnoise(h, w, 9, 52) - 0.60) * 2.4, 0, 1) * 0.35
    a = mix(a, np.asarray(GRIME, np.float32)[None, None, :], gr[..., None])
    # scuffs and handling wear
    sc = np.clip((vnoise(h, w, 3, 53, octaves=2) - 0.60) * 3.0, 0, 1) * 0.5
    a = mix(a, np.asarray(PC_LIT, np.float32)[None, None, :], sc[..., None])
    r += 0.10 * sc - 0.04
    hh += 0.02 * (rnoise(h, w, 54) - 0.5)
    # recess shadows around the mouldings, painted where build.py put them
    def recess(cx, cy, hw, hd, rc, soft=0.0016, dark=0.45, depth=0.35):
        d = np.abs(gx - cx) - (hw - rc)
        e = np.abs(gy - cy) - (hd - rc)
        sdf = np.hypot(np.maximum(d, 0), np.maximum(e, 0)) + np.minimum(np.maximum(d, e), 0) - rc
        k = np.clip(1.0 - np.abs(sdf) / soft, 0, 1) * (sdf > -0.010)
        k = np.maximum(k, np.clip(-sdf / 0.004, 0, 1) * (sdf < 0.0004))
        a[:] *= (1.0 - dark * k)[..., None]
        hh[:] -= depth * k
        return k
    recess(*layout.HATCH_C, layout.HATCH_SZ[0] / 2, layout.HATCH_SZ[1] / 2, layout.HATCH_R, dark=0.40, depth=0.30)
    recess(*layout.PAD_C, layout.PAD_SZ[0] / 2 + 0.0012, layout.PAD_SZ[1] / 2 + 0.0012, layout.PAD_R + 0.0012, dark=0.35, depth=0.25)
    recess(*layout.LABEL_C, layout.LABEL_SZ[0] / 2 + 0.0010, layout.LABEL_SZ[1] / 2 + 0.0010, layout.LABEL_R, dark=0.35, depth=0.22)
    # lens recess ring round the camera collar
    dcam = np.hypot(gx - layout.CAM_BACK[0], gy - layout.CAM_BACK[1])
    kcam = np.clip(1.0 - np.abs(dcam - (layout.CAM_BACK_R + 0.0014)) / 0.0014, 0, 1)
    a[:] *= (1.0 - 0.35 * kcam)[..., None]
    # dock contacts: four worn brass pads in a moulded well
    for cx, cy in layout.CONTACTS:
        d = np.hypot(gx - cx, gy - cy)
        pad = (d < 0.0034).astype(np.float32)
        edge = np.clip(1.0 - np.abs(d - 0.0034) / 0.0010, 0, 1)
        wear = np.clip((vnoise(h, w, 8, 61) - 0.45) * 2.0, 0, 1)
        a[:] = mix(a, np.asarray((0.62, 0.52, 0.30), np.float32)[None, None, :], (pad * (0.55 + 0.35 * wear))[..., None])
        a[:] *= (1.0 - 0.5 * edge)[..., None]
        m[:] = np.maximum(m, pad * 0.92)
        r[:] = np.where(pad > 0.5, 0.34 + 0.22 * wear, r)
        hh -= 0.10 * pad
    # a faint moulding part line down the long axis
    part = np.clip(1.0 - np.abs(gy - 0.048) / 0.0006, 0, 1) * 0.18
    a[:] *= (1.0 - part)[..., None]
    alb[y0:y1, x0:x1] = np.clip(a, 0.0, 1.0)
    return


def layout_gap(gx, gy):
    """0 on the base outline, growing inward (for the back's dish shading)."""
    d = np.abs(gx) - (layout.W / 2 - layout.RC)
    e = np.abs(gy) - (layout.D / 2 - layout.RC)
    return -(np.hypot(np.maximum(d, 0), np.maximum(e, 0)) + np.minimum(np.maximum(d, e), 0) - layout.RC)


def paint_bezel(alb, rgh, met, hgt):
    x0, y0, x1, y1 = layout.lane_px("bezel")
    w, h = x1 - x0, y1 - y0
    ppm_u, ppm_v = layout.lane_ppm("bezel")
    a, r, m, hh = alb[y0:y1, x0:x1], rgh[y0:y1, x0:x1], met[y0:y1, x0:x1], hgt[y0:y1, x0:x1]
    px = (np.arange(w, dtype=np.float32) + 0.5) / ppm_u - 0.266 / 2.0
    py = (np.arange(h, dtype=np.float32) + 0.5) / ppm_v - 0.176 / 2.0
    gx, gy = np.meshgrid(px, py)
    grain = (vnoise(h, w, 4, 71, octaves=3) - 0.5) * 0.03
    a[:] = np.asarray(BEZEL, np.float32) + grain[..., None]
    r[:] = 0.52
    inset = -layout_gap(gx, gy)
    # the anti-glare frame: a slightly darker band just inside the rim
    frame = np.clip(1.0 - np.abs(inset - 0.0045) / 0.0016, 0, 1)
    a[:] *= (1.0 - 0.30 * frame)[..., None]
    # the screen recess throat: inset 12.0 to 14.0 mm, in shadow under the rim
    throat = ((inset > 0.0116) & (inset < 0.0142)).astype(np.float32)
    a[:] = mix(a, np.asarray(tuple(v * D for v in (30, 30, 33)), np.float32)[None, None, :],
               (throat * (0.55 + 0.35 * np.clip((inset - 0.0120) / 0.0020, 0, 1)))[..., None])
    r[:] = np.where(throat > 0.5, 0.60, r)
    # the gasket bead: inset 14.0 to 16.6 mm, a black rubber band
    bead = (inset > 0.0140).astype(np.float32)
    bead_edge = np.clip(1.0 - np.abs(inset - 0.0140) / 0.0006, 0, 1)
    a[:] = mix(a, np.asarray((0.028, 0.028, 0.030), np.float32)[None, None, :], bead[..., None])
    a[:] *= (1.0 - 0.5 * bead_edge)[..., None]
    r[:] = np.where(bead > 0.5, 0.66, r)
    hh -= 0.20 * bead_edge
    # printed microtext on the top bezel strip (the brand, small on real devices)
    ty = int((0.0830 + 0.088) * ppm_v)
    tx = int((0.045 + 0.133) * ppm_u)
    text(a, tx, ty, "MX-10", 1, (0.34, 0.34, 0.35), centre=False)
    tx2 = int((-0.078 + 0.133) * ppm_u)
    text(a, tx2, ty, "CHARTPLOT", 1, (0.30, 0.30, 0.31), centre=False)
    # speaker slots on the bottom bezel strip
    for sx, sy in layout.SLOTS:
        u0 = (sx - layout.SLOT_SZ[0] / 2 + 0.133) * ppm_u
        u1 = (sx + layout.SLOT_SZ[0] / 2 + 0.133) * ppm_u
        v0 = (sy - layout.SLOT_SZ[1] / 2 + 0.088) * ppm_v
        v1 = (sy + layout.SLOT_SZ[1] / 2 + 0.088) * ppm_v
        a[int(v0):int(v1), int(u0):int(u1)] *= 0.30
        hh[int(v0):int(v1), int(u0):int(u1)] -= 0.9
        a[int(v1):int(v1) + 2, int(u0):int(u1)] *= 1.5
    # sensor and mic pinholes
    for cx, cy in (layout.SENSOR, layout.MIC):
        d = np.hypot(gx - cx, gy - cy)
        pin = (d < 0.0009).astype(np.float32)
        a[:] = mix(a, np.asarray((0.03, 0.03, 0.04), np.float32)[None, None, :], pin[..., None])
        hh -= 0.5 * pin
    # polished patches beside the screen where hands rest, salt bloom, one scuff
    polish = np.clip(1.0 - np.abs(inset - 0.0105) / 0.0022, 0, 1) * np.clip((vnoise(h, w, 3, 72) - 0.42) * 2.2, 0, 1)
    a[:] = mix(a, np.asarray((0.055, 0.055, 0.058), np.float32)[None, None, :], (polish * 0.7)[..., None])
    r[:] -= 0.12 * polish
    salt = np.clip((vnoise(h, w, 7, 73, octaves=3) - 0.62) * 2.8, 0, 1)
    salt *= np.clip(1.0 - inset / 0.004, 0, 1)
    a[:] = mix(a, np.asarray(SALT, np.float32)[None, None, :], (salt * 0.5)[..., None])
    alb[y0:y1, x0:x1] = np.clip(a, 0.0, 1.0)
    return


def paint_screen(alb, rgh, met, hgt):
    x0, y0, x1, y1 = layout.lane_px("screen")
    w, h = x1 - x0, y1 - y0
    ppm_u, ppm_v = layout.lane_ppm("screen")
    a, r, m, hh = alb[y0:y1, x0:x1], rgh[y0:y1, x0:x1], met[y0:y1, x0:x1], hgt[y0:y1, x0:x1]
    px = (np.arange(w, dtype=np.float32) + 0.5) / ppm_u - layout.WORLD["screen"][0] / 2.0
    py = (np.arange(h, dtype=np.float32) + 0.5) / ppm_v - layout.WORLD["screen"][1] / 2.0
    gx, gy = np.meshgrid(px, py)
    a[:] = np.asarray(GLASS, np.float32)
    r[:] = 0.22
    # a soft reflection band across the glass and a slightly brighter top-left
    refl = np.clip(1.0 - np.abs((gx * 0.7 + gy * 0.7) - 0.010) / 0.030, 0, 1) ** 1.5
    a += (0.020 * refl)[..., None]
    grad = np.clip((gy + 0.06) / 0.13, 0, 1) * 0.010 + np.clip((0.10 - gx) / 0.22, 0, 1) * 0.006
    a += grad[..., None]
    r += 0.05 * refl
    # hand marks: mostly a gloss change (a wiped screen dulls where palms rest), and two real fingerprints
    rn = np.random.RandomState(81)
    for _ in range(6):
        sx, sy = rn.uniform(-0.10, 0.10), rn.uniform(-0.055, 0.055)
        rx, ry = rn.uniform(0.006, 0.014), rn.uniform(0.005, 0.011)
        d = ((gx - sx) / rx) ** 2 + ((gy - sy) / ry) ** 2
        k = np.clip(1.0 - d / 3.2, 0, 1) ** 1.6
        r += 0.045 * k                      # wiped dull, not dark
    for fx, fy, rr in ((-0.086, 0.040, 0.0135), (0.070, -0.043, 0.0105)):
        d = np.hypot((gx - fx), (gy - fy)) / rr
        k = np.clip(1.0 - d, 0, 1) ** 1.3
        ridges = 0.5 + 0.5 * np.sin(np.arctan2(gy - fy, gx - fx) * 26.0)
        a[:] = mix(a, np.asarray((0.055, 0.060, 0.070), np.float32)[None, None, :], (k * 0.35 * ridges)[..., None])
        r -= 0.05 * k
    # dust and a couple of dried salt specks
    dust = (rnoise(h, w, 82) > 0.9994).astype(np.float32)
    a[:] = mix(a, np.asarray((0.16, 0.15, 0.14), np.float32)[None, None, :], (dust * 0.7)[..., None])
    salt = np.clip((vnoise(h, w, 14, 83) - 0.78) * 3.4, 0, 1)
    a[:] = mix(a, np.asarray((0.34, 0.34, 0.32), np.float32)[None, None, :], (salt * 0.20)[..., None])
    hh += 0.004 * dust + 0.008 * salt
    # polished glass edge: the last 2 px inside the outline catch the light
    edge = np.clip(1.0 - (np.maximum(np.abs(gx), np.abs(gy)) - (0.0714 - 0.0012)) / 0.0012, 0, 1)
    a += (0.045 * edge)[..., None]
    r -= 0.05 * edge
    alb[y0:y1, x0:x1] = np.clip(a, 0.0, 1.0)
    return


def paint_grip(alb, rgh, met, hgt):
    x0, y0, x1, y1 = layout.lane_px("grip")
    w, h = x1 - x0, y1 - y0
    ppm_u, ppm_v = layout.lane_ppm("grip")
    a, r, m, hh = alb[y0:y1, x0:x1], rgh[y0:y1, x0:x1], met[y0:y1, x0:x1], hgt[y0:y1, x0:x1]
    px = (np.arange(w, dtype=np.float32) + 0.5) / ppm_u - layout.WORLD["grip"][0] / 2.0
    py = (np.arange(h, dtype=np.float32) + 0.5) / ppm_v - layout.WORLD["grip"][1] / 2.0  # noqa
    gx, gy = np.meshgrid(px, py)
    grain = (rnoise(h, w, 91) - 0.5) * 0.05 + (vnoise(h, w, 6, 92, octaves=2) - 0.5) * 0.04
    a[:] = np.asarray(tuple(v * D for v in (44, 44, 47)), np.float32) + grain[..., None]
    r[:] = 0.62
    # 2.6 mm dot pattern, offset rows; worn smooth at the centre, dirty at the edge
    pitch = 0.0026
    dot_r = 0.0010
    shift = np.where((np.floor(gy / pitch) % 2) == 0, 0.0, 0.5)
    fx2 = ((gx / pitch + shift) % 1.0) - 0.5
    fy = (gy / pitch) % 1.0 - 0.5
    d = np.hypot(fx2 * pitch, fy * pitch)
    dot = np.clip(1.0 - d / dot_r, 0, 1) ** 0.6
    wear = np.clip(1.0 - np.hypot(gx / 0.030, gy / 0.026) / 1.6, 0, 1) ** 1.2
    dot *= (1.0 - 0.75 * wear)
    a += (0.055 * dot)[..., None]
    hh += 0.13 * dot
    r -= 0.16 * dot + 0.07 * wear
    edge = np.clip(1.0 - np.abs(np.maximum(np.abs(gx) / (layout.WORLD["grip"][0] / 2),
                                           np.abs(gy) / (layout.WORLD["grip"][1] / 2)) - 0.90) / 0.08, 0, 1)
    a[:] = mix(a, np.asarray(GRIME, np.float32)[None, None, :], (edge * 0.45 * dot)[..., None])
    alb[y0:y1, x0:x1] = np.clip(a, 0.0, 1.0)
    return


def paint_label(alb, rgh, met, hgt):
    x0, y0, x1, y1 = layout.lane_px("label")
    w, h = x1 - x0, y1 - y0
    a, r, m, hh = alb[y0:y1, x0:x1], rgh[y0:y1, x0:x1], met[y0:y1, x0:x1], hgt[y0:y1, x0:x1]
    # the plate's bevel is the lane's outer 6 % / 10 % margin, painted dark; the plateau holds the print
    u0, v0 = int(0.06 * w), int(0.10 * h)
    u1, v1 = int(0.94 * w), int(0.90 * h)
    a[:] = np.asarray(tuple(v * D for v in (40, 41, 44)), np.float32)[None, None, :]
    grain = (rnoise(h, w, 101) - 0.5) * 0.03
    a[v0:v1, u0:u1] = np.asarray(tuple(v * D for v in (92, 96, 101)), np.float32)
    a[v0:v1, u0:u1] += grain[v0:v1, u0:u1, None]
    r[:] = 0.30
    r[v0:v1, u0:u1] = 0.46
    # print: brand, model, serial (invented text; the plate is 88 x 20.5 mm, so this is 3-6 mm type)
    cx = (u0 + u1) // 2
    text(a, cx, v1 - int(0.34 * (v1 - v0)), "CHARTPLOT MX-10", 2, (0.62, 0.63, 0.64))
    text(a, cx, v1 - int(0.56 * (v1 - v0)), "GALE ISLES MARINE", 1, (0.46, 0.47, 0.48))
    text(a, cx, v1 - int(0.72 * (v1 - v0)), "IPX8  SN 2417-018", 1, (0.42, 0.43, 0.44))
    # the life-ring mark at the left of the plate
    mx, my, mr_ = u0 + int(0.09 * (u1 - u0)), (v0 + v1) // 2, int(0.055 * (v1 - v0))
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.hypot(xx - mx, yy - my)
    ring = ((d > mr_ * 0.55) & (d < mr_)).astype(np.float32)
    a[:] = mix(a, np.asarray((0.66, 0.67, 0.66), np.float32)[None, None, :], ring[..., None])
    # scuffs across the print, dust in the corners, a worn highlight along the top edge
    sc = np.clip((vnoise(h, w, 4, 102, octaves=2) - 0.58) * 3.0, 0, 1) * 0.55
    a[:] = mix(a, np.asarray((0.30, 0.31, 0.32), np.float32)[None, None, :], sc[..., None])
    a[v1 - 2:v1] *= 1.25
    a[:, u0:u1][:2] *= 1.2
    hh += 0.03 * (rnoise(h, w, 103) - 0.5)
    alb[y0:y1, x0:x1] = np.clip(a, 0.0, 1.0)
    return


def paint_metal(alb, rgh, met, hgt):
    x0, y0, x1, y1 = layout.lane_px("metal")
    w, h = x1 - x0, y1 - y0
    a, r, m, hh = alb[y0:y1, x0:x1], rgh[y0:y1, x0:x1], met[y0:y1, x0:x1], hgt[y0:y1, x0:x1]
    yy, xx = np.mgrid[0:h, 0:w]
    brush = (vnoise(h, w, 40, 111, octaves=2) - 0.5) * 0.10 + (rnoise(h, w, 112) - 0.5) * 0.03
    a[:] = np.asarray(STEEL, np.float32) + brush[..., None]
    r[:] = 0.26 + 0.10 * (rnoise(h, w, 113) - 0.5)
    m[:] = 0.95
    for name, (u0_, u1_, v0_, v1_) in SUB_RECTS["metal"].items():
        i0, i1 = int(u0_ * w), int(u1_ * w)
        j0, j1 = int(v0_ * h), int(v1_ * h)
        pa = a[j0:j1, i0:i1]
        pr = r[j0:j1, i0:i1]
        pm = m[j0:j1, i0:i1]
        phh = hh[j0:j1, i0:i1]
        hh_, ww_ = pa.shape[:2]
        ly, lx = np.mgrid[0:hh_, 0:ww_]
        if name == "lens":
            pa[:] = np.asarray((0.10, 0.115, 0.135), np.float32)
            d = np.hypot((lx - ww_ * 0.5) / (ww_ * 0.5), (ly - hh_ * 0.45) / (hh_ * 0.45))
            glint = np.clip(1.0 - np.abs(d - 0.55) / 0.22, 0, 1) * 0.5
            pa += (0.20 * glint)[..., None]
            pr[:] = 0.06 + 0.10 * glint
            pm[:] = 0.0
        else:
            # brushed stainless: fine radial-ish streaks and a soft sheen
            pa[:] = np.asarray(STEEL, np.float32) + ((rnoise(hh_, ww_, 114) - 0.5) * 0.06)[..., None]
            sheen = np.clip(1.0 - np.abs(ly / max(hh_ - 1, 1) - 0.35) / 0.5, 0, 1) * 0.05
            pa += sheen[..., None]
            pr[:] = 0.22 + 0.12 * (ly / max(hh_ - 1, 1))
            pm[:] = 0.95
            phh -= 0.02 * (1.0 - ly / max(hh_ - 1, 1))
        a[j0:j1, i0:i1] = pa
        r[j0:j1, i0:i1] = pr
        m[j0:j1, i0:i1] = pm
        hh[j0:j1, i0:i1] = phh
    # a little salt and a scratch on the metal
    salt = np.clip((vnoise(h, w, 10, 115) - 0.70) * 3.0, 0, 1) * 0.4
    a[:] = mix(a, np.asarray(SALT, np.float32)[None, None, :], salt[..., None])
    alb[y0:y1, x0:x1] = np.clip(a, 0.0, 1.0)
    return


def paint_rubber(alb, rgh, met, hgt):
    x0, y0, x1, y1 = layout.lane_px("rubber")
    w, h = x1 - x0, y1 - y0
    a, r, m, hh = alb[y0:y1, x0:x1], rgh[y0:y1, x0:x1], met[y0:y1, x0:x1], hgt[y0:y1, x0:x1]
    a[:] = np.asarray(RUBBER, np.float32)
    r[:] = 0.68
    grain = (rnoise(h, w, 121) - 0.5) * 0.05 + (vnoise(h, w, 8, 122, octaves=2) - 0.5) * 0.05
    a += grain[..., None]
    hh += 0.02 * (rnoise(h, w, 123) - 0.5)
    for name, (u0_, u1_, v0_, v1_) in SUB_RECTS["rubber"].items():
        i0, i1 = int(u0_ * w), int(u1_ * w)
        j0, j1 = int(v0_ * h), int(v1_ * h)
        pa, pr, phh = a[j0:j1, i0:i1], r[j0:j1, i0:i1], hh[j0:j1, i0:i1]
        hh_, ww_ = pa.shape[:2]
        ly, lx = np.mgrid[0:hh_, 0:ww_]
        if name in ("btn", "btn2"):
            pa[:] = np.asarray((0.042, 0.042, 0.045), np.float32) + ((rnoise(hh_, ww_, 124) - 0.5) * 0.05)[..., None]
            thumb = np.clip(1.0 - np.abs(ly / max(hh_ - 1, 1) - 0.45) / 0.45, 0, 1)
            pa -= (0.012 * thumb)[..., None]
            pr[:] = 0.44 + 0.10 * (1.0 - thumb)
            phh += 0.01 * (rnoise(hh_, ww_, 125) - 0.5)
        elif name == "port":
            pa[:] = np.asarray((0.038, 0.038, 0.040), np.float32)
            ribs = 0.5 + 0.5 * np.sin(ly * (2 * np.pi * hh_ / 9.0))
            pa += (0.020 * ribs)[..., None]
            phh += 0.05 * ribs
            pr[:] = 0.58 - 0.10 * ribs
        elif name == "lanyard":
            pa[:] = np.asarray((0.034, 0.034, 0.036), np.float32) + ((vnoise(hh_, ww_, 3, 126) - 0.5) * 0.04)[..., None]
            pr[:] = 0.60
        elif name == "gasket":
            pa[:] = np.asarray((0.030, 0.030, 0.032), np.float32)
            pa += ((0.5 + 0.5 * np.sin(lx * 2.4)) * 0.012)[..., None]
            pr[:] = 0.66
            phh += 0.03 * (0.5 + 0.5 * np.sin(lx * 2.4))
        a[j0:j1, i0:i1] = pa
        r[j0:j1, i0:i1] = pr
        hh[j0:j1, i0:i1] = phh
    alb[y0:y1, x0:x1] = np.clip(a, 0.0, 1.0)
    return


SUB_RECTS = {"metal": {"collar": (0.03, 0.30, 0.71, 0.97), "lens": (0.36, 0.58, 0.71, 0.97),
                       "screw": (0.63, 0.88, 0.71, 0.97), "ring": (0.03, 0.30, 0.35, 0.63)},
             "rubber": {"seal": (0.03, 0.34, 0.73, 0.97), "btn": (0.40, 0.61, 0.73, 0.97), "btn2": (0.67, 0.88, 0.73, 0.97),
                        "port": (0.40, 0.88, 0.45, 0.65), "gasket": (0.02, 0.98, 0.31, 0.41), "lanyard": (0.03, 0.34, 0.45, 0.65)}}


def normals(hgt, lanes_norm_x=True):
    """Tangent-space normals from the height field (mm), per lane at its own pixel size, OpenGL (green up)."""
    nor = np.full((SIZE, SIZE, 3), 0.5, np.float32)
    nor[..., 2] = 1.0
    for lane in layout.LANES:
        x0, y0, x1, y1 = layout.lane_px(lane)
        h = hgt[y0:y1, x0:x1]
        px_mm = 1000.0 / layout.lane_ppm(lane)[0]
        py_mm = 1000.0 / layout.lane_ppm(lane)[1]
        dx = np.gradient(h, axis=1) / px_mm * 0.55
        dy = np.gradient(h, axis=0) / py_mm * 0.55
        v = np.stack([-dx, -dy, np.ones_like(h)], -1)
        v /= np.linalg.norm(v, axis=-1, keepdims=True)
        nor[y0:y1, x0:x1] = v * 0.5 + 0.5
    return nor


def build(directory, size=SIZE):
    """Paint and write T_ChartTablet_Kit_{ALB,NOR,RGH,MET}.png (dry and _Wet) plus the source signal mask."""
    alb, rgh, met, hgt = new_maps()
    x0, y0, x1, y1, ib0, ib1 = paint_wall(alb, rgh, met, hgt)
    paint_back(alb, rgh, met, hgt)
    paint_bezel(alb, rgh, met, hgt)
    paint_screen(alb, rgh, met, hgt)
    paint_grip(alb, rgh, met, hgt)
    paint_label(alb, rgh, met, hgt)
    paint_metal(alb, rgh, met, hgt)
    paint_rubber(alb, rgh, met, hgt)
    rgh = np.clip(rgh, 0.02, 0.98)
    met = np.clip(met, 0.0, 1.0)
    alb = pbrmaps.clamp_albedo(np.clip(alb, 0.0, 1.0), met)      # per-class luma ranges (check_textures)
    nor = np.clip(normals(hgt), 0.0, 1.0)
    out = {"ALB": (alb * 255.0 + 0.5).astype(np.uint8), "NOR": (nor * 255.0 + 0.5).astype(np.uint8),
           "RGH": (rgh * 255.0 + 0.5).astype(np.uint8), "MET": (met * 255.0 + 0.5).astype(np.uint8)}
    wet_alb, wet_rgh = pbrmaps.wet(alb, rgh, darken=0.22, gloss=0.28)
    wet = {"ALB": (np.clip(wet_alb, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8),
           "NOR": out["NOR"].copy(),
           "RGH": (np.clip(wet_rgh, 0.02, 0.98) * 255.0 + 0.5).astype(np.uint8),
           "MET": out["MET"].copy()}
    os.makedirs(directory, exist_ok=True)
    written = []
    for kind, arr in out.items():
        p = os.path.join(directory, "T_ChartTablet_Kit_%s.png" % kind)
        pbrmaps.write_png(p, arr[::-1])                       # rows are v-up: flip for the PNG
        written.append(p)
    for kind, arr in wet.items():
        p = os.path.join(directory, "T_ChartTablet_Kit_%s_Wet.png" % kind)
        pbrmaps.write_png(p, arr[::-1])
        written.append(p)
    mask = np.zeros((SIZE, SIZE), np.uint8)
    mask[ib0 + y0:ib1 + y0, x0:x1] = 255                       # the hi-vis overmould band
    pbrmaps.write_png(os.path.join(HERE, "signal_mask.png"), mask[::-1])
    print("[maketex] %d maps at %d px in %s" % (len(written), size, os.path.relpath(directory)))
    return written


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else ".")
