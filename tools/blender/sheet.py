"""The review contact sheet (docs/12 section 1.4 item 6), 1536 px wide. System python3 with Pillow; no heavy slot.

    python3 tools/blender/sheet.py --asset <Asset> [--out-root build/x]      # newest <review>/<Asset>/*_report.json
    python3 tools/blender/sheet.py --report assets/review/<Asset>/<date>_report.json [--out sheet.png]
        [--studio <dir>] [--reference <photo or dir>]

Layout, 4 columns of 384 px cells (the turntable frames the asset to fill 70%+ of each cell):
  row 1: the 4 turntable angles under the neutral studio HDRI      (<review>/<Asset>/turntable/, turntable.py)
  row 2: the same 4 angles under the overcast sea HDRI
  row 3: the 4 Studio presets Clear, Overcast, Storm, Night         (<review>/<Asset>/studio/*<Preset>*.png, dry first;
         pending until the Studio pass of 1.4 item 7 writes them)
  detail rows: up to 6 close-ups at hero distance (turntable/closeup_*.png, 1024 px renders), 3 per row in 512 px cells,
         so seams, decals, wear and fasteners are readable
  last row: 1 reference photo (art/reference/<Asset>/, first image by name), the 64 px silhouette (05 10.3 step 4,
         shown at its real size), and a footer: triangles per LOD, texture sets, the real-size check, validate result.
Writes <review>/<Asset>/<date>_sheet.png (or --out) and prints its path.
"""
import argparse
import glob
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

SIZE, CELL, COLS = 1536, 384, 4
DCELL, DCOLS = 512, 3        # detail row cells (close-ups)
SIL = 64
VIEWS = ("Front3Q", "Side", "Rear3Q", "High")
PRESETS = ("Clear", "Overcast", "Storm", "Night")
IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp")
INK, PANEL, SHADE, PENDING = (232, 234, 235), (34, 38, 41), (24, 27, 29), (52, 56, 60)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def fitted(img, w, h, cover=True):
    """Scaled to fill (cover) or fit inside w x h, centred."""
    scale = (max if cover else min)(w / img.width, h / img.height)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    if cover:
        x, y = (img.width - w) // 2, (img.height - h) // 2
        return img.crop((x, y, x + w, y + h))
    out = Image.new("RGB", (w, h), SHADE)
    out.paste(img, ((w - img.width) // 2, (h - img.height) // 2))
    return out


def tag(draw, xy, text, size=11):
    f = font(size)
    box = draw.textbbox(xy, text, font=f)
    draw.rectangle((box[0] - 3, box[1] - 2, box[2] + 3, box[3] + 2), fill=(0, 0, 0))
    draw.text(xy, text, font=f, fill=INK)


def pending(text, w=CELL, h=CELL):
    img = Image.new("RGB", (w, h), PENDING)
    d = ImageDraw.Draw(img)
    for n, line in enumerate(wrap(d, [text], font(16), w - 24)):
        d.text((12, h // 2 - 20 + n * 20), line, font=font(16), fill=(160, 165, 168))
    return img


def wrap(draw, lines, f, width):
    out = []
    for line in lines:
        current = ""
        for word in line.split(" "):
            trial = (current + " " + word).strip()
            if current and draw.textlength(trial, font=f) > width:
                out.append(current)
                current = word
            else:
                current = trial
        out.append(current)
    return out


def silhouette(path):
    """The asset alone as black on white, fitted into 64 x 64 (from the alpha of turntable's silhouette.png)."""
    alpha = Image.open(path).convert("RGBA").getchannel("A")
    box = alpha.point(lambda a: 255 if a > 8 else 0).getbbox()
    if box:
        alpha = alpha.crop(box)
    k = (SIL - 4) / max(alpha.width, alpha.height)
    alpha = alpha.resize((max(1, round(alpha.width * k)), max(1, round(alpha.height * k))), Image.LANCZOS)
    out = Image.new("RGB", (SIL, SIL), (255, 255, 255))
    out.paste((0, 0, 0), ((SIL - alpha.width) // 2, (SIL - alpha.height) // 2), alpha)
    return out


def first_image(path):
    if path and os.path.isfile(path):
        return path
    if path and os.path.isdir(path):
        hits = sorted(p for p in glob.glob(os.path.join(path, "**", "*"), recursive=True) if p.lower().endswith(IMAGE_EXTS))
        return hits[0] if hits else None
    return None


def studio_image(directory, preset):
    """<Preset>*.png or <anything>_<Preset>_*.png (the Studio pass names shots <Asset>_<Preset>_dry|wet), dry first."""
    if not directory or not os.path.isdir(directory):
        return None
    pre = preset.lower()
    hits = [p for p in os.listdir(directory) if p.lower().endswith(IMAGE_EXTS)
            and (p.lower().startswith(pre) or ("_%s_" % pre) in p.lower() or p.lower().endswith("_%s.png" % pre))
            and "helm" not in p.lower() and "closeup" not in p.lower()]
    hits.sort(key=lambda p: ("wet" in p.lower(), p))
    return os.path.join(directory, hits[0]) if hits else None


def closeup_images(tt_dir, tt):
    """[(name, path)] of the detail renders, in the order turntable.json lists them (else by file name)."""
    listed = [(c["name"], os.path.join(tt_dir, c["file"])) for c in (tt or {}).get("closeups") or [] if c.get("file")]
    if not listed and os.path.isdir(tt_dir):
        listed = [(f[len("closeup_"):-4], os.path.join(tt_dir, f)) for f in sorted(os.listdir(tt_dir))
                  if f.startswith("closeup_") and f.endswith(".png")]
    return [(n, p) for n, p in listed if os.path.isfile(p)][:common.CLOSEUP_MAX]


def footer_lines(rep, tt):
    meshes = rep.get("meshes") or []
    per_lod = {}
    for m in meshes:
        key = m.get("lod") or m.get("role") or "?"
        per_lod[key] = per_lod.get(key, 0) + (m.get("triangles") or 0)
    tris = ", ".join("%s %d" % (k, v) for k, v in sorted(per_lod.items()))
    checks = rep.get("checks") or []
    failed = sorted({c["check"] for c in checks if not c.get("ok")})
    size_rows = [c for c in checks if c.get("check", "").startswith("real size")]
    size_ok = all(c.get("ok") for c in size_rows) if size_rows else None
    bbox = rep.get("bbox_studs")
    dims = (tt or {}).get("dims_m")
    want = " x ".join("-" if v is None else "%.2f" % (v * common.STUDS_PER_METRE) for v in dims) if dims else "?"
    have = " x ".join("%.2f" % v for v in bbox) if bbox else "?"
    sets = (tt or {}).get("sets") or []
    applied = (tt or {}).get("maps_applied") or {}
    hdri = (tt or {}).get("hdri") or {}
    return [
        "%s  (%s)  %s" % (rep.get("asset", "?"), rep.get("name", "?"), rep.get("date", "")),
        "Validate: %s, %d checks%s" % ("PASS" if rep.get("ok") else "FAIL", len(checks),
                                       "" if not failed else "; failed: " + ", ".join(failed)),
        "Tris: " + (tris or "?"),
        "Sets: %s; maps on render: %s" % (", ".join(sets) or "none",
                                          "; ".join("/".join(v) for v in applied.values()) or "none"),
        "Size: %s studs vs real %s (%s)" % (have, want, "no check" if size_ok is None else "PASS" if size_ok else "FAIL"),
        "Mannequin 5.5 studs. HDRI %s / %s" % (hdri.get("neutral", "?"), hdri.get("overcast", "?")),
        "Blender %s, commit %s" % (rep.get("blender", "?"), rep.get("commit", "?")),
    ]


def build(report_path, out=None, studio=None, reference=None, turntable_dir=None):
    with open(report_path, "r", encoding="utf-8") as f:
        rep = json.load(f)
    asset = rep["asset"]
    review = os.path.dirname(os.path.abspath(report_path))
    tt_dir = turntable_dir or (rep.get("turntable") or {}).get("dir") or os.path.join(review, "turntable")
    tt = rep.get("turntable")
    if tt is None and os.path.isfile(os.path.join(tt_dir, "turntable.json")):
        with open(os.path.join(tt_dir, "turntable.json"), "r", encoding="utf-8") as f:
            tt = json.load(f)
    studio = studio or os.path.join(review, "studio")
    ref = first_image(reference or common.reference_dir(asset))

    details = closeup_images(tt_dir, tt)
    drows = max(1, (len(details) + DCOLS - 1) // DCOLS)
    dy0 = 3 * CELL
    y = dy0 + drows * DCELL
    height = y + CELL
    sheet = Image.new("RGB", (SIZE, height), PANEL)
    draw = ImageDraw.Draw(sheet)
    filled = {"turntable": 0, "studio": 0, "reference": 0, "silhouette": 0, "closeups": 0}
    for row, short in ((0, "neutral"), (1, "overcast")):
        for col, view in enumerate(VIEWS):
            path = os.path.join(tt_dir, "%s_%s.png" % (view, short))
            if os.path.isfile(path):
                img = Image.open(path).convert("RGB").resize((CELL, CELL), Image.LANCZOS)
                filled["turntable"] += 1
            else:
                img = pending("turntable %s %s missing" % (view, short))
            sheet.paste(img, (col * CELL, row * CELL))
            tag(draw, (col * CELL + 6, row * CELL + 5), "%s %s" % (view, short), 15)
    for col, preset in enumerate(PRESETS):
        path = studio_image(studio, preset)
        if path:
            sheet.paste(fitted(Image.open(path).convert("RGB"), CELL, CELL), (col * CELL, 2 * CELL))
            filled["studio"] += 1
        else:
            sheet.paste(pending("Studio %s: pending (12 1.4 item 7)" % preset), (col * CELL, 2 * CELL))
        tag(draw, (col * CELL + 6, 2 * CELL + 5), "Studio " + preset, 15)
    for i, (name, path) in enumerate(details):
        x0, y0 = (i % DCOLS) * DCELL, dy0 + (i // DCOLS) * DCELL
        sheet.paste(fitted(Image.open(path).convert("RGB"), DCELL, DCELL), (x0, y0))
        tag(draw, (x0 + 6, y0 + 5), "Detail " + name, 15)
        filled["closeups"] += 1
    if not details:
        sheet.paste(pending("Detail: no close-ups (turntable/closeup_*.png; rerun the turntable step)", SIZE, DCELL), (0, dy0))
    if ref:
        sheet.paste(fitted(Image.open(ref).convert("RGB"), CELL, CELL, cover=False), (0, y))
        filled["reference"] = 1
    else:
        sheet.paste(pending("no reference photo in art/reference/%s/" % asset), (0, y))
    tag(draw, (6, y + 5), "Reference", 15)
    sil_cell = Image.new("RGB", (CELL, CELL), (255, 255, 255))
    sil_path = os.path.join(tt_dir, "silhouette.png")
    if os.path.isfile(sil_path):
        sil_cell.paste(silhouette(sil_path), ((CELL - SIL) // 2, (CELL - SIL) // 2))
        filled["silhouette"] = 1
    sheet.paste(sil_cell, (CELL, y))
    tag(draw, (CELL + 6, y + 5), "Silhouette 64 px", 15)
    fx, fw = 2 * CELL, 2 * CELL
    draw.rectangle((fx, y, SIZE - 1, height - 1), fill=SHADE)
    f = font(17)
    lines = wrap(draw, footer_lines(rep, tt), f, fw - 20)
    for n, line in enumerate(lines[:16]):
        draw.text((fx + 10, y + 10 + n * 23), line, font=f, fill=INK)
    for i in range(1, COLS):
        draw.line((i * CELL, 0, i * CELL, dy0), fill=(0, 0, 0))
        draw.line((i * CELL, y, i * CELL, height), fill=(0, 0, 0))
    for i in range(1, DCOLS):
        draw.line((i * DCELL, dy0, i * DCELL, y), fill=(0, 0, 0))
    for yy in (CELL, 2 * CELL, dy0) + tuple(dy0 + k * DCELL for k in range(1, drows + 1)):
        draw.line((0, yy, SIZE, yy), fill=(0, 0, 0))
    out = out or os.path.join(review, "%s_sheet.png" % rep.get("date", common.today()))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet.save(out)
    return out, filled


def latest_report(asset):
    hits = sorted(glob.glob(os.path.join(common.review_dir(asset), "*_report.json")))
    if not hits:
        raise SystemExit("no *_report.json in %s: run run.py with the turntable step first" % common.review_dir(asset))
    return hits[-1]


def main(argv=None):
    p = argparse.ArgumentParser(prog="sheet.py", description=__doc__.split("\n")[0])
    p.add_argument("--asset")
    p.add_argument("--report")
    p.add_argument("--out-root", help="the run.py --out-root the report was written under")
    p.add_argument("--out")
    p.add_argument("--studio", help="folder of Studio preset shots (Clear*, Overcast*, Storm*, Night*)")
    p.add_argument("--reference", help="reference photo or folder (default art/reference/<Asset>/)")
    p.add_argument("--turntable", help="turntable folder (default from the report)")
    a = p.parse_args(argv)
    if a.out_root:
        common.set_out_root(a.out_root)
    if not (a.report or a.asset):
        p.error("--asset or --report is required")
    out, filled = build(a.report or latest_report(a.asset), a.out, a.studio, a.reference, a.turntable)
    print("[sheet] %s (turntable %d/8, studio %d/4, close-ups %d, reference %d, silhouette %d)" % (
        out, filled["turntable"], filled["studio"], filled["closeups"], filled["reference"], filled["silhouette"]))
    return out


if __name__ == "__main__":
    main()
