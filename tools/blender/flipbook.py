"""Flipbook sheets: a Blender smoke / fluid / particle sim rendered to a 4x4 or 8x8 grid (docs/12 1.1, docs/06 2.4).

Runs inside Blender. Frames are sampled evenly over the range (first and last included), each rendered with a
transparent film (straight alpha) into a cell of --size (default common.SHIP_SIZE, at most EXPORT_CAP) / grid pixels, and the cells are laid out left to
right, top to bottom (Roblox ParticleEmitter FlipbookLayout Grid4x4 / Grid8x8 order). Output:
<out>/FX_<Group>_<Name>.png (RGBA, --size square) + FX_<Group>_<Name>.json (frames, alpha stats).

  ~/RobloxProjects/tools/blender-run.sh tools/blender/flipbook.py -- --demo smoke --out build/b01-flipbook
  ~/RobloxProjects/tools/blender-run.sh tools/blender/flipbook.py -- --demo spray --grid 8 --out build/b01-flipbook
  ~/RobloxProjects/tools/blender-run.sh tools/blender/flipbook.py -- --blend art/source/fx/X/X.blend \
        --name FX_Spray_BowSheet --grid 8 [--frames 1 64] [--size 1024] [--engine eevee|cycles] [--samples 16]
A supplied .blend uses its own scene camera, lights and frame range; fluid domains are baked first (cache in a temp
folder) unless their cache already covers the range. Demos (built in, each well under 3 minutes):
  smoke  Mantaflow smoke puff, domain resolution 64, 48 frames, EEVEE volumes  -> FX_Smoke_Puff
  spray  particle spray: 600 droplets instanced as small spheres, gravity, 32 frames (64 for --grid 8)  -> FX_Spray_Burst
"""
import argparse
import json
import math
import os
import sys
import tempfile
import time

import bpy
import numpy as np

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
if LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)
import common  # noqa: E402
import names  # noqa: E402
from rope import write_png  # noqa: E402  (zlib PNG writer, no Pillow in Blender)


def sample_frames(start, end, count):
    """`count` frames spread evenly over [start, end], first and last included."""
    return [int(round(x)) for x in np.linspace(start, end, count)]


def _engine(name):
    items = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys()
    if name == "cycles":
        return "CYCLES"
    for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        if e in items:
            return e
    return items[0]


def _clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def _camera(scene, target, ortho, z=1.0, dist=8.0):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = (target[0], target[1] - dist, z)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam


def _lights(scene, energy=4.0):
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = energy
    sun.rotation_euler = (math.radians(40), math.radians(-30), math.radians(20))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.55, 0.6, 0.68, 1)
    bg.inputs["Strength"].default_value = 0.6
    scene.world = world


def demo_smoke(scene, cache_dir):
    """Mantaflow puff: a short inflow burst from a small sphere, buoyant, dissolving."""
    scene.frame_start, scene.frame_end = 1, 48
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0, 0, 1.4))
    dom = bpy.context.active_object
    dom.name = "SmokeDomain"
    dom.scale = (1.0, 1.0, 1.4)
    mod = dom.modifiers.new("Fluid", "FLUID")
    mod.fluid_type = "DOMAIN"
    ds = mod.domain_settings
    ds.domain_type = "GAS"
    ds.resolution_max = 64
    ds.cache_type = "ALL"
    ds.cache_directory = cache_dir
    ds.cache_frame_start, ds.cache_frame_end = 1, 48
    ds.alpha = 1.2
    ds.beta = 0.4
    ds.vorticity = 0.25
    ds.use_dissolve_smoke = True
    ds.dissolve_speed = 40
    mat = bpy.data.materials.new("FX_Smoke")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.78, 0.79, 0.8, 1)
    vol.inputs["Density"].default_value = 6.0
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    dom.data.materials.append(mat)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(0, 0, 0.35), segments=16, ring_count=8)
    src = bpy.context.active_object
    src.name = "SmokeSource"
    fm = src.modifiers.new("Fluid", "FLUID")
    fm.fluid_type = "FLOW"
    fs = fm.flow_settings
    fs.flow_type = "SMOKE"
    fs.flow_behavior = "INFLOW"
    fs.flow_source = "MESH"
    fs.surface_distance = 0.3
    fs.use_initial_velocity = True
    fs.velocity_coord = (0.0, 0.0, 2.5)
    fs.use_inflow = True
    fs.keyframe_insert("use_inflow", frame=1)
    fs.use_inflow = False
    fs.keyframe_insert("use_inflow", frame=9)
    src.hide_render = True
    _camera(scene, (0, 0), ortho=3.3, z=1.4)
    _lights(scene)
    with bpy.context.temp_override(scene=scene, active_object=dom, object=dom, selected_objects=[dom]):
        t0 = time.time()
        res = bpy.ops.fluid.bake_all()
        print("FLIPBOOK fluid bake", res, "%.1fs" % (time.time() - t0), flush=True)
    return "FX_Smoke_Puff", (1, 48)


def demo_spray(scene, grid=4):
    """Particle spray: droplets fired up and out from a small disc, falling under gravity. The sim is slowed
    (time_tweak) so an 8x8 sheet gets 64 distinct frames."""
    k = max(1, grid * grid // 32)
    scene.frame_start, scene.frame_end = 1, 1 + 32 * k
    bpy.ops.mesh.primitive_circle_add(radius=0.15, fill_type="NGON", location=(0, 0, 0))
    em = bpy.context.active_object
    em.name = "SprayEmitter"
    em.modifiers.new("Particles", "PARTICLE_SYSTEM")
    ps = em.particle_systems[0].settings
    ps.count = 600
    ps.frame_start, ps.frame_end = 1, 1 + 7 * k
    ps.lifetime = 40 * k
    ps.time_tweak = 1.0 / k
    ps.normal_factor = 6.0
    ps.factor_random = 2.2
    ps.mass = 0.02
    ps.render_type = "OBJECT"
    ps.particle_size = 0.035
    ps.size_random = 0.7
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.0, subdivisions=2, location=(0, 0, -50))
    drop = bpy.context.active_object
    drop.name = "Drop"
    mat = bpy.data.materials.new("FX_Spray")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.9, 0.95, 1.0, 1)
    bsdf.inputs["Roughness"].default_value = 0.15
    bsdf.inputs["Emission Color"].default_value = (0.8, 0.88, 0.95, 1)
    bsdf.inputs["Emission Strength"].default_value = 0.6
    drop.data.materials.append(mat)
    ps.instance_object = drop
    drop.hide_render = True
    em.show_instancer_for_render = False
    _camera(scene, (0, 0), ortho=4.2, z=1.6)
    _lights(scene)
    return "FX_Spray_Burst", (2, 1 + 32 * k)


def _bake_domains(scene, cache_root):
    for ob in scene.objects:
        mod = next((m for m in ob.modifiers if m.type == "FLUID" and m.fluid_type == "DOMAIN"), None)
        if mod is None:
            continue
        ds = mod.domain_settings
        if ds.cache_type == "ALL" and ds.cache_directory and os.path.isdir(bpy.path.abspath(ds.cache_directory)) \
                and os.listdir(bpy.path.abspath(ds.cache_directory)):
            continue
        ds.cache_type = "ALL"
        ds.cache_directory = os.path.join(cache_root, ob.name)
        with bpy.context.temp_override(scene=scene, active_object=ob, object=ob, selected_objects=[ob]):
            print("FLIPBOOK bake", ob.name, bpy.ops.fluid.bake_all(), flush=True)


def render_sheet(scene, name, frames, grid=4, size=common.SHIP_SIZE, engine="eevee", samples=16, tmp=None):
    """Render `frames` (len == grid * grid) into one RGBA sheet; returns (uint8 sheet, cell stats)."""
    assert len(frames) == grid * grid
    cell = size // grid
    r = scene.render
    r.engine = _engine(engine)
    r.film_transparent = True
    r.resolution_x = r.resolution_y = cell
    r.resolution_percentage = 100
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    if r.engine == "CYCLES":
        scene.cycles.samples = samples
        scene.cycles.device = "CPU"
    else:
        try:
            scene.eevee.taa_render_samples = samples
        except AttributeError:
            pass
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    tmp = tmp or tempfile.mkdtemp(prefix="flipbook_")
    sheet = np.zeros((size, size, 4), np.uint8)
    stats = []
    for i, f in enumerate(frames):
        scene.frame_set(f)
        path = os.path.join(tmp, "cell_%03d.png" % i)
        r.filepath = path
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(path)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(cell, cell, 4)[::-1]   # Blender rows are bottom-up
        bpy.data.images.remove(img)
        cell8 = np.round(np.clip(px, 0, 1) * 255).astype(np.uint8)
        row, col = divmod(i, grid)
        sheet[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell] = cell8
        a = cell8[..., 3]
        stats.append({"frame": f, "alpha_cover": round(float((a > 2).mean()), 4), "alpha_max": int(a.max()),
                      "edge_alpha_max": int(max(a[0].max(), a[-1].max(), a[:, 0].max(), a[:, -1].max()))})
        print("FLIPBOOK cell %2d frame %3d cover %.3f max %3d edge %3d" % (
            i, f, stats[-1]["alpha_cover"], stats[-1]["alpha_max"], stats[-1]["edge_alpha_max"]), flush=True)
    return sheet, stats


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="render a sim to a flipbook sheet")
    ap.add_argument("--demo", choices=("smoke", "spray"))
    ap.add_argument("--blend", help="a .blend whose scene holds the sim, camera and lights")
    ap.add_argument("--name", help="FX_<Group>_<Name> (default from the demo)")
    ap.add_argument("--grid", type=int, choices=(4, 8), default=4)
    ap.add_argument("--size", type=int, default=common.SHIP_SIZE)
    ap.add_argument("--frames", type=int, nargs=2, metavar=("START", "END"))
    ap.add_argument("--engine", choices=("eevee", "cycles"), default="eevee")
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--out", default=os.path.join(common.REPO_DIR, "build", "flipbook"))
    a = ap.parse_args(argv)
    if not common.is_pow2(a.size) or a.size > common.EXPORT_CAP:
        ap.error("--size must be a power of two <= EXPORT_CAP %d" % common.EXPORT_CAP)
    os.makedirs(a.out, exist_ok=True)
    work = tempfile.mkdtemp(prefix="flipbook_")
    t0 = time.time()
    if a.blend:
        bpy.ops.wm.open_mainfile(filepath=os.path.abspath(a.blend))
        scene = bpy.context.scene
        _bake_domains(scene, os.path.join(work, "cache"))
        name, rng = a.name, (scene.frame_start, scene.frame_end)
    elif a.demo:
        scene = _clear()
        name, rng = (demo_smoke(scene, os.path.join(work, "cache")) if a.demo == "smoke" else demo_spray(scene, a.grid))
        name = a.name or name
    else:
        ap.error("give --demo or --blend")
    prob = names.fx_name_problem(name or "")
    if prob:
        ap.error("--name %r: %s" % (name, prob))
    rng = tuple(a.frames) if a.frames else rng
    frames = sample_frames(rng[0], rng[1], a.grid * a.grid)
    sheet, stats = render_sheet(scene, name, frames, a.grid, a.size, a.engine, a.samples, work)
    path = os.path.join(a.out, name + ".png")
    write_png(path, sheet)
    alpha = sheet[..., 3]
    info = {"name": name, "sheet": os.path.basename(path), "size": list(sheet.shape[:2]), "grid": a.grid,
            "cell": a.size // a.grid, "frames": frames, "engine": scene.render.engine,
            "alpha_cover": round(float((alpha > 2).mean()), 4), "alpha_max": int(alpha.max()),
            "empty_cells": sum(1 for s in stats if s["alpha_max"] <= 2), "cells": stats,
            "seconds": round(time.time() - t0, 1)}
    if a.demo:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(a.out, name + "_demo.blend"))
    with open(os.path.join(a.out, name + ".json"), "w") as f:
        json.dump(info, f, indent=1)
    print("FLIPBOOK %s %dx%d grid %d frames %s alpha cover %.3f max %d empty cells %d (%.0fs)" % (
        path, sheet.shape[1], sheet.shape[0], a.grid, frames, info["alpha_cover"], info["alpha_max"],
        info["empty_cells"], info["seconds"]), flush=True)


if __name__ == "__main__":
    main()
