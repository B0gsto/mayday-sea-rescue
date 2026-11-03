"""Retarget mocap (CMU BVH / Quaternius UAL GLB) onto an R15 blocky rig: rotations only, R15 limb lengths kept.
Reads clips.json, writes out/<Name>.json (30 fps keys: per-joint quaternion [w,x,y,z] relative to the Motor6D rest,
plus a Root offset in studs). Build the .rbxm after with mocap.luau (see README.md).
  Blender MCP: P = "<repo>/art/source/anim/mocap/retarget.py"
               exec(open(P).read(), {"__file__": P, "__name__": "__main__", "MOCAP_ARGS": ["WorkerHammer"]})
  CLI:         blender --background --python retarget.py -- [Name ...]   (no names = every clip)
  --scan Name  prints arm elevation / elbow bend every 0.5 s of the whole take (to pick one-shot frames).
Source files are untrusted data: only imported, never executed.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
FPS = 30
LEG = 2.1924  # R15 blocky hip joint -> sole (art/source/anim/_ik.luau: thigh 0.9207 + shin 1.0097 + ankle 0.262)
SMOOTH = 0.8  # gaussian sigma in 30 fps frames: kills mocap jitter, keeps the hits
XFADE = 6  # loop cross-fade, frames (0.2 s)
EASE = 10  # one-shot ease in/out to rest, frames
HAND_DAMP = 0.5  # CMU wrists are noisy; blocky hands read better half-strength
QA = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))).to_quaternion()  # Blender Z-up -> Roblox Y-up (proper rotation)
DOWN = Vector((0, -1, 0))
UP = Vector((0, 1, 0))

# R15 joint -> (part, parent part). Standard R15 Motor6D C0/C1 are pure translations, so a joint's Transform is
# parent_world_rot^-1 * part_world_rot with every part at identity in the rest pose (character faces -Z).
JOINTS = {
    "Root": ("LowerTorso", None),
    "Waist": ("UpperTorso", "LowerTorso"),
    "Neck": ("Head", "UpperTorso"),
}
for _s in ("Left", "Right"):
    JOINTS.update({
        _s + "Shoulder": (_s + "UpperArm", "UpperTorso"),
        _s + "Elbow": (_s + "LowerArm", _s + "UpperArm"),
        _s + "Wrist": (_s + "Hand", _s + "LowerArm"),
        _s + "Hip": (_s + "UpperLeg", "LowerTorso"),
        _s + "Knee": (_s + "LowerLeg", _s + "UpperLeg"),
        _s + "Ankle": (_s + "Foot", _s + "LowerLeg"),
    })
UPPER = ["Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist"]
# parts whose source rest differs from the R15 rest (T/A-pose arms, splayed legs) get direction-matched onto R15 -Y;
# torso, head and feet stand upright in both rests, so they map 1:1
ARC = {s + p for s in ("Left", "Right") for p in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg")}


def skeleton(kind):
    """R15 part -> (source bone, child bone that fixes its direction); plus toe bones for the floor."""
    if kind == "cmu":
        m = {"LowerTorso": ("Hips", None), "UpperTorso": ("Spine1", None), "Head": ("Head", None)}
        limbs = {"UpperArm": ("Arm", "ForeArm"), "LowerArm": ("ForeArm", "Hand"), "Hand": ("Hand", "FingerBase"),
                 "UpperLeg": ("UpLeg", "Leg"), "LowerLeg": ("Leg", "Foot"), "Foot": ("Foot", None), "Toe": ("ToeBase", None)}
        name = lambda s, b: s + b
    elif kind == "ual":
        m = {"LowerTorso": ("pelvis", None), "UpperTorso": ("spine_03", None), "Head": ("Head", None)}
        limbs = {"UpperArm": ("upperarm", "lowerarm"), "LowerArm": ("lowerarm", "hand"), "Hand": ("hand", "middle_01"),
                 "UpperLeg": ("thigh", "calf"), "LowerLeg": ("calf", "foot"), "Foot": ("foot", None), "Toe": ("ball", None)}
        name = lambda s, b: b + "_" + s[0].lower()
    else:
        raise ValueError("unknown skeleton " + kind)
    for s in ("Left", "Right"):
        for p, (b, c) in limbs.items():
            m[s + p] = (name(s, b), c and name(s, c))
    return m


def load(clip):
    """Import the take into an empty scene; returns (armature, blender frame of source frame 0, frame count)."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    path = os.path.join(REPO, "build", "mocap", "src", clip["file"])
    assert os.path.isfile(path), path
    sc = bpy.context.scene
    if path.endswith(".bvh"):
        bpy.ops.import_anim.bvh(filepath=path, frame_start=1, use_fps_scale=False, update_scene_fps=False,
                                update_scene_duration=True)
        arm = next(o for o in sc.objects if o.type == "ARMATURE")
        return arm, 1, sc.frame_end
    sc.render.fps = clip["fps"]  # glTF keys are seconds; the importer converts with the scene fps
    bpy.ops.import_scene.gltf(filepath=path)
    arm = next(o for o in sc.objects if o.type == "ARMATURE")
    act = bpy.data.actions.get(clip["take"]) or next(a for a in bpy.data.actions if a.name.startswith(clip["take"]))
    ad = arm.animation_data or arm.animation_data_create()
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    ad.action = act
    if getattr(act, "slots", None) and hasattr(ad, "action_slot"):
        ad.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    return arm, int(round(f0)), int(round(f1 - f0)) + 1


def yaw_to_minus_x(left):
    """Rotation about +Y that turns the horizontal 'left' vector onto -X (R15 left when facing -Z)."""
    ang = math.atan2(-left.z, left.x)  # rotating about +Y by t adds t to this angle
    return Quaternion((0, 1, 0), math.pi - ang)


def sample(arm, sk, f0, frames):
    """Per source frame: Roblox-space world rotation delta (pose * rest^-1) per part, and joint positions."""
    sc = bpy.context.scene
    ro = arm.matrix_world.decompose()[1]
    mw = arm.matrix_world
    bones, pb = arm.data.bones, arm.pose.bones
    rest_inv = {p: bones[b].matrix_local.to_3x3().normalized().to_quaternion().inverted() for p, (b, _) in sk.items()}
    pos = lambda v: QA @ (mw @ v)
    rest = {p: pos(bones[b].head_local) for p, (b, _) in sk.items()}
    rest.update({p + ">": pos(bones[c].head_local) for p, (b, c) in sk.items() if c})
    out = []
    for f in frames:
        sc.frame_set(f0 + f)
        fr = {}
        for p, (b, _) in sk.items():
            d = ro @ pb[b].matrix.to_3x3().normalized().to_quaternion() @ rest_inv[p] @ ro.inverted()
            fr[p] = QA @ d @ QA.inverted()
            fr[p + "@"] = pos(pb[b].head)
        out.append(fr)
    return rest, out


def tilt(w, k):
    """Scale a part's world tilt (its up axis away from vertical) toward 0 by k (1 = fully upright)."""
    return Quaternion().slerp((w @ UP).rotation_difference(UP), k) @ w


def euler(v):
    """[x, y, z] degrees -> quaternion, same order as Roblox CFrame.Angles(x, y, z)."""
    x, y, z = (math.radians(c) for c in v)
    return Quaternion((1, 0, 0), x) @ Quaternion((0, 1, 0), y) @ Quaternion((0, 0, 1), z)


def solve(rest, frames, ym, clip):
    """Source frames -> R15 joint quats + hips position (yaw-aligned Roblox space)."""
    up = clip.get("upright", 0)
    up = up if isinstance(up, dict) else {p: up for p in ("LowerTorso", "UpperTorso", "Head")}
    yr = yaw_to_minus_x(rest["LeftUpperLeg"] - rest["RightUpperLeg"])
    cal = {p: (DOWN.rotation_difference(yr @ (rest[p + ">"] - rest[p])) if p in ARC else Quaternion()) for p in JOINTS_PARTS}
    yri = yr.inverted()
    res = []
    for fr in frames:
        world = {p: ym @ fr[p] @ yri @ cal[p] for p in JOINTS_PARTS}
        if clip.get("upper"):  # layered over a walk/idle whose LowerTorso stays upright: keep the chest's own lean
            world["LowerTorso"] = Quaternion()
        for p, k in up.items():  # arms keep their world direction, so the hands stay at the work
            world[p] = tilt(world[p], k)
        q = {}
        for j, (p, par) in JOINTS.items():
            q[j] = world[p] if par is None else world[par].inverted() @ world[p]
            if j.endswith("Wrist"):
                q[j] = Quaternion().slerp(q[j], HAND_DAMP)
        res.append({"q": q, "hips": ym @ fr["LowerTorso@"], "toe": min(fr["LeftToe@"].y, fr["RightToe@"].y), "w": world})
    return res


JOINTS_PARTS = [p for p, _ in JOINTS.values()]


def qavg(qs, ws):
    ref = qs[len(qs) // 2]
    acc = [0.0, 0.0, 0.0, 0.0]
    for q, w in zip(qs, ws):
        s = w if q.dot(ref) >= 0 else -w
        acc = [acc[0] + s * q.w, acc[1] + s * q.x, acc[2] + s * q.y, acc[3] + s * q.z]
    q = Quaternion(acc)
    q.normalize()
    return q


def resample(seq, step, smooth=SMOOTH):
    """Gaussian-filtered resample of per-source-frame data to 30 fps (step = source frames per 30 fps frame)."""
    sig = smooth * step
    out = []
    n = int((len(seq) - 1) / step + 1e-6)
    for i in range(n + 1):
        c = i * step
        ks = range(max(0, math.ceil(c - 2.5 * sig)), min(len(seq) - 1, math.floor(c + 2.5 * sig)) + 1)
        ws = [math.exp(-0.5 * ((k - c) / sig) ** 2) for k in ks]
        tw = sum(ws)
        out.append({
            "q": {j: qavg([seq[k]["q"][j] for k in ks], ws) for j in JOINTS},
            "hips": sum((seq[k]["hips"] * w for k, w in zip(ks, ws)), Vector()) / tw,
        })
    return out


def qang(a, b):
    return 2 * math.acos(min(1.0, abs(a.dot(b))))


def pdist(a, b, joints):
    return sum(qang(a["q"][j], b["q"][j]) for j in joints)


def best_cycle(fr, lo, hi, lmin, lmax, joints):
    """Start s and length L in [lo, hi] whose ends match best (pose + velocity) per unit of motion in the cycle."""
    step = [pdist(fr[i], fr[i + 1], joints) for i in range(len(fr) - 1)]
    pre = [0.0]
    for d in step:
        pre.append(pre[-1] + d)
    best = None
    for s in range(max(lo, XFADE + 1), hi):
        for L in range(lmin, lmax + 1):
            e = s + L
            if e > hi or e + 1 >= len(fr):
                break
            match = pdist(fr[s], fr[e], joints) + 0.5 * (pdist(fr[s - 1], fr[e - 1], joints) + pdist(fr[s + 1], fr[e + 1], joints))
            cost = match / max(pre[e] - pre[s], 1e-3)
            if best is None or cost < best[0]:
                best = (cost, s, L)
    assert best, "no cycle fits the frame range"
    return best[1], best[2]


def stylize(fr, clip, ia, ib):
    """Per-clip knobs on the 30 fps local joint quats: amp scales each joint's motion around its mean over the used
    range, offset pre-rotates a joint in its parent frame, pose replaces it (degrees, CFrame.Angles order)."""
    for j, k in clip.get("amp", {}).items():
        m = qavg([f["q"][j] for f in fr[ia:ib + 1]], [1.0] * (ib - ia + 1))
        for f in fr:
            d = m.inverted() @ f["q"][j]
            d = d if d.w >= 0 else -d
            f["q"][j] = m @ Quaternion(d.axis, d.angle * k)
    for j, v in clip.get("offset", {}).items():
        e = euler(v)
        for f in fr:
            f["q"][j] = e @ f["q"][j]
    for j, v in clip.get("pose", {}).items():
        e = euler(v)
        for f in fr:
            f["q"][j] = e.copy()


def sway(q, u, clip):
    """Add seamless sine layers: [joint, x, y, z, cycles per loop, phase] at loop fraction u."""
    q = dict(q)
    for j, x, y, z, n, ph in clip.get("sway", []):
        s = math.sin(2 * math.pi * (n * u + ph))
        q[j] = euler((x * s, y * s, z * s)) @ q[j]
    return q


def smoothstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def retarget(clip):
    sk = skeleton(clip["skel"])
    arm, f0, nsrc = load(clip)
    a, b = clip["frames"]
    wrap = clip.get("wrap")  # native take whose last frame is not a copy of the first: sample b as frame a again
    b = min(b, nsrc - (0 if wrap else 1))
    pad = int(clip["fps"])  # 1 s of context either side for smoothing and the cross-fade
    first = 1 if clip["skel"] == "cmu" else 0  # cgspeed CMU frame 0 is a floating T-pose: never sample it
    a = max(a, first)
    lo, hi = max(first, a - pad), (b if wrap else min(nsrc - 1, b + pad))
    rest, raw = sample(arm, sk, f0, [a + (f - a) % (b - a) if wrap else f for f in range(lo, hi + 1)])
    left = sum(((fr["LeftUpperLeg@"] - fr["RightUpperLeg@"]) for fr in raw[a - lo:b - lo + 1]), Vector())
    ym = Quaternion((0, 1, 0), math.radians(clip.get("yaw", 0))) @ yaw_to_minus_x(left)
    src = solve(rest, raw, ym, clip)
    step = clip["fps"] / FPS
    fr = resample(src, step, clip.get("smooth", SMOOTH))
    ia, ib = round((a - lo) / step), min(len(fr) - 1, round((b - lo) / step))
    stylize(fr, clip, ia, ib)
    joints = UPPER if clip.get("upper") else list(JOINTS)
    scale = LEG / (rest["LowerTorso"].y - min(rest["LeftToe"].y, rest["RightToe"].y))
    floor = min(s["toe"] for s in src)
    if clip["loop"]:
        lmin, lmax = round(clip["cycle"][0] * FPS), round(clip["cycle"][1] * FPS)
        native = clip.get("native")  # the take already loops over its frames: keep it whole, only snap the seam
        s, L = (ia, ib - ia) if native else best_cycle(fr, ia, ib, lmin, lmax, joints)
        h0, h1 = fr[s]["hips"], fr[s + L]["hips"]
        trend = lambda k: fr[k]["hips"] - (h1 - h0) * ((k - s) / L)  # in place: remove the drift over the cycle
        keys = []
        for i in range(L + 1):
            q, h = dict(fr[s + i]["q"]), trend(s + i)
            w = float(i == L) if native else smoothstep((i - (L - XFADE)) / XFADE)
            if w > 0:
                q = {j: q[j].slerp(fr[s + i - L]["q"][j], w) for j in q}
                h = h.lerp(trend(s + i - L), w)
            keys.append((q, h, 1.0))
        keys = keys + keys[1:] * (clip.get("repeat", 1) - 1)  # still takes: a longer loop for slow sway layers
        rise = scale * (h1.y - h0.y)
        used = (lo + round(s * step), lo + round((s + L) * step))
    else:
        n = ib - ia
        keys = []
        for i in range(n + 1):
            w = smoothstep(i / EASE) * smoothstep((n - i) / EASE)
            keys.append(({j: Quaternion().slerp(q, w) for j, q in fr[ia + i]["q"].items()}, fr[ia + i]["hips"], w))
        rise, used = 0.0, (a, b)
    mean = sum((h for _, h, _ in keys), Vector()) / len(keys)
    bob = clip.get("bob", 1.0)
    out = []
    for i, (q, h, w) in enumerate(keys):
        off = (h - mean) * scale * bob * w
        if clip.get("root") == "abs":  # sit/crouch: real hip height above the floor
            off.y = scale * (h.y - floor) - LEG + clip.get("root_y", 0.0)
        q = sway(q, i / (len(keys) - 1), clip) if clip["loop"] else q
        out.append({"t": i / FPS, "q": {j: q[j] for j in joints}, "root": None if clip.get("upper") else off})
    out = reduce_keys(out)
    return {
        "name": clip["name"], "file": clip["file"], "take": clip.get("take"), "frames": list(used), "fps": FPS,
        "loop": clip["loop"], "priority": clip["priority"], "length": round(out[-1]["t"], 4),
        "rise": round(rise, 3), "keys": [encode(k) for k in out],
    }


def reduce_keys(keys, tol=math.radians(0.6), ptol=0.01):
    """Drop keys that linear interpolation between their kept neighbours already reproduces."""
    kept = [keys[0]]
    for i in range(1, len(keys) - 1):
        a, b, k = kept[-1], keys[i + 1], keys[i]
        u = (k["t"] - a["t"]) / (b["t"] - a["t"])
        ok = all(qang(a["q"][j].slerp(b["q"][j], u), k["q"][j]) < tol for j in k["q"])
        if ok and k["root"] is not None:
            ok = (a["root"].lerp(b["root"], u) - k["root"]).length < ptol
        if not ok:
            kept.append(k)
    kept.append(keys[-1])
    return kept


def encode(k):
    q = {}
    for j, v in k["q"].items():
        v = v if v.w >= 0 else -v
        assert all(math.isfinite(c) for c in v) and abs(v.magnitude - 1) < 1e-4, (j, v)
        q[j] = [round(c, 6) for c in (v.w, v.x, v.y, v.z)]  # 6 places: XYZ euler stays exact near gimbal lock (arm overhead)
    e = {"t": round(k["t"], 4), "q": q}
    if k["root"] is not None:
        e["root"] = [round(c, 3) for c in k["root"]]
    return e


def scan(clip):
    """Print arm elevation (deg from hanging) and elbow bend every 0.5 s of the whole take."""
    sk = skeleton(clip["skel"])
    arm, f0, nsrc = load(clip)
    stepf = max(1, int(clip["fps"] / 2))
    rest, raw = sample(arm, sk, f0, range(0, nsrc, stepf))
    left = sum(((fr["LeftUpperLeg@"] - fr["RightUpperLeg@"]) for fr in raw), Vector())
    for i, s in enumerate(solve(rest, raw, yaw_to_minus_x(left), {})):
        row = []
        for side in ("Right", "Left"):
            d = s["w"][side + "UpperArm"] @ DOWN
            row.append("%s elev %3d fwd %4.1f elbow %3d" % (side[0], math.degrees(DOWN.angle(d)), -d.z,
                                                          math.degrees(qang(s["q"][side + "Elbow"], Quaternion()))))
        print("f %5d t %5.1f  %s" % (i * stepf, i * stepf / clip["fps"], " | ".join(row)))


def main(args):
    cfg = json.load(open(os.path.join(HERE, "clips.json")))
    clips = {c["name"]: c for c in cfg["clips"]}
    if args[:1] == ["--scan"]:
        return scan(clips[args[1]])
    os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
    for name in args or list(clips):
        res = retarget(clips[name])
        with open(os.path.join(HERE, "out", name + ".json"), "w") as f:
            json.dump(res, f, separators=(",", ":"))
        print("%s: %.2f s, %d keys, frames %s, rise %.2f" % (name, res["length"], len(res["keys"]), res["frames"], res["rise"]))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(globals().get("MOCAP_ARGS", [])))
