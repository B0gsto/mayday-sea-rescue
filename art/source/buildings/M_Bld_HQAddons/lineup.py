"""HQ L1-L5 lineup: path view, game view, phone read and close-ups of the exported LOD0 FBXs, plus a contact sheet.

In the live Blender MCP session (renders in a temporary scene "HQ_LINEUP", deleted afterwards; other scenes untouched):
    import sys, runpy; sys.argv = ["lineup.py", "r1"]   # optional 2nd arg: output root (default H below)
    runpy.run_path(W + "/art/source/buildings/M_Bld_HQAddons/lineup.py", run_name="__main__")
The sheet step runs in system python3 (Pillow), called by the Blender run; alone: python3 lineup.py r1 [root] --sheet
Levels: L1 = RescueHQ Lv1, L2 = Lv1+Lv2, L3 = HQAddons Lv3, L4 = Lv3+Lv4, L5 = Lv3..Lv5, plus the M_Prop_HQInterior
Lv3..Lvn props (same HQ-spot frame) behind the open door, and stand-ins for code-added parts: the "Rescue Station"
ribbons on ATT_Sign_01/02 (L1/L2), the Station board + lifebuoy on ATT_Sign_03 and the ridge beacon mast (L3/L4).
Blender coords: door faces -Y (the path). Game/path cameras fit the level's whole bounding box (8% margin).
"""
import json
import math
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.abspath(os.path.join(HERE, "../../../.."))
H = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/build/status/2026-11-01/perfect/HQ"
args = [a for a in sys.argv[1:] if a != "--sheet"]
TAG = args[0] if args else "r1"
ROOT = args[1] if len(args) > 1 else H
OUT = os.path.join(ROOT, TAG)
LEVELS = ("L1", "L2", "L3", "L4", "L5")
INTERIOR_FBX = "/Users/bogdan/.t3/worktrees/MaydaySeaRescue/t3-1765274a/assets/fbx/M_Prop_HQInterior"
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
CLOSE = ("close_door_L1", "close_door_L3", "close_windows_L3", "close_roof_L3", "close_L4_mast_dish",
         "close_L5_lantern", "close_L2_front")


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 28)
    except OSError:
        font = ImageFont.load_default()
    SW, PAD, LH = 2400, 8, 36

    def tile(path, w, label):
        im = Image.open(path).convert("RGB")
        im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
        c = Image.new("RGB", (w, im.height + LH), (24, 26, 30))
        c.paste(im, (0, LH))
        ImageDraw.Draw(c).text((6, 3), label, fill=(255, 255, 255), font=font)
        return c

    def row(names, labels, per):
        w = (SW - PAD * (per + 1)) // per
        return [tile(os.path.join(OUT, n + ".png"), w, l) for n, l in zip(names, labels)], per

    phones = [Image.open(os.path.join(OUT, "game_%s.png" % l)).convert("RGB").resize((320, 180), Image.LANCZOS)
              for l in LEVELS]
    strip = Image.new("RGB", (320 * 5 + 4 * 4, 180), (24, 26, 30))
    for i, p in enumerate(phones):
        strip.paste(p, (i * 324, 0))
    strip.save(os.path.join(OUT, "phone_strip.png"))
    rows = [row(["path_" + l for l in LEVELS], ["path " + l for l in LEVELS], 5),
            row(["game_" + l for l in LEVELS], ["game " + l for l in LEVELS], 5),
            ([tile(os.path.join(OUT, "phone_strip.png"), strip.width, "phone 320x180  L1  L2  L3  L4  L5")], 1),
            row(CLOSE[:4], CLOSE[:4], 4), row(CLOSE[4:], CLOSE[4:], 4)]
    heights = [max(t.height for t in ts) for ts, _ in rows]
    out = Image.new("RGB", (SW, sum(heights) + PAD * (len(rows) + 1)), (24, 26, 30))
    y = PAD
    for (ts, per), h in zip(rows, heights):
        w = (SW - PAD * (per + 1)) // per
        for i, t in enumerate(ts):
            out.paste(t, (PAD + i * (w + PAD), y))
        y += h + PAD
    dst = os.path.join(ROOT, TAG + "_sheet.png")
    out.save(dst)
    small = os.path.join(ROOT, TAG + "_sheet_small.png")
    subprocess.run(["sips", "-Z", "1600", dst, "--out", small], check=True, capture_output=True)
    print("[lineup] sheet", dst)


def render_all():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    sys.path.insert(0, os.path.join(W, "tools/blender"))
    import template

    prev = bpy.context.window.scene
    scene = bpy.data.scenes.new("HQ_LINEUP")
    bpy.context.window.scene = scene
    before = (set(bpy.data.objects), set(bpy.data.meshes), set(bpy.data.materials), set(bpy.data.images),
              set(bpy.data.cameras), set(bpy.data.lights), set(bpy.data.worlds), set(bpy.data.curves),
              set(bpy.data.fonts))
    try:
        objs = {}
        srcs = {a: (os.path.join(W, "build/prod", a, "fbx", a), os.path.join(W, "build/prod", a, "textures", a))
                for a in ("M_Bld_RescueHQ", "M_Bld_HQAddons")}
        srcs["M_Prop_HQInterior"] = (INTERIOR_FBX, INTERIOR_FBX.replace("/fbx/", "/textures/"))  # read-only
        for asset, (fbx, tex) in srcs.items():
            old = set(bpy.data.objects)
            bpy.ops.import_scene.fbx(filepath=os.path.join(fbx, asset + "_LOD0.fbx"))
            objs[asset] = [o for o in bpy.data.objects if o not in old]
            # the FBX points at textures next to it; prod ones live in build/prod/<asset>/textures/<asset>
            for o in objs[asset]:
                for s in o.material_slots:
                    for n in (s.material.node_tree.nodes if s.material and s.material.use_nodes else ()):
                        if n.type == "TEX_IMAGE" and n.image and not os.path.isfile(bpy.path.abspath(n.image.filepath)):
                            n.image.filepath = os.path.join(tex, os.path.basename(n.image.filepath))
                            n.image.reload()
        att = {a["name"]: a["blender"] for a in json.load(open(os.path.join(
            W, "build/prod/M_Bld_HQAddons/fbx/M_Bld_HQAddons/M_Bld_HQAddons.attachments.json")))["attachments"]}

        def lv(o, asset):
            base = re.sub(r"\.\d{3}$", "", o.name)
            if o.type != "MESH" or base.endswith("_COL"):
                return None
            m = re.match(r"(?:M_Bld_RescueHQ_)?Lv(\d)_", base)
            return int(m.group(1)) if m else None

        def box(name, lo, hi, rgb, rough=0.5):
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=[(a + b) / 2 for a, b in zip(lo, hi)])
            o = bpy.context.active_object
            o.name, o.scale = "LINEUP_" + name, [b - a for a, b in zip(lo, hi)]
            o.data.materials.append(template.material("MI_LINEUP_" + name, rgb=rgb, roughness=rough))
            return o

        ink = template.material("MI_LINEUP_Ink", rgb=(0.05, 0.07, 0.12), roughness=0.5)
        font = bpy.data.fonts.load(FONT, check_existing=True)

        def text(name, body, cx, front_y, cz, w, h):
            # bold dark text facing -Y, extruded 0.02, 0.03 proud of front_y, scaled to fit w x h
            cu = bpy.data.curves.new("LINEUP_" + name, "FONT")
            cu.body, cu.font, cu.extrude, cu.align_x, cu.align_y = body, font, 0.02, "CENTER", "CENTER"
            o = bpy.data.objects.new("LINEUP_" + name, cu)
            scene.collection.objects.link(o)
            o.data.materials.append(ink)
            o.rotation_euler = (math.radians(90), 0, 0)
            bpy.context.view_layer.update()
            k = min(w / o.dimensions.x, h / o.dimensions.y)
            o.scale = (k, k, 1)
            o.location = (cx, front_y - 0.03, cz)
            return o

        # code-added stand-ins: L1/L2 white "Rescue Station" ribbons (7-l x 1.1 x 0.3) at ATT_Sign_0l + (0,-0.2,-1.1)
        ratt = {a["name"]: a["blender"] for a in json.load(open(os.path.join(
            W, "build/prod/M_Bld_RescueHQ/fbx/M_Bld_RescueHQ/M_Bld_RescueHQ.attachments.json")))["attachments"]}
        ribbons = {}
        for l in (1, 2):
            ax, ay, az = ratt["ATT_Sign_0%d" % l]
            w, cy, cz = 7 - l, ay - 0.2, az - 1.1
            ribbons[l] = [box("Ribbon%d" % l, (ax - w / 2, cy - 0.15, cz - 0.55), (ax + w / 2, cy + 0.15, cz + 0.55),
                              (0.95, 0.95, 0.95)),
                          text("RibbonText%d" % l, "Rescue Station", ax, cy - 0.15, cz, w - 0.6, 0.8)]
        # Station board 12 x 3 x 0.4 centred on ATT_Sign_03, red/white lifebuoy at its left, the level's name (code)
        sx, sy, sz = att["ATT_Sign_03"]
        sign = [box("Sign", (sx - 6, sy - 0.2, sz - 1.5), (sx + 6, sy + 0.2, sz + 1.5), (0.95, 0.95, 0.95)),
                ]
        names = {3: "Lifeboat Station", 4: "Coastguard Base", 5: "Coastguard HQ"}
        signtext = {l: [text("SignText%d" % l, n, sx + 1.2, sy - 0.2, sz, 8.8, 1.9)] for l, n in names.items()}
        bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.32, location=(sx - 4.6, sy - 0.3, sz),
                                         rotation=(math.radians(90), 0, 0))
        buoy = bpy.context.active_object
        buoy.name = "LINEUP_Lifebuoy"
        buoy.data.materials.append(template.material("MI_LINEUP_BuoyRed", rgb=(0.85, 0.06, 0.05), roughness=0.4))
        buoy.data.materials.append(template.material("MI_LINEUP_BuoyWhite", rgb=(0.95, 0.95, 0.95), roughness=0.4))
        for p in buoy.data.polygons:  # 8 alternating red/white bands
            p.material_index = int((math.atan2(p.center.y, p.center.x) + math.pi) / (math.pi / 4)) % 2
        sign.append(buoy)
        # warm fill so the open door shows a lit room
        fill = bpy.data.objects.new("LINEUP_InteriorFill", bpy.data.lights.new("LINEUP_InteriorFill", "POINT"))
        fill.data.energy, fill.data.color, fill.data.shadow_soft_size = 6000, (1.0, 0.78, 0.55), 3.0
        fill.location = (0, -4, 9)
        scene.collection.objects.link(fill)
        interior = [fill]
        mast = [box("Mast", (-18.5, -0.5, 21), (-17.5, 0.5, 29), (0.5, 0.5, 0.52)),
                box("MastBase", (-19.2, -1.2, 28.4), (-16.8, 1.2, 29.0), (0.5, 0.5, 0.52))]
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9, location=(-18, 0, 29.8))
        ball = bpy.context.active_object
        ball.name = "LINEUP_MastBall"
        ball.data.materials.append(template.material("MI_LINEUP_MastBall", rgb=(0.85, 0.05, 0.04), roughness=0.4))
        mast.append(ball)

        rq = {o: lv(o, "") for o in objs["M_Bld_RescueHQ"]}
        ad = {o: lv(o, "") for o in objs["M_Bld_HQAddons"]}
        ir = {o: lv(o, "") for o in objs["M_Prop_HQInterior"]}
        assert any(l == 3 for l in ir.values()), "no Lv3 interior meshes"

        def lvl(d, n):
            return [o for o, l in d.items() if l is not None and l <= n]

        comp = {"L1": lvl(rq, 1) + ribbons[1], "L2": lvl(rq, 2) + ribbons[1] + ribbons[2],
                "L3": lvl(ad, 3) + lvl(ir, 3) + interior + sign + signtext[3] + mast,
                "L4": lvl(ad, 4) + lvl(ir, 4) + interior + sign + signtext[4] + mast,
                "L5": lvl(ad, 5) + lvl(ir, 5) + interior + sign + signtext[5]}
        assert all(comp.values()), {k: len(v) for k, v in comp.items()}
        door_y = {"L1": -11.3, "L2": -11.3, "L3": -21.1, "L4": -21.1, "L5": -21.1}  # front face of the door bay
        stuff = ([o for v in objs.values() for o in v] + sign + mast + interior + ribbons[1] + ribbons[2]
                 + [o for v in signtext.values() for o in v])

        # daylight: blue sky + warm sun from the front-right, grass ground, Lego-bright Standard view
        template.set_eevee(scene, 16)
        try:
            scene.view_settings.view_transform = "Standard"
        except TypeError:
            pass
        world = bpy.data.worlds.new("WLD_LINEUP")
        world.use_nodes = True
        bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
        bg.inputs["Color"].default_value = (0.42, 0.62, 0.95, 1.0)
        bg.inputs["Strength"].default_value = 0.9
        scene.world = world
        sun = bpy.data.objects.new("LINEUP_Sun", bpy.data.lights.new("LINEUP_Sun", "SUN"))
        sun.data.energy, sun.data.color, sun.data.angle = 3.2, (1.0, 0.96, 0.88), math.radians(2)
        sun.rotation_euler = (math.radians(50), 0, math.radians(32))
        scene.collection.objects.link(sun)
        bpy.ops.mesh.primitive_plane_add(size=1200, location=(0, 0, -0.01))
        ground = bpy.context.active_object
        ground.name = "LINEUP_Ground"
        ground.data.materials.append(template.material("MI_LINEUP_Ground", rgb=(0.30, 0.52, 0.22), roughness=0.9))
        cam = bpy.data.objects.new("LINEUP_Cam", bpy.data.cameras.new("LINEUP_Cam"))
        cam.data.sensor_fit, cam.data.clip_start, cam.data.clip_end = "VERTICAL", 0.1, 2000
        scene.collection.objects.link(cam)
        scene.camera = cam
        os.makedirs(OUT, exist_ok=True)

        def aim(eye, look, fov, size):
            cam.data.angle_y = math.radians(fov)  # Roblox FieldOfView is vertical
            cam.matrix_world = template.look_matrix((Vector(look) - Vector(eye)).normalized(), location=Vector(eye))
            scene.render.resolution_x, scene.render.resolution_y = size

        def shot(name, level, eye, look, fov=70, size=(1600, 900)):
            keep = set(comp[level])
            for o in stuff:
                o.hide_render = o not in keep
            aim(eye, look, fov, size)
            scene.render.filepath = os.path.join(OUT, name + ".png")
            bpy.ops.render.render(write_still=True)

        def corners(level):
            # every visible part's box corners (tighter than one level-wide AABB) and the level's centre
            pts = [o.matrix_world @ Vector(c) for o in comp[level] if o.type in ("MESH", "FONT") for c in o.bound_box]
            lo = Vector([min(p[i] for p in pts) for i in range(3)])
            hi = Vector([max(p[i] for p in pts) for i in range(3)])
            return pts, (lo + hi) / 2

        def fit(level, place, d0, fov, size, m=0.08):
            # smallest distance d >= d0 at which every part's box corner sits inside the frame with margin m;
            # then shift the look point to centre the projected parts and refit (3 passes)
            pts, c = corners(level)
            tv = math.tan(math.radians(fov) / 2)
            for _ in range(3):
                d = d0
                while True:
                    assert d < 600, "no fit for " + level
                    aim(*place(d, c), fov, size)
                    uv = [world_to_camera_view(scene, cam, p) for p in pts]
                    if all(m <= v.x <= 1 - m and m <= v.y <= 1 - m and v.z > 0 for v in uv):
                        break
                    d += 0.5
                eye, look = place(d, c)
                depth = (Vector(look) - Vector(eye)).length
                du = (min(v.x for v in uv) + max(v.x for v in uv)) / 2 - 0.5
                dv = (min(v.y for v in uv) + max(v.y for v in uv)) / 2 - 0.5
                mw = cam.matrix_world
                c = c + mw.col[0].xyz * (du * 2 * depth * tv * size[0] / size[1]) + mw.col[1].xyz * (dv * 2 * depth * tv)
            return place(d, c)

        a = math.radians(40)
        gdir = Vector((45 * math.sin(a), -45 * math.cos(a), 13)).normalized()  # r1's front-right 3/4 direction
        for l in LEVELS:
            dy = door_y[l]
            # path: on the path line in front of the door, eye 6, d >= 60, turned toward the level
            shot("path_" + l, l, *fit(l, lambda d, c: ((0, dy - d, 6), (c.x, dy, c.z)), 60, 70, (1600, 900)))
            # game: 3rd-person front-right 3/4, looking at the level's framed centre
            shot("game_" + l, l, *fit(l, lambda d, c: (c + gdir * d, c), 20, 70, (960, 540)), size=(960, 540))
        shot("close_door_L1", "L1", (3, -27, 4.5), (0, -10, 5.5), fov=45)
        shot("close_door_L3", "L3", (4, -40, 6), (0, -20, 9), fov=45)
        shot("close_windows_L3", "L3", (-6, -38, 8), (-15, -15, 7), fov=40)
        shot("close_roof_L3", "L3", (-38, -42, 34), (-12, -4, 21), fov=40)
        shot("close_L4_mast_dish", "L4", (46, -30, 22), (36, 3, 25), fov=50)
        shot("close_L5_lantern", "L5", (44, -24, 40), (55, 3, 44), fov=45)
        shot("close_L2_front", "L2", (6, -42, 10), (2, -9, 15), fov=50)
    finally:
        bpy.context.window.scene = prev
        bpy.data.scenes.remove(scene)
        for coll, old in zip((bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images,
                              bpy.data.cameras, bpy.data.lights, bpy.data.worlds, bpy.data.curves,
                              bpy.data.fonts), before):
            for d in [d for d in coll if d not in old]:
                coll.remove(d)
    subprocess.run(["/usr/bin/python3", os.path.abspath(__file__), TAG, ROOT, "--sheet"], check=True)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet()
    else:
        render_all()
