"""H2: writes assets/review/M_Bld_Chandlery/studio/import-{setup,int,props}.luau. Imports the Chandlery exterior,
interior and props with tools/studio/import_asset.luau (explicit partSets), all three pivoted at the SAME CFrame
(the shared layout.py frame: origin = wall-footprint centre at quay level, front -Z in Roblox). Image ids are the
manifest entries whose sha matches the file on disk (adapted from art/source/vehicles/M_Veh_RIB/make_import_setup.py)."""
import hashlib, json, os, re
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
m = json.load(open(G + "assets/manifest.json"))
# shot on a neutral stand: quay level (layout z 0) on the backdrop floor top at y 40 (studio/chandlery.luau)
CF = [0, float(os.environ.get("MAYDAY_CHAND_Y", "40")), 0, 0]
_shas = {}


def _sha(path):
    if path not in _shas:
        try:
            _shas[path] = hashlib.sha256(open(G + path, "rb").read()).hexdigest()
        except OSError:
            _shas[path] = ""
    return _shas[path]


def sets_for(folder, wanted, wet):
    """{set: {ALB.., Wet: {..}}} for assets/textures/<folder>/T_<Name>_<Set>_<MAP>[_Wet].png on disk; the id is the
    manifest entry keyed by the file's content sha (identical maps, e.g. flat black MET, share one upload)."""
    import glob
    by_sha = {}
    for k, e in m.items():
        if e.get("imageId"):
            by_sha[k.split(":", 1)[1] if k.startswith("Image:") else e.get("sha", "")] = e["imageId"]
    sets = {}
    for f in sorted(glob.glob(G + "assets/textures/%s/*.png" % folder)):
        src = f[len(G):]
        r = re.match(rf"assets/textures/{folder}/T_\w+?_([A-Za-z][A-Za-z0-9]*)_(ALB|NOR|RGH|MET)(_Wet)?\.png$", src)
        if not r or r[1] not in wanted or (r[3] and not wet):
            continue
        iid = by_sha.get(_sha(src))
        if not iid:
            print("  no upload for", src)
            continue
        s = sets.setdefault(r[1], {})
        (s.setdefault("Wet", {}) if r[3] else s)[r[2]] = iid
    return sets


def lua(v):
    if isinstance(v, dict):
        return "{" + ", ".join("[%s] = %s" % (json.dumps(k), lua(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    return json.dumps(v)


def atts(asset):
    try:
        d = json.load(open(G + "assets/fbx/%s/%s.attachments.json" % (asset, asset)))
        return [{"name": a["name"], "pos": a["roblox_from_origin"]} for a in d.get("attachments", [])]
    except OSError:
        return []


def part_sets(asset, mapping, lods):
    return {"%s_%s_%s" % (asset, p, l): s for p, s in mapping.items() for l in lods}


EXT, INT, PROPS = "M_Bld_Chandlery_Ext", "M_Bld_Chandlery_Int", "M_Prop_Chandlery"
ext_map = {"Stone": "QuayStone", "Granite": "Granite", "Roof": "Slate", "Trim": "Sheet", "Details": "Details",
           "Shopfront": "Details", "Glass": "Details", "Door": "Details", "DoorGlass": "Details"}
int_map = {"Floor": "Pine", "Lining": "Lining", "Structure": "Joinery", "Joinery": "Joinery", "Trim": "Sheet",
           "Details": "Details", "Glow": "Details", "Hardware": "Details"}
prop_map = {p: "Atlas" for p in ("RackWall", "RackMid", "Gondola", "Mannequins", "Hung", "Corner")}
prop_map["Rope"] = "Rope"

ext_sets = sets_for(EXT, {"Slate", "Details"}, True)
ext_sets.update(sets_for("M_Bld_TrimSheet", {"Sheet"}, True))
ext_sets.update(sets_for("Materials", {"QuayStone", "Granite"}, True))
int_sets = sets_for(INT, {"Pine", "Lining", "Joinery", "Details"}, False)
int_sets.update(sets_for("M_Bld_TrimSheet", {"Sheet"}, False))   # dry trim indoors (no wet swap inside)
prop_sets = sets_for(PROPS, {"Atlas", "Rope"}, False)

L3 = ("LOD0", "LOD1", "LOD2")
cfgs = [
    {"name": EXT, "source": "Workspace/" + EXT, "tier": "hero", "sets": ext_sets,
     "partSets": part_sets(EXT, ext_map, L3), "attachments": atts(EXT), "cframe": CF},
    {"name": INT, "source": "Workspace/" + INT, "tier": "hero", "sets": int_sets,
     "partSets": part_sets(INT, int_map, L3), "attachments": atts(INT), "cframe": CF},
    {"name": PROPS, "source": "Workspace/" + PROPS, "tier": "hero", "sets": prop_sets,
     "partSets": part_sets(PROPS, prop_map, ("LOD0", "LOD1")), "attachments": atts(PROPS), "cframe": CF},
]
for c in cfgs:
    n = sum(len([k for k in s if k != "Wet"]) + len(s.get("Wet", {})) for s in c["sets"].values())
    need = sorted(set(c["partSets"].values()))
    print(c["name"], "sets", sorted(c["sets"]), "maps", n, "missing", [s for s in need if s not in c["sets"]])
pre = """for _, c in workspace:GetChildren() do
\tif c:IsA("Model") then
\t\tfor _, n in { "%s", "%s", "%s" } do
\t\t\tif c.Name == n .. "_LOD0" then c.Name = n end
\t\tend
\tend
end
""" % (EXT, INT, PROPS)
src = open(G + "tools/studio/import_asset.luau").read()
out = G + "assets/review/M_Bld_Chandlery/studio/"
os.makedirs(out, exist_ok=True)
open(out + "import-setup.luau", "w").write(pre + "_G.ImportAssetConfig = " + lua(cfgs[0]) + "\n" + src)
for c, f in ((cfgs[1], "import-int.luau"), (cfgs[2], "import-props.luau")):
    open(out + f, "w").write("local r = _G.ImportAsset(" + lua(c) + ")\nreturn game:GetService('HttpService'):JSONEncode(r)\n")
