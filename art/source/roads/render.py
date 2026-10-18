"""R1a review renders (Blender, EEVEE, overcast HDRI art/blender/hdri/gray_pier_2k.hdr): every furniture asset dry and wet,
the road strips (asphalt with kerbs, footway and UK markings; Harbour Road cobbles; gravel track) dry and wet, and one
close-up per kit. Outputs build/roads/renders/*.png; sheet.py-style contact sheet by contact.py (system python3).

    ~/RobloxProjects/tools/blender-run.sh art/source/roads/render.py
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kit  # noqa: E402

GAME = kit.GAME
OUT = os.path.join(GAME, "build/roads/renders")
RIB = os.path.join(GAME, "assets/textures/M_Road_Ribbon")
S = kit.S
LAYOUT = json.load(open(os.path.join(GAME, "assets/materials/roads_variants.json")))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x, sc.render.resolution_y = 800, 600
    sc.view_settings.view_transform = "AgX"
    try:
        sc.eevee.taa_render_samples = 48
    except AttributeError:
        pass
    w = bpy.data.worlds.new("Overcast")
    w.use_nodes = True
    nt = w.node_tree
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(os.path.join(GAME, "art/blender/hdri/gray_pier_2k.hdr"))
    nt.links.new(env.outputs["Color"], nt.nodes["Background"].inputs["Color"])
    sc.world = w
    return sc


def pbr(name, stem, wet=False, alpha=False, folder=RIB):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes["Principled BSDF"]

    def img(k, colour):
        p = os.path.join(folder, "%s_%s.png" % (stem, k))
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(p, check_existing=True)
        if not colour:
            n.image.colorspace_settings.name = "Non-Color"
        return n
    a = img("ALB_Wet" if wet else "ALB", True)
    nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    if alpha:
        nt.links.new(a.outputs["Alpha"], b.inputs["Alpha"])
        try:
            mat.surface_render_method = "DITHERED"
        except AttributeError:
            mat.blend_method = "HASHED"
    nt.links.new(img("RGH_Wet" if wet else "RGH", False).outputs["Color"], b.inputs["Roughness"])
    nt.links.new(img("MET", False).outputs["Color"], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(img("NOR", False).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return mat


def quad_mesh(name, verts_uv, mat):
    """verts_uv: list of quads [(x, y, z, u, v) x 4] in metres."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    for q in verts_uv:
        vs = [bm.verts.new((p[0] * S, p[1] * S, p[2] * S)) for p in q]
        f = bm.faces.new(vs)
        for l, p in zip(f.loops, q):
            l[uvl].uv = (p[3], p[4])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def strip(name, width, length, len_u, mat, x0=None, z=0.0, steps=8):
    x0 = -width / 2 if x0 is None else x0
    qs = []
    for i in range(steps):
        y0, y1 = length * i / steps, length * (i + 1) / steps
        qs.append([(x0, y0, z, y0 / len_u, 0), (x0 + width, y0, z, y0 / len_u, 0),
                   (x0 + width, y1, z, y1 / len_u, 0), (x0, y1, z, y1 / len_u, 0)])
        for q in qs[-1:]:
            q[1] = q[1][:4] + (1,)
            q[2] = q[2][:4] + (1,)
    return quad_mesh(name, qs, mat)


def kerb(name, x, side, length, mat, foot_mat):
    """Granite kerb along y at x (road edge), side +1 = footway to +x. Profile V: face, arris, top, back (layout)."""
    prof = [(0.0, 0.0, 0.0), (0.0, 0.125, 0.3125), (0.02, 0.145, 0.3625), (0.17, 0.145, 0.7375), (0.17, 0.10, 0.85),
            (0.17, 0.04, 1.0)]
    qs = []
    n = int(length / 1.8 * 4)
    for i in range(n):
        y0, y1 = length * i / n, length * (i + 1) / n
        for (d0, z0, v0), (d1, z1, v1) in zip(prof, prof[1:]):
            qs.append([(x + side * d0, y0, z0, y0 / 1.8, v0), (x + side * d1, y0, z1, y0 / 1.8, v1),
                       (x + side * d1, y1, z1, y1 / 1.8, v1), (x + side * d0, y1, z0, y1 / 1.8, v0)])
    ob = quad_mesh(name, qs, mat)
    fx = x + side * 0.17
    w = 2.2
    strip(name + "_Footway", w, length, 4.0, foot_mat, x0=(fx if side > 0 else fx - w), z=0.125)
    return ob


def decal(name, rect_key, center, size, mat, rot=0.0):
    u0, v0, u1, v1 = LAYOUT["markings"]["rects"][rect_key]
    cx, cy = center
    hw, hl = size[0] / 2, size[1] / 2      # size = (across, along)
    c, s = math.cos(rot), math.sin(rot)

    def p(a, b, u, v):  # a across (x), b along (y)
        return (cx + a * c - b * s, cy + a * s + b * c, 0.004, u, v)
    q = [p(-hw, -hl, u0, v1), p(hw, -hl, u0, v0), p(hw, hl, u1, v0), p(-hw, hl, u1, v1)]
    return quad_mesh(name, [q], mat)


def camera(loc, target, lens=35):
    cam = bpy.data.cameras.new("Cam")
    cam.lens = lens
    ob = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector(loc) * S
    d = Vector(target) * S - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    return ob


def shot(name):
    os.makedirs(OUT, exist_ok=True)
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name)


def road_scene(wet):
    reset()
    sfx = "_Wet" if wet else ""
    asp = pbr("Asphalt" + sfx, "T_Road_Asphalt", wet)
    krb = pbr("Kerb" + sfx, "T_Road_Kerb", wet)
    foot = pbr("Foot" + sfx, "T_Road_AsphaltTile", wet)
    mk = pbr("Mark" + sfx, "T_Road_Markings", wet, alpha=True)
    L = 24.0
    strip("Road", 6.0, L, 8.0, asp)
    kerb("KerbL", -3.0, -1, L, krb, foot)
    kerb("KerbR", 3.0, 1, L, krb, foot)
    for y in (3.0, 15.0):
        decal("Dash%d" % y, "CentreDash", (0.0, y + 2.25), (0.5, 4.5), mk)
    for i in range(6):
        decal("EdgeR%d" % i, "EdgeLine", (2.75, i * 4.0 + 2.0), (0.5, 4.0), mk)
        decal("DY%d" % i, "DoubleYellow", (-2.75, i * 4.0 + 2.0), (0.5, 4.0), mk)
    decal("GW", "GiveWayLines", (-1.5, 21.5), (1.0, 3.6), mk, rot=math.radians(90))
    decal("Tri", "GiveWayTriangle", (-1.5, 17.0), (1.75, 4.0), mk)
    for y in (9.0, 11.0, 13.0):
        decal("CE%d" % y, "CatsEyeWhite", (0.0, y), (0.25, 0.25), mk)
    camera((1.9, -3.2, 1.65), (-0.6, 10.0, 0.0), 30)
    shot("road_asphalt" + sfx)
    if not wet:
        camera((-2.2, 5.0, 0.75), (-2.95, 6.3, 0.05), 40)
        shot("closeup_road_kerb")


def surface_scene(stem, width, wet, name):
    reset()
    sfx = "_Wet" if wet else ""
    m = pbr(name + sfx, stem, wet)
    strip(name, width, 24.0, 8.0, m)
    if stem == "T_Road_Cobbles":
        krb = pbr("Kerb" + sfx, "T_Road_Kerb", wet)
        foot = pbr("Foot" + sfx, "T_Road_CobblesTile", wet)
        kerb("KerbL", -width / 2, -1, 24.0, krb, foot)
        kerb("KerbR", width / 2, 1, 24.0, krb, foot)
    else:
        g = pbr("Verge" + sfx, "T_Road_GravelTile", wet)
        strip("VergeL", 3.0, 24.0, 2.0, g, x0=-width / 2 - 3.0, z=-0.01)
        strip("VergeR", 3.0, 24.0, 2.0, g, x0=width / 2, z=-0.01)
    camera((width * 0.3, -3.0, 1.65), (-width * 0.1, 10.0, 0.0), 30)
    shot(name.lower() + sfx)


def furniture_scene(asset, wet, cam, target, lens=35, closeup=None):
    reset()
    sfx = "_Wet" if wet else ""
    parts, col, att = kit.BUILDERS[asset]()
    bpy.data.objects.remove(col, do_unlink=True)
    m = pbr("Street" + sfx, "T_Street_Main", wet, folder=os.path.join(GAME, "assets/textures", asset))
    for ob in parts.values():
        ob.data.materials[0] = m
    foot = pbr("Foot" + sfx, "T_Road_AsphaltTile", wet)
    strip("Ground", 8.0, 10.0, 4.0, foot, x0=-4.0, z=0.0)
    for o in bpy.data.objects:
        if o.name == "Ground":
            o.location.y = -5.0 * S
    camera(cam, target, lens)
    shot(asset + sfx)
    if closeup and not wet:
        camera(closeup[0], closeup[1], closeup[2])
        shot("closeup_" + asset)


def main():
    for wet in (False, True):
        road_scene(wet)
        surface_scene("T_Road_Cobbles", 6.0, wet, "Cobbles")
        surface_scene("T_Road_Gravel", 3.333, wet, "Gravel")
        furniture_scene("M_Road_StreetLamp", wet, (3.6, -5.6, 2.2), (0.45, 0.0, 2.9), 28)
        furniture_scene("M_Road_Bench", wet, (1.6, -2.3, 1.25), (0.0, 0.0, 0.42), 35,
                        closeup=((1.25, -0.75, 0.85), (0.80, -0.1, 0.5), 50))
        furniture_scene("M_Road_Bin", wet, (0.9, -1.3, 1.05), (0.0, 0.0, 0.46), 40)
        furniture_scene("M_Road_Bollard", wet, (0.75, -1.05, 0.85), (0.0, 0.0, 0.46), 40)


if __name__ == "__main__":
    main()
