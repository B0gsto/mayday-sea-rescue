"""Sheet renders for the art director (inside the live Blender MCP session): the hull with a level's pieces, three angles plus the
phone chase cam, with a proxy driver at his real size in the hull frame (an R15 is 5.5 studs, the hull is scaled by BoatLevels). Nothing here ships."""
import math
import os

import bpy
from mathutils import Vector

import hk
import pieces

GAME = hk.GAME
OUT = os.path.join(GAME, "build/status/2026-11-04/art/hydrofoil_cells")
ANGLES = {"three": (1.0, 0.45, -1.15), "side": (-1, 0.06, 0), "rear": (-0.45, 0.4, 1.1)}


def game_scale(level):
    return 1 + 1.5 * (level - 1) / 49


def bl(v):
    return Vector((-v[0], v[2], v[1]))


def flat_mat(name, rgb, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def plane(name, z, size, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata([(-size, -size, z), (size, -size, z), (size, size, z), (-size, size, z)], [], [(0, 1, 2, 3)])
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def foam(sea, level):
    """Sheet only: wake and spray where the strut tips cut the sea, so the lift-off gap reads. The game's VFX does this at ATT_Splash*."""
    import bmesh
    dz = pieces.LIFT_Z if level >= 34 else 0
    tips = [(sx * pieces.MAIN_X, pieces.strut_z(pieces.MAIN_Z, 0.3) * -1 + dz) for sx in (-1, 1)] + [(0, pieces.strut_z(pieces.RUDDER_Z, 0.3) * -1 + dz)]
    me = bpy.data.meshes.new("Foam")
    bm = bmesh.new()
    for x, z in tips:
        bm.faces.new([bm.verts.new(bl((x + dx, sea + 0.04, z + dz_))) for dx, dz_ in ((-0.28, -0.7), (0.28, -0.7), (1.5, 12), (-1.5, 12))])
    bm.to_mesh(me)
    bm.free()
    me.materials.append(flat_mat("StageFoam", (0.72, 0.84, 0.94), 0.8))
    o = bpy.data.objects.new("Foam", me)
    bpy.context.scene.collection.objects.link(o)


def driver(s):
    """Seated toy figure, 5.5 studs when standing in the world, so 5.5 / s in the hull frame."""
    k = hk.Kit()
    f = 1 / s
    y, z = pieces.SEAT_TOP, -2.1

    def fig():
        k.box((1.9, 1.0, 1.4), (0, 0.5, 0.7), hk.DARK)
        k.box((2.0, 2.0, 1.1), (0, 1.5, 0), hk.RED)
        for sx in (-1, 1):
            k.box((0.8, 0.8, 2.2), (sx * 1.3, 2.0, 1.0), hk.RED)
        k.cyl(0.8, 1.1, (0, 3.0, 0), hk.YELLOW, n=12)
        k.sphere(0.95, (0, 3.5, 0), hk.WHITE, half=True, n=12, lat=3)
    from mathutils import Matrix
    k.stack.append(k.stack[-1] @ Matrix.Translation((pieces.SEAT_X, y, z)) @ Matrix.Diagonal((f * 1.25, f * 1.25, f * 1.25, 1)))
    fig()
    return k.to_object("Driver", hk.material())


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
    sc.world = bpy.data.worlds.new("Stage")
    sc.world.use_nodes = True
    d = bpy.data.lights.new("Sun", "SUN")
    d.energy, d.angle = 3.2, math.radians(12)
    o = bpy.data.objects.new("Sun", d)
    o.rotation_euler = (math.radians(50), 0, math.radians(35))
    sc.collection.objects.link(o)
    return sc


def world(rgb, strength):
    bg = next(n for n in bpy.context.scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (*rgb, 1)
    bg.inputs[1].default_value = strength


def camera(pos, target, lens):
    cam = bpy.data.cameras.new("Cam")
    cam.lens, cam.clip_end = lens, 5000
    o = bpy.data.objects.new("Cam", cam)
    o.location = pos
    o.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    bpy.context.scene.camera = o
    return o


def fit(objs, d, lens, aspect):
    d = d.normalized()
    r = Vector((0, 0, 1)).cross(d).normalized()
    u = d.cross(r)
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    c = sum(pts, Vector()) / len(pts)
    x0, x1 = min((p - c).dot(r) for p in pts), max((p - c).dot(r) for p in pts)
    y0, y1 = min((p - c).dot(u) for p in pts), max((p - c).dot(u) for p in pts)
    t = c + r * ((x0 + x1) / 2) + u * ((y0 + y1) / 2)
    dist = max(max(v.dot(d) + abs(v.dot(r)) / (18 / lens * 0.96), v.dot(d) + abs(v.dot(u)) / (18 / lens / aspect * 0.96)) for v in (p - t for p in pts))
    return t, t + d * dist


def render(path, w, h):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = w, h, 100
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def scene(level):
    """The boat at a level; returns (objects, asset y of the sea)."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    setup()
    a, b, _ = pieces.hull_objects()
    sea = hk.WATER_ASSET
    if level >= 34:             # Sky Stilts: the foil set moves, the sea sits lower in the hull frame
        b.location = bl((0, -pieces.LIFT, pieces.LIFT_Z))
        sea -= pieces.LIFT
    objs = [a, b]
    for short, (lv, _) in pieces.PIECES.items():
        if lv <= level:
            objs.append(pieces.make(short)[0])
    objs.append(driver(game_scale(level)))
    for o in list(bpy.data.objects):
        if o.type == "EMPTY":
            bpy.data.objects.remove(o)
    bpy.context.view_layer.update()
    return objs, sea


def shoot_phone(level, name=None):
    objs, sea = scene(level)
    plane("Sea", sea, 3000, flat_mat("StageSea", (0.022, 0.21, 0.45), 0.75))
    foam(sea, level)
    world((0.5, 0.74, 0.95), 1.0)
    pos, target = Vector((1, 20 + sea, 38)), Vector((0, 7 + sea, -2))     # the chase cam is centred in play
    camera(bl(pos), bl(target), 18 / (math.tan(math.radians(35)) * 1.8))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name or "L%d_phone.png" % level)
    render(path, 720, 400)
    return path


def shoot(level):
    objs, sea = scene(level)
    sp = plane("Sea", sea, 3000, flat_mat("StageSea", (0.022, 0.21, 0.45), 0.75))
    foam(sea, level)
    world((0.5, 0.74, 0.95), 1.0)
    os.makedirs(OUT, exist_ok=True)
    for name, d in ANGLES.items():
        t, pos = fit(objs, bl(d), 45, 682 / 480)
        cam = camera(pos, t, 45)
        render(os.path.join(OUT, "L%d_%s.png" % (level, name)), 682, 480)
        bpy.data.objects.remove(cam)
    return shoot_phone(level)
