"""PBR map checks outside Blender (docs/06 2.1 step 13, docs/12 1.1): system python3 with Pillow and numpy, no heavy slot.

    python3 tools/blender/check_textures.py assets/textures/<Asset>/ [--cap 1024] [--alpha] [--wet]
        [--signal-mask T_<Name>_<Set>=mask.png] [--json report.json]

Per texture set T_<Name>_<Set>_<ALB|NOR|RGH|MET>[_Wet]:
  names        every image in the folder follows the texture name rule; all four maps present
  size         power of two on both sides, at or under the cap (EXPORT_CAP for shipping, 4096 for masters), one size a set
  ALB          RGB 24-bit (RGBA only with --alpha); non-metal pixels sRGB luma 30 to 240, metal pixels 180 to 250
               (metal = MET above 127; 1st and 99th percentiles, so a few stray pixels pass); saturation at most 0.45
               (95th percentile) outside the signal mask
  NOR          RGB, tangent space (blue mostly above 0.5, mean red and green near 0.5), OpenGL: the curl of the slope field
               is near zero only when green means +V (measured at 256, 128 and 64 px); a DirectX map fails, a flat or
               undecided map passes as an info row
  RGH, MET     single-channel 8-bit greyscale (mode L); MET mostly 0 or 1 (info only)
  _Wet         wet ALB at least 10% darker than dry, wet RGH lower than dry (when --wet or a _Wet map exists)
Exit status 1 on any failure. Limits are (tune).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import names  # noqa: E402
from validate import Report  # noqa: E402

ALB_NONMETAL = (30, 240)
ALB_METAL = (180, 250)
SAT_MAX = 0.45
SAT_PCT = 95
WET_DARKER = 0.10
NOR_TANGENT_TOL = 0.08          # mean red / green within this of 0.5
NOR_BLUE_MIN_SHARE = 0.99       # share of pixels with blue above 0.5 (z positive)
NOR_DECIDE = 0.35               # curl share below this: OpenGL; above 1 - this: DirectX
ANALYSE_MAX = 512               # images are downsampled to this for the statistics


def load(path):
    img = Image.open(path)
    img.load()
    return img


def small(img):
    if max(img.size) > ANALYSE_MAX:
        img = img.copy()
        img.thumbnail((ANALYSE_MAX, ANALYSE_MAX), Image.BILINEAR)
    return img


def luma(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def normal_convention(rgb):
    """('opengl' | 'directx' | 'flat' | 'undetermined', curl share). rgb: float array 0..255, shape (h, w, 3)."""
    n = rgb / 127.5 - 1.0
    nz = np.clip(n[..., 2], 0.05, None)
    gx = -n[..., 0] / nz                      # dh/dx
    gy = -n[..., 1] / nz                      # dh/dy_up when green is +V (OpenGL)
    a = (gx[2:, 1:-1] - gx[:-2, 1:-1]) / 2.0  # d gx / d row (rows run down)
    b = (gy[1:-1, 2:] - gy[1:-1, :-2]) / 2.0  # d gy / d column
    e_gl = float(np.mean((-a - b) ** 2))      # curl with V up = -d/drow
    e_dx = float(np.mean((-a + b) ** 2))      # the same with green flipped
    total = e_gl + e_dx
    if total < 1e-6:
        return "flat", 0.0
    share = e_gl / total
    if share < NOR_DECIDE:
        return "opengl", share
    if share > 1 - NOR_DECIDE:
        return "directx", share
    return "undetermined", share


def normal_convention_multiscale(img, scales=(256, 128, 64)):
    """8-bit quantisation noise swamps the curl at full resolution, so measure on box-downsampled copies and keep the
    most decisive scale (noise sits near a share of 0.5, a real convention near 0 or 1)."""
    best = ("flat", 0.0)
    for s in scales:
        if s > max(img.size):
            continue
        conv, share = normal_convention(np.asarray(img.resize((s, s), Image.BOX), dtype=np.float32))
        if conv != "flat" and (best[0] == "flat" or abs(share - 0.5) > abs(best[1] - 0.5)):
            best = (conv, share)
    return best


def group_sets(folder):
    """{(name, set): {('ALB', False): path, ...}}, plus the files that break the name rule."""
    sets, bad = {}, []
    for fn in sorted(os.listdir(folder)):
        stem, ext = os.path.splitext(fn)
        if ext.lower() not in common.MAP_EXTS:
            continue
        try:
            p = names.texture_parts(stem)
        except ValueError as e:
            bad.append((fn, str(e)))
            continue
        sets.setdefault((p["name"], p["set"]), {})[(p["map"], p["wet"])] = os.path.join(folder, fn)
    return sets, bad


def check_set(key, maps, report, cap, alpha=False, want_wet=False, signal_mask=None):
    prefix = "T_%s_%s" % key
    add = lambda subject, check, ok, detail="", info=False: report.add(subject, check, ok, detail, info=info)
    for kind in common.MAP_KINDS:
        add(prefix, "%s present" % kind, (kind, False) in maps, os.path.basename(maps.get((kind, False), "missing")))
    has_wet = any(w for _, w in maps)
    if want_wet or has_wet:
        for kind in ("ALB", "RGH"):
            add(prefix, "%s_Wet present" % kind, (kind, True) in maps, os.path.basename(maps.get((kind, True), "missing")))
    images, sizes = {}, {}
    for (kind, wet), path in sorted(maps.items()):
        img = load(path)
        images[(kind, wet)] = img
        sizes[(kind, wet)] = img.size
        w, h = img.size
        stem = os.path.basename(path)
        add(stem, "size", common.is_pow2(w) and common.is_pow2(h) and w <= cap and h <= cap, "%d x %d, cap %d" % (w, h, cap))
        if kind in ("RGH", "MET"):
            add(stem, "single channel", img.mode == "L", "mode %s (save as 8-bit greyscale)" % img.mode if img.mode != "L" else "8-bit greyscale")
        elif kind == "ALB":
            add(stem, "colour mode", img.mode == "RGB" or (alpha and img.mode == "RGBA"),
                "mode %s%s" % (img.mode, "" if alpha else "; RGBA needs --alpha (foliage, cards, decals)"))
        else:
            add(stem, "colour mode", img.mode == "RGB", "mode %s" % img.mode)
    if len(set(sizes.values())) > 1:
        add(prefix, "one size a set", False, ", ".join("%s%s %dx%d" % (k, "_Wet" if w else "", s[0], s[1]) for (k, w), s in sorted(sizes.items())))

    met = None
    if ("MET", False) in images:
        met_img = small(images[("MET", False)].convert("L"))
        met = np.asarray(met_img, dtype=np.float32)
        mid = float(np.mean((met > 25) & (met < 230)))
        add(prefix + "_MET", "metalness mostly 0 or 1", mid <= 0.1, "%.1f%% of pixels between 0.1 and 0.9" % (100 * mid), info=True)

    for wet in (False, True):
        if ("ALB", wet) not in images:
            continue
        stem = names.texture_stem(key[0], key[1], "ALB", wet)
        img = small(images[("ALB", wet)])
        arr = np.asarray(img.convert("RGBA"), dtype=np.float32)
        rgb, a = arr[..., :3], arr[..., 3]
        size = rgb.shape[:2]
        metal = (np.asarray(Image.fromarray(met.astype(np.uint8)).resize((size[1], size[0]), Image.NEAREST)) > 127) if met is not None else np.zeros(size, bool)
        valid = a >= 128
        y = luma(rgb)
        for label, mask, (lo, hi) in (("non-metal", valid & ~metal, ALB_NONMETAL), ("metal", valid & metal, ALB_METAL)):
            if not mask.any():
                continue
            p1, p99 = np.percentile(y[mask], 1), np.percentile(y[mask], 99)
            if wet:     # a wet albedo is darker on purpose: only the ceiling holds
                add(stem, "%s albedo" % label, p99 <= hi, "luma 99th %.0f, ceiling %d (wet: no floor)" % (p99, hi))
            else:
                add(stem, "%s albedo" % label, p1 >= lo and p99 <= hi, "luma 1st %.0f, 99th %.0f, range %d to %d over %.0f%% of pixels"
                    % (p1, p99, lo, hi, 100 * mask.mean()))
        mx, mn = rgb.max(axis=2), rgb.min(axis=2)
        sat = np.where(mx > 20, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
        keep = valid.copy()
        if signal_mask:
            sig = np.asarray(Image.open(signal_mask).convert("L").resize((size[1], size[0]), Image.NEAREST)) > 127
            keep &= ~sig
        s95 = float(np.percentile(sat[keep], SAT_PCT)) if keep.any() else 0.0
        add(stem, "saturation", s95 <= SAT_MAX, "%dth percentile %.2f, ceiling %.2f%s" % (SAT_PCT, s95, SAT_MAX,
                                                                                      " outside the signal mask" if signal_mask else ""))

    if ("NOR", False) in images:
        stem = names.texture_stem(key[0], key[1], "NOR")
        nor = images[("NOR", False)].convert("RGB")
        rgb = np.asarray(small(nor), dtype=np.float32)
        blue_share = float(np.mean(rgb[..., 2] > 127.5))
        mr, mg = float(rgb[..., 0].mean()) / 255, float(rgb[..., 1].mean()) / 255
        add(stem, "tangent space", blue_share >= NOR_BLUE_MIN_SHARE and abs(mr - 0.5) <= NOR_TANGENT_TOL and abs(mg - 0.5) <= NOR_TANGENT_TOL,
            "blue above 0.5 on %.1f%%, mean red %.2f, green %.2f" % (100 * blue_share, mr, mg))
        conv, share = normal_convention_multiscale(nor)
        add(stem, "OpenGL green", conv != "directx",
            {"opengl": "OpenGL (curl share %.2f)" % share, "directx": "DirectX: flip the green channel (curl share %.2f)" % share,
             "flat": "flat map: convention undetermined", "undetermined": "undetermined (curl share %.2f): check the bake settings" % share}[conv],
            info=conv in ("flat", "undetermined"))

    for kind, rule in (("ALB", "darker"), ("RGH", "lower")):
        if (kind, False) in images and (kind, True) in images:
            dry = float(np.asarray(small(images[(kind, False)]).convert("L"), dtype=np.float32).mean())
            wetv = float(np.asarray(small(images[(kind, True)]).convert("L"), dtype=np.float32).mean())
            ok = wetv <= dry * (1 - WET_DARKER) if kind == "ALB" else wetv < dry
            add(names.texture_stem(key[0], key[1], kind, True), "wet is %s" % rule, ok, "mean %.0f, dry %.0f" % (wetv, dry))


def check_folder(folder, cap=common.EXPORT_CAP, alpha=False, want_wet=False, signal_masks=None):
    report = Report()
    sets, bad = group_sets(folder)
    for fn, why in bad:
        report.add(fn, "naming", False, why)
    if not sets:
        report.add(folder, "texture sets", False, "no T_*_<ALB|NOR|RGH|MET> images")
    for key, maps in sorted(sets.items()):
        check_set(key, maps, report, cap, alpha, want_wet, (signal_masks or {}).get("T_%s_%s" % key))
    return report


def main(argv=None):
    ap = argparse.ArgumentParser(prog="check_textures.py")
    ap.add_argument("folders", nargs="+")
    ap.add_argument("--cap", type=int, default=common.EXPORT_CAP)
    ap.add_argument("--alpha", action="store_true", help="albedo may carry alpha (foliage, cards, decals)")
    ap.add_argument("--wet", action="store_true", help="require _Wet ALB and RGH for every set")
    ap.add_argument("--signal-mask", action="append", default=[], metavar="T_<Name>_<Set>=mask.png")
    ap.add_argument("--json", help="write the rows to this file")
    args = ap.parse_args(argv)
    masks = dict(m.split("=", 1) for m in args.signal_mask)
    rows, ok = [], True
    for folder in args.folders:
        report = check_folder(folder, args.cap, args.alpha, args.wet, masks)
        report.print("textures")
        rows += report.rows
        ok = ok and report.ok
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"ok": ok, "rows": rows}, f, indent=1)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
