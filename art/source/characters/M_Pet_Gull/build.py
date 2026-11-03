"""M_Pet_Gull: the herring gull pet, low-poly faceted (Bosun LP style).

One mesh per WildlifeRig part of Config/Wildlife.Species.Gull, in the same order (duplicate names get
Left / Right: Left is Roblox -X). Each FBX node sits at its PartSpec `at` CFrame, so WildlifeRig can swap
the block Parts for MeshParts by index; M_Pet_Gull.mapping.json lists node, part, index and CFrame.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/characters/M_Pet_Gull/build.py --out-root build/prod/M_Pet_Gull \
      --steps build,lod,validate,export,turntable
"""
import os
import sys

from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "_LP"))
import lpkit as K  # noqa: E402

ASSET = "M_Pet_Gull"
PREFIX = "M_Ani_Gull_"          # "Pet" is not a names.py category; nodes are renamed to the part names after validate

ZONES = {
    "white": dict(top="#FBFBF8", bottom="#D2D6D9", rough=0.84),
    "grey": dict(top="#9AA6B4", bottom="#848F9C", rough=0.82),     # r2: mid-grey mantle
    "black": dict(top="#2A2C32", bottom="#16171B", rough=0.6),
    "yellow": dict(top="#FFD23A", bottom="#E8A814", rough=0.38, signal=True),
    "red": dict(top="#E0402F", bottom="#B92A22", rough=0.42, signal=True),
    "eye": dict(top="#26262C", bottom="#141418", rough=0.12),
    "glint": dict(top="#FFFFFF", bottom="#F2F2F2", rough=0.1),
    "ring": dict(top="#F2A23A", bottom="#D4801F", rough=0.4, signal=True),
}


def _local(v):
    return Vector((-v[0], v[2], v[1]))


def body(p):
    def w(c):
        if c.y > 0:
            k = 1.0 - 0.3 * (c.y / 0.975)
            c.x *= k
            c.z = c.z * k + 0.1 * c.y
        return c
    p.add(K.ball((1.5, 1.2, 1.95), u=10, v=7, rot=[(90, "X")]), "white")      # poles along Y: a plump toy torpedo
    for v in p.bm.verts:
        v.co = w(v.co.copy())
    p.add(K.ball((0.72, 0.7, 0.76), (0, -0.78, 0.36), u=8, v=6), "white")       # neck up to the head


def body_refine(zone, c, n):
    return "grey" if n.z > 0.45 and c.y > -0.45 else zone


def belly(p):
    p.add(K.ball((1.2, 1.45, 0.72), u=10, v=6), "white")


def head(p):
    p.add(K.ball((0.68, 0.73, 0.65), u=10, v=7), "white")                    # r2: head 0.85x
    p.add(K.cyl(0.15, 0.16, (0, 0, 0.345), sides=10), "grey")                # 0.3 Lego stud, base sunk in the crown


def _mandible(y0, y1, width, top, bot, zone, p):
    def w(c):
        y = y0 + (c.y + 0.5) * (y1 - y0)
        t = (y0 - y) / (y0 - y1)
        b = bot(t)
        return Vector((c.x * width(t), y, b + (c.z + 0.5) * (top(t) - b)))
    p.add(K.box((1, 1, 1), bevel=0.06, seg=2, warp=w), zone)


def beak(p):
    # upper mandible, hooked tip, lower mandible with the red gonys spot
    # r2: 1.5x longer, the red spot moved out to the tip
    _mandible(0.3, -0.69, lambda t: 0.36 - 0.16 * t, lambda t: 0.16 - 0.08 * t, lambda t: -0.01 - 0.01 * t, "yellow", p)
    p.add(K.box((0.16, 0.12, 0.17), (0, -0.69, -0.03), bevel=0.035, taper=("z", 0.55, 1.0)), "yellow")
    _mandible(0.3, -0.6, lambda t: 0.3 - 0.13 * t, lambda t: -0.02,
              lambda t: -0.16 - 0.03 * min(t / 0.75, 1.0) + 0.15 * max(0.0, t - 0.75), "yellow", p)
    p.add(K.box((0.21, 0.12, 0.09), (0, -0.5, -0.145), bevel=0.025), "red")


def eye_maker(pos):
    inward = _local(Vector(PARTS[2][2]) - Vector(pos)).normalized()      # toward the Head part

    def make(p):
        p.add(K.ball((0.23, 0.23, 0.23), u=10, v=6), "eye")
        p.add(K.ball((0.27, 0.27, 0.27), inward * 0.05, u=10, v=6), "ring")
    return make


def glint(p):
    p.add(K.ball((0.08, 0.07, 0.08), u=6, v=4), "glint")


SPAN = 1.4       # tour 2026-10-31 2.5 -> 1.95; r2 AD: 30 % shorter, drooped (tucked toy wings)

DROOP = 0.42     # r2: the wing tips tuck down (~23 deg with the part's 0.12 rad roll)


def _span(p, s0, s1, le, te, thick, zone, chord=(0.0, 1.0)):
    """A spanwise wing slab from s0 to s1 (0 root, 1 tip, outward = +X), between chord fractions."""
    def w(c):
        s = s0 + (c.x + 0.5) * (s1 - s0)
        f = chord[0] + (c.y + 0.5) * (chord[1] - chord[0])
        a, b = le(s), te(s)
        return Vector((-1.25 + SPAN * s, a + f * (b - a), c.z * thick(s) - DROOP * s))
    p.add(K.box((1, 1, 1), bevel=0.05, warp=w), zone)


def wing_maker(left):
    le = lambda s: -0.5 + 0.38 * s ** 1.4
    te = lambda s: 0.5 - 0.3 * s - 0.12 * s ** 2
    th = lambda s: 0.2 - 0.1 * s

    def make(p):
        _span(p, 0.0, 0.62, le, te, th, "grey", (0.0, 0.84))
        _span(p, 0.0, 0.62, le, te, lambda s: th(s) * 0.92, "white", (0.8, 1.0))
        _span(p, 0.6, 1.0, le, te, lambda s: th(s) * 0.98, "black")
        p.add(K.box((0.16, 0.14, 0.1), (-1.25 + SPAN * 0.86, 0.02, -DROOP * 0.86), bevel=0.025), "white")
        if not left:          # authored for the left wing (outward = Blender +X)
            K.mirror_x(p.bm)
    return make


def tail(p):
    p.add(K.box((0.74, 0.6, 0.09), (0, -0.08, 0), bevel=0.04, taper=("y", 0.55, 1.0)), "white")


def leg(p):
    p.add(K.box((0.16, 0.16, 0.48), bevel=0.05, seg=2, taper=("z", 0.85, 1.0)), "yellow")   # r2: 20 % shorter


def foot(p):
    p.add(K.box((0.54, 0.58, 0.13), (0, -0.04, 0), bevel=0.05, seg=2, taper=("y", 1.0, 0.4)), "yellow")
    for x in (-0.18, 0.0, 0.18):
        p.add(K.box((0.09, 0.14, 0.09), (x, -0.36, -0.01), bevel=0.02), "yellow")


# node, WildlifeRig part, Roblox position, angles, maker, refine  (order = Wildlife.Species.Gull.parts)
PARTS = [
# r2: everything above the legs 0.1 lower (legs 20 % shorter); head cluster 0.85x about the Head; then SCALE
    ("Body", "Body", (0, 1.08, 0), (0, 0, 0), body, body_refine),
    ("Belly", "Belly", (0, 0.82, -0.05), (0, 0, 0), belly, None),
    ("Head", "Head", (0, 1.78, -0.92), (0, 0, 0), head, None),
    ("Beak", "Beak", (0, 1.706, -1.328), (0, 0, 0), beak, None),
    ("EyeLeft", "Eye", (-0.23, 1.882, -1.124), (0, 0, 0), None, None),
    ("EyeRight", "Eye", (0.23, 1.882, -1.124), (0, 0, 0), None, None),
    ("GlintLeft", "Glint", (-0.19, 1.932, -1.244), (0, 0, 0), glint, None),
    ("GlintRight", "Glint", (0.19, 1.932, -1.244), (0, 0, 0), glint, None),
    ("WingLeft", "Wing", (-1.28, 1.12, 0.0), (0, 0, 0.12), wing_maker(True), None),
    ("WingRight", "Wing", (1.28, 1.12, 0.0), (0, 0, -0.12), wing_maker(False), None),
    ("Tail", "Tail", (0, 1.06, 1.15), (0.16, 0, 0), tail, None),
    ("LegLeft", "Leg", (-0.32, 0.37, 0.25), (0, 0, 0), leg, None),
    ("LegRight", "Leg", (0.32, 0.37, 0.25), (0, 0, 0), leg, None),
    ("FootLeft", "Foot", (-0.32, 0.12, 0.02), (0, 0, 0), foot, None),
    ("FootRight", "Foot", (0.32, 0.12, 0.02), (0, 0, 0), foot, None),
]
PARTS = [(n, pn, pos, ang, mk or eye_maker(pos), rf) for n, pn, pos, ang, mk, rf in PARTS]
SCALE = 1.2      # r2 AD: the pet read as a speck next to a 5-stud figure


def build():
    parts = [dict(node=n, part=pn, index=i + 1, cframe=K.cf(pos, *ang), roblox=(pos, ang), make=mk, refine=rf)
             for i, (n, pn, pos, ang, mk, rf) in enumerate(PARTS)]
    spec = K.build_asset(ASSET, PREFIX, "Gull", "Feathers", ZONES, parts, HERE, fbx_name="M_Ani_Gull", scale=SCALE, smooth=40, extra_mapping={
        "source": "src/shared/Config/Wildlife.luau Species.Gull.parts (index = position in that list)",
        "rare": "the snow-gull palette is not in this atlas (needs a second ALB or a tinted copy)"})
    spec["waivers"]["UV faces"] = "per-face swatch UVs are tiny squares; LOD collapse of the head stud leaves a face with no UV area"
    return spec
