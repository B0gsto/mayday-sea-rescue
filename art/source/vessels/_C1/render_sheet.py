"""C1 review renders (Blender EEVEE, overcast-sea HDRI) and the contact sheet (system python3):

    ~/RobloxProjects/tools/with-heavy.sh -- ~/RobloxProjects/tools/blender-run.sh art/source/vessels/_C1/render_sheet.py
    python3 art/source/vessels/_C1/render_sheet.py --sheet      # -> assets/review/C1/contact.png

The Optimist (dry, wet, on the sea with the outboard and the trailing rope), the sit-on-top kayak and the SUP dry / wet /
capsized, plus close-ups at hero distance. LOD0 only, PBR maps from assets/textures, sea = stand-in plane at the waterline.
"""
import math
import os
import sys

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/review/C1/renders/"
SHEET = G + "assets/review/C1/contact.png"
S = 3.0
WLS = {"M_Veh_Optimist": 0.62, "M_Veh_Kayak": 0.10, "M_Veh_Paddleboard": 0.25}
# (asset, shot, pose, wet, water, target m, distance m, azimuth deg (0 = from -Y, the bow; 90 = from +X, port), elevation, lens)
SHOTS = [
    ("M_Veh_Optimist", "bow34_dry", "upright", False, False, (0, -0.6, 1.5), 11, 35, 14, 40),
    ("M_Veh_Optimist", "bow34_wet", "upright", True, False, (0, -0.6, 1.5), 11, 35, 14, 40),
    ("M_Veh_Optimist", "stern34_sea_dry", "upright", False, True, (0, 1.2, 1.1), 9.5, 215, 18, 40),
    ("M_Veh_Optimist", "port_sea_wet", "upright", True, True, (0, 0, 1.3), 11, 100, 8, 40),
    ("M_Veh_Optimist", "closeup_foredeck_samson_cleats_pulpit", "upright", False, False, (0, -2.6, 1.7), 2.8, 25, 38, 40),
    ("M_Veh_Optimist", "closeup_outboard_rust_rope", "upright", False, False, (0, 3.35, 0.8), 2.4, 140, 12, 40),
    ("M_Veh_Optimist", "closeup_bow_waterline_pln", "upright", False, False, (1.0, -2.0, 0.9), 3.0, 80, 6, 40),
    ("M_Veh_Kayak", "kayak34_dry", "upright", False, False, (0, 0, 0.2), 4.6, 40, 25, 40),
    ("M_Veh_Kayak", "kayak34_sea_wet", "upright", True, True, (0, 0, 0.2), 4.6, 220, 22, 40),
    ("M_Veh_Kayak", "kayak_capsized_sea_wet", "capsized", True, True, (0, 0, 0.1), 4.6, 60, 25, 40),
    ("M_Veh_Kayak", "closeup_kayak_seat_paddle", "upright", False, False, (0.05, 0.3, 0.25), 1.6, 165, 40, 40),
    ("M_Veh_Paddleboard", "sup34_dry", "upright", False, False, (0, 0, 0.3), 4.3, 35, 28, 40),
    ("M_Veh_Paddleboard", "sup34_sea_wet", "upright", True, True, (0, 0, 0.3), 4.3, 215, 25, 40),
    ("M_Veh_Paddleboard", "sup_capsized_sea_wet", "capsized", True, True, (0, 0, 0.3), 4.3, 70, 30, 40),
    ("M_Veh_Paddleboard", "closeup_sup_tail_leash_pad", "upright", False, False, (0.05, 1.2, 0.4), 1.5, 150, 45, 40),
]


def blender_main():
    import bpy
    from mathutils import Matrix, Vector
    sys.path.insert(0, G + "tools/blender")
    import template
    import turntable
    os.makedirs(OUT, exist_ok=True)
    by_asset = {}
    for s in SHOTS:
        by_asset.setdefault(s[0], []).append(s)
    for asset, shots in by_asset.items():
        bpy.ops.wm.open_mainfile(filepath=G + "art/source/vessels/%s/%s.blend" % (asset, asset))
        sc = bpy.context.scene
        vis = []
        for o in sc.objects:
            hide = o.name.startswith("TPL_") or o.name.endswith(("_LOD1", "_LOD2", "_COL")) or o.type == "LIGHT"
            o.hide_render = hide
            if o.type == "MESH" and not hide:
                vis.append(o)
        tex = G + "assets/textures/" + asset + "/"
        cache = {}

        def mat_for(stem, wet):
            key = (stem, wet)
            if key not in cache:
                sfx = "_Wet" if wet else ""
                nor = tex + "%s_NOR%s.png" % (stem, sfx)
                nor = nor if os.path.exists(nor) else tex + "%s_NOR.png" % stem
                maps = {"ALB": tex + "%s_ALB%s.png" % (stem, sfx), "NOR": nor,
                        "RGH": tex + "%s_RGH%s.png" % (stem, sfx), "MET": tex + "%s_MET.png" % stem}
                m = turntable.pbr_material("MI_C1_%s%s" % (stem, sfx), maps)
                if stem.endswith("Decals"):
                    nt = m.node_tree
                    alb = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and "ALB" in n.image.name)
                    nt.links.new(alb.outputs["Alpha"], nt.nodes["Principled BSDF"].inputs["Alpha"])
                cache[key] = m
            return cache[key]
        orig = {o.name: o.data.materials[0].name for o in vis}

        def stem_of(mn):
            # MI_<asset>_<Name>_<Set> -> T_<Name>_<Set>
            parts = mn.split("_")
            return "T_%s_%s" % (parts[-2], parts[-1])
        rig = bpy.data.objects.new("C1_Rig", None)
        sc.collection.objects.link(rig)
        for o in vis:
            o.parent = rig
        bpy.ops.mesh.primitive_plane_add(size=4000.0, location=(0, 0, 0))
        sea = bpy.context.active_object
        sea.name = "C1_SeaStandIn"
        sm = bpy.data.materials.new("MI_C1_Sea")
        sm.use_nodes = True
        bs = sm.node_tree.nodes["Principled BSDF"]
        bs.inputs["Base Color"].default_value = (0.012, 0.035, 0.040, 1)
        bs.inputs["Roughness"].default_value = 0.12
        sea.data.materials.append(sm)
        template.set_world(template.OVERCAST)
        cam_d = bpy.data.cameras.new("C1_Cam")
        cam = bpy.data.objects.new("C1_Cam", cam_d)
        sc.collection.objects.link(cam)
        sc.camera = cam
        sc.render.resolution_x = sc.render.resolution_y = 768
        sc.render.film_transparent = False
        for (_, shot, pose, wet, water, tgt, dist, az, el, lens) in shots:
            for o in vis:
                o.data.materials[0] = mat_for(stem_of(orig[o.name]), wet)
                # C2b state parts: Damage only when she lies over / is turned turtle, Undamaged only upright
                o.hide_render = ("_Damage_" in o.name and pose != "capsized") or ("_Undamaged_" in o.name and pose in ("capsized", "turtle"))
            wl = WLS[asset]
            if pose == "upright":
                rig.matrix_world = Matrix.Identity(4)
                sea_z = wl
            else:     # capsized: rolled 180 deg about the length axis, floating on its deck
                hgt = {"M_Veh_Kayak": 0.46, "M_Veh_Paddleboard": 0.40}.get(asset, 1.0)
                rig.matrix_world = Matrix.Translation((0, 0, hgt * S)) @ Matrix.Rotation(math.radians(180), 4, "Y")
                sea_z = hgt - (0.18 if asset == "M_Veh_Kayak" else 0.27)
            sea.location.z = sea_z * S
            sea.hide_render = not water
            t = Vector(tgt) * S
            a, e = math.radians(az), math.radians(el)
            pos = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist * S
            cam.matrix_world = template.look_matrix(tuple(t - pos), location=tuple(pos))
            cam_d.lens = lens
            cam_d.clip_start, cam_d.clip_end = 0.05, 5000
            sc.render.filepath = OUT + "%s__%s.png" % (asset, shot)
            bpy.ops.render.render(write_still=True)
            print("[C1] rendered", sc.render.filepath)


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    cell, cols = 400, 4
    rows = math.ceil(len(SHOTS) / cols)
    head = 40
    im = Image.new("RGB", (cell * cols, head + rows * (cell + 24)), (28, 30, 32))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)
    d.text((10, 10), "C1: The Optimist (7 m GRP inshore boat, Op 2 casualty), sit-on-top kayak 3.47 m, inflatable SUP 3.2 m "
                     "(Op 1 context). Dry / wet / capsized; overcast-sea HDRI, EEVEE, LOD0; sea = stand-in plane",
           fill=(230, 230, 230), font=f)
    for i, (asset, shot, *_r) in enumerate(SHOTS):
        x, y = (i % cols) * cell, head + (i // cols) * (cell + 24)
        p = OUT + "%s__%s.png" % (asset, shot)
        if os.path.exists(p):
            im.paste(Image.open(p).convert("RGB").resize((cell, cell), Image.LANCZOS), (x, y + 24))
        d.text((x + 6, y + 4), "%s  %s" % (asset.replace("M_Veh_", ""), shot), fill=(240, 240, 200), font=f)
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    im.save(SHEET)
    print("sheet", SHEET, im.size)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet()
    else:
        blender_main()
