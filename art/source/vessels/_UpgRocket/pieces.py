"""The Rocket Cutter hull (L41), its pilot and nine upgrade pieces (L42-L50), from the owner-cleared concept (artifact b8ff43b0).

Concept numbers (see kit.py), with the rocket 1.4x the concept's: it is the boat's top line and the joke. Round 2 (art director 6.5/10):
only the rocket and the sun stay big, the sun is small and warm behind the nozzle, every piece sits on a visible studded bracket,
the poppers have wide mouths with streamers spilling out. See RESULT.md for the other departures.
"""
import math

import kit as K
from kit import (AQUA, CHROME, DEEP, FLAME_O, FLAME_W, FLAME_Y, GLASS, GOLD, NAVY, RED, RUBBER, SEAT, SKIN, SUN, TAN, VEST, WHITE)

RT, RR = 9.8, 4.9       # rocket axis height and radius
BY, BZ, BR = 8.3, 7.8, 2.6      # side boosters
PX, SADDLE = 10.0, 15.85        # the rider's x, and the cushion top he sits on
NOSE0, NOSE = 21.0, 10.0
SIDES = ((1, "S"), (-1, "P"))
SEAT_X = (-17.8, -15.2, -12.6, -5.6, -3.0, -0.4)
SEAT_Z = 3.4


def plan(k, poly, y0, y1, cell, bevel=0.1):
    """A plan-view polygon (x, z) extruded up from y0 to y1."""
    k.prism(poly, y0, y1, cell, lambda a, b, d: (a, d, b), bevel)


def section(k, poly, x0, x1, cell, bevel=0.1):
    """A cross-section polygon (z, y) extruded along x."""
    k.prism(poly, x0, x1, cell, lambda a, b, d: (d, b, a), bevel)


def seat(k, x, s):
    k.box((1.6, 0.4, 1.4), (x, 3.02, s * SEAT_Z), SEAT, r=0)
    k.box((0.5, 1.3, 1.4), (x - 0.58, 3.82, s * SEAT_Z), SEAT, r=0)


def nose_r(u):
    return RR * max(0.0, 1 - (u / NOSE) ** 2) ** 0.62


def strap(k, x, w=1.2, cell=NAVY):
    """A fat band round the rocket: what visibly holds a piece on."""
    k.ring(x - w / 2, w, RR - 0.1, RR + 0.24, cell, RT, 0, n=24)


def hull(k):
    # ---- the knife: five raked courses, each tip further forward than the one below
    plan(k, [(6, -4.5), (21, 0), (6, 4.5)], -2.4, -1.2, NAVY, 0.14)
    plan(k, [(6, -5), (24, 0), (6, 5)], -1.2, 0, NAVY)
    plan(k, [(6, -5), (27.5, 0), (6, 5)], 0, 1.2, RED)
    plan(k, [(6, -5), (31, 0), (6, 5)], 1.2, 2.4, WHITE)
    plan(k, [(6, -5), (34.5, 0), (6, 5)], 2.4, 3.6, WHITE)
    for x0, x1 in ((-20, -9), (-9, 6)):       # bilge, chamfered
        section(k, [(-3.6, -2.4), (3.6, -2.4), (5, -1.2), (-5, -1.2)], x0, x1, NAVY, 0.14)
    for y, cell, seams in ((-1.2, NAVY, (-20, -4, 6)), (0, RED, (-20, -12, 2, 6)), (1.2, WHITE, (-20, -6, 6))):
        for x0, x1 in zip(seams, seams[1:]):
            k.box((x1 - x0, 1.2, 10), ((x0 + x1) / 2, y + 0.6, 0), cell)
    # ---- deck well: fat studded gunwale walls round tan plates
    for s, tag in SIDES:
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
        k.att("NumberPlate_" + tag, (-17.2, 1.2, s * 5.16))
        k.torus(0.85, 0.32, (3.2, 1.3, s * 5.3), VEST, n=14, m_=6)                  # life ring
        for a in range(4):
            c = math.radians(45 + 90 * a)
            k.box((0.34, 0.74, 0.74), (3.2 + 0.85 * math.cos(c), 1.3 + 0.85 * math.sin(c), s * 5.3), WHITE, (0, 0, 45 + 90 * a), r=0)
        k.cyl(0.65, 0.14, (-20.05, 3.0, s * 3.3), RED, (0, 0, 90), n=12)                # tail light
        for x, s2 in ((-19, 8), (-11, 8), (-3, 9)):
            k.box((s2 - 0.04, 0.44, 3.98), (x + s2 / 2, 2.6, s * 2), TAN, r=0.08)
    # foredeck studs and the red prow spine
    top = k.stack[-1]
    for x in (8.2, 10.8, 13.2):
        hw = 5 * (34.5 - x) / 28.5 - 0.9
        for z in (-hw, hw):
            k.stud(top, (x, 3.58, z), WHITE, big=True)
    plan(k, [(18, -2.4), (38, 0), (18, 2.4)], 3.6, 4.8, RED)
    for x in (25.5, 28.5, 31.5):
        k.stud(top, (x, 4.78, 0), RED, big=True)
    t = lambda y: 24 + (y + 0.6) / 0.343
    k.prism([(t(-2.4) - 1.2, -2.4), (t(-2.4) + 0.9, -2.4), (t(4.9) + 0.9, 4.9), (t(4.9) - 1.2, 4.9)], -0.28, 0.28, CHROME, lambda a, b, d: (a, b, d), 0.08)
    # ---- stern
    k.brick((1.4, 0.6, 7.2), (-20.7, 0.3, 0), NAVY, studs="big")
    # ---- cradle: fat saddles cut to the rocket, the front one on the taper where she overhangs the knife
    for x, hw in ((-9, 4.2), (5, 4.2), (15.5, 2.9)):
        prof = [(hw, 3.2)] + [(hw - i * 2 * hw / 14, RT - math.sqrt((RR + 0.06) ** 2 - (hw - i * 2 * hw / 14) ** 2)) for i in range(15)] + [(-hw, 3.2)]
        k.box((4.4, 0.5, 2 * hw + 0.7), (x, 3.45, 0), NAVY)
        section(k, prof, x - 1.6, x + 1.6, NAVY, 0)
        k.ring(x - 0.55, 1.1, RR - 0.1, RR + 0.26, RUBBER, RT, 0, n=20)
        k.box((1.3, 0.34, 1.3), (x, RT + RR + 0.32, 0), CHROME, r=0.08)
    # ---- the rocket, far too big: three red bands, round nose, cartoon windows
    for x0, x1, c in ((-15, -12, RED), (-12, -9.5, NAVY), (-9.5, -1, WHITE), (-1, 2, RED), (2, 14, WHITE), (14, 16, NAVY), (16, 19, RED), (19, 21, WHITE)):
        k.along(x0, x1, RR, c, RT, n=24)
    nose = [(0, 0), (RR - 0.04, 0)] + [(nose_r(NOSE * i / 8), NOSE * i / 8) for i in range(9)]
    nose[-1] = (0, NOSE)
    k.lathe(nose, 24, RED, (NOSE0, RT, 0), (0, 0, -90))
    k.sphere(1.15, (NOSE0 + NOSE - 0.5, RT, 0), WHITE, n=14, lat=5)        # a toy ball on the nose: never a warhead
    k.along(-16, -15, 3.9, NAVY, RT)
    bell = [(0, 0), (2.66, 0)] + [(2.66 + 1.68 * (i / 6) ** 1.5, 4.9 * i / 6) for i in range(1, 7)] + [(4.04, 4.9), (2.3, 0.7), (0, 0.7)]
    k.lathe(bell, 18, CHROME, (-16, RT, 0), (0, 0, 90))
    k.ring(-19.6, 0.8, 3.2, 4.2, NAVY, RT, 0)
    k.flame(-16.9, RT, 0, 2.2, 10.0)
    k.att("Flame_Main", (-21.0, RT, 0))
    for s, _ in SIDES:
        for x in (-5.5, 6.0):
            k.rim_window(x, RT, s, 1.4, RR - 0.04)
    # ---- saddle and handlebar
    k.box((2.6, 1.0, 2.6), (PX, 14.9, 0), NAVY, r=0.14)
    k.box((2.2, 0.45, 2.2), (PX, SADDLE - 0.225, 0), RUBBER, r=0.14)
    k.box((1.1, 0.5, 1.6), (PX + 1.75, 14.75, 0), NAVY, r=0.1)
    k.rod((PX + 1.75, 14.9, 0), (PX + 1.75, 17.6, 0), 0.34, NAVY, n=10)
    k.rod((PX + 1.75, 17.6, -1.75), (PX + 1.75, 17.6, 1.75), 0.24, CHROME, n=10)
    for s, _ in SIDES:
        k.rod((PX + 1.75, 17.6, s * 1.05), (PX + 1.75, 17.6, s * 1.95), 0.36, RUBBER, n=10)
    # ---- twelve yellow seats
    for x in SEAT_X:
        for s, _ in SIDES:
            seat(k, x, s)


def hull_marks(k):
    """The Tidewalker's ATT_ set (Boat/Builder buildTidewalkerAsset reads these), in model space. The rider's seat is the saddle."""
    def hr(name, x, y, z):      # numbers in HullRoot space
        k.atts["ATT_" + name] = (x - K.ORIGIN[0], y - K.ORIGIN[1], z - K.ORIGIN[2])
    k.att("DriverSeat", (PX, SADDLE + 0.3, 0))
    k.att("EyePoint", (PX + 0.7, SADDLE + 3.95, 0))
    for i, (x, s) in enumerate(((-0.4, -1), (-0.4, 1), (-3.0, -1))):
        k.att("PassengerSeat%d" % (i + 1), (x, 3.3, s * SEAT_Z))
    hr("TowHitch", 0, 0.6, 31.4)
    hr("BowPoint", 0, 0.6, -30)
    hr("DriveAttachment", 0, 0, 0)
    k.att("NavPort", (6.5, 4.1, -4.9))
    k.att("NavStarboard", (6.5, 4.1, 4.9))
    k.att("NavMasthead", (PX, 15.4, 1.9))
    k.att("NavStern", (-20.1, 3.8, 0))
    k.att("Beacon", (-5, RT + RR + 0.4, 0))
    k.att("Searchlight", (NOSE0 + NOSE, RT + 1.0, 0))
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
    k.scaled((PX, SADDLE, 0), 1.2, body)


def side_boosters(k):
    for s, tag in SIDES:
        z = BZ * s
        for x0, x1, c in ((-12, -3, NAVY), (-3, -0.5, WHITE), (-0.5, 4, NAVY)):
            k.along(x0, x1, BR, c, BY, z, n=22)
        prof = [(0, 0), (BR - 0.04, 0)] + [(BR * (1 - (i / 9) ** 2) ** 0.62, 4.5 * i / 9) for i in range(10)]
        prof[-1] = (0, 4.5)
        k.lathe(prof, 22, RED, (4, BY, z), (0, 0, -90))
        k.sphere(0.7, (8.2, BY, z), WHITE, n=12, lat=4)
        k.along(-12.8, -12, 2.2, NAVY, BY, z, n=20)
        bell = [(0, 0), (1.5, 0)] + [(1.5 + 1.0 * (i / 5) ** 1.5, 2.8 * i / 5) for i in range(1, 6)] + [(2.3, 2.8), (1.2, 0.4), (0, 0.4)]
        k.lathe(bell, 20, CHROME, (-12.8, BY, z), (0, 0, 90))
        k.flame(-13.4, BY, z, 1.65, 12.5)
        k.att("Flame_" + tag, (-15.6, BY, z))
        # brackets: a studded plate on the gunwale, a wedge pylon up to the booster, chrome bands round the tube
        for x in (-7.0, 1.2):
            k.brick((3.4, 0.7, 3.2), (x, 4.2, s * 4.6), NAVY, studs=[(-1.1, 0.33, 0.9), (-1.1, 0.33, -0.9), (1.1, 0.33, 0.9), (1.1, 0.33, -0.9)], big=True)
            section(k, [(s * 3.6, 4.5), (s * 6.0, 4.5), (s * 8.6, 6.2), (s * 8.2, 7.2), (s * 5.4, 7.4)], x - 1.2, x + 1.2, NAVY, 0.1)
            k.ring(x - 0.55, 1.1, BR - 0.1, BR + 0.22, CHROME, BY, z, n=22)
        k.at((0, BY, z), (90 * s, 0, 0), lambda: k.prism([(-8, 2.4), (-10.6, 5.0), (-13.4, 5.0), (-11.6, 2.4)], -0.5, 0.5, NAVY, lambda a, b, d: (a, b, d), 0.1))


def gold_plating(k):
    for s, _ in SIDES:
        for x0, x1 in ((-15.6, -9), (-9, -2.5), (-2.5, 4)):                 # one heavy belt on the red band
            k.box((x1 - x0 - 0.06, 0.86, 0.14), ((x0 + x1) / 2, 0.6, s * 5.05), GOLD, r=0.05)
        for x0, x1 in ((-20, -8), (-8, 6)):                                 # gunwale caps, chunky, own studs
            k.brick((x1 - x0 - 0.06, 0.56, 1.1), ((x0 + x1) / 2, 3.88, s * 4.5), GOLD, studs="big")
        k.brick((1.1, 0.56, 3.94), (-19.5, 3.88, s * 2.0), GOLD, studs="big")
        g = math.degrees(math.atan2(5, 21.5))                               # a sculpted gold wedge on each bow, on the red band
        k.box((16.4, 0.86, 0.14), (14.0, 0.6, s * 3.2), GOLD, (0, g * s, 0), r=0.05)
    for x in (-13.5, 0.5, 17.5):                                            # narrow rings: the rocket's red and white still show either side
        k.ring(x - 0.6, 1.2, RR - 0.1, RR + 0.16, GOLD, RT, 0, n=24)
    # a gold cap on the round nose, a collar under it: toy, not a spike
    u0 = 7.2
    prof = [(0, 0), (nose_r(u0) + 0.17, 0)] + [(nose_r(u0 + (9.4 - u0) * i / 6) + 0.17, (9.4 - u0) * i / 6) for i in range(1, 7)] + [(0, 2.25)]
    k.lathe(prof, 24, GOLD, (NOSE0 + u0, RT, 0), (0, 0, -90))
    k.ring(NOSE0 + u0 - 0.5, 0.55, nose_r(u0) - 0.3, nose_r(u0 - 0.5) + 0.3, NAVY, RT, 0, n=24)
    k.ring(-20.97, 0.4, 3.7, 4.55, GOLD, RT, 0)
    k.cyl(2.3, 0.2, (-21.5, 1.2, 0), GOLD, (0, 0, 90), n=18)                # transom badge on the swim platform's side
    k.cyl(1.05, 0.14, (-21.66, 1.2, 0), NAVY, (0, 0, 90), n=14)
    k.box((0.7, 1.9, 2.4), (-21.2, 0.0, 0), GOLD, r=0.1)


def wave_wall(k):
    # two curling walls peeled off the hull sides under the boosters, rising only once they clear the booster flames; centre lane open
    n = 10
    for s, tag in SIDES:
        secs, foam = [], []
        for i in range(n + 1):
            t = i / n
            x = -2 - 32 * t
            z = 5.0 + 11.0 * t
            top = 1.5 + 8.0 * t ** 2.2
            w = 1.3 + 2.4 * t                        # wall thickness
            lean = 1.8 * t                           # the crest curls outward over the wall's foot
            pts = [(z, -1.0), (z + w * 0.9, -1.0), (z + w * 1.05, top * 0.45), (z + w + lean, top), (z + lean * 0.8, top),
                   (z - 0.15 * t, top * 0.45)]
            secs.append([(x, y, s * a) for a, y in pts])
            cap = 0.9 + 0.8 * t
            fs = [(z + lean * 0.8 - 0.4, top - 0.15), (z + w + lean + 0.4, top - 0.15), (z + w + lean + 0.25, top + cap), (z + lean * 0.8 - 0.2, top + cap)]
            foam.append([(x - 0.07, y, s * a) for a, y in fs])
            if i >= 2:
                k.stud(k.stack[-1], (x, top + cap - 0.02, s * (z + lean * 0.8 + (w + 0.1) / 2)), WHITE, big=True)
        secs[0] = [(x, -1.0 + (y + 1.0) * 0.5, z_) for x, y, z_ in secs[0]]
        k.loft(secs, [DEEP, DEEP, AQUA, WHITE, AQUA, DEEP])
        k.loft(foam, WHITE)
        for t, r in ((0.7, 1.3), (0.86, 1.7), (1.0, 2.2)):                  # fat foam curls on the crest
            x, z, top = -2 - 32 * t, 5.0 + 11.0 * t, 1.5 + 8.0 * t ** 2.2
            k.sphere(r, (x + 0.2, top + 1.2 + 0.7 * t, s * (z + 2.4 * t + 1.0)), WHITE, n=12, lat=4)
        k.att("Crest_" + tag, (-34, 11, s * 19))


def gold_eagle(k):
    # small and on the very tip, a hood ornament on a studded plate
    k.brick((3.0, 0.45, 1.9), (34.4, 5.0, 0), NAVY, studs=[(-0.75, 0.2, 0.5), (-0.75, 0.2, -0.5)], big=True)
    k.box((2.0, 0.9, 0.9), (34.7, 4.45, 0), NAVY, r=0.12)

    def bird():
        k.cyl(0.95, 0.7, (0, 0.2, 0), NAVY, r2=0.75, n=14)
        k.box((1.5, 2.0, 1.4), (-0.05, 1.5, 0), GOLD, (0, 0, -12), r=0.3)
        k.sphere(0.85, (0.42, 1.65, 0), GOLD, n=14, lat=4)
        k.cyl(0.46, 1.0, (0.55, 2.7, 0), GOLD, (0, 0, -25), n=12)
        k.sphere(0.72, (0.85, 3.3, 0), GOLD, n=14, lat=4)
        k.cone(0.34, 1.0, (1.75, 3.2, 0), VEST, (0, 0, -100), tip=0.1, n=10)
        for s, _ in SIDES:
            k.sphere(0.15, (1.3, 3.5, 0.36 * s), NAVY, n=8, lat=3)
            k.box((0.5, 0.16, 0.34), (1.22, 3.72, 0.32 * s), GOLD, (0, 0, -20), r=0.04)
            k.box((0.55, 0.34, 0.34), (0.5, 0.65, 0.36 * s), VEST, r=0.06)

            def wing(s=s):
                for i, ln in enumerate((5.0, 3.8, 2.6)):                    # three fat feathers, each shorter and further aft
                    k.box((1.5, 0.5, ln), (-1.2 * i, 0.12 * i, s * ln / 2), GOLD, r=0.16)
                k.box((2.7, 0.62, 2.0), (-1.1, 0.34, s * 1.1), GOLD, r=0.18)
            k.at((-0.1, 2.5, 0.6 * s), (-30 * s, -14 * s, 0), wing)
        k.box((2.3, 0.4, 1.9), (-1.5, 1.1, 0), GOLD, (0, 0, 18), r=0.14)
    k.scaled((35.2, 5.2, 0), 0.95, bird)


def rocket_fins(k):
    def fin():
        k.prism([(-10.8, 4.4), (-14.2, 8.2), (-18.6, 8.2), (-16.2, 4.4)], -0.72, 0.72, RED, lambda a, b, d: (a, b, d), 0.14)
        k.prism([(-12.6, 6.4), (-13.8, 7.75), (-18.0, 7.75), (-17.2, 6.4)], -0.8, 0.8, WHITE, lambda a, b, d: (a, b, d), 0.05)
        k.brick((5.2, 0.6, 1.8), (-16.4, 8.4, 0), NAVY, studs=[(-1.5, 0.28, 0), (1.5, 0.28, 0)], big=True)
        k.box((6.0, 0.9, 2.6), (-13.5, 4.7, 0), NAVY, r=0.14)              # a bolted foot on the rocket's skin
    for a in (0, 135, -135):
        k.at((0, RT, 0), (a, 0, 0), fin)


def gold_throne(k):
    # shrunk: a low studded seat strapped on the rocket's back, nothing above the rider's shoulders but three small crown points
    strap(k, PX, 3.6)
    k.brick((4.4, 1.0, 3.6), (PX, 15.0, 0), GOLD, studs=[(1.4, 0.48, 1.3), (1.4, 0.48, -1.3), (-1.4, 0.48, 1.3), (-1.4, 0.48, -1.3)], big=True)
    k.box((3.0, 0.3, 2.6), (PX, 15.62, 0), GOLD, r=0.08)
    k.box((2.5, 0.2, 2.3), (PX, 15.86, 0), RED, r=0.05)
    k.box((0.9, 3.0, 4.4), (PX - 2.1, 17.0, 0), GOLD, r=0.16)
    k.box((0.14, 2.2, 3.2), (PX - 1.6, 17.1, 0), RED, r=0.04)
    k.box((0.14, 2.2, 3.2), (PX - 2.6, 17.1, 0), NAVY, r=0.04)              # the view from behind is a navy panel, a break in the gold
    for s, _ in SIDES:
        k.box((2.6, 0.6, 0.8), (PX - 0.7, 17.0, 2.1 * s), GOLD, r=0.12)
        k.box((0.8, 1.2, 0.8), (PX - 1.4, 16.3, 2.1 * s), GOLD, r=0.12)
    k.box((1.0, 0.4, 4.6), (PX - 2.1, 18.7, 0), GOLD, r=0.1)
    for z, h in ((-1.55, 0.9), (0, 1.3), (1.55, 0.9)):
        k.cone(0.5, h, (PX - 2.1, 18.85 + h / 2, z), GOLD, tip=0.1, n=8)


def _popper(k, s, tag):
    k.cyl(1.5, 0.7, (0, 0.15, 0), GOLD, n=14)
    for i, c in enumerate((WHITE, RED, WHITE, RED)):                        # short striped paper cone, flaring wide: party, not barrel
        r0, r1 = 0.9 + 3.5 * (i / 4) ** 1.5, 0.9 + 3.5 * ((i + 1) / 4) ** 1.5
        k.lathe([(0, 0), (r0, 0), (r1, 1.15), (0, 1.15)], 20, c, (0, 0.4 + 1.15 * i, 0))
    k.lathe([(3.6, 0), (4.75, 0), (4.75, 0.4), (3.6, 0.4), (3.6, 0)], 20, WHITE, (0, 5.0, 0))
    k.cyl(3.7, 0.2, (0, 5.05, 0), NAVY, n=20)                               # the dark open mouth
    k.att("Confetti_" + tag, (0, 5.8, 0))
    # a burst packed into the mouth, so nothing floats: paper puffs, big squares, three fat flat streamers spilling out over the lip
    for a, r, cell, ring_r in ((0, 1.5, GOLD, 1.9), (120, 1.4, RED, 1.9), (240, 1.45, WHITE, 1.9)):
        k.sphere(r, (ring_r * math.cos(math.radians(a)), 5.6, ring_r * math.sin(math.radians(a))), cell, n=10, lat=3)
    bits = ((0.3, 7.5, 0.2, GOLD), (2.4, 7.2, 0.9, RED), (-2.2, 7.3, 1.1, WHITE), (1.0, 7.9, -2.2, SEAT))
    for i, (x, y, z, c) in enumerate(bits):
        k.box((1.5, 0.4, 1.5), (x, y, z), c, (20 + 37 * i, 40 * i, 15 + 29 * i), r=0.08)
    for a0, c in ((0.5, SEAT), (2.6, WHITE), (4.7, RED)):
        pts = []
        for j in range(9):
            t = j / 8
            r = 2.2 + 4.2 * t
            a = a0 + 0.35 * math.sin(t * 4.0)
            pts.append((r * math.cos(a), 5.3 + 2.6 * math.sin(t * math.pi * 0.8) - 2.8 * t, r * math.sin(a)))
        w, h = 0.8, 0.24
        k.loft([[(x - w, y - h, z - w), (x + w, y - h, z - w), (x + w, y + h, z + w), (x - w, y + h, z + w)] for x, y, z in pts], c)


def party_cannons(k):
    for s, tag in SIDES:
        k.ring(-5.1, 1.2, BR - 0.1, BR + 0.22, CHROME, BY, BZ * s, n=22)
        k.brick((3.2, 0.6, 3.2), (-4.5, BY + BR + 0.1, BZ * s), NAVY)
        k.at((-4.5, BY + BR + 0.3, (BZ + 0.3) * s), (38 * s, 0, 32), lambda s=s, tag=tag: _popper(k, s, tag))     # mouths up, out and aft: the chase camera looks into them


def mega_trophy(k):
    # shrunk: strapped on the rocket's back ahead of the rider, under his head height
    x = 17.5
    strap(k, x, 1.5)
    k.brick((3.0, 1.0, 3.0), (x, 15.0, 0), NAVY, studs=[(1.0, 0.48, 1.0), (1.0, 0.48, -1.0), (-1.0, 0.48, 1.0), (-1.0, 0.48, -1.0)], big=True)
    k.box((1.7, 0.3, 1.7), (x, 15.62, 0), GOLD, r=0.08)
    i = 0.75
    prof = [(0, 0), (1, 0), (1, 0.25), (0.5, 0.45), (0.42, 1.1), (0.78, 1.35), (0.78, 1.6), (0.42, 1.85), (0.5, 2.3), (1.3, 2.5), (2.0, 3.0), (2.4, 3.8),
            (2.55, 4.8), (2.6, 5.6), (2.72, 5.82), (2.52, 5.88), (2.3, 5.0), (2.1, 4.1), (1.5, 3.3), (0, 3.1)]
    k.lathe([(r * i, y * i) for r, y in prof], 24, GOLD, (x, 15.75, 0))
    y = 15.75 + 3.65 * i
    k.lathe([(2.42 * i - 0.1, -0.35), (2.42 * i + 0.14, -0.35), (2.42 * i + 0.18, 0.35), (2.42 * i - 0.1, 0.35), (2.42 * i - 0.1, -0.35)], 24, RED, (x, y, 0))
    for s, _ in SIDES:
        k.torus(0.95, 0.34, (x, 15.75 + 4.55 * i, s * 2.75), GOLD, n=12, m_=6)
    k.att("Gleam", (x, 15.75 + 5.9 * i, 0))


def sun_booster(k):
    # 40% smaller, on a fat navy shaft behind the nozzle: the rocket and the rider stay in view above it
    fx = -28.0
    k.along(-20.3, fx + 0.3, 2.65, NAVY, RT, n=20)
    k.along(-24.8, -23.4, 2.85, WHITE, RT, n=20)
    k.ring(fx + 0.3, 0.6, 2.4, 3.4, FLAME_Y, RT, 0, n=20)
    k.prism([(-19.9, 3.4), (-19.9, 7.2), (-26.4, 8.4), (-26.4, 6.8)], -1.5, 1.5, NAVY, lambda a, b, d: (a, b, d), 0.12)     # a braced wedge off the transom
    for x in (-21.2, -23.2):
        for z in (-0.8, 0.8):
            y = 7.2 + (x + 19.9) / -6.5 * 1.2
            k.stud(k.stack[-1], (x, y - 0.06, z), NAVY, big=True)
    k.along(fx - 0.4, fx + 0.4, 4.3, SUN, RT, n=28)
    k.ring(fx - 0.3, 0.6, 4.2, 4.9, FLAME_O, RT, 0, n=28)
    for i in range(8):                                                     # eight fat wedge rays
        ln, cell, w = (1.5, SUN, 1.05) if i % 2 == 0 else (1.1, FLAME_O, 0.9)
        k.at((fx, RT, 0), (i * 45, 0, 0), lambda ln=ln, cell=cell, w=w: k.prism([(-w, 4.8), (w, 4.8), (0, 4.8 + ln)], -0.35, 0.35, cell, lambda p, q, d: (d, q, p), 0.06))
    # the face, looking aft at the player
    f = fx - 0.4
    for s, _ in SIDES:
        k.cyl(0.85, 0.24, (f - 0.05, RT + 1.6, s * 1.75), NAVY, (0, 0, 90), n=14)
        k.cyl(0.28, 0.12, (f - 0.2, RT + 1.92, s * 1.53), WHITE, (0, 0, 90), n=10)
        k.cyl(0.62, 0.16, (f - 0.02, RT - 0.35, s * 3.05), RED, (0, 0, 90), n=12)
    mouth = [(-2.4, -0.8)] + [(2.4 * math.cos(math.pi * i / 10), -0.8 - 2.3 * math.sin(math.pi * i / 10)) for i in range(11)][::-1][1:]
    k.prism([(a, b) for a, b in reversed(mouth)], f - 0.18, f + 0.08, NAVY, lambda a, b, d: (d, RT + b, a), 0)
    k.flame(f - 0.1, RT - 2.0, 0, 1.45, 8.0, n=14)                         # the long flame: the sun blows it out of its grin
    k.att("Flame_Sun", (f - 1.0, RT - 2.0, 0))
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
