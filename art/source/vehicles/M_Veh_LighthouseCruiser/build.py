"""M_Veh_LighthouseCruiser: premium (Robux) luxury SUV, generic full-size class (not a replica).

4.95 m x 2.0 m x 1.85 m roof (1.95 m over the roof-bar lamps; 14.85 x 6.0 x 5.85 studs), 2.92 m wheelbase, 1.66 m
track, 275/45 R21 on 21-inch ten-spoke alloys (0.39 m radius). LandVehicleConfig.LighthouseCruiser matches these
numbers; the art aligns on ATT_Wheel_*. Same parametric skin as the HarbourGT (_CarPremium/carkit.py): tall
confident stance, clamshell bonnet, gently rising beltline, floating cream roof on gloss-black pillars over
lighthouse-red paint, chrome DLO belt strip, chrome mesh grille with slats, slim LED lamps, fender vents, panoramic
glass roof, roof rails with a crossbar of four warm lamps, chrome sill strips, twin chrome outlets, tow hitch.
Cream leather and walnut five-seat cabin (2 + 3). Gameplay markers as on the pickup / Coastguard 4x4: four wheel
hubs, five seats (RHD, driver Blender -X), eye point, lamps, ATT_TowHitch, ATT_RoofLamp_01..04, ATT_DriveAttachment.

Sets (each _Wet, ship 1024): Body (skin), Cab (interior + glass), Wheels (wheels, brakes, underbody), Trim (lamps,
grille, chrome, rails, roof bar, mirrors, hitch, plates).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/vehicles/M_Veh_LighthouseCruiser/build.py --out-root build/prod/M_Veh_LighthouseCruiser \
      --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "_CarPremium"))
import carkit as K  # noqa: E402
import rbxkit  # noqa: E402

V = K.V
M, P, C = K.M, K.P, K.curve
NAME = "M_Veh_LighthouseCruiser"
TEX = "LighthouseCruiser"

# --------------------------------------------------------------------------- layout (studs, 3 per metre)
L = 14.85
AX_F, AX_R = 2.85, 11.61             # 0.95 m front overhang, 2.92 m wheelbase
HUB_X = 2.49                         # 1.66 m track
R, RR, WW = 1.23, 0.84, 0.855        # 0.41 m tyre radius, 22-inch rim, 285/45 section
SEAT_X, SEAT_Y, SEAT_Z = 1.30, 7.75, 2.25
REAR_Y, REAR_Z = 10.75, 2.35
ROOF_BAR_Y = 7.45
CHASSIS = (0.0, AX_F + 8.76 * (1 - 0.5), 0.88 * 3)    # inherited CoastguardResponse frontWeight / cgHeight

K.paint("PaintLH", "#A8262C", 0.12)          # lighthouse red
K.paint("PaintCream", "#E2D7BE", 0.14)       # lantern-room cream
K.leather("LeatherCream", "#CDBFA2")
K.leather("LeatherDark", "#3A3330")
V.PALETTE.update({"Walnut": ("#5E3F28", 0.30, 0.0), "RimBright": ("#C9CED1", 0.30, 1.0),
                  "BrakeRed": ("#9A2329", 0.36, 0.0)})
V.PROC["Walnut"] = dict(mottle=(14.0, 0.10), rough_var=0.04, bump=("grain", 0.03, 60))

CURVES = dict(
    L=L, axles=(AX_F, AX_R), wheel_z=R, arch_r=R + 0.18, arch_blend=0.34, flare=0.06, flare_sig=1.6,
    ds=0.36, KG=4, KR=7, crown=0.45, crease=(0.80, 0.05, 0.035),
    zb=C([(0, 1.28), (0.4, 1.04), (1.4, 0.80), (13.0, 0.83), (14.2, 1.10), (14.85, 1.38)]),
    hw=C([(0, 2.58), (0.3, 2.80), (1.0, 2.90), (2.85, 2.93), (6.0, 2.92), (11.6, 2.93), (13.8, 2.90), (14.5, 2.80),
          (14.85, 2.62)]),
    tuck=C([(0, 0.08), (1.0, 0.13), (14.0, 0.13), (14.85, 0.08)]),
    fsh=C([(0, 0.62), (14.85, 0.62)]),
    zbelt=C([(0, 3.05), (0.5, 3.25), (2.85, 3.38), (5.0, 3.45), (9.0, 3.55), (12.5, 3.62), (14.4, 3.62),
             (14.85, 3.45)]),
    hwb=C([(0, 2.45), (0.6, 2.68), (2.85, 2.74), (8.0, 2.74), (13.5, 2.72), (14.85, 2.45)]),
    zdeck=C([(0, 3.14), (0.5, 3.44), (2.0, 3.55), (4.5, 3.64), (6.0, 3.66), (13.9, 3.72), (14.5, 3.70),
             (14.85, 3.52)]),
    zr=C([(0, 2.0), (4.3, 3.30), (4.75, 3.66), (5.4, 4.35), (6.1, 4.98), (6.8, 5.42), (7.6, 5.54), (10.0, 5.55),
          (13.0, 5.50), (14.0, 5.42), (14.35, 5.26), (14.6, 4.62), (14.75, 3.92), (14.85, 3.5)]),
    zre=C([(0, 1.8), (4.3, 3.10), (4.9, 3.62), (5.5, 4.25), (6.2, 4.85), (6.9, 5.26), (7.6, 5.38), (13.0, 5.34),
           (14.0, 5.26), (14.35, 5.10), (14.6, 4.47), (14.75, 3.77), (14.85, 3.3)]),
    hwroof=C([(0, 2.2), (4.5, 2.45), (6.0, 2.42), (7.0, 2.38), (13.5, 2.36), (14.5, 2.40), (14.85, 2.3)]),
    extra=(4.75, 5.2, 8.55, 8.8, 11.45, 11.85, 14.1, 14.38, 14.45, 14.6, 14.7, 14.78),
    trim="TrimGloss", no_trim=("PaintCream",), cap_mat="PaintLH",
)


def matfn(B, band, k, x, y, z):
    c = B.c
    ax = abs(x)
    if band == "bottom":
        return "Underseal"
    if band == "side":
        return "PaintLH"
    zbelt = c["zbelt"](y)
    if band == "glass":
        if 5.2 < y < 14.42 and zbelt + 0.07 < z < c["zre"](y) - 0.06:
            if 8.55 < y < 8.8 or 11.45 < y < 11.85 or y > 14.1:
                return "TrimGloss"       # blacked B / C / D pillars: the roof floats
            return "Glass"
        if 4.85 < y < 14.8 and z > zbelt + 0.10:
            return "TrimGloss"           # A-pillars and the pillar roots
        return "PaintLH"
    hro = c["hwroof"](y)
    if 4.95 < y < 6.75 and ax < hro - 0.18:
        return "Glass"                   # windscreen
    if 14.4 < y < 14.76 and ax < hro - 0.25:
        return "Glass"                   # tailgate glass
    if 7.3 < y < 13.3 and ax < hro - 0.50:
        return "Glass"                   # panoramic roof
    if 4.85 < y < 14.8 and z > zbelt + 0.10:
        return "PaintCream"
    return "PaintLH"


CURVES["matfn"] = matfn
B = K.Body(CURVES)
zbelt, zr, hwroof = CURVES["zbelt"], CURVES["zr"], CURVES["hwroof"]


RAKE = math.tan(math.radians(9.0))


def rake(co):
    """Leans the fascia above the bumper back 9 degrees, fading out over the first 1.4 studs."""
    t = max(0.0, min(1.0, co.y / 1.4))
    f = 1.0 - t * t * (3 - 2 * t)
    return Vector((co.x, co.y + max(0.0, co.z - 1.9) * RAKE * f, co.z))


def raked(fn):
    def wrapped(g):
        before = K.mark(g)
        fn(g)
        K.move_new(g, before, rake)
    return wrapped


# --------------------------------------------------------------------------- parts
def body(g):
    B.build(g, lambda m: m != "Glass")
    if g.hi:   # shut lines (bake only): doors, bonnet clamshell, tailgate
        for y in (5.05, 8.68, 11.7):
            for side in (1, -1):
                B.patch(g, [y - 0.012, y + 0.012], None, side, "ShutLine", off=0.004, depth=0.01,
                        tfn=lambda yy: (B.t_at_z(yy, 0.95), B.t_at_z(yy, zbelt(yy) - 0.02)))
        for side in (1, -1):
            ts = B.tband("side", len(K.SIDE) - 1.4)
            ys = [0.45 + (4.75 - 0.45) * k / 16 for k in range(17)]
            B.patch(g, ys, (ts - 0.05, ts + 0.05), side, "ShutLine", off=0.004, depth=0.01)
            B.patch(g, [14.55, 14.575], (B.tband("side", 3), B.tband("roof", 1)), side, "ShutLine", off=0.004,
                    depth=0.01)


def glass(g):
    B.build(g, lambda m: m == "Glass", inset=0.03)


def cabin(g):
    lin = {"side": "LeatherDark", "glass": "LeatherCream", "roof": "LeatherCream", "bottom": "Carpet",
           "cap": "InteriorDark"}
    B.inner(g, 4.8, 14.5, lambda band: lin[band], off=0.08, caps=(True, False))
    for sx in (-1, 1):
        K.seat(g, sx * SEAT_X, SEAT_Y, SEAT_Z, 1.65, M(g, "LeatherCream"), False, sport=False, recline=12,
               side_mat=M(g, "LeatherCream"))
        V.box(g, (sx * SEAT_X, SEAT_Y, 1.45), (1.2, 1.4, 0.9), M(g, "InteriorDark"), bev=0.06)
    # rear bench: three places with headrests
    K.seat(g, 0.0, REAR_Y, REAR_Z, 4.4, M(g, "LeatherCream"), False, sport=False, recline=10)
    V.box(g, (0, REAR_Y, 1.5), (4.6, 1.5, 1.0), M(g, "InteriorDark"), bev=0.06)
    # cargo floor behind the bench
    V.box(g, (0, 12.9, 1.95), (4.9, 3.0, 0.08), M(g, "Carpet"), bev=0.02)
    # dash: leather top roll, walnut fascia band, screens, vents
    V.box(g, (0, 5.75, 2.95), (5.2, 1.2, 0.8), M(g, "InteriorDark"), bev=0.14)
    V.box(g, (0, 5.70, 3.42), (5.1, 1.1, 0.16), M(g, "LeatherDark"), bev=0.07)
    V.box(g, (0, 6.37, 3.05), (5.0, 0.06, 0.22), M(g, "Walnut"), bev=0.02)
    V.box(g, (-SEAT_X, 6.22, 3.48), (1.2, 0.10, 0.30), M(g, "Screen"), bev=0.03)
    V.box(g, (0.0, 6.36, 3.40), (1.15, 0.06, 0.48), M(g, "Screen"), bev=0.02)
    for sx in (-1, 1):
        V.box(g, (sx * 2.15, 6.38, 3.30), (0.5, 0.04, 0.12), M(g, "Chrome"), bev=0.01)
    # centre console, gear dial
    V.box(g, (0, 7.4, 1.9), (0.9, 3.2, 0.9), M(g, "LeatherDark"), bev=0.1)
    V.box(g, (0, 7.4, 2.37), (0.8, 3.0, 0.05), M(g, "Walnut"), bev=0.02)
    V.lathe(g, (0, 6.75, 2.40), (0, 0, 1), [(0.14, 0.0), (0.14, 0.10), (0.0, 0.11)], 14 if g.hi else 10, M(g, "Chrome"))
    K.steering_wheel(g, (-SEAT_X, 6.55, 3.22), 0.60, 24, M(g, "LeatherDark"), M(g, "TrimGloss"))
    V.tube(g, [(-SEAT_X, 6.58, 3.22), (-SEAT_X, 6.1, 3.38)], 0.10, M(g, "TrimGloss"), 8)


def wheel_fn(side, front):
    spec = dict(R=R, RR=RR, W=WW, spokes=10, twin=0.0, w0=0.17, w1=0.13, depth=0.10, dish0=0.30, dish1=0.42,
                face="RimBright", machined="RimPolished", lip="Chrome", cap="Chrome")
    hub = (side * HUB_X, AX_F if front else AX_R, R)
    return lambda g: K.wheel(g, hub, side, spec)


def underbody(g):
    spec = dict(W=WW, disc=0.62, caliper="BrakeRed")
    for side in (1, -1):
        for front, hy in ((True, AX_F), (False, AX_R)):
            K.brakes(g, (side * HUB_X, hy, R), side, spec, front)
            K.wheel_well(g, 2.92, hy, R, R + 0.26, 1.2, side)


def front(g):
    # chrome-framed mesh grille with five slats and the roundel
    V.box(g, (0, -0.02, 2.48), (2.7, 0.06, 0.92), M(g, "Chrome"), bev=0.04)
    V.box(g, (0, -0.05, 2.48), (2.5, 0.06, 0.76), M(g, "GrilleMesh"), bev=0.02)
    for k in range(5):
        V.box(g, (0, -0.08, 2.18 + 0.15 * k), (2.46, 0.05, 0.035), M(g, "Chrome"), bev=0.01)
    V.lathe(g, (0, -0.10, 2.48), (0, -1, 0), [(0.20, 0.0), (0.20, 0.03), (0.16, 0.05), (0.0, 0.05)],
            20 if g.hi else 12, M(g, "Chrome"))
    V.lathe(g, (0, -0.15, 2.48), (0, -1, 0), [(0.14, 0.0), (0.0, 0.006)], 16 if g.hi else 10, M(g, "PaintLH"))
    if g.hi:   # lighthouse mark inside the roundel
        V.box(g, (0, -0.158, 2.47), (0.06, 0.01, 0.18), "Badge")
        V.box(g, (0, -0.158, 2.58), (0.10, 0.01, 0.04), "Badge")
    # slim LED headlamps either side of the grille, wrapping onto the corners
    for sx in (-1, 1):
        # headlamp unit: black bezel, chrome reflector bowl, twin projectors, L-shaped LED signature
        # slim wide headlamp: black bezel, chrome reflector, LED signature line, three small projectors, wrapping
        # into the fender
        V.box(g, (sx * 1.92, -0.02, 2.70), (1.36, 0.06, 0.34), M(g, "TrimGloss"), bev=0.03)
        V.box(g, (sx * 1.92, -0.04, 2.68), (1.28, 0.04, 0.24), M(g, "LampChrome"), bev=0.02)
        V.box(g, (sx * 1.92, -0.065, 2.83), (1.28, 0.02, 0.04), M(g, "LED"), bev=0.0)
        for dx in (-0.40, 0.0, 0.40):
            K.projector(g, (sx * (1.92 + dx), -0.06, 2.66), (0, -1, 0), 0.085)
        B.strip_z(g, 0.04, 0.75, 2.53, 2.87, sx, M(g, "TrimGloss"), off=0.006, depth=0.08, n=6)
        B.strip_z(g, 0.05, 0.70, 2.58, 2.80, sx, M(g, "LampChrome"), off=0.012, depth=0.08, n=6)
        B.strip_z(g, 0.05, 0.72, 2.81, 2.85, sx, M(g, "LED"), off=0.018, depth=0.08, n=6)
        # corner intakes: framed, the mesh set back behind the frame
        V.box(g, (sx * 2.05, 0.02, 1.72), (0.52, 0.06, 0.38), M(g, "GrilleMesh"), bev=0.02)
        for dz in (-0.21, 0.21):
            V.box(g, (sx * 2.05, -0.03, 1.72 + dz), (0.62, 0.08, 0.05), M(g, "TrimGloss"), bev=0.0)
        for dx in (-0.29, 0.29):
            V.box(g, (sx * 2.05 + dx, -0.03, 1.72), (0.05, 0.08, 0.46), M(g, "TrimGloss"), bev=0.0)
        V.box(g, (sx * 2.05, -0.04, 1.72), (0.04, 0.04, 0.38), M(g, "Chrome"), bev=0.0)
    # lower intake: framed mesh set back, chrome bar, silver skid plate
    V.box(g, (0, 0.02, 1.70), (2.4, 0.06, 0.36), M(g, "GrilleMesh"), bev=0.02)
    for dz in (-0.21, 0.21):
        V.box(g, (0, -0.03, 1.70 + dz), (2.56, 0.08, 0.06), M(g, "TrimGloss"), bev=0.0)
    for dx in (-1.25, 1.25):
        V.box(g, (dx, -0.03, 1.70), (0.06, 0.08, 0.48), M(g, "TrimGloss"), bev=0.0)
    V.box(g, (0, -0.04, 1.70), (2.4, 0.05, 0.05), M(g, "Chrome"), bev=0.01)
    V.box(g, (0, 0.15, 1.18), (3.0, 0.40, 0.10), M(g, "Aluminium"), bev=0.03)


def rear(g):
    # slim tail lamps: a band across the tailgate under the glass and the corner units
    V.box(g, (0, L + 0.01, 3.30), (4.3, 0.05, 0.16), M(g, "TrimGloss"), bev=0.02)
    V.box(g, (0, L + 0.03, 3.30), (4.1, 0.04, 0.06), M(g, "LensRed"), bev=0.01)
    for sx in (-1, 1):
        V.box(g, (sx * 2.25, L + 0.01, 3.0), (0.62, 0.06, 0.66), M(g, "LensSmoke"), bev=0.04)
        V.box(g, (sx * 2.25, L + 0.04, 3.12), (0.55, 0.04, 0.10), M(g, "LensRed"), bev=0.01)
        V.box(g, (sx * 2.25, L + 0.04, 2.86), (0.55, 0.04, 0.08), M(g, "LensRed"), bev=0.01)
        B.strip_z(g, 14.25, L - 0.01, 2.70, 3.32, sx, M(g, "LensSmoke"), off=0.016, n=4)
        B.strip_z(g, 14.3, L - 0.01, 3.08, 3.16, sx, M(g, "LensRed"), off=0.03, n=4)
        V.box(g, (sx * 1.6, L + 0.04, 1.42), (0.36, 0.04, 0.08), M(g, "LensWhite"), bev=0.01)
        # twin chrome outlets in the bumper
        V.box(g, (sx * 1.55, L - 0.05, 0.98), (0.62, 0.24, 0.16), M(g, "Chrome"), bev=0.04)
        V.box(g, (sx * 1.55, L + 0.07, 0.98), (0.52, 0.02, 0.09), M(g, "LampInner"), bev=0.0)
    # chrome tailgate garnish, plate, black lower bumper and skid
    V.box(g, (0, L + 0.02, 2.62), (2.6, 0.04, 0.10), M(g, "Chrome"), bev=0.02)
    V.box(g, (0, L + 0.03, 2.12), (1.56, 0.04, 0.34), M(g, "PlateWhite"), bev=0.01)
    V.box(g, (0, L - 0.15, 1.30), (5.0, 0.42, 0.42), M(g, "TrimGloss"), bev=0.06)
    V.box(g, (0, L - 0.1, 0.98), (2.8, 0.4, 0.10), M(g, "Aluminium"), bev=0.03)
    if g.hi:
        me = V.text_mesh("GI 21 LH", 0.20, font_scale_x=0.9)
        g.add_mesh(me, "PlateLetter", lambda co: P(-co.x, L + 0.055, 2.12 + co.y))
        me = V.text_mesh("CRUISER", 0.13, font_scale_x=1.3)
        g.add_mesh(me, "PaintLH", lambda co: P(-co.x, L + 0.045, 2.62 + co.y))
    # tow hitch: receiver, pin, chrome ball
    V.box(g, (0, L - 0.1, 1.05), (0.32, 0.9, 0.26), M(g, "BlackMetal"), bev=0.03)
    V.box(g, (0, L + 0.42, 1.08), (0.30, 0.30, 0.26), M(g, "BlackMetal"), bev=0.03)
    V.tube(g, [(-0.2, L + 0.3, 1.05), (0.2, L + 0.3, 1.05)], 0.035, M(g, "Chrome"), 8)
    V.lathe(g, (0, L + 0.46, 1.21), (0, 0, 1), [(0.06, 0.0), (0.10, 0.04), (0.16, 0.14), (0.16, 0.20), (0.0, 0.23)],
            16 if g.hi else 12, M(g, "Chrome"))


def roof_and_sides(g):
    # roof rails on four feet, the crossbar and its four warm lamps
    for sx in (-1, 1):
        x = sx * (hwroof(10.0) - 0.20)
        ys = [7.0 + k * 6.6 / 5 for k in range(6)]
        V.tube(g, [(x, y, zr(y) - 0.14 + 0.20) for y in ys], 0.06, M(g, "Aluminium"), 8, fillet=0.4, fseg=2)
        for y in (7.1, 9.3, 11.6, 13.5):
            V.box(g, (x, y, zr(y) - 0.06), (0.14, 0.30, 0.22), M(g, "TrimGloss"), bev=0.0)
    zb_ = zr(ROOF_BAR_Y) + 0.06
    V.box(g, (0, ROOF_BAR_Y, zb_), (4.4, 0.36, 0.12), M(g, "TrimGloss"), bev=0.04)
    for k, x in enumerate((-1.35, -0.45, 0.45, 1.35)):   # rectangular LED pods: housing, chrome bezel, warm lens
        V.box(g, (x, ROOF_BAR_Y - 0.02, zb_ + 0.22), (0.66, 0.30, 0.30), M(g, "TrimGloss"), bev=0.05)
        V.box(g, (x, ROOF_BAR_Y - 0.17, zb_ + 0.22), (0.62, 0.03, 0.26), M(g, "Chrome"), bev=0.0)
        V.box(g, (x, ROOF_BAR_Y - 0.19, zb_ + 0.22), (0.54, 0.02, 0.19), M(g, "LensWarm"), bev=0.0)
        V.box(g, (x, ROOF_BAR_Y + 0.02, zb_ + 0.06), (0.10, 0.12, 0.10), M(g, "TrimGloss"), bev=0.0)
    for sx in (-1, 1):
        # cream mirror caps on black stalks
        V.box(g, (sx * 2.78, 5.55, 3.62), (0.26, 0.16, 0.30), M(g, "TrimGloss"), bev=0.03)
        K.loft_x(g, [(sx * 2.70, 5.62, 3.86, 0.10, 0.08), (sx * 2.86, 5.55, 3.90, 0.28, 0.20),
                     (sx * 3.10, 5.52, 3.92, 0.30, 0.21), (sx * 3.26, 5.56, 3.92, 0.24, 0.16),
                     (sx * 3.31, 5.61, 3.92, 0.12, 0.08)], M(g, "PaintCream"), seg=12, p=2.4)
        V.box(g, (sx * 3.02, 5.74, 3.92), (0.52, 0.02, 0.30), M(g, "Chrome"), bev=0.0)
        # chrome belt strip, sill strip, door handles, fender vent
        B.strip_z(g, 5.1, 14.25, lambda y: zbelt(y) - 0.07, lambda y: zbelt(y) - 0.005, sx, M(g, "Chrome"),
                  off=0.012)
        B.strip_z(g, AX_F + 1.55, AX_R - 1.55, 0.95, 1.22, sx, M(g, "Aluminium"), off=0.014, n=6)
        for hy in (AX_F, AX_R):   # gloss-black arch flares standing proud of the skin
            ar = R + 0.18
            B.strip_z(g, hy - ar - 0.30, hy + ar + 0.30, lambda y: B.half(y)[3][1] + 0.005,
                      lambda y: B.half(y)[3][1] + 0.24, sx, M(g, "TrimGloss"), off=0.045, n=8)
        for y0 in (7.15, 10.25):
            B.strip_z(g, y0, y0 + 0.55, lambda y: zbelt(y) - 0.36, lambda y: zbelt(y) - 0.26, sx, M(g, "Chrome"),
                      off=0.014, n=3)
        B.strip_z(g, 4.3, 4.95, 2.55, 2.85, sx, M(g, "GrilleMesh"), off=0.012, n=4)
        B.strip_z(g, 4.3, 4.95, 2.82, 2.88, sx, M(g, "Chrome"), off=0.02, n=4)


ATTACHMENTS = {
    "ATT_Wheel_FL": (HUB_X, AX_F, R),
    "ATT_Wheel_FR": (-HUB_X, AX_F, R),
    "ATT_Wheel_RL": (HUB_X, AX_R, R),
    "ATT_Wheel_RR": (-HUB_X, AX_R, R),
    "ATT_DriverSeat": (-SEAT_X, SEAT_Y, SEAT_Z),
    "ATT_Seat2": (SEAT_X, SEAT_Y, SEAT_Z),
    "ATT_Seat3": (1.5, REAR_Y, REAR_Z),
    "ATT_Seat4": (0.0, REAR_Y, REAR_Z),
    "ATT_Seat5": (-1.5, REAR_Y, REAR_Z),
    "ATT_EyePoint": (-SEAT_X, SEAT_Y - 0.2, SEAT_Z + 2.4),    # inherited eyePoint (0, 2.4, -0.2)
    "ATT_Headlamp_L": tuple(rake(Vector((1.92, -0.08, 2.68)))),
    "ATT_Headlamp_R": tuple(rake(Vector((-1.92, -0.08, 2.68)))),
    "ATT_TailLamp_L": (2.25, L + 0.07, 3.12),
    "ATT_TailLamp_R": (-2.25, L + 0.07, 3.12),
    "ATT_BrakeLamp_L": (2.25, L + 0.07, 2.86),
    "ATT_BrakeLamp_R": (-2.25, L + 0.07, 2.86),
    "ATT_ReverseLamp_L": (1.6, L + 0.07, 1.42),
    "ATT_ReverseLamp_R": (-1.6, L + 0.07, 1.42),
    "ATT_TowHitch": (0.0, L + 0.46, 1.44),
    "ATT_RoofLamp_01": (-1.35, ROOF_BAR_Y - 0.21, zr(ROOF_BAR_Y) + 0.28),
    "ATT_RoofLamp_02": (-0.45, ROOF_BAR_Y - 0.21, zr(ROOF_BAR_Y) + 0.28),
    "ATT_RoofLamp_03": (0.45, ROOF_BAR_Y - 0.21, zr(ROOF_BAR_Y) + 0.28),
    "ATT_RoofLamp_04": (1.35, ROOF_BAR_Y - 0.21, zr(ROOF_BAR_Y) + 0.28),
    "ATT_DriveAttachment": CHASSIS,
}


def build():
    global body, front
    body, front = raked(body), raked(front)
    unwrap = rbxkit.smart_uv
    body_set = V.build_set("Body", [(NAME + "_Body_LOD0", body)], unwrap, "MI_LighthouseCruiser_Body", angle=62)
    cab_set = V.build_set("Cab", [(NAME + "_Cab_LOD0", cabin), (NAME + "_Glass_LOD0", glass)], unwrap,
                          "MI_LighthouseCruiser_Cab", angle=55)
    wparts = [(NAME + "_Wheel_%s_LOD0" % t, wheel_fn(s, f)) for t, s, f in
              (("FL", 1, True), ("FR", -1, True), ("RL", 1, False), ("RR", -1, False))]
    wheels_set = V.build_set("Wheels", wparts + [(NAME + "_Underbody_LOD0", underbody)], unwrap,
                             "MI_LighthouseCruiser_Wheels", angle=50)

    def trim(g):
        front(g)
        rear(g)
        roof_and_sides(g)
    trim_set = V.build_set("Trim", [(NAME + "_Trim_LOD0", trim)], unwrap, "MI_LighthouseCruiser_Trim", angle=50)

    hps = [V.build_hp(NAME + "_Body_HP", [body]),
           V.build_hp(NAME + "_Cab_HP", [cabin], bevel=dict(width=0.008, segments=1, angle=40)),
           V.build_hp(NAME + "_Glass_HP", [glass]),
           V.build_hp(NAME + "_Underbody_HP", [underbody], bevel=dict(width=0.008, segments=1, angle=40)),
           V.build_hp(NAME + "_Trim_HP", [trim], bevel=dict(width=0.006, segments=1, angle=40))]
    hps += [V.build_hp(n.replace("_LOD0", "_HP"), [fn]) for n, fn in wparts]   # no HP bevel: a clean round lip
    col = K.collision_hull(NAME + "_COL", K.hull_points(B, (AX_F, AX_R), HUB_X, R, R))

    sets_objs = [(body_set, "Body"), (cab_set, "Cab"), (wheels_set, "Wheels"), (trim_set, "Trim")]
    meshes, atts, off = K.finish(NAME, HERE, sets_objs, hps, col, ATTACHMENTS, CHASSIS)

    wear = {"edge": 0.04, "edge_color": (0.62, 0.60, 0.58), "edge_metal": 0.0, "salt": 0.0,
            "salt_range": (0.45, 0.85), "salt_color": (0.70, 0.69, 0.65), "rust": 0.0, "ao_strength": 0.10}
    common = {"name": TEX, "size": 1024, "wet": True, "wet_streaks": 0.30, "cage_extrusion": 0.012,
              "max_ray_distance": 0.02}
    sets = [dict(common, set="Body", wet_darken=0.16, wet_gloss=0.10, ao_distance=1.6, wear=wear),
            dict(common, set="Cab", wet_darken=0.10, wet_gloss=0.10, ao_distance=1.2, wear=dict(wear, edge=0.03, salt=0.0)),
            dict(common, set="Wheels", wet_darken=0.25, wet_gloss=0.25, ao_distance=0.9,
                 wear=dict(wear, edge=0.06, salt=0.12)),
            dict(common, set="Trim", wet_darken=0.15, wet_gloss=0.15, ao_distance=0.8, wear=dict(wear, salt=0.06))]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    return {
        "name": NAME,
        "budget": "land_vehicle",
        "tris": 30000,
        "tier": "standard",
        "dims_m": (2.0, 4.95, 1.95),
        "size_note": "X includes the door mirrors (2.0 m is the body); Y includes the tow ball behind the bumper; Z is "
                     "to the top of the roof-bar lamps (the roof is 1.85 m).",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [
            {"name": "wheel_1m", "target": at((HUB_X + 0.3, AX_F, R)), "dist": 3.2, "az": 70, "el": 6},
            {"name": "grille_1m", "target": at((0.9, 0.0, 2.45)), "dist": 3.5, "az": 18, "el": 6},
            {"name": "roof_bar", "target": at((0.0, ROOF_BAR_Y, 5.75)), "dist": 5, "az": 25, "el": 20},
            {"name": "cabin", "target": at((-SEAT_X, 7.0, 3.4)), "dist": 6, "az": 280, "el": 14},
            {"name": "tail_hitch", "target": at((0.8, L, 1.9)), "dist": 5, "az": 160, "el": 10},
            {"name": "side_vent", "target": at((2.9, 4.6, 2.7)), "dist": 4, "az": 90, "el": 6},
        ],
        "waivers": {
            "texel density": "ship maps are 1024 (Roblox downsamples to 1024 at run time); 4 sets per the land_vehicle "
                             "class; paint is a clean clear-coat whose detail lives in geometry and the baked shut lines",
            "LOD UV layout": "collapse decimation moves small lamp, grille, spoke and tread islands at LOD1 / LOD2 "
                             "(seen past 150 / 500 studs, far below the island size in the mip chain); LOD0 unchanged",
            "geometry": "LOD2 slivers and loose verts left by collapse decimation of thin spokes, slats and strips",
        },
    }
