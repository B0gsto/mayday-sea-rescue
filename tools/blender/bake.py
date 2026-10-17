"""The `bake` step (docs/12-asset-list.md section 1.1): Cycles bake of _HP onto _LOD0, one texture set per run.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset <Asset> --steps build,lod,bake,validate,export
    MAYDAY_BAKE_SET=Hull MAYDAY_BAKE_SIZE=1024 ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset <Asset> ...

run.py calls run(spec, report) after lod and before validate. Per texture set (spec["sets"]; the LOD0 meshes whose
entry has "set" equal to the set name, or every LOD0 when the asset has one set) it bakes:

  NOR    tangent-space normal from the _HP (OpenGL: +X red, +Y green up, +Z blue); flat when there is no _HP
  masks  AO (only the source object), curvature (signed: pointiness for convex / concave, Bevel-normal difference for
         strength; 0.5 flat, 1 convex edge, 0 cavity), thickness (inside AO: 1 thick, 0 thin), world position and
         world normal (for rust streaks), base colour, metalness and roughness per material slot of the source
  ALB / RGH / MET   pbrmaps.compose: base values plus edge wear (curvature), salt crust (AO + cavity) and rust streaks
         running down from edges; no random grunge. _Wet ALB / RGH when set["wet"] (value -25%, roughness -0.3; tune)

Source: <mesh base>_HP (spec meshes with role hp, or an object of that name). Without one, AO / curvature / colours are
baked from the LOD0 itself and NOR is flat (128, 128, 255).

Outputs: masters at the bake size (MASTER 4096; spec["bake_size"] or env MAYDAY_BAKE_SIZE for fast iteration) in
art/source/<kind>/<Asset>/textures/ (spec["master_dir"] overrides; with run.py --out-root they go to
<out-root>/masters/<Asset>/), masks in its masks/ subfolder; exported maps box-downsized to min(set size (default SHIP_SIZE), EXPORT_CAP)
in common.textures_dir(asset) (or set["dir"]) as T_<Name>_<Set>_<ALB|NOR|RGH|MET>[_Wet].png (8-bit, RGH / MET greyscale).

Spec fields read here (spec level): bake_size, only_set (or env MAYDAY_BAKE_SET; default: every set, but one set a run
is the rule for big assets so a run stays under the 10-minute heavy-slot cap), bake_samples (AO / bevel samples,
default 16), master_dir, bake_device ("auto" GPU when present, "CPU").
Set fields: name, set, size, wet, dir (as validate), plus
  base_color   sRGB "#RRGGBB" or (r, g, b) 0..1, for every slot (else each slot's Principled Base Color)
  metal        0..1 for every slot (else Principled Metallic);  roughness  0..1 (else Principled Roughness)
  slots        {"<material name>": {"base_color", "metal", "roughness"}} per-slot overrides on the source mesh
  wear         False (off) or a dict of pbrmaps.WEAR_DEFAULTS fields: edge, edge_range, edge_color, edge_rough,
               edge_metal, salt, salt_range, salt_color, salt_rough, rust, rust_color, rust_rough, rust_length,
               rust_fingers, ao_strength, metal_snap. Thin bare-metal edge wear (edge_metal 1) needs a bright
               edge_color (metal albedo floor 180) and can still trip check_textures' 512 px metal sample
  ao_distance  AO ray length in studs (default 4% of the bbox diagonal, at least 0.05)
  bevel_radius curvature bevel radius in studs (default 2.5% of the bbox diagonal)
  cage_extrusion, max_ray_distance   selected-to-active ray settings (default 2% / 4% of the bbox diagonal)
  wet_darken (0.25), wet_gloss (0.3), wet_streaks (0: off; 0..1 running-water streaks on the _Wet maps)
"""
import os
import time

import numpy as np

import common
import names
import pbrmaps
import texgen

try:
    import bpy
    import mathutils
except ImportError:          # pure helpers stay importable for the tests
    bpy = mathutils = None

ENV_SIZE = "MAYDAY_BAKE_SIZE"
ENV_SET = "MAYDAY_BAKE_SET"


# ---------------------------------------------------------------- pure helpers

def bake_size(spec, env=None):
    env = os.environ if env is None else env
    size = int(env.get(ENV_SIZE) or spec.get("bake_size") or common.MASTER)
    if not common.is_pow2(size) or size > common.MASTER:
        raise ValueError("bake size %d must be a power of two at most %d" % (size, common.MASTER))
    return size


def export_size(set_spec, size):
    return min(int(set_spec.get("size", common.SHIP_SIZE)), common.EXPORT_CAP, size)


def sets_to_bake(spec, env=None):
    env = os.environ if env is None else env
    only = env.get(ENV_SET) or spec.get("only_set")
    sets = spec.get("sets", [])
    if only:
        sets = [s for s in sets if s["set"] == only]
        if not sets:
            raise ValueError("only_set '%s' is not one of the spec's sets %s" % (only, [s["set"] for s in spec.get("sets", [])]))
    return sets


def slot_values(set_spec, mat_name, principled):
    """(base sRGB tuple, metal, roughness) for one material slot: slot override > set field > the material's Principled
    values (principled: (linear rgb, metal, rough) or None)."""
    over = (set_spec.get("slots") or {}).get(mat_name, {})
    if principled is None:
        principled = ((0.18, 0.18, 0.18), 0.0, 0.6)
    lin, metal, rough = principled
    base = over.get("base_color", set_spec.get("base_color"))
    base = pbrmaps.parse_color(base) if base is not None else tuple(float(v) for v in pbrmaps.linear_to_srgb(np.array(lin[:3])))
    return base, float(over.get("metal", set_spec.get("metal", metal))), float(over.get("roughness", set_spec.get("roughness", rough)))


def stem_paths(directory, name, set_name, wet_too):
    out = {}
    for kind in common.MAP_KINDS:
        for wet in ((False, True) if wet_too and kind in ("ALB", "RGH") else (False,)):
            out[(kind, wet)] = os.path.join(directory, names.texture_stem(name, set_name, kind, wet) + ".png")
    return out


def finish_maps(baked, covered, size, set_spec):
    """Pure part of a set bake: pad, compose, wet. baked: {'nor', 'mask', 'pos', 'wn', 'base', 'mr'} float arrays
    (H, W, 3), image order. Returns {(kind, wet): array} at bake size plus the masks."""
    idx = pbrmaps.dilate_index(covered, texgen.margin_px(size))
    fills = {"nor": (0.5, 0.5, 1.0), "mask": (1.0, 0.5, 1.0), "pos": (0.5, 0.5, 0.5), "wn": (0.5, 0.5, 1.0),
             "base": (0.5, 0.5, 0.5), "mr": (0.0, 0.6, 0.0)}
    p = {k: pbrmaps.pad(v, idx, fills[k]) for k, v in baked.items()}
    grown = idx >= 0
    nor = p["nor"]
    n = nor * 2.0 - 1.0                                  # renormalise after padding / filtering
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
    nor = n * 0.5 + 0.5
    ao, curv, thick = p["mask"][..., 0], p["mask"][..., 1], p["mask"][..., 2]
    out = pbrmaps.compose(p["base"], p["mr"][..., 0], p["mr"][..., 1], ao, curv, p["pos"], p["wn"] * 2.0 - 1.0, grown,
                          set_spec.get("wear"))
    maps = {("ALB", False): out["alb"], ("NOR", False): nor, ("RGH", False): out["rgh"], ("MET", False): out["met"]}
    if set_spec.get("wet"):
        wa, wr = pbrmaps.wet(out["alb"], out["rgh"], set_spec.get("wet_darken", 0.25), set_spec.get("wet_gloss", 0.3))
        ws = float(set_spec.get("wet_streaks", 0.0))   # opt-in: running-water streaks (darker, glossier) on the _Wet maps
        if ws > 0:
            sp = pbrmaps.wear_params({"rust_length": 0.6, "rust_fingers": 7})
            src = np.maximum(pbrmaps.edge_mask(curv, sp), 0.35)
            st = pbrmaps.rust_streaks(p["pos"], p["wn"] * 2.0 - 1.0, src, grown, sp) * ws
            wa = wa * (1.0 - 0.3 * st[..., None])
            wr = np.clip(wr - 0.12 * st, 0.04, 1.0)
            yl = pbrmaps.luma(np.clip(wa, 0.0, 1.0)) * 255.0   # keep the non-metal albedo floor (check_textures 30)
            wa = np.clip(wa * np.where(yl < 31.0, 31.0 / np.maximum(yl, 1e-3), 1.0)[..., None], 0.0, 1.0)
        maps[("ALB", True)], maps[("RGH", True)] = wa, wr
    masks = {"AO": ao, "Curv": curv, "Thick": thick, "Edge": out["edge"], "Salt": out["salt"], "Rust": out["rust"]}
    return maps, masks


def write_maps(maps, masks, master_dir, export_dir, name, set_name, size, cap):
    written = []
    for directory, target in ((master_dir, size), (export_dir, cap)):
        for (kind, wet), path in stem_paths(directory, name, set_name, any(w for _, w in maps)).items():
            pbrmaps.write_png(path, pbrmaps.downsize(maps[(kind, wet)], target))
            written.append(os.path.relpath(path, common.REPO_DIR))
    for label, arr in masks.items():
        pbrmaps.write_png(os.path.join(master_dir, "masks", "%s_%s_%s.png" % (name, set_name, label)), arr)
    return written


# ---------------------------------------------------------------- Blender side

def master_dir_for(spec):
    if spec.get("master_dir"):
        return os.path.abspath(spec["master_dir"])
    asset = spec.get("asset", spec["name"])
    if common.out_root() != common.ASSETS_DIR:
        return os.path.join(common.out_root(), "masters", asset)
    try:
        return os.path.join(common.find_asset_dir(asset), "textures")
    except SystemExit:
        return os.path.join(common.out_root(), "masters", asset)


def setup_cycles(spec, samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.device = "CPU"
    device = "CPU"
    if spec.get("bake_device", "auto") != "CPU":
        try:
            prefs = bpy.context.preferences.addons["cycles"].preferences
            for kind in ("METAL", "OPTIX", "CUDA", "HIP", "ONEAPI"):
                try:
                    prefs.compute_device_type = kind
                except TypeError:
                    continue
                prefs.get_devices()
                devs = [d for d in prefs.devices if d.type == kind]
                if devs:
                    for d in prefs.devices:
                        d.use = d.type == kind
                    scene.cycles.device = "GPU"
                    device = "GPU (%s: %s)" % (kind, ", ".join(d.name for d in devs))
                    break
        except Exception as e:      # no GPU: CPU bake
            device = "CPU (%s)" % e
    b = scene.render.bake
    b.margin = 0
    b.use_clear = False
    b.target = "IMAGE_TEXTURES"
    return device


def principled_of(mat):
    if mat is None or not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            return (tuple(n.inputs["Base Color"].default_value[:3]), n.inputs["Metallic"].default_value,
                    n.inputs["Roughness"].default_value)
    return None


def new_image(name, size):
    img = bpy.data.images.new(name, size, size, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    fill = np.full((size * size, 4), -1.0, dtype=np.float32)
    fill[:, 3] = 0.0
    img.pixels.foreach_set(fill.ravel())       # sentinel: RGB -1, alpha 0 = not baked
    return img


def read_image(img):
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    return np.flipud(buf.reshape(h, w, 4))          # Blender rows run bottom-up


class PassMaterials:
    """Temporary materials swapped onto the source and target meshes for one bake pass, restored afterwards.
    Slots are assigned by index (materials.clear() would reset every polygon's material_index to 0)."""

    def __init__(self):
        self.saved = []          # (mesh, original material list, temps)

    def swap(self, obj, make):
        mesh = obj.data
        originals = list(mesh.materials)
        temps = [make(m) for m in (originals or [None])]
        if originals:
            for i, t in enumerate(temps):
                mesh.materials[i] = t
        else:
            mesh.materials.append(temps[0])
        self.saved.append((mesh, originals, temps))

    def restore(self):
        for mesh, originals, temps in reversed(self.saved):
            if originals:
                for i, m in enumerate(originals):
                    mesh.materials[i] = m
            else:
                mesh.materials.pop(index=0)
            for t in temps:
                if t.users == 0:
                    bpy.data.materials.remove(t)
        self.saved = []


def _node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def emission_tree(nt, mode, values, ctx):
    """Builds the emission network for one pass in node tree nt; returns the output socket to emit."""
    link = nt.links.new
    if mode == "base":
        rgb = _node(nt, "ShaderNodeRGB")
        rgb.outputs[0].default_value = tuple(values[0]) + (1.0,)
        return rgb.outputs[0]
    if mode == "mr":
        c = _node(nt, "ShaderNodeCombineXYZ", X=values[1], Y=values[2], Z=0.0)
        return c.outputs[0]
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    if mode == "wn":
        m = _node(nt, "ShaderNodeVectorMath")
        m.operation = "MULTIPLY_ADD"
        m.inputs[1].default_value = (0.5, 0.5, 0.5)
        m.inputs[2].default_value = (0.5, 0.5, 0.5)
        link(geo.outputs["Normal"], m.inputs[0])
        return m.outputs[0]
    if mode == "pos":
        m = _node(nt, "ShaderNodeVectorMath")
        m.operation = "MULTIPLY_ADD"
        lo, span = ctx["lo"], ctx["span"]
        m.inputs[1].default_value = tuple(1.0 / s for s in span)
        m.inputs[2].default_value = tuple(-l / s for l, s in zip(lo, span))
        link(geo.outputs["Position"], m.inputs[0])
        return m.outputs[0]
    # mode == "mask": (AO, curvature, thickness)
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.only_local, ao.samples = True, ctx["samples"]
    ao.inputs["Distance"].default_value = ctx["ao_distance"]
    th = nt.nodes.new("ShaderNodeAmbientOcclusion")
    th.only_local, th.inside, th.samples = True, True, ctx["samples"]
    th.inputs["Distance"].default_value = ctx["ao_distance"]
    bev = nt.nodes.new("ShaderNodeBevel")
    bev.samples = min(16, ctx["samples"])
    bev.inputs["Radius"].default_value = ctx["bevel_radius"]
    dist = _node(nt, "ShaderNodeVectorMath")
    dist.operation = "DISTANCE"
    link(bev.outputs["Normal"], dist.inputs[0])
    link(geo.outputs["Normal"], dist.inputs[1])
    strength = _node(nt, "ShaderNodeMath")
    strength.operation, strength.use_clamp = "MULTIPLY", True
    strength.inputs[1].default_value = 3.0                     # |n_bevel - n| of 0.33 counts as a full edge
    link(dist.outputs["Value"], strength.inputs[0])
    sign = _node(nt, "ShaderNodeMapRange")                       # pointiness 0.5 +- 0.02 -> -1..1
    sign.inputs["From Min"].default_value, sign.inputs["From Max"].default_value = 0.48, 0.52
    sign.inputs["To Min"].default_value, sign.inputs["To Max"].default_value = -1.0, 1.0
    link(geo.outputs["Pointiness"], sign.inputs["Value"])
    signed = _node(nt, "ShaderNodeMath")
    signed.operation = "MULTIPLY"
    link(strength.outputs[0], signed.inputs[0])
    link(sign.outputs["Result"], signed.inputs[1])
    curv = _node(nt, "ShaderNodeMath")
    curv.operation = "MULTIPLY_ADD"
    curv.inputs[1].default_value, curv.inputs[2].default_value = 0.5, 0.5
    link(signed.outputs[0], curv.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    link(ao.outputs["AO"], comb.inputs["X"])
    link(curv.outputs[0], comb.inputs["Y"])
    link(th.outputs["AO"], comb.inputs["Z"])
    return comb.outputs[0]


def make_material(label, emit_mode, values, ctx, image=None):
    mat = bpy.data.materials.new("_bake_%s" % label)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if emit_mode:
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(emission_tree(nt, emit_mode, values, ctx), em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    else:
        bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
        nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.nodes.active = tex
        tex.select = True
    return mat


def custom_material(m, mode):
    """Opt-in procedural slot (material custom property "bake_custom"): a copy of the source material whose node named
    BAKE_BASE (colour output, sRGB values like the constant base pass) or BAKE_MR (vector: X metal, Y roughness) is
    emitted instead of the constant slot value. None when the material has no such node (constant path)."""
    if m is None or not m.get("bake_custom") or not m.use_nodes:
        return None
    key = "BAKE_BASE" if mode == "base" else "BAKE_MR"
    if m.node_tree.nodes.get(key) is None:
        return None
    c = m.copy()
    c.name = "_bake_custom_%s" % mode
    nt = c.node_tree
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None) or nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(nt.nodes[key].outputs[0], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return c


def select(objs, active):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.hide_render = False
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def bake_pass(mode, target, source, image, set_spec, ctx):
    """One bake pass into `image` (target's UVs). mode: nor, mask, pos, wn, base, mr."""
    pm = PassMaterials()
    same = source is target
    values_for = lambda m: slot_values(set_spec, m.name if m else "", principled_of(m))
    try:
        if mode == "nor":
            pm.swap(target, lambda m: make_material("target", None, None, ctx, image))
        elif same:
            pm.swap(target, lambda m: make_material(mode, mode, values_for(m), ctx, image))
        else:
            pm.swap(source, lambda m: (custom_material(m, mode) if mode in ("base", "mr") else None)
                    or make_material(mode, mode, values_for(m), ctx))
            pm.swap(target, lambda m: make_material("target", None, None, ctx, image))
        select([target] if same else [source, target], target)
        b = bpy.context.scene.render.bake
        b.use_selected_to_active = not same
        if not same:
            b.cage_extrusion, b.max_ray_distance = ctx["cage_extrusion"], ctx["max_ray_distance"]
        bpy.context.scene.cycles.samples = 1 if mode in ("nor", "pos", "wn", "base", "mr") else ctx["samples"]
        if mode == "nor":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", normal_r="POS_X", normal_g="POS_Y", normal_b="POS_Z",
                                margin=0, use_clear=False, use_selected_to_active=not same)
        else:
            bpy.ops.object.bake(type="EMIT", margin=0, use_clear=False, use_selected_to_active=not same)
    finally:
        pm.restore()


def baked_texels(px, raster):
    """Texels a pass really baked: inside the UV raster (a same-object bake writes every texel) and not the sentinel."""
    return raster & (px[..., 3] > 0.5) & (px[..., 0] > -0.5)


def uv_triangles(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.data
    return np.array([[uv[i].uv[:] for i in t.loops] for t in mesh.loop_triangles], dtype=np.float64)


def find_hp(spec, lod0):
    base = names.mesh_base(lod0.name)
    for e in spec["meshes"]:
        if e.get("role") == "hp" and names.mesh_base(e["object"].name) == base:
            return e["object"]
    return bpy.data.objects.get(base + "_HP")


def bake_set(spec, set_spec, size, report, ctx_base):
    t0 = time.time()
    sets = spec.get("sets", [])
    lod0s = [e["object"] for e in spec["meshes"] if e.get("role") == "visual" and e.get("lod") == "LOD0"
             and (e.get("set") == set_spec["set"] or (len(sets) == 1 and not e.get("set")))]
    subject = "T_%s_%s" % (set_spec["name"], set_spec["set"])
    if not lod0s:
        report.add(subject, "bake", False, "no LOD0 mesh uses set %s" % set_spec["set"])
        return {"set": set_spec["set"], "ok": False}
    acc = {k: np.zeros((size, size, 3), dtype=np.float32) for k in ("nor", "mask", "pos", "wn", "base", "mr")}
    covered = np.zeros((size, size), dtype=bool)
    pairs, timings = [], {}
    for lod0 in lod0s:
        hp = find_hp(spec, lod0)
        objs = [lod0] + ([hp] if hp else [])
        pts = [o.matrix_world @ mathutils.Vector(b) for o in objs for b in o.bound_box]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        span = [max(h - l, 1e-4) for l, h in zip(lo, hi)]
        diag = sum(s * s for s in span) ** 0.5
        ctx = dict(ctx_base, lo=lo, span=span,
                   ao_distance=float(set_spec.get("ao_distance", max(0.05, 0.04 * diag))),
                   bevel_radius=float(set_spec.get("bevel_radius", 0.025 * diag)),
                   cage_extrusion=float(set_spec.get("cage_extrusion", 0.02 * diag)),
                   max_ray_distance=float(set_spec.get("max_ray_distance", 0.04 * diag)))
        pairs.append({"lod0": lod0.name, "hp": hp.name if hp else None})
        source = hp or lod0
        mine = pbrmaps.uv_coverage(uv_triangles(lod0), size, grow=0.0)
        for mode in acc:
            if mode == "nor" and hp is None:
                continue
            img = new_image("_bake_%s" % mode, size)
            t = time.time()
            bake_pass(mode, lod0, source, img, set_spec, ctx)
            timings[mode] = round(timings.get(mode, 0.0) + time.time() - t, 1)
            px = read_image(img)
            bpy.data.images.remove(img)
            hit = baked_texels(px, mine)
            acc[mode][hit] = px[..., :3][hit]
            if mode == "mask":
                covered |= hit
        if hp is None:
            acc["nor"][covered] = (0.5, 0.5, 1.0)
    coverage = float(covered.mean())
    report.add(subject, "bake coverage", coverage > 0.05, "%.1f%% of texels at %d px from %s" % (
        100 * coverage, size, ", ".join("%s<-%s" % (p["lod0"], p["hp"] or "itself (flat NOR)") for p in pairs)))
    t = time.time()
    maps, masks = finish_maps(acc, covered, size, set_spec)
    cap = export_size(set_spec, size)
    master = master_dir_for(spec)
    export_dir = set_spec.get("dir") or common.textures_dir(spec.get("asset", spec["name"]))
    written = write_maps(maps, masks, master, export_dir, set_spec["name"], set_spec["set"], size, cap)
    timings["compose_write"] = round(time.time() - t, 1)
    report.add(subject, "bake", True, "%d maps, master %d, export %d, %.0f s" % (len(written), size, cap, time.time() - t0), info=True)
    print("[bake] %s: %.0f s (%s)" % (subject, time.time() - t0, ", ".join("%s %.1f" % kv for kv in timings.items())))
    return {"set": set_spec["set"], "ok": True, "size": size, "export": cap, "pairs": pairs, "coverage": round(coverage, 4),
            "seconds": round(time.time() - t0, 1), "timings": timings, "written": written, "master_dir": master}


def run(spec, report):
    size = bake_size(spec)
    samples = int(spec.get("bake_samples", 16))
    device = setup_cycles(spec, samples)
    print("[bake] size %d, %d samples, %s" % (size, samples, device))
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    results = [bake_set(spec, s, size, report, {"samples": samples}) for s in sets_to_bake(spec)]
    return {"device": device, "size": size, "samples": samples, "sets": results}
