"""AD contact sheet for M_Upg_JetSki (not exported): L1, L5, L10 from three angles plus the phone chase view.

In Blender, after the pipeline (never save the .blend after this):  import preview; preview.render(out_dir); preview.zfight_with_hull()
Then, system python3 (Pillow):  python3 preview.py sheet <out_dir> <out.png>
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = {1: [], 5: ["SharkFin", "RescueSled", "TwinEngines", "FlamePipes"],
          10: ["SharkFin", "RescueSled", "TwinEngines", "FlamePipes", "BananaBoat", "HugeSpoiler", "BullNose", "HornStack", "TurboCrown"]}
VIEWS = {"front": (-135, 18), "side": (180, 8), "rear": (130, 22)}      # azimuth from +X (Blender port side; bow at -Y), elevation
PHONE = (320, 148)


def rider(mat, off):
    """Scale-ref stand-in for the player (the concept's seat, grips, helmet top), never exported."""
    import kitgeo
    from mathutils import Matrix
    b = kitgeo.B(0)
    b.rbox((0, 3.62, .95), (1.26, 1.25, .64), "VestYellow", r=.2, T=Matrix.Rotation(0, 4, "X"))
    for sx in (1, -1):
        b.tube([(sx * .66, 4.06, .86), (sx * .86, 3.62, -.02), (sx * .88, 3.38, -1.0)], .2, "SuitNavy", rs=10, f=.2)
        b.tube([(sx * .42, 2.95, .95), (sx * .78, 2.8, -.1), (sx * .86, 1.65, .55)], .24, "SuitNavy", rs=10, f=.25)
        b.sphere((sx * .88, 3.36, -1.07), .15, "Skin", n=10)
    b.rbox((0, 4.62, .78), (.8, .62, .8), "Skin", r=.2)
    b.sphere((0, 4.92, .78), .55, "ToothWhite", n=16, scale=(1, .95, 1.04))
    b.rbox((0, 4.84, .36), (.72, .2, .2), "Visor", r=.06)
    return b.to_object("PV_Rider", mat, off)


def render(out_dir):
    import bpy
    import kitgeo
    import pieces as build
    from mathutils import Vector
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    for o in bpy.data.objects:
        o.hide_render = True
    mat = kitgeo.material("MI_UpgJetSki_Brick", build.STEM)
    kit = {}
    for _, short, fn in build.PIECES:
        b = kitgeo.B(0)
        fn(b)
        kit[short] = b.to_object("PV_" + short, mat, build.HULL_OFF)
    # the shipped hull: its bake sources carry the real materials and livery; the old Sled stays out (concept, build order 1)
    src = os.path.join(build.HULL, "M_Veh_JetSki.blend")
    with bpy.data.libraries.load(src) as (a, t):
        t.objects = [n for n in a.objects if n.endswith("_HP") and n.startswith("M_Veh_JetSki_") and "Sled" not in n]
    hull = [o for o in t.objects if o]
    for o in hull:
        sc.collection.objects.link(o)
        o.hide_render = False
    hull.append(rider(mat, build.HULL_OFF))
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    wd = bpy.data.worlds.new("PV_World")
    wd.use_nodes = True
    bg = next(n for n in wd.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.72, 0.78, 0.82, 1)
    bg.inputs["Strength"].default_value = 0.9
    sc.world = wd
    sd = bpy.data.lights.new("PV_Sun", "SUN")
    sd.energy = 2.6
    sd.angle = math.radians(8)
    sun = bpy.data.objects.new("PV_Sun", sd)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    cd = bpy.data.cameras.new("PV_Cam")
    cam = bpy.data.objects.new("PV_Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    wm = bpy.data.materials.new("PV_Water")
    wm.use_nodes = True
    bs = next(n for n in wm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (0.05, 0.42, 0.62, 1)
    bs.inputs["Roughness"].default_value = 0.8
    wmesh = bpy.data.meshes.new("PV_Water")
    wmesh.from_pydata([(-300, -300, 0), (300, -300, 0), (300, 300, 0), (-300, 300, 0)], [], [(0, 1, 2, 3)])
    wmesh.materials.append(wm)
    water = bpy.data.objects.new("PV_Water", wmesh)
    water.location.z = 0.92
    sc.collection.objects.link(water)

    def aim(eye, at):
        cam.location = eye
        cam.rotation_euler = (Vector(at) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()

    def show(level):
        for n, o in kit.items():
            o.hide_render = n not in LEVELS[level]

    for level in LEVELS:
        show(level)
        shown = hull + [o for o in kit.values() if not o.hide_render]
        pts = [o.matrix_world @ Vector(c) for o in shown for c in o.bound_box]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        centre = Vector([(lo[i] + hi[i]) / 2 for i in range(3)])
        radius = max((p - centre).length for p in pts)
        water.hide_render = True
        cd.lens = 60
        sc.render.resolution_x = sc.render.resolution_y = 512
        for view, (az, el) in VIEWS.items():
            a, e = math.radians(az), math.radians(el)
            fov = 2 * math.atan(18 / cd.lens)
            d = radius / math.sin(fov / 2) * 0.92
            aim(centre + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * d, centre)
            sc.render.filepath = os.path.join(out_dir, "L%02d_%s.png" % (level, view))
            bpy.ops.render.render(write_still=True)
        # phone chase camera, as in the concept: look (0, 1, 2), 17 back, 30 degrees down
        water.hide_render = False
        cd.lens = 20
        sc.render.resolution_x, sc.render.resolution_y = PHONE[0] * 2, PHONE[1] * 2
        look = Vector((0, 2 + build.HULL_OFF, 1.0))
        aim(look + Vector((0, 17 * math.cos(math.radians(30)), 17 * math.sin(math.radians(30)))), look)
        sc.render.filepath = os.path.join(out_dir, "L%02d_phone.png" % level)
        bpy.ops.render.render(write_still=True)
    return out_dir


def zfight_with_hull():
    """All nine pieces (LOD0, as render() left them) against the shipped hull's LOD0: they show together in game."""
    import bpy
    import pieces as build
    import zfight_check as Z
    Z.GRID = build.PAL.GRID
    with bpy.data.libraries.load(os.path.join(build.HULL, "M_Veh_JetSki.blend")) as (a, t):
        t.objects = [n for n in a.objects if n.endswith("_LOD0") and n.startswith("M_Veh_JetSki_") and "Sled" not in n]
    hull = [o for o in t.objects if o]
    for o in hull:
        bpy.context.scene.collection.objects.link(o)
    kit = [o for o in bpy.data.objects if o.name.startswith("PV_") and o.type == "MESH" and o.name not in ("PV_Rider", "PV_Water")]
    rows = Z.analyse(Z.collect(bpy, kit + hull))
    vis = [r for r in rows if r["visible"]]
    return len(kit), len(hull), len(rows), len(vis)


def sheet(out_dir, out_png):
    from PIL import Image, ImageDraw, ImageFont
    C, W = 256, 1024
    im = Image.new("RGB", (W, C * 3), (24, 30, 36))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf", 15)
    for r, level in enumerate(LEVELS):
        for c, view in enumerate(VIEWS):
            cell = Image.open(os.path.join(out_dir, "L%02d_%s.png" % (level, view))).convert("RGB").resize((C, C), Image.LANCZOS)
            im.paste(cell, (c * C, r * C))
        ph = Image.open(os.path.join(out_dir, "L%02d_phone.png" % level)).convert("RGB")
        ph = ph.resize((C, C * PHONE[1] // PHONE[0]), Image.LANCZOS)
        im.paste(ph, (3 * C, r * C + (C - ph.height) // 2))
        d.text((6, r * C + 5), "L%d" % level, font=f, fill=(20, 20, 20))
        d.text((3 * C + 6, r * C + 5), "phone", font=f, fill=(230, 230, 230))
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    im.save(out_png)
    print(out_png, im.size)


if __name__ == "__main__" and len(sys.argv) > 3 and sys.argv[1] == "sheet":
    sheet(sys.argv[2], sys.argv[3])
