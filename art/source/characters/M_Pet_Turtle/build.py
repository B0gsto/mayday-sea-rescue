"""M_Pet_Turtle: green sea turtle pet, low-poly faceted (Bosun LP style), one mesh per WildlifeRig part.

The carapace is an elliptical dome grid split into scutes (5 vertebral, 4 costal a side, a marginal ring); each
scute is inset and raised so dark seams and lighter plate centres read from the chase camera.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/characters/M_Pet_Turtle/build.py --out-root build/prod/M_Pet_Turtle \
      --steps build,lod,validate,export,turntable
"""
import math
import os
import random
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_Pets"))
import petkit as K  # noqa: E402

ZONES = [  # name, top (faces up), bottom, roughness, tinted in the rare (golden) albedo
    ("skin", "#5E7A55", "#7F9A6E", 0.6, True),
    ("scale", "#8DA371", "#9DB07F", 0.6, True),
    ("cream", "#D9D2AE", "#CFC59D", 0.7, True),
    ("scute", "#56703F", "#647E49", 0.45, True),
    ("scuteLight", "#8C9C5A", "#94A363", 0.45, True),
    ("seam", "#33402A", "#2E3A26", 0.6, True),
    ("rim", "#4A5E36", "#56693F", 0.5, True),
    ("plastron", "#D8CFA2", "#C9BE8E", 0.65, True),
    ("eye", "#202026", "#202026", 0.1, False),
    ("glint", "#F0F0F0", "#F0F0F0", 0.2, False),
]
RARE = ("#6E8A62", "#DAAA46")   # the skin's mid green -> Wildlife rarePalette.Shell (golden turtle)


def shell():
    nu, nv, h, base = 10, 12, 0.62, -0.33
    bm = bmesh.new()
    grid = {}
    for j in range(nv + 1):
        for i in range(nu + 1):
            u, v = -1 + 2.0 * i / nu, -1 + 2.0 * j / nv
            x, z = u * math.sqrt(1 - v * v / 2), v * math.sqrt(1 - u * u / 2)
            y = base + h * max(0.0, 1 - x * x - z * z) ** 0.55
            grid[i, j] = bm.verts.new((x * 1.1 * (1 - 0.1 * max(0.0, z)), y, z * 1.3))
    scutes = {}
    for j in range(nv):
        for i in range(nu):
            f = bm.faces.new((grid[i, j], grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1]))
            uc, vc = -1 + 2.0 * (i + 0.5) / nu, -1 + 2.0 * (j + 0.5) / nv
            if i in (0, nu - 1) or j in (0, nv - 1):
                key = ("m", i // 2, j // 2)                       # marginal: one plate per 2 rim cells
            elif abs(uc) < 0.4:
                key = ("v", int((vc + 1 - 2.0 / nv) / (2 - 4.0 / nv) * 5))
            else:
                key = ("c", uc > 0, int((vc + 1 - 2.0 / nv) / (2 - 4.0 / nv) * 4))
            scutes.setdefault(key, []).append(f)
    bm.normal_update()
    zones = {}
    for key, faces in scutes.items():
        centre = sum((f.calc_center_median() for f in faces), Vector()) / len(faces)
        reach = max((f.calc_center_median() - centre).length for f in faces) or 1.0
        for f in faces:
            light = (f.calc_center_median() - centre).length < 0.55 * reach
            zones[f] = "rim" if key[0] == "m" else ("scuteLight" if light else "scute")
        bmesh.ops.inset_region(bm, faces=faces, thickness=0.025, depth=0.015, use_even_offset=True)
    edge = [e for e in bm.edges if e.is_boundary]
    new = bmesh.ops.extrude_edge_only(bm, edges=edge)["geom"]
    for v in new:
        if isinstance(v, bmesh.types.BMVert):
            v.co = Vector((v.co.x * 1.03, base - 0.08, v.co.z * 1.03))
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    return K.Shape().add(bm, lambda f: zones.get(f, "seam"))


def plastron():
    pts = [(0.9 * math.sin(a), 1.1 * math.cos(a)) for a in (2 * math.pi * k / 10 for k in range(10))]
    return K.Shape().add(K.lens(pts, 0.24), "plastron")


def _skin(rng, share=0.22):
    return K.speckle(rng, share, "scale", K.by([(lambda c, n: n.y < -0.45, "cream")], "skin"))


def head():
    rng = random.Random(3)

    def beak(c):
        t = max(0.0, -c.z - 0.2) / 0.25
        return (c.x * (1 - 0.1 * t), c.y - 0.06 * t, c.z)
    s = K.Shape().add(K.deform(K.ellipsoid((0.78, 0.66, 0.9), u=12, v=8), beak), _skin(rng))
    return s.add(K.ellipsoid((0.6, 0.52, 0.7), (0, -0.05, 0.45), u=10, v=6), _skin(rng, 0.2))


def eye():
    return K.Shape().add(K.ellipsoid((0.24, 0.24, 0.2), u=12, v=6), "eye")


def glint():
    return K.Shape().add(K.ellipsoid((0.08, 0.08, 0.04), u=8, v=4), "glint")


FRONT = [(-0.72, -0.12), (-0.35, -0.34), (0.2, -0.32), (0.62, -0.16), (0.76, 0.06), (0.55, 0.2), (0.0, 0.3),
         (-0.5, 0.3), (-0.75, 0.12)]
BACK = [(-0.45, -0.2), (0.05, -0.28), (0.42, -0.15), (0.5, 0.08), (0.3, 0.26), (-0.2, 0.26), (-0.48, 0.08)]


def flipper(outline, thick, side, seed):
    return lambda: K.Shape().add(K.lens([(x * side, z) for x, z in outline], thick), _skin(random.Random(seed), 0.25))


def tail():
    bm = K.cone(0.16, 0.02, 0.6, segments=6)
    K.deform(bm, lambda c: (c.x, c.y * 0.6, c.z))
    return K.Shape().add(bm, "skin")


PARTS = [  # node, rig name, placeholder size, at (x, y, z, rx, ry, rz), shape: Wildlife.Species.Turtle.parts order
    ("Shell", "Shell", (2.3, 0.75, 2.7), (0, 0.98, 0), shell),
    ("Plastron", "Plastron", (1.9, 0.26, 2.2), (0, 0.58, 0), plastron),
    ("Head", "Head", (0.85, 0.75, 0.8), (0, 0.95, -1.62), head),
    ("EyeLeft", "Eye", (0.22, 0.22, 0.22), (-0.28, 1.1, -1.98), eye),
    ("EyeRight", "Eye", (0.22, 0.22, 0.22), (0.28, 1.1, -1.98), eye),
    ("GlintLeft", "Glint", (0.07, 0.07, 0.07), (-0.24, 1.15, -2.1), glint),
    ("GlintRight", "Glint", (0.07, 0.07, 0.07), (0.24, 1.15, -2.1), glint),
    ("FlipperFrontLeft", "Flipper", (1.5, 0.16, 0.85), (-1.3, 0.6, -0.85, 0, 0.25, 0.2), flipper(FRONT, 0.16, -1, 1)),
    ("FlipperFrontRight", "Flipper", (1.5, 0.16, 0.85), (1.3, 0.6, -0.85, 0, -0.25, -0.2), flipper(FRONT, 0.16, 1, 2)),
    ("FlipperBackLeft", "Flipper", (1.0, 0.14, 0.6), (-1.05, 0.55, 0.95, 0, -0.2, 0.15), flipper(BACK, 0.13, -1, 3)),
    ("FlipperBackRight", "Flipper", (1.0, 0.14, 0.6), (1.05, 0.55, 0.95, 0, 0.2, -0.15), flipper(BACK, 0.13, 1, 4)),
    ("Tail", "Tail", (0.4, 0.2, 0.62), (0, 0.62, 1.5), tail),
]
PARTS = [(n, r, s, tuple(at) + (0.0,) * (6 - len(at)), fn) for n, r, s, at, fn in PARTS]


def build():
    face = [{"name": "face", "target": [0.0, -1.8, 1.0], "dist": 4.5, "az": 25, "el": 15}]
    return K.build("M_Pet_Turtle", "Turtle", PARTS, ZONES, RARE, face)
