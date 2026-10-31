"""Preview scene for the AD sheets (not exported): the kit placed round a 20 x 14 lot the way
ConstructionController.kitProps places it (mirror those numbers), a half-built Lego building and a hard-hat minifig.
Run inside Blender after build.build():  import preview; preview.scene(); preview.render(out_dir)
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

import build
import lego
import palette as P

C = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # roblox <-> blender (its own inverse)
HW, HD, TOP = 10.0, 7.0, 18.0     # the lot's half sizes and finished height (st.hw, st.hd, maxY - ground)


def rcf(x, y, z, yaw=0.0, sx=1.0):
    """Roblox CFrame (translation, yaw about y) with an x stretch, as a 4x4."""
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(yaw, 4, "Y") @ Matrix.Diagonal((sx, 1, 1, 1))


def place(coll, key, T):
    src = bpy.data.objects[key]
    slot = dict((n, s) for n, s, _ in [(m[0], m[1], 0) for m in build.MODULES])[key]
    o = bpy.data.objects.new(key + "_p", src.data)
    o.matrix_world = C @ T @ Matrix.Translation((-build.SLOTS[slot], 0, 0)) @ C
    coll.objects.link(o)
    return o


def frame(dirx, dirz, pos):
    """fromMatrix(pos, dir, up): x = dir, y = up, z = x cross y."""
    x = Vector((dirx, 0, dirz))
    y = Vector((0, 1, 0))
    z = x.cross(y)
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2], m[i][3] = x[i], y[i], z[i], pos[i]
    return m


def mesh_from(b, name, coll, mat):
    o = b.to_object(name, mat)
    bpy.context.scene.collection.objects.unlink(o)
    coll.objects.link(o)
    return o


def building(coll, mat):
    """A half-built Lego block: white courses with blue window bands, the top floor stepped and unfinished."""
    b = lego.B()
    k = build.K(b, 0)
    h = 1.2
    for row in range(10):
        y0 = row * h
        frac = 1.0 if row < 7 else (0.7 if row == 7 else 0.45 if row == 8 else 0.25)
        c = P.BLUE if row in (2, 5) else P.WHITE
        x1 = -HW + 2 * HW * frac
        k.box((-HW, y0, -HD), (x1, y0 + h - 0.02, HD), c, bev=0.1)
        if row == 9 or frac < 1:
            for i in range(int((x1 + HW) / 2)):
                k.stud(-HW + 1 + i * 2, y0 + h - 0.02, -HD + 1, c, r=0.5, h=0.35)
    return mesh_from(b, "PV_Building", coll, mat)


def minifig(coll, mat, x, z, yaw=0.0):
    b = lego.B()
    k = build.K(b, 0)
    for s in (-1, 1):
        k.box((s * 0.05, 0, -0.45), (s * 0.95, 2.0, 0.45), P.BLUE, bev=0.1)            # legs
        k.box((s * 1.0, 2.2, -0.35), (s * 1.6, 3.9, 0.35), P.ORANGE, bev=0.1)          # arms
    k.box((-1.0, 2.0, -0.55), (1.0, 4.1, 0.55), P.ORANGE, bev=0.12)                    # hi-vis torso
    k.box((-1.02, 2.9, -0.57), (1.02, 3.2, 0.57), P.WHITE, bev=0.02)
    k.cyl(0, 0, 4.1, 5.1, 0.62, P.YELLOW, n=12)                                         # head
    k.frustum(0, 0, [(4.85, 0.85), (5.2, 0.8), (5.55, 0.55), (5.65, 0.1)], P.YELLOW, n=12)   # hard hat
    o = mesh_from(b, "PV_Minifig", coll, mat)
    o.matrix_world = C @ rcf(x, 0, z, yaw) @ C
    return o


def scene():
    coll = bpy.data.collections.get("Preview") or bpy.data.collections.new("Preview")
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o)
    mat = bpy.data.materials["MI_BuildSiteKit_Brick"]
    for o in bpy.data.objects:
        if o.name.startswith(("L", "Col")) and o.type == "MESH":
            o.hide_render = o.hide_viewport = True
    fw, fd = HW + 4, HD + 4
    corners = [Vector((-fw, 0, -fd)), Vector((fw, 0, -fd)), Vector((fw, 0, fd)), Vector((-fw, 0, fd))]

    def fill(a, b):
        d = b - a
        n = max(1, round(d.length / 8))
        sx = d.length / (n * 8)
        u = d.normalized()
        for i in range(n):
            p = a + u * (i + 0.5) * d.length / n
            place(coll, "L01_FencePanel", frame(u.x, u.z, p) @ Matrix.Diagonal((sx, 1, 1, 1)))

    for i, c in enumerate(corners):
        nxt = corners[(i + 1) % 4]
        u = (nxt - c).normalized()
        place(coll, "L03_FencePost", rcf(c.x, 0, c.z))
        if i == 0:
            place(coll, "L02_FenceGate", rcf(0, 0, -fd))
            fill(c + u * 0.65, Vector((-4, 0, -fd)))
            fill(Vector((4, 0, -fd)), nxt - u * 0.65)
        else:
            fill(c + u * 0.65, nxt - u * 0.65)
    n = max(1, round(HW * 2 / 6))
    sx = HW * 2 / (n * 6)
    for level in range(max(1, min(3, round(TOP / 10)))):
        for i in range(n):
            place(coll, "L04_ScaffoldBay", rcf(-HW + (i + 0.5) * 6 * sx, level * 5, -HD - 1.4, sx=sx))
    place(coll, "L14_Barrier", rcf(fw + 2, 0, -fd + 4, yaw=-math.pi / 2))
    place(coll, "L13_Cone", rcf(-4.9, 0, -fd - 1.3))
    place(coll, "L13_Cone", rcf(4.9, 0, -fd - 1.3))
    base = rcf(-fw - 4.5, 0, fd + 4.5, yaw=math.pi / 4)
    for key in ("L05_CraneBase", "L06_CraneSlew", "L07_CraneHook"):
        place(coll, key, base)
    for n in range(3):
        T = rcf(6.5 + n * 3.8, 0, -fd - 2.4)
        keys = ("L08_StackPallet", "L09_StackLow", "L10_StackMid", "L11_StackTop")
        for key in keys[:4 - n]:                    # three fill states: full, two courses, one course
            place(coll, key, T)
    place(coll, "L12_SignBoard", rcf(-min(8.6, fw - 2.4), 0, -fd - 2))
    building(coll, mat)
    minifig(coll, mat, -3.2, -fd - 3.6, yaw=0.5)
    minifig(coll, mat, -HW + 2, -HD - 1.4 + 5.0, yaw=-0.4)   # on the scaffold deck
    # ground: green baseplate
    bpy.ops.mesh.primitive_plane_add(size=90, location=(0, 0, -0.06))
    g = bpy.context.active_object
    g.name = "PV_Ground"
    gm = bpy.data.materials.get("PV_Grass") or bpy.data.materials.new("PV_Grass")
    gm.use_nodes = True
    bs = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (0.18, 0.45, 0.12, 1)
    bs.inputs["Roughness"].default_value = 0.8
    g.data.materials.append(gm)
    for c2 in list(g.users_collection):
        c2.objects.unlink(g)
    coll.objects.link(g)
    return coll


def setup_render():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.render.resolution_x, sc.render.resolution_y = 1200, 800
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.72, 0.92, 1)
    bg.inputs["Strength"].default_value = 0.9
    sun = bpy.data.objects.get("PV_Sun")
    if not sun:
        sun = bpy.data.objects.new("PV_Sun", bpy.data.lights.new("PV_Sun", "SUN"))
        bpy.context.scene.collection.objects.link(sun)
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(15), math.radians(-35))
    try:
        sc.view_settings.view_transform = "AgX"
    except TypeError:
        pass


def shot(name, target, dist, az, el, lens=40, out_dir="/tmp"):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("PV_Cam")
    if not cam:
        cam = bpy.data.objects.new("PV_Cam", bpy.data.cameras.new("PV_Cam"))
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    t = Vector(target)
    a, e = math.radians(az), math.radians(el)
    cam.location = t + dist * Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath


def render(out_dir):
    setup_render()
    os.makedirs(out_dir, exist_ok=True)
    return [
        shot("game", (0, 0, 6), 70, 25, 28, out_dir=out_dir),                 # third-person game distance
        shot("crane", (12, 8, 13), 44, 30, 12, out_dir=out_dir),              # close: crane + gate
        shot("front", (4, -15.5, 3.2), 21, 8, 12, out_dir=out_dir),           # close: gate, sign, minifig
        shot("stacks", (-10.3, -13.4, 1.5), 13, -15, 28, out_dir=out_dir),    # close: the three pallet states
    ]
