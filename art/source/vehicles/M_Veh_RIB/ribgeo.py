"""Shared geometry helpers for M_Veh_RIB and M_Veh_RIB_Helm (1 Blender unit = 1 stud, 3 studs per metre).

Axes (pipeline): X beam (port +X, starboard -X), Y length (bow -Y, stern +Y), Z up. Base of the skegs at z 0.
Every part is built twice from the same generators: lo (LOD0, one material, UVs) and hi (_HP, named materials for
the bake: base colour / roughness / metalness per slot, more segments, bevels, non-slip relief).
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix, noise

# --------------------------------------------------------------------------- layout constants (studs)
K = 0.45            # keel bottom (skegs reach z 0)
DECK = 2.1          # deck surface (greybox deck y 0 -> z 2.1)
TR = 0.825          # tube radius (0.55 m tube)
TX = 3.45           # tube centre half-beam on the straight
TZ = 2.475          # tube centre height on the straight
BOW_Y0 = -6.0       # straight tube ends here; bow arc runs to the stem
BOW_Y1 = -12.2      # tube centreline at the stem
BOW_RISE = 0.45     # tube sheer rise at the stem
STERN_Y = 11.3      # tube cone starts
TRANSOM_Y = 10.9


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


PALETTE = {
    # name: (sRGB hex, roughness, metal). V2 fix batch livery: saturated orange Hypalon tubes, dark navy GRP hull,
    # grey rub strakes, white waterline stripe, oxblood antifoul, Hull Orange console / A-frame.
    "HullCharcoal": ("#1F2836", 0.36, 0.0),
    "HullBody": ("#1F2836", 0.36, 0.0),         # z-banded: antifoul / waterline stripe / navy (HULL_BANDS)     # dark navy gelcoat (name kept for the slot layout)
    "HullOrange": ("#F2620F", 0.36, 0.0),
    "BootStripe": ("#D9DBD7", 0.38, 0.0),       # white waterline stripe
    "TubeGrey": ("#EE6A1A", 0.66, 0.0),         # orange Hypalon (name kept)
    "TubeWear": ("#B85A26", 0.74, 0.0),         # scuffed underside / chafe patches
    "TubeSeam": ("#9C4A1E", 0.70, 0.0),         # welded overlap seams, dirt in the step
    "TubeFillet": ("#2E3135", 0.72, 0.0),       # tube-to-hull fillet tape
    "TubeEndCap": ("#383B3F", 0.70, 0.0),
    "Reflective": ("#C4C8CA", 0.28, 0.0),
    "RubStrake": ("#7B8085", 0.72, 0.0),        # grey rub strake
    "Rope": ("#4A5058", 0.88, 0.0),
    "Webbing": ("#2F3842", 0.85, 0.0),
    "NonSlip": ("#5E6468", 0.90, 0.0),
    "Gelcoat": ("#A4A9AB", 0.40, 0.0),
    "GelcoatWhite": ("#D9DBD7", 0.38, 0.0),
    "Acrylic": ("#23292D", 0.06, 0.0),
    "Stainless": ("#DCDFE0", 0.20, 1.0),
    "Aluminium": ("#C2C6C8", 0.38, 1.0),        # anodised
    "Bolt": ("#D6D9DA", 0.28, 1.0),
    "BlackPlastic": ("#2A2C2E", 0.55, 0.0),
    "Rubber": ("#2D2F31", 0.82, 0.0),
    "Cable": ("#26282A", 0.60, 0.0),
    "LensRed": ("#B3262A", 0.10, 0.0),
    "LensGreen": ("#1F8A4C", 0.10, 0.0),
    "LensWhite": ("#D6D8D6", 0.10, 0.0),
    "LensBlue": ("#2D5BC4", 0.10, 0.0),
    "CowlGrey": ("#3B3F43", 0.30, 0.0),
    "CowlLight": ("#B9BDBE", 0.34, 0.0),
    "Vent": ("#232527", 0.60, 0.0),
    "Antifoul": ("#5B2B26", 0.82, 0.0),         # oxblood ablative antifoul
    "KeelStrip": ("#B4B8BA", 0.45, 1.0),        # stainless keel band
    "Screen": ("#1C2830", 0.08, 0.0),
    "ScreenChart": ("#3E5866", 0.10, 0.0),
    "Vinyl": ("#2C2F33", 0.58, 0.0),
    "PodGrey": ("#6B7074", 0.45, 0.0),
    "Strap": ("#2B3440", 0.86, 0.0),
    "PanelOrange": ("#EE6A1A", 0.62, 0.0),       # matches the tube orange (lettering sits on it)
    "PanelConsole": ("#F2620F", 0.40, 0.0),     # matches the console Hull Orange
    "PanelNavy": ("#1F2836", 0.45, 0.0),
    "LetterWhite": ("#E6E7E3", 0.45, 0.0),
    "LetterNavy": ("#1F2836", 0.45, 0.0),
    "ChevronYellow": ("#E8D21C", 0.32, 0.0),    # retroreflective yellow
    "ChevronSilver": ("#C9CDCF", 0.26, 0.0),
    "CrestCharcoal": ("#2B2F33", 0.45, 0.0),
    "Dial": ("#E2E3DF", 0.20, 0.0),
}

# procedural slots (baked through bake.custom_material; bump goes into the NOR through the _HP shading normal):
# mottle (noise scale, amount), grime (colour, amount), streak (colour, amount: vertical water streaks),
# rough_var, bump (kind, strength, scale)
PROC = {
    "HullCharcoal": dict(mottle=(6, 0.10), grime=("#3A3F44", 0.30), streak=("#4B5257", 0.35), rough_var=0.14, bump=("peel", 0.05, 60)),
    "Antifoul": dict(mottle=(4, 0.16), grime=("#3A2826", 0.35), streak=("#6E5A4E", 0.25), rough_var=0.10, bump=("peel", 0.12, 40)),
    "BootStripe": dict(mottle=(5, 0.06), grime=("#9EA19A", 0.30), streak=("#8E918A", 0.30), rough_var=0.10),
    "HullOrange": dict(mottle=(5, 0.06), grime=("#A85A2C", 0.22), streak=("#C06A38", 0.25), rough_var=0.12, bump=("peel", 0.04, 60)),
    "TubeGrey": dict(mottle=(3, 0.10), grime=("#A65A2E", 0.30), streak=("#C77A4A", 0.22), rough_var=0.12, bump=("weave", 0.22, 70)),
    "TubeWear": dict(mottle=(4, 0.14), grime=("#6E4A34", 0.40), rough_var=0.10, bump=("weave", 0.25, 70)),
    "TubeSeam": dict(mottle=(4, 0.10), grime=("#5A4032", 0.45), rough_var=0.08, bump=("weave", 0.2, 70)),
    "TubeFillet": dict(mottle=(4, 0.10), grime=("#4A4640", 0.30), rough_var=0.08, bump=("weave", 0.15, 70)),
    "RubStrake": dict(mottle=(5, 0.10), grime=("#55585B", 0.40), rough_var=0.12, bump=("grain", 0.18, 90)),
    "Rubber": dict(mottle=(5, 0.08), grime=("#3E3C38", 0.30), rough_var=0.08, bump=("grain", 0.15, 120)),
    "NonSlip": dict(mottle=(3, 0.10), grime=("#4A4C48", 0.40), rough_var=0.06, bump=("diamond", 0.9, 30)),
    "Gelcoat": dict(mottle=(4, 0.08), grime=("#7E817C", 0.35), rough_var=0.12, bump=("peel", 0.05, 60)),
    "GelcoatWhite": dict(mottle=(4, 0.05), grime=("#AEB0A8", 0.30), streak=("#A3A59E", 0.25), rough_var=0.10, bump=("peel", 0.04, 60)),
    "Webbing": dict(mottle=(6, 0.08), grime=("#3E4144", 0.25), rough_var=0.05, bump=("weave", 0.35, 140)),
    "Strap": dict(mottle=(6, 0.08), grime=("#3E4144", 0.25), rough_var=0.05, bump=("weave", 0.35, 140)),
    "Rope": dict(mottle=(8, 0.10), rough_var=0.05, bump=("grain", 0.3, 160)),
    "Vinyl": dict(mottle=(5, 0.06), grime=("#45484A", 0.25), rough_var=0.10, bump=("grain", 0.12, 140)),
    "PodGrey": dict(mottle=(5, 0.06), grime=("#55595C", 0.30), rough_var=0.10, bump=("peel", 0.05, 60)),
    "CowlGrey": dict(mottle=(5, 0.05), grime=("#4E5256", 0.25), streak=("#5E6468", 0.25), rough_var=0.10),
    "CowlLight": dict(mottle=(5, 0.05), grime=("#8E918E", 0.30), streak=("#9A9D99", 0.25), rough_var=0.10),
    "PanelOrange": dict(mottle=(3, 0.10), grime=("#A65A2E", 0.30), rough_var=0.10),
    "PanelConsole": dict(mottle=(5, 0.06), grime=("#A85A2C", 0.22), rough_var=0.10),
    "PanelNavy": dict(mottle=(4, 0.05), grime=("#3A3F44", 0.18), rough_var=0.08),
    "LetterWhite": dict(mottle=(4, 0.04), grime=("#B4B5AE", 0.25), rough_var=0.08),
}
# bump only (constant base / roughness; metals keep a clean 180-250 albedo)
BUMP_ONLY = {"Stainless": ("brushed", 0.06, 200), "Aluminium": ("brushed", 0.05, 160), "KeelStrip": ("brushed", 0.08, 120),
             "Bolt": ("grain", 0.1, 200)}


def _ci(node, k):
    return [i for i in node.inputs if i.type == "RGBA"][k]


def _co(node):
    return [o for o in node.outputs if o.type == "RGBA"][0]


def deform(g, start, fn):
    """Moves every bmesh vert added since index `start` through fn(co) -> co."""
    g.bm.verts.ensure_lookup_table()
    for v in g.bm.verts[start:]:
        v.co = fn(v.co.copy())


def _hex_srgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _bump_tree(nt, kind, strength, scale, coord):
    """Height pattern in object space (studs); returns a Bump node output (normal)."""
    L = nt.links.new
    N = nt.nodes.new
    mp = N("ShaderNodeMapping")
    L(coord, mp.inputs["Vector"])
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    if kind == "diamond":
        mp.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(45))
        hs = []
        for axis in ("X", "Y"):
            w = N("ShaderNodeTexWave")
            w.wave_type, w.bands_direction, w.wave_profile = "BANDS", axis, "TRI"
            w.inputs["Scale"].default_value = 1.0
            w.inputs["Distortion"].default_value = 0.0
            L(mp.outputs[0], w.inputs["Vector"])
            hs.append(w.outputs["Fac"])
        h = N("ShaderNodeMath")
        h.operation = "MINIMUM"
        L(hs[0], h.inputs[0])
        L(hs[1], h.inputs[1])
        g = N("ShaderNodeTexNoise")
        g.inputs["Scale"].default_value = 3.0
        L(mp.outputs[0], g.inputs["Vector"])
        mix = N("ShaderNodeMath")
        mix.operation = "MULTIPLY_ADD"
        mix.inputs[1].default_value = 0.15
        L(g.outputs["Fac"], mix.inputs[0])
        L(h.outputs[0], mix.inputs[2])
        height = mix.outputs[0]
    elif kind == "weave":
        hs = []
        for axis in ("X", "Z"):
            w = N("ShaderNodeTexWave")
            w.wave_type, w.bands_direction, w.wave_profile = "BANDS", axis, "SIN"
            w.inputs["Scale"].default_value = 1.0
            w.inputs["Distortion"].default_value = 0.4
            L(mp.outputs[0], w.inputs["Vector"])
            hs.append(w.outputs["Fac"])
        h = N("ShaderNodeMath")
        h.operation = "MULTIPLY"
        L(hs[0], h.inputs[0])
        L(hs[1], h.inputs[1])
        height = h.outputs[0]
    elif kind == "brushed":
        mp.inputs["Scale"].default_value = (scale * 0.02, scale, scale)
        n = N("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 1.0
        n.inputs["Detail"].default_value = 4.0
        L(mp.outputs[0], n.inputs["Vector"])
        height = n.outputs["Fac"]
    else:  # peel / grain: fine noise
        n = N("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 1.0
        n.inputs["Detail"].default_value = 6.0 if kind == "grain" else 2.0
        n.inputs["Roughness"].default_value = 0.6
        L(mp.outputs[0], n.inputs["Vector"])
        height = n.outputs["Fac"]
    bump = N("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = 0.02
    L(height, bump.inputs["Height"])
    return bump.outputs["Normal"]


def _proc_sockets(nt, name, hexc, rough, coord):
    """(colour socket, roughness socket) for a PROC slot."""
    L = nt.links.new
    N = nt.nodes.new
    spec = PROC[name]
    base = _hex_srgb(hexc)
    ms, ma = spec.get("mottle", (4, 0.0))
    nz = N("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = ms
    nz.inputs["Detail"].default_value = 5.0
    L(coord, nz.inputs["Vector"])
    dark = N("ShaderNodeRGB")
    dark.outputs[0].default_value = tuple(c * (1 - ma * 2.0) for c in base) + (1.0,)
    lite = N("ShaderNodeRGB")
    lite.outputs[0].default_value = tuple(min(1.0, c * (1 + ma)) for c in base) + (1.0,)
    mott = N("ShaderNodeMix")
    mott.data_type = "RGBA"
    L(nz.outputs["Fac"], mott.inputs["Factor"])
    L(dark.outputs[0], _ci(mott, 0))
    L(lite.outputs[0], _ci(mott, 1))
    col = _co(mott)
    for key, scale, rng in (("grime", None, (0.52, 0.72)), ("streak", (9.0, 9.0, 0.35), (0.55, 0.75))):
        if key not in spec:
            continue
        cc, amt = spec[key]
        vec = coord
        if scale:
            mp = N("ShaderNodeMapping")
            mp.inputs["Scale"].default_value = scale
            L(coord, mp.inputs["Vector"])
            vec = mp.outputs[0]
        g = N("ShaderNodeTexNoise")
        g.inputs["Scale"].default_value = 1.6 if key == "grime" else 1.0
        g.inputs["Detail"].default_value = 8.0 if key == "grime" else 3.0
        g.inputs["Roughness"].default_value = 0.65
        L(vec, g.inputs["Vector"])
        mr = N("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = rng
        mr.inputs["To Max"].default_value = amt
        L(g.outputs["Fac"], mr.inputs["Value"])
        gcol = N("ShaderNodeRGB")
        gcol.outputs[0].default_value = _hex_srgb(cc) + (1.0,)
        mx = N("ShaderNodeMix")
        mx.data_type = "RGBA"
        L(mr.outputs[0], mx.inputs["Factor"])
        L(col, _ci(mx, 0))
        L(gcol.outputs[0], _ci(mx, 1))
        col = _co(mx)
    rv = spec.get("rough_var", 0.0)
    rn = N("ShaderNodeTexNoise")
    rn.inputs["Scale"].default_value = 2.5
    rn.inputs["Detail"].default_value = 6.0
    L(coord, rn.inputs["Vector"])
    rr = N("ShaderNodeMapRange")
    rr.inputs["From Min"].default_value, rr.inputs["From Max"].default_value = 0.3, 0.7
    rr.inputs["To Min"].default_value = max(0.02, rough - rv)
    rr.inputs["To Max"].default_value = min(1.0, rough + rv)
    L(rn.outputs["Fac"], rr.inputs["Value"])
    return col, rr.outputs[0]


def _proc_tree(mat, name, bsdf, hexc, rough, metal, bump=True):
    nt = mat.node_tree
    L = nt.links.new
    N = nt.nodes.new
    tc = N("ShaderNodeTexCoord")
    coord = tc.outputs["Object"]
    spec = PROC.get(name)
    if spec:
        col, rgh = _proc_sockets(nt, name, hexc, rough, coord)
        out = N("ShaderNodeGamma")        # BAKE_BASE: single colour output (gamma 1 pass-through)
        out.name = "BAKE_BASE"
        out.inputs["Gamma"].default_value = 1.0
        L(col, out.inputs["Color"])
        c = N("ShaderNodeCombineXYZ")
        c.name = "BAKE_MR"
        c.inputs["X"].default_value = metal
        L(rgh, c.inputs["Y"])
        mat["bake_custom"] = 1
    bmp = spec.get("bump") if spec else BUMP_ONLY.get(name)
    if bmp and bump:
        L(_bump_tree(nt, bmp[0], bmp[1], bmp[2], coord), bsdf.inputs["Normal"])


HULL_BANDS = ((1.60, "Antifoul"), (1.74, "BootStripe"), (99.0, "HullCharcoal"))   # object z (studs) upper bounds


def _band_tree(mat, bsdf):
    """HullBody: one slot whose colour / roughness switch by object Z (antifoul, waterline stripe, navy topsides)."""
    nt = mat.node_tree
    L = nt.links.new
    N = nt.nodes.new
    tc = N("ShaderNodeTexCoord")
    sep = N("ShaderNodeSeparateXYZ")
    L(tc.outputs["Object"], sep.inputs[0])
    col = rgh = None
    for zmax, name in HULL_BANDS:
        hexc, rough, metal = PALETTE[name]
        c, r = _proc_sockets(nt, name, hexc, rough, tc.outputs["Object"])
        if col is None:
            col, rgh, prev = c, r, zmax
            continue
        lo = prev
        st = N("ShaderNodeMath")
        st.operation = "GREATER_THAN"
        st.inputs[1].default_value = lo
        L(sep.outputs["Z"], st.inputs[0])
        mx = N("ShaderNodeMix")
        mx.data_type = "RGBA"
        L(st.outputs[0], mx.inputs["Factor"])
        L(col, _ci(mx, 0))
        L(c, _ci(mx, 1))
        col = _co(mx)
        mr = N("ShaderNodeMix")
        mr.data_type = "FLOAT"
        L(st.outputs[0], mr.inputs["Factor"])
        L(rgh, [i for i in mr.inputs if i.type == "VALUE" and i.name == "A"][0])
        L(r, [i for i in mr.inputs if i.type == "VALUE" and i.name == "B"][0])
        rgh = [o for o in mr.outputs if o.type == "VALUE"][0]
        prev = zmax
        continue
    out = N("ShaderNodeGamma")
    out.name = "BAKE_BASE"
    out.inputs["Gamma"].default_value = 1.0
    L(col, out.inputs["Color"])
    c = N("ShaderNodeCombineXYZ")
    c.name = "BAKE_MR"
    c.inputs["X"].default_value = 0.0
    L(rgh, c.inputs["Y"])
    mat["bake_custom"] = 1
    L(_bump_tree(nt, "peel", 0.06, 50, tc.outputs["Object"]), bsdf.inputs["Normal"])


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    hexc, rough, metal = PALETTE.get(name, ("#808080", 0.5, 0.0))
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*hexcol(hexc), 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if name == "HullBody":
        _band_tree(mat, bsdf)
    elif name in PROC or name in BUMP_ONLY:
        _proc_tree(mat, name, bsdf, hexc, rough, metal)
    return mat


# --------------------------------------------------------------------------- tube centreline
def tube_frame(y):
    """Tube centre (x half-beam, z) and radius at a station y (port side)."""
    if y >= BOW_Y0:
        return TX, TZ, TR
    s = min(1.0, (BOW_Y0 - y) / (BOW_Y0 - BOW_Y1))
    t = math.asin(s)
    return TX * math.cos(t), TZ + BOW_RISE * s ** 1.6, TR - 0.05 * s


def tube_path(lo):
    """Port stern -> bow -> starboard stern: list of (Vector, radius)."""
    n_arc = 22 if lo else 36
    side = []
    cone = [(12.12, 0.18), (12.02, 0.42), (11.82, 0.64), (11.58, 0.77)]
    if not lo:
        cone = [(12.16, 0.10), (12.1, 0.3), (12.0, 0.48), (11.85, 0.63), (11.68, 0.74), (11.5, 0.8)]
    for y, r in cone:
        side.append((Vector((TX, y, TZ)), r))
    ys = [STERN_Y] + [9.75 - 1.5 * i for i in range(11)] + [BOW_Y0]
    for y in ys:
        side.append((Vector((TX, y, TZ)), TR))
    for i in range(1, n_arc):
        t = (math.pi / 2) * i / n_arc
        s = math.sin(t)
        x = TX * math.cos(t)
        y = BOW_Y0 + (BOW_Y1 - BOW_Y0) * s
        side.append((Vector((x, y, TZ + BOW_RISE * s ** 1.6)), TR - 0.05 * s))
    centre = (Vector((0.0, BOW_Y1, TZ + BOW_RISE)), TR - 0.05)
    mirrored = [(Vector((-p.x, p.y, p.z)), r) for p, r in reversed(side)]
    return side + [centre] + mirrored


def frames(points):
    """Tangent, side (inward for this U path) and up per path point."""
    out = []
    n = len(points)
    for i in range(n):
        a = points[max(0, i - 1)]
        b = points[min(n - 1, i + 1)]
        t = (b - a).normalized()
        side = t.cross(Vector((0, 0, 1)))
        if side.length < 1e-6:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(t).normalized()
        out.append((t, side, up))
    return out


# --------------------------------------------------------------------------- mesh accumulator
class Geo:
    def __init__(self, hi):
        self.hi = hi
        self.bm = bmesh.new()
        self.mats = []

    def bevel_sharp(self, faces, offset, angle=25, segments=None):
        """Round the sharp edges of a just-built component (chamfer on LOD0, 3 segments on _HP)."""
        if offset <= 0 or not faces:
            return
        fs = set(faces)
        edges = {e for f in faces for e in f.edges
                 if len(e.link_faces) == 2 and all(lf in fs for lf in e.link_faces)
                 and e.calc_face_angle(0.0) > math.radians(angle)}
        if not edges:
            return
        seg = segments or (3 if self.hi else 1)
        try:
            bmesh.ops.bevel(self.bm, geom=list(edges) + list({v for e in edges for v in e.verts}), offset=offset,
                            segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        except Exception as exc:  # keep building; a failed bevel only loses the rounding
            print("[ribgeo] bevel skipped:", exc)

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def face(self, vs, mat):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = self.mi(mat)
        return f

    def rings(self, rings, mat, closed=True, cap0=False, cap1=False, matfn=None, recalc=True):
        vs = [[self.bm.verts.new(p) for p in r] for r in rings]
        n = len(rings[0])
        faces = []
        for i in range(len(vs) - 1):
            for j in range(n if closed else n - 1):
                k = (j + 1) % n
                m = matfn(i, j) if matfn else mat
                f = self.face((vs[i][j], vs[i][k], vs[i + 1][k], vs[i + 1][j]), m)
                if f:
                    faces.append(f)
        if cap0:
            faces += self.cap(vs[0], mat)
        if cap1:
            faces += self.cap(vs[-1], mat)
        if recalc and faces:
            bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return faces

    def cap(self, ring, mat):
        c = sum((v.co for v in ring), Vector()) / len(ring)
        cv = self.bm.verts.new(c)
        out = []
        for j in range(len(ring)):
            f = self.face((ring[j], ring[(j + 1) % len(ring)], cv), mat)
            if f:
                out.append(f)
        return out

    def orient(self, faces, fn):
        """Flip faces whose normal points against fn(face centre)."""
        for f in faces:
            f.normal_update()
            if f.normal.dot(fn(f.calc_center_median())) < 0:
                f.normal_flip()

    def add_mesh(self, me, mat, mapfn):
        vs = [self.bm.verts.new(mapfn(v.co)) for v in me.vertices]
        out = []
        for p in me.polygons:
            f = self.face([vs[i] for i in p.vertices], mat)
            if f:
                out.append(f)
        return out

    def to_object(self, name, collection=None, single_mat=None, smooth_angle=40):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        (collection or bpy.context.scene.collection).objects.link(obj)
        if single_mat:
            me.materials.append(material(single_mat) if isinstance(single_mat, str) else single_mat)
            for p in me.polygons:
                p.material_index = 0
        else:
            for m in self.mats:
                me.materials.append(material(m))
        me.shade_smooth()
        if smooth_angle:
            me.set_sharp_from_angle(angle=math.radians(smooth_angle))
        return obj


# --------------------------------------------------------------------------- primitives
def circle_profile(r, seg, phase=0.0):
    return [(r * math.cos(phase + 2 * math.pi * j / seg), r * math.sin(phase + 2 * math.pi * j / seg)) for j in range(seg)]


def sweep(g, pts, profile, mat, closed=True, radii=None, cap0=False, cap1=False, matfn=None, recalc=True):
    """Sweep a 2-D profile (side, up) along a path; radii scales the profile per point."""
    fr = frames(pts)
    rings = []
    for i, p in enumerate(pts):
        t, side, up = fr[i]
        s = radii[i] if radii else 1.0
        rings.append([p + side * (a * s) + up * (b * s) for a, b in profile])
    return g.rings(rings, mat, closed=closed, cap0=cap0, cap1=cap1, matfn=matfn, recalc=recalc)


def rounded_path(corners, radius, seg):
    """Polyline with filleted corners."""
    out = [corners[0]]
    for i in range(1, len(corners) - 1):
        a, b, c = corners[i - 1], corners[i], corners[i + 1]
        da, dc = (a - b).normalized(), (c - b).normalized()
        r = min(radius, (a - b).length * 0.45, (c - b).length * 0.45)
        p0, p1 = b + da * r, b + dc * r
        for k in range(seg + 1):
            t = k / seg
            out.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * b + t ** 2 * p1)
    out.append(corners[-1])
    return out


def tube(g, corners, r, mat, seg, fillet=0.3, fseg=4, caps=True):
    pts = rounded_path([Vector(c) for c in corners], fillet, fseg) if len(corners) > 2 else [Vector(c) for c in corners]
    return sweep(g, pts, circle_profile(r, seg), mat, cap0=caps, cap1=caps)


def box(g, centre, size, mat, rot=None, bev=None):
    cx, cy, cz = centre
    sx, sy, sz = (s / 2 for s in size)
    m = rot or Matrix.Identity(3)
    c = Vector(centre)
    v = [g.bm.verts.new(c + m @ Vector((x * sx, y * sy, z * sz))) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    faces = [g.face([v[i] for i in q], mat) for q in quads]
    faces = [f for f in faces if f]
    bmesh.ops.recalc_face_normals(g.bm, faces=faces)
    if bev is None:
        bev = 0.18 * min(size)
    g.bevel_sharp(faces, min(bev, 0.04))
    return faces


def lathe(g, axis_origin, axis, profile, seg, mat, matfn=None):
    """profile: list of (radius, height along axis); radius 0 ends are collapsed to a point ring."""
    axis = Vector(axis).normalized()
    ref = Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 1, 0))
    u = axis.cross(ref).normalized()
    w = axis.cross(u).normalized()
    o = Vector(axis_origin)
    rings = []
    for r, h in profile:
        r = max(r, 1e-4)
        rings.append([o + axis * h + (u * math.cos(2 * math.pi * j / seg) + w * math.sin(2 * math.pi * j / seg)) * r
                      for j in range(seg)])
    return g.rings(rings, mat, matfn=matfn)


def superellipse_ring(cx, cy, z, hx, hy, seg, p=3.0):
    pts = []
    for j in range(seg):
        t = 2 * math.pi * j / seg
        c, s = math.cos(t), math.sin(t)
        x = hx * math.copysign(abs(c) ** (2 / p), c)
        y = hy * math.copysign(abs(s) ** (2 / p), s)
        pts.append(Vector((cx + x, cy + y, z)))
    return pts


def loft(g, sections, seg, mat, cap0=True, cap1=True, p=3.0, matfn=None):
    """sections: (cx, cy, z, hx, hy) bottom to top (superellipse rings)."""
    rings = [superellipse_ring(cx, cy, z, max(hx, 1e-3), max(hy, 1e-3), seg, p) for cx, cy, z, hx, hy in sections]
    return g.rings(rings, mat, cap0=cap0, cap1=cap1, matfn=matfn)


def extrude_profile(g, profile_yz, x0, x1, mat, matfn=None, bev=0.0):
    """Prism: a convex YZ profile extruded from x0 to x1, side caps as fans."""
    rings = [[Vector((x, y, z)) for y, z in profile_yz] for x in (x0, x1)]
    faces = g.rings(rings, mat, cap0=True, cap1=True, matfn=matfn)
    g.bevel_sharp(faces, bev)
    return faces


def text_mesh(body, size, extrude=0.0, font_scale_x=1.0):
    cu = bpy.data.curves.new("TXT_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = extrude
    cu.space_character = 1.05
    ob = bpy.data.objects.new("TXT_" + body, cu)
    bpy.context.scene.collection.objects.link(ob)
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    if font_scale_x != 1.0:
        for v in me.vertices:
            v.co.x *= font_scale_x
    return me


def apply_modifiers(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(deps))
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)
    me.name = obj.name


def bevel_hp(obj, width=0.03, segments=2, angle=35):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = False
    apply_modifiers(obj)


def split_by_part(src, part_faces, names):
    """Split one UV-unwrapped object into one object per part (face index lists), keeping UVs."""
    out = []
    for name, idx in zip(names, part_faces):
        keep = set(idx)
        bm = bmesh.new()
        bm.from_mesh(src.data)
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if f.index not in keep]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in src.data.materials:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        out.append(ob)
    bpy.data.objects.remove(src)
    return out


def build_set(set_name, parts, unwrap, mat_name, angle=55, margin=0.004):
    """parts: [(object_name, geo_fn)] where geo_fn(g) adds lo geometry. Joins, unwraps (one packed UV layout per set),
    then splits back into one MeshPart object per part."""
    g = Geo(False)
    ranges = []
    for name, fn in parts:
        start = len(g.bm.faces)
        fn(g)
        g.bm.faces.ensure_lookup_table()
        ranges.append((start, len(g.bm.faces)))
    # keep the per-part face ranges through remove_doubles by tagging faces
    layer = g.bm.faces.layers.int.new("part")
    g.bm.faces.ensure_lookup_table()
    for pi, (a, b) in enumerate(ranges):
        for i in range(a, b):
            g.bm.faces[i][layer] = pi
    obj = g.to_object("TMP_" + set_name, single_mat=mat_name)
    unwrap(obj, angle=angle, margin=margin)
    obj.data.uv_layers[0].name = "UVMap"
    attr = obj.data.attributes["part"]
    idx = [[] for _ in parts]
    for i, d in enumerate(attr.data):
        idx[d.value].append(i)
    objs = split_by_part(obj, idx, [n for n, _ in parts])
    for o in objs:
        if "part" in o.data.attributes:
            o.data.attributes.remove(o.data.attributes["part"])
    return objs


def build_hp(name, fns, bevel=None):
    g = Geo(True)
    for fn in fns:
        fn(g)
    obj = g.to_object(name)
    if bevel:
        bevel_hp(obj, **bevel)
    return obj


def grit(p, scale=22.0, amp=0.006):
    return amp * noise.noise(p * scale)
