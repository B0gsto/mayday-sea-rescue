"""The Lifeboat stage's nine upgrade pieces (L22-L30), ported from the owner-cleared concept (artifact cdf29056, PIECES).

Coordinates are the concept's and the hull's (Builder.luau buildLifeboat). Fitted to the real waterline: the game floats her
with the water at about hull y +1.5 (float points y -3, draft 4.5), the concept drew the sea at y 0, so the spikes and the plough
ride higher here than on the board or they would sit under water from L22 to L27 (see RESULT.md).
"""
import math

import kit as K
from kit import AMBER, BEACON, CHROME, DARK, DECK, GLASS, GREEN, GREY, LENS, NAVY, ORANGE, RED, RUBBER, STEEL, WHITE, YELLOW, hull_x, hull_y


def lamp(k, pre, pos, r, n=20):
    """Base with border studs, yoke, yellow housing, chrome reflector and bezel, warm lens."""
    def body():
        w, hy, ln = 2 * r + 1.3, 0.55 + r + 0.3, 1.6 * r
        zf, yh = -ln / 2, 0.55 + r + 0.3 + 0.25 - 0.55
        k.brick((w, 0.55, 3.0), (0, 0.275, 0), DARK, studs="border")
        for s in (-1, 1):
            k.box((0.6, yh, 1.3), (s * (r + 0.45), 0.55 + yh / 2, 0), DARK)
            k.cyl(0.48, 0.36, (s * (r + 0.85), hy, 0), CHROME, (0, 0, 90), n=10)
        k.cyl(r, ln, (0, hy, 0), YELLOW, (90, 0, 0), n=n)
        k.sphere(r * 0.94, (0, hy, ln / 2), YELLOW, (1, 1, 0.5), n=n, lat=4)
        for f in (0.05, 0.28):
            k.torus(r + 0.03, 0.13, (0, hy, f * ln), DARK, n=n, m_=4)
        k.cyl(r * 0.9, 0.3, (0, hy, zf - 0.1), CHROME, (90, 0, 0), n=n)
        k.sphere(r * 0.82, (0, hy, zf - 0.22), LENS, (1, 1, 0.3), n=n, lat=4)
        k.torus(r * 0.98, r * 0.24, (0, hy, zf - 0.25), CHROME, n=n, m_=6)
        k.att("Lens_" + pre, (0, hy, zf - 0.5))
    k.at(pos, None, body)


def rocket(k, pre, pos, r, ln, rot=None):
    """Booster can: stubby candy-striped tube, domed cap, fat nozzle, a rounded three-band plume. A thruster, nothing pointy."""
    def body():
        k.cyl(r, ln, (0, 0, 0), RED, (90, 0, 0), n=18)
        for i in range(4):
            k.cyl(r + 0.05, ln / 9, (0, 0, -ln / 2 + ln / 9 * (2 * i + 1.5)), WHITE, (90, 0, 0), n=18)
        for z in (-ln / 2, ln / 2):
            k.torus(r + 0.02, 0.16, (0, 0, z), DARK, n=18, m_=4)
        k.sphere(r * 0.98, (0, 0, -ln / 2), YELLOW, (1, 1, 0.72), n=18, lat=4)
        k.sphere(r * 0.26, (0, 0, -ln / 2 - r * 0.7), WHITE, n=8, lat=3)
        for a in (0, 120, 240):
            k.at((0, 0, 0), (0, 0, a), lambda: k.box((0.42, r * 0.8, ln * 0.34), (0, r * 1.32, ln / 2 - ln * 0.17), NAVY, r=0.18))
        k.cyl(r * 0.78, r * 0.7, (0, 0, ln / 2 + r * 0.35), DARK, (90, 0, 0), r2=r, n=18)
        k.torus(r, 0.18, (0, 0, ln / 2 + r * 0.7), ORANGE, n=18, m_=4)
        fz, fl = ln / 2 + r * 0.7, r * 2.3
        tongue = lambda x, y, w, ln_, c: k.at((x, y, fz + ln_ / 2 - 0.1), (90, 0, 0), lambda: k.sphere(w, (0, 0, 0), c, (1, ln_ / 2 / w, 1), n=8, lat=3))
        for i in range(6):                      # three layers of rounded tongues, so it reads as fire and never as a warhead
            a = math.radians(30 + i * 60)
            tongue(r * 0.5 * math.cos(a), r * 0.5 * math.sin(a), r * 0.33, fl * (1.0 if i % 2 else 0.72), AMBER)
        for i in range(3):
            a = math.radians(i * 120)
            tongue(r * 0.24 * math.cos(a), r * 0.24 * math.sin(a), r * 0.3, fl * 0.84, YELLOW)
        tongue(0, 0, r * 0.3, fl * 0.5, LENS)
        k.att("Flame_" + pre, (0, 0, fz + 0.2))
    k.at(pos, rot, body)


# ---------------------------------------------------------------- L22
SPIKE_Y, SPIKE_TILT = 1.3, 16   # concept: y 0.2, flat, r 1.55; the game's water is at +1.5, the orange band starts at 2.55


def armour_spikes(k):
    def spike(z, yaw, sx):
        def body():
            k.lathe([(0, 0), (1.18, 0), (1.3, 0.12), (1.3, 0.88), (1.18, 1.0), (0, 1.0)], 16, DARK, (0, 0, 0), None, (1, 1, 1.6))
            m = k._m((0, 0, 0), None)
            for dz in (-1.72, 1.72):
                k.stud(m, (0, 0.72, dz), DARK)
            k.torus(1.12, 0.22, (0, 1.06, 0), WHITE, (90, 0, 0), n=16, m_=5)
            k.cone(1.25, 5.2, (0, 3.6, 0), RUBBER, tip=0.55, n=16)
        k.at((sx * hull_x(z, SPIKE_Y), SPIKE_Y, z), (0, yaw, -sx * (90 - SPIKE_TILT)), body)
    for sx in (-1, 1):
        spike(-7, 0, sx)
        spike(8, 0, sx)
        spike(-16, sx * 37, sx)
        spike(23, -sx * 37, sx)


# ---------------------------------------------------------------- L23
def huge_lamps(k):
    for sx, s in ((-1, "P"), (1, "S")):
        lamp(k, s, (sx * 4.7, 8.675, -13.9), 1.9)


# ---------------------------------------------------------------- L24
PLOUGH_UP = 2.4                 # concept y minus this would sit under the game's water line


def ice_plough(k):
    ln, yaw = math.hypot(7.2, 10), math.degrees(math.atan2(7.2, 10))
    ang = math.degrees(math.atan2(0.95, 3.25))

    def body():
        for sx in (-1, 1):
            def blade():
                sec = [(sx * x, y) for x, y in ((-0.5, -3.3), (1.0, -3.3), (1.2, -2.95), (0.25, 0.3), (-0.5, 0.3))]
                k.prism(sec, -(ln + 0.2) / 2, (ln + 0.2) / 2, ORANGE, lambda a, b, d: (a, b, d), bevel=0.18)
                k.brick((1.0, 0.45, ln + 0.3), (sx * -0.15, 0.55, 0), NAVY)
                k.box((0.22, 0.55, ln - 0.2), (sx * 1.14, -2.6, 0), NAVY, (0, 0, sx * ang), r=0.08)
            k.at((sx * 3.6, 0, -26), (0, sx * yaw, 0), blade)
            for z in (-21.8, -24.4):
                bx = 7.2 * (31 + z) / 10 - 0.55
                hx = max(0.3, hull_x(z, -1 + PLOUGH_UP) - 0.3)   # rib ends inside the hull skin
                wd = max(0.8, bx - hx)
                k.brick((wd, 2.0, 0.8), (sx * (hx + bx) / 2, -1.0, z), NAVY)
        k.cyl(0.95, 3.8, (0, -1.4, -31.1), ORANGE, n=16)
        k.sphere(1.0, (0, 0.5, -31.1), NAVY, n=16, lat=5)
    k.at((0, PLOUGH_UP, 0), None, body)


# ---------------------------------------------------------------- L25
def roof_rockets(k):
    for sx, s in ((-1, "P"), (1, "S")):
        x = sx * 8.7
        for z in (-7.7, -5.4):
            k.brick((3.6, 0.8, 1.6), (sx * 7.6, 9.075, z), WHITE)
            k.rod((sx * 6.45, 5.0, z), (sx * 9.0, 8.7, z), 0.16, DARK)
            k.cyl(1.43, 0.45, (x, 10.83, z), DARK, (90, 0, 0), n=18)
        rocket(k, s, (x, 10.83, -6.6), 1.35, 4.6)


# ---------------------------------------------------------------- L26
def crew_deck(k):
    k.brick((14, 0.5, 12.5), (0, 9.15, 9.25), DECK, studs="border")
    k.box((11.6, 0.12, 10.1), (0, 9.44, 9.25), WHITE, r=0.04)
    for sx in (-1, 1):
        for z in (8.5, 14.2):
            k.brick((1.8, 0.4, 1.8), (sx * 4.4, 3.13, z), DARK)
            k.cyl(0.7, 5.6, (sx * 4.4, 6.13, z), ORANGE, n=14)
    for sx in (-1, 1):
        for z in (3.3, 9.3, 15.2):
            k.brick((0.7, 2.0, 0.7), (sx * 6.6, 10.4, z), WHITE)
        k.box((0.55, 0.5, 12.6), (sx * 6.6, 11.55, 9.25), ORANGE)
    for x in (1.4, 3.4):
        k.brick((0.7, 2.0, 0.7), (x, 10.4, 15.2), WHITE)
    k.box((8.5, 0.5, 0.55), (-2.6, 11.55, 15.2), ORANGE)
    k.box((3.75, 0.5, 0.55), (5.0, 11.55, 15.2), ORANGE)
    for s in (-1, 1):                           # ladder
        k.box((0.3, 6.7, 0.3), (2.4 + s * 0.6, 6.3, 15.85), GREY)
    y = 3.7
    while y < 9.5:
        k.cyl(0.1, 1.2, (2.4, y, 15.85), STEEL, (0, 0, 90), n=6)
        y += 0.9
    for sx in (-1, 1):                          # life raft canisters
        k.box((2.6, 0.3, 1.2), (sx * 4.6, 9.65, 13.4), DARK)
        k.capsule(0.75, 1.6, (sx * 4.6, 10.55, 13.4), WHITE, (0, 0, 90))
        for d in (-0.6, 0.6):
            k.cyl(0.78, 0.3, (sx * 4.6 + d, 10.55, 13.4), ORANGE, (0, 0, 90), n=12)


# ---------------------------------------------------------------- L27
def tower_lamp(k, x, y, z, d, r, name):
    k.cyl(r, 1.0, (x, y, z), DARK, (90, 0, 0), n=14)
    k.torus(r * 0.98, r * 0.22, (x, y, z + d * 0.5), CHROME, n=14, m_=5)
    k.cyl(r * 0.84, 0.14, (x, y, z + d * 0.52), LENS, (90, 0, 0), n=14)
    k.att("Lens_" + name, (x, y, z + d * 0.7))


def lamp_tower(k):
    z0, c = 6.2, 1.3
    k.brick((4.0, 0.5, 4.0), (0, 9.75, z0), NAVY, studs="border")
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.box((0.9, 13.2, 0.9), (sx * c, 16.6, z0 + sz * c), WHITE)
    for y in (12.6, 19.0):
        for s in (-1, 1):
            k.box((3.5, 0.6, 0.6), (0, y, z0 + s * c), ORANGE)
            k.box((0.6, 0.6, 3.5), (s * c, y, z0), ORANGE)
    k.brick((5.2, 0.5, 5.2), (0, 14.93, z0), NAVY, studs="border")
    k.brick((5.0, 0.6, 5.0), (0, 23.5, z0), NAVY, studs="border")
    k.box((4.8, 3.6, 0.8), (0, 25.6, z0 + 1.8), WHITE)
    for i, x in enumerate((-1.2, 1.2)):
        for j, y in enumerate((24.8, 26.4)):
            tower_lamp(k, x, y, z0 + 0.9, -1, 0.85, "Fwd%d%d" % (i, j))
        tower_lamp(k, x, 25.6, z0 + 2.7, 1, 0.85, "Aft%d" % i)
    k.cyl(0.55, 0.35, (0, 27.57, z0 + 1.8), DARK, n=14)
    k.cyl(0.5, 0.8, (0, 28.1, z0 + 1.8), AMBER, n=14)
    k.sphere(0.3, (0, 28.55, z0 + 1.8), DARK, n=10, lat=4)
    k.att("Beacon", (0, 28.1, z0 + 1.8))


# ---------------------------------------------------------------- L28
def poly_studs(poly, y, inset):
    def inside(x, z):
        c = False
        j = len(poly) - 1
        for i in range(len(poly)):
            xi, zi = poly[i]
            xj, zj = poly[j]
            if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
                c = not c
            j = i
        return c
    xs, zs = [p[0] for p in poly], [p[1] for p in poly]
    out = []
    x = math.ceil(min(xs)) + 0.5
    while x < max(xs):
        z = math.floor(min(zs)) + 0.5
        while z < max(zs):
            if all(inside(x + a, z + b) for a, b in ((0, 0), (inset, 0), (-inset, 0), (0, inset), (0, -inset))):
                out.append((x, y, z))
            z += 1
        x += 1
    return out


def foil_lift(k):
    wy0, wy1 = -7.25, -6.45
    for z0, xs, half, c0, le, te in ((-9, (-5, 5), 11, 2.4, 1.0, 3.0), (17, (0,), 8.5, 2.0, 0.8, 2.6)):
        plan = [(-half, z0 + le), (0, z0 - c0), (half, z0 + le), (half, z0 + te), (0, z0 + c0), (-half, z0 + te)]
        k.prism(plan, wy0, wy1, NAVY, lambda a, b, d: (a, d, b), bevel=0.25)
        m = k._m(None, None)
        for p in poly_studs(plan, wy1 - 0.02, 0.7):
            if abs(p[0]) < half - 1.6:
                k.stud(m, p, NAVY)
        for sx in (-1, 1):
            k.brick((1.8, 1.0, te - le + 0.9), (sx * (half - 0.6), (wy0 + wy1) / 2, z0 + (le + te) / 2), YELLOW, r=0.35, studs=None)
        for x in xs:
            top = hull_y(abs(x), z0) if x else -3.45
            bot, w = wy1 + 0.2, 1.9 if x else 2.6
            h = top - bot
            k.capsule(1.15, 2.8, (x, top - 0.25, z0), NAVY, (90, 0, 0))
            k.box((w, h, 3.4), (x, (top + bot) / 2, z0 + 0.3), ORANGE, r=0.7)
            k.box((w + 0.1, 0.6, 3.5), (x, bot + h * 0.55, z0 + 0.3), WHITE, r=0.3)
            k.sphere(w * 0.6, (x, (wy0 + wy1) / 2, z0 + 0.3), ORANGE, (1, 0.4, 1.6), n=12, lat=4)


# ---------------------------------------------------------------- L29
def rear_rockets(k):
    for sx, s in ((-1, "P"), (1, "S")):
        x = sx * 5.6
        for z in (19.0, 22.2):
            k.brick((2.2, 1.2, 2.0), (x, 3.55, z), ORANGE)
            k.cyl(1.88, 0.5, (x, 5.95, z), DARK, (90, 0, 0), n=18)
        rocket(k, s, (x, 5.95, 20.6), 1.8, 5.2, (0, sx * 10, 0))


# ---------------------------------------------------------------- L30
def battle_bridge(k):
    z, top = -6, 15.175
    k.brick((8.4, 1.0, 10.4), (0, 9.175, z), NAVY, studs="border")
    k.box((8.0, 1.6, 10.0), (0, 10.475, z), ORANGE)
    k.box((7.7, 2.8, 9.7), (0, 12.675, z), GLASS, r=0.04)
    k.box((8.3, 0.25, 10.3), (0, 11.3, z), WHITE)
    k.box((8.2, 0.6, 10.2), (0, 14.375, z), WHITE)
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.box((0.45, 2.8, 0.45), (sx * 3.85, 12.675, z + sz * 4.85), WHITE, r=0)
    for x in (-1.3, 1.3):
        k.box((0.3, 2.8, 0.3), (x, 12.675, z - 4.9), WHITE, r=0)
    for sx in (-1, 1):
        for dz in (-1.8, 1.6):
            k.box((0.3, 2.8, 0.3), (sx * 3.9, 12.675, z + dz), WHITE, r=0)
        k.box((0.16, 2.6, 1.4), (sx * 3.92, 12.6, -8.5), WHITE, r=0)
    k.brick((6.4, 1.0, 1.2), (0, 11.8, z - 4.1), DARK, stud_cell=[RED, YELLOW, GREEN, BEACON])
    k.brick((9.4, 0.5, 11.6), (0, 14.925, z), WHITE, studs="border")
    k.box((8.6, 0.25, 1.0), (0, 14.55, z - 5.6), WHITE)
    for sx, s in ((-1, "P"), (1, "S")):
        k.brick((3.2, 0.4, 4.2), (sx * 5.6, 12.8, -8.5), DECK, studs="border")
        for dz in (-1.85, 1.85):
            k.brick((0.6, 1.3, 0.6), (sx * 6.95, 13.65, -8.5 + dz), WHITE)
            k.box((3.0, 0.45, 0.5), (sx * 5.45, 14.4, -8.5 + dz), ORANGE)
        k.box((0.5, 0.45, 4.3), (sx * 6.95, 14.4, -8.5), ORANGE)
        k.rod((sx * 4.0, 11.4, -8.5), (sx * 6.6, 12.6, -8.5), 0.14, DARK)
        lamp(k, "Search" + s, (sx * 2.95, top, -9.9), 0.85, n=10)
    for sx in (-1, 1):                          # twin horns
        k.box((0.6, 0.7, 0.6), (sx * 0.8, top + 0.35, -9.6), DARK)
        k.cyl(0.6, 2.4, (sx * 0.8, 16.05, -9.6), YELLOW, (90, 0, 0), r2=0.22, n=12)
        k.cyl(0.46, 0.06, (sx * 0.8, 16.05, -10.82), DARK, (90, 0, 0), n=12)
    for sx in (-1, 1):                          # flags
        k.cyl(0.14, 6.0, (sx * 3.9, top + 3.0, -1.6), WHITE, n=8)
        k.sphere(0.26, (sx * 3.9, top + 6.1, -1.6), YELLOW, n=8, lat=3)
    fy = top + 5.0
    k.flag(-3.9, fy, -1.6, 3.4, 2.2, ORANGE, half=1)
    k.flag(-3.9, fy, -1.6, 3.4, 2.2, WHITE, half=-1)
    k.flag(3.9, fy, -1.6, 3.8, 1.8, YELLOW, tri=True)
    k.brick((3.2, 0.4, 4.8), (0, 14.93, 2.0), NAVY, studs="border")   # top 0.05 under the tower landing it meets
    for sx in (-1, 1):
        k.cyl(0.42, 6.2, (sx * 1.1, 11.78, 1.9), ORANGE, n=12)
    ry, done = top + 1.15, set()

    def post(x, zz):
        if (x, zz) not in done:
            done.add((x, zz))
            k.brick((0.6, 1.06, 0.6), (x, top + 0.45, zz), WHITE)

    def rail(a, b):
        ln = math.hypot(b[0] - a[0], b[1] - a[1])
        size = (ln + 0.55, 0.45, 0.55) if a[1] == b[1] else (0.55, 0.45, ln + 0.55)
        k.box(size, ((a[0] + b[0]) / 2, ry, (a[1] + b[1]) / 2), ORANGE)
        post(*a)
        post(*b)
    for sx in (-1, 1):
        p = [(sx * 4.4, -8.2), (sx * 4.4, -0.6), (sx * 1.6, -0.6), (sx * 1.6, 3.7), (sx * 2.6, 3.7), (sx * 2.6, 8.7)]
        for a, b in zip(p, p[1:]):
            rail(a, b)
    rail((-2.6, 8.7), (2.6, 8.7))


PIECES = {  # short name -> (level, fn)
    "ArmourSpikes": (22, armour_spikes), "HugeLamps": (23, huge_lamps), "IcePlough": (24, ice_plough),
    "RoofRockets": (25, roof_rockets), "CrewDeck": (26, crew_deck), "LampTower": (27, lamp_tower),
    "FoilLift": (28, foil_lift), "RearRockets": (29, rear_rockets), "BattleBridge": (30, battle_bridge),
}


def asset(short):
    return "M_Upg_Lifeboat_" + short


def make(short, name=None):
    """Builds one piece's LOD0 object (hull frame origin) and its ATT_ empties. Returns (object, attachments)."""
    import bpy
    k = K.Kit()
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
        "name": asset(short), "budget": "large_prop", "tier": "standard",
        "dims_m": tuple(round(d / 3, 3) for d in obj.dimensions), "origin": "free", "tiling": True,
        "sets": [{"name": K.SET_NAME, "set": K.SET, "size": 256, "wet": False, "dir": K.TEX_DIR}],
        "meshes": [{"object": obj, "set": K.SET}], "attachments": atts,
        "waivers": {
            "_COL proxy": "bolt-on look only: CanCollide off, the hull's code box is the collision",
            "LOD UV layout": "flat palette cells, not a unique unwrap (like the other toy-brick assets)",
            "texture sets": "one flat palette set shared by all nine pieces",
            "UV faces": "decimated LOD faces collapse their small UV ring inside a palette cell: the colour stays the cell's",
        },
    }
