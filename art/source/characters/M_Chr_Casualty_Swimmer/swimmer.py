"""M_Chr_Casualty_Swimmer v3 under the character moderation rule (docs/06 2.1a): ONE merged mesh per LOD.

v2 (a 4.5 mm shrinkwrapped wetsuit) failed the moderation review: in clay it read as a bare body. v3 is built the other
way round: the clothing is modelled as loose real-world gear, NOT derived from the body surface, and the only body
geometry kept from the MakeHuman male base (local only, ../M_Chr_HumanBase_M/humanlib.py) is the skin of the face and
the neck (the hands are covered by neoprene rescue gloves with thick cuffs over the wrist seals).
  * baggy foul-weather drysuit: lofted from the skeleton as a boxy torso column (constant width and depth from the crotch
    gusset to the chest: no waist, hip or buttock curve), straight-legged trousers and sleeves 3-6 cm off the body, a
    low crotch gusset, unioned with a voxel remesh into ONE closed hollow shell (caps at the collar, cuffs and hems; no
    body shape inside), then real folds (elbows, knees, hem and cuff bunching, crotch, waist sides) displaced along
    the normals; raised seam piping (outer legs and sleeves), wrist cuffs and trouser hems with thickness, retro tape;
  * chunky sea boots (shaft, round toe box, thick sole and heel) under the trouser hems: no toes or ankle shape;
  * an inflated offshore lifejacket covering the front and the back from the collar to the hips (vertical chambers,
    yoke over the shoulders, pillow collar behind the head), chest and waist belts with buckles, a wide crotch-strap
    webbing panel, strobe (ATT_Strobe) and whistle (ATT_Whistle);
  * the wet hair is a solid shell grown from the scalp faces (one material, one mesh).
Skinning: weights transferred from the base rig (nearest base-body vertices of the same limb class) onto every clothing
vertex; R15-named RIG_Human (humanlib.build_rig). One 2048 atlas (Atlas set; dry + _Wet).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "M_Chr_HumanBase_M"))
import humanlib as H  # noqa: E402

import bpy  # noqa: E402
import bmesh  # noqa: E402
import mathutils  # noqa: E402
from mathutils.kdtree import KDTree  # noqa: E402

ASSET, TNAME, SETN, SIZE = "M_Chr_Casualty_Swimmer", "CasualtySwimmer", "Atlas", 2048
CFG = {"name": ASSET, "gender": "male", "height_m": 1.75, "skin": "#C49A82", "skin_rough": 0.42, "hair": "#2F2924",
       "iris": "#5A4A3A", "stubble": True, "garments": lambda h: []}
HEAD, HAND, SUIT, HAIR, LJ = 0, 1, 2, 3, 4
TILES = {HEAD: (0.0, 0.5, 0.5, 0.5), SUIT: (0.5, 0.0, 0.5, 1.0), LJ: (0.0, 0.25, 0.5, 0.25),
         HAND: (0.0, 0.0, 0.25, 0.25), HAIR: (0.25, 0.0, 0.25, 0.25)}
BONES = H.SKIN_BONES
BI = {b: i for i, b in enumerate(BONES)}


def ss(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def kd_of(points):
    kd = KDTree(len(points))
    for i, p in enumerate(points):
        kd.insert(tuple(p), i)
    kd.balance()
    return kd


def kd_dist(kd, Q):
    return np.array([kd.find(tuple(q))[2] for q in Q])


# ---------------------------------------------------------------- regions
def collar_z(hum, P):
    N, Hd = hum.J["neck"], hum.J["head"]
    return N[2] + 0.42 * (Hd[2] - N[2]) + 0.3 * (P[:, 1] - N[1])          # lower at the front (-Y)


def skin_mask(hum, P, W):
    """(skin, head, hands) per vertex: head/neck above the collar, hands beyond the wrist cuffs."""
    m = hum.m
    arms = W[:, [BI[b] for b in BONES if "Arm" in b or "Hand" in b]].sum(1)
    head = (P[:, 2] > collar_z(hum, P)) & (arms < 0.3)
    hands = np.zeros(len(P), bool)
    for s, sg in (("l", "Left"), ("r", "Right")):
        Hj, E = hum.J[s + "-hand"], hum.J[s + "-elbow"]
        d = (Hj - E) / np.linalg.norm(Hj - E)
        side = W[:, BI[sg + "LowerArm"]] + W[:, BI[sg + "Hand"]] > 0.5
        hands |= side & ((P - Hj) @ d > -m(0.03))
    return head | hands, head, hands


def wrist_plane(hum, s):
    Hj, E = hum.J[s + "-hand"], hum.J[s + "-elbow"]
    return Hj, (Hj - E) / np.linalg.norm(Hj - E)

# ---------------------------------------------------------------- mesh helpers
def get_arrays(obj):
    me = obj.data
    n = len(me.vertices)
    P = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("co", P)
    P = P.reshape(n, 3).astype(np.float64)
    polys = [tuple(p.vertices) for p in me.polygons]
    uv = np.empty(len(me.loops) * 2, np.float32)
    me.uv_layers["UVMap"].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2).astype(np.float64)
    starts = [p.loop_start for p in me.polygons]
    W = np.zeros((n, len(BONES)))
    gi = {obj.vertex_groups[b].index: j for j, b in enumerate(BONES) if b in obj.vertex_groups}
    for v in me.vertices:
        for g in v.groups:
            j = gi.get(g.group)
            if j is not None:
                W[v.index, j] = g.weight
    eye = np.zeros(n, np.float32)
    if "EyeMask" in me.attributes:
        me.attributes["EyeMask"].data.foreach_get("value", eye)
    return P, polys, starts, uv, W, eye


def vnormals(P, polys, use):
    N = np.zeros_like(P)
    for f, u in zip(polys, use):
        if not u:
            continue
        p0 = P[f[0]]
        fn = np.zeros(3)
        for k in range(1, len(f) - 1):
            fn += np.cross(P[f[k]] - p0, P[f[k + 1]] - p0)
        for v in f:
            N[v] += fn
    L = np.linalg.norm(N, axis=1, keepdims=True)
    return N / np.maximum(L, 1e-12)


def make_obj(name, P, faces, uvs, W, pattrs, freg):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in P], [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    uvl.data.foreach_set("uv", np.asarray(uvs, np.float32).ravel())
    me.update()
    obj = H.link(bpy.data.objects.new(name, me))
    for j, b in enumerate(BONES):
        vg = obj.vertex_groups.new(name=b)
        for i in np.nonzero(W[:, j] > 0)[0]:
            vg.add([int(i)], float(W[i, j]), 'REPLACE')
    for k, vals in pattrs.items():
        H.point_attr(obj, k, vals)
    a = me.attributes.new("Region", 'FLOAT', 'FACE')
    a.data.foreach_set("value", np.asarray(freg, np.float32))
    for p in me.polygons:
        p.use_smooth = True
    return obj


def thickness(hum, Q, N, W, db, zip_top):
    m, J = hum.m, hum.J
    t = np.full(len(Q), m(0.0045))
    t += m(0.0018) * (1 - ss(m(0.012), m(0.017), db))               # seal cuffs at collar / wrists
    for s, sg in (("l", "Left"), ("r", "Right")):
        leg = W[:, BI[sg + "UpperLeg"]] + W[:, BI[sg + "LowerLeg"]] > 0.5
        r = np.linalg.norm((Q - (J[s + "-knee"] + [0, -m(0.045), 0])) / [m(0.065), m(0.05), m(0.085)], axis=1)
        t += m(0.005) * (1 - ss(0.8, 1.0, r)) * ss(0.1, 0.35, -N[:, 1]) * leg
        arm = W[:, BI[sg + "UpperArm"]] + W[:, BI[sg + "LowerArm"]] > 0.5
        r = np.linalg.norm((Q - (J[s + "-elbow"] + [0, m(0.025), 0])) / [m(0.045), m(0.04), m(0.06)], axis=1)
        t += m(0.0035) * (1 - ss(0.8, 1.0, r)) * ss(0.0, 0.3, N[:, 1]) * arm
    zipm = (1 - ss(m(0.008), m(0.012), np.abs(Q[:, 0]))) * ss(0.2, 0.5, N[:, 1]) * (Q[:, 2] < zip_top) * (Q[:, 2] > zip_top - m(0.62))
    ank = J["l-ankle"][2]
    t += m(0.0025) * ss(ank + m(0.075), ank + m(0.068), Q[:, 2])                       # boot uppers (step at the cuff)
    t += m(0.007) * ss(-0.35, -0.7, N[:, 2]) * (Q[:, 2] < m(0.05))                     # boot soles
    t += m(0.004) * ss(m(0.08), m(0.06), Q[:, 2]) * ss(J["l-ankle"][1] - m(0.04), J["l-ankle"][1] - m(0.1), Q[:, 1])   # round toe cap
    return t + m(0.0025) * zipm


def process(src, name, hum):
    """Skin (head/neck/hands) + hair shell + suit shell + rim from a body object. The body under the suit is not kept."""
    m = hum.m
    P, polys, starts, uv, W, eye = get_arrays(src)
    skin, headm, handm = skin_mask(hum, P, W)
    fv = [list(f) for f in polys]
    fskin = np.array([skin[f].mean() > 0.5 for f in fv])
    fhand = fskin & np.array([handm[f].mean() > 0.5 for f in fv])
    feye = np.array([eye[f].mean() > 0.5 for f in fv])
    scalp = H.scalp_mask(hum, P, "wet")
    fhair = fskin & ~fhand & ~feye & np.array([scalp[f].mean() > 0.5 for f in fv])
    fsuit = ~fskin
    skin_v = sorted({v for f, s in zip(fv, fskin) if s for v in f})
    suit_v = sorted({v for f, s in zip(fv, fsuit) if s for v in f})
    bnd = np.array(sorted(set(skin_v) & set(suit_v)))
    # snap the opening edges onto clean cut planes (collar plane, wrist planes)
    for v in bnd:
        if P[v, 2] > hum.J["neck"][2] - m(0.08):
            dz = collar_z(hum, P[v:v + 1])[0] - P[v, 2]
            P[v, 2] += np.clip(dz, -m(0.025), m(0.025))
        else:
            s = "l" if P[v, 0] > 0 else "r"
            Hj, d = wrist_plane(hum, s)
            P[v] += d * np.clip(-m(0.03) - (P[v] - Hj) @ d, -m(0.025), m(0.025))
    # wet hair shell: scalp faces grown out, zero at the hairline (stays welded to the skin)
    hair_v = sorted({v for f, s in zip(fv, fhair) if s for v in f})
    rest_v = sorted({v for f, s, h in zip(fv, fskin, fhair) if s and not h for v in f})
    line = sorted(set(hair_v) & set(rest_v))
    if hair_v and line:
        vn = vnormals(P, polys, fskin)
        d = kd_dist(kd_of(P[line]), P[hair_v])
        cl = hair_clump(hum, P[hair_v])
        P[hair_v] += vn[hair_v] * (m(0.0065) * ss(0.0, m(0.03), d) * (0.8 + 0.4 * cl))[:, None]
    # suit shell
    vs = vnormals(P, polys, fsuit)
    db = kd_dist(kd_of(P[bnd]), P[suit_v])
    back = bnd[(np.abs(P[bnd, 0]) < m(0.03)) & (P[bnd, 1] > hum.J["neck"][1]) & (P[bnd, 2] > hum.J["neck"][2] - m(0.1))]
    zip_top = P[back, 2].mean() - m(0.012) if len(back) else hum.J["neck"][2]
    t = thickness(hum, P[suit_v], vs[suit_v], W[suit_v], db, zip_top)
    i_skin = {v: i for i, v in enumerate(skin_v)}
    i_suit = {v: len(skin_v) + i for i, v in enumerate(suit_v)}
    NP = np.concatenate([P[skin_v], P[suit_v] + vs[suit_v] * t[:, None]])
    NW = np.concatenate([W[skin_v], W[suit_v]])
    neye = np.concatenate([eye[skin_v], np.zeros(len(suit_v))])
    nbd = np.concatenate([np.zeros(len(skin_v)), db])
    tsuit = dict(zip(suit_v, t))
    faces, uvs, freg = [], [], []
    skin_edges = set()
    for f, s in zip(fv, fskin):
        if s:
            for k in range(len(f)):
                a, b = f[k], f[(k + 1) % len(f)]
                skin_edges.add((min(a, b), max(a, b)))
    rim = 0
    for i, f in enumerate(fv):
        luv = uv[starts[i]:starts[i] + len(f)]
        if fskin[i]:
            faces.append([i_skin[v] for v in f])
            freg.append(HAND if fhand[i] else (HAIR if fhair[i] else HEAD))
            uvs.extend(luv)
            continue
        faces.append([i_suit[v] for v in f])
        freg.append(SUIT)
        uvs.extend(luv)
        for k in range(len(f)):
            a, b = f[k], f[(k + 1) % len(f)]
            if (min(a, b), max(a, b)) in skin_edges:
                ua, ub = luv[k], luv[(k + 1) % len(f)]
                e = ub - ua
                el = np.linalg.norm(e)
                perp = np.array([e[1], -e[0]]) / max(el, 1e-9)
                delta = 0.5 * (tsuit[a] + tsuit[b]) * el / max(np.linalg.norm(P[b] - P[a]), 1e-9)
                faces.append([i_skin[a], i_skin[b], i_suit[b], i_suit[a]])
                uvs.extend([ua + perp * delta, ub + perp * delta, ub, ua])
                freg.append(SUIT)
                rim += 1
    arml = NW[:, [BI[b] for b in ("LeftLowerArm", "LeftHand", "RightLowerArm", "RightHand")]].sum(1)
    # boots: fuse the forefoot of the shell into a round-toe neoprene boot (no toe shapes)
    E = np.array(sorted({(min(f[k], f[(k + 1) % len(f)]), max(f[k], f[(k + 1) % len(f)])) for f, r in zip(faces, freg)
                         if r == SUIT for k in range(len(f))}))
    J = hum.J
    toe = ss(m(0.075), m(0.05), NP[:, 2]) * ss(J["l-ankle"][1] - m(0.03), J["l-ankle"][1] - m(0.08), NP[:, 1])
    toe[:len(skin_v)] = 0
    deg = np.maximum(np.bincount(E.ravel(), minlength=len(NP)), 1).astype(float)
    for _ in range(300):
        Sx = np.zeros_like(NP)
        np.add.at(Sx, E[:, 0], NP[E[:, 1]])
        np.add.at(Sx, E[:, 1], NP[E[:, 0]])
        NP = NP + (0.6 * toe)[:, None] * (Sx / deg[:, None] - NP)
    el = [(np.linalg.norm(NP[f[k]] - NP[f[(k + 1) % len(f)]]), f[k]) for f in faces for k in range(len(f))]
    lmax, vmax = max(el)
    print("[swimmer] %s longest edge %.3f studs at %s" % (name, lmax, np.round(NP[vmax], 3)))
    obj = make_obj(name, NP, faces, uvs, NW, {"EyeMask": neye, "BDist": nbd, "ArmLow": arml}, freg)
    print("[swimmer] %s: %d skin faces kept (head/neck/hands), %d body faces under the suit deleted and replaced by the "
          "shell, %d rim quads, %d hair faces" % (name, int(fskin.sum()), int(fsuit.sum()), rim, int(fhair.sum())))
    return obj, np.array(freg), {"suit_faces": int(fsuit.sum()), "skin_faces": int(fskin.sum()), "rim": rim}

# ---------------------------------------------------------------- hair field (shared by geometry and texture)
def hair_frame(hum):
    m = hum.m
    BV = hum.V[hum.bidx]
    hv = BV[hum.wsum(["Head"])[hum.bidx] > 0.5]
    C = hv.mean(0)
    top = hv[:, 2].max()
    pole = np.array([0.0, C[1] - m(0.075), top - m(0.035)])
    ax = (pole - C) / np.linalg.norm(pole - C)
    e1 = np.array([1.0, 0, 0]) - ax * ax[0]
    e1 /= np.linalg.norm(e1)
    return C, ax, e1, np.cross(ax, e1)


def hair_coords(hum, Q):
    C, ax, e1, e2 = hair_frame(hum)
    r = Q - C
    rn = r / np.maximum(np.linalg.norm(r, axis=1, keepdims=True), 1e-9)
    polar = np.arccos(np.clip(rn @ ax, -1, 1))
    phi = np.arctan2(r @ e2, r @ e1)
    return phi, polar


def hair_clump(hum, Q, seed=3):
    phi, polar = hair_coords(hum, Q)
    rng = np.random.default_rng(seed)
    w = phi + 0.06 * np.sin(polar * 7.0 + 1.3) + 0.03 * np.sin(polar * 17.0)
    c = np.zeros(len(Q))
    for f in (23, 37, 61):
        c += np.sin(w * f + rng.random() * 6.28) / (f / 23.0)
    return np.clip(0.5 + 0.3 * c, 0, 1)


# ---------------------------------------------------------------- lifejacket (real-size bladder) + straps + zip leash
def tube(bm, uvl, path, outs, ws, ds, u0=0.01, u1=0.99, v0=0.01, v1=0.69, ring_n=20):
    """Inflated bladder tube: elliptical rings (outer half d, inner half 0.55 d, half-width w), frames from a smooth
    `outs` field (no flips), closed end caps. UV: u along the path, v around (0 = outer face), humanlib's jacket layout."""
    n = len(path)
    rings, frames = [], []
    for i in range(n):
        tan = path[min(i + 1, n - 1)] - path[max(i - 1, 0)]
        tan = tan / np.linalg.norm(tan)
        out = outs[i] - tan * (outs[i] @ tan)
        out = out / np.linalg.norm(out)
        bb = np.cross(tan, out)
        ring = []
        for k in range(ring_n):
            a = 2 * math.pi * k / ring_n
            ca, sa = math.cos(a), math.sin(a)
            ce, se = math.copysign(abs(ca) ** 0.4, ca), math.copysign(abs(sa) ** 0.4, sa)     # boxy pillow section
            p = path[i] + out * ds[i] * ce * (0.6 if ca < 0 else 1.0) + bb * ws[i] * se
            ring.append(bm.verts.new(tuple(p)))
        rings.append(ring)
        frames.append((path[i] + out * ds[i], out, tan))
    for i in range(n - 1):
        for k in range(ring_n):
            k2 = (k + 1) % ring_n
            f = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
            for lp, (uu, vv) in zip(f.loops, ((i, k), (i, k + 1), (i + 1, k + 1), (i + 1, k))):
                lp[uvl].uv = (u0 + (u1 - u0) * uu / (n - 1.0), v0 + (v1 - v0) * vv / ring_n)
    for i, rev in ((0, True), (n - 1, False)):
        c = bm.verts.new(tuple(path[i]))
        for k in range(ring_n):
            k2 = (k + 1) % ring_n
            vs = (rings[i][k2], rings[i][k], c) if rev else (rings[i][k], rings[i][k2], c)
            f = bm.faces.new(vs)
            for lp in f.loops:
                lp[uvl].uv = (u0 + (u1 - u0) * i / (n - 1.0), v0 + (v1 - v0) * 0.5)
    return frames


def cyl(bm, uvl, c0, ax, side, r, h, u0, u1, segs=12, dome=False, rot=0.0):
    ax = ax / np.linalg.norm(ax)
    s1 = np.cross(side, ax)
    s1 /= np.linalg.norm(s1)
    s2 = np.cross(ax, s1)
    lev = [(0.0, 1.0), (h * 0.85, 1.0), (h, 0.75)] + ([(h + r * 0.6, 0.5), (h + r * 0.9, 0.05)] if dome else [(h + 0.002, 0.05)])
    rr = [[bm.verts.new(tuple(c0 + ax * z + (s1 * math.cos(2 * math.pi * k / segs + rot) + s2 * math.sin(2 * math.pi * k / segs + rot)) * r * sc))
           for k in range(segs)] for z, sc in lev]
    for j in range(len(rr) - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            f = bm.faces.new((rr[j][k], rr[j][k2], rr[j + 1][k2], rr[j + 1][k]))
            for lp, (uu, vv) in zip(f.loops, ((k, j), (k + 1, j), (k + 1, j + 1), (k, j + 1))):
                lp[uvl].uv = (u0 + (u1 - u0) * uu / segs, 0.885 + 0.105 * vv / (len(rr) - 1))
    return c0 + ax * lev[-1][0]


def ribbon_closed(bm, uvl, pts, nrm, width, th):
    ribbon(bm, uvl, pts, nrm, width, th)


def ribbon(bm, uvl, pts, nrm, width, th, u0=0.01, u1=0.99, v0=0.72, v1=0.86):
    n = len(pts)
    L = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
    rows = []
    for i in range(n):
        tan = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        tan /= np.linalg.norm(tan)
        nn = nrm[i] - tan * (nrm[i] @ tan)
        nn /= np.linalg.norm(nn)
        side = np.cross(tan, nn)
        p = pts[i]
        rows.append([bm.verts.new(tuple(p + side * sx * width / 2 + nn * sz)) for sx, sz in
                     ((-1, 0), (1, 0), (1, th), (-1, th))])
    for i in range(n - 1):
        for j in range(4):
            j2 = (j + 1) % 4
            f = bm.faces.new((rows[i][j], rows[i][j2], rows[i + 1][j2], rows[i + 1][j]))
            for lp, (a, b) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                lp[uvl].uv = (u0 + (u1 - u0) * L[a] / L[-1], v0 + (v1 - v0) * b / 4.0)

# ---------------------------------------------------------------- UV atlas
def set_uvs(obj, uv):
    obj.data.uv_layers["UVMap"].data.foreach_set("uv", np.asarray(uv, np.float32).ravel())


def get_uvs(obj):
    a = np.empty(len(obj.data.loops) * 2, np.float32)
    obj.data.uv_layers["UVMap"].data.foreach_get("uv", a)
    return a.reshape(-1, 2).astype(np.float64)


def pack_region(obj, freg, reg):
    if not (freg == reg).any():
        return
    u0, v0, w, h = TILES[reg]
    asp = h / w
    u0, v0, w, h = u0 + 0.003, v0 + 0.003, w - 0.006, h - 0.006
    T = H.copy_obj(obj, "TMP_Pack")
    H.keep_faces(T, list(freg == reg))
    H.select_only(T)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    try:
        bpy.ops.uv.select_all(action='SELECT')
    except Exception:
        pass
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode='OBJECT')
    uv = get_uvs(T)
    uv[:, 0] *= asp
    set_uvs(T, uv)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    try:
        bpy.ops.uv.select_all(action='SELECT')
    except Exception:
        pass
    bpy.ops.uv.pack_islands(rotate=(asp == 1.0), margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    uv = get_uvs(T)
    uv = np.stack([u0 + uv[:, 0] * w, v0 + uv[:, 1] * h], 1)
    full = get_uvs(obj)
    li = [l for p in obj.data.polygons if freg[p.index] == reg for l in range(p.loop_start, p.loop_start + p.loop_total)]
    full[li] = uv
    set_uvs(obj, full)
    bpy.data.objects.remove(T, do_unlink=True)


def ao_bake(obj, size):
    nb = H.NB(obj.data.materials[0])
    out = nb.n("ShaderNodeOutputMaterial")
    bsdf = nb.n("ShaderNodeBsdfPrincipled")
    nb.nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    img = H.bake_image("b_ao", size)
    tex = nb.n("ShaderNodeTexImage", _image=img)
    nb.nt.nodes.active = tex
    sc = bpy.context.scene
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.light_settings.distance = 0.35
    sc.cycles.samples = 24
    H.select_only(obj)
    bpy.ops.object.bake(type='AO', margin=8, use_clear=False)
    sc.cycles.samples = 4
    return H.read_px(img)


def resize_half_rows(a):
    a = a.astype(np.float32)
    return a.reshape(a.shape[0] // 2, 2, *a.shape[1:]).mean(1)



# ================================================================ v3: loose gear built as the outer mesh
K_SUIT, K_LJ, K_BOOT, K_SOLE, K_WEB, K_TAPE, K_HW, K_CUFF, K_SEAM = 2, 4, 5, 6, 7, 8, 9, 10, 11   # 0 head, 1 hand, 3 hair
ARM_DOWN = 18.0             # arms a little further from the body than v2 (8 deg): clear of the baggy torso
TRIS = {"skin": 3600, "suit": 8400, "boots": 1100, "lj": 2600, "gloves": 1300}
PAL = {K_SUIT: (43, 52, 69), K_LJ: (226, 88, 30), K_BOOT: (32, 33, 35), K_SOLE: (58, 55, 52), K_WEB: (30, 30, 32),
       K_TAPE: (200, 202, 198), K_HW: (214, 196, 70), K_CUFF: (33, 35, 42), K_SEAM: (30, 37, 50)}
RGH = {K_SUIT: 0.55, K_LJ: 0.48, K_BOOT: 0.32, K_SOLE: 0.85, K_WEB: 0.72, K_TAPE: 0.38, K_HW: 0.3, K_CUFF: 0.68,
       K_SEAM: 0.5}


def sgp(a, p):
    return np.sign(a) * np.abs(a) ** (2.0 / p)


def sup_pt(c, ru, rv, p, t):
    """Superellipse section point(s) at height c[2]; t = 0 front (-Y), pi/2 = +X (left side), pi = back."""
    t = np.asarray(t, float)
    x, y = ru * sgp(np.sin(t), p), -rv * sgp(np.cos(t), p)
    return np.stack([c[0] + x, c[1] + y, np.full_like(x, c[2])], -1)


def sup_n(ru, rv, p, t):
    t = np.asarray(t, float)
    x, y = sgp(np.sin(t), p), -sgp(np.cos(t), p)
    gx = np.sign(x) * np.abs(x) ** (p - 1) / ru
    gy = np.sign(y) * np.abs(y) ** (p - 1) / rv
    n = np.stack([gx, gy, np.zeros_like(gx)], -1)
    return n / np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-9)


def loft_obj(name, rings, cap=True):
    """Closed mesh from rings ((n,3) arrays, same n), n-gon caps."""
    n, R = len(rings[0]), len(rings)
    V = np.concatenate(rings)
    F = [[i * n + k, i * n + (k + 1) % n, (i + 1) * n + (k + 1) % n, (i + 1) * n + k] for i in range(R - 1) for k in range(n)]
    if cap:
        F += [list(range(n))[::-1], [(R - 1) * n + k for k in range(n)]]
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in V], [], F)
    me.update()
    return H.link(bpy.data.objects.new(name, me))


def tube_rings(path, ru, rv, ref, n=24, p=2.0):
    rings = []
    t = np.linspace(0, 2 * math.pi, n, endpoint=False)
    for i in range(len(path)):
        tan = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
        tan = tan / np.linalg.norm(tan)
        u = ref - tan * (ref @ tan)
        u /= np.linalg.norm(u)
        v = np.cross(tan, u)
        rings.append(path[i] + np.outer(ru[i] * sgp(np.cos(t), p), u) + np.outer(rv[i] * sgp(np.sin(t), p), v))
    return rings


def resample(pts, step):
    pts = np.asarray(pts, float)
    L = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
    s = np.linspace(0, L[-1], max(2, int(round(L[-1] / step)) + 1))
    out = np.stack([np.interp(s, L, pts[:, k]) for k in range(3)], 1)
    for _ in range(6):                                           # round the corners at the joints
        out[1:-1] = 0.25 * out[:-2] + 0.5 * out[1:-1] + 0.25 * out[2:]
    return out


def smooth1(a, k=2, it=3):
    a = np.asarray(a, float).copy()
    for _ in range(it):
        b = a.copy()
        for i in range(len(a)):
            b[i] = a[max(0, i - k):i + k + 1].mean()
        a = b
    return a


def fill_nan(a):
    a = np.asarray(a, float)
    ok = ~np.isnan(a)
    return np.interp(np.arange(len(a)), np.nonzero(ok)[0], a[ok])


def join(objs, name):
    H.select_only(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    objs[0].name = objs[0].data.name = name
    return objs[0]


def remesh(obj, voxel, smooth=4, factor=0.5):
    mod = obj.modifiers.new("R", 'REMESH')
    mod.mode, mod.voxel_size, mod.adaptivity = 'VOXEL', voxel, 0.0
    H.select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        s = obj.modifiers.new("S", 'SMOOTH')
        s.factor, s.iterations = factor, smooth
        bpy.ops.object.modifier_apply(modifier=s.name)
    return obj


def arrays(obj):
    me = obj.data
    P = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3).astype(np.float64)
    polys = [tuple(p.vertices) for p in me.polygons]
    return P, polys


def set_co(obj, P):
    obj.data.vertices.foreach_set("co", np.asarray(P, np.float32).ravel())
    obj.data.update()


def bm_obj(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return H.link(bpy.data.objects.new(name, me))


def seg_class(hum, P):
    names = list(hum.seg)
    D = np.stack([H.seg_dist(P, *hum.seg[b]) for b in names], 1)
    return np.array(names)[np.argmin(D, 1)]


# ---------------------------------------------------------------- measurements
def measure(hum):
    m, J = hum.m, hum.J
    BV, BW = hum.V[hum.bidx], hum.W[hum.bidx]
    G = {"BV": BV, "BW": BW}
    for s, sg in (("l", "Left"), ("r", "Right")):
        G["arm_" + s] = BW[:, [BI[sg + b] for b in ("UpperArm", "LowerArm", "Hand")]].sum(1)
        G["leg_" + s] = BW[:, [BI[sg + b] for b in ("UpperLeg", "LowerLeg", "Foot")]].sum(1)
        G["foot_" + s] = BW[:, BI[sg + "Foot"]]
    nonarm = G["arm_l"] + G["arm_r"] < 0.3
    mid = BV[(np.abs(BV[:, 0]) < m(0.008)) & (BV[:, 2] > J["l-knee"][2])]
    cz = mid[:, 2].min()
    zsh = 0.5 * (J["l-shoulder"][2] + J["r-shoulder"][2])
    zs = np.arange(cz + m(0.04), zsh - m(0.06), m(0.02))
    hw, hd, cy = [], [], []
    for z in zs:
        q = BV[nonarm & (np.abs(BV[:, 2] - z) < m(0.012))]
        hw.append(np.abs(q[:, 0]).max())
        hd.append(0.5 * (q[:, 1].max() - q[:, 1].min()))
        cy.append(0.5 * (q[:, 1].max() + q[:, 1].min()))
    fit = np.polyfit(zs, cy, 1)
    N, Hd = J["neck"], J["head"]
    zcol = N[2] + 0.42 * (Hd[2] - N[2])
    q = BV[nonarm & (BV[:, 2] > N[2] + m(0.01)) & (BV[:, 2] < zcol - m(0.005))]
    ncy = 0.5 * (q[:, 1].max() + q[:, 1].min())
    rn = np.hypot(q[:, 0], q[:, 1] - ncy).max()
    G.update(cz=cz, zsh=zsh, RU=max(hw) + m(0.05), RV=max(hd) + m(0.045), fit=fit, zn=N[2], ncy=ncy, rn=rn,
             zcol=zcol, xsh=0.5 * (abs(J["l-shoulder"][0]) + abs(J["r-shoulder"][0])))
    print("[swimmer] body: crotch z %.3f shoulders z %.3f torso half %.3f x %.3f (gear), neck r %.3f" %
          (cz, zsh, G["RU"], G["RV"], rn))
    return G


def torso_sec(hum, G, z):
    """Drysuit torso section at z: (centre, ru, rv, p). Boxy constant column from the gusset to the chest."""
    m = hum.m
    RU, RV, cz, zsh, zn, rn = G["RU"], G["RV"], G["cz"], G["zsh"], G["zn"], G["rn"]
    zb0 = cz - m(0.2)                                   # jacket hem at mid-thigh
    zt = min(zsh + m(0.035), zn - m(0.025))
    rush = max(0.82 * RU, G["xsh"] + m(0.03))          # narrower over the shoulders: the sleeves carry the width
    rc = rn + m(0.03)
    Z = [zb0, zb0 + m(0.02), zb0 + m(0.06), zb0 + m(0.13), zsh - m(0.11), zsh - m(0.02), zt, zn, zn + m(0.02)]
    ru = np.interp(z, Z, [1.0 * RU, 1.04 * RU, 1.03 * RU, RU, RU, rush, 0.72 * rush, rc + m(0.012), rc])
    rv = np.interp(z, Z, [1.02 * RV, 1.06 * RV, 1.05 * RV, RV, RV, 0.9 * RV, 0.72 * RV, rc + m(0.012), rc])
    p = np.interp(z, Z, [2.8, 2.7, 2.7, 2.7, 2.7, 2.6, 2.3, 2.0, 2.0])
    zf = cz + m(0.04)
    cy = np.interp(z, [zf, zsh, zn], [np.polyval(G["fit"], zf), np.polyval(G["fit"], zsh), G["ncy"]])
    return np.array([0.0, cy, z]), ru, rv, p


# ---------------------------------------------------------------- drysuit
def suit_pieces(hum, G):
    m, J = hum.m, hum.J
    BV = G["BV"]
    objs, limbs = [], {}
    # torso + collar: one loft; the collar rings tilt with the skin cut (lower at the front)
    zb0 = G["cz"] - m(0.2)
    ztop = G["zcol"] + m(0.018)
    zs = np.concatenate([np.arange(zb0, G["zn"] + m(0.02), m(0.02)), np.linspace(G["zn"] + m(0.02), ztop, 4)[1:]])
    t = np.linspace(0, 2 * math.pi, 40, endpoint=False)
    rings = []
    for z in zs:
        c, ru, rv, p = torso_sec(hum, G, z)
        r = sup_pt(c, ru, rv, p, t)
        w = ss(G["zn"], ztop, z)
        r[:, 2] += w * 0.3 * (r[:, 1] - G["ncy"])
        rings.append(r)
    objs.append(loft_obj("TMP_Torso", rings))
    # sleeves
    for s, side in (("l", 1), ("r", -1)):
        sh, el, hj = J[s + "-shoulder"], J[s + "-elbow"], J[s + "-hand"]
        d = (hj - el) / np.linalg.norm(hj - el)
        wend = hj - d * m(0.005)
        path = resample([sh + [-side * m(0.04), 0, m(0.01)], sh, el, wend], m(0.02))
        sel = G["arm_" + s] > 0.5
        r = []
        for i, c in enumerate(path):
            tan = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
            tan /= np.linalg.norm(tan)
            dd = BV[sel] - c
            h = dd @ tan
            k = np.abs(h) < m(0.012)
            r.append(np.linalg.norm(dd[k] - np.outer(h[k], tan), axis=1).max() if k.sum() > 3 else np.nan)
        r = np.minimum(smooth1(fill_nan(r), 3, 3) + m(0.035), m(0.092))
        L = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
        e = L[-1] - L                                         # distance from the cuff end
        rw = r[-1] - m(0.04) + m(0.024)                       # cinched cuff
        r = r * ss(m(0.02), m(0.07), e) + rw * (1 - ss(m(0.02), m(0.07), e))
        objs.append(loft_obj("TMP_Sleeve_" + s, tube_rings(path, r, r * 1.05, np.array([side, 0, 0.0]), 22)))
        limbs["arm_" + s] = (path, r, wend, d)
    # trouser legs: straight baggy tubes, no calf or knee shape, kept apart below the gusset
    hemz = m(0.215)
    for s, side in (("l", 1), ("r", -1)):
        hip, kn, an = J[s + "-upper-leg"], J[s + "-knee"], J[s + "-ankle"]
        hem = np.array([an[0], an[1] + m(0.005), hemz])
        path = resample([hip + [0, 0, m(0.07)], hip, kn, hem], m(0.025))
        sel = G["leg_" + s] > 0.5
        r = []
        for i, c in enumerate(path):
            tan = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
            tan /= np.linalg.norm(tan)
            dd = BV[sel] - c
            h = dd @ tan
            k = (np.abs(h) < m(0.015)) & (BV[sel, 2] > m(0.12))
            r.append(np.linalg.norm(dd[k] - np.outer(h[k], tan), axis=1).max() if k.sum() > 3 else np.nan)
        r = fill_nan(r)
        L = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
        Lk = L[np.argmin(np.linalg.norm(path - kn, axis=1))]
        r = np.minimum(r, np.interp(m(0.07) + Lk * 0.4, L, r))         # thigh measured at mid-thigh, not the hip
        r = np.maximum.accumulate(r[::-1])[::-1]               # never narrower above than below: straight leg
        r = np.clip(smooth1(r, 3, 3) + m(0.055), m(0.10), m(0.14))
        ry = r.copy()
        lim = np.abs(path[:, 0]) - m(0.008)
        low = path[:, 2] < G["cz"] - m(0.02)          # apart below the gusset: no fused ridge between the legs
        rx = np.where(low, np.minimum(r, lim), r)
        objs.append(loft_obj("TMP_Leg_" + s, tube_rings(path, rx, ry, np.array([side, 0, 0.0]), 24)))
        limbs["leg_" + s] = (path, rx, hem, None, ry)
        print("[swimmer] leg %s: r top %.3f knee %.3f hem %.3f, gap at the knee %.3f" % (
            s, r[0], np.interp(kn[2], path[::-1, 2], rx[::-1]), rx[-1], 2 * (abs(kn[0]) - np.interp(kn[2], path[::-1, 2], rx[::-1]))))
    # closed inseam: a thick flat-bottomed block between the legs from the gusset to 12 cm below the jacket hem, so no
    # gap, arch or crease shows at the crotch below the hem (legs part only lower down, under a flat blunt inseam)
    zi = G["cz"] - m(0.32)
    t = np.linspace(0, 2 * math.pi, 32, endpoint=False)
    rings = []
    for z, k in [(z, 1.0) for z in np.arange(G["cz"] + m(0.04), zi, -m(0.03))] + [(zi, 0.97), (zi - m(0.012), 0.9)]:
        xs, ys, rs = [], [], []
        for s in ("l", "r"):
            path, _, _, _, ry = limbs["leg_" + s]
            o = np.argsort(path[:, 2])
            xs.append(abs(np.interp(z, path[o, 2], path[o, 0])))
            ys.append(np.interp(z, path[o, 2], path[o, 1]))
            rs.append(np.interp(z, path[o, 2], ry[o]))
        c = np.array([0.0, np.mean(ys), z])
        rings.append(sup_pt(c, np.mean(xs) * k, 0.9 * np.mean(rs) * k, 3.0, t))
    objs.append(loft_obj("TMP_Inseam", rings))
    return objs, limbs, hemz


def add_folds(hum, G, obj, limbs, hemz):
    m, J = hum.m, hum.J
    P, polys = arrays(obj)
    N = vnormals(P, polys, [True] * len(polys))
    cls = seg_class(hum, P)
    disp = np.zeros(len(P))

    def crease(x):
        w = x - np.floor(x)
        return np.exp(-((w - 0.5) / 0.17) ** 2) - 0.3

    def frame(ax, ref):
        u = ref - ax * (ref @ ax)
        u /= np.linalg.norm(u)
        return u, np.cross(ax, u)
    for s, sg in (("l", "Left"), ("r", "Right")):
        arm = np.isin(cls, [sg + "UpperArm", sg + "LowerArm", sg + "Hand"])
        leg = np.isin(cls, [sg + "UpperLeg", sg + "LowerLeg", sg + "Foot"])
        for jn, a_, b_, amp, inner, msk, ph in ((s + "-elbow", s + "-shoulder", s + "-hand", m(0.014), np.array([0, -1.0, 0]), arm, 0.7),
                                                (s + "-knee", s + "-upper-leg", s + "-ankle", m(0.015), np.array([0, 1.0, 0]), leg, 2.1)):
            ax = J[b_] - J[a_]
            ax /= np.linalg.norm(ax)
            u, v = frame(ax, inner)
            d = P - J[jn]
            h = d @ ax
            th = np.arctan2(d @ v, d @ u)
            w = np.exp(-(h / m(0.11)) ** 2) * msk
            disp += amp * w * crease(h / m(0.055) + 0.5 * np.sin(th + ph) + 0.25 * np.cos(2 * th + ph)) * (0.55 + 0.45 * np.cos(th))
        # long drape folds down the trouser legs and sleeves
        for msk, (path, *_), k in ((leg, limbs["leg_" + s], 3), (arm, limbs["arm_" + s], 2)):
            a, b = path[1], path[-1]
            ax = (b - a) / np.linalg.norm(b - a)
            u, v = frame(ax, np.array([0, -1.0, 0]))
            d = P - a
            th = np.arctan2(d @ v, d @ u)
            disp += m(0.007) * msk * np.sin(k * th + 1.3 * (d @ ax) / m(0.3) + (1.0 if s == "l" else 2.4))
        # bunching above the hem and the cuff
        path = limbs["leg_" + s][0]
        ax = (path[-1] - path[-4]) / np.linalg.norm(path[-1] - path[-4])
        u, v = frame(ax, np.array([1.0, 0, 0]))
        d = P - path[-1]
        th = np.arctan2(d @ v, d @ u)
        w = ss(hemz + m(0.2), hemz + m(0.03), P[:, 2]) * leg
        disp += m(0.013) * w * crease((P[:, 2] - hemz) / m(0.05) + 0.4 * np.sin(th + 0.5))
        path, r, wend, dd = limbs["arm_" + s]
        e = (P - wend) @ (-dd)
        u, v = frame(dd, np.array([0, -1.0, 0]))
        th = np.arctan2((P - wend) @ v, (P - wend) @ u)
        w = ss(m(0.15), m(0.04), e) * (e > -m(0.01)) * arm
        disp += m(0.01) * w * crease(e / m(0.045) + 0.35 * np.sin(th))
    # no folds at the crotch (the closed inseam stays flat); waist sides: horizontal compression folds
    pz = J["pelvis"][2]
    band = ss(pz - m(0.02), pz + m(0.06), P[:, 2]) * ss(pz + m(0.38), pz + m(0.26), P[:, 2])
    disp += m(0.009) * band * ss(0.25, 0.75, np.abs(N[:, 0])) * crease(P[:, 2] / m(0.065) + 0.5 * np.sin(P[:, 1] / m(0.09)))
    # overall bagginess
    disp += m(0.006) * np.sin(P[:, 0] / m(0.11) + 1.0) * np.sin(P[:, 2] / m(0.17) + P[:, 1] / m(0.2))
    E = np.array(sorted({(min(f[k], f[(k + 1) % len(f)]), max(f[k], f[(k + 1) % len(f)])) for f in polys for k in range(len(f))}))
    deg = np.maximum(np.bincount(E.ravel(), minlength=len(P)), 1)
    for _ in range(2):
        S = np.zeros(len(P))
        np.add.at(S, E[:, 0], disp[E[:, 1]])
        np.add.at(S, E[:, 1], disp[E[:, 0]])
        disp = 0.5 * disp + 0.5 * S / deg
    set_co(obj, P + N * disp[:, None])
    print("[swimmer] folds: displacement %.4f..%.4f studs" % (disp.min(), disp.max()))


def rib(bm, uvl, pts, nrm, width, th):
    """ribbon() without NaNs or repeated points (a zero tangent would make NaN vertices)."""
    pts, nrm = np.asarray(pts, float), np.asarray(nrm, float)
    ok = np.isfinite(pts).all(1) & np.isfinite(nrm).all(1)
    pts, nrm = pts[ok], nrm[ok]
    keep = [0]
    for i in range(1, len(pts)):
        if np.linalg.norm(pts[i] - pts[keep[-1]]) > 1e-4:
            keep.append(i)
    if len(keep) >= 2:
        ribbon(bm, uvl, pts[keep], nrm[keep], width, th)


def surf_ring(Pg, c, ax, ref, n=28, slab=None, lift=0.0, rmax=None):
    ax = ax / np.linalg.norm(ax)
    u = ref - ax * (ref @ ax)
    u /= np.linalg.norm(u)
    v = np.cross(ax, u)
    d = Pg - c
    h = d @ ax
    q = d - np.outer(h, ax)
    r = np.linalg.norm(q, axis=1)
    k = (np.abs(h) < slab) & ((r < rmax) if rmax else True)
    q, r = q[k], r[k]
    a = np.arctan2(q @ v, q @ u)
    A = np.linspace(-math.pi, math.pi, n + 1)
    R = []
    for x in A:
        dif = np.abs((a - x + math.pi) % (2 * math.pi) - math.pi)
        R.append(r[dif < 0.16].max() if (dif < 0.16).any() else np.nan)
    R = fill_nan(R)
    R[-1] = R[0]
    dirs = np.outer(np.cos(A), u) + np.outer(np.sin(A), v)
    return c + dirs * (R + lift)[:, None], dirs


def surf_line(Pg, path, out, slab, lift, win=0.14):
    pts, nrm = [], []
    for i, c in enumerate(path):
        tan = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
        tan /= np.linalg.norm(tan)
        o = out - tan * (out @ tan)
        o /= np.linalg.norm(o)
        d = Pg - c
        h = d @ tan
        q = d - np.outer(h, tan)
        r = np.linalg.norm(q, axis=1)
        k = (np.abs(h) < slab) & (r > 1e-6)
        ca = (q[k] @ o) / r[k]
        g = ca > math.cos(win)
        pts.append(c + o * ((r[k][g].max() if g.any() else np.nan) + lift))
        nrm.append(o)
    P = np.array(pts)
    for j in range(3):
        P[:, j] = fill_nan(P[:, j])
    return P, np.array(nrm)


def suit_trims(hum, G, suit, limbs, hemz):
    """Raised seam piping, cuffs and hems with thickness, retro tape on the upper sleeves (sampled on the suit)."""
    m, J = hum.m, hum.J
    P, _ = arrays(suit)
    cls = seg_class(hum, P)
    out = {}
    for kind in (K_SEAM, K_CUFF, K_TAPE):
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        for s, sg, side in (("l", "Left", 1), ("r", "Right", -1)):
            armP = P[np.isin(cls, [sg + "UpperArm", sg + "LowerArm", sg + "Hand"])]
            legP = P[np.isin(cls, [sg + "UpperLeg", sg + "LowerLeg", sg + "Foot"])]
            apath, _, wend, dd = limbs["arm_" + s]
            lpath = limbs["leg_" + s][0]
            if kind == K_SEAM:
                L = resample(apath[3:-3], m(0.04))
                pts, nr = surf_line(armP, L, np.array([side, 0, 0.0]), m(0.02), m(0.002))
                rib(bm, uvl, pts, nr, m(0.014), m(0.0045))
                L = resample(lpath[2:-2], m(0.045))
                pts, nr = surf_line(legP, L, np.array([side, 0, 0.0]), m(0.022), m(0.002))
                rib(bm, uvl, pts, nr, m(0.014), m(0.0045))
                L = resample(lpath[lpath[:, 2] < J[s + "-knee"][2] + m(0.12)][:-2], m(0.045))
                pts, nr = surf_line(legP, L, np.array([-side, 0, 0.0]), m(0.022), m(0.002))
                rib(bm, uvl, pts, nr, m(0.012), m(0.004))
            elif kind == K_CUFF:
                c = wend - dd * m(0.024)
                pts, nr = surf_ring(armP, c, dd, np.array([side, 0, 0.0]), 28, m(0.02), m(0.001), m(0.15))
                rib(bm, uvl, pts, nr, m(0.046), m(0.009))
                ax = lpath[-1] - lpath[-4]
                c = lpath[-1] - ax / np.linalg.norm(ax) * m(0.022)
                pts, nr = surf_ring(legP, c, ax, np.array([side, 0, 0.0]), 28, m(0.02), m(0.001), m(0.2))
                rib(bm, uvl, pts, nr, m(0.04), m(0.008))
            else:
                sh, el = J[s + "-shoulder"], J[s + "-elbow"]
                c = sh + 0.42 * (el - sh)
                pts, nr = surf_ring(armP, c, el - sh, np.array([side, 0, 0.0]), 28, m(0.02), m(0.002), m(0.17))
                rib(bm, uvl, pts, nr, m(0.05), m(0.003))
        if kind == K_CUFF:
            torP = P[np.isin(cls, ["LowerTorso", "UpperTorso"])]
            z = G["cz"] - m(0.2) + m(0.022)
            c = torso_sec(hum, G, z)[0]
            pts, nr = surf_ring(P, c, np.array([0, 0, 1.0]), np.array([0, -1.0, 0]), 32, m(0.02), m(0.001), m(0.4))
            rib(bm, uvl, pts, nr, m(0.04), m(0.008))
        out[kind] = bm_obj(bm, "TMP_Trim_%d" % kind)
    return out


# ---------------------------------------------------------------- neoprene rescue gloves
def build_gloves(hum, G, hands, limbs):
    """Neoprene gloves from the hand skin (which is then deleted): the hand surface thickened outward by 7 mm into a
    solid and voxel-remeshed so the fingers fuse into simplified, rounded glove fingers, unioned with a thick gauntlet
    cuff that sits over the drysuit wrist seal. No hand inside: the only skin left is the face and the neck."""
    m = hum.m
    mod = hands.modifiers.new("T", 'SOLIDIFY')
    mod.thickness, mod.offset, mod.use_even_offset = m(0.007), 1.0, True
    H.select_only(hands)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    objs = [hands]
    for s, side in (("l", 1), ("r", -1)):
        path, r, wend, d = limbs["arm_" + s]
        rw = r[-1]
        e = np.array([-0.065, -0.05, -0.02, 0.0, 0.02, 0.04])
        P = np.array([wend + d * m(x) for x in e])
        ru = np.interp(e, [-0.065, -0.05, 0.0, 0.02, 0.04], [rw + m(0.012), rw + m(0.02), rw + m(0.016), rw - m(0.002), m(0.034)])
        objs.append(loft_obj("TMP_GloveCuff_" + s, tube_rings(P, ru * 0.92, ru, np.array([side, 0, 0.0]), 24)))
    g = join(objs, "TMP_Gloves")
    remesh(g, m(0.0045), 6, 0.5)
    g.vertex_groups.clear()
    for k in [a.name for a in g.data.attributes if a.name in ("Region", "Kind", "EyeMask", "BDist", "ArmLow")]:
        g.data.attributes.remove(g.data.attributes[k])
    return g


# ---------------------------------------------------------------- sea boots
def build_boots(hum, G):
    m, J = hum.m, hum.J
    objs = []
    for s in ("l", "r"):
        an = J[s + "-ankle"]
        fv = G["BV"][G["foot_" + s] > 0.5]
        yh, yt = fv[:, 1].max() + m(0.014), fv[:, 1].min() - m(0.02)
        xc = 0.5 * (fv[:, 0].max() + fv[:, 0].min())
        w = 0.5 * (fv[:, 0].max() - fv[:, 0].min()) + m(0.015)
        tt = np.linspace(0, 2 * math.pi, 26, endpoint=False)
        X, Z = np.array([1.0, 0, 0]), np.array([0, 0, 1.0])
        # upper: heel to toe in x-z sections (round toe box, tall instep), no toe or ankle shapes
        us = np.concatenate([[-0.035], np.linspace(0, 1, 14), [1.025]])
        rings = []
        for u in us:
            uc = np.clip(u, 0, 1)
            y = yh + (yt - yh) * u
            top = np.interp(uc, [0, 0.3, 0.6, 0.85, 1], [m(0.16), m(0.15), m(0.105), m(0.08), m(0.068)])
            bot = m(0.004)
            hw = w * np.interp(uc, [0, 0.15, 0.6, 0.9, 1], [0.86, 0.96, 1.0, 0.9, 0.62])
            k = 0.55 if u < 0 else (0.45 if u > 1 else 1.0)
            x0 = xc + np.interp(uc, [0, 1], [0, (xc - an[0]) * 0.3])
            c = np.array([x0, y, 0.5 * (top + bot)])
            rz = 0.5 * (top - bot) * (k if k < 1 else 1)
            rings.append(c + np.outer(hw * k * sgp(np.cos(tt), 2.8), X) + np.outer(rz * sgp(np.sin(tt), 2.8), Z))
        objs.append(loft_obj("TMP_BootFoot_" + s, rings))
        # shaft to mid-calf (under the trouser hem)
        zs = np.linspace(m(0.06), m(0.33), 8)
        path = np.array([[an[0], an[1] + m(0.012), z] for z in zs])
        rx = np.full(len(zs), m(0.064))
        objs.append(loft_obj("TMP_BootShaft_" + s, tube_rings(path, rx, rx * 1.15, np.array([1.0, 0, 0]), 22)))
        # sole with a heel block and toe spring
        us = np.concatenate([[-0.01], np.linspace(0, 1, 16), [1.01]])
        rings = []
        for u in us:
            uc = np.clip(u, 0, 1)
            y = yh + m(0.004) + (yt - m(0.01) - yh - m(0.004)) * u
            bot = np.interp(uc, [0, 0.27, 0.3, 0.8, 1.0], [-m(0.034), -m(0.034), -m(0.021), -m(0.021), -m(0.004)])
            top = m(0.013)
            hw = (w + m(0.007)) * np.interp(uc, [0, 0.15, 0.6, 0.9, 1], [0.86, 0.96, 1.0, 0.9, 0.6]) * (0.8 if u < 0 or u > 1 else 1)
            x0 = xc + np.interp(uc, [0, 1], [0, (xc - an[0]) * 0.3])
            c = np.array([x0, y, 0.5 * (top + bot)])
            rings.append(c + np.outer(hw * sgp(np.cos(tt), 6), X) + np.outer(0.5 * (top - bot) * sgp(np.sin(tt), 6), Z))
        objs.append(loft_obj("TMP_BootSole_" + s, rings))
    b = join(objs, "TMP_Boots")
    remesh(b, m(0.006), 2, 0.4)
    return b


# ---------------------------------------------------------------- lifejacket
def lj_shell(hum, G, z, t0, tw, T, inner_off):
    c, ru, rv, p = torso_sec(hum, G, z)
    ts = np.linspace(t0 - tw, t0 + tw, 21)
    e = np.maximum(np.sqrt(np.clip((1 - np.abs(ts - t0) / tw) / 0.38, 0, 1)), 0.22)
    base = sup_pt(c, ru, rv, p, ts)
    n = sup_n(ru, rv, p, ts)
    outer = base + n * (T(ts) * e)[:, None]
    inner = base - n * inner_off
    return np.concatenate([outer, inner[::-1]])


def build_lifejacket(hum, G):
    m, J = hum.m, hum.J
    zb = J["pelvis"][2] - m(0.06)
    zt = min(G["zsh"] + m(0.035), G["zn"] - m(0.025)) + m(0.01)
    G["lj_zb"], G["lj_zt"] = zb, zt
    pieces = []

    def env(u):
        return (0.62 + 0.38 * np.sin(math.pi * np.clip(u, 0, 1)) ** 0.6) * max(0.35, math.sqrt(min(1, u / 0.07))) * \
            max(0.35, math.sqrt(min(1, (1 - u) / 0.07)))
    for t0, Tm, tws, ribs in ((0.0, m(0.11), [0.85, 1.05, 1.2, 1.15], 0.17), (math.pi, m(0.065), [0.72, 0.92, 1.15, 1.1], 0.1)):
        rings = []
        zz = np.linspace(zb, zt, 15)
        for i, z in enumerate(zz):
            u = (z - zb) / (zt - zb)
            tw = np.interp(u, [0, 0.7, 0.92, 1.0], tws)
            T = (lambda ts: Tm * env(u) * (1 - ribs + ribs * np.cos(5.2 * (ts - t0))))
            if i == 0 or i == len(zz) - 1:          # rounded end: a zero-thickness ring just beyond the last one
                zd = z + (-1 if i == 0 else 1) * m(0.012)
                end = lj_shell(hum, G, zd, t0, tw * 0.97, lambda ts: 0.25 * T(ts), 0.0)
                h = len(end) // 2
                mid = 0.5 * (end[:h] + end[h:][::-1])
                end = np.concatenate([mid, mid[::-1]])
            rings.append(lj_shell(hum, G, z, t0, tw, T, m(0.015)))
            if i == 0:
                rings.insert(0, end)
            elif i == len(zz) - 1:
                rings.append(end)
        pieces.append(loft_obj("TMP_LJPanel", rings))
    # pillow collar behind the head
    zn, rc = G["zn"], G["rn"] + m(0.03) + m(0.05)
    ph = np.linspace(-2.1, 2.1, 17)
    path = np.stack([rc * np.sin(ph), G["ncy"] + rc * np.cos(ph), zn + m(0.03) + m(0.035) * np.cos(ph / 2) ** 2], 1)
    rr = m(0.055) * np.maximum(np.sqrt(np.clip((2.1 - np.abs(ph)) / 0.5, 0, 1)), 0.55)
    pieces.append(loft_obj("TMP_LJCollar", tube_rings(path, rr, rr * 1.15, np.array([0, 0, 1.0]), 18)))
    # inflated yoke straps over each shoulder, beside the neck, front panel top to back panel top
    zs = G["zsh"] - m(0.07)
    c, ru, rv, p = torso_sec(hum, G, zs)
    for side in (1, -1):
        tf, tb = side * 0.36, math.pi - side * 0.36
        f = sup_pt(c, ru, rv, p, tf) + sup_n(ru, rv, p, tf) * m(0.05)
        b = sup_pt(c, ru, rv, p, tb) + sup_n(ru, rv, p, tb) * m(0.03)
        top = np.array([side * (G["rn"] + m(0.04)), G["ncy"], G["zn"] - m(0.005)])
        path = resample([f, 0.5 * (f + top) + [0, 0, m(0.03)], top, 0.5 * (b + top) + [0, 0, m(0.03)], b], m(0.02))
        k = len(path)
        rr = np.full(k, m(0.042))
        pieces.append(loft_obj("TMP_LJYoke", tube_rings(path, rr, rr * 0.7, np.array([side, 0, 0.0]), 16)))
    lj = join(pieces, "TMP_LJ")
    remesh(lj, m(0.009), 3, 0.5)
    G["collar_path"] = path
    return lj


def lj_trims(hum, G, suit, lj):
    """Chest and waist belts with buckles, the wide crotch-strap webbing panel; strobe and whistle."""
    m, J = hum.m, hum.J
    Ps, _ = arrays(suit)
    Pl, _ = arrays(lj)
    cls = seg_class(hum, Ps)
    Pt = Ps[~np.array(["Arm" in c or "Hand" in c for c in cls])]
    web, hw = bmesh.new(), bmesh.new()
    uw, uh = web.loops.layers.uv.new("UVMap"), hw.loops.layers.uv.new("UVMap")
    allp = np.concatenate([Pt, Pl])
    for z in (G["lj_zb"] + m(0.07), J["neck"][2] - m(0.3)):
        c = torso_sec(hum, G, z)[0]
        pts, nr = surf_ring(allp, c, np.array([0, 0, 1.0]), np.array([0, -1.0, 0]), 28, m(0.02), m(0.003), m(0.45))
        rib(web, uw, pts, nr, m(0.042), m(0.006))
        f = pts[np.argmin(pts[:, 1])]
        cyl(hw, uh, f + np.array([0, m(0.004), 0]), np.array([0, -1.0, 0]), np.array([0, 0, 1.0]), m(0.034), m(0.016), 0.01, 0.99, 4,
            rot=math.pi / 4)                            # square buckle, edges level (never a diamond)
    # crotch strap: front panel hem, down round the gusset, up to the back panel hem
    zb = G["lj_zb"]
    sel = (np.abs(Ps[:, 0]) < m(0.035)) & (Ps[:, 2] < zb + m(0.03)) & (Ps[:, 2] > G["cz"] - m(0.19))
    Q = Ps[sel]
    zc = 0.5 * (zb + Q[:, 2].min())
    yc = Q[:, 1].mean()
    near = Q[np.abs(Q[:, 2] - zb) < m(0.03)]
    t0 = math.atan2(zb - zc, near[:, 1].min() - yc)
    t1 = math.atan2(zb - zc, near[:, 1].max() - yc) + 2 * math.pi
    ang = np.arctan2(Q[:, 2] - zc, Q[:, 1] - yc) % (2 * math.pi)
    rad = np.hypot(Q[:, 1] - yc, Q[:, 2] - zc)
    ths = np.linspace(t0, t1, 30)
    r_ = []
    for th in ths:
        dif = np.abs((ang - th + math.pi) % (2 * math.pi) - math.pi)
        r_.append(rad[dif < 0.12].max() if (dif < 0.12).any() else np.nan)
    r_ = smooth1(fill_nan(r_), 1, 2) + m(0.006)
    P3 = np.stack([np.zeros_like(ths), yc + r_ * np.cos(ths), zc + r_ * np.sin(ths)], 1)
    nrm = np.stack([np.zeros_like(ths), np.cos(ths), np.sin(ths)], 1)
    up = np.array([0, 0, m(0.09)])
    P3 = np.concatenate([[P3[0] + up - nrm[0] * m(0.012)], P3, [P3[-1] + up - nrm[-1] * m(0.012)]])
    nrm = np.concatenate([[nrm[0]], nrm, [nrm[-1]]])
    rib(web, uw, P3, nrm, m(0.13), m(0.004))          # plain strap: no buckle or marker on the lower front
    # strobe (left chest, top of the front panel) and whistle (right)
    z = G["lj_zt"] - m(0.07)
    c, ru, rv, p = torso_sec(hum, G, z)
    u = (z - G["lj_zb"]) / (G["lj_zt"] - G["lj_zb"])
    att = {}
    for nm, t in (("strobe", 0.62), ("whistle", -0.62)):
        T = m(0.105) * (0.62 + 0.38 * math.sin(math.pi * u) ** 0.6) * (0.9 + 0.1 * math.cos(5.2 * t))
        n = sup_n(ru, rv, p, t)
        o = sup_pt(c, ru, rv, p, t) + n * T
        if nm == "strobe":
            att[nm] = cyl(hw, uh, o - n * m(0.006), n, np.array([0, 0, 1.0]), m(0.02), m(0.035), 0.01, 0.99, 14, True)
        else:
            sd = np.cross(n, np.array([0, 0, 1.0]))
            att[nm] = cyl(hw, uh, o + n * m(0.006) - sd * m(0.02), sd, n, m(0.009), m(0.05), 0.01, 0.99, 10)
    return bm_obj(web, "TMP_Web"), bm_obj(hw, "TMP_HW"), att


# ---------------------------------------------------------------- part finishing: UVs, region/kind, weights
def transfer_weights(hum, G, P, mode):
    """Base-rig weights onto the clothing: average of the nearest base-body vertices of the same limb class."""
    BV, BW = G["BV"], G["BW"]
    arml, armr = G["arm_l"], G["arm_r"]
    srcs = {0: arml + armr < 0.5, 1: arml >= 0.5, 2: armr >= 0.5}
    kds = {k: (kd_of(BV[v]), BW[v]) for k, v in srcs.items()}
    if mode == "auto":
        c = seg_class(hum, P)
        cl = np.where(np.isin(c, ["LeftUpperArm", "LeftLowerArm", "LeftHand"]), 1,
                      np.where(np.isin(c, ["RightUpperArm", "RightLowerArm", "RightHand"]), 2, 0))
    else:
        cl = np.zeros(len(P), int)
    W = np.zeros((len(P), len(BONES)))
    for i, p in enumerate(P):
        kd, bw = kds[cl[i]]
        res = kd.find_n(tuple(p), 6)
        ws = np.array([1.0 / (d + hum.m(0.01)) ** 2 for _, _, d in res])
        W[i] = (bw[[j for _, j, _ in res]] * ws[:, None]).sum(0) / ws.sum()
    order = np.argsort(-W, 1)
    mask = np.zeros_like(W, bool)
    np.put_along_axis(mask, order[:, :4], True, 1)
    W = np.where(mask & (W > 0.02), W, 0)
    return W / W.sum(1, keepdims=True)


def finish_part(hum, G, obj, region, kind, target, mode="auto", smooth=True):
    if target and H.tris(obj) > target:
        versions.decimate(obj, target)
    me = obj.data
    if "UVMap" not in me.uv_layers:
        me.uv_layers.new(name="UVMap")
    H.select_only(obj)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.002)
    bpy.ops.object.mode_set(mode='OBJECT')
    P, polys = arrays(obj)
    if callable(kind):
        kf = np.array([kind(P[list(f)].mean(0)) for f in polys], np.float32)
    else:
        kf = np.full(len(polys), float(kind), np.float32)
    for nm, vals in (("Region", np.full(len(polys), float(region), np.float32)), ("Kind", kf)):
        a = me.attributes.new(nm, 'FLOAT', 'FACE')
        a.data.foreach_set("value", vals)
    W = transfer_weights(hum, G, P, mode)
    for j, b in enumerate(BONES):
        vg = obj.vertex_groups.new(name=b)
        for i in np.nonzero(W[:, j] > 0)[0]:
            vg.add([int(i)], float(W[i, j]), 'REPLACE')
    arml = W[:, [BI[b] for b in ("LeftLowerArm", "LeftHand", "RightLowerArm", "RightHand")]].sum(1)
    for k, vals in (("EyeMask", np.zeros(len(P))), ("BDist", np.zeros(len(P))), ("ArmLow", arml)):
        H.point_attr(obj, k, vals)
    for p in me.polygons:
        p.use_smooth = smooth          # webbing is flat-shaded: a flat strap, never a rounded tube
    return obj


# ---------------------------------------------------------------- textures
def compose(hum, M):
    """All atlas maps (dry + wet): skin and hair as before, the gear by kind (fabric, bladder, rubber, webbing, tape)."""
    m = hum.m
    S = SIZE
    H.setup_cycles(4)

    def skin_sock(nb, idx):
        hc = H.skin_colour_tree(nb, hum, CFG, "Head")[idx]
        bc = H.skin_colour_tree(nb, hum, CFG, "Body")[idx]
        r = nb.attr("Region")
        hand = nb.math('MULTIPLY', nb.maprange(r, 0.5, 0.9), nb.maprange(r, 1.5, 1.1))
        return nb.mix(hand, hc, bc) if idx == 0 else nb.mixf(hand, hc, bc)
    col = H.emit_bake(M, lambda nb: skin_sock(nb, 0), S, "b_alb")
    rgh = H.emit_bake(M, lambda nb: skin_sock(nb, 1), S, "b_rgh")
    pos = H.emit_bake(M, lambda nb: nb.vmath('ADD', nb.vmath('MULTIPLY', nb.pos(), (1 / 6.0,) * 3), (0.5,) * 3), S, "b_pos")

    def data_sock(nb):
        c = nb.n("ShaderNodeCombineXYZ")
        nb.set(c.inputs[0], nb.math('MULTIPLY', nb.attr("Region"), 0.125))
        nb.set(c.inputs[1], nb.math('MULTIPLY', nb.attr("Kind"), 0.0625))
        nb.set(c.inputs[2], nb.attr("EyeMask"))
        return c.outputs[0]
    dat = H.emit_bake(M, data_sock, S, "b_dat")
    ao = ao_bake(M, S)[..., 0]
    print("[swimmer] bakes done")
    cov = dat[..., 0] > -0.5
    R = np.where(cov, np.rint(dat[..., 0] * 8), -1).astype(int)
    K = np.where(cov, np.rint(dat[..., 1] * 16), -1).astype(int)
    Pw = (pos[..., :3] - 0.5) * 6.0
    ao = np.where(cov, np.clip(ao, 0, 1), 1.0)
    rng = np.random.default_rng(11)
    alb = np.zeros((S, S, 3))
    alb_w = np.zeros((S, S, 3))
    rg = np.full((S, S), 0.5)
    rg_w = np.full((S, S), 0.3)
    hgt = np.zeros((S, S))
    fine = H.value_noise((S, S), 2, rng)
    mid = H.fbm((S, S), 48, rng, 3)
    sk = (R == HEAD) | (R == HAND)
    sk &= (K != K_SUIT)
    sc = H.lin_to_srgb(np.clip(col[..., :3], 0, 1))
    alb[sk] = sc[sk] * (0.8 + 0.2 * ao[sk, None])
    alb_w[sk] = alb[sk] * 0.95
    rg[sk] = np.clip(rgh[sk, 0], 0.12, 1.0)
    drops = (H.value_noise((S, S), 3, rng) > 0.78)
    rg_w[sk] = np.clip(rgh[sk, 0] * 0.5 - 0.06 * drops[sk], 0.08, 1.0)
    signal = np.zeros((S, S), np.uint8)
    J = hum.J
    for k, c in PAL.items():
        sel = K == k
        if not sel.any():
            continue
        q = Pw[sel]
        base = np.array(c, float) / 255.0
        cc = np.tile(base, (sel.sum(), 1))
        if k == K_LJ:      # retro tape: two bands across the front panel top, a strip along the collar top
            tape = (np.abs(q[:, 2] - (J["neck"][2] - m(0.12))) < m(0.022)) & (q[:, 1] < 0)
            tape |= q[:, 2] > J["neck"][2] + m(0.075)
            cc[tape] = np.array(PAL[K_TAPE]) / 255.0
            signal[sel] = 255
        if k == K_TAPE:
            signal[sel] = 255
        ht = 0.25 * fine[sel] + 0.3 * (mid[sel] - 0.5)
        if k == K_SOLE:
            ht += 0.6 * (np.sin(q[:, 1] / m(0.012) * math.pi) > 0.2)
        if k in (K_WEB, K_CUFF):
            ht += 0.3 * (np.sin(q[:, 2] / m(0.003) * math.pi + q[:, 0] / m(0.003)) > 0)
        cc = cc * (0.93 + 0.12 * mid[sel, None]) * (0.6 + 0.4 * ao[sel, None])
        salt = np.clip((mid[sel] - 0.55) * 4, 0, 1) * (1 - ao[sel]) * 0.4 * (k in (K_SUIT, K_BOOT, K_LJ))
        alb[sel] = cc * (1 - salt[:, None] * 0.35) + np.array([150, 150, 148]) / 255.0 * salt[:, None] * 0.35
        alb_w[sel] = cc * (0.8 if k != K_TAPE else 0.95)
        r0 = RGH[k] + 0.08 * (mid[sel] - 0.5)
        rg[sel] = r0
        rg_w[sel] = np.clip(r0 * 0.5, 0.12, 1)
        hgt[sel] = ht
    hr = R == HAIR
    if hr.any():
        phi, polar = hair_coords(hum, Pw[hr])
        cl = hair_clump(hum, Pw[hr])
        w = phi + 0.06 * np.sin(polar * 7.0 + 1.3)
        fs = np.zeros(len(w))
        for f, ph in ((140, 0.3), (230, 1.9), (370, 4.1), (610, 2.2)):
            fs += np.sin(w * f + ph + 0.4 * np.sin(polar * 31)) * (140.0 / f)
        fs = 0.5 + 0.25 * fs
        hc = H.lin_to_srgb(np.array(H.hex_lin(CFG["hair"])))
        c = hc[None, :] * (0.78 + 0.35 * fs[:, None]) * (0.85 + 0.3 * cl[:, None]) * (0.75 + 0.25 * ao[hr, None])
        alb[hr] = c
        alb_w[hr] = c * 0.82
        rg[hr] = 0.48 - 0.08 * cl
        rg_w[hr] = 0.2 + 0.12 * (1 - cl) - 0.05 * fs
        hgt[hr] = 0.8 * cl + 0.35 * fs
    o = H.normal_from_height(hgt[::-1], 1.6).astype(np.float32) / 255.0
    o[~cov] = np.array([0.5, 0.5, 1.0])
    lo, hi = 31 / 255.0, 239 / 255.0
    maps = {"ALB": H.u8(np.clip(alb, lo, hi)), "NOR": H.u8(o), "RGH": H.u8(np.clip(rg, 0.06, 1)), "MET": np.zeros((S, S), np.uint8)}
    wet = {"ALB": H.u8(np.clip(alb_w, lo, hi)), "NOR": maps["NOR"], "RGH": H.u8(np.clip(rg_w, 0.05, 1)), "MET": maps["MET"]}
    H.write_set(ASSET, TNAME, SETN, maps)
    H.write_set(ASSET, TNAME, SETN, {k + "_Wet": v for k, v in wet.items()})
    H.write_png(os.path.join(HERE, "textures", "mask_%s_signal.png" % SETN), signal)


# ---------------------------------------------------------------- the whole build
def smooth_head(skin):
    """Soften over-sharp detail on the face and neck (volume-preserving Laplacian; eyes and open borders pinned)."""
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    rl = bm.faces.layers.float.get("Region")
    el = bm.verts.layers.float.get("EyeMask")
    vs = [v for v in bm.verts if not v.is_boundary and (el is None or v[el] < 0.5)
          and v.link_faces and all(int(round(f[rl])) == HEAD for f in v.link_faces)]
    for _ in range(2):
        bmesh.ops.smooth_laplacian_vert(bm, verts=vs, lambda_factor=0.25, lambda_border=0.0,
                                        use_x=True, use_y=True, use_z=True, preserve_volume=True)
    bm.to_mesh(skin.data)
    bm.free()
    print("[swimmer] head: smoothed %d face/neck verts" % len(vs))


def build():
    for o in list(bpy.data.objects):
        if o.name.startswith(("M_Chr_", "RIG_", "ATT_", "TMP_")):
            bpy.data.objects.remove(o, do_unlink=True)
    import versions
    globals()["versions"] = versions
    hum = H.Human(CFG["gender"], CFG["height_m"], ARM_DOWN)
    m = hum.m
    G = measure(hum)
    # skin: head, neck (inside the collar) and hands only; every other body face is deleted
    body_faces = hum.groups["body"]
    eye_faces = hum.groups["helper-l-eye"] + hum.groups["helper-r-eye"]
    full = H.mesh_from_faces("TMP_Full", hum, body_faces + eye_faces)
    eyeset = {v for n in eye_faces for v in hum.faces[n][1]}
    used = sorted({v for n in body_faces + eye_faces for v in hum.faces[n][1]})
    H.point_attr(full, "EyeMask", [1.0 if v in eyeset else 0.0 for v in used])
    skin, freg, info = process(full, "TMP_Skin", hum)
    bpy.data.objects.remove(full, do_unlink=True)
    hands = H.copy_obj(skin, "TMP_Hands")
    H.keep_faces(hands, list(freg == HAND))
    H.keep_faces(skin, list((freg != SUIT) & (freg != HAND)))      # face and neck (+ hair shell) only
    versions.decimate(skin, TRIS["skin"], 'X')
    smooth_head(skin)
    reg = np.zeros(len(skin.data.polygons), np.float32)
    skin.data.attributes["Region"].data.foreach_get("value", reg)
    a = skin.data.attributes.new("Kind", 'FLOAT', 'FACE')
    a.data.foreach_set("value", reg)
    # drysuit: one closed hollow shell
    pieces, limbs, hemz = suit_pieces(hum, G)
    suit = join(pieces, "TMP_Suit")
    remesh(suit, m(0.012), 4, 0.5)
    add_folds(hum, G, suit, limbs, hemz)
    versions.decimate(suit, TRIS["suit"])
    trims = suit_trims(hum, G, suit, limbs, hemz)
    gloves = build_gloves(hum, G, hands, limbs)
    boots = build_boots(hum, G)
    lj = build_lifejacket(hum, G)
    versions.decimate(lj, TRIS["lj"])
    web, hw, att = lj_trims(hum, G, suit, lj)
    parts = [finish_part(hum, G, suit, SUIT, K_SUIT, None),
             finish_part(hum, G, boots, SUIT, lambda c: K_SOLE if c[2] < m(0.009) else K_BOOT, TRIS["boots"], "torso")]
    parts += [finish_part(hum, G, o, SUIT, k, None) for k, o in trims.items()]
    parts.append(finish_part(hum, G, gloves, SUIT, K_CUFF, TRIS["gloves"]))     # neoprene: R15 hand weights
    parts += [finish_part(hum, G, lj, LJ, K_LJ, None, "torso"), finish_part(hum, G, web, LJ, K_WEB, None, "torso", False),
              finish_part(hum, G, hw, LJ, K_HW, None, "torso")]
    M = join([skin] + parts, ASSET + "_LOD0")
    reg = np.zeros(len(M.data.polygons), np.float32)
    M.data.attributes["Region"].data.foreach_get("value", reg)
    freg = np.rint(reg).astype(int)
    for r in (HEAD, HAND, SUIT, HAIR, LJ):
        pack_region(M, freg, r)
    H.set_material(M, "MAT_" + SETN)
    Pm, _ = arrays(M)
    bad = ~np.isfinite(Pm).all(1)
    if bad.any():
        bm = bmesh.new()
        bm.from_mesh(M.data)
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(bad)[0]], context='VERTS')
        bm.to_mesh(M.data)
        bm.free()
        print("[swimmer] WARNING removed %d non-finite vertices" % bad.sum())
    print("[swimmer] LOD0 before the budget check: %d tris" % H.tris(M))
    if H.tris(M) > 20000:
        versions.decimate(M, 20000)
    if not os.environ.get("SWIMMER_FAST"):
        compose(hum, M)
    for k in ("BDist", "ArmLow", "EyeMask", "Region", "Kind"):
        if k in M.data.attributes:
            M.data.attributes.remove(M.data.attributes[k])
    V = np.array([v.co[:] for v in M.data.vertices])
    shift = np.array([(V[:, 0].min() + V[:, 0].max()) / 2, (V[:, 1].min() + V[:, 1].max()) / 2, V[:, 2].min()])
    M.data.transform(mathutils.Matrix.Translation(tuple(-shift)))
    for b in hum.seg:
        hum.seg[b] = (hum.seg[b][0] - shift, hum.seg[b][1] - shift)
    atts = []
    for nm, p in (("ATT_Strobe", att["strobe"]), ("ATT_Whistle", att["whistle"])):
        e = H.link(bpy.data.objects.new(nm, None))
        e.location = mathutils.Vector(tuple(np.array(p[:]) - shift))
        e.empty_display_size = 0.1
        atts.append(e)
    rig = H.build_rig(hum, [M])
    bpy.context.view_layer.update()
    for e in atts:
        mw = mathutils.Matrix.Translation(e.location)
        e.parent = rig
        e.parent_type = 'BONE'
        e.parent_bone = "UpperTorso"
        bpy.context.view_layer.update()
        e.matrix_world = mw
    total = H.tris(M)
    print("[swimmer] %s %d tris; skin %s" % (M.name, total, info))
    return {
        "asset": ASSET, "name": ASSET, "budget": "npc_person", "tris": 20000, "tier": "hero",
        "dims_m": (None, None, CFG["height_m"]), "size_note": "height includes the sea-boot soles", "origin": "base",
        "species": "human",
        # docs/06 2.1a: the loose drysuit, sea boots and lifejacket are real geometry merged into this one mesh; the only
        # body geometry kept is the skin of the face and neck (gloved hands) (no body shell under the clothing, no anatomy).
        "clothing_merged": True,
        "sets": [{"name": TNAME, "set": SETN, "size": SIZE, "wet": True}],
        "meshes": [{"object": M, "set": SETN}],
        "attachments": atts,
        "waivers": {
            "per-MeshPart triangles": "docs/06 2.1a: clothing merged into ONE mesh per LOD (moderation rule), so LOD0 is "
                                      "one MeshPart at the docs/12 2.9 row's 20,000 (Roblox cap about 20,000)",
            "texture sets": "one MeshPart takes one SurfaceAppearance: the 2 sets + lifejacket (+ hair) of the docs/12 2.9 "
                            "row are packed into one 2048 atlas (same memory as four 1024 sets)",
            "LOD UV layout": "organic LOD2 decimation moves UV island borders slightly; same atlas, same layout",
            "geometry": "the eyes and mouth keep MakeHuman's open edges; the skin openings at the collar and cuffs end "
                        "inside the closed clothing shells; decimated LODs may leave loose verts"},
    }
