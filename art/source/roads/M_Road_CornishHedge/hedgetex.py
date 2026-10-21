"""M_Road_CornishHedge trim set `T_CornishHedge_Stone_*` (docs/12 2.4; system python3 + numpy + Pillow, no heavy slot).

    python3 art/source/roads/M_Road_CornishHedge/hedgetex.py [--out DIR]

Writes assets/textures/M_Road_CornishHedge/ (masters 2048 -> art/source/roads/M_Road_CornishHedge/textures/), the
signal mask for check_textures.py, and the dry/wet twins. One set for the whole solid mesh, three regions at one
scale (layout.py, PPM 707 px/m of wall):

  stone  the granite facing stones: split Cornish granite synthesised at stone scale (the cached granite_tile
         scan is a floor tile whose grout grid and mirror crop read through at this size), then the layers
         that belong to a hedge - stone-to-stone tone drift (slabs are individual pieces of rock), grey-green lichen
         crusts with their dark fissures, moss in the damp bands (the foot of the wall, and everything under the turf
         lip where the water runs off), road splash and silt at the foot, dried salt. V is height above the ground, so
         every layer sits where it belongs whatever stone samples it.
  earth  the bare earth core: dark damp earth, packing stones, root strands and moss, seen through the joints and on
         the end cuts.
  turf   the turf cap seen from above: dense grass blade mat over soil with dead patches, plus the damp underside of
         the lip.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROADS = os.path.dirname(HERE)
sys.path.insert(0, ROADS)
sys.path.insert(0, HERE)
import layout as L  # noqa: E402
import texlib as T  # noqa: E402

F32 = np.float32
M = L.MASTER
SHIP = L.SHIP
PPM = L.PPM
STEM = "T_CornishHedge_Stone"
MASTERS = os.path.join(HERE, "textures")
DEFAULT_OUT = os.path.join(T.GAME, "assets/textures/M_Road_CornishHedge")
H_MOSS_TOP = 1.24          # moss band under the turf lip starts here (the region's V runs to 1.45 m)


def renorm(n):
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def grid_m(region):
    """(u, v) metres per pixel of a region: u along the wall from 0, v up from the region's bottom edge."""
    x0, y0, x1, y1 = L.px_rect(region)
    h, w = y1 - y0, x1 - x0
    u = (np.arange(w, dtype=F32) + 0.5) / PPM
    v = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h) * (h / PPM)
    return u, v


def granite_bed(hw, seed, U, Z):
    """Grey Cornish granite, synthesised in the rocks-kit spirit (feldspar / biotite / pink blotches / iron stain)
    but without a scan: the hedge's stones are posted, split granite 20 to 40 cm across, and the only cached granite
    scan (granite_tile) is a floor tile whose 0.4 m slab joints repeat far too fast to hide at this size. The relief
    is a split stone's facets - a jittered cell grid with its own tilt per facet - over crystal grain and specks."""
    h, w = hw
    span_u = w / PPM
    blot = T.noise(hw, 4, seed + 21, 4)                       # 0.7 m pink / grey patches through the bed
    slab = T.noise(hw, 9, seed + 34, 3)                       # 0.32 m patches: roughly one facing stone's worth of tone
    gran = T.noise(hw, 90, seed + 23, 2)                      # 3 cm granularity
    fine = T.noise(hw, 340, seed + 24, 2)                     # 1 cm
    quartz = T.noise(hw, 1200, seed + 32, 1)                  # 0.5 mm sparkle
    cluster = T.sstep(0.30, 0.68, T.noise(hw, 22, seed + 33, 3))   # crystals gather in schlieren, not a starfield
    f1, f2, cid = T.voronoi(U, Z, 0.0085, span_u, None, seed + 25)
    fsp = (T.sstep(0.0024, 0.0004, f1) * T.sstep(0.42, 0.68, T.hash01(cid, 3))
           * (0.35 + 0.75 * cluster))                                            # pale K-feldspar laths
    b1, b2, bid = T.voronoi(U, Z, 0.0042, span_u, None, seed + 26)
    bio = (T.sstep(0.0014, 0.0002, b1) * T.sstep(0.28, 0.55, T.hash01(bid, 7))
           * (0.40 + 0.85 * (1.0 - cluster)))                                    # dark mica / hornblende specks
    j1, j2, jid = T.voronoi(U, Z, 0.018, span_u, None, seed + 27)
    fx = (T.hash01(jid, 11) - 0.5) * 0.26
    fy = (T.hash01(jid, 13) - 0.5) * 0.26
    facet = np.dstack([-fx, -fy, np.ones_like(fx)]).astype(F32)
    facet = facet / np.linalg.norm(facet, axis=2, keepdims=True)
    grey = np.array([0.198, 0.199, 0.194], F32) * 255.0       # wet-coast granite, weathered dark grey
    pink = np.array([0.326, 0.298, 0.278], F32) * 255.0
    dark = np.array([0.132, 0.132, 0.129], F32) * 255.0
    rusty = np.array([0.330, 0.268, 0.202], F32) * 255.0
    pale = np.array([0.448, 0.446, 0.434], F32) * 255.0       # weathered feldspar, matte and slightly pale
    alb = grey * (1.0 - blot[..., None] * 0.45) + pink * blot[..., None] * 0.45
    alb = alb * (0.76 + 0.46 * gran)[..., None] * (0.94 + 0.12 * fine)[..., None]
    alb = alb * (0.58 + 0.80 * slab)[..., None]
    alb = alb * (1.0 - bio[..., None] * 0.85) + dark * bio[..., None] * 0.85
    alb = alb * (1.0 - fsp[..., None] * 0.60) + pale * fsp[..., None] * 0.60
    alb = alb * (0.88 + 0.26 * quartz)[..., None]
    salt = T.noise(hw, 900, seed + 35, 1)
    alb = alb * (0.86 + 0.28 * salt)[..., None]
    rust = T.sstep(0.72, 0.88, T.noise(hw, 5, seed + 28, 4)) * T.sstep(0.45, 0.72, T.noise(hw, 16, seed + 29, 3))
    alb = alb * (1.0 - rust[..., None] * 0.32) + rusty * rust[..., None] * 0.32
    crack = T.noise(hw, 14, seed + 30, 3)
    joint = (1.0 - T.sstep(0.0, 0.007, np.abs(crack - 0.5))) * T.sstep(0.62, 0.85, T.noise(hw, 4, seed + 31, 2))
    alb = alb * (1.0 - joint[..., None] * 0.26)
    rgh = np.clip(0.62 - fsp * 0.06 + bio * 0.06 + (gran - 0.5) * 0.14 - quartz * 0.05 - joint * 0.05, 0.38, 0.90)
    lump = T.noise(hw, 55, seed + 42, 2)                     # 3 to 5 cm weathered lumps across the split face
    hgt = ((fine - 0.5) * 0.0012 + (quartz - 0.5) * 0.0005 + fsp * 0.0004 - bio * 0.0005
           - joint * 0.0014 + (lump - 0.5) * 0.0065)
    nor = T.combine_normals(facet, T.height_normal_uv(hgt, PPM, PPM, 1.0))
    return alb, rgh, nor, rust, joint, gran


def smear_down(mask, steps, decay):
    """Vertical run-off: the mask repeated downward (down the image = down the wall) with decaying strength."""
    out = mask.copy()
    for i in range(1, steps + 1):
        out = np.maximum(out, np.roll(mask, i, 0) * (decay ** i))
    return out


# ---------------------------------------------------------------------------------------------------- regions
def stone_region(seed):
    """Granite facing stones: the bed, individual slabs' tone, lichen crusts, moss bands, splash, salt."""
    u, v = grid_m("stone")
    h, w = len(v), len(u)
    hw = (h, w)
    U = np.broadcast_to(u[None, :], hw).astype(F32)
    Z = np.broadcast_to(v[:, None], hw).astype(F32)
    a, r, n, rust, joint, grain = granite_bed(hw, seed, U, Z)
    hgt = (grain - 0.5) * 0.0012 - joint * 0.0018
    # ---- individual slabs: a drift slower than a stone, so neighbours read as different pieces of rock
    tone = T.sstep(0.26, 0.74, T.noise(hw, 4, seed + 2, 3)) * (0.45 + 0.55 * T.noise(hw, 10, seed + 3, 3))
    a = a * (0.78 + 0.44 * tone)[..., None]
    r = r + 0.07 * (1.0 - tone)
    drift = T.noise(hw, 3, seed + 36, 3)                        # 1 m tone patches: neighbouring stones differ
    a = a * (0.80 + 0.40 * drift)[..., None]
    dark = T.sstep(0.76, 0.92, T.noise(hw, 4, seed + 37, 2))
    a = T.blend(a, a * 0.52 + np.array([18, 18, 17], F32), dark * 0.55)
    # ---- lichen crusts: patch field x granular speckle, thin cell fissures, raised off the stone
    speck = T.noise(hw, 150, seed + 4, 2) * 0.55 + T.noise(hw, 380, seed + 5, 1) * 0.45
    field = (T.sstep(0.33, 0.64, T.noise(hw, 7, seed + 6, 4)) * (0.45 + 0.60 * T.noise(hw, 17, seed + 7, 3))
             * T.sstep(0.13, 0.40, T.noise(hw, 3, seed + 8, 2)))          # bands of the face stay bare granite
    lich = np.clip(T.sstep(0.26, 0.70, field * (0.45 + 0.85 * speck)), 0, 1)
    lich = lich * (0.55 + 0.55 * T.sstep(0.30, 0.70, T.noise(hw, 420, seed + 22, 2)))
    f1, f2, _ = T.voronoi(U, Z, 0.017, L.span_m("stone")[0], None, seed + 9)
    fis = (1.0 - T.sstep(0.0, 0.0035, f2 - f1)) * T.sstep(0.42, 0.68, T.noise(hw, 40, seed + 19, 2))
    # two crustose communities: pale grey-green, and the yellow-green / orange of a sunlit coast
    yellow = T.sstep(0.42, 0.70, T.noise(hw, 9, seed + 20, 3)) * T.sstep(0.30, 0.60, speck)
    orange = T.sstep(0.72, 0.86, T.noise(hw, 13, seed + 21, 3)) * lich
    lc = np.dstack([132 + 30 * speck, 136 + 28 * speck, 118 + 20 * speck]).astype(F32)
    ly = np.dstack([136 + 26 * speck, 134 + 22 * speck, 92 + 16 * speck]).astype(F32)
    lo = np.dstack([164 + 20 * speck, 128 + 16 * speck, 72 + 12 * speck]).astype(F32)
    a = T.blend(a, lc, lich * 0.82)
    a = T.blend(a, ly, lich * yellow * 0.85)
    a = T.blend(a, lo, orange * 0.80)
    a = T.blend(a, np.dstack([78, 82, 68]).astype(F32), lich * fis * 0.30)
    r = r * (1 - lich * 0.85) + lich * 0.85 * 0.93
    hgt = hgt + lich * (0.0010 + 0.0024 * speck) - lich * fis * 0.0012
    # ---- moss: the foot of the wall and everything under the turf lip, seeping a little way down the face. The bands
    # follow a meandering water line (zw), not a straight stripe, and break up into cushions.
    zw = Z + 0.10 * (T.noise(hw, 8, seed + 18, 2) - 0.5) + 0.03 * (T.noise(hw, 40, seed + 19, 2) - 0.5)
    sc = T.noise(hw, 26, seed + 10, 2, aniso=(0.12, 1.0))
    cols = T.noise(hw, 12, seed + 11, 3)
    line = (1.0 - T.sstep(0.0, 0.035, np.abs(sc - 0.5))) * T.sstep(0.55, 0.85, cols)
    streak = smear_down(line, 120, 0.982) * np.exp(-np.maximum(H_MOSS_TOP - Z, 0.0) / 0.28)
    band = np.exp(-np.maximum(zw - 0.02, 0.0) / 0.17) + 1.05 * np.exp(-np.maximum(H_MOSS_TOP - zw, 0.0) / 0.10)
    fuzzy = np.clip(T.noise(hw, 240, seed + 12, 2) * 0.6 + T.noise(hw, 60, seed + 18, 2) * 0.4, 0, 1)
    moss = np.clip(T.sstep(0.34, 0.80, band * (0.40 + 0.85 * T.noise(hw, 9, seed + 13, 3)) + 0.35 * streak)
                   * (0.30 + 1.05 * fuzzy), 0, 1)
    mc = np.dstack([50 + 20 * fuzzy, 64 + 24 * fuzzy, 37 + 14 * fuzzy]).astype(F32)   # damp moss, not lawn
    a = T.blend(a, mc, moss * 0.82)
    r = r * (1 - moss * 0.9) + moss * 0.9 * 0.94
    hgt = hgt + moss * (0.0024 + 0.0026 * fuzzy)
    # ---- road splash and silt on the bottom of the face, a film that thins with height
    nz = T.noise(hw, 12, seed + 14, 3)
    splash = np.clip(np.exp(-np.maximum(Z - 0.05, 0.0) / 0.19) * (0.70 + 0.60 * nz) - 0.10, 0, 1)
    grit = T.noise(hw, 500, seed + 15, 1)
    splash = np.clip(splash * (0.72 + 0.55 * grit), 0, 1)
    a = T.blend(a, np.dstack([92 + 18 * nz, 84 + 14 * nz, 70 + 10 * nz]).astype(F32), splash * 0.62)
    r = r * (1 - splash) + splash * 0.88
    hgt = hgt * (1 - splash) + splash * (grit - 0.5) * 0.0012
    # ---- dark wet staining: the foot of the wall stays damp, with run-off streaks and darker, glossier joints
    wetn = T.noise(hw, 22, seed + 40, 3, aniso=(0.45, 1.0))
    wet = np.clip(np.exp(-np.maximum(Z - 0.03, 0.0) / 0.42) * (0.64 + 0.70 * wetn), 0, 1)
    streak = smear_down((1.0 - T.sstep(0.0, 0.020, np.abs(T.noise(hw, 7, seed + 41, 2, aniso=(0.12, 1.0)) - 0.5)))
                        * np.exp(-np.maximum(0.75 - Z, 0.0) / 0.55) * wetn, 90, 0.984)
    a = T.blend(a, np.dstack([24 + 7 * wetn, 25 + 6 * wetn, 22 + 5 * wetn]).astype(F32),
                np.clip(wet * 0.76 + streak * 0.28, 0, 1))
    algae = np.clip(np.exp(-np.maximum(Z - 0.02, 0.0) / 0.09) * (0.45 + 0.75 * fuzzy), 0, 1)
    a = T.blend(a, np.dstack([44 + 10 * fuzzy, 54 + 12 * fuzzy, 34 + 8 * fuzzy]).astype(F32), algae * 0.42)
    r = r * (1 - wet * 0.55) + wet * 0.55 * 0.44
    hgt = hgt * (1 - wet * 0.3) + wet * 0.3 * (wetn - 0.5) * 0.0016
    # ---- dried salt bloom up the face, and iron stain weeping from the joints above
    salt = T.sstep(0.72, 0.88, T.noise(hw, 32, seed + 16, 3, aniso=(0.85, 1.0))) * (0.35 + 0.65 * T.sstep(0.20, 0.80, Z / 1.35))
    a = T.blend(a, np.dstack([196 + 6 * nz] * 2 + [188 + 5 * nz]).astype(F32), salt * 0.09)
    r = r + 0.08 * salt
    a = a * (1.0 - rust[..., None] * 0.30)
    # ---- the whole bed drifts in tone so a 2.9 m repeat never reads as one tile
    a = a * (1.0 + 0.035 * (T.noise(hw, 3, seed + 17, 2)[..., None] - 0.5))
    n = T.combine_normals(n, T.height_normal_uv(hgt, PPM, PPM, 1.0))
    return np.clip(a, 34, 238), np.clip(r, 0.30, 0.96), n, np.clip(lich * 0.8 + moss, 0, 1), np.zeros(hw, F32)


def earth_region(seed):
    """The bare core behind the stones: damp dark earth, packed small stones, root strands, moss in the crevices."""
    u, v = grid_m("earth")
    h, w = len(v), len(u)
    hw = (h, w)
    U = np.broadcast_to(u[None, :], hw).astype(F32)
    Z = np.broadcast_to(v[:, None], hw).astype(F32)
    nz = T.noise(hw, 14, seed, 3)
    grit = T.noise(hw, 520, seed + 1, 1)
    a = np.dstack([52 + 18 * nz, 43 + 14 * nz, 32 + 10 * nz]).astype(F32)
    a = a * (0.86 + 0.28 * grit)[..., None]
    r = np.full(hw, 0.92, F32)
    hgt = (grit - 0.5) * 0.0022 + (nz - 0.5) * 0.0016
    # packed packing stones behind the facing (lighter granite flecks with dark joints)
    f1, f2, cid = T.voronoi(U, Z, 0.050, L.span_m("earth")[0], None, seed + 2)
    stone = T.sstep(0.010, 0.003, f1) * T.sstep(0.32, 0.54, T.noise(hw, 6, seed + 3, 3))
    tone = T.hash01(cid, 5)[..., None] * 0.5 + 0.25
    sc = np.dstack([96, 92, 84]).astype(F32) * (0.62 + 0.62 * tone) * (0.82 + 0.36 * grit[..., None])
    a = T.blend(a, sc, stone * 0.78)
    hgt = hgt + stone * 0.0016
    joint = 1.0 - T.sstep(0.0, 0.004, f2 - f1)
    a = T.blend(a, np.dstack([30, 28, 24]).astype(F32), joint * 0.55)
    # root strands
    rn = T.noise(hw, 26, seed + 4, 3, aniso=(0.10, 1.0))
    root = (1.0 - T.sstep(0.0, 0.030, np.abs(rn - 0.5))) * T.sstep(0.45, 0.75, T.noise(hw, 5, seed + 5, 2))
    a = T.blend(a, np.dstack([124, 104, 74]).astype(F32), root * 0.55)
    hgt = hgt + root * 0.0012
    # moss filling the crevices
    fuzzy = np.clip(T.noise(hw, 240, seed + 6, 2), 0, 1)
    moss = np.clip(T.sstep(0.26, 0.60, T.noise(hw, 8, seed + 7, 3) * (0.5 + 0.7 * fuzzy)), 0, 1)
    a = T.blend(a, np.dstack([40 + 14 * fuzzy, 52 + 18 * fuzzy, 30 + 10 * fuzzy]).astype(F32), moss * 0.46)
    r = r * (1 - moss * 0.4) + moss * 0.4 * 0.95
    hgt = hgt + moss * 0.0022
    n = T.height_normal_uv(hgt, PPM, PPM, 1.0)
    return np.clip(a, 32, 200), np.clip(r, 0.70, 0.97), n, np.clip(moss + stone * 0.4, 0, 1), np.zeros(hw, F32)


def turf_region(seed):
    """The turf cap from above: a dense mat of short blades over soil, with dead patches and a few weeds."""
    u, v = grid_m("turf")
    h, w = len(v), len(u)
    hw = (h, w)
    nz = T.noise(hw, 16, seed, 3)
    soil = np.dstack([56 + 20 * nz, 48 + 16 * nz, 36 + 10 * nz]).astype(F32)
    # blades: fine noise stretched along the wall, three tones, so the mat reads as grass at texel scale
    blade = T.noise(hw, 260, seed + 1, 2, aniso=(1.0, 5.0))
    blade2 = T.noise(hw, 1400, seed + 2, 2, aniso=(1.0, 9.0))
    blade3 = T.noise(hw, 3200, seed + 8, 1, aniso=(1.0, 7.0))
    mat = T.sstep(0.26, 0.58, blade * 0.5 + blade2 * 0.32 + blade3 * 0.18)
    patch = T.sstep(0.34, 0.66, T.noise(hw, 7, seed + 3, 3))
    green = np.dstack([42 + 22 * blade2 + 8 * blade3, 66 + 28 * blade + 10 * blade3,
                       32 + 14 * blade2 + 6 * blade3]).astype(F32)
    dead = np.dstack([92 + 24 * blade2, 86 + 20 * blade, 54 + 12 * blade2]).astype(F32)
    g = T.sstep(0.40, 0.62, patch)
    a = T.blend(soil, green, np.clip(mat * (0.55 + 0.65 * g), 0, 1))
    a = T.blend(a, dead, np.clip(mat * (0.40 + 0.70 * (1 - g)) * T.sstep(0.40, 0.75, T.noise(hw, 11, seed + 4, 2)), 0, 1) * 0.8)
    hgt = (blade - 0.5) * 0.004 + (blade2 - 0.5) * 0.0035 + (blade3 - 0.5) * 0.0018
    # a few broad leaves (plantain / clover) and moss in the shaded edges
    leaf = T.sstep(0.86, 0.92, T.noise(hw, 90, seed + 5, 2))
    a = T.blend(a, np.dstack([48, 70, 38]).astype(F32), leaf * 0.7)
    hgt = hgt + leaf * 0.004
    moss = T.sstep(0.60, 0.80, T.noise(hw, 22, seed + 6, 3)) * (0.5 + 0.6 * np.clip(T.noise(hw, 200, seed + 7, 2), 0, 1))
    a = T.blend(a, np.dstack([54, 74, 42]).astype(F32), moss * 0.5)
    n = T.height_normal_uv(hgt, PPM, PPM, 1.0)
    r = np.clip(0.80 + (blade - 0.5) * 0.18 - moss * 0.08, 0.55, 0.97)
    return np.clip(a, 34, 220), r, n, np.clip(moss + leaf, 0, 1), np.zeros(hw, F32)


REGIONS = (("stone", stone_region, 900), ("earth", earth_region, 950), ("turf", turf_region, 975))


def build():
    alb = np.full((M, M, 3), 120.0, F32)
    rgh = np.full((M, M), 0.8, F32)
    nor = np.dstack([np.zeros((M, M)), np.zeros((M, M)), np.ones((M, M))]).astype(F32)
    met = np.zeros((M, M), F32)
    sig = np.zeros((M, M), F32)
    for region, fn, seed in REGIONS:
        a, r, n, s, m = fn(seed)
        x0, y0, x1, y1 = L.px_rect(region)
        alb[y0:y1, x0:x1], rgh[y0:y1, x0:x1] = a, r
        nor[y0:y1, x0:x1], met[y0:y1, x0:x1], sig[y0:y1, x0:x1] = n, m, s
    alb = T.desat(alb, 0.11)                       # the greens stay green, not signal-bright (05 palette)
    nor[..., :2] *= 1.45                           # stronger split-stone relief at close range
    nor = renorm(nor)
    wa, wr = T.wet(alb, rgh, darken=0.24, gloss=0.28)
    wa = T.desat(wa, 0.18)                         # rain does not make moss louder (wet()'s saturation lift)
    return alb, rgh, nor, met, np.clip(wa, 30, 240), wr, sig


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT, help="shipping map folder (default assets/textures/M_Road_CornishHedge)")
    args = ap.parse_args()
    alb, rgh, nor, met, wa, wr, sig = build()
    T.save_set(args.out, STEM, alb, rgh, nor, met=met, size=SHIP, wet_maps=(wa, wr), master_dir=MASTERS)
    sig_i = Image.fromarray((np.clip(sig, 0, 1) * 255).astype(np.uint8)).resize((SHIP, SHIP), Image.NEAREST)
    sig_i.point(lambda v: 255 if v > 60 else 0).save(os.path.join(HERE, "%s_signal.png" % STEM))
    print("wrote", STEM, "->", os.path.relpath(args.out, T.GAME), "masters", os.path.relpath(MASTERS, T.GAME))


if __name__ == "__main__":
    main()
