"""B02: after upload.sh, write the Rojo MaterialService, the material manifest, the licence list and the batch status.

python3 art/source/materials/wire.py
  src/materials/MaterialService.model.json   MaterialVariants that show (PART_VARIANTS, own-base names); no Terrain slot overrides (see below)
  assets/materials/manifest.csv               one row per map: variant, map, file, asset id, source, licence
  assets/materials/LICENCES.md                every CC0 source with author and URL
  art/status/B02.csv                          batch status rows (docs/12 1.3)
"""
import csv, datetime, hashlib, json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path.insert(0, HERE)
from library import LIBRARY, TRIM, STUDS_PER_M, studs_per_tile  # noqa: E402

MATERIAL_ENUM = {"Sand": 1296, "Sandstone": 912, "Salt": 1392, "Limestone": 820, "Pebble": 864, "CrackedLava": 804, "Rock": 896, "Slate": 800,
                 "Basalt": 788, "Grass": 1280, "LeafyGrass": 1284, "Mud": 1344, "Ground": 1360, "Pavement": 836,
                 "Asphalt": 1376, "Cobblestone": 880, "Concrete": 816, "Granite": 832, "Plastic": 256,
                 "Snow": 1328, "WoodPlanks": 528, "Brick": 848, "Glacier": 1552, "Ice": 1536}
# WP-16: each variant is one Studio texture pack per publish, so the place gets only the ones that show: those a Part
# names (AssetLoader.PART_SETS "Mat" sets) and those named like their own base material (the engine applies those with
# no slot override: Mud on the terrain; Studio A/B 2026-10-25, Granite on a Rock base alone greyed the island cove, so
# it stays out). The _Wet twins are never applied. Roads are cut (WP-17).
PART_VARIANTS = {"Cobbles"}
PATTERN_ENUM = {"Regular": 0, "Organic": 1}
LICENCE = "CC0 1.0 (https://polyhaven.com/license)"
TODAY = datetime.date.today().isoformat()


def rel(p):
    return os.path.relpath(p, GAME)


class Ids(dict):
    """file path -> Image id, looked up by content sha256 (the manifest key), so identical maps share one upload."""
    def __init__(self):
        super().__init__()
        self.m = json.load(open(os.path.join(GAME, "assets/manifest.json")))

    def __contains__(self, path):
        return self.get(path) is not None

    def __getitem__(self, path):
        return self.get(path)

    def get(self, path, default=None):
        full = os.path.join(GAME, path)
        if not os.path.exists(full):
            return default
        e = self.m.get("Image:" + hashlib.sha256(open(full, "rb").read()).hexdigest())
        return (e.get("imageId") or e.get("assetId")) if e else default


def ids():
    return Ids()


def info(pid, cache):
    if pid not in cache:
        req = urllib.request.Request("https://api.polyhaven.com/info/%s" % pid, headers={"User-Agent": "MaydaySeaRescue-B02/1.0"})
        cache[pid] = json.loads(urllib.request.urlopen(req, timeout=60).read())
    return cache[pid]


def main():
    idmap = ids()
    cpath = os.path.join(GAME, "build/materials/info.json")
    cache = json.load(open(cpath)) if os.path.exists(cpath) else {}
    tex = "assets/textures/Materials/T_Mat_%s_%s.png"
    rows, children, missing = [], [], []

    def aid(path):
        if path not in idmap:
            missing.append(path)
            return "0"
        return idmap[path]

    for name, pid, dims, base, terrain, pattern, note in LIBRARY:
        url = "https://polyhaven.com/a/%s" % pid
        for wet in (False, True):
            sfx = "_Wet" if wet else ""
            # Granite wears the grey KelpRock (slate) albedo: its own averaged brown and read as brown cliffs from the air
            maps = {"ColorMap": tex % ("KelpRock" if name == "Granite" else name, "ALB" + sfx), "NormalMap": tex % (name, "NOR"),
                    "RoughnessMap": tex % (name, "RGH" + sfx), "MetalnessMap": tex % (name, "MET")}
            props = {k: "rbxassetid://%s" % aid(v) for k, v in maps.items()}
            props.update({"BaseMaterial": {"Enum": MATERIAL_ENUM[base]}, "StudsPerTile": studs_per_tile(name, dims),
                          "MaterialPattern": {"Enum": PATTERN_ENUM[pattern]}})
            props["Attributes"] = {"Attributes": {"Source": {"String": url}, "Licence": {"String": "CC0"}, "Wet": {"Bool": wet},
                                                  "DryTwin": {"String": name}}}
            children.append({"Name": name + sfx, "ClassName": "MaterialVariant", "Properties": props})
            for k, v in maps.items():
                if wet and k in ("NormalMap", "MetalnessMap"):
                    continue
                rows.append([name + sfx, base, terrain or "", k, v, aid(v), url, LICENCE, studs_per_tile(name, dims), pattern, note])
        # no terrain slot override (<Base>Name): the live client fails to load terrain variants and draws flat
        # MaterialColors (2026-10-22, white town ground), so terrain keeps the built-in materials

    trim = "assets/textures/M_Bld_TrimSheet/T_BldTrim_Sheet_%s.png"
    for kind in ("ALB", "NOR", "RGH", "MET", "ALB_Wet", "RGH_Wet"):
        rows.append(["BldTrimSheet", "", "", kind, trim % kind, aid(trim % kind),
                     " ".join(sorted({"https://polyhaven.com/a/%s" % t[1] for t in TRIM})), LICENCE, "", "UV trim sheet",
                     "building trim sheet (SurfaceAppearance; strips in layout.json)"])

    model = {"ClassName": "MaterialService",
             "Properties": dict({"Use2022Materials": True, "Attributes": {"Attributes": {"WetSuffix": {"String": "_Wet"}, "Batch": {"String": "B02"}}}}),
             "Children": [c for c in children if c["Name"] in PART_VARIANTS
                          or MATERIAL_ENUM.get(c["Name"]) == c["Properties"]["BaseMaterial"]["Enum"]]}
    os.makedirs(os.path.join(GAME, "src/materials"), exist_ok=True)
    json.dump(model, open(os.path.join(GAME, "src/materials/MaterialService.model.json"), "w"), indent=1)

    os.makedirs(os.path.join(GAME, "assets/materials"), exist_ok=True)
    with open(os.path.join(GAME, "assets/materials/manifest.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["variant", "baseMaterial", "terrainSlot", "map", "file", "assetId", "source", "licence", "studsPerTile", "pattern", "note"])
        w.writerows(rows)

    srcs = sorted({r[1] for r in LIBRARY} | {t[1] for t in TRIM})
    used = {}
    for r in LIBRARY:
        used.setdefault(r[1], []).append(r[0])
    for t in TRIM:
        used.setdefault(t[1], []).append("trim:" + t[0])
    lines = ["# assets/materials: third-party sources (batch B02)", "",
             "Every map in `assets/textures/Materials/` and `assets/textures/M_Bld_TrimSheet/` is derived from Poly Haven textures under "
             "CC0 ([licence](https://polyhaven.com/license)); credit is not required but is given here. Downloaded as 1k PNG through "
             "`api.polyhaven.com/files/<id>` (diffuse, nor_gl, rough) by `art/source/materials/process.py`, graded to the 05 3.1 albedo "
             "rules, wet twins derived. Asset ids per map: `manifest.csv`.", "",
             "| Poly Haven id | Name | URL | Author(s) | Real size | Used for | Licence | Date |", "|---|---|---|---|---|---|---|---|"]
    for pid in srcs:
        d = info(pid, cache)
        dims = d.get("dimensions") or [0, 0]
        lines.append("| `%s` | %s | https://polyhaven.com/a/%s | %s | %.2f x %.2f m | %s | [CC0](https://polyhaven.com/license) | %s |" % (
            pid, d.get("name", pid), pid, ", ".join(d.get("authors", {}).keys()), dims[0] / 1000, dims[1] / 1000,
            ", ".join(used[pid]), TODAY))
    open(os.path.join(GAME, "assets/materials/LICENCES.md"), "w").write("\n".join(lines) + "\n")
    json.dump(cache, open(cpath, "w"))

    os.makedirs(os.path.join(GAME, "art/status"), exist_ok=True)
    with open(os.path.join(GAME, "art/status/B02.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"])
        for name, pid, dims, base, terrain, pattern, note in LIBRARY:
            w.writerow(["MV_" + name, "P0", "round1 (look-dev pending review)", aid(tex % (name, "ALB")), "polyhaven:" + pid, "CC0", "no", "",
                        "%s; base %s; terrain %s; %s studs/tile; wet twin %s_Wet" % (note, base, terrain or "-", studs_per_tile(name, dims), name)])
        w.writerow(["T_BldTrim_Sheet", "P0", "round1", aid(trim % "ALB"), "polyhaven:" + "+".join(sorted({t[1] for t in TRIM})), "CC0", "no", "",
                    "10 strips, layout.json"])
    print("variants", len(children), "rows", len(rows), "missing ids", len(missing))
    for m in missing[:10]:
        print("  missing", m)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
