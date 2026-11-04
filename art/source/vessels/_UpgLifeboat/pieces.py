"""The Lifeboat stage's nine upgrade pieces (L22-L30), ported from the owner-cleared concept (artifact cdf29056, PIECES).

Coordinates are the concept's and the hull's (Builder.luau buildLifeboat). Fitted to the real waterline: the game floats her
with the water at about hull y +1.5 (float points y -3, draft 4.5), the concept drew the sea at y 0. Round 2 (art director 6.5/10) pushed
sizes, walls, skis and colours past the concept on purpose: see RESULT.md.
"""
import math

import kit as K
from kit import AMBER, BEACON, CHROME, DARK, DECK, GLASS, GREEN, GREY, LENS, NAVY, ORANGE, RED, RUBBER, STEEL, WHITE, YELLOW, hull_x, hull_y


def lamp(k, pre, pos, r, n=20):
    """Base with border studs, yoke, signature yellow housing, chrome reflector and bezel, warm lens."""
    def body():
        w, hy, ln = 2 * r + 1.3, 0.55 + r + 0.3, 1.6 * r
        zf, yh = -ln / 2, 0.55 + r + 0.3 + 0.25 - 0.55
        yt, yd = max(0.6, r * 0.3), max(1.3, r * 0.6)
        k.brick((w, 0.55, max(3.0, r * 1.3)), (0, 0.275, 0), DARK, studs="border")
        for s in (-1, 1):
            k.box((yt, yh, yd), (s * (r + yt * 0.75), 0.55 + yh / 2, 0), YELLOW)
            k.cyl(max(0.48, r * 0.26), max(0.36, r * 0.2), (s * (r + yt * 1.4), hy, 0), CHROME, (0, 0, 90), n=10)
        k.cyl(r, ln, (0, hy, 0), YELLOW, (90, 0, 0), n=n)
        k.sphere(r * 0.94, (0, hy, ln / 2), YELLOW, (1, 1, 0.5), n=n, lat=4)
        for f in (0.05, 0.28):
            k.torus(r + 0.03, max(0.13, r * 0.08), (0, hy, f * ln), DARK, n=n, m_=4)
        k.cyl(r * 0.9, 0.3, (0, hy, zf - 0.1), CHROME, (90, 0, 0), n=n)
        k.sphere(r * 0.82, (0, hy, zf - 0.22), LENS, (1, 1, 0.3), n=n, lat=4)
        k.torus(r * 0.98, r * 0.24, (0, hy, zf - 0.25), CHROME, n=n, m_=6)
        k.att("Lens_" + pre, (0, hy, zf - 0.5))
    k.at(pos, None, body)


def wall(k, x0, x1, z0, z1, y0, low=ORANGE, cap=WHITE, h0=0.95, h1=0.75):
    """A chunky parapet instead of a rail: two brick courses, big studs every 2 on top."""
    sx, sz, cx, cz = x1 - x0, z1 - z0, (x0 + x1) / 2, (z0 + z1) / 2
    k.box((sx, h0 + 0.05, sz), (cx, y0 + h0 / 2 - 0.025, cz), low)
    long_x = sx > sz
    n = max(1, int((sx if long_x else sz) / 2))
    step = (sx if long_x else sz) / n
    spots = [((-sx / 2 + (i + 0.5) * step) if long_x else 0, h1 / 2 - 0.02, 0 if long_x else (-sz / 2 + (i + 0.5) * step)) for i in range(n)]
    k.brick((sx + 0.1, h1, sz + 0.1), (cx, y0 + h0 + h1 / 2, cz), cap, studs=spots)


def rocket(k, pre, pos, r, ln, rot=None, n=18):
    """Firework can in the rockets' one colour: stubby red tube, two white bands, white dome, fat nozzle, a rounded three-layer plume."""
    def body():
        k.cyl(r, ln, (0, 0, 0), RED, (90, 0, 0), n=n)
        for f in (0.2, 0.62):
            k.cyl(r + 0.06, ln * 0.16, (0, 0, -ln / 2 + ln * f), WHITE, (90, 0, 0), n=n)
        for z in (-ln / 2, ln / 2):
            k.torus(r + 0.02, max(0.16, r * 0.09), (0, 0, z), DARK, n=n, m_=4)
        k.sphere(r * 0.98, (0, 0, -ln / 2), WHITE, (1, 1, 0.72), n=n, lat=4)
        k.sphere(r * 0.26, (0, 0, -ln / 2 - r * 0.7), RED, n=8, lat=3)
        for a in (0, 120, 240):
            k.at((0, 0, 0), (0, 0, a), lambda: k.box((max(0.42, r * 0.28), r * 0.8, ln * 0.34), (0, r * 1.32, ln / 2 - ln * 0.17), RED, r=0.18))
        k.cyl(r * 0.78, r * 0.7, (0, 0, ln / 2 + r * 0.35), DARK, (90, 0, 0), r2=r, n=n)
        k.torus(r, max(0.18, r * 0.1), (0, 0, ln / 2 + r * 0.7), WHITE, n=n, m_=4)
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
SPIKE_Y, SPIKE_TILT = 0.6, 20   # AD r1: white and much bigger; low root and a steep tilt keep the band clear and the tip out of the water (+1.5)


def armour_spikes(k):
    def spike(z, yaw, sx):
        def body():
            k.lathe([(0, 0), (2.3, 0), (2.5, 0.15), (2.5, 0.95), (2.3, 1.1), (0, 1.1)], 16, DARK, (0, 0, 0), None, (1, 1, 1.35))
            m = k._m((0, 0, 0), None)
            for dz in (-2.6, 2.6):
                k.stud(m, (0, 0.82, dz), DARK)
            k.torus(2.05, 0.34, (0, 1.2, 0), ORANGE, (90, 0, 0), n=16, m_=5)
            k.cone(2.2, 9.0, (0, 5.6, 0), WHITE, tip=0.95, n=16)
        k.at((sx * hull_x(z, SPIKE_Y), SPIKE_Y, z), (0, yaw, -sx * (90 - SPIKE_TILT)), body)
    for sx in (-1, 1):
        spike(-7, 0, sx)
        spike(8, 0, sx)
        spike(-16, sx * 37, sx)
        spike(23, -sx * 37, sx)


# ---------------------------------------------------------------- L23
def huge_lamps(k):
    for sx, s in ((-1, "P"), (1, "S")):         # AD r1: twice the concept's r 1.9
        lamp(k, s, (sx * 5.6, 8.675, -15.0), 3.8, n=24)


# ---------------------------------------------------------------- L24
PLOUGH_N = 5


def ice_plough(k):
    """AD r1: a stepped wedge. It climbs block by block to the nose (a stair from the side) and each block carries chunky white
    saw teeth (a saw from above). The top rows stay above the game's water (+1.5)."""
    ln, yaw = math.hypot(7.2, 10), math.degrees(math.atan2(7.2, 10))
    seg, bot = ln / PLOUGH_N, -2.4
    for sx in (-1, 1):
        def blade():
            for i in range(PLOUGH_N):
                zc, top = -ln / 2 + (i + 0.5) * seg, 6.0 - 0.85 * i
                k.brick((2.6, top - bot, seg - 0.1), (sx * 0.1, (top + bot) / 2, zc), ORANGE, studs=[(a, (top - bot) / 2 - 0.02, 0) for a in (-0.6, 0.6)])
                k.brick((2.8, 0.5, seg + 0.02), (sx * 0.1, top + 0.2, zc), NAVY, studs=[(a, 0.23, 0) for a in (-0.7, 0.7)])
                for y0, y1 in ((top - 2.5, top - 0.7), (bot + 0.2, min(bot + 2.0, top - 3.0))):
                    if y1 - y0 > 0.6:
                        tooth = [(sx * 1.35, zc - seg / 2 + 0.06), (sx * 3.3, zc - seg / 2 + 0.06), (sx * 1.35, zc + seg / 2 - 0.06)]
                        k.prism(tooth, y0, y1, WHITE, lambda a, b, d: (a, d, b), bevel=0.14)
        k.at((sx * 3.6, 0, -26), (0, sx * yaw, 0), blade)
        for z in (-21.8, -24.4):
            bx = 7.2 * (31 + z) / 10 - 0.55
            hx = max(0.3, hull_x(z, 1.4) - 0.3)         # rib ends inside the hull skin
            wd = max(0.8, bx - hx)
            k.brick((wd, 2.0, 0.8), (sx * (hx + bx) / 2, 1.4, z), NAVY)
    k.prism([(-4.0, -24.6), (0, -30.4), (4.0, -24.6)], 2.3, 3.0, NAVY, lambda a, b, d: (a, d, b), bevel=0.1)
    k.cyl(1.7, 9.0, (0, 2.1, -31.1), ORANGE, n=16)
    k.sphere(1.8, (0, 6.6, -31.1), NAVY, n=16, lat=5)
    k.cone(1.3, 3.2, (0, 3.2, -33.0), WHITE, (-90, 0, 0), tip=0.6, n=14)


# ---------------------------------------------------------------- L25
def roof_rockets(k):
    for sx, s in ((-1, "P"), (1, "S")):
        x = sx * 9.7
        for z in (-8.0, -5.2):
            k.brick((4.6, 0.9, 2.0), (sx * 8.0, 9.1, z), WHITE, studs=[(a, 0.43, 0) for a in (-1.4, 1.4)])
            k.cyl(1.9, 0.6, (x, 11.3, z), DARK, (90, 0, 0), n=18)
        rocket(k, s, (x, 11.3, -6.6), 1.8, 5.6)


# ---------------------------------------------------------------- L26
def crew_deck(k):
    k.brick((14, 0.5, 12.5), (0, 9.15, 9.25), DECK, studs="border")
    k.box((11.6, 0.12, 10.1), (0, 9.44, 9.25), WHITE, r=0.04)
    for sx in (-1, 1):                          # fat columns (AD r1), no thin legs
        for z in (8.5, 14.2):
            k.brick((3.0, 0.4, 3.0), (sx * 4.4, 3.13, z), DARK)
            k.cyl(1.3, 5.6, (sx * 4.4, 6.13, z), ORANGE, n=16)
        wall(k, sx * 6.0 if sx > 0 else -7.0, 7.0 if sx > 0 else -6.0, 3.0, 15.5, 9.4)
    wall(k, -7.0, -1.3, 14.5, 15.5, 9.4)        # the aft wall, with the ladder's gap
    wall(k, 1.3, 7.0, 14.5, 15.5, 9.4)
    for sx in (-1, 1):                          # chunky ladder on the centre line
        k.box((0.55, 6.7, 0.55), (sx * 0.8, 6.3, 15.85), GREY)
        for sz in (3.0, 15.5):
            k.cyl(0.85, 2.3, (sx * 6.5, 11.9, sz), NAVY, n=12)
    y = 3.8
    while y < 9.5:
        k.box((1.6, 0.42, 0.7), (0, y, 15.85), STEEL)
        y += 1.2
    for sx in (-1, 1):                          # life raft canisters
        k.box((2.6, 0.3, 1.2), (sx * 4.0, 9.65, 12.8), DARK)
        k.capsule(0.85, 1.6, (sx * 4.0, 10.65, 12.8), WHITE, (0, 0, 90))
        for d in (-0.6, 0.6):
            k.cyl(0.88, 0.34, (sx * 4.0 + d, 10.65, 12.8), ORANGE, (0, 0, 90), n=12)


# ---------------------------------------------------------------- L27
def tower_lamp(k, x, y, z, d, r, name):
    k.cyl(r, 1.4, (x, y, z), YELLOW, (90, 0, 0), n=14)
    k.torus(r * 0.98, r * 0.22, (x, y, z + d * 0.7), CHROME, n=14, m_=5)
    k.cyl(r * 0.84, 0.14, (x, y, z + d * 0.72), LENS, (90, 0, 0), n=14)
    k.att("Lens_" + name, (x, y, z + d * 0.9))


def lamp_tower(k):
    """AD r1: twice the height, a fat stacked brick column instead of a lattice, a big yellow lamp head."""
    z0 = 6.2
    k.brick((7.0, 0.6, 7.0), (0, 9.75, z0), NAVY, studs="border")
    y, i = 10.0, 0
    while y < 42:                               # courses taper from 5 to 3.8 wide
        w = 5.0 - i * 0.15
        k.box((w, 4.05, w), (0, y + 2.0, z0), ORANGE if i % 2 == 0 else WHITE)
        y += 4.0
        i += 1
    k.brick((7.0, 0.5, 7.0), (0, 14.93, z0), NAVY, studs="border")
    k.brick((6.2, 0.5, 6.2), (0, 28.0, z0), NAVY, studs="border")
    k.brick((8.6, 0.7, 8.6), (0, 42.2, z0), NAVY, studs="border")
    k.box((8.4, 5.8, 1.8), (0, 45.45, z0 + 0.4), YELLOW)
    for i, x in enumerate((-2.1, 2.1)):
        for j, yy in enumerate((44.1, 46.8)):
            tower_lamp(k, x, yy, z0 - 1.1, -1, 1.25, "Fwd%d%d" % (i, j))
        tower_lamp(k, x, 45.45, z0 + 1.9, 1, 1.25, "Aft%d" % i)
    k.cyl(0.9, 0.5, (0, 48.55, z0 + 0.4), DARK, n=14)
    k.cyl(0.8, 1.2, (0, 49.3, z0 + 0.4), AMBER, n=14)
    k.sphere(0.5, (0, 49.95, z0 + 0.4), DARK, n=10, lat=4)
    k.att("Beacon", (0, 49.3, z0 + 0.4))


# ---------------------------------------------------------------- L28
SKI_X, SKI_W, SKI_TOP, SKI_BOT = 9.0, 5.6, -5.8, -7.0


def foil_lift(k):
    """AD r1: wide yellow water-skis on thick struts instead of thin foils. They ride on the water: see RESULT.md for the lift."""
    for sx in (-1, 1):
        x0, x1 = sx * SKI_X - SKI_W / 2, sx * SKI_X + SKI_W / 2
        prof = [(23, SKI_BOT), (-18, SKI_BOT), (-24.5, -4.4), (-24.5, -3.4), (-22, -3.6), (-17.5, SKI_TOP), (23, SKI_TOP)]
        k.prism(prof, x0, x1, YELLOW, lambda a, b, d: (d, b, a), bevel=0.25)
        k.box((1.4, 0.14, 38), (sx * SKI_X, SKI_TOP + 0.03, 3.5), NAVY, r=0.04)
        m = k._m(None, None)
        for z in range(-14, 23, 3):
            for dx in (-1.7, 1.7):
                k.stud(m, (sx * SKI_X + dx, SKI_TOP - 0.02, z), YELLOW)
        for z in (-10, 14):
            hx = 5.0
            top, foot = (sx * hx, hull_y(hx, z) + 0.3, z), (sx * SKI_X, SKI_TOP + 0.2, z)
            k.rod(top, foot, 1.5, ORANGE, n=12)
            mid = [top[i] + (foot[i] - top[i]) * 0.45 for i in range(3)]
            end = [top[i] + (foot[i] - top[i]) * 0.65 for i in range(3)]
            k.rod(mid, end, 1.62, WHITE, n=12)
            k.brick((4.0, 0.8, 4.4), (sx * SKI_X, SKI_TOP + 0.35, z), ORANGE, studs=None)
            k.capsule(1.6, 2.8, (sx * hx, hull_y(hx, z) + 0.05, z), NAVY, (90, 0, 0))
    for z in (-10, 14):                         # the skis' cross bar under the keel
        k.cyl(0.8, 2 * SKI_X, (0, -4.6, z), NAVY, (0, 0, 90), n=10)


# ---------------------------------------------------------------- L29
def rear_rockets(k):
    for sx, s in ((-1, "P"), (1, "S")):         # AD r1: as thick as the hull is deep
        x = sx * 5.9
        for z in (18.8, 24.0):
            k.brick((4.86, 1.45, 2.6), (x, 3.6, z), ORANGE, studs=[(a, 0.7, 0) for a in (-1.6, 0, 1.6)])
            k.cyl(3.46, 0.7, (x, 7.6, z), DARK, (90, 0, 0), n=24)
        rocket(k, s, (x, 7.6, 21.8), 3.4, 8.6, (0, sx * 5, 0), n=24)


# ---------------------------------------------------------------- L30
def battle_bridge(k):
    """AD r1: brick walls and fat columns instead of rails and stilts. Needs the hull's mast group raised 7.2 (RESULT.md)."""
    z, top = -6.0, 15.8
    k.brick((10.4, 1.0, 12.4), (0, 9.175, z), NAVY, studs="border")
    k.box((10.0, 1.8, 12.0), (0, 10.575, z), ORANGE)
    k.box((10.3, 0.4, 12.3), (0, 11.6, z), WHITE)
    k.box((9.5, 2.9, 11.5), (0, 13.2, z), GLASS, r=0.04)
    k.box((10.2, 0.7, 12.2), (0, 14.85, z), WHITE)
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.cyl(0.95, 3.4, (sx * 4.75, 13.2, z + sz * 5.75), WHITE, n=12)
        k.box((1.3, 3.0, 1.3), (sx * 4.7, 13.2, z), WHITE)
        k.box((1.3, 3.0, 0.9), (sx * 1.7, 13.2, z - 5.75), WHITE)
    k.brick((11.4, 0.6, 13.4), (0, 15.5, z), WHITE, studs=None)
    for sx, s in ((-1, "P"), (1, "S")):
        c = sx * 6.1                            # bridge wing: a solid brick balcony on a stepped bracket
        k.brick((2.8, 0.7, 4.2), (c, 12.6, -7.5), DECK, studs=None)
        k.box((2.4, 1.3, 2.2), (sx * 5.7, 11.65, -7.5), NAVY)
        wall(k, c + sx * 0.9 - 0.5, c + sx * 0.9 + 0.5, -9.6, -5.4, 12.95, h0=0.7, h1=0.6)
        lamp(k, "Search" + s, (sx * 3.1, top, -10.3), 1.6, n=12)
        wall(k, sx * 5.2 - 0.45, sx * 5.2 + 0.45, -7.6, 0.2, top)
    wall(k, -5.65, -2.2, -0.7, 0.2, top)
    wall(k, 2.2, 5.65, -0.7, 0.2, top)
    for sx in (-1, 1):                          # twin horns
        k.box((0.8, 0.7, 0.8), (sx * 0.9, top + 0.35, -11.0), DARK)
        k.cyl(0.8, 2.6, (sx * 0.9, top + 1.2, -11.0), WHITE, (90, 0, 0), r2=0.3, n=12)
    for sx in (-1, 1):                          # flags
        k.cyl(0.26, 6.6, (sx * 3.6, top + 3.3, -2.2), WHITE, n=8)
        k.sphere(0.42, (sx * 3.6, top + 6.7, -2.2), YELLOW, n=8, lat=3)
    fy = top + 5.1
    k.flag(-3.6, fy, -2.2, 4.4, 2.8, ORANGE, half=1)
    k.flag(-3.6, fy, -2.2, 4.4, 2.8, WHITE, half=-1)
    k.flag(3.6, fy, -2.2, 4.8, 2.4, YELLOW, tri=True)
    k.brick((4.4, 0.5, 3.8), (0, 14.88, 1.1), NAVY, studs=None)   # top 0.05 under the tower landing it meets
    for sx in (-1, 1):                          # fat columns instead of the concept's stilts
        k.cyl(1.05, 6.3, (sx * 1.3, 11.8, 1.6), ORANGE, n=14)
    ly = 15.18                                  # brick walls round the Lamp Tower's landing, a gap for the walkway
    for sx in (-1, 1):
        wall(k, sx * 3.0 - 0.5, sx * 3.0 + 0.5, 2.7, 9.7, ly)
        wall(k, sx * 2.6 - 0.45, sx * 2.6 + 0.45, 0.7, 2.7, 14.93, h0=1.1)
    wall(k, -3.5, 3.5, 8.7, 9.7, ly)


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
