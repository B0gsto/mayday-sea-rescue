"""M_Veh_PirateBoat: toy-brick pirate boat, built part by part from the owner-cleared "Pirate Boat Concept" (its spec.json,
kept here as concept_spec.json: name, shape, pos, size, rot of every part; +X bow, Y up, +Z starboard, water y = 0).

Crew and jet ski parts are skipped (M_Chr_Pirate* are their own assets), and so is the concept's wheel: the crew concept
gives the captain his own wheel with the macaw. Scaled SCALE to about 26 studs long (the task's size). Origin = pivot on
the waterline, bow -Y (Roblox -Z). Layers: _Body, _Castle, _Rig (one MeshPart stays under 10k), _Lights (glowing parts, separate so the game can set them Neon). No guns.

    python3 art/source/vessels/M_Veh_PirateBoat/maketex.py --out build/prod/M_Veh_PirateBoat/textures/M_Veh_PirateBoat
    MCP: run.py -- --build art/source/vessels/M_Veh_PirateBoat/build.py --out-root build/prod/M_Veh_PirateBoat \
         --steps build,validate,export,turntable

LODs are authored here, not by the `lod` step: the collapse decimator cannot go below one shell per part (500+ parts).
"""
import importlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.modules.pop("kit", None)
kit = importlib.import_module("kit")
P = kit.P
RB = kit.RB

NAME = "M_Veh_PirateBoat"
SCALE = 0.875
SEAM, SEAM_Y = 0.05, 0.04
SKIP_GROUPS = ("crew", "jetski")
# crew feet in concept coordinates, raised on the plinths from adjust() so they clear the bulwark and read against sky and sail
CREW = {"ATT_Captain": (-7.4, 8.4, -0.85), "ATT_Deckhand": (6.9, 8.6, 0.0), "ATT_Lookout": (-2.8, 6.4, -1.6)}


def wanted(p):
    return p["group"] not in SKIP_GROUPS and not p["name"].startswith("wheel-")


def sides(d, base=6):
    return 4 if d < 0.2 else base if d < 0.6 else 8 if d < 1.3 else 12


# Every shape is local (a, b, c) = three (x, -z, y): lego.box chamfers and kit.lathe spin round c, the concept's height.
def box(b, s, bevel=0.07):
    w, h, d = s[0] - min(SEAM, s[0] * 0.2), s[1] - min(SEAM_Y, s[1] * 0.2), s[2] - min(SEAM, s[2] * 0.2)
    bev = bevel if min(w, h, d) >= 0.25 else 0
    b.box((-w / 2, -d / 2, -h / 2), (w / 2, d / 2, h / 2), b.col, bevel=bev)


def wedge(b, p):
    t, n, s = p["size"]
    d2 = p["d2"]
    t, n = t - SEAM, n - SEAM_Y
    bot = [(-t / 2, -s / 2), (t / 2, -d2 / 2), (t / 2, d2 / 2), (-t / 2, s / 2)]
    i = 0.05
    top = [(-t / 2 + i, -s / 2 + i), (t / 2 - i, -d2 / 2 + i), (t / 2 - i, d2 / 2 - i), (-t / 2 + i, s / 2 - i)]
    verts = [(x, y, -n / 2) for x, y in bot] + [(x, y, n / 2) for x, y in top]
    b._emit(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], b.col)


def ringarc(b, p):
    t, n, _ = p["size"]
    r1, r0 = t / 2 - SEAM / 2, p["inner"] + SEAM / 2
    a0, arc = p["arc"]
    k = 4 - getattr(b, "lod", 0)
    verts = []
    n_ = n - SEAM_Y
    for i in range(k + 1):
        q = math.radians(a0 + 1.5 + (arc - 3) * i / k)   # concept: x = r cos, three z = -r sin, so b = r sin
        for r, z in ((r1, -n_ / 2), (r0, -n_ / 2), (r0, n_ / 2), (r1, n_ / 2)):
            verts.append((r * math.cos(q), r * math.sin(q), z))
    faces = []
    for i in range(k):
        A, B = i * 4, (i + 1) * 4
        for j in range(4):
            m = (j + 1) % 4
            faces.append((A + j, B + j, B + m, A + m))
    faces += [(0, 3, 2, 1), (k * 4, k * 4 + 1, k * 4 + 2, k * 4 + 3)]
    b._emit(verts, faces, b.col)


def poly(b, p):
    t, n, s = p["size"]
    pts = [(x * (t - SEAM), y * (n - SEAM_Y)) for x, y in p["pts"]]
    w = (s - SEAM) / 2
    m = len(pts)
    verts = [(x, -w, y) for x, y in pts] + [(x, w, y) for x, y in pts]
    faces = [tuple(range(m)), tuple(reversed(range(m, 2 * m)))]
    faces += [(i, (i + 1) % m, m + (i + 1) % m, m + i) for i in range(m)]
    b._emit(verts, faces, b.col)


def torus(b, p):
    t, _, s = p["size"]
    R, r = t / 2 - s / 2, s / 2
    arc = p.get("arc", 360)
    maj = (10 if R > 0.5 else 8) * max(1, round(arc / 360)) if arc >= 360 else max(2, round(arc / 40))
    mnr = 3 if s < 0.25 or getattr(b, "lod", 0) else 4
    closed = arc >= 360
    verts = []
    # three torus: in the x-y plane, axis z; local (a, c) plane, axis b
    for i in range(maj + (0 if closed else 1)):
        q = math.radians(arc * i / maj)
        for j in range(mnr):
            v = 2 * math.pi * (j + 0.5) / mnr
            rr = R + r * math.cos(v)
            verts.append((rr * math.cos(q), -r * math.sin(v), rr * math.sin(q)))
    faces = []
    n_seg = maj if closed else maj
    for i in range(n_seg):
        A, B = i * mnr, ((i + 1) % maj if closed else i + 1) * mnr
        for j in range(mnr):
            m = (j + 1) % mnr
            faces.append((A + j, B + j, B + m, A + m))
    if not closed:
        faces += [tuple(range(mnr)), tuple(range(maj * mnr, (maj + 1) * mnr))]
    b._emit(verts, faces, b.col)


def round_shape(b, p):
    """cyl, rod, cone, sphere, dome, barrel, bell: lathes with the concept's profile, scaled to size."""
    sh, (t, n, s) = p["shape"], p["size"]
    if sh in ("cyl", "rod"):
        h = n - min(SEAM_Y, n * 0.2) if sh == "cyl" else n
        r0, r1 = t / 2 * p.get("bot", 1), t / 2 * p.get("top", 1)
        prof, seg = [(max(r0, 0), -h / 2), (max(r1, 0), h / 2)], p.get("seg") or sides(t)
        if r0 <= 1e-3:
            prof[0] = (0, -h / 2)
        if r1 <= 1e-3:
            prof[1] = (0, h / 2)
    elif sh == "cone":
        prof, seg = [(0.5, -0.5), (0, 0.5)], p.get("seg") or 6
    elif sh == "sphere":
        c = math.sqrt(0.5) * 0.5
        prof, seg = [(0, -0.5), (c, -c), (0.5, 0), (c, c), (0, 0.5)], 6 if t < 0.5 else 8
    elif sh == "dome":
        prof, seg = [(0.5, -0.5), (0.43, 0.0), (0.25, 0.37), (0, 0.5)], 8
    elif sh == "barrel":
        h, a = n - SEAM_Y, t / 2 - 0.02
        c = a * 0.86
        prof, seg = [(0, -h / 2), (c, -h / 2), (a * 0.96, -h / 4), (a, 0), (a * 0.96, h / 4), (c, h / 2), (0, h / 2)], 8
    else:                                       # bell
        prof, seg = [(0, -n / 2 + 0.12), (t * 0.5, -n / 2), (t * 0.36, -n * 0.3), (t * 0.27, 0), (t * 0.2, n / 2), (0, n / 2)], 8
    if sh in ("cone", "sphere", "dome"):
        prof = [(r * t, z * n) for r, z in prof]
    with b.at(_scale_ab(1.0, (s / t) if sh in ("cone", "sphere", "dome") else 1.0)):
        if "eye" in p["name"] or "pupil" in p["name"]:
            seg = 16                            # the shark's eyes are its read: keep them round
        seg = max(3, seg - 2 * getattr(b, "lod", 0))
        b.lathe(0, 0, prof, b.col, n=seg, start=math.pi / seg if seg == 4 else 0.0)


def _scale_ab(a, bb):
    import mathutils
    return mathutils.Matrix.Diagonal((a, bb, 1.0, 1.0))


def halfcyl(b, p):
    t, n, s = p["size"]
    k = 5
    w, h, d = (t - SEAM) / 2, (n - SEAM_Y) * 2, (s - SEAM) / 2
    arc = [(-d * math.cos(math.pi * i / k), h * math.sin(math.pi * i / k) - n / 2 + 0.0) for i in range(k + 1)]
    b.prof_x(-w, w, arc, b.col)


def sail(b, p):
    """Horizontal red and cream bands, one patch; full billow, arched foot, waisted leeches (round 2: never a flat plane)."""
    t, n, s = p["size"]
    t = t * 1.45
    lod = getattr(b, "lod", 0)
    bands = 9 if s > 15 else 5
    rows = bands * (2 if lod == 0 else 1)
    cols = 10 - 3 * lod
    red, cream = P.cell("#C8102E", "cloth"), P.CREAM

    def pt(i, j, off):
        l, h = i / cols, 1 - j / rows            # j = 0 at the head
        u = 1 - (2 * l - 1) ** 2
        wide = s * (1 - 0.07 * math.sin(math.pi * h))
        arch = 0.09 * n * u * (1 - h) ** 2
        return (t * u ** 0.8 * math.sin(0.65 * math.pi * (1 - h)) + off, (l - 0.5) * wide, (h - 0.5) * n + arch)

    vid = lambda i, j, side: (j * (cols + 1) + i) * 2 + side
    verts, faces, cc = [], [], []
    for j in range(rows + 1):
        for i in range(cols + 1):
            verts += [pt(i, j, 0.05), pt(i, j, -0.05)]
    band = lambda j: j * bands // rows
    for j in range(rows):
        for i in range(cols):
            c = red if band(j) % 2 == 0 else cream
            if bands == 9 and band(j) == 5 and i == cols - 3:
                c = P.TAN                          # the sewn patch
            faces += [(vid(i, j, 0), vid(i + 1, j, 0), vid(i + 1, j + 1, 0), vid(i, j + 1, 0)),
                      (vid(i, j, 1), vid(i, j + 1, 1), vid(i + 1, j + 1, 1), vid(i + 1, j, 1))]
            cc += [c, c]
    for i in range(cols):
        for j in (0, rows):
            faces.append((vid(i, j, 0), vid(i + 1, j, 0), vid(i + 1, j, 1), vid(i, j, 1)))
            cc.append(red)
    for j in range(rows):
        c = red if band(j) % 2 == 0 else cream
        for i in (0, cols):
            faces.append((vid(i, j, 0), vid(i, j + 1, 0), vid(i, j + 1, 1), vid(i, j, 1)))
            cc.append(c)
    b._emit(verts, faces, cc)


def flag(b, p):
    t, n, s = p["size"]
    m = 8
    verts = []
    for i in range(m + 1):
        c = i / m
        x, w, sag = (c - 0.5) * t, s * math.sin(c * math.pi * 2.2 + 0.4) * c, 0.18 * c * c
        # three z = wave, so local b = -wave; port and starboard skins
        verts += [(x, -w + 0.03, -n / 2 - sag), (x, -w + 0.03, n / 2 - sag), (x, -w - 0.03, -n / 2 - sag), (x, -w - 0.03, n / 2 - sag)]
    start = len(b.f)
    faces = []
    for i in range(m):
        A = i * 4
        faces += [(A + 4, A, A + 1, A + 5), (A + 2, A + 6, A + 7, A + 3)]
    for i in range(m):
        A = i * 4
        faces += [(A, A + 2, A + 6, A + 4), (A + 1, A + 5, A + 7, A + 3)]
    faces += [(0, 1, 3, 2), (m * 4, m * 4 + 2, m * 4 + 3, m * 4 + 1)]
    b._emit(verts, faces, P.BLACK)
    u0, v0, u1, v1 = P.uv_rect(P.FLAG)
    lerp = lambda q: u0 + (u1 - u0) * q
    for i in range(m):
        qa, qc = i / m, (i + 1) / m
        b.uv_quad(start + i * 2, ((lerp(1 - qc), v0), (lerp(1 - qa), v0), (lerp(1 - qa), v1), (lerp(1 - qc), v1)))
        b.uv_quad(start + i * 2 + 1, ((lerp(qa), v0), (lerp(qc), v0), (lerp(qc), v1), (lerp(qa), v1)))


def part_matrix(p):
    import mathutils
    T = mathutils.Matrix.Translation(p["pos"])
    rx, ry, rz = (math.radians(a) for a in p["rot"])
    R = mathutils.Matrix.Rotation(ry, 4, "Y") @ mathutils.Matrix.Rotation(rx, 4, "X") @ mathutils.Matrix.Rotation(rz, 4, "Z")
    return T @ R @ LOCAL()


def LOCAL():
    import mathutils
    return mathutils.Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))    # local (a, b, c) -> three (a, c, -b)


def to_blender():
    import mathutils
    # three -> Blender: bx = -z, by = -x, bz = y, then the size scale
    C = mathutils.Matrix(((0, 0, -1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    return mathutils.Matrix.Scale(SCALE, 4) @ C


def aabb(p, M):
    import mathutils
    t, n, s = p["size"]
    if p["shape"] == "wedge":
        s = max(s, p["d2"])
    pts = [M @ mathutils.Vector((x, y, z)) for x in (-t / 2, t / 2) for y in (-s / 2, s / 2) for z in (-n / 2, n / 2)]
    return [min(v[i] for v in pts) for i in range(3)], [max(v[i] for v in pts) for i in range(3)]


def studs(b, p, boxes, me):
    """Concept rule: a stud per grid cell on exposed tops only (nothing sits on it within 0.4)."""
    import mathutils
    if not p.get("studs"):
        return 0
    t, n, s = p["size"]
    wide = max(s, p["d2"]) if p["shape"] == "wedge" else s
    nx, nz = int(t + 0.01), int(wide + 0.01)
    M = part_matrix(p)
    cnt = 0
    top = n / 2 - min(SEAM_Y, n * 0.2) / 2
    for i in range(nx):
        for j in range(nz):
            h, u = i - (nx - 1) / 2, j - (nz - 1) / 2
            if p["shape"] == "wedge" and abs(u) > (s + (p["d2"] - s) * (h / t + 0.5)) / 2 - 0.45:
                continue
            w = M @ mathutils.Vector((h, -u, top + 0.12))
            if any(lo[1] > w[1] - 0.4 and all(lo[a] <= w[a] <= hi[a] for a in range(3))
                   for k, (lo, hi) in enumerate(boxes) if k != me):
                continue
            with b.at(mathutils.Matrix.Translation((h, -u, top - 0.03))):
                b.lathe(0, 0, [(0.3, 0), (0.3, 0.2), (0.21, 0.26), (0, 0.26)], b.col, n=6)
            cnt += 1
    return cnt


def part(name, shape, pos, size, color, group="bow-ram", rot=(0, 0, 0), **kw):
    return dict(name=name, shape=shape, group=group, pos=list(pos), size=list(size), rot=list(rot), color=color, material=kw.pop("material", "abs"), **kw)


SLOPE = [[-0.5, -0.5], [0.5, -0.5], [0.5, -0.25], [-0.2, 0.5], [-0.5, 0.5]]


def shark():
    """Art director round 2: about 1.5x the concept's head, hull-wide gaping jaw, big blunt teeth, angry eyes. Bow tip at x 17.6."""
    S, D = P.SLATE, P.SLATE_DARK
    out = [
        part("shark-jaw-lower", "wedge", (13, 0.55, 0), (9, 1.7, 8.6), S, d2=4.2),
        part("shark-mouth", "wedge", (12.7, 1.45, 0), (7.6, 0.24, 7.2), P.MOUTH, d2=3.3),
        part("shark-tongue", "box", (13.2, 1.75, 0), (3.8, 0.42, 2.8), P.TONGUE),
        part("shark-cheek", "wedge", (9.6, 3, 0), (2.4, 3.6, 8.8), S, d2=8),
        part("shark-throat", "box", (11, 3, 0), (0.5, 3.2, 6.2), P.THROAT),
        part("shark-palate", "wedge", (13.6, 4.45, 0), (7.2, 0.25, 7.2), P.PALATE, d2=3.5),
        part("shark-snout", "wedge", (13, 5.2, 0), (9.2, 1.3, 8.8), S, d2=4),
        part("shark-head", "wedge", (12, 6.75, 0), (7.2, 1.8, 8.8), S, d2=5),
        part("shark-crown", "wedge", (10.8, 8.6, 0), (4.8, 2, 8.4), S, d2=5.4, studs=True),
        part("shark-nose", "poly", (16.4, 6.45, 0), (2.4, 1.8, 3.6), S, pts=SLOPE),
        part("shark-brow-slope", "poly", (14, 8.6, 0), (1.6, 2, 5.2), S, pts=SLOPE),
        part("shark-fin", "poly", (10, 11, 0), (3, 3, 0.7), S, pts=[[-0.5, -0.5], [0.5, -0.5], [0.15, -0.05], [-0.2, 0.3], [-0.5, 0.5], [-0.38, 0]]),
    ]
    for s in (1, -1):
        yaw, ox, oz = s * 18, 0.31, s * 0.95       # proud of the head, turned a little forward so it reads from the bow too
        cx, cy, cz = 12.9, 7.5, s * 3.32
        at = lambda out_, along, up: (cx + ox * out_ + 0.95 * along, cy + up, cz + oz * out_ - s * 0.31 * along)
        rot = (90, yaw, 0)
        k = "01" if s < 0 else "02"
        out += [
            part("shark-eye-" + k, "cyl", at(0, 0, 0), (3, 0.3, 3), "#F4F4F0", rot=rot),
            part("shark-pupil-" + k, "cyl", at(0.18, 0.45, -0.25), (1.5, 0.16, 1.5), "#1C1C20", rot=rot),
            part("shark-eye-glint-" + k, "cyl", at(0.28, 0.7, 0.05), (0.42, 0.1, 0.42), "#F4F4F0", rot=rot),
            part("shark-brow-" + k, "box", at(0.42, 0.1, 1.1), (3.7, 0.75, 0.8), D, rot=(0, yaw, -28)),
        ]
        for i, x in enumerate((9.4, 10.1, 10.8)):
            hw = 4.4 - 1.9 * (x - 8.4) / 7.2
            out.append(part("shark-gill-%s%d" % (k, i), "box", (x, 6.3, s * hw), (0.24, 2, 0.2), D, rot=(0, s * 13, 0)))
    for s in (1, -1):                              # big, blunt, few: 5 a side up, 4 a side down, staggered
        for i, x in enumerate((11.5, 13.2, 14.9, 16.6)):
            hw = 4.4 - 2.4 * (x - 8.4) / 9.2 - 0.42
            out.append(part("shark-tooth-u%d%d" % (s > 0, i), "cone", (x, 3.7, s * hw), (1.05, 1.7, 0.8), "#FFFFFF", rot=(180, 45, 0), seg=4))
        out.append(part("shark-tooth-uf%d" % (s > 0), "cone", (17.25, 3.7, s * 0.95), (1, 1.7, 0.8), "#FFFFFF", rot=(180, 45, 0), seg=4))
        for i, x in enumerate((12.3, 14, 15.7)):
            hw = 4.3 - 2.2 * (x - 8.5) / 9 - 0.42
            out.append(part("shark-tooth-l%d%d" % (s > 0, i), "cone", (x, 2.2, s * hw), (1, 1.6, 0.8), "#FFFFFF", rot=(0, 45, 0), seg=4))
        out.append(part("shark-tooth-lf%d" % (s > 0), "cone", (16.9, 2.2, s * 0.9), (0.95, 1.6, 0.8), "#FFFFFF", rot=(0, 45, 0), seg=4))
    return out


def gunwale():
    """Clean sheer: one continuous bulwark with a tan cap, rising to the forecastle; replaces the concept's stepped blocks."""
    hull, cap, g = "#7A4A2A", "#D2AE76", "deck"
    out = []
    for s in (1, -1):
        k = "01" if s < 0 else "02"
        out += [
            part("bulwark-" + k, "box", (-1, 5.5, s * 4.5), (8, 1.4, 1), hull, group=g),
            part("bulwark-cap-" + k, "box", (-1, 6.35, s * 4.5), (8.2, 0.3, 1.16), cap, group=g),
            part("bulwark-rise-" + k, "poly", (3.8, 6.4, s * 4.5), (1.6, 3.2, 1), hull, group=g,
                 pts=[[-0.5, -0.5], [0.5, -0.5], [0.5, 0.5], [-0.5, -0.06]]),
            part("bulwark-rise-cap-" + k, "box", (3.8, 7.2, s * 4.5), (2.3, 0.3, 1.16), cap, group=g, rot=(0, 0, 46)),
            part("fc-wall-" + k, "box", (5.33, 7.8, s * 3.98), (3.08, 1.2, 1), hull, group="forecastle", rot=(0, s * 20, 0)),
            part("fc-wall-cap-" + k, "box", (5.33, 8.55, s * 3.98), (3.2, 0.3, 1.16), cap, group="forecastle", rot=(0, s * 20, 0)),
            part("fc-wall-bow-" + k, "box", (8.25, 7.8, s * 2.62), (3.33, 1.2, 1), hull, group="forecastle", rot=(0, s * 29, 0)),
            part("fc-wall-bow-cap-" + k, "box", (8.25, 8.55, s * 2.62), (3.45, 0.3, 1.16), cap, group="forecastle", rot=(0, s * 29, 0)),
        ]
    return out


def adjust(parts):
    """Art director round 1 fixes over the concept spec."""
    drop = ("bulwark", "fc-wall", "fc-bow-tip")
    out = []
    for p in parts:
        if p["group"] == "bow-ram" or p["name"].startswith(drop):
            continue
        if p["name"].startswith("hull-L4"):
            p = dict(p, studs=False)               # no studs along the hull's top edge: a clean line under the cap
        out.append(p)
    out += shark() + gunwale()
    # plinths: the crew stand clear of the bulwark
    out.append(part("helm-dais", "box", (-7.4, 8, -0.3), (4, 0.8, 7), P.DAIS, group="stern-castle", studs=True))
    out.append(part("bow-crate", "box", (6.9, 8.1, 0), (2.8, 1, 3), "#7A4A2A", group="forecastle", studs=True))
    out.append(part("deck-hatch", "box", (-2.8, 5.8, -1.6), (2.8, 1.2, 2.4), "#7A4A2A", group="deck", studs=True))
    return out


LAYER = {"stern-castle": "Castle", "mast": "Rig", "crows-nest": "Rig", "sail": "Rig", "flag": "Rig", "rigging": "Rig"}


def keep(p, lod):
    """LOD1 drops small trim, LOD2 keeps the silhouette: hull, deck, castle shell, shark, mast, sails, flag, windows."""
    big = max(p["size"])
    if lod == 0:
        return True
    if p["name"].startswith(("shark-eye", "shark-pupil", "shark-brow")):
        return lod < 2 or "glint" not in p["name"]
    if lod == 2 and p["name"].startswith("hull-L0"):
        return False                               # below the waterline
    if p["material"] == "glow" or "tooth" in p["name"] or p["group"] in ("sail", "flag", "mast"):
        return lod == 1 or big > 3.0 or p["material"] == "glow" and big > 0.8 or "tooth" in p["name"] and big >= 0.5
    if lod == 1:
        return big >= 0.5 and not (p["shape"] == "rod" and big < 3)
    return big >= 4.3 and p["shape"] != "rod" and "nest-rim" not in p["name"]


def build_lod(lod, parts, spec, W, mat, boxes):
    layers = {k: RB(W) for k in ("Body", "Castle", "Rig", "Lights")}
    for rb in layers.values():
        rb.lod = lod
    fn = {"wedge": wedge, "ringarc": ringarc, "poly": poly, "torus": torus, "halfcyl": halfcyl, "sail": sail, "flag": flag}
    n_studs = 0
    for k, p in enumerate(parts):
        if not keep(p, lod):
            continue
        b = layers["Lights" if p["material"] in ("glow", "trans") else LAYER.get(p["group"], "Body")]
        b.col = P.cell(p["color"], p["material"])
        with b.at(part_matrix(p)):
            if p["shape"] == "box":
                box(b, p["size"], bevel=0.07 if lod == 0 else 0)
            elif p["shape"] in fn:
                fn[p["shape"]](b, p)
            else:
                round_shape(b, p)
            if lod == 0:
                n_studs += studs(b, p, boxes, k)
    out = []
    for key, rb in layers.items():
        suffix = "_" + key
        name = NAME + suffix + "_LOD%d" % lod
        e = {"object": rb.to_object(name, mat), "set": kit.SET, "role": "visual", "lod": "LOD%d" % lod}
        if lod:
            e["of"] = NAME + suffix + "_LOD0"
        out.append(e)
        print("[boat] %-28s %5d tris" % (name, rb.tris()))
    print("[boat] LOD%d studs %d" % (lod, n_studs))
    return out


def build():
    import mathutils
    with open(os.path.join(HERE, "concept_spec.json")) as f:
        spec = json.load(f)
    parts = adjust([p for p in spec["parts"] if wanted(p)])
    W = to_blender()
    mat = kit.lego.material("MI_PirateBoat_Brick", kit.ALB)
    blockers = [aabb(p, part_matrix(p)) if p["shape"] not in ("rod", "sail", "flag") else ([9e9] * 3, [-9e9] * 3) for p in parts]
    meshes = []
    for lod in range(3):
        meshes += build_lod(lod, parts, spec, W, mat, blockers)
    import zfight_check                     # run.py only nudges LOD0
    for lod in ("LOD1", "LOD2"):
        zfight_check.fix([e["object"] for e in meshes if e.get("lod") == lod])
    col = RB(W)
    col.col = P.DARK
    col.box((-13, -1.2, -5.2), (16.2, 8, 5.2), P.DARK, bevel=0)    # shortcut: boat is non-solid in game, proxy only for the pipeline
    meshes.append({"object": col.to_object(NAME + "_COL", mat), "role": "col"})
    atts = [kit.lego.attach(n, tuple(W @ mathutils.Vector(v))) for n, v in CREW.items()]
    return {
        "name": NAME, "budget": "small_craft", "tier": "standard",
        "dims_m": kit.dims_of(meshes), "origin": "free", "tiling": True,
        "size_note": "stylised toy-brick boat from its concept spec, scaled to about 26 studs long",
        "sets": [{"name": kit.SET_NAME, "set": kit.SET, "size": 1024, "wet": False}],
        "waivers": {
            "UV faces": "at the LODs the collapse decimator merges palette-cell UVs of the smallest faces; each stays one flat colour",
            "LOD UV layout": "flat palette cells, not a unique unwrap (tiling=True skips the density check)",
        },
        "meshes": meshes, "attachments": atts,
        "closeups": [
            {"name": "ram", "target": [0, -13, 4], "dist": 16, "az": -40, "el": 12},
            {"name": "stern", "target": [0, 11, 8], "dist": 18, "az": 170, "el": 10},
            {"name": "nest", "target": [0, -1, 20], "dist": 16, "az": -30, "el": 5},
        ],
    }
