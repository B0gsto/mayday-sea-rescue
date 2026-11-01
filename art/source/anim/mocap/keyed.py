"""Hand-keyed R15 clips (mocap is only a timing reference): key poses below, keyed on a blocky R15 proxy armature in
Blender (Bezier, legs IK-planted on foot targets), sampled at 30 fps into out/keyed/<Name>.json (same format as
retarget.py's out/*.json). mocap.luau builds them unchanged; a keyed clip replaces the mocap slot of the same name.
  Blender MCP: P = "<repo>/art/source/anim/mocap/keyed.py"
               exec(open(P).read(), {"__file__": P, "__name__": "__main__", "KEYED_ARGS": ["WorkerHammer"]})
  KEYED_ARGS: slot names, empty = all; ["--pose", Name] keys the slot and stops (for looks, no export).
Angles: degrees, Roblox CFrame.Angles(x, y, z) order on the joint (x+ swings a limb forward / tilts Waist, Neck back,
y+ turns left, z+ moves a limb toward the character's right: RightShoulder z+ is out, LeftShoulder z+ is in).
A key's missing joints are not keyed there (Bezier flows through; the first and last key hold every joint); "rest": True starts from the R15 rest pose. "root": offset of
the Root joint in studs (x right, y up, z back); "feet": {"L"|"R": (dx, dy, dz)} on top of the slot's stance.
"hands": {"L"|"R": (x, y, z)} pins that wrist at an HRP point (arm IK, elbow toward the slot's "poles" point); Shoulder and
Elbow keys are then ignored for that arm (arm pole angle -90 checked: elbow points at the pole).
Slot "kneepoles": {"L"|"R": offset} moves that knee pole (rest: 3 studs ahead of the knee) for the whole slot.
Loops end on a copy of the first key; one-shots start and end at rest. "ease" shapes the way out of a key:
smooth (Bezier), in (accelerate into the next key: strikes), out (decelerate: pops), linear.
"""
import json
import math
import os

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
_R = {"__file__": os.path.join(HERE, "retarget.py"), "__name__": "retarget"}
exec(open(_R["__file__"]).read(), _R)  # reuse the retargeter's joint table, axes, euler, key reduction, encoding
JOINTS, QA, FPS, euler, reduce_keys, encode = (_R[k] for k in ("JOINTS", "QA", "FPS", "euler", "reduce_keys", "encode"))
QAI = QA.inverted()
FLOOR = -3.1924  # HumanoidRootPart frame (R15 blocky, HipHeight 2.192)
POLE_ANGLE = 90.0  # IK pole angle that keeps the knee plane straight forward (checked: rest legs come out identity)
KNEE = -0.03  # knee bones pre-bent 0.03 stud forward: Blender IK can't bend a dead-straight chain
WRIST = {"R": Vector((1.5, -0.69, 0)), "L": Vector((-1.5, -0.69, 0))}  # rest wrist pivots (HandTgt heads)

# R15 blocky proxy, Roblox HRP space: part -> (parent, joint pivot, bone tail, visual centre, visual size, colour)
_SKIN, _SHIRT, _PANTS = (1.0, 0.78, 0.2), (0.75, 0.12, 0.1), (0.12, 0.25, 0.6)
PARTS = {
    "LowerTorso": (None, (0, -1, 0), (0, -0.6, 0), (0, -0.8, 0), (2, 0.4, 1), _PANTS),
    "UpperTorso": ("LowerTorso", (0, -0.6, 0), (0, 1, 0), (0, 0.2, 0), (2, 1.6, 1), _SHIRT),
    "Head": ("UpperTorso", (0, 1, 0), (0, 2.1, 0), (0, 1.5, 0), (1.2, 1.2, 1.2), _SKIN),
}
for _s, _x in (("Right", 1.5), ("Left", -1.5)):
    _h = _x / 3  # hip x
    PARTS.update({
        _s + "UpperArm": ("UpperTorso", (_x * 2 / 3, 0.763, 0), (_x, 0.009, 0), (_x, 0.5, 0), (0.94, 1.0, 0.94), _SHIRT),
        _s + "LowerArm": (_s + "UpperArm", (_x, 0.009, 0), (_x, -0.69, 0), (_x, -0.345, 0), (0.9, 0.69, 0.9), _SHIRT),
        _s + "Hand": (_s + "LowerArm", (_x, -0.69, 0), (_x, -1.0, 0), (_x, -0.845, 0), (0.94, 0.31, 0.94), _SKIN),
        _s + "UpperLeg": ("LowerTorso", (_h, -1, 0), (_h, -1.9207, KNEE), (_h, -1.46, 0), (0.96, 0.92, 0.96), _PANTS),
        _s + "LowerLeg": (_s + "UpperLeg", (_h, -1.9207, KNEE), (_h, -2.9304, 0), (_h, -2.425, 0), (0.94, 1.01, 0.94), _PANTS),
        _s + "Foot": (_s + "LowerLeg", (_h, -2.9304, 0), (_h, FLOOR, 0), (_h, -3.061, -0.04), (0.96, 0.262, 1.08), _PANTS),
    })


def herm(s, p0, p1, m0, m1):
    """Cubic Hermite on s in 0..1 (end values and slopes): swing paths that leave and land at the contact's speed."""
    return (2*s**3 - 3*s**2 + 1)*p0 + (s**3 - 2*s**2 + s)*m0 + (-2*s**3 + 3*s**2)*p1 + (s**3 - s**2)*m1


def arm_ik(hy, hz, rooty, waist):
    """Hand tip (HRP y, z) -> (Shoulder x, Elbow x) degrees, arm in its sagittal plane, Root unrotated, Waist pitched."""
    L1, L2, w = 0.754, 1.009, math.radians(waist)  # shoulder->elbow, elbow->hand tip (yz lengths)
    sy, sz = -0.6 + rooty + 1.363 * math.cos(w), 1.363 * math.sin(w)  # shoulder pivot
    vy, vz = hy - sy, hz - sz
    y, z = vy * math.cos(w) + vz * math.sin(w), -vy * math.sin(w) + vz * math.cos(w)  # into UpperTorso space
    d = min(math.hypot(y, z), L1 + L2 - 1e-3)
    b = math.acos(max(-1, min(1, (d * d - L1 * L1 - L2 * L2) / (2 * L1 * L2))))
    a = math.atan2(-z, -y) - math.atan2(L2 * math.sin(b), L1 + L2 * math.cos(b))
    return math.degrees(a) % 360, math.degrees(b)


# WorkerCarry: 0.6 s per two steps at 6.4 studs/s (the worker's walk speed) at playback speed 1. Each foot is planted
# 60% of the cycle (double support, heavy walk), so the stride is 2 * 6.4 * 0.36 = 2.3 studs (the legs' reach at the dip).
CARRY_T, CARRY_D = 0.6, 0.6  # cycle, planted fraction
CARRY_A = 6.4 * CARRY_T * CARRY_D / 2  # stance sweep +-A while planted, so planted feet stay put in the world


def carry_feet(t):
    out, m = {}, 2 * CARRY_A * (1 - CARRY_D) / CARRY_D  # swing slope = planted speed, in swing-phase units
    for side, off in (("R", 0.0), ("L", 0.5)):
        p = (t / CARRY_T + off) % 1
        if p < CARRY_D:  # planted: slides back under the walking body
            out[side] = (0, 0, -CARRY_A + 2 * CARRY_A * p / CARRY_D)
        else:  # swing: lifts and lands at the planted speed, passing under the hip at mid-swing
            sw = (p - CARRY_D) / (1 - CARRY_D)
            out[side] = (0, 0.5 * math.sin(math.pi * sw), herm(sw, CARRY_A, -CARRY_A, m, m))
    return {"feet": out}


# WorkerClimb: 1.0 s, two mirrored pulls, rise 4 studs per cycle. Per hand (phase p): grab the rung overhead and hang
# on a straight arm (hold, body sags), pull it down to the chest while the body rises, let go and swing up past the
# face (bowing out) onto the next rung. Hand tips are HRP-relative; the body rides ~1 stud above the HRP so a straight
# arm reaches +3.2 (R15 blocky: straight overhead is only +2.4 above the HRP with the body unshifted).
# shortcut: the grip is world-fixed only on average (hold + pull drop 2.4 studs while the HRP rises 2.6), fine on a ladder.
CL_T, CL_RISE = 1.0, 4.0
CL_TOP, CL_LOW, CL_Z = 3.46, 1.05, -0.8  # grab tip height, release at the chest, ladder hand line (forward of the face)
CL_LO, CL_UP, CL_DIP = 1.02, 0.3, 0.3  # body (root y) at the bottom of the hang, rise per pull, hang share of a pull
CL_HOLD, CL_PULL = 0.15, 0.5  # per hand: hold at the top, pull down; the rest of the cycle swings up
CL_FOOT = (2.25, -0.85, 0.22)  # foot plant height (thigh near horizontal), rung line, planted time (leg range limits it)


def cl_body(u):
    """Root y over one pull (u 0..1, 0 = a hand grabs): sags into the hang, then rises 0.3 through the pull."""
    if u < CL_DIP:
        return CL_LO + CL_UP * (1 + math.cos(math.pi * u / CL_DIP)) / 2
    return CL_LO + CL_UP * (1 - math.cos(math.pi * (u - CL_DIP) / (1 - CL_DIP))) / 2


def climb(t):
    rooty = cl_body((2 * t / CL_T) % 1)
    waist = -15 - 4 * (rooty - CL_LO) / CL_UP  # leans in to the ladder, chest in at the top of the pull
    ch = {"root": (0, rooty, 0), "Waist": (waist, 0, 0)}
    for side, off, sgn in (("Right", 0.0, 1), ("Left", 0.5, -1)):
        p, hz, sz = (t / CL_T + off) % 1, CL_Z, 5
        if p < CL_HOLD:  # hang on the rung on a straight arm while the body sags (the hand rides down with it)
            hy = CL_TOP + rooty - CL_LO
        elif p < CL_HOLD + CL_PULL:
            hy = herm((p - CL_HOLD) / CL_PULL, CL_TOP, CL_LOW, 0, 0)
        else:  # let go at the chest, swing up past the face (bowing out), reach full stretch a beat before the grab
            sw = (p - CL_HOLD - CL_PULL) / (1 - CL_HOLD - CL_PULL)
            hy = herm(min(1, sw / 0.8), CL_LOW, CL_TOP + CL_UP, 0, 0)
            hz, sz = CL_Z + 0.25 * math.sin(math.pi * sw), 5 + 14 * math.sin(math.pi * sw)
        a, b = arm_ik(hy, hz, rooty, waist)
        ch[side + "Shoulder"], ch[side + "Elbow"] = (a, 0, sgn * sz), (b, 0, 0)
    hi, fz, q = CL_FOOT
    df = CL_RISE * q / CL_T
    feet = {}
    for side, plant in (("L", 0.0), ("R", 0.5)):  # each foot plants knee-high as the opposite hand grabs, pushes the pull
        p = (t / CL_T - plant) % 1
        if p < q:
            feet[side] = (0, hi - df * p / q, fz)
        else:  # leg hangs extended, then the knee drives up past the next rung and stamps down onto it at the rung's speed
            sw, v = (p - q) / (1 - q), -df / q * (1 - q)  # v: planted speed in swing-phase units
            y = herm(sw / 0.45, hi - df, hi - df + 0.1, v * 0.45, 2 * 0.45) if sw < 0.45 else \
                herm((sw - 0.45) / 0.55, hi - df + 0.1, hi, 2 * 0.55, v * 0.55)
            feet[side] = (0, y, fz + 0.3 * math.sin(math.pi * sw))
    ch["feet"] = feet
    return ch


# ---------------------------------------------------------------------------------------------------------------
# Key poses. Loops: the first key is repeated at `length`.
# ---------------------------------------------------------------------------------------------------------------
CW = (1.3, -0.85)  # WorkerCarry wrists: x (crate side), z (forward of the chest)


def carry_keys():
    """Two mirrored heavy steps (R contact at 0, L at 0.3): body dips 0.18 after each contact, leans back ~15 deg; the
    crate (hands) dips and rises a beat late (elbows give), sways toward the stance leg, the head lags."""
    def hands(t, y, z):
        sway = 0.1 * math.sin(2 * math.pi * (t - 0.11) / CARRY_T)
        return {"R": (CW[0] + sway, y, z), "L": (-CW[0] + sway, y, z)}
    keys = []
    for t0, g in ((0.0, 1), (0.3, -1)):
        keys += [
            {"t": t0, "root": (0, -0.45, 0), "Root": (8, 5 * g, -2 * g), "Waist": (6, -5 * g, g), "Neck": (-6, 2 * g, 0),
             "RightWrist": (0, 30, -75), "LeftWrist": (0, -30, 75)},  # heel contact; hands turned in flat on the crate sides
            {"t": t0 + 0.1, "root": (0, -0.6, 0.02), "Root": (7, 3 * g, -g), "Waist": (3, -3 * g, 0)},  # absorb: lowest, chest gives
            {"t": t0 + 0.14, "Neck": (-12, g, 0), "hands": hands(t0 + 0.14, -0.46, CW[1] + 0.03)},  # crate + head dip late
            {"t": t0 + 0.22, "root": (0.06 * g, -0.42, 0), "Root": (9, 0, 0), "Waist": (9, 0, 0)},  # passing: up on the planted leg
            {"t": t0 + 0.26, "Neck": (-2, 0, 0), "hands": hands(t0 + 0.26, -0.2, CW[1] - 0.03)},  # crate floats up late
        ]
    keys[0]["hands"] = hands(0.0, -0.24, CW[1])
    return keys

PT = (124, 29)  # WorkerPoint held point: RightShoulder x, z; with the chest turned ~20 deg right: ~67 deg right of forward, ~17 deg up


def hip(root):
    """WorkerPoint left wrist on the hip (akimbo), following the body (root offset)."""
    return {"L": (-0.95 + root[0], -0.3 + root[1], root[2])}


SIT_KNEE = (0.72, -1.55, -0.95)  # NpcSit wrists resting on the knees (mirrored)


def sit_hands(x, y, z):
    return {"R": (x, y, z), "L": (-x, y, z)}


def sit_poles(x, y, z):
    """NpcSit elbow poles where they should land (the value lands 3 studs inward, so add 3 outward)."""
    return {"R": (x + 3, y, z), "L": (-x - 3, y, z)}


SIT_POLE_KNEE, SIT_POLE_UP = sit_poles(2.5, -1.5, 0.5), sit_poles(3.0, 0.3, 0.6)  # elbows out-down / out to the sides
POINT_POLE_L, HIP_POLE_L = (-3.0, -1.0, 2.5), (-0.94, 0, 2.57)  # WorkerPoint left elbow: exact rest arm; out to the side on the hip
SAW_T, SAW_POLE_R, SAW_POLE_L = 0.6, (0, -1.0, 0), (-3.0, -0.4, -0.5)  # stroke period, arm IK poles (R: elbow out + back on the pull)
SAW_NAIL = (-0.6, 0.0, -1.4)  # WorkerSaw left wrist planted on the timber


def saw_keys():
    """One identical push/pull stroke per SAW_T, keyed every 0.075 s: s = +1 pulled back, -1 pushed through. The right
    wrist runs 2.0 studs on one level line (arm near straight at the push end); hips drive and knees dip on each push."""
    keys = []
    for i in range(16):
        t = i * 0.075
        w = 2 * math.pi * t / SAW_T
        s, h, g = math.cos(w), math.cos(w + 0.45), math.cos(w - 0.6)  # hand, hips (lead), head (lag)
        keys.append({"t": round(t, 4), "ease": "smooth",
                     "root": (0.04 * h, -0.2 + 0.1 * h, -0.06 + 0.16 * h), "Root": (-4 + 2 * h, -5 * h, 0),
                     "Waist": (-8 + 3 * s, -10 * s, 0), "Neck": (-16 + 4 * g, 8 * g, 0),
                     "hands": {"R": (1.1, -0.45, -1.25 + 1.0 * s), "L": SAW_NAIL},
                     "RightWrist": (-4 + 8 * g, 0, 0), "LeftWrist": (-20, 0, 0)})
    return keys


HC, HN = (0.8, 0.1, -1.2), (-0.5, 0.15, -1.25)  # WorkerHammer: right wrist at every hit, left wrist holding the nail beside it


def hc(dx=0.0, dy=0.0, dz=0.0, ny=0.0):
    """WorkerHammer hands: right wrist offset from the contact, left wrist pinned on the nail (ny: impact jolt)."""
    return {"R": (HC[0] + dx, HC[1] + dy, HC[2] + dz), "L": (HN[0], HN[1] + ny, HN[2])}


def cel(x, y, z, rooty=0.0):
    """WorkerCelebrate mirrored wrists, body-relative height (rooty: the jump/squash offset)."""
    return {"R": (x, y + rooty, z), "L": (-x, y + rooty, z)}
HAMMER_POLE_R, HAMMER_POLE_L = (0.14, 1, 1.04), (-5.04, 1, 3.86)  # WorkerHammer elbows: right down at the side, left out
CEL_DOWN, CEL_UP = {"R": (2.184, -1, 3.564), "L": (-2.184, -1, 3.564)}, {"R": (1.17, 1, -2.83), "L": (-1.17, 1, -2.83)}  # WorkerCelebrate
# elbow poles: DOWN gives the exact rest arm and elbows out in the crouch, UP keeps the elbows out with the fists overhead
CEL_CROUCH = (1.92, 0.03, -1.28, -0.5)  # WorkerCelebrate gather wrists (x, y, z, rooty)


SLOTS = {
    # Tap, tap, BIG strike per 1.2 s. Every hit lands the right wrist on one contact point (HC) at bench height and
    # stops there; the left hand holds the nail there (pinned). Taps lift ~0.5 stud. The big one: lean back and a slight
    # crouch while the hammer goes up (short top), drop forward, a 2-frame contact hold with a torso crunch and knee
    # dip, then a rebound that becomes the lift for the next tap.
    "WorkerHammer": {"loop": True, "length": 1.2, "stance": {"L": (-0.2, 0, -0.4), "R": (0.25, 0, 0.35)},
                     "poles": {"R": HAMMER_POLE_R, "L": HAMMER_POLE_L}, "keys": [
        {"t": 0.0, "ease": "linear", "root": (0, -0.1, 0), "Root": (-2, 0, 0), "Waist": (-10, -4, 0), "Neck": (-26, 4, 0),
         "hands": hc(), "RightWrist": (-30, 0, 0)},  # tap 1 contact
        {"t": 0.0667, "ease": "smooth", "root": (0, -0.12, 0), "Waist": (-11, -4, 0), "hands": hc(ny=-0.03)},  # stop on it
        {"t": 0.1667, "ease": "in", "root": (0, -0.08, 0), "Waist": (-7, -6, 0), "Neck": (-24, 6, 0),
         "hands": hc(0.05, 0.5, 0.15), "RightWrist": (20, 0, 0)},  # tap 2 lift, wrist lags back
        {"t": 0.2667, "ease": "linear", "root": (0, -0.11, 0), "Waist": (-10, -4, 0), "Neck": (-27, 4, 0),
         "hands": hc(), "RightWrist": (-30, 0, 0)},  # tap 2 contact
        {"t": 0.3333, "ease": "smooth", "root": (0, -0.13, 0), "Waist": (-11, -4, 0), "hands": hc(ny=-0.03)},  # stop on it
        {"t": 0.4667, "ease": "smooth", "root": (0, -0.18, 0.04), "Root": (3, 0, 0), "Waist": (2, -8, 0), "Neck": (-18, 6, 0),
         "hands": hc(0.55, 0.95, 0.75), "RightWrist": (10, 0, 0)},  # big lift: lean back, slight crouch
        {"t": 0.6, "ease": "smooth", "root": (0, -0.24, 0.08), "Root": (5, 0, 0), "Waist": (8, -10, 0), "Neck": (-12, 8, 0),
         "hands": hc(0.6, 1.8, 1.55), "RightWrist": (30, 0, 0)},  # top
        {"t": 0.6667, "ease": "in", "Waist": (9, -10, 0), "hands": hc(0.6, 1.85, 1.65), "RightWrist": (42, 0, 0)},  # wrist cocks last
        {"t": 0.7333, "ease": "in", "root": (0, -0.2, 0.0), "Root": (0, 0, 0), "Waist": (-6, -4, 0), "Neck": (-22, 4, 0),
         "hands": hc(0.6, 1.25, 0.05), "RightWrist": (10, 0, 0)},  # drop forward
        {"t": 0.8, "ease": "linear", "root": (0, -0.24, -0.04), "Root": (-4, 0, 0), "Waist": (-12, -2, 0), "Neck": (-32, 2, 0),
         "hands": hc(ny=-0.08), "RightWrist": (-40, 0, 0)},  # BIG contact: crunch + knee dip, nail hand jolts
        {"t": 0.8667, "ease": "smooth", "root": (0, -0.28, -0.05), "Waist": (-13, -2, 0), "Neck": (-34, 2, 0),
         "hands": hc(ny=-0.06), "RightWrist": (-42, 0, 0)},  # 2-frame contact hold
        {"t": 0.9667, "ease": "smooth", "root": (0, -0.16, 0), "Root": (-2, 0, 0), "Waist": (-6, -6, 0), "Neck": (-22, 6, 0),
         "hands": hc(0.08, 0.4, 0.12), "RightWrist": (0, 0, 0)},  # rebound
        {"t": 1.0667, "ease": "in", "root": (0, -0.08, 0), "Waist": (-7, -6, 0), "Neck": (-24, 6, 0),
         "hands": hc(0.05, 0.55, 0.18), "RightWrist": (22, 0, 0)},  # tap 1 lift
    ]},
    # Continuous saw: one smooth sinusoidal stroke per 0.6 s (saw_keys), right hand IK on a long straight saw line, elbow
    # driving back past the hip on the pull; hips drive and dip on each push; left hand planted forward on the timber.
    "WorkerSaw": {"loop": True, "length": 1.2, "stance": {"L": (-0.15, 0, -0.7), "R": (0.35, 0, 0.6)},
                  "poles": {"R": SAW_POLE_R, "L": SAW_POLE_L}, "keys": saw_keys()},
    # Crouch (gather) -> hop with a wide V, feet well off the ground -> landing squash while the fists travel up and in
    # to a double fist pump over the head (never below the shoulders) -> dip -> second, bigger hop with the highest V,
    # held through the landing bounce -> arms float down forward -> settle on the rest pose. Wrists on arm IK.
    # One-shot 1.93 s (58 frames).
    "WorkerCelebrate": {"loop": False, "length": 1.9333, "stance": {}, "poles": CEL_DOWN, "keys": [
        {"t": 0.0, "rest": True, "ease": "smooth", "hands": cel(1.5, -0.69, 0)},
        {"t": 0.3, "ease": "in", "root": (0, -0.5, 0.05), "Root": (-10, 0, 0), "Waist": (-16, 0, 0), "Neck": (-10, 0, 0),
         "feet": {"L": (0, 0, 0), "R": (0, 0, 0)}, "hands": cel(*CEL_CROUCH)},  # gather, arms out of the chest
        {"t": 0.3667, "ease": "out", "root": (0, 0.1, 0), "Root": (0, 0, 0), "Waist": (4, 0, 0), "Neck": (6, 0, 0),
         "feet": {"L": (0, 0, 0), "R": (0, 0, 0)}, "hands": cel(1.75, 1.0, -0.2, 0.1)},  # take-off: legs extend, arms fling
        {"t": 0.5333, "ease": "smooth", "root": (0, 0.95, 0), "Root": (4, 0, 0), "Waist": (12, 0, 0), "Neck": (18, 0, 0),
         "feet": {"L": (-0.1, 0.6, 0.1), "R": (0.1, 0.6, 0.1)}, "hands": cel(2.1, 1.85, 0.25, 0.95), "poles": CEL_UP},  # apex: wide V
        {"t": 0.6333, "ease": "in", "root": (0, 0.62, 0), "Waist": (12, 0, 0), "Neck": (16, 0, 0),
         "feet": {"L": (-0.1, 0.45, 0.06), "R": (0.1, 0.45, 0.06)}, "hands": cel(2.0, 1.95, 0.2, 0.62)},  # falling
        {"t": 0.7, "ease": "out", "root": (0, 0.0, 0), "Root": (0, 0, 0), "Waist": (6, 0, 0), "Neck": (10, 0, 0),
         "feet": {"L": (-0.1, 0, 0), "R": (0.1, 0, 0)}, "hands": cel(1.6, 2.0, 0.0, 0.0)},  # touch down, fists sweep in
        {"t": 0.8, "ease": "smooth", "root": (0, -0.45, 0.02), "Root": (-6, 0, 0), "Waist": (-2, 0, 0), "Neck": (8, 0, 0),
         "hands": cel(1.15, 2.05, -0.1, -0.45)},  # squash: double fist pump over the head
        {"t": 0.9667, "ease": "in", "root": (0, -0.5, 0.03), "Root": (-8, 0, 0), "Waist": (-6, 0, 0), "Neck": (2, 0, 0),
         "hands": cel(1.2, 1.65, -0.12, -0.5)},  # dip: fists pump down, still above the shoulders
        {"t": 1.0667, "ease": "out", "root": (0, 0.1, 0), "Root": (0, 0, 0), "Waist": (8, 0, 0), "Neck": (14, 0, 0),
         "feet": {"L": (-0.1, 0, 0), "R": (0.1, 0, 0)}, "hands": cel(1.45, 2.05, 0.0, 0.1)},  # take-off 2
        {"t": 1.2, "ease": "smooth", "root": (0, 0.75, 0), "Root": (4, 0, 0), "Waist": (16, 0, 0), "Neck": (24, 0, 0),
         "feet": {"L": (-0.1, 0.45, 0.06), "R": (0.1, 0.45, 0.06)}, "hands": cel(1.66, 2.12, 0.25, 0.75)},  # apex: highest V
        {"t": 1.3333, "ease": "out", "root": (0, -0.05, 0), "Root": (2, 0, 0), "Waist": (14, 0, 0), "Neck": (22, 0, 0),
         "feet": {"L": (-0.1, 0, 0), "R": (0.1, 0, 0)}, "hands": cel(1.68, 2.1, 0.25, -0.05)},  # land, V held
        {"t": 1.4333, "ease": "smooth", "root": (0, -0.3, 0), "Root": (-3, 0, 0), "Waist": (10, 0, 0), "Neck": (18, 0, 0),
         "hands": cel(1.7, 2.04, 0.22, -0.3)},  # knee bounce, V still held
        {"t": 1.6, "ease": "smooth", "root": (0, -0.12, 0), "Root": (0, 0, 0), "Waist": (2, 0, 0), "Neck": (4, 0, 0),
         "feet": {"L": (0, 0, 0), "R": (0, 0, 0)}, "hands": cel(1.9, 0.35, -0.45, -0.12)},  # arms float down forward
        {"t": 1.7667, "ease": "smooth", "root": (0, -0.04, 0), "Root": (0, 0, 0), "Waist": (0, 0, 0), "Neck": (0, 0, 0),
         "hands": cel(1.58, -0.58, -0.1, -0.04), "poles": CEL_DOWN},  # settle
        {"t": 1.9333, "rest": True, "hands": cel(1.5, -0.69, 0)},
    ]},
    # Eyes lead (head snaps to the target) while the arm cocks across the chest -> snap a straight arm ~65 deg right of
    # forward, ~18 deg up, past the mark -> settle; chest ~20 deg and head ~40 deg into it, small lean, left hand on the hip
    # (elbow out) -> pump (elbow folds back) and jab -> re-aim further right and up -> release with overlap. No crouch.
    "WorkerPoint": {"loop": False, "length": 1.8, "stance": {}, "poles": {"L": POINT_POLE_L}, "keys": [
        {"t": 0.0, "rest": True, "ease": "smooth", "hands": {"L": (-1.5, -0.69, 0)}},
        {"t": 0.2333, "ease": "in", "root": (-0.04, -0.03, 0.06), "Root": (-1, 10, 0), "Waist": (2, 10, 0), "Neck": (-4, -36, 0),
         "RightShoulder": (40, 0, -14), "RightElbow": (100, 0, 0), "RightWrist": (0, 0, 0), "hands": hip((-0.04, -0.03, 0.06)),
         "poles": {"L": HIP_POLE_L}},  # wind-up
        {"t": 0.4, "ease": "out", "root": (0.06, 0.02, -0.1), "Root": (-4, -10, 0), "Waist": (-8, -14, 0), "Neck": (-4, -22, 0),
         "RightShoulder": (PT[0] + 8, 0, PT[1] + 8), "RightElbow": (0, 0, 0), "RightWrist": (-8, 0, 0),
         "hands": hip((0.06, 0.02, -0.1))},  # snap past the point
        {"t": 0.5333, "ease": "smooth", "root": (0.05, 0, -0.08), "Root": (-3, -8, 0), "Waist": (-6, -12, 0), "Neck": (-2, -20, 0),
         "RightShoulder": (PT[0], 0, PT[1]), "RightElbow": (2, 0, 0), "RightWrist": (0, 0, 0), "hands": hip((0.05, 0, -0.08))},  # settle
        {"t": 0.7, "ease": "in", "root": (0.03, 0.02, -0.04), "Root": (-1, -7, 0), "Waist": (-2, -11, 0), "Neck": (2, -19, 0),
         "RightShoulder": (PT[0] - 12, 0, PT[1] - 8), "RightElbow": (40, 0, 0), "RightWrist": (12, 0, 0),
         "hands": hip((0.03, 0.02, -0.04))},  # pump: elbow folds back
        {"t": 0.8333, "ease": "out", "root": (0.07, -0.02, -0.12), "Root": (-5, -9, 0), "Waist": (-10, -13, 0), "Neck": (-8, -21, 0),
         "RightShoulder": (PT[0] + 4, 0, PT[1] + 2), "RightElbow": (0, 0, 0), "RightWrist": (-10, 0, 0),
         "hands": hip((0.07, -0.02, -0.12))},  # jab: "there!"
        {"t": 1.0333, "ease": "smooth", "root": (0.06, 0, -0.1), "Root": (-4, -12, 0), "Waist": (-7, -16, 0), "Neck": (6, -24, 0),
         "RightShoulder": (PT[0] + 8, 0, PT[1] + 4), "RightElbow": (2, 0, 0), "RightWrist": (0, 0, 0),
         "hands": hip((0.06, 0, -0.1))},  # re-aim: further right and up, head follows
        {"t": 1.2, "ease": "smooth", "Neck": (4, -22, 0), "RightShoulder": (PT[0] + 6, 0, PT[1] + 3)},  # drift
        {"t": 1.4, "ease": "smooth", "root": (0, -0.02, 0), "Root": (0, -3, 0), "Waist": (-2, -4, 0), "Neck": (-2, -8, 0),
         "RightShoulder": (24, 0, 10), "RightElbow": (30, 0, 0), "hands": {"L": (-1.55, -0.72, -0.06)}, "poles": {"L": POINT_POLE_L}},  # arms down, elbow trails
        {"t": 1.5667, "ease": "smooth", "root": (0, 0, 0), "Root": (0, 1, 0), "Waist": (0, 0, 0), "Neck": (1, 2, 0),
         "RightShoulder": (-5, 0, 4), "RightElbow": (8, 0, 0), "hands": {"L": (-1.5, -0.69, 0)}},  # follow-through
        {"t": 1.8, "rest": True},
    ]},
    # Two-hand crate carry walk: wrists pinned either side of a ~1.8 stud crate, forearms forward and parallel at chest
    # height, elbows out; whole upper body leans back ~15 deg against the load; body dips 0.18 after each contact, the
    # crate (hands) and head follow a beat late, crate sways. Hips turn a little with the stepping leg, shoulders counter-turn.
    # Feet from carry_feet.
    "WorkerCarry": {"loop": True, "length": CARRY_T, "stance": {"L": (-0.08, 0, 0), "R": (0.08, 0, 0)}, "fn": carry_feet,
                    "poles": {"R": (1.0, -0.6, 0.3), "L": (-1.0, -0.6, 0.3)},  # poles act ~90 deg round the arm: elbows down, a little out
                    "keys": carry_keys()},
    # Hand-over-hand ladder climb in place (code lifts the rig): arms, body dip and feet from climb(); head looks
    # up at the reaching hand. rise = studs per cycle at speed 1.
    "WorkerClimb": {"loop": True, "length": CL_T, "priority": "Movement", "rise": CL_RISE, "stance": {}, "fn": climb,
                    "keys": [
        {"t": 0.0, "Neck": (24, 0, 0)},  # right hand grabs overhead
        {"t": 0.25, "Neck": (32, 12, 0)},  # looks up at the left hand reaching
        {"t": 0.5, "Neck": (24, 0, 0)},  # left grabs
        {"t": 0.75, "Neck": (32, -12, 0)},
    ]},
    # Rescued survivor resting on the blanket: sits upright-ish, knees up and apart, hands resting on the knees, head up.
    # 4.8 s: breath in (chest opens, sways right) -> hunch forward -> big stretch, both arms overhead, looking up ->
    # arms float down and out back to the knees, slump (exhale) -> look round to the left with the torso following ~25
    # deg -> back past centre -> start. Feet planted, knees out on static knee poles.
    "NpcSit": {"loop": True, "length": 4.8, "priority": "Idle", "stance": {"L": (-0.38, 0, -0.95), "R": (0.38, 0, -0.9)},
               "kneepoles": {"L": (-1.6, 1.0, 0), "R": (1.6, 1.0, 0)}, "poles": SIT_POLE_KNEE, "keys": [
        {"t": 0.0, "root": (0, -1.6, 0), "Root": (6, 0, 0), "Waist": (-5, 0, -3), "Neck": (4, 0, 0),
         "hands": sit_hands(*SIT_KNEE), "RightWrist": (0, 0, 0), "LeftWrist": (0, 0, 0)},  # exhaled, hands on the knees
        {"t": 0.7, "root": (0, -1.52, 0), "Waist": (3, 0, 3), "Neck": (10, 0, 0)},  # breath in: chest opens, sways right
        {"t": 1.2, "ease": "in", "root": (0, -1.6, 0), "Waist": (-11, 0, 0), "Neck": (2, 0, 0),
         "hands": sit_hands(0.62, -1.68, -0.9)},  # hunch forward (anticipation)
        {"t": 1.75, "ease": "out", "root": (0, -1.5, 0), "Root": (9, 0, 0), "Waist": (9, 0, 0), "Neck": (18, 0, 0),
         "hands": sit_hands(1.3, 0.58, 0.15), "poles": SIT_POLE_UP},  # big stretch: arms overhead, looks up
        {"t": 2.15, "Waist": (10, 0, 4), "Neck": (20, 0, 6), "hands": sit_hands(1.38, 0.62, 0.25)},  # holds, leans into it
        {"t": 2.65, "root": (0, -1.57, 0), "Root": (6, 0, 0), "Waist": (2, 0, 0), "Neck": (8, 0, 0),
         "hands": sit_hands(1.9, -0.8, -0.35)},  # arms float down and out
        {"t": 3.0, "root": (0, -1.6, 0), "Waist": (-7, 0, 0), "Neck": (2, 0, 0), "hands": sit_hands(*SIT_KNEE),
         "poles": SIT_POLE_KNEE},  # back on the knees, slumps (exhale)
        {"t": 3.5, "ease": "out", "Waist": (-2, 24, 3), "Neck": (6, 28, 4),
         "hands": {"R": SIT_KNEE, "L": (-0.8, -1.48, -0.75)}},  # looks round left, torso follows (left hand slides back)
        {"t": 4.0, "root": (0, -1.54, 0), "Waist": (0, 22, 2), "Neck": (9, 24, 7),
         "hands": {"R": SIT_KNEE, "L": (-0.85, -1.4, -0.7)}},  # breath in while looking, head tilts
        {"t": 4.4, "root": (0, -1.58, 0), "Waist": (-4, -5, -2), "Neck": (3, -6, -2), "hands": sit_hands(*SIT_KNEE)},  # back past centre
    ]},
}
EASE = {"smooth": ("BEZIER", None), "in": ("CUBIC", "EASE_IN"), "out": ("CUBIC", "EASE_OUT"), "linear": ("LINEAR", None)}


def bl(v):
    """Roblox HRP point -> Blender armature space (Z up, faces +Y, floor at z = 0 once the object sits at -FLOOR)."""
    return Vector((v[0], -v[2], v[1]))


def build_rig():
    """Fresh scene with the R15 proxy armature: FK upper body, IK legs to FootTgt bones, cubes parented to bones."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    arm = bpy.data.objects.new("R15", bpy.data.armatures.new("R15"))
    arm.location = (0, 0, -FLOOR)
    sc.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for p, (par, piv, tail, *_r) in PARTS.items():
        b = eb.new(p)
        b.head, b.tail, b.roll = bl(piv), bl(tail), 0
        b.parent = par and eb[par]
    for s, x in (("Right", 0.5), ("Left", -0.5)):
        t = eb.new("FootTgt" + s[0])
        t.head, t.tail = eb[s + "Foot"].head, eb[s + "Foot"].tail
        pl = eb.new("Pole" + s[0])
        pl.head, pl.tail = bl((x, -1.92, -3)), bl((x, -1.6, -3))
        h = eb.new("HandTgt" + s[0])
        h.head, h.tail = eb[s + "Hand"].head, eb[s + "Hand"].tail
        hp = eb.new("HandPole" + s[0])
        hp.head, hp.tail = bl((3 * x, 0, 0)), bl((3 * x, 0.3, 0))
    bpy.ops.object.mode_set(mode="POSE")
    for s in ("Right", "Left"):
        ik = arm.pose.bones[s + "LowerLeg"].constraints.new("IK")
        ik.target, ik.subtarget, ik.pole_target, ik.pole_subtarget = arm, "FootTgt" + s[0], arm, "Pole" + s[0]
        ik.pole_angle, ik.chain_count, ik.use_stretch = math.radians(POLE_ANGLE), 2, False
        cr = arm.pose.bones[s + "Foot"].constraints.new("COPY_ROTATION")
        cr.target, cr.subtarget = arm, "FootTgt" + s[0]
        ik = arm.pose.bones[s + "LowerArm"].constraints.new("IK")
        ik.name, ik.mute = "HandIK", True
        ik.target, ik.subtarget, ik.pole_target, ik.pole_subtarget = arm, "HandTgt" + s[0], arm, "HandPole" + s[0]
        ik.pole_angle, ik.chain_count, ik.use_stretch = math.radians(-POLE_ANGLE), 2, False
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    bpy.ops.object.mode_set(mode="OBJECT")
    mats = {}
    for p, (_par, _piv, _tail, centre, size, col) in PARTS.items():
        boxes = [(centre, size, col)]
        if p == "Head":  # eyes: which way the head faces
            boxes += [((sx, 1.6, -0.62), (0.16, 0.22, 0.06), (0.05, 0.05, 0.05)) for sx in (-0.25, 0.25)]
        for i, (c, sz, colr) in enumerate(boxes):
            me = bpy.data.meshes.new(p)
            hx, hy, hz = (s / 2 for s in sz)
            me.from_pydata([(x * hx, y * hz, z * hy) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], [],
                           [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
            me.update()
            if colr not in mats:
                m = mats[colr] = bpy.data.materials.new("K%d" % len(mats))
                m.diffuse_color = (*colr, 1)
            me.materials.append(mats[colr])
            ob = bpy.data.objects.new(p + ("" if i == 0 else "_eye%d" % i), me)
            sc.collection.objects.link(ob)
            ob.parent, ob.parent_type, ob.parent_bone = arm, "BONE", p
            bpy.context.view_layer.update()
            ob.matrix_world = arm.matrix_world @ Matrix.Translation(bl(c))
    if "Floor" not in bpy.data.objects:
        me = bpy.data.meshes.new("Floor")
        me.from_pydata([(-6, -6, 0), (6, -6, 0), (6, 6, 0), (-6, 6, 0)], [], [(0, 1, 2, 3)])
        fl = bpy.data.objects.new("Floor", me)
        sc.collection.objects.link(fl)
    return arm


def rest_rot(arm):
    return {b.name: b.matrix_local.to_quaternion() for b in arm.data.bones}


def poses(slot):
    """Keys -> list of (frame, ease, {joint: Roblox quat keyed here}, root Vector or None, {L/R: foot Vector} or None).
    The first and last key (and rest keys) carry every joint, holding earlier values; others only what they name."""
    out, cur, feet, hands, root, poles = [], {}, {}, {}, (0, 0, 0), dict(slot.get("poles", {}))
    skip = set(slot["fn"](0)) if "fn" in slot else set()  # channels the per-frame fn owns
    keys = list(slot["keys"])
    for i, k in enumerate(keys):
        full = i == 0 or (i == len(keys) - 1 and not slot["loop"]) or k.get("rest")
        if k.get("rest"):
            cur, feet, root = {}, {}, (0, 0, 0)
        cur.update({j: v for j, v in k.items() if j in JOINTS})
        feet.update(k.get("feet", {}))
        hands.update(k.get("hands", {}))
        poles.update(k.get("poles", {}))
        root = k.get("root", root)
        q = {j: euler(cur.get(j, (0, 0, 0))) for j in JOINTS if (full or j in k) and j not in skip}
        ft = {s: Vector(slot["stance"].get(s, (0, 0, 0))) + Vector(feet.get(s, (0, 0, 0))) for s in "LR"}
        out.append([k["t"] * FPS, k.get("ease", "smooth"), q,
                    Vector(root) if (full or "root" in k) and "root" not in skip else None,
                    ft if (full or "feet" in k) and "feet" not in skip else None,
                    {s: Vector(v) - WRIST[s] for s, v in hands.items()} if (full or "hands" in k) else None,
                    {s: Vector(v) for s, v in poles.items()} if (full or "poles" in k) else None])
    if slot["loop"]:  # exact loop: the last key is the first one again
        out.append([slot["length"] * FPS, *out[0][1:]])
    return out


def fn_poses(slot):
    """slot["fn"](t) -> {joint: degrees, "root": studs, "feet": {L/R: offset}}, keyed linear on every frame: for
    channels that must track a planted contact exactly (feet, gripping hands); fn(0) == fn(length) for loops."""
    if "fn" not in slot:
        return []
    out = []
    for f in range(round(slot["length"] * FPS) + 1):
        ch = slot["fn"](f / FPS)
        ft = ch.get("feet")
        out.append([f, "linear", {j: euler(v) for j, v in ch.items() if j in JOINTS},
                    Vector(ch["root"]) if "root" in ch else None,
                    ft and {s: Vector(slot["stance"].get(s, (0, 0, 0))) + Vector(ft[s]) for s in "LR"}, None, None])
    return out


def key_slot(arm, name):
    slot = SLOTS[name]
    ad = arm.animation_data or arm.animation_data_create()
    act = bpy.data.actions.get("K_" + name)
    if act:
        bpy.data.actions.remove(act)
    ad.action = bpy.data.actions.new("K_" + name)
    rr, pbs, prev, eases = rest_rot(arm), arm.pose.bones, {}, {}

    def key(pb, prop, value, f, e):
        setattr(pb, prop, value)
        pb.keyframe_insert(prop, frame=f)
        eases.setdefault('pose.bones["%s"].%s' % (pb.name, prop), []).append(e)

    for s in "LR":  # knee poles: rest, or the slot's static offset (NpcSit: knees up and out); keyed so no slot inherits one
        key(pbs["Pole" + s], "location", rr["Pole" + s].inverted() @ (QAI @ Vector(slot.get("kneepoles", {}).get(s, (0, 0, 0)))), 0, "smooth")
    for s in "RL":  # arm IK only where the slot pins that wrist
        c = pbs[("Right" if s == "R" else "Left") + "LowerArm"].constraints["HandIK"]
        c.mute = s not in slot.get("poles", {})
    for f, e, q, root, feet, hands, poles in poses(slot) + fn_poses(slot):
        for j, qj in q.items():
            p = JOINTS[j][0]
            if p.endswith("Leg") or p.endswith("Foot"):
                continue  # IK
            b = rr[p].inverted() @ QAI @ qj @ QA @ rr[p]
            if j in prev and b.dot(prev[j]) < 0:
                b = -b  # component-wise interpolation needs the near hemisphere
            prev[j] = b
            key(pbs[p], "rotation_quaternion", b, f, e)
        if root is not None:
            key(pbs["LowerTorso"], "location", rr["LowerTorso"].inverted() @ (QAI @ root), f, e)
        for s in feet or ():
            key(pbs["FootTgt" + s], "location", rr["FootTgt" + s].inverted() @ (QAI @ feet[s]), f, e)
        for s in hands or ():
            key(pbs["HandTgt" + s], "location", rr["HandTgt" + s].inverted() @ (QAI @ hands[s]), f, e)
        for s in poles or ():  # a key's "poles" moves that elbow pole (lands 3 studs inward of the value: HandPole rest offset)
            pole = poles[s] - Vector((3 * WRIST[s].x, 0, 0))
            key(pbs["HandPole" + s], "location", rr["HandPole" + s].inverted() @ (QAI @ pole), f, e)
    from bpy_extras import anim_utils
    for fc in anim_utils.animdata_get_channelbag_for_assigned_slot(ad).fcurves:
        es = eases[fc.data_path]
        assert len(es) == len(fc.keyframe_points), fc.data_path
        for kp, e in zip(fc.keyframe_points, es):
            kp.interpolation = EASE[e][0]
            if EASE[e][1]:
                kp.easing = EASE[e][1]
            kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
        if slot["loop"]:
            fc.modifiers.new("CYCLES")  # cycle-aware auto handles: no ease-in/out stall at the seam
        fc.update()
    n = round(slot["length"] * FPS)
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, n
    return n


def sample(arm, name, n):
    sc, rr, pbs = bpy.context.scene, rest_rot(arm), arm.pose.bones
    keys, hands = [], []
    for f in range(n + 1):
        sc.frame_set(f)
        d = {p: pbs[p].matrix.to_quaternion() @ rr[p].inverted() for p in PARTS}
        q = {}
        for j, (p, par) in JOINTS.items():
            jb = d[p] if par is None else d[par].inverted() @ d[p]
            jq = QA @ jb @ QAI
            jq.normalize()
            q[j] = jq
        root = QA @ (pbs["LowerTorso"].head - arm.data.bones["LowerTorso"].head_local)
        keys.append({"t": f / FPS, "q": q, "root": root})
        hands.append(tuple(QA @ pbs[s + "Hand"].tail for s in ("Right", "Left")))
        for s in ("Right", "Left"):  # IK sanity: knees bend forward (or up, sitting), never sideways
            hip, knee, ank = pbs[s + "UpperLeg"].head, pbs[s + "LowerLeg"].head, pbs[s + "LowerLeg"].tail
            mid = (hip + ank) / 2
            assert abs(knee.x - mid.x) < 0.2 and (knee.y > mid.y - 0.02 or knee.z > mid.z + 0.3), (name, f, s, knee)
            c = pbs[s + "LowerArm"].constraints["HandIK"]
            if not c.mute:  # pinned wrist actually reaches its target (no stretch, so out of reach = sliding hand)
                miss = (pbs[s + "LowerArm"].tail - pbs["HandTgt" + s[0]].head).length
                assert miss < 0.03, (name, f, s, "wrist miss", miss)
    slot = SLOTS[name]
    out = reduce_keys(keys)
    for f, *_ in poses(slot):  # report hand tips (Roblox HRP space, y up, -z forward) at each key
        r, l = hands[round(f)]
        print("  %s f%2d  R hand (%5.2f %5.2f %5.2f)  L hand (%5.2f %5.2f %5.2f)" % (name, round(f), r.x, r.y, r.z, l.x, l.y, l.z))
    return {
        "name": name, "file": "keyed.py", "take": None, "frames": [0, n], "fps": FPS, "loop": slot["loop"],
        "priority": slot.get("priority", "Action"), "length": round(out[-1]["t"], 4), "rise": slot.get("rise", 0.0), "keys": [encode(k) for k in out],
    }


def main(args):
    pose_only = args[:1] == ["--pose"]
    names = args[1:] if pose_only else (args or list(SLOTS))
    arm = build_rig()  # always fresh: the rig is defined by this file
    os.makedirs(os.path.join(HERE, "out", "keyed"), exist_ok=True)
    for name in names:
        n = key_slot(arm, name)
        if pose_only:
            continue
        res = sample(arm, name, n)
        with open(os.path.join(HERE, "out", "keyed", name + ".json"), "w") as f:
            json.dump(res, f, separators=(",", ":"))
        print("%s: %.2f s, loop %s, %d keys" % (name, res["length"], res["loop"], len(res["keys"])))


if __name__ == "__main__":
    main(list(globals().get("KEYED_ARGS", [])))
