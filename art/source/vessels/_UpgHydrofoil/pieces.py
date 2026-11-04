"""Hydrofoil stage (L31-L40): the hull and nine pieces, from the owner-cleared concept (artifact f23406cb), in its numbers (hk.py).

Past the concept on purpose (art director round 1, 5.5): twice the stance on straight struts, thin swept foils, a splayed V tail,
one smooth ring, a fat bumper nose, cone flames; no flag, spray, vents or red. Yellow and white accents on the orange, cyan only in the
nozzles and screen. See RESULT.md.
"""
import math

from mathutils import Vector

import hk
from hk import DARK, FLAME, FLAME2, GLOW, GREY, ORANGE, SCREEN, WHITE, YELLOW

R = math.pi / 180
T, N = 12.0, 17.8                # hull bottom and stern top at L31: twice the concept's stance (art director round 1: it walked, now it flies)
ANHED = 3.0
FOIL_Y, STRUT_END = 1.7, -0.2    # the foils fly just over the sea, only the strut tips cut it (sea at y 0.3)
LIFT = 4.0                       # Sky Stilts: the foil set drops straight down this far in the hull frame and the boat rises as much
# Keel-fin struts, one forward and two aft: a hydrofoil's stance, not four legs. Each is (x, top z0, top z1, end z0, end z1); the leading edge rakes back.
FRONT = dict(tag="Front", struts=[(0.0, 2.4, 7.4, 2.1, 4.5)], span=9.0, chord=2.3, sweep=3.6, tipc=0.9)
REAR = dict(tag="Rear", struts=[(3.2, -9.6, -4.6, -9.6, -6.8), (-3.2, -9.6, -4.6, -9.6, -6.8)], span=12.5, chord=2.7, sweep=4.4, tipc=1.0)
LEGS = [FRONT, REAR]
JET = dict(x=7.4, y=T + 1.6, z=-8.4, r=3.0, ln=5.2)
FIN_X, FIN_Y, SPLAY = 2.2, N - 1.0, 26.0    # the fins' feet and how far they lean out: an open V, no crossbar
FIN_H, FIN_T = 11.0, 1.5
RING_R, RING_T, RING_TILT = 5.4, 0.85, -12.0


def fin_point(sx, xl, yl):
    """A point in a fin's own frame (xl across it, yl up it) in hull numbers."""
    c, s = math.cos(SPLAY * R), math.sin(SPLAY * R)
    return sx * (FIN_X + xl * c + yl * s), FIN_Y - xl * s + yl * c


RING_YL = (RING_R + 0.1 - fin_point(1, -FIN_T / 2, 0)[0]) / math.sin(SPLAY * R)     # where the fin's inner face meets the ring
RING_Y = fin_point(1, -FIN_T / 2, RING_YL)[1]
TOPJET = dict(y=N + 4.8, z=-7.6, r=2.2, ln=4.6)
PLAN = [(-11, 4.0), (1, 4.0), (7, 2.2), (12.8, 0.6), (14, 0.12)]
SEAT_TOP = T + 4.5
CAP_SLOPE = 9.7                  # degrees: the stern deck falls towards the cockpit
SIDES = ((1, "P"), (-1, "S"))        # concept +x is asset -x, port


def deck_y(z):
    return T + 4.96 + 0.25 - (z + 7.5) * math.tan(CAP_SLOPE * R)


def plan(z):
    for (a, wa), (b, wb) in zip(PLAN, PLAN[1:]):
        if a <= z <= b:
            return wa + (wb - wa) * (z - a) / (b - a)
    return PLAN[-1][1]


def blade(k, x, y0, y1, w0, z00, z01, w1, z10, z11, cell):
    """One straight tapered keel-fin strut from y0 down to y1, no knuckles."""
    def ring(y, w, z0, z1):
        b = 0.3
        return [(x - w / 2, y, z0 + b), (x - w / 2, y, z1 - b), (x - w / 2 + b, y, z1), (x + w / 2 - b, y, z1),
                (x + w / 2, y, z1 - b), (x + w / 2, y, z0 + b), (x + w / 2 - b, y, z0), (x - w / 2 + b, y, z0)]
    k.rings([ring(y0, w0, z00, z01), ring(y1, w1, z10, z11)], cell)


def body(k):
    t = T
    # the sculpted wedge: keel, two long courses, sloping bow. Each course sinks 0.05 into the one below and sits 0.05 in from it
    keel = {-11: 0, 1: 0, 7: 0, 12.8: 0.45, 14: 0.7}
    k.loft_z([(z, plan(z), t + keel[z], t + keel[z] + 0.45) for z in keel], WHITE)
    c1 = {-11: 1.64, 1: 1.64, 7: 1.64, 12.8: 1.5, 14: 1.35}
    k.loft_z([(z, plan(z) - 0.05, t + keel[z] + 0.4, t + c1[z]) for z in keel], ORANGE)
    c2 = [(-11, 2.88), (1, 2.88), (3.4, 2.88), (7, 2.5), (12.8, 1.72), (14, 1.42)]
    k.loft_z([(z, plan(z) - 0.1, t + c1.get(z, 1.64) - 0.05, t + y) for z, y in c2], ORANGE)
    # the wedge climbs on to the tall flat stern: a low front edge keeps the driver in view of the chase cam
    k.loft_z([(-11, 3.9, t + 2.83, t + 4.12), (-4, 3.9, t + 2.83, t + 4.12)], ORANGE)
    k.loft_z([(-10.95, 3.85, t + 4.07, t + 5.44), (-4.05, 3.85, t + 4.07, t + 4.25)], ORANGE)

    def cap():
        k.box((8.08, 0.45, 7.2), (0, 0, 0), WHITE, r=0.14)
        k.bigstuds([(x, z) for x in (-2.6, 0, 2.6) for z in (2.1, -0.3, -2.7)], 0.225, WHITE)
    k.at((0, t + 4.96, -7.5), (CAP_SLOPE, 0, 0), cap)
    k.box((8.14, 0.5, 11.7), (0, t + 1.04, -5.05), WHITE, r=0.05)                   # side stripe
    k.box((4.4, 1.5, 0.2), (0, t + 3.5, -11.0), WHITE, r=0.06)                      # stern number tile
    for sx, _ in SIDES:
        k.cyl(0.62, 0.3, (sx * 2.9, t + 4.8, -11.0), YELLOW, (90, 0, 0), n=12)      # tail lamps
        k.box((0.2, 1.1, 2.4), (sx * 3.05, t + 2.28, 4.42), WHITE, (0, -sx * 16.7, 0), r=0.05)   # bow number tile
    # the cockpit, open from behind
    k.box((6.1, 0.3, 6.8), (0, t + 3.0, -0.65), DARK, r=0.04)
    for sx, _ in SIDES:
        poly = [(sx * 4.0, -4.1), (sx * 4.0, 1.0), (sx * 3.38, 2.9), (sx * 2.5, 2.9), (sx * 3.0, 1.0), (sx * 3.0, -4.1)]
        k.plate(poly, t + 2.83, t + 4.12, ORANGE)
        k.bigstuds([(sx * 3.5, -2.9), (sx * 3.5, -0.5)], t + 4.12, ORANGE)
        k.at((sx * 4.28, t + 3.5, -1.7), (0, 90, 0), lambda: k.torus(0.95, 0.36, (0, 0, 0), WHITE, n=14, m_=6))
        k.box((0.5, 2.6, 0.5), (sx * 3.15, t + 4.35, 2.5), WHITE, (-25, 0, 0))      # screen posts
    k.box((7.0, 0.55, 1.1), (0, t + 3.2, 3.0), WHITE, r=0.14)                       # sill
    k.box((6.0, 2.4, 0.26), (0, t + 4.35, 2.5), SCREEN, (-25, 0, 0), r=0.05)
    k.box((6.76, 0.42, 0.56), (0, t + 5.48, 1.98), WHITE, (-25, 0, 0), r=0.1)
    k.box((5.0, 1.45, 1.05), (0, t + 3.4, 2.05), DARK, r=0.1)                       # dash
    k.rod((0, t + 4.05, 1.65), (0, t + 4.95, 0.1), 0.2, GREY)
    k.at((0, t + 4.95, 0.1), (32.6, 0, 0), lambda: k.torus(0.72, 0.2, (0, 0, 0), DARK, n=12, m_=5))
    k.cyl(0.32, 0.3, (0, t + 4.95, 0.1), YELLOW, (122.6, 0, 0), n=10)
    k.box((2.5, SEAT_TOP - t - 3.05, 2.0), (0, (SEAT_TOP + t + 3.05) / 2, -2.1), DARK)   # the driver sits high: he reads over the walls
    k.box((2.5, 1.3, 0.6), (0, SEAT_TOP + 0.45, -3.3), DARK)
    # bow deck studs
    k.bigstuds([(-1.2, 4.2), (1.2, 4.2)], t + 2.75, ORANGE)
    # straight struts, grouped with the foils by colour
    for leg in LEGS:
        for x, a0, a1, b0, b1 in leg["struts"]:
            blade(k, x, T + 0.5, STRUT_END, 2.0, a0, a1, 1.3, b0, b1, YELLOW)
    add_atts(k)


def add_atts(k):
    """Same names as M_Veh_RIB. Seats and slots in concept numbers; floats, drive and props in the RIB's own asset-frame spots."""
    t = T
    k.att("DriverSeat", (0, SEAT_TOP - 0.15, -2.1))
    k.att("EyePoint", (0, SEAT_TOP + 2.0, -2.1))
    for i, (x, z) in enumerate(((-2.8, -5.8), (2.8, -5.8)), 1):
        k.att("PassengerSeat%d" % i, (x, deck_y(z), z))
    for i, (x, y, z) in enumerate(((-1.3, t + 2.85, 5.0), (1.3, t + 2.85, 5.0), (-2.8, deck_y(-8.2), -8.2), (2.8, deck_y(-8.2), -8.2)), 1):
        k.att("SurvivorSlot%d" % i, (x, y, z))
    k.att("TowHitch", (0, t + 1.0, -11.2))
    k.att("BowPoint", (0, t + 1.1, 14.0))
    k.att("NavPort", (3.5, t + 4.2, 1.0))          # concept +x is asset -x (port)
    k.att("NavStarboard", (-3.5, t + 4.2, 1.0))
    k.att("NavMasthead", (3.0, deck_y(-10.4), -10.4))
    k.att("NavStern", (0, t + 4.8, -11.15))
    k.att("Beacon", (-3.0, deck_y(-10.4), -10.4))
    k.att("Searchlight", (0, t + 5.3, 2.2))
    k.att("NumberStern", (0, t + 3.5, -11.12))
    k.att("NumberP", (3.15, t + 2.28, 4.42))
    k.att("NumberS", (-3.15, t + 2.28, 4.42))
    k.att("Waterline", (0, 0.3, 0))
    k.att("DriveAttachment", (0, -0.5, -1.0))
    for i, (x, z) in enumerate(((2.2, 8.9), (-2.2, 8.9), (3.4, 2.9), (-3.4, 2.9), (3.6, -3.1), (-3.6, -3.1), (3.6, -9.1), (-3.6, -9.1)), 1):
        k.att("Float%d" % i, (x, 0.45 - hk.UP, z))
    for i, sx in enumerate((1, -1), 1):
        k.att("Prop%d" % i, (sx * 3.0, 0.3, -11.0))
    for leg in LEGS:
        for x, _, _, b0, b1 in leg["struts"]:
            k.att("Splash%s%s" % (leg["tag"], "" if x == 0 else "P" if x > 0 else "S"), (x, 0.3, (b0 + b1) / 2))


def foils(k):
    """The foil set, one MeshPart: two thin, swept, nearly flat yellow foils. Sky Stilts moves it as one (RESULT.md)."""
    for leg in LEGS:
        _, _, _, b0, b1 = leg["struts"][0]
        z, q, c = (b0 + b1) / 2, leg["span"], leg["chord"]

        def sec(x, zc, half, h):
            y = FOIL_Y - abs(x) * math.tan(ANHED * R)
            b = min(h * 0.8, half * 0.3)
            return [(x, y - h, zc - half + b), (x, y - h, zc + half - b), (x, y - h + b, zc + half), (x, y + h - b, zc + half),
                    (x, y + h, zc + half - b), (x, y + h, zc - half + b), (x, y + h - b, zc - half), (x, y - h + b, zc - half)]
        k.rings([sec(-q, z - leg["sweep"], leg["tipc"], 0.16), sec(0, z, c, 0.3), sec(q, z - leg["sweep"], leg["tipc"], 0.16)], YELLOW)


def turbofan(k, x, y, z, r, ln, n=20):
    """Lip ring, fan, band, stripe, round glow nozzle. Fat and open-mouthed: an engine, never a missile. Returns the nozzle's aft z."""
    k.cyl(r, ln, (x, y, z - ln / 2), WHITE, (90, 0, 0), n=n)
    k.torus(r - 0.25, 0.5, (x, y, z + 0.1), GREY, n=n, m_=6)
    k.cyl(r - 0.35, 0.24, (x, y, z - 0.02), DARK, (90, 0, 0), n=n)
    k.sphere(r * 0.34, (x, y, z + 0.1), WHITE, (1, 1, 1.1), n=10, lat=3)
    k.cyl(r + 0.1, ln * 0.2, (x, y, z - ln * 0.36), ORANGE, (90, 0, 0), n=n)
    k.cyl(r + 0.1, ln * 0.1, (x, y, z - ln * 0.68), YELLOW, (90, 0, 0), n=n)
    nl = r * 0.55
    k.cyl(r * 0.72, nl, (x, y, z - ln - nl / 2 + 0.05), DARK, (90, 0, 0), r2=r * 0.96, n=n)
    aft = z - ln - nl
    k.cyl(r * 0.6, 0.2, (x, y, aft - 0.02), GLOW, (90, 0, 0), n=n)
    k.torus(r * 0.62, 0.17, (x, y, aft - 0.02), GLOW, n=n, m_=4)
    return aft


def flame(k, x, y, z, r, ln):
    """One simple cone flying aft: yellow at the nozzle, orange to the tip."""
    k.at((x, y, z), (-90, 0, 0), lambda: k.lathe([(0, 0), (r, 0), (r * 0.92, ln * 0.22), (r * 0.62, ln * 0.5), (r * 0.3, ln * 0.78), (0, ln)], 18, [FLAME2, FLAME2, FLAME, FLAME, FLAME]))


def giant_jets(k):
    j = JET
    for sx, side in SIDES:
        x = sx * j["x"]
        turbofan(k, x, j["y"], j["z"], j["r"], j["ln"], n=24)
        k.box((3.0, 2.6, 4.0), (sx * 4.95, j["y"], -10.2), ORANGE, r=0.2)        # a fat pylon out of the stern, not a bracket
        k.att("Glow_" + side, (x, j["y"], j["z"] - j["ln"] - j["r"] * 0.55 - 0.1))


def t_tail(k):
    """Two fat swept fins splayed out in a V with yellow caps, no crossbar: the driver shows between them, the Top Jet and halo sit in the V."""
    for sx, _ in SIDES:
        fin = [(-10.2, 0), (-5.4, 0), (-9.9, FIN_H), (-13.6, FIN_H)]

        def blade_(fin=fin):
            k.prism(fin, -FIN_T / 2, FIN_T / 2, ORANGE, lambda a, c, d: (d, c, a), bevel=0.16)
            k.box((FIN_T + 0.2, 1.3, 4.0), (0, FIN_H, -11.75), YELLOW, r=0.2)
        k.at((sx * FIN_X, FIN_Y, 0), (0, 0, -sx * SPLAY), blade_)
        k.at((sx * FIN_X, 0, 0), None, lambda: k.loft_z([(-10.8, 1.3, N - 1.9, N + 0.75), (-5.2, 1.3, N - 1.9, N - 0.25)], ORANGE, b=0.2))   # a fat root out of the deck


def sky_stilts(k):
    """White sleeves telescope straight down out of the struts' ends to where the foil set now sits (RESULT.md: move it, raise the boat)."""
    for leg in LEGS:
        for x, _, _, b0, b1 in leg["struts"]:
            blade(k, x, STRUT_END + 1.2, STRUT_END - LIFT, 1.75, b0 - 0.25, b1 + 0.25, 1.5, b0 - 0.05, b1 + 0.05, WHITE)


def needle_nose(k):
    """The wedge runs on as a fat orange snout and ends in one big rounded white bumper: a toy ram, not a dart."""
    t = T
    k.loft_z([(8.6, plan(8.6) + 0.08, t + 0.05, t + 2.42), (12.2, 1.9, t - 0.35, t + 2.7), (15.0, 1.92, t - 0.6, t + 2.9)], ORANGE, b=0.4)
    y = t + 1.15
    k.cyl(1.9, 1.6, (0, y, 15.5), ORANGE, (90, 0, 0), n=20)
    k.sphere(1.98, (0, y, 16.3), WHITE, (1, 1, 0.82), n=20, lat=7)
    k.att("Nose", (0, y, 17.9))


def sky_wings(k):
    """Big raised yellow wings: the tips stand clear above the giant jets, so they read from the chase cam."""
    t, up = T, math.tan(25 * R)
    y_at = lambda x: t + 1.6 + (x - 3.4) * up
    for sx, side in SIDES:
        def sec(x, z0, z1, h):
            y, b = y_at(x), h * 0.5
            return [(sx * x, y - h, z0 + b), (sx * x, y - h, z1 - b), (sx * x, y - h + b, z1), (sx * x, y + h - b, z1),
                    (sx * x, y + h, z1 - b), (sx * x, y + h, z0 + b), (sx * x, y + h - b, z0), (sx * x, y - h + b, z0)]
        k.rings([sec(3.2, -2.2, 6.2, 0.62), sec(12.0, -3.8, 0.4, 0.4)], YELLOW)
        for x, z in ((5.6, 2.9), (5.6, 0.1), (8.2, 1.2), (8.2, -1.2)):
            k.at((sx * x, y_at(x), z), (0, 0, sx * 25), lambda: k.bigstuds([(0, 0)], 0.5, YELLOW))
        k.at((sx * 12.0, y_at(12.0), -1.7), (0, 0, sx * 25), lambda: k.box((1.3, 1.6, 4.6), (0, 0, 0), ORANGE, r=0.25))


def afterburners(k):
    """A yellow burner can on each nozzle and one simple cone of flame."""
    j = JET
    aft = j["z"] - j["ln"] - j["r"] * 0.55
    for sx, side in SIDES:
        x = sx * j["x"]
        k.cyl(j["r"] * 0.8, 0.9, (x, j["y"], aft - 0.3), YELLOW, (90, 0, 0), n=20)
        flame(k, x, j["y"], aft - 0.7, j["r"] * 0.74, 4.8)
        k.att("Flame_" + side, (x, j["y"], aft - 0.8))


def radar_dish(k):
    """A big white dish high on a fat mast beside the cockpit, its lower edge above the driver's head."""
    t, x, z = T, 4.0, -1.6
    k.cyl(1.2, 0.7, (x, t + 4.45, z), DARK, n=14)
    k.cyl(0.72, 5.2, (x, t + 7.2, z), GREY, n=12)
    y = t + 9.6

    def dish():
        k.lathe([(0, -1.0), (1.5, -0.86), (3.0, -0.3), (4.2, 0.65), (3.9, 0.9), (2.4, 0.15), (1.1, -0.3), (0, -0.4)], 24, WHITE)
        k.cyl(0.85, 0.7, (0, -0.15, 0), YELLOW, n=12)
        k.cyl(0.3, 1.9, (0, 1.0, 0), GREY, n=8)
        k.sphere(0.72, (0, 2.1, 0), YELLOW, n=12, lat=4)
    k.at((x, y, z), (35, 0, 0), dish)
    k.att("Spin", (x, y, z))


def top_jet(k):
    """A fat engine in the V's throat, above the sight line to the driver, on two short stubs into the fins."""
    j = TOPJET
    aft = turbofan(k, 0, j["y"], j["z"], j["r"], j["ln"])
    inner = fin_point(1, -FIN_T / 2, (j["y"] - FIN_Y) / math.cos(SPLAY * R))[0]
    for sx, _ in SIDES:
        k.box((inner - j["r"] + 0.5, 1.8, 3.0), (sx * (inner + j["r"]) / 2, j["y"], j["z"] - 2.3), ORANGE, r=0.2)
    flame(k, 0, j["y"], aft - 0.05, j["r"] * 0.72, 2.6)
    k.att("Flame_Top", (0, j["y"], aft - 0.1))
    k.att("Glow_Top", (0, j["y"], aft - 0.1))


def turbo_halo(k):
    """One clean smooth gold ring cradled in the V's fins, tilted to the chase cam: the one joke. Spin the whole piece round ATT_HaloAxis."""
    c = (0, RING_Y, -11.05)
    k.at(c, (RING_TILT + 90, 0, 0), lambda: k.torus(RING_R, RING_T, (0, 0, 0), YELLOW, n=40, m_=10))
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
