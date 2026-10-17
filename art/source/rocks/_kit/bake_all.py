"""K1 bake (Blender, one heavy slot): for each asset given, import the full Poly Haven scan (HP), move it to studs
(1 m = 3 studs) with the origin at the base centre, decimate a copy to the kit budget (UVs kept), then Cycles-bake
  * NOR: the HP shading normal (geometry + the scan's own normal map) onto the LP, tangent space OpenGL, BAKE px
  * MASK: R = height in the piece (0 base, 1 top), G = up-facing (normal Z * 0.5 + 0.5)
Writes build/k1/work/<Asset>_{NOR,MASK}.png, <Asset>_lp.blend (the LP mesh) and <Asset>.json (size, tris).
  blender-run.sh art/source/rocks/_kit/bake_all.py -- M_Rock_Boulder_01 [...]"""
import json, os, sys, time
import bpy, bmesh
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import piece, SRC, WORK, BAKE

def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def bake_one(asset):
    t0 = time.time()
    p = piece(asset)
    clear()
    d = SRC + p["pid"] + "/"
    gl = [f for f in os.listdir(d) if f.endswith(".gltf")][0]
    bpy.ops.import_scene.gltf(filepath=d + gl, merge_vertices=True)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    hp = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    hp.scale = [s * 3.0 for s in hp.scale]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    vs = [v.co for v in hp.data.vertices]
    mn = [min(v[i] for v in vs) for i in range(3)]
    mx = [max(v[i] for v in vs) for i in range(3)]
    off = ((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2])
    hp.data.transform(__import__("mathutils").Matrix.Translation((-off[0], -off[1], -off[2])))
    size = [mx[i] - mn[i] for i in range(3)]
    hp.name = asset + "_HP"
    bm = bmesh.new(); bm.from_mesh(hp.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4); bm.to_mesh(hp.data); bm.free()
    if hp.data.uv_layers:
        hp.data.uv_layers.active_index = 0
    # LP
    lp = hp.copy(); lp.data = hp.data.copy(); lp.name = asset + "_LOD0"; lp.data.name = asset + "_LOD0"
    bpy.context.scene.collection.objects.link(lp)
    while len(lp.data.uv_layers) > 1:
        lp.data.uv_layers.remove(lp.data.uv_layers[-1])
    lp.data.uv_layers[0].name = "UVMap"
    n0 = tris(hp)
    orig = lp.data; orig.name = asset + "_src"
    bpy.context.view_layer.objects.active = lp
    bpy.ops.object.select_all(action="DESELECT"); lp.select_set(True)
    ratio = p["tris"] / max(n0, 1)
    for attempt in range(4):
        lp.data = orig.copy()
        m = lp.modifiers.new("dec", "DECIMATE"); m.ratio = min(1.0, ratio); m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="dec")
        n = tris(lp)
        print("K1DEC", asset, attempt, ratio, n, flush=True)
        if n <= p["tris"]:
            break
        ratio *= p["tris"] / n * 0.97
    lp.data.name = asset + "_LOD0"
    bm = bmesh.new(); bm.from_mesh(lp.data); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(lp.data); bm.free()
    lp.data.materials.clear()
    for poly in lp.data.polygons:
        poly.use_smooth = True
    # bake material on LP: image node active + mask emission
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.samples = 4; sc.cycles.device = "CPU"
    mat = bpy.data.materials.new("K1Bake"); mat.use_nodes = True; lp.data.materials.append(mat)
    nt = mat.node_tree; out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
    img = bpy.data.images.new("bake", BAKE, BAKE, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; nt.nodes.active = tex
    # NOR from HP
    hp.select_set(True); lp.select_set(True); bpy.context.view_layer.objects.active = lp
    ext = max(size) * 0.015
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_selected_to_active=True, cage_extrusion=ext,
                        max_ray_distance=ext * 3, margin=8, use_clear=True)
    os.makedirs(WORK, exist_ok=True)
    img.filepath_raw = WORK + asset + "_NOR.png"; img.file_format = "PNG"; img.save()
    # MASK (emission)
    geo = nt.nodes.new("ShaderNodeNewGeometry"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    sepn = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs[1].default_value = 0.0; mr.inputs[2].default_value = size[2]
    mn2 = nt.nodes.new("ShaderNodeMapRange"); mn2.inputs[1].default_value = -1.0; mn2.inputs[2].default_value = 1.0
    comb = nt.nodes.new("ShaderNodeCombineXYZ"); em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(geo.outputs["Position"], sep.inputs[0]); nt.links.new(sep.outputs[2], mr.inputs[0])
    nt.links.new(geo.outputs["Normal"], sepn.inputs[0]); nt.links.new(sepn.outputs[2], mn2.inputs[0])
    nt.links.new(mr.outputs[0], comb.inputs[0]); nt.links.new(mn2.outputs[0], comb.inputs[1])
    nt.links.new(comb.outputs[0], em.inputs[0]); nt.links.new(em.outputs[0], out.inputs[0])
    hp.select_set(False)
    sc.cycles.samples = 1
    bpy.ops.object.bake(type="EMIT", use_selected_to_active=False, margin=8, use_clear=True)
    img.filepath_raw = WORK + asset + "_MASK.png"; img.save()
    lp.data.materials.clear()
    bpy.data.libraries.write(WORK + asset + "_lp.blend", {lp.data}, compress=True)
    info = {"asset": asset, "lp_mesh": lp.data.name, "size_studs": size, "size_m": [s / 3 for s in size],
            "hp_tris": n0, "lp_tris": tris(lp), "seconds": round(time.time() - t0, 1)}
    json.dump(info, open(WORK + asset + ".json", "w"), indent=1)
    print("K1BAKE", json.dumps(info), flush=True)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for a in argv:
    try:
        bake_one(a)
    except Exception as e:
        import traceback; traceback.print_exc(); print("K1FAIL", a, e, flush=True)
