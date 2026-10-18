"""S1a review renders (Blender, EEVEE): dim blue-green underwater rig (sun + sky fill + volume haze, 7 m) and one
neutral studio HDRI shot per asset, close-ups at diver distance. Then system python3 makes the contact sheet:

    ~/RobloxProjects/tools/blender-run.sh art/source/seabed/_S1a/render_sheet.py
    python3 art/source/seabed/_S1a/render_sheet.py --sheet
"""
import math
import os
import sys

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/review/POL2/renders/"       # POL2 polish (bell lettering, anchor sand); S1a rounds stay in S1a/renders*/
SHEET = G + "assets/review/POL2/contact.png"
TERRAIN = {"M_Sea_Morwenna": "assets/fbx/M_Sea_Morwenna/M_Sea_Morwenna.instances.json",
           "M_Sea_AdmiraltyAnchor": "assets/fbx/M_Sea_AdmiraltyAnchor/M_Sea_AdmiraltyAnchor.placement.json"}
SHOTS = [  # (asset, shot, rig, target (m from base centre), distance m, azimuth deg, elevation deg, lens)
    ("M_Sea_Bell", "neutral_lettering_front", "neutral", (0.0, 0.0, 0.14), 0.75, 0, 6, 50),
    ("M_Sea_Bell", "neutral_lettering_30deg", "neutral", (0.0, 0.0, 0.14), 0.75, 30, 12, 50),
    ("M_Sea_Bell", "uw_lettering", "uw", (0.0, 0.0, 0.14), 0.75, -12, 8, 50),
    ("M_Sea_Bell", "neutral_closeup_relief", "neutral", (0.0, -0.1, 0.14), 0.32, -25, 4, 50),
    ("M_Sea_Bell", "uw_mouth_clapper", "uw", (0.0, 0.0, 0.13), 0.8, 28, 14, 50),
    ("M_Sea_AdmiraltyAnchor", "neutral_threequarter", "neutral", (0.0, 0.0, 0.7), 6.0, 220, 25, 35),
    ("M_Sea_AdmiraltyAnchor", "neutral_sand_edge", "neutral", (1.4, 0.6, 0.0), 2.6, 150, 40, 35),
    ("M_Sea_AdmiraltyAnchor", "neutral_high", "neutral", (0.0, 0.0, 0.3), 7.5, 30, 70, 35),
    ("M_Sea_AdmiraltyAnchor", "uw_threequarter", "uw", (0.0, 0.0, 0.7), 6.0, 40, 25, 35),
]


def blender_main():
    import bpy
    from mathutils import Matrix, Vector
    sys.path.insert(0, G + "tools/blender")
    import common
    import template
    import turntable
    os.makedirs(OUT, exist_ok=True)
    by_asset = {}
    for s in SHOTS:
        by_asset.setdefault(s[0], []).append(s)
    for asset, shots in by_asset.items():
        bpy.ops.wm.open_mainfile(filepath=G + "art/source/seabed/%s/%s.blend" % (asset, asset))
        sc = bpy.context.scene
        for o in sc.objects:
            hide = o.name.startswith("TPL_") or o.name.endswith(("_LOD1", "_LOD2", "_COL")) or o.type in ("LIGHT",)
            o.hide_render = hide
        tex = G + "assets/textures/" + asset + "/"
        mats = {}

        def mat_for(stem, d):
            if stem not in mats:
                maps = {k: d + "%s_%s.png" % (stem, k) for k in ("ALB", "NOR", "RGH", "MET")}
                m = turntable.pbr_material("MI_S1a_" + stem, maps)
                nt = m.node_tree
                if stem.endswith(("Kelp", "AdmiraltyAnchor_Sand")):
                    alb = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and "ALB" in n.image.name)
                    nt.links.new(alb.outputs["Alpha"], nt.nodes["Principled BSDF"].inputs["Alpha"])
                mats[stem] = m
            return mats[stem]
        for o in sc.objects:
            if o.type != "MESH" or not o.data.materials:
                continue
            mn = o.data.materials[0].name if o.data.materials[0] else ""
            stem = None
            for st in ("Wood", "Metal", "Silt", "Kelp", "Encrust"):
                if mn.endswith("Morwenna_" + st):
                    stem = ("T_Morwenna_" + st, G + "assets/textures/M_Sea_Morwenna/")
            for st in ("Iron", "Sand"):
                if mn.endswith("AdmiraltyAnchor_" + st):
                    stem = ("T_AdmiraltyAnchor_" + st, tex)
            if stem:
                o.data.materials[0] = mat_for(*stem)
        if asset == "M_Sea_Morwenna":      # lay the bell at ATT_Bell for the review (integration does this in Studio)
            with bpy.data.libraries.load(G + "art/source/seabed/M_Sea_Bell/M_Sea_Bell.blend") as (src, dst):
                dst.objects = ["M_Sea_Bell_LOD0"]
            bell = dst.objects[0]
            sc.collection.objects.link(bell)
            bell.data.materials[0] = mat_for("T_Morwenna_Metal", G + "assets/textures/M_Sea_Morwenna/")
            att = sc.objects["ATT_Bell"]
            bell.matrix_world = Matrix.Translation(att.matrix_world.translation + Vector((0, 0, 0.35))) @ Matrix.Rotation(math.radians(100), 4, "X") @ Matrix.Rotation(math.radians(30), 4, "Z")
            bell.hide_render = False
        # stand-in for the game's seabed terrain (Sand): a 600 m plane at the asset's terrain level, Silt set, so
        # the scour / sand bed edge is judged where it meets the ground
        tz = 0.0
        if asset in TERRAIN:
            import json
            tz = json.load(open(G + TERRAIN[asset]))["terrain_z_studs_above_base"]
        bpy.ops.mesh.primitive_plane_add(size=1800.0, location=(0, 0, tz))
        ground = bpy.context.active_object
        ground.name = "S1a_TerrainStandIn"
        for lp in ground.data.uv_layers[0].data:
            lp.uv = (lp.uv[0] * 150.0, lp.uv[1] * 150.0)
        ground.data.materials.append(mat_for("T_Morwenna_Silt", G + "assets/textures/M_Sea_Morwenna/"))
        try:
            sc.eevee.volumetric_end = 3000.0
            sc.eevee.volumetric_tile_size = "4"
        except Exception as e:  # noqa: BLE001
            print("[S1a] volumetrics:", e)
        # rigs
        uw = bpy.data.worlds.new("WLD_S1a_Underwater")
        uw.use_nodes = True
        nt = uw.node_tree
        bg = nt.nodes["Background"]
        sky = nt.nodes.new("ShaderNodeTexGradient")
        coord = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        nt.links.new(coord.outputs["Generated"], sep.inputs[0])
        nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
        ramp.color_ramp.elements[0].color = (0.003, 0.016, 0.020, 1)
        ramp.color_ramp.elements[1].color = (0.030, 0.120, 0.125, 1)
        nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 1.6
        # bounded water haze (a world volume would swallow the sun in EEVEE): a cube of scattering water around the set
        vm = bpy.data.materials.new("MI_S1a_Water")
        vm.use_nodes = True
        vnt = vm.node_tree
        for n in list(vnt.nodes):
            if n.type == "BSDF_PRINCIPLED":
                vnt.nodes.remove(n)
        vol = vnt.nodes.new("ShaderNodeVolumePrincipled")
        vol.inputs["Color"].default_value = (0.10, 0.26, 0.25, 1)
        vol.inputs["Density"].default_value = 0.0035
        vol.inputs["Absorption Color"].default_value = (0.45, 0.82, 0.76, 1)    # reds go first: blue-green with depth
        vnt.links.new(vol.outputs["Volume"], vnt.nodes["Material Output"].inputs["Volume"])
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        water = bpy.context.active_object
        water.name = "S1a_WaterHaze"
        water.data.materials.append(vm)
        sun_d = bpy.data.lights.new("S1a_Sun", "SUN")
        sun_d.energy = 2.2
        sun_d.color = (0.62, 0.86, 0.82)
        sun_d.angle = math.radians(12)
        sun = bpy.data.objects.new("S1a_Sun", sun_d)
        sun.rotation_euler = (math.radians(20), math.radians(10), math.radians(30))
        sc.collection.objects.link(sun)
        cam_d = bpy.data.cameras.new("S1a_Cam")
        cam = bpy.data.objects.new("S1a_Cam", cam_d)
        sc.collection.objects.link(cam)
        sc.camera = cam
        sc.render.resolution_x = sc.render.resolution_y = 768
        sc.render.film_transparent = False
        for (_, shot, rig, tgt, dist, az, el, lens) in shots:
            if rig == "uw":
                sc.world = uw
                sun.hide_render = False
                water.hide_render = False
                water.location = Vector(tgt) * 3.0
                water.scale = (max(dist * 3.0 * 2.6, 1500.0),) * 3
                # S1a-fix: depth falloff: about 0.5 optical depth at the camera distance, the far seabed lost in haze
                vol.inputs["Density"].default_value = min(0.05, 0.5 / (dist * 3.0))
                sc.view_settings.exposure = 0.6
            else:
                template.set_world(template.NEUTRAL)
                sun.hide_render = True
                water.hide_render = True
                sc.view_settings.exposure = 0.0
            if asset == "M_Sea_Bell":      # the mouth shot lays the bell on its side, mouth to the camera
                b_ = sc.objects["M_Sea_Bell_LOD0"]
                b_.matrix_world = (Matrix.Translation((0, 0, 0.131 * 3)) @ Matrix.Rotation(math.radians(-90), 4, "X")
                                   @ Matrix.Translation((0, 0, -0.18 * 3))) if "mouth" in shot else Matrix.Identity(4)
            t = Vector(tgt) * 3.0
            a, e = math.radians(az), math.radians(el)
            pos = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist * 3.0
            cam.matrix_world = template.look_matrix(tuple(t - pos), location=tuple(pos))
            cam_d.lens = lens
            cam_d.clip_start, cam_d.clip_end = 0.05, 2000
            sc.render.filepath = OUT + "%s__%s.png" % (asset, shot)
            bpy.ops.render.render(write_still=True)
            print("[S1a] rendered", sc.render.filepath)


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    cell, cols = 512, 3
    rows = math.ceil(len(SHOTS) / cols)
    head = 40
    im = Image.new("RGB", (cell * cols, head + rows * (cell + 24)), (28, 30, 32))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 16)
    fb = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 20)
    d.text((10, 9), "POL2 polish on S1a: bell 0.26 m (cast MORWENNA / 1902, raised), Admiralty anchor sand bed (ripples, faded rim). "
                    "POL2. uw = underwater rig (7 m, blue-green depth falloff), neutral = studio HDRI; ground = terrain stand-in", fill=(230, 230, 230), font=f)
    for i, (asset, shot, *_r) in enumerate(SHOTS):
        x, y = (i % cols) * cell, head + (i // cols) * (cell + 24)
        p = OUT + "%s__%s.png" % (asset, shot)
        if os.path.exists(p):
            im.paste(Image.open(p).convert("RGB").resize((cell, cell), Image.LANCZOS), (x, y + 24))
        d.text((x + 6, y + 2), "%s  %s" % (asset.replace("M_Sea_", ""), shot), fill=(240, 240, 200), font=fb if False else f)
    out = SHEET
    if im.width > 1600:
        im = im.resize((1600, int(im.height * 1600 / im.width)), Image.LANCZOS)
    im.save(out)
    print("sheet", out, im.size)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet()
    else:
        blender_main()
