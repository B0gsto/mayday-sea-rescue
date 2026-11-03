"""Preview scene for the AD sheets (not exported): the kit at LAYOUT in turquoise water, stand-in plate edges at 310, a jet ski
and minifig for scale, renders + Pillow contact sheet. Run in Blender after build (never save the .blend after this):
    import preview; preview.scene(); preview.sheet(preview.render(out_dir), out_png)
"""
import math
import os

try:                                 # Blender; sheet() also runs in system python3 (Pillow)
    import bpy
    from mathutils import Matrix, Vector

    import build
    import lego
    import palette as P
except ImportError:
    pass

FOV_LENS = 18.0                      # Roblox default 70 degrees vertical at this 800 x 560 frame (36 mm sensor)
SHOT = (800, 560)


def coll():
    c = bpy.data.collections.get("Preview") or bpy.data.collections.new("Preview")
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    return c


def link(o):
    for c in list(o.users_collection):
        c.objects.unlink(o)
    coll().objects.link(o)
    return o


def mat(name, rgb, rough=0.6):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = rough
    return m


def rbx(x, y, z):
    return Vector((-x, z, y))


def cam_at(eye, look):
    return rbx(*eye), rbx(*look)


def stand_in_plate(x, z, yaw, kit):
    """Plate stand-in, square, 320 across, centred at radius 470 and turned to the centre."""
    b = lego.B()
    k = build.K(b, 0)
    k.box((-160, -6, -160), (160, 3.6, 160), P.TAN, bev=0.6)
    k.box((-158.5, 3.5, -158.5), (158.5, 4.0, 158.5), P.GREEN, bev=0.2)
    o = link(b.to_object("PV_Plate", kit))
    o.matrix_world = Matrix.Translation(rbx(x, 0, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")


def jet_ski(kit, x, z, yaw=0.0):
    b = lego.B()
    k = build.K(b, 0)
    k.box((-3.2, -0.5, -1.4), (3.2, 1.0, 1.4), P.WHITE, bev=0.3)
    k.box((-5.0, -0.3, -0.8), (-3.2, 0.8, 0.8), P.RED, bev=0.2)
    k.box((-1.0, 1.0, -0.7), (2.2, 1.7, 0.7), P.INK, bev=0.15)
    k.box((-2.4, 1.0, -0.4), (-1.6, 2.6, 0.4), P.DBG, bev=0.1)
    o = link(b.to_object("PV_JetSki", kit))
    o.matrix_world = Matrix.Translation(rbx(x, 0.4, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")


def minifig(kit, x, y, z, yaw=0.0):
    b = lego.B()
    k = build.K(b, 0)
    for s in (-1, 1):
        k.box((s * 0.05, 0, -0.45), (s * 0.95, 2.0, 0.45), P.INK, bev=0.1)
        k.box((s * 1.0, 2.2, -0.35), (s * 1.6, 3.9, 0.35), P.RED, bev=0.1)
    k.box((-1.0, 2.0, -0.55), (1.0, 4.1, 0.55), P.RED, bev=0.12)
    k.cyl(0, 0, 4.1, 5.1, 0.62, P.YELLOW, n=12)
    k.frustum(0, 0, [(4.95, 0.7), (5.4, 0.66), (5.6, 0.2)], P.BROWN, n=12)
    o = link(b.to_object("PV_Minifig", kit))
    o.matrix_world = Matrix.Translation(rbx(x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")


def scene():
    c = coll()
    for o in list(c.objects):
        bpy.data.objects.remove(o)
    slot_of = {n: s for n, s, _ in build.MODULES}
    src = {}
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name in slot_of:
            src[o.name] = o
            o.hide_render = True
            o.hide_viewport = True
        elif o.type == "MESH":
            o.hide_render = o.hide_viewport = True
    for name, x, y, z, yaw, q in build.LAYOUT:
        o = src[name].copy()
        o.hide_render = o.hide_viewport = False
        o.name = "PV_" + name
        coll().objects.link(o)
        ox = build.SLOTS[slot_of[name]]
        o.matrix_world = (Matrix.Translation(rbx(x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
                          @ Matrix.Scale(q, 4) @ Matrix.Translation((ox, 0, 0)))
        if name == "L10_BeaconGlass":                # the code makes the panes clear: pale-blue glass
            o.material_slots[0].link = "OBJECT"
            gm = o.material_slots[0].material = mat("PV_Glass", (0.6, 0.82, 0.95))
            next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Alpha"].default_value = 0.12
        if name == "L08_BeaconLens":                 # the code makes the lantern Neon
            o.material_slots[0].link = "OBJECT"
            nm = o.material_slots[0].material = mat("PV_Neon", (1.0, 0.75, 0.05))
            bs = next(n for n in nm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bs.inputs["Emission Color"].default_value = (1.0, 0.72, 0.05, 1)
            bs.inputs["Emission Strength"].default_value = 1.2
    bpy.context.scene.world = bpy.data.worlds.get("PV_World") or bpy.data.worlds.new("PV_World")
    kit = bpy.data.materials["MI_HubKit_Brick"]
    for i in range(6):
        b = math.radians(60 * i)
        stand_in_plate(470 * math.cos(b), 470 * math.sin(b), -60 * i, kit)
    jet_ski(kit, -7.0, -80.0, 90)
    jet_ski(kit, -34.0, -66.0, 40)
    minifig(kit, 4.0, 0.8, -57.0)
    minifig(kit, 5.0, 6.05, 2.0, 190)
    minifig(kit, 14.0, 3.6, -27.0, 20)
    me = bpy.data.meshes.new("PV_Water")
    me.from_pydata([(-6000, -6000, 0), (6000, -6000, 0), (6000, 6000, 0), (-6000, 6000, 0)], [], [(0, 1, 2, 3)])
    w = bpy.data.objects.new("PV_Water", me)
    coll().objects.link(w)
    w.data.materials.append(mat("PV_Water", (0.04, 0.52, 0.60), rough=0.75))     # the game's clear-weather turquoise
    return c


def setup_render(w, h):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    wd = sc.world
    wd.use_nodes = True
    bg = next(n for n in wd.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.42, 0.66, 0.98, 1)
    bg.inputs["Strength"].default_value = 2.0
    sun = bpy.data.objects.get("PV_Sun")
    if not sun:
        sun = bpy.data.objects.new("PV_Sun", bpy.data.lights.new("PV_Sun", "SUN"))
        sc.collection.objects.link(sun)
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = -1.0


def shot(name, eye, look, out_dir, lens=FOV_LENS, size=SHOT):
    setup_render(*size)
    sc = bpy.context.scene
    cam = bpy.data.objects.get("PV_Cam")
    if not cam:
        cam = bpy.data.objects.new("PV_Cam", bpy.data.cameras.new("PV_Cam"))
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_end = 20000
    cam.location, t = cam_at(eye, look)
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath


def edge_eye(bearing, r=320.0, h=12.0):
    b = math.radians(bearing)
    return (r * math.cos(b), h, r * math.sin(b))


def render(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    r = {}
    for n, br in (("edge_0", 0), ("edge_120", 120), ("edge_240", 240)):
        r[n] = shot(n, edge_eye(br), (0, 22, 0), out_dir)
    r["boat_120"] = shot("boat_120", (-80, 26, -175), (0, 52, -20), out_dir)
    r["boat_60"] = shot("boat_60", (-16, 22, -134), (0, 62, -20), out_dir)
    wx, wz, wy = next((p[1], p[3], math.radians(p[4])) for p in build.LAYOUT if p[0] == "L03_Wreck")
    nx, nz = -math.sin(wy), -math.cos(wy)         # the hull's long side, facing the boat approach
    r["boat_wreck"] = shot("boat_wreck", (wx + 60 * nx, 14, wz + 60 * nz), (wx, 12, wz), out_dir)
    r["c_door"] = shot("c_door", (12, 12, -58), (0, 14, -14), out_dir, lens=26)
    r["c_room"] = shot("c_room", (0, 13.6, -10.5), (0, 10.1, 11), out_dir, lens=18)
    r["c_wreck"] = shot("c_wreck", (wx + 62 * nx + 8, 20, wz + 62 * nz - 12), (wx, 8, wz), out_dir, lens=26)
    bx, bz = next((p[1], p[3]) for p in build.LAYOUT if p[0] == "L04_Buoy")
    bl = math.hypot(bx, bz)
    r["c_buoy"] = shot("c_buoy", (bx * (1 + 34 / bl) - 12, 13, bz * (1 + 34 / bl) + 12), (bx, 11, bz), out_dir, lens=26)
    rx, rz = next((p[1], p[3]) for p in build.LAYOUT if p[0] == "L05_RockA")
    r["c_rock"] = shot("c_rock", (rx + 24, 15, rz - 30), (rx, 8, rz), out_dir, lens=26)
    r["c_stud"] = shot("c_stud", (-34, 18, -66), (-26, 2, -40), out_dir, lens=30)
    r["c_top"] = shot("c_top", (40, 118, -70), (0, 108, 0), out_dir, lens=26)
    fx, fz = next((p[1], p[3]) for p in build.LAYOUT if p[0] == "L07_Raft")
    fl = math.hypot(fx, fz)
    r["c_raft"] = shot("c_raft", (fx * (1 + 62 / fl) + 14, 15, fz * (1 + 62 / fl)), (fx, 15, fz), out_dir, lens=26)
    return r


ROW1 = ("edge_0", "edge_120", "edge_240")
ROW2 = ("boat_120", "boat_60", "boat_wreck")
CLOSE = ("c_door", "c_room", "c_wreck", "c_buoy", "c_rock", "c_stud", "c_top", "c_raft")
LABEL = {"edge_0": "plate edge E, 320 studs, FOV 70", "edge_120": "plate edge, 320 studs", "edge_240": "plate edge, 320 studs",
         "boat_120": "boat, 120 studs", "boat_60": "boat, 60 studs", "boat_wreck": "boat at wreck side, 60 studs",
         "c_door": "door / arch", "c_room": "inside the room", "c_wreck": "wreck", "c_buoy": "buoy",
         "c_rock": "rock", "c_stud": "stud detail", "c_top": "lantern + day mark", "c_raft": "raft"}


def sheet(r, out_png):
    from PIL import Image, ImageDraw
    W, tw, th = 1800, 600, 420
    def lab(im, s):
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 7 * len(s) + 10, 16), fill=(0, 0, 0))
        d.text((4, 2), s, fill=(255, 255, 255))
        return im
    rows = []
    for names in (ROW1, ROW2):
        g = Image.new("RGB", (W, th), (30, 30, 30))
        for i, k in enumerate(names):
            g.paste(lab(Image.open(r[k]).convert("RGB").resize((tw, th)), LABEL[k]), (i * tw, 0))
        rows.append(g)
    p = Image.new("RGB", (W, th // 3 + 8), (30, 30, 30))
    for i, k in enumerate(ROW1 + ROW2):
        p.paste(Image.open(r[k]).convert("RGB").resize((tw // 3 - 4, th // 3)), (i * (W // 6) + 50, 4))
    rows.append(lab(p, "phone strip (1/3 size)"))
    cw, ch = W // 4, int((W // 4) * 0.7)
    cl = Image.new("RGB", (W, 2 * ch), (30, 30, 30))
    for i, k in enumerate(CLOSE):
        im = Image.open(r[k]).convert("RGB").resize((cw, ch))
        cl.paste(lab(im, LABEL[k]), ((i % 4) * cw, (i // 4) * ch))
    rows.append(cl)
    out = Image.new("RGB", (W, sum(x.height for x in rows)), (30, 30, 30))
    y = 0
    for x in rows:
        out.paste(x, (0, y))
        y += x.height
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    out.save(out_png)
    out.resize((1600, int(out.height * 1600 / out.width))).save(out_png.replace(".png", "_small.png"))
    return out_png
