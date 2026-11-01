"""Preview scene for the AD sheets (not exported): the kit in place, a minifig on every Hangout spot ATT (sitting at
seats / lying in the hammock / standing), a second bench at BenchB (+12 on the bench patio), lit globes, flame and water,
the six decor icons' reads side by side, renders + a Pillow contact sheet (copied from M_Prop_BoardKit).
Run inside Blender after build.build() (never save the .blend after this: it overrides the lit materials):
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


def rb(slot, x, y, z):
    """Roblox (x, y, z) from a slot origin -> Blender."""
    return Vector(build.K(None, build.SLOTS[slot]).p(x, y, z))


def minifig(m, at, pose="stand", yaw=0.0):
    """A 5.6-stud minifig at Blender point `at`: stand (feet at at), sit (hips at at, legs forward) or lie."""
    b = lego.B()
    k = build.K(b, 0)
    hip = 2.0
    for s in (-1, 1):
        if pose in ("stand", "lie"):
            k.box((s * 0.05, 0, -0.45), (s * 0.95, hip, 0.45), P.BLUE, bev=0.1)
        else:
            k.box((s * 0.05, hip - 0.9, -2.0), (s * 0.95, hip, 0.45), P.BLUE, bev=0.1)
        k.box((s * 1.0, 2.2, -0.35), (s * 1.6, 3.9, 0.35), P.RED, bev=0.1)
    k.box((-1.0, hip, -0.55), (1.0, 4.1, 0.55), P.RED, bev=0.12)
    k.cyl(0, 0, 4.1, 5.1, 0.62, P.YELLOW, n=12)
    k.frustum(0, 0, [(4.95, 0.7), (5.4, 0.66), (5.6, 0.2)], P.BROWN, n=12)
    o = link(b.to_object("PV_Minifig", m))
    # lie: on its back along +y (head +z Roblox), hips on the rest point, back on the top
    o.location = at - {"sit": Vector((0, 0, hip)), "lie": Vector((0, hip, -0.55))}.get(pose, Vector((0, 0, 0)))
    o.rotation_euler = (math.radians(-90) if pose == "lie" else 0, 0, yaw)
    return o


def scene():
    c = coll()
    for o in list(c.objects):
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == "MESH":
            lod0 = "_LOD" not in o.name and "_COL" not in o.name and not o.name.startswith("TPL_")
            o.hide_render = o.hide_viewport = not lod0
    bpy.context.scene.world = bpy.data.worlds.get("PV_World") or bpy.data.worlds.new("PV_World")
    kit = bpy.data.materials["MI_CommonsKit_Brick"]
    warm = mat("PV_Warm", (1.0, 0.78, 0.42), emit=7.0)
    water = mat("PV_Water", (0.31, 0.75, 1.0))
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name.endswith("Glow"):
            o.data.materials[0] = warm
        if o.type == "MESH" and o.name == "H02_CampfireGlow":
            o.data.materials[0] = mat("PV_Flame", (1.0, 0.72, 0.08), emit=3.5)
        if o.type == "MESH" and o.name == "D06_FountainWater":
            o.data.materials[0] = water
    bench = bpy.data.objects["H04_ParkBench"]
    twin = link(bench.copy())
    twin.location.x -= 12                               # BenchB = BenchA frame +12 Roblox x (Blender -x)
    twin["slot"] = "Bench"
    for n, slot, p in build._spots():
        if n.startswith(("ATT_Canteen_Eat", "ATT_Campfire_Sit", "ATT_Bench_Sit", "ATT_Hammock", "ATT_Cart_",
                         "ATT_ChatEast_", "ATT_ChatWest_", "ATT_Campfire_Warm")) and not n.endswith("Lamp"):
            pose = "sit" if "Sit" in n or "Eat" in n else "lie" if "Lie" in n else "stand"
            at = rb(slot, *p)
            fx, fz = (p[0], -5) if slot == "Bench" else (0, 0)    # benches face front, the rest the module centre
            face = rb(slot, fx, p[1], fz) - at
            yaw = math.atan2(face.x, -face.y) if face.length > 0.1 else 0.0
            minifig(kit, at, pose, yaw)["slot"] = slot
            if slot == "Bench":                         # r3: BenchB's sitters too (same spots, frame x +12)
                minifig(kit, rb(slot, p[0] + 12, p[1], p[2]), pose, yaw)["slot"] = slot
    bpy.ops.mesh.primitive_plane_add(size=320, location=(-70, 0, 0.0))
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


def solo(slot=None):
    """r2: show only one module (+ its minifigs) so neighbours stay out of its tiles; None shows the whole kit."""
    owner = {n: s for n, s, *_ in build.MODULES}
    for o in bpy.data.objects:
        if o.type != "MESH" or "_LOD" in o.name or "_COL" in o.name or o.name.startswith("TPL_"):
            continue
        s = o.get("slot") or owner.get(o.name)
        if s:
            o.hide_render = slot is not None and s != slot


def shot(name, target, dist, az, el, out_dir, lens=40, size=(800, 560), clip=0.1):
    setup_render(*size)
    sc = bpy.context.scene
    cam = bpy.data.objects.get("PV_Cam")
    if not cam:
        cam = bpy.data.objects.new("PV_Cam", bpy.data.cameras.new("PV_Cam"))
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_start = clip
    t = Vector(target)
    a, e = math.radians(az), math.radians(el)
    cam.location = t + dist * Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath


# per module: (slot, look-at x, y, z in the module frame, framing extent in studs)
VIEWS = [("Canteen", 0, 3, 0, 17), ("Campfire", 0, 2, 0, 15), ("Bench", 6, 1.5, -0.4, 21), ("Hammock", 0, 2, 0, 13),
         ("Cart", 0, 3.5, -1, 12), ("ChatEast", 0, 4.0, 0, 11), ("ChatWest", 0, 2.5, 0, 11), ("FlowerBed", 0, 1, 0, 10),
         ("PicnicTable", 0, 1.5, 0, 9), ("LampRow", 0, 4.5, 0, 12), ("FlagPole", 0, 10.5, 3.5, 22), ("Statue", 0, 4.5, 0, 11),
         ("Fountain", 0, 2.2, 0, 9)]


def render(out_dir):
    """The kit overview + every module at a 3/4 game-camera angle (from the front, a little above) and from the top."""
    os.makedirs(out_dir, exist_ok=True)
    solo()
    r = {"overview": shot("overview", rb("ChatEast", -3, 3, 0), 175, 8, 14, out_dir, size=(1600, 560))}
    for s, x, y, z, ext in VIEWS:
        solo(s)
        t = rb(s, x, y, z)
        r["g_" + s] = shot("g_" + s, t, 1.7 * ext, 30, 32, out_dir, size=(600, 420))
        # the canteen's top view is a cutaway under the roof (clip at 5.9 up) so the four eaters show
        r["t_" + s] = shot("t_" + s, t, 1.5 * ext, 0, 89, out_dir, size=(420, 420),
                           clip=1.5 * ext + y - 5.9 if s == "Canteen" else 0.1)
    solo()
    return r


def sheet(r, out_png):
    """One contact sheet (2040 px): overview, 4 modules per row as 3/4 + top pairs, phone-size thumbnails."""
    from PIL import Image, ImageDraw
    W, GW, GH, T = 2040, 300, 210, 210

    def lab(im, s):
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 7 * len(s) + 10, 16), fill=(0, 0, 0))
        d.text((5, 2), s, fill=(255, 255, 255))
        return im
    rows = [lab(Image.open(r["overview"]).convert("RGB").resize((W, 714)), "kit overview (a minifig on every spot)")]
    n = len(VIEWS)
    grid = Image.new("RGB", (W, GH * ((n + 3) // 4)), (30, 30, 30))
    th = Image.new("RGB", (W, 120), (30, 30, 30))
    for i, (s, *_) in enumerate(VIEWS):
        g = Image.open(r["g_" + s]).convert("RGB")
        x, y = (i % 4) * (GW + T), (i // 4) * GH
        grid.paste(lab(g.resize((GW, GH)), s), (x, y))
        grid.paste(Image.open(r["t_" + s]).convert("RGB").resize((T, T)), (x + GW, y))
        th.paste(g.resize((150, 105)), (i * 156 + 4, 12))
    rows += [grid, lab(th, "phone size (150 px)")]
    out = Image.new("RGB", (W, sum(x.height for x in rows)), (30, 30, 30))
    y = 0
    for x in rows:
        out.paste(x, (0, y))
        y += x.height
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    out.save(out_png)
    return out_png
