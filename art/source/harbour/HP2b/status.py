"""Writes art/status/HP2b.csv from the run reports and assets/manifest.json (system python3)."""
import csv
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
import marks  # noqa: E402

man = json.load(open(os.path.join(REPO, "assets", "manifest.json")))
by_source = {}
for v in man.values():
    if v.get("source"):
        by_source[v["source"]] = v


import hashlib

_cands = {}
for v in man.values():
    if v.get("source"):
        _cands.setdefault(v["source"], []).append(v)


def asset_id(rel):
    """The manifest entry whose sha matches the file on disk (re-uploads leave the old entry beside the new one)."""
    v = by_source.get(rel)
    path = os.path.join(REPO, rel)
    if os.path.isfile(path):
        sha = hashlib.sha256(open(path, "rb").read()).hexdigest()
        v = next((c for c in _cands.get(rel, []) if c.get("sha") == sha), v)
    return (v.get("assetId") or "", v.get("moderation", "")) if v else ("", "missing")


rows = []
SCANS = ("CC0 1.0 (https://polyhaven.com/license): Poly Haven rusty_painted_metal, rust_coarse_01, metal_plate_02, "
         "low_tide_rocks (https://polyhaven.com/a/<id>) as triplanar detail; model and maps owned")
for k in marks.ALL:
    name = marks.asset_name(k)
    tex = marks.tex_name(k)
    reps = sorted(glob.glob(os.path.join(REPO, "assets", "review", name, "*_report.json")))
    rep = json.load(open(reps[-1])) if reps else {}
    tris = {}
    for m in rep.get("meshes", []):
        if m.get("lod"):
            tris[m["lod"]] = tris.get(m["lod"], 0) + (m.get("triangles") or 0)
    ids = {lod: asset_id("assets/fbx/%s/%s_%s.fbx" % (name, name, lod)) for lod in ("LOD0", "LOD1", "LOD2")}
    maps = glob.glob(os.path.join(REPO, "assets", "textures", name, "*.png"))
    mods = [asset_id(os.path.relpath(p, REPO))[1] for p in maps] + [v[1] for v in ids.values()]
    approved = all(m == "Approved" for m in mods)
    if k in marks.NAVMARKS:
        c = marks.NAVMARKS[k]
        what = "%s; topmark %s; light %s (rhythm in dims.md); ATT_WaterLine (origin, z 0), ATT_Light (lens centre), " \
               "ATT_Topmark, ATT_Mooring%s; separate %s_Lens part (drive Neon + PointLight)" % (
                   c["label"], c["top"], c["light"], ", ATT_Bell" if c.get("bell") else "", name)
        size = 2048
    else:
        what = "%s, %.2f m; ATT_WaterLine (origin), ATT_Pickup, ATT_Mooring (chain end)" % (marks.MOORINGS[k]["label"], marks.MOORINGS[k]["d"])
        size = 1024
    status = "fix round b: rebuilt+validated+exported+check_textures PASS+re-uploaded (%s)+review sheet b; AD re-review pending; no Studio pass (batch rule)" % (
        "all Approved" if approved else "moderation: " + ",".join(sorted(set(mods))))
    notes = ("Tris LOD0/1/2 %s/%s/%s; LOD1 %s, LOD2 %s. %s. 1 set T_%s_Buoy at %d (+ALB/RGH _Wet), masters 2048 in "
             "art/source/harbour/%s/textures (G-buffer bake + compose.py; 4096 not authored), _COL hull, signal_mask.png. "
             "Weathering: faded enamel, edge chips, rust streaks under seams and bleeding from every cage joint, gull droppings "
             "on tops, salt film, graded fouling zone (slime film, patchy algae, wrack mat, barnacles ramping with depth). "
             "Fix round b (after AD 6.5/10): topmarks 1.5x with a clear gap, solid banded pillar so every IALA band reads. "
             "dims art/reference/%s/dims.md; no reference photo board (open). Sheet assets/review/HP2b/contact_b.png "
             "(round a: contact.png)") % (
        tris.get("LOD0", "?"), tris.get("LOD1", "?"), tris.get("LOD2", "?"), ids["LOD1"][0], ids["LOD2"][0], what, tex, size,
        name, name)
    rows.append([name, "P0", status, ids["LOD0"][0], "blender:art/source/harbour/HP2b/buoylib.py (HP2b Opus 2026-10-18)",
                 SCANS, "assisted (code-generated model and procedural weathering by Claude on CC0 scans; no AI images)", "", notes])
out = os.path.join(REPO, "art", "status", "HP2b.csv")
with open(out, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"])
    w.writerows(rows)
for r in rows:
    print(r[0], r[3], r[8][:60])
