"""Hydrofoil stage (L31-L40): the hull and nine pieces, from the owner-cleared concept (artifact f23406cb), in its numbers (hk.py).

Round 3 (art director 5.5, then 5): one joke, oversized turbines on a wide, low hull. Slim raked struts, one wide T-foil, one fin, nothing
pointed. L40 stays under the Upgrade Station gate: at most 38 studs at game scale x2.194. See RESULT.md.
"""
import math

from mathutils import Vector

import hk
from hk import DARK, FLAME, FLAME2, GLOW, GREY, ORANGE, SCREEN, WHITE, YELLOW

R = math.pi / 180
T = 5.5                          # hull bottom at L31 (sea at y 0.3)
RAKE = 25.0
FOIL_Y, TIP_Y = 1.0, -0.1        # the T-foil flies just over the sea, only the strut tips cut it
LIFT = 1.6                       # Sky Stilts: the foil set drops this far in the hull frame and the boat rises as much
LIFT_Z = LIFT * math.tan(RAKE * R)   # ...and slides aft along the rake (concept -z, asset +z)
MAIN_X, MAIN_Z, RUDDER_Z = 3.6, 2.0, -9.5    # where the struts leave the hull
STRUT = (0.7, 1.9)               # slim and rigid: width, chord
FOIL = dict(span=11.4, chord=1.7, sweep=2.5, tip=0.8)
PLAN = [(-11, 5.6), (1, 5.6), (7, 3.6), (12.8, 1.5), (14, 0.9)]
SEAT_TOP = T + 4.1
SEAT_X = -1.7                    # concept -x is asset +x: the driver sits off the centre line, so the one fin and the top jet can never hide him from the chase cam
CAP_SLOPE = 5.7                  # degrees: the stern deck falls towards the cockpit
JET = dict(x=9.2, y=T + 2.4, z=-5.5, r=3.4, ln=5.4)
FIN_BASE, FIN_TOP = T + 3.4, T + 6.4
TOPJET = dict(y=T + 8.4, z=-9.2, r=1.15, ln=3.2)
SIDES = ((1, "P"), (-1, "S"))    # concept +x is asset -x, port


def deck_y(z):
    return T + 3.87 + 0.18 - (z + 7.5) * math.tan(CAP_SLOPE * R)


def plan(z):
    for (a, wa), (b, wb) in zip(PLAN, PLAN[1:]):
        if a <= z <= b:
            return wa + (wb - wa) * (z - a) / (b - a)
    return PLAN[-1][1]


def strut_z(z_top, y):
    return z_top - (T - y) * math.tan(RAKE * R)


def strut(k, x, z_top, y0, y1, w, c, cell):
    """One straight raked strut of constant section, from y0 down to y1."""
    def ring(y):
        z, b = strut_z(z_top, y), 0.12
        return [(x - w / 2, y, z - c / 2 + b), (x - w / 2, y, z + c / 2 - b), (x - w / 2 + b, y, z + c / 2), (x + w / 2 - b, y, z + c / 2),
                (x + w / 2, y, z + c / 2 - b), (x + w / 2, y, z - c / 2 + b), (x + w / 2 - b, y, z - c / 2), (x - w / 2 + b, y, z - c / 2)]
    k.rings([ring(y0), ring(y1)], cell)


def body(k):
    t = T
    # a wide low wedge: keel, two long courses, a sloping blunt bow
    keel = {-11: 0, 1: 0, 7: 0, 12.8: 0.35, 14: 0.55}
    k.loft_z([(z, plan(z), t + keel[z], t + keel[z] + 0.4) for z in keel], WHITE)
    c1 = {-11: 1.4, 1: 1.4, 7: 1.4, 12.8: 1.3, 14: 1.15}
    k.loft_z([(z, plan(z) - 0.05, t + keel[z] + 0.35, t + c1[z]) for z in keel], ORANGE)
    c2 = [(-11, 2.4), (1, 2.4), (3.4, 2.4), (7, 2.1), (12.8, 1.5), (14, 1.25)]
    k.loft_z([(z, plan(z) - 0.1, t + c1.get(z, 1.4) - 0.05, t + y) for z, y in c2], ORANGE)
    # the wedge climbs on to a low stern; the deck falls to the cockpit, so the driver shows whole
    k.loft_z([(-11, 5.5, t + 2.35, t + 3.4), (-4, 5.5, t + 2.35, t + 3.4)], ORANGE)
    k.loft_z([(-10.95, 5.45, t + 3.35, t + 4.2), (-4.05, 5.45, t + 3.35, t + 3.5)], ORANGE)

    def cap():
        k.box((11.1, 0.36, 7.1), (0, 0, 0), WHITE, r=0.12)
        k.bigstuds([(x, z) for x in (-4.2, 4.2) for z in (2.2, -2.4)], 0.18, WHITE)
    k.at((0, t + 3.87, -7.5), (CAP_SLOPE, 0, 0), cap)
    # livery: one white band the length of the hull, a white and yellow rescue flash, a bow chevron, number tiles
    k.box((11.24, 0.5, 11.7), (0, t + 0.9, -5.05), WHITE, r=0.05)
    k.box((5.2, 1.3, 0.2), (0, t + 2.1, -11.0), WHITE, r=0.06)
    for sx, _ in SIDES:
        k.cyl(0.6, 0.3, (sx * 4.3, t + 3.1, -11.0), YELLOW, (90, 0, 0), n=12)
        k.box((0.16, 2.6, 1.3), (sx * 5.53, t + 2.3, -5.6), WHITE, (-32, 0, 0), r=0.04)
        k.box((0.16, 2.6, 0.55), (sx * 5.53, t + 2.3, -7.05), YELLOW, (-32, 0, 0), r=0.04)
    k.at((0, t + 2.13, 6.5), (4.8, 0, 0), lambda: k.plate([(-2.7, -2.1), (0, 0.4), (2.7, -2.1), (2.7, -0.7), (0, 1.8), (-2.7, -0.7)], -0.1, 0.05, WHITE, bevel=0))
    # the cockpit, open from behind
    k.box((8.4, 0.3, 6.8), (0, t + 2.42, -0.65), DARK, r=0.04)
    for sx, _ in SIDES:
        poly = [(sx * 5.6, -4.1), (sx * 5.6, 1.0), (sx * 4.75, 2.9), (sx * 3.7, 2.9), (sx * 4.3, 1.0), (sx * 4.3, -4.1)]
        k.plate(poly, t + 2.35, t + 3.55, ORANGE)
        k.bigstuds([(sx * 4.95, -1.6)], t + 3.55, ORANGE)
        k.box((0.5, 2.3, 0.5), (sx * 4.2, t + 3.7, 2.5), WHITE, (-25, 0, 0))
    k.box((9.0, 0.5, 1.1), (0, t + 2.6, 3.0), WHITE, r=0.14)
    k.box((8.1, 2.1, 0.26), (0, t + 3.7, 2.5), SCREEN, (-25, 0, 0), r=0.05)
    k.box((8.8, 0.4, 0.56), (0, t + 4.72, 2.02), WHITE, (-25, 0, 0), r=0.1)
    k.box((5.0, 1.2, 1.05), (0, t + 2.95, 2.05), DARK, r=0.1)
    k.at((SEAT_X, t + 4.1, 0.6), (32.6, 0, 0), lambda: k.torus(0.72, 0.2, (0, 0, 0), DARK, n=12, m_=5))
    k.rod((SEAT_X, t + 3.5, 1.6), (SEAT_X, t + 4.1, 0.6), 0.2, GREY)
    k.box((2.8, SEAT_TOP - t - 2.45, 2.0), (SEAT_X, (SEAT_TOP + t + 2.45) / 2, -2.1), DARK)
    k.box((2.8, 1.0, 0.6), (SEAT_X, SEAT_TOP + 0.3, -3.3), DARK)
    # slim raked struts, calm grey; a rudder blade aft
    for sx, _ in SIDES:
        strut(k, sx * MAIN_X, MAIN_Z, T + 0.3, FOIL_Y - 0.5, STRUT[0], STRUT[1], GREY)
    strut(k, 0, RUDDER_Z, T + 0.3, TIP_Y, STRUT[0] * 0.8, STRUT[1] * 0.85, GREY)
    add_atts(k)


def add_atts(k):
    """Same names as M_Veh_RIB. Seats and slots in concept numbers; floats, drive and props in the RIB's own asset-frame spots."""
    t = T
    k.att("DriverSeat", (SEAT_X, SEAT_TOP - 0.15, -2.1))
    k.att("EyePoint", (SEAT_X, SEAT_TOP + 2.0, -2.1))
    for i, (x, z) in enumerate(((-3.0, -6.2), (3.0, -6.2)), 1):
        k.att("PassengerSeat%d" % i, (x, deck_y(z), z))
    for i, (x, y, z) in enumerate(((-1.5, t + 2.15, 5.5), (1.5, t + 2.15, 5.5), (-3.0, deck_y(-9.0), -9.0), (3.0, deck_y(-9.0), -9.0)), 1):
        k.att("SurvivorSlot%d" % i, (x, y, z))
    k.att("TowHitch", (0, t + 1.0, -11.2))
    k.att("BowPoint", (0, t + 0.9, 14.0))
    k.att("NavPort", (4.95, t + 3.6, 1.0))
    k.att("NavStarboard", (-4.95, t + 3.6, 1.0))
    k.att("NavMasthead", (3.6, deck_y(-10.0), -10.0))
    k.att("NavStern", (0, t + 3.1, -11.15))
    k.att("Beacon", (-3.6, deck_y(-10.0), -10.0))
    k.att("Searchlight", (0, t + 4.8, 2.0))
    k.att("NumberStern", (0, t + 2.1, -11.12))
    k.att("Waterline", (0, 0.3, 0))
    k.att("DriveAttachment", (0, -0.5, -1.0))
    for i, (x, z) in enumerate(((2.2, 8.9), (-2.2, 8.9), (3.4, 2.9), (-3.4, 2.9), (3.6, -3.1), (-3.6, -3.1), (3.6, -9.1), (-3.6, -9.1)), 1):
        k.att("Float%d" % i, (x, 0.45 - hk.UP, z))
    for i, sx in enumerate((1, -1), 1):
        k.att("Prop%d" % i, (sx * MAIN_X, 0.3, strut_z(MAIN_Z, 0.3)))
    k.att("SplashRudder", (0, 0.3, strut_z(RUDDER_Z, 0.3)))
    for sx, side in SIDES:
        k.att("SplashMain" + side, (sx * MAIN_X, 0.3, strut_z(MAIN_Z, 0.3)))


def foils(k):
    """The one wide T-foil, a thin swept yellow blade. Sky Stilts moves this MeshPart as one (RESULT.md)."""
    f, z = FOIL, strut_z(MAIN_Z, FOIL_Y)

    def sec(x, zc, half, h):
        b = min(h * 0.8, half * 0.3)
        return [(x, FOIL_Y - h, zc - half + b), (x, FOIL_Y - h, zc + half - b), (x, FOIL_Y - h + b, zc + half), (x, FOIL_Y + h - b, zc + half),
                (x, FOIL_Y + h, zc + half - b), (x, FOIL_Y + h, zc - half + b), (x, FOIL_Y + h - b, zc - half), (x, FOIL_Y - h + b, zc - half)]
    k.rings([sec(-f["span"], z - f["sweep"], f["tip"], 0.14), sec(0, z, f["chord"], 0.26), sec(f["span"], z - f["sweep"], f["tip"], 0.14)], YELLOW)
    for sx, side in SIDES:
        k.att("SplashTip" + side, (sx * f["span"], 0.3, z - f["sweep"]))


def turbine(k, x, y, z, r, ln, fan=8, n=28):
    """A fat open drum: a wide round intake with a fan you can see, a flat open exhaust with a cyan glow in it. Blunt both ends. Returns the exhaust's z."""
    deep, re, ri = max(0.5, r * 0.28), r * 0.76, r * 0.82
    pts = [(0, -ln + deep), (re, -ln + deep), (re, -ln), (r * 0.95, -ln), (r, -ln + 0.3), (r, -0.3), (ri + 0.2, 0.0), (ri, 0.0), (ri, -deep), (0, -deep)]
    k.at((x, y, z), (90, 0, 0), lambda: k.lathe(pts, n, [DARK, DARK, ORANGE, ORANGE, WHITE, ORANGE, ORANGE, DARK, DARK]))
    k.torus(ri + 0.28, max(0.2, r * 0.13), (x, y, z), ORANGE, n=n, m_=6)
    k.sphere(r * 0.24, (x, y, z - deep), WHITE, n=12, lat=3)
    for i in range(fan):
        k.at((x, y, z - deep + 0.1), (0, 0, i * 360 / fan), lambda: k.box((ri * 0.76, max(0.28, r * 0.13), 0.14), (ri * 0.5, 0, 0), GREY, r=0.02))
    k.cyl(re * 0.8, 0.12, (x, y, z - ln + deep - 0.08), GLOW, (90, 0, 0), n=n)
    return z - ln


def giant_jets(k):
    """The joke: two turbines far too big for the boat, as tall as the hull and half again."""
    j = JET
    for sx, side in SIDES:
        x = sx * j["x"]
        aft = turbine(k, x, j["y"], j["z"], j["r"], j["ln"])
        k.box((3.0, 2.4, 4.2), (sx * 5.75, j["y"], j["z"] - j["ln"] / 2), ORANGE, r=0.2)
        k.att("Glow_" + side, (x, j["y"], aft + 0.5))


def t_tail(k):
    """One fat swept fin on the stern, no cross plate (art director round 2): low enough that the driver's head shows over it from the chase cam."""
    fin = [(-11.0, FIN_BASE), (-5.6, FIN_BASE), (-9.0, FIN_TOP), (-12.2, FIN_TOP)]
    k.prism(fin, -0.6, 0.6, ORANGE, lambda a, c, d: (d, c, a), bevel=0.16)
    k.box((1.4, 0.5, 3.4), (0, FIN_TOP, -10.6), WHITE, r=0.14)


def sky_stilts(k):
    """White sleeves on the same rake, down to where the foil set now sits (RESULT.md: move it, raise the boat)."""
    for sx, _ in SIDES:
        strut(k, sx * MAIN_X, MAIN_Z, FOIL_Y + 0.9, FOIL_Y - LIFT - 0.5, STRUT[0] + 0.3, STRUT[1] + 0.3, WHITE)
    strut(k, 0, RUDDER_Z, TIP_Y + 0.9, TIP_Y - LIFT, STRUT[0] * 0.8 + 0.3, STRUT[1] * 0.85 + 0.3, WHITE)


def needle_nose(k):
    """No needle left: the bow runs on into a wide flat snout with a broad rubber bumper. Nothing pointed, nothing white."""
    t = T
    k.loft_z([(9.0, plan(9.0) + 0.08, t + 0.08, t + 1.98), (13.0, 2.3, t - 0.05, t + 1.75), (15.4, 2.5, t + 0.1, t + 1.55)], ORANGE, b=0.3)
    k.sphere(1.0, (0, t + 0.82, 15.5), DARK, (2.75, 0.85, 1.05), n=20, lat=6)
    k.att("Nose", (0, t + 0.82, 16.5))


def sky_wings(k):
    """Small orange strakes along the hull, under the turbines' line: they add to the wedge and leave the silhouette alone."""
    t = T
    for sx, side in SIDES:
        k.plate([(sx * 3.2, 5.6), (sx * 7.2, 0.4), (sx * 8.4, -1.6), (sx * 5.2, -1.6)], t + 0.75, t + 1.25, ORANGE, bevel=0.1)
        k.box((1.2, 0.8, 2.2), (sx * 8.2, t + 1.0, -0.8), WHITE, r=0.15)


def afterburners(k):
    """No flame shape at all: a hot ring and a hot heart inside each exhaust. Flames are the game's VFX at ATT_Flame_*."""
    j = JET
    aft = j["z"] - j["ln"]
    re = j["r"] * 0.76
    for sx, side in SIDES:
        x = sx * j["x"]
        k.torus(re - 0.1, 0.42, (x, j["y"], aft + 0.05), FLAME2, n=26, m_=6)
        k.cyl(re * 0.55, 0.14, (x, j["y"], aft + j["r"] * 0.28 - 0.12), FLAME, (90, 0, 0), n=20)
        k.att("Flame_" + side, (x, j["y"], aft - 0.1))


def radar_dish(k):
    """A small dish on the cockpit wall."""
    t, x, z = T, 4.95, -2.6
    k.cyl(0.5, 0.3, (x, t + 3.65, z), DARK, n=10)
    k.cyl(0.32, 1.2, (x, t + 4.2, z), GREY, n=10)
    y = t + 4.95

    def dish():
        k.lathe([(0, -0.45), (0.7, -0.38), (1.3, -0.1), (1.45, 0.2), (1.3, 0.28), (0.7, 0.0), (0, -0.14)], 16, WHITE)
        k.sphere(0.24, (0, 0.5, 0), YELLOW, n=8, lat=3)
    k.at((x, y, z), (35, 0, 0), dish)
    k.att("Spin", (x, y, z))


def top_jet(k):
    """A small third turbine on the fin's tip, a tri-jet's tail: the same open drum, well under the giant pair. The sight line passes under it."""
    j = TOPJET
    aft = turbine(k, 0, j["y"], j["z"], j["r"], j["ln"], fan=6, n=18)
    k.box((0.9, 1.1, 2.2), (0, FIN_TOP + 0.65, j["z"] - j["ln"] / 2), ORANGE, r=0.1)
    k.att("Flame_Top", (0, j["y"], aft - 0.1))
    k.att("Glow_Top", (0, j["y"], aft + 0.3))


def turbo_halo(k):
    """A small clean yellow ring round the one fin, no mounts. Spin the whole piece round ATT_HaloAxis."""
    c = (0, T + 5.0, -9.3)
    k.at(c, (78, 0, 0), lambda: k.torus(2.9, 0.34, (0, 0, 0), YELLOW, n=28, m_=8))
    k.att("HaloAxis", c)


HULL = "M_Veh_Hydrofoil"
PIECES = {  # short name -> (level, fn)
    "GiantJets": (32, giant_jets), "TTail": (33, t_tail), "SkyStilts": (34, sky_stilts), "NeedleNose": (35, needle_nose), "SkyWings": (36, sky_wings),
    "Afterburners": (37, afterburners), "RadarDish": (38, radar_dish), "TopJet": (39, top_jet), "TurboHalo": (40, turbo_halo),
}


def asset(short):
    return "M_Upg_Hydrofoil_" + short


def _obj(fn, name):
    import bpy
    k = hk.Kit()
    fn(k)
    obj = k.to_object(name, hk.material())
    atts = []
    for att, (x, y, z) in k.atts.items():
        e = bpy.data.objects.new(att, None)
        e.location = (-x, z, y)
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)
    return obj, atts


WAIVERS = {
    "_COL proxy": "look only: CanCollide off, the hull's code box is the collision",
    "LOD UV layout": "flat palette cells, not a unique unwrap (like the other toy-brick assets)",
    "texture sets": "one flat palette set shared by the hull and all nine pieces",
    "LOD0 floor": "toy-brick piece, fewer bigger shapes by design",
    "UV faces": "decimated LOD faces collapse their small UV ring inside a palette cell: the colour stays the cell's",
}


def _spec(name, meshes, atts, budget):
    import names
    if "Upg" not in names.CATEGORIES:   # shortcut: run-time only, tools/ is not ours; add Upg to names.py when upgrade pieces settle
        names.CATEGORIES = (*names.CATEGORIES, "Upg")
    pts = [Vector(c) for o in meshes for c in o.bound_box]
    lo, hi = [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]
    return {
        "name": name, "budget": budget, "tier": "standard",
        "dims_m": tuple(round((h - l) / 3, 3) for h, l in zip(hi, lo)), "origin": "free", "tiling": True,
        "size_note": "toy-brick boat from its concept, not a real vessel's size",
        "sets": [{"name": hk.SET_NAME, "set": hk.SET, "size": 256, "wet": False, "dir": hk.TEX_DIR}],
        "meshes": [{"object": o, "set": hk.SET} for o in meshes], "attachments": atts, "waivers": WAIVERS,
    }


def hull_objects():
    a, atts = _obj(body, HULL + "_LOD0")
    b, more = _obj(foils, HULL + "_Foils_LOD0")
    return a, b, atts + more


def hull_spec():
    a, b, atts = hull_objects()
    return _spec(HULL, [a, b], atts, "rib")


def make(short, name=None):
    return _obj(PIECES[short][1], name or asset(short) + "_LOD0")


def spec(short):
    obj, atts = make(short)
    return _spec(asset(short), [obj], atts, "large_prop")
