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
    ("skin", "#5A8A47", "#7FA866", 0.6, True),         # r2: ~+20 % saturation, brighter Lego greens
    ("scale", "#8DB463", "#9DC070", 0.6, True),
    ("cream", "#E2D8A8", "#D4C792", 0.7, True),
    ("scute", "#408833", "#35752A", 0.45, True),      # r4: shell 15 % darker
    ("scuteLight", "#5DA142", "#54963B", 0.45, True),
    ("vert", "#5BA648", "#4F9A3E", 0.45, True),       # r5: the lighter centre row
    ("vertLight", "#78BC5C", "#6CB052", 0.45, True),
    ("seam", "#244E20", "#1F431D", 0.6, True),        # r3: dark green, not black
    ("rim", "#31752B", "#3A8031", 0.5, True),
    ("plastron", "#E2D49C", "#D2C185", 0.65, True),
    ("bellyRim", "#E6CF86", "#D9BF72", 0.5, True),    # r3: cream/tan plastron edge
    ("skinDark", "#3B5E2E", "#34522A", 0.6, True),     # r2: darker flipper tips
    ("headSkin", "#A4C440", "#B2CE55", 0.6, True),    # r4: yellow-green head
    ("headScale", "#AECA4C", "#BAD25E", 0.6, True),
    ("stud", "#C8E86A", "#B4D858", 0.45, True),       # r4: the ridge studs pop off the darker shell
    ("eye", "#1C1C22", "#1C1C22", 0.08, False),
    ("glint", "#F0F0F0", "#F0F0F0", 0.2, False),
]
RARE = ("#6C9956", "#DAAA46")   # the skin's mid green -> Wildlife rarePalette.Shell (golden turtle)


def shell():
    nu, nv, h, base = 10, 12, 0.9, -0.38      # r3: dome 1.4x higher; r5: hull +15 % (0.87 -> plates at 1.0), sunk 0.05 to stay under 2.7
    # r5: plates 25 % larger: rows -> plate index (4 vertebral, 3 costal a side, wider marginals), front-back symmetric
    vert, costal, rim_u = (0, 0, 1, 1, 1, 2, 2, 2, 3, 3), (0, 0, 0, 1, 1, 1, 1, 2, 2, 2), (0, 0, 0, 1, 1, 2, 2, 3, 3, 3)
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
            uc = -1 + 2.0 * (i + 0.5) / nu
            if i in (0, nu - 1) or j in (0, nv - 1):
                key = ("m", rim_u[i], j // 3)
            elif abs(uc) < 0.4:
                key = ("v", vert[j - 1])
            else:
                key = ("c", uc > 0, costal[j - 1])
            scutes.setdefault(key, []).append(f)
    bm.normal_update()                                    # the grid winding faces down: depth < 0 raises, normals negate
    zones, tops = {}, {}
    plate = {"m": ("rim", "rim"), "v": ("vert", "vertLight"), "c": ("scute", "scuteLight")}
    for key, faces in scutes.items():
        centre = sum((f.calc_center_median() for f in faces), Vector()) / len(faces)
        reach = max((f.calc_center_median() - centre).length for f in faces) or 1.0
        for f in faces:
            light = (f.calc_center_median() - centre).length < 0.55 * reach
            zones[f] = plate[key[0]][light]
        bmesh.ops.inset_region(bm, faces=faces, thickness=0.07, depth=-0.08, use_even_offset=True)   # raised tiles (r5: were sunk), r3: seams 1.5x wider, r5: wider again
        lip = bmesh.ops.inset_region(bm, faces=faces, thickness=0.03, depth=-0.02, use_even_offset=True)["faces"]
        for f in lip:                                     # r2: a 0.03 chamfer round each plate top, plate-coloured
            zones[f] = plate[key[0]][0]
        if key[0] == "v":
            n = -sum((f.normal for f in faces), Vector()).normalized()
            tops[key[1]] = (sum((f.calc_center_median() for f in faces), Vector()) / len(faces), n)
    edge = [e for e in bm.edges if e.is_boundary]
    new = bmesh.ops.extrude_edge_only(bm, edges=edge)["geom"]
    for f in new:
        if isinstance(f, bmesh.types.BMFace):
            zones[f] = "bellyRim"                         # the yellow-green skirt under the shell
    for v in new:
        if isinstance(v, bmesh.types.BMVert):
            tx, tz = v.co.x / (1.1 * (1 - 0.1 * max(0.0, v.co.z / 1.3))), v.co.z / 1.3     # back on the unit circle
            r = math.hypot(tx, tz) or 1.0
            # r4: tan rim on a clean ellipse: the raised rim plates overhang anything closer; r5: 1.3x
            v.co = Vector((tx / r * 1.1 * (1 - 0.1 * max(0.0, tz / r)) * 1.13, base - 0.234, tz / r * 1.3 * 1.13))
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    s = K.Shape().add(bm, lambda f: zones.get(f, "seam"))
    for k in (0, 3):                                      # r2: three studs on the centre ridge only
        c, n = tops[k]
        st = K.stud((0, 0, 0), r=0.18, h=0.12, segments=12)
        bmesh.ops.rotate(st, verts=st.verts, cent=Vector(), matrix=Vector((0, 1, 0)).rotation_difference(n).to_matrix())
        s.add(K.move(st, c), "stud")
    # r5: 4 plates, so the big centre stud straddles the middle seam: sunk past the groove floor
    return s.add(K.move(K.stud((0, 0, 0), r=0.32, h=0.12, sink=0.14, segments=12), (tops[1][0] + tops[2][0]) * 0.5), "stud")


def plastron():
    pts = [(1.0 * math.sin(a), 1.2 * math.cos(a)) for a in (2 * math.pi * k / 10 for k in range(10))]
    rim = lambda f: "bellyRim" if (f.calc_center_median().x / 1.0) ** 2 + (f.calc_center_median().z / 1.2) ** 2 > 0.6 else "plastron"
    return K.Shape().add(K.lens(pts, 0.24, y=-0.13), rim)      # r5: 0.13 down, still below the taller skirt's cap


def _skin(rng, share=0.22, skin="skin", scale="scale"):
    return K.speckle(rng, share, scale, K.by([(lambda c, n: n.y < -0.45, "cream")], skin))


def head():
    rng = random.Random(3)

    def beak(c):
        t = max(0.0, -c.z - 0.2) / 0.25
        return (c.x * (1 - 0.1 * t), c.y - 0.06 * t, c.z)
    s = K.Shape().add(K.deform(K.ellipsoid((0.9, 0.76, 1.03), u=12, v=8), beak), _skin(rng, 0.22, "headSkin", "headScale"))     # 1.15x: cuter
    return s.add(K.ellipsoid((0.66, 0.57, 0.75), (0, -0.05, 0.5), u=10, v=6), _skin(rng, 0.2, "headSkin", "headScale"))


def eye():
    return K.Shape().add(K.ellipsoid((0.3, 0.3, 0.24), u=12, v=6), "eye")


def glint():
    return K.Shape().add(K.ellipsoid((0.1, 0.1, 0.05), u=8, v=4), "glint")


def _shorter(outline, x0, k=0.75):
    """r4: 25 % shorter past the shell edge x0 (the part hidden under the shell doesn't count)."""
    return [(x0 + (x - x0) * k, z) for x, z in outline]


# r5: 15 % shorter again, a blunt rounded tip
FRONT = _shorter([(-0.72, -0.12), (-0.35, -0.34), (0.2, -0.32), (0.58, -0.25), (0.76, -0.06), (0.74, 0.12), (0.52, 0.26),
                  (0.0, 0.3), (-0.5, 0.3), (-0.75, 0.12)], -0.2, 0.6375)
BACK = _shorter([(-0.45, -0.2), (0.05, -0.28), (0.42, -0.15), (0.5, 0.08), (0.3, 0.26), (-0.2, 0.26), (-0.48, 0.08)], 0.05)


def flipper(outline, thick, side, seed):
    tip = 0.45 * max(x for x, _z in outline)            # outline +x is the outward tip
    dark = K.by([(lambda c, n: c.x * side > tip, "skinDark")], _skin(random.Random(seed), 0.12))
    return lambda: K.Shape().add(K.lens([(x * side, z) for x, z in outline], thick, rings=K.CHUNKY), dark)


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
    ("FlipperFrontLeft", "Flipper", (1.5, 0.16, 0.85), (-1.3, 0.6, -0.85, 0, 0.25, 0.2), flipper(FRONT, 0.368, -1, 1)),
    ("FlipperFrontRight", "Flipper", (1.5, 0.16, 0.85), (1.3, 0.6, -0.85, 0, -0.25, -0.2), flipper(FRONT, 0.368, 1, 2)),
    ("FlipperBackLeft", "Flipper", (1.0, 0.14, 0.6), (-1.05, 0.55, 0.95, 0, -0.2, 0.15), flipper(BACK, 0.42, -1, 3)),
    ("FlipperBackRight", "Flipper", (1.0, 0.14, 0.6), (1.05, 0.55, 0.95, 0, 0.2, -0.15), flipper(BACK, 0.42, 1, 4)),
    ("Tail", "Tail", (0.4, 0.2, 0.62), (0, 0.62, 1.5), tail),
]
PARTS = [(n, r, s, tuple(at) + (0.0,) * (6 - len(at)), fn) for n, r, s, at, fn in PARTS]

SCALE = 1.45     # r2 1.2; flat, so the read comes from the dome and the raised head rather than from the height
HEAD = 1.3       # r3: head cluster 1.3x about the Head part...
EYE = 1.2        # ...eyes (and their glints) another 1.2x...
LIFT = 0.21      # ...head + front flippers up 0.3 studs after SCALE...
HEAD_UP = 0.116  # ...r4: the head alone 10 % higher again
_H = PARTS[2][3]
_EYES = {n: at for n, _r, _s, at, _f in PARTS if n.startswith("Eye")}


def _grown(fn, k):
    def shape():
        s = fn()
        s.verts = [v * k for v in s.verts]
        return s
    return shape


def _r3(n, r, s, at, fn):
    pos = list(at[:3])
    if n == "Head" or n.startswith(("Eye", "Glint")):
        if n.startswith("Glint"):         # stays on the grown eye
            e = _EYES["Eye" + n[5:]]
            pos = [e[i] + (pos[i] - e[i]) * EYE for i in range(3)]
        pos = [_H[i] + (pos[i] - _H[i]) * HEAD for i in range(3)]
        fn = _grown(fn, HEAD if n == "Head" else HEAD * EYE)
    if n == "Head" or n.startswith(("Eye", "Glint", "FlipperFront")):
        pos[1] += LIFT
    if n == "Head" or n.startswith(("Eye", "Glint")):
        pos[1] += HEAD_UP
    return n, r, s, tuple(pos) + tuple(at[3:]), fn


PARTS = [_r3(*p) for p in PARTS]


def build():
    face = [{"name": "face", "target": [0.0, -2.75, 1.9], "dist": 6.5, "az": 25, "el": 15}]
    return K.build("M_Pet_Turtle", "Turtle", PARTS, ZONES, RARE, face, scale=SCALE, smooth=40, under=0.25)
