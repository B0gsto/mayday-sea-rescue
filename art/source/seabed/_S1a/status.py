"""Writes art/status/S1a.csv from assets/manifest.json (system python3)."""
import csv
import json

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
m = json.load(open(G + "assets/manifest.json"))
ids = {}
for v in m.values():
    if v.get("source", "").startswith(("assets/fbx/M_Sea_", "assets/textures/M_Sea_")):
        ids[v["name"]] = (v.get("assetId"), v.get("moderation"))


def mod(prefixes):
    states = {s for n, (_, s) in ids.items() if n.startswith(prefixes)}
    return "all Approved" if states == {"Approved"} else "moderation: " + ",".join(sorted(str(s) for s in states))


LIC = ("CC0 1.0 (https://polyhaven.com/license): Poly Haven rough_wood, rust_coarse_01, green_metal_rust, "
       "damp_beach_sand_02 (2k scans, graded + zoned); reference links art/reference/<Asset>/dims.md (not shipped)")
AI = "assisted (geometry, texture zoning and lettering written as code by Claude on real CC0 scans; no AI images)"
SRC = "BL: art/source/seabed/<Asset>/build.py + art/source/seabed/_S1a (wreckgeo.py, maketex.py, render_sheet.py) (S1a Opus 2026-10-18)"
rows = [
    ("M_Sea_Morwenna", "P0", "M_Sea_Morwenna", ("M_Sea_Morwenna", "T_Morwenna_"),
     "LOD0 26,836 tris in 14 MeshParts (max 5,020) + 27 instanced frame clones (9,936 tris, instances.json); LOD1 9,190, "
     "LOD2 1,649 (LODs made in build.py: chain LOD2 is a swept strap, link rings cannot collapse to 10%%). bbox 12.9 x 28.9 x "
     "5.9 m (Y 28 m +3%%; X free: collapsed port side, fallen foremast, chain on the sand). 4 sets at 1024, wet-only "
     "(underwater): Wood (tiling 2 m), Metal (trim strips: iron / verdigris bronze / bell lettering), Silt (tiling 4 m), Kelp "
     "(RGBA cards: DoubleSided + AlphaMode Transparency). ATT_Bell, ATT_Hatch, ATT_Anchor, ATT_Windlass, ATT_ChainEnd, ATT_Stem; "
     "_COL 8 boxes. Integration: drop greybox roll, sink ~0.3 m so the silt skirt meets terrain, clone RibA/B/C per "
     "M_Sea_Morwenna.instances.json. LOD1 %s, LOD2 %s"),
    ("M_Sea_AdmiraltyAnchor", "P0", "M_Sea_AdmiraltyAnchor", ("M_Sea_AdmiraltyAnchor", "T_AdmiraltyAnchor_"),
     "LOD0 2,208 tris (1 MeshPart), LOD1 1,104, LOD2 551; 3.35 x 4.0 x 1.93 m: 1841 Admiralty pattern iron-stocked merchant "
     "bower, shank 3.2 m. SIZE: WorldConfig 15 x 9 studs (5 x 3 m) is a ship-of-the-line anchor; recommend 12 x 10 studs. "
     "1 set T_AdmiraltyAnchor_Iron (tiling 1 m, wet-only). ATT_Anchor (ring), ATT_AnchorCrown; _COL 4 boxes. LOD1 %s, LOD2 %s"),
    ("M_Sea_Bell", "P0", "M_Sea_Bell", ("M_Sea_Bell",),
     "LOD0 1,192 tris, LOD1 595 (small_prop: no LOD2); 0.26 x 0.26 x 0.35 m; shares T_Morwenna_Metal (verdigris bronze strip, "
     "'MORWENNA 1902' raised capitals on the waist band facing -Y, iron clapper). ATT_Bell at the crown. LOD1 %s, LOD2 %s"),
]
with open(G + "art/status/S1a.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"])
    for asset, pri, lod0, prefixes, notes in rows:
        aid = ids.get(lod0, ("", ""))[0] or ""
        l1 = (ids.get(asset + "_LOD1") or ("n/a",))[0]
        l2 = (ids.get(asset + "_LOD2") or ("n/a",))[0]
        status = "built+validated+exported+review renders (uw + neutral)+uploaded (%s); Studio pass and AD review pending" % mod(prefixes)
        w.writerow([asset, pri, status, aid, SRC.replace("<Asset>", asset), LIC, AI, "", notes % (l1, l2)])
print(open(G + "art/status/S1a.csv").read()[:600])
