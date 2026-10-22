"""M_Veh_StormRunner: premium (Robux) offshore powerboat on the M_Veh_RIB frame and markers (generic go-fast class,
not a replica). VehicleConfig.StormRunner (base "RIB"): Boat/Builder buildRIBAsset welds this mesh at RIB_ORIGIN and
places seats, survivor slots, nav lamps, tow hitch and bow point from the RIB's ATT_ markers, so every marker here sits
exactly where the RIB's does (same frame offset, frame_offset.json of M_Veh_RIB).

About 8.1 m hull (8.9 m with the engines) x 2.8 m: long low stepped deep V (23 deg at the transom), two spray strakes,
reverse chine, raked stem; pearl-white topsides over a graphite bottom, graphite flake / cobalt / silver racing sweep with a
spear tip, italic STORM RUNNER wordmark; non-slip foredeck with pinstripes, chrome bow rail, rub rail, grab rails and
pop-up cleats; bow lounge (survivor well), full-beam carbon dash with a raked wraparound smoked windscreen in a chrome
frame, sport wheel, screens and throttles; three offshore bolster seats, aft bench, sunpad, splash well; chrome
roll-bar raked aft with a graphite light pod (LED bar, masthead / beacon / stern light, searchlight, radome, whips);
twin outboards (the RIB's, 15% larger, gloss black cowls with cobalt and chrome bands) and split swim platforms.

Sets (every set has _Wet): Hull (hull shell + deck liner, 2048), Interior (dash, seats, cushions, windscreen; 4096,
hero tier for the helm), Engines (1024), Rig (roll-bar, rails, rub rail, cleats, 2048). Bake with MAYDAY_BAKE_SIZE=4096. Stripes and lettering are _HP-only geometry baked into the Hull maps.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Veh_StormRunner \
      --steps build,lod,bake,validate,export,turntable
"""
import json
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_BoatPremium"))
import boatkit as X  # noqa: E402

R, RB, M, smooth = X.R, X.RB, X.M, X.smooth
NAME = "M_Veh_StormRunner"
TEX = "StormRunner"
RIB_OFF = Vector(json.load(open(os.path.join(X.RIB, "frame_offset.json")))["offset"])

# --------------------------------------------------------------------------- palette (sRGB, roughness, metal)
R.PALETTE.update({
    "SR_White": ("#E4E6E3", 0.16, 0.0),        # pearl gloss gelcoat
    "SR_Bottom": ("#30353C", 0.26, 0.0),       # graphite bottom paint
    "SR_DeckWhite": ("#D8DAD6", 0.60, 0.0),    # moulded non-slip
    "SR_Sole": ("#3A3F45", 0.82, 0.0),         # EVA foam cockpit sole
    "SR_Graphite": ("#2E3238", 0.30, 0.0),
    "SR_Carbon": ("#25282C", 0.22, 0.0),
    "SR_Vinyl": ("#E0DFD9", 0.45, 0.0),        # white marine vinyl
    "SR_Quilt": ("#DEDDD6", 0.50, 0.0),
    "SR_Pleat": ("#DEDDD6", 0.50, 0.0),
    "SR_VinylSide": ("#2B3442", 0.50, 0.0),    # navy-graphite side panels
    "SR_Cobalt": ("#24509B", 0.20, 0.0),       # stripe paint (clear of every docs/05 3.2 signal colour)
    "SR_Silver": ("#C6CBCF", 0.28, 1.0),       # metallic silver stripe
    "SR_Flake": ("#3B4250", 0.20, 0.0),        # graphite flake lower topsides (two-tone sweep under the stripes)
    "SR_Pin": ("#3A3F46", 0.22, 0.0),
    "SR_Glass": ("#252B30", 0.04, 0.0),        # smoked acrylic
    "SR_AntiGlare": ("#2A2D31", 0.72, 0.0),    # matt dash top
    "GaugeFace": ("#2C3035", 0.35, 0.0),
    "Chrome": ("#E6E8EA", 0.05, 1.0),
    "Stainless": ("#E2E5E7", 0.08, 1.0),
    "CowlGrey": ("#1D1F23", 0.12, 0.0),        # gloss black outboard cowls (name kept: the RIB outboard slots)
    "CowlLight": ("#2E3238", 0.30, 0.0),       # graphite midsection / leg
})
for k in ("Stainless",):
    R.BUMP_ONLY.pop(k, None)                   # polished, not brushed
R.PROC.update({
    # light waterline scum (waterline about z 2.05), salt in the streaks, a gloss break-up on the gelcoat
    "SR_White": dict(mottle=(1.0, 0.03), streak=("#C8CBC6", 0.14), salt=("#CBCCC4", 0.10), zgrime=("#AEB1AA", 0.35, 2.0, 2.45),
                     rough_var=0.08),
    "SR_Bottom": dict(mottle=(2, 0.04), grime=("#262A2F", 0.18), streak=("#444A51", 0.14), rough_var=0.06),
    "SR_DeckWhite": dict(mottle=(1.5, 0.04), grime=("#BDBFBA", 0.18), rough_var=0.06, bump=("diamond", 0.5, 6)),
    "SR_Sole": dict(mottle=(1.5, 0.05), grime=("#33373C", 0.2), rough_var=0.05, bump=("grain", 0.12, 60)),
    "SR_Graphite": dict(mottle=(2, 0.03), rough_var=0.05),
    "SR_Carbon": dict(mottle=(2, 0.03), rough_var=0.04),
    "SR_Vinyl": dict(mottle=(4, 0.03), rough_var=0.05, bump=("grain", 0.1, 140)),
    "SR_Quilt": dict(mottle=(4, 0.03), rough_var=0.05, bump=("grain", 0.12, 140)),
    "SR_Pleat": dict(mottle=(4, 0.03), rough_var=0.05, bump=("grain", 0.12, 140)),
    "SR_AntiGlare": dict(mottle=(3, 0.03), rough_var=0.05, bump=("grain", 0.15, 90)),
    "SR_VinylSide": dict(mottle=(4, 0.04), rough_var=0.05, bump=("grain", 0.1, 140)),
    "SR_Cobalt": dict(mottle=(1.5, 0.03), rough_var=0.04),
    "SR_Pin": dict(mottle=(2, 0.03), rough_var=0.04),
    "CowlGrey": dict(mottle=(1.5, 0.03), streak=("#2A2D32", 0.10), rough_var=0.03),
    "SR_Flake": dict(mottle=(9, 0.05), streak=("#454C58", 0.08), rough_var=0.05),
    "CowlLight": dict(mottle=(2, 0.03), streak=("#3C4148", 0.12), rough_var=0.05),
})

# --------------------------------------------------------------------------- hull lines (studs, RIB frame pre-offset)
BOW = -13.35                    # stem head (sheer tip); bbox centred on the RIB's with the 15% engines aft
TR_Y = R.TRANSOM_Y              # 10.9, the RIB transom: the outboards mount here
LEN = TR_Y - BOW
K, DECK = R.K, R.DECK           # keel 0.45, cockpit sole 2.1 (greybox deck)
BM = 4.2                        # max half-beam (2.8 m beam)
STEPS = (-0.4, 4.2)             # bottom steps (y)
STEP_H = 0.07
Y_W0, Y_DASH0, Y_DASH1, Y_C1, Y_WELL = -6.9, -3.3, -0.8, 7.8, 9.6   # bow well, dash, aft bulkhead, splash well
Z_WELL = 2.65


def u_(y):
    return min(1.0, max(0.0, (y - BOW) / LEN))


def beam(y):
    u = u_(y)
    if u >= 0.62:
        return BM * (1 - 0.05 * ((u - 0.62) / 0.38) ** 2)
    return BM * (1 - (1 - u / 0.62) ** 1.6)     # fine, near-straight entry (about 24 deg half angle)


def sheer(y):
    return 3.9 + 0.95 * (1 - u_(y)) ** 2.0       # low freeboard aft, strong sheer rise to the bow


def keel(y):
    lift = STEP_H * sum(1 for s in STEPS if y > s)
    return K + lift + 2.1 * max(0.0, (0.3 - u_(y)) / 0.3) ** 1.9


def chine(y):
    u = u_(y)
    b, zs, zk = beam(y), sheer(y), keel(y)
    d = math.radians(23 + 28 * (1 - u) ** 1.7)
    xc = b * (0.80 + 0.10 * u)
    zc = min(zk + math.tan(d) * xc * 0.94, zs - 0.55 - 0.45 * max(0.0, 1 - u / 0.25))   # chine dies out low on the stem
    return xc, zc


def sc(y):
    """Detail scale: offsets shrink with the beam toward the stem."""
    return min(1.0, beam(y) / 2.0)


def lipf(y):
    """Reverse-chine lip width factor: fades into the stem."""
    return sc(y) * min(1.0, max(0.0, (u_(y) - 0.02) / 0.15))


def topside(y, t):
    """Topside point (x >= 0, z) at height fraction t (0 chine lip top, 1 below the gunwale round) with a slight bulge."""
    xc, zc = chine(y)
    b, zs = beam(y), sheer(y)
    x0, z0, x1, z1 = xc + 0.01 + 0.16 * lipf(y), zc + 0.09, b, zs - 0.2
    bul = 0.05 * math.sin(math.pi * t) * min(1.0, b / 2.0)
    return x0 + (x1 - x0) * t + bul, z0 + (z1 - z0) * t


def topside_normal(y, t):
    (xa, za), (xb, zb) = topside(y, max(0.0, t - 0.02)), topside(y, min(1.0, t + 0.02))
    n = Vector((zb - za, 0.0, -(xb - xa)))
    return n.normalized() if n.length > 1e-9 else Vector((1, 0, 0))


def rake(y, z):
    """Raked stem: the lower bow is pulled aft (0 at the sheer, 1.8 studs at the forefoot)."""
    u = u_(y)
    w = max(0.0, 1 - u / 0.35)      # linear falloff: dy'/dy stays > 0 (no folded forefoot rings)
    if w <= 0:
        return y
    zs, zk = sheer(y), keel(y)
    return y + 2.6 * w * max(0.0, min(1.0, (zs - z) / max(zs - zk, 1e-3)))


def half_section(y, hi):
    """[(x, z, mat)] keel -> gunwale (port), mat names the segment from this point to the next."""
    b, zs, zk = beam(y), sheer(y), keel(y)
    xc, zc = chine(y)
    s = sc(y)
    pts = [(0.0, zk, "SR_Bottom"), (0.1 * s, zk + 0.02, "SR_Bottom")]
    for f in (0.34, 0.67):
        xa = f * xc
        za = zk + (zc - zk) * f * 0.97
        pts += [(xa, za, "SR_Bottom"), (xa + 0.05 * s, za - 0.035 * s, "SR_Bottom")]
    pts += [(xc, zc, "SR_Bottom"), (xc + 0.001 + 0.16 * lipf(y), zc + 0.01, "SR_Bottom")]
    for t in ((0.0, 0.25, 0.5, 0.75) if hi else (0.0, 0.5)):
        x, z = topside(y, t)
        pts.append((x, z, "SR_White"))
    pts += [(b, zs - 0.2, "SR_White"), (b - 0.02 * s, zs - 0.07, "SR_White"), (b - 0.1 * s, zs, "SR_White")]
    return pts


def stations(hi):
    step = 0.45 if hi else 0.8
    ys = [BOW + 0.02] + [BOW + 0.15 * k for k in range(1, 6)] + [BOW + 0.9 + step * 0.6 * k for k in range(9)]
    y = ys[-1]
    while y < TR_Y - 0.05:
        y += step
        ys.append(min(y, TR_Y))
    for s in STEPS:
        ys += [s - 0.002, s + 0.002]
    ys.append(TR_Y)
    return sorted(set(round(v, 4) for v in ys if BOW < v <= TR_Y))


def ring(y, hi):
    half = half_section(y, hi)
    full = [(-x, z, m) for x, z, m in reversed(half)] + [(x, z, m) for x, z, m in half[1:]]
    return [Vector((x, rake(y, z), z)) for x, z, _ in full], [m for _, _, m in reversed(half[:-1])] + \
        [m for _, _, m in half[:-1]]


def hull(g):
    ys = stations(g.hi)
    rings, mats = [], None
    for y in ys:
        r, m = ring(y, g.hi)
        rings.append(r)
        mats = m
    # stem: collapse onto the centreline at the stem head
    stem = [Vector((0.0, rake(BOW, p.z), max(p.z, keel(BOW)))) for p in rings[0]]
    rings.insert(0, stem)
    fs = g.rings(rings, M(g, "SR_White"), closed=False, recalc=False,
                 matfn=(lambda i, j: mats[j]) if g.hi else None)
    g.orient(fs, lambda c: Vector((c.x, 0.0, c.z - 3.6)) if abs(c.x) > 0.04 else Vector((0, 0, -1)))
    # transom (notched for the splash well): the hull ring, then the deck ring back across
    hr = [g.bm.verts.new(p) for p in rings[-1]]
    dr = [g.bm.verts.new(p) for p in deck_ring(TR_Y)[1:-1]]
    f = g.face(hr + dr, M(g, "SR_White"))
    if f:
        res = bmesh.ops.triangulate(g.bm, faces=[f], quad_method="BEAUTY", ngon_method="EAR_CLIP")
        g.orient(res["faces"], lambda c: Vector((0, 1, 0)))
    # stainless keel band
    kp = [Vector((0, rake(y, keel(y)) , keel(y) - 0.012)) for y in ys if y > BOW + 0.6]
    R.sweep(g, kp, [(-0.11, -0.02), (0.11, -0.02), (0.09, 0.03), (-0.09, 0.03)], M(g, "Stainless"), cap0=True,
            cap1=True)
    if g.hi:
        hull_decals(g)


# --------------------------------------------------------------------------- _HP-only stripes and lettering
OFF = 0.012


def side_pt(sx, y, t, off=OFF):
    x, z = topside(y, t)
    n = topside_normal(y, t)
    return Vector((sx * (x + n.x * off), rake(y, z), z + n.z * off))


def band(y, aft, fwd, y_fwd, y_tip, t_tip):
    """(t_lo, t_hi) of a stripe at y: linear from the transom (aft) to y_fwd (fwd), then a spear tip at y_tip."""
    if y >= y_fwd:
        f = (TR_Y - y) / (TR_Y - y_fwd)
        return aft[0] + (fwd[0] - aft[0]) * f, aft[1] + (fwd[1] - aft[1]) * f
    f = (y_fwd - y) / (y_fwd - y_tip)
    return fwd[0] + (t_tip - fwd[0]) * f, fwd[1] + (t_tip - fwd[1]) * f


STRIPES = [   # (mat, aft (lo, hi), fwd (lo, hi), y_fwd, y_tip, t_tip, offset)
    ("SR_Flake", (0.0, 0.06), (0.0, 0.40), -5.2, -8.4, 0.0, OFF - 0.004),
    ("SR_Pin", (0.06, 0.085), (0.40, 0.42), -5.2, -8.4, 0.44, OFF),
    ("SR_Cobalt", (0.11, 0.62), (0.45, 0.68), -5.0, -9.0, 0.62, OFF),
    ("SR_Silver", (0.66, 0.72), (0.72, 0.77), -4.6, -10.0, 0.76, OFF),
]


def hull_decals(g):
    for sx in (1, -1):
        out = (lambda c, sx=sx: Vector((sx, 0, 0.1)))
        for mat, aft, fwd, yf, yt, tt, off in STRIPES:
            def fn(a, b, aft=aft, fwd=fwd, yf=yf, yt=yt, tt=tt, off=off):
                y = TR_Y - 0.02 + (yt - TR_Y + 0.02) * a
                lo, hi = band(y, aft, fwd, yf, yt, tt)
                return side_pt(sx, y, lo + (hi - lo) * b, off)
            X.patch(g, fn, 60, 3, mat, out)
        # italic wordmark in the cobalt band, reading bow -> stern on both sides
        yc = 3.0
        lo, hi = band(yc, (0.11, 0.62), (0.45, 0.68), -5.0, -9.0, 0.62)
        tc = (lo + hi) / 2
        sl = (Vector(topside(yc, 1.0)) - Vector(topside(yc, 0.0))).length
        X.text_on(g, "STORM RUNNER", 0.5,
                  lambda u, v, sx=sx: side_pt(sx, yc + sx * u, tc + v / sl, OFF + 0.006), "LetterWhite", out,
                  scale_x=1.0, shear=0.28)
    # transom: name and home port (read from astern: text X runs to -X)
    def tr(u, v, z0):
        return Vector((-u, TR_Y + 0.012, z0 + v))
    X.text_on(g, "STORM RUNNER", 0.42, lambda u, v: tr(u, v, 1.75), "LetterCharcoal", lambda c: Vector((0, 1, 0)),
              shear=0.25)
    X.text_on(g, "PORT GALE", 0.22, lambda u, v: tr(u, v, 1.3), "LetterCharcoal", lambda c: Vector((0, 1, 0)))


# --------------------------------------------------------------------------- deck liner (one loft, bow to transom)
def deck_half(y):
    """Port half of the deck ring, gunwale -> centreline: [(x, z, mat)] (same count in every region)."""
    b, zs = beam(y), sheer(y)
    xs = [b - 0.1, b - 0.55, b - 0.68, b - 0.76, b - 0.86, b - 0.98, b - 1.15, 0.5 * (b - 1.15), 0.0]
    if y < Y_W0:   # the bow-well front's x layout, scaled down to the stem
        bw = beam(Y_W0)
        ref = [bw - 0.1, bw - 0.55, bw - 0.68, bw - 0.76, bw - 0.86, bw - 0.98, bw - 1.15, 0.5 * (bw - 1.15), 0.0]
        xs = [(b - 0.1 * sc(y)) * r / ref[0] for r in ref]
    if y < Y_W0 or (Y_C1 <= y < Y_WELL):
        # foredeck (crowned) / flush aft deck
        crown = 0.4 if y < Y_W0 else 0.0
        bi = max(b - 0.1, 1e-3)
        zz = [zs + crown * (1 - (min(x, bi) / bi) ** 2) + (0.0 if y < Y_W0 else 0.02 * (i > 0)) for i, x in enumerate(xs)]
        return [(x, z, "SR_DeckWhite") for x, z in zip(xs, zz)]
    if y >= Y_WELL:
        xs = [b - 0.1, b - 0.55, 2.95, 2.85, 2.75, 2.68, 2.55, 1.3, 0.0]
        zz = [zs, zs + 0.02, zs + 0.02, zs - 0.1, Z_WELL + 0.3, Z_WELL + 0.05, Z_WELL, Z_WELL, Z_WELL]
        mats = ["SR_DeckWhite"] * 3 + ["SR_White"] * 3 + ["SR_Sole"] * 3
        return list(zip(xs, zz, mats))
    zz = [zs, zs + 0.02, zs - 0.06, zs - 0.3, DECK + 0.35, DECK + 0.06, DECK, DECK, DECK]
    mats = ["SR_DeckWhite", "SR_DeckWhite", "SR_White", "SR_White", "SR_White", "SR_White", "SR_Sole", "SR_Sole",
            "SR_Sole"]
    return list(zip(xs, zz, mats))


def deck_ring(y):
    h = deck_half(y)
    full = h + [(-x, z, m) for x, z, m in reversed(h[:-1])]
    return [Vector((x, y, z)) for x, z, _ in full]


def deck_mats(y):
    h = deck_half(y)
    return [m for _, _, m in h[:-1]] + [m for _, _, m in reversed(h[:-1])]


def deck(g):
    step = 0.5 if g.hi else 0.9
    ys = [BOW + 0.05, BOW + 0.2, BOW + 0.45, BOW + 0.8]
    y = ys[-1]
    while y < TR_Y - 0.05:
        y += step
        ys.append(min(y, TR_Y))
    edges = [Y_W0, Y_C1, Y_WELL]
    ys = sorted(set(round(v, 4) for v in ys if all(abs(v - e) > 0.05 for e in edges)) | {TR_Y})
    # each region boundary gets two stations at the same y (the bulkhead faces between them)
    rows = []
    for y in ys:
        for e in edges:
            if rows and rows[-1][0] < e <= y:
                rows.append((e - 1e-4, deck_ring(e - 1e-4), deck_mats(e - 1e-4)))
                rows.append((e, deck_ring(e), deck_mats(e)))
        rows.append((y, deck_ring(y), deck_mats(y)))
    for i in range(len(rows) - 1):
        (ya, ra, ma), (yb, rb, mb) = rows[i], rows[i + 1]
        mats = ma if yb - ya > 1e-3 else ["SR_White"] * len(ma)
        fs = g.rings([ra, rb], M(g, "SR_DeckWhite"), closed=False, recalc=False,
                     matfn=(lambda i_, j, mats=mats: mats[j]) if g.hi else None)
        for f in fs:
            f.normal_update()
            nrm = f.normal
            c = f.calc_center_median()
            if yb - ya > 1e-3:
                want = Vector((-c.x, 0, 1.0)) if c.z < sheer(c.y) - 0.15 else Vector((0, 0, 1))
            else:
                # bulkhead faces look into the lower region (aft at the bow-well front and the splash well, forward at Y_C1)
                want = Vector((0, -1, 0)) if abs(ya - Y_C1) < 0.01 else Vector((0, 1, 0))
            if nrm.dot(want) < 0:
                f.normal_flip()
    # foredeck hatch and a flush deck plate
    zc = sheer(-10.2) + 0.4
    R.box(g, (0, -10.2, zc + 0.02), (1.7, 1.4, 0.07), M(g, "SR_DeckWhite"), bev=0.03)
    R.box(g, (0, -11.25, sheer(-11.25) + 0.42), (0.3, 0.3, 0.03), M(g, "Chrome"), bev=0.01)


def dash(g):
    b = beam(-2.0)
    w = b - 0.82
    prof = [(Y_DASH0, DECK), (Y_DASH0, 4.32), (-3.0, 4.6), (-2.0, 4.7), (-1.1, 4.76), (Y_DASH1, 4.05), (Y_DASH1, DECK)]
    R.extrude_profile(g, prof, -w, w, M(g, "SR_White"),
                      matfn=(lambda i, j: "SR_Carbon" if j == 4 else ("SR_Graphite" if j == 5 else
                                                                         ("SR_AntiGlare" if j in (2, 3) else "SR_White")))
                      if g.hi else None, bev=0.04)
    # gauge panel on the aft slope: two screens, four dials, a switch row
    a, c =Vector((0, -1.1, 4.76)), Vector((0, Y_DASH1, 4.05))
    tdir = (a - c).normalized()
    n = Vector((0, -tdir.z, tdir.y)) if tdir.z > 0 else Vector((0, tdir.z, -tdir.y))
    if n.y < 0:
        n = -n
    rot = Matrix((Vector((1, 0, 0)), tdir, n)).transposed()
    for k, (x, s) in enumerate(((0.78, (0.8, 0.44)), (-0.78, (0.8, 0.44)))):
        p = c.lerp(a, 0.55) + Vector((x, 0, 0)) + n * 0.015
        R.box(g, tuple(p), (s[0] + 0.06, s[1] + 0.06, 0.03), M(g, "BlackPlastic"), rot=rot, bev=0.01)
        R.box(g, tuple(p + n * 0.017), (s[0], s[1], 0.01), M(g, "Screen"), rot=rot, bev=0.0)
        if g.hi:
            R.box(g, tuple(p + n * 0.023 + tdir * 0.05), (s[0] * 0.8, s[1] * 0.45, 0.004), "ScreenChart", rot=rot, bev=0.0)
    for x in (1.75, 2.25, -1.75, -2.25):     # tach / speed / trim / fuel
        X.gauge(g, c.lerp(a, 0.6) + Vector((x, 0, 0)), n, 0.19)
    for x in (-0.4, 0.0, 0.4):               # engine gauges over the screens
        X.gauge(g, c.lerp(a, 0.88) + Vector((x, 0, 0)), n, 0.13)
    for k in range(6):
        p = c.lerp(a, 0.18) + Vector((-0.5 + 0.2 * k, 0, 0)) + n * 0.01
        R.box(g, tuple(p), (0.1, 0.12, 0.04), M(g, "BlackPlastic"), rot=rot, bev=0.01)
    # helm pod, column and sport wheel (axis toward the driver, tilted back)
    R.box(g, (0, Y_DASH1 + 0.12, 3.75), (1.3, 0.3, 1.0), M(g, "SR_Graphite"), bev=0.06)
    ax = Vector((0, 1, 0.5)).normalized()
    wc = Vector((0, -0.35, 5.1))
    R.tube(g, [(0, Y_DASH1 - 0.05, 4.62), tuple(wc - ax * 0.08)], 0.06, M(g, "Chrome"), 12 if g.hi else 8)
    X.wheel(g, wc, ax, 0.56, 0.055, M(g, "SR_Graphite"), M(g, "Chrome"), M(g, "Chrome"), seg=40 if g.hi else 28)
    # throttle quadrant (starboard, -X) with twin chrome levers
    R.box(g, (-1.55, Y_DASH1 + 0.25, 4.35), (0.42, 0.5, 0.28), M(g, "SR_Graphite"), bev=0.05)
    for dx in (-0.08, 0.08):
        R.tube(g, [(-1.55 + dx, Y_DASH1 + 0.25, 4.45), (-1.55 + dx, Y_DASH1 + 0.45, 4.95)], 0.025, M(g, "Chrome"), 8)
        R.lathe(g, (-1.55 + dx, Y_DASH1 + 0.47, 4.98), (0, 0, 1), [(0.0, -0.05), (0.06, -0.04), (0.06, 0.04), (0.0, 0.05)],
                10, M(g, "BlackPlastic"))
    # sidelight housings on the dash top (ATT_NavPort / ATT_NavStarboard of the RIB at (+-1.47, -2.0, 4.72))
    for sx, lens in ((1, "LensRed"), (-1, "LensGreen")):
        R.box(g, (sx * 1.47, -2.0, 4.72), (0.26, 0.24, 0.12), M(g, "SR_Graphite"), bev=0.03)
        R.box(g, (sx * 1.47 + sx * 0.06, -2.05, 4.75), (0.16, 0.16, 0.07), M(g, lens), bev=0.02)
    # compass binnacle on the dash centre ahead of the screen
    R.lathe(g, (0, -2.45, 4.66), (0, 0, 1), [(0.0, 0.0), (0.22, 0.0), (0.22, 0.06), (0.18, 0.1), (0.14, 0.2), (0.0, 0.23)],
            20 if g.hi else 12, M(g, "BlackPlastic"), matfn=(lambda i, j: "SR_Glass" if i >= 3 else "BlackPlastic") if g.hi else None)


def windscreen(g):
    """Raked wraparound smoked screen on the dash top: a thin closed shell, chrome top rail and corner posts."""
    n = 26 if g.hi else 14
    base, top = [], []
    for k in range(n + 1):
        s = -1 + 2 * k / n
        x = 3.0 * s
        yb = -1.0 - 0.95 * (1 - abs(s) ** 2.6)
        rk = 0.3 + 1.5 * (1 - abs(s) ** 1.8)
        base.append(Vector((x, yb, 4.72 + 0.03 * (1 - abs(s)))))
        top.append(Vector((x * 0.92, yb + rk, 6.1 - 0.3 * abs(s) ** 3)))
    cols = []
    for k, (p, q) in enumerate(zip(base, top)):
        tr = base[min(n, k + 1)] - base[max(0, k - 1)]
        nrm = tr.cross(q - p).normalized()
        if nrm.dot(p - Vector((0, 0.5, p.z))) < 0:
            nrm = -nrm
        mid = p.lerp(q, 0.5)
        th = 0.035
        cols.append([p, mid, q, q - nrm * th, mid - nrm * th, p - nrm * th])
    g.rings(cols, M(g, "SR_Glass"), closed=True, cap0=True, cap1=True, recalc=True)
    # chrome top rail and the two corner posts, black base gasket
    R.sweep(g, [q - Vector((0, 0, 0.0)) for q in top], R.circle_profile(0.05, 10 if g.hi else 6), M(g, "Chrome"),
            cap0=True, cap1=True)
    for k in (0, n):
        R.tube(g, [tuple(base[k]), tuple(top[k])], 0.05, M(g, "Chrome"), 10 if g.hi else 6)
    R.sweep(g, base, [(-0.06, -0.02), (0.06, -0.02), (0.05, 0.04), (-0.05, 0.04)], M(g, "Rubber"), cap0=True, cap1=True)


def bolster(g, x, y, grab=False):
    seg = 32 if g.hi else 16
    R.box(g, (x, y + 0.05, DECK + 0.6), (0.85, 0.85, 1.2), M(g, "SR_Graphite"), bev=0.06)
    R.box(g, (x, y + 0.05, DECK + 0.02), (1.05, 1.05, 0.05), M(g, "Chrome"), bev=0.02)
    R.tube(g, [(x - 0.45, y - 0.55, DECK + 0.95), (x - 0.45, y - 0.75, DECK + 0.95), (x + 0.45, y - 0.75, DECK + 0.95),
               (x + 0.45, y - 0.55, DECK + 0.95)], 0.035, M(g, "Chrome"), 10 if g.hi else 6, fillet=0.12, fseg=3)
    secs = [(x, y, 3.42, 0.7, 0.6), (x, y, 3.55, 0.78, 0.66), (x, y, 4.45, 0.78, 0.66), (x, y, 4.6, 0.7, 0.58)]
    R.loft(g, secs, seg, M(g, "SR_Quilt"), cap0=True, cap1=True, p=3.0,
           matfn=(lambda i, j: ("SR_Graphite", "SR_VinylSide", "SR_Vinyl")[i]) if g.hi else None)
    # high back with wings: front (-Y) half pleated
    by = y + 0.62
    secs = [(x, by, 4.5, 0.74, 0.2), (x, by, 5.4, 0.8, 0.24), (x, by + 0.04, 6.05, 0.62, 0.2), (x, by + 0.06, 6.2, 0.45, 0.14)]

    def back(i, j):
        return "SR_Pleat" if (j > seg // 2 and i < 2) else ("SR_Vinyl" if i < 3 else "SR_VinylSide")
    R.loft(g, secs, seg, M(g, "SR_Vinyl"), cap0=True, cap1=True, p=3.2, matfn=back if g.hi else None)
    for sx in (1, -1):
        R.loft(g, [(x + sx * 0.72, y + 0.1, 4.55, 0.12, 0.5), (x + sx * 0.74, y + 0.2, 5.25, 0.13, 0.42),
                   (x + sx * 0.72, y + 0.3, 5.5, 0.1, 0.3)], seg // 2, M(g, "SR_VinylSide"), p=2.6)
    if grab:
        R.tube(g, [(x - 0.55, by + 0.24, 5.2), (x - 0.55, by + 0.42, 5.3), (x + 0.55, by + 0.42, 5.3),
                   (x + 0.55, by + 0.24, 5.2)], 0.04, M(g, "Chrome"), 10 if g.hi else 6, fillet=0.12, fseg=3)


def cushions(g):
    # bow lounge: two side benches following the liner wall and a forward bench across (the survivor well)
    for sx in (1, -1):
        pts = []
        for k in range(9 if g.hi else 5):
            y = Y_W0 + 0.1 + (-3.55 - Y_W0 - 0.1) * k / (8 if g.hi else 4)
            pts.append(Vector((sx * (beam(y) - 0.86 - 0.34), y, DECK)))
        prof_base = [(-0.32, 0.0), (0.32, 0.0), (0.32, 0.8), (-0.32, 0.8)]
        prof_cush = [(-0.3, 0.8), (0.3, 0.8), (0.32, 0.92), (0.3, 1.12), (-0.3, 1.12), (-0.32, 0.92)]
        R.sweep(g, pts, prof_base, M(g, "SR_White"), cap0=True, cap1=True)
        R.sweep(g, pts, prof_cush, M(g, "SR_Quilt"), cap0=True, cap1=True)
        # backrest pad against the liner
        pb = [p + Vector((sx * 0.24, 0, 0)) for p in pts]
        R.sweep(g, pb, [(-0.1, 1.15), (0.1, 1.15), (0.1, 1.95), (-0.1, 1.95)], M(g, "SR_Pleat"), cap0=True, cap1=True)
    yf = Y_W0 + 0.45
    w = beam(yf) - 0.86
    R.box(g, (0, yf, DECK + 0.4), (2 * w, 0.85, 0.8), M(g, "SR_White"), bev=0.05)
    R.box(g, (0, yf, DECK + 0.96), (2 * w - 0.1, 0.82, 0.3), M(g, "SR_Quilt"), bev=0.1)
    # aft bench against the aft bulkhead, and the sunpad on the aft deck
    w = beam(Y_C1) - 0.86
    R.box(g, (0, Y_C1 - 0.45, DECK + 0.55), (2 * w, 0.9, 1.1), M(g, "SR_White"), bev=0.05)
    R.box(g, (0, Y_C1 - 0.47, DECK + 1.25), (2 * w - 0.2, 0.86, 0.3), M(g, "SR_Quilt"), bev=0.1)
    R.box(g, (0, Y_C1 - 0.12, DECK + 1.85), (2 * w - 0.3, 0.22, 0.9), M(g, "SR_Pleat"), bev=0.08)
    zs = sheer(8.7) + 0.02
    R.box(g, (0, 8.7, zs + 0.17), (2 * (beam(8.7) - 0.75), Y_WELL - Y_C1 - 0.2, 0.34), M(g, "SR_Quilt"), bev=0.12)
    # split swim platforms outboard of the engines, graphite non-slip
    for sx in (1, -1):
        R.box(g, (sx * 3.2, TR_Y + 0.55, 2.25), (1.6, 1.1, 0.18), M(g, "SR_Sole"), bev=0.05)
        R.box(g, (sx * 3.2, TR_Y + 0.4, 2.05), (1.4, 0.8, 0.25), M(g, "SR_White"), bev=0.05)


def interior(g):
    dash(g)
    bolster(g, 0.0, 1.6, grab=True)
    for x in (1.3, -1.3):
        bolster(g, x, 4.8)
    cushions(g)


# --------------------------------------------------------------------------- rig: engines, roll-bar, rails
ENG_S = 1.15


def engines(g):
    start = len(g.bm.verts)
    # shortcut: drop the RIB outboard's flat blade strips (they read as discs from astern) by filtering g.rings
    # while it runs; four thin cupped blades replace them below. Upgrade if the RIB build grows its own prop.
    rings = g.rings
    g.rings = lambda rr, mat, closed=True, **kw: [] if (not closed and len(rr[0]) == 2 and len(rr) in (6, 9)) \
        else rings(rr, mat, closed=closed, **kw)
    try:
        RB.engines(g)
    finally:
        del g.rings
    for x in RB.ENG_X:
        X.prop_blades(g, (x, RB.ENG_Y + 0.46, 0.62))
    if g.hi:
        for x in RB.ENG_X:   # cobalt wrap band and a thin silver line round each cowl
            R.loft(g, [(x, RB.ENG_Y, 3.72, 0.628, 0.868), (x, RB.ENG_Y, 3.86, 0.628, 0.868)], 40, "SR_Cobalt",
                   cap0=False, cap1=False, p=3.2)
            R.loft(g, [(x, RB.ENG_Y, 3.9, 0.626, 0.866), (x, RB.ENG_Y, 3.93, 0.626, 0.866)], 40, "Chrome",
                   cap0=False, cap1=False, p=3.2)
    R.deform(g, start, lambda c: Vector((math.copysign(1.3, c.x) + (c.x - math.copysign(1.3, c.x)) * ENG_S,
                                         TR_Y + 0.2 + (c.y - TR_Y - 0.2) * ENG_S, c.z * ENG_S)))


AF_Y, AF_Z = 9.95, 8.05


def rollbar(g):
    seg = 18 if g.hi else 10
    zs = sheer(6.3)
    pts = [(3.62, 6.3, zs + 0.02), (3.25, 8.3, 6.9), (2.55, AF_Y, AF_Z), (-2.55, AF_Y, AF_Z), (-3.25, 8.3, 6.9),
           (-3.62, 6.3, zs + 0.02)]
    R.tube(g, pts, 0.13, M(g, "Chrome"), seg, fillet=0.9, fseg=8)
    for sx in (1, -1):
        R.box(g, (sx * 3.62, 6.3, zs + 0.03), (0.42, 0.55, 0.06), M(g, "Chrome"), bev=0.02)
        # aft brace to the aft deck
        R.tube(g, [(sx * 3.3, 8.0, 6.45), (sx * 3.35, 9.3, sheer(9.3) + 0.02)], 0.08, M(g, "Chrome"), seg - 4)
        R.box(g, (sx * 3.35, 9.3, sheer(9.3) + 0.03), (0.3, 0.36, 0.05), M(g, "Chrome"), bev=0.02)
    # graphite light pod on the crossbar (aerofoil, leading edge forward)
    path = [Vector((2.45 - 4.9 * k / 8, AF_Y, AF_Z + 0.02)) for k in range(9)]
    R.sweep(g, path, X.aerofoil(0.85, 0.3, 10 if g.hi else 6), M(g, "SR_Graphite"), cap0=True, cap1=True)
    zt = AF_Z + 0.16
    # LED bar under the leading edge (white floods, blue strobes at the ends)
    R.box(g, (0, AF_Y - 0.4, AF_Z - 0.05), (2.6, 0.16, 0.16), M(g, "BlackPlastic"), bev=0.03)
    for k in range(10):
        R.box(g, (-1.17 + 0.26 * k, AF_Y - 0.485, AF_Z - 0.05), (0.2, 0.02, 0.1),
              M(g, "LensBlue" if k in (0, 9) else "LensWhite"), bev=0.0)
    # masthead (white, -X) and blue beacon (+X) on the pod top, at the RIB's ATT_NavMasthead / ATT_Beacon
    for x, lens, h in ((-1.25, "LensWhite", 0.22), (1.25, "LensBlue", 0.36)):
        R.box(g, (x, AF_Y + 0.15, zt + 0.02), (0.3, 0.3, 0.07), M(g, "SR_Graphite"))
        R.lathe(g, (x, AF_Y + 0.15, zt + 0.05), (0, 0, 1),
                [(0.13, 0), (0.13, 0.08), (0.11, 0.09), (0.11, 0.09 + h), (0.08, 0.12 + h), (0.0, 0.14 + h)],
                seg, M(g, lens), matfn=(lambda i, j, lens=lens: "BlackPlastic" if i < 1 or i >= 3 else lens) if g.hi else None)
    # stern light on the pod's aft edge (ATT_NavStern 0, 10.36, 7.9)
    R.box(g, (0, AF_Y + 0.38, 7.92), (0.22, 0.1, 0.14), M(g, "BlackPlastic"))
    R.box(g, (0, AF_Y + 0.44, 7.92), (0.16, 0.02, 0.09), M(g, "LensWhite"))
    # searchlight (ATT_Searchlight -0.62, 9.65, 8.68)
    R.lathe(g, (-0.62, AF_Y - 0.05, zt), (0, 0, 1), [(0.08, 0), (0.08, 0.3), (0.0, 0.31)], seg // 2, M(g, "Chrome"))
    R.lathe(g, (-0.62, 9.95 - 0.3, 8.62), (0, -1, 0),
            [(0.0, -0.15), (0.16, -0.15), (0.18, 0.0), (0.18, 0.12), (0.16, 0.14), (0.0, 0.14)], seg, M(g, "Chrome"),
            matfn=(lambda i, j: "LensWhite" if i >= 4 else "Chrome") if g.hi else None)
    # two chrome spotlight pods on the hoop's upper bends, facing forward
    for sx in (1, -1):
        c = Vector((sx * 2.95, 9.45, 7.72))
        R.box(g, tuple(c + Vector((0, 0.18, -0.12))), (0.12, 0.2, 0.2), M(g, "Chrome"), bev=0.02)
        R.lathe(g, tuple(c), (0, -1, 0), [(0.0, -0.25), (0.2, -0.25), (0.24, 0.0), (0.24, 0.1), (0.21, 0.12), (0.0, 0.12)],
                seg + 6, M(g, "Chrome"), matfn=(lambda i, j: "LensWhite" if i >= 4 else "Chrome") if g.hi else None)
    # compact radome, GPS puck, two whips raked aft
    R.lathe(g, (0.25, AF_Y + 0.05, zt), (0, 0, 1),
            [(0.1, 0), (0.42, 0.02), (0.44, 0.08), (0.44, 0.26), (0.36, 0.34), (0.15, 0.38), (0.0, 0.39)],
            32 if g.hi else 20, M(g, "SR_White"))
    for sx in (1, -1):
        b = Vector((sx * 1.85, AF_Y + 0.2, zt))
        R.lathe(g, tuple(b), (0, 0.9, 0.44), [(0.045, 0.0), (0.045, 0.25), (0.03, 0.3), (0.0, 0.31)], 8, M(g, "Chrome"))
        R.lathe(g, tuple(b + Vector((0, 0.13, 0.2))), (0, 0.9, 0.44), [(0.028, 0.0), (0.011, 2.0), (0.0, 2.02)],
                6, M(g, "SR_White"))


def rails(g):
    seg = 12 if g.hi else 7
    # bow rail: stanchions on the foredeck edge and a rail converging on the pulpit
    ys = [-11.7, -10.3, -8.9, -7.5, -6.1]
    top = []
    for sx in (1, -1):
        side = []
        for y in ys:
            x = sx * (beam(y) - 0.32)
            z0 = sheer(y) + (0.05 if y < Y_W0 else 0.02)
            R.tube(g, [(x, y, z0), (x, y, z0 + 0.95)], 0.045, M(g, "Chrome"), seg)
            R.lathe(g, (x, y, z0), (0, 0, 1), [(0.0, 0.0), (0.11, 0.0), (0.11, 0.03), (0.06, 0.08), (0.0, 0.09)],
                    seg, M(g, "Chrome"))
            side.append((x, y, z0 + 0.95))
        top.append(side)
    path = list(reversed(top[0])) + [(0.0, BOW + 0.75, sheer(BOW + 0.75) + 1.0)] + top[1]
    path = [(x, y, z) for x, y, z in path]
    R.tube(g, [p for p in path], 0.055, M(g, "Chrome"), seg, fillet=0.6, fseg=5)
    R.tube(g, [(0.0, BOW + 0.75, sheer(BOW + 0.75) + 0.98), (0.0, BOW + 0.75, sheer(BOW + 0.75) + 0.3)], 0.05,
           M(g, "Chrome"), seg)
    # cockpit grab rails on the covering boards
    for sx in (1, -1):
        pts = []
        for y in (-0.4, 2.8, 6.0):
            x = sx * (beam(y) - 0.33)
            pts.append((x, y, sheer(y) + 0.02))
        rail = [(p[0], p[1], p[2] + 0.32) for p in pts]
        R.tube(g, [pts[0]] + rail + [pts[-1]], 0.04, M(g, "Chrome"), seg, fillet=0.25, fseg=4)
        R.tube(g, [pts[1], rail[1]], 0.035, M(g, "Chrome"), seg)
    # pop-up cleats
    for sx in (1, -1):
        for y in (-9.6, 8.8):
            x = sx * (beam(y) - 0.34)
            z = sheer(y) + (0.06 if y < 0 else 0.03)
            R.box(g, (x, y, z), (0.18, 0.55, 0.05), M(g, "Chrome"), bev=0.02)
            R.tube(g, [(x, y - 0.3, z + 0.05), (x, y - 0.2, z + 0.15), (x, y + 0.2, z + 0.15), (x, y + 0.3, z + 0.05)],
                   0.035, M(g, "Chrome"), 8, fillet=0.08, fseg=2)
    # rub rail: black rubber D with a chrome insert, stem to transom
    n = 40 if g.hi else 22
    ys2 = [BOW + 0.25 + (TR_Y - 0.02 - BOW - 0.25) * (k / n) ** 1.3 for k in range(n + 1)]
    path = [Vector((beam(y) + 0.02, y, sheer(y) - 0.14)) for y in reversed(ys2)] + \
        [Vector((0.0, BOW + 0.02, sheer(BOW) - 0.12))] + [Vector((-beam(y) - 0.02, y, sheer(y) - 0.14)) for y in ys2]
    R.sweep(g, path, [(0.0, -0.09), (-0.08, -0.07), (-0.11, 0.0), (-0.08, 0.07), (0.0, 0.09)], M(g, "Rubber"),
            closed=True, cap0=True, cap1=True)
    path2 = [p + Vector((0.11 if p.x > 0.05 else (-0.11 if p.x < -0.05 else 0), -0.11 if abs(p.x) <= 0.05 else 0, 0))
             for p in path]
    R.sweep(g, path2, R.circle_profile(0.03, 6), M(g, "Chrome"), cap0=True, cap1=True)
    # tow eye on the splash-well floor (ATT_TowHitch 0, 10.45, 2.72)
    R.box(g, (0, 10.45, Z_WELL + 0.02), (0.4, 0.3, 0.04), M(g, "Chrome"), bev=0.01)
    R.tube(g, [(-0.12, 10.45, Z_WELL), (-0.1, 10.45, Z_WELL + 0.12), (0.1, 10.45, Z_WELL + 0.12), (0.12, 10.45, Z_WELL)],
           0.03, M(g, "Chrome"), 8, fillet=0.06, fseg=2)
    # boarding ladder folded on the port platform
    for dx in (-0.25, 0.25):
        R.tube(g, [(3.2 + dx, TR_Y + 0.2, 2.38), (3.2 + dx, TR_Y + 1.0, 2.38)], 0.03, M(g, "Chrome"), 8)
    for k in range(3):
        R.tube(g, [(2.95, TR_Y + 0.35 + 0.28 * k, 2.38), (3.45, TR_Y + 0.35 + 0.28 * k, 2.38)], 0.025, M(g, "Chrome"), 6)


# --------------------------------------------------------------------------- collision, markers
def collision():
    pts = []
    for y in stations(False):
        r, _ = ring(y, False)
        pts += [tuple(p) for p in r]
    for x in (-3.0, 3.0):
        pts += [(x * 0.93, -0.6, 6.0), (x, -1.2, 4.7)]
    pts += [(0, 12.9, 0.0), (1.3, 13.2, 5.4), (-1.3, 13.2, 5.4)]
    return X.convex_col(NAME, pts)


def markers():
    atts = dict(RB.ATTACHMENTS)
    for i, (x, z) in enumerate(RB.FLOATS):
        atts["ATT_Float%d" % (i + 1)] = RB.gb(x, -1.65, z)
    for i, x in enumerate(RB.ENG_X):   # props of the 15% engines
        atts["ATT_Prop%d" % (i + 1)] = (x, TR_Y + 0.2 + (RB.ENG_Y + 0.46 - TR_Y - 0.2) * ENG_S, 0.62 * ENG_S)
    return atts


def build():
    X.pattern("SR_Carbon", "forged")
    X.pattern("SR_Quilt", "quilt", thread="#2F5597", groove="#9E9D95", cell=0.4)
    X.pattern("SR_Pleat", "pleat", thread="#2F5597", groove="#9E9D95", cell=0.3)
    unwrap = rbxkit_unwrap()
    hull_set = R.build_set("Hull", [(NAME + "_Hull_LOD0", hull), (NAME + "_Deck_LOD0", deck)], unwrap, "MI_SR_Hull")
    deck_set = R.build_set("Interior", [(NAME + "_Interior_LOD0", interior), (NAME + "_Screen_LOD0", windscreen)],
                           unwrap, "MI_SR_Interior")
    eng_set = R.build_set("Engines", [(NAME + "_Engines_LOD0", engines)], unwrap, "MI_SR_Engines")
    rig_set = R.build_set("Rig", [(NAME + "_RollBar_LOD0", rollbar), (NAME + "_Rails_LOD0", rails)], unwrap, "MI_SR_Rig")
    hps = [
        R.build_hp(NAME + "_Hull_HP", [hull]),
        R.build_hp(NAME + "_Deck_HP", [deck]),
        R.build_hp(NAME + "_Interior_HP", [interior], bevel=dict(width=0.02, segments=2, angle=40)),
        R.build_hp(NAME + "_Screen_HP", [windscreen]),
        R.build_hp(NAME + "_Engines_HP", [engines], bevel=dict(width=0.015, segments=2, angle=40)),
        R.build_hp(NAME + "_RollBar_HP", [rollbar]),
        R.build_hp(NAME + "_Rails_HP", [rails]),
    ]
    col = collision()
    atts = X.empties(markers())
    # the RIB's frame offset (not our own bbox): every marker matches M_Veh_RIB's
    lod0 = hull_set + deck_set + eng_set + rig_set
    for o in lod0 + hps + [col]:
        o.data.transform(Matrix.Translation(RIB_OFF))
    for e in atts:
        e.location = e.location + RIB_OFF
    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    print("[%s] bbox lo %s hi %s" % (NAME, [round(c, 3) for c in lo], [round(c, 3) for c in hi]))

    meshes = []
    for objs, s in ((hull_set, "Hull"), (deck_set, "Interior"), (eng_set, "Engines"), (rig_set, "Rig")):
        for o in objs:
            meshes.append({"object": o, "set": s})
    meshes += [{"object": h} for h in hps] + [{"object": col}]
    wear = {"edge": 0.1, "edge_color": (0.55, 0.56, 0.57), "salt": 0.12, "salt_color": (0.66, 0.66, 0.63),
            "salt_range": (0.4, 0.85), "rust": 0.0}
    sets = [{"name": TEX, "set": s, "size": 2048, "wet": True, "wet_darken": 0.3, "wet_gloss": 0.35, "wet_streaks": 0.4,
             "cage_extrusion": 0.06, "max_ray_distance": 0.15, "wear": dict(wear)} for s in ("Hull", "Interior", "Engines", "Rig")]
    sets[2]["size"] = 1024       # the engines alone hold 130+ px/stud at 2048
    sets[1]["size"] = 4096       # helm, seats and screen: hero tier (100+ px/stud) for the 1 m view; bake at 4096
    return {
        "name": NAME,
        "budget": "rib",
        "tier": "standard",
        "dims_m": (2.85, 8.9, 2.95),
        "size_note": "Premium variant on the RIB frame: same beam, a longer bow and 15% larger outboards (8.9 m "
                     "overall); Z includes the two VHF whips raked aft on the roll-bar pod.",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_size": 2048,
        "waivers": {
            "LOD UV layout": "LOD1 / LOD2 collapse decimation moves small tube / screen-edge UV island borders (the "
                             "RIB's waiver); LODs are only seen beyond 250 studs where the maps are mip-mapped far "
                             "below the island size.",
        },
        "bake_samples": 16,
        "closeups": [
            {"name": "helm_1m", "target": [0.0, -1.0, 4.55], "dist": 3.0, "az": 192, "el": 22},
            {"name": "stripes_wordmark", "target": [4.0, 3.0, 3.3], "dist": 6, "az": 90, "el": 5},
            {"name": "rollbar_pod", "target": [0.0, AF_Y, AF_Z + 0.2], "dist": 5, "az": 20, "el": 15},
            {"name": "bow_rail", "target": [1.5, -10.5, 5.0], "dist": 6, "az": 35, "el": 25},
            {"name": "outboards", "target": [0.0, 12.5, 3.0], "dist": 6, "az": 155, "el": 14},
            {"name": "seats", "target": [0.0, 3.0, 4.6], "dist": 6, "az": 140, "el": 35},
        ],
    }


def rbxkit_unwrap():
    return X.rbxkit.smart_uv
