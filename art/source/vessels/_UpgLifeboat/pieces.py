"""The Lifeboat stage's nine upgrade pieces (L22-L30), ported from the owner-cleared concept (artifact cdf29056, PIECES).

Coordinates are the concept's and the hull's (Builder.luau buildLifeboat). Fitted to the real waterline: the game floats her
with the water at about hull y +1.5 (float points y -3, draft 4.5), the concept drew the sea at y 0. Round 2 (art director 6.5/10) pushed
sizes, walls, skis and colours past the concept on purpose: see RESULT.md.
"""
import math

import kit as K
from kit import AMBER, CHROME, DARK, DECK, GLASS, LENS, NAVY, ORANGE, RED, STEEL, WHITE, YELLOW, hull_x, hull_y


def lamp(k, pre, pos, r, n=20):
    """Base with border studs, yoke, signature yellow housing, chrome reflector and bezel, warm lens."""
    def body():
        w, hy, ln = 2 * r + 1.3, 0.55 + r + 0.3, 1.6 * r
        zf, yh = -ln / 2, 0.55 + r + 0.3 + 0.25 - 0.55
        yt, yd = max(0.6, r * 0.3), max(1.3, r * 0.6)
        k.brick((w, 0.55, max(3.0, r * 1.3)), (0, 0.275, 0), NAVY, studs="bigborder")
        for s in (-1, 1):
            k.box((yt, yh, yd), (s * (r + yt * 0.75), 0.55 + yh / 2, 0), YELLOW)
            k.cyl(max(0.48, r * 0.26), max(0.36, r * 0.2), (s * (r + yt * 1.4), hy, 0), CHROME, (0, 0, 90), n=10)
        k.cyl(r, ln, (0, hy, 0), YELLOW, (90, 0, 0), n=n)
        k.sphere(r * 0.94, (0, hy, ln / 2), YELLOW, (1, 1, 0.5), n=n, lat=4)
        for f in (0.05, 0.28):
            k.torus(r + 0.03, max(0.13, r * 0.08), (0, hy, f * ln), WHITE, n=n, m_=4)
        k.cyl(r * 0.9, 0.3, (0, hy, zf - 0.1), CHROME, (90, 0, 0), n=n)
        k.sphere(r * 0.82, (0, hy, zf - 0.22), LENS, (1, 1, 0.3), n=n, lat=4)
        k.torus(r * 0.98, r * 0.24, (0, hy, zf - 0.25), CHROME, n=n, m_=6)
        k.att("Lens_" + pre, (0, hy, zf - 0.5))
    k.at(pos, None, body)


def wall(k, x0, x1, z0, z1, y0, low=ORANGE, cap=WHITE, h0=0.95, h1=0.75):
    """A chunky parapet instead of a rail: two brick courses, big studs on top."""
    sx, sz, cx, cz = x1 - x0, z1 - z0, (x0 + x1) / 2, (z0 + z1) / 2
    k.box((sx, h0 + 0.05, sz), (cx, y0 + h0 / 2 - 0.025, cz), low)
    long_x = sx > sz
    n = max(1, int((sx if long_x else sz) / 3))
    step = (sx if long_x else sz) / n
    spots = [((-sx / 2 + (i + 0.5) * step) if long_x else 0, h1 / 2 - 0.02, 0 if long_x else (-sz / 2 + (i + 0.5) * step)) for i in range(n)]
    k.brick((sx + 0.1, h1, sz + 0.1), (cx, y0 + h0 + h1 / 2, cz), cap, studs=spots, big=True)


def rocket(k, pre, pos, r, ln, rot=None, n=18, can=RED, band=WHITE, mid_band=True):
    """Firework can: stubby tube, white dome, light nozzle (never a dark hole from the stern), a big rounded orange plume."""
    def body():
        k.cyl(r, ln, (0, 0, 0), can, (90, 0, 0), n=n)
        for f in ((0.2, 0.62) if mid_band else (0.42,)):
            k.cyl(r + 0.06, ln * 0.18, (0, 0, -ln / 2 + ln * f), band, (90, 0, 0), n=n)
        k.sphere(r * 0.98, (0, 0, -ln / 2), WHITE, (1, 1, 0.72), n=n, lat=4)
        for a in (0, 120, 240):
            k.at((0, 0, 0), (0, 0, a), lambda: k.box((max(0.42, r * 0.28), r * 0.8, ln * 0.34), (0, r * 1.32, ln / 2 - ln * 0.17), can, r=0.18))
        k.cyl(r * 0.78, r * 0.7, (0, 0, ln / 2 + r * 0.35), STEEL, (90, 0, 0), r2=r, n=n)
        k.torus(r, max(0.18, r * 0.1), (0, 0, ln / 2 + r * 0.7), WHITE, n=n, m_=4)
        fz, fl = ln / 2 + r * 0.7, r * 3.0
        tongue = lambda x, y, w, ln_, c: k.at((x, y, fz + ln_ / 2 - 0.1), (90, 0, 0), lambda: k.sphere(w, (0, 0, 0), c, (1, ln_ / 2 / w, 1), n=8, lat=3))
        for i in range(6):                      # three layers of rounded tongues: fire, never a warhead
            a = math.radians(30 + i * 60)
            tongue(r * 0.55 * math.cos(a), r * 0.55 * math.sin(a), r * 0.42, fl * (1.0 if i % 2 else 0.78), ORANGE)
        for i in range(3):
            a = math.radians(i * 120)
            tongue(r * 0.26 * math.cos(a), r * 0.26 * math.sin(a), r * 0.36, fl * 0.86, AMBER)
        tongue(0, 0, r * 0.34, fl * 0.55, LENS)
        k.att("Flame_" + pre, (0, 0, fz + 0.2))
    k.at(pos, rot, body)


# ---------------------------------------------------------------- L22
SPIKE_Y, SPIKE_TILT, SPIKE_SWEEP = 0.6, 25, 62
# The bay takes 24 x 1.387 (the lifeboat's level scale cap): the hull already fills it, so the spikes sweep aft along her side:
# tips at x about +-11 (concept +-18 flat), and they add no width from the stern.


def armour_spikes(k):
    def spike(z, sx):
        def body():
            k.lathe([(0, 0), (1.8, 0), (2.0, 0.15), (2.0, 0.95), (1.8, 1.1), (0, 1.1)], 16, DARK, (0, 0, 0), None, (1, 1, 1.3))
            k.torus(1.6, 0.3, (0, 1.2, 0), ORANGE, (90, 0, 0), n=16, m_=5)
            k.cone(1.75, 5.6, (0, 3.9, 0), WHITE, tip=0.8, n=16)
        k.at((sx * hull_x(z, SPIKE_Y), SPIKE_Y, z), (0, -sx * SPIKE_SWEEP, -sx * (90 - SPIKE_TILT)), body)
    for sx in (-1, 1):                          # three a side: fewer, cleaner than the concept's four
        for z in (-15, -2, 11):
            spike(z, sx)


# ---------------------------------------------------------------- L23
def huge_lamps(k):
    for sx, s in ((-1, "P"), (1, "S")):         # AD r1: twice the concept's r 1.9
        lamp(k, s, (sx * 5.6, 8.675, -15.0), 3.8, n=24)


# ---------------------------------------------------------------- L24
def ice_plough(k):
    """One chunky toy bumper (AD r2): a fat orange V in stepped courses with big studs and one dark rubber strip. Bow out to open sea, so it
    ends at z -31 (game -43), past the bay's open end."""
    up = lambda a, b, d: (a, d, b)

    def vee(wing, nose, aft, thick):
        o = [(wing, aft), (nose, -30.9 + (6.8 - wing) * 0.9), (-nose, -30.9 + (6.8 - wing) * 0.9), (-wing, aft)]
        return o + [(-wing + thick, aft), (-nose * 0.6, -30.9 + thick * 1.4 + (6.8 - wing) * 0.9), (nose * 0.6, -30.9 + thick * 1.4 + (6.8 - wing) * 0.9), (wing - thick, aft)]
    k.prism(vee(6.8, 1.7, -19.5, 3.4), -2.4, 2.75, ORANGE, up, bevel=0.32)
    k.prism(vee(7.0, 1.85, -19.3, 3.0), 2.05, 2.75, DARK, up, bevel=0.12)
    k.prism(vee(5.2, 1.5, -21.0, 3.0), 2.7, 4.2, ORANGE, up, bevel=0.32)
    k.prism(vee(3.4, 1.2, -24.0, 2.6), 4.15, 5.5, ORANGE, up, bevel=0.32)
    m = k._m(None, None)
    for x, y, z in ((5.2, 2.73, -20.6), (3.3, 4.18, -22.0), (1.7, 5.48, -25.6)):
        for sx in (-1, 1):
            k.stud(m, (sx * x, y, z), ORANGE, big=True)
    k.stud(m, (0, 5.48, -26.6), ORANGE, big=True)
    k.stud(m, (0, 2.73, -30.2), ORANGE, big=True)
    k.prism([(-4.0, -24.6), (0, -29.0), (4.0, -24.6)], 2.3, 2.75, NAVY, up, bevel=0.08)   # closes the V behind the stem


# ---------------------------------------------------------------- L25
def roof_rockets(k):
    for sx, s in ((-1, "P"), (1, "S")):         # tight to the cabin, white with one red band: the red hero is the rear pair
        x = sx * 8.9
        for z in (-8.0, -5.2):
            k.brick((3.8, 0.9, 2.0), (sx * 7.6, 9.1, z), WHITE, studs=[(a, 0.43, 0) for a in (-1.0, 1.0)], big=True)
            k.cyl(1.9, 0.6, (x, 11.3, z), NAVY, (90, 0, 0), n=18)
        rocket(k, s, (x, 11.3, -6.6), 1.8, 5.6, can=WHITE, band=RED, mid_band=False)


# ---------------------------------------------------------------- L26
def crew_deck(k):
    k.brick((14, 0.5, 12.5), (0, 9.15, 9.25), DECK, studs=None)
    k.box((11.6, 0.12, 10.1), (0, 9.44, 9.25), WHITE, r=0.04)
    for sx in (-1, 1):                          # fat columns, clear of the survivor slots at x +-3.4
        for z in (8.5, 14.2):
            k.brick((3.0, 0.4, 3.0), (sx * 5.6, 3.13, z), DARK)
            k.cyl(1.3, 5.6, (sx * 5.6, 6.13, z), ORANGE, n=16)
        wall(k, sx * 6.0 if sx > 0 else -7.0, 7.0 if sx > 0 else -6.0, 3.0, 15.5, 9.4)
    wall(k, -7.0, 7.0, 14.5, 15.5, 9.4)
    wall(k, -7.0, 7.0, 3.0, 4.0, 9.4)


# ---------------------------------------------------------------- L27
def lamp_tower(k):
    """AD r2: a stepped plinth and a fat base so it grows out of the deck, broad bands, one big white lamp drum on top."""
    z0 = 9.25
    k.brick((11.0, 1.35, 8.6), (0, 10.125, z0), NAVY, studs="bigborder")
    k.brick((8.6, 1.45, 7.4), (0, 11.5, z0), WHITE, studs="bigborder")
    k.brick((7.0, 1.45, 6.4), (0, 12.9, z0), NAVY, studs="bigborder")
    y = 13.6
    for i in range(5):
        w = 6.2 - i * 0.4
        k.box((w, 5.05, w), (0, y + 2.5, z0), ORANGE if i % 2 == 0 else WHITE)
        y += 5.0
    k.brick((9.0, 0.8, 9.0), (0, 39.0, z0), NAVY, studs="bigborder")
    k.cyl(3.4, 5.4, (0, 43.0, z0), WHITE, (90, 0, 0), n=24)
    k.cyl(3.46, 1.2, (0, 43.0, z0), ORANGE, (90, 0, 0), n=24)
    k.box((1.6, 1.2, 4.0), (0, 39.8, z0), NAVY)
    for d in (-1, 1):
        k.torus(3.15, 0.55, (0, 43.0, z0 + d * 2.7), CHROME, n=24, m_=5)
        k.sphere(2.9, (0, 43.0, z0 + d * 2.75), LENS, (1, 1, 0.22), n=20, lat=3)
        k.att("Lens_" + ("Fwd" if d < 0 else "Aft"), (0, 43.0, z0 + d * 3.3))
    k.cyl(1.0, 0.6, (0, 46.6, z0), NAVY, n=14)
    k.cyl(0.85, 1.2, (0, 47.4, z0), AMBER, n=14)
    k.att("Beacon", (0, 47.4, z0))


# ---------------------------------------------------------------- L28
SKI_X, SKI_W, SKI_TOP, SKI_BOT = 7.4, 4.8, -5.8, -7.0   # outer edge x +-9.8: no wider than the bay needs; orange, yellow belongs to the lamps


def foil_lift(k):
    """Two wide orange water-skis with big studs on thick white struts. They ride on the water: see RESULT.md for the lift."""
    for sx in (-1, 1):
        x0, x1 = sx * SKI_X - SKI_W / 2, sx * SKI_X + SKI_W / 2
        prof = [(23, SKI_BOT), (-18, SKI_BOT), (-24.5, -4.4), (-24.5, -3.4), (-22, -3.6), (-17.5, SKI_TOP), (23, SKI_TOP)]
        k.prism(prof, x0, x1, ORANGE, lambda a, b, d: (d, b, a), bevel=0.25)
        m = k._m(None, None)
        for z in range(-15, 23, 4):
            for dx in (-1.2, 1.2):
                k.stud(m, (sx * SKI_X + dx, SKI_TOP - 0.02, z), ORANGE, big=True)
        for z in (-10, 14):
            hx = 5.0
            top, foot = (sx * hx, hull_y(hx, z) + 0.3, z), (sx * SKI_X, SKI_TOP + 0.2, z)
            k.rod(top, foot, 1.5, WHITE, n=12)
            k.brick((4.0, 0.8, 4.4), (sx * SKI_X, SKI_TOP + 0.35, z), WHITE, studs=None)
            k.capsule(1.6, 2.8, (sx * hx, hull_y(hx, z) + 0.05, z), NAVY, (90, 0, 0))
    for z in (-10, 14):                         # the skis' cross bar under the keel
        k.cyl(0.8, 2 * SKI_X, (0, -4.6, z), NAVY, (0, 0, 90), n=10)


# ---------------------------------------------------------------- L29
def rear_rockets(k):
    for sx, s in ((-1, "P"), (1, "S")):         # AD r2: spread wide with a clear gap, splayed out, the one red hero
        x = sx * 8.0
        for z in (19.5, 24.3):
            k.brick((7.0, 1.45, 2.6), (sx * 6.9, 3.6, z), ORANGE, studs=[(a, 0.7, 0) for a in (-2.2, 0, 2.2)], big=True)
            k.cyl(3.26, 0.7, (x, 7.4, z), WHITE, (90, 0, 0), n=24)
        rocket(k, s, (x, 7.4, 21.9), 3.2, 8.4, (0, sx * 11, 0), n=24)


# ---------------------------------------------------------------- L30
def battle_bridge(k):
    """AD r2: one big brick mass joined to the tower's plinth; the small searchlights, horns, flags and wings are cut.
    Needs the hull's mast group raised 7.2 (RESULT.md)."""
    z = -6.0
    k.brick((12.0, 1.0, 12.8), (0, 9.175, z), NAVY, studs=None)
    k.box((11.6, 2.2, 12.4), (0, 10.775, z), ORANGE)
    k.box((11.0, 2.8, 11.8), (0, 13.2, z), GLASS, r=0.04)
    k.box((11.8, 0.65, 12.6), (0, 14.9, z), WHITE)
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.cyl(1.1, 3.3, (sx * 5.5, 13.2, z + sz * 5.9), WHITE, n=12)
        k.box((1.4, 2.9, 1.4), (sx * 5.5, 13.2, z), WHITE)
    k.brick((13.0, 0.7, 14.4), (0, 15.45, z), WHITE, studs="bigborder")
    # the joined block from the bridge's back to the tower's plinth
    k.box((6.4, 5.5, 4.6), (0, 11.55, 2.6), ORANGE)
    k.brick((7.0, 0.7, 5.2), (0, 14.55, 2.6), NAVY, studs="big")


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
            "LOD0 floor": "Ice Plough is one chunky toy bumper by design (art director round 2)",
            "UV faces": "decimated LOD faces collapse their small UV ring inside a palette cell: the colour stays the cell's",
        },
    }
