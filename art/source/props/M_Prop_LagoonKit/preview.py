"""Preview scene for the AD sheets (not exported): the kit at LAYOUT over a warm-tan terrain STAND-IN (the real sand is terrain, not in this kit), turquoise water,
a jet ski and minifigs for scale, renders + Pillow contact sheet. Run in Blender after build (never save the .blend after this):
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
ISLE = [(0, 270), (35, 170), (90, 120), (145, 170), (180, 270), (220, 150), (255, 130), (285, 130), (320, 150), (360, 270)]   # tools/world/layout.py main isle ring


def ground(x, z):
    """Stand-in for groundY on the main isle: beach rising inland, the lookout dune, the flat café pad; below 0 = water."""
    a = math.degrees(math.atan2(z - 4980, x - 300)) % 360
    r = math.hypot(x - 300, z - 4980)
    R = next(r0 + (r1 - r0) * (a - a0) / (a1 - a0) for (a0, r0), (a1, r1) in zip(ISLE, ISLE[1:]) if a0 <= a <= a1)
    t = max(0.0, min(1.0, (R - r) / 60.0))
    h = 14.0 * t * t * (3 - 2 * t) if R > r else -0.12 * (r - R)
    h = max(h, -14.0)
    h += 12.0 * math.exp(-((x - 300) ** 2 + (z - 4950) ** 2) / (2 * 40.0 ** 2)) * (1 if R > r else 0)
    if 360 <= x <= 450 and 4960 <= z <= 5030:
        h = 16.3 - 1.0
    return h


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


def terrain():
    x0, x1, z0, z1, st = -60, 700, 4700, 5180, 6
    nx, nz = (x1 - x0) // st + 1, (z1 - z0) // st + 1
    verts = [tuple(rbx(x0 + i * st, ground(x0 + i * st, z0 + j * st), z0 + j * st)) for j in range(nz) for i in range(nx)]
    faces = [(j * nx + i, j * nx + i + 1, (j + 1) * nx + i + 1, (j + 1) * nx + i) for j in range(nz - 1) for i in range(nx - 1)]
    me = bpy.data.meshes.new("PV_Terrain")
    me.from_pydata(verts, [], faces)
    me.materials.append(mat("PV_Sand", (0.72, 0.56, 0.34), rough=0.9))        # warm-tan stand-in, NOT the game's white sand
    t = bpy.data.objects.new("PV_Terrain", me)
    coll().objects.link(t)


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
        if y is None:
            y = ground(x, z)
            if y <= 0.5:
                continue
        o = src[name].copy()
        o.hide_render = o.hide_viewport = False
        o.name = "PV_" + name
        coll().objects.link(o)
        ox = build.SLOTS[slot_of[name]]
        o.matrix_world = (Matrix.Translation(rbx(x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
                          @ Matrix.Scale(q, 4) @ Matrix.Translation((ox, 0, 0)))
        if name == "L08_CafeBulbs":                   # the code makes them Neon
            o.material_slots[0].link = "OBJECT"
            nm = o.material_slots[0].material = mat("PV_Neon", (1.0, 0.8, 0.4))
            bs = next(n for n in nm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bs.inputs["Emission Color"].default_value = (1.0, 0.8, 0.4, 1)
            bs.inputs["Emission Strength"].default_value = 1.0
    bpy.context.scene.world = bpy.data.worlds.get("PV_World") or bpy.data.worlds.new("PV_World")
    kit = bpy.data.materials["MI_LagoonKit_Brick"]
    jet_ski(kit, 490.0, 4802.0, 90)
    jet_ski(kit, 255.0, 5205.0, 30)
    minifig(kit, 498.0, 3.5, 4840.0, 0)
    minifig(kit, 405.0, 16.9, 5016.0, 180)
    minifig(kit, 419.0, 16.9, 4986.0, 0)
    minifig(kit, 408.0, ground(408, 5052), 5052.0, 180)
    minifig(kit, 300.0, ground(300, 4965), 4965.0, 180)
    terrain()
    me = bpy.data.meshes.new("PV_Water")
    me.from_pydata([(-6000, 0, 0), (6000, 0, 0), (6000, 8000, 0), (-6000, 8000, 0)], [], [(0, 1, 2, 3)])
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
    cam.location, t = rbx(*eye), rbx(*look)
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath


SHOTS = {
    "land_120": ((505, 14, 4692), (480, 13, 4860), FOV_LENS),         # from the sea, 120 studs off the T-head (island.dock), on her sightline past the café roof
    "land_60": ((492, 12, 4752), (478, 13, 4900), FOV_LENS),
    "statue_120": ((385, 13, 5170), (303, 42, 5265), FOV_LENS),       # statue from a boat in the lagoon, 125 studs, third person
    "g_cafe": ((405, 28, 5044), (405, 22, 4985), FOV_LENS),           # game view from the beach up at the café
    "g_statue": ((300, 14, 5160), (298, 46, 5265), FOV_LENS),         # game view: statue from the water's edge
    "g_beach": ((418, 19, 5112), (408, 6, 5062), FOV_LENS),           # game view: beach props
    "c_statue": ((358, 32, 5145), (300, 48, 5265), 20),               # yaw 340: she faces the shore and the café
    "c_head": ((307, 72, 5193), (276, 69, 5253), 20),
    "c_back": ((358, 30, 5385), (306, 46, 5265), 20),                 # lagoon side
    "c_cafe_in": ((405, 23, 4990), (405, 21, 4966), 16),
    "c_door": ((434, 24, 4966), (415, 21, 4972), 18),
    "c_terrace": ((425, 26, 5022), (405, 19, 5000), 22),
    "c_jetty": ((478, 14, 4798), (500, 7, 4816), 22),
    "c_stairs": ((512, 16, 4905), (498, 8, 4935), 22),
    "c_palm": ((338, 26, 5084), (356, 15, 5060), 20),
    "c_arch": ((590, 12, 4795), (590, 16, 4870), 22),
    "c_coral": ((458, 10, 5110), (440, 3, 5085), 26),
    "c_daymark": ((268, 34, 5020), (300, 36, 4950), 18),
}


def render(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    return {n: shot(n, e, l, out_dir, lens=q) for n, (e, l, q) in SHOTS.items()}


ROW1 = ("land_120", "land_60", "statue_120")
ROW2 = ("g_cafe", "g_statue", "g_beach")
CLOSE = ("c_statue", "c_head", "c_back", "c_cafe_in", "c_door", "c_terrace", "c_jetty", "c_stairs", "c_palm", "c_arch", "c_coral", "c_daymark")
LABEL = {"land_120": "water, 120 from landing dock", "land_60": "water, 60 from dock", "statue_120": "boat to statue, 125", "g_cafe": "game: cafe (TAN = terrain stand-in)",
         "g_statue": "game: statue from shore", "g_beach": "game: beach props", "c_statue": "statue, shore side (front)", "c_head": "head + shell, front", "c_back": "statue, lagoon side", "c_cafe_in": "cafe hatch, inside", "c_door": "cafe walk-in door",
         "c_terrace": "terrace furniture", "c_jetty": "jetty T-head", "c_stairs": "stairs", "c_palm": "palm + stud base", "c_arch": "rock arch", "c_coral": "coral cluster",
         "c_daymark": "day mark + telescope"}


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
    for i, k in enumerate(ROW1 + ROW2 + ("c_statue",)):
        p.paste(Image.open(r[k]).convert("RGB").resize((tw // 3 - 4, th // 3)), (i * (W // 7) + 30, 4))
    rows.append(lab(p, "phone strip (1/3 size)"))
    n = (len(CLOSE) + 3) // 4
    cw, ch = W // 4, int((W // 4) * 0.7)
    cl = Image.new("RGB", (W, n * ch), (30, 30, 30))
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
