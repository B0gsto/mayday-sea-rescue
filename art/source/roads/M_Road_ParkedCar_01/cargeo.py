"""Shared geometry helpers for M_Veh_LifeguardPickup (1 Blender unit = 1 stud, 3 studs per metre).

Axes (pipeline): X across (driver side -X, kerb side +X), Y length (front -Y, rear +Y), Z up. Ground at z 0.
Every part is generated twice from the same functions: the LOD0 Geo (one material, UVs, chamfer bevels) and the _HP
Geo (named material slots for the bake, more segments, finer bevels, baked-only fasteners and seams).

Ported from art/source/vehicles/M_Veh_RIB/ribgeo.py (same Geo / build_set / bake-custom contract).
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix, noise


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


PALETTE = {
    # name: (sRGB hex, roughness, metal). Invented muted blue-grey metallic for the parked hatchback; the rest of the
    # table is reused from M_Veh_LifeguardPickup (same wheel, glass, trim and lamp materials).
    "PaintBlue": ("#6B7C88", 0.27, 0.36),
    "PaintWhite": ("#E8E7E1", 0.34, 0.0),
    "PaintRed": ("#CC2A2E", 0.34, 0.0),
    "PaintYellow": ("#ECCB22", 0.34, 0.0),
    "BumperPlastic": ("#3B3E41", 0.62, 0.0),
    "ArchPlastic": ("#2F3235", 0.70, 0.0),
    "GrilleDark": ("#232527", 0.50, 0.0),
    "BlackPlastic": ("#26282A", 0.55, 0.0),
    "BlackMetal": ("#2C2F32", 0.42, 0.0),      # satin black powder coat: paint, not bare metal
    "Rubber": ("#2D2F31", 0.82, 0.0),
    "Tyre": ("#212325", 0.86, 0.0),
    "RimSilver": ("#D2D6D8", 0.34, 1.0),
    "RimDark": ("#3C4044", 0.55, 0.0),
    "BrakeSteel": ("#B4B8BB", 0.48, 0.0),       # cast iron reads matt grey, not bright metal
    "Exhaust": ("#C6C8CA", 0.42, 1.0),
    "Chrome": ("#EDEFF0", 0.16, 1.0),
    "Stainless": ("#EFF1F2", 0.22, 1.0),
    "Aluminium": ("#E0E4E6", 0.45, 1.0),
    "Glass": ("#26343C", 0.06, 0.0),
    "GlassSeal": ("#1B1D1F", 0.78, 0.0),
    "InteriorDark": ("#2C2F33", 0.72, 0.0),
    "InteriorMid": ("#4B5055", 0.68, 0.0),
    "SeatFabric": ("#3D4146", 0.88, 0.0),
    "SeatAccent": ("#D8C43A", 0.70, 0.0),
    "Headliner": ("#9FA3A4", 0.88, 0.0),
    "Carpet": ("#24262A", 0.92, 0.0),
    "Screen": ("#2D4F63", 0.14, 0.0),
    "LensWhite": ("#D9DBD9", 0.10, 0.0),
    "LensAmber": ("#E8A02A", 0.12, 0.0),
    "LensRed": ("#B3262A", 0.12, 0.0),
    "LensReverse": ("#D4D6D4", 0.10, 0.0),
    "PlateWhite": ("#E4E5E0", 0.50, 0.0),
    "PlateYellow": ("#D9B62A", 0.50, 0.0),
    "PlateLetter": ("#26282A", 0.50, 0.0),
    "Webbing": ("#323438", 0.86, 0.0),
    "KitOrange": ("#E8641C", 0.66, 0.0),
    "KitYellow": ("#E2C81E", 0.62, 0.0),
    "Underseal": ("#26282A", 0.90, 0.0),
    "WheelWell": ("#202224", 0.90, 0.0),
    "LetterRed": ("#C22A2E", 0.50, 0.0),
    "LetterWhite": ("#E6E7E3", 0.50, 0.0),
    # flush lamps / shut lines (Strip helpers); darks kept at sRGB luma >= 34 so the bake's albedo floor does not
    # shift (brighten) the whole set
    "SeamDark": ("#202326", 0.68, 0.0),
    "LensDark": ("#202529", 0.05, 0.0),
    "DRLWhite": ("#ECF0F2", 0.06, 0.0),
    "TailRed": ("#8A0C14", 0.09, 0.0),
    "TailClear": ("#C7CBC9", 0.07, 0.0),
    "TailAmber": ("#B4640E", 0.10, 0.0),
}

# procedural slots (baked through bake.custom_material; bump goes into the NOR through the _HP shading normal):
# mottle (noise scale, amount), grime (colour, amount), streak (colour, amount), salt / scuff (colour, amount),
# rough_var, bump (kind, strength, scale)
PROC = {
    "PaintBlue": dict(mottle=(1.5, 0.010), grime=("#48545E", 0.11), grime_z=(0.45, 2.45),
                      rough_var=0.02, bump=("flake", 0.010, 18)),
    "PaintWhite": dict(mottle=(2.0, 0.03), grime=("#BDBCB4", 0.13), streak=("#B4B3AB", 0.16),
                       salt=("#C9C6BC", 0.20), scuff=("#C8C7BF", 0.22), rough_var=0.08, bump=("peel", 0.02, 9)),
    "PaintRed": dict(mottle=(2.0, 0.05), grime=("#8E4A44", 0.22), streak=("#9C544C", 0.20),
                     salt=("#C6BEB2", 0.20), scuff=("#C05A50", 0.25), rough_var=0.08, bump=("peel", 0.02, 9)),
    "PaintYellow": dict(mottle=(2.0, 0.05), grime=("#A88E3A", 0.22), streak=("#B49A44", 0.18),
                        salt=("#CEC6B4", 0.20), scuff=("#D8BE4A", 0.22), rough_var=0.08, bump=("peel", 0.02, 9)),
    "BumperPlastic": dict(mottle=(3.0, 0.06), grime=("#2A2C2E", 0.28), salt=("#8E8C86", 0.16),
                          rough_var=0.08, bump=("grain", 0.10, 26)),
    "ArchPlastic": dict(mottle=(3.0, 0.06), grime=("#26282A", 0.30), salt=("#87857F", 0.18),
                        rough_var=0.08, bump=("grain", 0.12, 22)),
    "BlackPlastic": dict(mottle=(4.0, 0.05), grime=("#1E2022", 0.22), rough_var=0.06, bump=("grain", 0.08, 32)),
    "BlackMetal": dict(mottle=(2.0, 0.04), grime=("#22262A", 0.18), streak=("#4A5156", 0.16),
                       rough_var=0.05, bump=("peel", 0.02, 8)),
    "Rubber": dict(mottle=(5.0, 0.08), grime=("#3E3C38", 0.30), rough_var=0.08, bump=("grain", 0.10, 36)),
    "Tyre": dict(mottle=(4.0, 0.05), grime=("#2E2B26", 0.30), salt=("#8C8880", 0.16),
                 rough_var=0.06, bump=("grain", 0.12, 28)),
    "RimSilver": dict(mottle=(3.0, 0.04), grime=("#6E7174", 0.20), salt=("#B8B4AA", 0.14), rough_var=0.06),
    "RimDark": dict(mottle=(3.0, 0.05), grime=("#2A2C2E", 0.22), rough_var=0.08),
    "BrakeSteel": dict(mottle=(3.0, 0.05), grime=("#4A4C4E", 0.25), rough_var=0.10),
    "Underseal": dict(mottle=(2.0, 0.10), grime=("#1E2022", 0.35), salt=("#7E7B74", 0.20),
                      rough_var=0.08, bump=("grain", 0.15, 20)),
    "WheelWell": dict(mottle=(2.0, 0.08), grime=("#1B1D1F", 0.30), rough_var=0.06, bump=("grain", 0.12, 24)),
    "InteriorDark": dict(mottle=(4.0, 0.05), grime=("#33363A", 0.20), rough_var=0.06, bump=("grain", 0.08, 32)),
    "InteriorMid": dict(mottle=(4.0, 0.05), grime=("#41464B", 0.20), rough_var=0.06, bump=("grain", 0.08, 32)),
    "SeatFabric": dict(mottle=(6.0, 0.07), grime=("#3A3D42", 0.22), rough_var=0.05, bump=("weave", 0.10, 38)),
    "SeatAccent": dict(mottle=(5.0, 0.04), grime=("#A89830", 0.18), rough_var=0.05, bump=("weave", 0.10, 38)),
    "Headliner": dict(mottle=(5.0, 0.04), grime=("#8E9294", 0.18), rough_var=0.05, bump=("grain", 0.08, 30)),
    "Carpet": dict(mottle=(8.0, 0.08), grime=("#1E2022", 0.30), rough_var=0.05, bump=("grain", 0.12, 30)),
    "Webbing": dict(mottle=(6.0, 0.08), grime=("#3E4144", 0.25), rough_var=0.05, bump=("weave", 0.12, 38)),
    "KitOrange": dict(mottle=(3.0, 0.05), grime=("#A84E20", 0.20), salt=("#C9B6A6", 0.18), rough_var=0.06),
    "KitYellow": dict(mottle=(3.0, 0.05), grime=("#9C8524", 0.20), rough_var=0.06),
    "LensWhite": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "LensAmber": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "LensRed": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "LensReverse": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "GlassSeal": dict(mottle=(6.0, 0.04), rough_var=0.04, bump=("grain", 0.06, 30)),
    "PlateWhite": dict(mottle=(3.0, 0.03), grime=("#B8B8B0", 0.16), rough_var=0.05),
    "PlateYellow": dict(mottle=(3.0, 0.03), grime=("#A08A34", 0.18), rough_var=0.05),
    "Glass": dict(rough_var=0.02),
}
# bump only (constant base / roughness; metals keep a clean albedo)
BUMP_ONLY = {"Chrome": ("brushed", 0.04, 200), "Stainless": ("brushed", 0.06, 200),
             "Aluminium": ("brushed", 0.05, 150), "Exhaust": ("brushed", 0.05, 140)}


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
    elif kind == "flake":     # fine metallic flake under the clear coat
        n = N("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 3.0
        n.inputs["Detail"].default_value = 2.0
        n.inputs["Roughness"].default_value = 0.5
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
    """(colour socket, roughness socket) for a PROC slot: mottle, grime, streaks, salt, scuffs, rough variation."""
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
        fac = mr.outputs[0]
        if key == "grime" and spec.get("grime_z"):
            sep = N("ShaderNodeSeparateXYZ")
            L(coord, sep.inputs[0])
            zr = N("ShaderNodeMapRange")
            zr.inputs["From Min"].default_value, zr.inputs["From Max"].default_value = spec["grime_z"]
            zr.inputs["To Min"].default_value, zr.inputs["To Max"].default_value = 1.0, 0.0
            L(sep.outputs["Z"], zr.inputs["Value"])
            mul = N("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            L(fac, mul.inputs[0])
            L(zr.outputs[0], mul.inputs[1])
            fac = mul.outputs[0]
        gcol = N("ShaderNodeRGB")
        gcol.outputs[0].default_value = _hex_srgb(cc) + (1.0,)
        mx = N("ShaderNodeMix")
        mx.data_type = "RGBA"
        L(fac, mx.inputs["Factor"])
        L(col, _ci(mx, 0))
        L(gcol.outputs[0], _ci(mx, 1))
        col = _co(mx)
    rough_mods = []
    for key, sc, rng in (("salt", 0.7, (0.58, 0.74)), ("scuff", 2.2, (0.62, 0.74))):
        if key not in spec:
            continue
        cc, amt = spec[key]
        g = N("ShaderNodeTexNoise")
        g.inputs["Scale"].default_value = sc
        g.inputs["Detail"].default_value = 2.0
        g.inputs["Roughness"].default_value = 0.45
        try:   # 4D noise with a per-key W so salt and scuffs do not share a pattern
            g.noise_dimensions = "4D"
            g.inputs["W"].default_value = 3.7 if key == "salt" else 8.1
        except (AttributeError, TypeError, KeyError):
            pass
        L(coord, g.inputs["Vector"])
        mr = N("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = rng
        mr.inputs["To Max"].default_value = amt
        L(g.outputs["Fac"], mr.inputs["Value"])
        fac = mr.outputs[0]
        if key == "grime" and spec.get("grime_z"):
            sep = N("ShaderNodeSeparateXYZ")
            L(coord, sep.inputs[0])
            zr = N("ShaderNodeMapRange")
            zr.inputs["From Min"].default_value, zr.inputs["From Max"].default_value = spec["grime_z"]
            zr.inputs["To Min"].default_value, zr.inputs["To Max"].default_value = 1.0, 0.0
            L(sep.outputs["Z"], zr.inputs["Value"])
            mul = N("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            L(fac, mul.inputs[0])
            L(zr.outputs[0], mul.inputs[1])
            fac = mul.outputs[0]
        gcol = N("ShaderNodeRGB")
        gcol.outputs[0].default_value = _hex_srgb(cc) + (1.0,)
        mx = N("ShaderNodeMix")
        mx.data_type = "RGBA"
        L(fac, mx.inputs["Factor"])
        L(col, _ci(mx, 0))
        L(gcol.outputs[0], _ci(mx, 1))
        col = _co(mx)
        rough_mods.append((mr.outputs[0], 0.2 if key == "salt" else 0.12))
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
    rgh = rr.outputs[0]
    for fac, d in rough_mods:   # salt crust / scuffs are matt
        ad = N("ShaderNodeMath")
        ad.operation = "MULTIPLY_ADD"
        L(fac, ad.inputs[0])
        ad.inputs[1].default_value = d
        L(rgh, ad.inputs[2])
        ad.use_clamp = True
        rgh = ad.outputs[0]
    return col, rgh


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
    if name in PROC or name in BUMP_ONLY:
        _proc_tree(mat, name, bsdf, hexc, rough, metal)
    return mat


# --------------------------------------------------------------------------- mesh accumulator
class Geo:
    def __init__(self, hi):
        self.hi = hi
        self.bm = bmesh.new()
        self.mats = []

    def bevel_sharp(self, faces, offset, angle=25, segments=None):
        """Round the sharp edges of a just-built component (chamfer on LOD0, 2-3 segments on _HP)."""
        if offset <= 0 or not faces:
            return
        fs = set(faces)
        edges = {e for f in faces for e in f.edges
                 if len(e.link_faces) == 2 and all(lf in fs for lf in e.link_faces)
                 and e.calc_face_angle(0.0) > math.radians(angle)}
        if not edges:
            return
        seg = segments or 1     # single 45 deg chamfer: 2+ segment bevels bake normals past 60 deg (check_textures)
        try:
            bmesh.ops.bevel(self.bm, geom=list(edges) + list({v for e in edges for v in e.verts}), offset=offset,
                            segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        except Exception as exc:  # keep building; a failed bevel only loses the rounding
            print("[vehgeo] bevel skipped:", exc)

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


def tube(g, corners, r, mat, seg, fillet=0.3, fseg=4, caps=True, radii=None):
    pts = rounded_path([Vector(c) for c in corners], fillet, fseg) if len(corners) > 2 else [Vector(c) for c in corners]
    rr = None
    if radii:
        rr = []
        for p in pts:
            best, bd = radii[0], 1e9
            for c, r in zip(corners, radii):
                d = (Vector(c) - p).length
                if d < bd:
                    bd, best = d, r
            rr.append(best)
    return sweep(g, pts, circle_profile(r, seg), mat, cap0=caps, cap1=caps, radii=rr)


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


def lathe(g, axis_origin, axis, profile, seg, mat, matfn=None, recalc=True):
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
    return g.rings(rings, mat, matfn=matfn, recalc=recalc)


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


def text_mesh(body, size, extrude=0.0, font_scale_x=1.0, resolution=3):
    cu = bpy.data.curves.new("TXT_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.resolution_u = resolution
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


# --------------------------------------------------------------------------- smooth body shells (shared by _01.._03)
def spline(pts, x):
    """Monotone cubic (Fritsch-Carlson) through (x, v) keys, flat outside. Per-segment smoothstep stopped the slope at
    every key and terraced bonnets and roofs."""
    n = len(pts)
    if x <= pts[0][0]:
        return pts[0][1]
    if x >= pts[-1][0]:
        return pts[-1][1]
    d = [(pts[i + 1][1] - pts[i][1]) / (pts[i + 1][0] - pts[i][0]) for i in range(n - 1)]
    m = [d[0]] + [0.0 if d[i - 1] * d[i] <= 0 else 0.5 * (d[i - 1] + d[i]) for i in range(1, n - 1)] + [d[-1]]
    for i in range(n - 1):
        if d[i] == 0:
            m[i] = m[i + 1] = 0.0
        else:
            a, b = m[i] / d[i], m[i + 1] / d[i]
            s = a * a + b * b
            if s > 9:
                t = 3 / math.sqrt(s)
                m[i], m[i + 1] = t * a * d[i], t * b * d[i]
    for i in range(n - 1):
        (x0, v0), (x1, v1) = pts[i], pts[i + 1]
        if x <= x1:
            h = x1 - x0
            t = (x - x0) / h
            t2, t3 = t * t, t * t * t
            return ((2 * t3 - 3 * t2 + 1) * v0 + (t3 - 2 * t2 + t) * h * m[i] + (-2 * t3 + 3 * t2) * v1
                    + (t3 - t2) * h * m[i + 1])
    return pts[-1][1]


def _cr(p0, p1, p2, p3, t):
    """Centripetal Catmull-Rom point between p1 and p2 (no loops or overshoot on uneven spacing)."""
    def tj(ti, a, b):
        return ti + max((b - a).length, 1e-6) ** 0.5
    t0 = 0.0
    t1 = tj(t0, p0, p1)
    t2 = tj(t1, p1, p2)
    t3 = tj(t2, p2, p3)
    u = t1 + (t2 - t1) * t
    a1 = p0 * ((t1 - u) / (t1 - t0)) + p1 * ((u - t0) / (t1 - t0))
    a2 = p1 * ((t2 - u) / (t2 - t1)) + p2 * ((u - t1) / (t2 - t1))
    a3 = p2 * ((t3 - u) / (t3 - t2)) + p3 * ((u - t2) / (t3 - t2))
    b1 = a1 * ((t2 - u) / (t2 - t0)) + a2 * ((u - t0) / (t2 - t0))
    b2 = a2 * ((t3 - u) / (t3 - t1)) + a3 * ((u - t1) / (t3 - t1))
    return b1 * ((t2 - u) / (t2 - t1)) + b2 * ((u - t1) / (t2 - t1))


def _nb(r, j, closed):
    n = len(r)
    if closed:
        return r[(j - 1) % n], r[j % n], r[(j + 1) % n], r[(j + 2) % n]
    p1, p2 = r[j], r[j + 1]
    p0 = r[j - 1] if j > 0 else p1 * 2 - p2
    p3 = r[j + 2] if j + 2 < n else p2 * 2 - p1
    return p0, p1, p2, p3


def resample(r, subs, closed):
    """Ring r with segment j split into subs[j] pieces along a centripetal Catmull-Rom through its vertices."""
    out = []
    for j, k in enumerate(subs):
        p0, p1, p2, p3 = _nb(r, j, closed)
        out += [p1.copy()] + [_cr(p0, p1, p2, p3, s / k) for s in range(1, k)]
    if not closed:
        out.append(r[-1].copy())
    return out


LOFT_TOL = {False: (0.03, 2, 2), True: (0.0025, 8, 8)}   # LOD0 / _HP: sag tolerance (studs), max splits (ring, length)


def refine_rings(ring_fn, ys, closed, hi):
    """Rings of ring_fn through ys, refined where the shape bends: a station interval is split while its mid ring sits
    more than the tolerance off the chord, a ring segment is split while its Catmull-Rom midpoint does. The _HP gets a
    tight tolerance so the baked normal map carries a smooth surface onto the lighter LOD0. Returns (rings, src_i,
    src_j): source station / segment index of every output interval / segment (material functions keep working)."""
    tol, rcap, ycap = LOFT_TOL[bool(hi)]
    out_y, src_i = [], []
    for i, (a, b) in enumerate(zip(ys, ys[1:])):
        ra, rb, rm = ring_fn(a), ring_fn(b), ring_fn(0.5 * (a + b))
        dev = max((m - (p + q) * 0.5).length for p, q, m in zip(ra, rb, rm))
        k = min(ycap, max(1, math.ceil(math.sqrt(dev / tol))))
        out_y += [a + (b - a) * s / k for s in range(k)]
        src_i += [i] * k
    out_y.append(ys[-1])
    raw = [ring_fn(y) for y in out_y]
    nseg = len(raw[0]) if closed else len(raw[0]) - 1
    zmin = min(p.z for p in raw[0])
    subs = []
    for j in range(nseg):
        dev = 0.0
        if all(abs(raw[0][(j + e) % len(raw[0])].z - zmin) < 1e-6 for e in (0, 1)):
            subs.append(1)      # flat floor: hidden, and splitting it would only bow it
            continue
        for r in raw:
            p0, p1, p2, p3 = _nb(r, j, closed)
            dev = max(dev, (_cr(p0, p1, p2, p3, 0.5) - (p1 + p2) * 0.5).length)
        subs.append(min(rcap, max(1, math.ceil(math.sqrt(dev / tol)))))
    src_j = [j for j, k in enumerate(subs) for _ in range(k)]
    return [resample(r, subs, closed) for r in raw], src_i, src_j


def smooth_loft(g, ring_fn, ys, mat, closed=True, cap0=False, cap1=False, matfn=None):
    """Lofted panel through ring_fn(y) at ys, refined for this LOD (refine_rings). Returns the rings (for Snap)."""
    rings, si, sj = refine_rings(ring_fn, ys, closed, g.hi)
    mf = (lambda i, j: matfn(si[i], sj[j])) if matfn else None
    g.rings(rings, mat, closed=closed, cap0=cap0, cap1=cap1, matfn=mf)
    return rings


class Snap:
    """Nearest-point snapping onto lofted ring grids (the shell exactly as built for one LOD): lamps, grilles and
    shut lines sit flush on the panel instead of floating as boxes. centre: a point inside the body (normal sign)."""

    def __init__(self, grids, centre):
        from mathutils.bvhtree import BVHTree
        verts, polys, alt, caps = [], [], [], []
        for rings, closed in grids:
            n, base = len(rings[0]), len(verts)
            for r in rings:
                verts += [tuple(p) for p in r]
            if closed:     # closed lofts are capped (nose / tail faces)
                caps += [tuple(range(base, base + n)), tuple(range(base + (len(rings) - 1) * n, base + len(rings) * n))]
            for i in range(len(rings) - 1):
                for j in range(n if closed else n - 1):
                    k = (j + 1) % n
                    a, b, c, d = base + i * n + j, base + i * n + k, base + (i + 1) * n + k, base + (i + 1) * n + j
                    polys += [(a, b, c), (a, c, d)]
                    alt += [(a, b, d), (b, c, d)]
        self.bvh = BVHTree.FromPolygons(verts, polys + caps)
        # the other diagonal: a twisted quad can be triangulated either way on export, the lens must clear both
        self.alt = BVHTree.FromPolygons(verts, alt + caps)
        self.centre = Vector(centre)

    def at(self, p, depth=0.0, toward=None):
        """(point, outward normal) on the surface nearest p, moved `depth` inwards (negative: proud). toward (x, y):
        instead project p horizontally from outside toward that plan point (points round a corner can sit inside the
        body, where the nearest surface is ambiguous)."""
        p = Vector(p)
        loc = None
        if toward:
            d = Vector((toward[0] - p.x, toward[1] - p.y, 0.0)).normalized()
            loc, nrm, _, _ = self.bvh.ray_cast(p - d * 4.0, d, 8.0)
        if loc is None:
            loc, nrm, _, _ = self.bvh.find_nearest(p)
        n = Vector()
        for o in ((0, 0, 0), (0.07, 0, 0), (-0.07, 0, 0), (0, 0.07, 0), (0, -0.07, 0), (0, 0, 0.07), (0, 0, -0.07)):
            q = self.bvh.find_nearest(loc + Vector(o))
            if q[0] is not None:     # blurred face normals: recesses and lenses stay unbroken across panel creases
                n += q[1] if q[1].dot(q[0] - self.centre) >= 0 else -q[1]
        nrm = n.normalized()
        hit = self.alt.ray_cast(loc + nrm * 0.1, -nrm, 0.2)[0]
        if hit is not None and (hit - loc).dot(nrm) > 0:
            loc = hit
        return loc - nrm * depth, nrm


def _poly_at(pts, s):
    """Point at parameter s (0..1 by arc length, linear extrapolation outside) on a polyline."""
    ls = [0.0]
    for a, b in zip(pts, pts[1:]):
        ls.append(ls[-1] + (b - a).length)
    d = s * ls[-1]
    i = 0
    while i < len(pts) - 2 and d > ls[i + 1]:
        i += 1
    if d < 0:
        i = 0
    seg = max(ls[i + 1] - ls[i], 1e-9)
    return pts[i] + (pts[i + 1] - pts[i]) * ((d - ls[i]) / seg)


class Strip:
    """A panel-conforming lamp / grille area between a top and a bottom edge curve (same point count, laid on the
    shell by snap). at(s, r, depth): s 0..1 along, r 0..1 top to bottom, depth below the panel; outside 0..1 extends."""

    def __init__(self, snap, tops, bots, k=16, toward=None):
        tops, bots = [Vector(p) for p in tops], [Vector(p) for p in bots]
        subs = [max(1, round(k / (len(tops) - 1)))] * (len(tops) - 1)
        self.top = resample(tops, subs, False)
        self.bot = resample(bots, subs, False)
        self.snap = snap
        self.toward = toward
        self.n = len(self.top)
        self.length = sum((b - a).length for a, b in zip(self.top, self.top[1:]))
        self.height = sum((t - b).length for t, b in zip(self.top, self.bot)) / self.n
        # sample positions along s, split where a lens chord would dip more than ~2 mm under a panel crease
        ss = [i / (self.n - 1) for i in range(self.n)]
        for _ in range(4):
            out = [ss[0]]
            for a, b in zip(ss, ss[1:]):
                sag = 0.0
                for r in (0.0, 0.5, 1.0):
                    pm, nm = self.at(0.5 * (a + b), r)
                    sag = max(sag, (pm - (self.at(a, r)[0] + self.at(b, r)[0]) * 0.5).dot(nm))
                if sag > 0.005:
                    out.append(0.5 * (a + b))
                out.append(b)
            ss = out
        self.ss = ss

    def span(self, s0, s1):
        return [s0 + (s1 - s0) * u for u in self.ss]

    def at(self, s, r, depth=0.0):
        t, b = _poly_at(self.top, s), _poly_at(self.bot, s)
        return self.snap.at(t + (b - t) * r, depth, self.toward)

    def rect(self, s0, s1, r0, r1, nr):
        """Closed ring round the (s0..s1, r0..r1) rectangle: span points per long side, nr per short side."""
        sp = self.span(s0, s1)
        ring = [(s, r0) for s in sp[:-1]]
        ring += [(s1, r0 + (r1 - r0) * k / nr) for k in range(nr)]
        ring += [(s, r1) for s in reversed(sp[1:])]
        ring += [(s0, r1 - (r1 - r0) * k / nr) for k in range(nr)]
        return ring


def strip_patch(g, st, s0, s1, r0, r1, depth, mat, nr=2):
    """Grid laid on the panel over (s0..s1, r0..r1), facing out."""
    rows = [[st.at(s, r0 + (r1 - r0) * m / nr, depth)[0] for s in st.span(s0, s1)] for m in range(nr + 1)]
    fs = g.rings(rows, mat, closed=False, recalc=False)
    g.orient(fs, lambda c: st.snap.at(c)[1])
    return fs


def strip_band(g, st, ra, da, rb, db, mat, nr=2):
    """Ribbon between two rectangles (s0, s1, r0, r1) at depths da / db: shut-line gaskets, recess walls."""
    rings = [[st.at(s, r, d)[0] for s, r in st.rect(*rc, nr)] for rc, d in ((ra, da), (rb, db))]
    fs = g.rings(rings, mat, closed=True, recalc=False)
    g.orient(fs, lambda c: st.snap.at(c)[1])
    return fs


def strip_cup(g, st, s, r, radius, depth, mat, rim_mat=None, seg=12):
    """Round reflector cup / projector on the floor of a lamp recess (_HP), facing out along the panel normal."""
    p, n = st.at(s, r, depth)
    lathe(g, tuple(p), tuple(n), [(0.0, 0.0), (radius * 0.55, 0.004), (radius * 0.92, 0.012), (radius, 0.022),
                                  (radius * 1.08, 0.026)], seg, rim_mat or mat,
          matfn=lambda i, j: mat if i < 2 else (rim_mat or mat))


def flush_lamp(g, st, lens_mat, inner=None, depth=0.035, gasket=0.02, gasket_mat="SeamDark", rows=2, proud=0.02,
               floor="Aluminium"):
    """Lamp lens flush with the panel, ringed by a dark shut line. LOD0: just the conforming lens (its look is baked);
    _HP: a recess `depth` deep with glossy black walls and `inner(g, st, depth)` building reflectors, projectors and
    light guides on its floor, which the bake projects onto the lens."""
    ws, wr = gasket / max(st.length, 1e-3), gasket / max(st.height, 1e-3)
    # proud enough that its chords stay outside the panel's facets on convex corners and quad-split creases
    strip_band(g, st, (-ws, 1 + ws, -wr, 1 + wr), -proud * 0.6, (0, 1, 0, 1), -proud, gasket_mat, nr=rows)
    if not g.hi:
        return strip_patch(g, st, 0, 1, 0, 1, -proud, lens_mat, nr=rows)
    a, b = 0.03 / max(st.length, 1e-3), 0.03 / max(st.height, 1e-3)
    strip_band(g, st, (0, 1, 0, 1), -proud, (a, 1 - a, b, 1 - b), depth, "LensDark", nr=rows)
    strip_patch(g, st, a, 1 - a, b, 1 - b, depth, floor, nr=rows)
    if inner:
        inner(g, st, depth)

