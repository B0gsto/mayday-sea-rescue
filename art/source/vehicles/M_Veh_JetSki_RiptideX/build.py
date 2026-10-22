"""M_Veh_JetSki_RiptideX: premium (Robux) sport jet ski, on the M_Veh_JetSki frame and markers (see
art/source/vehicles/_JetSkiPremium/premium.py).

Shared sport hull (premium.use_sport_hull) with a deeper V, faceted ridge cowl, four spray strakes, sponsons. Graphite
gloss topsides with a carbon-black aft panel on an angled break (neon edge), carbon-black bottom and nose cone, neon
cyan rub-rail band, slashes and hood pinstripes, a wide chrome-grilled nose intake with a 0.3-stud throat, a two-step
suede saddle with side bolsters and a rear hump, chrome fittings. Sets: Hull (hull, seat, trim) and Sled (sled,
fittings, cockpit), 1024 + _Wet.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- \
      --build art/source/vehicles/M_Veh_JetSki_RiptideX/build.py --steps build,lod,bake,validate,export,turntable
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_JetSkiPremium"))
import premium as X  # noqa: E402

P, R, M, smooth = X.P, X.R, X.M, X.smooth
NAME = "M_Veh_JetSki_RiptideX"

R.PALETTE.update({
    "HullCharcoal": ("#1F2226", 0.30, 0.0),     # carbon-black bottom
    "PWCOrange": ("#3D434B", 0.20, 0.0),        # graphite gloss topsides (name kept: every base slot follows)
    "PWCOrangeDark": ("#363B42", 0.22, 0.0),
    "PWCDeck": ("#26292D", 0.24, 0.0),          # forged carbon hood / deck
    "DeckGrey": ("#33373C", 0.40, 0.0),
    "NonSlip": ("#2C3034", 0.86, 0.0),
    "SledOrange": ("#363B42", 0.26, 0.0),
    "SledHull": ("#1F2226", 0.40, 0.0),
    "Stainless": ("#E4E7E9", 0.06, 1.0),        # chrome
    "Aluminium": ("#DADDDF", 0.10, 1.0),
    "Bolt": ("#E0E3E5", 0.10, 1.0),
    "Neon": ("#17C3D6", 0.30, 0.0),             # electric cyan (clear of every docs/05 3.2 signal colour)
    "Suede": ("#2B2D31", 0.84, 0.0),
    "SeatCarbon": ("#2A2D31", 0.30, 0.0),
    "Vent": ("#16181B", 0.70, 0.0),
})
for k in ("Stainless", "Aluminium", "Bolt"):
    R.BUMP_ONLY.pop(k, None)                    # polished chrome, not brushed
LIGHT = dict(salt=("#8A8F92", 0.10), rough_var=0.05)
R.PROC.update({
    "HullCharcoal": dict(mottle=(2, 0.04), grime=("#2A2C30", 0.15), streak=("#3A3E42", 0.15), scuff=("#4A4E54", 0.3),
                         salt=("#6E7276", 0.12), rough_var=0.06),
    "PWCOrange": dict(mottle=(1.0, 0.03), streak=("#474C53", 0.12), zsalt=("#D9D6CC", 0.6, 1.0, 1.3),
                      scuff=("#5C626A", 0.3), **LIGHT),
    "PWCOrangeDark": dict(mottle=(1.5, 0.03), rough_var=0.05),
    "PWCDeck": dict(mottle=(1.5, 0.01), salt=("#8A8F92", 0.06), rough_var=0.03),   # clean gloss carbon-black hood
    "SledOrange": dict(mottle=(1.0, 0.03), zgrime=("#25282C", 0.3, 1.05, 1.25), **LIGHT),
    "SledHull": dict(mottle=(1.5, 0.04), grime=("#2A2C30", 0.2), rough_var=0.06),
    "Neon": dict(mottle=(3, 0.03), rough_var=0.04),
    "Suede": dict(mottle=(4, 0.01), rough_var=0.03, bump=("diamond", 0.45, 10)),   # perforated grip suede
    "SeatCarbon": dict(mottle=(2, 0.01), rough_var=0.03),
    "Vent": dict(mottle=(3, 0.05), rough_var=0.05),
    "GripRubber": dict(mottle=(5, 0.04), salt=("#D9D6CC", 0.4), scuff=("#55524E", 0.35), rough_var=0.1,
                       bump=("diamond", 0.6, 9)),
})


# =========================================================================== sharp hull
X.use_sport_hull(t_aft=0.5, t_bow=0.42)


def top_z(x, y):
    """Faceted ridge hood: a centre spine, flat panels to a shoulder crease at 0.62 beam, steep flank to the gunwale."""
    b, zg = P.half_beam(y), P.gunwale_z(y)
    crown = (X.H["crown"] - zg - 0.06) * (0.25 + 0.75 * smooth(P.NOSE, -1.5, y) ** 0.8)
    r = min(abs(x) / b, 1.0)
    sh = 1 - 0.3 * r / 0.62 if r < 0.62 else 0.7 * ((1 - r) / 0.38) ** 0.8
    hood = zg + 0.06 + crown * sh
    return hood + (X.floor_z(y) - hood) * P.footwell(y)


NOSE_CONE = P.NOSE + 0.85


def seg_mat(k, y):
    f = P.footwell(y)
    if k <= 3:
        return "HullCharcoal"
    if k in (5, 7):
        return "RubBlack"
    if k == 6:
        return "Neon"                            # neon band on the rub rail's outer face, bow to stern
    if y < NOSE_CONE:
        return "PWCDeck"                         # forged-carbon nose cone
    if k == 10:
        return "DeckGrey" if f > 0.5 else "PWCOrange"
    if k >= 11:
        return "NonSlip" if f > 0.5 else "PWCDeck"
    return "PWCOrange"


P.top_z, P._seg_mat = top_z, seg_mat

SCOOP = (-4.15, -2.5)        # nose intake front / back (y): mouth just behind the nose cone


def scoop(g):
    """Wide angular nose intake: faceted cowl, chrome bezel, a dark throat 0.3 deep, four recessed chrome slats."""
    yf, yb = SCOOP
    n = 14 if g.hi else 8
    rows = []
    for i in range(n + 1):
        a = i / n
        y = yf + (yb - yf) * a
        w = 0.6 + 0.04 * a
        zt = P.top_z(0, y) + 0.34 * (1 - a ** 1.3)
        rows.append([Vector((-w, y, P.top_z(w, y) - 0.03)), Vector((-0.78 * w, y, zt)), Vector((0.78 * w, y, zt)),
                     Vector((w, y, P.top_z(w, y) - 0.03))])
    fs = g.rings(rows, M(g, "PWCDeck"), closed=False, recalc=False,
                 matfn=(lambda i, j: "PWCOrange" if j != 1 else "PWCDeck") if g.hi else None)
    g.orient(fs, lambda c: Vector((c.x, -0.3, 1.0)))
    f = g.face([g.bm.verts.new(p) for p in rows[-1]], M(g, "PWCOrange"))
    if f:
        g.orient([f], lambda c: Vector((0, 1, 0)))
    w, zt = 0.6, rows[0][1].z

    def mouth(y, ins):
        """Closed mouth outline at y, inset by ins: the cowl's three sides, then back along the hood."""
        wi, wt = w - ins, 0.78 * w - 0.8 * ins
        pts = [Vector((-wi, y, P.top_z(wi, y) + ins * 0.5)), Vector((-wt, y, zt - ins)), Vector((wt, y, zt - ins)),
               Vector((wi, y, P.top_z(wi, y) + ins * 0.5))]
        pts += [Vector((x, y, P.top_z(x, y) + ins * 0.5 - 0.01)) for x in (0.5 * wi, 0.0, -0.5 * wi)]
        return pts
    outer, inner = mouth(yf - 0.005, 0.0), mouth(yf - 0.005, 0.07)
    cz = (P.top_z(0, yf) + zt) / 2
    fs = g.rings([outer, inner], M(g, "Stainless"), closed=True, recalc=False)       # chrome bezel
    g.orient(fs, lambda c: Vector((0, -1, 0)))
    depth = 0.3
    back = [p + Vector((0, depth, 0)) for p in inner]
    fs = g.rings([inner, back], M(g, "Vent"), closed=True, recalc=False)             # throat walls
    g.orient(fs, lambda c: Vector((-c.x, 0, cz - c.z)))
    f = g.face([g.bm.verts.new(p) for p in back], M(g, "Vent"))
    if f:
        g.orient([f], lambda c: Vector((0, -1, 0)))
    # recessed slats and a centre bar, set 0.1 back in the throat
    ys = yf + 0.1
    zb, ztop = P.top_z(0, ys) + 0.06, zt - 0.1
    for k in range(4):
        z = zb + (ztop - zb) * (k + 0.5) / 4
        tz = (z - inner[0].z) / (inner[1].z - inner[0].z)
        hw = inner[3].x + (inner[2].x - inner[3].x) * min(max(tz, 0.0), 1.0)
        R.box(g, (0, ys, z), (2 * hw, 0.05, 0.035), M(g, "Stainless"), bev=0.01, rot=Matrix.Rotation(math.radians(-20), 3, "X"))
    R.box(g, (0, ys - 0.02, (zb + ztop) / 2), (0.04, 0.06, ztop - zb + 0.06), M(g, "Stainless"), bev=0.01)


def strakes(g):
    """Spray strakes: triangular ridges on the bottom, two a side, bow to transom."""
    n = 40 if g.hi else 20
    for sx in (1, -1):
        for fr in (0.4, 0.75):
            rings = []
            for i in range(n + 1):
                y = P.NOSE + 0.9 + (P.TRANSOM - 0.05 - P.NOSE - 0.9) * i / n
                pr = P.profile(y)
                (x0, z0), (x1, z1) = pr[0], pr[2]
                px, pz = x0 + (x1 - x0) * fr, z0 + (z1 - z0) * fr
                dl = math.hypot(x1 - x0, z1 - z0)
                dx, dz = (x1 - x0) / dl, (z1 - z0) / dl
                nx, nz = dz, -dx                    # outward-down
                hgt = 0.06 * smooth(P.NOSE + 0.9, P.NOSE + 2.2, y)
                rings.append([Vector((sx * (px - dx * 0.06), y, pz - dz * 0.06)),
                              Vector((sx * (px + nx * hgt), y, pz + nz * hgt)),
                              Vector((sx * (px + dx * 0.02 - nx * 0.01), y, pz + dz * 0.02 - nz * 0.01))])
            g.rings(rings, M(g, "HullCharcoal"), closed=True, cap0=True, cap1=True)


def decals(g):
    off = P.OFF
    nu = 2 if not g.hi else 4
    for sx in (1, -1):
        for y0, w in ((-3.85, 0.26), (-3.4, 0.16)):         # neon slashes behind the nose cone
            X.topside_quad(g, sx, [(y0, 0.06), (y0 + 0.45, 0.94), (y0 + 0.45 + w, 0.94), (y0 + w, 0.06)],
                           M(g, "Neon"), off, nu, nu)
        # angled panel break: graphite forward, carbon-black aft, a neon edge on the diagonal
        X.topside_quad(g, sx, [(-1.2, 0.03), (0.15, 0.97), (4.95, 0.97), (4.95, 0.03)], M(g, "HullCharcoal"), off,
                       40 if g.hi else 16, nu)
        X.topside_quad(g, sx, [(-1.42, 0.03), (-0.07, 0.97), (0.07, 0.97), (-1.28, 0.03)], M(g, "Neon"), off + 0.004,
                       nu, nu)
    # hood: neon pinstripes on the shoulder creases, converging on the nose, broken by the intake
    for s in (1, -1):
        f0, f1 = (0.6, 0.66) if s > 0 else (-0.66, -0.6)
        X.deck_strip(g, f0, f1, SCOOP[1] + 0.05, -1.95, M(g, "Neon"), nu=6)


def trim(g):
    decals(g)
    scoop(g)
    strakes(g)
    X.sponsons(g, "HullCharcoal")


def sculpt(c):
    """Sport saddle: raised side bolsters, a dished rider pocket."""
    if c.z < 2.5:
        return c
    r = abs(c.x) / 0.6
    dz = 0.07 * smooth(0.25, 0.62, r) - 0.045 * (1 - smooth(0.0, 0.5, r)) * (1 - smooth(0.5, 1.3, abs(c.y - 1.1)))
    return Vector((c.x, c.y, c.z + dz))


def two_step(y):
    """Rider pocket, a sharp step up to the passenger pad, a bolstered hump at the tail."""
    return 0.2 * smooth(2.2, 2.5, y) + 0.12 * smooth(3.15, 3.45, y) * (1 - smooth(3.8, 4.15, y))


seat = X.make_seat(["DeckGrey", "BlackPlastic", "BlackPlastic", "SeatCarbon", "Neon", "Suede", "Suede", "Suede"],
                   "Suede", 4.2, sculpt, step=two_step, taper=0.75)


def sled(g):
    P.sled(g)
    X.sled_pinline(g, M(g, "Neon"), 0.3, 0.045)


STYLE = {
    "name": NAME, "tex": "RiptideX",
    "seat": seat, "trim": trim, "sled": sled, "sled_text": lambda g: None, "fittings": X.fittings,
 "hull_sharp": 16,
    "wear_hull": {"edge": 0.2, "edge_color": (0.42, 0.44, 0.46), "salt": 0.08, "salt_color": (0.6, 0.6, 0.58),
                  "rust": 0.0},
    "wear_sled": {"edge": 0.1, "edge_color": (0.42, 0.44, 0.46), "salt": 0.08, "salt_color": (0.6, 0.6, 0.58),
                  "rust": 0.0},
    "closeups": [
        {"name": "scoop_grille_1m", "target": (0.0, -4.15, 2.4), "dist": 3.0, "az": 25, "el": 18},
        {"name": "seat_bolsters", "target": (0.0, 1.4, 2.7), "dist": 5.0, "az": 120, "el": 35},
        {"name": "side_slashes", "target": (1.4, -3.2, 1.6), "dist": 5.5, "az": 70, "el": 8},
        {"name": "panel_break", "target": (1.9, 0.0, 1.2), "dist": 4.5, "az": 90, "el": 5},
        {"name": "stern_sled", "target": (0.0, 6.5, 1.4), "dist": 6.0, "az": 150, "el": 30},
    ],
}


def build():
    return X.build_style(STYLE)
