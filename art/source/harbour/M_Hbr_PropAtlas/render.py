"""HP2a review renders (inside Blender, one process): every prop dry and wet under the overcast-sea HDRI
(art/blender/_template.blend WLD_OvercastSea), plus one hero-distance close-up per kit. Alpha nets use the ALB alpha.

    ~/RobloxProjects/tools/blender-run.sh art/source/harbour/M_Hbr_PropAtlas/render.py
    python3 art/source/harbour/M_Hbr_PropAtlas/sheet.py      # -> assets/review/HP2a/contact.png
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
sys.path.insert(0, HERE)
import run  # noqa: E402
import template  # noqa: E402
import turntable  # noqa: E402
import atlas  # noqa: E402
from refs import REFS  # noqa: E402

OUT = os.path.join(G, "build/hp2a/renders")
TEX = os.path.join(G, "assets/textures", atlas.ATLAS_ASSET)
CELL = 400
CLOSE = 600
# kit close-ups: asset, (az, el), target height fraction, distance factor of the bbox size
CLOSEUPS = {"M_Hbr_Bollard_01": ("bollard_neck_rope_wear", 30, 18, 0.62, 0.9),
            "M_Hbr_Fender_Cyl_01": ("fender_pvc", 30, 10, 0.55, 0.6),
            "M_Hbr_LifebuoyStation": ("lifebuoy_ring_sign", 15, 8, 0.75, 0.55),
            "M_Hbr_LobsterPot_02": ("creel_netting", 35, 30, 0.5, 0.9),
            "M_Hbr_NetPile": ("net_pile", 25, 35, 0.4, 0.55),
            "M_Hbr_Rope_Coil": ("rope_coil", 20, 45, 0.3, 0.55)}


def material(set_name, wet):
    key = "MI_HP2a_%s%s" % (set_name, "_Wet" if wet else "")
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    sfx = "_Wet" if wet else ""
    for k in ("ALB", "NOR", "RGH", "MET"):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(os.path.join(TEX, "T_%s_%s_%s%s.png" % (atlas.NAME, set_name, k, sfx)), check_existing=True)
        t.image.colorspace_settings.name = "sRGB" if k == "ALB" else "Non-Color"
        if k == "ALB":
            nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
            if set_name == "Rope":
                nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
        elif k == "RGH":
            nt.links.new(t.outputs["Color"], b.inputs["Roughness"])
        elif k == "MET":
            nt.links.new(t.outputs["Color"], b.inputs["Metallic"])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nm.uv_map = "UVMap"
            nt.links.new(t.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    try:
        m.surface_render_method = "DITHERED"
    except Exception:
        pass
    m.use_backface_culling = False
    return m


def ground(z=0.0, size=40.0):
    me = bpy.data.meshes.new("HP2a_Ground")
    s = size / 2
    me.from_pydata([(-s, -s, z), (s, -s, z), (s, s, z), (-s, s, z)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("HP2a_Ground", me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("HP2a_GroundMat")
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.11, 0.105, 0.1, 1)
    b.inputs["Roughness"].default_value = 0.85
    me.materials.append(m)
    return ob


def shoot(scene, cam, pts, az, el, path, res, target=None, dist=None):
    d = turntable.view_dir(az, el)
    if target is None:
        turntable.fit(cam, pts, d)
    else:
        cam.matrix_world = template.look_matrix(-d, location=Vector(target) + d * dist)
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for asset in REFS:
        if only and asset not in only:
            continue
        run.open_scene(True)
        scene = bpy.context.scene
        for ob in list(scene.objects):
            ob.hide_render = True
        template.set_world("WLD_OvercastSea")
        template.set_eevee(scene, 48)
        mod = run.load_build(os.path.join(G, "art/source/harbour", asset, "build.py"))
        spec = mod.build()
        vis = [e for e in spec["meshes"] if e["object"].name.endswith("_LOD0")]
        for e in spec["meshes"]:
            if e not in vis:
                e["object"].hide_render = True
        ground()
        cam_data = bpy.data.cameras.new("HP2a_Cam")
        cam_data.lens = 70
        cam = bpy.data.objects.new("HP2a_Cam", cam_data)
        scene.collection.objects.link(cam)
        scene.camera = cam
        pts = turntable.corners([e["object"] for e in vis])
        for wet in (False, True):
            for e in vis:
                o = e["object"]
                o.data.materials.clear()
                o.data.materials.append(material(e["set"], wet))
            shoot(scene, cam, pts, 35, 22, os.path.join(OUT, "%s_%s.png" % (asset, "wet" if wet else "dry")), CELL)
        if asset in CLOSEUPS:
            name, az, el, hf, df = CLOSEUPS[asset]
            for e in vis:
                e["object"].data.materials.clear()
                e["object"].data.materials.append(material(e["set"], False))
            lo, hi = turntable.bounds(pts)
            size = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
            tgt = ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z + (hi.z - lo.z) * hf)
            shoot(scene, cam, pts, az, el, os.path.join(OUT, "closeup_%s.png" % name), CLOSE, tgt, max(size * df, 1.6))
        print("[HP2a] rendered", asset, flush=True)


main()
