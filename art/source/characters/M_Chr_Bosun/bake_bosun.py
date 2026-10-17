"""Cycles bakes for M_Chr_Bosun, one texture set a run (Body or Harness; Fur comes from fur_textures.py).

Procedural look-dev shaders on the LOD0 meshes, driven by the per-vertex attributes from bosun.py:
  Body     black double coat: flow-aligned strands and clumps (the fur-direction normal detail), subtle brown
           sun-bleaching on the top line and long-coat tips, nose leather with nostrils, lip line, paw pads,
           dark brown eyes with a glossy cornea. _Wet: the coat darker, clumped (stronger, coarser clump normals,
           strands merged) and glossy.
  Harness  Hull Orange woven webbing and padding, retroreflective tape (microprism), stainless D-ring, black
           plastic buckles, neoprene grip. _Wet: fabric darker and glossier.
Outputs masters (PNG, bake size) to art/source/characters/M_Chr_Bosun/textures/raw/; finalize.py (system python3)
writes the shipping maps. Passes: ALB, RGH, MET, NOR (tangent, OpenGL), and ALB/RGH/NOR _Wet; plus SIG (signal mask).
"""
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "textures", "raw")
ASSET = "M_Chr_Bosun"


def srgb(h):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(lin(float(c)) for c in h)


class G:
    """Tiny node-graph builder."""

    def __init__(self, mat):
        mat.use_nodes = True
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.x = 0

    def node(self, kind, **props):
        n = self.nt.nodes.new(kind)
        n.location = (self.x, 0)
        self.x += 30
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, src, dst):
        self.nt.links.new(src, dst)

    def put(self, sock, v):
        if isinstance(v, bpy.types.NodeSocket):
            self.link(v, sock)
        else:
            sock.default_value = v

    def attr(self, name, out="Fac"):
        return self.node("ShaderNodeAttribute", attribute_name=name).outputs[out]

    def math(self, op, a, b=0.0, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.put(n.inputs[0], a)
        self.put(n.inputs[1], b)
        return n.outputs[0]

    def vmath(self, op, a, b=None, scale=None):
        n = self.node("ShaderNodeVectorMath", operation=op)
        self.put(n.inputs[0], a)
        if b is not None:
            self.put(n.inputs[1], b)
        if scale is not None:
            self.put(n.inputs["Scale"], scale)
        return n.outputs["Value" if op in ("DOT_PRODUCT", "LENGTH", "DISTANCE") else "Vector"]

    def lerp(self, a, b, t):
        """a + (b - a) * t for floats or colours (vectors)."""
        if isinstance(a, tuple) or isinstance(b, tuple) or (isinstance(a, bpy.types.NodeSocket) and a.type == "VECTOR") \
                or (isinstance(b, bpy.types.NodeSocket) and b.type == "VECTOR"):
            d = self.vmath("SUBTRACT", b, a)
            return self.vmath("ADD", a, self.vmath("SCALE", d, scale=t))
        return self.math("ADD", a, self.math("MULTIPLY", self.math("SUBTRACT", b, a), t))

    def remap(self, v, a, b, lo=0.0, hi=1.0):
        n = self.node("ShaderNodeMapRange", clamp=True)
        self.put(n.inputs["Value"], v)
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        n.inputs["To Min"].default_value = lo
        n.inputs["To Max"].default_value = hi
        return n.outputs["Result"]

    def noise(self, vec, scale, detail=2.0, rough=0.5, dist=0.0):
        n = self.node("ShaderNodeTexNoise")
        self.put(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = dist
        return n.outputs["Fac"]

    def voronoi(self, vec, scale, feature="F1", rand=1.0):
        n = self.node("ShaderNodeTexVoronoi", feature=feature)
        self.put(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = rand
        return n.outputs["Distance"]

    def wave(self, vec, scale, axis="X"):
        n = self.node("ShaderNodeTexWave", wave_type="BANDS", bands_direction=axis)
        self.put(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Distortion"].default_value = 0.6
        n.inputs["Detail"].default_value = 0.0
        return n.outputs["Fac"]


def body_graph(g, wet):
    P = g.node("ShaderNodeTexCoord").outputs["Object"]
    F = g.attr("flow", "Vector")
    longw, short, bleach = g.attr("long"), g.attr("short"), g.attr("bleach")
    nose, pad, lip, eye, eye_r = g.attr("nose"), g.attr("pad"), g.attr("lip"), g.attr("eye"), g.attr("eye_r")

    def stretched(k):
        d = g.vmath("DOT_PRODUCT", P, F)
        return g.vmath("SUBTRACT", P, g.vmath("SCALE", F, scale=g.math("MULTIPLY", d, 1.0 - 1.0 / k)))

    p8, p3 = stretched(9.0), stretched(3.2)
    strands_l = g.noise(p8, 70.0, 3.0, 0.55)
    strands_s = g.noise(p8, 150.0, 2.0, 0.5)
    strands = g.lerp(strands_l, strands_s, short)
    clump_scale = 9.0 if wet else 12.0
    edge = g.voronoi(p3, clump_scale, "DISTANCE_TO_EDGE")
    clump = g.remap(edge, 0.0, 0.10 if wet else 0.16)                    # 0 in the partings, 1 on the clump
    if wet:
        clump = g.math("POWER", clump, 0.45)                             # sharp wet partings
    clump = g.lerp(clump, g.math("MULTIPLY", clump, 0.35), short)
    big = g.noise(P, 3.0, 2.0, 0.5)
    # height for the normal: clumps + strands (wet: clumps dominate, strands merged)
    h = g.math("ADD", g.math("MULTIPLY", clump, 0.85 if wet else 0.55), g.math("MULTIPLY", strands, 0.18 if wet else 0.45))
    nostrils = None
    nos = []
    for sx in (1, -1):
        dpt = g.vmath("DISTANCE", P, (sx * 0.056, NOSE[1], NOSE[2] + 0.004))
        nos.append(g.remap(dpt, 0.010, 0.024, 1.0, 0.0))
    nostrils = g.math("MAXIMUM", nos[0], nos[1])
    cobble = g.remap(g.voronoi(P, 260.0, "DISTANCE_TO_EDGE"), 0.0, 0.08)
    h = g.lerp(h, g.math("SUBTRACT", g.math("MULTIPLY", cobble, 0.5), g.math("MULTIPLY", nostrils, 1.2)), nose)
    h = g.lerp(h, g.math("MULTIPLY", cobble, 0.4), pad)
    h = g.math("SUBTRACT", h, g.math("MULTIPLY", lip, 0.6))
    bump_k = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, eye), 0.85 if wet else 0.7)

    # albedo (linear)
    c_dark, c_light = (srgb((31, 30, 30)), srgb((35, 34, 34))) if wet else (srgb((35, 33, 33)), srgb((50, 46, 44)))
    tone = g.math("ADD", g.math("MULTIPLY", strands, 0.6), g.math("MULTIPLY", clump, 0.25), clamp=True)
    tone = g.math("ADD", tone, g.math("MULTIPLY", g.math("SUBTRACT", big, 0.5), 0.3), clamp=True)
    col = g.lerp(c_dark, c_light, tone)
    tips = g.math("MULTIPLY", bleach, g.remap(strands, 0.45, 0.75))
    tips = g.math("MULTIPLY", tips, g.math("ADD", 0.55, g.math("MULTIPLY", big, 0.9)), clamp=True)
    brown = srgb((40, 33, 30)) if wet else srgb((74, 58, 46))
    col = g.lerp(col, brown, g.math("MULTIPLY", tips, 0.35 if wet else 0.85))
    leather = g.lerp(srgb((40, 38, 38)) if not wet else srgb((33, 32, 32)), srgb((31, 30, 30)), g.math("MAXIMUM", nostrils, g.math("SUBTRACT", 1.0, cobble)))
    col = g.lerp(col, leather, nose)
    col = g.lerp(col, srgb((44, 41, 40)) if not wet else srgb((35, 33, 33)), pad)
    col = g.lerp(col, srgb((31, 30, 30)), g.math("MINIMUM", g.math("MULTIPLY", lip, 1.4), 1.0))
    iris = g.remap(eye_r, 0.50, 0.56, 1.0, 0.0)
    pupil = g.remap(eye_r, 0.20, 0.24, 1.0, 0.0)
    eye_col = g.lerp(g.lerp(srgb((52, 40, 34)), srgb((78, 58, 44)), iris), srgb((30, 30, 30)), pupil)
    eye_col = g.lerp(eye_col, srgb((60, 46, 38)), g.math("MULTIPLY", g.math("MULTIPLY", iris, g.math("SUBTRACT", 1.0, pupil)),
                                                          g.noise(P, 900.0, 1.0)))
    col = g.lerp(col, eye_col, eye)

    # roughness
    rgh = g.math("ADD", 0.26 if wet else 0.56, g.math("MULTIPLY", strands, 0.12))
    if wet:
        rgh = g.math("SUBTRACT", rgh, g.math("MULTIPLY", clump, 0.08))
    rgh = g.lerp(rgh, 0.22 if wet else 0.44, nose)
    rgh = g.lerp(rgh, 0.30 if wet else 0.58, pad)
    rgh = g.lerp(rgh, 0.22 if wet else 0.40, g.math("MINIMUM", lip, 1.0))
    rgh = g.lerp(rgh, 0.05, eye)
    return col, rgh, 0.0, h, bump_k, 0.006 if wet else 0.004, None


def harness_graph(g, wet):
    P = g.node("ShaderNodeTexCoord").outputs["Object"]
    tape, metal, plastic, grip = g.attr("tape"), g.attr("metal"), g.attr("plastic"), g.attr("grip")
    fabric = g.math("SUBTRACT", 1.0, g.math("ADD", g.math("ADD", tape, metal), g.math("ADD", plastic, grip)), clamp=True)
    weave = g.math("MULTIPLY", g.wave(P, 260.0, "X"), g.wave(P, 260.0, "Y"))
    weave = g.math("ADD", weave, g.math("MULTIPLY", g.wave(P, 260.0, "Z"), 0.5))
    grime = g.noise(P, 6.0, 4.0, 0.6)
    prism = g.remap(g.voronoi(P, 700.0, "F1"), 0.0, 0.5)
    pores = g.noise(P, 500.0, 1.0)
    h = g.math("MULTIPLY", weave, fabric)
    h = g.math("ADD", h, g.math("MULTIPLY", g.math("MULTIPLY", prism, 0.4), tape))
    h = g.math("ADD", h, g.math("MULTIPLY", g.math("MULTIPLY", pores, 0.6), grip))
    orange = srgb((168, 66, 22)) if wet else srgb((226, 94, 30))
    orange_d = srgb((150, 60, 22)) if wet else srgb((196, 82, 30))
    col = g.lerp(orange, orange_d, g.remap(grime, 0.35, 0.75))
    col = g.lerp(col, srgb((200, 203, 206)) if wet else srgb((212, 215, 218)), tape)
    col = g.lerp(col, srgb((205, 207, 210)), metal)
    col = g.lerp(col, srgb((33, 33, 35)) if wet else srgb((40, 40, 42)), plastic)
    col = g.lerp(col, srgb((32, 32, 34)) if wet else srgb((44, 44, 46)), grip)
    rgh = g.math("ADD", 0.38 if wet else 0.74, g.math("MULTIPLY", weave, 0.06))
    rgh = g.lerp(rgh, 0.18 if wet else 0.30, tape)
    rgh = g.lerp(rgh, 0.18 if wet else 0.26, metal)
    rgh = g.lerp(rgh, 0.24 if wet else 0.46, plastic)
    rgh = g.lerp(rgh, 0.34 if wet else 0.68, grip)
    bump_k = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, metal), 0.22)
    return col, rgh, metal, h, bump_k, 0.002, fabric


NOSE = (0.0, 0.0, 0.0)


def find_nose():
    """Front centre of the nose leather (studs), from the nose attribute of the head part."""
    global NOSE
    import numpy as np
    me = bpy.data.objects["%s_BodyHead_LOD0" % ASSET].data
    n = len(me.vertices)
    V = np.zeros(n * 3)
    me.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    w = np.zeros(n)
    me.attributes["nose"].data.foreach_get("value", w)
    sel = w > 0.5
    NOSE = (0.0, float(V[sel, 1].min()) + 0.006, float(np.average(V[sel, 2], weights=w[sel])))
    print("[bake] nose front", NOSE)


GRAPHS = {"Body": (body_graph, ["BodyHead", "BodyFore", "BodyHind"]), "Harness": (harness_graph, ["Harness"])}


def build_material(mat, set_name, wet, kind, image):
    g = G(mat)
    col, rgh, met, h, bump_k, bump_d, sig = GRAPHS[set_name][0](g, wet)
    out = g.node("ShaderNodeOutputMaterial")
    if kind == "NOR":
        bsdf = g.node("ShaderNodeBsdfPrincipled")
        bump = g.node("ShaderNodeBump")
        g.put(bump.inputs["Height"], h)
        g.put(bump.inputs["Strength"], bump_k)
        bump.inputs["Distance"].default_value = bump_d
        g.link(bump.outputs["Normal"], bsdf.inputs["Normal"])
        g.link(bsdf.outputs["BSDF"], out.inputs["Surface"])
    else:
        em = g.node("ShaderNodeEmission")
        val = {"ALB": col, "RGH": rgh, "MET": met, "SIG": sig if sig is not None else 0.0}[kind]
        if isinstance(val, bpy.types.NodeSocket) and val.type == "VECTOR" or isinstance(val, tuple):
            g.put(em.inputs["Color"], val if not isinstance(val, tuple) else val + (1.0,))
        else:
            comb = g.node("ShaderNodeCombineXYZ")
            for i in range(3):
                g.put(comb.inputs[i], val)
            g.link(comb.outputs[0], em.inputs["Color"])
        g.link(em.outputs[0], out.inputs["Surface"])
    tex = g.node("ShaderNodeTexImage")
    tex.image = image
    g.nt.nodes.active = tex


def bake_set(set_name, size):
    import bake as libbake
    os.makedirs(RAW, exist_ok=True)
    scene = bpy.context.scene
    device = libbake.setup_cycles({}, 16)
    scene.render.bake.margin = 24
    scene.render.bake.margin_type = "EXTEND"
    scene.render.bake.use_clear = True
    find_nose()
    objs = [bpy.data.objects["%s_%s_LOD0" % (ASSET, p)] for p in GRAPHS[set_name][1]]
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
        o.hide_render = False
    bpy.context.view_layer.objects.active = objs[0]
    mat = objs[0].data.materials[0]
    passes = [("ALB", False), ("RGH", False), ("MET", False), ("NOR", False), ("ALB", True), ("RGH", True), ("NOR", True)]
    if set_name == "Harness":
        passes.append(("SIG", False))
    import time
    for kind, wet in passes:
        t0 = time.time()
        stem = "T_Bosun_%s_%s%s" % (set_name, kind, "_Wet" if wet else "")
        img = bpy.data.images.new(stem, size, size, alpha=False, float_buffer=False)
        img.colorspace_settings.name = "sRGB" if kind == "ALB" else "Non-Color"
        build_material(mat, set_name, wet, kind, img)
        scene.cycles.samples = 4 if kind in ("MET", "SIG") else 16
        if kind == "NOR":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", normal_r="POS_X", normal_g="POS_Y", normal_b="POS_Z",
                                margin=24, use_clear=True)
        else:
            bpy.ops.object.bake(type="EMIT", margin=24, use_clear=True)
        img.filepath_raw = os.path.join(RAW, stem + ".png")
        img.file_format = "PNG"
        img.save()
        print("[bake] %s %d px %.1f s (%s)" % (stem, size, time.time() - t0, device))
        bpy.data.images.remove(img)
