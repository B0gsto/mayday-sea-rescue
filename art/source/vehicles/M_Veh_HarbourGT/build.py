"""M_Veh_HarbourGT: premium (Robux) sports coupe, generic front-engined grand tourer (not a replica).

4.55 m x 1.95 m x 1.29 m (13.65 x 5.85 x 3.86 studs), 2.65 m wheelbase, 1.62 m track, 275/35 R20 on 20-inch forged
alloys (0.35 m radius). LandVehicleConfig.HarbourGT matches these numbers; the art aligns on ATT_Wheel_*.
Low wide body from one parametric skin (_CarPremium/carkit.py): fender crests above a dipped bonnet, wide rear
haunches, fastback roof into a duck-tail deck with a carbon wing. Deep crimson clear-coat, carbon roof / skirts /
splitter / diffuser / mirror caps, gloss-black DLO, slim LED headlamps with an eyebrow DRL, full-width LED tail bar,
quad titanium tips, gunmetal twin-spoke wheels with polished lips and bronze calipers, cognac and black leather
two-seat cabin. Gameplay markers as on the pickup: four wheel hubs, two seats (RHD, driver Blender -X), eye point,
head / tail / brake / reverse lamps, ATT_DriveAttachment.

Sets (each _Wet, ship 1024): Body (skin), Cab (interior + glass), Wheels (wheels, brakes, underbody), Trim (lamps,
grilles, aero, mirrors, plates).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/vehicles/M_Veh_HarbourGT/build.py --out-root build/prod/M_Veh_HarbourGT \
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
NAME = "M_Veh_HarbourGT"
TEX = "HarbourGT"

# --------------------------------------------------------------------------- layout (studs, 3 per metre)
L = 13.65
AX_F, AX_R = 2.85, 10.80             # 0.95 m front overhang, 2.65 m wheelbase
HUB_X = 2.43                         # 1.62 m track
R, RR, WW = 1.05, 0.762, 0.855       # 0.35 m tyre radius, 20-inch rim, 285 mm section
SEAT_X, SEAT_Y, SEAT_Z = 1.12, 7.55, 1.25
CHASSIS = (0.0, AX_F + 7.95 * (1 - 0.48), 0.45 * 3)   # frontWeight 0.48, cgHeight 0.45 m

K.paint("PaintGT", "#6A0C14", 0.10)          # deep crimson clear-coat
K.leather("LeatherTan", "#8E5C3C")           # cognac
K.leather("LeatherBlack", "#2B2B2D")
V.PALETTE.update({"RimGunmetal": ("#33363A", 0.24, 0.0), "BrakeBronze": ("#8C6A3E", 0.35, 0.0)})

CURVES = dict(
    L=L, axles=(AX_F, AX_R), wheel_z=R, arch_r=R + 0.20, arch_blend=0.30, flare=(0.10, 0.13), flare_sig=1.5,
    ds=0.32, KG=4, KR=8, crown=0.55,
    zb=C([(0, 0.80), (0.35, 0.54), (1.2, 0.42), (12.0, 0.44), (13.0, 0.66), (13.65, 0.96)]),
    hw=C([(0, 1.95), (0.25, 2.32), (0.7, 2.58), (1.4, 2.74), (2.85, 2.80), (5.0, 2.74), (7.0, 2.72), (9.0, 2.76),
          (10.8, 2.80), (12.4, 2.74), (13.1, 2.56), (13.45, 2.32), (13.65, 2.06)]),
    tuck=C([(0, 0.10), (1.0, 0.16), (12.6, 0.16), (13.65, 0.10)]),
    fsh=C([(0, 0.5), (13.65, 0.55)]),
    zbelt=C([(0, 1.45), (0.3, 1.80), (1.0, 2.20), (2.85, 2.62), (4.4, 2.66), (5.5, 2.62), (7.0, 2.66), (9.0, 2.78),
             (10.8, 2.92), (12.2, 2.95), (13.2, 2.86), (13.65, 2.55)]),
    hwb=C([(0, 1.70), (0.5, 2.15), (2.85, 2.45), (5.0, 2.42), (7.0, 2.40), (10.8, 2.52), (12.6, 2.45), (13.65, 1.85)]),
    zdeck=C([(0, 1.55), (0.35, 1.86), (1.2, 2.20), (2.85, 2.46), (4.5, 2.62), (6.0, 2.70), (9.0, 2.85), (11.5, 3.0),
             (12.8, 3.04), (13.3, 3.0), (13.65, 2.62)]),
    zr=C([(0, 1.0), (4.2, 2.2), (4.75, 2.70), (5.4, 3.20), (6.1, 3.62), (6.8, 3.82), (7.5, 3.86), (8.2, 3.80),
          (9.2, 3.55), (10.3, 3.26), (11.4, 3.05), (12.0, 2.9), (13.65, 1.5)]),
    zre=C([(0, 0.8), (4.2, 2.0), (4.9, 2.62), (5.5, 3.02), (6.2, 3.45), (6.9, 3.66), (7.6, 3.70), (8.3, 3.62),
           (9.3, 3.36), (10.3, 3.10), (11.2, 2.92), (12.0, 2.75), (13.65, 1.3)]),
    hwroof=C([(0, 1.6), (4.5, 2.10), (5.5, 2.0), (6.5, 1.92), (7.6, 1.90), (9.0, 1.95), (10.5, 2.10), (11.8, 2.25),
              (13.65, 1.6)]),
    extra=(4.75, 4.95, 5.0, 8.25, 8.42, 11.0, 12.55, 13.45),
    trim="TrimGloss", no_trim=("Carbon",), cap_mat="PaintGT",
)


def matfn(B, band, k, x, y, z):
    c = B.c
    ax = abs(x)
    if band == "bottom":
        return "Underseal"
    if band == "side":
        if k <= 2 and AX_F + 1.35 < y < AX_R - 1.35:
            return "Carbon"              # side skirt
        return "PaintGT"
    zbelt = c["zbelt"](y)
    if band == "glass":
        if 5.1 < y < 10.45 and zbelt + 0.07 < z < c["zre"](y) - 0.05:
            return "TrimGloss" if 8.25 < y < 8.42 else "Glass"
        if 4.85 < y < 11.2 and z > zbelt + 0.10:
            return "Carbon"              # A / C pillars run into the carbon roof
        return "PaintGT"
    hro = c["hwroof"](y)
    if 4.95 < y < 6.55 and ax < hro - 0.16:
        return "Glass"                   # windscreen
    if 8.75 < y < 11.0 and ax < hro - 0.30:
        return "Glass"                   # fastback rear glass
    if 4.85 < y < 11.2 and z > zbelt + 0.10:
        return "Carbon"
    return "PaintGT"


CURVES["matfn"] = matfn
B = K.Body(CURVES)
zbelt = CURVES["zbelt"]


# --------------------------------------------------------------------------- parts
def body(g):
    B.build(g, lambda m: m != "Glass")
    if g.hi:   # shut lines (bake only)
        for y in (5.0, 8.33):
            B.patch(g, [y - 0.012, y + 0.012], None, 1, "ShutLine", off=0.004, depth=0.01,
                    tfn=lambda yy: (B.t_at_z(yy, 0.62), B.t_at_z(yy, zbelt(yy) - 0.02)))
            B.patch(g, [y - 0.012, y + 0.012], None, -1, "ShutLine", off=0.004, depth=0.01,
                    tfn=lambda yy: (B.t_at_z(yy, 0.62), B.t_at_z(yy, zbelt(yy) - 0.02)))
        for side in (1, -1):
            tg = B.tband("glass", 0.6)
            for y0, y1 in ((0.55, 4.7), (11.35, 13.35)):
                ys = [y0 + (y1 - y0) * k / 14 for k in range(15)]
                B.patch(g, ys, (tg - 0.05, tg + 0.05), side, "ShutLine", off=0.004, depth=0.01)
            for y in (0.55, 11.35):
                B.patch(g, [y - 0.012, y + 0.012], (tg, B.tband("roof", B.KR)), side, "ShutLine", off=0.004, depth=0.01)


def glass(g):
    B.build(g, lambda m: m == "Glass", inset=0.03)


def cabin(g):
    lin = {"side": "LeatherBlack", "glass": "LeatherBlack", "roof": "InteriorDark", "bottom": "Carpet",
           "cap": "InteriorDark"}
    B.inner(g, 4.8, 11.05, lambda band: lin[band], off=0.07)
    for sx, drv in ((-1, True), (1, False)):
        K.seat(g, sx * SEAT_X, SEAT_Y, SEAT_Z, 1.55, M(g, "LeatherTan"), True, sport=True, recline=16,
               side_mat=M(g, "LeatherBlack"))
        V.box(g, (sx * SEAT_X, SEAT_Y, 0.80), (1.0, 1.3, 0.5), M(g, "InteriorDark"), bev=0.05)   # seat base
    # dash: lower block, leather top pad, binnacle, centre screen
    V.box(g, (0, 5.55, 2.15), (4.6, 1.0, 0.7), M(g, "InteriorDark"), bev=0.12)
    V.box(g, (0, 5.50, 2.56), (4.5, 0.95, 0.14), M(g, "LeatherBlack"), bev=0.06)
    V.box(g, (0, 6.03, 2.2), (4.3, 0.1, 0.16), M(g, "Carbon"), bev=0.03)
    V.box(g, (-SEAT_X, 5.92, 2.74), (1.05, 0.34, 0.24), M(g, "TrimGloss"), bev=0.06)
    V.box(g, (-SEAT_X, 6.09, 2.72), (0.92, 0.02, 0.16), M(g, "Screen"), bev=0.0)
    V.box(g, (0.0, 6.03, 2.52), (0.95, 0.06, 0.40), M(g, "Screen"), bev=0.02)
    for sx in (-1, 1):   # air vents
        V.box(g, (sx * 1.95, 6.07, 2.34), (0.42, 0.04, 0.14), M(g, "TrimGloss"), bev=0.02)
    # centre tunnel / console with the gear selector
    V.box(g, (0, 7.0, 1.0), (0.66, 2.8, 0.66), M(g, "Carbon"), bev=0.08)
    V.box(g, (0, 7.0, 1.36), (0.62, 2.6, 0.06), M(g, "LeatherBlack"), bev=0.02)
    V.box(g, (0, 6.55, 1.48), (0.14, 0.22, 0.20), M(g, "TrimGloss"), bev=0.04)
    # steering wheel and column
    K.steering_wheel(g, (-SEAT_X, 6.35, 2.28), 0.54, 22, M(g, "LeatherBlack"), M(g, "TrimGloss"))
    V.tube(g, [(-SEAT_X, 6.38, 2.28), (-SEAT_X, 5.9, 2.42)], 0.09, M(g, "TrimGloss"), 8)
    # parcel shelf behind the seats
    V.box(g, (0, 9.7, 2.6), (4.6, 2.2, 0.08), M(g, "InteriorDark"), bev=0.02)


def wheel_fn(side, front):
    spec = dict(R=R, RR=RR, W=WW, spokes=5, twin=0.15, w0=0.18, w1=0.13, depth=0.12, dish0=0.22, dish1=0.42,
                face="RimGunmetal", machined="RimPolished", lip="RimPolished", cap="TrimGloss")
    hub = (side * HUB_X, AX_F if front else AX_R, R)
    return lambda g: K.wheel(g, hub, side, spec)


def underbody(g):
    spec = dict(W=WW, disc=0.60, caliper="BrakeBronze")
    for side in (1, -1):
        for front, hy in ((True, AX_F), (False, AX_R)):
            K.brakes(g, (side * HUB_X, hy, R), side, spec, front)
            K.wheel_well(g, 2.85, hy, R, R + 0.22, 1.2, side)


def lamps_front(g):
    for side in (1, -1):
        lo = lambda y: zbelt(y) - 0.50 + 0.16 * y / 1.75          # noqa: E731
        hi = lambda y: zbelt(y) - 0.11                            # noqa: E731  (clear of the belt crease)
        # flush lamp: the units sit sunk in the skin (walls hidden), so only clean faces show: black bezel, chrome
        # reflector, LED eyebrow, twin projectors
        B.strip_z(g, 0.20, 1.60, lambda y: lo(y) - 0.05, lambda y: hi(y) + 0.025, side, M(g, "TrimGloss"), off=0.004,
                  depth=0.08, n=14)
        B.strip_z(g, 0.25, 1.54, lo, hi, side, M(g, "LampChrome"), off=0.008, depth=0.08, n=14)
        B.strip_z(g, 0.28, 1.52, lambda y: hi(y) - 0.075, lambda y: hi(y) - 0.03, side, M(g, "LED"), off=0.013, depth=0.08,
                  n=14)
        for y in (0.58, 1.02):
            t = B.t_at_z(y, (lo(y) + hi(y)) / 2 - 0.035)
            n = B.snormal(y, t, side)
            K.projector(g, B.surf(y, t, side) + n * 0.008, n, 0.105)
        # corner intakes
        B.strip_z(g, 0.12, 0.85, 0.66, 1.04, side, M(g, "GrilleMesh"), off=0.015)
    # main intake with carbon blades, upper slot, splitter, badge
    V.box(g, (0, -0.03, 1.02), (3.2, 0.08, 0.50), M(g, "GrilleMesh"), bev=0.03)
    V.box(g, (0, -0.01, 1.02), (3.42, 0.06, 0.64), M(g, "TrimGloss"), bev=0.05)
    for x in (-0.85, 0.85):
        V.box(g, (x, -0.06, 1.02), (0.06, 0.08, 0.50), M(g, "Carbon"), bev=0.0)
    V.box(g, (0, -0.015, 1.41), (1.7, 0.05, 0.09), M(g, "TrimGloss"), bev=0.02)
    V.box(g, (0, 0.18, 0.50), (4.0, 0.72, 0.06), M(g, "Carbon"), bev=0.02)
    V.lathe(g, (0, -0.01, 1.30), (0, -1, 0), [(0.12, 0.0), (0.12, 0.02), (0.09, 0.035), (0.0, 0.035)],
            16 if g.hi else 10, M(g, "Badge"))


def lamps_rear(g):
    # full-width LED tail bar in a gloss-black band under the duck-tail lip, wrapping round the corners
    V.box(g, (0, L + 0.01, 2.36), (4.1, 0.05, 0.30), M(g, "TrimGloss"), bev=0.02)
    V.box(g, (0, L + 0.035, 2.36), (4.0, 0.05, 0.16), M(g, "LensRed"), bev=0.02)
    V.box(g, (0, L + 0.06, 2.36), (3.9, 0.01, 0.035), M(g, "LensRedHi"), bev=0.0)
    for side in (1, -1):
        B.strip_z(g, 12.85, L - 0.01, 2.20, 2.50, side, M(g, "TrimGloss"), off=0.006, depth=0.08)
        B.strip_z(g, 12.9, L - 0.01, 2.28, 2.44, side, M(g, "LensRed"), off=0.012, depth=0.08)
        B.strip_z(g, 12.95, L - 0.01, 2.345, 2.375, side, M(g, "LensRedHi"), off=0.017, depth=0.08)
    # lower rear: black valance with the plate recess, carbon diffuser, fins, quad tips
    V.box(g, (0, L - 0.2, 0.98), (4.1, 0.5, 0.62), M(g, "TrimGloss"), bev=0.05)
    V.box(g, (0, L + 0.0, 1.62), (1.80, 0.05, 0.50), M(g, "TrimGloss"), bev=0.03)
    V.box(g, (0, 13.2, 0.60), (3.9, 0.95, 0.16), M(g, "Carbon"), bev=0.03)
    for x in (-1.55, -0.96, -0.45, 0.0, 0.45, 0.96, 1.55):
        V.box(g, (x, 13.3, 0.62), (0.04, 0.8, 0.36), M(g, "Carbon"), bev=0.0)
    for x in (-1.15, -0.78, 0.78, 1.15):
        V.lathe(g, (x, L - 0.25, 0.80), (0, 1, 0), [(0.13, 0.0), (0.14, 0.30), (0.115, 0.33), (0.10, 0.05)],
                16 if g.hi else 12, M(g, "Titanium"))
        V.lathe(g, (x, L - 0.05, 0.80), (0, 1, 0), [(0.10, 0.0), (0.0, 0.01)], 12 if g.hi else 8, M(g, "LampInner"))
    # plate, reverse lamps, badge
    V.box(g, (0, L + 0.04, 1.62), (1.56, 0.04, 0.34), M(g, "PlateWhite"), bev=0.01)
    for sx in (-1, 1):
        V.box(g, (sx * 1.55, L + 0.06, 1.12), (0.42, 0.04, 0.08), M(g, "LensWhite"), bev=0.01)
    if g.hi:   # text faces +Y: mirror X so it reads from behind
        me = V.text_mesh("GI 07 GT", 0.20, font_scale_x=0.9)
        g.add_mesh(me, "PlateLetter", lambda co: P(-co.x, L + 0.065, 1.62 + co.y))
        me = V.text_mesh("HARBOUR GT", 0.12, font_scale_x=1.1)
        g.add_mesh(me, "Badge", lambda co: P(-co.x, L + 0.012, 2.05 + co.y))


def aero_and_mirrors(g):
    # rear wing: carbon aerofoil on swan-neck struts, end plates
    prof = [(-0.45, 0.0), (-0.32, 0.065), (0.0, 0.09), (0.32, 0.065), (0.48, 0.02), (0.48, -0.01), (0.0, -0.035),
            (-0.40, -0.02)]
    V.extrude_profile(g, [(12.95 + y, 3.45 + z) for y, z in prof], -2.15, 2.15, M(g, "Carbon"), bev=0.01)
    for sx in (-1, 1):
        V.box(g, (sx * 2.17, 12.98, 3.40), (0.04, 1.0, 0.26), M(g, "Carbon"), bev=0.01)
        V.box(g, (sx * 1.05, 13.0, 3.22), (0.06, 0.32, 0.44), M(g, "TrimGloss"), bev=0.015)
        # mirrors
        V.box(g, (sx * 2.55, 5.42, 2.78), (0.26, 0.14, 0.30), M(g, "Carbon"), bev=0.03)
        K.loft_x(g, [(sx * 2.50, 5.50, 2.97, 0.10, 0.07), (sx * 2.66, 5.42, 3.0, 0.24, 0.15),
                     (sx * 2.88, 5.40, 3.01, 0.26, 0.16), (sx * 3.02, 5.43, 3.01, 0.21, 0.12),
                     (sx * 3.07, 5.47, 3.01, 0.10, 0.06)], M(g, "Carbon"), seg=12, p=2.4)
        V.box(g, (sx * 2.80, 5.60, 3.01), (0.46, 0.02, 0.22), M(g, "Chrome"), bev=0.0)
        # flush door handles and the side vents behind the front wheels
        B.strip_z(g, 7.55, 7.95, lambda y: zbelt(y) - 0.30, lambda y: zbelt(y) - 0.21, sx, M(g, "Chrome"), off=0.012, n=3)
        B.strip_z(g, 4.35, 4.95, 1.45, 1.95, sx, M(g, "GrilleMesh"), off=0.012, n=4)


ATTACHMENTS = {
    "ATT_Wheel_FL": (HUB_X, AX_F, R),
    "ATT_Wheel_FR": (-HUB_X, AX_F, R),
    "ATT_Wheel_RL": (HUB_X, AX_R, R),
    "ATT_Wheel_RR": (-HUB_X, AX_R, R),
    "ATT_DriverSeat": (-SEAT_X, SEAT_Y, SEAT_Z),
    "ATT_Seat2": (SEAT_X, SEAT_Y, SEAT_Z),
    "ATT_EyePoint": (-SEAT_X, SEAT_Y, SEAT_Z + 1.9),     # LandVehicleConfig.HarbourGT eyePoint (0, 1.9, 0)
    "ATT_Headlamp_L": tuple(B.surf(0.6, B.t_at_z(0.6, zbelt(0.6) - 0.22), 1)),
    "ATT_Headlamp_R": tuple(B.surf(0.6, B.t_at_z(0.6, zbelt(0.6) - 0.22), -1)),
    "ATT_TailLamp_L": (1.95, L + 0.05, 2.36),
    "ATT_TailLamp_R": (-1.95, L + 0.05, 2.36),
    "ATT_BrakeLamp_L": (1.0, L + 0.05, 2.36),
    "ATT_BrakeLamp_R": (-1.0, L + 0.05, 2.36),
    "ATT_ReverseLamp_L": (1.55, L + 0.08, 1.12),
    "ATT_ReverseLamp_R": (-1.55, L + 0.08, 1.12),
    "ATT_DriveAttachment": CHASSIS,
}


def build():
    unwrap = rbxkit.smart_uv
    body_set = V.build_set("Body", [(NAME + "_Body_LOD0", body)], unwrap, "MI_HarbourGT_Body", angle=62)
    cab_set = V.build_set("Cab", [(NAME + "_Cab_LOD0", cabin), (NAME + "_Glass_LOD0", glass)], unwrap,
                          "MI_HarbourGT_Cab", angle=55)
    wparts = [(NAME + "_Wheel_%s_LOD0" % t, wheel_fn(s, f)) for t, s, f in
              (("FL", 1, True), ("FR", -1, True), ("RL", 1, False), ("RR", -1, False))]
    wheels_set = V.build_set("Wheels", wparts + [(NAME + "_Underbody_LOD0", underbody)], unwrap,
                             "MI_HarbourGT_Wheels", angle=50)

    def trim(g):
        lamps_front(g)
        lamps_rear(g)
        aero_and_mirrors(g)
    trim_set = V.build_set("Trim", [(NAME + "_Trim_LOD0", trim)], unwrap, "MI_HarbourGT_Trim", angle=50)

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
    sets = [dict(common, set="Body", wet_darken=0.16, wet_gloss=0.10, ao_distance=1.4, wear=wear),
            dict(common, set="Cab", wet_darken=0.10, wet_gloss=0.10, ao_distance=1.0, wear=dict(wear, edge=0.03, salt=0.0)),
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
        "dims_m": (1.95, 4.55, 1.29),
        "size_note": "X includes the door mirrors (the 1.95 m body width is to the rear haunches); Y includes the "
                     "splitter lip ahead of the nose.",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [
            {"name": "wheel_1m", "target": at((HUB_X + 0.3, AX_F, R)), "dist": 3, "az": 70, "el": 6},
            {"name": "headlamp_1m", "target": at((1.9, 0.7, 1.95)), "dist": 3, "az": 40, "el": 10},
            {"name": "tail_1m", "target": at((1.3, L, 2.0)), "dist": 3.5, "az": 160, "el": 8},
            {"name": "cabin", "target": at((-SEAT_X, 6.6, 2.4)), "dist": 5, "az": 280, "el": 14},
            {"name": "wing", "target": at((0.9, 12.9, 3.2)), "dist": 5, "az": 140, "el": 22},
            {"name": "nose", "target": at((0.0, 0.3, 1.3)), "dist": 5, "az": 20, "el": 8},
        ],
        "waivers": {
            "texel density": "ship maps are 1024 (Roblox downsamples to 1024 at run time); 4 sets per the land_vehicle "
                             "class; paint is a clean clear-coat whose detail lives in geometry and the baked shut lines",
            "LOD UV layout": "collapse decimation moves small lamp, grille, spoke and tread islands at LOD1 / LOD2 "
                             "(seen past 150 / 500 studs, far below the island size in the mip chain); LOD0 unchanged",
            "geometry": "LOD2 slivers and loose verts left by collapse decimation of thin spokes, fins and strips",
        },
    }
