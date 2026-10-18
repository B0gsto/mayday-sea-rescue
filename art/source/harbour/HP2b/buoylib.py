"""HP2b (docs/12 2.3): IALA Region A pillar buoys and mooring / pick-up buoys, built in Blender from code.

Every asset is one joined mesh built in metres (Z up, z 0 = waterline, buoy axis = Z), with a face attribute `part`
(P_* below). Pipeline per asset (one Blender run):
  1. geometry, smart UVs, smooth-by-angle;
  2. G-buffer bake (Cycles EMIT: object position, normal, part id, pointiness, AO) to a 2048 npz cache
     (HP2B_BAKE=1, or no cache yet);
  3. compose.py turns the G-buffer + CC0 Poly Haven scans into the PBR set (2048 masters in textures/, 1024 maps to
     assets/textures/<Asset>/, _Wet ALB/RGH, signal_mask.png);
  4. the lens faces split off as their own MeshPart (<Name>_Lens_LOD0, same set) for the game's Neon flash;
  5. scaled to studs (x3), transforms applied, _COL hulls, ATT_WaterLine / ATT_Light / ATT_Mooring (+ ATT_Bell).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import marks  # noqa: E402
import compose  # noqa: E402

import common  # noqa: E402  (tools/blender, on the path under run.py)
import rbxkit  # noqa: E402

S = common.STUDS_PER_METRE
GBUF = int(os.environ.get("HP2B_GBUF", "2048"))
P_BODY, P_FENDER, P_CAGE, P_LENS, P_LAMP, P_SOLAR, P_GALV, P_BELL, P_TOP, P_CHAIN, P_ROPE = range(11)
SMOOTH = {P_BODY, P_FENDER, P_LENS, P_BELL, P_TOP, P_CHAIN, P_ROPE, P_CAGE}


class Geo:
    def __init__(self):
        self.bm = bmesh.new()
        self.layer = self.bm.faces.layers.int.new("part")

    def face(self, verts, part, smooth=True):
        f = self.bm.faces.new(verts)
        f[self.layer] = part
        f.smooth = smooth
        return f

    def ring(self, r, z, seg, m=None, phase=0.0):
        m = m or Matrix()
        if r <= 1e-6:
            return [self.bm.verts.new(m @ Vector((0.0, 0.0, z)))]
        return [self.bm.verts.new(m @ Vector((r * math.cos(2 * math.pi * (i + phase) / seg),
                                              r * math.sin(2 * math.pi * (i + phase) / seg), z))) for i in range(seg)]

    def lathe(self, profile, seg, part, m=None, parts=None, phase=0.0, smooth=True):
        """profile: [(r, z)] bottom to top; r 0 ends become poles. parts: per-span part ids (len(profile) - 1)."""
        rings = [self.ring(r, z, seg, m, phase) for r, z in profile]
        for k, (a, b) in enumerate(zip(rings, rings[1:])):
            p = parts[k] if parts else part
            for i in range(seg):
                j = (i + 1) % seg
                if len(a) == 1 and len(b) == 1:
                    continue
                if len(a) == 1:
                    self.face((a[0], b[i], b[j]), p, smooth)
                elif len(b) == 1:
                    self.face((a[j], a[i], b[0]), p, smooth)
                else:
                    self.face((a[i], a[j], b[j], b[i]), p, smooth)
        if len(rings[0]) > 1:
            self.face(list(reversed(rings[0])), part, False)
        if len(rings[-1]) > 1:
            self.face(rings[-1], part, False)

    def tube(self, p0, p1, r, sides, part, caps=True, smooth=True):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        m = Matrix.Translation(p0) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        prof = [(r, 0.0), (r, d.length)]
        rings = [self.ring(rr, z, sides, m) for rr, z in prof]
        for i in range(sides):
            j = (i + 1) % sides
            self.face((rings[0][i], rings[0][j], rings[1][j], rings[1][i]), part, smooth)
        if caps:
            self.face(list(reversed(rings[0])), part, False)
            self.face(rings[1], part, False)

    def sweep(self, pts, r, sides, part, closed=False, caps=True):
        """Circle of radius r swept along the polyline pts (parallel-transport frames)."""
        pts = [Vector(p) for p in pts]
        n = len(pts)
        tangents = []
        for i in range(n):
            a = pts[(i - 1) % n] if (closed or i > 0) else pts[i]
            b = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
            tangents.append((b - a).normalized())
        ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
        u = tangents[0].cross(ref).normalized()
        rings = []
        for i in range(n):
            t = tangents[i]
            u = (u - t * u.dot(t)).normalized()
            v = t.cross(u)
            rings.append([self.bm.verts.new(pts[i] + (u * math.cos(2 * math.pi * k / sides) + v * math.sin(2 * math.pi * k / sides)) * r)
                          for k in range(sides)])
        spans = n if closed else n - 1
        for i in range(spans):
            a, b = rings[i], rings[(i + 1) % n]
            for k in range(sides):
                kk = (k + 1) % sides
                self.face((a[k], a[kk], b[kk], b[k]), part)
        if caps and not closed:
            self.face(list(reversed(rings[0])), part, False)
            self.face(rings[-1], part, False)

    def torus(self, centre, R, r, seg, sides, part, normal=(0, 0, 1)):
        m = Matrix.Translation(Vector(centre)) @ Vector(normal).to_track_quat("Z", "Y").to_matrix().to_4x4()
        pts = [m @ Vector((R * math.cos(2 * math.pi * i / seg), R * math.sin(2 * math.pi * i / seg), 0.0)) for i in range(seg)]
        self.sweep(pts, r, sides, part, closed=True)

    def link(self, centre, axis, turn, length, width, wire, part, sides=4, path=8):
        """One chain link: a stadium of outer length `length`, width `width`, wire radius `wire`; its long axis along
        `axis`, rotated `turn` radians about it (alternate links 90 degrees)."""
        a = (length - width) / 2.0
        rr = (width - 2 * wire) / 2.0 + wire
        pts = []
        half = path // 2
        for k in range(half):
            t = math.pi * k / (half - 1)
            pts.append(Vector((rr * math.cos(t), 0.0, a + rr * math.sin(t))))
        for k in range(half):
            t = math.pi + math.pi * k / (half - 1)
            pts.append(Vector((rr * math.cos(t), 0.0, -a + rr * math.sin(t))))
        m = Matrix.Translation(Vector(centre)) @ Vector(axis).to_track_quat("Z", "X").to_matrix().to_4x4() @ Matrix.Rotation(turn, 4, "Z")
        self.sweep([m @ p for p in pts], wire, sides, part, closed=True)

    def chain(self, top, bottom, pitch, width, wire, part, sway=0.0):
        top, bottom = Vector(top), Vector(bottom)
        n = max(1, int((top - bottom).length / pitch))
        for i in range(n):
            t = (i + 0.5) / n
            c = top.lerp(bottom, t)
            c.x += sway * math.sin(t * math.pi)
            axis = (bottom - top).normalized()
            self.link(c, axis, (math.pi / 2) * (i % 2), pitch * 1.55, width, wire, part)

    def box(self, centre, size, part, rot=None):
        m = Matrix.Translation(Vector(centre)) @ (rot or Matrix())
        sx, sy, sz = (s / 2.0 for s in size)
        vs = [self.bm.verts.new(m @ Vector((x, y, z))) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.face([vs[i] for i in q], part, False)

    def to_object(self, name):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


# ------------------------------------------------------------------ pillar buoy (metres)

FLOAT = [(0.0, -2.05), (0.15, -2.05), (0.18, -2.0), (0.18, -1.08), (0.32, -0.98), (0.62, -0.78), (0.84, -0.52),
         (0.90, -0.40), (0.90, 0.30), (0.94, 0.33), (0.94, 0.42), (0.90, 0.45), (0.88, 0.50), (0.84, 0.53),
         (0.30, 0.56), (0.0, 0.565)]
FLOAT_PARTS = [P_BODY] * 8 + [P_FENDER] * 3 + [P_BODY] * 4
DECK, PLAT = 0.56, 2.62
LEG_FOOT_R, LEG_TOP_R = 0.62, 0.30
LENS_Z = (2.80, 3.00)
SEG = 24


def leg_r(z):
    return LEG_FOOT_R + (LEG_TOP_R - LEG_FOOT_R) * (z - DECK) / (PLAT - DECK)


TS = 1.5          # HP2b-fix: topmarks 1.5x (0.66 m cardinal cones, 0.57 m can) so they read at range


def topmark(g, kind, z0):
    """Returns the top z. IALA Region A topmark shapes."""
    seg = 20
    if kind == "can":
        r, h = 0.19 * TS, 0.38 * TS
        g.lathe([(0.0, z0), (r, z0), (r, z0 + h), (0.0, z0 + h)], seg, P_TOP)
        return z0 + h
    if kind == "cone":
        r, h = 0.25 * TS, 0.44 * TS
        g.lathe([(0.0, z0), (r, z0), (0.012 * TS, z0 + h), (0.0, z0 + h + 0.005)], seg, P_TOP)
        return z0 + h + 0.005
    if kind in ("ball", "balls2"):
        r = (0.21 if kind == "ball" else 0.17) * TS
        n = 1 if kind == "ball" else 2
        gap = 0.10
        z = z0
        steps, bseg = (8, seg) if n == 1 else (6, 16)     # two balls: lighter spheres to stay in the 3,000 row
        for _ in range(n):
            prof = [(r * math.sin(math.pi * k / steps), z + r - r * math.cos(math.pi * k / steps)) for k in range(steps + 1)]
            g.lathe(prof, bseg, P_TOP)
            z += 2 * r + gap
        return z - gap
    # cardinal cones r 0.33 h 0.45; a clear 0.16 m gap with the mast showing, so base-to-base (East) reads as two
    # cones, not one diamond, and point-to-point (West) as a wineglass
    r, h, gap = 0.22 * TS, 0.30 * TS, 0.16
    up = lambda zb: g.lathe([(0.0, zb), (r, zb), (0.01, zb + h), (0.0, zb + h + 0.003)], seg, P_TOP)
    down = lambda zb: g.lathe([(0.0, zb - 0.003), (0.01, zb), (r, zb + h), (0.0, zb + h)], seg, P_TOP)
    lower, upper = {"cones_up": (up, up), "cones_down": (down, down), "cones_base": (down, up),
                    "cones_point": (up, down)}[kind]
    lower(z0)
    upper(z0 + h + gap)
    return z0 + 2 * h + gap


def pillar(kind):
    cfg = marks.NAVMARKS[kind]
    g = Geo()
    g.lathe(FLOAT, SEG, P_BODY, parts=FLOAT_PARTS)
    bell = cfg.get("bell")
    # central column (the pillar) and cage legs
    col_top = 1.15 if bell else PLAT
    # HP2b-fix: solid tapered pillar (0.80 m at the deck to 0.48 m under the platform) so every paint band, the top
    # band included, has real painted area and reads at range, not just thin cage tubes
    if bell:
        g.lathe([(0.27, DECK - 0.01), (0.25, DECK + 0.08), (0.24, col_top)], 18, P_CAGE)
    else:
        g.lathe([(0.40, DECK - 0.01), (0.37, DECK + 0.08), (0.24, col_top)], 20, P_CAGE)
    joints = []
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        foot = (LEG_FOOT_R * math.cos(a), LEG_FOOT_R * math.sin(a), DECK - 0.01)
        top = (LEG_TOP_R * math.cos(a), LEG_TOP_R * math.sin(a), PLAT)
        g.tube(foot, top, 0.036, 6, P_CAGE, caps=False)
        # rust bleeds from every welded joint: down the leg below hoops, brace ends and the platform, and from the
        # foot weld and lifting lug across the deck and down the float side
        legj = lambda zj: {"mode": "leg", "p0": list(foot), "p1": list(top), "z": zj}
        joints += [legj(PLAT - 0.03), legj(1.95), legj(1.25), legj(0.70),
                   {"mode": "radial", "a": a, "z": DECK + 0.02, "r0": 0.52},
                   {"mode": "radial", "a": a + 0.4, "z": DECK + 0.03, "r0": 0.66}]
        # diagonal brace between legs (lower bay)
        b = a + math.pi / 2
        z1, z2 = 0.70, 1.22
        g.tube((leg_r(z1) * math.cos(a), leg_r(z1) * math.sin(a), z1), (leg_r(z2) * math.cos(b), leg_r(z2) * math.sin(b), z2),
               0.018, 4, P_CAGE, caps=False)
        joints.append({"mode": "leg", "p0": [LEG_FOOT_R * math.cos(b), LEG_FOOT_R * math.sin(b), DECK - 0.01],
                       "p1": [LEG_TOP_R * math.cos(b), LEG_TOP_R * math.sin(b), PLAT], "z": z2})
        # deck lifting lugs and the gusset at each leg foot
        g.box((0.74 * math.cos(a + 0.4), 0.74 * math.sin(a + 0.4), DECK - 0.01), (0.10, 0.03, 0.09), P_CAGE,
              Matrix.Rotation(a + 0.4, 4, "Z"))
    for z in (1.25, 1.95):
        g.torus((0, 0, z), leg_r(z), 0.024, 24, 4, P_CAGE)
    # platform with a guard rail
    g.lathe([(0.0, PLAT - 0.03), (0.37, PLAT - 0.03), (0.37, PLAT + 0.02), (0.0, PLAT + 0.02)], 24, P_CAGE)
    g.torus((0, 0, 2.90), 0.35, 0.018, 20, 4, P_CAGE)
    for i in range(4):
        a = i * math.pi / 2
        g.tube((0.35 * math.cos(a), 0.35 * math.sin(a), PLAT), (0.35 * math.cos(a), 0.35 * math.sin(a), 2.90), 0.016, 4, P_CAGE, caps=False)
    # self-contained solar LED lantern: housing, 4 panels, Fresnel lens, cap, bird spikes
    g.lathe([(0.0, PLAT + 0.02), (0.14, PLAT + 0.02), (0.14, LENS_Z[0] - 0.02), (0.11, LENS_Z[0]), (0.0, LENS_Z[0])], 20, P_LAMP)
    for i in range(4):
        a = i * math.pi / 2
        g.box((0.155 * math.cos(a), 0.155 * math.sin(a), PLAT + 0.10), (0.022, 0.20, 0.13), P_SOLAR,
              Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.radians(-18), 4, "Y"))
    lz0, lz1 = LENS_Z
    ribs = [(0.0, lz0)] + [(0.098 if k % 2 == 0 else 0.106, lz0 + (lz1 - lz0) * k / 6.0) for k in range(7)] + [(0.0, lz1)]
    g.lathe(ribs, 20, P_LENS)
    g.lathe([(0.0, lz1), (0.125, lz1), (0.125, lz1 + 0.035), (0.07, lz1 + 0.06), (0.0, lz1 + 0.065)], 20, P_LAMP)
    for i in range(5):
        a = i * 2 * math.pi / 5
        g.tube((0.06 * math.cos(a), 0.06 * math.sin(a), lz1 + 0.05), (0.09 * math.cos(a), 0.09 * math.sin(a), lz1 + 0.17), 0.004, 3, P_GALV, caps=False)
    # topmark mast, radar reflector (octahedral corner cluster), topmark
    mz0 = lz1 + 0.06
    rz = mz0 + 0.27
    rot = Matrix.Rotation(math.pi / 4, 4, "Z")
    for size in ((0.32, 0.32, 0.006), (0.32, 0.006, 0.32), (0.006, 0.32, 0.32)):
        g.box((0, 0, rz), size, P_GALV, rot)
    top_z = topmark(g, cfg["top"], mz0 + 0.50)
    g.tube((0, 0, mz0), (0, 0, top_z - 0.02), 0.028, 6, P_TOP, caps=True)
    # bell: hung from a cross-bar at 2.05, four clappers swinging on rods from the upper hoop
    if bell:
        g.tube((-leg_r(2.05) * 0.72, -leg_r(2.05) * 0.72, 2.05), (leg_r(2.05) * 0.72, leg_r(2.05) * 0.72, 2.05), 0.025, 6, P_CAGE)
        prof = [(0.0, 1.50), (0.215, 1.50), (0.205, 1.53), (0.16, 1.62), (0.125, 1.78), (0.115, 1.90), (0.08, 1.96), (0.0, 1.97)]
        g.lathe(prof, 16, P_BELL)
        g.tube((0, 0, 1.96), (0, 0, 2.05), 0.03, 6, P_GALV)
        for i in range(4):
            a = i * math.pi / 2
            p = (0.31 * math.cos(a), 0.31 * math.sin(a))
            g.tube((p[0], p[1], 1.95), (p[0] * 0.95, p[1] * 0.95, 1.58), 0.008, 3, P_GALV, caps=False)
            g.lathe([(0.0, 1.52), (0.04, 1.54), (0.045, 1.58), (0.0, 1.60)], 6, P_GALV,
                    m=Matrix.Translation((p[0] * 0.92, p[1] * 0.92, 0.0)))
    # mooring eye under the tail and a chain stub
    g.torus((0, 0, -2.13), 0.07, 0.02, 10, 4, P_GALV, normal=(0, 1, 0))
    g.chain((0, 0, -2.20), (0.05, 0, -2.62), 0.105, 0.11, 0.019, P_CHAIN)
    obj = g.to_object(marks.asset_name(kind) + "_LOD0")
    info = {"kind": kind, "top_z": top_z, "lens_z": (lz0 + lz1) / 2.0, "bell": bool(bell), "r": 0.94,
            "bottom": -2.68, "rust_heights": [DECK, PLAT - 0.03, 0.30, LENS_Z[0]],
            "drop_tops": [DECK, PLAT + 0.02, top_z, lz1 + 0.06, 2.90], "joints": joints}
    return obj, info


def mooring(kind):
    cfg = marks.MOORINGS[kind]
    g = Geo()
    r = cfg["d"] / 2.0
    if kind == "MooringBuoy":
        zc = 0.10
        prof = []
        for k in range(13):
            t = math.pi * k / 12
            rr = r * math.sin(t) + (0.012 if k == 6 else 0.0)     # moulded equator rib
            prof.append((rr, zc - r * math.cos(t)))
        g.lathe(prof, 20, P_BODY)
        g.tube((0, 0, zc - r - 0.10), (0, 0, zc + r + 0.10), 0.03, 6, P_GALV)
        g.lathe([(0.0, zc + r - 0.02), (0.09, zc + r - 0.02), (0.09, zc + r + 0.02), (0.0, zc + r + 0.03)], 12, P_GALV)
        g.torus((0, 0, zc + r + 0.17), 0.075, 0.018, 12, 4, P_GALV, normal=(0, 1, 0))
        g.torus((0, 0, zc - r - 0.16), 0.06, 0.018, 10, 4, P_GALV, normal=(1, 0, 0))
        g.chain((0, 0, zc - r - 0.22), (0.10, 0.03, -1.80), 0.10, 0.10, 0.016, P_CHAIN, sway=0.05)
        bottom, top_z = -1.85, zc + r + 0.27
        rust = [zc + r, zc - r]
    else:
        zc = 0.04
        prof = []
        for k in range(12):
            t = math.pi * k / 11
            prof.append((r * math.sin(t), zc - r * math.cos(t)))
        prof[-1] = (0.05, zc + r - 0.005)
        prof += [(0.05, zc + r + 0.05), (0.0, zc + r + 0.055)]
        g.lathe(prof, 22, P_BODY)
        g.torus((0, 0, zc + r + 0.10), 0.055, 0.022, 10, 5, P_BODY, normal=(0, 1, 0))
        # pick-up line from the eye, over the side and down to a light riser chain
        e = zc + r + 0.10
        pts = [(0.0, 0.0, e + 0.03), (0.07, 0.0, e + 0.05), (0.16, 0.0, e - 0.02), (0.28, 0.0, zc + 0.15),
               (0.325, 0.0, zc), (0.31, 0.0, zc - 0.20), (0.25, 0.02, -0.45), (0.18, 0.04, -0.75), (0.14, 0.05, -1.0)]
        g.sweep(pts, 0.012, 6, P_ROPE)
        g.chain((0.14, 0.05, -1.03), (0.10, 0.08, -1.80), 0.075, 0.07, 0.011, P_CHAIN)
        bottom, top_z = -1.85, e + 0.09
        rust = [zc + r]
    obj = g.to_object(marks.asset_name(kind) + "_LOD0")
    return obj, {"kind": kind, "top_z": top_z, "bottom": bottom, "r": r + 0.02, "rust_heights": rust,
                 "drop_tops": [zc + r], "bell": False}


# ------------------------------------------------------------------ bake

def _gbuffer_material():
    mat = bpy.data.materials.new("MI_HP2b_GBuffer")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emi = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emi.outputs[0], out.inputs[0])
    tc = nt.nodes.new("ShaderNodeTexCoord")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    att = nt.nodes.new("ShaderNodeAttribute")
    att.attribute_name = "part"
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples, ao.inputs["Distance"].default_value = 16, 0.25
    def remap(sock, scale):
        m = nt.nodes.new("ShaderNodeVectorMath")
        m.operation = "MULTIPLY_ADD"
        nt.links.new(sock, m.inputs[0])
        m.inputs[1].default_value = (scale, scale, scale)
        m.inputs[2].default_value = (0.5, 0.5, 0.5)
        return m.outputs[0]
    pos = remap(tc.outputs["Object"], 0.1)
    nrm = remap(geo.outputs["Normal"], 0.5)
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = "MULTIPLY_ADD"
    nt.links.new(att.outputs["Fac"], div.inputs[0])
    div.inputs[1].default_value, div.inputs[2].default_value = 1.0 / 16.0, 1.0 / 32.0
    nt.links.new(div.outputs[0], comb.inputs[0])
    nt.links.new(geo.outputs["Pointiness"], comb.inputs[1])
    nt.links.new(ao.outputs["AO"], comb.inputs[2])
    tex = nt.nodes.new("ShaderNodeTexImage")
    nt.nodes.active = tex
    return mat, nt, emi, {"pos": pos, "nrm": nrm, "aux": comb.outputs[0]}, tex


def bake_gbuffer(obj, path, size=GBUF):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.bake.margin = 12
    scene.render.bake.use_clear = True
    mat, nt, emi, socks, tex = _gbuffer_material()
    saved = list(obj.data.materials)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    rbxkit.select_only(obj)
    out = {}
    for key, sock in socks.items():
        img = bpy.data.images.new("GB_" + key, size, size, alpha=True, float_buffer=True)
        img.colorspace_settings.name = "Non-Color"
        img.generated_color = (0, 0, 0, 0)
        tex.image = img
        nt.links.new(sock, emi.inputs["Color"])
        bpy.ops.object.bake(type="EMIT")
        a = np.empty(size * size * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        out[key] = a.reshape(size, size, 4)
        bpy.data.images.remove(img)
    obj.data.materials.clear()
    for m in saved:
        obj.data.materials.append(m)
    pos = (out["pos"][..., :3] - 0.5) * 10.0
    nrm = out["nrm"][..., :3] * 2.0 - 1.0
    aux = out["aux"]
    covered = out["pos"][..., 3] > 0.5
    part = np.where(covered, np.rint((aux[..., 0] - 1.0 / 32.0) * 16.0), -1).astype(np.int8)
    np.savez_compressed(path, pos=pos.astype(np.float16), nrm=nrm.astype(np.float16), part=part,
                        curv=aux[..., 1].astype(np.float16), ao=aux[..., 2].astype(np.float16), covered=covered)
    bpy.data.materials.remove(mat)


# ------------------------------------------------------------------ spec

def preview_material(name, alb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if os.path.isfile(alb):
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(alb, check_existing=True)
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def split_lens(obj, name):
    """Moves the P_LENS faces into their own object (UVs kept)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.faces.layers.int.get("part")
    lens_bm = bm.copy()
    lay2 = lens_bm.faces.layers.int.get("part")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[layer] == P_LENS], context="FACES")
    bmesh.ops.delete(lens_bm, geom=[f for f in lens_bm.faces if f[lay2] != P_LENS], context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    mesh = bpy.data.meshes.new(name)
    lens_bm.to_mesh(mesh)
    lens_bm.free()
    lens = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(lens)
    return lens


def hull_col(name, r, z0, z1, top_r=None, top_z=None, seg=8):
    g = Geo()
    prof = [(r, z0), (r, z1)]
    if top_r:
        prof += [(top_r, z1 + 0.01), (top_r, top_z)]
    g.lathe([(0.0, z0)] + prof + [(0.0, prof[-1][1])], seg, 0, smooth=False)
    return g.to_object(name)


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.location = Vector(loc) * S
    bpy.context.scene.collection.objects.link(e)
    return e


def finish(obj):
    obj.scale = (S, S, S)
    rbxkit.select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def ship_size(kind):
    """Nav marks ship at 2048: a 4.2 m pillar buoy with its underwater tail is 51 px/stud (standard tier) only at 2048."""
    return 2048 if kind in marks.NAVMARKS else 1024


def build(kind):
    navmark = kind in marks.NAVMARKS
    name = marks.asset_name(kind)
    tex = marks.tex_name(kind)
    src = os.path.join(common.SOURCE_DIR, "harbour", name)
    os.makedirs(src, exist_ok=True)
    obj, info = pillar(kind) if navmark else mooring(kind)
    rbxkit.select_only(obj)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50), keep_sharp_edges=True)
    rbxkit.smart_uv(obj, angle=60, margin=0.004)
    obj.data.uv_layers[0].name = common.UV_NAME
    gb = os.path.join(src, "textures", "gbuffer_%d.npz" % GBUF)
    os.makedirs(os.path.dirname(gb), exist_ok=True)
    if os.environ.get("HP2B_BAKE") == "1" or not os.path.isfile(gb):
        bake_gbuffer(obj, gb)
    out_dir = common.textures_dir(name)
    import json
    with open(os.path.join(src, "textures", "info.json"), "w") as f:
        json.dump(info, f)
    if os.environ.get("HP2B_COMPOSE", "1") == "1" or not os.path.isfile(os.path.join(out_dir, "T_%s_Buoy_ALB.png" % tex)):
        compose.compose(kind, info, gb, src, out_dir, tex, ship_size(kind))
    mat = preview_material("MI_%s_Buoy" % tex, os.path.join(out_dir, "T_%s_Buoy_ALB.png" % tex))
    obj.data.materials.append(mat)
    meshes = [{"object": obj, "set": "Buoy"}]
    if navmark:
        lens = split_lens(obj, name + "_Lens_LOD0")
        lens.data.materials.append(mat)
        meshes.append({"object": lens, "set": "Buoy"})
    for e in meshes:
        finish(e["object"])
    if navmark:
        col = hull_col(name + "_COL", 0.94, -2.05, 0.56, top_r=0.40, top_z=info["top_z"])
    else:
        col = hull_col(name + "_COL", info["r"], -0.40 if kind == "MooringBuoy" else -0.30, info["top_z"] - 0.1)
    finish(col)
    meshes.append({"object": col})
    atts = [empty("ATT_WaterLine", (0, 0, 0)), empty("ATT_Mooring", (0, 0, info["bottom"]))]
    if navmark:
        atts.append(empty("ATT_Light", (0, 0, info["lens_z"])))
        atts.append(empty("ATT_Topmark", (0, 0, info["top_z"])))
        if info["bell"]:
            atts.append(empty("ATT_Bell", (0, 0, 1.75)))
    else:
        atts.append(empty("ATT_Pickup", (0, 0, info["top_z"] - 0.06)))
    pts = [o.matrix_world @ Vector(c) for e in meshes[:-1] for o in [e["object"]] for c in o.bound_box]
    lo = [min(p[i] for p in pts) / S for i in range(3)]
    hi = [max(p[i] for p in pts) / S for i in range(3)]
    dims = tuple(round(hi[i] - lo[i], 2) for i in range(3))
    print("[HP2b] %s bbox m %s z %.2f..%.2f tris %s" % (name, dims, lo[2], hi[2],
          [sum(len(p.vertices) - 2 for p in e["object"].data.polygons) for e in meshes]))
    spec = {"name": name, "budget": "large_prop", "tris": 3000 if navmark else 1500, "tier": "standard",
            "dims_m": dims, "origin": "free",
            "sets": [{"name": tex, "set": "Buoy", "size": ship_size(kind), "wet": True}],
            "meshes": meshes, "attachments": atts,
            "closeups": [{"name": "top", "target": [0, 0, (info["top_z"] - 0.4) * S], "dist": 6.0, "az": 35, "el": 20},
                         {"name": "waterline", "target": [0, 0, 0.0], "dist": 6.0, "az": 200, "el": 10}],
            "waivers": {"LOD UV layout": "collapse decimation of the thin cage tubes, rails and chain links drops small UV "
                                         "islands at LOD1/LOD2 (UV bounds unchanged); the kept faces keep the LOD0 UVs and set"}}
    return spec
