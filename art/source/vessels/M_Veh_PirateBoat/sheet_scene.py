"""Blender (MCP): the boat with its crew on water, three angles + one phone-size view, PNGs to --out. Not part of the game."""
import importlib.util
import math
import os
import sys

import bpy
import mathutils

G = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
OUT = os.path.join(G, "build/status/2026-11-04/art/pirates_src")
sys.path.insert(0, os.path.join(G, "tools/blender"))   # build.py imports zfight_check


def load_build(path):
    spec = importlib.util.spec_from_file_location("b_" + os.path.basename(os.path.dirname(path)), path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m.build()


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def set_scene():
    clear()
    s = load_build(os.path.join(G, "art/source/vessels/M_Veh_PirateBoat/build.py"))
    atts = {a.name: tuple(a.location) for a in s["attachments"]}
    for name, att in (("M_Chr_PirateCaptain", "ATT_Captain"), ("M_Chr_PirateDeckhand", "ATT_Deckhand"), ("M_Chr_PirateLookout", "ATT_Lookout")):
        c = load_build(os.path.join(G, "art/source/characters", name, "build.py"))
        for e in c["meshes"]:
            e["object"].location = atts[att]
    for o in bpy.data.objects:
        if o.type == "MESH" and (o.name.endswith("_COL") or "_LOD1" in o.name or "_LOD2" in o.name):
            o.hide_render = o.hide_viewport = True
    # lit panes glow (Neon in game)
    base = bpy.data.materials["MI_PirateBoat_Brick"]
    lit = base.copy()
    lit.name = "MI_Sheet_Lit"
    nt = lit.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 2.2
    for o in bpy.data.objects:
        if "_Lights_" in o.name:
            o.data.materials[0] = lit
    me = bpy.data.meshes.new("Water")
    me.from_pydata([(-5000, -5000, 0), (5000, -5000, 0), (5000, 5000, 0), (-5000, 5000, 0)], [], [(0, 1, 2, 3)])
    w = bpy.data.objects.new("Water", me)
    bpy.context.scene.collection.objects.link(w)
    m = bpy.data.materials.new("Water")
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.03, 0.26, 0.52, 1)
    b.inputs["Roughness"].default_value = 0.35
    w.data.materials.append(m)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(4)
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.context.scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.62, 0.8, 0.98, 1)
    bg.inputs["Strength"].default_value = 0.9
    bpy.context.scene.world = world
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def shoot(cam, name, target, direction, dist, res, lens=50):
    cam.data.lens = lens
    d = mathutils.Vector(direction).normalized()
    cam.location = mathutils.Vector(target) + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = os.path.join(OUT, name + ".png")
    win = bpy.context.window_manager.windows[0]
    with bpy.context.temp_override(window=win, screen=win.screen):     # the MCP add-on runs without a window
        bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    cam = set_scene()
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    t = (0, -1, 13.5)
    shoot(cam, "front34", t, (-0.75, -1.0, 0.42), 62, (768, 768))
    shoot(cam, "side", t, (1, 0, 0.1), 62, (768, 768))
    shoot(cam, "rear34", t, (0.75, 1.0, 0.3), 62, (768, 768))
    shoot(cam, "crew", (0, 0.5, 8.5), (0.8, -0.8, 0.12), 38, (768, 768))
    shoot(cam, "ram", (0, -13, 4), (-0.55, -0.85, 0.22), 24, (768, 768))
    shoot(cam, "phone", (0, 0, 8), (-0.6, -0.8, 0.55), 70, (360, 200), lens=32)
    print("sheet renders in", OUT)


main()
