"""M_Pet_Puffin: the Atlantic puffin pet, low-poly faceted (Bosun LP style).

One mesh per WildlifeRig part of Config/Wildlife.Species.Puffin, in the same order (duplicate names get
Left / Right: Left is Roblox -X). Each FBX node sits at its PartSpec `at` CFrame, so WildlifeRig can swap
the block Parts for MeshParts by index; M_Pet_Puffin.mapping.json lists node, part, index and CFrame.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/characters/M_Pet_Puffin/build.py --out-root build/prod/M_Pet_Puffin \
      --steps build,lod,validate,export,turntable
"""
import os
import sys

from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "_LP"))
import lpkit as K  # noqa: E402

ASSET = "M_Pet_Puffin"
PREFIX = "M_Ani_Puffin_"        # "Pet" is not a names.py category; nodes are renamed to the part names after validate

ZONES = {
    "black": dict(top="#454A57", bottom="#1E2027", rough=0.34),       # glossy toy plastic: a soft spec on the black (r2 stronger)
    "white": dict(top="#FAFAF6", bottom="#D3D6D7", rough=0.84),
    "face": dict(top="#EEEEEA", bottom="#C2C5C8", rough=0.84),
    "orange": dict(top="#FF6A14", bottom="#E2480C", rough=0.38, signal=True),
    "yellow": dict(top="#FFD21F", bottom="#EAAE10", rough=0.38, signal=True),
    "slate": dict(top="#6E8CAE", bottom="#4E6680", rough=0.5),
    "feet": dict(top="#FF8A2A", bottom="#DE6014", rough=0.6, signal=True),
    "eye": dict(top="#26262C", bottom="#141418", rough=0.12),
    "glint": dict(top="#FFFFFF", bottom="#F2F2F2", rough=0.1),
    "ring": dict(top="#D9503F", bottom="#B23A2E", rough=0.4, signal=True),
}


def _local(v):
    """Roblox rig-local vector -> Blender part-local."""
    return Vector((-v[0], v[2], v[1]))


def body(p):
    def w(c):
        if c.z > 0:
            k = 1.0 - 0.2 * (c.z / 0.81)
            c.x *= k
            c.y *= k
        return c
    p.add(K.ball((1.46, 1.3, 1.62), u=10, v=7, warp=w), "black")


def belly(p):
    p.add(K.ball((1.14, 0.92, 1.2), (0, 0, 0.02), u=10, v=7), "white")
    p.add(K.ball((1.26, 0.6, 1.32), (0, 0.02, 0.02), u=10, v=7), "white")    # r2: a 0.06 lip where the white meets the black


def head(p):
    p.add(K.ball((1.04, 1.0, 0.98), u=10, v=7), "black")
    p.add(K.cyl(0.13, 0.16, (0, 0.02, 0.52), sides=10), "black")      # a subtle Lego stud, base sunk in the crown


def face(p):
    # mostly inside the head: only the front cap shows, as the white puffin mask
    p.add(K.ball((0.96, 0.9, 0.76), (0, 0.3, -0.02), u=10, v=7), "face")


def _beak_seg(y0, y1, zone, p, puff=1.0):
    """One brick band of the beak; puff > 1 makes a band stand proud of its neighbours (a raised stripe)."""
    def w(c):
        y = y0 + (c.y + 0.5) * (y1 - y0)
        t = (0.3 - y) / 0.86
        width = (0.4 * (1 - t) + 0.24 * t) * puff        # r2: a wedge, tip 60 % of the base (was a flat plate)
        top = (0.38 - 0.43 * t ** 0.8) * puff
        bot = (-0.36 * (1 - t) - 0.12 * t) * puff
        return Vector((c.x * width, y, bot + (c.z + 0.5) * (top - bot)))
    p.add(K.box((1, 1, 1), bevel=0.06, seg=2, warp=w), zone)


def beak(p):
    # bands overlap 0.02 so every hidden end cap sits inside its proud neighbour (no shared planes)
    _beak_seg(0.3, 0.14, "slate", p)
    _beak_seg(0.16, 0.05, "yellow", p, 1.05)
    _beak_seg(0.07, -0.16, "orange", p)
    _beak_seg(-0.1, -0.33, "yellow", p, 1.06)     # r2: the yellow tip band ~25 % of the beak
    _beak_seg(-0.31, -0.56, "orange", p)


def eye_maker(pos):
    inward = _local(Vector((0, 2.0, -0.2)) - Vector(pos)).normalized()

    def make(p):
        p.add(K.ball((0.23, 0.21, 0.23), u=10, v=6), "eye")
        p.add(K.ball((0.255, 0.255, 0.255), inward * 0.05, u=10, v=6), "ring")
        p.add(K.ball((0.38, 0.38, 0.38), inward * 0.14, u=12, v=6), "white")   # r2: a 0.05 white eye rim
    return make


def glint(p):
    p.add(K.ball((0.09, 0.07, 0.09), u=6, v=4), "glint")


def wing_maker(s):
    """s = Roblox X side (-1 left). Tucked in and leaning against the body (the rig tilts the top outward)."""
    def make(p):
        def w(c):
            t = max(0.0, -c.z / 0.62)
            c.y = c.y * (1 - 0.35 * t) + 0.18 * t
            c.z += 0.12
            c.x += s * (0.28 + 0.1 * c.z)
            return c
        p.add(K.ball((0.22, 0.8, 1.25), u=8, v=6, warp=w), "black")
    return make


def foot(p):
    p.add(K.box((0.6, 0.8, 0.1), (0, -0.02, -0.02), bevel=0.04, seg=2, taper=("y", 1.0, 0.4)), "feet")
    for x in (-0.2, 0.0, 0.2):
        p.add(K.box((0.07, 0.12, 0.06), (x, -0.42, -0.01), bevel=0.0), "feet")
    p.add(K.box((0.17, 0.17, 0.32), (0, 0.22, 0.17), bevel=0.06, seg=2), "feet")


def tail(p):
    p.add(K.box((0.62, 0.5, 0.2), (0, 0.02, 0), bevel=0.07, seg=2, taper=("y", 1.0, 0.55), rot=[(-14, "X")]), "black")


# node, WildlifeRig part, Roblox position, angles, maker  (order = Wildlife.Species.Puffin.parts)
PARTS = [
    ("Body", "Body", (0, 1.05, 0), (0, 0, 0), body),
    ("Belly", "Belly", (0, 0.95, -0.35), (0, 0, 0), belly),
    ("Head", "Head", (0, 2.0, -0.2), (0, 0, 0), head),
    ("Face", "Face", (0, 2.0, -0.7), (0, 0, 0), face),
    ("Beak", "Beak", (0, 1.98, -1.03), (0, 0, 0), beak),
    ("EyeLeft", "Eye", (-0.34, 2.14, -0.72), (0, 0, 0), eye_maker((-0.34, 2.14, -0.72))),
    ("EyeRight", "Eye", (0.34, 2.14, -0.72), (0, 0, 0), eye_maker((0.34, 2.14, -0.72))),
    ("GlintLeft", "Glint", (-0.3, 2.2, -0.82), (0, 0, 0), glint),
    ("GlintRight", "Glint", (0.3, 2.2, -0.82), (0, 0, 0), glint),
    ("WingLeft", "Wing", (-0.9, 1.05, 0.1), (0, 0, 0.15), wing_maker(-1)),
    ("WingRight", "Wing", (0.9, 1.05, 0.1), (0, 0, -0.15), wing_maker(1)),
    ("FootLeft", "Foot", (-0.38, 0.14, -0.5), (0, 0, 0), foot),
    ("FootRight", "Foot", (0.38, 0.14, -0.5), (0, 0, 0), foot),
    ("Tail", "Tail", (0, 0.9, 0.76), (0, 0, 0), tail),
]


def build():
    parts = [dict(node=n, part=pn, index=i + 1, cframe=K.cf(pos, *ang), roblox=(pos, ang), make=mk)
             for i, (n, pn, pos, ang, mk) in enumerate(PARTS)]
    spec = K.build_asset(ASSET, PREFIX, "Puffin", "Feathers", ZONES, parts, HERE, fbx_name="M_Ani_Puffin", scale=1.2, smooth=40, extra_mapping={
        "source": "src/shared/Config/Wildlife.luau Species.Puffin.parts (index = position in that list)",
        "rare": "the albino palette is not in this atlas (needs a second ALB or a tinted copy)"})
    spec["waivers"]["UV faces"] = "per-face swatch UVs are tiny squares; LOD collapse of the head stud leaves a face with no UV area"
    return spec
