"""HP1: write art/status/HP1.csv from assets/manifest.json and the latest validate reports.  python3 status.py"""
import csv
import glob
import json

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
man = json.load(open(G + "assets/manifest.json"))
import hashlib  # noqa: E402
by_src = {}
for v in man.values():      # HP1b: re-uploads share a source; keep the entry whose sha matches the file on disk
    src = v.get("source")
    if src:
        try:
            cur = hashlib.sha256(open(G + src, "rb").read()).hexdigest()
        except OSError:
            cur = None
        if src not in by_src or v.get("sha") == cur:
            by_src[src] = v
NOTE = {
    "QuayKit_Straight": "HP1b: 3 m (9 studs) straight random-rubble Cornish granite quay wall (skyline-packed uncoursed blocks 0.15 to 1.15 m, pitch-faced pillow relief in geometry, 3 cm joints raked 6 cm deep to a lime-mortar face, continuous 9 cm/m batter), lighter weathered 0.6 x 0.3 m copings with a rounded arris, setts behind",
    "QuayKit_Corner": "HP1b: outer 90 degree corner in random rubble, long-and-short dressed quoins, corner coping stone; snaps A (-X) and B (+Y)",
    "QuayKit_Steps": "HP1b: 6 m random-rubble section, flight of 13 granite steps (0.3 m risers, 0.33 m treads with nosings, 1 m wide) built out against the face, down to -4 m; stepped _COL",
    "QuayKit_Head": "HP1b: pier roundhead for a 6 m pier (r 3 m), random-rubble drum (relief blocks on the curved battered face), radial copings; snaps to two Straights turned to face -X / +X",
    "QuayKit_Armour": "HP1b: 3 m breakwater rock armour section, 11 big angular quarried granite blocks (1.0 to 2.2 m, boxes chipped by random plane cuts, facets re-meshed with noise relief, crisp arrises) in 4 layers to 5 m out, crest ~1 m above the waterline; opaque own T_QuayKit_Armour set (4 height zones per facet: kelp film, wrack + barnacles, barnacle + tar lichen, dry lichened granite)",
    "QuayKit_LadderBay": "HP1b: random-rubble straight with a 0.7 m wide x 0.22 m deep ladder recess (rubble back, dressed reveals) (ATT_Ladder at the recess top = M_Hbr_Ladder ATT_Ladder_Mount)",
    "Pontoon_Straight6": "6 x 2.4 m, 0.5 m freeboard, composite boards (real gaps), galvanised edge channel, rubber D-fenders, 4 HDPE floats with weed/barnacles, 4 horn cleats",
    "Pontoon_Straight12": "12 x 2.4 m, as Straight6 with 8 floats and 6 cleats",
    "Pontoon_Corner": "2.4 x 2.4 m junction, snaps on all four sides",
    "Pontoon_Finger": "6 x 0.9 m finger, rubber tip, 4 cleats; snaps by ATT_Snap_Start to a Straight's ATT_Snap_Finger_*",
    "Pontoon_Gangway": "HP1b: 9 x 1.0 m hinged gangway, ribbed aluminium tread + slats, galvanised stringers and posts with rust streaks (own GwSteel strip), 64 mm handrail + 48 mm knee rail at 1.0 / 0.55 m, hinge pin and plate, two rollers; modelled level, rotate about ATT_Hinge",
    "Ladder": "galvanised ladder 0.45 m between flat-bar stiles, rungs 0.3 m, brackets every 1.2 m, grab hoops 1 m above the quay; HP1b rust-streak pass (tears from every bracket and the coping lip) + rust bleed, weed, barnacles below the waterline (height-mapped set)",
}
rows = []
for key, note in NOTE.items():
    a = "M_Hbr_" + key
    ids = {}
    for lod in ("LOD0", "LOD1", "LOD2"):
        e = by_src.get("assets/fbx/%s/%s_%s.fbx" % (a, a, lod))
        ids[lod] = (e or {}).get("assetId", "")
        ids[lod + "m"] = (e or {}).get("moderation", "")
    rep = json.load(open(sorted(glob.glob(G + "assets/review/%s/*_report.json" % a))[-1]))
    tris = {}
    for m in rep["meshes"]:
        if m.get("lod"):
            tris[m["lod"]] = tris.get(m["lod"], 0) + (m.get("triangles") or 0)
    parts = len([m for m in rep["meshes"] if m.get("lod") == "LOD0"])
    atts = [r["name"] for r in json.load(open(G + "assets/fbx/%s/%s.attachments.json" % (a, a)))["attachments"]]
    sets = {"QuayKit": ("own T_QuayKit_Armour (assets/textures/M_Hbr_QuayKit); MeshPart *_Wall = Armour" if key == "QuayKit_Armour" else "own T_QuayKit_Tide (u 0..0.75 granite, u 0.79..0.99 lime mortar, v = height: clustered barnacles thinning with height, wrack clumps, tar lichen) + T_QuayKit_Stone (assets/textures/M_Hbr_QuayKit) + B02 Cobbles; MeshParts *_Wall = Tide, *_Stone = Stone, *_Top = Cobbles"),
            "Pontoon": "own T_Pontoon_Kit strip atlas (assets/textures/M_Hbr_Pontoon; HP1b split the gangway-only Tread strip into Tread + GwSteel, the pontoon strips are unchanged)",
            "Ladder": "own T_Ladder_Steel (assets/textures/M_Hbr_Ladder)"}[key.split("_")[0]]
    allok = all(ids[l + "m"] == "Approved" for l in ("LOD0", "LOD1", "LOD2"))
    rows.append({
        "asset": a, "priority": "P0",
        "status": "built+validated+exported+turntable+uploaded (%s); maps check_textures PASS; contact sheet assets/review/HP1/contact_b.png (HP1b fix round); no Studio pass (batch rule); AD review pending"
                  % ("all Approved" if allok else "moderation: %s/%s/%s" % (ids["LOD0m"], ids["LOD1m"], ids["LOD2m"])),
        "assetId": ids["LOD0"],
        "source": "blender:art/source/harbour/%s/build.py -> art/source/harbour/_hp1/kit.py; maps art/source/harbour/_hp1/maketex.py (HP1 Opus 2026-10-18, HP1b fix round)" % a,
        "licence": "owned model + CC0 1.0 Poly Haven scans (granite_tile_02 Charlotte Baglioni; wood_floor_deck Dimitrios Savva; metal_plate, rusty_metal_02 Rob Tuytel; https://polyhaven.com/license) + B02 Cobbles (square_cobblestone, CC0)",
        "ai_used": "assisted (code-generated model and procedural zoning on real CC0 scans by Claude; no AI images)",
        "reviewer": "",
        "notes": "LOD1 %s, LOD2 %s. Tris %d / %d / %d (budget large_prop, row ceiling), %d MeshParts + _COL. %s. Sets: %s. Attachments: %s."
                 % (ids["LOD1"], ids["LOD2"], tris.get("LOD0", 0), tris.get("LOD1", 0), tris.get("LOD2", 0), parts, note, sets, " ".join(atts)),
    })
with open(G + "art/status/HP1.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)
for r in rows:
    print(r["asset"], r["assetId"], r["status"][:60])
