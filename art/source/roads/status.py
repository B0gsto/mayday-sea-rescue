"""R1a status rows -> art/status/R1a.csv (asset ids by content hash from assets/manifest.json; docs/12 1.3 columns).

    python3 art/source/roads/status.py
"""
import csv
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path.insert(0, HERE)
import texlib  # noqa: E402

MAN = json.load(open(os.path.join(GAME, "assets/manifest.json")))


def aid(rel, kind):
    sha = hashlib.sha256(open(os.path.join(GAME, rel), "rb").read()).hexdigest()
    e = MAN.get("%s:%s" % (kind, sha))
    return (e["assetId"], e.get("moderation", "?")) if e else ("", "not uploaded")


def tris(asset):
    rp = os.path.join(GAME, "assets/review", asset, "2026-10-18_report.json")
    out = {}
    try:
        txt = json.dumps(json.load(open(rp)))
        import re
        for lod in ("LOD0", "LOD1", "LOD2"):
            m = re.search(r"%s triangles[^0-9]*?(\d+) of" % lod, txt)
            out[lod] = m.group(1) if m else "?"
    except OSError:
        pass
    return out


def scans(ids):
    rows = []
    for pid in ids:
        m = texlib.fetch(pid)
        rows.append("%s (%s)" % (m["url"], ", ".join(m["authors"])))
    return "; ".join(rows)


LIC = texlib.LICENCE + "; procedural masks own work"
AI = "assisted (code-written geometry, maps composited by Claude from real CC0 scans; no AI images)"
ROWS = []
furn = {"M_Road_StreetLamp": "5.45 m painted column on a cast base shroud, 0.7 m outreach, LED lantern (Lens part); ATT_Light, ATT_Base",
        "M_Road_Bench": "1.84 m hardwood slats on cast-iron end frames + centre bearer, coach bolts; ATT_Seat, ATT_Base",
        "M_Road_Bin": "open-top fluted round litter bin, muted gold LITTER band, galvanised liner; ATT_Opening, ATT_Base",
        "M_Road_Bollard": "heritage cast-iron bollard 0.915 m, retroreflective band; ATT_Base"}
for a, note in furn.items():
    ids = {lod: aid("assets/fbx/%s/%s_%s.fbx" % (a, a, lod), "Model") for lod in ("LOD0", "LOD1", "LOD2")}
    t = tris(a)
    alb = aid("assets/textures/%s/T_Street_Main_ALB.png" % a, "Image")
    status = "built+validated (hand-made LODs)+exported+turntable+uploaded (%s)+review renders; no Studio pass (batch rule); AD review pending" % (
        "/".join(sorted({ids[l][1] for l in ids})))
    ROWS.append([a, "P0", status, ids["LOD0"][0],
                 "blender:art/source/roads/kit.py + streettex.py (R1a Opus 2026-10-18); scans " +
                 scans(["rusty_painted_metal", "fine_grained_wood", "metal_plate"]), LIC, AI, "",
                 "LOD1 %s, LOD2 %s. Tris LOD0/1/2 %s/%s/%s, _COL. %s. Street atlas T_Street_Main (set Main, 1024, +_Wet; ALB %s) in "
                 "B02's Street cells, trim regions street_layout.py. Sheet assets/review/R1a/contact.png. Reference photo board not "
                 "collected (dims.md only). Atlas ids listed once under Textures.M_Road_StreetLamp.Main: I1 adds Bench/Bin/Bollard "
                 "to AssetLoader.SHARED_SETS." % (ids["LOD1"][0], ids["LOD2"][0], t.get("LOD0"), t.get("LOD1"), t.get("LOD2"), note, alb[0])])
sets = ["Asphalt", "Cobbles", "Gravel", "Kerb", "AsphaltTile", "CobblesTile", "GravelTile", "KerbTile", "Markings"]
ids = {s: aid("assets/textures/M_Road_Ribbon/T_Road_%s_ALB.png" % s, "Image") for s in sets}
mods = sorted({ids[s][1] for s in sets})
ROWS.append(["M_Road_Ribbon (materials + decals)", "P0",
             "maps built+check_textures PASS+uploaded (%s)+review renders; ribbon mesh generator not built (I1 / R1 follow-up, INTEGRATION.md)" % "/".join(mods),
             ids["Asphalt"][0], "textures:art/source/roads/roadmats.py (R1a Opus 2026-10-18); scans " +
             scans(["asphalt_04", "clean_asphalt", "cobblestone_04", "gravel_road", "granite_tile"]), LIC, AI, "",
             "ALB ids: " + ", ".join("%s %s" % (s, ids[s][0]) for s in sets) + ". 9 sets x ALB/NOR/RGH/MET + _Wet at 1024 "
             "(masters 2048). Strips Asphalt/Cobbles 8x6 m, Gravel 8x3.33 m, Kerb 1.8x0.4 m profile; tiles for MaterialVariants "
             "(assets/materials/roads_variants.json); Markings RGBA decal atlas (UK lines, give-way, cat's eyes; sizes verify), "
             "AlphaMode Transparency via gen_asset_ids ALPHA_TRANSPARENCY_SETS. MaterialVariants not wired into "
             "MaterialService (B02 wire.py owns it)."])
out = os.path.join(GAME, "art/status/R1a.csv")
with open(out, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"])
    w.writerows(ROWS)
print(out)
for r in ROWS:
    print(r[0], r[3], r[2][:80])
