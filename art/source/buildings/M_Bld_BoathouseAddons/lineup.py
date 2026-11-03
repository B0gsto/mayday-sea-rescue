"""Boathouse L1-L3 lineup (path view, game view, phone strip, close-ups) of the exported LOD0 FBX + a contact sheet.
Live Blender MCP session (temporary scene "BH_LINEUP", deleted afterwards):
    import sys, runpy; sys.argv = ["lineup.py", "r1"]; runpy.run_path(W + "/art/source/buildings/M_Bld_BoathouseAddons/lineup.py", run_name="__main__")
Sheet alone (system python3 + Pillow): python3 lineup.py r1 --sheet
L1 = Lv1, L2 = Lv1 + Lv2, L3 = Lv1 + Lv2 + Lv3, plus stand-ins for the code Parts that stay: plinths, name signs, the
slipway, the walk and the plate/cove. Path view = the plaza centre (right 5, fwd 16), looking across at the door. Blender +X = in-game -X.
"""
import math
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.abspath(os.path.join(HERE, "../../../.."))
H = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/build/status/2026-11-01/perfect/buildings/Boathouse"
args = [a for a in sys.argv[1:] if a != "--sheet"]
TAG = args[0] if args else "r1"
OUT = os.path.join(H, TAG)
LEVELS = ("L1", "L2", "L3")
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
CLOSE = ("close_door_L1", "close_gable_L1", "close_side_L1", "close_bay_L2", "close_columns_L3", "close_launch_L3")


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
    scene = bpy.data.scenes.new("BH_LINEUP")
    bpy.context.window.scene = scene
    colls = (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras,
             bpy.data.lights, bpy.data.worlds, bpy.data.curves, bpy.data.fonts)
    before = [set(c) for c in colls]
    try:
        A = "M_Bld_BoathouseAddons"
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


        font = bpy.data.fonts.load("/System/Library/Fonts/Supplemental/Arial Black.ttf", check_existing=True)   # closest to FredokaOne

        def sign(tag, text, sx, sy, sz, hw, hh, th, icon_rgb, kw):       # a code sign: white, facing -Y, icon on the left
            o = [box("Sign" + tag, (sx - hw, sy - th, sz - hh), (sx + hw, sy + th, sz + hh), (0.89, 0.87, 0.81))]
            cu = bpy.data.curves.new("LINEUP_SignText" + tag, "FONT")
            cu.body, cu.font, cu.extrude, cu.align_x, cu.align_y = text, font, 0.02, "CENTER", "CENTER"
            t = bpy.data.objects.new("LINEUP_SignText" + tag, cu)
            scene.collection.objects.link(t)
            t.data.materials.append(template.material("MI_LINEUP_Ink" + tag, rgb=(0.02, 0.03, 0.06), roughness=0.9))
            t.rotation_euler = (math.radians(90), 0, 0)
            bpy.context.view_layer.update()
            k = min(kw * hw * 2 / t.dimensions.x, 1.45 * hh / t.dimensions.y)
            t.scale = (k, k, 1)
            t.location = (sx + hh * 0.72, sy - th - 0.03, sz - 0.34 * hh)
            bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=hh * 0.72, depth=0.06, location=(sx - hw + hh * 1.02, sy - th - 0.03, sz),
                                                rotation=(math.radians(90), 0, 0))
            i = bpy.context.active_object
            i.name = "LINEUP_SignIcon" + tag
            i.data.materials.append(template.material("MI_LINEUP_Icon" + tag, rgb=icon_rgb, roughness=0.9))
            # stand-in for the sign's real ImageLabel icon (UiImages.Kit.lifebuoy / boat_to_me): a life ring, not a blank disc
            ix, iy, ir = sx - hw + hh * 1.02, sy - th - 0.09, hh * 0.72
            bpy.ops.mesh.primitive_torus_add(major_radius=ir * 0.60, minor_radius=ir * 0.32, major_segments=24, minor_segments=8,
                                             location=(ix, iy, sz), rotation=(math.radians(90), 0, 0))
            g = bpy.context.active_object
            g.name = "LINEUP_SignRing" + tag
            g.scale.z = 0.25
            g.data.materials.append(template.material("MI_LINEUP_Ring" + tag, rgb=(0.95, 0.95, 0.93), roughness=0.9))
            bands = []
            for a in (45, 135, 225, 315):                                # the ring's four red bands
                bx, bz = ir * 0.60 * math.cos(math.radians(a)), ir * 0.60 * math.sin(math.radians(a))
                band = box("SignBand%s%d" % (tag, a), (ix + bx - ir * 0.24, iy - 0.14, sz + bz - ir * 0.24),
                           (ix + bx + ir * 0.24, iy + 0.02, sz + bz + ir * 0.24), (0.80, 0.05, 0.04))
                bands.append(band)
            return o + [t, i, g] + bands

        tan, dbg = (0.66, 0.48, 0.24), (0.12, 0.11, 0.12)
        base = [box("Plate", (-300, -35, -6), (125, 300, 0), (0.30, 0.52, 0.22)),                  # the plate, the cove's quay at y -35
                box("PlazaWing", (-300, -300, -6), (-28, -35, 0), (0.30, 0.52, 0.22)),             # the plaza end of the cove
                box("Sea", (-280, -300, -8), (500, 300, -4), (0.08, 0.32, 0.62)),
                box("Plinth", (-19.8, -23.4, 0), (19.8, 23.4, 0.48), (0.64, 0.64, 0.65)),
                box("Stub", (-4, -24, 0.10), (4, -18, 0.40), tan), box("Walk", (-28, -32, 0.12), (92, -24, 0.42), tan)]
        main = sign("1", "Boathouse", 0.0, -23.34, 18.0, 9.30, 1.86, 0.24, (0.87, 0.30, 0.05), 0.70)
        slip = [box("SlipPlinth", (29, -12, 0), (79, 12, 0.8), (0.64, 0.64, 0.65)),
                box("Slipway", (77, -3.5, 0), (103, 3.5, 0.6), tan)]
        for y in (-2.6, 2.6):
            slip.append(box("SlipRail%d" % y, (77, y - 0.3, 0.6), (103, y + 0.3, 1.2), dbg))
        slip += sign("2", "Lifeboat", 61.0, -20.85, 16.40, 11.00, 2.40, 0.20, (0.75, 0.04, 0.03), 0.66)
        slip += sign("3", "Lifeboat", 0.0, 0.0, 13.40, 4.95, 0.90, 0.20, (0.75, 0.04, 0.03), 0.66)   # sea end, faces +X below
        for o in slip[-8:]:                                              # turn the sea-end sign round to face +X, at x 80.25
            o.location = (80.25 + o.location.y, o.location.x, o.location.z)
            o.rotation_euler.z += math.pi / 2
        launch = sign("4", "Launch", 52.5, -45.60, 10.20, 7.00, 1.55, 0.20, (0.75, 0.04, 0.03), 0.66)
        code = base + main
        code2 = slip

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
                if n <= i + 1 and not (l == "L3" and base == "Lv2_L05_LaneWet"):   # DockPieces.boathouseLevel drops it at Lv3
                    comp[l].append(o)
        for l in LEVELS:
            comp[l] += code + (code2 if l != "L1" else []) + (launch if l == "L3" else [])
        stuff = [o for o in imported if o.type == "MESH"] + code + code2 + launch

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
        sun.rotation_euler = (math.radians(50), 0, math.radians(-28))    # lights the door and the plaza side
        scene.collection.objects.link(sun)
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
            shot("path_" + l, l, (-42, -85, 22), (11.5, -25.5, 11), fov=37)    # from the plaza centre, across the cove
            shot("game_" + l, l, (-32, -92, 46), (20, -12, 6), fov=42, size=(960, 540))
        shot("close_door_L1", "L1", (-10, -56, 9), (0, -22, 9), fov=46)
        shot("close_gable_L1", "L1", (-8, -50, 24), (0, -23, 20), fov=42)
        shot("close_side_L1", "L1", (-54, -26, 14), (-18, -4, 10), fov=46)
        shot("close_bay_L2", "L2", (46, -56, 13), (61, -18, 11), fov=46)
        shot("close_columns_L3", "L3", (26, -72, 12), (51, -40, 8), fov=46)
        shot("close_launch_L3", "L3", (2, -70, 13), (24, -41, 3), fov=46)
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
