"""H1 Studio pass inputs -> assets/review/M_Bld_Station/{shots.json, studio/*.luau}: imports the station and the slipway
with tools/studio/import_asset.luau (own sets by content hash from assets/manifest.json, shared sets from
assets/materials/manifest.csv), lays them out as in the greybox (station pivot (0, 4, 0), slipway pivot (-55, 4, 69),
both yawed 180 so the fronts face +Z, the sea), a quay slab at Y 4, practical lamps, preload. FOV 40 in every shot."""
import csv, hashlib, json
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
R = G + "assets/review/M_Bld_Station/"
man = json.load(open(G + "assets/manifest.json"))
by_sha = {e.get("sha"): e for e in man.values() if e.get("sha")}


def img(path):
    h = hashlib.sha256(open(G + path, "rb").read()).hexdigest()
    for s, e in by_sha.items():
        if h.startswith(s) or s.startswith(h[:40]):
            return str(e.get("imageId") or e.get("assetId"))
    raise SystemExit("not uploaded: " + path)


def own(asset, stem):
    d = {k: img("assets/textures/%s/%s_%s.png" % (asset, stem, k)) for k in ("ALB", "NOR", "RGH", "MET")}
    d["Wet"] = {k: img("assets/textures/%s/%s_%s_Wet.png" % (asset, stem, k)) for k in ("ALB", "RGH")}
    return d


lib = {}
for row in csv.reader(open(G + "assets/materials/manifest.csv")):
    if len(row) > 5 and row[5].isdigit():
        name, kind = row[0], row[3]
        key = {"ColorMap": "ALB", "NormalMap": "NOR", "RoughnessMap": "RGH", "MetalnessMap": "MET"}.get(kind, kind)
        base = name[:-4] if name.endswith("_Wet") else name
        wet = name.endswith("_Wet") or key.endswith("_Wet")
        key = key.replace("_Wet", "")
        s = lib.setdefault(base, {})
        (s.setdefault("Wet", {}) if wet else s)[key] = row[5]
sheet = lib["BldTrimSheet"]


def lua(v):
    if isinstance(v, dict):
        return "{" + ", ".join("[%s] = %s" % (json.dumps(k), lua(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    return json.dumps(v)


def atts(asset):
    d = json.load(open(G + "assets/fbx/%s/%s.attachments.json" % (asset, asset)))
    return [{"name": a["name"], "pos": a["roblox_from_origin"]} for a in d.get("attachments", [])]


def parts(asset, m):
    return {"%s_%s_%s" % (asset, p, l): s for p, s in m.items() for l in ("LOD0", "LOD1", "LOD2")}


st = {"name": "M_Bld_Station", "source": "Workspace/M_Bld_Station", "tier": "hero",
      "sets": {"Render": own("M_Bld_Station", "T_Station_Render"), "Slate": own("M_Bld_Station", "T_Station_Slate"),
               "Details": own("M_Bld_Station", "T_Station_Details"), "Sheet": sheet, "Granite": own("M_Bld_Station", "T_Station_Granite")},
      "partSets": parts("M_Bld_Station", {"Stone": "Granite", "Render": "Render", "Roof": "Slate", "Trim": "Sheet",
                                          "Details": "Details", "BayDoor": "Details"}),
      "attachments": atts("M_Bld_Station"), "cframe": [0, 4, 0, 180]}
sl = {"name": "M_Bld_Slipway", "source": "Workspace/M_Bld_Slipway", "tier": "hero",
      "sets": {"Concrete": lib["Concrete"], "WeedyConcrete": lib["WeedyConcrete"], "Steel": own("M_Bld_Slipway", "T_Slipway_Steel")},
      "partSets": parts("M_Bld_Slipway", {"Ramp": "Concrete", "Weedy": "WeedyConcrete", "Steel": "Steel"}),
      "attachments": atts("M_Bld_Slipway"), "cframe": [-55, 4, 69, 180]}
pre = """for _, c in workspace:GetChildren() do
\tif c:IsA("Model") and c.Name == "M_Bld_Station_LOD0" then c.Name = "M_Bld_Station" end
\tif c:IsA("Model") and c.Name == "M_Bld_Slipway_LOD0" then c.Name = "M_Bld_Slipway" end
end
"""
src = open(G + "tools/studio/import_asset.luau").read()
open(R + "studio/import-setup.luau", "w").write(pre + "_G.ImportAssetConfig = " + lua(st) + "\n" + src)
open(R + "studio/import-slipway.luau", "w").write("local r = _G.ImportAsset(" + lua(sl) + ")\nreturn game:GetService('HttpService'):JSONEncode(r)\n")
open(R + "studio/scene.luau", "w").write("""-- H1 scene: quay slab (top Y 4) under the station, lamps lit for Night, preload every map (3 tries)
local old = workspace:FindFirstChild("H1Scene") if old then old:Destroy() end
local f = Instance.new("Folder") f.Name = "H1Scene" f.Parent = workspace
local q = Instance.new("Part") q.Name = "Quay" q.Anchored = true q.Size = Vector3.new(220, 12, 100)
q.CFrame = CFrame.new(-20, -2, 19) q.Material = Enum.Material.Concrete q.Color = Color3.fromRGB(120, 118, 112) q.Parent = f
for _, d in workspace:GetDescendants() do
	if d:IsA("Attachment") and (d.Name == "ATT_CrewDoor" or d.Name == "ATT_Sign" or d.Name == "ATT_HallBackDoor") then
		local l = Instance.new("PointLight") l.Brightness = 1.2 l.Range = 18 l.Color = Color3.fromRGB(255, 214, 160) l.Parent = d
	end
end
local CP = game:GetService("ContentProvider")
local ids, seen = {}, {}
for _, d in workspace:GetDescendants() do
	if d:IsA("SurfaceAppearance") and string.find(d:GetFullName(), "M_Bld_", 1, true) then
		for _, k in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" } do
			local ok, v = pcall(function() return d[k] end)
			if ok and type(v) == "string" and v ~= "" and not seen[v] then seen[v] = true table.insert(ids, v) end
		end
	end
end
local failed = {}
for attempt = 1, 3 do
	failed = {}
	local list = {}
	for _, id in ids do local dec = Instance.new("Decal") dec.Texture = id table.insert(list, dec) end
	pcall(function() CP:PreloadAsync(list, function(id, s) if s ~= Enum.AssetFetchStatus.Success then table.insert(failed, id) end end) end)
	if #failed == 0 then break end
	task.wait(2)
end
return string.format("H1 scene ok; maps %d, failed %d", #ids, #failed)
""")
shots = []
def shot(name, cam, look, preset, wet):
    shots.append({"name": name, "cam": cam, "look": look, "settle": 3.0,
                  "lua": "workspace.CurrentCamera.FieldOfView = 40 _G.LookDev.shot(%s, %s) return _G.LookDev.apply('%s', %s)"
                         % (lua(cam), lua(look), preset, "true" if wet else "false")})
for p in ("Clear", "Overcast", "Storm", "Night"):          # hero framing, both assets, four presets dry and wet
    for w in (False, True):
        shot("M_Bld_Station_Harbour_%s_%s" % (p, "wet" if w else "dry"), [45, 16, 165], [-18, 15, 12], p, w)
for p in ("Clear", "Overcast", "Storm", "Night"):
    for w in (False, True):
        shot("M_Bld_Slipway_Hero_%s_%s" % (p, "wet" if w else "dry"), [-18, 24, 150], [-55, 0, 92], p, w)
for w in (False, True):                                    # close-ups (Overcast): tide line, bay door + sign, wing wall
    shot("M_Bld_Slipway_Closeup_Overcast_%s" % ("wet" if w else "dry"), [-38, 9, 102], [-55, 2, 82], "Overcast", w)
    shot("M_Bld_Station_DoorDetail_Overcast_%s" % ("wet" if w else "dry"), [-6, 10, 42], [-15, 10, 23], "Overcast", w)
    shot("M_Bld_Station_WallDetail_Overcast_%s" % ("wet" if w else "dry"), [38, 9, 46], [24, 9, 26], "Overcast", w)
json.dump(shots, open(R + "shots.json", "w"), indent=1)
print("sets station", sorted(st["sets"]), "slipway", sorted(sl["sets"]), "shots", len(shots))
