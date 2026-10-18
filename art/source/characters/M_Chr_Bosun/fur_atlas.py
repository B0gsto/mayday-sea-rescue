#!/usr/bin/env python3
"""Rendered fur-card atlas for M_Chr_Bosun (the Newfoundland): real strands grown in Blender, assembled with numpy.

Two steps (render once, re-assemble as often as you like; the assembly is cheap and needs no heavy slot):

    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Chr_Bosun/fur_atlas.py -- [--cache DIR] [--samples 64]
    python3 art/source/characters/M_Chr_Bosun/fur_atlas.py [--cache DIR] [--size 4096] [--ship]

Step 1 (inside Blender) builds, per variant (dry / wet), one Curves object holding every strand of all 8 atlas cells
laid out in world space exactly like the atlas (cell = 1 x 2 units, column c at x = c, UV row r at y = 2 r), renders it
with Cycles through an orthographic top camera on a transparent film and dumps the passes it needs (alpha, normal,
AO and AOVs: intercept, per-strand tone / bleach / layer, height) as float16 .npy files into the cache dir
(default /tmp/bosun_fur_cache).
Step 2 (system python3: numpy + Pillow) turns the passes into the masters textures/T_Bosun_Fur_<ALB|NOR|RGH|MET>
[_Wet].png (4096 px; ALB is RGBA, alpha = anti-aliased strand coverage) and prints per-cell coverage and colour stats.

Atlas contract (bosun.py card UVs): 4 columns x 2 rows of equal cells. Columns: 0 long wavy clump (ruff / chest /
belly / breeches / feathering), 1 medium clump (back / sides), 2 short tuft (head / paws), 3 tail plume. Rows: two
variants (UV row 0 = bottom half of the image). Strands root at the cell bottom (cell V = 0) and their tips point up.
Each cell: a dense crinkled undercoat across the full root strip, a clumped mid coat, sparse long guard hairs with
thin tapered tips (a fraction sun-faded brown) and a few strays. Dry colour: warm brown-black coat (sRGB ~(31,27,24)),
a grey-brown sheen down the strand centres (~(50,45,40)), sun-bleached warm-brown guard tips (~(70,58,46)); darkest
texels held at sRGB luma 22 (check_textures floor 20); roughness ~0.6-0.65. _Wet: same footprint, fewer strands
stuck into a few pointed spikes with gaps between them (alpha coverage ~0.46 vs ~0.61 dry), soaked base sRGB luma
~18-22 (soft knee so finalize.py's luma floor of 18 does not flatten it), roughness ~0.27-0.33, stronger clump
normals, and water beads (alpha, dome normal, roughness 0.05) hanging off the spike tips of the long-clump and plume
cells (columns 0 and 3: ruff / chest / belly / breeches, tail / feathering). MET is all 0 (one file).
--ship also writes the 2048 Fur maps to assets/textures/M_Chr_Bosun/ (Fur-only copy of finalize.py's step).
Only the wet strands changed since the dry passes were rendered: re-render with `-- --only wet` after editing them.
"""
import argparse
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "textures")
CACHE = "/tmp/bosun_fur_cache"
PX = 1.0 / 1024.0          # one 4096-atlas texel in world units (cell width = 1 unit = 1024 px)
H = 2.0                    # cell height in world units
S = 24                     # points per strand
TIPS = {}                  # (col, row, wet) -> (K, 2) clump tip positions, filled by grow_cell

KINDS = [
    # 0 long wavy clump
    dict(under=1500, under_len=(0.28, 0.52), mid=1150, clumps=8, mid_len=(0.66, 0.93), guards=150,
         guard_len=(0.80, 0.97), strays=36, wave=0.035, freq=1.6, fan=0.16, crinkle=0.008),
    # 1 medium clump
    dict(under=1500, under_len=(0.28, 0.50), mid=1050, clumps=7, mid_len=(0.58, 0.88), guards=115,
         guard_len=(0.74, 0.95), strays=30, wave=0.013, freq=1.2, fan=0.12, crinkle=0.006),
    # 2 short tuft
    dict(under=1750, under_len=(0.30, 0.50), mid=1100, clumps=9, mid_len=(0.48, 0.80), guards=90,
         guard_len=(0.62, 0.90), strays=26, wave=0.006, freq=1.0, fan=0.30, crinkle=0.005),
    # 3 tail plume / leg feathering
    dict(under=1350, under_len=(0.30, 0.52), mid=1250, clumps=6, mid_len=(0.70, 0.95), guards=190,
         guard_len=(0.84, 0.97), strays=46, wave=0.05, freq=1.8, fan=0.24, crinkle=0.009),
]


# ======================================================================================== strand generation (numpy)

def _taper(t, r0, start, power, tip):
    """radius along t: full until `start`, then falls to `tip` with `power`."""
    f = np.clip((1.0 - t) / max(1e-6, 1.0 - start), 0.0, 1.0) ** power
    return r0[:, None] * f + tip


def grow_cell(col, row, wet, seed):
    """Returns (pos (N,S,3) cell-local, radius (N,S), tone (N,), bleach (N,), layer (N,))."""
    rng = np.random.default_rng(seed)
    k = KINDS[col]
    t = np.linspace(0.0, 1.0, S)[None, :]
    wv = 0.45 if wet else 1.0                       # wet hair hangs straighter
    out = []

    # clump guides (shared by the mid coat, loosely followed by guards)
    K = max(2, int(round(k["clumps"] * (0.5 if wet else 1.0))))
    ck = np.linspace(0.08, 0.92, K) + rng.uniform(-0.35, 0.35, K) * (0.84 / K)
    c_len = rng.uniform(*k["mid_len"], K) * H
    c_lean = rng.normal(0, 0.10, K) + k["fan"] * (ck - 0.5)
    c_amp = k["wave"] * rng.uniform(0.6, 1.35, K) * wv
    c_ph = rng.uniform(0, 2 * math.pi, K)
    c_fr = k["freq"] * rng.uniform(0.8, 1.2, K)
    c_bend = rng.normal(0, 0.05, K)
    c_dz = rng.uniform(-0.010, 0.014, K)
    spacing = 0.84 / K

    def guide_x(ci, tt):
        L = c_len[ci][:, None]
        return (ck[ci][:, None] + np.sin(c_lean[ci])[:, None] * L * tt + c_bend[ci][:, None] * L * tt ** 2
                + c_amp[ci][:, None] * np.sin(2 * math.pi * c_fr[ci][:, None] * tt + c_ph[ci][:, None])
                * np.minimum(1.0, tt * 3.0))

    if wet:  # wet spikes follow their guide to the tip: keep every tip inside the cell (no blunt cuts at the border)
        tip = guide_x(np.arange(K), 1.0)[:, 0]
        c_lean = np.arcsin(np.clip(np.sin(c_lean) + (np.clip(tip, 0.12, 0.88) - tip) / c_len, -0.8, 0.8))

    # clump tips (cell-local x, y), used by the assembly to hang water beads on the wet clumps
    TIPS[(col, row, wet)] = np.stack([guide_x(np.arange(K), 1.0)[:, 0], c_len * np.cos(c_lean)], -1)

    def clumped(n, length_rng, pull, pull_pow, root_sigma, len_jit, own_wave, own_lean):
        ci = rng.integers(0, K, n)
        ur = np.clip(ck[ci] + rng.normal(0, root_sigma, n), 0.015, 0.985)
        L = (c_len[ci] * rng.uniform(*len_jit, n)) if length_rng is None else rng.uniform(*length_rng, n) * H
        lean = c_lean[ci] + rng.normal(0, own_lean, n)
        amp = own_wave * rng.uniform(0.4, 1.4, n) * wv
        ph = c_ph[ci] + rng.normal(0, 0.6, n)
        xs = (ur[:, None] + np.sin(lean)[:, None] * L[:, None] * t
              + amp[:, None] * np.sin(2 * math.pi * c_fr[ci][:, None] * t + ph[:, None]) * np.minimum(1, t * 3))
        tg = np.clip(t * (L / c_len[ci])[:, None], 0, 1)
        c = pull * t ** pull_pow
        x = xs + (guide_x(ci, tg) - xs) * c
        y = L[:, None] * t * np.cos(lean)[:, None]
        return ci, ur, x, y

    # ---- undercoat: dense, short, crinkled, deepest layer
    n = int(k["under"] * (0.55 if wet else 1.0))     # wet: the undercoat mats down into the clumps, gaps open
    ur = rng.uniform(0.012, 0.988, n)
    L = rng.uniform(*k["under_len"], n) * H
    lean = rng.normal(0, 0.16, n) + k["fan"] * 0.7 * (ur - 0.5)
    bend = rng.normal(0, 0.10, n)
    camp = k["crinkle"] * rng.uniform(0.4, 1.3, n) * (0.4 if wet else 1.0)
    cfr = rng.uniform(2.5, 6.0, n)
    cph = rng.uniform(0, 2 * math.pi, n)
    x = (ur[:, None] + np.sin(lean)[:, None] * L[:, None] * t + bend[:, None] * L[:, None] * t ** 2
         + camp[:, None] * np.sin(2 * math.pi * cfr[:, None] * t + cph[:, None]) * np.sqrt(t))
    if wet:  # wet undercoat mats towards the nearest clump
        near = ck[np.argmin(np.abs(ur[:, None] - ck[None, :]), axis=1)]
        x = x + (near[:, None] - ur[:, None]) * 0.8 * t ** 0.8
    y = L[:, None] * t * np.cos(lean)[:, None]
    z = np.broadcast_to(rng.uniform(-0.08, -0.03, n)[:, None], x.shape)
    r = _taper(t, rng.uniform(1.4, 2.1, n) * PX * (0.8 if wet else 1.0), 0.45, 0.75, 0.12 * PX)
    out.append((x, y, z, r, rng.uniform(0, 1, n), np.zeros(n), np.zeros(n)))

    # ---- mid coat: clumped
    n = int(k["mid"] * (0.7 if wet else 1.0))
    # wet: strands stuck together into pointed spikes (pulled onto the guide early, ending together at its tip)
    ci, ur, x, y = clumped(n, None, 0.985 if wet else 0.68, 0.75 if wet else 1.4, spacing * (0.42 if wet else 0.6),
                           (0.88, 1.0) if wet else (0.80, 1.03), k["wave"] * 0.15, 0.03 if wet else 0.05)
    d = np.abs(ur - ck[ci]) / (spacing * 0.6)
    z = np.broadcast_to((-0.02 + c_dz[ci] + (0.024 if wet else 0.008) * np.exp(-d * d)
                         + rng.uniform(-0.005, 0.005, n))[:, None], x.shape)
    r = _taper(t, rng.uniform(1.7, 2.6, n) * PX * (0.8 if wet else 1.0), 0.45, 0.85, 0.10 * PX)
    bl = np.where(rng.random(n) < 0.22, rng.uniform(0.15, 0.55, n), 0.0)
    out.append((x, y, z, r, rng.uniform(0, 1, n), bl, np.full(n, 0.5)))

    # ---- guard hairs: long, sparse, thin tapered tips, loosely clumped
    n = int(k["guards"] * (0.55 if wet else 1.0))
    ci, ur, x, y = clumped(n, None if wet else k["guard_len"], 0.96 if wet else 0.35, 1.2,   # wet: end at the spike tip
                           spacing * (0.6 if wet else 1.2), (0.9, 1.04) if wet else None,
                           k["wave"] * 0.6 + 0.004, 0.07)
    z = np.broadcast_to(rng.uniform(0.004, 0.03, n)[:, None], x.shape)
    r = _taper(t, rng.uniform(2.0, 3.0, n) * PX, 0.30, 1.25, 0.08 * PX)
    bl = np.where(rng.random(n) < 0.5, rng.uniform(0.45, 1.0, n), 0.0)
    out.append((x, y, z, r, rng.uniform(0, 1, n), bl, np.ones(n)))

    # ---- strays
    n = int(k["strays"] * (0.2 if wet else 1.0))
    ur = rng.uniform(0.05, 0.95, n)
    L = rng.uniform(0.3, 0.85, n) * H * (0.9 if col == 2 else 1.0)
    lean = rng.normal(0, 0.38, n)
    bend = rng.normal(0, 0.28, n)
    x = ur[:, None] + np.sin(lean)[:, None] * L[:, None] * t + bend[:, None] * L[:, None] * t ** 2
    y = L[:, None] * t * np.cos(lean)[:, None]
    z = np.broadcast_to(rng.uniform(0.02, 0.04, n)[:, None], x.shape)
    r = _taper(t, rng.uniform(1.2, 1.9, n) * PX, 0.35, 1.1, 0.08 * PX)
    bl = np.where(rng.random(n) < 0.5, rng.uniform(0.3, 0.9, n), 0.0)
    out.append((x, y, z, r, rng.uniform(0, 1, n), bl, np.ones(n)))

    X = np.concatenate([o[0] for o in out])
    Y = np.concatenate([o[1] for o in out]) + 0.004
    Z = np.concatenate([np.asarray(o[2]) for o in out])
    R = np.concatenate([o[3] for o in out])
    tone, bleach, layer = (np.concatenate([o[i] for o in out]) for i in (4, 5, 6))
    # stay inside the cell: a strand leaving it is cut (radius 0) from that point on, never clamped onto the border
    m = 0.012
    outside = (X < m) | (X > 1 - m) | (Y > H - 0.03) | (Y < 0.002)
    outside = np.cumsum(outside, axis=1) > 0
    R = np.where(outside, 0.0, R)
    X = np.clip(X, m, 1 - m)
    Y = np.clip(Y, 0.002, H - 0.03)
    return np.stack([X, Y, Z], -1), R, tone, bleach, layer


# ================================================================================================ Blender render

def blender_main(argv):
    import bpy

    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=CACHE)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--res", type=int, default=4096)
    ap.add_argument("--only", default="", help="dry or wet (default both)")
    a = ap.parse_args(argv)
    os.makedirs(a.cache, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
        print("fur_atlas: cycles devices", [d.name for d in prefs.devices if d.use])
    except Exception as e:  # noqa: BLE001
        print("fur_atlas: GPU unavailable, CPU render:", e)
    sc.cycles.samples = a.samples
    sc.cycles.use_adaptive_sampling = False
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 0
    sc.cycles.pixel_filter_type = "BLACKMAN_HARRIS"
    sc.cycles.filter_width = 1.5
    sc.cycles_curves.shape = "THICK"
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = a.res
    sc.render.resolution_percentage = 100
    w = bpy.data.worlds.new("W")
    sc.world = w
    w.light_settings.distance = 0.05

    cam_d = bpy.data.cameras.new("Cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 4.0
    cam_d.clip_end = 20
    cam = bpy.data.objects.new("Cam", cam_d)
    cam.location = (2.0, 2.0, 5.0)
    sc.collection.objects.link(cam)
    sc.camera = cam

    sc.view_settings.view_transform = "Standard"

    # Data are rendered as emission into Combined RGBA (premultiplied by coverage, alpha = coverage), three
    # renders per variant: A = (intercept, tone, bleach), B = (layer, height, AO), C = normal * 0.5 + 0.5.
    def make_mat(mode):
        mat = bpy.data.materials.new("Fur_" + mode)
        nt = mat.node_tree if mat.node_tree else None
        if nt is None:
            mat.use_nodes = True
            nt = mat.node_tree
        nt.nodes.clear()
        outn = nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Strength"].default_value = 1.0
        nt.links.new(em.outputs[0], outn.inputs["Surface"])
        comb = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(comb.outputs[0], em.inputs["Color"])
        hi = nt.nodes.new("ShaderNodeHairInfo")
        geo = nt.nodes.new("ShaderNodeNewGeometry")

        def attr(nm):
            at = nt.nodes.new("ShaderNodeAttribute")
            at.attribute_type = "GEOMETRY"
            at.attribute_name = nm
            return at.outputs["Fac"]

        def remap(sock, mul, add):
            m = nt.nodes.new("ShaderNodeVectorMath")
            m.operation = "MULTIPLY_ADD"
            nt.links.new(sock, m.inputs[0])
            m.inputs[1].default_value = (mul, mul, mul)
            m.inputs[2].default_value = (add, add, add)
            return m.outputs[0]

        if mode == "A":
            nt.links.new(hi.outputs["Intercept"], comb.inputs[0])
            nt.links.new(attr("tone"), comb.inputs[1])
            nt.links.new(attr("bleach"), comb.inputs[2])
        elif mode == "B":
            nt.links.new(attr("layer"), comb.inputs[0])
            sep = nt.nodes.new("ShaderNodeSeparateXYZ")
            nt.links.new(geo.outputs["Position"], sep.inputs[0])
            mz = nt.nodes.new("ShaderNodeMath")
            mz.operation = "MULTIPLY_ADD"
            nt.links.new(sep.outputs["Z"], mz.inputs[0])
            mz.inputs[1].default_value = 5.0
            mz.inputs[2].default_value = 0.5
            nt.links.new(mz.outputs[0], comb.inputs[1])
            ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
            ao.samples = 16
            ao.inputs["Distance"].default_value = 0.05
            nt.links.new(ao.outputs["AO"], comb.inputs[2])
        else:
            nt.nodes.remove(comb)
            nt.links.new(remap(geo.outputs["Normal"], 0.5, 0.5), em.inputs["Color"])
        return mat

    mats = {m: make_mat(m) for m in "ABC"}
    import OpenImageIO as oiio

    def render_rgba(path):
        ims = sc.render.image_settings
        if hasattr(ims, "media_type"):
            ims.media_type = "IMAGE"
        ims.file_format = "OPEN_EXR"
        ims.color_mode = "RGBA"
        ims.color_depth = "32"
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        inp = oiio.ImageInput.open(path)
        spec = inp.spec()
        px = inp.read_image(0, 0, 0, spec.nchannels, "float")
        inp.close()
        return px

    for wet in (False, True):
        tag = "wet" if wet else "dry"
        if a.only and a.only != tag:
            continue
        P, R, TN, BL, LY = [], [], [], [], []
        for col in range(4):
            for row in range(2):
                p, r, tn, bl, ly = grow_cell(col, row, wet, 7100 + col * 10 + row + (500 if wet else 0))
                p = p.copy()
                p[..., 0] += col
                p[..., 1] += row * H
                P.append(p), R.append(r), TN.append(tn), BL.append(bl), LY.append(ly)
        P, R = np.concatenate(P), np.concatenate(R)
        TN, BL, LY = np.concatenate(TN), np.concatenate(BL), np.concatenate(LY)
        n = len(P)
        cv = bpy.data.hair_curves.new("Fur_" + tag)
        cv.add_curves([S] * n)
        cv.attributes["position"].data.foreach_set("vector", P.reshape(-1).astype(np.float32))
        if "radius" not in cv.attributes:
            cv.attributes.new("radius", "FLOAT", "POINT")
        cv.attributes["radius"].data.foreach_set("value", R.reshape(-1).astype(np.float32))
        for nm, arr in (("tone", TN), ("bleach", BL), ("layer", LY)):
            at = cv.attributes.new(nm, "FLOAT", "CURVE")
            at.data.foreach_set("value", arr.astype(np.float32))
        cv.materials.append(mats["A"])
        ob = bpy.data.objects.new("Fur_" + tag, cv)
        sc.collection.objects.link(ob)
        print("fur_atlas: %s %d strands, %d points" % (tag, n, n * S))
        dump = {}
        for mode, names in (("A", ("icpt", "tone", "bleach")), ("B", ("layer", "hz", "ao")),
                            ("C", ("nx", "ny", "nz"))):
            cv.materials[0] = mats[mode]
            px = render_rgba(os.path.join(a.cache, "fur_%s_%s.exr" % (tag, mode)))
            for i, nm in enumerate(names):
                dump[nm] = px[..., i]
            dump["alpha"] = px[..., 3]
        sc.collection.objects.unlink(ob)
        for nm, arr in dump.items():
            np.save(os.path.join(a.cache, "%s_%s.npy" % (tag, nm)), arr.astype(np.float16))
        print("fur_atlas: wrote %s passes to %s" % (tag, a.cache))


# ============================================================================================ assembly (numpy/PIL)

def blur(img, sigma):
    """separable gaussian-ish blur: three box passes via cumulative sums (no scipy)."""
    r = max(1, int(round(sigma * 0.9)))
    out = img.astype(np.float32)
    for axis in (0, 1):
        for _ in range(3):
            pad = [(0, 0)] * out.ndim
            pad[axis] = (r + 1, r)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
            hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
            out = (hi - lo) / (2 * r + 1)
    return out


def push_pull(val, w):
    """fill texels with weight ~0 from weighted coarser levels (dilation that never mixes in background)."""
    levels = [(val * w[..., None], w)]
    while levels[-1][1].shape[0] > 4:
        v, ww = levels[-1]
        h, wd = ww.shape
        v = v.reshape(h // 2, 2, wd // 2, 2, -1).sum((1, 3))
        ww = ww.reshape(h // 2, 2, wd // 2, 2).sum((1, 3))
        levels.append((v, ww))
    v, ww = levels[-1]
    filled = v / np.maximum(ww, 1e-8)[..., None]
    for v, ww in reversed(levels[:-1]):
        up = np.repeat(np.repeat(filled, 2, 0), 2, 1)
        own = v / np.maximum(ww, 1e-8)[..., None]
        k = np.clip(ww * 4.0, 0, 1)[..., None]
        filled = own * k + up * (1 - k)
    return filled


def srgb_to_lin(c):
    c = np.asarray(c, np.float32) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb8(c):
    c = np.clip(c, 0, 1)
    s = np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)
    return np.clip(np.round(s * 255), 0, 255).astype(np.uint8)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


BEAD_COLS = (0, 3)          # long clump (ruff / chest / belly / breeches) and plume (tail / feathering) cells


def add_beads(A, lin, nt, rg):
    """wet only: water beads hanging off the clump tips of the BEAD_COLS cells (alpha, albedo, dome normal, gloss)."""
    h, w = A.shape
    upx = w / 4.0                                     # texels per world unit
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n = 0
    for col in BEAD_COLS:
        for row in range(2):
            grow_cell(col, row, True, 7100 + col * 10 + row + 500)
            rng = np.random.default_rng(4400 + col * 10 + row)
            for tx, ty in TIPS[(col, row, True)]:
                if rng.random() > 0.85 or not (0.08 < tx < 0.92 and 0.3 < ty < H - 0.08):
                    continue
                r = rng.uniform(15.0, 22.0) * upx / 1024.0
                rx, ry = r, r * rng.uniform(1.15, 1.35)
                cx = (col + tx) * upx
                cy = h - (row * H + ty) * upx - ry * 0.35          # hangs just past the tip (+V = towards the tip)
                x0, x1 = int(max(0, cx - rx - 3)), int(min(w, cx + rx + 4))
                y0, y1 = int(max(0, cy - ry - 3)), int(min(h, cy + ry + 4))
                u = (xx[y0:y1, x0:x1] - cx) / rx
                v = -(yy[y0:y1, x0:x1] - cy) / ry                   # +v = up the texture (OpenGL +Y)
                v = v * np.where(v > 0, 1.0, 1.0 - 0.5 * v)        # teardrop: necks in towards the fur (-v)
                d = np.sqrt(u * u + v * v)
                ab = 1.0 - smooth(1.0 - 1.6 / r, 1.0, d)
                if not ab.any():
                    continue
                body = np.array([34.0, 37.0, 41.0])
                caus = np.exp(-(u * u / 0.22 + (v + 0.55) ** 2 / 0.05))          # refracted light, lower rim
                spec = np.exp(-((u + 0.32) ** 2 + (v - 0.42) ** 2) / 0.018)      # sky glint, upper side
                rim = smooth(0.70, 1.0, d)
                c = body * (1.0 - 0.35 * rim)[..., None]
                c = c + (np.array([125.0, 132.0, 140.0]) - c) * (0.8 * caus)[..., None]
                c = c + (np.array([222.0, 228.0, 234.0]) - c) * spec[..., None]
                nz = np.sqrt(np.clip(1.0 - d * d, 0.09, 1.0))
                bn = np.stack([u, v, nz], -1)
                bn /= np.linalg.norm(bn, axis=-1, keepdims=True)
                k = ab[..., None]
                sl = (slice(y0, y1), slice(x0, x1))
                lin[sl] = lin[sl] * (1 - k) + srgb_to_lin(c) * k
                nt[sl] = nt[sl] * (1 - k) + bn * k
                rg[sl] = rg[sl] * (1 - ab) + 0.05 * ab
                A[sl] = ab + A[sl] * (1 - ab)
                n += 1
    nt /= np.maximum(np.linalg.norm(nt, axis=-1, keepdims=True), 1e-6)
    print("[wet] %d water beads on cells %s" % (n, BEAD_COLS))
    return A, lin, nt, rg


def assemble(tag, cache, size, out=OUT):
    from PIL import Image

    wet = tag == "wet"
    L = {nm: np.load(os.path.join(cache, "%s_%s.npy" % (tag, nm))).astype(np.float32)
         for nm in ("alpha", "nx", "ny", "nz", "ao", "icpt", "tone", "bleach", "layer", "hz")}
    A = np.clip(L["alpha"], 0, 1)
    inv = 1.0 / np.maximum(A, 1e-4)
    un = {nm: L[nm] * inv for nm in ("nx", "ny", "nz", "ao", "icpt", "tone", "bleach", "layer", "hz")}
    un["hz"] = (un["hz"] - 0.5) / 5.0                                  # back to world z
    for nm in ("nx", "ny", "nz"):
        un[nm] = un[nm] * 2.0 - 1.0
    tt = np.clip(un["icpt"], 0, 1)
    tone = np.clip(un["tone"], 0, 1)
    bleach = np.clip(un["bleach"], 0, 1)
    layer = np.clip(un["layer"], 0, 1)
    ao = np.clip(un["ao"], 0, 1)

    # ---- albedo in sRGB terms, per strand: warm brown-black root -> body with a grey-brown sheen down the strand
    #      centre -> (guards / some mid) sun-bleached warm-brown tips
    base = np.array([40.0, 33.0, 27.0]) * (0.90 + 0.20 * tone)[..., None]     # round 4: lifted, warmer (was 31,27,24)
    root = base * 0.86
    srgb = root + (base - root) * smooth(0.0, 0.40, tt)[..., None]
    face = np.clip(un["nz"], 0, 1) ** 2                                   # strand centre (faces the card normal)
    band = smooth(0.20, 0.55, tt) * (1.0 - 0.6 * smooth(0.80, 1.0, tt))
    sheen = (0.25 + 0.55 * tone) * band * face * (0.45 + 0.55 * (layer > 0.25)) * (0.3 if wet else 1.0)
    srgb = srgb + (np.array([64.0, 53.0, 43.0]) - srgb) * sheen[..., None]     # warm brown sun-tint in the mid-tones
    tip = np.array([96.0, 72.0, 50.0])
    sun = np.clip(bleach * 1.35, 0, 1) + 0.18 * (layer > 0.25)        # some strong, all mid/guard tips a little
    fade = np.clip(sun, 0, 1) * smooth(0.45, 1.0, tt) ** 1.4 * (0.3 if wet else 1.0)
    srgb = srgb + (tip - srgb) * fade[..., None]
    lin = srgb_to_lin(srgb)
    occl = (0.80 + 0.20 * ao) * (0.88 + 0.12 * smooth(0.0, 0.3, tt))         # AO + root darkening
    lin = lin * occl[..., None]
    if wet:
        lin = lin * 0.50                                                   # soaked: dark, clearly apart from dry
    # sRGB luma floor: dry keeps its darkest texels at the non-metal albedo floor (check_textures: 1st pct >= 20);
    # wet gets a soft knee into 18..22 so finalize.py's luma_clamp(18) never flattens the soaked coat
    y = (lin_to_srgb8(lin).astype(np.float32) * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(-1)
    yt = np.where(y < 24.0, 20.0 + (np.clip(y, 12.0, 24.0) - 12.0) / 3.0, y) if wet else np.maximum(y, 31.0)
    lin = lin * (srgb_to_lin(yt) / np.maximum(srgb_to_lin(np.maximum(y, 1.0)), 1e-6))[..., None]

    # ---- normal: strand cylinder normals (camera = card space, +Y up) + clump / layer normals from height
    n = np.stack([un["nx"], un["ny"], un["nz"]], -1)
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    wh = smooth(0.05, 0.5, A)
    hz = un["hz"] * wh + push_pull(un["hz"][..., None], wh)[..., 0] * (1 - wh)   # no cliffs at strand / cell edges
    hb = blur(hz, 4.0 if wet else 5.0)
    gy, gx = np.gradient(hb)
    kk = (1.9 if wet else 0.9) * 1024 / 4 * (4096 / size)                  # wet: stronger clump relief
    clump = np.stack([-gx * kk, gy * kk, np.zeros_like(gx)], -1)   # image rows go down: +gy (down) -> -Y
    nt = np.stack([n[..., 0] * 0.65, n[..., 1] * 0.65, np.ones_like(A)], -1) + clump
    nt /= np.linalg.norm(nt, axis=-1, keepdims=True)

    # ---- roughness
    if wet:
        rg = 0.35 - 0.08 * smooth(0.2, 1.0, tt) - 0.02 * layer + 0.02 * (tone - 0.5)   # ~0.25-0.35
    else:
        rg = 0.71 + 0.04 * (tone - 0.5) - 0.03 * layer - 0.08 * layer * smooth(0.5, 1.0, tt) + 0.02 * (layer < 0.25)
    rg = np.clip(rg, 0.15, 0.75)

    # ---- dilate everything into empty texels (weights = coverage, so the background never leaks in)
    wgt = smooth(0.02, 0.6, A)
    pack = np.concatenate([lin, nt, rg[..., None]], -1)
    filled = push_pull(pack, wgt)
    k = smooth(0.02, 0.35, A)[..., None]
    pack = pack * k + filled * (1 - k)
    lin, nt, rg = pack[..., :3], pack[..., 3:6], pack[..., 6]
    nt /= np.maximum(np.linalg.norm(nt, axis=-1, keepdims=True), 1e-6)
    if wet:
        A, lin, nt, rg = add_beads(A, lin, nt, rg)

    if A.shape[0] != size:
        pass  # renders are made at the atlas size; finalize.py downsizes for shipping
    a8 = np.clip(np.round(A * 255), 0, 255).astype(np.uint8)
    rgb8 = lin_to_srgb8(lin)
    sfx = "_Wet" if wet else ""
    Image.fromarray(np.dstack([rgb8, a8])).save(os.path.join(out, "T_Bosun_Fur_ALB%s.png" % sfx))
    nor8 = np.clip(np.round((nt * 0.5 + 0.5) * 255), 0, 255).astype(np.uint8)
    Image.fromarray(nor8).save(os.path.join(out, "T_Bosun_Fur_NOR%s.png" % sfx))
    Image.fromarray(np.clip(np.round(rg * 255), 0, 255).astype(np.uint8)).save(
        os.path.join(out, "T_Bosun_Fur_RGH%s.png" % sfx))
    if not wet:
        Image.fromarray(np.zeros_like(a8)).save(os.path.join(out, "T_Bosun_Fur_MET.png"))

    # ---- report
    hh, ww = A.shape
    ch, cw = hh // 2, ww // 4
    print("[%s] cell(col,row): mean alpha | frac alpha>0.9 in lower 40%% | lower-40%% mean alpha" % tag)
    for row in range(2):
        for col in range(4):
            y1 = hh - row * ch
            cell = A[y1 - ch:y1, col * cw:(col + 1) * cw]
            low = cell[int(ch * 0.6):]
            print("  (%d,%d) %.3f | %.3f | %.3f" % (col, row, cell.mean(), (low > 0.9).mean(), low.mean()))
    m = A > 0.5
    y8 = (rgb8[m].astype(np.float32) * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(-1)
    print("[%s] coverage: mean alpha %.3f, alpha>0.5 on %.1f%%" % (tag, A.mean(), 100 * m.mean()))
    print("[%s] alpha>0.5: mean sRGB %s  luma p1 %.1f p50 %.1f p99 %.1f  rough mean %.3f p10-p90 %.2f-%.2f" % (
        tag, rgb8[m].mean(0).round(1), *np.percentile(y8, (1, 50, 99)), rg[m].mean(),
        *np.percentile(rg[m], (10, 90))))
    nm_ = nt[m]
    print("[%s] normal alpha>0.5: mean %s  |xy| mean %.3f" % (tag, nm_.mean(0).round(3),
                                                          np.linalg.norm(nm_[:, :2], axis=1).mean()))
    lo = (A > 0) & (A < 0.1)
    if lo.any():
        print("[%s] low-alpha (0<a<0.1) RGB mean %s max %s" % (tag, rgb8[lo].mean(0).round(1), rgb8[lo].max(0)))
    return rgb8, A


def ship(masters=OUT, size=2048):
    """Fur-only copy of finalize.py's step: masters -> assets/textures/M_Chr_Bosun/ at the set size (does not touch
    the Body / Harness maps other stages own)."""
    from PIL import Image
    import finalize
    os.makedirs(finalize.OUT, exist_ok=True)
    for sfx in ("ALB", "ALB_Wet", "NOR", "NOR_Wet", "RGH", "RGH_Wet", "MET"):
        name = "T_Bosun_Fur_%s.png" % sfx
        im = Image.open(os.path.join(masters, name))
        if sfx.startswith("ALB"):
            arr = np.asarray(im.convert("RGBA"))        # RGB and alpha resized apart: an RGBA resize premultiplies
            rgb = np.asarray(Image.fromarray(arr[..., :3]).resize((size, size), Image.LANCZOS))   # and blacks out
            a8 = np.asarray(Image.fromarray(arr[..., 3]).resize((size, size), Image.LANCZOS))    # the dilated RGB
            im = Image.fromarray(np.dstack([finalize.luma_clamp(rgb), a8]))
        elif sfx.startswith("NOR"):
            n = np.asarray(im.convert("RGB").resize((size, size), Image.LANCZOS), np.float32) / 127.5 - 1.0
            n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
            n[n[..., 2] < 0.05] = (0.0, 0.0, 1.0)
            im = Image.fromarray(((n + 1) * 127.5).clip(0, 255).round().astype(np.uint8))
        else:
            im = im.convert("L").resize((size, size), Image.LANCZOS)
        im.save(os.path.join(finalize.OUT, name), optimize=True)
    print("shipped Fur maps (%d px) to %s" % (size, finalize.OUT))


def main_assemble(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=CACHE)
    ap.add_argument("--size", type=int, default=4096)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--ship", action="store_true", help="also write the 2048 Fur maps to assets/textures/M_Chr_Bosun/")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    dry, Ad = assemble("dry", a.cache, a.size, a.out)
    wet, Aw = assemble("wet", a.cache, a.size, a.out)
    m = (Ad > 0.5) & (Aw > 0.5)
    lum = lambda c: c.astype(np.float32).mean(-1)
    print("wet lighter than dry (both a>0.5): %.4f of texels" % (lum(wet)[m] > lum(dry)[m] + 1).mean())
    if a.ship:
        ship(a.out)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    try:
        import bpy  # noqa: F401
        in_blender = True
    except ImportError:
        in_blender = False
    if in_blender:
        blender_main(args)
    else:
        main_assemble(args)
