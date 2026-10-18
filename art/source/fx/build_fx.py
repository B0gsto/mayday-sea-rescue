"""FX1 / FX2 (docs/12 2.11): photoreal ParticleEmitter flipbooks and foam maps, each from a real Blender
simulation (Mantaflow smoke / fire, Newtonian particle droplets with motion blur) rendered with Cycles.

One asset per Blender process (fresh scene each time):
  ~/RobloxProjects/tools/blender-run.sh art/source/fx/build_fx.py -- --asset FX_Spray_BowSheet [--out assets/textures/FX]
  ... -- --list                     print the asset names
Output: <out>/<asset>.png (RGBA, straight alpha, 1024 or less, Roblox Grid order: left to right, top to bottom)
and <out>/<asset>.json (grid, frames, alpha stats). Lit assets are rendered on a transparent film under a soft
overcast rig so the sprite reads as albedo with gentle form (ParticleEmitter LightInfluence 1 relights it);
emissive assets (flare head, sparks, parachute glow) are rendered on black and their alpha is taken from
brightness (for LightEmission 1 additive sprites).
"""
import argparse
import json
import math
import os
import random
import sys
import tempfile
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
from flipbook import sample_frames  # noqa: E402
from rope import write_png  # noqa: E402
sys.path.insert(0, HERE)
import fxpack  # noqa: E402

ASSETS = {}


def asset(name, grid, size=1024, kind="lit"):
    def deco(fn):
        ASSETS[name] = dict(fn=fn, grid=grid, size=size, kind=kind)
        return fn
    return deco


# ---------------------------------------------------------------- scene helpers

def reset(fps=48):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = fps
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 6
    sc.cycles.volume_bounces = 1
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    return sc


def overcast(sc, world=0.55, sun=2.2, tint=(0.80, 0.84, 0.88), sun_dir=(50, 0, 25)):
    w = bpy.data.worlds.new("Overcast")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*tint, 1)
    bg.inputs["Strength"].default_value = world
    sc.world = w
    if sun > 0:
        s = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        s.data.energy = sun
        s.data.angle = math.radians(25)  # soft, high-overcast sun
        s.rotation_euler = tuple(math.radians(v) for v in sun_dir)
        sc.collection.objects.link(s)


def black_world(sc):
    w = bpy.data.worlds.new("Black")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    sc.world = w


def camera(sc, target, ortho, elev=0.0, dist=10.0, yaw=0.0):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.data.clip_end = 100
    e, y = math.radians(elev), math.radians(yaw)
    cam.location = (target[0] + dist * math.cos(e) * math.sin(y), target[1] - dist * math.cos(e) * math.cos(y),
                    target[2] + dist * math.sin(e))
    cam.rotation_euler = (math.radians(90) - e, 0, y)
    sc.camera = cam
    return cam


def principled(name, color, rough=0.3, trans=0.0, ior=1.33, emit=None, strength=0.0, alpha=1.0, sss=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Transmission Weight"].default_value = trans
    b.inputs["IOR"].default_value = ior
    b.inputs["Alpha"].default_value = alpha
    if sss:
        b.inputs["Subsurface Weight"].default_value = sss
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


def emission(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*color, 1)
    e.inputs["Strength"].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs["Surface"])
    return m


def drop_object(mat, name="Drop", subdiv=2):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.0, subdivisions=subdiv, location=(0, 0, -80))
    d = bpy.context.active_object
    d.name = name
    bpy.ops.object.shade_smooth()
    d.data.materials.append(mat)
    d.hide_render = True
    return d


def particles(emitter, count, start, end, life, size, inst, normal=0.0, align=(0, 0, 0), rand=0.0, size_rand=0.6,
              gravity=1.0, life_rand=0.4, emit_from="FACE", seed=1, drag=0.0):
    emitter.modifiers.new("P", "PARTICLE_SYSTEM")
    psys = emitter.particle_systems[-1]
    psys.seed = seed
    ps = psys.settings
    ps.count = count
    ps.frame_start, ps.frame_end = start, end
    ps.lifetime = life
    ps.lifetime_random = life_rand
    ps.emit_from = emit_from
    ps.use_emit_random = True
    ps.normal_factor = normal
    ps.object_align_factor = align
    ps.factor_random = rand
    ps.effector_weights.gravity = gravity
    ps.drag_factor = drag
    ps.render_type = "OBJECT"
    ps.instance_object = inst
    ps.particle_size = size
    ps.size_random = size_rand
    ps.use_rotations = True
    ps.rotation_factor_random = 1.0
    emitter.show_instancer_for_render = False
    return psys


def smoke_material(name, color, density, flame=None, flame_strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    v = nt.nodes.new("ShaderNodeVolumePrincipled")
    v.inputs["Color"].default_value = (*color, 1)
    v.inputs["Density"].default_value = density
    v.inputs["Anisotropy"].default_value = 0.35  # water mist / smoke forward-scatters
    v.inputs["Absorption Color"].default_value = (*color, 1)  # tint, never black: no brown-grey murk
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(v.outputs[0], o.inputs["Volume"])
    if flame:
        at = nt.nodes.new("ShaderNodeAttribute")
        at.attribute_name = "flame"
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        cr = ramp.color_ramp
        cr.elements[0].position, cr.elements[0].color = 0.0, (flame[0][0], flame[0][1], flame[0][2], 1)
        cr.elements[1].position, cr.elements[1].color = 1.0, (flame[2][0], flame[2][1], flame[2][2], 1)
        mid = cr.elements.new(0.45)
        mid.color = (flame[1][0], flame[1][1], flame[1][2], 1)
        nt.links.new(at.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], v.inputs["Emission Color"])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = flame_strength
        nt.links.new(at.outputs["Fac"], mul.inputs[0])
        nt.links.new(mul.outputs[0], v.inputs["Emission Strength"])
    return m


def domain(loc, scale, res, frames, cache, mat, dissolve=None, vort=0.2, alpha=1.0, beta=0.4, fire=False):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=loc)
    d = bpy.context.active_object
    d.name = "Domain"
    d.scale = scale
    mod = d.modifiers.new("Fluid", "FLUID")
    mod.fluid_type = "DOMAIN"
    ds = mod.domain_settings
    ds.domain_type = "GAS"
    ds.resolution_max = res
    ds.cache_type = "ALL"
    ds.cache_directory = cache
    ds.cache_frame_start, ds.cache_frame_end = frames
    ds.alpha, ds.beta = alpha, beta
    ds.vorticity = vort
    ds.use_adaptive_domain = False
    if dissolve:
        ds.use_dissolve_smoke = True
        ds.dissolve_speed = dissolve
        ds.use_dissolve_smoke_log = True
    if fire:
        ds.burning_rate = 0.55
        ds.flame_smoke = 0.0
        ds.flame_vorticity = 0.9
        ds.flame_ignition = 1.25
        ds.flame_max_temp = 3.0
    d.data.materials.append(mat)
    return d


def flow(obj, kind="SMOKE", src="MESH", psys=None, density=1.0, temp=1.0, vel=None, keys=None, fuel=1.0,
         normal_vel=0.0, surface=0.15, color=(1, 1, 1)):
    mod = obj.modifiers.new("Fluid", "FLUID")
    mod.fluid_type = "FLOW"
    fs = mod.flow_settings
    fs.flow_type = kind
    fs.flow_behavior = "INFLOW"
    fs.flow_source = src
    if psys is not None:
        fs.particle_system = psys
        fs.particle_size = 0.12
        fs.use_particle_size = True
    fs.surface_distance = surface
    fs.density = density
    fs.temperature = temp
    fs.smoke_color = color
    fs.subframes = 2
    if kind in ("FIRE", "BOTH"):
        fs.fuel_amount = fuel
    if vel is not None or normal_vel:
        fs.use_initial_velocity = True
        fs.velocity_factor = 1.0
        fs.velocity_normal = normal_vel
        if vel is not None:
            fs.velocity_coord = vel
    if keys:
        for f, on in keys:
            fs.use_inflow = on
            fs.keyframe_insert("use_inflow", frame=f)
    obj.hide_render = True
    return obj


def bake(sc):
    with bpy.context.temp_override(scene=sc):
        try:
            bpy.ops.ptcache.bake_all(bake=True)
        except RuntimeError as e:
            print("FX ptcache", e, flush=True)
    for ob in sc.objects:
        m = next((m for m in ob.modifiers if m.type == "FLUID" and m.fluid_type == "DOMAIN"), None)
        if m:
            t0 = time.time()
            with bpy.context.temp_override(scene=sc, active_object=ob, object=ob, selected_objects=[ob]):
                r = bpy.ops.fluid.bake_all()
            print("FX fluid bake", ob.name, r, "%.0fs" % (time.time() - t0), flush=True)


def motion_blur(sc, shutter=0.5):
    sc.render.use_motion_blur = True
    sc.render.motion_blur_shutter = shutter


# ---------------------------------------------------------------- FX1: spray

def _spray_drops(sc, emitter, count, start, end, life, size, normal, align, rand, gravity=1.0, seed=1, drag=0.0):
    mat = principled("FX_Water_Drop", (0.86, 0.90, 0.92), rough=0.18, trans=0.35, sss=0.2)
    d = drop_object(mat)
    return particles(emitter, count, start, end, life, size, d, normal, align, rand, gravity=gravity, seed=seed,
                     drag=drag)


@asset("FX_Spray_BowSheet", 8)
def bow_sheet(sc, cache):
    """Bow sheet: water peeled off the stem as a curved fan that breaks into droplets and a trailing mist."""
    sc.frame_start, sc.frame_end = 1, 80
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(-0.9, 0, 0.0))
    em = bpy.context.active_object
    em.scale = (0.7, 0.08, 1)
    em.rotation_euler = (math.radians(-70), 0, math.radians(8))  # facing up and forward: a sheet, not a fountain
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    ps = _spray_drops(sc, em, 5200, 1, 10, 70, 0.024, normal=4.2, align=(2.4, 0, 1.2), rand=0.55, drag=0.25)
    flow(em, src="PARTICLES", psys=ps, density=0.9, temp=0.2)
    domain((0.3, 0, 1.3), (1.9, 1.0, 1.5), 80, (1, 80), cache,
           smoke_material("FX_Mist", (0.92, 0.94, 0.95), 10.0), dissolve=26, vort=0.35, alpha=0.05, beta=0.0)
    camera(sc, (-0.5, 0, 0.5), 2.3, elev=8)
    overcast(sc)
    motion_blur(sc, 0.25)
    return (6, 80), 24


@asset("FX_Spray_SlamBurst", 8)
def slam_burst(sc, cache):
    """Slam burst: a hull dropping off a wave throws a white crown of water up and out, which collapses to mist."""
    sc.frame_start, sc.frame_end = 1, 84
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.1, vertices=24, location=(0, 0, 0), end_fill_type="NOTHING")
    em = bpy.context.active_object
    ps = _spray_drops(sc, em, 6000, 1, 6, 76, 0.024, normal=3.2, align=(0, 0, 6.2), rand=1.6, drag=0.2, seed=3)
    flow(em, src="PARTICLES", psys=ps, density=0.6, temp=0.25)
    domain((0, 0, 1.55), (2.0, 2.0, 1.7), 80, (1, 84), cache,
           smoke_material("FX_Mist", (0.92, 0.94, 0.95), 7.0), dissolve=30, vort=0.4, alpha=0.04, beta=0.05)
    camera(sc, (0, 0, 1.45), 5.8, elev=6)
    overcast(sc)
    motion_blur(sc, 0.18)
    return (3, 84), 24


@asset("FX_Spray_Mist", 8)
def spray_mist(sc, cache):
    """Mist: the fine suspended spray left behind a slam or a breaking crest, billowing and thinning out."""
    sc.frame_start, sc.frame_end = 1, 90
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.35, location=(0, 0, 0.5), segments=16, ring_count=8)
    src = bpy.context.active_object
    flow(src, density=0.8, temp=0.4, vel=(0.4, 0, 1.6), normal_vel=1.2, keys=[(1, True), (12, False)], surface=0.25)
    domain((0, 0, 1.4), (1.6, 1.6, 1.6), 80, (1, 90), cache,
           smoke_material("FX_Mist", (0.93, 0.95, 0.96), 6.0), dissolve=45, vort=0.6, alpha=0.08, beta=0.15)
    camera(sc, (0, 0, 0.95), 2.9, elev=4)
    overcast(sc)
    return (4, 90), 24


@asset("FX_Spray_Spindrift", 8)
def spindrift(sc, cache):
    """Spindrift: gale wind tearing spray off a crest in long low streamers (Beaufort 8+)."""
    sc.frame_start, sc.frame_end = 1, 80
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(-1.5, 0, 0.1))
    em = bpy.context.active_object
    em.scale = (0.5, 0.35, 1)
    bpy.ops.object.transform_apply(scale=True)
    ps = _spray_drops(sc, em, 3400, 1, 18, 62, 0.014, normal=0.8, align=(5.8, 0, 1.2), rand=0.7, gravity=0.35, seed=5,
                      drag=0.05)
    flow(em, src="PARTICLES", psys=ps, density=0.9, temp=0.0)
    bpy.ops.object.effector_add(type="WIND", location=(-2.2, 0, 0.3), rotation=(0, math.radians(90), 0))
    wind = bpy.context.active_object
    wind.field.strength = 6.0
    wind.field.flow = 1.0
    wind.field.noise = 1.5
    domain((0.3, 0, 0.75), (2.1, 0.8, 0.85), 96, (1, 80), cache,
           smoke_material("FX_Mist", (0.93, 0.95, 0.96), 8.0), dissolve=24, vort=0.5, alpha=0.0, beta=0.0)
    camera(sc, (0.3, 0, 0.55), 5.0, elev=10)
    overcast(sc)
    motion_blur(sc, 0.6)
    return (8, 80), 24


# ---------------------------------------------------------------- FX1: foam (single maps)

def _foam_plane(sc, size, recipe):
    """An ortho top view of a flat plane whose emission = foam albedo and alpha = foam cover (no lighting baked in).
    `recipe(nt, coord)` returns (cover socket 0..1)."""
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    p = bpy.context.active_object
    m = bpy.data.materials.new("FX_Foam")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord")
    cover = recipe(nt, tc.outputs["Object"])
    # albedo: off-white foam, bubble walls slightly darker grey-green where thin (real foam is never pure white)
    shade = nt.nodes.new("ShaderNodeValToRGB")
    shade.color_ramp.elements[0].color = (0.70, 0.76, 0.76, 1)
    shade.color_ramp.elements[1].color = (0.93, 0.94, 0.93, 1)
    shade.color_ramp.elements[0].position = 0.0
    shade.color_ramp.elements[1].position = 0.6
    nt.links.new(cover, shade.inputs["Fac"])
    strong = _n(nt, "ShaderNodeMath", _operation="POWER", _use_clamp=True)
    nt.links.new(cover, strong.inputs[0])
    strong.inputs[1].default_value = 0.7
    cover = strong.outputs[0]
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(shade.outputs["Color"], em.inputs["Color"])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(cover, mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mix.outputs[0], o.inputs["Surface"])
    p.data.materials.append(m)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size
    cam.location = (0, 0, 5)
    sc.camera = cam
    black_world(sc)
    sc.cycles.samples = 32
    sc.view_settings.view_transform = "Standard"


def _n(nt, kind, **inputs):
    node = nt.nodes.new(kind)
    for k, v in inputs.items():
        if k.startswith("_"):
            setattr(node, k[1:], v)
        else:
            node.inputs[k].default_value = v
    return node


def _lace(nt, coord, scale=26.0, stretch=(1, 1, 1), warp=0.35, seed=0.0):
    """Foam lace: Voronoi cell walls (bubble rafts) broken up by fBm noise, the look of real wake foam."""
    mp = _n(nt, "ShaderNodeMapping", Scale=stretch, Location=(seed, seed * 0.7, 0))
    nt.links.new(coord, mp.inputs["Vector"])
    noise = _n(nt, "ShaderNodeTexNoise", Scale=3.0, Detail=8.0, Roughness=0.62)
    nt.links.new(mp.outputs[0], noise.inputs["Vector"])
    mixv = _n(nt, "ShaderNodeMix", _data_type="VECTOR")
    mixv.inputs["Factor"].default_value = warp
    nt.links.new(mp.outputs[0], mixv.inputs[4])
    nt.links.new(noise.outputs["Color"], mixv.inputs[5])
    vor = _n(nt, "ShaderNodeTexVoronoi", _feature="DISTANCE_TO_EDGE", Scale=scale, Randomness=1.0)
    nt.links.new(mixv.outputs[1], vor.inputs["Vector"])
    walls = _n(nt, "ShaderNodeMapRange", **{"From Min": 0.0, "From Max": 0.09, "To Min": 1.0, "To Max": 0.0})
    nt.links.new(vor.outputs["Distance"], walls.inputs["Value"])
    vor2 = _n(nt, "ShaderNodeTexVoronoi", _feature="DISTANCE_TO_EDGE", Scale=scale * 3.1, Randomness=1.0)
    nt.links.new(mixv.outputs[1], vor2.inputs["Vector"])
    walls2 = _n(nt, "ShaderNodeMapRange", **{"From Min": 0.0, "From Max": 0.12, "To Min": 0.8, "To Max": 0.0})
    nt.links.new(vor2.outputs["Distance"], walls2.inputs["Value"])
    mx = _n(nt, "ShaderNodeMath", _operation="MAXIMUM")
    nt.links.new(walls.outputs[0], mx.inputs[0])
    nt.links.new(walls2.outputs[0], mx.inputs[1])
    dense = _n(nt, "ShaderNodeTexNoise", Scale=5.5, Detail=10.0, Roughness=0.7)
    nt.links.new(mp.outputs[0], dense.inputs["Vector"])
    dr = _n(nt, "ShaderNodeMapRange", **{"From Min": 0.48, "From Max": 0.68})
    nt.links.new(dense.outputs["Fac"], dr.inputs["Value"])
    lace = _n(nt, "ShaderNodeMath", _operation="MAXIMUM")
    nt.links.new(mx.outputs[0], lace.inputs[0])
    nt.links.new(dr.outputs[0], lace.inputs[1])
    return lace.outputs[0], noise.outputs["Fac"]


def _times(nt, a, b):
    m = _n(nt, "ShaderNodeMath", _operation="MULTIPLY", _use_clamp=True)
    nt.links.new(a, m.inputs[0])
    nt.links.new(b, m.inputs[1])
    return m.outputs[0]


def _breakup(nt, mask, noise, lo=0.35, hi=0.6):
    """Ragged edges: the envelope is pushed by noise, then clipped, so the patch boundary frays into lace."""
    add = _n(nt, "ShaderNodeMath", _operation="ADD")
    nt.links.new(mask, add.inputs[0])
    sub = _n(nt, "ShaderNodeMath", _operation="SUBTRACT")
    nt.links.new(noise, sub.inputs[0])
    sub.inputs[1].default_value = 0.5
    nt.links.new(sub.outputs[0], add.inputs[1])
    r = _n(nt, "ShaderNodeMapRange", **{"From Min": lo, "From Max": hi})
    nt.links.new(add.outputs[0], r.inputs["Value"])
    return r.outputs[0]


def _radial(nt, coord, inner, outer, sx=1.0, sy=1.0, ring=False, width=0.25):
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord, sep.inputs[0])
    x = _n(nt, "ShaderNodeMath", _operation="MULTIPLY")
    nt.links.new(sep.outputs[0], x.inputs[0])
    x.inputs[1].default_value = 1.0 / sx
    y = _n(nt, "ShaderNodeMath", _operation="MULTIPLY")
    nt.links.new(sep.outputs[1], y.inputs[0])
    y.inputs[1].default_value = 1.0 / sy
    cx = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(x.outputs[0], cx.inputs[0])
    nt.links.new(y.outputs[0], cx.inputs[1])
    ln = _n(nt, "ShaderNodeVectorMath", _operation="LENGTH")
    nt.links.new(cx.outputs[0], ln.inputs[0])
    if ring:
        d = _n(nt, "ShaderNodeMath", _operation="SUBTRACT")
        nt.links.new(ln.outputs["Value"], d.inputs[0])
        d.inputs[1].default_value = (inner + outer) * 0.5
        a = _n(nt, "ShaderNodeMath", _operation="ABSOLUTE")
        nt.links.new(d.outputs[0], a.inputs[0])
        r = _n(nt, "ShaderNodeMapRange", **{"From Min": width, "From Max": 0.0, "_interpolation_type": "SMOOTHSTEP"})
        nt.links.new(a.outputs[0], r.inputs["Value"])
        return r.outputs[0]
    r = _n(nt, "ShaderNodeMapRange", **{"From Min": outer, "From Max": inner, "_interpolation_type": "SMOOTHSTEP"})
    nt.links.new(ln.outputs["Value"], r.inputs["Value"])
    return r.outputs[0]


def _foam_asset(sc, recipe):
    sc.frame_start = sc.frame_end = 1
    _foam_plane(sc, 2.0, recipe)
    return (1, 1), 32


@asset("FX_Foam_HullRing", 1, kind="flat")
def foam_hull_ring(sc, cache):
    """Hull foam ring: the collar of broken white water and bubble lace around a hull moving slowly (top view)."""
    def r(nt, co):
        lace, noise = _lace(nt, co, scale=30, warp=0.4, seed=1.3)
        env = _radial(nt, co, 0.42, 0.62, ring=True, width=0.42)
        return _times(nt, lace, _breakup(nt, env, noise, 0.3, 0.62))
    return _foam_asset(sc, r)


@asset("FX_Foam_WakeRibbon", 1, kind="flat")
def foam_wake_ribbon(sc, cache):
    """Wake ribbon (Trail texture: U along the wake, V across): churned centre band, lace fraying at both edges."""
    def r(nt, co):
        lace, noise = _lace(nt, co, scale=24, stretch=(0.45, 1.0, 1.0), warp=0.45, seed=2.1)
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(co, sep.inputs[0])
        a = _n(nt, "ShaderNodeMath", _operation="ABSOLUTE")
        nt.links.new(sep.outputs[1], a.inputs[0])
        env = _n(nt, "ShaderNodeMapRange", **{"From Min": 0.9, "From Max": 0.15, "_interpolation_type": "SMOOTHSTEP"})
        nt.links.new(a.outputs[0], env.inputs["Value"])
        ax = _n(nt, "ShaderNodeMath", _operation="ABSOLUTE")
        nt.links.new(sep.outputs[0], ax.inputs[0])
        ends = _n(nt, "ShaderNodeMapRange", **{"From Min": 0.99, "From Max": 0.8, "To Min": 0.0, "To Max": 1.0})
        nt.links.new(ax.outputs[0], ends.inputs["Value"])
        return _times(nt, _times(nt, lace, _breakup(nt, env.outputs[0], noise, 0.28, 0.6)), ends.outputs[0])
    return _foam_asset(sc, r)


@asset("FX_Foam_CrestStreak", 1, kind="flat")
def foam_crest_streak(sc, cache):
    """Crest streak: wind-drawn foam streak left on the back of a breaking crest (streaks align with the wind, X)."""
    def r(nt, co):
        lace, noise = _lace(nt, co, scale=20, stretch=(0.28, 1.4, 1.0), warp=0.5, seed=3.7)
        env = _radial(nt, co, 0.15, 0.95, sx=1.0, sy=0.42)
        return _times(nt, lace, _breakup(nt, env, noise, 0.3, 0.62))
    return _foam_asset(sc, r)


@asset("FX_Foam_Swash", 1, kind="flat")
def foam_swash(sc, cache):
    """Swash edge: the foam line of a spent wave running up the sand (dense at the top edge, lacing out downhill)."""
    def r(nt, co):
        lace, noise = _lace(nt, co, scale=28, stretch=(0.6, 1.0, 1.0), warp=0.45, seed=4.4)
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(co, sep.inputs[0])
        env = _n(nt, "ShaderNodeMapRange", **{"From Min": -0.85, "From Max": 0.4, "_interpolation_type": "SMOOTHSTEP"})
        nt.links.new(sep.outputs[1], env.inputs["Value"])
        top = _n(nt, "ShaderNodeMapRange", **{"From Min": 0.85, "From Max": 0.55, "_interpolation_type": "SMOOTHSTEP"})
        nt.links.new(sep.outputs[1], top.inputs["Value"])
        ax = _n(nt, "ShaderNodeMath", _operation="ABSOLUTE")
        nt.links.new(sep.outputs[0], ax.inputs[0])
        sides = _n(nt, "ShaderNodeMapRange", **{"From Min": 0.97, "From Max": 0.75, "_interpolation_type": "SMOOTHSTEP"})
        nt.links.new(ax.outputs[0], sides.inputs["Value"])
        band = _times(nt, _breakup(nt, env.outputs[0], noise, 0.3, 0.6), _times(nt, top.outputs[0], sides.outputs[0]))
        return _times(nt, lace, band)
    return _foam_asset(sc, r)


# ---------------------------------------------------------------- FX2: rain

@asset("FX_Rain_Streak", 4)
def rain_streak(sc, cache):
    """16 rain streak variants (camera exposure of a 2-4 mm drop at terminal speed), for random-start rain."""
    sc.frame_start, sc.frame_end = 1, 16
    rng = random.Random(7)
    mat = principled("FX_RainDrop", (0.82, 0.86, 0.9), rough=0.05, trans=0.6, ior=1.33)
    for f in range(1, 17):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.017 * rng.uniform(0.75, 1.25), segments=16, ring_count=8)
        d = bpy.context.active_object
        d.data.materials.append(mat)
        x = rng.uniform(-0.08, 0.08)
        drift = rng.uniform(-0.06, 0.06)
        top, bot = rng.uniform(0.32, 0.46), -rng.uniform(0.32, 0.46)
        for fr, vis in ((f - 1, False), (f, True), (f + 1, False)):
            d.hide_render = not vis
            d.keyframe_insert("hide_render", frame=fr)
        rad = d.dimensions[2] * 0.5
        d.scale = (1.0, 1.0, (top - bot) * 0.42 / rad)  # the exposure smear of the drop (shutter ~1/50 s)
        d.rotation_euler = (0, math.atan2(2 * drift, top - bot), 0)
        d.location = (x - drift, 0, top)
        d.keyframe_insert("location", frame=f - 0.5)
        d.location = (x + drift, 0, bot)
        d.keyframe_insert("location", frame=f + 0.5)
        for fc in d.animation_data.action.fcurves if hasattr(d.animation_data.action, "fcurves") else []:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR" if fc.data_path == "location" else "CONSTANT"
    camera(sc, (0, 0, 0), 1.0)
    overcast(sc, world=0.9, sun=1.0)
    motion_blur(sc, 0.5)
    sc.cycles.film_transparent_glass = True
    return (1, 16), 96


def _ring(name, mat, r0, minor):
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=minor, major_segments=96, minor_segments=12)
    t = bpy.context.active_object
    t.name = name
    bpy.ops.object.shade_smooth()
    t.data.materials.append(mat)
    return t


def _key_ring(t, mat_node, frames, radii, alphas, flat=0.35):
    for f, r, a in zip(frames, radii, alphas):
        t.scale = (r, r, r * flat)
        t.keyframe_insert("scale", frame=f)
        mat_node.inputs["Alpha"].default_value = a
        mat_node.inputs["Alpha"].keyframe_insert("default_value", frame=f)


@asset("FX_Rain_SplashRing", 4)
def rain_splash(sc, cache):
    """Raindrop impact on water seen from a low angle: crown of droplets, then the spreading ring (16 frames)."""
    sc.frame_start, sc.frame_end = 1, 26
    mat = principled("FX_Ring", (0.93, 0.95, 0.96), rough=0.08, trans=0.1)
    t = _ring("Ring", mat, 0.05, 0.06)
    _key_ring(t, mat.node_tree.nodes["Principled BSDF"], (1, 8, 26), (0.05, 0.15, 0.3), (0.95, 0.8, 0.2))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.01, vertices=32, end_fill_type="NOTHING")
    em = bpy.context.active_object
    dm = principled("FX_Water_Drop", (0.86, 0.9, 0.92), rough=0.1, trans=0.4)
    particles(em, 220, 1, 3, 22, 0.011, drop_object(dm), normal=0.6, align=(0, 0, 1.15), rand=0.25, size_rand=0.7)
    bpy.ops.mesh.primitive_plane_add(size=0.01, location=(0, 0, 0))
    jet = bpy.context.active_object
    particles(jet, 6, 7, 9, 14, 0.012, drop_object(dm, "JetDrop"), align=(0, 0, 1.25), rand=0.05, size_rand=0.3,
              seed=4)
    camera(sc, (0, 0, 0.1), 1.0, elev=16)
    overcast(sc, world=0.8, sun=1.6)
    motion_blur(sc, 0.4)
    sc.cycles.film_transparent_glass = False
    return (1, 26), 48


@asset("FX_Rain_OnWater", 4)
def rain_on_water(sc, cache):
    """Raindrop ripple on the sea seen from above (flat particle): a bright leading ring and a fainter second ring."""
    sc.frame_start, sc.frame_end = 1, 32
    mat = principled("FX_Ring", (0.94, 0.96, 0.96), rough=0.05, trans=0.0)
    t = _ring("Ring", mat, 0.05, 0.04)
    _key_ring(t, mat.node_tree.nodes["Principled BSDF"], (1, 10, 32), (0.06, 0.4, 0.85), (1.0, 0.8, 0.12), flat=0.2)
    mat2 = principled("FX_Ring2", (0.9, 0.93, 0.94), rough=0.05)
    t2 = _ring("Ring2", mat2, 0.05, 0.03)
    _key_ring(t2, mat2.node_tree.nodes["Principled BSDF"], (1, 6, 16, 32), (0.0, 0.03, 0.26, 0.62),
              (0.0, 0.6, 0.45, 0.0), flat=0.2)
    camera(sc, (0, 0, 0), 2.0, elev=90)
    overcast(sc, world=0.9, sun=1.2, sun_dir=(30, 0, 40))
    return (4, 32), 32


# ---------------------------------------------------------------- FX2: smoke and flares

def _puff(sc, cache, color, density, name, frames=96, rise=2.2, res=80, dissolve=55):
    sc.frame_start, sc.frame_end = 1, frames
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(0, 0, 0.35), segments=16, ring_count=8)
    src = bpy.context.active_object
    flow(src, density=1.0, temp=2.0, vel=(0.25, 0, rise), normal_vel=0.6, keys=[(1, True), (18, False)], surface=0.3)
    domain((0, 0, 1.55), (1.45, 1.45, 1.6), res, (1, frames), cache, smoke_material(name, color, density),
           dissolve=dissolve, vort=0.45, alpha=0.2, beta=1.2)
    camera(sc, (0, 0, 1.15), 2.6, elev=3)
    overcast(sc)
    return (6, frames), 24


@asset("FX_Smoke_Orange", 8)
def smoke_orange(sc, cache):
    """Orange buoyant smoke signal: dense, saturated, rolling billows (pyrotechnic orange 2.2 dye smoke)."""
    return _puff(sc, cache, (1.0, 0.40, 0.04), 26.0, "FX_SmokeOrange")


@asset("FX_Flare_Smoke", 8)
def flare_smoke(sc, cache):
    """Red hand flare smoke: thick off-white smoke with a faint warm cast, from the magnesium / strontium burn."""
    return _puff(sc, cache, (0.95, 0.90, 0.89), 20.0, "FX_FlareSmoke", rise=2.6)


@asset("FX_Flare_Head", 4, kind="emissive")
def flare_head(sc, cache):
    """Red hand flare head: a strontium flame flickering off a 2 cm burning pellet (sustained burn, loopable)."""
    sc.frame_start, sc.frame_end = 1, 72
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(0, 0, 0.2), segments=16, ring_count=8)
    src = bpy.context.active_object
    flow(src, kind="FIRE", fuel=1.6, temp=2.0, vel=(0, 0, 0.6), normal_vel=0.5, surface=0.12)
    fm = smoke_material("FX_Flame", (0.0, 0.0, 0.0), 0.0,
                        flame=((0.35, 0.0, 0.02), (1.0, 0.08, 0.10), (1.0, 0.82, 0.86)), flame_strength=24.0)
    domain((0, 0, 0.65), (0.42, 0.42, 0.62), 72, (1, 72), cache, fm, vort=0.6, alpha=0.0, beta=1.4, fire=True)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(0, 0, 0.2))
    core = bpy.context.active_object
    core.data.materials.append(emission("FX_FlareCore", (1.0, 0.86, 0.9), 30.0))
    camera(sc, (0, 0, 0.6), 1.25, elev=5)
    black_world(sc)
    return (40, 71), 64


@asset("FX_Flare_Sparks", 4, kind="emissive")
def flare_sparks(sc, cache):
    """Hand flare sparks: burning slag thrown off the head, arcing down as motion-blurred streaks."""
    sc.frame_start, sc.frame_end = 1, 40
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(0, 0, 0.6), segments=12, ring_count=6)
    em = bpy.context.active_object
    sm = emission("FX_Spark", (1.0, 0.45, 0.42), 14.0)
    particles(em, 60, 1, 4, 24, 0.015, drop_object(sm, "Spark", 1), normal=0.85, align=(0, 0, 0.9), rand=0.7,
              size_rand=0.6, life_rand=0.3, emit_from="FACE", gravity=0.45)
    camera(sc, (0, 0, -0.3), 3.3, elev=4)
    black_world(sc)
    motion_blur(sc, 0.9)
    return (2, 26), 48


@asset("FX_Flare_Parachute", 4, kind="emissive")
def flare_parachute(sc, cache):
    """Parachute rocket flare glow: a 30 000 cd red star seen in sea haze: hot core, scattered red halo, flicker."""
    sc.frame_start, sc.frame_end = 1, 16
    rng = random.Random(11)
    core_m = emission("FX_ParaCore", (1.0, 0.55, 0.55), 60.0)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, location=(0, 0, 0))
    core = bpy.context.active_object
    core.data.materials.append(core_m)
    pt = bpy.data.objects.new("Glow", bpy.data.lights.new("Glow", "POINT"))
    pt.data.color = (1.0, 0.16, 0.12)
    pt.data.shadow_soft_size = 0.03
    sc.collection.objects.link(pt)
    em_node = core_m.node_tree.nodes["Emission"]
    for f in range(1, 17):
        k = rng.uniform(0.7, 1.15)
        em_node.inputs["Strength"].default_value = 60.0 * k
        em_node.inputs["Strength"].keyframe_insert("default_value", frame=f)
        pt.data.energy = 220.0 * k
        pt.data.keyframe_insert("energy", frame=f)
        core.scale = (0.85 + 0.3 * k,) * 3
        core.keyframe_insert("scale", frame=f)
    # haze: a sphere of scattering air (density falls off with distance so the halo is soft and round)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.95, location=(0, 0, 0), segments=32, ring_count=16)
    haze = bpy.context.active_object
    m = bpy.data.materials.new("FX_Haze")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    v = nt.nodes.new("ShaderNodeVolumePrincipled")
    v.inputs["Color"].default_value = (1, 0.92, 0.92, 1)
    v.inputs["Anisotropy"].default_value = 0.55
    tc = nt.nodes.new("ShaderNodeTexCoord")
    ln = _n(nt, "ShaderNodeVectorMath", _operation="LENGTH")
    nt.links.new(tc.outputs["Object"], ln.inputs[0])
    rr = _n(nt, "ShaderNodeMapRange", **{"From Min": 0.95, "From Max": 0.0, "To Min": 0.0, "To Max": 2.2,
                                        "_interpolation_type": "SMOOTHSTEP"})
    nt.links.new(ln.outputs["Value"], rr.inputs["Value"])
    for f in range(1, 17):  # the halo breathes with the burn
        rr.inputs["To Max"].default_value = rng.uniform(1.6, 2.8)
        rr.inputs["To Max"].keyframe_insert("default_value", frame=f)
    noise = _n(nt, "ShaderNodeTexNoise", Scale=2.5, Detail=4.0, _noise_dimensions="4D")
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    noise.inputs["W"].default_value = 0.0
    noise.inputs["W"].keyframe_insert("default_value", frame=1)
    noise.inputs["W"].default_value = 3.0
    noise.inputs["W"].keyframe_insert("default_value", frame=16)
    mul = _n(nt, "ShaderNodeMath", _operation="MULTIPLY")
    nt.links.new(rr.outputs[0], mul.inputs[0])
    nt.links.new(noise.outputs["Fac"], mul.inputs[1])
    nt.links.new(mul.outputs[0], v.inputs["Density"])
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(v.outputs[0], o.inputs["Volume"])
    haze.data.materials.append(m)
    camera(sc, (0, 0, 0), 2.0)
    black_world(sc)
    sc.cycles.volume_bounces = 2
    return (1, 16), 96


# ---------------------------------------------------------------- FX2: underwater

@asset("FX_Under_MarineSnow", 4)
def marine_snow(sc, cache):
    """16 marine snow aggregates (detritus flocs, 0.5-5 mm): loose translucent clumps, one per cell (random start)."""
    sc.frame_start, sc.frame_end = 1, 16
    rng = random.Random(21)
    mat = principled("FX_Floc", (0.68, 0.67, 0.62), rough=0.8, sss=0.6, trans=0.15, alpha=0.5)
    fib = principled("FX_Fibre", (0.72, 0.71, 0.66), rough=0.8, alpha=0.6)
    for f in range(1, 17):
        bpy.ops.object.empty_add(location=(0, 0, 0))
        root = bpy.context.active_object
        for _ in range(rng.randint(3, 9)):
            bpy.ops.mesh.primitive_ico_sphere_add(radius=rng.uniform(0.02, 0.07), subdivisions=3,
                                                  location=(rng.gauss(0, 0.06), rng.gauss(0, 0.03), rng.gauss(0, 0.06)))
            b = bpy.context.active_object
            b.scale = (rng.uniform(0.6, 1.4), rng.uniform(0.6, 1.4), rng.uniform(0.5, 1.2))
            tex = bpy.data.textures.new("n", "CLOUDS")
            tex.noise_scale = rng.uniform(0.05, 0.12)
            dm = b.modifiers.new("D", "DISPLACE")
            dm.texture = tex
            dm.strength = rng.uniform(0.05, 0.12)
            b.data.materials.append(mat)
            b.parent = root
        for _ in range(rng.randint(2, 5)):  # mucus strands / fibres trailing off the aggregate
            bpy.ops.mesh.primitive_cylinder_add(radius=0.003, depth=rng.uniform(0.08, 0.22), vertices=6,
                                                location=(rng.gauss(0, 0.06), 0, rng.gauss(0, 0.06)),
                                                rotation=(rng.uniform(0, 3.14), rng.uniform(0, 3.14), 0))
            fb = bpy.context.active_object
            fb.data.materials.append(fib)
            fb.parent = root
        for fr, vis in ((f - 1, False), (f, True), (f + 1, False)):
            for c in root.children:
                c.hide_render = not vis
                c.keyframe_insert("hide_render", frame=fr)
    camera(sc, (0, 0, 0), 0.75)
    overcast(sc, world=0.7, sun=2.4, tint=(0.78, 0.86, 0.86), sun_dir=(10, 0, 0))
    return (1, 16), 48


@asset("FX_Under_Bubbles", 4)
def bubbles(sc, cache):
    """A rising air bubble in seawater (air-in-water IOR 0.75: bright total-internal-reflection rim), wobbling."""
    sc.frame_start, sc.frame_end = 1, 16
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.3, segments=64, ring_count=32)
    b = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    tex = bpy.data.textures.new("wob", "CLOUDS")
    tex.noise_scale = 0.6
    bpy.ops.object.empty_add(location=(0, 0, 0))
    ctl = bpy.context.active_object
    dm = b.modifiers.new("Wobble", "DISPLACE")
    dm.texture = tex
    dm.texture_coords = "OBJECT"
    dm.texture_coords_object = ctl
    dm.strength = 0.06
    dm.mid_level = 0.5
    for f in range(1, 17):
        a = 2 * math.pi * (f - 1) / 16
        ctl.location = (0.35 * math.cos(a), 0.35 * math.sin(a), 0.2 * math.sin(2 * a))
        ctl.keyframe_insert("location", frame=f)
        b.scale = (1.0 + 0.06 * math.cos(2 * a), 1.0 + 0.06 * math.cos(2 * a), 0.9 - 0.06 * math.cos(2 * a))
        b.keyframe_insert("scale", frame=f)
    m = bpy.data.materials.new("FX_Bubble")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    # a bubble is seen by its surface only: clear interior, a thin bright rim where the air-water
    # interface reflects at grazing angles (total internal reflection), and specular glints
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    gl = nt.nodes.new("ShaderNodeBsdfGlossy")
    gl.inputs["Roughness"].default_value = 0.02
    gl.inputs["Color"].default_value = (1, 1, 1, 1)
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.12
    pw = _n(nt, "ShaderNodeMath", _operation="POWER", _use_clamp=True)
    nt.links.new(lw.outputs["Facing"], pw.inputs[0])
    pw.inputs[1].default_value = 3.0
    rim = _n(nt, "ShaderNodeMath", _operation="ADD", _use_clamp=True)
    nt.links.new(pw.outputs[0], rim.inputs[0])
    rim.inputs[1].default_value = 0.04
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(rim.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(gl.outputs[0], mix.inputs[2])
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mix.outputs[0], o.inputs["Surface"])
    b.data.materials.append(m)
    bpy.ops.object.light_add(type="AREA", location=(0.6, -1.5, 3.0))
    lt = bpy.context.active_object
    lt.data.energy = 600
    lt.data.size = 1.5
    lt.rotation_euler = (math.radians(30), 0, math.radians(15))
    camera(sc, (0, 0, 0), 1.0)
    overcast(sc, world=0.9, sun=0, tint=(0.80, 0.86, 0.87))
    return (1, 16), 64


# ---------------------------------------------------------------- render + pack

def render_sheet(sc, frames, grid, size, samples, kind, tmp):
    """Render the cells. Blender writes straight-alpha sRGB 8-bit PNGs; a byte image's .pixels are those values
    (16-bit PNGs load as premultiplied scene-linear floats, which read dark here: keep 8-bit)."""
    cell = size // grid
    r = sc.render
    r.film_transparent = kind != "emissive"
    r.resolution_x = r.resolution_y = cell
    r.resolution_percentage = 100
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    sc.cycles.samples = samples
    cells = []
    for i, f in enumerate(frames):
        sc.frame_set(f)
        path = os.path.join(tmp, "cell_%03d.png" % i)
        r.filepath = path
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(path)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(cell, cell, 4)[::-1]
        bpy.data.images.remove(img)
        cells.append(px)
        print("FX cell %2d frame %3d alpha max %.3f" % (i, f, px[..., 3].max()), flush=True)
    return fxpack.pack(cells, grid, kind)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--out", default=os.path.join(REPO, "assets", "textures", "FX"))
    ap.add_argument("--samples", type=int)
    a = ap.parse_args(argv)
    if a.list:
        print("FXLIST", " ".join(ASSETS))
        return
    spec = ASSETS[a.asset]
    t0 = time.time()
    sc = reset()
    tmp = tempfile.mkdtemp(prefix="fx_")
    rng, samples = spec["fn"](sc, os.path.join(tmp, "cache"))
    bake(sc)
    grid = spec["grid"]
    frames = sample_frames(rng[0], rng[1], grid * grid)
    sheet = render_sheet(sc, frames, grid, spec["size"], a.samples or samples, spec["kind"], tmp)
    os.makedirs(a.out, exist_ok=True)
    path = os.path.join(a.out, a.asset + ".png")
    write_png(path, sheet)
    info = {"name": a.asset, "size": spec["size"], "grid": grid, "layout": "Grid%dx%d" % (grid, grid) if grid > 1 else
            "None", "kind": spec["kind"], "frames": frames, **fxpack.stats(sheet, grid), "seconds": round(time.time() - t0, 1)}
    with open(os.path.join(a.out, a.asset + ".json"), "w") as f:
        json.dump(info, f, indent=1)
    print("FXDONE %s cover %.3f empty %d edgeMax %d (%.0fs)" % (a.asset, info["alpha_cover"], info["empty_cells"],
                                                                max(edge), info["seconds"]), flush=True)


if __name__ == "__main__":
    main()
