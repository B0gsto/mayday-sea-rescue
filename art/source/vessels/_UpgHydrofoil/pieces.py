"""Hydrofoil stage (L31-L40): the hull and nine pieces, from the owner-cleared concept (artifact f23406cb), in its numbers (hk.py).

Past the concept on purpose, for the phone read from the chase cam: fatter legs, jets and needle; a twin-fin tail, so the sight line
to the driver stays open and the Top Jet sits in the tail with no code move; no flag, spray, vents or red; yellow and white accents
on the orange, cyan only in the nozzles and screen. See RESULT.md.
"""
import math

from mathutils import Vector

import hk
from hk import DARK, FLAME, FLAME2, GLOW, GREY, ORANGE, SCREEN, WHITE, YELLOW

R = math.pi / 180
T, N = 6.0, 11.8                 # hull bottom and stern top in the concept at L31
RAKE, ANHED = 28.0, 8.0
HINGE = T - 0.3
FOIL_Y, POD_Y = 2.5, 0.65
LIFT = 2.5                       # Sky Stilts: the foil set drops this far in the hull frame and the boat rises as much
LIFT_Z = LIFT * math.tan(RAKE * R)   # ...and slides aft along the rake (concept -z, asset +z)
LEGS = [dict(tag="Front", z=5.5, x=1.7, w=2.6, c=3.6, span=9.2, chord=2.6, tip=4.0), dict(tag="Rear", z=-5.5, x=3.0, w=3.0, c=4.0, span=11.2, chord=3.0, tip=4.6)]
LEG_LEN = (HINGE - POD_Y) / math.cos(RAKE * R)
STILT_END = (HINGE + LIFT - POD_Y) / math.cos(RAKE * R)
JET = dict(x=7.4, y=T + 1.6, z=-8.4, r=3.0, ln=5.2)
TOPJET = dict(y=N + 5.3, z=-4.4, r=1.7, ln=4.6)
FIN_X = 2.8                      # the twin fins' centres: the top jet and its flame run between them
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


def leg_at(leg, s):
    return (T - 0.3 - s * math.cos(RAKE * R), leg["z"] - s * math.sin(RAKE * R))


def stack(k, x, leg, s0, s1, w, c, cell, n=3):
    """A raked stack of fat bricks from s0 to s1 along the leg line: seams show, big stud on no open top."""
    step = (s1 - s0) / n
    y, z = leg_at(leg, (s0 + s1) / 2)
    k.box((w - 0.5, s1 - s0 - 0.4, c - 0.5), (x, y, z), DARK, (RAKE, 0, 0), r=0.05)
    for i in range(n):
        y, z = leg_at(leg, s0 + (i + 0.5) * step)
        k.box((w, step - 0.1, c), (x, y, z), cell, (RAKE, 0, 0), r=0.2)


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
    # thick raked legs
    for leg in LEGS:
        for sx, _ in SIDES:
            x = sx * leg["x"]
            k.cyl(1.0, leg["w"] + 0.6, (x, HINGE, leg["z"]), DARK, (0, 0, 90), n=14)
            stack(k, x, leg, 0.1, LEG_LEN, leg["w"], leg["c"], ORANGE)
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
        for sx, _ in SIDES:
            k.att("Splash%s%s_Pod" % (leg["tag"], "P" if sx > 0 else "S"), (sx * leg["x"], 0.3, foil_z(leg, POD_Y)))


def foil_z(leg, y):
    return leg["z"] - (HINGE - y) * math.tan(RAKE * R)


def foils(k):
    """The foil set, one MeshPart: pods, huge yellow T-foils, orange end plates. Sky Stilts moves it as one (RESULT.md)."""
    for leg in LEGS:
        z, q, c, x0 = foil_z(leg, FOIL_Y), leg["span"], leg["chord"], leg["x"]
        for sx, side in SIDES:
            pz = foil_z(leg, POD_Y)
            k.cyl(1.25, 3.4, (sx * x0, POD_Y, pz), DARK, (90, 0, 0), n=14)
            k.sphere(1.24, (sx * x0, POD_Y, pz + 1.7), WHITE, (1, 1.2, 1), n=14, lat=4)

            def wing(s=sx, q=q, c=c):
                sec = lambda x, z0, z1, h: [(s * x, -h, z0 + 0.4), (s * x, -h, z1 - 0.4), (s * x, -h + 0.35, z1), (s * x, h - 0.35, z1), (s * x, h, z1 - 0.4), (s * x, h, z0 + 0.4), (s * x, h - 0.35, z0), (s * x, -h + 0.35, z0)]
                k.rings([sec(-0.4, -c, c, 0.72), sec(q - 1.6, -c, c, 0.62), sec(q, -c, c * 0.35, 0.5)], YELLOW)
                k.bigstuds([(s * x, zs) for x in (x0 + 2.4, x0 + 4.8, x0 + 7.2) if x < q - 0.8 for zs in (-c * 0.45, c * 0.45)], 0.62, YELLOW)
                k.box((1.3, 2.5, leg["tip"]), (s * (q + 0.5), -0.3, 0), ORANGE, r=0.2)
                k.bigstuds([(s * (q + 0.5), 0)], 0.95, ORANGE)
            k.at((0, FOIL_Y, z), (0, 0, -sx * ANHED), wing)
            k.att("Splash%s%s_Tip" % (leg["tag"], "P" if sx > 0 else "S"), (sx * (q + 0.5) * math.cos(ANHED * R), 0.3, z))
        k.box((2.4, 1.6, 2 * c + 0.2), (0, FOIL_Y, z), YELLOW, r=0.2)


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
    """A fat round fireball plume: big blunt orange lobes of mixed length round a round yellow heart, no point anywhere."""
    for i in range(6):
        a = (30 + i * 60) * R
        k.tongue(x + r * 0.5 * math.cos(a), y + r * 0.5 * math.sin(a), z, r * 0.72, ln * (1.0 if i % 2 else 0.7), FLAME)
    k.tongue(x, y, z - 0.2, r * 0.8, ln * 1.12, FLAME2)


def giant_jets(k):
    j = JET
    for sx, side in SIDES:
        x = sx * j["x"]
        turbofan(k, x, j["y"], j["z"], j["r"], j["ln"], n=24)
        k.box((3.0, 2.6, 4.0), (sx * 4.95, j["y"], -10.2), ORANGE, r=0.2)        # a fat pylon out of the stern, not a bracket
        k.att("Glow_" + side, (x, j["y"], j["z"] - j["ln"] - j["r"] * 0.55 - 0.1))


def t_tail(k):
    """Two fat swept fins with a wide studded tailplane on top. The driver shows between them, the Top Jet later fills the gap."""
    base, top = N - 1.4, N + 7.9
    fin = [(-10.2, base), (-5.4, base), (-9.4, top), (-13.0, top)]
    for sx, _ in SIDES:
        k.prism(fin, sx * FIN_X - 0.75, sx * FIN_X + 0.75, ORANGE, lambda a, c, d: (d, c, a), bevel=0.14)
        k.at((sx * FIN_X, 0, 0), None, lambda: k.loft_z([(-10.8, 1.2, N - 1.9, N + 0.75), (-5.2, 1.2, N - 1.9, N - 0.25)], ORANGE, b=0.2))   # a fat root out of the deck
    k.plate([(-7, -14.4), (7, -14.4), (7, -12), (5.2, -8.8), (-5.2, -8.8), (-7, -12)], top - 0.05, top + 1.05, ORANGE, bevel=0.18)
    k.bigstuds([(x, z) for x in (-4.6, 4.6, -2.3, 2.3) for z in (-13.0, -10.6)], top + 1.05, ORANGE)
    for sx, _ in SIDES:
        k.box((1.5, 2.0, 3.6), (sx * 7.5, top + 0.5, -12.4), YELLOW, r=0.2)
        k.bigstuds([(sx * 7.5, -12.4)], top + 1.5, YELLOW)
    # the crown fin: the halo's fin at L40, the tail's cap until then
    crown = [(-13.2, top + 1.0), (-9.6, top + 1.0), (-12.0, top + 4.2), (-14.6, top + 4.2)]
    k.prism(crown, -0.8, 0.8, YELLOW, lambda a, c, d: (d, c, a), bevel=0.14)


def sky_stilts(k):
    """Yellow stilts carry on down the leg lines to where the foil set now sits (RESULT.md: move it, raise the boat)."""
    for leg in LEGS:
        for sx, _ in SIDES:
            x = sx * leg["x"]
            stack(k, x, leg, LEG_LEN - 0.3, STILT_END + 0.2, leg["w"] - 0.3, leg["c"] - 0.3, YELLOW, n=2)
            y, z = leg_at(leg, LEG_LEN - 0.2)
            k.box((leg["w"] + 0.6, 0.8, leg["c"] + 0.6), (x, y, z), DARK, (RAKE, 0, 0), r=0.2)


def needle_nose(k):
    """A fat stepped race nose out of a sheath over the prow; the tip is round."""
    t = T
    k.loft_z([(8.6, plan(8.6) + 0.08, t + 0.05, t + 2.42), (13.0, 1.36, t + 0.2, t + 1.98), (15.2, 1.32, t + 0.35, t + 1.85)], WHITE)
    y = t + 1.1
    for z0, ln, r, c in ((15.0, 3.2, 1.28, ORANGE), (18.1, 2.9, 1.08, WHITE), (20.9, 2.5, 0.88, ORANGE)):
        k.cyl(r, ln, (0, y, z0 + ln / 2), c, (90, 0, 0), r2=r * 0.97, n=16)
    k.cone(0.72, 2.6, (0, y, 24.6), YELLOW, (90, 0, 0), tip=0.42, n=14)
    k.att("Nose", (0, y, 25.9))


def sky_wings(k):
    t = T
    for sx, side in SIDES:
        poly = [(sx * 3.6, 0.0), (sx * 2.4, 6.0), (sx * 6.2, 5.6), (sx * 11.2, 3.3), (sx * 11.2, 1.4), (sx * 7.2, 0.0)]
        k.plate(poly, t + 0.5, t + 1.7, YELLOW, bevel=0.2)
        k.bigstuds([(sx * x, z) for x, z in ((5.6, 1.5), (8.0, 2.0), (5.6, 3.9))], t + 1.7, YELLOW)
        k.box((1.8, 2.4, 3.2), (sx * 11.8, t + 1.1, 2.35), ORANGE, r=0.2)
        k.bigstuds([(sx * 11.8, 2.35)], t + 2.3, ORANGE)


def afterburners(k):
    j = JET
    aft = j["z"] - j["ln"] - j["r"] * 0.55
    for sx, side in SIDES:
        x = sx * j["x"]
        k.cyl(j["r"] * 0.8, 0.8, (x, j["y"], aft - 0.3), YELLOW, (90, 0, 0), n=20)       # a burner can bolted on the nozzle
        flame(k, x, j["y"], aft - 0.6, j["r"] * 0.85, 6.5)
        k.att("Flame_" + side, (x, j["y"], aft - 0.7))


def radar_dish(k):
    t, x, z = T, 3.5, -1.6
    k.cyl(1.0, 0.6, (x, t + 4.4, z), DARK, n=14)
    k.cyl(0.6, 3.0, (x, t + 6.0, z), GREY, n=12)
    y = t + 7.5

    def dish():
        k.lathe([(0, -0.75), (1.1, -0.62), (2.2, -0.2), (2.9, 0.45), (2.7, 0.62), (1.7, 0.1), (0.8, -0.2), (0, -0.28)], 20, WHITE)
        k.cyl(0.6, 0.5, (0, -0.1, 0), YELLOW, n=12)
        k.cyl(0.22, 1.6, (0, 0.8, 0), GREY, n=8)
        k.sphere(0.55, (0, 1.75, 0), YELLOW, n=10, lat=3)
    k.at((x, y, z), (35, 0, 0), dish)
    k.att("Spin", (x, y, z))


def top_jet(k):
    j = TOPJET
    aft = turbofan(k, 0, j["y"], j["z"], j["r"], j["ln"])
    for sx, _ in SIDES:
        k.box((2.0, 1.6, 3.2), (sx * 1.65, j["y"], j["z"] - 2.9), ORANGE, r=0.2)     # stubs into the twin fins
    flame(k, 0, j["y"], aft - 0.05, j["r"] * 0.85, 3.8)
    k.att("Flame_Top", (0, j["y"], aft - 0.1))
    k.att("Glow_Top", (0, j["y"], aft - 0.1))


def turbo_halo(k):
    """Ten gold bricks round the crown fin, tilted, no mounts: the one joke. Set the whole piece spinning round ATT_HaloAxis."""
    top = N + 7.9
    c = (0, top + 3.1, -11.8)

    def ring():
        k.at((0, 0, 0), (90, 0, 0), lambda: k.torus(4.1, 0.6, (0, 0, 0), WHITE, n=24, m_=6))
        for i in range(10):
            k.at((0, 0, 0), (0, 36 * i, 0), lambda: (k.brick((1.9, 1.5, 2.42), (4.1, 0, 0), YELLOW, studs=None, r=0.2), k.bigstuds([(4.1, 0)], 0.75, YELLOW)))
    k.at(c, (-18, 0, 0), ring)
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
