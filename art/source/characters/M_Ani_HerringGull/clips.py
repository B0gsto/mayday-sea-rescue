"""M_Ani_HerringGull clips (docs/12 2.10): glide, flap, land, stand, call, as Blender actions on RIG_HerringGull.

Every rotation is given as a world-axis turn about the bone head, so a clip reads the same whatever the bone roll:
the pose is converted into the bone's local rest frame (B^-1 R B). Actions are authored with use_fake_user, NOT
stashed in the NLA, so the .blend the pipeline saves stays in the rest glide pose. run.py's clips steps are not
ported (docs/12 1.1), so these are the Blender-side clips; Roblox upload is a later step (see RESULT.md).

    name        frames  loop  the bird does
    Glide        72     yes   long shallow glide: a slow wing settle, a small body bob, tail steering
    Flap         24     yes   cruise flapping: full down/up cycle, outer wing lagging the inner, body rising on the down stroke
    Land         45     no    comes in high, wings up and back, drops the legs, flares, feet forward, tail down
    Stand        60     yes   stands on the tucked legs: wings folded along the body, an idle look, a small weight shift
    Call         36     no    head up, bill to the sky, the gull's long call: head raised then thrown forward
"""
import math

import bpy
from mathutils import Matrix

FPS = 30


def bone_rot(pb, turns):
    """turns: [(world axis 'X'/'Y'/'Z', degrees), ...] applied about the bone head, in the bone's local rest frame."""
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
    root = rig.pose.bones["Root"]
    if loc is not None:
        root.location = loc
    root.keyframe_insert("location", frame=frame)


def fcurves_of(act):
    """Blender 4.4+ slotted actions moved fcurves under layers/strips/channelbags; 3.x kept act.fcurves."""
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    out = []
    for layer in act.layers:
        for strip in layer.strips:
            for cb in getattr(strip, "channelbags", []):
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


GLIDE_POSE = {                                      # the rest mesh is already the glide pose
    "Body": [("X", -3.0)],
    "Neck": [("X", 3.0)],
    "Head": [("X", 3.0)],
    "Wing_L_1": [("Y", -6.0), ("Z", -6.0)], "Wing_L_2": [("Y", 3.0), ("Z", -6.0)],
    "Wing_R_1": [("Y", 6.0), ("Z", 6.0)], "Wing_R_2": [("Y", -3.0), ("Z", 6.0)],
    "Tail": [("X", -2.0)],
}


def glide(rig):
    """Long shallow glide: the wings breathe a few degrees, the body bobs, the tail steers slowly."""
    keys = []
    for i in range(5):
        f = 1 + 18 * i
        p = 2.0 * math.pi * i / 4.0
        s = math.sin(p)
        pose = {
            "Body": [("X", -3.0 + 1.6 * s)],
            "Neck": [("X", 3.0 - 1.0 * s)],
            "Head": [("X", 3.0 - 1.4 * s)],
            "Wing_L_1": [("Y", -6.0 - 3.5 * s), ("Z", -6.0 + 1.5 * math.cos(p))],
            "Wing_L_2": [("Y", 3.0 + 4.5 * math.sin(p - 0.5)), ("Z", -6.0 + 2.0 * math.cos(p))],
            "Wing_R_1": [("Y", 6.0 + 3.5 * s), ("Z", 6.0 - 1.5 * math.cos(p))],
            "Wing_R_2": [("Y", -3.0 - 4.5 * math.sin(p - 0.5)), ("Z", 6.0 - 2.0 * math.cos(p))],
            "Tail": [("X", -2.0 + 4.0 * s)],
        }
        keys.append((f, pose, [0.0, 0.010 * s, 0.0]))
    return make_action(rig, "A_HerringGull_Glide", keys)


def flap(rig):
    """Cruise flapping: one full cycle in 24 frames at 30 fps; the hand lags the arm by about a quarter stroke."""
    keys = []
    for i in range(9):
        f = 1 + 3 * i
        p = 2.0 * math.pi * i / 8.0
        s = math.sin(p)
        pose = {
            "Body": [("X", -2.0 * s), ("Z", 0.0)],
            "Neck": [("X", 2.0 * s)],
            "Head": [("X", 1.5 * s)],
            "Wing_L_1": [("Y", -34.0 * s - 2.0), ("Z", -7.0)],
            "Wing_L_2": [("Y", -30.0 * math.sin(p - 0.55) + 4.0), ("Z", -7.0)],
            "Wing_R_1": [("Y", 34.0 * s + 2.0), ("Z", 7.0)],
            "Wing_R_2": [("Y", 30.0 * math.sin(p - 0.55) - 4.0), ("Z", 7.0)],
            "Tail": [("X", -3.0 - 3.0 * s)],
        }
        keys.append((f, pose, [0.0, 0.035 * s, 0.0]))
    return make_action(rig, "A_HerringGull_Flap", keys)


def land(rig):
    """Approach high, wings up and back, legs down, a flare, then the feet forward and the tail down."""
    st = [
        (1,  {"Wing_L_1": [("Y", -12.0)], "Wing_L_2": [("Y", -6.0)], "Body": [("X", -4.0)],
              "Wing_R_1": [("Y", 12.0)], "Wing_R_2": [("Y", 6.0)]}),
        (10, {"Wing_L_1": [("Y", -40.0), ("Z", -4.0)], "Wing_L_2": [("Y", -34.0)], "Body": [("X", -12.0)],
              "Neck": [("X", 6.0)], "Head": [("X", 8.0)], "Tail": [("X", -6.0)],
              "Leg_L_1": [("Y", 26.0)], "Leg_L_2": [("Y", 18.0)],
              "Leg_R_1": [("Y", -26.0)], "Leg_R_2": [("Y", -18.0)],
              "Wing_R_1": [("Y", 40.0), ("Z", 4.0)], "Wing_R_2": [("Y", 34.0)]}),
        (22, {"Wing_L_1": [("Y", -18.0), ("Z", -12.0)], "Wing_L_2": [("Y", -8.0), ("Z", -10.0)],
              "Body": [("X", 8.0)], "Neck": [("X", -4.0)], "Head": [("X", -6.0)], "Tail": [("X", 6.0)],
              "Leg_L_1": [("Y", 40.0)], "Leg_L_2": [("Y", 30.0)],
              "Leg_R_1": [("Y", -40.0)], "Leg_R_2": [("Y", -30.0)],
              "Wing_R_1": [("Y", 18.0), ("Z", 12.0)], "Wing_R_2": [("Y", 8.0), ("Z", 10.0)]}),
        (34, {"Wing_L_1": [("Y", 6.0), ("Z", -14.0)], "Wing_L_2": [("Y", 14.0), ("Z", -12.0)],
              "Body": [("X", 14.0)], "Neck": [("X", -8.0)], "Head": [("X", -10.0)], "Tail": [("X", 10.0)],
              "Leg_L_1": [("Y", 46.0)], "Leg_L_2": [("Y", 34.0)],
              "Leg_R_1": [("Y", -46.0)], "Leg_R_2": [("Y", -34.0)],
              "Wing_R_1": [("Y", -6.0), ("Z", 14.0)], "Wing_R_2": [("Y", -14.0), ("Z", 12.0)]}),
        (45, {"Wing_L_1": [("Y", -4.0), ("Z", -8.0)], "Wing_L_2": [("Y", -2.0), ("Z", -6.0)],
              "Body": [("X", 4.0)], "Tail": [("X", 4.0)],
              "Leg_L_1": [("Y", 44.0)], "Leg_L_2": [("Y", 32.0)],
              "Leg_R_1": [("Y", -44.0)], "Leg_R_2": [("Y", -32.0)],
              "Wing_R_1": [("Y", 4.0), ("Z", 8.0)], "Wing_R_2": [("Y", 2.0), ("Z", 6.0)]}),
    ]
    return make_action(rig, "A_HerringGull_Land", [(f, p, None) for f, p in st])


def stand(rig):
    """On the legs: the wings fold back along the body, the body comes upright, a slow weight shift and a look."""
    folded = {
        "Wing_L_1": [("Y", -8.0), ("Z", -78.0)], "Wing_L_2": [("Y", 4.0), ("Z", -120.0)],
        "Wing_R_1": [("Y", 8.0), ("Z", 78.0)], "Wing_R_2": [("Y", -4.0), ("Z", 120.0)],
        "Leg_L_1": [("Y", 46.0)], "Leg_L_2": [("Y", 30.0)],
        "Leg_R_1": [("Y", -46.0)], "Leg_R_2": [("Y", -30.0)],
        "Body": [("X", 16.0)], "Neck": [("X", -12.0)], "Head": [("X", -8.0)], "Tail": [("X", 12.0)],
    }
    keys = []
    for i in range(5):
        f = 1 + 15 * i
        p = 2.0 * math.pi * i / 4.0
        s, c = math.sin(p), math.cos(p)
        pose = {k: list(v) for k, v in folded.items()}
        pose["Body"] = [("X", 16.0 + 1.5 * s), ("Y", 1.5 * c)]
        pose["Head"] = [("X", -8.0 - 2.0 * s), ("Z", 6.0 * c)]
        pose["Neck"] = [("X", -12.0 + 1.0 * s)]
        pose["Tail"] = [("X", 12.0 - 2.0 * s)]
        pose["Wing_L_2"] = [("Y", 4.0), ("Z", -120.0 + 2.5 * s)]
        pose["Wing_R_2"] = [("Y", -4.0), ("Z", 120.0 - 2.5 * s)]
        keys.append((f, pose, [0.0, 0.0, 0.004 * (1.0 - s)]))
    return make_action(rig, "A_HerringGull_Stand", keys)


def call(rig):
    """The long call: head down, then thrown up with the bill open to the sky, tail cocked."""
    st = [
        (1,  {"Head": [("X", -2.0)], "Neck": [("X", -2.0)], "Body": [("X", 2.0)], "Tail": [("X", 4.0)]}),
        (8,  {"Head": [("X", 14.0)], "Neck": [("X", 10.0)], "Body": [("X", 8.0)], "Tail": [("X", 10.0)],
              "Leg_L_1": [("Y", 10.0)], "Leg_R_1": [("Y", -10.0)]}),
        (16, {"Head": [("X", -46.0)], "Neck": [("X", -26.0)], "Body": [("X", 6.0)], "Tail": [("X", 12.0)],
              "Wing_L_1": [("Y", -10.0), ("Z", -8.0)], "Wing_R_1": [("Y", 10.0), ("Z", 8.0)],
              "Leg_L_1": [("Y", 12.0)], "Leg_R_1": [("Y", -12.0)]}),
        (26, {"Head": [("X", -40.0)], "Neck": [("X", -22.0)], "Body": [("X", 5.0)], "Tail": [("X", 8.0)],
              "Wing_L_1": [("Y", -6.0), ("Z", -6.0)], "Wing_R_1": [("Y", 6.0), ("Z", 6.0)]}),
        (36, {"Head": [("X", -18.0)], "Neck": [("X", -8.0)], "Body": [("X", 3.0)], "Tail": [("X", 5.0)]}),
    ]
    return make_action(rig, "A_HerringGull_Call", [(f, p, None) for f, p in st])


def build_all(rig):
    reset(rig)
    acts = [glide(rig), flap(rig), land(rig), stand(rig), call(rig)]
    reset(rig)
    rig.animation_data.action = None
    for a in acts:
        print("[clips] %-22s %d frames, %d fcurves" % (a.name, int(a.frame_range[1]), len(fcurves_of(a))))
    return acts
