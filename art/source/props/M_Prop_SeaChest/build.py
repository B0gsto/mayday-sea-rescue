"""M_Prop_SeaChest: the daily-reward sea chest (StreakCrate), low-poly faceted (Bosun LP style).

Two meshes: Base (node at the ground centre, the crate's `at` pivot) and Lid (node at the hinge line,
Roblox (0, 3.1, -1.8), so rotating the Lid node about its X opens it like StreakCrate.open does).
Sizes follow StreakCrate.build at scale 1: body 5.6 x 3.1 x 3.6, lid 6.0 x 0.55 x 3.95, flat lid top for the
pip strip. Front (lock, hasp) faces Roblox +Z like the code-built crate. ATT_LidHinge marks the hinge.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/props/M_Prop_SeaChest/build.py --out-root build/prod/M_Prop_SeaChest \
      --steps build,lod,validate,export,turntable
"""
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "characters", "_LP"))
import lpkit as K  # noqa: E402

ASSET = "M_Prop_SeaChest"
PREFIX = "M_Prop_SeaChest_"
W, H, DP = 5.6, 3.1, 3.6
HINGE = (0.0, H, -DP / 2)                 # Roblox; Blender (0, -1.8, 3.1)

ZONES = {
    "wood": dict(top="#A8754A", bottom="#7C522E", rough=0.8, signal=True),
    "wood2": dict(top="#966640", bottom="#6E4727", rough=0.82, signal=True),
    "woodDark": dict(top="#644128", bottom="#3E2717", rough=0.85, signal=True),
    "iron": dict(top="#50555C", bottom="#2E3135", rough=0.55),
    "brass": dict(top="#F0CF7A", bottom="#DDB35C", rough=0.32, metal=1.0, signal=True),
    "rope": dict(top="#D2B47F", bottom="#A88A58", rough=0.92, signal=True),
}


def base(p):
    p.add(K.box((5.5, 3.5, 3.0), (0, 0, 1.55), bevel=0.05), "woodDark")
    p.add(K.box((5.76, 3.76, 0.28), (0, 0, 0.14), bevel=0.05), "woodDark")
    for i in range(4):
        z = 0.28 + 0.705 * (i + 0.5)
        zone = "wood" if i % 2 == 0 else "wood2"
        for y in (-1.75, 1.75):
            p.add(K.box((5.56, 0.1, 0.66), (0, y, z), bevel=0.035), zone)
        for x in (-2.75, 2.75):
            p.add(K.box((0.1, 3.42, 0.66), (x, 0, z), bevel=0.035), "wood2" if zone == "wood" else "wood")
    for x in (-1.57, 1.57):
        for y in (-1.83, 1.83):
            p.add(K.box((0.36, 0.07, 2.9), (x, y, 1.6), bevel=0.02), "iron")
            for z in (0.75, 2.45):
                p.add(K.box((0.09, 0.04, 0.09), (x, y + 0.045 * (1 if y > 0 else -1), z), bevel=0.0), "brass")
    for x in (-2.61, 2.61):
        for y in (-1.61, 1.61):
            for z in (0.47, 2.91):
                p.add(K.box((0.42, 0.42, 0.42), (x, y, z), bevel=0.04), "brass")
    p.add(K.box((0.7, 0.06, 0.8), (0, 1.87, 2.5), bevel=0.02), "brass")
    p.add(K.box((0.1, 0.03, 0.22), (0, 1.905, 2.38), bevel=0.0), "iron")
    for s in (-1, 1):            # rope beckets: two cleats and a sagging rope loop per short side
        x = 2.93 * s
        for y in (-1.1, 1.1):
            p.add(K.box((0.22, 0.34, 0.3), (x, y, 2.0), bevel=0.04), "woodDark")
            p.add(K.ball((0.26, 0.26, 0.26), (x + 0.1 * s, y, 1.98), u=6, v=4), "rope")
        pts = []
        for i in range(9):
            y = -1.1 + 2.2 * i / 8
            k = 1 - (y / 1.1) ** 2
            pts.append((x + (0.1 + 0.14 * k) * s, y, 1.98 - 0.5 * k))
        p.add(K.tube(pts, 0.075, sides=6), "rope")


def lid(p):
    p.add(K.box((5.96, 3.91, 0.42), (0, 0, 3.31), bevel=0.06), "woodDark")
    for i, y in enumerate((-1.3, 0.0, 1.3)):
        p.add(K.box((5.9, 1.24, 0.12), (0, y, 3.58), bevel=0.035), "wood" if i % 2 == 0 else "wood2")
    for x in (-1.57, 1.57):
        p.add(K.box((0.38, 3.99, 0.05), (x, 0, 3.645), bevel=0.015), "iron")
        for y in (-1.99, 1.99):
            p.add(K.box((0.38, 0.05, 0.5), (x, y, 3.38), bevel=0.015), "iron")
    for x in (-2.81, 2.81):
        for y in (-1.785, 1.785):
            p.add(K.box((0.42, 0.42, 0.42), (x, y, 3.46), bevel=0.04), "brass")
    p.add(K.box((0.46, 0.06, 0.46), (0, 2.0, 3.33), bevel=0.02), "brass")
    p.add(K.box((0.34, 0.05, 0.5), (0, 1.925, 2.95), bevel=0.015), "brass")
    # authored in the Base frame; the Lid node's rest frame is the hinge
    bmesh.ops.translate(p.bm, verts=p.bm.verts, vec=(0, DP / 2, -H))


def build():
    parts = [
        dict(node="Base", part="Base", index=1, cframe=K.cf((0, 0, 0)), roblox=((0, 0, 0), (0, 0, 0)), make=base),
        dict(node="Lid", part="Lid", index=2, cframe=K.cf(HINGE), roblox=(HINGE, (0, 0, 0)), make=lid),
    ]
    spec = K.build_asset(ASSET, PREFIX, "SeaChest", "Wood", ZONES, parts, HERE, origin="base", extra_mapping={
        "source": "src/client/World/StreakCrate.luau (scale 1; welcome crate = scale the model 1.35)",
        "front": "lock and hasp face Roblox +Z (as the code-built crate); the hinge is the back top edge",
        "open": "Lid.CFrame = base * CFrame.new(hinge) * CFrame.Angles(-angle, 0, 0), angle up to 108 deg",
        "lid_top_y": 3.65})
    att = bpy.data.objects.new("ATT_LidHinge", None)
    att.location = (0.0, -DP / 2, H)
    bpy.context.scene.collection.objects.link(att)
    spec["attachments"] = [att]
    return spec
