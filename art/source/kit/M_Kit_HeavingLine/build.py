"""M_Kit_HeavingLine: weighted heaving line for the tow kit (docs/12 2.8 rescue kit, E2, P0 Op 2).

A working heaving line as it comes off the boat: about 12 m of 6 mm floating polypropylene line (the class in
art/reference/M_Kit_HeavingLine/dims.md is 20 to 25 m; see the budget note) coiled on deck in ten large throwing
loops, two wide over five layers, seized with twine at -X, its free end drawn out under the coil to a spliced eye
on the deck at +X, and a 61 mm woven monkey's fist resting on the bundle at the throwing end with its short worked
end left hanging over the bundle onto the deck.

All geometry through tools/blender/rope.py (the docs/12 2.8 row's own source). The tubes are plain: over 12 m the
budget cannot resolve a three-strand or braid twist geometrically, so rope.py's documented fallback applies and
the tiling rope trim carries the strand look (U once round the rope, V one tile per circumference). maketex.py
paints T_Rope_Poly_* (dry + _Wet) - rope.py's braid trim tinted sun-bleached yellow and worn - into the out-root
before validate looks for the maps. Spec set: rope trim, one unique set (docs/12 row).

Budget: the docs/12 2.8 row says coils 1,500 to 2,500 tris; the build uses the small_prop class cap of 3,000 (the
raise HP2a made for its rope props: "above the docs/12 row for fidelity, class cap 3000"). small_prop is the class
the row's siblings use (M_Hbr_Rope_Coil / _Flaked), and here it is a hard constraint rather than a preference: the
lod step's collapse decimation cannot take a rope tube below about one ring per 0.15 m, i.e. about 84 triangles
per coil turn, so a LOD2 (25 %) of any coil is out of reach, and a 50 % LOD1 only works while the coil stays near
ten turns. Ten throwing loops are what keeps the fist, the spliced eye and a 50 % LOD1 inside 3,000 tris: a coil
of the full 20 to 25 m would need about twenty loops, whose LOD1 target falls under that decimation floor, so the
line is 12 m (the low end of a working heaving line, verify).

Authored in metres, front -Y, base at Z 0, coil centred; 1 Blender unit = 1 stud (common.metres_to_studs inside
rope.py). Attachments the game uses (docs/09 6 step 4; names as the E1 kit family, cf. M_Kit_ThrowBag): ATT_Grip
(where the thrower holds the seized coil), ATT_Throw (the monkey's fist the ballistic throw flies), ATT_LineExit
(where the line leaves the coil for the fist: a Beam origin), ATT_LineEnd (the spliced eye the tow line is bent
onto).
"""
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import maketex  # noqa: E402
import rope  # noqa: E402

S = common.STUDS_PER_METRE
NAME = "M_Kit_HeavingLine"
MI = "Rope_Poly"

# ---------------------------------------------------------------- the line (metres)
D = 0.006                                  # line diameter (class: about 0.006 m)
R = D / 2.0
COLS, ROWS = 2, 5                          # 10 loops: 2 wide over 5 layers (about 14 m of line)
DR = D * 1.05                              # radial step between the columns of a layer
DZ = D * 1.10                              # vertical step between layers
OVAL_E = 0.10                              # the coil is a soft oval (long axis X), as a hand-coiled line lies
R_IN = 0.150                               # innermost column radius on the narrow axis
PHASE = math.radians(-25.0)                # where both ends leave the coil, toward the eye at +X
COIL_TOP = R + (ROWS - 1) * DZ + R         # 0.0174: top surface of the coil

# ---------------------------------------------------------------- the monkey's fist
BALL_RC = 0.0275                           # wrap centreline radius: 61 mm ball over 6 mm line
WRAP_OFF = D * 0.90                        # wraps of one pass press on each other, as the knot is tied
BALL_R = (R_IN + DR) * (1.0 + OVAL_E * math.cos(2.0 * PHASE))
BALL_AT = (BALL_R * math.cos(PHASE), BALL_R * math.sin(PHASE))   # resting on the bundle at the throwing end
BALL_Z = COIL_TOP + BALL_RC - 0.002        # settled a couple of mm into the top layer
BALL_C = Vector((BALL_AT[0], BALL_AT[1], BALL_Z))

# ---------------------------------------------------------------- seizing, eye, tails
TWINE = 0.0016
SEIZE_CTR = Vector((-(R_IN + DR) * (1.0 + OVAL_E), 0.0, R + (ROWS - 1) * DZ / 2.0))   # bundle at -X
SEIZE_A = ((COLS - 1) * DR + D) / 2.0 + 0.0010                           # radial half-extent + clearance
SEIZE_B = ((ROWS - 1) * DZ + D) / 2.0 + 0.0010                           # vertical half-extent
EYE_DIR = Vector((math.cos(PHASE), math.sin(PHASE), 0.0))                # the eye lies outward at the ends
EYE_T_R = 0.190                                                          # the eye's throat, from the coil axis
EYE_R = 0.0230
EYE_C = EYE_DIR * (EYE_T_R + EYE_R) + Vector((0.0, 0.0, 0.0032))
EYE_T = EYE_DIR * EYE_T_R + Vector((0.0, 0.0, 0.0032))

PARTS = {}                                 # mesh part -> [(verts, faces, uvs), ...]
TUBES = []                                 # (part, description, triangles)


def tube(part, what, points_m, diameter_m, sides=4, max_tris=None, caps=True):
    v, f, u, tris, _ = rope.tube(points_m, diameter_m, "braid", sides=sides, max_tris=max_tris, caps=caps)
    PARTS.setdefault(part, []).append((v, f, u))
    TUBES.append((part, what, tris))
    return tris


def smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- the coil (a continuous serpentine)
def coil_points(rng):
    """One continuous centreline: 3 layers x 3 loops, each layer a spiral sweeping the 3 columns, the layer turns
    taken at the outer edge (even layers) or the inner edge (odd layers) over a half turn. Hand-coiled irregularity:
    per-layer oval and centre drift, per-loop radius and height jitter, the line itself never lying dead straight."""
    pts = []
    for row in range(ROWS):
        out = row % 2 == 0
        zc = R + row * DZ + (rng.uniform(-0.0008, 0.0008) if row else 0.0)
        ov = rng.uniform(0.012, 0.025)
        psi = rng.uniform(0.0, math.tau)
        dx = 0.00040 * row * math.cos(1.9 * row)
        dy = 0.00040 * row * math.sin(1.9 * row)
        a0 = PHASE + math.tau * (COLS + 0.5) * row
        n = 84
        for k in range(n + 1):
            tau = COLS * k / n
            th = a0 + math.tau * tau
            colf = tau * (COLS - 1.0) / COLS if out else (COLS - 1.0) * (1.0 - tau / COLS)
            shape = 1.0 + OVAL_E * math.cos(2.0 * (th - 0.30 * row)) + ov * math.cos(2.0 * (th - psi))
            shape += 0.004 * math.sin(3.3 * th + 1.7 * row) + 0.002 * math.sin(7.1 * th - 0.9 * row)
            rr = (R_IN + DR * colf) * shape
            pts.append((rr * math.cos(th) + dx, rr * math.sin(th) + dy,
                        zc + 0.00035 * math.sin(2.0 * th + row)))
        if row < ROWS - 1:                      # the layer turn: half a turn, same column, one layer up
            n2 = 16
            for k in range(1, n2 + 1):
                s = k / float(n2)
                th = a0 + math.tau * (COLS + 0.5 * s)
                colf = COLS - 1.0 if out else 0.0
                rr = (R_IN + DR * colf) * (1.0 + OVAL_E * math.cos(2.0 * th))
                pts.append((rr * math.cos(th) + dx, rr * math.sin(th) + dy,
                            zc + DZ * smoothstep(s) + 0.00035 * math.sin(2.0 * th + row)))
    return pts


def tail_points():
    """The free end: out from under the coil's inner start over the bundle's edge (a steep ramp the layers press
    down on, as a line is pulled out of a real coil), then flat on the deck to the eye's throat."""
    f = 1.0 + OVAL_E * math.cos(2.0 * PHASE)
    pts = [((R_IN * f - 0.008) * math.cos(PHASE), (R_IN * f - 0.008) * math.sin(PHASE), 0.0028)]
    ramp = [(R_IN * f, 0.0042), ((R_IN + DR) * f, 0.0090), ((R_IN + DR) * f + 0.008, 0.0108),
            ((R_IN + DR) * f + 0.017, 0.0074), ((R_IN + DR) * f + 0.026, 0.0048), (EYE_T_R, 0.0036)]
    for r, z in ramp:
        a = PHASE + 0.006 * math.sin(r * 90.0)
        pts.append((r * math.cos(a), r * math.sin(a), z))
    pts.append((EYE_T.x, EYE_T.y, EYE_T.z))
    return pts


def eye_points():
    """The spliced eye: a teardrop loop pinched to a point at the throat (where the standing part runs into it),
    lying on the deck with a slight twist, its end tucked back under the splice sleeve."""
    pts = []
    n = 18
    up = Vector((0.0, 0.0, 1.0))
    side = Vector((-EYE_DIR.y, EYE_DIR.x, 0.0))
    side = (side * math.cos(math.radians(12.0)) + up * math.sin(math.radians(12.0))).normalized()
    for k in range(n + 1):
        t = 2.0 * math.pi * 0.99 * k / n
        rr = EYE_R * (0.60 + 0.40 * 0.5 * (1.0 - math.cos(t)))
        p = EYE_T + (EYE_DIR * (1.0 - math.cos(t)) + side * math.sin(t)) * rr
        pts.append((p.x, p.y, p.z + 0.0035 * 0.5 * (1.0 - math.cos(t))))
    tuck = EYE_T - EYE_DIR * 0.020 + Vector((0.0, 0.0, -0.0006))
    pts.append((tuck.x, tuck.y, tuck.z))
    pts.append((tuck.x - EYE_DIR.x * 0.014, tuck.y - EYE_DIR.y * 0.014, tuck.z))
    return pts


def fist_rings():
    """Nine wraps: three passes of three wraps each about three axes, the wraps of a pass touching, ring radii and
    bases nudged so the weave reads over-under instead of z-fighting."""
    rng = random.Random(23)
    rings = []
    for i, ax in enumerate((Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))):
        band = 1.0 + 0.006 * (i - 1)
        for o in (-1, 0, 1):
            off = o * WRAP_OFF + rng.uniform(-0.0003, 0.0003)
            rc = math.sqrt(max(BALL_RC * BALL_RC - off * off, 1e-6)) * band
            e1 = ax.orthogonal().normalized()
            e1 = (e1 + Vector((rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), 0.0))).normalized()
            e2 = ax.cross(e1).normalized()
            c = BALL_C + ax * off
            n = 11
            ring = []
            for k in range(n + 1):
                a = math.tau * k / n
                rr = rc * (1.0 + 0.006 * math.sin(3.0 * a + i))
                p = c + (e1 * math.cos(a) + e2 * math.sin(a)) * rr
                ring.append(tuple(p))
            rings.append(ring)
    return rings


def fist_extra():
    """The collar the standing part is drawn tight with, and the short worked end left hanging over the bundle."""
    collar = []
    tilt = math.radians(22.0)
    c = BALL_C + Vector((0.0, 0.0, -0.0245))
    e1 = Vector((math.cos(tilt), 0.0, math.sin(tilt)))
    e2 = Vector((0.0, 1.0, 0.0))
    for k in range(9):
        a = math.tau * k / 8
        p = c + (e1 * math.cos(a) + e2 * math.sin(a)) * 0.0245 * (1.0 + 0.01 * math.sin(3 * a))
        collar.append(tuple(p))
    d = Vector((math.cos(math.radians(-115.0)), math.sin(math.radians(-115.0)), 0.0))
    tail = [tuple(BALL_C + d * 0.004 + Vector((0.0, 0.0, -0.024))), tuple(BALL_C + d * 0.020 + Vector((0.0, 0.0, -0.030))),
            tuple(BALL_C + d * 0.036 + Vector((0.0, 0.0, -0.044))), tuple(BALL_C + d * 0.050 + Vector((0.0, 0.0, -0.052))),
            tuple(BALL_C + d * 0.057 + Vector((0.0, 0.0, -0.056)))]
    whip = [tail[2], tail[3], tail[4], tuple(BALL_C + d * 0.061 + Vector((0.0, 0.0, -0.056)))]
    return collar, tail, whip


def seizing_parts():
    """Two tight turns of 1.6 mm twine round the bundle at -X (the coil is kept ready to throw)."""
    turns = []
    for i, y in enumerate((-0.0032, 0.0, 0.0032)):
        ring = []
        a_ = SEIZE_A + 0.0002 * i
        b_ = SEIZE_B + 0.0002 * i
        for k in range(8):
            a = math.tau * k / 7
            ring.append((SEIZE_CTR.x - a_ * math.cos(a), y + 0.0004 * math.sin(2 * a), SEIZE_CTR.z + b_ * math.sin(a)))
        turns.append(ring)
    kx = SEIZE_CTR.x - SEIZE_A - 0.0004
    kz = SEIZE_CTR.z + SEIZE_B + 0.0006
    knot = [(kx, -0.0032, kz - 0.0010), (kx - 0.0020, 0.0, kz + 0.0010), (kx, 0.0032, kz - 0.0007)]
    ends = [[(kx - 0.0004, 0.0034, kz - 0.0004), (kx - 0.0010, 0.0046, kz - 0.0086), (kx - 0.0016, 0.0048, kz - 0.0158)],
            [(kx - 0.0010, -0.0034, kz - 0.0008), (kx - 0.0016, -0.0042, kz - 0.0062), (kx - 0.0022, -0.0040, kz - 0.0112)]]
    return turns, knot, ends


def throat_points(end, t):
    """From the end of the coil's top layer up into the fist's lower side (a short rise: the knot rests where the
    line's end comes off the coil)."""
    return [tuple(end - t * 0.006), tuple(end + t * 0.014 + Vector((0.0, 0.0, 0.011))),
            tuple(BALL_C + Vector((0.014, -0.014, -0.018))), tuple(BALL_C + Vector((0.002, -0.002, -0.008)))]


def build_geometry():
    rng = random.Random(11)
    coil = coil_points(rng)
    end = Vector(coil[-1])
    tang = (Vector(coil[-1]) - Vector(coil[-3])).normalized()
    tube("line", "coil", coil, D, sides=4, max_tris=1280)
    tube("line", "tail to the eye", tail_points(), D, sides=4, max_tris=96)
    tube("line", "eye", eye_points(), D, sides=4, max_tris=144)
    s = EYE_T - EYE_DIR * 0.008
    e = EYE_T - EYE_DIR * 0.052
    tube("line", "splice sleeve", [tuple(s), tuple(s.lerp(e, 0.55)), tuple(e)], D * 1.50, sides=4, max_tris=48)
    tube("line", "splice tip", [tuple(s.lerp(e, 0.62)), tuple(e + EYE_DIR * 0.014)], D * 1.20, sides=4, max_tris=24)
    tube("line", "throat to the fist", throat_points(end, tang), D, sides=4, max_tris=88)
    turns, knot, ends = seizing_parts()
    for i, ring in enumerate(turns):
        tube("line", "seizing turn %d" % (i + 1), ring, TWINE, sides=3, max_tris=42, caps=False)
    tube("line", "seizing knot", knot, TWINE * 1.3, sides=3, max_tris=40)
    for i, t in enumerate(ends):
        tube("line", "seizing end %d" % (i + 1), t, TWINE, sides=3, max_tris=20)
    for i, ring in enumerate(fist_rings()):
        tube("fist", "wrap %d" % (i + 1), ring, D, sides=5, max_tris=110, caps=False)
    collar, ftail, whip = fist_extra()
    tube("fist", "collar", collar, D, sides=4, max_tris=56, caps=False)
    tube("fist", "working end", ftail, D, sides=4, max_tris=48)
    tube("fist", "whipping", whip, D * 1.25, sides=4, max_tris=28)
    return coil, end


def material():
    mat = bpy.data.materials.get(MI)
    if mat is None:
        mat = bpy.data.materials.new(MI)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Base Color"].default_value = (0.82, 0.77, 0.54, 1.0)
        b.inputs["Roughness"].default_value = 0.66
        b.inputs["Metallic"].default_value = 0.0
    mat.diffuse_color = (0.82, 0.77, 0.54, 1.0)
    return mat


def clear():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_"):
            bpy.data.objects.remove(o, do_unlink=True)


def empty(name, p_studs):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.06
    e.location = tuple(p_studs)
    bpy.context.scene.collection.objects.link(e)
    return e


def sync_dims_md(dims, line_len):
    path = os.path.join(G, "art/reference", NAME, "dims.md")
    line = "dims_m: %.3f x %.3f x %.3f" % dims
    note = ("\nE2 (2026-10-18): dims_m is the authored flake as it sits (X, Y, Z metres, front -Y, base at Z 0): the "
            "class is the line itself - about 6 mm floating line, 20 to 25 m long (above) - coiled here in nine "
            "large throwing loops, %.1f m of line: the oval coil is about 0.71 x 0.50 m, the monkey's fist rests on "
            "the bundle and the eye tail out at +X sets the bbox. Source: art/source/kit/M_Kit_HeavingLine/build.py, "
            "tools/blender/rope.py tubes.\n" % line_len)
    import re
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as fh:
            txt = fh.read()
        txt = re.sub(r"^dims_m:.*$", line, txt, count=1, flags=re.M)
        if "E2 (2026-10-18)" not in txt:
            txt += note
    else:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        txt = "# %s\n\nWeighted heaving line (throw line with monkey's fist).\n\n%s\n%s" % (NAME, line, note)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(txt)
    return path


def build():
    clear()
    coil, end = build_geometry()
    line_len = float(rope.polyline_length(np.asarray(coil)))

    allv = [Vector(v) for part in PARTS.values() for chunk in part for v in chunk[0]]
    lo = Vector([min(v[i] for v in allv) for i in range(3)])
    hi = Vector([max(v[i] for v in allv) for i in range(3)])
    off = Vector((-(lo.x + hi.x) / 2.0, -(lo.y + hi.y) / 2.0, -lo.z))
    for part in PARTS.values():
        for chunk in part:
            chunk[0][:] = [Vector(v) + off for v in chunk[0]]
    lo, hi = lo + off, hi + off

    objs = {}
    for part, name in (("line", NAME + "_LOD0"), ("fist", NAME + "_Fist_LOD0")):
        objs[part] = rope._object(name, PARTS[part], set_name="Poly")
        objs[part].data.materials.clear()
        objs[part].data.materials.append(material())

    dims = tuple(round((hi[i] - lo[i]) / S, 3) for i in range(3))
    off_m = off / S
    atts = [
        ("ATT_Grip", SEIZE_CTR + off_m),
        ("ATT_Throw", BALL_C + off_m),
        ("ATT_LineExit", end + off_m),
        ("ATT_LineEnd", EYE_C + EYE_DIR * EYE_R + off_m),
    ]
    empty_objs = [empty(n, p * S) for n, p in atts]

    maketex.build(common.textures_dir(NAME))
    sync_dims_md(dims, line_len)
    total = 0
    for o in (objs["line"], objs["fist"]):
        n = sum(len(p.vertices) - 2 for p in o.data.polygons)
        total += n
        print("[%s] %-46s %5d tris" % (NAME, o.name, n))
    print("[%s] total %d tris, line %.1f m, coil %.3f m across, bbox m %.3f x %.3f x %.3f" %
          (NAME, total, line_len, 2 * ((R_IN + 2 * DR) * (1.0 + OVAL_E) + R), dims[0], dims[1], dims[2]))
    longest = max(TUBES, key=lambda t: t[2])
    print("[%s] longest part %s: %s, %d tris" % (NAME, longest[0], longest[1], longest[2]))

    return {
        "name": NAME, "budget": "small_prop", "tris": 3000, "tier": "hero",
        "dims_m": dims,
        "size_note": ("the class is 20 to 25 m of 6 mm line; dims_m is the coil as it sits: the coil, the fist on "
                      "top and the eye tail set the bbox"),
        "origin": "base",
        "sets": [{"name": "Rope", "set": "Poly", "size": maketex.SIZE, "wet": True,
                  "dir": common.textures_dir(NAME)}],
        "meshes": [{"object": objs["line"], "set": "Poly"}, {"object": objs["fist"], "set": "Poly"}],
        "attachments": empty_objs,
        "tiling": True, "lod_symmetry": None,
        "waivers": {"LOD UV layout": "collapse decimation of a tiled rope tube moves UVs a little; the LODs sample "
                                    "the same one-tile-per-circumference trim"},
        "closeups": [
            {"name": "fist", "target": list(BALL_C * S + off), "dist": 1.1, "az": 35.0, "el": 24.0},
            {"name": "seizing", "target": list(SEIZE_CTR * S + off), "dist": 1.1, "az": 250.0, "el": 18.0},
            {"name": "eye", "target": list(EYE_C * S + off), "dist": 1.5, "az": 35.0, "el": 22.0},
            {"name": "coil", "target": list(Vector((0.0, 0.0, COIL_TOP * S)) + off), "dist": 3.0, "az": 35.0, "el": 42.0},
        ],
    }
