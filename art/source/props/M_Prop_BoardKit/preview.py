"""Preview scene for the AD sheets (not exported): the kit in place with sample text on every text face (score rows on
both board faces, the real Coming Soon PNG, an owner-coloured name plate, a lit lens and an icon), a minifig beside
each module, and the renders + Pillow contact sheet.
Run inside Blender after build.build() (never save the .blend after this: it overrides the lens material):
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

UI = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/assets/ui"
SIGN_PNG = os.path.join(UI, "signs/sign_coming_soon.png")
ICON_PNG = os.path.join(UI, "hud/xp_star.png")
ROWS = [("Bogdan", 42), ("SeaDog_7", 38), ("Puffin", 31), ("Marina", 24), ("Kelp", 19), ("Captain Z", 15),
        ("Gull", 9), ("Ripple", 4)]
TITLES = ("THIS WEEK", "FERRY", "ALL TIME")


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


def mat(name, rgb, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = 0.6
    if emit:
        bs.inputs["Emission Color"].default_value = (*rgb, 1)
        bs.inputs["Emission Strength"].default_value = emit
    return m


def img_mat(name, path):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=True)
    nt.links.new(tex.outputs["Color"], bs.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bs.inputs["Alpha"])
    bs.inputs["Roughness"].default_value = 0.7
    return m


def rb(slot, x, y, z):
    """Roblox point at a kit slot -> Blender."""
    return Vector(build.K(None, build.SLOTS[slot]).p(x, y, z))


def text(body, slot, x, y, z, size, m, face=-1, align="LEFT", offset=0.0):
    cu = bpy.data.curves.new("PV_T", "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.offset = offset
    o = bpy.data.objects.new("PV_Text", cu)
    o.location = rb(slot, x, y, z)
    o.rotation_euler = (math.pi / 2, 0, 0 if face < 0 else math.pi)
    o.data.materials.append(m)
    bpy.context.scene.collection.objects.link(o)
    return link(o)


def plane(slot, x, y, z, w, h, m, face=-1):
    bpy.ops.mesh.primitive_plane_add(size=1, location=rb(slot, x, y, z), rotation=(math.pi / 2, 0, 0 if face < 0 else math.pi))
    o = bpy.context.active_object
    o.scale = (w, h, 1)
    o.data.materials.append(m)
    return link(o)


def minifig(m, slot, x, z, yaw=0.0):
    b = lego.B()
    k = build.K(b, 0)
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


def board_text():
    ink, white = mat("PV_Ink", (0.02, 0.03, 0.06)), mat("PV_White", (1, 1, 1), emit=0.6)
    top = build.BCY + build.FH / 2
    for face in (-1, 1):
        z = face * (build.SLAB + build.TILE + 0.14)

        def X(u):
            return build.FW / 2 - u if face < 0 else -build.FW / 2 + u
        text("RESCUE BOARD", "Board", X(build.FW / 2), top - 1.15, z, 1.15, white, face, "CENTER")
        for i, u in enumerate(build.COLS):
            text(TITLES[i], "Board", X(u + build.CW / 2), top - 2.55, z, 0.5, ink, face, "CENTER")
            for r, (name, val) in enumerate(ROWS[:build.NROWS]):
                v = build.ROW0 + r * build.ROWP + build.ROWH / 2
                text(str(r + 1), "Board", X(u + build.ROWH / 2), top - v, z, 0.8, ink if r < 3 else white, face,
                     "CENTER")                   # r3: ranks 4-5 sit on navy tiles
                text(name, "Board", X(u + build.ROWH + 0.2), top - v, z, 0.44, white, face, "LEFT")
                text(str(val * (3 - i) if i != 1 else val // 2), "Board", X(u + build.CW - 0.12), top - v, z, 0.44,
                     white, face, "RIGHT")


def scene():
    c = coll()
    for o in list(c.objects):
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == "MESH":
            lod0 = "_LOD" not in o.name and "_COL" not in o.name and not o.name.startswith("TPL_")
            o.hide_render = o.hide_viewport = not lod0
            o.location.x = 0
    # r3: the run.py template brings an HDRI world, water and swatches; render on the plain sky like r2
    bpy.context.scene.world = bpy.data.worlds.get("PV_World") or bpy.data.worlds.new("PV_World")
    kit = bpy.data.materials["MI_BoardKit_Brick"]
    board_text()
    plane("Soon", 0, build.SCY, build.SFZ - 0.01, build.SW, build.SH, img_mat("PV_Soon", SIGN_PNG))
    # the code's owner-coloured NameBoard Part with the outlined name on both faces
    plate = lego.B()
    build.K(plate, build.SLOTS["Sign"]).box((-build.NW / 2, build.NCY - build.NH / 2, -build.ND / 2),
                                            (build.NW / 2, build.NCY + build.NH / 2, build.ND / 2), P.BLUE, bev=0.02)
    po = link(plate.to_object("PV_Plate", kit))
    po.material_slots[0].link = "OBJECT"
    po.material_slots[0].material = mat("PV_Owner", (0.05, 0.42, 0.62))
    blk, wht = mat("PV_Black", (0.01, 0.01, 0.01)), mat("PV_White", (1, 1, 1), emit=0.6)
    for face in (-1, 1):
        z = face * (build.ND / 2 + 0.03)
        text("Bogdan's Isle", "Sign", 0, build.NCY, z + face * 0.01, 4.4, blk, face, "CENTER", offset=0.16)
        text("Bogdan's Isle", "Sign", 0, build.NCY, z + face * 0.03, 4.4, wht, face, "CENTER")
    lens = bpy.data.objects["L05_BeaconLens"]
    lens.material_slots[0].link = "OBJECT"
    # r4: saturated warm yellow #FFC83A (linear 1.0, 0.578, 0.042), strong emission; r3 amber on dark read pale peach
    lm = lens.material_slots[0].material = mat("PV_Lens", (1.0, 0.578, 0.042), emit=2.0)   # 2 x 0.5 EV: R just at 1
    # pure emission: a lit yellow base washed it to cream
    next(n for n in lm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.02, 0.01, 0, 1)
    next(n for n in lm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Specular IOR Level"].default_value = 0.0
    lt = bpy.data.objects.new("PV_LensLight", bpy.data.lights.new("PV_LensLight", "POINT"))
    lt.data.energy, lt.data.color = 1500, (1.0, 0.75, 0.4)
    lt.location = rb("Beacon", 0, build.LENS_Y, 0)
    bpy.context.scene.collection.objects.link(lt)
    link(lt)
    panes = bpy.data.objects["L06_BeaconPanes"]      # the code makes the panes clear: pale-blue glass
    panes.material_slots[0].link = "OBJECT"
    gm = panes.material_slots[0].material = mat("PV_Glass", (0.6, 0.82, 0.95))
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Alpha"].default_value = 0.1   # r4: clearer (r3 0.3)
    gm.use_backface_culling = True                   # r4: one glass layer per side, not four
    plane("Beacon", 0, build.ICON_Y, build.ICON_Z - 0.01, 2.4, 2.4, img_mat("PV_Icon", ICON_PNG))
    for slot, x, z, yaw in (("Board", -10.5, -2.0, 0.4), ("Soon", -9.0, -3.0, 0.3), ("Sign", 9.0, -3.5, -0.3),
                            ("Beacon", 4.5, -2.5, -0.4)):
        minifig(kit, slot, x, z, yaw)
    bpy.ops.mesh.primitive_plane_add(size=240, location=(-38, 0, 0.0))
    g = link(bpy.context.active_object)
    g.data.materials.append(mat("PV_Grass", (0.16, 0.42, 0.11)))
    return c


def setup_render(w=800, h=560):
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
    try:      # r2: AgX washed the palette yellow to khaki; Standard is closer to Roblox's own tonemap
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
        sc.view_settings.exposure = -1.0
    except TypeError:
        pass


def shot(name, target, dist, az, el, out_dir, lens=40, size=(800, 560)):
    setup_render(*size)
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
    os.makedirs(out_dir, exist_ok=True)
    B = build
    tb, ts, tn, tc = (rb("Board", 0, 6.8, 0), rb("Soon", 0, 5.2, -1.5), rb("Sign", 0, 9.5, 0), rb("Beacon", 0, 14, 0))
    r = {"overview": shot("overview", rb("Sign", -6, 18, 0), 150, 12, 12, out_dir, size=(1600, 560))}
    # game distance: the third-person camera ~35-60 studs off, a little above
    r["g_board"] = shot("g_board", tb, 38, 20, 14, out_dir)
    r["g_soon"] = shot("g_soon", ts, 36, -20, 16, out_dir)
    r["g_sign"] = shot("g_sign", tn, 62, 15, 12, out_dir)
    r["g_beacon"] = shot("g_beacon", rb("Beacon", 0, 15, 0), 70, -35, 10, out_dir)
    # close-ups
    r["c_board_f"] = shot("c_board_f", rb("Board", 0, 9.6, 0), 27, 12, 8, out_dir)
    r["c_board_b"] = shot("c_board_b", rb("Board", 0, 9.6, 0), 27, 168, 8, out_dir)
    r["c_soon"] = shot("c_soon", rb("Soon", 0, 5.0, -1.5), 22, -28, 18, out_dir)
    r["c_sign"] = shot("c_sign", rb("Sign", 0, 12, 0), 36, 22, 10, out_dir)
    r["c_lantern"] = shot("c_lantern", rb("Beacon", 0, B.LENS_Y + 0.4, 0), 14, 30, 14, out_dir)
    r["c_base"] = shot("c_base", rb("Beacon", 0, B.ICON_Y - 0.6, 0), 15, 18, 14, out_dir)
    return r


def sheet(r, out_png):
    """One contact sheet: overview, 4 game-distance views, the same at phone-thumbnail size, 6 close-ups."""
    from PIL import Image, ImageDraw
    W = 1600
    rows = []

    def lab(im, s):
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 9 * len(s) + 10, 20), fill=(0, 0, 0))
        d.text((5, 4), s, fill=(255, 255, 255))
        return im
    ov = Image.open(r["overview"]).convert("RGB").resize((W, 560))
    rows.append(lab(ov, "overview (kit strip, minifig 5.6 studs at each)"))
    g = Image.new("RGB", (W, 280), (30, 30, 30))
    th = Image.new("RGB", (W, 150), (30, 30, 30))
    for i, k in enumerate(("g_board", "g_soon", "g_sign", "g_beacon")):
        im = Image.open(r[k]).convert("RGB")
        g.paste(lab(im.resize((400, 280)), k + " (game distance)"), (i * 400, 0))
        th.paste(im.resize((180, 126)), (i * 400 + 110, 12))
    rows += [g, lab(th, "phone thumbnails (180 px)")]
    cl = Image.new("RGB", (W, 2 * 373), (30, 30, 30))
    for i, k in enumerate(("c_board_f", "c_board_b", "c_soon", "c_sign", "c_lantern", "c_base")):
        im = Image.open(r[k]).convert("RGB").resize((533, 373))
        cl.paste(lab(im, k), ((i % 3) * 533, (i // 3) * 373))
    rows.append(cl)
    out = Image.new("RGB", (W, sum(x.height for x in rows)), (30, 30, 30))
    y = 0
    for x in rows:
        out.paste(x, (0, y))
        y += x.height
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    out.save(out_png)
    return out_png
