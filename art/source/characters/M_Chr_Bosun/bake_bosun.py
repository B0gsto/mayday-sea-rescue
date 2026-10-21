"""Cycles bakes for M_Chr_Bosun, one texture set a run (Body or Harness; Fur comes from fur_textures.py).

Procedural look-dev shaders on the LOD0 meshes, driven by the per-vertex attributes from bosun.py:
  Body     black double coat: flow-aligned strands and clumps (the fur-direction normal detail), brown-black base
           ~(31,27,24) sRGB (25-35), grey-brown sheen ~(50,45,40) on the back / ears, lighter sun-faded tips on the top
           line (sunfade, else bleach + up-facing ear), patches, streaks, shallow crease AO; a per-channel luma floor
           (check_textures non-metal 20) keeps the 1st percentile up (only nostrils / pupils go below it). Pebbled
           nose leather, dark lips / lid rims, pads, nails, dark brown iris + near-black pupil under a 0.05-roughness
           cornea; mouth_inner (dark gums) and tongue (pink, papillae, median groove) when the attributes exist.
           _Wet: ~0.8x sRGB coat (median luma ~22, floor 20), roughness ~0.2-0.3, sharper clumps, plus water runnels
           and droplet domes concentrated on the belly underside, chest front and tail (normal facing + body bounds,
           "tail" attribute when present, a little on the long coat).
  Harness  Hull Orange woven webbing and padding; stitch rows sized to read at 2 m (dark groove, fat pale thread
           dashes in relief; "tack" mask = solid box-X satin if present); salt tide-mark patches with crusty white
           rims, edge / stitch-groove salt bloom, more on the lower straps ("lower" mask, else height); frayed faded
           edges; banded retroreflective tape (checker segments, microprisms, seals, low roughness); stainless D-ring,
           black acetal buckles, neoprene grip. _Wet: fabric darker and glossier, salt dissolved.
Attributes missing from the meshes (HAS) fall back gracefully (masks read 0, sunfade / iris use older fields).
Outputs masters (PNG, bake size) to art/source/characters/M_Chr_Bosun/textures/raw/; finalize.py (system python3)
writes the shipping maps. Passes: ALB, RGH, MET, NOR (tangent, OpenGL), and ALB/RGH/NOR _Wet; plus SIG (signal mask).
"""
import math
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
        self.put(n.inputs["From Min"], a)
        self.put(n.inputs["From Max"], b)
        self.put(n.inputs["To Min"], lo)
        self.put(n.inputs["To Max"], hi)
        return n.outputs["Result"]

    def sep(self, vec):
        n = self.node("ShaderNodeSeparateXYZ")
        self.put(n.inputs[0], vec)
        return n.outputs[0], n.outputs[1], n.outputs[2]

    def checker(self, vec, scale):
        n = self.node("ShaderNodeTexChecker")
        self.put(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Color1"].default_value = (1.0, 1.0, 1.0, 1.0)
        n.inputs["Color2"].default_value = (0.0, 0.0, 0.0, 1.0)
        return n.outputs["Fac"]

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


HAS = set()           # attribute names present on the meshes being baked (filled by bake_set)


def A(g, name, fallback=0.0):
    """Attribute mask, or the fallback (float / socket) when the geometry does not carry it yet."""
    return g.attr(name) if name in HAS else fallback


def colscale(g, c, k):
    return g.vmath("SCALE", c, scale=k)


def up_facing(g):
    n = g.node("ShaderNodeNewGeometry").outputs["Normal"]
    return g.math("MAXIMUM", g.vmath("DOT_PRODUCT", n, (0.0, 0.0, 1.0)), 0.0)


def local_ao(g, dist, samples=8):
    n = g.node("ShaderNodeAmbientOcclusion", samples=samples, inside=False, only_local=True)
    n.inputs["Distance"].default_value = dist
    return n.outputs["AO"]


def facing(g, axis):
    """max(N . axis, 0) with the geometry normal (world; the parts are not rotated)."""
    n = g.node("ShaderNodeNewGeometry").outputs["Normal"]
    return g.math("MAXIMUM", g.vmath("DOT_PRODUCT", n, axis), 0.0)


def drops(g, vec, scale, density):
    """Water droplets: (dome height 0..1, mask). One droplet per Voronoi cell where the cell's random value passes
    the density (float / socket), radius 0.16-0.30 of a cell."""
    v = g.node("ShaderNodeTexVoronoi", feature="F1")
    g.put(v.inputs["Vector"], vec)
    v.inputs["Scale"].default_value = scale
    v.inputs["Randomness"].default_value = 0.9
    sc = g.node("ShaderNodeSeparateColor")
    g.link(v.outputs["Color"], sc.inputs[0])
    rnd, rnd2 = sc.outputs["Red"], sc.outputs["Green"]
    r = g.math("ADD", 0.16, g.math("MULTIPLY", rnd2, 0.14))
    q = g.math("DIVIDE", v.outputs["Distance"], r)
    dome = g.math("SQRT", g.math("MAXIMUM", g.math("SUBTRACT", 1.0, g.math("MULTIPLY", q, q)), 0.0))
    present = g.math("GREATER_THAN", rnd, g.math("SUBTRACT", 1.0, density))
    dome = g.math("MULTIPLY", dome, present)
    return dome, g.remap(dome, 0.0, 0.08)


def runnels(g, vec, scale, width):
    """Thin broken water runnels: the edges of Voronoi cells on a stretched vector, interrupted by noise."""
    line = g.remap(g.voronoi(vec, scale, "DISTANCE_TO_EDGE"), 0.0, width, 1.0, 0.0)
    return g.math("MULTIPLY", line, g.remap(g.noise(vec, scale * 0.6, 2.0, 0.5), 0.42, 0.58))


def body_graph(g, wet):
    P = g.node("ShaderNodeTexCoord").outputs["Object"]
    L = BODY_L                                                        # nose-to-tail length in object units
    F = g.attr("flow", "Vector")
    longw, short, bleach = g.attr("long"), g.attr("short"), g.attr("bleach")
    nose, pad, lip, eye = g.attr("nose"), g.attr("pad"), g.attr("lip"), g.attr("eye")
    eye_r = g.attr("eye_r") if "eye_r" in HAS else 3.14
    nail, web, lid, cornea = A(g, "nail"), A(g, "web"), A(g, "lid"), A(g, "cornea")
    tear, brow, ear = A(g, "tear"), A(g, "brow"), A(g, "ear")
    tongue, mouth = A(g, "tongue"), A(g, "mouth_inner")
    upz = up_facing(g)
    # sun fade: geometry's sunfade, else the old bleach (top line) plus the up-facing ear tops
    fade = A(g, "sunfade", g.math("MAXIMUM", bleach, g.math("MULTIPLY", ear, g.remap(upz, 0.2, 0.8))))
    skin = g.math("ADD", g.math("ADD", nose, pad), g.math("ADD", g.math("ADD", eye, nail), g.math("ADD", lid, cornea)))
    skin = g.math("MINIMUM", g.math("ADD", skin, g.math("ADD", tongue, mouth)), 1.0)
    coat = g.math("SUBTRACT", 1.0, skin, clamp=True)

    def stretched(k, vec=P):
        d = g.vmath("DOT_PRODUCT", vec, F)
        return g.vmath("SUBTRACT", vec, g.vmath("SCALE", F, scale=g.math("MULTIPLY", d, 1.0 - 1.0 / k)))

    p8, p3 = stretched(9.0), stretched(3.2)
    strands_l = g.noise(p8, 70.0, 3.0, 0.55)
    strands_s = g.noise(p8, 150.0, 2.0, 0.5)
    strands = g.lerp(strands_l, strands_s, g.math("MAXIMUM", short, brow))
    streak = g.remap(g.noise(stretched(14.0), 38.0, 2.0, 0.5), 0.35, 0.65)        # long strand-direction streaks
    clump_scale = 6.5 if wet else 12.0
    edge = g.voronoi(p3, clump_scale, "DISTANCE_TO_EDGE")
    clump = g.remap(edge, 0.0, 0.12 if wet else 0.16)                      # 0 in the partings, 1 on the clump
    if wet:
        clump = g.math("POWER", clump, 0.35)                               # sharp wet partings, merged strands
    clump = g.lerp(clump, g.math("MULTIPLY", clump, 0.35), short)
    big = g.noise(P, 3.0, 2.0, 0.5)
    patch = g.remap(g.noise(P, 1.6, 3.0, 0.55, 0.3), 0.3, 0.7)              # low-frequency patchy coat variation
    ao = local_ao(g, 0.10)                                                 # studs (1/3 m)

    # ---- wet drip zones: belly underside, chest front, tail (+ the long coat a little), coat only
    zone = runs = dmask = None
    if wet:
        X, Y, Z = g.sep(P)
        yr = g.remap(Y, BODY_B[0][1], BODY_B[1][1])                         # 0 nose, 1 tail end
        zr = g.remap(Z, BODY_B[0][2], BODY_B[1][2])
        belly = g.remap(facing(g, (0.0, 0.0, -1.0)), 0.25, 0.75)
        chest = g.math("MULTIPLY", g.remap(facing(g, (0.0, -1.0, 0.0)), 0.2, 0.7),
                       g.math("MULTIPLY", g.remap(yr, 0.18, 0.42, 1.0, 0.0), g.remap(zr, 0.55, 0.72, 1.0, 0.0)))
        tail = A(g, "tail", g.remap(yr, 0.84, 0.93))
        zone = g.math("MAXIMUM", g.math("MAXIMUM", belly, chest), tail)
        zone = g.math("MAXIMUM", zone, g.math("MULTIPLY", longw, 0.35))
        zone = g.math("MULTIPLY", g.math("MINIMUM", zone, 1.0), coat)
        # runnels: down the sides / chest (stretched along Z), along the flow under the belly and on the tail
        vert = g.vmath("MULTIPLY", P, (1.0, 1.0, 0.14))
        rv = runnels(g, vert, 1.0 / (0.05 * L), 0.035)
        rf = runnels(g, stretched(7.0), 1.0 / (0.04 * L), 0.04)
        runs = g.math("MULTIPLY", g.lerp(rv, rf, g.math("MAXIMUM", belly, tail)), zone)
        dome, dm = drops(g, P, 1.0 / (0.016 * L), g.math("ADD", 0.06, g.math("MULTIPLY", zone, 0.55)))
        dome2, dm2 = drops(g, g.vmath("ADD", P, (0.37, 0.11, 0.73)), 1.0 / (0.007 * L),
                           g.math("MULTIPLY", zone, 0.35))                  # fine spray of small beads
        dome = g.math("MULTIPLY", g.math("MAXIMUM", dome, g.math("MULTIPLY", dome2, 0.6)), coat)
        dmask = g.math("MULTIPLY", g.math("MAXIMUM", dm, dm2), coat)

    # ---- height for the normal
    h = g.math("ADD", g.math("MULTIPLY", clump, 1.0 if wet else 0.55), g.math("MULTIPLY", strands, 0.12 if wet else 0.45))
    h = g.math("ADD", h, g.math("MULTIPLY", streak, 0.05 if wet else 0.12))
    if wet:
        h = g.math("ADD", h, g.math("MULTIPLY", runs, 0.7))                 # water-filled runnels sit proud of the parting
        h = g.math("ADD", h, g.math("MULTIPLY", dome, 1.8))                 # droplet domes
    nos = []
    for sx in (1, -1):
        dpt = g.vmath("DISTANCE", P, (sx * 0.056, NOSE[1], NOSE[2] + 0.004))
        nos.append(g.remap(dpt, 0.010, 0.024, 1.0, 0.0))
    nostrils = g.math("MAXIMUM", nos[0], nos[1])
    cell = g.remap(g.voronoi(P, 260.0, "DISTANCE_TO_EDGE"), 0.0, 0.10)     # nose pebbles (0 in the cracks)
    pebble = g.math("POWER", cell, 0.5)
    h = g.lerp(h, g.math("SUBTRACT", g.math("MULTIPLY", pebble, 0.6), g.math("MULTIPLY", nostrils, 1.2)), nose)
    papil = g.remap(g.voronoi(P, 420.0, "DISTANCE_TO_EDGE"), 0.0, 0.12)     # pad papillae
    h = g.lerp(h, g.math("ADD", g.math("MULTIPLY", papil, 0.5), g.math("MULTIPLY", g.noise(P, 90.0, 2.0), 0.2)), pad)
    ridges = g.noise(stretched(20.0), 220.0, 1.0, 0.5)                      # nail growth ridges along the flow
    h = g.lerp(h, g.math("MULTIPLY", ridges, 0.25), nail)
    h = g.lerp(h, g.math("MULTIPLY", g.noise(P, 300.0, 1.0), 0.15), g.math("MAXIMUM", lid, lip))
    h = g.math("SUBTRACT", h, g.math("MULTIPLY", lip, 0.25))
    # tongue: filiform papillae and a shallow median groove (tongue runs along Y, centred on x = 0)
    X0 = g.sep(P)[0]
    groove = g.remap(g.math("ABSOLUTE", X0), 0.0, 0.004 * L, 1.0, 0.0)
    tpap = g.remap(g.voronoi(P, 1.0 / (0.0018 * L), "F1"), 0.0, 0.5, 1.0, 0.0)
    h = g.lerp(h, g.math("SUBTRACT", g.math("MULTIPLY", tpap, 0.35), g.math("MULTIPLY", groove, 0.6)), tongue)
    h = g.lerp(h, g.math("MULTIPLY", g.noise(P, 1.0 / (0.004 * L), 2.0), 0.3), mouth)
    smooth_k = g.math("SUBTRACT", 1.0, g.math("MAXIMUM", eye, cornea), clamp=True)
    bump_k = g.math("MULTIPLY", smooth_k, 0.85 if wet else 0.7)

    # ---- albedo (linear). Coat: brown-black, sRGB ~25-35 around (31,27,24), R > G > B, warm undertone
    c_dark, c_mid, c_light = srgb((44, 34, 26)), srgb((60, 46, 33)), srgb((78, 59, 41))   # r6: charcoal-brown, luma ~34-56 (r5 25-40 read as a silhouette)
    tone = g.math("ADD", g.math("MULTIPLY", strands, 0.55), g.math("MULTIPLY", clump, 0.25), clamp=True)
    tone = g.math("ADD", tone, g.math("MULTIPLY", g.math("SUBTRACT", streak, 0.5), 0.25), clamp=True)
    tone = g.math("ADD", tone, g.math("MULTIPLY", g.math("SUBTRACT", patch, 0.5), 0.45), clamp=True)
    col = g.lerp(g.lerp(c_dark, c_mid, g.math("MULTIPLY", tone, 2.0, clamp=True)), c_light,
                 g.math("MULTIPLY", g.math("SUBTRACT", tone, 0.5), 2.0, clamp=True))
    # grey-brown sheen on the back / ears, lighter sun-faded strand tips on the top line, patchy
    tips = g.remap(strands, 0.40, 0.72)
    fadek = g.math("MULTIPLY", g.math("POWER", g.math("MAXIMUM", fade, 0.0), 0.7), g.math("ADD", 0.55, g.math("MULTIPLY", tips, 0.6)))
    fadek = g.math("MULTIPLY", fadek, g.math("ADD", 0.6, g.math("MULTIPLY", g.math("ADD", big, patch), 0.55)), clamp=True)
    fade_col = g.lerp(srgb((96, 72, 50)), srgb((130, 96, 64)), g.math("MULTIPLY", tips, g.remap(fade, 0.4, 0.9)))
    col = g.lerp(col, fade_col, fadek)
    # r6: warm tip sheen on the clump crests (Roblox has no sheen lobe: albedo + lower roughness carry it)
    crest = g.math("MULTIPLY", g.math("MULTIPLY", g.remap(clump, 0.55, 1.0), tips), g.math("SUBTRACT", 1.0, short), clamp=True)
    col = g.lerp(col, srgb((88, 68, 49)), g.math("MULTIPLY", crest, 0.30 if wet else 0.45))
    # crease AO and clump partings (shallow: the floor below keeps the 1st percentile up)
    occl = g.math("MULTIPLY", g.remap(ao, 0.2, 1.0, 0.84, 1.0), g.remap(clump, 0.0, 0.5, 0.92, 1.0))
    col = colscale(g, col, g.lerp(1.0, occl, coat))
    # tear stain (wet fur below the inner corner)
    col = g.lerp(col, srgb((32, 27, 24)), g.math("MULTIPLY", tear, 0.6))
    # nose leather: dark grey-brown pebbles, darker cracks; nostrils near-black (tiny, exempt from the floor)
    leather = g.lerp(srgb((28, 26, 25)), srgb((46, 42, 39)), pebble)          # r6: matte grey-brown pebbles, dark cracks
    col = g.lerp(col, leather, nose)
    # lips / flews darker
    col = g.lerp(col, srgb((30, 26, 24)), g.math("MINIMUM", g.math("MULTIPLY", lip, 0.9), 0.8))   # softer lip line (seam)
    # paw pads, the fur webbing between the toes, nails (dark horn)
    col = g.lerp(col, g.lerp(srgb((27, 25, 24)), srgb((34, 32, 30)), papil), pad)
    col = g.lerp(col, colscale(g, srgb((27, 24, 22)), g.remap(ao, 0.2, 1.0, 0.85, 1.0)), web)
    col = g.lerp(col, g.lerp(srgb((28, 25, 23)), srgb((42, 37, 32)), ridges), nail)
    # eyelid rim
    col = g.lerp(col, srgb((24, 22, 21)), lid)
    if wet:
        col = colscale(g, col, g.lerp(0.40, 0.78, skin))                  # linear; soaked coat ~(25,22,19), median luma ~22
    # luma floor (check_textures non-metal 20): per-channel max keeps the warm hue; dry (23,21,19) ~21.3, wet (22,20,18) ~20.3
    col = colscale(g, col, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", A(g, "harn_ao"), 0.55)))   # r5: strap contact shadow
    col = g.vmath("MAXIMUM", col, srgb((22, 20, 18)) if wet else srgb((26, 22, 19)))
    col = g.lerp(col, srgb((17, 16, 16)), g.math("MULTIPLY", nostrils, nose))
    # mouth: dark gums / inner mouth, pink tongue with paler papillae and a darker groove (not darkened when wet)
    gum = g.lerp(srgb((52, 30, 31)), srgb((66, 39, 38)), g.noise(P, 1.0 / (0.006 * L), 2.0))
    col = g.lerp(col, gum, mouth)
    tcol = g.lerp(srgb((178, 86, 92)), srgb((198, 104, 108)), tpap)
    tcol = g.lerp(tcol, srgb((150, 68, 76)), g.math("MULTIPLY", groove, 0.7))
    col = g.lerp(col, tcol, tongue)
    # eye: near-black pupil, dark brown iris (fibres, collarette, dark limbal ring), little dark sclera
    R = 0.84 if "iris" in HAS else 0.53                                     # iris edge radius (rad from the axis)
    iris_m = g.attr("iris") if "iris" in HAS else g.remap(eye_r, 0.50, 0.56, 1.0, 0.0)
    pupil = g.remap(eye_r, 0.34 * R, 0.38 * R, 1.0, 0.0)
    limbal = g.math("MULTIPLY", g.remap(eye_r, 0.76 * R, 0.95 * R), iris_m)
    fibres = g.noise(P, 900.0, 2.0, 0.6)
    iris_col = g.lerp(srgb((112, 70, 34)), srgb((76, 47, 24)), g.remap(fibres, 0.35, 0.65))   # r6: readable warm brown
    iris_col = g.lerp(iris_col, srgb((140, 92, 44)), g.math("MULTIPLY", g.remap(eye_r, 0.38 * R, 0.52 * R, 1.0, 0.0), 0.55))
    iris_col = g.lerp(iris_col, srgb((28, 21, 17)), limbal)
    eye_col = g.lerp(srgb((44, 34, 30)), iris_col, iris_m)
    eye_col = g.lerp(eye_col, srgb((12, 11, 11)), pupil)
    col = g.lerp(col, eye_col, g.math("MAXIMUM", eye, g.math("MULTIPLY", cornea, iris_m)))

    # ---- roughness
    if wet:
        rgh = g.math("ADD", 0.19, g.math("MULTIPLY", strands, 0.08))       # round 4: soaked coat ~0.25-0.35
        rgh = g.math("ADD", rgh, g.math("MULTIPLY", g.math("SUBTRACT", 1.0, clump), 0.05))
        rgh = g.lerp(rgh, 0.08, runs)                                      # water runnels
        rgh = g.lerp(rgh, 0.03, dmask)                                     # droplets
    else:
        rgh = g.math("ADD", 0.52, g.math("MULTIPLY", strands, 0.26))       # r6: dry range ~0.45-0.85 (r5 0.66-0.74)
        rgh = g.math("ADD", rgh, g.math("MULTIPLY", g.math("SUBTRACT", 1.0, clump), 0.12))   # partings dull
        rgh = g.math("ADD", rgh, g.math("MULTIPLY", fadek, 0.06))           # sun-faded tips drier
        rgh = g.math("ADD", rgh, g.math("MULTIPLY", g.math("SUBTRACT", patch, 0.5), 0.14))  # patchy sheen
        rgh = g.math("SUBTRACT", rgh, g.math("MULTIPLY", crest, 0.28))      # glossy clump crests (tip sheen)
    moist = g.remap(g.noise(P, 40.0, 2.0, 0.5), 0.45, 0.65)
    nose_r = g.lerp(0.86 if not wet else 0.52, 0.72 if not wet else 0.40, pebble)   # r6: matte leather (r5 0.18-0.26 read as a shiny blob)
    nose_r = g.lerp(nose_r, 0.62 if not wet else 0.34, g.math("MULTIPLY", moist, g.math("MULTIPLY", pebble, 0.6)))
    rgh = g.lerp(rgh, nose_r, nose)
    rgh = g.lerp(rgh, 0.24 if wet else 0.50, g.math("MINIMUM", lip, 1.0))
    rgh = g.lerp(rgh, g.lerp(0.42 if wet else 0.78, 0.36 if wet else 0.66, papil), pad)
    rgh = g.lerp(rgh, 0.30 if wet else 0.62, web)
    rgh = g.lerp(rgh, g.lerp(0.20 if wet else 0.30, 0.26 if wet else 0.40, ridges), nail)
    rgh = g.lerp(rgh, 0.14 if wet else 0.20, lid)
    rgh = g.lerp(rgh, 0.07, tear)
    rgh = g.lerp(rgh, 0.22 if wet else 0.30, mouth)
    rgh = g.lerp(rgh, g.lerp(0.13 if wet else 0.32, 0.17 if wet else 0.40, tpap), tongue)
    rgh = g.lerp(rgh, 0.08, eye)
    rgh = g.lerp(rgh, 0.04 if wet else 0.05, cornea)                     # wet cornea: a sharp specular highlight
    return col, rgh, 0.0, h, bump_k, 0.006 if wet else 0.004, coat


def harness_graph(g, wet):
    P = g.node("ShaderNodeTexCoord").outputs["Object"]
    L = BODY_L
    tape, metal, plastic, grip = g.attr("tape"), g.attr("metal"), g.attr("plastic"), g.attr("grip")
    stitch, edge, padding, buckle = A(g, "stitch"), A(g, "edge"), A(g, "padding"), A(g, "buckle")
    edge = g.remap(edge, 0.6, 1.0)                          # interpolated across the face: keep only the edge band
    tack = A(g, "tack")                                     # optional box-X tack mask (solid satin thread)
    metal = g.math("MAXIMUM", metal, buckle)                 # round 4: steel buckles / tri-glides
    hard = g.math("ADD", g.math("ADD", tape, metal), g.math("ADD", plastic, grip))
    fabric = g.math("SUBTRACT", 1.0, hard, clamp=True)
    ao = local_ao(g, 0.03)
    Z = g.sep(P)[2]
    low = A(g, "lower", g.remap(g.remap(Z, SET_B[0][2], SET_B[1][2]), 0.15, 0.65, 1.0, 0.0))  # lower straps: more salt
    # woven webbing: two crossing yarn sets plus yarn slub; padding: puffy cells with a ripstop grid
    if "along" in HAS:   # round 5: woven nylon webbing in strap space: 2/2 twill ribs plus warp ribs and weft picks
        al, ac = g.attr("along"), g.attr("across")
        tw = g.math("SINE", g.math("MULTIPLY", g.math("ADD", al, ac), 2 * math.pi / 0.0040))
        rib = g.math("SINE", g.math("MULTIPLY", ac, 2 * math.pi / 0.0030))
        pick = g.math("SINE", g.math("MULTIPLY", al, 2 * math.pi / 0.0026))
        weave = g.math("ADD", g.math("MULTIPLY", tw, 0.30), g.math("ADD", g.math("MULTIPLY", rib, 0.12),
                                                                     g.math("MULTIPLY", pick, 0.08)))
        weave = g.math("ADD", weave, 0.5, clamp=True)
    else:
        weave = g.math("MULTIPLY", g.wave(P, 260.0, "X"), g.wave(P, 260.0, "Y"))
        weave = g.math("ADD", weave, g.math("MULTIPLY", g.wave(P, 260.0, "Z"), 0.5))
    slub = g.noise(P, 120.0, 2.0, 0.5)
    puff = g.remap(g.voronoi(P, 12.0, "DISTANCE_TO_EDGE"), 0.0, 0.25)
    rip = g.math("MULTIPLY", g.wave(P, 140.0, "X"), g.wave(P, 140.0, "Z"))
    grime = g.noise(P, 6.0, 4.0, 0.6)
    # stitching, sized to read at 2 m: dark groove either side, fat pale thread dashes (box-X tacks solid)
    groove = g.math("MULTIPLY", g.remap(stitch, 0.50, 0.82), fabric)
    line = g.math("MULTIPLY", g.remap(stitch, 0.84, 0.95), fabric)
    dash = g.remap(g.voronoi(P, 1.0 / (0.0065 * L), "F1"), 0.24, 0.42, 1.0, 0.0)
    thread = g.math("MULTIPLY", line, g.math("MAXIMUM", dash, tack))
    thread = g.math("MAXIMUM", thread, g.math("MULTIPLY", tack, fabric))
    twist = g.noise(P, 1.0 / (0.0012 * L), 1.0)
    # salt: tide-mark patches with a crusty white rim, bloom along the edges and in the stitch grooves, more low down
    tn = g.noise(P, 1.0 / (0.07 * L), 3.0, 0.6, 0.3)
    t0 = g.math("SUBTRACT", 0.66, g.math("MULTIPLY", low, 0.10))
    fill = g.remap(tn, t0, g.math("ADD", t0, 0.07))
    rim = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", tn, t0)), 0.0, 0.012, 1.0, 0.0)
    rim2 = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", tn, g.math("ADD", t0, 0.045))), 0.0, 0.008, 0.7, 0.0)
    salt = g.math("ADD", g.math("MULTIPLY", fill, 0.20), g.math("MULTIPLY", g.math("MAXIMUM", rim, rim2), 0.35), clamp=True)
    bloom = g.math("MULTIPLY", g.math("MAXIMUM", edge, g.math("MULTIPLY", groove, 0.7)),
                   g.remap(g.noise(P, 1.0 / (0.025 * L), 3.0, 0.6), 0.38, 0.58))
    salt = g.math("MAXIMUM", salt, bloom)
    salt = g.math("MULTIPLY", salt, g.math("ADD", 0.30, g.math("MULTIPLY", low, 0.70)))
    crystal = g.remap(g.noise(P, 1.0 / (0.0015 * L), 2.0, 0.6), 0.32, 0.6, 0.35, 1.0)  # crystalline crust speckle
    salt = g.math("MULTIPLY", g.math("MULTIPLY", salt, crystal), fabric, clamp=True)
    # edge wear and fray: faded, fuzzy, broken fibres sticking out
    wear = g.math("MULTIPLY", edge, g.remap(g.noise(P, 1.0 / (0.03 * L), 3.0, 0.6), 0.30, 0.55))
    fibre = g.remap(g.noise(P, 1.0 / (0.0015 * L), 2.0, 0.7, 2.5), 0.52, 0.68)
    fray = g.math("MULTIPLY", wear, fibre)
    # retroreflective tape: banded segments (3D checker), microprisms, seal lines
    band = g.checker(P, 1.0 / (0.05 * L))
    prism = g.remap(g.voronoi(P, 700.0, "F1"), 0.0, 0.5)
    seal = g.remap(g.math("MINIMUM", g.wave(P, 55.0, "X"), g.wave(P, 55.0, "Z")), 0.0, 0.08, 1.0, 0.0)
    pores = g.noise(P, 500.0, 1.0)
    scuff = g.remap(g.noise(P, 160.0, 3.0, 0.7), 0.62, 0.75)
    # height
    fab_h = g.lerp(weave, g.math("ADD", g.math("MULTIPLY", puff, 0.9), g.math("MULTIPLY", rip, 0.25)), padding)
    fab_h = g.math("ADD", fab_h, g.math("MULTIPLY", slub, 0.25))
    fab_h = g.math("SUBTRACT", fab_h, g.math("MULTIPLY", groove, 1.2))          # seam groove
    fab_h = g.math("ADD", fab_h, g.math("MULTIPLY", thread, g.math("ADD", 1.6, g.math("MULTIPLY", twist, 0.4))))
    fab_h = g.lerp(fab_h, g.math("ADD", g.math("MULTIPLY", g.noise(P, 220.0, 3.0, 0.7), 0.8), g.math("MULTIPLY", fibre, 0.9)), wear)
    fab_h = g.math("ADD", fab_h, g.math("MULTIPLY", g.math("MULTIPLY", salt, crystal), 0.0 if wet else 0.2))  # salt crust
    h = g.math("MULTIPLY", fab_h, fabric)
    h = g.math("ADD", h, g.math("MULTIPLY", g.math("SUBTRACT", g.math("MULTIPLY", prism, 0.4), g.math("MULTIPLY", seal, 0.6)), tape))
    h = g.math("ADD", h, g.math("MULTIPLY", g.math("MULTIPLY", pores, 0.6), grip))
    h = g.math("ADD", h, g.math("MULTIPLY", g.math("MULTIPLY", scuff, -0.3), plastic))
    # albedo: Hull Orange
    orange = srgb((206, 90, 40))                                 # round 4: weathered
    orange_d = srgb((172, 76, 38))
    col = g.lerp(orange, orange_d, g.remap(grime, 0.35, 0.75))
    col = g.lerp(col, srgb((214, 84, 26)), g.math("MULTIPLY", g.math("SUBTRACT", 1.0, weave), 0.3))
    col = g.lerp(col, g.lerp(srgb((212, 82, 26)), srgb((232, 104, 40)), puff), padding)
    col = g.lerp(col, srgb((138, 50, 20)), g.math("MULTIPLY", groove, 0.75))     # seam shadow
    col = g.lerp(col, g.lerp(srgb((236, 196, 150)), srgb((250, 222, 182)), twist), thread)  # pale thread
    col = g.lerp(col, srgb((226, 150, 112)), g.math("MULTIPLY", wear, 0.65))     # faded edge
    col = g.lerp(col, srgb((242, 186, 146)), g.math("MULTIPLY", fray, 0.8))      # frayed fibres
    col = g.lerp(col, srgb((122, 66, 38)), g.math("MULTIPLY", g.remap(grime, 0.55, 0.85), 0.35))  # grime
    col = g.lerp(col, srgb((236, 231, 220)), g.math("MULTIPLY", salt, 0.10 if wet else 0.50))      # salt (r5: lighter)
    col = colscale(g, col, g.remap(ao, 0.2, 1.0, 0.72, 1.0))
    if wet:
        col = colscale(g, col, 0.50)                                            # soaked fabric (~0.73x sRGB)
    tape_col = g.lerp(srgb((150, 153, 157)), srgb((196, 199, 202)), band)
    tape_col = g.lerp(tape_col, colscale(g, tape_col, 0.82), prism)
    tape_col = g.lerp(tape_col, srgb((104, 106, 109)), seal)
    col = g.lerp(col, colscale(g, tape_col, 0.92 if wet else 1.0), tape)
    steel = g.lerp(srgb((196, 198, 201)), srgb((172, 174, 178)), g.noise(P, 400.0, 1.0))
    col = g.lerp(col, steel, metal)
    acetal = g.lerp(srgb((30, 30, 32)), srgb((48, 48, 50)), scuff)
    col = g.lerp(col, acetal, plastic)
    col = g.lerp(col, srgb((30, 30, 32)) if wet else srgb((40, 40, 42)), grip)
    # roughness
    if wet:
        rgh = g.math("ADD", 0.36, g.math("MULTIPLY", weave, 0.06))
    else:
        rgh = g.math("ADD", 0.74, g.math("MULTIPLY", weave, 0.06))
        rgh = g.math("ADD", rgh, g.math("MULTIPLY", salt, 0.16))
    rgh = g.lerp(rgh, 0.42 if wet else 0.80, g.math("MULTIPLY", padding, 0.8))
    rgh = g.lerp(rgh, 0.32 if wet else 0.60, thread)                            # bonded nylon thread, a little sheen
    rgh = g.lerp(rgh, 0.46 if wet else 0.90, wear)
    rgh = g.lerp(rgh, g.lerp(g.lerp(0.12 if wet else 0.16, 0.16 if wet else 0.22, prism), 0.30 if wet else 0.42, seal), tape)
    rgh = g.lerp(rgh, g.lerp(0.20 if wet else 0.25, 0.30, g.noise(P, 400.0, 1.0)), metal)
    rgh = g.lerp(rgh, g.lerp(0.26 if wet else 0.40, 0.50 if wet else 0.58, scuff), plastic)
    rgh = g.lerp(rgh, 0.34 if wet else 0.68, grip)
    bump_k = g.math("MULTIPLY", g.math("SUBTRACT", 1.0, metal), 0.40)
    return col, rgh, metal, h, bump_k, 0.002, fabric


NOSE = (0.0, 0.0, 0.0)
BODY_B = ((0.0, 0.0, 0.0), (1.0, 1.0, 1.0))     # object-space bounds of the body parts (find_bounds)
SET_B = BODY_B                                    # bounds of the set being baked
BODY_L = 1.0                                      # body length along Y (pattern sizes scale with it)


def find_bounds(objs):
    global BODY_B, SET_B, BODY_L
    import numpy as np

    def bounds(os_):
        V = []
        for o in os_:
            n = len(o.data.vertices)
            a = np.zeros(n * 3)
            o.data.vertices.foreach_get("co", a)
            V.append(a.reshape(-1, 3))
        V = np.concatenate(V)
        return tuple(map(float, V.min(0))), tuple(map(float, V.max(0)))

    BODY_B = bounds([bpy.data.objects["%s_%s_LOD0" % (ASSET, p)] for p in GRAPHS["Body"][1]])
    SET_B = bounds(objs)
    BODY_L = BODY_B[1][1] - BODY_B[0][1]
    print("[bake] body bounds", [round(v, 3) for v in BODY_B[0] + BODY_B[1]], "set Z", round(SET_B[0][2], 3), round(SET_B[1][2], 3))


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


GRAPHS = {"Body": (body_graph, ["BodyHead", "BodyFore", "BodyHind", "Tail"]), "Harness": (harness_graph, ["Harness"])}


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
    find_bounds(objs)
    mat = objs[0].data.materials[0]
    HAS.clear()
    HAS.update(set.intersection(*[set(a.name for a in o.data.attributes) for o in objs]))
    print("[bake] attributes", sorted(HAS))
    passes = [("ALB", False), ("RGH", False), ("MET", False), ("NOR", False), ("ALB", True), ("RGH", True), ("NOR", True)]
    # SIG: Harness = the Hull Orange signal mask (saved); Body = the coat mask, only for the stats below (not saved)
    passes.insert(0, ("SIG", False)) if set_name == "Body" else passes.append(("SIG", False))
    import time
    import numpy as np
    stat_mask = None
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
        px = np.empty(size * size * 4, np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(-1, 4)[:, :3] * 255.0
        if set_name == "Body" and kind == "SIG":
            stat_mask = px[:, 0] > 200
            bpy.data.images.remove(img)
            continue
        img.filepath_raw = os.path.join(RAW, stem + ".png")
        img.file_format = "PNG"
        img.save()
        print("[bake] %s %d px %.1f s (%s)" % (stem, size, time.time() - t0, device))
        if kind in ("ALB", "RGH"):
            cov = px.max(axis=1) > 0.5
            for label, m in (("all", cov), ("coat", cov & stat_mask if stat_mask is not None else None)):
                if m is None or not m.any():
                    continue
                v = px[m]
                lum = 0.2126 * v[:, 0] + 0.7152 * v[:, 1] + 0.0722 * v[:, 2]
                q = np.percentile(lum, (0, 1, 50, 99, 100))
                print("[stats] %s %-5s mean RGB %s  luma min %.1f p1 %.1f p50 %.1f p99 %.1f max %.1f%s" % (
                    stem, label, np.round(v.mean(axis=0), 1).tolist(), *q,
                    "" if kind == "ALB" else "  (rough %.2f-%.2f)" % (q[1] / 255, q[3] / 255)))
        bpy.data.images.remove(img)
