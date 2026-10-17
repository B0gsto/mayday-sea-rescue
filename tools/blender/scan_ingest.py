"""Ingest a CC0 scan material (Poly Haven, ambientCG; docs/12 1.1 and 1.5) as one of our texture sets.

Pure-image mode (system python3 with Pillow and numpy, no heavy slot):

    python3 tools/blender/scan_ingest.py --src <folder of maps> --asset <Asset> --name <Name> --set <Set> \
        --url <asset page> --author "<author>" [--licence CC0] [--batch B01 | --status <file.csv>] [--wet] \
        [--normal auto|gl|dx] [--ao-strength 0] [--no-fix-range] [--master-dir D] [--out-dir D] [--max-size 4096]

Blender mode (re-bake the tiling scan onto an object's own UVs with box projection, through the heavy slot):

    ~/RobloxProjects/tools/blender-run.sh tools/blender/scan_ingest.py -- <same args> --blend <file.blend> \
        --object M_<Cat>_<Name>_LOD0 [--tile-studs 4] [--bake-size 1024]

What it does: maps file names to our kinds (diff / albedo / basecolor / color -> ALB; nor_gl / NormalGL -> NOR;
nor_dx / NormalDX -> NOR with the green channel inverted; a plain `normal` is measured with check_textures' curl test;
rough -> RGH; metal / metalness -> MET; ao; arm / orm packed (R occlusion, G roughness, B metalness) unpacked; disp and
opacity are ignored), resizes to the largest power of two at or under MASTER (masters, kept in
art/source/<kind>/<Asset>/textures/ or <out-root>/masters/<Asset>/) and --size (default SHIP_SIZE, at most EXPORT_CAP;
common.textures_dir(asset)),
clamps albedo luma into check_textures' ranges (unless --no-fix-range), writes T_<Name>_<Set>_<ALB|NOR|RGH|MET>[_Wet]
(RGH / MET 8-bit greyscale; a missing MET is written black), runs check_textures on the export folder and appends a
licence row (asset, source URL, author, licence, date) to art/status/<Batch>.csv or --status.
"""
import argparse
import csv
import os
import sys

import numpy as np

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
if LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)

import common  # noqa: E402
import names  # noqa: E402
import pbrmaps  # noqa: E402

try:
    import bpy
except ImportError:
    bpy = None

STATUS_HEADER = ["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"]
PREFER_EXT = (".png", ".tif", ".tiff", ".jpg", ".jpeg", ".tga", ".bmp", ".exr")


# ---------------------------------------------------------------- pure helpers

def find_maps(src):
    """{kind: path} for the scan files under `src` (one level deep is enough for both sites); PNG preferred over JPG."""
    found = {}
    for root, _, files in os.walk(src):
        for fn in sorted(files):
            ext = os.path.splitext(fn)[1].lower()
            if ext not in PREFER_EXT:
                continue
            kind = pbrmaps.classify_map_name(fn)
            if kind is None:
                continue
            path = os.path.join(root, fn)
            old = found.get(kind)
            if old is None or PREFER_EXT.index(ext) < PREFER_EXT.index(os.path.splitext(old)[1].lower()):
                found[kind] = path
    return found


def pow2_floor(n):
    p = 1
    while p * 2 <= n:
        p *= 2
    return p


def target_sizes(src_size, max_size=common.MASTER, cap=common.SHIP_SIZE):
    """(master, export) square sizes: the largest power of two at or under the source's shorter side and max_size;
    the export is that capped at `cap` (default SHIP_SIZE, never above EXPORT_CAP)."""
    master = min(pow2_floor(min(src_size)), max_size)
    return master, min(master, cap, common.EXPORT_CAP)


def licence_row(header, info):
    """A CSV row (list) for `header` from info {asset, url, author, licence, date, maps, src}. Known batch columns get
    source = URL, licence, ai_used none, status 'scan ingested'; extra url / author / date columns are filled too."""
    note = "scan_ingest %s: %s by %s, %s; maps %s" % (info["date"], info.get("licence", "CC0"), info.get("author", "unknown"),
                                                       info.get("src", ""), info.get("maps", ""))
    values = {"asset": info["asset"], "status": "scan ingested", "source": info.get("url", ""), "url": info.get("url", ""),
              "licence": info.get("licence", "CC0"), "license": info.get("licence", "CC0"), "author": info.get("author", ""),
              "date": info["date"], "ai_used": "none", "notes": note}
    return [values.get(col.strip(), "") for col in header]


def append_licence(path, info):
    exists = os.path.isfile(path) and os.path.getsize(path) > 0
    header = STATUS_HEADER
    if exists:
        with open(path, newline="", encoding="utf-8") as f:
            header = next(csv.reader(f), STATUS_HEADER)
        row = licence_row(header, info)
        with open(path, newline="", encoding="utf-8") as f:
            if any(r == row or (r[:1] == row[:1] and info.get("url") and info["url"] in r and info.get("maps", "") in ",".join(r))
                   for r in csv.reader(f)):
                return None          # already recorded (re-run)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if not exists:
            w.writerow(header)
        w.writerow(licence_row(header, info))
    return path


def default_master_dir(asset):
    if common.out_root() != common.ASSETS_DIR:
        return os.path.join(common.out_root(), "masters", asset)
    try:
        return os.path.join(common.find_asset_dir(asset), "textures")
    except SystemExit:
        return os.path.join(common.SOURCE_DIR, "_scans", asset, "textures")


def process(arrays, normal_kind, args_wet=False, ao_strength=0.0, fix_range=True, normal_convention=None, max_saturation=None):
    """Pure conversion of loaded float maps (0..1, same size) to ours. arrays: {kind: (H, W[, 3]) float}.
    normal_kind: which of NOR_GL / NOR_DX / NOR was loaded; normal_convention('opengl'|'directx'|...) decides a plain NOR.
    Returns ({(kind, wet): array}, notes)."""
    notes = []
    alb = arrays["ALB"][..., :3]
    packed = next((k for k in ("ARM", "ORM") if k in arrays), None)
    unpacked = pbrmaps.unpack_packed(arrays[packed][..., :3], packed) if packed else {}
    rgh = arrays.get("RGH", unpacked.get("RGH"))
    met = arrays.get("MET", unpacked.get("MET"))
    ao = arrays.get("AO", unpacked.get("AO"))
    for label, a in (("RGH", rgh), ("MET", met), ("AO", ao)):
        if a is not None and a.ndim == 3:
            a = a[..., 0]
        if label == "RGH":
            rgh = a
        elif label == "MET":
            met = a
        else:
            ao = a
    if rgh is None:
        raise ValueError("no roughness map (rough / roughness / arm / orm)")
    if packed:
        notes.append("%s unpacked (R occlusion, G roughness, B metalness)" % packed)
    if met is None:
        met = np.zeros(alb.shape[:2], dtype=np.float32)
        notes.append("no metalness map: MET written black")
    nor = arrays.get(normal_kind)[..., :3] if normal_kind else None
    if nor is None:
        nor = np.zeros(alb.shape, dtype=np.float32) + np.array([0.5, 0.5, 1.0], dtype=np.float32)
        notes.append("no normal map: flat NOR")
    elif normal_kind == "NOR_DX" or (normal_kind == "NOR" and normal_convention == "directx"):
        nor = pbrmaps.flip_green(nor)
        notes.append("normal was DirectX: green inverted to OpenGL")
    if ao is not None and ao_strength > 0:
        alb = alb * (1.0 + (ao - 1.0) * ao_strength)[..., None]
        notes.append("AO x%.2f multiplied into ALB" % ao_strength)
    if max_saturation:
        alb, share = pbrmaps.limit_saturation(alb, max_saturation)
        notes.append("saturation capped at %.2f on %.1f%% of pixels" % (max_saturation, 100 * share))
    if fix_range:
        before = alb
        alb = pbrmaps.clamp_albedo(alb, met)
        changed = float(np.mean(np.abs(alb - before).max(axis=2) > 1.5 / 255))
        if changed > 0:
            notes.append("albedo luma clamped on %.1f%% of pixels" % (100 * changed))
    maps = {("ALB", False): alb, ("NOR", False): nor, ("RGH", False): rgh, ("MET", False): met}
    if args_wet:
        maps[("ALB", True)], maps[("RGH", True)] = pbrmaps.wet(alb, rgh)
    return maps, notes


# ---------------------------------------------------------------- pure-image mode (Pillow)

def load_float(path, size):
    from PIL import Image
    img = Image.open(path)
    img.load()
    if img.mode in ("I;16", "I;16B", "I", "F"):
        a = np.asarray(img, dtype=np.float32)
        a = a / (65535.0 if a.max() > 255 else 255.0)
        img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    if img.mode not in ("L", "RGB", "RGBA"):
        img = img.convert("RGB")
    if img.size != (size, size):
        img = img.resize((size, size), Image.LANCZOS)
    return np.asarray(img, dtype=np.float32) / 255.0


def save_map(path, arr, kind):
    from PIL import Image
    u8 = pbrmaps.to_u8(arr)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if kind in ("RGH", "MET") and u8.ndim == 3:
        u8 = u8[..., 0]
    Image.fromarray(np.ascontiguousarray(u8)).save(path)


def resize_arr(arr, size):
    from PIL import Image
    if arr.shape[0] == size:
        return arr
    u8 = pbrmaps.to_u8(arr)
    return np.asarray(Image.fromarray(u8).resize((size, size), Image.LANCZOS), dtype=np.float32) / 255.0


def write_set(maps, master_dir, export_dir, name, set_name, master, export):
    written = []
    for (kind, wet), arr in sorted(maps.items()):
        stem = names.texture_stem(name, set_name, kind, wet)
        for directory, size in ((master_dir, master), (export_dir, export)):
            path = os.path.join(directory, stem + ".png")
            out = resize_arr(arr, size)
            if kind == "NOR":     # renormalise after resampling
                n = out * 2.0 - 1.0
                out = n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6) * 0.5 + 0.5
            save_map(path, out, kind)
            written.append(path)
    return written


def ingest_images(args):
    from PIL import Image
    import check_textures
    found = find_maps(args.src)
    if "ALB" not in found:
        raise SystemExit("no albedo map (diff / albedo / basecolor / color) under %s; found %s" % (args.src, sorted(found)))
    with Image.open(found["ALB"]) as im:
        master, export = target_sizes(im.size, args.max_size, args.size)
    normal_kind = "NOR_GL" if "NOR_GL" in found else "NOR_DX" if "NOR_DX" in found else "NOR" if "NOR" in found else None
    arrays = {k: load_float(p, master) for k, p in found.items() if k in ("ALB", "RGH", "MET", "AO", "ARM", "ORM", normal_kind)}
    convention = None
    if normal_kind == "NOR":
        if args.normal in ("gl", "dx"):
            convention = {"gl": "opengl", "dx": "directx"}[args.normal]
        else:
            convention, share = check_textures.normal_convention_multiscale(Image.fromarray(pbrmaps.to_u8(arrays["NOR"][..., :3])))
            print("[scan] plain normal map measured as %s (curl share %.2f)" % (convention, share))
    maps, notes = process(arrays, normal_kind, args.wet, args.ao_strength, not args.no_fix_range, convention, args.max_saturation)
    return found, maps, notes, master, export


def main(argv=None):
    if argv is None:
        argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser(prog="scan_ingest.py")
    ap.add_argument("--src", required=True, help="folder holding the downloaded maps (treated as data)")
    ap.add_argument("--asset", required=True)
    ap.add_argument("--name", required=True, help="texture <Name> (PascalCase words joined by _)")
    ap.add_argument("--set", required=True, help="texture <Set> (one PascalCase word)")
    ap.add_argument("--url", default="")
    ap.add_argument("--author", default="")
    ap.add_argument("--licence", default="CC0")
    ap.add_argument("--date", default=common.today())
    ap.add_argument("--batch", help="append the licence row to art/status/<Batch>.csv")
    ap.add_argument("--status", help="append the licence row to this CSV instead")
    ap.add_argument("--normal", choices=("auto", "gl", "dx"), default="auto", help="convention of a plain 'normal' map")
    ap.add_argument("--wet", action="store_true", help="also write _Wet ALB and RGH")
    ap.add_argument("--ao-strength", type=float, default=0.0, help="multiply AO into the albedo (0 = off)")
    ap.add_argument("--no-fix-range", action="store_true", help="do not clamp albedo luma into the check ranges")
    ap.add_argument("--max-saturation", type=float, help="cap albedo HSV saturation (check_textures' ceiling is 0.45)")
    ap.add_argument("--max-size", type=int, default=common.MASTER)
    ap.add_argument("--size", type=int, default=common.SHIP_SIZE,
                    help="export size (default SHIP_SIZE, at most EXPORT_CAP; hero sets may ask 2048 / 4096)")
    ap.add_argument("--master-dir")
    ap.add_argument("--out-dir", help="export folder (default common.textures_dir(asset))")
    ap.add_argument("--out-root", help="like run.py --out-root")
    ap.add_argument("--blend", help="Blender mode: .blend holding the target object")
    ap.add_argument("--object", help="Blender mode: the LOD0 object whose UVs receive the scan")
    ap.add_argument("--tile-studs", type=float, default=4.0, help="Blender mode: studs per scan tile (box projection)")
    ap.add_argument("--bake-size", type=int, default=0, help="Blender mode: bake size (default the master size)")
    args = ap.parse_args(argv)
    if not common.is_pow2(args.size) or args.size > common.EXPORT_CAP:
        ap.error("--size must be a power of two <= EXPORT_CAP %d" % common.EXPORT_CAP)
    for label, value in (("name", args.name), ("set", args.set)):
        problem = names.texture_name_problem(names.texture_stem(args.name, args.set, "ALB"))
        if problem:
            raise SystemExit("--%s: %s" % (label, problem))
    if args.out_root:
        common.set_out_root(args.out_root)
    master_dir = os.path.abspath(args.master_dir) if args.master_dir else default_master_dir(args.asset)
    export_dir = os.path.abspath(args.out_dir) if args.out_dir else common.textures_dir(args.asset)

    if args.blend or args.object:
        if bpy is None:
            raise SystemExit("--blend / --object need Blender: run through ~/RobloxProjects/tools/blender-run.sh")
        found, written, notes = rebake_blender(args, master_dir, export_dir)
    else:
        found, maps, notes, master, export = ingest_images(args)
        written = write_set(maps, master_dir, export_dir, args.name, args.set, master, export)
        notes.append("master %d, export %d" % (master, export))
    for n in notes:
        print("[scan] " + n)
    print("[scan] %d files: %s" % (len(written), ", ".join(sorted({os.path.basename(p) for p in written}))))
    status = args.status or (os.path.join(common.STATUS_DIR, "%s.csv" % args.batch) if args.batch else None)
    if status:
        done = append_licence(status, {"asset": args.asset, "url": args.url, "author": args.author, "licence": args.licence,
                                "date": args.date, "src": os.path.basename(os.path.abspath(args.src)),
                                "maps": "T_%s_%s" % (args.name, args.set)})
        print("[scan] licence row %s %s" % ("appended to" if done else "already in", status))
    else:
        print("[scan] no --batch / --status: licence row NOT recorded")
    ok = True
    if bpy is None:
        import check_textures
        report = check_textures.check_folder(export_dir, want_wet=args.wet)
        ok = report.ok
        fails = report.failures()
        for row in fails:
            print("[scan] check FAIL %s %s %s" % (row["subject"], row["check"], row["detail"]))
        print("[scan] check_textures %s: %d checks, %d failed" % ("PASS" if ok else "FAIL", len(report.rows), len(fails)))
    return 0 if ok else 1


# ---------------------------------------------------------------- Blender mode: re-bake onto our UVs

def rebake_blender(args, master_dir, export_dir):
    """Box-projects the scan onto args.object and bakes ALB / RGH / MET / NOR as emission (data) into its UVs.
    NOR is approximate: the scan's tangent-space colour is copied as is, i.e. read in each face's UV tangent frame
    rather than rotated from the projection frame; fine for isotropic scans (rock, concrete, rust), not for
    directional ones (planks, brushed metal), which should be laid out on UVs instead."""
    import bake
    if args.blend:
        bpy.ops.wm.open_mainfile(filepath=os.path.abspath(args.blend))
    obj = bpy.data.objects.get(args.object)
    if obj is None or obj.type != "MESH":
        raise SystemExit("no mesh object %s" % args.object)
    found = find_maps(args.src)
    if "ALB" not in found:
        raise SystemExit("no albedo map under %s" % args.src)
    size = args.bake_size or bake.bake_size({})
    export = min(size, args.size, common.EXPORT_CAP)
    bake.setup_cycles({}, 1)
    images = {k: bpy.data.images.load(os.path.abspath(p)) for k, p in found.items() if k in ("ALB", "NOR_GL", "NOR_DX", "NOR", "RGH", "MET", "ARM", "ORM")}
    for k, img in images.items():
        img.colorspace_settings.name = "sRGB" if k == "ALB" else "Non-Color"
    normal_kind = next((k for k in ("NOR_GL", "NOR_DX", "NOR") if k in images), None)
    flip = normal_kind == "NOR_DX" or (normal_kind == "NOR" and args.normal == "dx")
    notes = ["re-baked onto %s UVs at %d (box projection, %.1f studs a tile)" % (obj.name, size, args.tile_studs)]
    if flip:
        notes.append("normal was DirectX: green inverted in the bake material")
    if normal_kind:
        notes.append("NOR copied in the UV tangent frame (approximate for directional scans)")

    def tex(nt, key, coords):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image, n.projection, n.projection_blend = images[key], "BOX", 0.2
        nt.links.new(coords, n.inputs["Vector"])
        return n

    def material(mode):
        mat = bpy.data.materials.new("_scan_%s" % mode)
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sc = nt.nodes.new("ShaderNodeVectorMath")
        sc.operation = "SCALE"
        sc.inputs["Scale"].default_value = 1.0 / args.tile_studs
        nt.links.new(tc.outputs["Object"], sc.inputs[0])
        coords = sc.outputs[0]
        packed = next((k for k in ("ARM", "ORM") if k in images), None)
        if mode == "nor":        # the scan's tangent-space colour, box-projected and emitted as data (see docstring)
            em = nt.nodes.new("ShaderNodeEmission")
            if normal_kind:
                col = tex(nt, normal_kind, coords).outputs["Color"]
                if flip:
                    sep = nt.nodes.new("ShaderNodeSeparateColor")
                    inv = nt.nodes.new("ShaderNodeMath")
                    inv.operation = "SUBTRACT"
                    inv.inputs[0].default_value = 1.0
                    comb = nt.nodes.new("ShaderNodeCombineColor")
                    nt.links.new(col, sep.inputs[0])
                    nt.links.new(sep.outputs[1], inv.inputs[1])
                    nt.links.new(sep.outputs[0], comb.inputs[0])
                    nt.links.new(inv.outputs[0], comb.inputs[1])
                    nt.links.new(sep.outputs[2], comb.inputs[2])
                    col = comb.outputs[0]
                nt.links.new(col, em.inputs["Color"])
            else:
                em.inputs["Color"].default_value = (0.5, 0.5, 1.0, 1.0)
            nt.links.new(em.outputs[0], out.inputs["Surface"])
        else:
            em = nt.nodes.new("ShaderNodeEmission")
            if mode == "alb":
                src = tex(nt, "ALB", coords).outputs["Color"]
            else:
                comb = nt.nodes.new("ShaderNodeCombineXYZ")
                for i, (k, ch) in enumerate((("MET", 2), ("RGH", 1))):
                    key = k if k in images else packed
                    if key is None:
                        continue
                    t = tex(nt, key, coords)
                    sep = nt.nodes.new("ShaderNodeSeparateColor")
                    nt.links.new(t.outputs["Color"], sep.inputs[0])
                    nt.links.new(sep.outputs[ch if key == packed else 0], comb.inputs[i])
                src = comb.outputs[0]
            nt.links.new(src, em.inputs["Color"])
            nt.links.new(em.outputs[0], out.inputs["Surface"])
        return mat

    acc, covered = {}, None
    for mode in ("alb", "mr", "nor"):
        img = bake.new_image("_scan_%s" % mode, size)
        if mode == "alb":
            img.colorspace_settings.name = "Non-Color"
        pm = bake.PassMaterials()

        def make(_m, mode=mode, img=img):
            m = material(mode)
            t = m.node_tree.nodes.new("ShaderNodeTexImage")
            t.image = img
            m.node_tree.nodes.active = t
            return m
        try:
            pm.swap(obj, make)
            bake.select([obj], obj)
            bpy.context.scene.render.bake.use_selected_to_active = False
            bpy.ops.object.bake(type="EMIT", margin=0, use_clear=False)
        finally:
            pm.restore()
        px = bake.read_image(img)
        bpy.data.images.remove(img)
        acc[mode] = px[..., :3]
        if covered is None:
            covered = bake.baked_texels(px, pbrmaps.uv_coverage(bake.uv_triangles(obj), size, grow=0.0))
    import texgen
    idx = pbrmaps.dilate_index(covered, texgen.margin_px(size))
    alb = pbrmaps.linear_to_srgb(pbrmaps.pad(acc["alb"], idx, (0.5, 0.5, 0.5)))   # emission is scene linear
    mr = pbrmaps.pad(acc["mr"], idx, (0.0, 0.6, 0.0))
    nor = pbrmaps.pad(acc["nor"], idx, (0.5, 0.5, 1.0))
    met, rgh = mr[..., 0], mr[..., 1]
    if args.max_saturation:
        alb, share = pbrmaps.limit_saturation(alb, args.max_saturation)
        notes.append("saturation capped at %.2f on %.1f%% of pixels" % (args.max_saturation, 100 * share))
    if not args.no_fix_range:
        alb = pbrmaps.clamp_albedo(alb, met)
    maps = {("ALB", False): alb, ("NOR", False): nor, ("RGH", False): rgh, ("MET", False): met}
    if args.wet:
        maps[("ALB", True)], maps[("RGH", True)] = pbrmaps.wet(alb, rgh)
    written = []
    for (kind, wet), arr in maps.items():
        stem = names.texture_stem(args.name, args.set, kind, wet)
        for directory, s in ((master_dir, size), (export_dir, export)):
            written.append(pbrmaps.write_png(os.path.join(directory, stem + ".png"), pbrmaps.downsize(arr, s)))
    return found, written, notes


if __name__ == "__main__":
    sys.exit(main())
