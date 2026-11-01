"""Preview scene for the AD sheets (not exported): both plates over a water plane at the waterline, lit lamp heads,
minifig stand-ins (5.6 studs), the renders and one Pillow contact sheet (copied from M_Prop_BoardKit/preview.py).
Run inside Blender after build.build() (never save the .blend after this: it overrides the lamp materials):
    import preview; preview.scene(); preview.sheet(preview.render(out_dir), out_png)
"""
import math
import os

try:                                 # Blender; sheet() also runs in system python3 (Pillow)
    import bpy
    from mathutils import Vector

    import build
    import lego
    import palette as P
except ImportError:
    pass


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


def mat(name, rgb, emit=0.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = 0.6
    if emit:
        bs.inputs["Emission Color"].default_value = (*rgb, 1)
        bs.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        bs.inputs["Alpha"].default_value = alpha
        bs.inputs["Roughness"].default_value = 0.15
    return m


def rb(slot, x, y, z):
    """Roblox point in a plate frame -> Blender."""
    return Vector((-(build.SLOTS[slot] + x), z, y))


def minifig(m, slot, x, z, yaw=0.0):
    b = lego.B()
    k = build.K(b)
    for s in (-1, 1):
        k.box((s * 0.05, 0, -0.45), (s * 0.95, 2.0, 0.45), P.BLUE, bev=0.1)
        k.box((s * 1.0, 2.2, -0.35), (s * 1.6, 3.9, 0.35), P.RED, bev=0.1)
    k.box((-1.0, 2.0, -0.55), (1.0, 4.1, 0.55), P.RED, bev=0.12)
    k.cyl(0, 0, 4.1, 5.1, 0.62, P.YELLOW, n=12)
    k.frustum(0, 0, [(4.95, 0.7), (5.4, 0.66), (5.6, 0.2)], P.BROWN, n=12)
    o = link(b.to_object("PV_Minifig", m))
    o.location = rb(slot, x, 0, z)
    o.rotation_euler = (0, 0, yaw)
    return o


BARGE_DIR = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/build/prod/M_Veh_SupplyBarge"


def barge(kit):
    """The shipped supply barge (M_Veh_SupplyBarge LOD0) at ATT_BargeMoor with three bright containers aboard and two
    mooring lines to the quay bollards. Preview only: the game moors its own barge there."""
    F = "FreightWharf"
    bx, by, bz, yaw = build.BARGE
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=BARGE_DIR + "/fbx/M_Veh_SupplyBarge/M_Veh_SupplyBarge_LOD0.fbx")
    img = bpy.data.images.load(BARGE_DIR + "/textures/M_Veh_SupplyBarge/T_Barge_Hull_ALB.png", check_existing=True)
    for o in [o for o in bpy.data.objects if o not in before]:
        link(o)
        o.name = "PV_" + o.name
        if o.type != "MESH" or "Crate" in o.name or "_COL" in o.name:   # our containers replace its crates
            bpy.data.objects.remove(o)
            continue
        o.location = rb(F, bx, by, bz)
        o.rotation_euler = (0, 0, math.radians(yaw))
        for m in o.data.materials:
            tex = next((n for n in m.node_tree.nodes if n.type == "TEX_IMAGE"), None) if m.use_nodes else None
            if tex is not None:                          # the FBX points next to itself; the maps live in textures/
                tex.image = img
    b = lego.B()
    k = build.K(b, build.SLOTS[F])
    deck = by + 2.35
    for (lx, lz, c) in ((-10.0, -2.3, P.RED), (-10.0, 2.3, P.BLUE), (-3.0, 0.0, P.GREEN)):  # barge-local (y, x)
        build.container(k, bx - lx, bz - lz, deck, c, length=6.5, w=4.2, h=3.8, along_z=False)
    for qx, rx in ((0.0, -5.0), (24.6, 24.0)):           # mooring lines: bollard neck -> over the kerb -> barge rail
        k.tube([(qx, 2.1, -45.9), (qx - 0.3, 2.0, -47.4), ((qx + rx) / 2, 1.0, -49.4), (rx, -0.2, -50.4)], 0.24, P.ORANGE)
    link(b.to_object("PV_BargeCargo", kit))


FIGS = [("RampWharf", -18.0, -37.5, 0.5), ("RampWharf", 31.5, 30.0, 2.8), ("FreightWharf", 20.0, -36.5, -0.4),
        ("FreightWharf", -31.5, 20.0, 3.0)]


def scene():
    c = coll()
    for o in list(c.objects):
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == "MESH":
            lod0 = "_LOD" not in o.name and "_COL" not in o.name and not o.name.startswith("TPL_")
            o.hide_render = o.hide_viewport = not lod0
    kit = bpy.data.materials["MI_SeaPlateKit_Brick"]
    for n in ("L06_RampLamps", "L13_FreightLamps"):      # the code makes the heads Neon
        o = bpy.data.objects[n]
        o.material_slots[0].link = "OBJECT"
        o.material_slots[0].material = mat("PV_Lamp", (1.0, 0.78, 0.35), emit=2.0)
    for slot, x, z, yaw in FIGS:
        minifig(kit, slot, x, z, yaw)
    barge(kit)
    bpy.ops.mesh.primitive_plane_add(size=900, location=(-80, -40, build.SEA))
    w = link(bpy.context.active_object)
    w.name = "PV_Water"
    wm = mat("PV_Water", (0.05, 0.32, 0.42), alpha=0.82)
    try:
        wm.surface_render_method = "BLENDED"
    except Exception:
        wm.blend_method = "BLEND"
    w.data.materials.append(wm)
    bpy.ops.mesh.primitive_plane_add(size=900, location=(-80, -40, build.SEA - 14))
    f = link(bpy.context.active_object)
    f.name = "PV_Seabed"
    f.data.materials.append(mat("PV_Sand", (0.5, 0.45, 0.32)))
    for slot in build.SLOTS:
        bpy.ops.mesh.primitive_cube_add(size=1, location=rb(slot, 0, -1.3, build.HD + 30.06))    # the island beach past the gangway
        g = link(bpy.context.active_object)
        g.scale = (240, 60, 2.0)
        g.data.materials.append(mat("PV_Beach", (0.86, 0.78, 0.55)))
    return c


def setup_render(w=1024, h=640):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    wd = sc.world or bpy.data.worlds.new("World")
    sc.world = wd
    wd.use_nodes = True
    bg = next(n for n in wd.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.72, 0.92, 1)
    bg.inputs["Strength"].default_value = 0.9
    sun = bpy.data.objects.get("PV_Sun")
    if not sun:
        sun = bpy.data.objects.new("PV_Sun", bpy.data.lights.new("PV_Sun", "SUN"))
        sc.collection.objects.link(sun)
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    try:
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
        sc.view_settings.exposure = -1.0
    except TypeError:
        pass


def shot(name, target, dist, az, el, out_dir, lens=32, size=(1024, 640)):
    """az 0 = from out at sea (Roblox -z), positive = round toward Roblox -x."""
    setup_render(*size)
    sc = bpy.context.scene
    cam = bpy.data.objects.get("PV_Cam")
    if not cam:
        cam = bpy.data.objects.new("PV_Cam", bpy.data.cameras.new("PV_Cam"))
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_end = 2000
    t = Vector(target)
    a, e = math.radians(az), math.radians(el)
    cam.location = t + dist * Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath


def render(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    R, F = "RampWharf", "FreightWharf"
    r = {}
    r["ramp_game"] = shot("ramp_game", rb(R, 38, 0, -58), 122, -60, 30, out_dir)
    r["ramp_close"] = shot("ramp_close", rb(R, -24.6, 0.2, -47), 15, 22, 9, out_dir, lens=30)
    r["ramp_fig"] = shot("ramp_fig", rb(R, -16, 2.4, -40), 15, -28, 16, out_dir, lens=30, size=(768, 480))
    r["ramp_jump"] = shot("ramp_jump", rb(R, 50.0, -1.5, -82), 44, -60, 8, out_dir, size=(768, 480))   # r3: low side
    r["freight_game"] = shot("freight_game", rb(F, 2, 2, -28), 100, 30, 30, out_dir)
    r["freight_close"] = shot("freight_close", rb(F, 24.6, 0.5, -48), 15, -20, 9, out_dir, lens=30)
    r["freight_fig"] = shot("freight_fig", rb(F, 20, 3.0, -38), 17, -35, 16, out_dir, lens=30, size=(768, 480))
    r["freight_crane"] = shot("freight_crane", rb(F, 12, 7, -48), 48, 35, 14, out_dir, size=(768, 480))
    return r


def sheet(r, out_png):
    """Per plate: game distance | close-up, then phone tile (360 px) | minifig | ramp / crane."""
    from PIL import Image, ImageDraw
    W = 2048

    def lab(im, s):
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 7 * len(s) + 12, 18), fill=(0, 0, 0))
        d.text((6, 3), s, fill=(255, 255, 255))
        return im
    rows = []
    for p, extra in (("ramp", "jump"), ("freight", "crane")):
        a = Image.new("RGB", (W, 640), (30, 30, 30))
        a.paste(lab(Image.open(r[p + "_game"]).convert("RGB"), p + " wharf: game distance (~60 studs over water)"), (0, 0))
        a.paste(lab(Image.open(r[p + "_close"]).convert("RGB"), p + ": close-up edge / pylon / bollard"), (1024, 0))
        b = Image.new("RGB", (W, 480), (30, 30, 30))
        ph = Image.open(r[p + "_game"]).convert("RGB").resize((360, 225), Image.LANCZOS)
        b.paste(lab(ph, "phone tile 360 px"), (76, 128))
        b.paste(lab(Image.open(r[p + "_fig"]).convert("RGB"), p + ": minifig scale (5.6-stud figure)"), (512, 0))
        b.paste(lab(Image.open(r[p + "_" + extra]).convert("RGB"), p + ": " + ("jump ramp, low side" if extra == "jump" else extra)), (1280, 0))
        rows += [a, b]
    out = Image.new("RGB", (W, sum(x.height for x in rows)), (30, 30, 30))
    y = 0
    for x in rows:
        out.paste(x, (0, y))
        y += x.height
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    out.save(out_png)
    return out_png
