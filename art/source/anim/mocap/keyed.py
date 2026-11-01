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
# 56% of the cycle (double support, heavy walk), so the stride is 2 * 6.4 * 0.3375 = 2.16 studs.
CARRY_T, CARRY_D = 0.6, 0.5625  # cycle, planted fraction
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


# WorkerClimb: 1.0 s, two equal mirrored pulls; each grip slides 2 studs down while gripped -> rise 4 studs per cycle.
# Hands are set body-relative: the reaching hand straight overhead (CL_TOP) while the other is down at the chest (CL_LOW).
CL_T, CL_RISE = 1.0, 4.0
CL_TOP, CL_LOW, CL_Z = 2.3, 0.3, -0.7  # grab height (arm straight overhead), release (chest), ladder hand line; TOP-LOW = rise/2
CL_R0, CL_A, CL_PK = -0.1, 0.4, 0.3  # root y at the grab, snap lift, lift peak (fraction of a pull)
CL_FOOT = (1.0, -0.5, 0.15)  # foot plant height (knee high), rung line, planted fraction (leg range limits it)


def cl_lift(u):
    """Root y over one pull (u 0..1): snaps up in the first 30%, then sags through the hang (the rig's own rise is linear)."""
    w = u / (2 * CL_PK) if u < CL_PK else 0.5 + (u - CL_PK) / (2 * (1 - CL_PK))
    return CL_R0 + CL_A * math.sin(math.pi * w)


def climb(t):
    u = (2 * t / CL_T) % 1  # pull phase: 0 = a hand grabs
    rooty = cl_lift(u)
    waist = -8 - 10 * (rooty - CL_R0) / CL_A  # chest in to the ladder at the top of the pull
    ch = {"root": (0, rooty, 0), "Waist": (waist, 0, 0)}
    for side, off, sz in (("Right", 0.0, 8), ("Left", 0.5, -8)):  # sz: arms a little out to the sides
        p = (t / CL_T + off) % 1
        if p < 0.5:  # gripping: hand fixed on the rung (HRP slide = rise) while the body snaps up, then hangs
            hy, hz = CL_TOP + CL_R0 - (CL_TOP - CL_LOW) * p / 0.5, CL_Z
        else:  # release at the chest, shoot straight up past the face, overshoot the rung, settle onto it
            sw = (p - 0.5) / 0.5
            rel = herm(sw / 0.4, CL_LOW, CL_TOP + 0.2, 4.0, 0) if sw < 0.4 else \
                herm((sw - 0.4) / 0.6, CL_TOP + 0.2, CL_TOP, 0, 0)
            hy, hz = rel + rooty, CL_Z + 0.2 * math.sin(math.pi * sw)
        a, b = arm_ik(hy, hz, rooty, waist)
        ch[side + "Shoulder"], ch[side + "Elbow"] = (a, 0, sz), (b, 0, 0)
    hi, fz, q = CL_FOOT
    df = CL_RISE * q / CL_T
    feet = {}
    for side, plant in (("L", 0.0), ("R", 0.5)):  # each foot plants (knee high) as the opposite hand grabs, pushes the pull
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
CW = (1.3, -0.8)  # WorkerCarry wrists: x (crate side), z (forward of the chest)
PT = (92, 5)  # WorkerPoint held point: RightShoulder x (level), z (+ chest/hip turn: ~43 deg right of forward, clear of the head in all three sheet views)


def hip(root):
    """WorkerPoint left wrist on the hip, following the body (root offset)."""
    return {"L": (-1.12 + root[0], -0.28 + root[1], -0.12 + root[2])}  # -0.12: hips turned ~10 deg right


SIT_HANDS = {"R": (1.6, -2.7, 1.5), "L": (-1.6, -2.7, 1.5)}  # NpcSit wrists: planted wide behind the hips
POINT_POLE_L = (-3.0, -1.0, 2.5)  # WorkerPoint left elbow out to the side and forward
SAW_T, SAW_POLE_R, SAW_POLE_L = 0.6, (0, -1.0, 0), (-3.0, -0.4, -0.5)  # stroke period, arm IK poles (R: elbow out + back on the pull)


def saw_keys():
    """One identical push/pull stroke per SAW_T, keyed every 0.075 s: s = +1 pulled back, -1 pushed through."""
    keys = []
    for i in range(16):
        t = i * 0.075
        w = 2 * math.pi * t / SAW_T
        s, h, g = math.cos(w), math.cos(w + 0.45), math.cos(w - 0.6)  # hand, hips (lead), head (lag)
        keys.append({"t": round(t, 4), "ease": "smooth",
                     "root": (0.04 * h, -0.2 + 0.06 * h, -0.03 + 0.11 * h), "Root": (-4 + 2 * h, -5 * h, 0),
                     "Waist": (-12 + 4 * s, -10 * s, 0), "Neck": (-18 + 4 * g, 8 * g, 0),
                     "hands": {"R": (1.25, -0.55 + 0.05 * s, -1.025 + 0.925 * s), "L": (-0.9, -0.5, -1.15)},
                     "RightWrist": (-4 + 8 * g, 0, 0), "LeftWrist": (-20, 0, 0)})
    return keys


SLOTS = {
    # Tap, tap, BIG strike per 1.2 s, all in the arm and shoulder (small torso settle, no crouch): each hit snaps the
    # wrist, rebounds off the nail and the torso settles a beat later; the big one cocks overhead with only a brief top.
    # Left hand pinned on the nail low in front (IK, elbow out so it reads from the front-3/4).
    "WorkerHammer": {"loop": True, "length": 1.2, "stance": {"L": (-0.2, 0, -0.4), "R": (0.25, 0, 0.35)},
                     "poles": {"L": SAW_POLE_L}, "keys": [
        {"t": 0.0, "ease": "smooth", "root": (0, -0.08, 0.02), "Root": (2, 6, 0), "Waist": (6, -14, 0), "Neck": (-22, 10, 0),
         "RightShoulder": (150, 0, 14), "RightElbow": (40, 0, 0), "RightWrist": (-22, 0, 0),
         "hands": {"L": (-0.45, -0.35, -0.95)}, "LeftWrist": (-30, 0, 0)},  # big cock, still rising
        {"t": 0.1, "ease": "in", "root": (0, -0.06, 0.03), "Waist": (8, -17, 0), "Neck": (-20, 12, 0),
         "RightShoulder": (164, 0, 14), "RightElbow": (48, 0, 0), "RightWrist": (-36, 0, 0)},  # top: wrist cocks last
        {"t": 0.2333, "ease": "out", "root": (0, -0.16, -0.04), "Root": (-3, -3, 0), "Waist": (-10, 6, 0), "Neck": (-30, 0, 0),
         "RightShoulder": (54, 0, -10), "RightElbow": (22, 0, 0), "RightWrist": (-62, 0, 0),
         "hands": {"L": (-0.45, -0.41, -0.95)}},  # BIG impact: wrist snapped through, nail hand jolts
        {"t": 0.3, "ease": "smooth", "root": (0, -0.2, -0.05), "Waist": (-14, 8, 0), "Neck": (-33, -2, 0),
         "RightShoulder": (60, 0, 10), "RightElbow": (34, 0, 0), "RightWrist": (-10, 0, 0),
         "hands": {"L": (-0.45, -0.35, -0.95)}},  # rebound; torso still settling
        {"t": 0.4, "ease": "smooth", "root": (0, -0.14, -0.03), "Root": (-2, -1, 0), "Waist": (-10, 4, 0), "Neck": (-28, 2, 0),
         "RightShoulder": (52, 0, 2), "RightElbow": (30, 0, 0), "RightWrist": (-40, 0, 0)},  # settle
        {"t": 0.5, "ease": "in", "Waist": (-7, 0, 0), "Neck": (-26, 4, 0),
         "RightShoulder": (54, 0, 16), "RightElbow": (36, 0, 0), "RightWrist": (30, 0, 0)},  # tap 1 up (wrist lags back)
        {"t": 0.6, "ease": "out", "root": (0, -0.15, -0.03), "Waist": (-9, 3, 0), "Neck": (-30, 0, 0),
         "RightShoulder": (52, 0, -8), "RightElbow": (26, 0, 0), "RightWrist": (-56, 0, 0),
         "hands": {"L": (-0.45, -0.38, -0.95)}},  # tap 1
        {"t": 0.6667, "ease": "smooth", "RightShoulder": (52, 0, 8), "RightElbow": (28, 0, 0), "RightWrist": (-16, 0, 0),
         "hands": {"L": (-0.45, -0.35, -0.95)}},  # rebound
        {"t": 0.7667, "ease": "in", "root": (0, -0.12, -0.02), "Waist": (-6, -2, 0), "Neck": (-25, 5, 0),
         "RightShoulder": (55, 0, 18), "RightElbow": (38, 0, 0), "RightWrist": (32, 0, 0)},  # tap 2 up
        {"t": 0.8667, "ease": "out", "root": (0, -0.15, -0.03), "Waist": (-9, 3, 0), "Neck": (-30, 0, 0),
         "RightShoulder": (52, 0, -8), "RightElbow": (26, 0, 0), "RightWrist": (-58, 0, 0),
         "hands": {"L": (-0.45, -0.38, -0.95)}},  # tap 2
        {"t": 0.9333, "ease": "smooth", "Waist": (-6, -2, 0),
         "RightShoulder": (54, 0, 10), "RightElbow": (30, 0, 0), "RightWrist": (-12, 0, 0),
         "hands": {"L": (-0.45, -0.35, -0.95)}},  # rebound into the big lift
        {"t": 1.0667, "ease": "smooth", "root": (0, -0.1, 0.01), "Root": (0, 4, 0), "Waist": (2, -10, 0), "Neck": (-24, 8, 0),
         "RightShoulder": (124, 0, 22), "RightElbow": (58, 0, 0), "RightWrist": (12, 0, 0)},  # big lift, out past the head
    ]},
    # Continuous saw: one smooth sinusoidal stroke per 0.6 s (saw_keys), right hand IK on a straight saw line, elbow
    # driving back past the torso on the pull; hips rock and dip with each stroke; left hand pinned on the timber.
    "WorkerSaw": {"loop": True, "length": 1.2, "stance": {"L": (-0.15, 0, -0.7), "R": (0.35, 0, 0.6)},
                  "poles": {"R": SAW_POLE_R, "L": SAW_POLE_L}, "keys": saw_keys()},
    # Eased crouch (arms out a little) -> pop to a wide V (swung back, clear of the head) with a big hop -> squash on
    # landing -> one small goalpost pump -> dip -> the BIG pump straight up with a second small hop, held high with a knee
    # bounce -> elbows fold into a "yes!" pull-down -> knee settle and follow-through. Arms never pass through a flat T.
    # One-shot 1.73 s (52 frames).
    "WorkerCelebrate": {"loop": False, "length": 1.7333, "stance": {}, "keys": [
        {"t": 0.0, "rest": True, "ease": "smooth"},
        {"t": 0.3, "ease": "in", "root": (0, -0.5, 0.05), "Root": (-10, 0, 0), "Waist": (-16, 0, 0), "Neck": (-10, 0, 0),
         "RightShoulder": (26, 0, 30), "RightElbow": (72, 0, 0), "LeftShoulder": (26, 0, -30), "LeftElbow": (72, 0, 0),
         "feet": {"L": (0, 0, 0), "R": (0, 0, 0)}},  # gather, arms out of the chest
        {"t": 0.3667, "ease": "out", "root": (0, 0.1, 0), "Root": (0, 0, 0), "Waist": (4, 0, 0),
         "feet": {"L": (0, 0, 0), "R": (0, 0, 0)}},  # take-off: legs extend, toes leave
        {"t": 0.5, "ease": "in", "root": (0, 0.92, 0), "Root": (4, 0, 0), "Waist": (14, 0, 0), "Neck": (20, 0, 0),
         "feet": {"L": (-0.1, 0.8, 0.1), "R": (0.1, 0.8, 0.1)},
         "RightShoulder": (-16, 0, 124), "RightElbow": (8, 0, 0), "LeftShoulder": (-16, 0, -124), "LeftElbow": (8, 0, 0)},  # apex: wide V
        {"t": 0.6333, "ease": "out", "root": (0, 0.04, 0), "Root": (1, 0, 0), "Waist": (10, 0, 0),
         "feet": {"L": (-0.1, 0, 0), "R": (0.1, 0, 0)}},  # touch down
        {"t": 0.7, "ease": "smooth", "root": (0, -0.52, 0), "Root": (-6, 0, 0), "Waist": (0, 0, 0), "Neck": (6, 0, 0),
         "RightShoulder": (-10, 0, 114), "RightElbow": (24, 0, 0), "LeftShoulder": (-10, 0, -114), "LeftElbow": (24, 0, 0)},  # squash, arms drag
        {"t": 0.8, "ease": "out", "root": (0, -0.12, 0), "Root": (0, 0, 0), "Waist": (10, 0, 0), "Neck": (14, 0, 0),
         "RightShoulder": (-12, 0, 128), "RightElbow": (12, 0, 0), "LeftShoulder": (-12, 0, -128), "LeftElbow": (12, 0, 0)},  # back up
        {"t": 0.8667, "ease": "out", "root": (0, -0.22, 0), "Waist": (6, 12, 0), "Neck": (8, 14, 0),
         "RightShoulder": (60, 15, 88), "RightElbow": (85, 0, 0), "LeftShoulder": (60, -15, -88), "LeftElbow": (85, 0, 0)},  # small pump: elbows drop to a goalpost, fists stay up beside the head
        {"t": 0.9667, "ease": "in", "root": (0, -0.36, 0), "Root": (-4, 0, 0), "Waist": (2, -6, 0), "Neck": (4, -8, 0),
         "RightShoulder": (62, 15, 84), "RightElbow": (102, 0, 0), "LeftShoulder": (62, -15, -84), "LeftElbow": (102, 0, 0),
         "feet": {"L": (-0.1, 0, 0), "R": (0.1, 0, 0)}},  # dip: wind up for the big one
        {"t": 1.0667, "ease": "out", "root": (0, 0.36, 0), "Root": (2, 0, 0), "Waist": (16, 0, 0), "Neck": (24, 0, 0),
         "feet": {"L": (-0.1, 0.3, 0.06), "R": (0.1, 0.3, 0.06)},
         "RightShoulder": (-8, 0, 150), "RightElbow": (4, 0, 0), "LeftShoulder": (-8, 0, -150), "LeftElbow": (4, 0, 0)},  # BIG pump + hop
        {"t": 1.1667, "ease": "out", "root": (0, -0.04, 0), "Waist": (14, 4, 0), "Neck": (22, 6, 0),
         "feet": {"L": (-0.1, 0, 0), "R": (0.1, 0, 0)},
         "RightShoulder": (-6, 0, 148), "RightElbow": (6, 0, 0), "LeftShoulder": (-6, 0, -148), "LeftElbow": (6, 0, 0)},  # land, still high
        {"t": 1.2333, "ease": "smooth", "root": (0, -0.26, 0), "Root": (-3, 0, 0), "Waist": (8, -3, 0), "Neck": (16, -4, 0),
         "RightShoulder": (-4, 0, 142), "RightElbow": (14, 0, 0), "LeftShoulder": (-4, 0, -142), "LeftElbow": (14, 0, 0)},  # knee bounce, held
        {"t": 1.3333, "ease": "smooth", "root": (0, -0.08, 0), "Root": (0, 0, 0), "Waist": (10, 0, 0), "Neck": (14, 0, 0),
         "RightShoulder": (-2, 0, 136), "RightElbow": (18, 0, 0), "LeftShoulder": (-2, 0, -136), "LeftElbow": (18, 0, 0)},  # drift
        {"t": 1.4, "ease": "smooth", "root": (0, -0.1, 0), "Waist": (6, 0, 0), "Neck": (10, 0, 0),
         "RightShoulder": (45, 15, 80), "RightElbow": (95, 0, 0), "LeftShoulder": (45, -15, -80), "LeftElbow": (95, 0, 0)},  # elbows fold
        {"t": 1.4667, "ease": "smooth", "root": (0, -0.18, 0), "Waist": (-2, 0, 0), "Neck": (2, 0, 0),
         "RightShoulder": (6, 0, 30), "RightElbow": (50, 0, 0), "LeftShoulder": (6, 0, -30), "LeftElbow": (50, 0, 0)},  # "yes!" pull-down
        {"t": 1.5667, "ease": "smooth", "root": (0, -0.2, 0), "Root": (-2, 0, 0), "Waist": (-4, 0, 0), "Neck": (-5, 0, 0),
         "feet": {"L": (0, 0, 0), "R": (0, 0, 0)},
         "RightShoulder": (8, 0, 14), "RightElbow": (26, 0, 0), "LeftShoulder": (8, 0, -14), "LeftElbow": (26, 0, 0)},  # knee settle
        {"t": 1.6667, "ease": "smooth", "root": (0, -0.04, 0), "Root": (0, 0, 0), "Waist": (1, 0, 0), "Neck": (1, 0, 0),
         "RightShoulder": (-6, 0, 8), "RightElbow": (10, 0, 0), "LeftShoulder": (-6, 0, -8), "LeftElbow": (10, 0, 0)},  # follow-through
        {"t": 1.7333, "rest": True},
    ]},
    # Windup across the chest -> snap a STRAIGHT arm to shoulder height, ~55 deg right of forward (clear of the head from
    # front-3/4, front and side), overshoot -> settle; chest and head turn and lean into it, left hand on the hip (elbow
    # out) -> two small nods with a push of the point and a body bob -> release with overlap. 1.8 s.
    "WorkerPoint": {"loop": False, "length": 1.8, "stance": {}, "poles": {"L": POINT_POLE_L}, "keys": [
        {"t": 0.0, "rest": True, "ease": "smooth", "hands": {"L": (-1.5, -0.69, 0)}},
        {"t": 0.2333, "ease": "in", "root": (-0.06, -0.16, 0.1), "Root": (-3, 14, 0), "Waist": (-2, 10, 0), "Neck": (-6, -24, 0),
         "RightShoulder": (24, 0, 6), "RightElbow": (92, 0, 0), "hands": {"L": (-1.62, -0.68, -0.12)}},  # pull back
        {"t": 0.4, "ease": "out", "root": (0.12, -0.06, -0.2), "Root": (-3, -12, 0), "Waist": (-4, -16, 0), "Neck": (4, -30, 0),
         "RightShoulder": (PT[0] + 6, 0, PT[1] + 8), "RightElbow": (0, 0, 0), "RightWrist": (-6, 0, 0),
         "hands": {"L": (-1.35, -0.55, -0.12)}},  # snap past the point
        {"t": 0.5, "ease": "smooth", "root": (0.1, -0.15, -0.15), "Root": (-2, -9, 0), "Waist": (-2, -12, 0), "Neck": (0, -24, 0),
         "RightShoulder": (PT[0] - 2, 0, PT[1] - 3), "RightElbow": (3, 0, 0), "RightWrist": (0, 0, 0),
         "hands": hip((0.1, -0.15, -0.15))},  # settle back, hand on the hip
        {"t": 0.5667, "ease": "smooth", "root": (0.1, -0.12, -0.16), "hands": hip((0.1, -0.12, -0.16)), "Neck": (2, -26, 0),
         "RightShoulder": (PT[0], 0, PT[1]), "RightElbow": (1, 0, 0)},
        {"t": 0.7667, "ease": "smooth", "root": (0.1, -0.2, -0.18), "hands": hip((0.1, -0.2, -0.18)), "Root": (-3, -11, 0), "Waist": (-6, -14, 0), "Neck": (-4, -28, 0),
         "RightShoulder": (PT[0] - 2, 0, PT[1] - 2)},  # nod 1: point pushes out, body bobs
        {"t": 0.9333, "ease": "smooth", "root": (0.1, -0.09, -0.15), "hands": hip((0.1, -0.09, -0.15)), "Root": (-2, -8, 0), "Waist": (-1, -11, 0), "Neck": (9, -22, 0),
         "RightShoulder": (PT[0], 0, PT[1] + 4)},
        {"t": 1.1, "ease": "smooth", "root": (0.1, -0.19, -0.18), "hands": hip((0.1, -0.19, -0.18)), "Root": (-3, -12, 0), "Waist": (-6, -15, 0), "Neck": (-3, -29, 0),
         "RightShoulder": (PT[0] - 1, 0, PT[1] - 2)},  # nod 2
        {"t": 1.2667, "ease": "smooth", "root": (0.08, -0.1, -0.14), "hands": hip((0.08, -0.1, -0.14)), "Root": (-2, -9, 0), "Waist": (-1, -11, 0), "Neck": (8, -23, 0),
         "RightShoulder": (PT[0], 0, PT[1] + 3)},
        {"t": 1.5, "ease": "smooth", "root": (0, -0.1, 0), "Root": (0, -3, 0), "Waist": (-3, -4, 0), "Neck": (-4, -8, 0),
         "RightShoulder": (14, 0, 8), "RightElbow": (24, 0, 0), "hands": {"L": (-1.56, -0.72, -0.08)}},  # arms down, elbows trailing
        {"t": 1.6333, "ease": "smooth", "root": (0, -0.02, 0), "Root": (0, 1, 0), "Neck": (1, 2, 0),
         "RightShoulder": (-4, 0, 4), "RightElbow": (8, 0, 0), "hands": {"L": (-1.5, -0.69, 0)}},  # follow-through
        {"t": 1.8, "rest": True},
    ]},
    # Two-hand crate carry walk: wrists pinned either side of a ~1.8 stud crate, forearms forward and parallel at chest
    # height, elbows out; whole upper body leans back ~15 deg against the load; big body dip after each contact, the
    # crate (hands) and head follow a beat late. Hips turn a little with the stepping leg, shoulders counter-turn.
    # Feet from carry_feet.
    "WorkerCarry": {"loop": True, "length": CARRY_T, "stance": {"L": (-0.08, 0, 0), "R": (0.08, 0, 0)}, "fn": carry_feet,
                    "poles": {"R": (1.0, -0.6, 0.3), "L": (-1.0, -0.6, 0.3)}, "keys": [  # poles act ~90 deg round the arm: elbows down, a little out
        {"t": 0.0, "root": (0, -0.4, 0), "Root": (4, 5, -2), "Waist": (11, -5, 1), "Neck": (-14, 2, 0),
         "hands": {"R": (CW[0], 0.0, CW[1]), "L": (-CW[0], 0.0, CW[1])},
         "RightWrist": (0, 30, -75), "LeftWrist": (0, -30, 75)},  # right heel contact; hands turned in flat on the crate sides
        {"t": 0.0667, "ease": "out", "root": (0, -0.56, 0.02), "Waist": (9, -4, 1)},  # absorb: body at its lowest
        {"t": 0.1, "Neck": (-24, 1, 0), "hands": {"R": (CW[0], -0.3, CW[1] + 0.04), "L": (-CW[0], -0.3, CW[1] + 0.04)}},  # crate, head dip late
        {"t": 0.1667, "root": (0.06, -0.14, 0), "Root": (4, 0, 0), "Waist": (13, 0, 0)},  # passing: up on the planted leg
        {"t": 0.2167, "Neck": (-6, 0, 0), "hands": {"R": (CW[0], 0.16, CW[1] - 0.04), "L": (-CW[0], 0.16, CW[1] - 0.04)}},  # crate floats up late
        {"t": 0.3, "root": (0, -0.4, 0), "Root": (4, -5, 2), "Waist": (11, 5, -1), "Neck": (-14, -2, 0),
         "hands": {"R": (CW[0], 0.0, CW[1]), "L": (-CW[0], 0.0, CW[1])}},  # left contact
        {"t": 0.3667, "ease": "out", "root": (0, -0.56, 0.02), "Waist": (9, 4, -1)},
        {"t": 0.4, "Neck": (-24, -1, 0), "hands": {"R": (CW[0], -0.3, CW[1] + 0.04), "L": (-CW[0], -0.3, CW[1] + 0.04)}},
        {"t": 0.4667, "root": (-0.06, -0.14, 0), "Root": (4, 0, 0), "Waist": (13, 0, 0)},
        {"t": 0.5167, "Neck": (-6, 0, 0), "hands": {"R": (CW[0], 0.16, CW[1] - 0.04), "L": (-CW[0], 0.16, CW[1] - 0.04)}},
    ]},
    # Hand-over-hand ladder climb in place (code lifts the rig): arms, body dip and feet from climb(); head looks
    # up at the reaching hand. rise = studs per cycle at speed 1.
    "WorkerClimb": {"loop": True, "length": CL_T, "priority": "Movement", "rise": CL_RISE, "stance": {}, "fn": climb,
                    "keys": [
        {"t": 0.0, "Neck": (24, 0, 0)},  # right hand grabs overhead
        {"t": 0.25, "Neck": (32, 12, 0)},  # looks up at the left hand reaching
        {"t": 0.5, "Neck": (24, 0, 0)},  # left grabs
        {"t": 0.75, "Neck": (32, -12, 0)},
    ]},
    # Rescued survivor resting on a blanket, open silhouette from every side: both legs out in front, slightly apart,
    # knees a little bent; leaning back ~55 deg on both straight arms planted wide behind the hips; head up. Big slow
    # breaths (3 per loop, chest rises and opens), and one ~45 deg look round to the left with the upper torso following
    # (glance right first, quick turn past the mark, settle, drift, slow return with overshoot). Idle, 4.8 s.
    "NpcSit": {"loop": True, "length": 4.8, "priority": "Idle", "stance": {"L": (-0.1, 0.3, -1.45), "R": (0.12, 0.36, -1.6)},
               "poles": {"R": (3.0, -1.0, 3.0), "L": (-3.0, -1.0, 3.0)}, "keys": [
        {"t": 0.0, "root": (0, -1.54, 0.05), "Root": (30, 0, 0), "Waist": (25, 0, 0), "Neck": (-45, 0, 0),
         "hands": SIT_HANDS, "RightWrist": (0, 0, 0), "LeftWrist": (0, 0, 0)},  # exhaled
        {"t": 0.8, "root": (0, -1.5, 0.05), "Waist": (34, 0, 0), "Neck": (-53, 5, 0)},  # inhale: chest lifts and opens
        {"t": 1.5, "root": (0, -1.54, 0.05), "Waist": (24, -2, 0), "Neck": (-44, -12, 2)},  # exhale, glance dips right first
        {"t": 1.85, "ease": "out", "Waist": (27, 5, 0), "Neck": (-47, 48, -4)},  # quick turn left, past the mark
        {"t": 2.1, "Waist": (27, 5, 0), "Neck": (-46, 41, -2)},  # settles on it
        {"t": 2.5, "root": (0, -1.5, 0.05), "Waist": (35, 5, 0), "Neck": (-55, 42, -7)},  # inhale while looking, head tilts
        {"t": 3.0, "Waist": (28, 4, 0), "Neck": (-47, 37, -5)},  # drift
        {"t": 3.3, "root": (0, -1.54, 0.05), "Waist": (25, 3, 0), "Neck": (-44, 32, -3)},  # exhale, starts back slowly
        {"t": 3.9, "Waist": (26, -2, 0), "Neck": (-46, -14, 3)},  # comes back past the start
        {"t": 4.2, "root": (0, -1.5, 0.05), "Waist": (33, -1, 0), "Neck": (-53, -7, 2)},  # breath in
        {"t": 4.5, "Waist": (26, -1, 0), "Neck": (-46, -2, 1)},  # settle
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
    out, cur, feet, hands, root = [], {}, {}, {}, (0, 0, 0)
    skip = set(slot["fn"](0)) if "fn" in slot else set()  # channels the per-frame fn owns
    keys = list(slot["keys"])
    for i, k in enumerate(keys):
        full = i == 0 or (i == len(keys) - 1 and not slot["loop"]) or k.get("rest")
        if k.get("rest"):
            cur, feet, root = {}, {}, (0, 0, 0)
        cur.update({j: v for j, v in k.items() if j in JOINTS})
        feet.update(k.get("feet", {}))
        hands.update(k.get("hands", {}))
        root = k.get("root", root)
        q = {j: euler(cur.get(j, (0, 0, 0))) for j in JOINTS if (full or j in k) and j not in skip}
        ft = {s: Vector(slot["stance"].get(s, (0, 0, 0))) + Vector(feet.get(s, (0, 0, 0))) for s in "LR"}
        out.append([k["t"] * FPS, k.get("ease", "smooth"), q,
                    Vector(root) if (full or "root" in k) and "root" not in skip else None,
                    ft if (full or "feet" in k) and "feet" not in skip else None,
                    {s: Vector(v) - WRIST[s] for s, v in hands.items()} if (full or "hands" in k) else None])
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
                    ft and {s: Vector(slot["stance"].get(s, (0, 0, 0))) + Vector(ft[s]) for s in "LR"}, None])
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

    for s in "RL":  # arm IK only where the slot pins that wrist
        c = pbs[("Right" if s == "R" else "Left") + "LowerArm"].constraints["HandIK"]
        c.mute = s not in slot.get("poles", {})
        if not c.mute:
            pole = Vector(slot["poles"][s]) - Vector((3 * WRIST[s].x, 0, 0))
            key(pbs["HandPole" + s], "location", rr["HandPole" + s].inverted() @ (QAI @ pole), 0, "linear")
    for f, e, q, root, feet, hands in poses(slot) + fn_poses(slot):
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
