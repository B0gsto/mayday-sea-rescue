"""M_Veg_Wrack_Kit shared layout (docs/12 2.5): the atlas cell, the cell's sub-rects and the frond shapes.

Pure python (no bpy / numpy / PIL) so both `wrack_tex.py` (the atlas painter, system python3) and `wrackkit.py`
(the Blender geometry) read the same numbers: rects, real sizes in metres and the painted frond envelopes. The
painted silhouette and the card geometry then always agree; modelled vesicles sit on the painted bladders.

Atlas: shared marine atlas FoliageMarine / Main (art/source/materials/atlases.py), this kit owns the `M_Veg_Wrack`
cell: atlas UV u 0.250..0.750, v 0.750..1.000 (2048 x 1024 px of the 4096 master, 1024 x 512 at the 2048 ship size).
Each rect below is (s0, t0, s1, t1) inside the cell (s right, t up) plus the real surface it paints (metres, x
along u).
"""
M = 3.0                                                        # studs per metre

CELL = (0.250, 0.750, 0.750, 1.000)                            # atlas UV, v up (atlases.json)
RECTS = {
    "Mat":          (0.000, 0.000, 0.250, 0.250),              # encrusted rock under and around the mat
    "Strap":        (0.250, 0.000, 0.500, 0.250),              # young frayed straps, bright olive
    "Pod":          (0.500, 0.000, 0.625, 0.250),              # a cluster of air vesicles (solid geometry)
    "Holdfast":     (0.625, 0.000, 0.750, 0.250),              # the crown: holdfast disc and stubs
    "Fringe":       (0.000, 0.250, 1.000, 0.500),              # wrack fringe hanging over the rock edge
    "BladderFrond": (0.000, 0.500, 0.500, 1.000),              # Fucus vesiculosus, forked, paired bladders
    "EggFrond":     (0.500, 0.500, 1.000, 1.000),              # Ascophyllum nodosum, long strap, egg pods
}
# the real surface each rect paints (m): (x along u, y along v). Cards use the same numbers, so paint is not stretched.
RECT_M = {
    "Mat": (1.100, 1.100), "Strap": (0.300, 0.150), "Pod": (0.060, 0.060), "Holdfast": (0.160, 0.160),
    "Fringe": (1.600, 0.200), "BladderFrond": (0.400, 0.200), "EggFrond": (0.550, 0.275),
}

# frond cards: real card length x width (m) and the envelope of the painted clump (half-width as a share of the
# card's half width at t, t 0 base -> 1 tip). The geometry follows the envelope, alpha cuts the straps apart.
FROND_M = {"Bladder": (0.400, 0.075), "Egg": (0.550, 0.080), "Strap": (0.300, 0.070)}


def frond_env(kind, t):
    """Envelope of the painted clump: the card's half width as a share of the card's half width at t. Fairly flat
    (the straps converge at the base by themselves), so painted vesicles stay round and the geometry stays tight."""
    t = min(1.0, max(0.0, t))
    if kind == "Bladder":
        e = 0.50 + 0.50 * t ** 0.55
        return e * (1.0 - 0.06 * smooth(0.90, 1.0, t))
    if kind == "Egg":
        e = 0.55 + 0.45 * min(1.0, t * 2.0) ** 0.50
        return e * (1.0 - 0.08 * smooth(0.88, 1.0, t))
    e = 0.48 + 0.52 * t ** 0.50
    return e * (1.0 - 0.06 * smooth(0.90, 1.0, t))


def strap_hw(kind, t):
    """The painted MAIN strap's half width in metres (painter and geometry share it, so modelled vesicles land on
    the painted bladders)."""
    base = {"Bladder": 0.0092, "Egg": 0.0108, "Strap": 0.0056}[kind]
    tail = {"Bladder": 0.26, "Egg": 0.30, "Strap": 0.24}[kind]
    t = min(1.0, max(0.0, t))
    return base * 0.86 * (0.50 + 0.50 * smooth(0, 0.20, t)) * (1.0 - tail * smooth(0.84, 1.0, t))


def smooth(e0, e1, x):
    u = min(1.0, max(0.0, (x - e0) / max(e1 - e0, 1e-9)))
    return u * u * (3.0 - 2.0 * u)


# vesicles (both painted and modelled, same parametric spots): (t along the frond, side share of the half width,
# radius in m, elongate along the frond)
VESICLES = {
    "Bladder": [(0.30, -0.52, 0.0125), (0.30, 0.52, 0.0125), (0.45, -0.55, 0.0140), (0.45, 0.55, 0.0140),
                (0.60, -0.50, 0.0150), (0.62, 0.50, 0.0145), (0.76, -0.45, 0.0135), (0.78, 0.45, 0.0130),
                (0.90, -0.40, 0.0110), (0.92, 0.40, 0.0105)],
    "Egg": [(0.32, -0.22, 0.0170, 1.9), (0.44, 0.24, 0.0180, 2.0), (0.56, -0.24, 0.0185, 2.1),
            (0.68, 0.22, 0.0180, 2.0), (0.80, -0.22, 0.0165, 1.9), (0.91, 0.20, 0.0140, 1.8)],
    "Strap": [(0.12, -0.40, 0.0060), (0.20, 0.45, 0.0065), (0.30, -0.42, 0.0060)],
}


def rect_uv(rect, s, t, m=0.004):
    """Rect-local s across (0 left, 1 right), t up (0 bottom, 1 top) -> atlas UV (v up), inset by `m`."""
    s0, t0, s1, t1 = RECTS[rect]
    u0, v0, u1, v1 = CELL
    s, t = min(1.0 - m, max(m, s)), min(1.0 - m, max(m, t))
    return (u0 + (s0 + s * (s1 - s0)) * (u1 - u0), v0 + (t0 + t * (t1 - t0)) * (v1 - v0))


def rect_uv_wrap(rect, s, t):
    """As rect_uv, but s wraps 0..1 exactly (a strip that tiles across itself)."""
    s0, t0, s1, t1 = RECTS[rect]
    u0, v0, u1, v1 = CELL
    return (u0 + (s0 + min(1.0, max(0.0, s)) * (s1 - s0)) * (u1 - u0),
            v0 + (t0 + min(1.0, max(0.0, t)) * (t1 - t0)) * (v1 - v0))


def sig3(x):
    return float("%.3g" % x)
