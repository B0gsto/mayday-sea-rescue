"""M_Pet_Otter: Eurasian otter pet, low-poly faceted (Bosun LP style), one mesh per WildlifeRig part.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/characters/M_Pet_Otter/build.py --out-root build/prod/M_Pet_Otter \
      --steps build,lod,validate,export,turntable
"""
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_Pets"))
import petkit as K  # noqa: E402

ZONES = [  # name, top (faces up), bottom, roughness, tinted in the rare (silver) albedo
    ("fur", "#61493A", "#8A6B52", 0.55, True),
    ("furLight", "#9C7F66", "#A88C72", 0.6, True),
    ("furDark", "#4A3A30", "#3E3129", 0.6, True),
    ("cream", "#DCCDB5", "#CBB89D", 0.7, True),
    ("paw", "#4A3B31", "#3F322A", 0.6, True),
    ("dot", "#7A6450", "#7A6450", 0.7, True),
    ("whisker", "#E8E2D6", "#DCD6CA", 0.5, False),
    ("nose", "#2A2624", "#24201F", 0.35, False),
    ("eye", "#202026", "#202026", 0.1, False),
    ("glint", "#F0F0F0", "#F0F0F0", 0.2, False),
]
RARE = ("#765A46", "#B0B6BE")   # the coat's mid brown -> Wildlife rarePalette.Body (silver otter)

FOOT = [(-0.17, -0.28), (0.0, -0.32), (0.17, -0.28), (0.2, 0.05), (0.12, 0.25), (-0.12, 0.25), (-0.2, 0.05)]


def _foot(s, at, toes=True):
    s.add(K.lens([(x + at[0], z + at[2]) for x, z in FOOT], 0.14, y=at[1]), "paw")
    if toes:
        for x in (-0.12, -0.04, 0.04, 0.12):
            s.add(K.ellipsoid((0.08, 0.07, 0.1), (at[0] + x, at[1] + 0.01, at[2] - 0.3), u=6, v=3), "paw")


def body():
    def shape(c):
        t = max(0.0, -c.z - 0.5) / 0.95
        return (c.x * (1.0 - 0.15 * t), c.y + 0.15 * t, c.z)
    under = K.by([(lambda c, n: n.y < -0.3 and c.z < 0.0, "cream"), (lambda c, n: n.y < -0.5, "furLight")], "fur")
    s = K.Shape().add(K.deform(K.ellipsoid((1.1, 0.88, 2.9), u=12, v=8), shape), under)
    s.add(K.ellipsoid((0.8, 0.75, 0.9), (0, 0.3, -1.15), u=10, v=6), under)
    for x in (-0.38, 0.38):
        s.add(K.ellipsoid((0.42, 0.5, 0.6), (x, -0.22, 0.85), u=8, v=5), "fur")
        _foot(s, (x, -0.47, 0.8), toes=False)
    return s


def tummy():
    return K.Shape().add(K.ellipsoid((0.9, 0.42, 1.9), u=10, v=5),
                         K.by([(lambda c, n: c.z < -0.3, "cream")], "furLight"))


def head():
    bm = K.deform(K.ellipsoid((1.02, 0.82, 0.98), u=12, v=8), lambda c: (c.x, c.y * 0.85 if c.y > 0 else c.y, c.z))
    return K.Shape().add(bm, K.by([(lambda c, n: n.y < -0.3, "cream")], "fur"))


def muzzle():
    rng = random.Random(5)
    s = K.Shape()
    cheek = K.speckle(rng, 0.12, "dot", K.by([(lambda c, n: n.y > 0.6, "fur")], "cream"))
    for x in (-0.13, 0.13):
        s.add(K.ellipsoid((0.34, 0.32, 0.4), (x, 0.0, 0.0), u=10, v=6), cheek)
    s.add(K.ellipsoid((0.28, 0.16, 0.28), (0, -0.15, 0.04), u=8, v=4), "cream")
    for side in (-1, 1):
        for y, dy in ((0.05, 0.07), (-0.02, 0.0), (-0.09, -0.07)):
            s.add(K.whisker((0.26 * side, y, -0.04), (0.58 * side, y + dy, 0.08), w=0.02), "whisker")
    return s


def nose():
    bm = K.ellipsoid((0.22, 0.14, 0.13), u=8, v=4)
    K.deform(bm, lambda c: (c.x * (1.0 + 0.4 * max(0.0, c.y) / 0.07), c.y, c.z))
    return K.Shape().add(bm, "nose")


def eye():
    return K.Shape().add(K.ellipsoid((0.26, 0.26, 0.22), u=12, v=6), "eye")


def glint():
    return K.Shape().add(K.ellipsoid((0.09, 0.09, 0.05), u=8, v=4), "glint")


def ear(side):
    """side -1 = the animal's left (x < 0); the ear sinks inward and down into the head."""
    return lambda: K.Shape().add(K.ellipsoid((0.26, 0.24, 0.13), (-0.06 * side, -0.1, 0), u=8, v=4),
                                 K.by([(lambda c, n: n.z < -0.6, "furDark")], "fur"))


def paw():
    s = K.Shape().add(K.ellipsoid((0.3, 0.42, 0.34), (0, 0.12, 0.06), u=8, v=5), "fur")
    _foot(s, (0, -0.08, 0.0))
    return s


def tail():
    bm = K.cone(0.26, 0.04, 1.9, segments=8)
    K.deform(bm, lambda c: (c.x, c.y * 0.8 - 0.1 * ((c.z + 0.95) / 1.9) ** 2, c.z))
    return K.Shape().add(bm, "fur")


PARTS = [  # node, rig name, placeholder size, at (x, y, z, rx, ry, rz), shape: Wildlife.Species.Otter.parts order
    ("Body", "Body", (2.5, 0.95, 1.15), (0, 0.85, 0), body),
    ("Tummy", "Tummy", (1.9, 0.5, 0.95), (0, 0.52, -0.1), tummy),
    ("Head", "Head", (1.05, 1.0, 1.0), (0, 1.35, -1.55), head),
    ("Muzzle", "Muzzle", (0.62, 0.46, 0.52), (0, 1.22, -2.02), muzzle),
    ("Nose", "Nose", (0.2, 0.16, 0.16), (0, 1.32, -2.28), nose),
    ("EyeLeft", "Eye", (0.28, 0.28, 0.28), (-0.3, 1.52, -1.95), eye),
    ("EyeRight", "Eye", (0.28, 0.28, 0.28), (0.3, 1.52, -1.95), eye),
    ("GlintLeft", "Glint", (0.09, 0.09, 0.09), (-0.25, 1.58, -2.1), glint),
    ("GlintRight", "Glint", (0.09, 0.09, 0.09), (0.25, 1.58, -2.1), glint),
    ("EarLeft", "Ear", (0.32, 0.26, 0.16), (-0.42, 1.76, -1.45), ear(-1)),
    ("EarRight", "Ear", (0.32, 0.26, 0.16), (0.42, 1.76, -1.45), ear(1)),
    ("PawLeft", "Paw", (0.42, 0.26, 0.7), (-0.52, 0.38, -1.1), paw),
    ("PawRight", "Paw", (0.42, 0.26, 0.7), (0.52, 0.38, -1.1), paw),
    ("Tail", "Tail", (0.52, 0.36, 1.9), (0, 0.78, 1.75, 0.16, 0, 0), tail),
]
PARTS = [(n, r, s, tuple(at) + (0.0,) * (6 - len(at)), fn) for n, r, s, at, fn in PARTS]


def build():
    face = [{"name": "face", "target": [0.0, -1.9, 1.4], "dist": 4.5, "az": 25, "el": 12}]
    return K.build("M_Pet_Otter", "Otter", PARTS, ZONES, RARE, face)
