"""The three pirates (concept "Pirate Crew Concept"): static posed meshes, feet at the origin, facing -Y, no baseplate.

Local axes: x the figure's left, y back, z up. Poses are the concept's idle rotations (three.js X, Y, Z degrees).
"""
import math

import kit

P = kit.P
RB = kit.RB
SCALE = 1.25      # art director round 2: 1.4x, they must read against the hull on a phone

DEF = {
    "captain": dict(leg=1.55, hip=0.36, torso=1.6, top=1.6, bot=2.3, depth=1.05, r=0.82, head=1.36, arm=1.0,
                    skin=P.CSKIN, nose=P.CNOSE, sleeve=[P.COAT], cuff=P.CUFF, pants=P.BREECH, side=P.COAT,
                    armR=(-38, 0, -12), armL=(-8, 0, 4), head_pose=(3, -8, 0)),
    "crewA": dict(leg=0.95, hip=0.32, torso=1.42, top=1.85, bot=2.45, depth=1.15, r=0.92, head=1.28, arm=1.1,
                  skin=P.ASKIN, nose=P.ANOSE, sleeve=[P.ASHIRT, P.ASTRIPE, P.ASHIRT, P.ASTRIPE, P.ASHIRT], cuff=P.ASHIRT, pants=P.APANTS,
                  side=None, armR=(-55, 0, -10), armL=(-8, 0, 4), head_pose=(0, -8, 0)),
    "crewB": dict(leg=1.95, hip=0.32, torso=1.75, top=1.25, bot=1.55, depth=0.85, r=0.7, head=1.42, arm=1.12,
                  skin=P.BSKIN, nose=P.BNOSE, sleeve=[P.BSHIRT], cuff=P.BSHIRT, pants=P.BPANTS, side=P.VEST,
                  armR=(-17, 0, 0), armL=(-6, 0, 0), head_pose=(0, 12, 0)),
}


def pose_matrix(rx, ry, rz):
    """Concept rotation (three.js, X then Y then Z intrinsic: Rx Ry Rz) in this file's axes."""
    import mathutils
    C = mathutils.Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    R = (mathutils.Matrix.Rotation(math.radians(rx), 4, "X") @ mathutils.Matrix.Rotation(math.radians(ry), 4, "Y")
         @ mathutils.Matrix.Rotation(math.radians(rz), 4, "Z"))
    return C @ R @ C.inverted()


def trans(*v):
    import mathutils
    return mathutils.Matrix.Translation(v)


def torso(b, who, d, z0, z1):
    hb, ht, hd, ch = d["bot"] / 2, d["top"] / 2, d["depth"] / 2, 0.14
    def ring(hw, z):
        return [(-hw + ch, -hd, z), (hw - ch, -hd, z), (hw, -hd + ch, z), (hw, hd - ch, z), (hw - ch, hd, z), (-hw + ch, hd, z),
                (-hw, hd - ch, z), (-hw, -hd + ch, z)]
    verts = ring(hb, z0) + ring(ht, z1)
    faces = [(i, (i + 1) % 8, 8 + (i + 1) % 8, 8 + i) for i in range(8)]
    faces += [tuple(reversed(range(8))), tuple(range(8, 16))]
    base_col = d["side"] if d["side"] is not None else P.ASHIRT
    start = len(b.f)
    b._emit(verts, faces, base_col)
    F, B = P.TORSO[who]
    b.tile(start, F)                       # front quad: 0 1 9 8 runs BL, BR, TR, TL seen from -y
    b.uv_quad(start + 4, tuple((u, v) for u, v in _rect(B, flip=True)))   # back quad seen from +y
    if who == "crewA":                     # stripes wrap round
        for i in (2, 6):
            b.tile(start + i, F)


def _rect(rect, flip=False):
    u0, v0, u1, v1 = P.uv_rect(rect)
    if flip:
        return (u1, v0), (u0, v0), (u0, v1), (u1, v1)
    return (u0, v0), (u1, v0), (u1, v1), (u0, v1)


def head(b, who, d):
    """Cylinder head: rim rings, the front 7 of 12 band faces carry the printed face."""
    r, h = d["r"], d["head"]
    n = 12
    zs = [(r * 0.84, 0.0), (r, 0.12), (r, h - 0.16), (r * 0.8, h)]
    verts = []
    for q, z in zs:
        for i in range(n):
            a = math.radians(-195 + i * 30)
            verts.append((q * math.cos(a), q * math.sin(a), z))
    faces, start = [], len(b.f)
    for s in range(3):
        for i in range(n):
            faces.append((s * n + i, s * n + (i + 1) % n, (s + 1) * n + (i + 1) % n, (s + 1) * n + i))
    faces += [tuple(reversed(range(n))), tuple(range(3 * n, 4 * n))]
    b._emit(verts, faces, d["skin"])
    u0, v0, u1, v1 = P.uv_rect(P.FACE[who])
    for i in range(7):
        ua, uc = u0 + (u1 - u0) * i / 7, u0 + (u1 - u0) * (i + 1) / 7
        b.uv_quad(start + n + i, ((ua, v0), (uc, v0), (uc, v1), (ua, v1)))
    b.box((-0.13, -r - 0.14, h * 0.4), (0.13, -r + 0.2, h * 0.58), d["nose"], bevel=0.05)
    b.lathe(0, 0, [(r * 0.5, h - 0.02), (r * 0.5, h + 0.16), (0, h + 0.2)], d["skin"], n=8)    # head stud


def arm(b, d, side, rot, z_sh):
    """side +1 is the figure's left. Returns the matrix at the hand clip."""
    x = side * (d["top"] / 2 + 0.12)
    M = trans(x, 0, z_sh) @ pose_matrix(*rot)
    L = d["arm"]
    cols = d["sleeve"]
    k = len(cols)
    with b.at(M):
        prof = [(0.0, 0.32), (0.25, 0.26), (0.33, 0.06)]
        cs = [cols[0], cols[0]]
        for i in range(k):
            prof.append((0.33 - 0.06 * (i + 1) / k, 0.06 - (L - 0.06) * (i + 1) / k))
            cs.append(cols[i])
        prof += [(0.3, -L), (0.26, -L - 0.04), (0, -L - 0.04)]
        cs += [d["cuff"]] * 3
        b.lathe(0, 0, prof, cs, n=8)
        hand = trans(0, 0, -L - 0.18)
    with b.at(M @ hand):                   # C-clip hand: a short ring across the arm
        with b.at(kit.along((1, 0, 0))):
            b.lathe(0, 0, [(0.2, -0.17), (0.2, 0.17)], d["skin"], n=8)
    return M @ hand


def legs(b, d):
    half = d["bot"] / 2
    w = half * 0.95
    for s in (1, -1):
        x0, x1 = sorted((s * 0.05, s * w))
        hd = d["depth"] / 2 * 0.95
        b.box((x0 - 0.02, -hd - 0.12, 0), (x1 + 0.02, hd, 0.1), P.SOLE, bevel=0.02)
        b.box((x0, -hd - 0.1, 0.08), (x1, hd - 0.02, 0.55), P.BOOT, bevel=0.1)
        b.box((x0 + 0.02, -hd + 0.02, 0.5), (x1 - 0.02, hd - 0.04, d["leg"]), d["pants"], bevel=0.05)
    b.box((-half, -d["depth"] / 2, d["leg"]), (half, d["depth"] / 2, d["leg"] + d["hip"]), d["pants"], bevel=0.07)


def tricorn(b, z0):
    n = 12
    def corner(deg):
        return 0.5 + 0.5 * math.cos(math.radians(3 * (deg + 90)))
    rings = {"in": [], "out": [], "lip": [], "under": []}
    verts = []
    for i in range(n):
        deg = -90 + i * 30
        a = math.radians(deg)
        c = corner(deg)
        R = 1.85 + 0.95 * c ** 1.3                  # huge: the captain's read at phone size
        rise = 0.75 * (1 - c)
        for r, z in ((0.7, z0 + 0.08), (R, z0 + 0.04 + rise), (R + 0.03, z0 - 0.1 + rise), (0.7, z0 - 0.04)):
            verts.append((r * math.cos(a), r * math.sin(a), z))
    faces, cols = [], []
    for i in range(n):
        A, B = i * 4, ((i + 1) % n) * 4
        for j, c in ((0, P.FELT), (1, P.CUFF), (2, P.FELT), (3, P.FELT)):
            m = (j + 1) % 4
            faces.append((A + j, B + j, B + m, A + m))
            cols.append(c)
    b._emit(verts, faces, cols)
    b.lathe(0, 0, [(0.95, z0), (0.92, z0 + 0.8), (0.72, z0 + 1.12), (0, z0 + 1.16)], P.FELT, n=12)
    b.lathe(0, 0, [(0.3, z0 + 1.14), (0.3, z0 + 1.28), (0, z0 + 1.32)], P.FELT, n=8)
    # skull badge at the front point, printed tile on a small plate
    x, y0, y1, zb, zt = 0.52, -1.0, -0.86, z0 + 0.06, z0 + 1.04
    verts = [(-x, y0, zb), (x, y0, zb), (x, y0, zt), (-x, y0, zt), (-x, y1, zb), (x, y1, zb), (x, y1, zt), (-x, y1, zt)]
    start = len(b.f)
    b._emit(verts, [(0, 1, 2, 3), (5, 4, 7, 6), (1, 5, 6, 2), (4, 0, 3, 7), (3, 2, 6, 7), (4, 5, 1, 0)], P.FELT)
    b.tile(start, P.BADGE)


def bicorne(b, z0):
    W = 1.55
    def secs(zb_off, zt_of, t_extra):
        out = []
        for i in range(11):
            x = -W + 2 * W * i / 10
            k = max(0.0, 1 - (x / W) ** 2)
            zb, zt = z0 + zb_off, z0 + zt_of(k)
            t = 0.5 * k ** 0.5 + 0.05 + t_extra
            out.append([(x, -t, zb), (x, t, zb), (x, t * 0.55, zt), (x, -t * 0.55, zt)])
        return out
    b.loft(secs(0.0, lambda k: 0.14 + 0.98 * k ** 0.6, 0.0), P.FELT)
    b.loft(secs(-0.06, lambda k: 0.12, 0.03), P.CUFF)


def bandana(b, d):
    r, h = d["r"], d["head"]
    z0 = h - 0.42
    b.lathe(0, 0, [(r + 0.05, z0), (r + 0.05, z0 + 0.14), (r * 1.0 + 0.04, h - 0.02), (r * 0.72, h + 0.24), (r * 0.3, h + 0.4), (0, h + 0.42)],
            [P.BFOLD, P.BANDANA, P.BANDANA, P.BANDANA, P.BANDANA], n=12)
    b.lathe(0, 0, [(0.3, h + 0.38), (0.3, h + 0.52), (0, h + 0.56)], P.BANDANA, n=8)
    y = r + 0.02
    b.box((-0.2, y, z0 + 0.05), (0.2, y + 0.26, z0 + 0.45), P.BFOLD, bevel=0.05)
    for s in (1, -1):
        b.beam((s * 0.1, y + 0.18, z0 + 0.15), (s * 0.45, y + 0.3, z0 - 0.45), 0.2, 0.08, P.BANDANA)
    # eye patch strap, seen from the back
    with b.at(pose_matrix(0, 0, -12)):
        b.lathe(0, 0, [(r + 0.0, h * 0.56), (r + 0.045, h * 0.56), (r + 0.045, h * 0.64), (r + 0.0, h * 0.64)], P.BOOT, n=12, start=math.radians(-195))


def captain_props(b):
    """The wheel beside him (his right, turned 30 degrees) with the macaw on the top handle; never in front of his coat."""
    import mathutils
    c = (-1.95, -0.55, 2.75)
    b.box((c[0] - 0.3, c[1] + 0.05, 0), (c[0] + 0.3, c[1] + 0.65, c[2] + 0.06), P.POST, bevel=0.06)
    R = trans(*c) @ mathutils.Matrix.Rotation(math.radians(-30), 4, "Z")
    with b.at(R):
        with b.at(kit.along((0, -1, 0))):
            b.lathe(0, 0, [(0.2, -0.2), (0.2, 0.24), (0, 0.3)], P.TRIM, n=8)
        Rw, tube = 1.08, 0.13
        verts, faces = [], []
        for i in range(12):
            a = 2 * math.pi * i / 12
            for j in range(4):
                v = 2 * math.pi * (j + 0.5) / 4
                rr = Rw + tube * math.cos(v)
                verts.append((rr * math.cos(a), tube * math.sin(v) - 0.05, rr * math.sin(a)))
        for i in range(12):
            k = (i + 1) % 12
            for j in range(4):
                m = (j + 1) % 4
                faces.append((i * 4 + j, k * 4 + j, k * 4 + m, i * 4 + m))
        b._emit(verts, faces, P.WHEEL)
        for i in range(6):
            a = 2 * math.pi * i / 6 + math.pi / 2
            ca, sa = math.cos(a), math.sin(a)
            b.beam((0.1 * ca, -0.05, 0.1 * sa), (1.02 * ca, -0.05, 1.02 * sa), 0.15, 0.1, P.WHEEL)
            b.rod((1.08 * ca, -0.05, 1.08 * sa), (1.42 * ca, -0.05, 1.42 * sa), 0.16, P.POST, n=6)
    # macaw on the top handle: pure red and yellow, double size so it reads on a phone
    import mathutils as mu
    x, y, z = c[0], c[1], c[2] + 1.45
    R_, Y_ = P.cell(P.MACAW_R, "abs"), P.cell(P.MACAW_Y, "abs")
    with b.at(trans(x, y, z) @ mu.Matrix.Scale(2.0, 4)):
        b.lathe(0, 0, [(0, 0), (0.28, 0.14), (0.34, 0.45), (0.25, 0.8), (0, 0.92)], [R_, Y_, R_, R_], n=8)
        b.lathe(0, -0.03, [(0, 0.78), (0.24, 0.9), (0.25, 1.1), (0, 1.26)], R_, n=8)
        b.lathe(0, -0.25, [(0.13, 1.0), (0.11, 1.08), (0, 1.12)], Y_, n=6)
        for s in (1, -1):
            b.box((s * 0.3 - 0.07, -0.16, 0.2), (s * 0.3 + 0.07, 0.2, 0.74), Y_, bevel=0.03)
            b.box((s * 0.3 - 0.06, -0.08, 0.02), (s * 0.3 + 0.06, 0.2, 0.22), R_, bevel=0.02)
            with b.at(kit.along((s * 0.5, -1, 0), (s * 0.12, -0.25, 1.06))):
                b.lathe(0, 0, [(0.06, 0), (0.06, 0.04), (0, 0.05)], P.BLACK, n=6)
        b.box((-0.1, 0.12, -0.5), (0.1, 0.24, 0.1), R_, bevel=0.03)
        b.box((-0.1, 0.12, -0.74), (0.1, 0.24, -0.5), Y_, bevel=0.03)


def oar(b, hand):
    p = hand.translation
    x, y = p[0], p[1]
    top = p[2] + 2.2
    b.rod((x, y, 1.0), (x, y, top), 0.17, P.OAR, n=6)
    b.lathe(x, y, [(0, top - 0.02), (0.12, top), (0.12, top + 0.14), (0, top + 0.18)], P.SASH, n=6)
    b.beam((x, y, 0.05), (x, y, 1.15), 0.56, 0.1, P.OAR)
    b.beam((x, y, 0.28), (x, y, 0.5), 0.6, 0.13, P.SASH)                # the tip band


def spyglass(b, hand):
    import mathutils
    p = hand.translation
    Dir = mathutils.Vector((-0.1, -0.75, 0.65)).normalized()
    with b.at(kit.along(Dir, (p[0], p[1], p[2]))):
        b.lathe(0, 0, [(0.13, -0.5), (0.13, 0.3), (0.17, 0.32), (0.17, 1.1), (0.21, 1.12), (0.21, 1.9), (0.25, 1.92), (0.25, 2.08), (0, 2.1)],
                [P.TRIM, P.TRIM, P.TRIM, P.LEATHER, P.TRIM, P.TRIM, P.TRIM, P.LENS], n=8)


def figure(who, b):
    d = DEF[who]
    legs(b, d)
    waist = d["leg"] + d["hip"]
    top = waist + d["torso"]
    torso(b, who, d, waist, top)
    hb, hd = d["bot"] / 2, d["depth"] / 2
    if who == "captain":
        b.box((-hb - 0.03, -hd - 0.04, waist - 0.08), (hb + 0.03, hd + 0.04, waist + 0.18), P.BOOT, bevel=0.03)
        b.box((-0.22, -hd - 0.1, waist - 0.1), (0.22, -hd + 0.02, waist + 0.2), P.TRIM, bevel=0.03)
        for s in (1, -1):                    # coat tails, the frock coat's shape from the side and back
            x0, x1 = sorted((s * hb, s * (hb - 0.5)))
            b.box((x0 - s * 0.04, -hd * 0.4, d["leg"] * 0.5), (x1, hd + 0.06, waist - 0.05), P.COAT, bevel=0.03)
        b.box((-hb, hd * 0.25, d["leg"] * 0.5), (hb, hd + 0.08, waist - 0.05), P.COAT, bevel=0.03)
    else:
        b.box((-hb * 0.97 - 0.03, -hd - 0.03, waist - 0.02), (hb * 0.97 + 0.03, hd + 0.03, waist + 0.26), P.SASH, bevel=0.03)
        b.box((hb - 0.5, -hd - 0.08, waist - 0.46), (hb - 0.2, -hd + 0.02, waist + 0.14), P.SASH, bevel=0.02)
    z_sh = top - 0.22
    hands = {}
    hands["R"] = arm(b, d, -1, d["armR"], z_sh)
    hands["L"] = arm(b, d, 1, d["armL"], z_sh)
    b.lathe(0, 0, [(0.3, top - 0.02), (0.3, top + 0.1)], d["skin"], n=8)
    with b.at(trans(0, 0, top + 0.08) @ pose_matrix(*d["head_pose"])):
        head(b, who, d)
        h = d["head"]
        if who == "captain":
            tricorn(b, h - 0.14)
        elif who == "crewA":
            bandana(b, d)
            b.lathe(-d["r"] - 0.05, 0, [(0.13, h * 0.42), (0.13, h * 0.48)], P.TRIM, n=6)      # earring side
        else:
            bicorne(b, h - 0.16)
            with b.at(kit.along((1, 0, 0), (d["r"] + 0.02, 0, h * 0.32))):
                pass
            with b.at(kit.along((0, 1, 0), (d["r"] + 0.05, 0, h * 0.3))):       # gold hoop
                b.lathe(0, 0, [(0.16, -0.03), (0.16, 0.03), (0.1, 0.03), (0.1, -0.03)], P.TRIM, n=8)
    if who == "captain":
        captain_props(b)
    elif who == "crewA":
        oar(b, hands["R"])
    else:
        spyglass(b, hands["R"])


def build_asset(name, who):
    import mathutils
    mat = kit.lego.material("MI_PirateBoat_Brick", kit.ALB)
    b = RB(mathutils.Matrix.Scale(SCALE, 4))
    figure(who, b)
    obj = b.to_object(name + "_LOD0", mat)
    print("[crew] %s %d tris" % (name, b.tris()))
    meshes = [{"object": obj, "set": kit.SET}]
    return {
        "name": name, "budget": "small_prop", "tier": "standard", "dims_m": kit.dims_of(meshes), "origin": "free", "tiling": True, "clothing_merged": True,
        "size_note": "toy-brick figure from the crew concept, posed static, scaled to the boat",
        "sets": [{"name": kit.SET_NAME, "set": kit.SET, "size": 1024, "wet": False, "dir": kit.TEX_DIR}],
        "waivers": {
            "UV faces": "at the LOD the collapse decimator merges palette-cell UVs of the smallest faces; each stays one flat colour",
            "LOD UV layout": "flat palette cells and printed tiles from the shared atlas, not a unique unwrap",
            "budget": "a posed figure with a prop: small_prop triangle row, one shared atlas of the boat",
        },
        "meshes": meshes,
    }
