"""Writes assets/review/M_Veh_RIB/studio/import-setup.luau: renames the inserted models, imports the RIB and the helm
with tools/studio/import_asset.luau (explicit partSets), both pivoted at the same CFrame (shared frame)."""
import json, re
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
m = json.load(open(G + "assets/manifest.json"))
CF = [0, -2.05, 0, 0]   # base of the skegs 2.05 studs under sea level: keel 0.45 + 0.53 m draught


def sets_for(asset):
    sets = {}
    for e in m.values():
        r = re.match(rf"assets/textures/{asset}/T_\w+?_([A-Za-z][A-Za-z0-9]*)_(ALB|NOR|RGH|MET)(_Wet)?\.png$", e.get("source", ""))
        if r and e.get("imageId"):
            s = sets.setdefault(r[1], {})
            (s.setdefault("Wet", {}) if r[3] else s)[r[2]] = e["imageId"]
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
        return json.load(open(G + "assets/fbx/%s/%s.attachments.json" % (asset, asset)))
    except OSError:
        return []


rib_parts = {}
for lod in ("LOD0", "LOD1", "LOD2"):
    for p, s in (("Hull", "Hull"), ("Tubes", "Hull"), ("Deck", "Deck"), ("Console", "Deck"), ("AFrame", "Rig"),
                 ("Engines", "Rig"), ("Decals", "Decals")):
        rib_parts["M_Veh_RIB_%s_%s" % (p, lod)] = s
rib = {"name": "M_Veh_RIB", "source": "Workspace/M_Veh_RIB", "tier": "hero", "sets": sets_for("M_Veh_RIB"),
       "partSets": rib_parts, "attachments": atts("M_Veh_RIB"), "cframe": CF}
helm = {"name": "M_Veh_RIB_Helm", "source": "Workspace/M_Veh_RIB_Helm", "tier": "hero", "sets": sets_for("M_Veh_RIB_Helm"),
        "partSets": {"M_Veh_RIB_Helm_Console_LOD0": "Console", "M_Veh_RIB_Helm_Seats_LOD0": "Seats"},
        "attachments": atts("M_Veh_RIB_Helm"), "cframe": CF}
for c in (rib, helm):
    n = sum(len([k for k in s if k != "Wet"]) + len(s.get("Wet", {})) for s in c["sets"].values())
    print(c["name"], "sets", sorted(c["sets"]), "maps", n)
pre = """for _, c in workspace:GetChildren() do
\tif c:IsA("Model") and (c.Name == "M_Veh_RIB_LOD0") then c.Name = "M_Veh_RIB" end
\tif c:IsA("Model") and (c.Name == "M_Veh_RIB_Helm_LOD0") then c.Name = "M_Veh_RIB_Helm" end
end
"""
src = open(G + "tools/studio/import_asset.luau").read()
out = G + "assets/review/M_Veh_RIB/studio/"
open(out + "import-setup.luau", "w").write(pre + "_G.ImportAssetConfig = " + lua(rib) + "\n" + src)
open(out + "import-helm.luau", "w").write("local r = _G.ImportAsset(" + lua(helm) + ")\nreturn game:GetService('HttpService'):JSONEncode(r)\n")
