"""M_Pet_SealPup: grey seal pup pet, low-poly faceted (Bosun LP style), one mesh per WildlifeRig part.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/characters/M_Pet_SealPup/build.py --out-root build/prod/M_Pet_SealPup \
      --steps build,lod,validate,export,turntable
"""
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_Pets"))
import petkit as K  # noqa: E402

ZONES = [  # name, top (faces up), bottom, roughness, tinted in the rare (golden) albedo
    ("fur", "#76808E", "#A3ABB6", 0.7, True),
    ("belly", "#D3D9DD", "#C2C9CF", 0.75, True),
    ("muzzle", "#E6EAEA", "#D2D7DA", 0.75, True),
    ("dot", "#4A505A", "#4A505A", 0.75, True),
    ("whisker", "#EEEEE8", "#E2E2DC", 0.5, False),
    ("nose", "#2C2C32", "#202026", 0.35, False),
    ("eye", "#202026", "#202026", 0.1, False),
    ("glint", "#F0F0F0", "#F0F0F0", 0.2, False),
    ("flipper", "#66707C", "#7A8390", 0.65, True),
]
RARE = ("#8A94A2", "#E6B852")   # the coat's mid grey -> Wildlife rarePalette.Body (golden seal)


def body():
    def shape(c):
        t = max(0.0, c.z) / 1.2
        c.x *= 1.0 - 0.28 * t
        c.y = c.y * (1.0 - 0.18 * t) - 0.1 * t + (0.08 * -c.z / 1.2 if c.z < 0 else 0.0)
        c.y = max(c.y, -0.5)
        return c
    bm = K.deform(K.ellipsoid((2.1, 1.3, 2.4), u=16, v=8), shape)
    zone = K.by([(lambda c, n: n.y < -0.5, "belly")], "fur")
    neck = K.ellipsoid((1.35, 1.15, 1.2), (0, 0.4, -0.85), u=12, v=6)
    return K.Shape().add(bm, zone).add(neck, K.by([(lambda c, n: n.y < -0.4, "belly")], "fur"))


def belly():
    return K.Shape().add(K.ellipsoid((1.7, 0.6, 2.1), u=12, v=6), "belly")


def head():
    bm = K.ellipsoid((1.3, 1.12, 1.2), u=12, v=8)
    return K.Shape().add(bm, K.by([(lambda c, n: n.y < -0.55, "belly")], "fur"))


def snout():
    rng = random.Random(4)
    s = K.Shape()
    for x in (-0.16, 0.16):
        s.add(K.ellipsoid((0.4, 0.38, 0.42), (x, 0.0, 0.0), u=10, v=6), K.speckle(rng, 0.15, "dot", "muzzle"))
    s.add(K.ellipsoid((0.34, 0.2, 0.3), (0, -0.17, 0.06), u=8, v=4), "muzzle")
    for side in (-1, 1):
        for y, dy in ((0.05, 0.08), (-0.03, 0.0), (-0.11, -0.08)):
            s.add(K.whisker((0.3 * side, y, -0.04), (0.66 * side, y + dy, 0.1)), "whisker")
    return s


def nose():
    bm = K.ellipsoid((0.24, 0.15, 0.13), u=8, v=4)
    K.deform(bm, lambda c: (c.x * (1.0 + 0.5 * max(0.0, c.y) / 0.075), c.y, c.z))
    return K.Shape().add(bm, "nose")


def eye():
    return K.Shape().add(K.ellipsoid((0.36, 0.36, 0.3), u=12, v=6), "eye")


def glint():
    return K.Shape().add(K.ellipsoid((0.12, 0.12, 0.06), u=8, v=4), "glint")


PADDLE = [(-0.40, -0.30), (-0.05, -0.52), (0.30, -0.42), (0.48, -0.08), (0.44, 0.30), (0.18, 0.55),
          (-0.20, 0.48), (-0.45, 0.12)]


def flipper(side):
    return lambda: K.Shape().add(K.lens([(x * side, z) for x, z in PADDLE], 0.17), "flipper")


def tail():
    s = K.Shape()
    lobe = [(-0.16, -0.35), (0.12, -0.35), (0.22, 0.1), (0.12, 0.45), (-0.12, 0.45), (-0.22, 0.1)]
    for side in (-1, 1):
        bm = K.lens([(x * side, z) for x, z in lobe], 0.14)
        K.rotate(bm, ry=0.38 * side)
        s.add(K.move(bm, (0.17 * side, 0, 0.05)), "flipper")
    s.add(K.ellipsoid((0.5, 0.2, 0.45), (0, 0, -0.35), u=8, v=4), "flipper")
    return s


PARTS = [  # node, rig name, placeholder size, at (x, y, z, rx, ry, rz), shape: Wildlife.Species.SealPup.parts order
    ("Body", "Body", (2.8, 1.4, 1.9), (0, 0.95, 0), body),
    ("Belly", "Belly", (2.3, 0.7, 1.5), (0, 0.55, -0.1), belly),
    ("Head", "Head", (1.3, 1.15, 1.2), (0, 1.55, -1.45), head),
    ("Snout", "Snout", (0.7, 0.5, 0.6), (0, 1.38, -2.05), snout),
    ("Nose", "Nose", (0.22, 0.18, 0.18), (0, 1.5, -2.36), nose),
    ("EyeLeft", "Eye", (0.3, 0.3, 0.3), (-0.38, 1.78, -1.98), eye),
    ("EyeRight", "Eye", (0.3, 0.3, 0.3), (0.38, 1.78, -1.98), eye),
    ("GlintLeft", "Glint", (0.1, 0.1, 0.1), (-0.32, 1.86, -2.14), glint),
    ("GlintRight", "Glint", (0.1, 0.1, 0.1), (0.32, 1.86, -2.14), glint),
    ("FlipperLeft", "Flipper", (1.0, 0.18, 1.3), (-1.05, 0.45, -0.55, 0, 0, 0.28), flipper(-1)),
    ("FlipperRight", "Flipper", (1.0, 0.18, 1.3), (1.05, 0.45, -0.55, 0, 0, -0.28), flipper(1)),
    ("Tail", "Tail", (0.95, 0.16, 1.0), (0, 0.5, 1.05, 0.2, 0, 0), tail),
]

PARTS = [(n, r, s, tuple(at) + (0.0,) * (6 - len(at)), fn) for n, r, s, at, fn in PARTS]


def build():
    face = [{"name": "face", "target": [0.0, -2.0, 1.6], "dist": 4.5, "az": 25, "el": 12}]
    return K.build("M_Pet_SealPup", "SealPup", PARTS, ZONES, RARE, face)
