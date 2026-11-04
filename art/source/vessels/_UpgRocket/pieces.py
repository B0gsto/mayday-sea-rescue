"""The Rocket Cutter hull (L41), its pilot and nine upgrade pieces (L42-L50), from the owner-cleared concept (artifact b8ff43b0).

Concept numbers (see kit.py). Must-fix round (art director found a weapon read): the rocket is a fairground ride, a squat round egg sunk in a
wide deck, with no cradle, no tail cone, big windows and chunky fins. Soft puffs, never cones. The side tubes are gone: Side Boosters are
beach-ball pods. L50's stern is one big round sun face. See RESULT.md.
"""
import math

import kit as K
from kit import (AQUA, CHROME, FLAME_O, FLAME_W, FLAME_Y, GLASS, GOLD, NAVY, RED, RUBBER, SEAT, SKIN, SUN, TAN, VEST, WHITE)
from mathutils import Matrix, Vector

B = 9.0                         # the hull's half beam: wide enough to carry her
RT, RY, RZ = 11.4, 9.0, 9.8     # the egg: axis height, half height, half width
XC, HL = -1.0, 16.0             # its middle along the boat and its half length
TAIL, TIP = XC - HL, XC + HL
PX, SADDLE = 1.0, 18.0          # the rider's x, and the (hidden) seat he sits on inside the cockpit
SIDES = ((1, "S"), (-1, "P"))
SEAT_X = (15.8, 18.0, 20.2, 22.4, 24.6, 26.8)


def f(x):
    return math.sqrt(max(0.0, 1 - ((x - XC) / HL) ** 2))


def top_y(x, z=0.0):
    w = RZ * f(x)
    return RT + RY * f(x) * math.sqrt(max(0.0, 1 - (z / w) ** 2)) if w > 0 else RT


def plan(k, poly, y0, y1, cell, bevel=0.1):
    """A plan-view polygon (x, z) extruded up from y0 to y1."""
    k.prism(poly, y0, y1, cell, lambda a, b, d: (a, d, b), bevel)


def section(k, poly, x0, x1, cell, bevel=0.1):
    """A cross-section polygon (z, y) extruded along x."""
    k.prism(poly, x0, x1, cell, lambda a, b, d: (d, b, a), bevel)


def seat_z(x):
    return min(3.2, B * (34.5 - x) / 28.5 - 0.8)


def seat(k, x, z):
    k.box((1.6, 0.4, 1.4), (x, 3.82, z), NAVY, r=0)
    k.box((0.5, 1.3, 1.4), (x - 0.58, 4.62, z), NAVY, r=0)


def puff(k, x, y, z, r):
    """A soft cartoon exhaust: a round cloud, blowing aft. No cone, no point."""
    k.sphere(r, (x, y, z), FLAME_Y, n=12, lat=4)
    k.sphere(r * 0.72, (x - r * 0.72, y + r * 0.42, z + r * 0.42), FLAME_O, n=10, lat=3)
    k.sphere(r * 0.72, (x - r * 0.72, y + r * 0.42, z - r * 0.42), FLAME_O, n=10, lat=3)
    k.sphere(r * 0.66, (x - r * 0.72, y - r * 0.5, z), FLAME_O, n=10, lat=3)


SQUASH = (RY / RZ, 1, 1)        # local x of a lathe along +X is world -Y


def rocket_ring(k, x, w, grow, cell, n=28):
    """A band hugging the egg at x, grow proud of it."""
    x0, x1 = x - w / 2, x + w / 2
    rz = lambda a: RZ * f(a)
    pts = [(rz(x0) - 0.4, 0), (rz(x0) + grow, 0), (rz(x) + grow, w / 2), (rz(x1) + grow, w), (rz(x1) - 0.4, w), (rz(x0) - 0.4, 0)]
    k.lathe(pts, n, cell, (x0, RT, 0), (0, 0, -90), SQUASH)


def on_skin(k, x, z, fn, lift=0.0):
    """Runs fn in a frame whose local +Z is the egg's outward normal at (x, top_y(x, z), z)."""
    e = 0.05
    n = Vector((-(top_y(x + e, z) - top_y(x - e, z)) / (2 * e), 1, -(top_y(x, z + e) - top_y(x, z - e)) / (2 * e))).normalized()
    m = Matrix.Translation(Vector((x, top_y(x, z), z)) + n * lift) @ Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
    k.stack.append(k.stack[-1] @ m)
    fn()
    k.stack.pop()


def porthole(k, x, z, r):
    def body():
        k.torus(r, max(0.3, r * 0.22), (0, 0, 0), NAVY, n=16, m_=5)
        k.cyl(r, 0.5, (0, 0, -0.1), GLASS, (90, 0, 0), n=16)
        k.sphere(r * 0.28, (r * 0.35, r * 0.4, 0.1), WHITE, n=8, lat=3)
    on_skin(k, x, z, body)


def hull(k):
    # ---- a wide knife: five raked courses, each tip further forward than the one below
    plan(k, [(6, -B + 0.5), (21, 0), (6, B - 0.5)], -2.4, -1.2, NAVY, 0.14)
    plan(k, [(6, -B), (24, 0), (6, B)], -1.2, 0, NAVY)
    plan(k, [(6, -B), (27.5, 0), (6, B)], 0, 1.2, RED)
    plan(k, [(6, -B), (31, 0), (6, B)], 1.2, 2.4, WHITE)
    plan(k, [(6, -B), (34.5, 0), (6, B)], 2.4, 3.6, WHITE)
    for x0, x1 in ((-20, -9), (-9, 6)):       # bilge, chamfered
        section(k, [(-B + 1.4, -2.4), (B - 1.4, -2.4), (B, -1.2), (-B, -1.2)], x0, x1, NAVY, 0.14)
    for y, cell, seams in ((-1.2, NAVY, (-20, -4, 6)), (0, RED, (-20, -12, 2, 6)), (1.2, WHITE, (-20, -6, 6))):
        for x0, x1 in zip(seams, seams[1:]):
            k.box((x1 - x0, 1.2, 2 * B), ((x0 + x1) / 2, y + 0.6, 0), cell)
    # ---- deck well: fat studded gunwale walls round tan plates
    for s, tag in SIDES:
        for x0, x1 in ((-20, -8), (-8, 6)):
            k.brick((x1 - x0, 1.2, 1), ((x0 + x1) / 2, 3.0, s * (B - 0.5)), WHITE, studs="big")
        k.box((1, 1.2, B - 1.02), (-19.5, 3.0, s * (B - 1) / 2), WHITE, studs="big")
        k.box((26, 0.28, 0.14), (-7, 2.62, s * (B + 0.03)), NAVY, r=0.05)           # sheer stripe
        k.box((26, 0.55, 0.46), (-7, 3.3, s * (B + 0.17)), RUBBER)                  # rub rail
        d = math.hypot(25, 25 * B / 28.5)
        k.box((d, 0.34, 0.14), (18.5, 3.0, s * (B * 16 / 28.5 + 0.11)), NAVY, (0, math.degrees(math.atan2(B, 28.5)) * s, math.degrees(math.atan2(0.8, d))), r=0.05)
        for x in (-12.5, -6.5, -0.5):
            k.rim_window(x, 1.7, s, 0.62, B + 0.02)
        k.box((3.9, 2.5, 0.12), (-17.2, 1.2, s * (B + 0.02)), NAVY, r=0.04)         # number plate
        k.box((3.4, 2.1, 0.12), (-17.2, 1.2, s * (B + 0.09)), WHITE, r=0.04)
        k.att("NumberPlate_" + tag, (-17.2, 1.2, s * (B + 0.16)))
        k.torus(0.85, 0.32, (3.2, 1.3, s * (B + 0.3)), VEST, n=14, m_=6)            # life ring
        for a in range(4):
            c = math.radians(45 + 90 * a)
            k.box((0.34, 0.74, 0.74), (3.2 + 0.85 * math.cos(c), 1.3 + 0.85 * math.sin(c), s * (B + 0.3)), WHITE, (0, 0, 45 + 90 * a), r=0)
        k.cyl(0.65, 0.14, (-20.05, 3.0, s * 5), RED, (0, 0, 90), n=12)              # tail light
        for x, s2 in ((-19, 8), (-11, 8), (-3, 9)):
            k.box((s2 - 0.04, 0.44, B - 1.02), (x + s2 / 2, 2.6, s * (B - 1) / 2), TAN, r=0.08)
    # foredeck: the red prow spine, and the twelve seats on the open deck ahead of her nose
    top = k.stack[-1]
    plan(k, [(28, -1.3), (38, 0), (28, 1.3)], 3.6, 4.8, RED)
    k.stud(top, (30.5, 4.78, 0), RED, big=True)
    for x in SEAT_X:
        for s, _ in SIDES:
            seat(k, x, s * seat_z(x))
    t = lambda y: 24 + (y + 0.6) / 0.343
    k.prism([(t(-2.4) - 1.2, -2.4), (t(-2.4) + 0.9, -2.4), (t(4.9) + 0.9, 4.9), (t(4.9) - 1.2, 4.9)], -0.28, 0.28, CHROME, lambda a, b, d: (a, b, d), 0.08)
    # ---- stern
    k.brick((1.4, 0.6, 7.2), (-20.7, 0.3, 0), NAVY, studs="big")
    # ---- the ride: one squat round egg sunk in the deck, no cradle, no rails, nothing it could launch from
    sts = sorted({round(XC + HL * math.cos(math.pi * i / 16), 3) for i in range(17)} | {-11.0, -9.4, 5.0, 7.0})
    cell = lambda m: RED if m < -11 else NAVY if m < -9.4 else WHITE if m < 5 else NAVY if m < 7 else RED
    pts = [(RZ * f(x), x - TAIL) for x in sts]
    pts[0] = (0, 0)
    pts[-1] = (0, TIP - TAIL)
    k.lathe(pts, 28, [cell((a + b) / 2) for a, b in zip(sts, sts[1:])], (TAIL, RT, 0), (0, 0, -90), SQUASH)
    # a stubby navy ring on the round tail and a soft puff: no nozzle cone
    k.along(TAIL - 1.0, TAIL + 1.0, 2.7, NAVY, RT, n=20)
    puff(k, TAIL - 1.5, RT, 0, 1.85)
    k.att("Flame_Main", (TAIL - 2.5, RT, 0))
    # chunky rounded fins, low on her sides
    for s, _ in SIDES:
        plan(k, [(-7, s * 6.5), (-14, s * 5.5), (-16.6, s * 7.5), (-16.8, s * 9.4), (-15.6, s * 10.3), (-13.2, s * 10.2), (-9.8, s * 8.9)], RT - 2.4, RT - 0.2, RED, 0.35)
    # the porthole face on her nose, and big windows along her sides
    for s, _ in SIDES:
        porthole(k, 10.0, s * 3.5, 2.0)
        porthole(k, -7.0, s * 7.2, 2.6)
        porthole(k, 2.4, s * 8.0, 2.6)
    smile = []
    for i in range(11):
        a = math.radians(205 + 130 * i / 10)
        sec = []
        for dx, g in ((-0.45, 0.97), (0.45, 0.97), (0.45, 1.05), (-0.45, 1.05)):
            x = 12.0 + dx
            sec.append((x, RT + RY * f(x) * g * math.sin(a), RZ * f(x) * g * math.cos(a)))
        smile.append(sec)
    k.loft(smile, NAVY)
    # ---- the cockpit: a fat rim and a handlebar; the rider's legs are inside her
    k.torus(2.6, 0.5, (PX, top_y(PX) + 0.05, 0), NAVY, (90, 0, 0), n=18, m_=6)
    bar = PX + 2.3
    k.rod((bar, top_y(bar) - 0.3, 0), (bar, 21.9, 0), 0.34, NAVY, n=10)
    k.rod((bar, 21.9, -1.75), (bar, 21.9, 1.75), 0.24, CHROME, n=10)
    for s, _ in SIDES:
        k.rod((bar, 21.9, s * 1.05), (bar, 21.9, s * 1.95), 0.36, RUBBER, n=10)


def hull_marks(k):
    """The Tidewalker's ATT_ set (Boat/Builder buildTidewalkerAsset reads these), in model space. The rider's seat is in the cockpit."""
    def hr(name, x, y, z):      # numbers in HullRoot space
        k.atts["ATT_" + name] = (x - K.ORIGIN[0], y - K.ORIGIN[1], z - K.ORIGIN[2])
    k.att("DriverSeat", (PX, SADDLE + 0.3, 0))
    k.att("EyePoint", (PX + 0.7, SADDLE + 3.95, 0))
    for i, (x, s) in enumerate(((SEAT_X[0], -1), (SEAT_X[0], 1), (SEAT_X[1], -1))):
        k.att("PassengerSeat%d" % (i + 1), (x, 4.1, s * seat_z(x)))
    hr("TowHitch", 0, 0.6, 31.4)
    hr("BowPoint", 0, 0.6, -30)
    hr("DriveAttachment", 0, 0, 0)
    k.att("NavPort", (6.5, 4.1, -B + 0.1))
    k.att("NavStarboard", (6.5, 4.1, B - 0.1))
    k.att("NavMasthead", (PX - 3, top_y(PX - 3) + 0.2, 0))
    k.att("NavStern", (-20.1, 3.8, 0))
    k.att("Beacon", (-5, top_y(-5) + 0.4, 0))
    k.att("Searchlight", (TIP, RT, 0))
    for i, s in enumerate((-1, 1)):
        k.att("Prop%d" % (i + 1), (-20.6, -1.4, s * 3))
    slots = [(x, s) for x in SEAT_X for s in (-1, 1)]
    for i, (x, s) in enumerate(slots):
        k.att("SurvivorSlot%d" % (i + 1), (x, 4.1, s * seat_z(x)))
    for i, s in enumerate((-1, 1)):
        k.att("SurvivorSlot%d" % (13 + i), (13.4, 4.1, s * 5.2))
    for i, (x, z) in enumerate(((-5.5, -20), (5.5, -20), (-6.5, -7), (6.5, -7), (-6.5, 7), (6.5, 7), (-5.5, 20), (5.5, 20))):
        hr("Float%d" % (i + 1), x, -3, z)


def pilot(k):
    def body():
        k.box((1.3, 0.8, 2.0), (0, 0.9, 0), NAVY, r=0.14)                                   # no legs: they are inside the rocket
        for s, _ in SIDES:
            k.rod((0.1, 2.8, 1.22 * s), (1.92, 3.25, 1.25 * s), 0.36, VEST, n=8)            # arms up to the bar
            k.box((0.62, 0.62, 0.62), (1.92, 3.25, 1.25 * s), WHITE, r=0.12)
        k.box((1.3, 1.9, 2.15), (0, 2.25, 0), VEST, r=0.16)                                 # the orange vest is the read
        for y in (2.0, 2.85):
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
    # the side tubes are gone: two beach-ball pods bolted on the aft deck, each with a soft puff. Round from every side
    r = 2.9
    for s, tag in SIDES:
        z = 6.3 * s
        k.brick((4.2, 0.5, 3.6), (-13, 3.85, z), NAVY, studs=[(-1.6, 0.23, 1.25), (-1.6, 0.23, -1.25), (1.6, 0.23, 1.25), (1.6, 0.23, -1.25)], big=True)
        n = 8
        rings = [(r * math.cos(-math.pi / 2 + math.pi * i / n), r * math.sin(-math.pi / 2 + math.pi * i / n)) for i in range(n + 1)]
        rings[0], rings[-1] = (0, -r), (0, r)
        k.lathe(rings, 18, [RED, RED, WHITE, WHITE, RED, RED, WHITE, WHITE], (-13, 6.75, z))
        k.att("Flame_" + tag, (-16.2, 6.75, z))
        puff(k, -15.9, 6.75, z, 1.15)


def gold_plating(k):
    for s, _ in SIDES:
        for x0, x1 in ((-15.6, -9), (-9, -2.5), (-2.5, 4)):                 # one heavy belt on the red band
            k.box((x1 - x0 - 0.06, 0.86, 0.14), ((x0 + x1) / 2, 0.6, s * (B + 0.05)), GOLD, r=0.05)
        for x0, x1 in ((-20, -8), (-8, 6)):                                 # gunwale caps, chunky, studless
            k.box((x1 - x0 - 0.06, 0.7, 1.1), ((x0 + x1) / 2, 3.95, s * (B - 0.5)), GOLD)
        k.box((1.1, 0.7, B - 1.06), (-19.5, 3.95, s * (B - 1) / 2), GOLD)
        g = math.degrees(math.atan2(B, 21.5))                               # a sculpted gold wedge on each bow, on the red band
        d = math.hypot(16, 16 * B / 21.5)
        k.box((d, 0.86, 0.14), (14.0, 0.6, s * (B * 13.5 / 21.5 + 0.1)), GOLD, (0, g * s, 0), r=0.05)
    for x in (-10.2, 6.0):                                                  # gold rings on her two navy bands
        rocket_ring(k, x, 1.1, 0.14, GOLD)
    x0 = 13.2                                                               # a round gold cap on the nose
    prof = [(0, 0), (RZ * f(x0) + 0.16, 0)] + [(RZ * f(x0 + (14.8 - x0) * i / 6) + 0.16, (14.8 - x0) * i / 6) for i in range(1, 7)] + [(0, 1.8)]
    k.lathe(prof, 18, GOLD, (x0, RT, 0), (0, 0, -90), SQUASH)


def wave_wall(k):
    # the hull flaring out: the same navy, red and white courses at the same heights, a continuous waterline, an aqua scoop on top
    n = 9
    for s, tag in SIDES:
        secs, foam = [], []
        for i in range(n + 1):
            t = i / n
            x = 5 - 30 * t
            zo = B + 0.6 + 4.2 * t ** 0.85
            top = 2.9 + 2.6 * t ** 1.5
            peel = max(0.0, (t - 0.8) / 0.2) ** 1.4
            z_in = B - 0.04 + (zo - 1.8 - B) * peel
            mid = 2.7 + (top - 2.7) * 0.4
            z_mid = z_in + (zo - z_in) * 0.6
            pts = [(z_in, -1.0), (zo - 0.2, -1.0), (zo, 0.0), (zo + 0.1, 1.2), (zo + 0.25, top), (zo - 0.7, top), (z_mid, mid), (z_in, 2.5 + (top - 2.5) * 0.5 * peel)]
            secs.append([(x, y, s * a) for a, y in pts])
            cap = 0.7 + 0.6 * t
            fs = [(zo - 1.0, top - 0.2), (zo + 0.5, top - 0.2), (zo + 0.42, top + cap), (zo - 0.85, top + cap)]
            foam.append([(x - 0.07, y, s * a) for a, y in fs])
            if i in (3, 5, 7):
                k.stud(k.stack[-1], (x, top + cap - 0.02, s * (zo - 0.2)), WHITE, big=True)
        k.loft(secs, [NAVY, NAVY, RED, WHITE, WHITE, AQUA, AQUA, NAVY])
        k.loft(foam, WHITE)
        k.att("Crest_" + tag, (-25, 7, s * (B + 4.8)))


def gold_eagle(k):
    # small, a hood ornament on the very tip of the prow, under the nose line
    k.brick((2.4, 0.4, 1.3), (36.8, 4.98, 0), NAVY, studs=[(-0.6, 0.18, 0)], big=True)
    k.box((1.4, 0.7, 0.8), (37.0, 4.55, 0), NAVY, r=0.1)

    def bird():
        k.cyl(0.95, 0.7, (0, 0.2, 0), NAVY, r2=0.75, n=12)
        k.box((1.5, 2.0, 1.4), (-0.05, 1.5, 0), GOLD, (0, 0, -12), r=0.3)
        k.sphere(0.85, (0.42, 1.65, 0), GOLD, n=12, lat=4)
        k.cyl(0.46, 1.0, (0.55, 2.7, 0), GOLD, (0, 0, -25), n=10)
        k.sphere(0.72, (0.85, 3.3, 0), GOLD, n=12, lat=4)
        k.cone(0.34, 1.0, (1.75, 3.2, 0), VEST, (0, 0, -100), tip=0.1, n=8)
        for s, _ in SIDES:
            k.sphere(0.15, (1.3, 3.5, 0.36 * s), NAVY, n=8, lat=3)

            def wing(s=s):
                for i, ln in enumerate((4.6, 3.3)):                         # two fat feathers
                    k.box((1.7, 0.55, ln), (-1.3 * i, 0.12 * i, s * ln / 2), GOLD, r=0.16)
            k.at((-0.1, 2.5, 0.6 * s), (-30 * s, -14 * s, 0), wing)
    k.scaled((37.2, 5.2, 0), 0.72, bird)


def rocket_fins(k):
    # one chunky rounded dorsal fin, edge-on from behind so it never hides the rider
    poly = [(-5.5, 17.5), (-8.0, 20.0), (-10.5, 21.4), (-13.5, 21.6), (-15.4, 20.6), (-15.0, 18.6), (-13.5, 16.0)]
    k.prism(poly, -1.1, 1.1, RED, lambda a, b, d: (a, b, d), 0.3)
    on_skin(k, -9.5, 0, lambda: k.box((8.0, 3.2, 0.6), (0, 0, 0.1), NAVY, r=0.14))     # a bolted foot on her skin


def gold_throne(k):
    # an accent: a gold collar on the cockpit and a low back, nothing above the rider's chin
    k.torus(3.0, 0.42, (PX, top_y(PX) + 0.2, 0), GOLD, (90, 0, 0), n=20, m_=6)
    k.box((0.8, 2.3, 3.4), (PX - 2.05, top_y(PX) + 1.05, 0), GOLD, r=0.16)
    k.box((0.14, 1.5, 2.4), (PX - 1.6, top_y(PX) + 1.1, 0), RED, r=0.04)
    k.box((0.14, 1.5, 2.4), (PX - 2.5, top_y(PX) + 1.1, 0), NAVY, r=0.04)   # a navy break from behind
    for z, h in ((-1.15, 0.6), (0, 0.9), (1.15, 0.6)):
        k.cone(0.42, h, (PX - 2.05, top_y(PX) + 2.2 + h / 2, z), GOLD, tip=0.1, n=8)


def _popper(k, s, tag):
    k.cyl(1.5, 0.7, (0, 0.15, 0), GOLD, n=14)
    for i, c in enumerate((WHITE, RED, WHITE, RED)):                        # a short striped paper cone, flaring wide: party, not barrel
        r0, r1 = 0.9 + 3.3 * (i / 4) ** 1.5, 0.9 + 3.3 * ((i + 1) / 4) ** 1.5
        k.lathe([(0, 0), (r0, 0), (r1, 1.1), (0, 1.1)], 20, c, (0, 0.4 + 1.1 * i, 0))
    k.lathe([(3.4, 0), (4.55, 0), (4.55, 0.4), (3.4, 0.4), (3.4, 0)], 20, WHITE, (0, 4.8, 0))
    k.cyl(3.5, 0.2, (0, 4.85, 0), NAVY, n=20)                               # the dark open mouth
    k.att("Confetti_" + tag, (0, 5.6, 0))
    # a burst packed in the centre of the mouth, so the dark mouth and rim stay readable: three puffs, three big squares, one fat streamer
    for a, r, cell in ((0, 1.25, GOLD), (120, 1.15, RED), (240, 1.2, WHITE)):
        k.sphere(r, (1.05 * math.cos(math.radians(a)), 5.45, 1.05 * math.sin(math.radians(a))), cell, n=10, lat=3)
    for i, (x, y, z, c) in enumerate(((0.2, 7.3, 0.2, SEAT), (1.5, 6.9, -0.9, RED), (-1.4, 7.0, 0.9, GOLD))):
        k.box((1.5, 0.45, 1.5), (x, y, z), c, (20 + 37 * i, 40 * i, 15 + 29 * i), r=0.08)
    pts = []
    for j in range(8):
        t = j / 7
        r = 1.6 + 5.0 * t
        pts.append((r * math.cos(0.5 * s + 0.3 * math.sin(t * 4.0)), 5.5 + 1.6 * math.sin(t * math.pi * 0.8) - 2.2 * t, s * r * math.sin(1.1 + 0.3 * math.sin(t * 4.0))))
    w, h = 0.8, 0.26
    k.loft([[(x - w, y - h, z - w), (x + w, y - h, z - w), (x + w, y + h, z + w), (x - w, y + h, z + w)] for x, y, z in pts], SEAT)


def party_cannons(k):
    for s, tag in SIDES:
        x, z = 3.0, 8.0 * s
        k.brick((3.4, 0.5, 2.0), (x, 3.85, z), NAVY)                        # a bracket on the deck edge, amidships: well clear of the stern
        k.scaled((x, 4.05, z), 1.1, lambda s=s, tag=tag: _popper(k, s, tag), (50 * s, 0, 0))    # mouths up and out over the side


def mega_trophy(k):
    # an accent: a small cup on the prow in front of her nose, below the nose line, on a studded plate
    x = 33.4
    k.brick((2.6, 0.45, 1.8), (x, 5.0, 0), NAVY, studs=[(-0.8, 0.2, 0.0)], big=True)
    k.box((1.5, 0.7, 1.0), (x, 4.5, 0), NAVY, r=0.1)
    i = 0.58
    prof = [(0, 0), (1, 0), (1, 0.25), (0.5, 0.45), (0.42, 1.1), (0.78, 1.35), (0.78, 1.6), (0.42, 1.85), (0.5, 2.3), (1.3, 2.5), (2.0, 3.0), (2.4, 3.8),
            (2.55, 4.8), (2.6, 5.6), (2.72, 5.82), (2.52, 5.88), (2.3, 5.0), (2.1, 4.1), (1.5, 3.3), (0, 3.1)]
    k.lathe([(r * i, y * i) for r, y in prof], 18, GOLD, (x, 5.2, 0))
    for s, _ in SIDES:
        k.torus(0.72, 0.28, (x, 5.2 + 4.55 * i, s * 2.0), GOLD, n=10, m_=5)
    k.att("Gleam", (x, 5.2 + 5.9 * i, 0))


def sun_booster(k):
    # L50's stern: one big plain round sun face right across her, no spikes, no flame cone, nothing round it
    fx = -20.75
    k.along(-20.3, TAIL + 0.2, 3.1, NAVY, RT, n=20)                         # a short hub, hiding the puff
    k.along(fx - 0.4, fx + 0.4, 9.2, SUN, RT, n=36)
    k.ring(fx - 0.3, 0.6, 9.1, 9.8, FLAME_O, RT, 0, n=36)
    f0 = fx - 0.4
    for s, _ in SIDES:
        k.cyl(1.9, 0.3, (f0 - 0.05, RT + 3.1, s * 3.5), NAVY, (0, 0, 90), n=18)
        k.cyl(0.6, 0.14, (f0 - 0.24, RT + 3.7, s * 3.0), WHITE, (0, 0, 90), n=12)
        k.cyl(1.4, 0.2, (f0 - 0.02, RT - 1.0, s * 6.2), RED, (0, 0, 90), n=16)
    arc = [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))) for r, seq in ((7.1, range(205, 340, 15)), (5.3, range(325, 190, -15))) for a in seq]
    k.prism(arc, f0 - 0.2, f0 + 0.08, NAVY, lambda a, b, d: (d, RT + b, a), 0)
    k.att("Flame_Sun", (f0 - 1.0, RT, 0))
    for s, _ in SIDES:
        seat(k, 13.4, s * 5.2)


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
