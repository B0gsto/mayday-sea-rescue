"""Round-4 art-review renders for M_Chr_Bosun (Blender only, Cycles at low samples), then a Pillow contact sheet.

    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Chr_Bosun/render_r4.py -- [--samples 48] [--px 800]
    -> assets/review/M_Chr_Bosun/r4/*.png and assets/review/M_Chr_Bosun/r4_contact.png (4 x 2 tiles, 1600 px wide)

LOD0 body + harness + fur cards with the master textures (textures/T_Bosun_<Set>_<MAP>[_Wet].png). Every frame is
fitted to its subject (the whole dog, the head, the harness) so the subject fills ~85-90% of the frame. Lighting:
an overcast HDRI (gray_pier), and a dim storm (the same HDRI at low strength, cooled, plus a weak cold rim light).
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
ASSET = "M_Chr_Bosun"
BLEND = os.path.join(HERE, ASSET + ".blend")
TEX = os.path.join(HERE, "textures")
HDRI = os.path.join(REPO, "art", "blender", "hdri", "gray_pier_2k.hdr")
OUT = os.path.join(REPO, "assets", "review", ASSET, "r4")
SHEET = os.path.join(REPO, "assets", "review", ASSET, "r4_contact.png")

a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAMPLES = int(a[a.index("--samples") + 1]) if "--samples" in a else 48
PX = int(a[a.index("--px") + 1]) if "--px" in a else 800

# name, subject, view direction (target -> camera, x right / -y front / z up), wet, light, fill, label
SHOTS = [
    ("q34_dry", "dog", (-0.62, -0.72, 0.30), False, "overcast", 0.90, "3/4 dry - overcast"),
    ("q34_wet", "dog", (-0.62, -0.72, 0.30), True, "overcast", 0.90, "3/4 wet - overcast"),
    ("side_dry", "dog", (-1.0, 0.0, 0.10), False, "overcast", 0.92, "side dry - overcast"),
    ("head_dry", "head", (-0.55, -0.80, 0.18), False, "overcast", 0.88, "head close-up - overcast"),
    ("rear_dry", "dog", (-0.60, 0.74, 0.30), False, "overcast", 0.90, "rear 3/4 (tail) - overcast"),
    ("harness_dry", "harness", (-0.50, -0.45, 0.74), False, "overcast", 0.88, "harness close-up - overcast"),
    ("q34_dry_storm", "dog", (-0.62, -0.72, 0.30), False, "storm", 0.90, "3/4 dry - dim storm"),
    ("q34_wet_storm", "dog", (-0.62, -0.72, 0.30), True, "storm", 0.90, "3/4 wet - dim storm"),
]


def set_of(name):
    return "Fur" if "_Fur" in name else "Harness" if "_Harness" in name else "Body"


def image(path, colour):
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    return img


def material(set_name, wet):
    sfx = "_Wet" if wet else ""
    mat = bpy.data.materials.new("R4_%s%s" % (set_name, sfx))
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def tex(map_name, colour):
        p = os.path.join(TEX, "T_Bosun_%s_%s%s.png" % (set_name, map_name, sfx if map_name != "MET" else ""))
        if not os.path.isfile(p):
            p = os.path.join(TEX, "T_Bosun_%s_%s.png" % (set_name, map_name))
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = image(p, colour)
        return n

    alb = tex("ALB", True)
    nt.links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
    if set_name == "Fur":
        nt.links.new(alb.outputs["Alpha"], bsdf.inputs["Alpha"])
    nt.links.new(tex("RGH", False).outputs["Color"], bsdf.inputs["Roughness"])
    nt.links.new(tex("MET", False).outputs["Color"], bsdf.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex("NOR", False).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if set_name == "Fur":
        bsdf.inputs["Subsurface Weight"].default_value = 0.0
    return mat


def world(light):
    w = bpy.data.worlds.new("R4_" + light)
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(HDRI, check_existing=True)
    mapping = nt.nodes.new("ShaderNodeMapping")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
    mapping.inputs["Rotation"].default_value[2] = math.radians(130)
    nt.links.new(mapping.outputs["Vector"], env.inputs["Vector"])
    if light == "storm":
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        nt.links.new(env.outputs["Color"], mix.inputs["A"])
        mix.inputs["B"].default_value = (0.55, 0.63, 0.75, 1.0)
        nt.links.new(mix.outputs["Result"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 0.22
    else:
        nt.links.new(env.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 1.0
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    return w


def subject_points(objs, subject):
    pts = []
    for o in objs:
        if subject == "harness" and "_Harness" not in o.name:
            continue
        if subject == "head" and not ("_BodyHead" in o.name or "_FurFront" in o.name):
            continue
        M = np.array(o.matrix_world)
        V = np.zeros(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", V)
        V = V.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
        pts.append(V)
    P = np.vstack(pts)
    if subject == "head":
        S = 2.91                                                       # studs per build metre (3 x 0.97)
        P = P[P[:, 1] < P[:, 1].min() + 0.36 * S]                      # the head: ~0.36 m behind the nose
        P = P[P[:, 2] > P[:, 2].max() - 0.44 * S]                      # crown down to the ear tips
    rng = np.random.default_rng(1)
    if len(P) > 20000:
        P = P[rng.choice(len(P), 20000, replace=False)]
    return P


def fit_camera(cam, P, d, fill):
    d = np.asarray(d, float)
    d /= np.linalg.norm(d)
    up0 = np.array([0, 0, 1.0])
    right = np.cross(d * -1, up0)
    right /= np.linalg.norm(right)
    up = np.cross(right, -d)
    t = math.tan(cam.data.angle / 2) * fill
    c = (P.min(0) + P.max(0)) / 2
    for _ in range(3):
        Q = P - c
        lat = np.maximum(np.abs(Q @ right), np.abs(Q @ up))
        dist = float(np.max(lat / t + Q @ d))
        eye = c + d * dist
        R = P - eye
        z = R @ -d
        u, v = (R @ right) / z, (R @ up) / z
        du, dv = (u.min() + u.max()) / 2, (v.min() + v.max()) / 2
        c = c + right * du * dist + up * dv * dist
    Q = P - c
    lat = np.maximum(np.abs(Q @ right), np.abs(Q @ up))
    dist = float(np.max(lat / t + Q @ d))
    eye = c + d * dist
    cam.location = Vector(eye.tolist())
    cam.rotation_euler = Vector((-d).tolist()).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_start = max(0.01, dist * 0.02)
    return dist


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    scene = bpy.context.scene
    objs = []
    for o in scene.objects:
        keep = o.type == "MESH" and o.name.startswith(ASSET) and o.name.endswith("_LOD0")
        o.hide_render = not keep
        if keep:
            objs.append(o)
    print("[r4] objects", [o.name for o in objs])
    mats = {(s, w): material(s, w) for s in ("Body", "Harness", "Fur") for w in (False, True)}

    # ground: dark wet slipway concrete
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("R4_Ground")
    gm.use_nodes = True
    gb = gm.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (0.055, 0.055, 0.052, 1)
    gb.inputs["Roughness"].default_value = 0.55
    ground.data.materials.append(gm)

    cam_data = bpy.data.cameras.new("R4_Cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("R4_Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    rim_data = bpy.data.lights.new("R4_StormRim", "SUN")
    rim_data.energy = 0.9
    rim_data.color = (0.70, 0.80, 1.0)
    rim_data.angle = math.radians(12)
    rim = bpy.data.objects.new("R4_StormRim", rim_data)
    rim.rotation_euler = (math.radians(55), 0, math.radians(150))
    scene.collection.objects.link(rim)
    worlds = {k: world(k) for k in ("overcast", "storm")}

    scene.render.engine = "CYCLES"
    cy = scene.cycles
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for dev in prefs.devices:
            dev.use = True
        cy.device = "GPU"
    except Exception as e:  # CPU fallback
        print("[r4] GPU unavailable:", e)
    cy.samples = SAMPLES
    cy.use_denoising = True
    cy.max_bounces = 6
    cy.transparent_max_bounces = 48
    cy.use_adaptive_sampling = True
    scene.render.resolution_x = scene.render.resolution_y = PX
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Base Contrast"
    scene.render.image_settings.file_format = "PNG"
    os.makedirs(OUT, exist_ok=True)

    paths = []
    for name, subject, d, wet, light, fill, label in SHOTS:
        for o in objs:
            o.data.materials.clear()
            o.data.materials.append(mats[(set_of(o.name), wet)])
        scene.world = worlds[light]
        rim.hide_render = light != "storm"
        scene.view_settings.exposure = 0.6 if light == "storm" else 0.0
        fit_camera(cam, subject_points(objs, subject), d, fill)
        scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
        paths.append((scene.render.filepath, label))
        print("[r4] rendered", name)
    contact(paths)


def contact(paths):
    import subprocess
    script = (
        "import sys\nfrom PIL import Image, ImageDraw\n"
        "items = [l.split('\\t') for l in sys.argv[2].split('\\n')]\n"
        "T = 400\nsheet = Image.new('RGB', (4 * T, 2 * T), (18, 18, 18))\nd = ImageDraw.Draw(sheet)\n"
        "for i, (p, lab) in enumerate(items):\n"
        "    im = Image.open(p).convert('RGB').resize((T, T), Image.LANCZOS)\n"
        "    x, y = (i % 4) * T, (i // 4) * T\n    sheet.paste(im, (x, y))\n"
        "    d.rectangle([x, y + T - 18, x + T, y + T], fill=(0, 0, 0))\n"
        "    d.text((x + 6, y + T - 15), 'Bosun r4 | ' + lab, fill=(235, 235, 235))\n"
        "sheet.save(sys.argv[1])\nprint('[r4] sheet', sys.argv[1], sheet.size)\n")
    subprocess.run([os.environ.get("R4_PY", "/usr/bin/python3"), "-c", script, SHEET,
                    "\n".join("%s\t%s" % pl for pl in paths)], check=True)


main()
