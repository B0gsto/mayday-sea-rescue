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
    "grey": dict(top="#B6C0CB", bottom="#8C97A4", rough=0.82),
    "black": dict(top="#34363C", bottom="#1B1C20", rough=0.8),
    "yellow": dict(top="#F7CB3C", bottom="#D9A21E", rough=0.42, signal=True),
    "red": dict(top="#E0402F", bottom="#B92A22", rough=0.42, signal=True),
    "pink": dict(top="#EFAEA2", bottom="#CC8577", rough=0.6, signal=True),
    "eye": dict(top="#26262C", bottom="#141418", rough=0.12),
    "glint": dict(top="#FFFFFF", bottom="#F2F2F2", rough=0.1),
    "ring": dict(top="#F2A23A", bottom="#D4801F", rough=0.4, signal=True),
}


def _local(v):
    return Vector((-v[0], v[2], v[1]))


def body(p):
    def w(c):
        if c.y > 0:
            k = 1.0 - 0.4 * (c.y / 0.975)
            c.x *= k
            c.z = c.z * k + 0.1 * c.y
        return c
    p.add(K.ball((1.22, 0.95, 1.95), u=10, v=7, rot=[(90, "X")]), "white")    # poles along Y: a torpedo
    for v in p.bm.verts:
        v.co = w(v.co.copy())
    p.add(K.ball((0.62, 0.62, 0.72), (0, -0.78, 0.36), u=8, v=6), "white")      # neck up to the head


def body_refine(zone, c, n):
    return "grey" if n.z > 0.45 and c.y > -0.45 else zone


def belly(p):
    p.add(K.ball((0.95, 1.35, 0.55), u=10, v=6), "white")


def head(p):
    p.add(K.ball((0.8, 0.86, 0.76), u=10, v=7), "white")


def _mandible(y0, y1, width, top, bot, zone, p):
    def w(c):
        y = y0 + (c.y + 0.5) * (y1 - y0)
        t = (y0 - y) / (y0 - y1)
        b = bot(t)
        return Vector((c.x * width(t), y, b + (c.z + 0.5) * (top(t) - b)))
    p.add(K.box((1, 1, 1), bevel=0.06, warp=w), zone)


def beak(p):
    # upper mandible, hooked tip, lower mandible with the red gonys spot
    _mandible(0.3, -0.33, lambda t: 0.26 - 0.14 * t, lambda t: 0.12 - 0.08 * t, lambda t: -0.01 - 0.01 * t, "yellow", p)
    p.add(K.box((0.11, 0.1, 0.13), (0, -0.33, -0.03), bevel=0.025, taper=("z", 0.5, 1.0)), "yellow")
    _mandible(0.3, -0.28, lambda t: 0.22 - 0.12 * t, lambda t: -0.02,
              lambda t: -0.12 - 0.03 * min(t / 0.75, 1.0) + 0.12 * max(0.0, t - 0.75), "yellow", p)
    p.add(K.box((0.14, 0.09, 0.07), (0, -0.19, -0.115), bevel=0.02), "red")


def eye_maker(pos):
    inward = _local(Vector((0, 1.88, -0.92)) - Vector(pos)).normalized()

    def make(p):
        p.add(K.ball((0.2, 0.2, 0.2), u=10, v=6), "eye")
        p.add(K.ball((0.24, 0.24, 0.24), inward * 0.045, u=10, v=6), "ring")
    return make


def glint(p):
    p.add(K.ball((0.08, 0.07, 0.08), u=6, v=4), "glint")


def _span(p, s0, s1, le, te, thick, zone, chord=(0.0, 1.0)):
    """A spanwise wing slab from s0 to s1 (0 root, 1 tip, outward = +X), between chord fractions."""
    def w(c):
        s = s0 + (c.x + 0.5) * (s1 - s0)
        f = chord[0] + (c.y + 0.5) * (chord[1] - chord[0])
        a, b = le(s), te(s)
        return Vector((-1.25 + 2.5 * s, a + f * (b - a), c.z * thick(s) - 0.02 * s))
    p.add(K.box((1, 1, 1), bevel=0.04, warp=w), zone)


def wing_maker(left):
    le = lambda s: -0.5 + 0.38 * s ** 1.4
    te = lambda s: 0.5 - 0.3 * s - 0.12 * s ** 2
    th = lambda s: 0.14 - 0.08 * s

    def make(p):
        _span(p, 0.0, 0.7, le, te, th, "grey", (0.0, 0.84))
        _span(p, 0.0, 0.7, le, te, lambda s: th(s) * 0.92, "white", (0.8, 1.0))
        _span(p, 0.68, 1.0, le, te, lambda s: th(s) * 0.98, "black")
        p.add(K.box((0.14, 0.12, 0.08), (-1.25 + 2.5 * 0.9, 0.02, -0.02), bevel=0.02), "white")
        if not left:          # authored for the left wing (outward = Blender +X)
            K.mirror_x(p.bm)
    return make


def tail(p):
    p.add(K.box((0.74, 0.6, 0.09), (0, -0.08, 0), bevel=0.03, taper=("y", 0.55, 1.0)), "white")


def leg(p):
    p.add(K.box((0.1, 0.1, 0.62), bevel=0.025, taper=("z", 0.85, 1.0)), "pink")


def foot(p):
    p.add(K.box((0.42, 0.48, 0.07), (0, -0.04, 0), bevel=0.02, taper=("y", 1.0, 0.35)), "pink")
    for x in (-0.14, 0.0, 0.14):
        p.add(K.box((0.05, 0.1, 0.05), (x, -0.3, 0.0), bevel=0.0), "pink")


# node, WildlifeRig part, Roblox position, angles, maker, refine  (order = Wildlife.Species.Gull.parts)
PARTS = [
    ("Body", "Body", (0, 1.18, 0), (0, 0, 0), body, body_refine),
    ("Belly", "Belly", (0, 0.92, -0.05), (0, 0, 0), belly, None),
    ("Head", "Head", (0, 1.88, -0.92), (0, 0, 0), head, None),
    ("Beak", "Beak", (0, 1.84, -1.4), (0, 0, 0), beak, None),
    ("EyeLeft", "Eye", (-0.27, 2.0, -1.16), (0, 0, 0), eye_maker((-0.27, 2.0, -1.16)), None),
    ("EyeRight", "Eye", (0.27, 2.0, -1.16), (0, 0, 0), eye_maker((0.27, 2.0, -1.16)), None),
    ("GlintLeft", "Glint", (-0.23, 2.05, -1.28), (0, 0, 0), glint, None),
    ("GlintRight", "Glint", (0.23, 2.05, -1.28), (0, 0, 0), glint, None),
    ("WingLeft", "Wing", (-1.28, 1.22, 0.0), (0, 0, 0.12), wing_maker(True), None),
    ("WingRight", "Wing", (1.28, 1.22, 0.0), (0, 0, -0.12), wing_maker(False), None),
    ("Tail", "Tail", (0, 1.16, 1.15), (0.16, 0, 0), tail, None),
    ("LegLeft", "Leg", (-0.32, 0.42, 0.25), (0, 0, 0), leg, None),
    ("LegRight", "Leg", (0.32, 0.42, 0.25), (0, 0, 0), leg, None),
    ("FootLeft", "Foot", (-0.32, 0.12, 0.02), (0, 0, 0), foot, None),
    ("FootRight", "Foot", (0.32, 0.12, 0.02), (0, 0, 0), foot, None),
]


def build():
    parts = [dict(node=n, part=pn, index=i + 1, cframe=K.cf(pos, *ang), roblox=(pos, ang), make=mk, refine=rf)
             for i, (n, pn, pos, ang, mk, rf) in enumerate(PARTS)]
    return K.build_asset(ASSET, PREFIX, "Gull", "Feathers", ZONES, parts, HERE, fbx_name="M_Ani_Gull", extra_mapping={
        "source": "src/shared/Config/Wildlife.luau Species.Gull.parts (index = position in that list)",
        "rare": "the snow-gull palette is not in this atlas (needs a second ALB or a tinted copy)"})
