"""Builds art/blender/_template.blend (docs/12 section 1.1 template row; docs/06 section 2.1 step 2). Every asset build
starts from it (run.py opens it unless --no-template). Always through the heavy-slot wrapper:

    ~/RobloxProjects/tools/blender-run.sh tools/blender/template.py [-- --out art/blender/_template.blend]

What it holds, all in the collection "Template" (never exported: export.py and validate.py only look at the spec's
meshes and at empties named ATT*, and the template has no empties):
  - units: metric, scale 1, so 1 Blender unit = 1 stud (3 studs per metre, common.metres_to_studs). Not 'NONE':
    the FBX exporter writes UnitScaleFactor 1 for 'NONE', and export.py's read-back expects 100.
  - TPL_Mannequin: a 5.5-stud (1.8 m) adult, simple but proportioned (8 heads tall), feet on Z 0, facing -Y.
  - TPL_Water: a 2000-stud water plane at Z 0 (Blender up), hidden in renders.
  - TPL_Dock: a quay slab at Y +60 with every vehicle's real footprint (VEHICLES, docs/12 2.1) and a label each.
  - two world setups from art/blender/hdri/ (Poly Haven CC0, art/blender/LICENCES.md): WLD_Neutral and WLD_OvercastSea,
    plus WLD_OvercastCoast as an alternative; set_world(name) switches them.
  - TPL_Swatch_*: the reference palette of docs/05 section 3 (real albedos and signal colours) as labelled tiles.
  - EEVEE, 768 x 768, AgX, and CAM_Template.
template.py is also imported by turntable.py (no side effects on import).
"""
import math
import os
import sys

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
if LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402

COLLECTION = "Template"
BLEND = os.path.join(common.ART_DIR, "blender", "_template.blend")
HDRI_DIR = os.path.join(common.ART_DIR, "blender", "hdri")
RENDER_SIZE = 768

# world name -> (HDRI file, strength, Z rotation in degrees)
WORLDS = {
    "WLD_Neutral": ("studio_small_08_2k.hdr", 1.0, 0.0),
    "WLD_OvercastSea": ("gray_pier_2k.hdr", 1.0, 0.0),
    "WLD_OvercastCoast": ("dalkey_view_2k.hdr", 1.0, 0.0),
}
NEUTRAL, OVERCAST = "WLD_Neutral", "WLD_OvercastSea"

# Dock lineup: real footprints in metres (length along Y, beam along X), docs/12 section 2.1; (verify) as there.
VEHICLES = [
    ("JetSki", 3.4, 1.2), ("JetSki rescue sled", 2.0, 1.2), ("ATV", 2.1, 1.2), ("Kayak (verify)", 3.3, 0.8),
    ("Paddleboard (verify)", 3.2, 0.8), ("Liferaft 3 m (verify)", 3.0, 3.0), ("MooredBoat_01 punt (tune)", 4.0, 1.5),
    ("BoatTrailer_JetSki (verify)", 4.5, 1.8), ("Coastguard4x4 (verify)", 5.0, 2.0), ("LifeguardPickup", 5.3, 1.85),
    ("Ambulance (verify)", 6.8, 2.3), ("Optimist 7 m (tune)", 7.0, 2.6), ("RIB Atlantic 85", 8.4, 2.85),
    ("BoatTrailer_RIB (verify)", 9.5, 2.5), ("MooredBoat_02 crabber (tune)", 10.0, 3.8),
    ("MooredBoat_03 trawler (tune)", 15.0, 5.0), ("GaleQueen 45 m (tune)", 45.0, 11.0),
]
DOCK_Y = 60.0           # studs: the lineup sits behind the asset, out of every turntable frame

# docs/05 section 3: water, sky, real-world albedos and the signal colours.
PALETTE = [
    ("DeepWaterOvercast", "#34484C"), ("HarbourWater", "#33483F"), ("ShallowsSand", "#4C9C94"), ("Foam", "#DCE2E1"),
    ("BrightOvercast", "#B3B9BC"), ("StormCloud", "#4A5157"), ("GraniteDry", "#8A8781"), ("GraniteWet", "#4E4C49"),
    ("SlateRoof", "#4B5257"), ("Whitewash", "#E3DFD5"), ("HarbourStone", "#7D756A"), ("DrySand", "#CDBB98"),
    ("WetSand", "#8C7B62"), ("Kelp", "#4B4A26"), ("Lichen", "#C9B458"), ("CoastalGrass", "#5E6E3A"),
    ("Rust", "#8B4A25"), ("SaltCrust", "#D9D6CC"), ("HullOrange", "#FF6600"), ("HiVisYellow", "#DFFF00"),
    ("SOLASOrange", "#FF5A1F"), ("DistressRed", "#FF2A1A"), ("Retroreflective", "#D6D9DC"), ("HullCharcoal", "#2B2F33"),
]


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(hexcode):
    h = hexcode.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def look_matrix(look, up=(0.0, 0.0, 1.0), location=(0.0, 0.0, 0.0)):
    """World matrix of a camera at `location` whose -Z axis points along `look`."""
    z = -Vector(look).normalized()
    x = Vector(up).cross(z)
    if x.length < 1e-6:
        x = Vector((1.0, 0.0, 0.0))
    x.normalize()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(location)
    return m


def collection():
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    col["mayday_template"] = True
    return col


def template_objects():
    col = bpy.data.collections.get(COLLECTION)
    return list(col.all_objects) if col else []


def material(name, hexcode=None, rgb=None, roughness=0.6, emission=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    lin = rgb or hex_to_linear(hexcode)
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*lin, 1.0)
    return mat


def mesh_object(name, mesh, mat=None):
    obj = bpy.data.objects.new(name, mesh)
    if mat:
        mesh.materials.append(mat)
    collection().objects.link(obj)
    return obj


def _box(name, size, location, mat=None):
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=location, verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh_object(name, mesh, mat)


def label(name, text, location, size=0.8, rotation=(0.0, 0.0, 0.0)):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = text
    curve.size = size
    obj = bpy.data.objects.new(name, curve)
    obj.location = location
    obj.rotation_euler = rotation
    collection().objects.link(obj)
    return obj


# ---------------------------------------------------------------- mannequin

# Parts in metres for a 1.80 m adult (8 heads of 0.225 m), facing -Y: (kind, centre (x, y, z), size (x, y, z)).
# kind "ell" is a scaled UV sphere, "cyl" a capsule-like cylinder with rounded ends (scaled sphere along its axis).
_HEAD = 0.225
MANNEQUIN_PARTS = [
    ("ell", (0.0, 0.0, 1.69), (0.155, 0.19, 0.225)),       # head: 1.575 to 1.80
    ("ell", (0.0, 0.0, 1.535), (0.11, 0.11, 0.12)),        # neck
    ("ell", (0.0, 0.0, 1.30), (0.40, 0.22, 0.42)),         # chest
    ("ell", (0.0, 0.0, 1.05), (0.31, 0.19, 0.28)),         # waist
    ("ell", (0.0, 0.0, 0.92), (0.36, 0.21, 0.22)),         # pelvis
    ("ell", (0.0, 0.0, 1.43), (0.44, 0.16, 0.12)),         # shoulders
]
for _s in (-1.0, 1.0):
    MANNEQUIN_PARTS += [
        ("ell", (_s * 0.225, 0.0, 1.23), (0.10, 0.10, 0.34)),     # upper arm 1.40 to 1.06
        ("ell", (_s * 0.235, 0.0, 0.92), (0.085, 0.085, 0.30)),   # forearm to the wrist at 0.78
        ("ell", (_s * 0.24, -0.01, 0.71), (0.06, 0.09, 0.17)),    # hand, fingertips at about 0.62
        ("ell", (_s * 0.10, 0.0, 0.70), (0.16, 0.16, 0.44)),      # thigh 0.92 to 0.48
        ("ell", (_s * 0.10, 0.01, 0.28), (0.115, 0.115, 0.46)),   # shin 0.51 to 0.05
        ("ell", (_s * 0.10, -0.06, 0.04), (0.10, 0.26, 0.08)),    # foot on the ground, toes forward (-Y)
    ]


def build_mannequin(scale_studs=common.MANNEQUIN_STUDS):
    """One mesh, feet on Z 0, exactly `scale_studs` tall, facing -Y."""
    import bmesh
    bm = bmesh.new()
    for kind, centre, size in MANNEQUIN_PARTS:
        part = bmesh.new()
        bmesh.ops.create_uvsphere(part, u_segments=20, v_segments=12, radius=0.5)
        bmesh.ops.scale(part, vec=size, verts=part.verts)
        bmesh.ops.translate(part, vec=centre, verts=part.verts)
        tmp = bpy.data.meshes.new("tmp")
        part.to_mesh(tmp)
        part.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    zs = [v.co.z for v in bm.verts]
    lo, hi = min(zs), max(zs)
    k = scale_studs / (hi - lo)
    bmesh.ops.translate(bm, vec=(0.0, 0.0, -lo), verts=bm.verts)
    bmesh.ops.scale(bm, vec=(k, k, k), verts=bm.verts)
    for f in bm.faces:
        f.smooth = True
    mesh = bpy.data.meshes.new("TPL_Mannequin")
    bm.to_mesh(mesh)
    bm.free()
    obj = mesh_object("TPL_Mannequin", mesh, material("MI_TPL_Mannequin", rgb=(0.30, 0.30, 0.30), roughness=0.55))
    obj["height_studs"] = scale_studs
    return obj


# ---------------------------------------------------------------- worlds

def build_world(name, filename, strength=1.0, rot_z=0.0):
    world = bpy.data.worlds.get(name) or bpy.data.worlds.new(name)
    world.use_nodes = True
    world.use_fake_user = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    mapping = nt.nodes.new("ShaderNodeMapping")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    path = os.path.join(HDRI_DIR, filename)
    if os.path.isfile(path):
        env.image = bpy.data.images.load(path, check_existing=True)
    else:
        print("[template] WARNING: HDRI missing: %s (world %s is black)" % (path, name))
    mapping.inputs["Rotation"].default_value[2] = math.radians(rot_z)
    bg.inputs["Strength"].default_value = strength
    nt.links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], env.inputs["Vector"])
    nt.links.new(env.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    world["hdri"] = filename
    return world


def set_world(name):
    """Switches the scene world: WLD_Neutral, WLD_OvercastSea or WLD_OvercastCoast. Builds it if the scene lacks it."""
    world = bpy.data.worlds.get(name)
    if world is None:
        filename, strength, rot = WORLDS[name]
        world = build_world(name, filename, strength, rot)
    bpy.context.scene.world = world
    return world


def set_eevee(scene, samples=32):
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.eevee.taa_render_samples = samples
    for attr, value in (("use_shadows", True), ("use_raytracing", True), ("use_gtao", True)):
        if hasattr(scene.eevee, attr):
            setattr(scene.eevee, attr, value)
    scene.render.resolution_x = scene.render.resolution_y = RENDER_SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "AgX"
    except TypeError:
        scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0


# ---------------------------------------------------------------- the scene

def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "Mayday"
    us = scene.unit_settings
    us.system, us.scale_length, us.length_unit = "METRIC", 1.0, "METERS"   # 1 unit = 1 stud (see the docstring)
    set_eevee(scene)
    col = collection()

    mannequin = build_mannequin()
    mannequin.location = (-4.0, 0.0, 0.0)

    bpy.ops.mesh.primitive_plane_add(size=2000.0, location=(0.0, 0.0, 0.0))
    water = bpy.context.active_object
    water.name = water.data.name = "TPL_Water"
    for c in list(water.users_collection):
        c.objects.unlink(water)
    col.objects.link(water)
    water.data.materials.append(material("MI_TPL_Water", "#34484C", roughness=0.08))
    water.hide_render = True

    # Dock: a quay slab (deck 1.5 studs above the water) with the footprints in a row along X, bows to -Y.
    s = common.metres_to_studs
    gap, x = 3.0, 0.0
    deck_z = 1.5
    longest = max(s(v[1]) for v in VEHICLES)
    stone = material("MI_TPL_Dock", "#7D756A", roughness=0.85)
    paint = material("MI_TPL_Footprint", "#D6D9DC", roughness=0.5)
    for name, length_m, beam_m in VEHICLES:
        w, l = s(beam_m), s(length_m)
        fp = _box("TPL_Footprint_" + name.split(" ")[0], (w, l, 0.05), (x + w / 2.0, DOCK_Y + l / 2.0, deck_z + 0.025), paint)
        fp["real_m"] = "%.2f x %.2f" % (length_m, beam_m)
        label("TPL_Label_" + name.split(" ")[0], "%s %.1f x %.1f m" % (name, length_m, beam_m),
              (x + w / 2.0 - 0.3, DOCK_Y - 1.0, deck_z + 0.06), size=0.9, rotation=(0.0, 0.0, math.radians(90)))
        x += w + gap
    _box("TPL_Dock", (x + gap, longest + 12.0, deck_z + 3.0), ((x - gap) / 2.0, DOCK_Y + longest / 2.0 - 3.0, deck_z - (deck_z + 3.0) / 2.0), stone)

    # Palette swatches: 2-stud tiles in rows of 8 at X -40, standing up facing -Y so the camera sees them.
    for i, (name, hexcode) in enumerate(PALETTE):
        cx, cz = -40.0 + (i % 8) * 2.6, 9.0 - (i // 8) * 3.2
        emissive = 2.0 if name == "DistressRed" else 0.0
        _box("TPL_Swatch_" + name, (2.0, 0.2, 2.0), (cx, 0.0, cz), material("MI_TPL_Swatch_" + name, hexcode, roughness=0.6, emission=emissive))
        label("TPL_SwatchLabel_" + name, "%s %s" % (name, hexcode), (cx - 1.0, -0.15, cz - 1.45), size=0.28,
              rotation=(math.radians(90), 0.0, 0.0))
    for obj in template_objects():
        if obj.name.startswith(("TPL_Swatch", "TPL_Dock", "TPL_Footprint", "TPL_Label")):
            obj.hide_render = True        # visible in the viewport; turntable.py shows only the asset and the mannequin

    for name, (filename, strength, rot) in WORLDS.items():
        build_world(name, filename, strength, rot)
    set_world(NEUTRAL)

    cam_data = bpy.data.cameras.new("CAM_Template")
    cam_data.lens, cam_data.clip_start, cam_data.clip_end = 50.0, 0.1, 5000.0
    cam = bpy.data.objects.new("CAM_Template", cam_data)
    col.objects.link(cam)
    target = Vector((-2.0, 0.0, 2.75))
    loc = target + Vector((9.0, -14.0, 4.0))
    cam.matrix_world = look_matrix(target - loc, location=loc)
    scene.camera = cam
    return scene


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = os.path.abspath(argv[argv.index("--out") + 1]) if "--out" in argv else BLEND
    build_scene()
    bpy.context.preferences.filepaths.save_version = 0      # no _template.blend1 backup
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out, check_existing=False)
    try:
        bpy.ops.file.make_paths_relative()
        bpy.ops.wm.save_mainfile()
    except RuntimeError as exc:
        print("[template] paths kept absolute:", exc)
    m = bpy.data.objects["TPL_Mannequin"]
    zs = [(m.matrix_world @ v.co).z for v in m.data.vertices]
    print("[template] mannequin %.3f studs tall, %d template objects, worlds %s" % (
        max(zs) - min(zs), len(template_objects()), ", ".join(sorted(w.name for w in bpy.data.worlds))))
    print("[template] HDRIs:", ", ".join("%s=%s" % (i.name, "ok" if i.has_data or os.path.isfile(bpy.path.abspath(i.filepath)) else "MISSING")
                                       for i in bpy.data.images))
    print("[template] wrote", out)


if __name__ == "__main__":
    main()
