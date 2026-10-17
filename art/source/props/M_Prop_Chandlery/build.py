"""H2 M_Prop_Chandlery: the Port Haven Chandlery stock (docs/12 props row, 05 hero location, 04 section 1 shop places).

About 30 props authored in place in the shared Chandlery frame (art/source/buildings/M_Bld_Chandlery_Ext/layout.py:
metres x 3 = studs, front -Y, floor 0.15, loft 3.35, beams at BEAM_XS with undersides at 2.95), so the props Model drops
in at the same pivot as M_Bld_Chandlery_Ext and _Int. The interior (floor, walls, counter, till, stairs, lamps) is not
modelled here.

MeshParts (one material each, all on the shared atlas T_ChandleryProps_Atlas_* except Rope on T_ChandleryProps_Rope_*):
  RackWall   west wall rail: inflatable lifejackets and foam buoyancy aids face-out on hangers, 3 SOLAS ring buoys above,
             the horn board (4 horns, push buttons, plaques)
  RackMid    free-standing rail: foul-weather jackets and salopettes on hangers, sea boots on the floor
  Gondola    double-sided shelf unit: bins of shackles, D-shackles on pegs, blocks, horn cleats, shelf-edge price tags
  Mannequins 4 faceless dress-form mannequins (no body mesh: garments merged into the same mesh) on bases:
             foul-weather red, Hi-Vis, crew drysuit + lifejacket, navy offshore
  Hung       fenders and mooring buoys on eyebolts under the beams
  Corner     dog basket with cushion and tartan blanket, low rail of dog coats, livery swatch board, VHF radio on its shelf
  Rope       rope.py: hanks (three-strand, braid) on the gondola, whippings and tails, hanging lines, ring-buoy grab lines

    python3 art/source/props/M_Prop_Chandlery/maketex.py
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Prop_Chandlery --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(G, "art/source/buildings/M_Bld_Chandlery_Ext"))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import atlas  # noqa: E402
import kit  # noqa: E402
import layout as L  # noqa: E402
import rope  # noqa: E402
import versions  # noqa: E402
from kit import Part, RopePart, frame, fit_frame  # noqa: E402

NAME = "M_Prop_Chandlery"
F = L.FLOOR
ROPE = RopePart("Rope")


def W(M, p):
    return M @ Vector(p)


def Ws(M, pts):
    return [M @ Vector(p) for p in pts]


# ------------------------------------------------------------------ small parts
def tag(P, M, i, hole_to=None):
    """Paper price tag (0.045 x 0.09 m, both faces printed) hanging from local origin; string to world point hole_to."""
    w, h = atlas.TAG_M
    rc = atlas.tag_rect(i % atlas.N_TAGS)
    R3 = M.to_3x3()
    fits = {"-y": ("Tags", fit_frame(W(M, (-w / 2, 0, -0.012 - h)), R3 @ Vector((1, 0, 0)), R3 @ Vector((0, 0, 1)), w, h, rc)),
            "+y": ("Tags", fit_frame(W(M, (w / 2, 0, -0.012 - h)), R3 @ Vector((-1, 0, 0)), R3 @ Vector((0, 0, 1)), w, h, rc))}
    P.box((-w / 2, -0.0007, -0.012 - h), (w / 2, 0.0007, -0.012), "Card", M, fits=fits)
    if hole_to is not None:
        a = W(M, (0, 0, -0.02))
        b = Vector(hole_to)
        P.sweep([a, (a + b) / 2 + Vector((0, 0, 0.006)), b], 0.0012, 3, "String")


def hanger(P, M, w=0.42, wood=True):
    """Hanger hooked over a rail along local X at the origin; the bar is at z -0.10 .. -0.15."""
    P.sweep(Ws(M, [(-w / 2, 0, -0.15), (-w / 4, 0, -0.118), (0, 0, -0.10), (w / 4, 0, -0.118), (w / 2, 0, -0.15)]),
            0.009, 4, "Pine" if wood else "BlackPlastic", rx=0.006)
    hook = [(0, 0, -0.10), (0, -0.012, -0.05), (0, -0.021, -0.012)]
    hook += [(0, 0.021 * math.cos(a), 0.021 * math.sin(a)) for a in np.radians([180, 120, 60, 0, -40])]
    P.sweep(Ws(M, hook), 0.0024, 3, "Stainless")


def front_y(prof, sy, z, x=0.0):
    """Front surface (-y) of an elliptic lathe at height z and lateral x."""
    zs = [p[1] for p in prof]
    rs = [p[0] for p in prof]
    r = float(np.interp(z, zs, rs))
    return -sy * math.sqrt(max(r * r - x * x, 1e-6))


def zip_line(P, M, prof, sy, z0, z1, x0=0.0, x1=0.0, n=6, region="Zip"):
    pts = []
    for k in range(n):
        t = k / (n - 1)
        z, x = z0 + (z1 - z0) * t, x0 + (x1 - x0) * t
        pts.append(W(M, (x, front_y(prof, sy, z, x) - 0.004, z)))
    P.sweep(pts, 0.004, 4, region, rx=0.011)


def band(P, M, prof, sy, z0, z1, region, segs=12, grow=0.006, offset=(0, 0)):
    zs, rs = [p[1] for p in prof], [p[0] for p in prof]
    pr = [(float(np.interp(z, zs, rs)) + grow / sy, z) for z in (z0, z1)]
    P.lathe(pr, segs, region, M, 1.0, sy, False, False, offset=offset)


# ------------------------------------------------------------------ garments on hangers (local: rail along X at origin)
def foam_vest(P, M, region, ti):
    hanger(P, M, 0.38)
    prof = [(0.20, -0.70), (0.215, -0.58), (0.21, -0.40), (0.185, -0.26), (0.12, -0.17)]
    sy = 0.36
    P.lathe(prof, 10, region, M, 1.0, sy, True, True)
    for z in (-0.47, -0.62):
        band(P, M, prof, sy, z - 0.018, z + 0.018, "Webbing", 10, 0.007)
        y = front_y(prof, sy, z, 0.07) - 0.006
        P.box((0.045, y - 0.006, z - 0.022), (0.10, y + 0.004, z + 0.022), "BlackPlastic", M)
    zip_line(P, M, prof, sy, -0.69, -0.24, n=4)
    for s in (-1, 1):
        P.box((s * 0.06 - 0.035, -0.035, -0.205), (s * 0.06 + 0.035, 0.035, -0.175), "Tape", M)
    tag(P, M @ Matrix.Translation((0.03, -0.09, -0.16)), ti, W(M, (0.0, -0.01, -0.10)))


def inflatable(P, M, region, ti):
    hanger(P, M, 0.36)
    lobe = [(0.03, -0.56), (0.058, -0.52), (0.064, -0.38), (0.056, -0.24), (0.04, -0.16)]
    for s in (-1, 1):
        P.lathe(lobe, 8, region, M, 1.0, 0.62, True, True, offset=(s * 0.085, 0.0))
        P.box((s * 0.085 - 0.03, -0.044, -0.36), (s * 0.085 + 0.03, -0.030, -0.33), "Tape", M)
    P.box((-0.06, -0.025, -0.19), (0.06, 0.025, -0.15), region, M)
    P.box((-0.15, -0.02, -0.54), (0.15, -0.008, -0.51), "Webbing", M)
    P.box((-0.025, -0.03, -0.55), (0.025, -0.012, -0.50), "BlackPlastic", M)
    P.box((0.10, -0.045, -0.47), (0.125, -0.025, -0.42), "LJ_Orange", M)
    tag(P, M @ Matrix.Translation((-0.03, -0.06, -0.15)), ti, W(M, (0.0, -0.01, -0.10)))


JACKET = [(0.25, -0.86), (0.25, -0.62), (0.235, -0.38), (0.205, -0.24), (0.13, -0.17)]


def jacket(P, M, body, trim, ti=None, tape=True):
    hanger(P, M, 0.44)
    sy = 0.42
    P.lathe(JACKET, 12, body, M, 1.0, sy, True, True, cap_region=trim)
    for s in (-1, 1):
        a, b = (s * 0.225, 0.0, -0.24), (s * 0.27, -0.015, -0.80)
        P.cyl(W(M, a), W(M, b), 0.062, 6, body, r1=0.055, caps=False)
        P.cyl(W(M, (s * 0.268, -0.014, -0.78)), W(M, (s * 0.272, -0.016, -0.84)), 0.058, 6, "Neoprene")
        y = front_y(JACKET, sy, -0.42, s * 0.12)
        P.box((s * 0.12 - 0.065, y - 0.012, -0.44), (s * 0.12 + 0.065, y + 0.01, -0.40), body, M)
        y = front_y(JACKET, sy, -0.66, s * 0.14)
        P.box((s * 0.14 - 0.06, y - 0.012, -0.68), (s * 0.14 + 0.06, y + 0.01, -0.64), body, M)
        if tape:
            P.box((s * 0.17 - 0.04, -0.06, -0.26), (s * 0.17 + 0.04, 0.0, -0.205), "Tape", M)
    P.lathe([(0.088, -0.20), (0.092, -0.06), (0.084, -0.06), (0.08, -0.19)], 10, trim, M, 1.0, 0.75, False, False)
    zip_line(P, M, JACKET, sy, -0.85, -0.2, n=5)
    if ti is not None:
        tag(P, M @ Matrix.Translation((0.272, -0.05, -0.84)), ti, W(M, (0.27, -0.03, -0.82)))


def salopettes(P, M, body, trim):
    hanger(P, M, 0.36, wood=False)
    sy = 0.45
    bib = [(0.19, -0.62), (0.18, -0.42), (0.16, -0.27)]
    P.lathe(bib, 10, body, M, 1.0, sy, True, True)
    for s in (-1, 1):
        leg = [(0.085, -1.30), (0.09, -1.0), (0.105, -0.78), (0.12, -0.62)]
        P.lathe(leg, 8, body, M, 1.0, 0.8, True, False, offset=(s * 0.085, 0.0), cap_region=trim)
        P.box((s * 0.085 - 0.06, -0.085, -1.02), (s * 0.085 + 0.06, -0.06, -0.86), trim, M)
        P.sweep(Ws(M, [(s * 0.1, -0.03, -0.28), (s * 0.15, -0.01, -0.2), (s * 0.17, 0, -0.15)]), 0.003, 4, "Webbing", rx=0.014)
    zip_line(P, M, bib, sy, -0.6, -0.3, n=3)


def boot(P, x, y, z, yaw=0.0, region="Boot"):
    M = frame(x, y, z, yaw)
    P.lathe([(0.064, 0.05), (0.069, 0.20), (0.074, 0.33), (0.068, 0.33), (0.062, 0.30)], 8, region, M, 1.0, 1.05, False, False)
    P.lathe([(0.06, 0.012), (0.066, 0.05), (0.05, 0.11)], 8, region, M, 1.0, 1.75, False, True, offset=(0, -0.045))
    P.box((-0.055, -0.15, 0.0), (0.055, 0.075, 0.022), "Sole", M)
    P.box((-0.068, -0.02, 0.24), (0.068, 0.02, 0.27), "Tape", M)


# ------------------------------------------------------------------ groups
def rack_wall():
    P = Part("RackWall")
    x, y0, y1 = L.RACK_WALL
    zr = 1.7
    P.cyl((x, y0 - 0.15, zr), (x, y1 + 0.15, zr), 0.016, 8, "Galv")
    for yb in (y0 - 0.05, (y0 + y1) / 2 + 0.268, y1 + 0.05):
        P.cyl((L.IX0, yb, zr), (x, yb, zr), 0.012, 6, "Galv", caps=False)
        P.cyl((L.IX0 + 0.004, yb, zr), (L.IX0 + 0.012, yb, zr), 0.04, 8, "Galv")
    ys = np.linspace(y0 + 0.3, y1 - 0.3, 13)
    for k, yy in enumerate(ys):
        M = frame(x, yy, zr, 90.0)
        if k < 6:
            inflatable(P, M, "FW_Navy" if k % 3 else "FW_Red", 0 if k % 2 else 1)
        else:
            foam_vest(P, M, "LJ_Orange" if k % 4 else "HV_Yellow", 1 if k % 2 else 0)
    for yy in (-2.2, 0.4, 3.0):          # SOLAS ring buoys on wall hooks above the rail
        M = frame(L.IX0 + 0.12, yy, 2.35, 0) @ Matrix.Rotation(math.radians(90), 4, 'Y')
        P.torus(0.30, 0.075, 14, 6, "Foam", M)
        for k in range(4):
            P.torus(0.30, 0.079, 2, 6, "Tape", M, arc=0.22, a0=math.pi / 4 + k * math.pi / 2 - 0.11)
        P.cyl((L.IX0, yy, 2.535), (L.IX0 + 0.21, yy, 2.56), 0.011, 6, "Galv")
        P.box((L.IX0 - 0.01, yy - 0.04, 2.49), (L.IX0 + 0.012, yy + 0.04, 2.59), "Galv")
        pts = []
        for k in range(4):
            a0 = math.pi / 4 + k * math.pi / 2
            for t in np.linspace(0, 1, 6)[:-1] if k < 3 else np.linspace(0, 1, 6):
                a = a0 + t * math.pi / 2
                sag = 0.05 * math.sin(math.pi * t)
                pts.append(tuple(M @ Vector(((0.38 + sag) * math.cos(a), (0.38 + sag) * math.sin(a), 0.0))))
        ROPE.tube(rope, pts, 0.01, "Cream", "plain", sides=4, max_tris=180, caps=False)
    # horn board (ATT_HornBoard), west wall, faces +X
    ax, ay, az = L.ATT["ATT_HornBoard"]
    bw, bh = atlas.BOARD_M
    bx0, bx1 = L.IX0 + 0.02, L.IX0 + 0.045
    by0, bz0 = ay - bw / 2, az - bh / 2
    fits = {"+x": ("HornBoard", fit_frame((bx1, by0, bz0), (0, 1, 0), (0, 0, 1), bw, bh, atlas.rect("HornBoard")))}
    P.box((bx0, by0, bz0), (bx1, by0 + bw, bz0 + bh), "PaintBoard", fits=fits)
    for zz in (bz0 + 0.08, bz0 + bh - 0.08):
        P.box((L.IX0 - 0.01, by0 + 0.05, zz - 0.02), (bx0 + 0.001, by0 + bw - 0.05, zz + 0.02), "Pine")
    horns = [  # (u, bell radius, length, region, twin)
        (0.14, 0.085, 0.30, "Chrome", False), (0.38, 0.05, 0.22, "Chrome", True),
        (0.62, 0.04, 0.16, "FW_Red", False), (0.86, 0.075, 0.26, "Brass", False)]
    for u, rb, ln, reg, twin in horns:
        yc = by0 + u * bw
        for dz, sc in ((0.0, 1.0),) + (((0.09, 0.8),) if twin else ()):
            zc = bz0 + 0.36 + dz
            ln2 = ln * sc
            prof = [(0.014, 0.0), (0.016, ln2 * 0.45), (0.024, ln2 * 0.72), (rb * sc * 0.6, ln2 * 0.92), (rb * sc, ln2)]
            Mh = frame(bx1 + rb * sc + 0.015, yc - ln2 / 2, zc, 0.0, -90.0)
            P.lathe(prof, 10, reg, Mh, cap0=True, cap1=False)
            P.lathe([(rb * sc * 0.96, ln2 * 0.995), (0.018, ln2 * 0.8)], 10, "BlackPlastic", Mh, cap0=False, cap1=True)
        if u == 0.62:      # air horn canister
            P.cyl((bx1 + 0.035, yc - 0.12, bz0 + 0.27), (bx1 + 0.035, yc - 0.12, bz0 + 0.42), 0.032, 10, "Stainless")
        P.box((bx1, yc - 0.02, zc - 0.02), (bx1 + rb + 0.012, yc + 0.02, zc + 0.02), "Galv")
        P.cyl((bx1, yc, bz0 + 0.21), (bx1 + 0.018, yc, bz0 + 0.21), 0.022, 10, "Brass")
        P.cyl((bx1 + 0.018, yc, bz0 + 0.21), (bx1 + 0.03, yc, bz0 + 0.21), 0.015, 10, "Rubber")
    return P


def rack_mid():
    P = Part("RackMid")
    x0, x1, y = L.RACK_MID
    zr = 1.65
    P.cyl((x0 - 0.05, y, zr), (x1 + 0.05, y, zr), 0.016, 8, "Galv")
    for xe in (x0, x1):
        P.cyl((xe, y, F + 0.06), (xe, y, zr + 0.03), 0.019, 8, "Galv")
        P.cyl((xe, y - 0.3, F + 0.05), (xe, y + 0.3, F + 0.05), 0.019, 8, "Galv")
        for dy in (-0.28, 0.28):
            P.cyl((xe, y + dy, F), (xe, y + dy, F + 0.03), 0.025, 8, "Rubber")
        P.lathe([(0.03, zr + 0.03), (0.022, zr + 0.06)], 8, "Galv", Matrix.Translation((xe, y, 0)))
    kinds = ["J", "S", "J", "J", "S", "J"]
    looks = [("FW_Red", "FW_Grey"), ("FW_Navy", "FW_Grey"), ("FW_Navy", "FW_Red"), ("HV_Yellow", "FW_Navy"),
             ("FW_Red", "FW_Navy"), ("FW_Grey", "FW_Red"), ("FW_Red", "FW_Grey")]
    for k, (xx, kind) in enumerate(zip(np.linspace(x0 + 0.33, x1 - 0.33, len(kinds)), kinds)):
        M = frame(xx, y + (0.015 if k % 2 else -0.015), zr)
        body, trim = looks[k]
        if kind == "J":
            jacket(P, M, body, trim, ti=5 if k % 2 == 0 else None)
        else:
            salopettes(P, M, body, trim)
    for k, xx in enumerate(np.linspace(x0 + 0.5, x1 - 0.5, 4)):
        for s in (-1, 1):
            boot(P, xx + s * 0.075, y - 0.42, F + 0.001, 4.0 * s + 6 * (k % 2), "Boot" if k % 2 == 0 else "Rubber")
    return P


def shackle(P, M, size=1.0, region="Stainless"):
    R, r, leg = 0.018 * size, 0.0045 * size, 0.022 * size
    P.torus(R, r, 6, 3, region, M @ Matrix.Rotation(math.radians(90), 4, 'X'), arc=math.pi)
    for s in (-1, 1):
        P.cyl(W(M, (s * R, 0, 0)), W(M, (s * R, 0, -leg)), r, 3, region, caps=False)
        P.cyl(W(M, (s * R, 0, -leg)), W(M, (s * R * 1.0, 0, -leg - 0.008 * size)), r * 1.5, 4, region, caps=False)
    P.cyl(W(M, (-R - 0.006 * size, 0, -leg - 0.004 * size)), W(M, (R + 0.01 * size, 0, -leg - 0.004 * size)), r * 1.1, 4, region)


def block(P, M):
    for s in (-1, 1):
        P.lathe([(0.03, s * 0.012), (0.034, s * 0.016)], 10, "BlackPlastic",
                M @ Matrix.Rotation(math.radians(90), 4, 'Y'), 1.0, 1.45, True, True)
    P.cyl(W(M, (-0.012, 0, 0)), W(M, (0.012, 0, 0)), 0.024, 8, "Stainless")
    P.torus(0.014, 0.004, 6, 4, "Stainless", M @ Matrix.Translation((0, 0, 0.06)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))


def cleat(P, M, region="Stainless"):
    P.box((-0.07, -0.012, 0.0), (0.07, 0.012, 0.008), region, M)
    for s in (-1, 1):
        P.box((s * 0.03 - 0.008, -0.009, 0.0), (s * 0.03 + 0.008, 0.009, 0.026), region, M)
    P.cyl(W(M, (-0.09, 0, 0.032)), W(M, (0.09, 0, 0.032)), 0.011, 5, region, r1=0.011)


def bin_(P, x0, y0, z0, w, d, h, ti, contents="Stainless"):
    t = 0.004
    P.box((x0, y0, z0), (x0 + w, y0 + d, z0 + h), "Plastic", skip=("+z",))
    P.box((x0 + t, y0 + t, z0 + t), (x0 + w - t, y0 + d - t, z0 + h), "Plastic", skip=("+z",))
    P.f[-5:] = [(list(reversed(f[0])), f[1], f[2]) for f in P.f[-5:]]
    a = 0
    Ms = frame(x0 + w * 0.5, y0 + d * 0.3, z0 + h * 0.62, 30, 70, 15)
    shackle(P, Ms, 1.5, contents)
    P.box((x0 + 0.01, y0 + 0.01, z0 + t), (x0 + w - 0.01, y0 + d - 0.01, z0 + h * 0.45), contents)
    return a


def gondola():
    P = Part("Gondola")
    x0, x1, y0, y1 = L.GONDOLA
    H = 1.4
    yc = (y0 + y1) / 2
    P.box((x0 + 0.03, y0 + 0.06, F), (x1 - 0.03, y1 - 0.06, F + 0.11), "PaintBoard")
    for xe in (x0, x1 - 0.03, (x0 + x1) / 2 - 0.015):
        P.box((xe, y0, F), (xe + 0.03, y1, F + H), "Pine")
    P.box((x0 + 0.03, yc - 0.012, F + 0.11), (x1 - 0.03, yc + 0.012, F + H - 0.002), "PaintBoard")
    P.box((x0 - 0.01, y0 - 0.01, F + H), (x1 + 0.01, y1 + 0.01, F + H + 0.03), "Pine")
    shelves = [F + 0.125, F + 0.55, F + 0.97]
    for side, (ya, yb) in (("S", (y0, yc - 0.012)), ("N", (yc + 0.012, y1))):
        xm_ = (x0 + x1) / 2
        for zs in shelves:
            for bx0, bx1 in ((x0 + 0.03, xm_ - 0.015), (xm_ + 0.015, x1 - 0.03)):
                P.box((bx0, ya + 0.002, zs), (bx1, yb - 0.002, zs + 0.025), "Pine")
                yl = y0 - 0.006 if side == "S" else y1 + 0.001
                P.box((bx0, yl, zs - 0.02), (bx1, yl + 0.005, zs + 0.035), "PaintBoard")
    xm = (x0 + x1) / 2
    holder = []          # where the hanks go (rope.py)
    ti = 2
    for side in ("S", "N"):
        sgn = -1 if side == "S" else 1
        yf = y0 if side == "S" else y1
        ymid = (yf + yc) / 2
        zs = shelves[2] + 0.025
        # top shelf: hanks (rope part)
        for k, xx in enumerate(np.linspace(x0 + 0.35, xm - 0.3, 3)):
            holder.append((xx, ymid, zs, ["ManilaHank", "CreamHank", "NavyHank", "GreenHank"][(k + (side == "N")) % 4]))
        # top shelf, east bay: blocks and cleats on the shelf
        for k, xx in enumerate(np.linspace(xm + 0.25, x1 - 0.3, 4)):
            if k % 2 == 0:
                block(P, frame(xx, ymid, zs + 0.05, 0, 0, 0))
            else:
                cleat(P, frame(xx, ymid + sgn * 0.05, zs, 90 * (side == "N") + 10), "Stainless" if k == 1 else "BlackPlastic")
        # middle shelf: bins of shackles with tags on the shelf lip
        zm = shelves[1] + 0.025
        for k, xx in enumerate(np.linspace(x0 + 0.1, x1 - 0.42, 6)):
            dd = abs(yf - yc) - 0.06
            yb0 = yc + 0.03 if side == "N" else yf + 0.02
            bin_(P, xx, yb0, zm, 0.3, dd, 0.14, ti, "Stainless" if k % 2 else "Galv")
            yl = yf + sgn * 0.009
            tag(P, frame(xx + 0.15, yl, zm + 0.016, 0 if side == "S" else 180), ti)
            ti = (ti + 1) % 5 + 2
        # bottom deck: big hanks west bay, shackles on pegs above the middle shelf east bay
        zb = shelves[0] + 0.025
        holder.append((x0 + 0.5, ymid, zb, "NavyHank" if side == "S" else "ManilaHank"))
        holder.append((x0 + 1.15, ymid, zb, "CreamHank"))
        for k, xx in enumerate(np.linspace(xm + 0.3, x1 - 0.3, 3)):
            zp = shelves[1] + 0.33
            ys = yc + sgn * 0.012
            P.cyl((xx, ys, zp), (xx, ys + sgn * 0.16, zp + 0.02), 0.005, 5, "Stainless")
            for j in range(2):
                shackle(P, frame(xx, ys + sgn * (0.06 + 0.06 * j), zp + 0.012 + 0.008 * j), 1.6, "Galv" if k == 1 else "Stainless")
            tag(P, frame(xx, ys + sgn * 0.165, zp + 0.01, 0 if side == "S" else 180), 4)
        # bottom deck east bay: boxed fenders stand-in = blocks laid out
        for k, xx in enumerate(np.linspace(xm + 0.3, x1 - 0.35, 3)):
            block(P, frame(xx, ymid, zb + 0.04, 0, 90, 0))
    return P, holder


def hung():
    P = Part("Hung")
    items = [(-4.8, -2.3, "F"), (-4.8, -1.55, "F"), (-2.4, -2.0, "F"), (-2.4, -0.9, "B"), (2.4, -2.6, "F"), (2.4, -3.5, "B")]
    for k, (x, y, kind) in enumerate(items):
        zb = L.BEAM_UNDERSIDE
        P.box((x - 0.04, y - 0.04, zb - 0.012), (x + 0.04, y + 0.04, zb + 0.01), "Galv")
        P.torus(0.022, 0.006, 6, 4, "Galv", frame(x, y, zb - 0.034) @ Matrix.Rotation(math.radians(90), 4, 'X'))
        P.cyl((x, y, zb - 0.012), (x, y, zb - 0.012 - 0.01), 0.007, 4, "Galv")
        if kind == "F":
            top = zb - 0.30 - 0.06 * (k % 2)
            L_ = 0.58
            prof = [(0.03, 0.0), (0.075, 0.012), (0.10, 0.045), (0.108, 0.10), (0.108, L_ - 0.10), (0.10, L_ - 0.045),
                    (0.075, L_ - 0.012), (0.03, L_)]
            M = Matrix.Translation((x, y, top - L_))
            P.lathe(prof, 12, "FenderPVC", M)
            for zz in (top + 0.03, top - L_ - 0.03):
                P.torus(0.024, 0.008, 6, 3, "FenderPVC", frame(x, y, zz) @ Matrix.Rotation(math.radians(90), 4, 'X'))
            eye_top = top + 0.055
        else:
            Rb = 0.19
            top = zb - 0.45
            prof = [(0.02, -Rb)] + [(Rb * math.sin(a), -Rb * math.cos(a)) for a in np.linspace(0.35, math.pi - 0.3, 6)] + [(0.04, Rb * 0.99)]
            P.lathe(prof, 12, "BuoyOrange", Matrix.Translation((x, y, top - Rb)))
            P.cyl((x, y, top - 0.01), (x, y, top + 0.04), 0.035, 8, "BuoyOrange", r1=0.02)
            P.torus(0.022, 0.007, 6, 3, "Galv", frame(x, y, top + 0.06) @ Matrix.Rotation(math.radians(90), 4, 'X'))
            eye_top = top + 0.08
        ROPE.tube(rope, [(x, y + 0.012, zb - 0.05), (x + 0.004, y, (zb + eye_top) / 2), (x, y - 0.01, eye_top)],
                  0.012, "Manila" if k % 2 else "Cream", "plain", sides=5, max_tris=60)
        off = 0.125 if kind == "F" else 0.21
        tag(P, frame(x + off, y, top - 0.03, 90), 7 if kind == "F" else 2, (x + 0.02, y, eye_top - 0.025))
    return P


def mannequin(P, x, y, z0, look):
    M = frame(x, y, z0)
    P.lathe([(0.24, 0.0), (0.24, 0.022), (0.226, 0.034)], 16, "Ebony", M)
    for s in (-1, 1):
        boot(P, x + s * 0.105, y - 0.01, z0 + 0.034, -s * 5, "Boot" if look != "drysuit" else "Rubber")
    P.cyl(W(M, (0.105, 0.075, 0.034)), W(M, (0.105, 0.05, 0.46)), 0.009, 6, "Chrome", caps=False)
    legs = {"fw_red": "FW_Navy", "hivis": "FW_Navy", "drysuit": "FW_Navy", "fw_navy": "FW_Grey"}[look]
    body, trim = {"fw_red": ("FW_Red", "FW_Grey"), "hivis": ("HV_Yellow", "FW_Navy"),
                  "drysuit": ("FW_Navy", "FW_Red"), "fw_navy": ("FW_Navy", "FW_Red")}[look]
    leg = [(0.068, 0.30), (0.073, 0.42), (0.066, 0.55), (0.078, 0.66), (0.095, 0.82), (0.11, 0.94)]
    for s in (-1, 1):
        P.lathe(leg, 8, legs, M, 1.0, 0.95, False, False, offset=(s * 0.105, 0.0))
        if look == "fw_navy" or look == "fw_red":
            band(P, M, leg, 0.95, 0.47, 0.6, trim if look == "fw_red" else "FW_Navy", 8, 0.005, offset=(s * 0.105, 0.0))
    torso = [(0.215, 0.80), (0.205, 0.95), (0.195, 1.10), (0.205, 1.25), (0.19, 1.36), (0.13, 1.42), (0.07, 1.45)]
    sy = 0.62
    if look == "drysuit":
        lower = [(0.205, 0.84), (0.2, 0.95), (0.195, 1.10)]
        P.lathe(lower, 12, "FW_Navy", M, 1.0, sy, True, False)
        P.lathe([p for p in torso if p[1] >= 1.10], 12, "FW_Red", M, 1.0, sy, False, True)
    else:
        P.lathe(torso, 12, body, M, 1.0, sy, True, True, cap_region=legs)
    for s in (-1, 1):
        a, b = W(M, (s * 0.19, 0.0, 1.35)), W(M, (s * 0.235, -0.05, 0.88))
        P.cyl(a, b, 0.06, 7, "FW_Red" if look == "drysuit" else body, r1=0.05, caps=False)
        P.cyl(W(M, (s * 0.233, -0.048, 0.89)), W(M, (s * 0.237, -0.053, 0.84)), 0.052, 7, "Neoprene", cap_region="Neoprene")
        if look == "hivis":
            mid = a.lerp(b, 0.6)
            P.cyl(mid, a.lerp(b, 0.68), 0.06, 7, "Tape", r1=0.06, caps=False)
        if look in ("fw_red", "fw_navy"):
            P.box((s * 0.15 - 0.04, -0.07, 1.36), (s * 0.15 + 0.04, 0.0, 1.405), "Tape", M)
            yb = front_y(torso, sy, 1.2, s * 0.09)
            P.box((s * 0.09 - 0.06, yb - 0.012, 1.17), (s * 0.09 + 0.06, yb + 0.01, 1.205), body, M)
            yb = front_y(torso, sy, 0.98, s * 0.12)
            P.box((s * 0.12 - 0.06, yb - 0.012, 0.96), (s * 0.12 + 0.06, yb + 0.01, 0.995), body, M)
    if look == "hivis":
        for z in (0.93, 1.08):
            band(P, M, torso, sy, z, z + 0.05, "Tape", 12, 0.006)
    if look == "drysuit":
        P.lathe([(0.075, 1.42), (0.06, 1.50), (0.055, 1.55)], 10, "Neoprene", M, 1.0, 0.9, False, False)
        zip_line(P, M, torso, sy, 1.36, 1.0, -0.13, 0.11, n=5, region="Zip")
        for s in (-1, 1):        # worn lifejacket lobes, collar, belt, buckle
            lob = [(0.03, 1.12), (0.06, 1.16), (0.064, 1.28), (0.05, 1.38), (0.03, 1.42)]
            yf = front_y(torso, sy, 1.27, s * 0.085)
            P.lathe(lob, 8, "LJ_Orange", M, 1.0, 0.55, True, True, offset=(s * 0.085, yf - 0.012))
            P.box((s * 0.085 - 0.025, yf - 0.05, 1.26), (s * 0.085 + 0.025, yf - 0.036, 1.29), "Tape", M)
        P.torus(0.105, 0.032, 12, 6, "LJ_Orange", frame(x, y + 0.01, z0 + 1.44), sr=0.8)
        band(P, M, torso, sy, 1.05, 1.08, "Webbing", 12, 0.01)
        yf = front_y(torso, sy, 1.065)
        P.box((-0.03, yf - 0.02, 1.045), (0.03, yf - 0.002, 1.085), "BlackPlastic", M)
    else:
        P.lathe([(0.088, 1.40), (0.092, 1.56), (0.084, 1.56), (0.08, 1.42)], 10, trim if look != "hivis" else "FW_Navy",
                M, 1.0, 0.85, False, False)
        zip_line(P, M, torso, sy, 0.81, 1.40, n=6)
    P.lathe([(0.05, 1.48), (0.05, 1.62), (0.045, 1.65), (0.02, 1.665)], 10, "DressForm", M, 1.0, 0.9, False, True)
    P.lathe([(0.012, 1.664), (0.016, 1.685), (0.006, 1.705)], 6, "Ebony", M, cap0=False, cap1=True)
    if look in ("fw_red", "hivis"):
        tag(P, frame(x + 0.237, y - 0.05, z0 + 0.83), 5, W(M, (0.236, -0.05, 0.845)))


def mannequins():
    P = Part("Mannequins")
    for (x, y, z), look in zip(L.MANNEQUINS, ("fw_red", "hivis", "drysuit", "fw_navy")):
        mannequin(P, x, y, z, look)
    return P


def corner():
    P = Part("Corner")
    bx, by = L.DOG_CORNER
    M = Matrix.Translation((bx, by, F))
    sy = 0.72
    P.lathe([(0.40, 0.0), (0.44, 0.04), (0.45, 0.25), (0.462, 0.272), (0.465, 0.295), (0.455, 0.315), (0.435, 0.315),
             (0.425, 0.29), (0.415, 0.06)], 20, "Wicker", M, 1.0, sy, True, True)
    P.lathe([(0.40, 0.061), (0.405, 0.11), (0.37, 0.15), (0.2, 0.165)], 16, "Fleece", M, 1.0, sy * 0.98, False, True)
    # tartan blanket draped over the back rim (two-sided sheet)
    nu, nv = 7, 5
    vs, vb = [], []
    for i in range(nu + 1):
        t = -0.85 + 1.7 * i / nu
        for j in range(nv + 1):
            s = j / nv
            ang = math.pi / 2 + t * 0.9
            rr = 0.30 + 0.2 * s
            z = 0.17 + 0.13 * math.sin(math.pi * min(s * 1.3, 1.0)) - 0.25 * max(0, s - 0.75) * 4 * 0.5
            z += 0.012 * math.sin(5 * t + 2 * s)
            p = (rr * math.cos(ang), rr * math.sin(ang) * sy + 0.0, z)
            vs.append(p)
            vb.append((p[0], p[1], p[2] - 0.008))
    faces = [(i * (nv + 1) + j, (i + 1) * (nv + 1) + j, (i + 1) * (nv + 1) + j + 1, i * (nv + 1) + j + 1)
             for i in range(nu) for j in range(nv)]
    P.mesh(vs, [tuple(reversed(f)) for f in faces], "Tartan", M)
    P.mesh(vb, faces, "Tartan", M)
    # low rail of dog coats (face-out, front -Y)
    rx0, rx1, ry, rz = bx - 0.9, bx + 0.7, by + 0.75, F + 0.78
    P.cyl((rx0 - 0.04, ry, rz), (rx1 + 0.04, ry, rz), 0.013, 8, "Galv")
    for xe in (rx0, rx1):
        P.cyl((xe, ry, F + 0.02), (xe, ry, rz + 0.02), 0.015, 8, "Galv")
        P.box((xe - 0.03, ry - 0.2, F), (xe + 0.03, ry + 0.2, F + 0.02), "Galv")
    looks = ["DogCoat", "FW_Red", "HV_Yellow", "FW_Navy", "LJ_Orange"]
    for k, xx in enumerate(np.linspace(rx0 + 0.18, rx1 - 0.18, 5)):
        Mc = frame(xx, ry + (0.012 if k % 2 else -0.012), rz)
        P.sweep(Ws(Mc, [(-0.13, 0, -0.10), (0, 0, -0.08), (0.13, 0, -0.10)]), 0.007, 4, "BlackPlastic", rx=0.005)
        hook = [(0, 0, -0.08), (0, -0.012, -0.04), (0, -0.018, -0.01)] + [(0, 0.018 * math.cos(a), 0.018 * math.sin(a)) for a in np.radians([180, 120, 60, 0, -40])]
        P.sweep(Ws(Mc, hook), 0.002, 3, "Stainless")
        coat = [(0.10, -0.40), (0.135, -0.34), (0.14, -0.2), (0.12, -0.12), (0.075, -0.095)]
        P.lathe(coat, 10, looks[k], Mc, 1.0, 0.3, True, True, cap_region="Fleece")
        band(P, Mc, coat, 0.3, -0.30, -0.27, "Webbing" if k != 2 else "Tape", 10, 0.006)
        tag(P, Mc @ Matrix.Translation((0.06, -0.05, -0.09)), 6, W(Mc, (0.0, -0.01, -0.08)))
    # livery swatch board (ATT_SwatchBoard), back wall, faces -Y
    sx_, sy_, sz_ = L.ATT["ATT_SwatchBoard"]
    bw, bh = atlas.BOARD_M
    yf = L.IY1 - 0.045
    x0, z0 = sx_ - bw / 2, sz_ - bh / 2
    fits = {"-y": ("SwatchBoard", fit_frame((x0, yf, z0), (1, 0, 0), (0, 0, 1), bw, bh, atlas.rect("SwatchBoard")))}
    P.box((x0, yf, z0), (x0 + bw, L.IY1 - 0.02, z0 + bh), "PaintBoard", fits=fits)
    for a, b in (((x0 - 0.035, z0 - 0.035), (x0 + bw + 0.035, z0)), ((x0 - 0.035, z0 + bh), (x0 + bw + 0.035, z0 + bh + 0.035)),
                 ((x0 - 0.035, z0), (x0, z0 + bh)), ((x0 + bw, z0), (x0 + bw + 0.035, z0 + bh))):
        P.box((a[0], yf - 0.012, a[1]), (b[0], L.IY1 - 0.002, b[1]), "Pine")
    # VHF radio on its shelf (ATT_RadioShelf), back wall
    rx, ry_, rz_ = L.ATT["ATT_RadioShelf"]
    zs = rz_ - 0.17
    P.box((rx - 0.32, L.IY1 - 0.3, zs - 0.025), (rx + 0.32, L.IY1 - 0.001, zs), "Pine")
    for s in (-1, 1):
        P.box((rx + s * 0.25 - 0.012, L.IY1 - 0.22, zs - 0.2), (rx + s * 0.25 + 0.012, L.IY1 - 0.001, zs - 0.025), "Galv")
    w, h = atlas.RADIO_M
    yfr = L.IY1 - 0.26
    fits = {"-y": ("Radio", fit_frame((rx - w / 2, yfr, zs + 0.006), (1, 0, 0), (0, 0, 1), w, h, atlas.rect("Radio")))}
    P.box((rx - w / 2, yfr, zs + 0.006), (rx + w / 2, yfr + 0.17, zs + 0.006 + h), "RadioBody", fits=fits)
    for s in (-1, 1):       # U mounting bracket and knobs
        P.box((rx + s * (w / 2 + 0.006) - 0.004, yfr + 0.03, zs), (rx + s * (w / 2 + 0.006) + 0.004, yfr + 0.12, zs + 0.11), "Galv")
        P.cyl((rx + s * (w / 2 + 0.01), yfr + 0.075, zs + 0.075), (rx + s * (w / 2 + 0.03), yfr + 0.075, zs + 0.075), 0.016, 8, "BlackPlastic")
    P.box((rx - w / 2 - 0.02, yfr + 0.03, zs), (rx + w / 2 + 0.02, yfr + 0.12, zs + 0.006), "Galv")
    hx = rx + w / 2 + 0.07
    P.box((hx - 0.03, yfr + 0.01, zs + 0.0), (hx + 0.03, yfr + 0.05, zs + 0.11), "BlackPlastic")
    P.box((hx - 0.022, yfr - 0.004, zs + 0.06), (hx + 0.022, yfr + 0.012, zs + 0.1), "BlackPlastic")
    coil = [(hx + 0.012 * math.cos(t), yfr + 0.05 + 0.012 * math.sin(t), zs + 0.005 - 0.004 * t / (2 * math.pi)) for t in np.linspace(0, 4 * math.pi, 14)]
    P.sweep([Vector((hx, yfr + 0.03, zs + 0.01))] + [Vector(c) for c in coil] + [Vector((rx + w / 2 - 0.02, yfr + 0.16, zs + 0.02))], 0.004, 4, "Webbing")
    P.cyl((rx - 0.05, yfr + 0.17, zs + 0.1), (rx - 0.05, L.IY1 - 0.01, zs + 0.3), 0.004, 4, "Webbing")
    tag(P, frame(rx - 0.18, L.IY1 - 0.302, zs - 0.026), 3)
    return P


def hanks(holder):
    for k, (x, y, z, strip) in enumerate(holder):
        big = z < L.FLOOR + 0.3
        R, r = (0.17, 0.05) if big else (0.12, 0.034)
        M = frame(x, y, z + r * 0.85, 15 * k) @ Matrix.Diagonal((1, 1, 0.85, 1))
        ROPE.hank((x, y, z), R, r, strip, segs=16 if big else 14, rsegs=8 if big else 7, M=M, binds=2, rope_mod=rope,
                  tail=strip != "GreenHank")


def col_part():
    C = Part("COL")
    x, y0, y1 = L.RACK_WALL
    C.box((L.IX0 + 0.01, y0 - 0.15, F), (x + 0.3, y1 + 0.15, 1.75), "Galv")
    x0, x1, y = L.RACK_MID
    C.box((x0 - 0.06, y - 0.32, F), (x1 + 0.06, y + 0.32, 1.7), "Galv")
    g = L.GONDOLA
    C.box((g[0] - 0.01, g[2] - 0.01, F), (g[1] + 0.01, g[3] + 0.01, F + 1.43), "Galv")
    for (mx, my, mz) in L.MANNEQUINS:
        C.box((mx - 0.25, my - 0.25, mz), (mx + 0.25, my + 0.25, mz + 1.7), "Galv")
    bx, by = L.DOG_CORNER
    C.box((bx - 0.47, by - 0.34, F), (bx + 0.47, by + 0.34, F + 0.31), "Galv")
    C.box((bx - 0.93, by + 0.55, F), (bx + 0.73, by + 0.95, F + 0.8), "Galv")
    return C


def lod1(obj):
    """LOD1 at half the LOD0 triangles (the class makes no LODs: the shop is seen close, LOD1 is for the bay window from the quay)."""
    o = versions.copy_object(obj, obj.name.replace("_LOD0", "_LOD1"))
    versions.decimate(o, versions.triangles(obj.data) // 2)
    versions.weighted_normals(o)
    print("[H2props] %s %d tris" % (o.name, versions.triangles(o.data)))
    return o


def build():
    groups = [rack_wall(), rack_mid()]
    gp, holder = gondola()
    groups += [gp, mannequins(), hung(), corner()]
    hanks(holder)
    meshes = []
    tints = {"RackWall": (0.6, 0.3, 0.1), "RackMid": (0.4, 0.15, 0.12), "Gondola": (0.45, 0.33, 0.2),
             "Mannequins": (0.3, 0.3, 0.35), "Hung": (0.15, 0.2, 0.35), "Corner": (0.5, 0.4, 0.3)}
    total = 0
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for P in groups:
        mat = kit.material("MI_ChandleryProps_%s" % P.name, tints[P.name])
        obj = P.to_object("%s_%s_LOD0" % (NAME, P.name), mat)
        meshes.append({"object": obj, "set": "Atlas"})
        meshes.append({"object": lod1(obj), "set": "Atlas"})
        total += P.tris()
        print("[H2props] %s %d tris" % (P.name, P.tris()))
        for v in P.v:
            lo = Vector(map(min, lo, v))
            hi = Vector(map(max, hi, v))
    robj = ROPE.to_object(rope, "%s_Rope_LOD0" % NAME)
    meshes.append({"object": robj, "set": "Rope"})
    meshes.append({"object": lod1(robj), "set": "Rope"})
    rt = rope.tri_count(robj)
    total += rt
    print("[H2props] Rope %d tris; LOD0 total %d" % (rt, total))
    colobj = col_part().to_object(NAME + "_COL", None)

    atts = []
    for n in ("ATT_Rack_01", "ATT_Rack_02", "ATT_Rack_03", "ATT_Mannequin_01", "ATT_Mannequin_02", "ATT_Mannequin_03",
              "ATT_Mannequin_04", "ATT_DogBasket", "ATT_HornBoard", "ATT_SwatchBoard", "ATT_RadioShelf"):
        e = bpy.data.objects.new(n, None)
        e.location = L.studs(L.ATT[n])
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)
    size = hi - lo
    print("[H2props] bbox m %.2f x %.2f x %.2f" % tuple(size))
    S = 3.0

    def at(p):
        return [p[0] * S, p[1] * S, p[2] * S]
    g = L.GONDOLA
    return {
        "name": NAME,
        "budget": "helm_interior",
        "tris": 30000,
        "tier": "standard",
        "dims_m": (round(size.x, 3), round(size.y, 3), round(size.z, 3)),
        "size_note": None,
        "origin": "free",
        "origin_note": "shared Chandlery frame (layout.py): pivot = M_Bld_Chandlery_Ext / _Int pivot; every prop is authored at its stand",
        "tiling": True,
        "atlas": "ChandleryProps_Atlas",
        "waivers": {
            "LOD1 triangles": "close-up interior set class (30,000 = the docs/12 props row) makes no LODs; a LOD1 at 0.5 is kept "
                              "for the bay-window view from the quay (mannequins, racks seen through the glass)",
            "LOD UV layout": "collapse decimation of ~30 small props on one atlas merges small islands (tags, buckles, tape, rope V tiles), so UV area / bounds shift; every LOD still samples the same atlas regions",
        },
        "sets": [
            {"name": "ChandleryProps", "set": "Atlas", "size": 2048, "wet": False},
            {"name": "ChandleryProps", "set": "Rope", "size": 1024, "wet": False},
        ],
        "meshes": meshes + [{"object": colobj}],
        "attachments": atts,
        "closeups": [
            {"name": "lifejacket_rack", "target": at((L.RACK_WALL[0], -1.6, 1.35)), "dist": 8, "az": 70, "el": 5},
            {"name": "mannequin_foulweather", "target": at((L.MANNEQUINS[0][0], L.MANNEQUINS[0][1], 1.0)), "dist": 8, "az": 0, "el": 5},
            {"name": "gondola_rope_shackles", "target": at(((g[0] + g[1]) / 2 - 0.8, g[2], 1.0)), "dist": 7, "az": 10, "el": 18},
            {"name": "fenders_beam", "target": at((-4.8, -1.9, 2.5)), "dist": 8, "az": 60, "el": 5},
            {"name": "dog_basket", "target": at((L.DOG_CORNER[0], L.DOG_CORNER[1] + 0.3, 0.5)), "dist": 8, "az": 20, "el": 30},
            {"name": "horn_board", "target": at(L.ATT["ATT_HornBoard"]), "dist": 6, "az": 90, "el": 5},
        ],
    }
