"""C2 M_Sea_Liferaft: a SOLAS 12-person throw-over liferaft, inflated (generic, not a replica). Op 3 (Capsized Ferry)
liferaft pick-up; docs/12 2.1 lists it as M_Veh_Liferaft (the C2 brief names it M_Sea_Liferaft).

Two stacked black buoyancy tubes (2.9 m over the tubes), floor, orange domed canopy held up by an inflatable arch,
two entrances (bow -Y: inflatable yellow boarding ramp; stern +Y: webbing boarding ladder with rigid rungs), rolled
entrance flaps, retro-reflective tape, lifeline in scallops round the upper tube, canopy light, four ballast pockets
under the floor, a drogue line. Pivot = centre of the base (ballast pocket bottoms); waterline at ATT_Waterline.
MeshParts: Canopy (outer + inner shell, arch, flaps, light; T_Liferaft_Canopy), Tubes (tubes, floor, ramp, ladder,
lifeline, ballast pockets, drogue line; T_Liferaft_Tubes).
"""
import math
import os
import sys

import bpy  # noqa: F401
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../_C2"))
import c2geo as C  # noqa: E402
from c2geo import Buf, V, W  # noqa: E402

NAME = "M_Sea_Liferaft"
BUDGET, BUDGET_TRIS = "small_craft", 6000
R, r = 1.22, 0.225                     # tube ring radius (to the tube centre), tube radius -> 2.89 m over the tubes
Z0 = 0.30                              # lower tube centre above the base (ballast pockets hang below)
Z1 = Z0 + 2 * r * 0.92                 # upper tube centre
WL = Z0 + 0.02
BANDS = {"tube": (0.00, 0.40), "floor": (0.40, 0.55), "ramp": (0.55, 0.70), "webbing": (0.70, 0.80),
         "lifeline": (0.80, 0.90), "ballast": (0.90, 1.00)}


def band(k, tu=1.0):
    v0, v1 = BANDS[k]
    return ("strip", v0 + 0.004, v1 - 0.004, tu)


def entrance(a, z):
    """Openings: centred on -Y (a = -90 deg) and +Y (a = +90 deg), 0.8 m wide, up to 0.85 m above the upper tube."""
    for ac in (-math.pi / 2, math.pi / 2):
        d = abs((a - ac + math.pi) % (2 * math.pi) - math.pi)
        if d < 0.30 and z < Z1 + r + 0.75:
            return True
    return False


def canopy_profile():
    pts = []
    for k in range(11):
        t = k / 10
        rad = (R + 0.05) * (1 - t ** 2.2) ** 0.55 if t < 1 else 0.0
        z = Z1 + r * 0.6 + 0.95 * math.sin(t * math.pi / 2) ** 0.9
        pts.append((max(rad, 0.0), z))
    pts[-1] = (0.0, pts[-1][1])
    return pts


def build_canopy():
    b = Buf()
    prof = canopy_profile()
    n = 28
    C.lathe_strip(b, prof, n, 0.0, 1.0, 4, skip=entrance)
    n_outer = len(b.f)
    # inner shell (darker orange read through the openings): same set, inward faces, 6 cm inside
    inner = [(max(p[0] - 0.06, 0.0), p[1] - 0.05) for p in prof]
    C.lathe_strip(b, inner, n, 0.0, 1.0, 4, skip=entrance, flip=True)
    n_inner = len(b.f)
    # entrance jambs (fabric returns between the shells) and rolled flaps above each opening
    for ac in (-math.pi / 2, math.pi / 2):
        for da in (-0.30, 0.30):
            a = ac + da
            pts = []
            for p in prof:
                if p[1] < Z1 + r + 0.75 and p[0] > 0:
                    pts.append(V(p[0] * math.cos(a), p[0] * math.sin(a), p[1]))
            if len(pts) >= 2:
                W.sweep(b, pts, W.rect_profile(0.06, 0.07), ("strip", 0.02, 0.12, 1.0))
        top_z = Z1 + r + 0.78
        rr = (R + 0.05) * 0.86
        flap = [V(rr * math.cos(ac + d), rr * math.sin(ac + d), top_z) for d in (-0.33, -0.15, 0.0, 0.15, 0.33)]
        C.tube(b, flap, 0.07, ("strip", 0.30, 0.42, 1.0), sides=8)
    # inflatable arch over the top (along X, between the entrances) under a canopy ridge
    arch = []
    for k in range(13):
        a = math.pi * k / 12
        x = math.cos(a) * (R * 0.98)
        t = abs(math.cos(a))
        prof_z = Z1 + r * 0.6 + 0.95 * math.sin((1 - t) * math.pi / 2) ** 0.9 - 0.1
        arch.append(V(x, 0, max(prof_z, Z1 + 0.2)))
    C.tube(b, arch, 0.11, ("strip", 0.50, 0.62, 1.0), sides=8)
    # canopy light + rain catcher at the apex
    apex = prof[-1][1]
    C.tube(b, [V(0, 0, apex - 0.02), V(0, 0, apex + 0.12)], 0.045, ("strip", 0.86, 0.90, 0.3), sides=8)
    # C2b: arch inflation / topping-up valves (dark grey moulding, silver cap ring) on reinforcing patches, both legs
    HWS, TAPE = ("strip", 0.962, 0.995, 0.3), ("strip", 0.845, 0.875, 0.3)
    for k in (3, 9):
        p, t = arch[k], (arch[k + 1] - arch[k - 1])
        n = Vector((-t.z, 0, t.x)).normalized()
        if n.dot(p - V(0, 0, Z1)) < 0:
            n = -n
        p = p + n * 0.105
        W.sweep(b, [p - n * 0.01, p + n * 0.012], W.round_profile(0.085, 14), ("strip", 0.20, 0.28, 0.3), up_hint=(0, 1, 0))
        C.tube(b, [p, p + n * 0.065], 0.034, HWS, sides=12, up_hint=(0, 1, 0))
        C.tube(b, [p + n * 0.062, p + n * 0.092], 0.041, TAPE, sides=12, up_hint=(0, 1, 0))
        C.tube(b, [p + n * 0.09, p + n * 0.10], 0.022, HWS, sides=8, up_hint=(0, 1, 0))
    return b, n_outer, n_inner


def build_tubes():
    b = Buf()
    T = band("tube", 1.0)
    for z in (Z0, Z1):
        W.ring(b, (0, 0, z), (1, 0, 0), (0, 1, 0), R, r, 32, 10, T)
    # floor (inflatable insulated floor, slightly sagging)
    rows, uvs = [], []
    for k in range(5):
        rad = (R - r * 0.6) * k / 4
        rows.append([V(rad * math.cos(2 * math.pi * i / 24), rad * math.sin(2 * math.pi * i / 24), Z0 - 0.10 + 0.04 * (k / 4) ** 2) for i in range(25)])
        uvs.append([(i / 24 * 4, BANDS["floor"][0] + 0.01 + 0.13 * k / 4) for i in range(25)])
    C.grid(b, rows, uvs, smooth=True, flip=True)
    # ballast pockets: four hemispherical bags under the floor
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        c = V(0.62 * math.cos(a), 0.62 * math.sin(a), 0.0)
        prof = [(0.0, 0.0), (0.18, 0.02), (0.30, 0.10), (0.34, 0.22), (0.32, Z0 - 0.08)]
        C.lathe_strip(b, prof, 12, BANDS["ballast"][0] + 0.005, BANDS["ballast"][1] - 0.005, 2, centre=tuple(c))
    # boarding ramp at the -Y entrance: an inflated platform at the waterline lashed to the lower tube: two side
    # tubes, an outer cross tube, a deck panel between them and a fabric apron up to the entrance sill
    RP = band("ramp", 1.0)
    yi, yo, zr = -(R + r * 0.35), -(R + r + 0.80), Z0 - 0.02
    for sx in (-0.40, 0.40):
        C.tube(b, [V(sx, yi, zr + 0.04), V(sx, (yi + yo) / 2, zr), V(sx, yo, zr - 0.03)], 0.12, RP, sides=10)
    C.tube(b, [V(-0.40, yo, zr - 0.03), V(0.0, yo - 0.04, zr - 0.03), V(0.40, yo, zr - 0.03)], 0.12, RP, sides=10)
    rows = [[V(x, y, zr + 0.06 - 0.03 * k) for x in (-0.40, 0.40)] for k, y in enumerate((yi, (yi + yo) / 2, yo))]
    uv = [[(0, BANDS["ramp"][0] + 0.01), (0.8, BANDS["ramp"][0] + 0.01)], [(0, 0.62), (0.8, 0.62)], [(0, BANDS["ramp"][1] - 0.01), (0.8, BANDS["ramp"][1] - 0.01)]]
    C.grid(b, rows, uv, smooth=False)
    C.grid(b, [[p - V(0, 0, 0.04) for p in row] for row in rows], uv, smooth=False, flip=True)
    apron = [[V(x, -(R + r * 0.55), zr + 0.06), V(x, -(R + r * 0.75), Z1 - 0.05)] for x in (-0.40, 0.40)]
    C.grid(b, [list(p) for p in zip(*apron)], [[(0, 0.56), (0.8, 0.56)], [(0, 0.69), (0.8, 0.69)]], smooth=False)
    C.grid(b, [list(p) for p in zip(*apron)], [[(0, 0.56), (0.8, 0.56)], [(0, 0.69), (0.8, 0.69)]], smooth=False, flip=True)
    # grab handles on the ramp tubes
    # boarding ladder at the +Y entrance: two webbing straps over the upper tube with 3 rungs
    WB = band("webbing", 1.0)
    ytop = R + r * 0.1
    for sx in (-0.22, 0.22):
        pts = [V(sx, R - 0.25, Z1 + r + 0.02), V(sx, R, Z1 + r + 0.04), V(sx, R + r + 0.02, Z1 + 0.05), V(sx, R + r + 0.03, Z0),
               V(sx, R + r - 0.02, Z0 - 0.45), V(sx, R + r - 0.08, Z0 - 0.75)]
        W.sweep(b, pts, W.rect_profile(0.08, 0.012), WB, up_hint=(0, 1, 0))
    for z in (Z0 + 0.05, Z0 - 0.2, Z0 - 0.48, Z0 - 0.73):
        y = R + r + 0.02 - 0.1 * max(0.0, Z0 - z)
        C.tube(b, [V(-0.26, y, z), V(0.26, y, z)], 0.032, band("ramp", 1.0), sides=8)
    # lifeline: scallops between 16 patches round the upper tube's outside
    LL = band("lifeline", 0.5)
    pts = []
    m = 16
    for k in range(m):
        a0, a1 = 2 * math.pi * k / m, 2 * math.pi * (k + 1) / m
        for t in (0.0, 0.25, 0.5, 0.75):
            a = a0 + (a1 - a0) * t
            sag = 0.10 * math.sin(math.pi * t)
            pts.append(V((R + r + 0.03) * math.cos(a), (R + r + 0.03) * math.sin(a), Z1 + 0.02 - sag))
    pts.append(pts[0])
    C.tube(b, pts, 0.011, LL, sides=4, caps=(False, False))
    # C2b: topping-up valves on the upper tube either side of the ramp entrance (grey-blue moulding)
    for a in (math.radians(-62), math.radians(-118)):
        n = V(math.cos(a) * 0.45, math.sin(a) * 0.45, 0.89).normalized()
        p = V(R * math.cos(a), R * math.sin(a), Z1) + n * r
        C.tube(b, [p - n * 0.01, p + n * 0.05], 0.03, band("floor", 0.3), sides=10, up_hint=(1, 0, 0))
        C.tube(b, [p + n * 0.05, p + n * 0.075], 0.036, band("lifeline", 0.3), sides=10, up_hint=(1, 0, 0))
    # drogue line paying out astern
    C.tube(b, C.catenary(V(0.5, R + r, Z1), V(0.9, R + 2.4, WL - 0.05), 0.15, 6), 0.009, LL, sides=4)
    return b


def build():
    C.clear_scene()
    import bmesh
    parts = {}
    cb, n_outer, n_inner = build_canopy()
    for k, buf, st in (("Canopy", cb, "Canopy"), ("Tubes", build_tubes(), "Tubes")):
        o = buf.to_object("%s_%s_LOD0" % (NAME, k), "MI_%s_Liferaft_%s" % (NAME, st))
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.faces.ensure_lookup_table()
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if k == "Canopy":     # shells: outer faces out, inner faces in (recalc cannot know an open shell's side)
            for i, f in enumerate(bm.faces):
                if i >= n_inner:
                    break
                c = f.calc_center_median()
                out = (c - Vector((0, 0, Z1))).dot(f.normal) > 0
                if out != (i < n_outer):
                    f.normal_flip()
        bm.to_mesh(o.data)
        bm.free()
        parts[k] = o
    atts = [W.empty("ATT_Waterline", (0, 0, WL)), W.empty("ATT_Entrance_Ramp", (0, -(R + r), Z1), look=(0, -1, 0)),
            W.empty("ATT_Entrance_Ladder", (0, R + r, Z1), look=(0, 1, 0)), W.empty("ATT_Light", (0, 0, canopy_profile()[-1][1] + 0.12)),
            W.empty("ATT_Painter", (0.5, R + r, Z1))]
    for i in range(6):        # seated survivors round the inside of the tube (12 places, 6 markers)
        a = math.pi / 6 + i * math.pi / 3
        atts.append(W.empty("ATT_Seat_%02d" % (i + 1), (0.85 * math.cos(a), 0.85 * math.sin(a), Z0 - 0.05), look=(-math.cos(a), -math.sin(a), 0)))
    col = W.col_boxes([((0, 0, Z0 + 0.25), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (R + r, R + r, 0.45)),
                       ((0, 0, Z1 + 0.75), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (R * 0.8, R * 0.8, 0.5))], NAME + "_COL")
    lods = C.make_lods(parts, BUDGET, BUDGET_TRIS)
    vis = list(parts.values())
    W.shift_to_base(vis + [col], empties=atts, others=[o for o, _, _ in lods])
    lo, hi = W.bbox(vis)
    tri = {k: C.tri_count(o) for k, o in parts.items()}
    print("[C2] liferaft tris", tri, "total", sum(tri.values()), "bbox m %.2f x %.2f x %.2f" % tuple((hi - lo) / W.S))
    meshes = [{"object": o, "set": k} for k, o in parts.items()] + [{"object": col}]
    meshes += [{"object": o, "role": "visual", "lod": lod, "of": src.name, "set": next(m["set"] for m in meshes if m["object"] is src)}
               for o, lod, src in lods]
    return {
        "name": NAME, "budget": BUDGET, "tris": BUDGET_TRIS, "tier": "standard",
        "dims_m": (2.9, None, None), "size_note": None, "origin": "base", "tiling": True,
        "sets": [{"name": "Liferaft", "set": st, "size": 1024, "wet": True} for st in ("Canopy", "Tubes")],
        "meshes": meshes, "attachments": atts,
        "waivers": {"LOD UV layout": "lifeline, ladder and drogue strips decimate into fewer islands; every LOD samples the same trim sets"},
    }
