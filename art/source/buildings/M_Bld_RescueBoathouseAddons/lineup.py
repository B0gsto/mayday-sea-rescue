"""Rescue Boathouse L1-L3 lineup (path view, game view, phone strip, close-ups) of the exported LOD0 FBX + a contact sheet.
Live Blender MCP session (temporary scene "RB_LINEUP", deleted afterwards):
    import sys, runpy; sys.argv = ["lineup.py", "r1"]; runpy.run_path(W + "/art/source/buildings/M_Bld_RescueBoathouseAddons/lineup.py", run_name="__main__")
Sheet alone (system python3 + Pillow): python3 lineup.py r1 --sheet
L1 = Lv1, L2 = Lv1 (no L07) + Lv2, L3 = Lv1 (no L07, L08, L09) + Lv2 + Lv3, plus stand-ins for the code Parts that stay:
the plinth and the white "Rescue Boathouse" name sign (on the portal header at every level). Blender +X = in-game -X.
"""
import math
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.abspath(os.path.join(HERE, "../../../.."))
H = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/build/status/2026-11-01/perfect/buildings/RescueBoathouse"
args = [a for a in sys.argv[1:] if a != "--sheet"]
TAG = args[0] if args else "r1"
OUT = os.path.join(H, TAG)
LEVELS = ("L1", "L2", "L3")
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
CLOSE = ("close_door_L1", "close_flank_L1", "close_roof_L1", "close_bay_L2", "close_tower_L3", "close_boat_L3")


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype(FONT, 28)
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
    strip = Image.new("RGB", (320 * 3 + 2 * 4, 180), (24, 26, 30))
    for i, p in enumerate(phones):
        strip.paste(p, (i * 324, 0))
    strip.save(os.path.join(OUT, "phone_strip.png"))
    rows = [row(["path_" + l for l in LEVELS], ["path " + l for l in LEVELS], 3),
            row(["game_" + l for l in LEVELS], ["game " + l for l in LEVELS], 3),
            ([tile(os.path.join(OUT, "phone_strip.png"), strip.width, "phone 320x180  L1  L2  L3")], 1),
            row(CLOSE[:3], CLOSE[:3], 3), row(CLOSE[3:], CLOSE[3:], 3)]
    heights = [max(t.height for t in ts) for ts, _ in rows]
    out = Image.new("RGB", (SW, sum(heights) + PAD * (len(rows) + 1)), (24, 26, 30))
    y = PAD
    for (ts, per), h in zip(rows, heights):
        w = (SW - PAD * (per + 1)) // per
        for i, t in enumerate(ts):
            out.paste(t, (PAD + i * (w + PAD), y))
        y += h + PAD
    dst = os.path.join(H, TAG + "_sheet.png")
    out.save(dst)
    subprocess.run(["sips", "-Z", "1600", dst, "--out", os.path.join(H, TAG + "_sheet_small.png")], check=True,
                   capture_output=True)
    print("[lineup] sheet", dst)


def render_all():
    import bpy
    from mathutils import Vector
    sys.path.insert(0, os.path.join(W, "tools/blender"))
    import template
    prev = bpy.context.window.scene
    scene = bpy.data.scenes.new("RB_LINEUP")
    bpy.context.window.scene = scene
    colls = (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras,
             bpy.data.lights, bpy.data.worlds, bpy.data.curves, bpy.data.fonts)
    before = [set(c) for c in colls]
    try:
        A = "M_Bld_RescueBoathouseAddons"
        tex = os.path.join(W, "build/prod", A, "textures", A)
        old = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(W, "build/prod", A, "fbx", A, A + "_LOD0.fbx"))
        imported = [o for o in bpy.data.objects if o not in old]
        for o in imported:
            for s in o.material_slots:
                for n in (s.material.node_tree.nodes if s.material and s.material.use_nodes else ()):
                    if n.type == "TEX_IMAGE" and n.image and not os.path.isfile(bpy.path.abspath(n.image.filepath)):
                        n.image.filepath = os.path.join(tex, os.path.basename(n.image.filepath))
                        n.image.reload()

        def box(name, lo, hi, rgb):
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=[(a + b) / 2 for a, b in zip(lo, hi)])
            o = bpy.context.active_object
            o.name, o.scale = "LINEUP_" + name, [b - a for a, b in zip(lo, hi)]
            o.data.materials.append(template.material("MI_LINEUP_" + name, rgb=rgb, roughness=0.9))
            return o


        plinth = box("Plinth", (-23.725, -19.725, 0), (23.725, 19.725, 0.92), (0.64, 0.64, 0.65))
        stub = box("Path", (-4.6, -120, 0), (4.6, -19.78, 0.42), (0.72, 0.60, 0.40))     # the code tan stub path to the gate
        font = bpy.data.fonts.load("/System/Library/Fonts/Supplemental/Arial Black.ttf", check_existing=True)   # closest to FredokaOne

        def sign(tag, sx, sy, sz):                         # the code name sign: 16.56 x 0.46 x 5.0, red, facing -Y
            o = [box("Sign" + tag, (sx - 8.28, sy - 0.23, sz - 2.50), (sx + 8.28, sy + 0.23, sz + 2.50), (0.745, 0.04, 0.021))]
            cu = bpy.data.curves.new("LINEUP_SignText" + tag, "FONT")
            cu.body, cu.font, cu.extrude, cu.align_x, cu.align_y = "Rescue\nBoathouse", font, 0.02, "CENTER", "CENTER"
            cu.offset = 0.012                              # the code's UIStroke
            t = bpy.data.objects.new("LINEUP_SignText" + tag, cu)
            scene.collection.objects.link(t)
            t.data.materials.append(template.material("MI_LINEUP_Ink", rgb=(0.95, 0.95, 0.93), roughness=0.9))
            t.rotation_euler = (math.radians(90), 0, 0)
            bpy.context.view_layer.update()
            k = min(11.0 / t.dimensions.x, 3.60 / t.dimensions.y)
            t.scale = (k, k, 1)
            t.location = (sx + 2.00, sy - 0.26, sz - 0.40)
            return o + [t]                                 # the code icon sits under the mesh's life ring
        s1 = sign("1", 0.0, -17.77, 12.8225)
        code = [plinth, stub] + s1

        def lv(o):
            base = re.sub(r"\.\d{3}$", "", o.name)
            if o.type != "MESH" or base.endswith("_COL"):
                return None
            m = re.match(r"Lv(\d)_", base)
            return (int(m.group(1)), base) if m else None
        comp = {"L1": [], "L2": [], "L3": []}
        for o in imported:
            r = lv(o)
            if not r:
                continue
            n, base = r
            for i, l in enumerate(LEVELS):
                if n <= i + 1 and not ((i >= 1 and base.startswith("Lv1_L07_")) or (i >= 2 and base.startswith(("Lv1_L08_", "Lv1_L09_")))):
                    comp[l].append(o)
        for l in LEVELS:
            comp[l] += code
        stuff = [o for o in imported if o.type == "MESH"] + code

        try:
            scene.render.engine = "BLENDER_EEVEE_NEXT"
        except TypeError:
            scene.render.engine = "BLENDER_EEVEE"
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
        ground.data.materials.append(template.material("MI_LINEUP_Ground", rgb=(0.30, 0.52, 0.22), roughness=0.9))
        cam = bpy.data.objects.new("LINEUP_Cam", bpy.data.cameras.new("LINEUP_Cam"))
        cam.data.sensor_fit, cam.data.clip_start, cam.data.clip_end = "VERTICAL", 0.1, 2000
        scene.collection.objects.link(cam)
        scene.camera = cam
        os.makedirs(OUT, exist_ok=True)

        def shot(name, level, eye, look, fov=70, size=(1600, 900)):
            keep = set(comp[level])
            for o in stuff:
                o.hide_render = o not in keep
            cam.data.angle_y = math.radians(fov)
            cam.matrix_world = template.look_matrix((Vector(look) - Vector(eye)).normalized(), location=Vector(eye))
            scene.render.resolution_x, scene.render.resolution_y = size
            scene.render.filepath = os.path.join(OUT, name + ".png")
            bpy.ops.render.render(write_still=True)

        for l in LEVELS:
            shot("path_" + l, l, (0, -80, 13), (0, 0, 15), fov=37)            # on the path, ~60 studs from the gate
            shot("game_" + l, l, (36, -50, 34), (3, 2, 13), fov=46, size=(960, 540))
        shot("close_door_L1", "L1", (4, -42, 11), (0, -17, 8.5), fov=46)
        shot("close_flank_L1", "L1", (44, -30, 13), (22, -6, 8), fov=46)
        shot("close_roof_L1", "L1", (26, -32, 28), (6, -8, 16), fov=44)
        shot("close_bay_L2", "L2", (24, -50, 15), (16, -12, 11.5), fov=46)
        shot("close_tower_L3", "L3", (-2, -58, 24), (-16, -14, 15), fov=46)
        shot("close_boat_L3", "L3", (-5, -36, 8.5), (-17, -4, 5), fov=46)
    finally:
        bpy.context.window.scene = prev
        bpy.data.scenes.remove(scene)
        for coll, old in zip(colls, before):
            for d in [d for d in coll if d not in old]:
                coll.remove(d)
    subprocess.run(["/usr/bin/python3", os.path.abspath(__file__), TAG, "--sheet"], check=True)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet()
    else:
        render_all()
