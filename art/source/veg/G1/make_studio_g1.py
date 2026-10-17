#!/usr/bin/env python3
"""G1 Studio pass helpers (system python3).
  make_studio_g1.py setup        -> assets/review/G1/studio/plant.luau (ImportAsset x16 with the atlas ids, AlphaMode
                                    Transparency + wet twin, DoubleSided, then a planted patch on the real terrain at a
                                    Haven Head cliff top and on the Haven Sands dunes; returns JSON with the sites)
  make_studio_g1.py shots <res>  -> assets/review/G1/shots.json from the plant.luau result (4 presets dry + wet per site,
                                    FOV 40, plus Overcast close-ups)"""
import json, os, re, sys
GAME = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
R = os.path.join(GAME, "assets/review/G1")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def lua(v):
    if isinstance(v, dict):
        return "{" + ", ".join("[%s] = %s" % (json.dumps(k), lua(x)) for k, x in v.items()) + "}"
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    return json.dumps(v)


def sha1(rel):
    import hashlib
    return hashlib.sha256(open(os.path.join(GAME, rel), "rb").read()).hexdigest()


def setup():
    m = json.load(open(os.path.join(GAME, "assets/manifest.json")))
    s = {"alphaMode": "Transparency", "Wet": {}}
    for e in m.values():
        r = re.match(r"assets/textures/M_Veg_FoliageLand/T_FoliageLand_Main_(ALB|NOR|RGH|MET)(_Wet)?\.png$", e.get("source", ""))
        if r and e.get("imageId") and sha1(e["source"]).startswith(e.get("sha") or "-"):  # the entry for the current bytes only
            (s["Wet"] if r[2] else s)[r[1]] = str(e["imageId"])
    for k in ("NOR", "MET"):  # identical bytes to the dry map: the manifest dedupes by sha, so reuse the dry id
        s["Wet"].setdefault(k, s.get(k))
    assert all(k in s for k in ("ALB", "NOR", "RGH", "MET")) and len(s["Wet"]) == 4, s
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "vegkit.py")).read()
    names = re.findall(r'^\s+"(M_Veg_\w+)": \(', src, re.M)
    code = "local ASSETS = %s\nlocal SET = %s\n" % (lua(names), lua(s)) + PLANT
    os.makedirs(os.path.join(R, "studio"), exist_ok=True)
    open(os.path.join(R, "studio/plant.luau"), "w").write(code)  # run after tools/studio/import_asset.luau (installs _G.ImportAsset)
    print("plant.luau", len(names), "assets")


PLANT = r'''
local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local out = { imported = {}, warnings = {}, doubleSided = {}, sites = {} }
local lib = SS:FindFirstChild("G1Templates") or Instance.new("Folder")
lib.Name = "G1Templates"; lib.Parent = SS
for _, a in ASSETS do
	local src = workspace:FindFirstChild(a .. "_LOD0") or workspace:FindFirstChild(a)
	if not src then table.insert(out.warnings, "missing " .. a); continue end
	local ok, rep = pcall(_G.ImportAsset, { name = a, source = src, tier = "standard", sets = { Main = SET }, parent = "LookDev", cframe = { 0, 3000, 0, 0 } })
	local model = workspace:FindFirstChild("LookDev") and workspace.LookDev:FindFirstChild(a)
	if not ok or not model then table.insert(out.warnings, a .. ": " .. tostring(rep)); continue end
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then
			-- round 2: cards carry explicit back faces with the same outward normals, so DoubleSided stays OFF
			-- (Roblox flips back-face normals, which darkened every card seen from behind)
			local okd = pcall(function() (p :: any).DoubleSided = false end)
			local okr, val = pcall(function() return (p :: any).DoubleSided end)
			out.doubleSided[a] = okd and okr and val == false
			p.CastShadow = true
		end
	end
	model.Parent = lib
	out.imported[#out.imported + 1] = a
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x, z)
	local r = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), params)
	return r
end
local function find(x0, x1, z0, z1, step, ok, score)
	local best, bs = nil, -math.huge
	for x = x0, x1, step do
		for z = z0, z1, step do
			local r = ground(x, z)
			if r and ok(r) then
				-- the whole 24-stud patch must be dry land too
				local good = true
				for _, d in { Vector3.new(12, 0, 0), Vector3.new(-12, 0, 0), Vector3.new(0, 0, 12), Vector3.new(0, 0, -12) } do
					local q = ground(x + d.X, z + d.Z)
					if not q or q.Position.Y < 3 or q.Material == Enum.Material.Water then good = false end
				end
				local s = score(r)
				if good and s > bs then best, bs = r, s end
			end
		end
	end
	return best
end
local cliff = find(1380, 1760, 560, 900, 8, function(r)
	return r.Position.Y > 45 and r.Normal.Y > 0.9 and (r.Material == Enum.Material.Grass or r.Material == Enum.Material.LeafyGrass)
end, function(r) return r.Position.Z * 1.0 + r.Position.Y * 0.2 end)  -- nearest the sea, on the top
-- Haven Sands dune band (tools/world/layout.py: sand 120 studs from the waterline, then 110 of dunes): sample the band
-- inland of the beach line (640, 130) -> (1340, 590) and take the highest gentle crest
local dune, dbest = nil, -math.huge
for t = 0.2, 0.8, 0.025 do
	for s = 130, 225, 8 do
		local x, z = 640 + 700 * t + 0.549 * s, 130 + 460 * t - 0.836 * s
		local r = ground(x, z)
		if r and r.Position.Y > 3 and r.Position.Y < 45 and r.Normal.Y > 0.8 and (r.Material == Enum.Material.Sand or r.Material == Enum.Material.Grass) then
			local sc = r.Position.Y + (r.Material == Enum.Material.Sand and 3 or 0)
			if sc > dbest then dune, dbest = r, sc end
		end
	end
end
local folder = workspace:FindFirstChild("G1Patch"); if folder then folder:Destroy() end
folder = Instance.new("Folder"); folder.Name = "G1Patch"; folder.Parent = workspace
local rng = Random.new(1871)
local WINDYAW = math.rad(-135)  -- Blender +X (leeward) -> Roblox -X, turned to blow towards the north-east
local function put(t, pos, smin, smax)
	local hit = ground(pos.X, pos.Z)
	if not hit or hit.Material == Enum.Material.Water or hit.Material == Enum.Material.Rock then return nil end
	local m = t:Clone()
	m:ScaleTo(rng:NextNumber(smin, smax))
	-- yaw: wind-aligned with a wide spread; a small tilt so nothing stands ruler-straight
	m:PivotTo(CFrame.new(hit.Position - Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, WINDYAW + rng:NextNumber(-0.7, 0.7), 0)
		* CFrame.Angles(rng:NextNumber(-0.07, 0.07), 0, rng:NextNumber(-0.07, 0.07)))
	m.Parent = folder
	return hit
end
-- clustered placement: a few cluster centres inside the patch, members gaussian around each (no even hedge)
local function plant(name, c, radius, n, smin, smax, ring)
	local t = lib:FindFirstChild(name); if not t then return 0 end
	smin, smax = math.min(smin, 0.7), math.max(smax, 1.3)
	local k, clusters = 0, {}
	for i = 1, math.max(1, math.ceil(n / 7)) do
		local a, r = rng:NextNumber(0, 2 * math.pi), radius * math.sqrt(rng:NextNumber(ring or 0, 1))
		clusters[i] = Vector3.new(c.X + math.cos(a) * r, c.Y, c.Z + math.sin(a) * r)
	end
	for i = 1, n do
		local cc = clusters[rng:NextInteger(1, #clusters)]
		local spread = radius * 0.22
		local pos = cc + Vector3.new(rng:NextNumber(-1, 1) * spread * rng:NextNumber(0.2, 1), 0, rng:NextNumber(-1, 1) * spread * rng:NextNumber(0.2, 1))
		if put(t, pos, smin, smax) then k += 1 end
	end
	return k
end
-- hero plant + its ground fill: a darker soil patch under it (terrain material swap), then turf and thrift around the base
local heroes = {}
local function hero(name, pos, s0, s1)
	local t = lib:FindFirstChild(name); if not t then return 0 end
	local hit = put(t, pos, s0, s1); if not hit then return 0 end
	table.insert(heroes, { name = name, p = hit.Position })
	local mat = hit.Material
	if mat == Enum.Material.Grass or mat == Enum.Material.LeafyGrass then
		local r = name:find("Hawthorn") and 2.5 or (name:find("Gorse") and 1.5 or 0.5)  -- one or two voxels: a base patch, not a field
		local p = hit.Position
		local reg = Region3.new(p - Vector3.new(r, 3, r), p + Vector3.new(r, 2, r)):ExpandToGrid(4)
		pcall(function() workspace.Terrain:ReplaceMaterial(reg, 4, mat, Enum.Material.Ground) end)
	end
	local fill = 0
	for i = 1, 9 do  -- turf skirt hugging the base
		local a = rng:NextNumber(0, 2 * math.pi)
		local d = rng:NextNumber(1.2, name:find("Hawthorn") and 5 or 3.2)
		if put(lib:FindFirstChild(rng:NextNumber() < 0.6 and "M_Veg_Grass_Turf_01" or "M_Veg_Grass_Turf_02"),
			hit.Position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), 0.7, 1.3) then fill += 1 end
	end
	for i = 1, 4 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local d = rng:NextNumber(1.8, 3.6)
		if put(lib:FindFirstChild(rng:NextNumber() < 0.5 and "M_Veg_SeaThrift_01" or "M_Veg_SeaThrift_02"),
			hit.Position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), 0.7, 1.3) then fill += 1 end
	end
	return 1, fill
end
local counts = { fill = 0 }
local function H(name, pos, s0, s1)
	local n, f = hero(name, pos, s0, s1); counts.fill += (f or 0); return n
end
if cliff then
	local c = cliff.Position
	out.sites.cliff = { c.X, c.Y, c.Z, cliff.Material.Name }
	counts.turf = plant("M_Veg_Grass_Turf_01", c, 13, 70, 0.7, 1.3) + plant("M_Veg_Grass_Turf_02", c, 13, 40, 0.7, 1.3)
	counts.thrift = plant("M_Veg_SeaThrift_01", c, 12, 28, 0.7, 1.3, 0.25) + plant("M_Veg_SeaThrift_02", c, 12, 18, 0.7, 1.3, 0.2)
	counts.heather = plant("M_Veg_Heather_01", c, 11, 10, 0.7, 1.3) + plant("M_Veg_Heather_02", c, 11, 8, 0.7, 1.3) + plant("M_Veg_Heather_03", c, 11, 6, 0.7, 1.3)
	counts.gorse = H("M_Veg_Gorse_01", c + Vector3.new(-5, 0, -6), 0.85, 1.15) + H("M_Veg_Gorse_01", c + Vector3.new(-2.5, 0, -8.5), 0.7, 0.9)
		+ H("M_Veg_Gorse_02", c + Vector3.new(6, 0, -8), 0.9, 1.1) + H("M_Veg_Gorse_03", c + Vector3.new(4, 0, 2), 0.8, 1.2)
		+ H("M_Veg_Gorse_03", c + Vector3.new(-7, 0, 3), 0.7, 1.0)
	counts.bracken = H("M_Veg_Bracken_01", c + Vector3.new(-1, 0, -11), 0.9, 1.3) + H("M_Veg_Bracken_01", c + Vector3.new(1.5, 0, -12.5), 0.7, 1.0)
		+ plant("M_Veg_Bracken_01", c + Vector3.new(0, 0, -10), 4, 4, 0.7, 1.3) + H("M_Veg_Bracken_02", c + Vector3.new(-8, 0, -9), 0.8, 1.2)
		+ plant("M_Veg_Bracken_02", c + Vector3.new(-8, 0, -9), 3, 3, 0.7, 1.3)
	counts.hawthorn = H("M_Veg_Hawthorn_01", c + Vector3.new(-9, 0, -11), 0.95, 1.05) + H("M_Veg_Hawthorn_02", c + Vector3.new(9, 0, -12), 0.9, 1.1)
end
if dune then
	local d = dune.Position
	out.sites.dune = { d.X, d.Y, d.Z, dune.Material.Name }
	counts.marram = plant("M_Veg_Grass_Marram_01", d, 13, 55, 0.7, 1.3) + plant("M_Veg_Grass_Marram_02", d, 13, 35, 0.7, 1.3)
	counts.duneTurf = plant("M_Veg_Grass_Turf_02", d + Vector3.new(0, 0, -6), 8, 18, 0.7, 1.3)
	counts.duneGorse = H("M_Veg_Gorse_03", d + Vector3.new(-6, 0, -10), 0.8, 1.1) + H("M_Veg_Gorse_03", d + Vector3.new(-3.5, 0, -12), 0.7, 0.9)
	counts.duneBracken = H("M_Veg_Bracken_02", d + Vector3.new(8, 0, -11), 0.8, 1.2) + plant("M_Veg_Bracken_02", d + Vector3.new(8, 0, -11), 3, 2, 0.7, 1.3)
end
out.heroes = #heroes
out.counts = counts
workspace.CurrentCamera.FieldOfView = 40
return HttpService:JSONEncode(out)
'''


def shots(result_file):
    t = open(result_file).read()
    d = json.loads(t[t.find("{"):t.rfind("}") + 1])
    out = []
    for site, s in d["sites"].items():
        if os.environ.get("G1_ONLY") and site != os.environ["G1_ONLY"]:
            continue
        x, y, z = s[0], s[1], s[2]
        wide = ([x - 9, y + 6.5, z - 25], [x + 1, y + 1.2, z + 3])
        for preset in ("Clear", "Overcast", "Storm", "Night"):
            for wet in (False, True):
                out.append({"name": "G1_%s_%s_%s" % (site, preset, "wet" if wet else "dry"), "cam": wide[0], "look": wide[1],
                            "settle": 4.0 if wet else 1.5, "lua": "workspace.CurrentCamera.FieldOfView = 40 return _G.LookDev.apply('%s', %s)"
                            % (preset, "true" if wet else "false")})
        out.append({"name": "G1_%s_Overcast_close" % site, "cam": [x - 4, y + 2.6, z - 9], "look": [x, y + 0.8, z - 1],
                    "settle": 1.5, "lua": "workspace.CurrentCamera.FieldOfView = 40 return _G.LookDev.apply('Overcast', false)"})
    json.dump(out, open(os.path.join(R, "shots.json"), "w"), indent=1)
    print("shots", len(out), d.get("counts"), d.get("sites"), "warnings", d.get("warnings"), "doubleSided", set(d.get("doubleSided", {}).values()))


if __name__ == "__main__":
    setup() if sys.argv[1] == "setup" else shots(sys.argv[2])
