"""Shared geometry helpers for M_Veh_Ambulance (1 Blender unit = 1 stud, 3 studs per metre).

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
    # name: (sRGB hex, roughness, metal). Invented Gale Isles Lifeguard livery: off-white service paint, red and
    # yellow battenburg, satin black trim, dark tinted glass.
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
    "RimSilver": ("#E8ECEE", 0.34, 1.0),
    "RimDark": ("#3C4044", 0.55, 0.0),
    "BrakeSteel": ("#CACED1", 0.48, 0.0),       # cast iron reads matt grey, not bright metal
    "Exhaust": ("#DEE0E2", 0.42, 1.0),
    "Chrome": ("#F4F6F7", 0.16, 1.0),
    "Stainless": ("#F2F4F5", 0.22, 1.0),
    "Aluminium": ("#E8ECEE", 0.45, 1.0),
    "Glass": ("#1C252B", 0.05, 0.0),
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
    "PlateLetter": ("#26282A", 0.50, 0.0),
    "Webbing": ("#323438", 0.86, 0.0),
    "KitOrange": ("#E8641C", 0.66, 0.0),
    "KitYellow": ("#E2C81E", 0.62, 0.0),
    # Gale Isles Ambulance (invented): high-vis yellow with green, matching the hospital heart-wave mark
    "PaintGreen": ("#1E8C3C", 0.36, 0.0),
    "PaintHiVis": ("#FADC1E", 0.38, 0.0),
    "LetterGreen": ("#1B7A36", 0.46, 0.0),
    "LetterDark": ("#2A2C2E", 0.46, 0.0),
    "RoundelWhite": ("#EAEBE6", 0.40, 0.0),
    "ReflRed": ("#B4242A", 0.28, 0.0),
    "ReflYellow": ("#E8C21C", 0.26, 0.0),
    "LensBlue": ("#2F55D4", 0.10, 0.0),
    "BeaconMount": ("#26292C", 0.46, 0.0),
    "Underseal": ("#26282A", 0.90, 0.0),
    "WheelWell": ("#202224", 0.90, 0.0),
    "LetterRed": ("#C22A2E", 0.50, 0.0),
    "LetterWhite": ("#E6E7E3", 0.50, 0.0),
}

# procedural slots (baked through bake.custom_material; bump goes into the NOR through the _HP shading normal):
# mottle (noise scale, amount), grime (colour, amount), streak (colour, amount), salt / scuff (colour, amount),
# rough_var, bump (kind, strength, scale)
PROC = {
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
    "PaintGreen": dict(mottle=(2.0, 0.05), grime=("#2C5A34", 0.22), streak=("#3A6A40", 0.18),
                       salt=("#C6C0B4", 0.20), scuff=("#3E8A50", 0.22), rough_var=0.07, bump=("peel", 0.02, 9)),
    "PaintHiVis": dict(mottle=(2.0, 0.05), grime=("#A89030", 0.20), streak=("#B49C34", 0.20),
                       salt=("#CFC7B0", 0.22), scuff=("#DCC23C", 0.24), rough_var=0.07, bump=("peel", 0.02, 9)),
    "LetterGreen": dict(mottle=(2.0, 0.03), grime=("#2C6A3C", 0.16), rough_var=0.05),
    "LetterDark": dict(mottle=(2.0, 0.03), grime=("#2A2C2E", 0.14), rough_var=0.05),
    "RoundelWhite": dict(mottle=(2.0, 0.03), grime=("#BDBCB4", 0.14), salt=("#C9C6BC", 0.18), rough_var=0.06),
    "ReflRed": dict(mottle=(3.0, 0.04), grime=("#8E3A34", 0.20), rough_var=0.05),
    "ReflYellow": dict(mottle=(3.0, 0.04), grime=("#A88E30", 0.20), rough_var=0.05),
    "LensBlue": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "BeaconMount": dict(mottle=(3.0, 0.05), grime=("#1E2022", 0.22), rough_var=0.06, bump=("grain", 0.08, 30)),
    "LensWhite": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "LensAmber": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "LensRed": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "LensReverse": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "GlassSeal": dict(mottle=(6.0, 0.04), rough_var=0.04, bump=("grain", 0.06, 30)),
    "PlateWhite": dict(mottle=(3.0, 0.03), grime=("#B8B8B0", 0.16), rough_var=0.05),
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
        gcol = N("ShaderNodeRGB")
        gcol.outputs[0].default_value = _hex_srgb(cc) + (1.0,)
        mx = N("ShaderNodeMix")
        mx.data_type = "RGBA"
        L(mr.outputs[0], mx.inputs["Factor"])
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
        gcol = N("ShaderNodeRGB")
        gcol.outputs[0].default_value = _hex_srgb(cc) + (1.0,)
        mx = N("ShaderNodeMix")
        mx.data_type = "RGBA"
        L(mr.outputs[0], mx.inputs["Factor"])
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
