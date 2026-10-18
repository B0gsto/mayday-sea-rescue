"""C2 review renders (Blender EEVEE, overcast-sea HDRI) and the contact sheet (system python3):

    ~/RobloxProjects/tools/blender-run.sh art/source/vessels/_C2/render_sheet.py
    python3 art/source/vessels/_C2/render_sheet.py --sheet      # -> assets/review/C2/contact.png

Gale Queen upright, lying over at the op's 72 deg roll (RescueService f.tilt) and turned turtle, dry and wet, on a sea
stand-in plane; the liferaft dry and wet; close-ups at hero distance. LOD0 only, PBR maps from assets/textures.
"""
import math
import os
import sys

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/review/C2/renders/"
SHEET = G + "assets/review/C2/contact_b.png"      # C2b fix round (C2 sheet: contact.png)
S = 3.0
# (asset, shot, pose, wet, water, target m (x, y, z in the posed frame), distance m, azimuth deg (0 = from -Y, the bow), elevation, lens)
SHOTS = [
    ("M_Veh_GaleQueen", "upright_bow34_dry", "upright", False, False, (0, -1.0, 3.2), 30, 40, 14, 40),
    ("M_Veh_GaleQueen", "upright_bow34_wet", "upright", True, False, (0, -1.0, 3.2), 30, 40, 14, 40),
    ("M_Veh_GaleQueen", "upright_stern34_sea_dry", "upright", False, True, (0, 1.0, 3.6), 30, 215, 18, 40),
    ("M_Veh_GaleQueen", "capsized72_bottom_dry", "capsized", False, True, (0, 0.0, 1.0), 32, 300, 22, 40),
    ("M_Veh_GaleQueen", "capsized72_bottom_wet", "capsized", True, True, (0, 0.0, 1.0), 32, 250, 16, 40),
    ("M_Veh_GaleQueen", "turtle_dry", "turtle", False, True, (0, 0.0, 1.0), 30, 60, 22, 40),
    ("M_Veh_GaleQueen", "capsized72_deckside_dry", "capsized", False, True, (3.0, -1.0, 2.8), 27, 75, 24, 40),
    ("M_Veh_GaleQueen", "capsized72_deckside_wet", "capsized", True, True, (3.0, -1.0, 2.8), 27, 75, 24, 40),
    ("M_Veh_GaleQueen", "closeup_capsized_damage_rail_raft_window", "capsized", False, True, (3.6, -0.6, 5.0), 9.0, 55, 26, 40),
    ("M_Veh_GaleQueen", "closeup_capsized_bottom_wet_fouling", "capsized", True, True, (-2.0, 3.0, 2.6), 7.0, 285, 18, 40),
    ("M_Veh_GaleQueen", "closeup_bottom_grablines_bilgekeel", "capsized", False, True, (-2.2, 2.0, 2.4), 6.5, 290, 30, 40),
    ("M_Veh_GaleQueen", "closeup_saloon_rafts", "upright", False, False, (2.4, 2.4, 5.2), 6.5, 70, 18, 40),
    ("M_Veh_GaleQueen", "closeup_bow_name_fender", "upright", False, False, (2.8, -7.0, 2.6), 6.0, 60, 6, 40),
    ("M_Veh_GaleQueen", "closeup_aftdeck_grime_scuppers", "upright", False, False, (0.0, 7.6, 3.6), 6.5, 160, 38, 40),
    ("M_Sea_Liferaft", "raft_ramp34_dry", "raft", False, True, (0, -0.4, 0.9), 6.5, 30, 18, 40),
    ("M_Sea_Liferaft", "raft_ladder34_wet", "raft", True, True, (0, 0.4, 0.9), 6.5, 200, 18, 40),
    ("M_Sea_Liferaft", "closeup_raft_entrance", "raft", False, True, (0, -1.4, 0.8), 3.0, 20, 12, 40),
    ("M_Sea_Liferaft", "closeup_raft_ramp_stitching", "raft", False, True, (0, -2.0, 0.35), 1.8, 25, 40, 40),
    ("M_Sea_Liferaft", "closeup_raft_canopy_label_valve", "raft", False, True, (0.6, -0.6, 1.9), 2.6, 40, 22, 40),
    ("M_Sea_Liferaft", "closeup_raft_tubes_wet", "raft", True, True, (0.9, -0.9, 0.7), 2.4, 45, 14, 40),
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
                m = turntable.pbr_material("MI_C2_%s%s" % (stem, sfx), maps)
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
        rig = bpy.data.objects.new("C2_Rig", None)
        sc.collection.objects.link(rig)
        for o in vis:
            o.parent = rig
        bpy.ops.mesh.primitive_plane_add(size=4000.0, location=(0, 0, 0))
        sea = bpy.context.active_object
        sea.name = "C2_SeaStandIn"
        sm = bpy.data.materials.new("MI_C2_Sea")
        sm.use_nodes = True
        bs = sm.node_tree.nodes["Principled BSDF"]
        bs.inputs["Base Color"].default_value = (0.012, 0.035, 0.040, 1)
        bs.inputs["Roughness"].default_value = 0.12
        sea.data.materials.append(sm)
        template.set_world(template.OVERCAST)
        cam_d = bpy.data.cameras.new("C2_Cam")
        cam = bpy.data.objects.new("C2_Cam", cam_d)
        sc.collection.objects.link(cam)
        sc.camera = cam
        sc.render.resolution_x = sc.render.resolution_y = 768
        sc.render.film_transparent = False
        for (_, shot, pose, wet, water, tgt, dist, az, el, lens) in shots:
            for o in vis:
                o.data.materials[0] = mat_for(stem_of(orig[o.name]), wet)
                # C2b state parts: Damage only when she lies over / is turned turtle, Undamaged only upright
                o.hide_render = ("_Damage_" in o.name and pose != "capsized") or ("_Undamaged_" in o.name and pose in ("capsized", "turtle"))
            if pose == "upright":
                rig.matrix_world = Matrix.Identity(4)
                sea_z = 1.75
            elif pose == "capsized":     # 72 deg onto Roblox -X (Blender +X) about the hull centre, centre 0.6 m above water
                rig.matrix_world = Matrix.Translation((0, 0, 2.0 * S)) @ Matrix.Rotation(math.radians(72), 4, "Y") @ Matrix.Translation((0, 0, -2.0 * S))
                sea_z = 1.4
            elif pose == "turtle":
                rig.matrix_world = Matrix.Translation((0, 0, 2.0 * S)) @ Matrix.Rotation(math.radians(180), 4, "Y") @ Matrix.Translation((0, 0, -2.0 * S))
                sea_z = 2.7
            else:
                rig.matrix_world = Matrix.Identity(4)
                sea_z = 0.32
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
            print("[C2] rendered", sc.render.filepath)


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    cell, cols = 400, 4
    rows = math.ceil(len(SHOTS) / cols)
    head = 40
    im = Image.new("RGB", (cell * cols, head + rows * (cell + 24)), (28, 30, 32))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)
    d.text((10, 10), "C2b: Gale Queen island passenger ferry (21 m, steel, generic) upright / lying over 72 deg (the op's roll) / "
                     "turned turtle, and SOLAS 12-person liferaft. Overcast-sea HDRI, EEVEE, LOD0; sea = stand-in plane",
           fill=(230, 230, 230), font=f)
    for i, (asset, shot, *_r) in enumerate(SHOTS):
        x, y = (i % cols) * cell, head + (i // cols) * (cell + 24)
        p = OUT + "%s__%s.png" % (asset, shot)
        if os.path.exists(p):
            im.paste(Image.open(p).convert("RGB").resize((cell, cell), Image.LANCZOS), (x, y + 24))
        d.text((x + 6, y + 4), "%s  %s" % (asset.replace("M_Veh_", "").replace("M_Sea_", ""), shot), fill=(240, 240, 200), font=f)
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    im.save(SHEET)
    print("sheet", SHEET, im.size)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet()
    else:
        blender_main()
