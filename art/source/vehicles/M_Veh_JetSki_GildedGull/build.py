"""M_Veh_JetSki_GildedGull: premium (Robux) luxe jet ski, on the M_Veh_JetSki frame and markers (see
art/source/vehicles/_JetSkiPremium/premium.py).

Shared sport hull (premium.use_sport_hull) in pearl-white gelcoat over a polished gold underbody, chine, sponsons and
bow cap, a polished gold rub rail, double gold pinstripes and a gold gull emblem on the topsides, gold hood
pinstripes, teak footwell, hatch and sled decking with black caulking, a tight cream quilted-leather saddle with gold
lock stitching and piping, piano-black console, gold bars and fittings, two swept gold gull-wing fins on the stern
quarters. Sets: Hull (hull, seat, trim) and Sled (sled, fittings + fins, cockpit), 1024 + _Wet.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- \
      --build art/source/vehicles/M_Veh_JetSki_GildedGull/build.py --steps build,lod,bake,validate,export,turntable
"""
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_JetSkiPremium"))
import premium as X  # noqa: E402

P, R, M, smooth = X.P, X.R, X.M, X.smooth
NAME = "M_Veh_JetSki_GildedGull"

R.PALETTE.update({
    "HullCharcoal": ("#D4AF5A", 0.17, 1.0),     # polished gold underbody, chine and sponsons
    "PWCOrange": ("#EAE3D3", 0.25, 0.0),        # pearl-white gelcoat (name kept: every base slot follows)
    "PWCOrangeDark": ("#E6E1D6", 0.20, 0.0),
    "PWCDeck": ("#E8E1D2", 0.25, 0.0),
    "DeckGrey": ("#CFC7B8", 0.34, 0.0),         # footwell walls, pedestal: darker pearl
    "RubBlack": ("#D4AF5A", 0.16, 1.0),         # polished gold rub rail
    "NonSlip": ("#8E6C4C", 0.60, 0.0),          # teak
    "SledOrange": ("#E6E1D6", 0.22, 0.0),
    "SledHull": ("#CFC7B8", 0.32, 0.0),
    "Stainless": ("#D4AF5A", 0.16, 1.0),        # polished gold fittings, grab rails
    "Aluminium": ("#D4AF5A", 0.18, 1.0),        # gold handlebar, mast
    "Bolt": ("#D4AF5A", 0.18, 1.0),
    "Gold": ("#D4AF5A", 0.16, 1.0),
    "BlackPlastic": ("#232427", 0.16, 0.0),     # piano black console, housings
    "HoseBlack": ("#CDB892", 0.50, 0.0),        # sled handles wrapped in cream leather
    "GripRubber": ("#A07E58", 0.55, 0.0),       # tan leather grips
    "Quilt": ("#D9C9A7", 0.45, 0.0),            # cream leather
    "LeatherSide": ("#CDBC98", 0.45, 0.0),
})
for k in ("Stainless", "Aluminium", "Bolt"):
    R.BUMP_ONLY.pop(k, None)
METAL = dict(mottle=(3, 0.015), rough_var=0.04)
PEARL = dict(mottle=(1.2, 0.02), grime=("#CBC4B6", 0.10), salt=("#D9D3C7", 0.10), rough_var=0.05, bump=("peel", 0.015, 6))
R.PROC.update({
    "HullCharcoal": dict(METAL, salt=("#EDE6D2", 0.1), scuff=("#A88A48", 0.15)), "RubBlack": dict(METAL), "Gold": dict(METAL),
    "PWCOrange": dict(PEARL, zgrime=("#B9B19F", 0.2, 0.75, 0.95), zsalt=("#D9D6CC", 0.6, 1.0, 1.3),
                      scuff=("#C9C1B1", 0.25)),
    "PWCOrangeDark": dict(PEARL), "PWCDeck": dict(PEARL),
    "DeckGrey": dict(mottle=(2, 0.03), grime=("#B8B0A0", 0.15), rough_var=0.05),
    "SledOrange": dict(PEARL, zgrime=("#B9B19F", 0.3, 1.05, 1.25)),
    "SledHull": dict(mottle=(1.5, 0.03), grime=("#B4AC9C", 0.2), rough_var=0.05),
    "NonSlip": dict(mottle=(2, 0.04), grime=("#6E553C", 0.12), rough_var=0.06),
    "HoseBlack": dict(mottle=(5, 0.04), rough_var=0.06, bump=("grain", 0.12, 60)),
    "GripRubber": dict(mottle=(5, 0.05), grime=("#7E6446", 0.15), salt=("#D9D6CC", 0.4), scuff=("#7A5E40", 0.3),
                       rough_var=0.08, bump=("grain", 0.14, 60)),
    "Quilt": dict(mottle=(3, 0.03), grime=("#BFAE8C", 0.12), rough_var=0.06, bump=("grain", 0.08, 70)),
    "LeatherSide": dict(mottle=(3, 0.03), grime=("#B8A682", 0.12), rough_var=0.06, bump=("grain", 0.1, 70)),
    "BlackPlastic": dict(mottle=(3, 0.02), rough_var=0.03),
})


X.use_sport_hull()
BOW_CAP = P.NOSE + 0.75


def seg_mat(k, y):
    f = P.footwell(y)
    if k <= 3:
        return "HullCharcoal"
    if k in (5, 6, 7):
        return "RubBlack"
    if y < BOW_CAP:
        return "Gold"                            # polished gold bow cap
    if k == 10:
        return "DeckGrey" if f > 0.5 else "PWCOrange"
    if k >= 11:
        return "NonSlip" if f > 0.5 else "PWCDeck"
    return "PWCOrange"


P._seg_mat = seg_mat


def gull(s):
    """Gull glyph centre line: a soft M (wings up, body dip), s in -1..1 -> (dy, dz, half width)."""
    a = abs(s)
    return 0.36 * s, 0.14 * math.sin(math.pi * min(a / 0.55, 1.0)) * (1 - 0.35 * max(0.0, (a - 0.55) / 0.45)) \
        - 0.05 * max(0.0, (a - 0.55) / 0.45) - 0.02, 0.032 * (1 - 0.75 * a)


def decals(g):
    off = P.OFF
    for sx in (1, -1):
        # double gold pinstripe, bow to stern, kicking up at the bow
        for t0, t1 in ((0.80, 0.84), (0.88, 0.90)):
            X.topside_quad(g, sx, [(-4.3, t0 + 0.06), (-4.3, t1 + 0.06), (4.75, t1), (4.75, t0)], M(g, "Gold"), off,
                           48 if g.hi else 20, 1)
        n = 24 if g.hi else 12
        X.topside_stroke(g, sx, -2.75, 0.45, [gull(-1 + 2 * i / n) for i in range(n + 1)], M(g, "Gold"), off + 0.002)
    for s in (1, -1):
        f0, f1 = (0.8, 0.83) if s > 0 else (-0.83, -0.8)
        X.deck_strip(g, f0, f1, P.NOSE + 0.12, -1.95, M(g, "Gold"), nu=40 if g.hi else 18)


def wings(g):
    """Two swept gold gull-wing fins on the stern quarters (~40 cm): rise off the gunwale, kink outboard at the knee,
    swept back; lens section thinning to the tip."""
    n = 14 if g.hi else 8
    m = 18 if g.hi else 10
    yr = 3.6
    root = Vector((P.half_beam(yr) - 0.24, 0, P.gunwale_z(yr) - 0.03))
    path = R.rounded_path([root, root + Vector((0.2, 0, 0.85)), root + Vector((0.95, 0, 1.3))], 0.26, 6 if g.hi else 3)
    cum = [0.0]
    for a, b in zip(path, path[1:]):
        cum.append(cum[-1] + (b - a).length)
    total = cum[-1]

    def at(s):
        d = s * total
        for i in range(len(path) - 1):
            if cum[i + 1] >= d:
                u = (d - cum[i]) / max(cum[i + 1] - cum[i], 1e-6)
                return path[i].lerp(path[i + 1], u), (path[i + 1] - path[i]).normalized()
        return path[-1], (path[-1] - path[-2]).normalized()
    for sx in (1, -1):
        rings = []
        for i in range(n + 1):
            s = i / n
            p, t = at(s)
            nrm = Vector((-t.z, 0, t.x))
            yl, yt = 3.1 + 1.45 * s ** 0.8, 4.35 + 0.45 * s ** 0.9   # swept ~30 deg aft, tapering to the tip
            th = 0.15 * (1 - 0.7 * s)
            ring = []
            for k in range(m):
                th_k = 2 * math.pi * k / m
                c = (1 - math.cos(th_k)) / 2
                o = 0.5 * th * math.sin(th_k) * (1 - 0.6 * c)
                q = p + nrm * o
                ring.append(Vector((sx * q.x, yl + (yt - yl) * c, q.z)))
            rings.append(ring)
        g.rings(rings, M(g, "Gold"), closed=True, cap0=True, cap1=True)


def trim(g):
    decals(g)
    X.sponsons(g, "HullCharcoal")


def fittings(g):
    X.fittings(g)
    wings(g)


def sculpt(c):
    """Plush saddle: a soft crown on the cushion."""
    if c.z < 2.5:
        return c
    r = min(abs(c.x) / 0.6, 1.0)
    return Vector((c.x, c.y, c.z + 0.012 * (1 - r * r)))


seat = X.make_seat(["DeckGrey", "Gold", "LeatherSide", "LeatherSide", "Gold", "Quilt", "Quilt", "Quilt"], "Quilt", 3.4,
                   sculpt, step=lambda y: 0.12 * smooth(1.9, 2.6, y))


def sled(g):
    P.sled(g)
    X.sled_pinline(g, M(g, "Gold"), 0.3, 0.04)


STYLE = {
    "name": NAME, "tex": "GildedGull",
    "seat": seat, "trim": trim, "sled": sled, "sled_text": X.rescue_text("Gold"), "fittings": fittings,
    "hull_hp": [P.foredeck], "uv_boost": {1: 1.6, 2: 1.4}, "hull_sharp": 45,
    "wear_hull": {"edge": 0.05, "edge_color": (0.82, 0.79, 0.72), "salt": 0.06, "salt_color": (0.84, 0.82, 0.77),
                  "rust": 0.0},
    "wear_sled": {"edge": 0.05, "edge_color": (0.82, 0.79, 0.72), "salt": 0.06, "salt_color": (0.84, 0.82, 0.77),
                  "rust": 0.0},
    "closeups": [
        {"name": "seat_quilt_1m", "target": (0.0, 1.0, 2.72), "dist": 3.0, "az": 115, "el": 40},
        {"name": "gull_wing", "target": (1.9, 3.8, 2.2), "dist": 4.5, "az": 125, "el": 22},
        {"name": "emblem_pinstripe", "target": (1.5, -2.75, 1.25), "dist": 4.5, "az": 75, "el": 8},
        {"name": "stern_quarter", "target": (1.4, 4.4, 1.4), "dist": 5.0, "az": 140, "el": 15},
        {"name": "teak_footwell", "target": (0.9, 0.2, 1.6), "dist": 4.5, "az": 55, "el": 50},
    ],
}


def build():
    X.pattern("NonSlip", "teak")
    X.pattern("Quilt", "quilt")
    for k in ("PWCOrange", "PWCDeck", "SledOrange"):
        X.pattern(k, "pearl")
    return X.build_style(STYLE)
