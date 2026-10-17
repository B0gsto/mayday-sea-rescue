"""B02: shared atlas layouts (docs/12 2.x): cell rects at MASTER 4096, shelf-packed by tools/blender/texgen.atlas_rects.
python3 art/source/materials/atlases.py  -> assets/materials/atlases.json. Owning batches bake into these cells (tune sizes there)."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path.insert(0, os.path.join(GAME, "tools/blender"))
import texgen  # noqa: E402
import common  # noqa: E402

K = 1024
ATLASES = {
    "HarbourProp": {"note": "docs/12 2.6: all small harbour props share it, 2 sets", "sets": {
        "Metal": [("M_Hbr_Ladder", K, 2 * K), ("M_Hbr_Bollard", K, K), ("M_Hbr_LifebuoyStation", K, K), ("M_Hbr_LobsterPot_Frame", K, K),
                  ("M_Hbr_Cleat", K // 2, K // 2), ("M_Hbr_MooringChain", K // 2, K), ("M_Hbr_Shackles", K // 2, K // 2),
                  ("M_Hbr_FishBox_Handles", K // 2, K // 2), ("Spare", 2 * K, K)],
        "RopePlastic": [("M_Hbr_Rope_Trim", 2 * K, K // 2), ("M_Hbr_NetPile_Cards", 2 * K, K), ("M_Hbr_Fender", K, K),
                        ("M_Hbr_MooringBuoy", K, K), ("M_Hbr_FishBox", K, K), ("M_Hbr_LobsterPot_Net", K, K),
                        ("M_Hbr_Lifebuoy_Ring", K, K // 2), ("M_Hbr_PickupBuoy", K // 2, K // 2), ("Spare", 2 * K, K // 2)]}},
    "Street": {"note": "docs/12 2.7 road furniture", "sets": {
        "Main": [("M_Road_StreetLamp", K, 2 * K), ("M_Road_Bench", K, K), ("M_Road_Bin", K, K), ("M_Road_Bollard", K // 2, K),
                 ("M_Road_BeachFlags", K, K), ("Spare", 2 * K, K)]}},
    "FoliageLand": {"note": "docs/12 2.8 alpha cards (AlphaMode Transparency)", "sets": {
        "Main": [("M_Veg_Grass_Turf", K, K), ("M_Veg_Grass_Marram", K, 2 * K), ("M_Veg_Gorse", 2 * K, K), ("M_Veg_Heather", K, K),
                 ("M_Veg_SeaThrift", K // 2, K // 2), ("Spare", K, K)]}},
    "FoliageMarine": {"note": "docs/12 2.8 marine alpha cards", "sets": {
        "Main": [("M_Veg_Kelp", K, 2 * K), ("M_Veg_Wrack", 2 * K, K), ("M_Veg_Eelgrass", K, K), ("Spare", K, K)]}},
}

out = {"master": common.MASTER, "export_cap": common.EXPORT_CAP, "uv": "u0, v0, u1, v1 (v up, Blender)", "atlases": {}}
for name, a in ATLASES.items():
    sets = {s: texgen.atlas_rects(cells, common.MASTER) for s, cells in a["sets"].items()}
    out["atlases"][name] = {"note": a["note"], "sets": {s: {k: [round(x, 5) for x in r] for k, r in v.items()} for s, v in sets.items()},
                            "textures": ["T_%s_%s_{ALB,NOR,RGH,MET}" % (name, s) for s in sets]}
os.makedirs(os.path.join(GAME, "assets/materials"), exist_ok=True)
json.dump(out, open(os.path.join(GAME, "assets/materials/atlases.json"), "w"), indent=1)
print({n: {s: len(c) for s, c in a["sets"].items()} for n, a in ATLASES.items()})
