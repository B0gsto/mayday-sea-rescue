"""M_Kit_TriageTags: three waterproof casualty triage tags (Red P1, Yellow P2, Green P3), kit set."""
import json
import math
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "tools/blender"))
import common
import dims
import maketex
from dims import (ATT_OUT, CARD_L, CARD_T, CARD_W, CODE, CORNER, D_OUT, EYE, EYE_LIFT, EYE_R, EYE_SEG, HOLE_R,
                  NC, NR, P_SIDE, PLACE, TAGS, WARP_A, WARP_PH, WARP_T, WIRE_PATH, WIRE_T, WIRE_W, WORD)

S = common.STUDS_PER_METRE
NAME = "M_Kit_TriageTags"
MI = "MI_TriageTags_Kit"
Z0 = WARP_A + WARP_T + 0.0004


def cl(v, a=0.0, b=1.0):
    return a if v < a else b if v > b else v


def warp(x, y, ph):
    u, v = x / CARD_L, y / CARD_W
    return WARP_A * math.sin(2.0 * math.pi * u + ph) + WARP_T * math.sin(math.pi * u) * v * 0.5


def pillow(x, y):
    u = abs(x) / (CARD_L * 0.5)
    v = abs(y) / (CARD_W * 0.5)
    return max(0.0, 1.0 - u ** 5) * max(0.0, 1.0 - v ** 5)


def face_z(x, y, ph):
    return Z0 + CARD_T * pillow(x, y) + warp(x, y, ph)


def back_z(x, y, ph):
    return Z0 + warp(x, y, ph)


def place(tag, p):
    a = math.radians(PLACE[tag][2])
    c, s = math.cos(a), math.sin(a)
    return (PLACE[tag][0] + p[0] * c - p[1] * s, PLACE[tag][1] + p[0] * s + p[1] * c)


class Buf:
    def __init__(self):
        self.v = []
        self.f = []

    def add(self, p):
        self.v.append((p[0] * S, p[1] * S, p[2] * S))
        return len(self.v) - 1

    def face(self, ids, lane, uvs):
        if len(set(ids)) < 3:
            return
        self.f.append((tuple(ids), lane, tuple(dims.uv(lane, u, v) for u, v in uvs)))

    def to_object(self, obj_name, material):
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new(common.UV_NAME)
        bv = [bm.verts.new(p) for p in self.v]
        for idx, lane, uvs in self.f:
            try:
                f = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            for loop, uv in zip(f.loops, uvs):
                loop[uvl].uv = uv
        mesh = bpy.data.meshes.new(obj_name)
        bm.to_mesh(mesh)
        bm.free()
        for p in mesh.polygons:
            p.use_smooth = True
        try:
            mesh.set_sharp_from_angle(angle=math.radians(30.0))
        except Exception:
            pass
        obj = bpy.data.objects.new(obj_name, mesh)
        obj.data.materials.append(material)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def grid_uv(i, j):
    return (i / float(NC), j / float(NR))


def build_card(Bu, tag):
    ph = WARP_PH[tag]
    lane = dims.FRONT_LANE[tag]
    back = dims.BACK_LANE[tag]
    xs = [-CARD_L * 0.5 + CARD_L * i / NC for i in range(NC + 1)]
    ys = [-CARD_W * 0.5 + CARD_W * j / NR for j in range(NR + 1)]
    xs[0] += CORNER
    xs[-1] -= CORNER
    ys[0] += CORNER
    ys[-1] -= CORNER
    top, bot = {}, {}
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            z = face_z(x, y, ph)
            p = place(tag, (x, y, 0.0))
            top[(i, j)] = Bu.add((p[0], p[1], z))
            bot[(i, j)] = Bu.add((p[0], p[1], back_z(x, y, ph)))
    for j in range(NR):
        for i in range(NC):
            u0, v0 = grid_uv(i, j)
            u1, v1 = grid_uv(i + 1, j + 1)
            Bu.face([top[(i, j)], top[(i + 1, j)], top[(i + 1, j + 1)], top[(i, j + 1)]],
                    lane, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
            Bu.face([bot[(i, j + 1)], bot[(i + 1, j + 1)], bot[(i + 1, j)], bot[(i, j)]],
                    back, [(u0, v1), (u1, v1), (u1, v0), (u0, v0)])


def build_eyelet(Bu, tag):
    ph = WARP_PH[tag]
    c = place(tag, (EYE[0], EYE[1], 0.0))
    ztop = face_z(EYE[0], EYE[1], ph) + EYE_LIFT
    zface = face_z(EYE[0], EYE[1], ph)
    inner, outer = [], []
    for k in range(EYE_SEG):
        a = 2.0 * math.pi * k / EYE_SEG
        ca, sa = math.cos(a), math.sin(a)
        for rr, dst in ((HOLE_R, inner), (EYE_R, outer)):
            p = place(tag, (EYE[0] + rr * ca, EYE[1] + rr * sa, 0.0))
            dst.append(Bu.add((p[0], p[1], ztop)))
    for k in range(EYE_SEG):
        k2 = (k + 1) % EYE_SEG
        u0, u1 = k / float(EYE_SEG), (k + 1) / float(EYE_SEG)
        Bu.face([inner[k], outer[k], outer[k2], inner[k2]], "Eyelet",
                [(u0, 0.0), (u0, 1.0), (u1, 1.0), (u1, 0.0)])
    base = []
    for k in range(EYE_SEG):
        a = 2.0 * math.pi * k / EYE_SEG
        p = place(tag, (EYE[0] + EYE_R * math.cos(a), EYE[1] + EYE_R * math.sin(a), 0.0))
        base.append(Bu.add((p[0], p[1], zface)))
    for k in range(EYE_SEG):
        k2 = (k + 1) % EYE_SEG
        u0, u1 = k / float(EYE_SEG), (k + 1) / float(EYE_SEG)
        Bu.face([outer[k], base[k], base[k2], outer[k2]], "Eyelet",
                [(u0, 1.0), (u0, 0.94), (u1, 0.94), (u1, 1.0)])


def path_pts(tag):
    ph = WARP_PH[tag]
    out = []
    for a, b, h in WIRE_PATH:
        x = EYE[0] + D_OUT[0] * a + P_SIDE[0] * b
        y = EYE[1] + D_OUT[1] * a + P_SIDE[1] * b
        out.append((x, y, face_z(EYE[0], EYE[1], ph) + h))
    return out


def build_wire(Bu, tag):
    pts = path_pts(tag)
    cum = [0.0]
    for a, b in zip(pts, pts[1:]):
        cum.append(cum[-1] + math.dist(a, b))
    total = cum[-1]
    half = WIRE_W * 0.5
    left, right = [], []
    for p, s in zip(pts, cum):
        u = s / total
        q = place(tag, (p[0] + P_SIDE[0] * half, p[1] + P_SIDE[1] * half, 0.0))
        r = place(tag, (p[0] - P_SIDE[0] * half, p[1] - P_SIDE[1] * half, 0.0))
        left.append((Bu.add((q[0], q[1], p[2])), u))
        right.append((Bu.add((r[0], r[1], p[2])), u))
    for k in range(len(pts) - 1):
        u0, u1 = left[k][1], left[k + 1][1]
        Bu.face([left[k][0], left[k + 1][0], right[k + 1][0], right[k][0]], "Wire",
                [(u0, 1.0), (u1, 1.0), (u1, 0.0), (u0, 0.0)])
        Bu.face([right[k][0], right[k + 1][0], left[k + 1][0], left[k][0]], "Wire",
                [(u0, 0.0), (u1, 0.0), (u1, 1.0), (u0, 1.0)])


def material():
    mat = bpy.data.materials.new(MI)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.62, 0.20, 0.18, 1.0)
    b.inputs["Roughness"].default_value = 0.46
    b.inputs["Metallic"].default_value = 0.0
    return mat


def empty(name, p):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.04
    e.location = (p[0] * S, p[1] * S, p[2] * S)
    bpy.context.scene.collection.objects.link(e)
    return e


def attach_pos(tag):
    ph = WARP_PH[tag]
    a = WIRE_PATH[3][0] + ATT_OUT
    x = EYE[0] + D_OUT[0] * a
    y = EYE[1] + D_OUT[1] * a
    return place(tag, (x, y, 0.0)) + (face_z(EYE[0], EYE[1], ph) + WIRE_PATH[3][2],)


def clear():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_"):
            bpy.data.objects.remove(o, do_unlink=True)


def build():
    clear()
    Bu = Buf()
    atts = []
    for tag in TAGS:
        build_card(Bu, tag)
        build_eyelet(Bu, tag)
        build_wire(Bu, tag)
    lo = [min(v[i] for v in Bu.v) for i in range(3)]
    hi = [max(v[i] for v in Bu.v) for i in range(3)]
    shift = (-(lo[0] + hi[0]) * 0.5, -(lo[1] + hi[1]) * 0.5, -lo[2])
    Bu.v = [(v[0] + shift[0], v[1] + shift[1], v[2] + shift[2]) for v in Bu.v]
    for tag in TAGS:
        p = attach_pos(tag)
        atts.append(empty("ATT_Tie_%s" % tag, (p[0] + shift[0] / S, p[1] + shift[1] / S, p[2] + shift[2] / S)))
    lod0 = Bu.to_object(NAME + "_LOD0", material())
    with open(os.path.join(HERE, "features.json"), "w", encoding="utf-8") as f:
        json.dump({"tags": list(TAGS)}, f, indent=1)
    def wpt(tag, p):
        q = place(tag, p)
        return ((q[0] + shift[0] / S) * S, (q[1] + shift[1] / S) * S, (p[2] + shift[2] / S) * S)

    maketex.build(common.textures_dir(NAME))
    tris = sum(len(p.vertices) - 2 for p in lod0.data.polygons)
    lo = [min(v.co[i] for v in lod0.data.vertices) / S for i in range(3)]
    hi = [max(v.co[i] for v in lod0.data.vertices) / S for i in range(3)]
    print("[%s] tris %d, bbox m %.3f x %.3f x %.3f" % (NAME, tris, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))
    return {
        "name": NAME, "budget": "small_prop", "tris": 300, "tier": "standard",
        "dims_m": (round(hi[0] - lo[0], 3), round(hi[1] - lo[1], 3), round(hi[2] - lo[2], 3)),
        "size_note": None, "origin": "base",
        "sets": [{"name": "TriageTags", "set": "Kit", "size": dims.SIZE, "wet": True,
                  "dir": common.textures_dir(NAME)}],
        "meshes": [{"object": lod0, "set": "Kit"}],
        "attachments": atts,
        "waivers": {"LOD0 floor": "docs/12 caps these three flat 200 x 120 mm cards at 300 tris; 500 would add "
                                 "invisible tessellation to a P1 kit prop"},
        "closeups": [
            {"name": "red_face", "target": wpt("Red", (0.0, 0.0, 0.008)), "dist": 1.7, "az": 16.0, "el": 50.0},
            {"name": "eyelet_wire", "target": wpt("Red", (EYE[0], EYE[1], 0.012)), "dist": 0.95, "az": 8.0, "el": 42.0},
            {"name": "yellow_edge", "target": wpt("Yellow", (0.075, 0.0, 0.006)), "dist": 1.5, "az": 338.0, "el": 14.0},
            {"name": "green_face", "target": wpt("Green", (0.0, 0.0, 0.008)), "dist": 1.7, "az": 344.0, "el": 50.0},
        ],
    }
