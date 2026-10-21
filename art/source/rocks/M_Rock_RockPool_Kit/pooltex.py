"""M_Rock_RockPool_Kit texture bake (Blender, one heavy slot): every pass lands on the 4096 atlas, in atlas UV space
(the four variants each own one 2048 x 2048 cell; build.py placed the UVs).

  nor / mask / pos / wn   each variant's _HP onto its _LOD0 (bake.bake_pass), accumulated in one atlas image
  scan_alb / scan_nrm     the K1 CC0 scan pieces (poolgeo.assemble_projector) through their own atlas UVs, so the
                          LOD0 keeps real Cornish granite diffuse and shading-normal detail
  pool                    the _LOD0's PoolData vertex attribute: R = under water inside the pool, G = distance to the
                          pool shoreline in studs (+-2, coded 0..1). compose_maps.py uses it for the pool zonation.

compose_maps.py (system python3) grades these into T_Pool_Granite_* (+ _Wet). Pads are dilated to the bake margin
(64 px at 4096) so the compose never sees an unbaked texel and never crosses into a neighbouring cell.

  ~/RobloxProjects/tools/blender-run.sh art/source/rocks/M_Rock_RockPool_Kit/pooltex.py -- \
      --blend art/source/rocks/M_Rock_RockPool_Kit/M_Rock_RockPool_Kit.blend \
      --out-root build/prod/M_Rock_RockPool_Kit [--size 4096]
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
LIB = os.path.join(REPO, "tools/blender")
for p in (LIB, HERE):
    if p not in sys.path:
        sys.path.insert(0, p)

import bake  # noqa: E402
import bpy  # noqa: E402
import common  # noqa: E402
import pbrmaps  # noqa: E402
import poolgeo as G  # noqa: E402
import texgen  # noqa: E402

NAME = "M_Rock_RockPool_Kit"
SCAN = os.path.join(REPO, "build/k1/src/rock_face_01/textures")
WORK = None


def pool_flag_material(image):
    """Emits the PoolData vertex attribute into `image` (the bake target must be the material's active image node)."""
    mat = bpy.data.materials.new("_bake_pool")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "PoolData"
    nt.links.new(at.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    nt.nodes.active = tex
    tex.select = True
    return mat


def scan_material(images):
    """The scan's maps through the projector's own UVs: diffuse -> base colour + emission (EMIT reads emission),
    nor_gl -> normal map (the NORMAL bake reads the shading normal), arm G -> roughness."""
    mat = bpy.data.materials.new("_scan_uv")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = images["ALB"]
    nt.links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
    nor = nt.nodes.new("ShaderNodeTexImage")
    nor.image = images["NOR"]
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 1.0
    nt.links.new(nor.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    rgh = nt.nodes.new("ShaderNodeTexImage")
    rgh.image = images["ARM"]
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(rgh.outputs["Color"], sep.inputs[0])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(alb.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def repaired(image, covered, radius=14):
    """The scan atlas is half empty space with dark island borders: dilate the used texels so the projection never
    samples a border (that is what paints black outlines along block edges)."""
    px = bake.read_image(image)
    idx = pbrmaps.dilate_index(covered, radius)
    if idx is None:
        return image
    a = pbrmaps.pad(px[..., :3], idx, px[..., :3][covered].mean(0) if covered.any() else (0.5, 0.5, 0.5))
    out = bpy.data.images.new(image.name + "_fix", image.size[0], image.size[1], alpha=True, float_buffer=True)
    out.colorspace_settings.name = image.colorspace_settings.name
    buf = np.concatenate([a, np.ones(a.shape[:2] + (1,), np.float32)], axis=2)
    out.pixels.foreach_set(np.flipud(buf).reshape(-1))
    print("[pooltex] repaired %s: %.1f%% used texels dilated %d px" % (image.name, 100 * covered.mean(), radius))
    return out


def projector(hp, V):
    ob = G.assemble_projector(hp, V)
    bm_n = len(ob.data.polygons)
    images = {}
    for kind, fn in (("ALB", "rock_face_01_diff_2k.jpg"), ("NOR", "rock_face_01_nor_gl_2k.jpg"),
                     ("ARM", "rock_face_01_arm_2k.jpg")):
        images[kind] = bpy.data.images.load(os.path.join(SCAN, fn))
        images[kind].colorspace_settings.name = "sRGB" if kind == "ALB" else "Non-Color"
    used = pbrmaps.uv_coverage(bake.uv_triangles(ob), 2048, grow=0.0)
    for kind, img in list(images.items()):
        images[kind] = repaired(img, used)
    ob.data.materials.clear()
    ob.data.materials.append(scan_material(images))
    print("[pooltex] projector %s: %d tris, %.1f%% of the scan atlas used" % (V["nn"], bm_n, 100 * used.mean()))
    return ob


def bake_from(lod0, source, image, ctx, kind):
    """Selected-to-active bake of the source's shading (EMIT) or normal (NORMAL) onto lod0's UVs."""
    pm = bake.PassMaterials()
    try:
        pm.swap(lod0, lambda m: bake.make_material("target", None, None, ctx, image))
        bake.select([source, lod0], lod0)
        b = bpy.context.scene.render.bake
        b.use_selected_to_active = True
        b.cage_extrusion, b.max_ray_distance = ctx["cage_extrusion"], ctx["max_ray_distance"]
        bpy.context.scene.cycles.samples = 1
        if kind == "NORMAL":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", normal_r="POS_X", normal_g="POS_Y",
                                normal_b="POS_Z", margin=0, use_clear=False, use_selected_to_active=True)
        else:
            bpy.ops.object.bake(type="EMIT", margin=0, use_clear=False, use_selected_to_active=True)
    finally:
        pm.restore()


def bake_same(lod0, image, make):
    """Same-object EMIT bake into `image` with a temporary material from `make`."""
    pm = bake.PassMaterials()
    try:
        pm.swap(lod0, lambda m: make())
        bake.select([lod0], lod0)
        b = bpy.context.scene.render.bake
        b.use_selected_to_active = False
        bpy.context.scene.cycles.samples = 1
        bpy.ops.object.bake(type="EMIT", margin=0, use_clear=False, use_selected_to_active=False)
    finally:
        pm.restore()


def save_pass(name, px, covered, size, srgb=False, fill=(0.5, 0.5, 1.0)):
    idx = pbrmaps.dilate_index(covered, texgen.margin_px(size))
    arr = pbrmaps.pad(px[..., :3], idx, fill)
    if srgb:
        arr = pbrmaps.linear_to_srgb(arr)
    path = os.path.join(WORK, name + ".png")
    pbrmaps.write_png(path, np.clip(arr, 0.0, 1.0))
    print("[pooltex] %-9s %.1f%% baked -> %s" % (name, 100 * covered.mean(), os.path.relpath(path, REPO)))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="pooltex.py")
    ap.add_argument("--blend", default=os.path.join(HERE, NAME + ".blend"))
    ap.add_argument("--out-root", default=None)
    ap.add_argument("--size", type=int, default=0, help="bake size (default: MAYDAY_BAKE_SIZE or 4096)")
    ap.add_argument("--passes", default="", help="limit to these passes (comma separated), e.g. pool")
    args = ap.parse_args(argv)
    global WORK
    out_root = os.path.abspath(args.out_root) if args.out_root else os.path.abspath(os.path.join(REPO, "build/prod", NAME))
    WORK = os.path.join(out_root, "work")
    os.makedirs(WORK, exist_ok=True)
    size = args.size or int(os.environ.get("MAYDAY_BAKE_SIZE") or common.MASTER)
    only = [s for s in args.passes.split(",") if s]

    pools = json.load(open(os.path.join(HERE, "pool.json")))
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(args.blend))
    for o in list(bpy.context.scene.objects):          # the template's lineup and swatches: no stray bake rays
        base = o.name.split(".")[0]
        if not (base.startswith("M_Rock_RockPool") or base.startswith("ATT_Pool")):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()                    # else the stale view layer holds None entries

    variants = []
    mine = np.zeros((size, size), bool)
    for pv in pools["variants"]:
        lod0 = bpy.data.objects[pv["name"] + "_LOD0"]
        hp = bpy.data.objects[pv["name"] + "_HP"]
        V = G.variant(pv["nn"])
        span = pv["span"]
        diag = sum(s * s for s in span) ** 0.5
        ctx = {"samples": 16, "lo": pv["lo"], "span": span, "ao_distance": 0.10 * diag, "bevel_radius": 0.02 * diag,
               "cage_extrusion": 0.045 * diag, "max_ray_distance": 0.09 * diag}
        variants.append((pv, lod0, hp, V, ctx))
        mine |= pbrmaps.uv_coverage(bake.uv_triangles(lod0), size, grow=0.0)
    device = bake.setup_cycles({"bake_device": "auto"}, 16)
    print("[pooltex] %s at %d px, %s, %d variants" % (os.path.basename(args.blend), size, device, len(variants)))

    for mode in ("nor", "mask", "pos", "wn"):
        if only and mode not in only:
            continue
        img = bake.new_image("_%s" % mode, size)
        for pv, lod0, hp, V, ctx in variants:
            bake.bake_pass(mode, lod0, hp, img, {}, ctx)
        px = bake.read_image(img)
        bpy.data.images.remove(img)
        save_pass(mode, px, bake.baked_texels(px, mine), size,
                  fill=(0.5, 0.5, 1.0) if mode == "nor" else (0.5, 0.5, 0.5))

    for name, kind, srgb, fill in (("scan_alb", "EMIT", True, (0.4, 0.38, 0.36)),
                                   ("scan_nrm", "NORMAL", False, (0.5, 0.5, 1.0))):
        if only and name not in only:
            continue
        img = bake.new_image("_%s" % name, size)
        for pv, lod0, hp, V, ctx in variants:
            proj = projector(hp, V)
            bake_from(lod0, proj, img, ctx, kind)
            bpy.data.objects.remove(proj, do_unlink=True)
            bpy.context.view_layer.update()
        px = bake.read_image(img)
        bpy.data.images.remove(img)
        save_pass(name, px, bake.baked_texels(px, mine), size, srgb=srgb, fill=fill)

    if not only or "pool" in only:
        img = bake.new_image("_pool", size)
        for pv, lod0, hp, V, ctx in variants:
            bake_same(lod0, img, lambda: pool_flag_material(img))
        px = bake.read_image(img)
        bpy.data.images.remove(img)
        save_pass("pool", px, bake.baked_texels(px, mine), size, fill=(0.0, 0.5, 0.0))


if __name__ == "__main__":
    main()
