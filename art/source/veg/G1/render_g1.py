"""Blender (EEVEE): G1 review renders from the saved .blends -> assets/review/G1/renders/ (alpha-clipped atlas,
double-sided, overcast-coast HDRI from the template). 16 hero cells (Front3Q), 6 close-ups, LOD rows."""
import math, os, sys
import bpy
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import vegkit
OUT = os.path.join(GAME, "assets/review/G1/renders")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.path.join(GAME, "art/blender/_template.blend"))
sc = bpy.context.scene
for ob in list(sc.objects):
    ob.hide_render = True
w = bpy.data.worlds.get("WLD_OvercastCoast") or bpy.data.worlds.get("WLD_OvercastSea")
if w:
    sc.world = w
T = vegkit.TEX_DIR
mat = bpy.data.materials.new("G1_Foliage")
mat.use_nodes = True
nt = mat.node_tree
b = nt.nodes.get("Principled BSDF")
def tex(kind, colour):
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(T, "T_FoliageLand_Main_%s.png" % kind))
    t.image.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    return t
a = tex("ALB", True); nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
clip = nt.nodes.new("ShaderNodeMath"); clip.operation = "GREATER_THAN"; clip.inputs[1].default_value = 0.45
nt.links.new(a.outputs["Alpha"], clip.inputs[0]); nt.links.new(clip.outputs[0], b.inputs["Alpha"])
r = tex("RGH", False); nt.links.new(r.outputs["Color"], b.inputs["Roughness"])
n = tex("NOR", False); nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(n.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
if "Subsurface Weight" in b.inputs:
    pass
b.inputs["Metallic"].default_value = 0
mat.use_backface_culling = False
try:
    mat.surface_render_method = "DITHERED"
except Exception:
    mat.blend_method = "CLIP"
# ground: muted turf-coloured plane, a sun from the SW (wind side) at 35 degrees
bpy.ops.mesh.primitive_plane_add(size=400)
g = bpy.context.object; gm = bpy.data.materials.new("G1_Ground"); gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.1, 0.06, 1)
gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
g.data.materials.append(gm)
sun_d = bpy.data.lights.new("G1_Sun", "SUN"); sun_d.energy = 2.2; sun_d.angle = math.radians(8)
sun = bpy.data.objects.new("G1_Sun", sun_d); sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(55), 0, math.radians(-130))
cam_d = bpy.data.cameras.new("G1_Cam"); cam_d.angle = math.radians(40)
cam = bpy.data.objects.new("G1_Cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
sc.render.film_transparent = False

def load(asset):
    path = os.path.join(GAME, "art/source/veg", asset, asset + ".blend")
    with bpy.data.libraries.load(path) as (src, dst):
        dst.objects = [o for o in src.objects if o.startswith(asset + "_LOD")]
    obs = {}
    for o in dst.objects:
        sc.collection.objects.link(o); o.data.materials.clear(); o.data.materials.append(mat)
        o.hide_render = True; obs[o.name[-4:]] = o
    return obs

def frame(ob, az, el, scale=1.0, target=None, dist=None):
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    c = target if target is not None else (lo + hi) / 2
    rad = (hi - lo).length / 2
    d = dist if dist is not None else rad / math.sin(math.radians(20)) * 0.92 * scale
    dirv = Vector((math.cos(math.radians(el)) * math.sin(math.radians(az)), -math.cos(math.radians(el)) * math.cos(math.radians(az)), math.sin(math.radians(el))))
    cam.location = c + dirv * d
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()

def shot(name, size):
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)

CLOSE = {"M_Veg_Gorse_01": 0.62, "M_Veg_Heather_03": 0.7, "M_Veg_SeaThrift_01": 0.75, "M_Veg_Grass_Marram_02": 0.55,
         "M_Veg_Bracken_01": 0.6, "M_Veg_Hawthorn_01": 0.55}
for asset in vegkit.VARIANTS:
    obs = load(asset)
    o = obs["LOD0"]; o.hide_render = False
    frame(o, -35, 14); shot("hero_" + asset, 384)
    if asset in CLOSE:
        bb = [Vector(c) for c in o.bound_box]
        hi = max(v.z for v in bb)
        t = Vector((0, 0, hi * CLOSE[asset]))
        frame(o, -30, 18, target=t, dist=max(1.6, hi * 0.9)); shot("close_" + asset, 512)
    if asset in ("M_Veg_Gorse_01", "M_Veg_Grass_Marram_02", "M_Veg_Hawthorn_01"):
        for lod in ("LOD0", "LOD1", "LOD2"):
            for k, ob in obs.items():
                ob.hide_render = k != lod
            frame(obs["LOD0"], -35, 14); shot("lod_%s_%s" % (asset, lod), 256)
    for ob in obs.values():
        ob.hide_render = True
print("G1 renders ok", OUT)
