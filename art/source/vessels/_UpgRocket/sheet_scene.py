"""Sheet renders for the art director (run inside the live Blender MCP session): hull, pilot and the pieces of a level on the
game's frame, three stage angles plus a phone chase cam. Reference scene only: nothing here ships."""
import math
import os

import bpy
from mathutils import Vector

import kit as K
import pieces

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
OUT = os.path.join(GAME, "build/status/2026-11-04/art/rocket_cells")
WATER = 1.5           # hull y of the sea in the game
ANGLES = {"three": (1.0, 0.55, -1.15), "side": (-1, 0.1, 0), "rear": (-1.0, 0.5, 1.1)}


def bl(v):
    return Vector((-v[0], v[2], v[1]))


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for m in list(bpy.data.materials):
        if m.name.startswith(("Ref_", "Stage")):
            bpy.data.materials.remove(m)


def flat_mat(name, rgb, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def plane(name, y, size, mat):
    me = bpy.data.meshes.new(name)
    s = size
    me.from_pydata([(-s, -s, y), (s, -s, y), (s, s, y), (-s, s, y)], [], [(0, 1, 2, 3)])
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def setup():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.image_settings.file_format = "PNG"
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("Stage")     # never the template's HDRI: flat colours like the concept's stage
    sc.world.use_nodes = True
    return sc


def world(rgb, strength):
    bg = next(n for n in bpy.context.scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (*rgb, 1)
    bg.inputs[1].default_value = strength


def sun(rot, energy):
    d = bpy.data.lights.new("Sun", "SUN")
    d.energy = energy
    d.angle = math.radians(12)
    o = bpy.data.objects.new("Sun", d)
    o.rotation_euler = rot
    bpy.context.scene.collection.objects.link(o)


def camera(pos, target, lens):
    cam = bpy.data.cameras.new("Cam")
    cam.lens = lens
    cam.clip_end = 5000
    o = bpy.data.objects.new("Cam", cam)
    o.location = pos
    o.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    bpy.context.scene.camera = o
    return o


def fit(boxes, d, lens, aspect):
    """Distance along d so every box corner sits well inside the frame (corners of whole-object boxes overstate it)."""
    d = d.normalized()
    r = Vector((0, 0, 1)).cross(d).normalized()
    u = d.cross(r)
    pts = [Vector((x, y, z)) for b0, b1 in boxes for x in (b0.x, b1.x) for y in (b0.y, b1.y) for z in (b0.z, b1.z)]
    c = sum(pts, Vector()) / len(pts)
    x0, x1 = min((p - c).dot(r) for p in pts), max((p - c).dot(r) for p in pts)
    y0, y1 = min((p - c).dot(u) for p in pts), max((p - c).dot(u) for p in pts)
    t = c + r * ((x0 + x1) / 2) + u * ((y0 + y1) / 2)
    tv = 18 / lens / aspect
    th = 18 / lens
    dist = 0
    for p in pts:
        v = p - t
        dist = max(dist, v.dot(d) + abs(v.dot(r)) / (th * 0.98), v.dot(d) + abs(v.dot(u)) / (tv * 0.98))
    return t, t + d * dist


def render(path, w, h):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = w, h, 100
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def level_scene(level):
    clear()
    setup()
    hull = pieces.make("M_Veh_RocketCutter")[0]
    hull.location = (-K.ORIGIN[0], K.ORIGIN[2], K.ORIGIN[1])      # the model's pivot in HullRoot space
    objs = [hull]
    for short, (lv, _) in pieces.PIECES.items():
        if lv <= level:
            objs.append(pieces.make(short)[0])
    for o in list(bpy.data.objects):
        if o.type == "EMPTY":
            bpy.data.objects.remove(o)
    bpy.context.view_layer.update()
    boxes = []
    for o in objs:
        cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
        boxes.append((Vector(tuple(min(c[i] for c in cs) for i in range(3))), Vector(tuple(max(c[i] for c in cs) for i in range(3)))))
    return boxes


def phone_scene(level):
    """Sea, sky and the chase camera from behind: slightly off-centre, sized to a phone."""
    plane("Sea", WATER, 3000, flat_mat("StageSea", (0.022, 0.21, 0.45), 0.75))
    world((0.5, 0.74, 0.95), 1.0)
    sun((math.radians(50), 0, math.radians(35)), 3.2)
    back = 1.25 if level >= 44 else 1.0      # the concept's 3/4 chase; the wave walls need it pulled back (RESULT.md)
    pos, target = Vector((11 * back, 20 * back + WATER, 53 * back)), Vector((0, 6 + WATER, 2))
    camera(bl(pos), bl(target), 18 / (math.tan(math.radians(35)) * 1.8))


def shoot(level, phone_only=False):
    os.makedirs(OUT, exist_ok=True)
    boxes = level_scene(level)
    if not phone_only:
        floor = min(b[0].z for b in boxes) - 0.05
        fl = plane("Floor", floor, 4000, flat_mat("StageFloor", (0.66, 0.63, 0.6), 0.6))
        world((0.78, 0.76, 0.74), 0.85)
        sun((math.radians(50), 0, math.radians(35)), 3.2)
        for name, d in ANGLES.items():
            t, pos = fit(boxes, bl(d), 45, 682 / 480)
            cam = camera(pos, t, 45)
            render(os.path.join(OUT, "L%d_%s.png" % (level, name)), 682, 480)
            bpy.data.objects.remove(cam)
        bpy.data.objects.remove(fl)
    phone_scene(level)
    render(os.path.join(OUT, "L%d_phone.png" % level), 720, 400)


def shoot_all(levels=(41, 45, 50)):
    for lv in levels:
        shoot(lv)
