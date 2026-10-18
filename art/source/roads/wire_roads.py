"""I1b-3: add the R1a road MaterialVariants (assets/materials/roads_variants.json) to the Rojo MaterialService and point
the terrain road slots at them (art/source/roads/INTEGRATION.md section 6). Idempotent; art/source/materials/wire.py
(B02) calls it after writing the model, so a B02 re-wire keeps them.

python3 art/source/roads/wire_roads.py
  Asphalt -> RoadAsphaltWorn, Cobblestone (the quayside setts) -> RoadHarbourCobbles, Pavement -> RoadGravelTrack;
  RoadKerbGranite for the kerb Parts (src/server/World/Street.luau). Each with a <Name>_Wet twin from the _Wet maps.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path.insert(0, os.path.join(GAME, "art/source/materials"))
from wire import Ids, MATERIAL_ENUM, PATTERN_ENUM  # noqa: E402

SLOTS = {"Asphalt": "RoadAsphaltWorn", "Cobblestone": "RoadHarbourCobbles", "Pavement": "RoadGravelTrack"}
TEX = "assets/textures/M_Road_Ribbon/T_Road_%s_%s.png"


def main(model_path=None):
    path = model_path or os.path.join(GAME, "src/materials/MaterialService.model.json")
    model = json.load(open(path))
    spec = json.load(open(os.path.join(GAME, "assets/materials/roads_variants.json")))
    idmap, missing = Ids(), []
    names = set()
    added = []
    for v in spec["variants"]:
        for wet in (False, True):
            sfx = "_Wet" if wet else ""
            maps = {"ColorMap": TEX % (v["set"], "ALB" + sfx), "NormalMap": TEX % (v["set"], "NOR"),
                    "RoughnessMap": TEX % (v["set"], "RGH" + sfx), "MetalnessMap": TEX % (v["set"], "MET")}
            props = {}
            for k, f in maps.items():
                i = idmap.get(f)
                if i is None:
                    missing.append(f)
                props[k] = "rbxassetid://%s" % (i or 0)
            props.update({"BaseMaterial": {"Enum": MATERIAL_ENUM[v["base"]]}, "StudsPerTile": v["studsPerTile"],
                          "MaterialPattern": {"Enum": PATTERN_ENUM[v["pattern"]]},
                          "Attributes": {"Attributes": {"Source": {"String": "R1a art/source/roads/roadmats.py"},
                                                        "Licence": {"String": "CC0"}, "Wet": {"Bool": wet},
                                                        "DryTwin": {"String": v["name"]}, "Batch": {"String": "R1a"}}}})
            names.add(v["name"] + sfx)
            added.append({"Name": v["name"] + sfx, "ClassName": "MaterialVariant", "Properties": props})
    model["Children"] = [c for c in model["Children"] if c["Name"] not in names] + added
    for slot, name in SLOTS.items():
        model["Properties"]["%sName" % slot] = name
    json.dump(model, open(path, "w"), indent=1)
    print("road variants", len(added), "slots", SLOTS, "missing ids", len(missing))
    for m in missing[:10]:
        print("  missing", m)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
