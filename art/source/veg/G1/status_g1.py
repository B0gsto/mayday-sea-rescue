#!/usr/bin/env python3
"""Writes art/status/G1.csv from the validate reports and assets/manifest.json. usage: status_g1.py "<status>" "<extra note>" """
import csv, glob, json, os, sys
GAME = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "vegkit.py")).read()
V = eval(src[src.index("VARIANTS = {") + 11: src.index("}\n", src.index("VARIANTS = {")) + 1])
man = json.load(open(os.path.join(GAME, "assets/manifest.json"))).values()
import hashlib
def cur(e):  # the manifest entry for the file's current bytes (older uploads of the same source stay in the manifest)
    p = os.path.join(GAME, e["source"])
    return os.path.exists(p) and hashlib.sha256(open(p, "rb").read()).hexdigest().startswith(e.get("sha") or "-")
def ids(stem):
    return {e["source"].rsplit("/", 1)[-1]: (e.get("assetId"), e.get("moderation")) for e in man if stem in e.get("source", "") and cur(e)}
status, extra = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
atlas = ids("/M_Veg_FoliageLand/")
rows = [["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"]]
rows.append(["T_FoliageLand_Main (atlas)", "P0", status, " ".join("%s=%s" % (k[:-4].replace("T_FoliageLand_Main_", ""), v[0]) for k, v in sorted(atlas.items())),
             "procedural: art/source/veg/G1/atlas.py (numpy/Pillow, drawn from plant structure)", "owned", "none", "",
             "2048 ship / 4096 master; ALB with alpha + NOR (OpenGL) + RGH + MET + _Wet; check_textures 31/31 PASS; moderation " +
             ",".join(sorted(set(v[1] or "?" for v in atlas.values())))])
for a, (kind, seed, dims, rowt, note) in V.items():
    r = json.load(open(sorted(glob.glob(os.path.join(GAME, "assets/review", a, "*_report.json")))[-1]))
    t = {m["lod"]: m["triangles"] for m in r["meshes"]}
    mi = ids("/%s/" % a)
    lod = {k.rsplit("_", 1)[-1][:-4]: v for k, v in mi.items() if k.endswith(".fbx")}
    pri = "P0" if kind in ("turf", "marram", "gorse", "ling", "bell", "heathmix", "thrift") else "P1 (task extra; not a docs/12 row)"
    rows.append([a, pri, status, (lod.get("LOD0") or ("",))[0] or "",
                 "BL procedural: art/source/veg/G1/vegkit.py (+ art/source/veg/%s/build.py)" % a, "owned", "none", "",
                 "%s; %s x %s x %s m; tris %d/%d/%d (row cap %d); validate %s (LOD UV layout waived: card LODs); LOD1 %s LOD2 %s; moderation %s. %s"
                 % (note, dims[0], dims[1], dims[2], t["LOD0"], t["LOD1"], t["LOD2"], rowt, "PASS" if r["ok"] else "FAIL",
                    (lod.get("LOD1") or ("",))[0], (lod.get("LOD2") or ("",))[0], ",".join(sorted(set(v[1] or "?" for v in lod.values()))), extra)])
csv.writer(open(os.path.join(GAME, "art/status/G1.csv"), "w", newline="")).writerows(rows)
print(len(rows) - 1, "rows")
