"""M_Ani_HerringGull geometry, armature and skinning (Blender; no bpy.ops mesh editing).

Adult herring gull (Larus argentatus) in a neutral glide pose, modelled from the numbers in
art/reference/M_Ani_HerringGull/dims.md: 1.40 m wingspan, 0.59 m bill tip to tail tip. Authored in metres, then
scaled to studs by the caller (1 m = 3 studs). Front is -Y, up is +Z, the bird is centred on its own bbox.

One mesh, built as lofts so the UVs are exact: BODY (tail base -> bill base: the spine runs through the body, the
neck and the head), WING (right, mirrored for the left: a NACA-thickness section around a cambered chord line,
planar taper, the outer five primaries cut as a sawtooth trailing edge), TAIL (flat fan), BILL (a slender cone with
a hooked nail), LEGS (folded back under the tail in the glide pose, webbed feet), EYES. Feather detail is texture +
normal map only, never loose cards.

Skinning is analytic (RIG_HerringGull): body / neck / head along the spine parameter, Wing_1 / Wing_2 by span,
Tail, Leg_1 / Leg_2 along each folded leg; every vertex is weighted, <= 4 influences, weights sum to 1.
"""
import math

import bmesh
import bpy

import gulltex

REG = gulltex.REGIONS
BODY_N, BODY_U = 26, 16                   # points around a body section, sections along the spine
WING_N, WING_U = 22, 11                   # points around a wing section, sections across the span
TAIL_N, TAIL_U = 16, 6
BILL_N, BILL_U = 14, 7
LEG_N, LEG_U = 10, 10
EYE_RINGS, EYE_SIDES = 5, 12


class Builder:
    def __init__(self):
        self.verts = []
        self.faces = []                   # (indices, [uv per loop])
        self.tag = []                     # (part, s) per vertex: part and its along-parameter

    def v(self, co, part, s=0.0):
        self.verts.append((float(co[0]), float(co[1]), float(co[2])))
        self.tag.append((part, float(s)))
        return len(self.verts) - 1

    def face(self, idx, uvs, flip=False):
        if flip:
            idx = list(idx)[::-1]
            uvs = list(uvs)[::-1]
        self.faces.append((tuple(idx), list(uvs)))


def uv_of(region, tu, tv):
    u0, v0, u1, v1 = REG[region]
    return (u0 + tu * (u1 - u0), v0 + tv * (v1 - v0))


def surface(B, stations, region, part, flip=False):
    """stations[i][j] = (co, tv): a (nu x nv) tube, closed around j. Returns the row lists (index, uv)."""
    nu, nv = len(stations), len(stations[0])
    rows = []
    for i, st in enumerate(stations):
        tu = i / float(nu - 1)
        rows.append([(B.v(co, part, tu), uv_of(region, tu, tv)) for co, tv in st])
    for i in range(nu - 1):
        for j in range(nv):
            j2 = (j + 1) % nv
            a, b = rows[i][j], rows[i][j2]
            c, d = rows[i + 1][j2], rows[i + 1][j]
            B.face([a[0], b[0], c[0], d[0]], [a[1], b[1], c[1], d[1]], flip)
    return rows


def cap_fan(B, row, centre_co, region, uv_c, radius=0.03, flip=False):
    """Closes a tube end with a fan; the cap's UVs are a small disc so no face has zero UV area."""
    c = B.v(centre_co, B.tag[row[0][0]][0], B.tag[row[0][0]][1])
    n = len(row)
    cuv = uv_of(region, uv_c[0], uv_c[1])
    ring = []
    for k, (vi, _) in enumerate(row):
        a = 2.0 * math.pi * k / n
        ring.append((vi, uv_of(region, uv_c[0] + radius * math.cos(a), uv_c[1] + radius * math.sin(a))))
    for k in range(n):
        k2 = (k + 1) % n
        B.face([c, ring[k][0], ring[k2][0]], [cuv, ring[k][1], ring[k2][1]], flip)


def resample(table, n):
    """Uniform Catmull-Rom through the control rows (each row is one section) -> n evenly spaced rows."""
    P = [list(r) for r in table]
    P = [P[0]] + P + [P[-1]]
    m = len(P)
    cols = len(P[0])
    out = []
    for i in range(n):
        f = i / float(n - 1) * (m - 3) + 1.0
        k = min(int(f), m - 3)
        u = f - k
        row = []
        for c in range(cols):
            p0, p1, p2, p3 = P[k - 1][c], P[k][c], P[k + 1][c], P[k + 2][c]
            row.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
        out.append(row)
    out[0], out[-1] = list(table[0]), list(table[-1])
    return out


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0) if e1 != e0 else 0.0))
    return t * t * (3.0 - 2.0 * t)


def naca_section(t, th, m=0.035, p=0.40):
    """(half thickness, camber) at chord fraction t: NACA 4-digit thickness (peak near a third of the chord, a blunt
    leading edge, a sharp trailing edge) and a 4 percent camber line; the camber scales with the local thickness, so
    the thin outer wing stays flat."""
    t = min(max(t, 0.0), 1.0)
    yt = (1.4845 * math.sqrt(t) - 0.6300 * t - 1.758 * t * t + 1.4215 * t ** 3 - 0.5075 * t ** 4) / 0.6853
    yc = (m / p ** 2) * (2 * p * t - t * t) if t < p else (m / (1 - p) ** 2) * ((1 - 2 * p) + 2 * p * t - t * t)
    return th * yt, yc * (th * 12.0)


# ---------------------------------------------------------------- section tables (metres)
BODY_SPINE = [                       # u, y, z, rx, rz  (the spine runs tail first)
    (0.000, 0.108, 0.002, 0.014, 0.010),
    (0.070, 0.084, 0.002, 0.034, 0.034),
    (0.160, 0.046, 0.000, 0.048, 0.050),
    (0.260, 0.000, -0.001, 0.056, 0.059),
    (0.360, -0.048, 0.000, 0.057, 0.061),
    (0.460, -0.092, 0.010, 0.053, 0.058),
    (0.545, -0.126, 0.022, 0.044, 0.050),
    (0.630, -0.158, 0.036, 0.032, 0.036),
    (0.715, -0.184, 0.046, 0.025, 0.027),
    (0.800, -0.204, 0.051, 0.028, 0.031),
    (0.880, -0.219, 0.052, 0.028, 0.030),
    (0.950, -0.231, 0.049, 0.021, 0.023),
    (0.985, -0.238, 0.046, 0.015, 0.016),
    (1.000, -0.241, 0.044, 0.010, 0.011),
]
WING_SPAN = [                        # t, x, leading y, trailing y, half thickness, z (right wing)
    (0.00, 0.020, -0.148, 0.104, 0.0180, 0.003),
    (0.08, 0.088, -0.168, 0.098, 0.0148, 0.010),
    (0.20, 0.170, -0.180, 0.070, 0.0116, 0.017),
    (0.32, 0.252, -0.184, 0.046, 0.0094, 0.022),
    (0.44, 0.336, -0.176, 0.027, 0.0078, 0.026),
    (0.56, 0.420, -0.160, 0.011, 0.0066, 0.030),
    (0.67, 0.500, -0.139, -0.001, 0.0055, 0.033),
    (0.78, 0.578, -0.116, -0.012, 0.0044, 0.036),
    (0.88, 0.650, -0.090, -0.024, 0.0034, 0.038),
    (1.00, 0.700, -0.048, -0.038, 0.0018, 0.041),
]
NOTCH_FROM, NOTCH_N, NOTCH_AMP = 0.46, 5, 0.019
TAIL = [                             # t, y, half width, half thickness, z
    (0.00, 0.052, 0.030, 0.013, 0.004),
    (0.16, 0.098, 0.040, 0.0092, 0.002),
    (0.42, 0.164, 0.047, 0.0068, -0.003),
    (0.72, 0.238, 0.053, 0.0050, -0.009),
    (1.00, 0.300, 0.057, 0.0036, -0.014),
]
BILL = [                             # t, y, z, rx, rz (near parallel-sided, then a hooked nail at the tip)
    (0.00, -0.238, 0.0454, 0.0100, 0.0126),
    (0.30, -0.253, 0.0450, 0.0094, 0.0118),
    (0.55, -0.265, 0.0444, 0.0086, 0.0107),
    (0.75, -0.274, 0.0438, 0.0074, 0.0093),
    (0.90, -0.281, 0.0428, 0.0058, 0.0073),
    (0.97, -0.285, 0.0414, 0.0040, 0.0050),
    (1.00, -0.288, 0.0388, 0.0014, 0.0020),
]
LEG_PATH = [                         # x, y, z, radius, flatten (1 round tarsus -> webbed foot), width
    (0.026, 0.040, -0.036, 0.0140, 1.00, 1.00),
    (0.027, 0.066, -0.050, 0.0104, 1.00, 1.00),
    (0.028, 0.092, -0.058, 0.0074, 1.00, 1.00),
    (0.028, 0.118, -0.056, 0.0058, 0.95, 1.00),
    (0.028, 0.140, -0.054, 0.0050, 0.75, 1.05),
    (0.028, 0.164, -0.052, 0.0044, 0.52, 1.15),
    (0.028, 0.184, -0.050, 0.0038, 0.36, 1.30),
    (0.028, 0.200, -0.049, 0.0030, 0.30, 1.35),
    (0.028, 0.214, -0.048, 0.0024, 0.26, 1.25),
]


def body_sections():
    out = []
    for u, y, z, rx, rz in resample(BODY_SPINE, BODY_U):
        st = []
        breadth = 1.0 + 0.10 * smoothstep(0.55, 0.95, u)          # a slightly wider face on the head
        for j in range(BODY_N):
            a = 2.0 * math.pi * j / BODY_N
            up = math.cos(a)
            k = 1.0 + 0.10 * up + 0.04 * (1.0 - up * up)           # full back, flatter belly, full flanks
            st.append(((rx * math.sin(a) * k * breadth, y, z + rz * up * k), j / float(BODY_N)))
        out.append(st)
    return out


def wing_stations(right=True):
    out = []
    for t, x, yle, yte, th, z in resample(WING_SPAN, WING_U):
        if t > NOTCH_FROM:                      # the five outer primaries: a sawtooth trailing edge
            p = (t - NOTCH_FROM) / ((1.0 - NOTCH_FROM) / NOTCH_N)
            saw = p - math.floor(p)
            yte += NOTCH_AMP * (0.22 + 0.78 * saw) * smoothstep(NOTCH_FROM, NOTCH_FROM + 0.05, t)
        sx = x if right else -x
        st = []
        for j in range(WING_N):
            a = 2.0 * math.pi * j / WING_N
            ty = 0.5 * (1.0 - math.cos(a))      # 0 leading edge, 1 trailing edge
            y = yle + (yte - yle) * ty
            yt, yc = naca_section(ty, th)
            zz = z + yc + (-1.0 if a <= math.pi else 1.0) * yt
            st.append(((sx, y, zz), j / float(WING_N)))
        out.append(st)
    return out


def tail_sections():
    out = []
    for t, y, hw, th, z in resample(TAIL, TAIL_U):
        st = []
        for j in range(TAIL_N):
            a = 2.0 * math.pi * j / TAIL_N
            st.append(((hw * math.sin(a) * (1.0 - 0.10 * (1 - math.cos(a))), y, z + th * math.cos(a)),
                       j / float(TAIL_N)))
        out.append(st)
    return out


def bill_sections():
    out = []
    for t, y, z, rx, rz in resample(BILL, BILL_U):
        st = []
        for j in range(BILL_N):
            a = 2.0 * math.pi * j / BILL_N
            k = 1.0 + 0.14 * max(0.0, -math.cos(a))            # the lower mandible a touch deeper
            st.append(((rx * math.sin(a), y, z + rz * math.cos(a) * k), j / float(BILL_N)))
        out.append(st)
    return out


def leg_stations(right=True):
    """Tube along the folded leg, continuing into the flattened webbed foot."""
    out = []
    for i, (x, y, z, r, flat, wide) in enumerate(resample(LEG_PATH, LEG_U)):
        t = i / float(LEG_U - 1)
        sx = x if right else -x
        st = []
        for j in range(LEG_N):
            a = 2.0 * math.pi * j / LEG_N
            st.append(((sx + r * math.sin(a) * wide, y, z + r * math.cos(a) * flat), j / float(LEG_N)))
        out.append(st)
    return out


def sph(B, centre, r, rings, sides, region, part):
    """Small UV sphere: rings of latitude between two fans."""
    rows = []
    for i in range(1, rings):
        lat = math.pi * i / rings
        st = []
        for j in range(sides):
            lon = 2.0 * math.pi * j / sides
            co = (centre[0] + r * math.sin(lat) * math.cos(lon),
                  centre[1] + r * math.sin(lat) * math.sin(lon),
                  centre[2] + r * math.cos(lat))
            st.append((co, j / float(sides)))
        rows.append(st)
    grid = surface(B, rows, region, part)
    cap_fan(B, grid[0], (centre[0], centre[1], centre[2] + r), region, (0.5, 0.93), 0.03)
    cap_fan(B, grid[-1], (centre[0], centre[1], centre[2] - r), region, (0.5, 0.07), 0.03, flip=True)


def build_mesh(name):
    B = Builder()
    rows = surface(B, body_sections(), "BODY", "body")
    cap_fan(B, rows[0], (0.0, 0.100, 0.002), "BODY", (0.5, 0.5), 0.02, flip=True)
    cap_fan(B, rows[-1], (0.0, -0.239, 0.045), "BODY", (0.5, 0.06), 0.02)
    for right in (True, False):
        w = surface(B, wing_stations(right), "WING", "wing%s" % ("R" if right else "L"), flip=not right)
        cap_fan(B, w[0], ((0.010 if right else -0.010), -0.022, 0.003), "WING", (0.03, 0.5), 0.025, flip=not right)
        cap_fan(B, w[-1], ((0.696 if right else -0.696), -0.043, 0.041), "WING", (0.975, 0.5), 0.014, flip=right)
    t = surface(B, tail_sections(), "TAIL", "tail")
    cap_fan(B, t[0], (0.0, 0.040, 0.004), "TAIL", (0.03, 0.5), 0.03, flip=True)
    cap_fan(B, t[-1], (0.0, 0.297, -0.0135), "TAIL", (0.97, 0.5), 0.03)
    bl = surface(B, bill_sections(), "BILL", "head")
    cap_fan(B, bl[0], (0.0, -0.232, 0.0455), "BILL", (0.05, 0.5), 0.03, flip=True)
    cap_fan(B, bl[-1], (0.0, -0.2862, 0.0400), "BILL", (0.965, 0.5), 0.025)
    for right in (True, False):
        tag = "leg%s" % ("R" if right else "L")
        s = surface(B, leg_stations(right), "LEG", tag, flip=not right)
        cap_fan(B, s[0], ((0.026 if right else -0.026), 0.032, -0.032), "LEG", (0.03, 0.5), 0.03, flip=not right)
        cap_fan(B, s[-1], ((0.028 if right else -0.028), 0.213, -0.048), "LEG", (0.97, 0.5), 0.03, flip=right)
    for right in (True, False):
        ex = 0.0268 if right else -0.0268
        sph(B, (ex, -0.2155, 0.0552), 0.0082, EYE_RINGS, EYE_SIDES, "EYE", "head")
    me = bpy.data.meshes.new(name)
    me.from_pydata(list(B.verts), [], [f[0] for f in B.faces])
    me.validate(verbose=False)
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for poly, (_, uvs) in zip(me.polygons, B.faces):
        for k, li in enumerate(poly.loop_indices):
            uvl.data[li].uv = uvs[k]
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()
    return ob, B


# ---------------------------------------------------------------- armature
BONES = {                                  # name: (head, tail, parent)
    "Root": ((0.0, 0.06, 0.0), (0.0, -0.02, 0.0), None),
    "Body": ((0.0, 0.10, 0.002), (0.0, -0.115, 0.012), "Root"),
    "Neck": ((0.0, -0.115, 0.012), (0.0, -0.180, 0.046), "Body"),
    "Head": ((0.0, -0.180, 0.046), (0.0, -0.245, 0.047), "Neck"),
    "Tail": ((0.0, 0.070, 0.002), (0.0, 0.240, -0.008), "Body"),
    "Wing_L_1": ((0.045, -0.030, 0.006), (0.300, -0.060, 0.022), "Body"),
    "Wing_L_2": ((0.300, -0.060, 0.022), (0.680, -0.055, 0.039), "Wing_L_1"),
    "Wing_R_1": ((-0.045, -0.030, 0.006), (-0.300, -0.060, 0.022), "Body"),
    "Wing_R_2": ((-0.300, -0.060, 0.022), (-0.680, -0.055, 0.039), "Wing_R_1"),
    "Leg_L_1": ((0.028, 0.042, -0.036), (0.028, 0.096, -0.058), "Body"),
    "Leg_L_2": ((0.028, 0.096, -0.058), (0.028, 0.210, -0.048), "Leg_L_1"),
    "Leg_R_1": ((-0.028, 0.042, -0.036), (-0.028, 0.096, -0.058), "Body"),
    "Leg_R_2": ((-0.028, 0.096, -0.058), (-0.028, 0.210, -0.048), "Leg_R_1"),
}


def build_rig(scale, off=(0.0, 0.0, 0.0)):
    arm = bpy.data.armatures.new("RIG_HerringGull")
    rig = bpy.data.objects.new("RIG_HerringGull", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for bname, (head, tail, parent) in BONES.items():
        eb = arm.edit_bones.new(bname)
        eb.head = [(c + o) * scale for c, o in zip(head, off)]
        eb.tail = [(c + o) * scale for c, o in zip(tail, off)]
        eb.roll = 0.0
    for bname, (_, _, parent) in BONES.items():
        if parent:
            arm.edit_bones[bname].parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.display_type = 'OCTAHEDRAL'
    return rig


def weights_for(tag, co):
    """{bone: weight} for one vertex, from its part tag and position (metres). Always sums to 1."""
    part, s = tag
    x, y, z = co[0], co[1], co[2]
    if part == "body":
        u = s
        if u < 0.55:
            return {"Body": 1.0}
        if u < 0.66:
            k = smoothstep(0.55, 0.66, u)
            return {"Body": 1.0 - k, "Neck": k}
        if u < 0.78:
            return {"Neck": 1.0}
        if u < 0.86:
            k = smoothstep(0.78, 0.86, u)
            return {"Neck": 1.0 - k, "Head": k}
        return {"Head": 1.0}
    if part in ("wingL", "wingR"):
        side = "L" if part == "wingL" else "R"
        ax = abs(x)
        wb = 1.0 - smoothstep(0.050, 0.110, ax)
        rest = 1.0 - wb
        k = smoothstep(0.22, 0.36, ax)
        return {"Body": wb, "Wing_%s_1" % side: rest * (1.0 - k), "Wing_%s_2" % side: rest * k}
    if part == "tail":
        k = smoothstep(0.070, 0.145, y)
        return {"Body": 1.0 - k, "Tail": k}
    if part in ("legL", "legR"):
        side = "L" if part == "legL" else "R"
        kb = 1.0 - smoothstep(0.040, 0.080, y)
        rest = 1.0 - kb
        k2 = smoothstep(0.090, 0.130, y)
        return {"Body": kb, "Leg_%s_1" % side: rest * (1.0 - k2), "Leg_%s_2" % side: rest * k2}
    return {"Head": 1.0}                       # the bill and the eyes ride the head


def skin(ob, B, rig):
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    groups = {bname: ob.vertex_groups.new(name=bname) for bname in BONES}
    for i, (tag, co) in enumerate(zip(B.tag, B.verts)):
        w = {k: v for k, v in weights_for(tag, co).items() if v > 1e-4}
        tot = sum(w.values())
        for bname, weight in w.items():
            groups[bname].add([i], weight / tot, 'REPLACE')
    mod = ob.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    return rig
