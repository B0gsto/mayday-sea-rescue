"""M_Pet_Gull: the herring gull pet, low-poly faceted (Bosun LP style).

One mesh per WildlifeRig part of Config/Wildlife.Species.Gull, in the same order (duplicate names get
Left / Right: Left is Roblox -X). Each FBX node sits at its PartSpec `at` CFrame, so WildlifeRig can swap
the block Parts for MeshParts by index; M_Pet_Gull.mapping.json lists node, part, index and CFrame.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/characters/M_Pet_Gull/build.py --out-root build/prod/M_Pet_Gull \
      --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "_LP"))
import lpkit as K  # noqa: E402

ASSET = "M_Pet_Gull"
PREFIX = "M_Ani_Gull_"          # "Pet" is not a names.py category; nodes are renamed to the part names after validate

ZONES = {
    "white": dict(top="#FBFBF8", bottom="#D2D6D9", rough=0.84),
    "grey": dict(top="#66737F", bottom="#5E6B77", rough=0.82),     # r5: mantle two steps darker
    "black": dict(top="#2A2C32", bottom="#16171B", rough=0.6),
    "yellow": dict(top="#FFC800", bottom="#F2A200", rough=0.38, signal=True),     # r4: more saturated
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
    return "grey" if n.z > 0.2 and c.y > -0.6 else zone      # r5: wider, onto the shoulders


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
    # r5: one closed wedge (two mandibles read as a shouting mouth), 20 % narrower/shorter; the red dot only underneath
    _mandible(0.3, -0.36, lambda t: 0.288 - 0.128 * t, lambda t: 0.15 - 0.09 * t, lambda t: -0.15 + 0.08 * t, "yellow", p)
    p.add(K.ball((0.18, 0.18, 0.11), (0, -0.2, -0.1), u=8, v=4), "red")


def eye_maker(pos):
    inward = _local(Vector(PARTS[2][2]) - Vector(pos)).normalized()      # toward the Head part

    def make(p):
        p.add(K.ball((0.23, 0.23, 0.23), u=10, v=6), "eye")
        p.add(K.ball((0.27, 0.27, 0.27), inward * 0.05, u=10, v=6), "ring")
    return make


def glint(p):
    p.add(K.ball((0.08, 0.07, 0.08), u=6, v=4), "glint")


WING = 0.95      # r3: folded, shoulder to tip
FOLD = math.radians(63)      # r3: 70 deg down with the part's 0.12 rad roll, flat against the body (no T-pose)
ROOT = (-0.68, 0.22)         # the shoulder (x, z) in the part's frame, sunk in the body
SWEEP = 0.4      # the tip points back along the flank, like a folded wing
CURL = 0.12      # the tip curves in under the body's widest point (r4: less, so the black shows from the front)


def _span(p, s0, s1, le, te, thick, zone, chord=(0.0, 1.0)):
    """A spanwise wing slab from s0 to s1 (0 root, 1 tip, outward = +X), between chord fractions."""
    def w(c):
        s = s0 + (c.x + 0.5) * (s1 - s0)
        f = chord[0] + (c.y + 0.5) * (chord[1] - chord[0])
        a, b = le(s), te(s)
        along, across = WING * s, c.z * thick(s)
        return Vector((ROOT[0] + along * math.cos(FOLD) - CURL * s * s + across * math.sin(FOLD), a + f * (b - a) + SWEEP * s,
                       ROOT[1] - along * math.sin(FOLD) + across * math.cos(FOLD)))
    p.add(K.box((1, 1, 1), bevel=0.05, warp=w), zone)


def wing_maker(left):
    tip = lambda s: 0.1 * max(0.0, (s - 0.8) / 0.2) ** 2      # the chord rounds off over the last 20 %
    le = lambda s: -0.5 + 0.3 * s * s + tip(s)
    te = lambda s: 0.5 - 0.18 * s - 0.2 * s ** 3 - tip(s)
    th = lambda s: 0.2 - 0.1 * s

    def make(p):
        _span(p, 0.0, 0.43, le, te, th, "grey", (0.0, 0.84))
        _span(p, 0.0, 0.43, le, te, lambda s: th(s) * 0.92, "white", (0.8, 1.0))
        _span(p, 0.415, 0.85, le, te, lambda s: th(s) * 0.98, "black")     # rounded black tip, r4 0.45 of the span, r5 1.3x
        _span(p, 0.83, 1.0, le, te, lambda s: th(s) * 0.88, "black")
        if not left:          # authored for the left wing (outward = Blender +X)
            K.mirror_x(p.bm)
    return make


def tail(p):
    p.add(K.box((0.74, 0.6, 0.09), (0, -0.08, 0), bevel=0.04, taper=("y", 0.55, 1.0)), "white")


def leg(p):
    p.add(K.box((0.224, 0.224, 0.48), bevel=0.05, seg=2, taper=("z", 0.85, 1.0)), "yellow")   # r2: 20 % shorter, r4: 1.4x thicker


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
HEAD = 1.15      # r4: head cluster +15 % about the Head...
DROP = 0.055     # ...and down so its stud stays inside the 2.7 stud band
_H = PARTS[2][2]


def _grown(mk):
    def make(p):
        mk(p)
        bmesh.ops.scale(p.bm, vec=(HEAD, HEAD, HEAD), verts=p.bm.verts)
    return make


def _r4(n, pn, pos, ang, mk, rf):
    if n == "Head" or n.startswith(("Beak", "Eye", "Glint")):
        pos = tuple(_H[i] + (pos[i] - _H[i]) * HEAD - (DROP if i == 1 else 0) for i in range(3))
        mk = _grown(mk)
    return n, pn, pos, ang, mk, rf


PARTS = [_r4(*p) for p in PARTS]
SCALE = 1.25     # r3: top of the 2.3-2.7 stud band (r2 1.2)


def build():
    parts = [dict(node=n, part=pn, index=i + 1, cframe=K.cf(pos, *ang), roblox=(pos, ang), make=mk, refine=rf)
             for i, (n, pn, pos, ang, mk, rf) in enumerate(PARTS)]
    spec = K.build_asset(ASSET, PREFIX, "Gull", "Feathers", ZONES, parts, HERE, fbx_name="M_Ani_Gull", scale=SCALE, smooth=40, under=0.25, extra_mapping={
        "source": "src/shared/Config/Wildlife.luau Species.Gull.parts (index = position in that list)",
        "rare": "the snow-gull palette is not in this atlas (needs a second ALB or a tinted copy)"})
    spec["waivers"]["UV faces"] = "per-face swatch UVs are tiny squares; LOD collapse of the head stud leaves a face with no UV area"
    return spec
