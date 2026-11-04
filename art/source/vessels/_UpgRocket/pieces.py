"""The Rocket Cutter hull (L41), its pilot and nine upgrade pieces (L42-L50), from the owner-cleared concept (artifact b8ff43b0).

Concept numbers (see kit.py). Past the concept on purpose, from the art director's notes on the other stages: fewer and fatter shapes
(no rails, ladder, rivets, 40 confetti bits), an open throne so the pilot stays visible from behind, wave walls sculpted out of the hull
instead of towed bricks, and at L50 one joke: a beaming sun the size of the boat's beam blowing the flame out of its mouth.
"""
import math

import kit as K
from kit import (AQUA, CHROME, DEEP, FLAME_O, FLAME_W, FLAME_Y, GLASS, GOLD, NAVY, RED, RUBBER, SEAT, SKIN, TAN, VEST, WHITE)
from mathutils import Vector

RT, RR = 7.6, 3.5       # rocket axis height and radius
SIDES = ((1, "S"), (-1, "P"))
SEAT_X = (-17.8, -15.2, -12.6, -5.6, -3.0, -0.4)
SEAT_Z = 3.4


def plan(k, poly, y0, y1, cell, bevel=0.1):
    """A plan-view polygon (x, z) extruded up from y0 to y1."""
    k.prism(poly, y0, y1, cell, lambda a, b, d: (a, d, b), bevel)


def section(k, poly, x0, x1, cell, bevel=0.1):
    """A cross-section polygon (z, y) extruded along x."""
    k.prism(poly, x0, x1, cell, lambda a, b, d: (d, b, a), bevel)


def side(k, poly, z0, z1, cell, bevel=0.1):
    """A side-view polygon (x, y) extruded across z."""
    k.prism(poly, z0, z1, cell, lambda a, b, d: (a, b, d), bevel)


def seat(k, x, s):
    k.box((1.6, 0.4, 1.4), (x, 3.02, s * SEAT_Z), SEAT, r=0)
    k.box((0.5, 1.3, 1.4), (x - 0.58, 3.82, s * SEAT_Z), SEAT, r=0)


def hull(k):
    # ---- the knife: five raked courses, each tip further forward than the one below
    plan(k, [(6, -4.5), (21, 0), (6, 4.5)], -2.4, -1.2, NAVY, 0.14)
    plan(k, [(6, -5), (24, 0), (6, 5)], -1.2, 0, NAVY)
    plan(k, [(6, -5), (27.5, 0), (6, 5)], 0, 1.2, RED)
    plan(k, [(6, -5), (31, 0), (6, 5)], 1.2, 2.4, WHITE)
    plan(k, [(6, -5), (34.5, 0), (6, 5)], 2.4, 3.6, WHITE)
    for i, (x0, x1) in enumerate(((-20, -9), (-9, 6))):       # bilge, chamfered
        section(k, [(-3.6, -2.4), (3.6, -2.4), (5, -1.2), (-5, -1.2)], x0, x1, NAVY, 0.14)
    for y, cell, seams in ((-1.2, NAVY, (-20, -4, 6)), (0, RED, (-20, -12, 2, 6)), (1.2, WHITE, (-20, -6, 6))):
        for x0, x1 in zip(seams, seams[1:]):
            k.box((x1 - x0, 1.2, 10), ((x0 + x1) / 2, y + 0.6, 0), cell)
    # ---- deck well: fat studded gunwale walls round tan plates
    for s, _ in SIDES:
        for x0, x1 in ((-20, -8), (-8, 6)):
            k.brick((x1 - x0, 1.2, 1), ((x0 + x1) / 2, 3.0, s * 4.5), WHITE, studs="big")
        k.box((1, 1.2, 3.98), (-19.5, 3.0, s * 2), WHITE, studs="big")
        k.box((26, 0.28, 0.14), (-7, 2.62, s * 5.03), NAVY, r=0.05)                 # sheer stripe
        k.box((26, 0.55, 0.46), (-7, 3.3, s * 5.17), RUBBER)                        # rub rail
        d, g = math.hypot(25, 4.12), math.degrees(math.atan2(5, 28.5))
        k.box((d, 0.34, 0.14), (18.5, 3.0, s * 2.95), NAVY, (0, g * s, math.degrees(math.atan2(0.8, d))), r=0.05)   # rising along the bow
        for x in (-12.5, -6.5, -0.5):
            k.rim_window(x, 1.7, s, 0.62, 5.02)
        k.box((3.9, 2.5, 0.12), (-17.2, 1.2, s * 5.02), NAVY, r=0.04)                 # number plate
        k.box((3.4, 2.1, 0.12), (-17.2, 1.2, s * 5.09), WHITE, r=0.04)
        k.att("NumberPlate_" + _, (-17.2, 1.2, s * 5.16))
        k.torus(0.85, 0.32, (3.2, 1.3, s * 5.3), VEST, n=14, m_=6)                  # life ring
        for a in range(4):
            c = math.radians(45 + 90 * a)
            k.box((0.34, 0.74, 0.74), (3.2 + 0.85 * math.cos(c), 1.3 + 0.85 * math.sin(c), s * 5.3), WHITE, (0, 0, 45 + 90 * a), r=0)
        k.cyl(0.65, 0.14, (-20.05, 3.0, s * 3.3), RED, (0, 0, 90), n=12)                # tail light
        for x, s2 in ((-19, 8), (-11, 8), (-3, 9)):
            k.box((s2 - 0.04, 0.44, 3.98), (x + s2 / 2, 2.6, s * 2), TAN, r=0.08)
    # foredeck studs and the red prow spine
    top = k.stack[-1]
    spots = []
    for x in (8.2, 10.6, 13.0, 15.4):
        hw = 5 * (34.5 - x) / 28.5 - 0.9
        spots += [(x, 3.58, z) for z in (-hw, -hw + 2.4 * ((2 * hw) // 2.4 > 0), hw - 2.4 * ((2 * hw) // 2.4 > 0), hw)]
    for p in spots:
        k.stud(top, p, WHITE, big=True)
    plan(k, [(18, -2.4), (38, 0), (18, 2.4)], 3.6, 4.8, RED)
    for x, z in ((19.5, 1.1), (19.5, -1.1), (22.5, 0), (25.5, 0), (28.5, 0), (31.5, 0)):
        k.stud(top, (x, 4.78, z), RED, big=True)
    t = lambda y: 24 + (y + 0.6) / 0.343
    k.prism([(t(-2.4) - 1.2, -2.4), (t(-2.4) + 0.9, -2.4), (t(4.9) + 0.9, 4.9), (t(4.9) - 1.2, 4.9)], -0.28, 0.28, CHROME, lambda a, b, d: (a, b, d), 0.08)
    # ---- stern
    k.brick((1.4, 0.6, 7.2), (-20.7, 0.3, 0), NAVY, studs="big")
    # ---- cradle: two fat saddles cut to the rocket
    prof = [(3, 3.2)] + [(3 - i * 6 / 14, RT - math.sqrt(3.56 ** 2 - (3 - i * 6 / 14) ** 2)) for i in range(15)] + [(-3, 3.2)]
    for x in (-9, 5):
        k.box((4.4, 0.42, 7), (x, 3.0, 0), NAVY)
        section(k, prof, x - 1.6, x + 1.6, NAVY, 0)
        k.ring(x - 0.55, 1.1, RR - 0.1, RR + 0.26, RUBBER, RT, 0, n=20)
        k.box((1.3, 0.34, 1.3), (x, RT + RR + 0.32, 0), CHROME, r=0.08)
    # ---- the rocket, twice too big: three red bands, round nose, cartoon windows
    for x0, x1, c in ((-15, -13, RED), (-13, -11, NAVY), (-11, -3, WHITE), (-3, -1, RED), (-1, 7, WHITE), (7, 9, NAVY), (9, 11, RED), (11, 13, WHITE)):
        k.along(x0, x1, RR, c, RT, n=24)
    nose = [(0, 0), (RR - 0.04, 0)] + [(RR * (1 - (i / 8) ** 2) ** 0.62, 8 * i / 8) for i in range(9)]
    nose[-1] = (0, 8)
    k.lathe(nose, 24, RED, (13, RT, 0), (0, 0, -90))
    k.sphere(0.95, (20.6, RT, 0), SEAT, n=14, lat=5)        # a toy ball on the nose: never a warhead
    k.along(-16, -15, 2.8, NAVY, RT)
    bell = [(0, 0), (1.9, 0)] + [(1.9 + 1.2 * (i / 6) ** 1.5, 3.5 * i / 6) for i in range(1, 7)] + [(2.86, 3.5), (1.62, 0.5), (0, 0.5)]
    k.lathe(bell, 18, CHROME, (-16, RT, 0), (0, 0, 90))
    k.ring(-18.7, 0.6, 2.3, 2.95, NAVY, RT, 0)
    k.flame(-16.8, RT, 0, 1.55, 7.2)
    k.att("Flame_Main", (-19.6, RT, 0))
    for s, _ in SIDES:
        for x in (-7.0, 1.2):
            k.rim_window(x, RT, s, 1.05, RR - 0.04)
    # ---- saddle and handlebar
    k.box((2.6, 1.0, 2.6), (7, 10.95, 0), NAVY, r=0.14)
    k.box((2.2, 0.5, 2.2), (7, 11.7, 0), RUBBER, r=0.14)
    k.box((1.1, 0.5, 1.6), (8.75, 11.2, 0), NAVY, r=0.1)
    k.rod((8.75, 11.3, 0), (8.75, 13.4, 0), 0.34, NAVY, n=10)
    k.rod((8.75, 13.4, -1.75), (8.75, 13.4, 1.75), 0.24, CHROME, n=10)
    for s, _ in SIDES:
        k.rod((8.75, 13.4, s * 1.05), (8.75, 13.4, s * 1.95), 0.36, RUBBER, n=10)
    # ---- twelve yellow seats
    for x in SEAT_X:
        for s, _ in SIDES:
            seat(k, x, s)


def hull_marks(k):
    """The Tidewalker's ATT_ set (Boat/Builder buildTidewalkerAsset reads these), in model space."""
    def hr(name, x, y, z):      # numbers in HullRoot space
        k.atts["ATT_" + name] = (x - K.ORIGIN[0], y - K.ORIGIN[1], z - K.ORIGIN[2])
    k.att("DriverSeat", (7, 12.25, 0))
    k.att("EyePoint", (7.7, 15.6, 0))
    for i, (x, s) in enumerate(((-0.4, -1), (-0.4, 1), (-3.0, -1))):
        k.att("PassengerSeat%d" % (i + 1), (x, 3.3, s * SEAT_Z))
    hr("TowHitch", 0, 0.6, 31.4)
    hr("BowPoint", 0, 0.6, -30)
    hr("DriveAttachment", 0, 0, 0)
    k.att("NavPort", (6.5, 4.1, -4.9))
    k.att("NavStarboard", (6.5, 4.1, 4.9))
    k.att("NavMasthead", (7, 11.4, 1.9))
    k.att("NavStern", (-20.1, 3.8, 0))
    k.att("Beacon", (-5, RT + RR + 0.4, 0))
    k.att("Searchlight", (20.6, RT + 1.0, 0))
    for i, s in enumerate((-1, 1)):
        k.att("Prop%d" % (i + 1), (-20.6, -1.4, s * 3))
    slots = [(x, s) for x in reversed(SEAT_X) for s in (-1, 1)] + [(2.0, -1), (2.0, 1)]
    for i, (x, s) in enumerate(slots):
        k.att("SurvivorSlot%d" % (i + 1), (x, 3.3, s * SEAT_Z))
    for i, (x, z) in enumerate(((-5.5, -20), (5.5, -20), (-6.5, -7), (6.5, -7), (-6.5, 7), (6.5, 7), (-5.5, 20), (5.5, 20))):
        hr("Float%d" % (i + 1), x, -3, z)


def pilot(k):
    def body():
        h = 0.9             # concept numbers about the saddle, hips at y 0.9
        k.box((1.3, 0.8, 2.0), (0, h, 0), NAVY, r=0.14)
        for s, _ in SIDES:
            k.box((1.2, 0.75, 1.2), (0.5, 0.45, 1.3 * s), NAVY, (22 * s, 0, 0), r=0.12)     # legs splayed, can't reach
            k.box((1.4, 0.85, 0.95), (0.95, -0.05, 2.1 * s), RUBBER, (40 * s, 0, 0), r=0.14)
            k.rod((0.1, 2.8, 1.22 * s), (1.45, 1.55, 1.25 * s), 0.34, VEST, n=8)            # arms to the bar
            k.box((0.62, 0.62, 0.62), (1.45, 1.5, 1.25 * s), WHITE, r=0.12)
        k.box((1.3, 1.9, 2.15), (0, 2.25, 0), VEST, r=0.16)                                 # the orange vest is the read
        for y in (1.75, 2.75):
            k.box((0.14, 0.26, 2.05), (0.67, y, 0), WHITE, r=0.04)
        k.cyl(0.45, 0.4, (0, 3.3, 0), SKIN, n=12)
        k.cyl(0.8, 1.45, (0, 4.05, 0), SKIN, n=18)
        # face: goggles pushed up on a big smile
        for s, _ in SIDES:
            k.torus(0.28, 0.1, (0.82, 4.2, 0.36 * s), CHROME, (0, 90, 0), n=10, m_=4)
            k.cyl(0.26, 0.2, (0.76, 4.2, 0.36 * s), GLASS, (0, 0, 90), n=10)
        k.box((0.14, 0.14, 0.9), (0.8, 3.66, 0), NAVY, r=0.03)
        for s, _ in SIDES:
            k.box((0.14, 0.14, 0.3), (0.77, 3.76, 0.5 * s), NAVY, (35 * s, 0, 0), r=0.03)
        k.sphere(0.98, (-0.03, 4.72, 0), WHITE, (1, 0.9, 1), True, n=18, lat=4)             # helmet
        k.cyl(1.03, 0.26, (-0.03, 4.72, 0), RED, n=18)
    k.scaled((7, 11.95, 0), 1.2, body)


def side_boosters(k):
    for s, tag in SIDES:
        z = 6.2 * s
        for x0, x1, c in ((-12, -3, NAVY), (-3, -0.5, WHITE), (-0.5, 4, NAVY)):
            k.along(x0, x1, 2.6, c, RT, z, n=22)
        prof = [(0, 0), (2.56, 0)] + [(2.6 * (1 - (i / 9) ** 2) ** 0.62, 4.5 * i / 9) for i in range(10)]
        prof[-1] = (0, 4.5)
        k.lathe(prof, 22, RED, (4, RT, z), (0, 0, -90))
        k.sphere(0.7, (8.2, RT, z), SEAT, n=12, lat=4)
        k.along(-12.8, -12, 2.2, NAVY, RT, z, n=20)
        bell = [(0, 0), (1.5, 0)] + [(1.5 + 1.0 * (i / 5) ** 1.5, 2.8 * i / 5) for i in range(1, 6)] + [(2.3, 2.8), (1.2, 0.4), (0, 0.4)]
        k.lathe(bell, 20, CHROME, (-12.8, RT, z), (0, 0, 90))
        k.flame(-13.4, RT, z, 1.65, 10.6)       # ends short of the L50 sun disc at x -25, so it never pokes through the face
        k.att("Flame_" + tag, (-15.6, RT, z))
        # fat wedged pylons: gunwale and rocket flow into the booster, no struts
        for x in (-3.4, 2.0):
            section(k, [(s * 2.6, 3.6), (s * 5.0, 3.6), (s * 6.6, 5.3), (s * 5.4, 7.9), (s * 3.0, 6.0)], x - 1.3, x + 1.3, NAVY, 0.1)
            k.ring(x - 0.45, 0.9, 2.5, 2.86, RUBBER, RT, z, n=22)
        k.at((0, RT, z), (90 * s, 0, 0), lambda: side_fin(k))


def side_fin(k):
    k.prism([(-8, 2.4), (-10.6, 5.2), (-13.4, 5.2), (-11.6, 2.4)], -0.5, 0.5, NAVY, lambda a, b, d: (a, b, d), 0.1)


def gold_plating(k):
    for s, _ in SIDES:
        for x0, x1 in ((-15.6, -9), (-9, -2.5), (-2.5, 4)):                 # one heavy belt on the red band
            k.box((x1 - x0 - 0.06, 0.86, 0.14), ((x0 + x1) / 2, 0.6, s * 5.05), GOLD, r=0.05)
        for x0, x1 in ((-20, -8), (-8, 6)):                                 # gunwale caps, chunky, own studs
            k.brick((x1 - x0 - 0.06, 0.56, 1.1), ((x0 + x1) / 2, 3.88, s * 4.5), GOLD, studs="big")
        k.brick((1.1, 0.56, 3.94), (-19.5, 3.88, s * 2.0), GOLD, studs="big")
        # a sculpted gold wedge on each bow, the red band's whole first run
        g = math.degrees(math.atan2(5, 21.5))
        k.box((16.4, 0.86, 0.14), (14.0, 0.6, s * 3.2), GOLD, (0, g * s, 0), r=0.05)
        k.box((10.0, 0.34, 0.14), (11.0, 2.05, s * (5 * (31 - 11.0) / 25 + 0.07)), GOLD, (0, math.degrees(math.atan2(5, 25)) * s, 0), r=0.05)
    for x in (-14, -2, 10):                                                 # fat rings exactly on the rocket's red bands
        k.ring(x - 0.75, 1.5, RR - 0.1, RR + 0.18, GOLD, RT, 0)
    # a gold cap on the round nose, a collar under it: toy, not a spike
    prof = [(2.25, 0)] + [(RR * (1 - ((5.7 + 2.3 * i / 7) / 8) ** 2) ** 0.62 + 0.1, 2.3 * i / 7) for i in range(8)]
    prof[-1] = (0, 2.45)
    k.lathe(prof, 24, GOLD, (18.7, RT, 0), (0, 0, -90))
    k.ring(18.2, 0.6, 1.9, 2.75, GOLD, RT, 0, n=24)
    k.ring(-19.45, 0.34, 2.8, 3.4, GOLD, RT, 0)
    k.cyl(2.3, 0.2, (-21.5, 1.2, 0), GOLD, (0, 0, 90), n=18)                # transom badge on the swim platform's side, fat
    k.cyl(1.05, 0.14, (-21.66, 1.2, 0), NAVY, (0, 0, 90), n=14)
    k.box((0.7, 1.9, 2.4), (-21.2, 0.0, 0), GOLD, r=0.1)


def wave_wall(k):
    # two curling walls sprung from the stern quarters; the centre lane stays open for the chase camera
    n = 9
    for s, tag in SIDES:
        secs, foam = [], []
        for i in range(n + 1):
            t = i / n
            x = -13.5 - 20.5 * t
            z = 4.9 + 9.0 * t ** 0.85
            top = 1.2 + 7.8 * t ** 1.15
            w = 1.5 + 2.6 * t                        # wall thickness
            lean = 1.8 * t                           # the crest curls outward over the wall's foot
            pts = [(z, -1.0), (z + w * 0.9, -1.0), (z + w * 1.05, top * 0.45), (z + w + lean, top), (z + lean * 0.8, top),
                   (z - 0.15 * t, top * 0.45)]
            secs.append([(x, y, s * a) for a, y in pts])
            cap = 1.1 + 0.7 * t
            fs = [(z + lean * 0.8 - 0.5, top - 0.15), (z + w + lean + 0.5, top - 0.15), (z + w + lean + 0.3, top + cap), (z + lean * 0.8 - 0.25, top + cap)]
            foam.append([(x - 0.07, y, s * a) for a, y in fs])
            if i >= 2:
                k.stud(k.stack[-1], (x, top + cap - 0.02, s * (z + lean * 0.8 + (w + 0.1) / 2)), WHITE, big=True)
        # taper the first section into the hull side and close the last into a round curl
        secs[0] = [(x, -1.0 + (y + 1.0) * 0.3, z_) for x, y, z_ in secs[0]]
        k.loft(secs, [DEEP, DEEP, AQUA, WHITE, AQUA, DEEP])
        k.loft(foam, WHITE)
        for f, r in ((0.55, 1.5), (0.78, 1.9), (1.0, 2.4)):                 # fat foam curls on the crest
            t = f
            x, z, top = -13.5 - 20.5 * t, 4.9 + 9.0 * t ** 0.85, 1.2 + 7.8 * t ** 1.15
            k.sphere(r, (x + 0.2, top + 1.3 + 0.7 * t, s * (z + 2.6 * t + 1.0)), WHITE, n=12, lat=4)
        k.att("Crest_" + tag, (-34, 12, s * 15))


def gold_eagle(k):
    def bird():
        k.cyl(1.0, 0.7, (0, 0.2, 0), NAVY, r2=0.8, n=14)
        k.box((1.5, 2.0, 1.4), (-0.05, 1.5, 0), GOLD, (0, 0, -12), r=0.3)
        k.sphere(0.85, (0.42, 1.65, 0), GOLD, n=14, lat=4)
        k.cyl(0.46, 1.0, (0.55, 2.7, 0), GOLD, (0, 0, -25), n=12)
        k.sphere(0.72, (0.85, 3.3, 0), GOLD, n=14, lat=4)
        k.cone(0.34, 1.0, (1.75, 3.2, 0), VEST, (0, 0, -100), tip=0.1, n=10)
        for s, _ in SIDES:
            k.sphere(0.15, (1.3, 3.5, 0.36 * s), NAVY, n=8, lat=3)
            k.box((0.5, 0.16, 0.34), (1.22, 3.72, 0.32 * s), GOLD, (0, 0, -20), r=0.04)
            k.box((0.55, 0.34, 0.34), (0.5, 0.65, 0.36 * s), VEST, r=0.06)
            def wing():
                for i, ln in enumerate((6.2, 4.7, 3.2)):                    # three fat feathers, each shorter and further aft
                    k.box((1.5, 0.5, ln), (-1.2 * i, 0.12 * i, s * ln / 2), GOLD, r=0.16)
                k.box((2.7, 0.62, 2.4), (-1.1, 0.34, s * 1.3), GOLD, r=0.18)
            k.at((-0.1, 2.5, 0.6 * s), (-30 * s, -14 * s, 0), wing)
        k.box((2.3, 0.4, 1.9), (-1.5, 1.1, 0), GOLD, (0, 0, 18), r=0.14)
    k.scaled((33.0, 4.8, 0), 1.45, bird)


def rocket_fins(k):
    def fin():
        k.prism([(-6.4, 2.9), (-11.6, 10.0), (-16.8, 10.0), (-13.2, 2.9)], -0.72, 0.72, RED, lambda a, b, d: (a, b, d), 0.14)
        k.prism([(-9.2, 6.45), (-10.65, 8.45), (-15.1, 8.45), (-14.0, 6.45)], -0.8, 0.8, WHITE, lambda a, b, d: (a, b, d), 0.05)
        k.brick((5.7, 0.7, 1.7), (-14.2, 10.2, 0), GOLD, studs=[(-1.6, 0.33, 0), (1.6, 0.33, 0)], big=True)
    for a in (0, 120, -120):
        k.at((0, RT, 0), (a, 0, 0), fin)


def gold_throne(k):
    k.box((4.68, 2.6, 3.7), (7, 10.45, 0), GOLD, r=0.2)                      # plinth hugging the rocket's back
    k.box((3.2, 0.5, 3.0), (7, 12.0, 0), GOLD, r=0.12)
    k.box((2.5, 0.22, 2.5), (7, 12.33, 0), RED, r=0.06)
    # low back, then a fat open arch round the pilot: from behind you look through it at him
    k.box((1.0, 2.5, 5.0), (4.95, 13.5, 0), GOLD, r=0.18)
    k.box((0.14, 1.7, 3.6), (5.5, 13.5, 0), RED, r=0.04)
    for s, _ in SIDES:
        k.box((1.6, 8.2, 1.6), (4.95, 15.5, 3.0 * s), GOLD, r=0.24)
        k.box((3.2, 0.8, 0.95), (6.75, 13.5, 2.2 * s), GOLD, r=0.16)
        k.box((0.95, 1.2, 0.9), (5.6, 12.6, 2.2 * s), GOLD, r=0.14)
        k.sphere(0.58, (8.45, 13.55, 2.2 * s), GOLD, n=12, lat=4)
        k.sphere(1.05, (4.95, 20.1, 3.0 * s), GOLD, n=12, lat=4)
    k.box((1.6, 1.5, 7.4), (4.95, 19.9, 0), GOLD, r=0.24)
    for z, h in ((-1.55, 1.7), (0, 2.5), (1.55, 1.7)):                       # three fat crown points on the arch
        k.cone(0.72, h, (4.95, 20.5 + h / 2, z), GOLD, tip=0.14, n=10)
    k.sphere(0.55, (4.95, 23.1, 0), RED, n=12, lat=4)


def _popper(k, s, tag):
    k.cyl(1.6, 0.8, (0, 0.2, 0), GOLD, n=16)
    for i, c in enumerate((RED, WHITE, RED, WHITE, RED)):                   # the striped paper cone that says party, not barrel
        r0, r1 = 0.8 + 2.3 * i / 5, 0.8 + 2.3 * (i + 1) / 5
        k.lathe([(0, 0), (r0, 0), (r1, 1.3), (0, 1.3)], 18, c, (0, 0.6 + 1.3 * i, 0))
    k.lathe([(2.8, 0), (3.5, 0), (3.5, 0.55), (2.8, 0.55), (2.8, 0)], 18, GOLD, (0, 7.05, 0))
    k.att("Confetti_" + tag, (0, 7.6, 0))
    # a burst packed into the mouth, so nothing floats: fat paper puffs, big squares, one curly streamer
    for (a, r, cell, h) in ((0, 1.6, GOLD, 7.6), (120, 1.45, RED, 7.7), (240, 1.5, WHITE, 7.6)):
        k.sphere(r, (1.25 * math.cos(math.radians(a)), h, 1.25 * math.sin(math.radians(a))), cell, n=10, lat=3)
    bits = ((0.3, 9.4, 0.2, GOLD), (2.0, 9.0, 0.9, RED), (-1.7, 9.2, 1.1, WHITE), (0.9, 9.8, -1.8, SEAT), (-1.3, 9.9, -1.2, RED), (0.1, 11.0, 1.0, SEAT))
    for i, (x, y, z, c) in enumerate(bits):
        k.box((1.6, 0.42, 1.6), (x, y, z), c, (20 + 37 * i, 40 * i, 15 + 29 * i), r=0.08)
    pts = [(math.cos(0.5 + j / 10 * 5.5) * (0.6 + 1.5 * j / 10), 7.4 + j / 10 * 5.2, math.sin(0.5 + j / 10 * 5.5) * (0.6 + 1.5 * j / 10)) for j in range(11)]
    w = 0.42
    k.loft([[(x - w, y, z - w), (x + w, y, z - w), (x + w, y, z + w), (x - w, y, z + w)] for x, y, z in pts], SEAT)


def party_cannons(k):
    for s, tag in SIDES:
        k.at((-4.5, RT + 2.3, 6.4 * s), (64 * s, 0, 6), lambda s=s, tag=tag: _popper(k, s, tag))


def mega_trophy(k):
    k.brick((3.2, 1.6, 3.2), (24.5, 5.6, 0), NAVY, studs="big")
    k.brick((2.5, 1.2, 2.5), (24.5, 7.0, 0), NAVY)
    for s, _ in SIDES:
        k.box((1.7, 0.75, 0.14), (24.5, 7.0, s * 1.28), GOLD, r=0.04)
    k.box((2.0, 0.45, 2.0), (24.5, 7.82, 0), GOLD, r=0.08)
    i = 1.75
    prof = [(0, 0), (1, 0), (1, 0.25), (0.5, 0.45), (0.42, 1.1), (0.78, 1.35), (0.78, 1.6), (0.42, 1.85), (0.5, 2.3), (1.3, 2.5), (2.0, 3.0), (2.4, 3.8),
            (2.55, 4.8), (2.6, 5.6), (2.72, 5.82), (2.52, 5.88), (2.3, 5.0), (2.1, 4.1), (1.5, 3.3), (0, 3.1)]
    k.lathe([(r * i, y * i) for r, y in prof], 28, GOLD, (24.5, 8.0, 0))
    y = 8.0 + 3.65 * i
    k.lathe([(2.42 * i - 0.1, -0.5), (2.42 * i + 0.14, -0.5), (2.42 * i + 0.18, 0.5), (2.42 * i - 0.1, 0.5), (2.42 * i - 0.1, -0.5)], 28, RED, (24.5, y, 0))
    for s, _ in SIDES:
        k.torus(1.55, 0.52, (24.5, 8.0 + 4.55 * i, s * 5.1), GOLD, n=14, m_=6)
    k.att("Gleam", (24.5, 8.0 + 5.9 * i, 0))


def sun_booster(k):
    fx = -25.0       # the disc's centre plane
    k.along(-19.75, fx, 3.5, GOLD, RT)                                     # hub over the nozzle: the sun is bolted on the rocket
    for s, _ in SIDES:
        k.prism([(-19.9, 0.3), (-24.8, 0.3), (-24.8, 5.2), (-19.9, 3.5)], s * 2.8, s * 4.3, GOLD, lambda a, b, d: (a, b, d), 0.12)
    k.along(fx - 0.6, fx + 0.6, 7.2, GOLD, RT, n=32)
    k.ring(fx - 0.45, 0.9, 7.1, 8.1, FLAME_Y, RT, 0, n=32)
    # fat wedge rays, no bottom ones: those would sit in the sea
    for i, a in enumerate((0, 30, -30, 60, -60, 90, -90, 120, -120)):
        ln, cell, w = (2.5, GOLD, 1.45) if i % 2 == 0 else (1.9, FLAME_O, 1.2)
        k.at((fx, RT, 0), (a, 0, 0), lambda ln=ln, cell=cell, w=w: k.prism([(-w, 8.0), (w, 8.0), (0, 8.0 + ln)], -0.5, 0.5, cell, lambda p, q, d: (d, q, p), 0.08))
    # the face, looking aft at the player
    f = fx - 0.6
    for s, _ in SIDES:
        k.cyl(1.35, 0.3, (f - 0.05, RT + 2.7, s * 2.8), NAVY, (0, 0, 90), n=18)
        k.cyl(0.45, 0.14, (f - 0.24, RT + 3.2, s * 2.45), WHITE, (0, 0, 90), n=12)
        k.cyl(1.05, 0.2, (f - 0.02, RT - 0.6, s * 5.0), FLAME_O, (0, 0, 90), n=16)
    mouth = [(-3.9, -1.2)] + [(3.9 * math.cos(math.pi * i / 10), -1.2 - 3.7 * math.sin(math.pi * i / 10)) for i in range(11)][::-1][1:]
    k.prism([(a, b) for a, b in reversed(mouth)], f - 0.22, f + 0.1, NAVY, lambda a, b, d: (d, RT + b, a), 0)
    k.flame(f - 0.1, RT - 3.4, 0, 2.3, 10.0, n=16)                         # the long flame: the sun blows it out of its grin
    for s, _ in SIDES:
        k.flame(f - 0.1, RT - 3.6, s * 1.9, 1.3, 6.0, n=12)
    k.att("Flame_Sun", (f - 2.0, RT - 3.4, 0))
    for s, _ in SIDES:
        seat(k, 2.0, s)


PIECES = {
    "Pilot": (41, pilot), "SideBoosters": (42, side_boosters), "GoldPlating": (43, gold_plating), "WaveWall": (44, wave_wall),
    "GoldEagle": (45, gold_eagle), "RocketFins": (46, rocket_fins), "GoldThrone": (47, gold_throne), "PartyCannons": (48, party_cannons),
    "MegaTrophy": (49, mega_trophy), "SunBooster": (50, sun_booster),
}


def asset(short):
    return short if short.startswith("M_Veh") else "M_Upg_Rocket_" + short


def make(short, name=None):
    """Builds one LOD0 object and its ATT_ empties. Pieces: pivot at HullRoot. The hull: pivot at Builder.TIDEWALKER_ORIGIN."""
    import bpy
    is_hull = short.startswith("M_Veh")
    k = K.Kit(K.MODEL_FRAME if is_hull else K.ROOT_FRAME)
    if is_hull:
        hull(k)
        hull_marks(k)
    else:
        PIECES[short][1](k)
    obj = k.to_object(name or asset(short) + "_LOD0", K.material())
    atts = []
    for att, (x, y, z) in k.atts.items():
        e = bpy.data.objects.new(att, None)
        e.location = (-x, z, y)
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)
    return obj, atts


def spec(short):
    import names
    if "Upg" not in names.CATEGORIES:   # shortcut: run-time only, tools/ is not ours; add Upg to names.py when upgrade pieces settle
        names.CATEGORIES = (*names.CATEGORIES, "Upg")
    obj, atts = make(short)
    return {
        "name": asset(short), "budget": "small_craft" if short.startswith("M_Veh") else "large_prop", "tier": "standard",
        "dims_m": tuple(round(d / 3, 3) for d in obj.dimensions), "origin": "free", "tiling": True,
        "sets": [{"name": K.SET_NAME, "set": K.SET, "size": 256, "wet": False, "dir": K.TEX_DIR}],
        "meshes": [{"object": obj, "set": K.SET}], "attachments": atts,
        "waivers": {
            "_COL proxy": "look only: CanCollide off, the hull's code box is the collision",
            "LOD UV layout": "flat palette cells, not a unique unwrap (like the other toy-brick assets)",
            "texture sets": "one flat palette set shared by the hull and all pieces",
            "LOD0 floor": "fewer, bigger shapes by design (art director notes on the other stages)",
            "UV faces": "decimated LOD faces collapse their small UV ring inside a palette cell: the colour stays the cell's",
        },
    }
