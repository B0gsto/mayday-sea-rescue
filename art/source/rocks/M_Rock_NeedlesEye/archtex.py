"""M_Rock_NeedlesEye texture bake (Blender, one heavy slot): every pass lands on the LOD0s' UVs (arch + fallen blocks),
selected-to-active from the one _HP.

  nor     the _HP's normal: its jointed geometry plus CC0 scan relief (Poly Haven rock_face, its normal map integrated
          to a height; rock_boulder_dry displacement) box-projected in world studs as a bump, two scales, so the
          detail has one texel density everywhere and never stretches
  mask    AO / curvature (bake_pass "mask")
  pos     world position over the bbox: Z is the height above the base (bake_pass "pos")
  wn      world normal: Z is up-facing (bake_pass "wn")
  detail  the same projection as colour: R rock_boulder_dry albedo luma, G rock_face albedo luma, B the relief height

compose_maps.py (system python3) grades these into the Granite set with the tide-line zonation.

  ~/RobloxProjects/tools/blender-run.sh art/source/rocks/M_Rock_NeedlesEye/archtex.py -- \
      --blend art/source/rocks/M_Rock_NeedlesEye/M_Rock_NeedlesEye.blend --out-root build/prod/M_Rock_NeedlesEye
"""
import argparse
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
LIB = os.path.join(REPO, "tools/blender")
if LIB not in sys.path:
    sys.path.insert(0, LIB)

import bpy  # noqa: E402
import bake  # noqa: E402
import common  # noqa: E402
import pbrmaps  # noqa: E402
import texgen  # noqa: E402

NAME = "M_Rock_NeedlesEye"
ROCK_FACE = os.path.join(REPO, "build/materials/src/rock_face")       # https://polyhaven.com/a/rock_face (CC0)
BOULDER = os.path.join(REPO, "build/s1a/src/rock_boulder_dry")         # https://polyhaven.com/a/rock_boulder_dry (CC0)
BUMP = 0.45                                                            # relief depth (studs)


def load(path):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"
    return img


def height_from_normal(img):
    """Frankot-Chellappa: integrate the tileable OpenGL normal map to a periodic height in 0..1 (sign checked
    against the scan's AO: cracks come out low)."""
    n = bake.read_image(img)[..., :3] * 2.0 - 1.0                      # image order, row 0 = top
    h, w = n.shape[:2]
    fy, fx = np.fft.fftfreq(h)[:, None], np.fft.fftfreq(w)[None, :]
    nz = np.maximum(n[..., 2], 0.2)
    P, Q = np.fft.fft2(-n[..., 0] / nz), np.fft.fft2(n[..., 1] / nz)
    Z = (fx * P + fy * Q) / (2j * np.pi * (fx ** 2 + fy ** 2) + 1e-12)
    Z[0, 0] = 0.0
    z = np.real(np.fft.ifft2(Z))
    lo, hi = np.percentile(z, (1.0, 99.0))
    z = np.clip((z - lo) / (hi - lo), 0.0, 1.0).astype(np.float32)
    out = bpy.data.images.new("_rf_height", w, h, alpha=True, float_buffer=True)
    out.colorspace_settings.name = "Non-Color"
    out.pixels.foreach_set(np.flipud(np.dstack([z, z, z, np.ones_like(z)])).ravel())
    return out


def detail_material():
    """World-space box projection of the scans on the _HP: bump into the shading normal (the NORMAL bake reads it)
    and the detail channels as emission (the EMIT bake reads it)."""
    rf_h = height_from_normal(load(os.path.join(ROCK_FACE, "nor_1k.png")))
    rf_d = load(os.path.join(ROCK_FACE, "diff_1k.png"))
    bd_h = load(os.path.join(BOULDER, "Displacement.png"))
    bd_d = load(os.path.join(BOULDER, "Diffuse.png"))
    mat = bpy.data.materials.new("_arch_detail")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord")

    def tex(img, tile, offset=(0.0, 0.0, 0.0)):
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Location"].default_value = offset
        mp.inputs["Scale"].default_value = (1.0 / tile,) * 3
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image, t.projection, t.projection_blend = img, "BOX", 0.35
        nt.links.new(mp.outputs["Vector"], t.inputs["Vector"])
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        nt.links.new(t.outputs["Color"], bw.inputs["Color"])
        return bw.outputs["Val"]

    def mix(a, b, wa, wb):
        m1 = nt.nodes.new("ShaderNodeMath")
        m1.operation = "MULTIPLY_ADD"
        nt.links.new(a, m1.inputs[0])
        m1.inputs[1].default_value = wa
        m2 = nt.nodes.new("ShaderNodeMath")
        m2.operation = "MULTIPLY"
        nt.links.new(b, m2.inputs[0])
        m2.inputs[1].default_value = wb
        nt.links.new(m2.outputs[0], m1.inputs[2])
        return m1.outputs[0]

    height = mix(mix(tex(rf_h, 7.3), tex(rf_h, 19.7, (0.37, 0.11, 0.53)), 0.55, 0.30), tex(bd_h, 13.1, (0.2, 0.6, 0.1)),
                 1.0, 0.25)
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = BUMP
    nt.links.new(height, bump.inputs["Height"])
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    comb = nt.nodes.new("ShaderNodeCombineColor")
    nt.links.new(tex(bd_d, 13.1, (0.2, 0.6, 0.1)), comb.inputs[0])
    nt.links.new(tex(rf_d, 7.3), comb.inputs[1])
    nt.links.new(height, comb.inputs[2])
    nt.links.new(comb.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def bake_detail(tgt, hp, image, ctx):
    pm = bake.PassMaterials()
    try:
        pm.swap(tgt, lambda m: bake.make_material("target", None, None, ctx, image))
        bake.select([hp, tgt], tgt)
        b = bpy.context.scene.render.bake
        b.use_selected_to_active = True
        b.cage_extrusion, b.max_ray_distance = ctx["cage_extrusion"], ctx["max_ray_distance"]
        bpy.context.scene.cycles.samples = 1
        bpy.ops.object.bake(type="EMIT", margin=0, use_clear=False, use_selected_to_active=True)
    finally:
        pm.restore()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="archtex.py")
    ap.add_argument("--blend", default=os.path.join(HERE, NAME + ".blend"))
    ap.add_argument("--out-root", default=os.path.join(REPO, "build/prod", NAME))
    ap.add_argument("--size", type=int, default=0, help="bake size (default: MAYDAY_BAKE_SIZE or 4096)")
    args = ap.parse_args(argv)
    work = os.path.join(os.path.abspath(args.out_root), "work")
    os.makedirs(work, exist_ok=True)
    size = args.size or int(os.environ.get("MAYDAY_BAKE_SIZE") or common.MASTER)

    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(args.blend))
    lod0, rocks, hp = (bpy.data.objects[NAME + s] for s in ("_LOD0", "_Base_LOD0", "_HP"))
    co = np.array([v.co[:] for v in hp.data.vertices], np.float32)
    lo, hi = co.min(0), co.max(0)
    # cage just past the decimation error (LOD0 edges ~1.5 studs): rays never reach the far wall of the eye
    ctx = {"samples": 16, "lo": [float(v) for v in lo], "span": [float(v) for v in np.maximum(hi - lo, 1e-4)],
           "ao_distance": 3.0, "bevel_radius": 0.25, "cage_extrusion": 0.8, "max_ray_distance": 2.0}
    print("[archtex] %s at %d px, %s" % (os.path.basename(args.blend), size, bake.setup_cycles({"bake_device": "auto"}, 16)))
    hp.data.materials.clear()
    hp.data.materials.append(detail_material())

    targets = (lod0, rocks)
    cov = {t.name: pbrmaps.uv_coverage(bake.uv_triangles(t), size, grow=0.0) for t in targets}
    for mode in ("nor", "mask", "pos", "wn", "detail"):
        acc = np.zeros((size, size, 3), np.float32)
        covered = np.zeros((size, size), bool)
        for tgt in targets:
            img = bake.new_image("_" + mode, size)
            if mode == "detail":
                bake_detail(tgt, hp, img, ctx)
            else:
                bake.bake_pass(mode, tgt, hp, img, {}, ctx)
            px = bake.read_image(img)
            bpy.data.images.remove(img)
            got = cov[tgt.name] & (px[..., 3] > 0.5) & ~covered
            acc[got] = px[..., :3][got]
            covered |= got
        fill = (0.5, 0.5, 1.0) if mode == "nor" else (0.5, 0.5, 0.5)
        arr = pbrmaps.pad(acc, pbrmaps.dilate_index(covered, texgen.margin_px(size)), fill)
        pbrmaps.write_png(os.path.join(work, mode + ".png"), np.clip(arr, 0.0, 1.0))
        print("[archtex] %-6s %.1f%% baked" % (mode, 100 * covered.mean()))


if __name__ == "__main__":
    main()
