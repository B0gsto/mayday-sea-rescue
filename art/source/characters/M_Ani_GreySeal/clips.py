"""M_Ani_GreySeal clips (docs/12 2.10 AN1): swim, surface, look, haul-out and flee, as Blender actions on RIG_Seal.

Every turn is given about a world axis at the bone head, so a clip reads the same whatever the bone roll: the pose is
converted into the bone's local rest frame (B^-1 R B). Actions carry a fake user and are not stashed in the NLA, so
the .blend the pipeline saves stays in the neutral swim glide (run.py's clips step is not ported; the rigged FBX and
the Roblox upload are the next step, see export_rig.py and RESULT.md).

    name           frames  loop  the seal does
    A_Seal_Swim      72     yes   cruising: a lateral wave down the spine, the hind flippers sculling in time, the
                                  fore-flippers tucked and steering, the head steady
    A_Seal_Surface   48     yes   hanging at the surface: nose up, two slow breaths (the jaw opens), the flippers
                                  sculling to hold station
    A_Seal_Look      72     yes   the curious hold of a grey seal: the head swings left and right to watch, a slow
                                  roll, small nods, the fore-flippers fanning
    A_Seal_HaulOut   60     no    on to the rocks: the head lifts, the fore-flippers swing forward and plant, the
                                  chest is pulled up, the body comes up behind it and settles on the belly
    A_Seal_Flee      48     no    startled on land: head up, a coil, then the stampede: a hard hind-flipper push, the
                                  body lunging forward and dropping into the water nose first
"""
import math

import bpy
from mathutils import Matrix

FPS = 30


def bone_rot(pb, turns):
    """turns: [(world axis 'X' / 'Y' / 'Z', degrees), ...] about the bone head, in the bone's local rest frame."""
    B = pb.bone.matrix_local.to_3x3()
    R = Matrix.Identity(3)
    for axis, deg in turns:
        R = Matrix.Rotation(math.radians(deg), 3, axis) @ R
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = (B.inverted() @ R @ B).to_quaternion()


def key(rig, frame, pose, loc=None):
    for name, turns in pose.items():
        pb = rig.pose.bones[name]
        bone_rot(pb, turns)
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    if loc is not None:
        root = rig.pose.bones["Root"]
        root.location = loc
        root.keyframe_insert("location", frame=frame)


def fcurves_of(act):
    """Every fcurve of an action across Blender versions: 4.4+ keeps them in layers/strips/channelbags."""
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    out = []
    for layer in act.layers:
        for strip in layer.strips:
            bags = list(getattr(strip, "channelbags", []))
            if not bags:
                try:
                    bags = [strip.channelbag(s) for s in act.slots]
                except (AttributeError, TypeError):
                    bags = []
            for cb in bags:
                out.extend(cb.fcurves)
    return out


def make_action(rig, name, keys, ease='BEZIER'):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for frame, pose, loc in keys:
        key(rig, frame, pose, loc)
    for fc in fcurves_of(act):
        for kp in fc.keyframe_points:
            kp.interpolation = ease
    rig.animation_data.action = None
    return act


def reset(rig):
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()


def wave(p, amps):
    """A travelling wave: amps = [(bone, axis, amplitude, phase), ...] at phase p."""
    pose = {}
    for bone, axis, a, ph in amps:
        pose.setdefault(bone, []).append((axis, a * math.sin(p + ph)))
    return pose


# ---------------------------------------------------------------- the clips
def swim(rig):
    """Cruising: the lateral wave grows toward the tail, the hind flippers scull with the wave, the head holds."""
    keys = []
    for i in range(9):
        f = 1 + 9 * i
        p = 2.0 * math.pi * i / 8.0
        pose = wave(p, [
            ("Spine_1", "Z", 3.2, 0.00), ("Spine_1", "Y", 2.0, 0.30),
            ("Spine_2", "Z", 4.4, -0.55), ("Spine_2", "Y", 2.2, -0.25),
            ("Chest", "Z", 3.0, -1.10), ("Chest", "X", 1.4, -1.30),
            ("Neck", "Z", -4.2, -1.45), ("Neck", "X", 1.6, -1.60),
            ("Head", "Z", -2.2, -1.75),
            ("Tail", "Z", 7.5, -1.90),
            ("FlipperH_L_1", "Z", -14.0, -1.15), ("FlipperH_L_1", "X", 5.0, -0.65),
            ("FlipperH_R_1", "Z", -14.0, -1.15), ("FlipperH_R_1", "X", 5.0, -0.65),
            ("FlipperH_L_2", "Z", -16.0, -1.70), ("FlipperH_R_2", "Z", -16.0, -1.70),
            ("FlipperF_L_1", "Z", 5.0, -0.90), ("FlipperF_R_1", "Z", 5.0, -0.90),
            ("FlipperF_L_2", "Z", 6.0, -1.30), ("FlipperF_R_2", "Z", 6.0, -1.30),
        ])
        keys.append((f, pose, [0.0, 0.010 * math.cos(p), 0.0]))
    return make_action(rig, "A_Seal_Swim", keys)


def surface(rig):
    """Holding at the surface: nose up, two slow breaths (jaw, throat), the flippers sculling gently."""
    keys = []
    for i in range(13):
        f = 1 + 4 * i
        p = 2.0 * math.pi * i / 12.0
        s = math.sin(p)
        breath = max(0.0, math.sin(p * 2.0)) ** 2                 # two breaths per cycle
        pose = {
            "Spine_1": [("X", -1.0 + 1.2 * s)],
            "Spine_2": [("X", -1.5 + 1.0 * s)],
            "Chest": [("X", -2.5 + 1.5 * s)],
            "Neck": [("X", -10.0 - 2.5 * s)],
            "Head": [("X", -5.0 - 2.0 * s), ("Z", 1.5 * math.cos(p))],
            "Jaw": [("X", 8.0 * breath)],
            "Tail": [("X", 5.0 + 2.0 * s)],
            "FlipperF_L_1": [("Z", 3.0 * s), ("X", -6.0)], "FlipperF_R_1": [("Z", 3.0 * s), ("X", -6.0)],
            "FlipperF_L_2": [("Z", -5.0 * s)], "FlipperF_R_2": [("Z", -5.0 * s)],
            "FlipperH_L_1": [("X", -4.0 + 3.0 * s), ("Z", -3.0 * s)],
            "FlipperH_R_1": [("X", -4.0 + 3.0 * s), ("Z", -3.0 * s)],
            "FlipperH_L_2": [("X", -5.0 * s)], "FlipperH_R_2": [("X", -5.0 * s)],
        }
        keys.append((f, pose, [0.0, 0.0, 0.012 * s]))
    return make_action(rig, "A_Seal_Surface", keys)


def look(rig):
    """The curious hold: the head swings to port and starboard to watch, with a slow roll and small nods."""
    keys = []
    for i in range(13):
        f = 1 + 6 * i
        p = 2.0 * math.pi * i / 12.0
        turn = math.sin(p) * 26.0
        pose = {
            "Spine_1": [("Z", -turn * 0.10)],
            "Spine_2": [("Z", -turn * 0.10)],
            "Chest": [("Z", turn * 0.12), ("Y", turn * 0.05)],
            "Neck": [("Z", turn * 0.55), ("X", -6.0 + 2.0 * math.sin(2 * p))],
            "Head": [("Z", turn * 0.45), ("X", -3.0 + 2.5 * math.sin(2 * p)), ("Y", -turn * 0.06)],
            "Tail": [("Z", 4.0 * math.sin(p + 0.8))],
            "FlipperF_L_1": [("Z", 8.0 + 4.0 * math.sin(p))], "FlipperF_R_1": [("Z", -8.0 - 4.0 * math.sin(p))],
            "FlipperF_L_2": [("Z", -6.0 - 3.0 * math.sin(p))], "FlipperF_R_2": [("Z", 6.0 + 3.0 * math.sin(p))],
            "FlipperH_L_1": [("X", 3.0 * math.sin(p + 1.6))], "FlipperH_R_1": [("X", 3.0 * math.sin(p + 1.6))],
            "FlipperH_L_2": [("X", -4.0 * math.sin(p + 1.9))], "FlipperH_R_2": [("X", -4.0 * math.sin(p + 1.9))],
        }
        keys.append((f, pose, [0.0, 0.0, 0.006 * math.sin(p * 2.0)]))
    return make_action(rig, "A_Seal_Look", keys)


def haulout(rig):
    """On to the rocks: head up, the fore-flippers swing forward and plant, the chest is pulled up over them, the
    body follows, then it settles flat on the belly with the head up and the hind flippers trailing."""
    st = [
        (1, {"Neck": [("X", 6.0)], "Head": [("X", 4.0)], "Spine_1": [("X", 2.0)], "Spine_2": [("X", 2.0)]}, None),
        (10, {"Neck": [("X", -14.0)], "Head": [("X", -8.0)], "Chest": [("X", 6.0)], "Spine_2": [("X", 4.0)],
              "Spine_1": [("X", 3.0)],
              "FlipperF_L_1": [("Z", 34.0), ("X", 26.0)], "FlipperF_R_1": [("Z", -34.0), ("X", 26.0)],
              "FlipperF_L_2": [("Z", 10.0), ("X", 10.0)], "FlipperF_R_2": [("Z", -10.0), ("X", 10.0)],
              "FlipperH_L_1": [("X", -14.0)], "FlipperH_R_1": [("X", -14.0)],
              "FlipperH_L_2": [("X", -10.0)], "FlipperH_R_2": [("X", -10.0)]}, [0.0, 0.0, 0.03]),
        (22, {"Neck": [("X", -20.0)], "Head": [("X", -10.0)], "Chest": [("X", 10.0)], "Spine_2": [("X", 8.0)],
              "Spine_1": [("X", 6.0)], "Tail": [("X", 10.0)],
              "FlipperF_L_1": [("Z", 40.0), ("X", 44.0)], "FlipperF_R_1": [("Z", -40.0), ("X", 44.0)],
              "FlipperF_L_2": [("Z", 6.0), ("X", 20.0)], "FlipperF_R_2": [("Z", -6.0), ("X", 20.0)],
              "FlipperH_L_1": [("X", -20.0)], "FlipperH_R_1": [("X", -20.0)],
              "FlipperH_L_2": [("X", -14.0)], "FlipperH_R_2": [("X", -14.0)]}, [0.0, 0.0, 0.10]),
        (34, {"Neck": [("X", -16.0)], "Head": [("X", -6.0)], "Chest": [("X", 8.0)], "Spine_2": [("X", 6.0)],
              "Spine_1": [("X", 4.0)], "Tail": [("X", 8.0)],
              "FlipperF_L_1": [("Z", 30.0), ("X", 52.0)], "FlipperF_R_1": [("Z", -30.0), ("X", 52.0)],
              "FlipperF_L_2": [("Z", -6.0), ("X", 16.0)], "FlipperF_R_2": [("Z", 6.0), ("X", 16.0)],
              "FlipperH_L_1": [("X", -12.0)], "FlipperH_R_1": [("X", -12.0)],
              "FlipperH_L_2": [("X", -8.0)], "FlipperH_R_2": [("X", -8.0)]}, [0.0, -0.04, 0.12]),
        (48, {"Neck": [("X", -10.0)], "Head": [("X", -4.0)], "Chest": [("X", 4.0)], "Spine_2": [("X", 3.0)],
              "Spine_1": [("X", 2.0)], "Tail": [("X", 6.0)],
              "FlipperF_L_1": [("Z", 26.0), ("X", 48.0)], "FlipperF_R_1": [("Z", -26.0), ("X", 48.0)],
              "FlipperF_L_2": [("Z", -4.0), ("X", 10.0)], "FlipperF_R_2": [("Z", 4.0), ("X", 10.0)],
              "FlipperH_L_1": [("X", -6.0)], "FlipperH_R_1": [("X", -6.0)],
              "FlipperH_L_2": [("X", -4.0)], "FlipperH_R_2": [("X", -4.0)]}, [0.0, -0.06, 0.10]),
        (60, {"Neck": [("X", -8.0)], "Head": [("X", -3.0)], "Chest": [("X", 3.0)], "Spine_2": [("X", 2.0)],
              "Spine_1": [("X", 1.0)], "Tail": [("X", 5.0)],
              "FlipperF_L_1": [("Z", 24.0), ("X", 46.0)], "FlipperF_R_1": [("Z", -24.0), ("X", 46.0)],
              "FlipperF_L_2": [("Z", -2.0), ("X", 8.0)], "FlipperF_R_2": [("Z", 2.0), ("X", 8.0)],
              "FlipperH_L_1": [("X", -4.0)], "FlipperH_R_1": [("X", -4.0)],
              "FlipperH_L_2": [("X", -3.0)], "FlipperH_R_2": [("X", -3.0)]}, [0.0, -0.06, 0.09]),
    ]
    return make_action(rig, "A_Seal_HaulOut", [(f, p, loc) for f, p, loc in st])


def flee(rig):
    """Startled: head up and back, a coil, then the stampede into the water: a hard hind-flipper push, the body
    lunging forward, the nose dropping as it dives."""
    st = [
        (1, {"Neck": [("X", -14.0)], "Head": [("X", -6.0)], "Chest": [("X", 4.0)],
             "FlipperF_L_1": [("Z", 22.0), ("X", 40.0)], "FlipperF_R_1": [("Z", -22.0), ("X", 40.0)]}, None),
        (8, {"Neck": [("X", -22.0)], "Head": [("X", -8.0)], "Spine_1": [("X", 4.0)], "Spine_2": [("X", 6.0)],
             "Chest": [("X", 10.0)], "Tail": [("X", 14.0)],
             "FlipperF_L_1": [("Z", 20.0), ("X", 36.0)], "FlipperF_R_1": [("Z", -20.0), ("X", 36.0)],
             "FlipperF_L_2": [("X", 12.0)], "FlipperF_R_2": [("X", 12.0)],
             "FlipperH_L_1": [("X", -22.0)], "FlipperH_R_1": [("X", -22.0)]}, [0.0, 0.02, 0.02]),
        (16, {"Neck": [("X", -6.0)], "Head": [("X", 2.0)], "Spine_1": [("X", -6.0)], "Spine_2": [("X", -4.0)],
              "Chest": [("X", -4.0)], "Tail": [("X", -12.0)],
              "FlipperF_L_1": [("Z", 30.0), ("X", 10.0)], "FlipperF_R_1": [("Z", -30.0), ("X", 10.0)],
              "FlipperH_L_1": [("X", 16.0), ("Z", -10.0)], "FlipperH_R_1": [("X", 16.0), ("Z", -10.0)],
              "FlipperH_L_2": [("X", 18.0), ("Z", -14.0)], "FlipperH_R_2": [("X", 18.0), ("Z", -14.0)]},
         [0.0, -0.09, 0.04]),
        (26, {"Neck": [("X", 4.0)], "Head": [("X", 6.0)], "Spine_1": [("X", -8.0)], "Spine_2": [("X", -6.0)],
              "Chest": [("X", -6.0)], "Tail": [("X", -14.0)],
              "FlipperF_L_1": [("Z", 44.0), ("X", -6.0)], "FlipperF_R_1": [("Z", -44.0), ("X", -6.0)],
              "FlipperH_L_1": [("X", -12.0), ("Z", 8.0)], "FlipperH_R_1": [("X", -12.0), ("Z", 8.0)],
              "FlipperH_L_2": [("X", -16.0), ("Z", 12.0)], "FlipperH_R_2": [("X", -16.0), ("Z", 12.0)]},
         [0.0, -0.18, 0.02]),
        (38, {"Neck": [("X", 10.0)], "Head": [("X", 8.0)], "Spine_1": [("X", -10.0)], "Spine_2": [("X", -8.0)],
              "Chest": [("X", -8.0)], "Tail": [("X", -16.0)],
              "FlipperF_L_1": [("Z", 30.0), ("X", -14.0)], "FlipperF_R_1": [("Z", -30.0), ("X", -14.0)],
              "FlipperH_L_1": [("X", 12.0), ("Z", -6.0)], "FlipperH_R_1": [("X", 12.0), ("Z", -6.0)],
              "FlipperH_L_2": [("X", 16.0), ("Z", -8.0)], "FlipperH_R_2": [("X", 16.0), ("Z", -8.0)]},
         [0.0, -0.26, -0.02]),
        (48, {"Neck": [("X", 6.0)], "Head": [("X", 4.0)], "Spine_1": [("X", -6.0)], "Spine_2": [("X", -5.0)],
              "Chest": [("X", -4.0)], "Tail": [("X", -10.0)],
              "FlipperF_L_1": [("Z", 16.0), ("X", -10.0)], "FlipperF_R_1": [("Z", -16.0), ("X", -10.0)],
              "FlipperH_L_1": [("X", 6.0)], "FlipperH_R_1": [("X", 6.0)],
              "FlipperH_L_2": [("X", 8.0)], "FlipperH_R_2": [("X", 8.0)]}, [0.0, -0.30, -0.04]),
    ]
    return make_action(rig, "A_Seal_Flee", [(f, p, loc) for f, p, loc in st])


def build_all(rig):
    reset(rig)
    acts = [swim(rig), surface(rig), look(rig), haulout(rig), flee(rig)]
    reset(rig)
    rig.animation_data.action = None
    for a in acts:
        print("[clips] %-20s %d frames, %d fcurves" % (a.name, int(a.frame_range[1]), len(fcurves_of(a))))
    return acts
