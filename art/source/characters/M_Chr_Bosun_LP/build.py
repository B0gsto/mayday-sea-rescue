"""M_Chr_Bosun_LP: Bosun, the warm-brown water-rescue dog (tan points), low-poly Lego-character style.

One bevelled mesh per BosunRig PartSpec, authored in that part's rest frame (studs, origin between
the feet, front -Z, up +Y, his right +X) and exported in the pipeline's Roblox mapping. The rig and
BosunMotion are unchanged: every mesh fills its PartSpec box around the rest pivot, so the existing
Motor6Ds articulate the segments. Harness pieces stay separate (BosunRig.harness = true).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/characters/M_Chr_Bosun_LP/build.py --out-root build/prod/M_Chr_Bosun_LP \
      --steps build,lod,validate,export,turntable
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

import common
import names
import versions

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
ASSET = "M_Chr_Bosun_LP"
PREFIX = "M_Chr_Bosun_" + "LP_"          # M_Chr_Bosun_LP_<Part>
SHIFT_Y = 0.0                             # set from the measured bbox (feet stay on z = 0)

# ---------------------------------------------------------------- Roblox CFrame -> Blender

_X = lambda a: Matrix.Rotation(a, 3, "X")
_Y = lambda a: Matrix.Rotation(a, 3, "Y")
_Z = lambda a: Matrix.Rotation(a, 3, "Z")


def _rot_rb(rx=0.0, ry=0.0, rz=0.0):
    """CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz (radians), in authored Roblox axes."""
    return _X(rx) @ _Y(ry) @ _Z(rz)


def _to_bl(p, r=None):
    """Authored Roblox studs -> Blender studs: bx=-x, by=z, bz=y."""
    pb = Vector((-p[0], p[2], p[1]))
    if r is None:
        return Matrix.Translation(pb)
    m = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
    return Matrix.Translation(pb) @ (m.transposed() @ r @ m).to_4x4()


def cf(pos, rx=0.0, ry=0.0, rz=0.0):
    return _to_bl(pos, _rot_rb(rx, ry, rz))


def mul(c, x, y, z):
    return c @ Matrix.Translation(Vector((x, y, z)))


# ---------------------------------------------------------------- the BosunRig contract

PARTS = []


def add(name, size, cframe, parent, joint=None, pivot=None, harness=False):
    PARTS.append(dict(name=name, size=Vector(size), cframe=cframe, parent=parent,
                      joint=joint, pivot=(Vector(pivot) if pivot else None), harness=harness))
    return PARTS[-1]


D = math.radians
add("Torso", (0.95, 0.9, 2.3), cf((0, 1.68, 0.05)), "Body", "Root", (0, 0, -0.85))
add("Chest", (1.0, 1.0, 1.0), cf((0, 1.66, -1.0)), "Torso")
add("Rump", (0.92, 0.88, 0.88), cf((0, 1.74, 1.05)), "Torso")
add("Head", (0.78, 0.72, 0.8), cf((0, 2.62, -1.55)), "Torso", "Neck", (0, 2.0, -1.05))
add("Neck", (0.56, 0.95, 0.56), cf((0, 2.2, -1.28), D(-28)), "Head")
add("Muzzle", (0.48, 0.36, 0.55), cf((0, 2.48, -2.16)), "Head")
add("Nose", (0.24, 0.15, 0.08), cf((0, 2.6, -2.45)), "Head")
add("Jaw", (0.42, 0.12, 0.5), cf((0, 2.25, -2.12)), "Head", "Jaw", (0, 2.3, -1.86))
add("Tongue", (0.22, 0.04, 0.3), cf((0, 2.32, -2.12)), "Jaw")
for s, side in ((-1, "Left"), (1, "Right")):
    add("Eye" + side, (0.12, 0.12, 0.12), cf((0.22 * s, 2.76, -1.94)), "Head")
    add("Ear" + side, (0.1, 0.5, 0.34), cf((0.42 * s, 2.58, -1.42), 0, 0, D(8) * s), "Head")

TAIL = (0, 1.95, 1.4)
tail1 = cf(TAIL, D(40))
add("Tail1", (0.22, 0.22, 0.62), mul(tail1, 0, 0.31, 0), "Torso", "Tail1", TAIL)
tip = mul(tail1, 0, 0.6, 0)
TIP_RB = (0.0, 1.95 - 0.6 * math.sin(D(40)), 1.4 + 0.6 * math.cos(D(40)))
add("Tail2", (0.16, 0.16, 0.55), tip @ cf((0, 0, 0), D(15)) @ Matrix.Translation((0, 0.27, 0)),
    "Tail1", "Tail2", TIP_RB)

for end_, z in (("Front", -0.82), ("Back", 0.92)):
    for s, side in ((-1, "Left"), (1, "Right")):
        leg = end_ + side
        x = 0.28 * s
        w = 0.32 if end_ == "Back" else 0.27
        add(leg + "Upper", (w, 0.9, w + 0.06), cf((x, 1.15, z)), "Torso", leg + "Upper", (x, 1.5, z))
        add(leg + "Lower", (0.22, 0.66, 0.24), cf((x, 0.43, z)), leg + "Upper", leg + "Lower", (x, 0.72, z))
        add(leg + "Paw", (0.28, 0.14, 0.38), cf((x, 0.07, z - 0.06)), leg + "Lower")

HZ = -0.4
for nm, size, pos in (
    ("HarnessBack", (0.99, 0.08, 0.95), (0, 2.15, HZ)),
    ("HarnessSideLeft", (0.06, 0.78, 0.95), (-0.5, 1.78, HZ)),
    ("HarnessSideRight", (0.06, 0.78, 0.95), (0.5, 1.78, HZ)),
    ("HarnessTapeLeft", (0.02, 0.08, 0.9), (-0.535, 1.86, HZ)),
    ("HarnessTapeRight", (0.02, 0.08, 0.9), (0.535, 1.86, HZ)),
    ("HarnessBelly", (1.0, 0.07, 0.3), (0, 1.24, HZ)),
    ("HarnessChest", (0.86, 0.14, 0.08), (0, 1.82, -1.5)),
    ("HarnessHandle", (0.12, 0.08, 0.5), (0, 2.27, HZ)),
):
    add(nm, size, cf(pos), "Torso", harness=True)

# ---------------------------------------------------------------- geometry helpers

_rng = random.Random(11)
_face_zones = []          # (first face, end face, zone) for tagged pieces of the part being built


def _bevel(bm, width, segments):
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=width, offset_type="OFFSET", segments=segments,
                    profile=0.5, affect="EDGES", clamp_overlap=True)


def _box(size, centre=(0, 0, 0), bevel=0.05, segments=2, taper=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = (max(v, 1e-5) for v in size)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    if taper:
        axis, neg, pos = taper
        half = {"x": sx, "y": sy, "z": sz}[axis] * 0.5
        ai = {"x": 0, "y": 1, "z": 2}[axis]
        for v in bm.verts:
            t = max(-1.0, min(1.0, v.co[ai] / half))
            k = neg if t < 0 else pos
            f = 1.0 + (k - 1.0) * abs(t)
            for a in range(3):
                if a != ai:
                    v.co[a] *= f
    if bevel > 0:
        _bevel(bm, bevel, segments)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return bm


def _pad(size, centre, corner, edge):
    """Box with round corners in its y-z plane (`corner`) and a small `edge` bevel round its faces (x is thickness)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    xs = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized().x) > 0.9]
    bmesh.ops.bevel(bm, geom=xs, offset=corner, offset_type="OFFSET", segments=3, profile=0.5, affect="EDGES",
                    clamp_overlap=True)
    rest = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized().x) < 0.9]
    bmesh.ops.bevel(bm, geom=rest, offset=edge, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES",
                    clamp_overlap=True)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return bm


def _sphere(size, centre=(0, 0, 0), u=12, v=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vert in bm.verts:
        vert.co.x *= size[0] * 0.5
        vert.co.y *= size[1] * 0.5
        vert.co.z *= size[2] * 0.5
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return bm


def _merge(dst, src, zone=None):
    n0 = len(dst.faces)
    me = bpy.data.meshes.new("_prim")
    src.to_mesh(me)
    src.free()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)
    if zone:
        _face_zones.append((n0, len(dst.faces), zone))


def _rot(bm, angle, axis, centre=(0, 0, 0)):
    m = Matrix.Rotation(angle, 4, axis)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts, space=Matrix.Translation(-Vector(centre)))


def _stud(r, h, centre, band=0.055, segs=12):
    """Lego stud (axis +Z) with a chamfered top rim, one closed piece spun from a profile; the base sinks into
    the panel it sits on. The lowest `band` is its own ring of faces (zoned dark as a contact shadow)."""
    bm = bmesh.new()
    prof = [(0, 0), (r, 0), (r, band), (r, h - 0.22 * r), (0.78 * r, h), (0, h)]
    vs = [bm.verts.new((x, 0, z - h * 0.5)) for x, z in prof]
    for a, b in zip(vs, vs[1:]):
        bm.edges.new((a, b))
    bmesh.ops.spin(bm, geom=list(bm.verts) + list(bm.edges), cent=(0, 0, 0), axis=(0, 0, 1),
                   angle=2 * math.pi, steps=segs)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return bm


# ---------------------------------------------------------------- each part's shape

def _torso(bm):
    # r4: 2.1 long (reads ~10 % shorter), 0.2 deeper belly (top kept) so less leg shows below it
    _merge(bm, _box((0.95, 2.1, 1.1), (0, 0, -0.10), bevel=0.08, segments=2, taper=("y", 0.95, 0.9)))
    _merge(bm, _box((0.70, 0.9, 0.12), (0, -0.15, 0.42), bevel=0.05, segments=1))


def _chest(bm):
    # r4: crisp bevelled block (was a 12x6 sphere): deeper brisket, front pulled back 0.05
    _merge(bm, _box((1.04, 0.90, 1.15), (0, 0.05, -0.08), bevel=0.10, segments=2, taper=("z", 0.9, 1.0)))


def _rump(bm):
    # r4: tucked-up seat (bottom 0.1 higher, rounder) so the sit is rump + all four paws on the ground
    _merge(bm, _box((0.94, 0.84, 0.90), (0, -0.08, -0.01), bevel=0.14, segments=2, taper=("z", 0.92, 1.0)))


def _head(bm):
    # r4: ~1.17x r3 (chibi); grows back/up/out so the front face and the eye domes (rest pivots fixed) stay put
    _merge(bm, _box((1.05, 1.05, 0.97), (0, 0.115, 0.02), bevel=0.08, segments=2, taper=("z", 0.96, 0.92)))
    for s in (-1, 1):       # soft tan brow dots, inner end raised (friendly, not grumpy)
        brow = _sphere((0.17, 0.07, 0.065), (0.25 * s, -0.38, 0.33), u=8, v=4)
        _rot(brow, D(10) * s, "Y", (0.25 * s, -0.38, 0.33))
        _merge(bm, brow, "tan")
    blaze = _box((0.30, 0.07, 0.44), (0, -0.405, 0.23), bevel=0.02, segments=2, taper=("z", 1.2, 1.0))   # cream blaze ~0.3 head widths
    _rot(blaze, D(-3), "X", (0, -0.405, 0.23))
    _merge(bm, blaze, "tan")


def _neck(bm):
    _merge(bm, _box((0.56, 0.56, 0.95), (0, 0, 0), bevel=0.11, segments=2, taper=("z", 0.9, 0.95)))


def _muzzle(bm):
    _merge(bm, _box((0.63, 0.48, 0.47), (0, 0.09, 0.01), bevel=0.07, segments=2, taper=("y", 0.88, 1.0)))   # r5: +15 %, 20 % shorter


def _nose(bm):
    _merge(bm, _box((0.34, 0.12, 0.20), (0, 0.105, 0), bevel=0.035, segments=2))   # 1.2x; r5 back 0.12 with the shorter muzzle


def _jaw(bm):
    _merge(bm, _box((0.55, 0.43, 0.13), (0, 0.08, -0.005), bevel=0.035, segments=2, taper=("y", 0.88, 1.0)))   # r5 shorter


def _tongue(bm):
    _merge(bm, _box((0.20, 0.30, 0.06), (0, -0.02, -0.075), bevel=0.009, segments=1, taper=("y", 0.86, 1.0)))
    tip = _box((0.17, 0.15, 0.055), (0, -0.235, -0.125), bevel=0.008, segments=1, taper=("y", 0.72, 1.0))
    _rot(tip, D(18), "X", (0, -0.235, -0.125))
    _merge(bm, tip)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0, 0.11, 0)))       # r5: back with the shorter jaw


def _eye(bm):
    _merge(bm, _sphere((0.41, 0.24, 0.38), (0, -0.05, 0), u=16, v=8))            # r6: 1.15x r5
    _merge(bm, _sphere((0.16, 0.05, 0.16), (0.065, -0.155, 0.08), u=8, v=4), "highlight")    # bigger catch-light
    _merge(bm, _sphere((0.06, 0.03, 0.06), (-0.07, -0.152, -0.075), u=8, v=4), "highlight")    # second small glint


def _ear(bm, side):
    # 0.15 thick flap, root sunk into the head side, bottom splayed out and tipped forward
    o = -side * 0.08                    # r4: pushed out with the wider head (his right, +1, is Blender -x)
    bm_ear = _box((0.176, 0.48, 0.825), (o, 0, -0.1125), bevel=0.05, segments=2, taper=("z", 1.0, 0.74))   # r6: +10 %, top kept
    _rot(bm_ear, D(12) * side, "Y", (o, 0, 0.30))
    _rot(bm_ear, D(-12), "X", (0, 0, 0.28))
    _merge(bm, bm_ear)


# r4 tail: one thick block carried up 35 deg (happy), the tip curling on up to 65 deg. Built in rig space and
# brought into each part's frame; the tip sits right above the Tail2 pivot so its wag yaw spins it in place.
T1_UP, T2_UP, T1_LEN = D(35), D(110), 0.62     # r5: tip hooks forward over the back


def _in_part(bm, name):
    bmesh.ops.transform(bm, matrix=next(p for p in PARTS if p["name"] == name)["cframe"].inverted(), verts=bm.verts)


def _tail_end():
    return Vector((0, TAIL[2], TAIL[1])) + Vector((0, math.cos(T1_UP), math.sin(T1_UP))) * T1_LEN


def _tail1(bm):
    piv = Vector((0, TAIL[2], TAIL[1]))
    d = Vector((0, math.cos(T1_UP), math.sin(T1_UP)))
    blk = _box((0.70, 0.62, 0.74), (0, 0, 0), bevel=0.12, segments=2, taper=("y", 1.0, 0.82))   # r6: 1.35x thicker, shorter
    _rot(blk, T1_UP, "X")
    bmesh.ops.translate(blk, verts=blk.verts, vec=piv + d * 0.31)
    _merge(bm, blk)
    _merge(bm, _sphere((0.58, 0.58, 0.58), _tail_end(), u=10, v=5))
    _in_part(bm, "Tail1")


def _tail2(bm):
    d = Vector((0, math.cos(T2_UP), math.sin(T2_UP)))
    for size, at, zone in (((0.54, 0.30, 0.56), 0.12, None), ((0.48, 0.30, 0.50), 0.36, "tan")):   # r6 thicker, shorter, chunky cream tip
        blk = _box(size, (0, 0, 0), bevel=0.08, segments=2, taper=("y", 1.0, 0.80))
        _rot(blk, T2_UP, "X")
        bmesh.ops.translate(blk, verts=blk.verts, vec=_tail_end() + d * at)
        _merge(bm, blk, zone)
    _in_part(bm, "Tail2")


def _upper(bm, back, side):
    # r4: 1.2x thicker, grown outward so each pair stays 0.04 apart; the hind thigh is a rounded haunch
    w = 0.62 if back else 0.58
    o = -side * (0.05 if back else 0.03)        # his right (+1) is Blender -x
    _merge(bm, _box((w, w + 0.06, 0.90), (o, 0, 0), bevel=0.12 if back else 0.06, segments=2, taper=("z", 0.86, 1.0)))


def _lower(bm):
    _merge(bm, _box((0.48, 0.52, 0.66), (0, 0, 0), bevel=0.05, segments=2, taper=("z", 0.92, 0.95)))   # r4 1.2x
    _merge(bm, _sphere((0.50, 0.50, 0.32), (0, 0, 0.285), u=8, v=4))
    _merge(bm, _box((0.54, 0.58, 0.28), (0, 0, -0.16), bevel=0.04, segments=1), "tan")   # r6: 1.5x taller cream sock


def _paw(bm):
    _merge(bm, _box((0.52, 0.58, 0.18), (0, -0.04, 0.02), bevel=0.05, segments=2, taper=("y", 0.92, 1.0)))   # cream boot; sole on z = 0


# r4 vest: a thick foam jacket over the back and down both sides to the belly line (Roblox z -1.12..0.20, ~57 % of
# the torso), solid orange, ONE bold white band per side (Tape meshes: never tinted).
# Panels grow around their fixed part centres; the side panels are 0.21 thick so the thicker legs stay inside.
# r5: side panels hug the barrel (15 % shorter, belly strap rises to meet them), each is an orange 0.08-bevel inset
# raised over a navy base plate (a 0.10 navy rim, 2x r4), 2 chunky back studs, white band across the top (Tape).
VEST_Y, VEST_LEN = -0.06, 1.32          # Blender local y centre / length of the back panel (-0.08)
# r6 side panels: a rounded near-square pad between the legs (front edge behind the shoulders), so the sit's body pitch
# doesn't read as a long card tilted off the barrel
SIDE_Y, SIDE_LEN, SIDE_ZC, SIDE_H, SIDE_X, SIDE_T, SIDE_BEV = 0.30, 0.94, -0.045, 0.83, 0.035, 0.17, 0.16
TAPE_X = 0.5 + SIDE_X + (SIDE_T + 0.04) * 0.5 + 0.0125 - 0.535     # side band sunk 0.01 into the pad's orange face


def _harness_back(bm):
    _merge(bm, _box((1.24, VEST_LEN + 0.08, 0.08), (0, VEST_Y, 0), bevel=0.025, segments=2))
    for s in (-1, 1):       # navy edge front and back (0.10)
        _merge(bm, _box((1.16, 0.10, 0.03), (0, VEST_Y + s * (VEST_LEN + 0.08 - 0.13) * 0.5, 0.05), bevel=0), "webbing")
        # one chunky ~0.5 stud per side, dark base band reads as a contact shadow
        _merge(bm, _stud(0.25, 0.24, (0.33 * s, VEST_Y - 0.06, 0.14), segs=12))


def _harness_side(bm, side):
    o = -side                             # outward is Blender -x for his right (+1)
    zc, h = SIDE_ZC, SIDE_H
    _merge(bm, _pad((SIDE_T, SIDE_LEN, h), (o * SIDE_X, SIDE_Y, zc), SIDE_BEV, 0.03), "webbing")   # navy base
    _merge(bm, _pad((SIDE_T + 0.04, SIDE_LEN - 0.20, h - 0.20), (o * SIDE_X, SIDE_Y, zc), SIDE_BEV - 0.06, 0.05))  # orange inset
    for t in (-1, 1):
        stud = _stud(0.11, 0.11, (0, 0, 0), segs=10)       # 1x2 studs below the band
        _rot(stud, D(-90) * side, "Y")       # stud axis points outward
        bmesh.ops.translate(stud, verts=stud.verts, vec=Vector((o * (SIDE_X + SIDE_T * 0.5 + 0.055), SIDE_Y + 0.21 * t, zc - h * 0.5 + 0.20)))
        _merge(bm, stud)


def _harness_tape(bm, side):
    _merge(bm, _box((0.045, SIDE_LEN - 0.08, 0.24), (-side * TAPE_X, SIDE_Y, -0.01), bevel=0.012, segments=1))   # side band
    # r6: its half of a raised white bar across the back panel's rear edge (0.3 wide, 0.21 above the panel): clears
    # the rump and tail line so it reads from behind and from the game camera, not only from straight above
    _merge(bm, _box((0.60, 0.30, 0.24), (side * 0.22, 0.46, 0.42), bevel=0.03, segments=2))


def _harness_belly(bm):
    # r6: one flush navy strap under the belly, inside the barrel's width (the r5 flank risers read as an orange wedge
    # at the hip in the sit, and the wide ends as a tab hanging below the vest)
    _merge(bm, _box((0.90, 0.26, 0.08), (0, 0.04, -0.20), bevel=0.02, segments=2), "webbing")


def _harness_chest(bm):
    # ~0.3 tall orange chest strap across the brisket, wrapping back along the chest into the side panels
    _merge(bm, _box((1.06, 0.08, 0.30), (0, 0.09, 0), bevel=0.025, segments=2))
    for s in (-1, 1):
        _merge(bm, _box((0.06, 0.83, 0.22), (s * 0.53, 0.515, 0), bevel=0.015, segments=1))   # r6: back into the side pads


def _harness_handle(bm):
    for s in (-1, 1):
        _merge(bm, _box((0.11, 0.075, 0.27), (0, 0.205 * s, 0.025), bevel=0.018, segments=1))   # feet sunk into the back panel
    _merge(bm, _box((0.12, 0.44, 0.07), (0, 0, 0.155), bevel=0.022, segments=1))


SHAPES = {
    "Torso": _torso, "Chest": _chest, "Rump": _rump, "Head": _head, "Neck": _neck,
    "Muzzle": _muzzle, "Nose": _nose, "Jaw": _jaw, "Tongue": _tongue,
    "Tail1": _tail1, "Tail2": _tail2,
}

# ---------------------------------------------------------------- texture zones

ZONES = {
    "coat": (0.0, 0.5, 0.0, 0.5), "harness": (0.52, 0.72, 0.0, 0.5),
    "webbing": (0.74, 0.82, 0.0, 0.5), "tape": (0.84, 1.0, 0.0, 0.5),
    "eye": (0.52, 0.60, 0.52, 0.60), "highlight": (0.62, 0.70, 0.52, 0.60),
    "nose": (0.72, 0.80, 0.52, 0.60), "tongue": (0.82, 0.90, 0.52, 0.60),
    "inner": (0.92, 1.0, 0.52, 0.60),
    "tan": (0.0, 0.5, 0.62, 1.0), "ear": (0.52, 0.72, 0.62, 1.0),
}
GRADIENT = {"coat", "harness", "nose", "tan", "ear"}


def _zone_of(part, index, centre, normal=None):
    """centre / normal are in the part's own rest frame (Blender axes: front -Y, up +Z)."""
    name = part["name"]
    for a, b, zone in _face_zones:
        if a <= index < b:
            return zone
    if name == "HarnessBack" and 0.042 < centre.z < 0.085:              # stud base bands (panel top is 0.04)
        return "webbing"
    if name in ("Muzzle", "Jaw") or name.endswith("Paw"):
        return "tan"
    if name == "Chest" and centre.y < -0.15 and centre.z < 0.25:      # bib
        return "tan"
    if name.endswith("Lower") and centre.z < -0.12:                      # taller cream boots
        return "tan"
    if name.startswith("Ear"):            # inner face (toward the head) is tan
        side = -1 if name.endswith("Left") else 1
        return "tan" if normal is not None and normal.x * side > 0.6 else "ear"
    if name.startswith("Eye"):
        return "eye"
    if name == "Nose":
        return "nose"
    if name == "Tongue":
        return "tongue"
    if name.startswith("HarnessTape"):
        return "tape"
    if name == "HarnessHandle":
        return "webbing"
    if name.startswith("Harness"):
        return "harness"
    return "coat"


def _assign_uv(bm, part):
    uv = bm.loops.layers.uv.new("UVMap")
    inv = part["cframe"].inverted()
    for i, f in enumerate(bm.faces):
        f.normal_update()
        zone = _zone_of(part, i, inv @ f.calc_center_median(), (inv.to_3x3() @ f.normal).normalized())
        x0, x1, y0, y1 = ZONES[zone]
        up = max(0.0, min(1.0, (f.normal.z + 1.0) * 0.5))
        u = _rng.uniform(x0 + 0.03 * (x1 - x0), x1 - 0.03 * (x1 - x0))
        if zone in GRADIENT:
            v = y0 + (0.05 + 0.90 * up) * (y1 - y0)
        else:
            v = _rng.uniform(y0 + 0.12 * (y1 - y0), y1 - 0.12 * (y1 - y0))
        s = 0.004
        u = max(x0 + s, min(x1 - s, u))
        v = max(y0 + s, min(y1 - s, v))
        n = len(f.loops)
        for i, loop in enumerate(f.loops):     # distinct points on a circle: n-gons (stud caps) keep UV area in LODs
            t = 2.0 * math.pi * (i + 0.5) / n
            loop[uv].uv = (u + 0.5 * s * (1 + math.cos(t)), v + 0.5 * s * (1 + math.sin(t)))


# ---------------------------------------------------------------- materials and build

def _material():
    out_dir = common.textures_dir(ASSET)
    import coattex
    paths = coattex.write(out_dir)
    mat = bpy.data.materials.get("M_Chr_Bosun_LP_Coat") or bpy.data.materials.new("M_Chr_Bosun_LP_Coat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    for kind, path, colour in (("ALB", paths[0], "sRGB"), ("NOR", paths[1], "Non-Color"),
                               ("RGH", paths[2], "Non-Color"), ("MET", paths[3], "Non-Color")):
        img = bpy.data.images.load(path, check_existing=True)
        img.colorspace_settings.name = colour
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        if kind == "ALB":
            nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
        elif kind == "RGH":
            nt.links.new(node.outputs["Color"], bsdf.inputs["Roughness"])
        elif kind == "MET":
            nt.links.new(node.outputs["Color"], bsdf.inputs["Metallic"])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(node.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


HEAD_GROUP = {"Head", "Muzzle", "Nose", "Jaw", "Tongue", "EyeLeft", "EyeRight", "EarLeft", "EarRight"}
HEAD_SCALE = 1.22                         # r6 (r5 1.12 read as barely grown)
NECK_BL = Vector((0, -1.05, 2.0))         # BosunRig Neck pivot (0, 2.0, -1.05) in Blender axes


def _make_part(part, mat):
    name = PREFIX + part["name"]
    bm = bmesh.new()
    _face_zones.clear()
    maker = SHAPES.get(part["name"])
    if part["name"].startswith("Eye"):
        _eye(bm)
    elif part["name"].startswith("Ear"):
        _ear(bm, -1 if part["name"].endswith("Left") else 1)
    elif part["name"].startswith("HarnessSide"):
        _harness_side(bm, -1 if part["name"].endswith("Left") else 1)
    elif part["name"].startswith("HarnessTape"):
        _harness_tape(bm, -1 if part["name"].endswith("Left") else 1)
    elif part["name"] == "HarnessBack":
        _harness_back(bm)
    elif part["name"] == "HarnessBelly":
        _harness_belly(bm)
    elif part["name"] == "HarnessChest":
        _harness_chest(bm)
    elif part["name"] == "HarnessHandle":
        _harness_handle(bm)
    elif part["name"].endswith("Upper"):
        _upper(bm, part["name"].startswith("Back"), -1 if "Left" in part["name"] else 1)
    elif part["name"].endswith("Lower"):
        _lower(bm)
    elif part["name"].endswith("Paw"):
        _paw(bm)
    elif maker:
        maker(bm)
    else:
        raise RuntimeError("no shape for " + part["name"])
    m = part["cframe"]
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    if part["name"] in HEAD_GROUP:         # r5 chibi head: the whole head grows about the neck pivot (pivots kept)
        bmesh.ops.scale(bm, vec=(HEAD_SCALE,) * 3, space=Matrix.Translation(-NECK_BL), verts=bm.verts)
    bm.normal_update()
    _assign_uv(bm, part)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.name = name
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    versions.weighted_normals(ob)          # crisp 2-segment bevels read as rounded plastic edges
    return ob


def _write_mapping(shapes):
    rows = {}
    for p in PARTS:
        cfm = p["cframe"]
        rot = cfm.to_3x3()
        # Blender part frame -> authored Roblox part frame: inverse of the authored conversion
        M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
        rr = M @ rot @ M.transposed()
        pos_b = cfm.translation
        pos = (-pos_b.x, pos_b.z, pos_b.y)
        rows[p["name"]] = {
            "part": p["name"],
            "mesh": p["name"],
            "pipeline_name": PREFIX + p["name"],
            "size": [round(v, 4) for v in p["size"]],
            "cframe": {"position": [round(v, 4) for v in pos],
                       "matrix": [[round(rr[i][j], 5) for j in range(3)] for i in range(3)]},
            "offset": [0, 0, 0],
            "parent": "Body" if p["parent"] == "Body" else p["parent"],
            "joint": p["joint"],
            "pivot": ([round(v, 4) for v in p["pivot"]] if p["pivot"] else None),
            "harness": bool(p["harness"]),
        }
    out = {
        "asset": ASSET,
        "source": "src/shared/Dog/BosunRig.luau",
        "axes": "authored studs: origin on the ground between the feet, front -Z, up +Y, his right +X; "
                 "FBX exported with rbxkit (roblox = (-bx, bz, by), 1 BU = 1 stud)",
        "names": "the exported FBX nodes are named exactly like BosunRig.PARTS (Torso, Head, ...); "
                 "pipeline_name is the validated Blender object name with the M_Chr_ asset prefix",
        "pivot_note": "Each mesh is authored around its PartSpec rest frame and exported with the node origin at that "
                      "part centre; cframe is the Part's rest CFrame (position + rotation matrix), offset is zero. "
                      "MeshParts already carry their mesh bounds: set CFrame only, do not force Size to size (the "
                      "grab handle deliberately rises above its flat placeholder box). If an importer collapses node "
                      "pivots, set the MeshPart CFrame to cframe.",
        "textures": {"set": "T_Bosun_Coat_<ALB|NOR|RGH|MET>.png", "size": 1024,
                     "dir": "textures/M_Chr_Bosun_LP"},
        "parts": rows,
    }
    path = os.path.join(common.out_root(), ASSET + ".mapping.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
    return path


def _repose(spec, report):
    """After validate: put every LOD node's origin at its part centre and its transform at the rig rest CFrame.

    Until here the meshes are assembled at the authored rest layout (so the size / origin rows measure the dog);
    a node per part with its own pivot is what Roblox needs for the Motor6D swap. No scale is used."""
    if spec.get("_reposed"):
        return
    for e in spec["meshes"]:
        if e.get("role") != "visual":
            continue
        ob = e["object"]
        base = names.mesh_base(ob.name)
        root = REST_BL.get(base)
        if root is None:
            report.add(ob.name, "part pivot", False, "no rest CFrame for " + base)
            continue
        if SHIFT_Y:
            ob.data.transform(Matrix.Translation((0, -SHIFT_Y, 0)))
        ob.data.transform(root.inverted())
        ob.matrix_world = root
        short = base[len(PREFIX):] if base.startswith(PREFIX) else base
        new_name = short + ob.name[len(base):]
        ob.name = new_name
        ob.data.name = new_name
    spec["_reposed"] = True
    report.add(ASSET, "part pivots", True, "%d segmented MeshParts re-origined at their BosunRig rest CFrames" % len(spec["meshes"]))


def _bbox(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi


REST_BL = {}


def build():
    global SHIFT_Y
    for ob in list(bpy.data.objects):
        if ob.name.startswith(PREFIX):
            bpy.data.objects.remove(ob, do_unlink=True)
    mat = _material()
    meshes = []
    for p in PARTS:
        ob = _make_part(p, mat)
        meshes.append({"object": ob, "role": "visual", "lod": "LOD0"})
        REST_BL[ob.name] = p["cframe"]
    lo, hi = _bbox([e["object"] for e in meshes])
    SHIFT_Y = -(lo[1] + hi[1]) * 0.5
    if abs(SHIFT_Y) > 1e-6:
        for e in meshes:
            e["object"].data.transform(Matrix.Translation((0, SHIFT_Y, 0)))
    lo, hi = _bbox([e["object"] for e in meshes])
    dims_m = tuple(round((hi[i] - lo[i]) / common.STUDS_PER_METRE, 3) for i in range(3))
    _write_mapping(meshes)
    return {
        "name": ASSET,
        "budget": "dog",
        "species": "dog",
        "tris": 7000,          # r6: brief allows LOD0 <= ~7,000
        "tier": "standard",
        "dims_m": dims_m,
        "origin": "base",
        "sets": [{"name": "Bosun", "set": "Coat", "size": 1024, "wet": False}],
        "meshes": meshes,
        "attachments": [],
        "extra_checks": [_repose],
        "waivers": {
            "texture sets": "one 1024 swatch set for a 35-part segmented character (dog class asks 2 to 3)",
            "texel density": "swatch atlas: per-face palette zones, form from bevelled low-poly geometry",
            "LOD UV layout": "segmented character: per-face palette swatches; collapsed LOD faces shift UV bounds",
            "LOD0 floor": "briefed 3,000 to 7,000 tris, far under the dog class 25,000",
            "origin": "rig origin is the ground between the feet (BosunRig); footprint centre is not the bbox centre",
        },
    }
