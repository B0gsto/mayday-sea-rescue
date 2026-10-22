"""M_Veh_Tidewalker: premium (Robux) luxury rescue catamaran on the Lifeboat greybox frame (VehicleConfig.Tidewalker,
base "Lifeboat": 17.3 m x 5.9 m, hullSize 17.7 x 7.5 x 51.9 studs, floats at x +-5.5..6.5). Generic 17 m power-cat
class, not a replica.

Frame: greybox HullRoot point (rx, ry, rz) -> Blender (-rx, rz, ry + 2.8) (keel line greybox y -2.8 at z 0), then the
bbox recentre; frame_offset.json holds the offset and the HullRoot position of the model pivot (like Builder.RIB_ORIGIN).
Markers: survivor slots 1-6 in the aft teak cockpit at the greybox's slot positions, helm and passenger seats on the
open flybridge (visible in the chase camera), floats on the config's floatPoints, tow hitch / bow point at the
greybox's, nav lamps on the hardtop and mast.

Twin slender demihulls (plumb bows, flared topsides, skegs, shafts, bronze props, rudders) in pearl white over a navy
boot stripe and graphite antifoul, gold sheer pinstripe, long tinted hull windows and portlights, gold TIDEWALKER
wordmark; bridgedeck with a wave-piercing nacelle; teak side decks, cockpit, swim platform and transom steps; sleek
white saloon with raked wraparound tinted glass, gold sill line, aft glass doors; roof overhang over the cockpit;
flybridge with a raked helm console, smoked visor, gold-spoked wheel, cream quilted helm chairs and settee; hardtop on
raked aerofoil struts with a radome mast and lights; polished stainless rails with gold caps, gold-capped cleats.

Sets (every set _Wet): Hulls (both demihulls + bridgedeck, 4096: 51 px/stud on 17 m), Deck (platforms, steps,
cockpit furniture, 2048),
Cabin (saloon, roof, 2048), Fly (flybridge, hardtop, mast, 2048), Fittings (rails, running gear, cleats, 2048).
Bake one set a run; the Hulls set with MAYDAY_BAKE_SIZE=4096.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Veh_Tidewalker \
      --steps build,lod,bake,validate,export,turntable
"""
import json
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_BoatPremium"))
import boatkit as X  # noqa: E402

R, RB, M, smooth = X.R, X.RB, X.M, X.smooth
NAME = "M_Veh_Tidewalker"
TEX = "Tidewalker"
ZK = 2.8


def gb(rx, ry, rz):
    """Lifeboat greybox (HullRoot space) -> this model's Blender frame (before the recentre)."""
    return (-rx, rz, ry + ZK)


R.PALETTE.update({
    "TW_Pearl": ("#E6E4DE", 0.18, 0.0),
    "TW_Antifoul": ("#2B323C", 0.72, 0.0),
    "TW_Boot": ("#1F2B3D", 0.24, 0.0),
    "TW_Teak": ("#8E6542", 0.62, 0.0),
    "TW_DeckWhite": ("#D9D8D2", 0.58, 0.0),
    "TW_Glass": ("#33465A", 0.02, 0.0),
    "TW_Gold": ("#E2BE6A", 0.14, 1.0),
    "TW_Leather": ("#D8CEBB", 0.48, 0.0),
    "TW_Pleat": ("#D8CEBB", 0.48, 0.0),
    "TW_Navy": ("#24303F", 0.42, 0.0),
    "TW_Bronze": ("#C49A62", 0.30, 1.0),
    "TW_Grey": ("#9A9D9F", 0.45, 0.0),
    "Stainless": ("#E2E5E7", 0.08, 1.0),
})
R.BUMP_ONLY.pop("Stainless", None)
R.PROC.update({
    "TW_Pearl": dict(mottle=(1.0, 0.02), streak=("#D2D1CB", 0.10), salt=("#D6D4CD", 0.05), rough_var=0.04),
    "TW_Antifoul": dict(mottle=(3, 0.08), grime=("#232931", 0.25), streak=("#3A424C", 0.18), rough_var=0.08),
    "TW_Boot": dict(mottle=(2, 0.03), rough_var=0.04),
    "TW_Teak": dict(mottle=(2, 0.05), grime=("#6E5236", 0.15), rough_var=0.06),
    "TW_DeckWhite": dict(mottle=(1.5, 0.04), grime=("#BEBDB6", 0.18), rough_var=0.06, bump=("diamond", 0.5, 6)),
    "TW_Leather": dict(mottle=(4, 0.03), rough_var=0.05, bump=("grain", 0.06, 220)),
    "TW_Pleat": dict(mottle=(4, 0.03), rough_var=0.05, bump=("grain", 0.06, 220)),
    "TW_Navy": dict(mottle=(4, 0.04), rough_var=0.05, bump=("grain", 0.1, 140)),
    "TW_Grey": dict(mottle=(2, 0.04), rough_var=0.05),
})
R.HULL_BANDS = ((2.95, "TW_Antifoul"), (3.42, "TW_Boot"), (99.0, "TW_Pearl"))   # object z (studs) upper bounds

# --------------------------------------------------------------------------- layout (studs, Blender frame)
BOW, STERN = -25.9, 24.4
HX = 6.3                       # demihull centreline |x|
WM = 2.3                       # demihull half-beam at the sheer
WL = 3.0
Z_UNDER, Z_SOLE = 4.9, 5.75    # bridgedeck underside / cockpit sole (greybox deck y 2.95)
Y_FWD = -21.0                  # bridgedeck / foredeck forward edge
SAL_AFT = 5.0                  # saloon aft bulkhead
Z_ROOF = 12.4                  # saloon roof / flybridge floor
Z_HT = 18.6                    # hardtop underside
MAST = 2.3                     # radar mast height on the hardtop


def u_(y):
    return min(1.0, max(0.0, (y - BOW) / (STERN - BOW)))


def half_w(y):
    u = u_(y)
    w = WM * (1 - (1 - min(1.0, u / 0.42)) ** 1.8)
    if u > 0.86:
        w *= 1 - 0.06 * (u - 0.86) / 0.14
    return max(w, 0.12)


def sheer_z(y):
    return 5.9 + 1.7 * max(0.0, (0.5 - u_(y)) / 0.5) ** 1.8


def keel_z(y):
    u = u_(y)
    # forefoot rises into the plumb stem; the run rises aft so the props sit in clear water above the skeg line
    return 0.3 + 1.4 * max(0.0, (0.16 - u) / 0.16) ** 2 + 2.0 * max(0.0, (u - 0.7) / 0.3) ** 1.4


def hull_half(y):
    """Outboard half of a demihull section, sheer -> keel: [(x', z)] (x' outboard of the hull centreline)."""
    w, zs, zk = half_w(y), sheer_z(y), keel_z(y)
    s = min(1.0, w / 1.2)
    u = u_(y)
    fwl = 0.74 - 0.24 * (1 - min(1.0, u / 0.35))       # flared topsides, finer waterline entry forward
    f = fwl / 0.74
    # knuckle at z 4.3 with a spray-chine lip below it (a crisp line on both faces of each hull)
    return [(w - 0.08 * s, zs), (w, zs - 0.14), (0.955 * w, 4.3), (0.955 * w + 0.06 * s, 4.2), (0.925 * w, 4.1),
            (fwl * w, WL), (0.66 * f * w, zk + 1.0),
            (0.46 * f * w, zk + 0.42), (0.22 * f * w, zk + 0.1), (0.0, zk)]


def outboard_x(y, z):
    """x' on the outboard topside at height z (between the waterline and the sheer)."""
    pts = hull_half(y)[:3] + hull_half(y)[5:6]
    for (xa, za), (xb, zb) in zip(pts[1:], pts[:-1]):
        if za <= z <= zb:
            t = (z - za) / max(zb - za, 1e-6)
            return xa + (xb - xa) * t
    return pts[0][0]


def hull_ring(y, sx):
    """Closed ring of the demihull at x = sx * HX: outboard topside, keel, inboard topside, crowned top (teak)."""
    h = hull_half(y)
    w, zs = half_w(y), sheer_z(y)
    pts = [(x, z) for x, z in h] + [(-x, z) for x, z in reversed(h[:-1])]
    top = [(-0.5 * w, zs + 0.07), (0.0, zs + 0.1), (0.5 * w, zs + 0.07)]
    pts += top
    return [Vector((sx * (HX + x), y, z)) for x, z in pts], len(h) * 2 - 2


def hull_stations(hi):
    ys = [BOW + 0.02, BOW + 0.2, BOW + 0.5, BOW + 0.9, BOW + 1.4, BOW + 2.0]
    y = ys[-1]
    step = 0.9 if hi else 1.6
    while y < STERN - 0.05:
        y += step
        ys.append(min(y, STERN))
    return sorted(set(ys))


def demihull(g, sx):
    rings = []
    ntop = None
    for y in hull_stations(g.hi):
        r, nside = hull_ring(y, sx)
        rings.append(r)
        ntop = nside
    # rounded plumb stem: two closing rings ahead of the first station
    r0 = rings[0]
    rings = [[Vector((sx * HX + (p.x - sx * HX) * f, BOW - dy, p.z)) for p in r0] for f, dy in ((0.0, 0.16), (0.5, 0.1))] \
        + rings

    def mat(i, j):
        return "HullBody" if j < ntop else "TW_Teak"
    fs = g.rings(rings, M(g, "HullBody"), closed=True, recalc=False, matfn=mat if g.hi else None)
    g.orient(fs, lambda c, sx=sx: Vector((c.x - sx * HX, -2.0 if c.y < BOW + 0.2 else 0.0, c.z - 3.2)))
    tv = [g.bm.verts.new(p) for p in rings[-1]]
    f = g.face(tv, M(g, "TW_Pearl"))
    if f:
        import bmesh
        res = bmesh.ops.triangulate(g.bm, faces=[f], quad_method="BEAUTY", ngon_method="EAR_CLIP")
        g.orient(res["faces"], lambda c: Vector((0, 1, 0)))
    # skeg keel
    prof = [(-12.0, keel_z(-12.0) + 0.4), (-9.0, 0.0), (18.5, 0.0), (19.6, 1.0), (19.0, 1.9), (-12.0, 0.75)]
    R.extrude_profile(g, prof, sx * HX - 0.1, sx * HX + 0.1, M(g, "TW_Antifoul"), bev=0.03)
    if g.hi:
        hull_decals(g, sx)


OFF = 0.012


def out_pt(sx, y, z, off=OFF):
    """Point on the outboard topside of the sx hull (outboard is +X on the port hull, -X on starboard)."""
    return Vector((sx * (HX + outboard_x(y, z) + off), y, z))


def hull_decals(g, sx):
    out = (lambda c, sx=sx: Vector((sx, 0, 0)))
    y0, y1 = BOW + 1.0, STERN - 0.05
    # gold sheer pinstripe following the sheer
    X.patch(g, lambda a, b: out_pt(sx, y0 + (y1 - y0) * a, sheer_z(y0 + (y1 - y0) * a) - 0.42 + 0.17 * b),
            90, 1, "TW_Gold", out)
    # long tapered hull windows (owner cabins) with a gold surround, and three portlights forward
    for ya, yb, zl, zh in ((-11.5, 2.5, 4.55, 5.25), (4.0, 9.5, 4.6, 5.2)):
        def win(a, b, ya=ya, yb=yb, zl=zl, zh=zh, grow=0.0):
            y = ya + (yb - ya) * a
            taper = math.sin(math.pi * min(1.0, a / 0.12 if a < 0.5 else (1 - a) / 0.12) / 2) if (a < 0.12 or a > 0.88) else 1.0
            zm = (zl + zh) / 2 + 0.12 * (a - 0.5)
            hh = (zh - zl) / 2 * (0.35 + 0.65 * taper) + grow
            return out_pt(sx, y, zm - hh + 2 * hh * b, OFF + (0.0 if grow else 0.006))
        X.patch(g, lambda a, b, win=win: win(a, b, grow=0.06), 40, 2, "TW_Gold", out)
        X.patch(g, win, 40, 2, "TW_Glass", out)
    for y in (-17.0, -15.6, -14.2):
        z = sheer_z(y) - 0.9
        for r, mat, off in ((0.3, "TW_Gold", OFF), (0.24, "TW_Glass", OFF + 0.006)):
            X.patch(g, lambda a, b, y=y, z=z, r=r, off=off: out_pt(sx, y + r * b * math.cos(2 * math.pi * a),
                                                                   z + r * b * math.sin(2 * math.pi * a), off),
                    16, 1, mat, out)
    # gold wordmark aft of the windows, reading bow -> stern
    X.text_on(g, "TIDEWALKER", 0.85, lambda u, v: out_pt(sx, 15.5 + sx * u, 5.05 + v, OFF + 0.004), "TW_Gold", out,
              scale_x=1.1)
    X.text_on(g, "PORT GALE", 0.32, lambda u, v: out_pt(sx, 15.5 + sx * u, 4.55 + v, OFF + 0.004), "TW_Boot", out)


def hull_port(g):
    demihull(g, 1)


def hull_stbd(g):
    demihull(g, -1)


# --------------------------------------------------------------------------- bridgedeck, platforms, cockpit
BX = 4.45


def bridge_top(y):
    return Z_SOLE + 1.25 * smooth(-14.5, Y_FWD, y)


def bridge_ring(y, hi):
    """Bridgedeck section: crowned top, underside with the wave-piercing nacelle; the underside sweeps up to a
    rounded lip at the foredeck nose (y < Y_FWD: the lip itself)."""
    nx = 10 if hi else 6
    lip = max(0.0, (Y_FWD - y) / 0.3)
    zt = bridge_top(max(y, Y_FWD)) - 0.06 * lip
    top = [Vector((BX - 2 * BX * k / nx, y, zt)) for k in range(nx + 1)]
    nac = 0.95 * smooth(-4.0, -18.0, y)
    ramp = smooth(Y_FWD + 5.0, Y_FWD, y) ** 0.8
    bot = []
    for k in range(nx + 1):
        x = -BX + 2 * BX * k / nx
        f = max(0.0, 1 - (x / 2.4) ** 2)
        zb = Z_UNDER - nac * f ** 0.7 + 0.45 * max(0.0, (abs(x) - 3.2) / (BX - 3.2)) ** 1.5   # fillet into the hulls
        zb = zb + (zt - 0.35 - zb) * ramp
        bot.append(Vector((x, y, zb + (zt - 0.1 - zb) * lip)))
    return top + bot


def bridgedeck(g):
    ys = [Y_FWD - 0.3, Y_FWD - 0.15, Y_FWD, Y_FWD + 0.4, Y_FWD + 1.0, Y_FWD + 1.8, Y_FWD + 2.8, Y_FWD + 4.0]
    y = ys[-1]
    while y < STERN:
        y += 1.0 if g.hi else 2.0
        ys.append(min(y, STERN))
    rings = [bridge_ring(y, g.hi) for y in ys]
    nt = len(rings[0]) // 2

    def mat(i, j):
        yc = (ys[i] + ys[i + 1]) / 2
        if j < nt - 1:
            return "TW_Teak" if yc > SAL_AFT - 0.5 else "TW_DeckWhite"
        return "TW_Pearl"
    g.rings(rings, M(g, "TW_Pearl"), closed=True, cap0=True, cap1=True, recalc=True, matfn=mat if g.hi else None)


def platforms(g):
    # aft panel closing the bridgedeck to the platform, hydraulic arms, a fold-down swim ladder
    R.box(g, (0, STERN - 0.1, 4.55), (2 * BX - 0.2, 0.25, 0.9), M(g, "TW_Pearl"), bev=0.05)
    for sx in (1, -1):
        R.box(g, (sx * 3.2, STERN + 0.2, 4.45), (0.25, 0.8, 0.5), M(g, "Stainless"), bev=0.04)
        R.tube(g, [(sx * 2.6, STERN + 0.05, 4.7), (sx * 2.6, STERN + 0.9, 4.15)], 0.07, M(g, "Stainless"), 10 if g.hi else 6)
    for dx in (-0.35, 0.35):
        R.tube(g, [(dx, STERN + 1.3, 4.2), (dx, STERN + 1.55, 3.9), (dx, STERN + 1.55, 2.6)], 0.045, M(g, "Stainless"),
               10 if g.hi else 6, fillet=0.15, fseg=2)
    for z in (3.6, 3.1, 2.65):
        R.box(g, (0, STERN + 1.55, z), (0.75, 0.18, 0.06), M(g, "TW_Teak"), bev=0.02)
    # swim platform between the hulls (teak), with a stainless tow eye under its aft edge (ATT_TowHitch)
    R.box(g, (0, STERN + 0.75, 4.05), (2 * BX + 0.6, 1.5, 0.3), M(g, "TW_Teak"), bev=0.06)
    R.box(g, (0, STERN + 1.42, 3.72), (0.5, 0.16, 0.5), M(g, "Stainless"), bev=0.04)
    R.tube(g, [(-0.16, STERN + 1.5, 3.55), (-0.12, STERN + 1.5, 3.36), (0.12, STERN + 1.5, 3.36), (0.16, STERN + 1.5, 3.55)],
           0.045, M(g, "Stainless"), 8, fillet=0.08, fseg=2)
    # transom steps down each hull to the platform
    for sx in (1, -1):
        for k, (dy, z) in enumerate(((0.4, 5.35), (0.95, 4.8))):
            R.box(g, (sx * HX, STERN + dy, z), (2 * WM * 0.9, 0.6, 0.22), M(g, "TW_Teak"), bev=0.05)
            R.box(g, (sx * HX, STERN + dy - 0.05, z - 0.45), (2 * WM * 0.86, 0.5, 0.7), M(g, "TW_Pearl"), bev=0.05)


def cockpit(g):
    seg = 24 if g.hi else 12
    # side settees outboard of the survivor slots (x +-3.4), teak-framed, cream quilted cushions
    for sx in (1, -1):
        x = sx * 5.05
        for yc, ln in ((8.9, 5.4), (14.5, 2.6)):     # split for the flybridge ladder (y 11.8 - 12.9)
            R.box(g, (x, yc, Z_SOLE + 0.65), (1.3, ln, 1.3), M(g, "TW_Navy"), bev=0.04)
            X.cushion(g, (x, yc, Z_SOLE + 1.47), (1.25, ln - 0.15, 0.36), "TW_Leather", pipe="TW_Gold")
            X.cushion(g, (x + sx * 0.6, yc, Z_SOLE + 2.2), (0.3, ln - 0.3, 1.15), "TW_Pleat", pipe="TW_Gold", p=4.0)
            R.box(g, (x, yc, Z_SOLE + 0.04), (1.32, ln + 0.02, 0.08), M(g, "TW_Gold"), bev=0.02)
    # aft settee across, a teak cocktail table on a stainless pedestal
    R.box(g, (0, 19.2, Z_SOLE + 0.65), (6.2, 1.3, 1.3), M(g, "TW_Navy"), bev=0.04)
    X.cushion(g, (0, 19.2, Z_SOLE + 1.47), (6.0, 1.25, 0.36), "TW_Leather", pipe="TW_Gold")
    X.cushion(g, (0, 19.8, Z_SOLE + 2.2), (5.9, 0.3, 1.15), "TW_Pleat", pipe="TW_Gold", p=4.0)
    R.lathe(g, (0, 16.6, Z_SOLE), (0, 0, 1), [(0.0, 0.0), (0.5, 0.0), (0.5, 0.06), (0.12, 0.12), (0.1, 2.0), (0.0, 2.0)],
            seg, M(g, "Stainless"))
    R.loft(g, [(0, 16.6, Z_SOLE + 2.0, 1.5, 0.9), (0, 16.6, Z_SOLE + 2.18, 1.5, 0.9)], seg * 2, M(g, "TW_Teak"), p=2.6)
    # aft wet bar against the saloon (galley unit) under the roof overhang
    R.box(g, (3.6, SAL_AFT + 0.7, Z_SOLE + 1.4), (3.0, 1.2, 2.8), M(g, "TW_Pearl"), bev=0.08)
    R.box(g, (3.6, SAL_AFT + 0.7, Z_SOLE + 2.84), (3.1, 1.3, 0.1), M(g, "TW_Grey"), bev=0.03)


def deck_parts(g):
    platforms(g)
    cockpit(g)


# --------------------------------------------------------------------------- saloon and roof
def plan(z):
    """Saloon plan ring at height z: (y_front, y_aft, half-width, front corner radius)."""
    t = (z - 5.7) / (12.1 - 5.7)
    yf = -14.5 + 4.6 * smooth(0.18, 1.0, t) ** 0.9
    hw = 7.05 - 0.4 * t
    return yf, SAL_AFT, hw, 3.2 - 0.6 * t


def plan_ring(z, n_side, n_corner):
    yf, ya, hw, rf = plan(z)
    ra = 0.5
    pts = []
    # starboard aft corner -> starboard side -> front -> port side -> port aft corner -> aft face
    for k in range(n_side + 1):
        pts.append(Vector((-hw, ya - ra - (ya - ra - (yf + rf)) * k / n_side, z)))
    for k in range(1, n_corner):
        a = math.pi + (math.pi / 2) * k / n_corner
        pts.append(Vector((-hw + rf + rf * math.cos(a), yf + rf + rf * math.sin(a), z)))
    nf = 6
    for k in range(nf + 1):
        pts.append(Vector((-hw + rf + (2 * hw - 2 * rf) * k / nf, yf, z)))
    for k in range(1, n_corner):
        a = 1.5 * math.pi + (math.pi / 2) * k / n_corner
        pts.append(Vector((hw - rf + rf * math.cos(a), yf + rf + rf * math.sin(a), z)))
    for k in range(n_side + 1):
        pts.append(Vector((hw, yf + rf + (ya - ra - yf - rf) * k / n_side, z)))
    for k in range(1, 3):
        a = (math.pi / 2) * k / 3
        pts.append(Vector((hw - ra + ra * math.cos(a), ya - ra + ra * math.sin(a), z)))
    na = 8
    for k in range(na + 1):
        pts.append(Vector((hw - ra - (2 * hw - 2 * ra) * k / na, ya, z)))
    for k in range(1, 3):
        a = math.pi / 2 + (math.pi / 2) * k / 3
        pts.append(Vector((-hw + ra + ra * math.cos(a), ya - ra + ra * math.sin(a), z)))
    return pts


Z_SILL, Z_HEAD = 7.35, 11.45


def saloon(g):
    ns, nc = (14, 8) if g.hi else (8, 5)
    zs = [5.65, Z_SILL, Z_SILL + 0.1, Z_SILL + 0.18, 9.4, Z_HEAD - 0.08, Z_HEAD, 12.1]
    rings = [plan_ring(z, ns, nc) for z in zs]

    def mat(i, j):
        if i == 1:
            return "TW_Gold"
        if i in (2, 5):
            return "Stainless"                              # polished window frames
        if i in (0, 6):
            return "TW_Pearl"
        a, b = rings[i][j], rings[i][(j + 1) % len(rings[i])]
        c = (a + b) / 2
        hw = plan(c.z)[2]
        if abs(c.y - SAL_AFT) < 0.05:                       # aft glass doors: mullions
            return "TW_Pearl" if any(abs(c.x - m) < 0.22 for m in (-4.6, -1.6, 1.6, 4.6)) else "TW_Glass"
        yf, _, _, rf = plan(c.z)
        if abs(abs(c.x) - hw) < 0.05:                       # sides: A-pillars at the corner arcs, two slim pillars
            return "TW_Pearl" if any(abs(c.y - m) < 0.3 for m in (yf + rf + 0.3, -3.5, 1.8)) else "TW_Glass"
        if abs(c.y - yf) < 0.05:                            # windscreen: centre mullion
            return "TW_Pearl" if abs(c.x) < 0.2 else "TW_Glass"
        return "TW_Glass"
    g.rings(rings, M(g, "TW_Pearl"), closed=True, recalc=True, matfn=mat if g.hi else None)


def roof(g):
    """Roof slab over the saloon and the aft overhang (flybridge floor on top), rounded fascia, two aft posts."""
    n = 30 if g.hi else 16
    yf, hw = -10.6, 7.05
    ya = 12.0

    def ring(z, grow):
        pts = []
        for k in range(n + 1):           # front: superellipse nose
            a = math.pi * k / n
            x = (hw + grow) * math.cos(a)
            pts.append(Vector((x, yf - grow + (abs(math.cos(a)) ** 3.5) * 3.0, z)))
        pts.append(Vector((-(hw + grow), ya + grow - 0.4, z)))
        pts.append(Vector((-(hw + grow) + 0.4, ya + grow, z)))
        pts.append(Vector(((hw + grow) - 0.4, ya + grow, z)))
        pts.append(Vector(((hw + grow), ya + grow - 0.4, z)))
        return pts
    rings = [ring(12.0, 0.0), ring(12.18, 0.18), ring(Z_ROOF - 0.04, 0.2), ring(Z_ROOF, 0.12)]
    g.rings(rings, M(g, "TW_Pearl"), closed=True, cap0=True, cap1=True, recalc=True)
    # gold pinstripe round the fascia (HP)
    if g.hi:
        r0, r1 = ring(12.22, 0.205), ring(12.27, 0.205)
        g.rings([r0, r1], "TW_Gold", closed=True, recalc=True)
    for sx in (1, -1):
        R.tube(g, [(sx * 6.55, ya - 0.5, Z_SOLE), (sx * 6.55, ya - 0.5, 12.0)], 0.16, M(g, "Stainless"), 16 if g.hi else 10)
        R.lathe(g, (sx * 6.55, ya - 0.5, Z_SOLE), (0, 0, 1), [(0.0, 0.0), (0.32, 0.0), (0.32, 0.05), (0.18, 0.15), (0.0, 0.16)],
                16 if g.hi else 10, M(g, "TW_Gold"))


# --------------------------------------------------------------------------- flybridge and hardtop
Y_HELM = -3.0
Z_SEAT = Z_ROOF + 1.55          # helm chair cushion top


def chair(g, x, y, wide=1.0):
    seg = 28 if g.hi else 14
    R.lathe(g, (x, y, Z_ROOF), (0, 0, 1), [(0.0, 0.0), (0.45, 0.0), (0.45, 0.05), (0.12, 0.12), (0.1, 0.9), (0.0, 0.9)],
            seg, M(g, "Stainless"))
    R.lathe(g, (x, y, Z_ROOF + 0.55), (0, 0, 1), [(0.03, -0.03), (0.42, -0.03), (0.42, 0.03), (0.03, 0.03)], seg,
            M(g, "TW_Gold"))
    secs = [(x, y, Z_ROOF + 0.9, 0.8 * wide, 0.7), (x, y, Z_ROOF + 1.05, 0.86 * wide, 0.76),
            (x, y, Z_SEAT - 0.12, 0.86 * wide, 0.76), (x, y, Z_SEAT, 0.78 * wide, 0.68)]
    R.loft(g, secs, seg, M(g, "TW_Leather"), p=3.0,
           matfn=(lambda i, j: ("TW_Navy", "TW_Leather", "TW_Leather")[i]) if g.hi else None)
    by = y + 0.7
    secs = [(x, by, Z_SEAT - 0.1, 0.8 * wide, 0.22), (x, by + 0.05, Z_SEAT + 1.0, 0.84 * wide, 0.26),
            (x, by + 0.1, Z_SEAT + 1.6, 0.66 * wide, 0.22), (x, by + 0.12, Z_SEAT + 1.75, 0.45 * wide, 0.15)]
    R.loft(g, secs, seg, M(g, "TW_Leather"), p=3.2,
           matfn=(lambda i, j: "TW_Pleat" if (j > seg // 2 and i < 2) else "TW_Leather") if g.hi else None)
    for sx in (1, -1):    # gold-tipped armrests
        R.box(g, (x + sx * 0.88 * wide, y + 0.1, Z_SEAT + 0.42), (0.18, 1.0, 0.16), M(g, "TW_Leather"), bev=0.06)
        R.box(g, (x + sx * 0.88 * wide, y - 0.42, Z_SEAT + 0.42), (0.19, 0.08, 0.17), M(g, "TW_Gold"), bev=0.02)


def flybridge(g):
    # flybridge sole: teak inlay on the roof
    R.box(g, (0, 1.5, Z_ROOF + 0.02), (12.6, 18.0, 0.05), M(g, "TW_Teak"), bev=0.0)
    # helm console: raked white console with a navy dash, screens, gold-spoked wheel
    prof = [(-6.4, Z_ROOF), (-6.4, Z_ROOF + 1.6), (-5.6, Z_ROOF + 2.15), (-4.9, Z_ROOF + 2.25), (-4.55, Z_ROOF + 1.7),
            (-4.55, Z_ROOF)]
    R.extrude_profile(g, prof, -3.0, 3.0, M(g, "TW_Pearl"),
                      matfn=(lambda i, j: "TW_Navy" if j in (2, 3) else "TW_Pearl") if g.hi else None, bev=0.06)
    a, c = Vector((0, -4.9, Z_ROOF + 2.25)), Vector((0, -4.55, Z_ROOF + 1.7))
    tdir = (a - c).normalized()
    n = Vector((0, -tdir.z, tdir.y))
    if n.y < 0:
        n = -n
    rot = Matrix((Vector((1, 0, 0)), tdir, n)).transposed()
    for x in (-1.45, 1.45):
        p = c.lerp(a, 0.5) + Vector((x, 0, 0)) + n * 0.02
        R.box(g, tuple(p), (1.4, 0.5, 0.04), M(g, "BlackPlastic"), rot=rot, bev=0.01)
        R.box(g, tuple(p + n * 0.022), (1.3, 0.42, 0.01), M(g, "Screen"), rot=rot, bev=0.0)
        if g.hi:
            R.box(g, tuple(p + n * 0.028), (1.0, 0.2, 0.004), "ScreenChart", rot=rot, bev=0.0)
    ax = Vector((0, 1, 0.45)).normalized()
    wc = Vector((0, -4.25, Z_ROOF + 2.3))
    R.tube(g, [tuple(c.lerp(a, 0.45) + n * 0.02), tuple(wc - ax * 0.08)], 0.07, M(g, "Stainless"), 12 if g.hi else 8)
    X.wheel(g, wc, ax, 0.62, 0.06, M(g, "TW_Navy"), M(g, "TW_Gold"), M(g, "TW_Gold"), seg=40 if g.hi else 26)
    R.box(g, (1.95, -4.75, Z_ROOF + 1.95), (0.5, 0.5, 0.3), M(g, "TW_Navy"), bev=0.05)
    for dx in (-0.1, 0.1):
        R.tube(g, [(1.95 + dx, -4.75, Z_ROOF + 2.05), (1.95 + dx, -4.5, Z_ROOF + 2.55)], 0.03, M(g, "Stainless"), 8)
        R.lathe(g, (1.95 + dx, -4.48, Z_ROOF + 2.58), (0, 0, 1), [(0.0, -0.05), (0.07, -0.04), (0.07, 0.04), (0.0, 0.05)],
                10, M(g, "TW_Gold"))
    # smoked visor wrapping the console front, gold top trim
    nv = 20 if g.hi else 10
    base, top = [], []
    for k in range(nv + 1):
        s = -1 + 2 * k / nv
        base.append(Vector((2.95 * s, -6.0 + 1.3 * abs(s) ** 2.2, Z_ROOF + 1.85)))
        top.append(Vector((2.85 * s, -5.3 + 1.2 * abs(s) ** 2.2, Z_ROOF + 2.9 - 0.2 * abs(s) ** 2)))
    cols = []
    for k, (p, q) in enumerate(zip(base, top)):
        tr = base[min(nv, k + 1)] - base[max(0, k - 1)]
        nrm = tr.cross(q - p).normalized()
        if nrm.dot(p - Vector((0, -3.0, p.z))) < 0:
            nrm = -nrm
        cols.append([p, q, q - nrm * 0.04, p - nrm * 0.04])
    g.rings(cols, M(g, "TW_Glass"), closed=True, cap0=True, cap1=True)
    R.sweep(g, top, R.circle_profile(0.045, 8 if g.hi else 5), M(g, "TW_Gold"), cap0=True, cap1=True)
    # helm chairs (driver centre, two companions) and the aft settee (third passenger)
    chair(g, 0.0, Y_HELM)
    for x in (2.3, -2.3):
        chair(g, x, Y_HELM, 0.95)
    R.box(g, (0, 6.6, Z_ROOF + 0.75), (7.0, 1.4, 1.5), M(g, "TW_Navy"), bev=0.04)
    X.cushion(g, (0, 6.6, Z_SEAT - 0.17), (6.8, 1.35, 0.36), "TW_Leather", pipe="TW_Gold")
    X.cushion(g, (0, 7.3, Z_SEAT + 0.6), (6.7, 0.3, 1.25), "TW_Pleat", pipe="TW_Gold", p=4.0)
    R.box(g, (0, 6.6, Z_ROOF + 0.04), (7.05, 1.45, 0.08), M(g, "TW_Gold"), bev=0.02)
    R.lathe(g, (0, 3.8, Z_ROOF), (0, 0, 1), [(0.0, 0.0), (0.45, 0.0), (0.45, 0.05), (0.1, 0.12), (0.09, 1.25), (0.0, 1.25)],
            24 if g.hi else 12, M(g, "Stainless"))
    R.loft(g, [(0, 3.8, Z_ROOF + 1.25, 2.2, 0.9), (0, 3.8, Z_ROOF + 1.4, 2.2, 0.9)], 40 if g.hi else 20, M(g, "TW_Teak"), p=2.4)
    # ladder from the cockpit to the roof overhang (aft, port)
    lx, y0, y1 = 5.2, 12.9, 11.85
    for dx in (-0.45, 0.45):
        R.tube(g, [(lx + dx, y0, Z_SOLE), (lx + dx, y1, Z_ROOF), (lx + dx, y1 - 0.15, Z_ROOF + 1.1)], 0.06,
               M(g, "Stainless"), 10 if g.hi else 6, fillet=0.3, fseg=3)
    for k in range(1, 9):
        t = k / 9
        R.box(g, (lx, y0 + (y1 - y0) * t, Z_SOLE + (Z_ROOF - Z_SOLE) * t), (0.9, 0.36, 0.08), M(g, "TW_Teak"), bev=0.02)


def hardtop(g):
    n = 30 if g.hi else 16
    yf, ya, hw = -5.9, 9.6, 6.4

    def ring(z, grow, lift=0.0):
        pts = []
        for k in range(n + 1):
            a = math.pi * k / n
            x = (hw + grow) * math.cos(a)
            pts.append(Vector((x, yf - grow + (abs(math.cos(a)) ** 3.0) * 3.4, z + lift * (1 - abs(math.cos(a))))))
        pts += [Vector((-(hw + grow), ya + grow - 0.6, z)), Vector((-(hw + grow) + 0.6, ya + grow, z)),
                Vector(((hw + grow) - 0.6, ya + grow, z)), Vector(((hw + grow), ya + grow - 0.6, z))]
        return pts
    rings = [ring(Z_HT, 0.0), ring(Z_HT + 0.15, 0.14), ring(Z_HT + 0.42, 0.1, 0.12), ring(Z_HT + 0.5, -0.1, 0.18)]
    g.rings(rings, M(g, "TW_Pearl"), closed=True, cap0=True, cap1=True, recalc=True)
    if g.hi:
        g.rings([ring(Z_HT + 0.2, 0.145), ring(Z_HT + 0.25, 0.143)], "TW_Gold", closed=True, recalc=True)
    # raked aerofoil struts, gold feet
    for sx in (1, -1):
        for (y0, y1) in ((-1.6, 0.2), (8.0, 9.0)):
            p0 = Vector((sx * 5.9, y0, Z_ROOF))
            p1 = Vector((sx * 5.7, y1, Z_HT + 0.05))
            path = [p0.lerp(p1, k / 6) for k in range(7)]
            R.sweep(g, path, [(b, -a) for a, b in X.aerofoil(0.7, 0.28, 10 if g.hi else 6)], M(g, "TW_Pearl"),
                    cap0=True, cap1=True)
            R.box(g, tuple(p0 + Vector((0, 0, 0.06))), (0.5, 0.9, 0.12), M(g, "TW_Gold"), bev=0.03)
    # radar mast on the hardtop: radome, masthead, beacon, two whips; searchlight at the front, nav lights
    zt = Z_HT + 0.5
    R.loft(g, [(0, 3.2, zt, 0.6, 1.3), (0, 3.4, zt + MAST, 0.32, 0.95)], 16 if g.hi else 10, M(g, "TW_Pearl"), p=2.6)
    R.box(g, (0, 3.9, zt + MAST + 0.03), (2.0, 0.3, 0.08), M(g, "Stainless"), bev=0.02)
    R.lathe(g, (0, 2.75, zt + MAST), (0, 0, 1),
            [(0.1, 0), (0.9, 0.03), (0.92, 0.12), (0.92, 0.45), (0.75, 0.6), (0.3, 0.7), (0.0, 0.72)],
            40 if g.hi else 22, M(g, "TW_Pearl"))
    for x, lens, h in ((-0.75, "LensWhite", 0.25), (0.75, "LensBlue", 0.38)):
        R.box(g, (x, 3.9, zt + MAST + 0.09), (0.3, 0.3, 0.06), M(g, "Stainless"))
        R.lathe(g, (x, 3.9, zt + MAST + 0.12), (0, 0, 1),
                [(0.13, 0), (0.13, 0.08), (0.11, 0.09), (0.11, 0.09 + h), (0.08, 0.12 + h), (0.0, 0.14 + h)],
                16 if g.hi else 10, M(g, lens), matfn=(lambda i, j, lens=lens: "BlackPlastic" if i < 1 or i >= 3 else lens)
                if g.hi else None)
    for sx in (1, -1):
        b = Vector((sx * 3.5, 7.8, zt - 0.05))
        R.lathe(g, tuple(b), (0, 0.3, 1), [(0.06, 0.0), (0.06, 0.3), (0.04, 0.35), (0.0, 0.36)], 8, M(g, "Stainless"))
        R.lathe(g, tuple(b + Vector((0, 0.1, 0.35))), (0, 0.3, 1), [(0.035, 0.0), (0.012, 3.0), (0.0, 3.02)], 6,
                M(g, "TW_Pearl"))
    R.lathe(g, (0, yf + 0.4, zt - 0.08), (0, 0, 1), [(0.1, 0), (0.1, 0.3), (0.0, 0.31)], 10, M(g, "Stainless"))
    R.lathe(g, (0, yf + 0.15, zt + 0.42), (0, -1, 0),
            [(0.0, -0.2), (0.22, -0.2), (0.25, 0.0), (0.25, 0.16), (0.22, 0.19), (0.0, 0.19)], 20 if g.hi else 12,
            M(g, "Stainless"), matfn=(lambda i, j: "LensWhite" if i >= 4 else "Stainless") if g.hi else None)
    for sx, lens in ((1, "LensRed"), (-1, "LensGreen")):
        R.box(g, (sx * 6.45, -3.2, Z_HT + 0.25), (0.14, 0.5, 0.2), M(g, "Stainless"))
        R.box(g, (sx * 6.53, -3.2, Z_HT + 0.25), (0.03, 0.4, 0.13), M(g, lens))
    R.box(g, (0, ya + 0.02, Z_HT + 0.25), (0.3, 0.12, 0.16), M(g, "BlackPlastic"))
    R.box(g, (0, ya + 0.09, Z_HT + 0.25), (0.22, 0.02, 0.1), M(g, "LensWhite"))


def fly_parts(g):
    flybridge(g)


# --------------------------------------------------------------------------- fittings
def rail_run(g, pts_base, h, seg):
    """Polished stainless stanchions on pts_base (gold bases), a gold cap rail at height h, a stainless mid rail."""
    tops = []
    for p in pts_base:
        p = Vector(p)
        R.tube(g, [tuple(p), tuple(p + Vector((0, 0, h)))], 0.075, M(g, "Stainless"), seg)
        R.lathe(g, tuple(p), (0, 0, 1), [(0.0, 0.0), (0.14, 0.0), (0.14, 0.04), (0.07, 0.1), (0.0, 0.11)], seg,
                M(g, "TW_Gold"))
        tops.append(tuple(p + Vector((0, 0, h))))
    R.tube(g, tops, 0.1, M(g, "TW_Gold"), seg, fillet=0.8, fseg=4)          # polished gold cap rail
    mids = [tuple(Vector(t) - Vector((0, 0, h * 0.5))) for t in tops]
    R.tube(g, mids, 0.045, M(g, "Stainless"), seg, fillet=0.8, fseg=4)


def rails(g):
    seg = 10 if g.hi else 6
    for sx in (1, -1):
        ys = [-21.5, -18.5, -15.5, -12.5, -9.5, -6.5, -3.5, -0.5, 2.5]
        base = [(sx * (HX + half_w(y) - 0.25), y, sheer_z(y) + 0.08) for y in ys]
        rail_run(g, base, 2.4, seg)
        ys2 = [6.5, 9.5, 12.5, 15.5, 18.5, 21.5, 23.6]
        base = [(sx * (HX + half_w(y) - 0.25), y, sheer_z(y) + 0.08) for y in ys2]
        rail_run(g, base, 2.4, seg)
    # bow pulpit across the foredeck front, flybridge rails aft and at the sides
    base = [(x, Y_FWD + 0.3, bridge_top(Y_FWD) + 0.02) for x in (-3.9, -1.3, 1.3, 3.9)]
    rail_run(g, base, 1.8, seg)
    for sx in (1, -1):
        base = [(sx * 6.75, y, Z_ROOF + 0.02) for y in (-5.0, -1.5, 2.0, 5.5, 9.0, 11.6)]
        rail_run(g, base, 2.6, seg)
    base = [(x, 11.75, Z_ROOF + 0.02) for x in (-6.75, -4.5, 3.9)]
    rail_run(g, base, 2.6, seg)


def cleat(g, x, y, z, along=(0, 1, 0)):
    d = Vector(along).normalized()
    p = Vector((x, y, z))
    R.box(g, tuple(p + Vector((0, 0, 0.04))), (0.2 if abs(d.y) > 0.5 else 0.6, 0.6 if abs(d.y) > 0.5 else 0.2, 0.08),
          M(g, "Stainless"), bev=0.03)
    R.tube(g, [tuple(p - d * 0.42 + Vector((0, 0, 0.08))), tuple(p - d * 0.3 + Vector((0, 0, 0.22))),
               tuple(p + d * 0.3 + Vector((0, 0, 0.22))), tuple(p + d * 0.42 + Vector((0, 0, 0.08)))],
           0.05, M(g, "Stainless"), 8, fillet=0.1, fseg=2)
    R.box(g, tuple(p + Vector((0, 0, 0.24))), (0.14, 0.14, 0.04), M(g, "TW_Gold"), bev=0.02)


def running(g):
    seg = 24 if g.hi else 14
    for sx in (1, -1):
        x = sx * HX
        # shaft, P-bracket, 4-blade bronze prop, rudder
        R.tube(g, [(x, 14.5, 1.35), (x, 20.4, 0.95)], 0.1, M(g, "Stainless"), 10 if g.hi else 6)
        R.extrude_profile(g, [(19.4, 0.95), (19.9, 0.95), (19.6, 2.4), (19.1, 2.4)], x - 0.05, x + 0.05, M(g, "TW_Bronze"))
        R.lathe(g, (x, 20.3, 0.95), (0, 1, 0), [(0.0, -0.1), (0.2, 0.0), (0.2, 0.4), (0.12, 0.55), (0.0, 0.6)], 16,
                M(g, "TW_Bronze"))
        for bl in range(4):
            a0 = 2 * math.pi * bl / 4 + 0.4
            rows = []
            nk = 8 if g.hi else 5
            for k in range(nk + 1):
                t = k / nk
                rr = 0.18 + 0.44 * t
                ang = a0 + 0.3 * t
                chord = 0.36 * math.sin(math.pi * (0.2 + 0.7 * t))
                cc = Vector((x + rr * math.cos(ang), 20.45, 0.95 + rr * math.sin(ang)))
                td = Vector((-math.sin(ang), 0, math.cos(ang)))
                dd = (td * math.cos(0.6) + Vector((0, 1, 0)) * math.sin(0.6)) * chord
                rows.append([cc - dd, cc + dd])
            g.rings(rows, M(g, "TW_Bronze"), closed=False)
        R.extrude_profile(g, [(21.3, 0.45), (22.3, 0.45), (22.2, 2.6), (21.4, 2.6)], x - 0.08, x + 0.08,
                          M(g, "TW_Antifoul"), bev=0.03)
        R.tube(g, [(x, 21.8, 2.5), (x, 21.8, keel_z(21.8) + 0.6)], 0.09, M(g, "Stainless"), 8)
        # cleats: bow, midships, stern on each hull top
        for y in (-19.0, 3.0, 22.6):
            cleat(g, sx * (HX + half_w(y) - 0.55), y, sheer_z(y) + 0.08)
    # anchor on a stainless roller at the foredeck nose
    R.box(g, (0, Y_FWD - 0.1, bridge_top(Y_FWD) + 0.05), (0.7, 2.0, 0.2), M(g, "Stainless"), bev=0.05)
    R.lathe(g, (-0.3, Y_FWD - 1.0, bridge_top(Y_FWD) + 0.1), (1, 0, 0), [(0.15, 0.0), (0.15, 0.6)], 12,
            M(g, "BlackPlastic"))
    R.box(g, (0, Y_FWD - 1.25, bridge_top(Y_FWD) - 0.25), (0.6, 0.15, 0.7), M(g, "Stainless"), bev=0.04)


# --------------------------------------------------------------------------- collision, markers, build
def collision():
    pts = []
    for sx in (1, -1):
        for y in hull_stations(False)[::2]:
            r, _ = hull_ring(y, sx)
            pts += [tuple(p) for p in r]
    for x in (-7.0, 7.0):
        for y in (-14.0, 5.0, 12.0):
            pts.append((x, y, Z_ROOF))
    return X.convex_col(NAME, pts)


FLOAT_POINTS = [(-5.5, -20), (5.5, -20), (-6.5, -7), (6.5, -7), (-6.5, 7), (6.5, 7), (-5.5, 20), (5.5, 20)]


def markers():
    seat = Z_SEAT - 0.27
    atts = {
        "ATT_DriverSeat": (0.0, Y_HELM, seat),
        "ATT_EyePoint": (0.0, Y_HELM - 0.5, seat + 2.8),
        "ATT_PassengerSeat1": (2.3, Y_HELM, seat),
        "ATT_PassengerSeat2": (-2.3, Y_HELM, seat),
        "ATT_PassengerSeat3": (0.0, 6.6, seat),
        "ATT_TowHitch": gb(0, 0.6, 25.4),
        "ATT_BowPoint": gb(0, 0.6, -25.4),
        "ATT_DriveAttachment": gb(0, 0, 0),
        "ATT_NavPort": (6.55, -3.2, Z_HT + 0.25),
        "ATT_NavStarboard": (-6.55, -3.2, Z_HT + 0.25),
        "ATT_NavMasthead": (-0.75, 3.9, Z_HT + 0.5 + MAST + 0.12 + 0.3),
        "ATT_NavStern": (0.0, 9.7, Z_HT + 0.25),
        "ATT_Beacon": (0.75, 3.9, Z_HT + 0.5 + MAST + 0.12 + 0.42),
        "ATT_Searchlight": (0.0, -5.75, Z_HT + 0.92),
        "ATT_Prop1": (HX, 20.45, 0.95),
        "ATT_Prop2": (-HX, 20.45, 0.95),
    }
    for i in range(6):   # the lifeboat greybox's aft survivor well layout
        side = -1 if i % 2 == 0 else 1
        atts["ATT_SurvivorSlot%d" % (i + 1)] = gb(side * 3.4, 3.0, 7.5 + (i // 2) * 3.4)
    for i, (x, z) in enumerate(FLOAT_POINTS):
        atts["ATT_Float%d" % (i + 1)] = gb(x, -3.0, z)
    return atts


def build():
    X.pattern("TW_Teak", "teak")
    X.pattern("TW_Leather", "quilt", thread="#C8AE7E", groove="#B3A88F", cell=0.5)
    X.pattern("TW_Pleat", "pleat", thread="#C8AE7E", groove="#B3A88F", cell=0.34)
    X.pattern("TW_Pearl", "pearl")
    unwrap = X.tight_uv
    hl_set = R.build_set("Hulls", [(NAME + "_HullP_LOD0", hull_port), (NAME + "_HullS_LOD0", hull_stbd),
                                   (NAME + "_Bridgedeck_LOD0", bridgedeck)], unwrap, "MI_TW_Hulls")
    dk_set = R.build_set("Deck", [(NAME + "_Cockpit_LOD0", deck_parts)], unwrap, "MI_TW_Deck")
    cb_set = R.build_set("Cabin", [(NAME + "_Saloon_LOD0", saloon), (NAME + "_Roof_LOD0", roof)], unwrap, "MI_TW_Cabin")
    fl_set = R.build_set("Fly", [(NAME + "_Flybridge_LOD0", fly_parts), (NAME + "_Hardtop_LOD0", hardtop)], unwrap,
                         "MI_TW_Fly")
    ft_set = R.build_set("Fittings", [(NAME + "_Rails_LOD0", rails), (NAME + "_Running_LOD0", running)], unwrap,
                         "MI_TW_Fittings")
    hps = [
        R.build_hp(NAME + "_HullP_HP", [hull_port]),
        R.build_hp(NAME + "_HullS_HP", [hull_stbd]),
        R.build_hp(NAME + "_Bridgedeck_HP", [bridgedeck]),
        R.build_hp(NAME + "_Cockpit_HP", [deck_parts], bevel=dict(width=0.02, segments=2, angle=40)),
        R.build_hp(NAME + "_Saloon_HP", [saloon]),
        R.build_hp(NAME + "_Roof_HP", [roof]),
        R.build_hp(NAME + "_Flybridge_HP", [fly_parts]),
        R.build_hp(NAME + "_Hardtop_HP", [hardtop]),
        R.build_hp(NAME + "_Rails_HP", [rails]),
        R.build_hp(NAME + "_Running_HP", [running]),
    ]
    col = collision()
    atts = X.empties(markers())
    groups = ((hl_set, "Hulls"), (dk_set, "Deck"), (cb_set, "Cabin"), (fl_set, "Fly"), (ft_set, "Fittings"))
    lod0 = [o for objs, _ in groups for o in objs]
    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    off = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    for o in lod0 + hps + [col]:
        o.data.transform(Matrix.Translation(off))
    for e in atts:
        e.location = e.location + off
    # HullRoot (greybox) position of the model pivot, the Tidewalker's Builder.RIB_ORIGIN equivalent
    origin = (off.x, -ZK - off.z, -off.y)
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "frame_offset.json"), "w") as f:
        json.dump({"offset": list(off), "bbox_studs": [h - l for l, h in zip(lo, hi)], "hullroot_origin": origin}, f)
    print("[%s] offset %s bbox %s origin %s" % (NAME, tuple(round(c, 3) for c in off),
                                                [round(h - l, 3) for l, h in zip(lo, hi)], origin))

    meshes = [{"object": o, "set": s} for objs, s in groups for o in objs]
    meshes += [{"object": h} for h in hps] + [{"object": col}]
    wear = {"edge": 0.05, "edge_color": (0.6, 0.6, 0.58), "salt": 0.06, "salt_color": (0.68, 0.67, 0.64),
            "salt_range": (0.4, 0.85), "rust": 0.0}
    sets = [{"name": TEX, "set": s, "size": 2048, "wet": True, "wet_darken": 0.3, "wet_gloss": 0.35,
             "wet_streaks": 0.4, "cage_extrusion": 0.06, "max_ray_distance": 0.15, "wear": dict(wear)}
            for _, s in groups]
    sets[0]["size"] = 4096       # both 17 m demihulls in one set: 51 px/stud needs 4096 (bake it with MAYDAY_BAKE_SIZE=4096)
    sets[3]["size"] = 4096       # flybridge helm (the driver's view, 1 m close-up): near hero tier
    return {
        "name": NAME,
        "budget": "allweather_lifeboat",
        "tier": "standard",
        "dims_m": (5.9, 17.3, None),
        "size_note": "Lifeboat greybox frame (17.3 x 5.9 m); length includes the swim platform and transom steps.",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_size": 2048,
        "bake_samples": 16,
        "closeups": [
            {"name": "helm_1m", "target": [0.0, -4.4, Z_ROOF + 2.2], "dist": 3.0, "az": 200, "el": 25},
            {"name": "hull_windows", "target": [8.7, -4.0, 5.0], "dist": 9, "az": 90, "el": 5},
            {"name": "wordmark", "target": [8.6, 15.5, 5.1], "dist": 7, "az": 90, "el": 4},
            {"name": "cockpit_teak", "target": [0.0, 13.0, 6.5], "dist": 9, "az": 160, "el": 35},
            {"name": "saloon_glass", "target": [4.0, -11.0, 9.5], "dist": 8, "az": 35, "el": 12},
            {"name": "stern_steps", "target": [0.0, 25.0, 4.6], "dist": 8, "az": 160, "el": 18},
        ],
        "waivers": {
            "LOD UV layout": "LOD1 / LOD2 collapse decimation moves small tube / rail UV island borders (the RIB's "
                             "waiver); LODs are only seen far off where the maps are mip-mapped below the island size.",
        },
    }
