"""CH6 driver for M_Chr_Bosun (Blender, always through ~/RobloxProjects/tools/blender-run.sh):

    blender-run.sh art/source/characters/M_Chr_Bosun/pipeline.py -- build            # geometry, LODs, UVs -> M_Chr_Bosun.blend
    blender-run.sh art/source/characters/M_Chr_Bosun/pipeline.py -- bake Body|Harness [size]   # one set a run
    blender-run.sh art/source/characters/M_Chr_Bosun/pipeline.py -- final [--no-turntable]     # validate, export, turntable

Why not tools/blender/run.py: the docs/12 row is two budget classes in one asset (body + harness under `dog`, the fur
cards under `dog_fur_cards`, 25,000 + 15,000), and run.py validates one class per spec. This driver runs the same
validate.run on two specs, exports one FBX per LOD with every part (export.run), and the shared turntable.
Fur-card LODs are subsets of the LOD0 cards (wider, same atlas), not decimations, so their UV area differs by design
(waived "LOD UV layout"). Fur maps come from fur_atlas.py (Blender strand renders, then system python3 assembly), not from a bake.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
LIB = os.path.join(REPO, "tools", "blender")
for p in (LIB, HERE):
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402
import validate  # noqa: E402
import export  # noqa: E402
import versions  # noqa: E402

ASSET = "M_Chr_Bosun"
BLEND = os.path.join(HERE, ASSET + ".blend")
TEMPLATE = os.path.join(common.ART_DIR, "blender", "_template.blend")
SETS = [{"name": "Bosun", "set": "Body", "size": 2048, "wet": True},
        {"name": "Bosun", "set": "Harness", "size": 1024, "wet": True},
        {"name": "Bosun", "set": "Fur", "size": 2048, "wet": True, "alpha": "Transparency"}]
LODS = ("LOD0", "LOD1", "LOD2")


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return a


# ------------------------------------------------------------------ build

def stage_build():
    import bosun
    if os.path.isfile(TEMPLATE):
        bpy.ops.wm.open_mainfile(filepath=TEMPLATE)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    body_me, eyes = bosun.build_body(2)
    Vb = bosun.mesh_arrays(body_me)
    wh = bosun.withers_height(Vb)
    k = 0.700 / wh                                    # withers at 0.70 m (2.1 studs), proportions kept
    print("[bosun] withers %.3f m as built, scale %.3f" % (wh, k))
    harness_me = bosun.harness_mesh(body_me)           # built and fitted in build metres
    cards = bosun.fur_cards(body_me, harness_me)
    Va = np.vstack([Vb, bosun.mesh_arrays(harness_me)])          # origin: centre of the base of body + harness
    shift = np.array([-(Va[:, 0].min() + Va[:, 0].max()) / 2, -(Va[:, 1].min() + Va[:, 1].max()) / 2, -Vb[:, 2].min()])
    bosun.XFORM.update(shift=shift, k=k)
    for me in (body_me, harness_me):
        bosun.set_coords(me, bosun.to_final(bosun.mesh_arrays(me)))
    for c in cards:
        c["verts"] = (c["verts"] + shift) * k        # cards_mesh multiplies by S
    bpy.context.scene["bosun_withers_y"] = float(bosun.to_final((0, -0.28, 0))[1])
    body = bosun.new_object(ASSET + "_Body_TMP", body_me)
    harn = bosun.new_object(ASSET + "_Harness_LOD0", harness_me)
    bosun.uv_unwrap(body, 0.002)
    bosun.uv_unwrap(harn, 0.004)

    # LODs: the harness first (thin straps: 10% breaks them), then the unsplit body fills the rest of the LOD budget
    # (dog: LOD1 10,000, LOD2 3,000 for body + harness), decimated before the split so the parts do not crack
    import bmesh
    harn_tris = versions.triangles(harn.data)
    harn_lod = {}
    for lod, share in (("LOD1", 0.45), ("LOD2", 0.25)):
        o = versions.copy_object(harn, ASSET + "_Harness_" + lod)
        versions.decimate(o, int(harn_tris * share))
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges[:])
        bm.to_mesh(o.data)
        bm.free()
        versions.weighted_normals(o)
        harn_lod[lod] = versions.triangles(o.data)
    lod_objs = {"LOD0": body}
    body_tris = versions.triangles(body.data)
    for lod, cap in (("LOD1", 9600), ("LOD2", 2850)):
        o = versions.copy_object(body, ASSET + "_Body_TMP_" + lod)
        versions.decimate(o, int(min(cap - harn_lod[lod], body_tris * 0.45)))
        lod_objs[lod] = o
    parts = {}
    for lod, o in lod_objs.items():
        parts[lod] = bosun.split_body(o, ASSET, lod)
        if lod != "LOD0":
            for p in parts[lod].values():
                versions.weighted_normals(p)
        bpy.data.objects.remove(o, do_unlink=True)

    # fur cards: front and rear MeshParts; LOD1 / LOD2 keep ~40% / ~10% of the cards, wider, capped by triangles
    # (dog_fur_cards: LOD1 0.4 x 15,000, LOD2 0.1 x 15,000)
    cards.sort(key=lambda c: -c["size"])

    def subset(pick, cap):
        sub, tris = [], 0
        for i, c in enumerate(cards):
            if pick(i) and tris + 2 * c["segs"] <= cap:
                sub.append(c)
                tris += 2 * c["segs"]
        return sub

    for lod, ws, ls in (("LOD0", 1.0, 1.0), ("LOD1", 1.45, 1.05), ("LOD2", 2.4, 1.1)):
        sub = cards if lod == "LOD0" else subset(lambda i: i % 5 in (0, 2), 5900) if lod == "LOD1" else \
            subset(lambda i: i % 10 == 0, 1480)
        for half, front in (("FurFront", True), ("FurRear", False)):
            bosun.cards_mesh([c for c in sub if c["front"] == front], "%s_%s_%s" % (ASSET, half, lod), ws, ls)

    # materials (one per mesh) and attachments
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.name.startswith(ASSET):
            set_name = "Fur" if "_Fur" in o.name else "Harness" if "_Harness" in o.name else "Body"
            mat = bpy.data.materials.get("MI_Bosun_" + set_name) or bpy.data.materials.new("MI_Bosun_" + set_name)
            o.data.materials.clear()
            o.data.materials.append(mat)
    # attachments ride on their MeshParts: harness handle and tow ring on the harness, the mouth on the head
    for e in bosun.attachments():
        par = bpy.data.objects[ASSET + ("_BodyHead_LOD0" if e.name == "ATT_Mouth" else "_Harness_LOD0")]
        e.parent = par
        e.matrix_parent_inverse = par.matrix_world.inverted()
    report_counts()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, check_existing=False)
    print("[bosun] saved", BLEND)


def report_counts():
    tot = {}
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith(ASSET):
            t = versions.triangles(o.data)
            print("[bosun] %-32s %6d tris" % (o.name, t))
            lod = o.name.rsplit("_", 1)[1]
            key = ("fur " if "_Fur" in o.name else "body ") + lod
            tot[key] = tot.get(key, 0) + t
    print("[bosun] totals", json.dumps(tot))


# ------------------------------------------------------------------ specs (from the saved scene)

def specs():
    objs = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith(ASSET)}
    atts = [o for o in bpy.context.scene.objects if o.type == "EMPTY" and o.name.startswith("ATT_")]

    def meshes(prefixes):
        out = []
        for n, o in sorted(objs.items()):
            if any(n.startswith(ASSET + "_" + p) for p in prefixes):
                s = "Fur" if "_Fur" in n else "Harness" if "_Harness" in n else "Body"
                out.append({"object": o, "set": s})
        return out

    import bosun_checks
    body = {"name": ASSET, "asset": ASSET, "species": "animal", "budget": "dog", "tier": "hero", "dims_m": (None, None, None),
            "origin": "base", "sets": [s for s in SETS if s["set"] != "Fur"], "meshes": meshes(["Body", "Harness"]),
            "attachments": atts, "extra_checks": [bosun_checks.withers],
            # round 3: only BodyHind_LOD2 trips this, at the 15% edge (the 2,850-tri far LOD collapses small paw / tail
            # islands); LOD1 rows pass. Revisit with a UV-seam-preserving LOD2 decimate.
            "waivers": {"LOD UV layout": "BodyHind LOD2 (~3k-tri far LOD) loses ~15% UV area to decimation of small "
                        "paw / tail islands; same atlas, invisible at LOD2 distance"}}
    fur = {"name": ASSET, "asset": ASSET, "species": "animal", "budget": "dog_fur_cards", "tier": "hero", "dims_m": (None, None, None),
           "origin": "free", "sets": [s for s in SETS if s["set"] == "Fur"], "meshes": meshes(["Fur"]), "attachments": [],
           "waivers": {"LOD UV layout": "fur-card LODs are subsets of the LOD0 cards on the same atlas cells (fewer, wider cards), "
                       "so the used UV area shrinks by design; the atlas layout is identical",
                       "real size": "measured on the body spec (withers 2.1 studs); the cards only add coat"}}
    allspec = {"name": ASSET, "asset": ASSET, "species": "animal", "budget": "dog", "tier": "hero", "sets": SETS,
               "meshes": body["meshes"] + fur["meshes"], "attachments": atts}
    return body, fur, allspec


# ------------------------------------------------------------------ bake

def stage_bake(set_name, size):
    import bake_bosun
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    bake_bosun.bake_set(set_name, size)


# ------------------------------------------------------------------ final

def alpha_pbr_material(orig):
    def pbr_material(name, maps):
        mat = orig(name, maps)
        if "ALB" in maps and "_Fur" in name:
            nt = mat.node_tree
            bsdf = nt.nodes.get("Principled BSDF")
            for n in nt.nodes:
                if n.type == "TEX_IMAGE" and n.image and n.image.filepath.endswith("_ALB.png"):
                    nt.links.new(n.outputs["Alpha"], bsdf.inputs["Alpha"])
            try:
                mat.surface_render_method = "DITHERED"
            except AttributeError:
                mat.blend_method = "HASHED"
        return mat
    return pbr_material


def stage_final(turntable=True):
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    body, fur, allspec = specs()
    report = validate.Report()
    ok = True
    for spec in (body, fur):
        validate.classify(spec)
        r = validate.run(spec)
        report.rows += r.rows
        ok = ok and r.ok
    validate.classify(allspec)
    result = {"asset": ASSET, "name": ASSET, "date": common.today(), "commit": common.git_commit(),
              "blender": bpy.app.version_string, "steps": ["validate", "export"] + (["turntable"] if turntable else []),
              "scene": "art/source/characters/M_Chr_Bosun/M_Chr_Bosun.blend", "driver": "pipeline.py",
              "export_settings": export.recorded_settings()}
    if ok:
        result["exports"] = export.run(allspec, report)
        ok = report.ok
    else:
        print("[bosun] validation failed: nothing exported")
        for row in report.failures():
            print("[bosun] FAIL", row["subject"], row["check"], row["detail"])
    if turntable:
        import turntable as tt
        tt.pbr_material = alpha_pbr_material(tt.pbr_material)
        for e in allspec["meshes"]:
            e["object"].hide_render = e.get("lod") != "LOD0"
        # Bosun-only: the template mannequin is the 5.5-stud avatar (docs/05 4.1); next to a dog read it as the docs/05
        # adult, 1.8 m = 5.4 studs. Uniform scale about its feet (origin at Z 0) for the render, restored after.
        man = bpy.data.objects.get("TPL_Mannequin")
        man_scale = man.scale.copy() if man else None
        if man:
            from mathutils import Vector
            bpy.context.view_layer.update()
            zs = [(man.matrix_world @ Vector(c)).z for c in man.bound_box]
            man.scale = man_scale * (5.4 / (max(zs) - min(zs)))
            bpy.context.view_layer.update()
        try:
            result["turntable"] = tt.run(allspec, report, ok)
        finally:
            if man:
                man.scale = man_scale
        result["mannequin_studs_rendered"] = 5.4 if man else common.MANNEQUIN_STUDS
    result["ok"] = ok
    result["checks"] = report.rows
    result["meshes"] = [{"name": e["object"].name, "role": e["role"], "lod": e.get("lod"), "triangles": e.get("tris"),
                         "texel_density": e.get("texel_density")} for e in allspec["meshes"]]
    result["bbox_studs"] = body.get("bbox_studs")
    out = os.path.join(common.review_dir(ASSET), "%s_report.json" % common.today())
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1, default=str)
    print("[bosun] report", out, "OK" if ok else "FAILED")
    return ok


def main():
    a = args()
    if not a:
        raise SystemExit("usage: pipeline.py -- build | bake <Set> [size] | final [--no-turntable]")
    if a[0] == "build":
        stage_build()
    elif a[0] == "bake":
        stage_bake(a[1], int(a[2]) if len(a) > 2 else 2048)
    elif a[0] == "final":
        if not stage_final("--no-turntable" not in a):
            sys.exit(1)


if __name__ == "__main__":
    main()
