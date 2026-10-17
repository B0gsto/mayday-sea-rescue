
local function lod0Box(model)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") and string.find(p.Name, "_LOD0") and not string.find(p.Name, "_COL") then
			local h = p.Size / 2
			for _, sx in {-1, 1} do for _, sy in {-1, 1} do for _, sz in {-1, 1} do
				local w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
				mn = mn:Min(w); mx = mx:Max(w)
			end end end
		end
	end
	return mn, mx
end

_G.ImportAssetConfig = nil
local model
for _, c in workspace:GetChildren() do
	if c:IsA("Model") and string.sub(c.Name, 1, 11) == "M_Chr_Bosun" then model = c end
end
assert(model, "inserted M_Chr_Bosun model not found")
model.Name = "M_Chr_Bosun"
local mn, mx = lod0Box(model)
local centre = (mn + mx) / 2
_G.BosunPre = {centre = {centre.X, centre.Y, centre.Z}, size = {mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z}}
for _, m in {{["name"] = "ATT_HarnessHandle", ["c"] = {0.0011, 1.035, -0.0065}, ["o"] = {-0.0, 2.4365, 0.1089}}, {["name"] = "ATT_TowRing", ["c"] = {0.0011, 0.8565, 0.4623}, ["o"] = {-0.0, 2.258, 0.5777}}, {["name"] = "ATT_Mouth", ["c"] = {0.0011, 0.8305, -2.5318}, ["o"] = {-0.0, 2.232, -2.4165}}} do
	local p = Instance.new("Part")
	p.Name = m.name; p.Size = Vector3.one * 0.1; p.Anchored = true; p.Transparency = 1
	p.CFrame = CFrame.new(centre + Vector3.new(m.c[1], m.c[2], m.c[3]))
	p.Parent = model
end
--!strict
--# selene: allow(global_usage)
--[==[
import_asset.luau: Studio side of the asset pipeline (docs/12-asset-list.md 1.1, 1.2, 1.4 item 7).

Takes a model that tools/studio-insert.py already put into the place (Workspace or ServerStorage; the
.rbxm from tools/assets.py: a Model root with MeshParts under it) and makes it look-dev ready:
  * one SurfaceAppearance per MeshPart from the uploaded map ids (_ALB/_NOR/_RGH/_MET), replacing any
    the importer made; where the set has _Wet ids, a second SurfaceAppearance is stored disabled in a
    Configuration child "SurfaceVariants" (names SurfaceAppearance_Wet / SurfaceAppearance_Dry) and the
    part is tagged "HasWetVariant" - art/lookdev/shot-setup.luau (_G.LookDev.apply(name, true)) swaps it;
  * ATT_* markers to Attachments: marker MeshParts/Parts/Models named ATT_* become Attachments on the
    nearest visual part (or config.attachParent) at the same world CFrame and are destroyed; existing
    ATT_* Attachments are kept; config.attachments (from <Name>.attachments.json) fills in any missing;
  * visual parts CanCollide/CanTouch false (CanQuery kept), _COL parts CanCollide true, Transparency 1,
    CastShadow false; CollisionFidelity per kind; RenderFidelity per tier (05 section 5.6);
    CastShadow off on parts whose largest axis is under config.smallPartSize; Anchored as configured;
  * _LOD1/_LOD2 parts hidden (Transparency 1, attribute LodHidden) when config.hideLods (default true),
    so the look-dev shot shows LOD0 only; LodController owns LOD switching in the game;
  * renamed to config.name, PrimaryPart set to the largest LOD0 visual part, pivoted to config.cframe and
    parented to workspace.LookDev (config.parent overrides), tagged "LookDevAsset".
Saving as a Package is not scriptable from run_code (no API): the model gets attribute PackagePending =
true; a human does right click > Convert to Package (or Save to Roblox) later.
MeshPart triangle counts are not readable from Luau: the report says tris = "unknown" (validate.py has
the real numbers). RenderFidelity / CollisionFidelity are Studio-only writes: they work in the Edit
datamodel (run_code has plugin security) and are reported as warnings anywhere else.

USAGE (Studio MCP execute_luau / run_code, Edit datamodel): prepend the config as a global, then the file:
    code = "_G.ImportAssetConfig = " + luau_table + "\n" + open("tools/studio/import_asset.luau").read()
The chunk returns the report as JSON text and leaves _G.ImportAsset(config) -> Report installed for
further calls in the same session. Without _G.ImportAssetConfig it only installs _G.ImportAsset.

CONFIG (all ids may be "rbxassetid://N" or a bare number "N"):
    {
      name = "M_Veh_RIB",                 -- result model name (required)
      source = "Workspace/M_Veh_RIB",     -- path from game (slash or dot separated) or an Instance (required)
      tier = "hero",                      -- hero | standard | background (default standard)
      renderFidelity = nil,               -- override: Automatic | Precise | Performance
      collisionFidelity = "Hull",         -- for _COL parts (default Hull)
      visualCollisionFidelity = "Box",    -- for visual parts (cheapest; they do not collide) (default Box)
      anchored = true,                    -- default true
      smallPartSize = 1.5,                -- studs; largest axis below this -> CastShadow false (default 1.5)
      hideLods = true,                    -- default true
      parent = "LookDev",                 -- folder under workspace, or an Instance (default "LookDev")
      cframe = {0, 10, 0, 90},            -- {x, y, z [, yawDeg]} or a CFrame (default: keep where it is)
      attachParent = nil,                 -- MeshPart name that receives every Attachment (default nearest)
      sets = {                            -- texture set -> map ids
        Hull = { ALB = "1", NOR = "2", RGH = "3", MET = "4",
                 Wet = { ALB = "5", NOR = "6", RGH = "7", MET = "8" },   -- optional, any subset
                 alphaMode = nil },       -- optional: Overlay | Transparency
      },
      partSets = { M_Veh_RIB_Hull_LOD0 = "Hull" },  -- optional MeshPart name -> set; default rule below
      attachments = {                     -- optional, from <Name>.attachments.json, model space (studs,
        { name = "ATT_Seat_Driver", pos = {0, 2, -1}, rot = {0, 180, 0}, part = nil },  -- relative to the
      },                                  -- model pivot as imported; rot = degrees, CFrame.fromOrientation)
    }
Default part -> set rule: partSets entry, else the only set when there is one, else the longest set
name found in the MeshPart name (case-insensitive, e.g. "Hull" in M_Veh_RIB_Hull_LOD1), else a warning.

BUILDING THE CONFIG from assets/manifest.json (entries {source = "assets/textures/<Asset>/T_<Name>_<Set>_<MAP>[_Wet].png",
imageId = ...}); system python3, no extra files:
    import json, re, sys
    asset, name = sys.argv[1], sys.argv[2]           # e.g. RIB  M_Veh_RIB
    m = json.load(open("assets/manifest.json")); sets = {}
    for e in m.values():
        r = re.match(rf"assets/textures/{asset}/T_\w+?_([A-Za-z][A-Za-z0-9]*(?:_\d+)?)_(ALB|NOR|RGH|MET)(_Wet)?\.png$", e.get("source", ""))
        if r and e.get("imageId"):
            s = sets.setdefault(r[1], {}); (s.setdefault("Wet", {}) if r[3] else s)[r[2]] = e["imageId"]
    att = f"assets/fbx/{asset}/{name}.attachments.json"
    try: atts = json.load(open(att))
    except OSError: atts = []
    lua = lambda v: ("{" + ", ".join(f"[{json.dumps(k)}] = {lua(x)}" if isinstance(v, dict) else lua(x)
                     for k, x in (v.items() if isinstance(v, dict) else enumerate(v))) + "}"
                     if isinstance(v, (dict, list)) else json.dumps(v))
    cfg = {"name": name, "source": f"Workspace/{name}", "tier": "hero", "sets": sets, "attachments": atts}
    print("_G.ImportAssetConfig = " + lua(cfg))
(the set is the last word before the map suffix, plus an optional _NN: T_RIB_Hull_ALB -> Hull,
T_Bld_Cottage_Wall_02_NOR -> Wall_02; keys are emitted as ["..."] so any set name is valid Luau).
]==]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

export type MapSet = { ALB: string?, NOR: string?, RGH: string?, MET: string? }
export type TextureSet = {
	ALB: string?,
	NOR: string?,
	RGH: string?,
	MET: string?,
	Wet: MapSet?,
	alphaMode: string?,
}
export type AttachmentSpec = { name: string, pos: { number }, rot: { number }?, part: string? }
export type Config = {
	name: string,
	source: string | Instance,
	tier: string?,
	renderFidelity: string?,
	collisionFidelity: string?,
	visualCollisionFidelity: string?,
	anchored: boolean?,
	smallPartSize: number?,
	hideLods: boolean?,
	parent: (string | Instance)?,
	cframe: (CFrame | { number })?,
	attachParent: string?,
	sets: { [string]: TextureSet }?,
	partSets: { [string]: string }?,
	attachments: { AttachmentSpec }?,
}
export type Report = {
	asset: string,
	path: string,
	parts: number,
	meshParts: number,
	colParts: number,
	lodHidden: number,
	tris: string,
	surfaceAppearances: number,
	wetVariants: number,
	attachments: { string },
	castShadowOff: number,
	warnings: { string },
}

local TIER_FIDELITY: { [string]: string } = {
	hero = "Precise",
	standard = "Automatic",
	background = "Performance",
}
local MAP_PROPS: { [string]: string } = {
	ALB = "ColorMap",
	NOR = "NormalMap",
	RGH = "RoughnessMap",
	MET = "MetalnessMap",
}

local function assetUri(id: string): string
	if string.find(id, "://", 1, true) then
		return id
	end
	return "rbxassetid://" .. id
end

local function enumItem(enum: any, name: string?, warnings: { string }): any?
	if not name then
		return nil
	end
	local ok, item = pcall(function()
		return enum[name]
	end)
	if ok then
		return item
	end
	table.insert(warnings, "unknown enum value " .. tostring(name))
	return nil
end

local function resolve(path: string | Instance): Instance?
	if typeof(path) == "Instance" then
		return path
	end
	local node: Instance? = game
	for segment in string.gmatch(path :: string, "[^/%.]+") do
		if not node then
			return nil
		end
		if node == game then
			local ok, service = pcall(function()
				return game:GetService(segment :: any)
			end)
			node = if ok and service then service else game:FindFirstChild(segment)
		else
			node = (node :: Instance):FindFirstChild(segment)
		end
	end
	return if node == game then nil else node
end

-- Sets one SurfaceAppearance map; newer engines expose *Content properties next to the string ones.
local function setMap(sa: SurfaceAppearance, prop: string, id: string, warnings: { string })
	local uri = assetUri(id)
	local ok = pcall(function()
		(sa :: any)[prop] = uri
	end)
	if not ok then
		ok = pcall(function()
			(sa :: any)[prop .. "Content"] = (Content :: any).fromUri(uri)
		end)
	end
	if not ok then
		table.insert(
			warnings,
			("could not set %s on %s (needs plugin security: run in Edit)"):format(
				prop,
				sa:GetFullName()
			)
		)
	end
end

local function makeSurface(
	name: string,
	maps: MapSet,
	alphaMode: string?,
	warnings: { string }
): SurfaceAppearance
	local sa = Instance.new("SurfaceAppearance")
	sa.Name = name
	for key, prop in MAP_PROPS do
		local id = (maps :: any)[key]
		if type(id) == "string" and id ~= "" then
			setMap(sa, prop, id, warnings)
		elseif type(id) == "number" then
			setMap(sa, prop, tostring(id), warnings)
		end
	end
	local mode = enumItem(Enum.AlphaMode, alphaMode, warnings)
	if mode then
		sa.AlphaMode = mode
	end
	return sa
end

local function maxAxis(part: BasePart): number
	local s = part.Size
	return math.max(s.X, s.Y, s.Z)
end

local function isMarkerName(name: string): boolean
	return string.sub(name, 1, 4) == "ATT_"
end

local function setStudioOnly(part: BasePart, prop: string, value: any, warnings: { string })
	if value == nil then
		return
	end
	local ok, err = pcall(function()
		(part :: any)[prop] = value
	end)
	if not ok then
		table.insert(warnings, ("%s on %s: %s"):format(prop, part.Name, tostring(err)))
	end
end

local function pickSet(partName: string, config: Config, setNames: { string }): string?
	local explicit = config.partSets and config.partSets[partName]
	if explicit then
		return explicit
	end
	if #setNames == 1 then
		return setNames[1]
	end
	local lower = string.lower(partName)
	local best: string? = nil
	for _, setName in setNames do
		if
			string.find(lower, string.lower(setName), 1, true)
			and (not best or #setName > #(best :: string))
		then
			best = setName
		end
	end
	return best
end

local function importAsset(config: Config): Report
	local warnings: { string } = {}
	local report: Report = {
		asset = config.name,
		path = "",
		parts = 0,
		meshParts = 0,
		colParts = 0,
		lodHidden = 0,
		tris = "unknown",
		surfaceAppearances = 0,
		wetVariants = 0,
		attachments = {},
		castShadowOff = 0,
		warnings = warnings,
	}
	local root = resolve(config.source)
	if not root then
		table.insert(warnings, "source not found: " .. tostring(config.source))
		return report
	end
	-- studio-insert may hand us a folder-like container or a bare MeshPart: always end with a Model.
	local model: Model
	if root:IsA("Model") then
		model = root
	else
		model = Instance.new("Model")
		model.Parent = root.Parent
		root.Parent = model
		table.insert(warnings, "source was a " .. root.ClassName .. ", wrapped in a Model")
	end
	model.Name = config.name

	local sets: { [string]: TextureSet } = config.sets or {}
	local setNames: { string } = {}
	for setName in sets do
		table.insert(setNames, setName)
	end
	table.sort(setNames)
	local tierName = config.tier or "standard"
	local renderFidelity = enumItem(
		Enum.RenderFidelity,
		config.renderFidelity or TIER_FIDELITY[tierName] or "Automatic",
		warnings
	)
	local colFidelity =
		enumItem(Enum.CollisionFidelity, config.collisionFidelity or "Hull", warnings)
	local visFidelity =
		enumItem(Enum.CollisionFidelity, config.visualCollisionFidelity or "Box", warnings)
	local anchored = if config.anchored == nil then true else config.anchored
	local small = config.smallPartSize or 1.5
	local hideLods = if config.hideLods == nil then true else config.hideLods

	-- 1. Collect markers first (they must not get SurfaceAppearances or count as parts).
	local markers: { { name: string, cf: CFrame, inst: Instance } } = {}
	local existing: { [string]: boolean } = {}
	for _, d in model:GetDescendants() do
		if isMarkerName(d.Name) then
			if d:IsA("Attachment") then
				existing[d.Name] = true
			elseif d:IsA("BasePart") then
				table.insert(markers, { name = d.Name, cf = d.CFrame, inst = d :: Instance })
			elseif d:IsA("Model") then
				table.insert(markers, { name = d.Name, cf = d:GetPivot(), inst = d :: Instance })
			elseif d:IsA("Bone") then
				table.insert(
					markers,
					{ name = d.Name, cf = d.TransformedWorldCFrame, inst = d :: Instance }
				)
			end
		end
	end
	local markerSet: { [Instance]: boolean } = {}
	for _, m in markers do
		markerSet[m.inst] = true
		for _, d in m.inst:GetDescendants() do
			markerSet[d] = true
		end
	end

	-- 2. Parts.
	local visual: { BasePart } = {}
	local primary: BasePart? = nil
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") or markerSet[d] then
			continue
		end
		local part = d :: BasePart
		report.parts += 1
		local name = part.Name
		local isCol = string.match(name, "_COL$") ~= nil or string.match(name, "_COL_%d+$") ~= nil
		local lod = string.match(name, "_LOD(%d)$")
		part.Anchored = anchored
		if isCol then
			report.colParts += 1
			part.CanCollide = true
			part.CanTouch = true
			part.CanQuery = true
			part.Transparency = 1
			part.CastShadow = false
			setStudioOnly(part, "CollisionFidelity", colFidelity, warnings)
			for _, c in part:GetChildren() do
				if c:IsA("SurfaceAppearance") then
					c:Destroy()
				end
			end
			continue
		end
		part.CanCollide = false
		part.CanTouch = false
		setStudioOnly(part, "CollisionFidelity", visFidelity, warnings)
		if maxAxis(part) < small then
			part.CastShadow = false
			report.castShadowOff += 1
		end
		if hideLods and lod and lod ~= "0" then
			part.Transparency = 1
			part.CastShadow = false
			part:SetAttribute("LodHidden", true)
			report.lodHidden += 1
		end
		if not lod or lod == "0" then
			table.insert(visual, part)
			if not primary or part.Size.Magnitude > (primary :: BasePart).Size.Magnitude then
				primary = part
			end
		end
		if part:IsA("MeshPart") then
			report.meshParts += 1
			setStudioOnly(part, "RenderFidelity", renderFidelity, warnings)
			local setName = pickSet(name, config, setNames)
			local set = setName and sets[setName]
			if not set then
				if #setNames > 0 then
					table.insert(warnings, "no texture set matched MeshPart " .. name)
				end
				continue
			end
			for _, c in part:GetChildren() do
				if
					c:IsA("SurfaceAppearance")
					or (c:IsA("Configuration") and c.Name == "SurfaceVariants")
				then
					c:Destroy()
				end
			end
			local dry = makeSurface("SurfaceAppearance", set :: any, set.alphaMode, warnings)
			dry:SetAttribute("TextureSet", setName)
			dry.Parent = part
			report.surfaceAppearances += 1
			local wet = set.Wet
			if wet and next(wet :: any) then
				-- Missing wet maps fall back to the dry ones (often only ALB and RGH change).
				local merged: MapSet = {
					ALB = wet.ALB or set.ALB,
					NOR = wet.NOR or set.NOR,
					RGH = wet.RGH or set.RGH,
					MET = wet.MET or set.MET,
				}
				local store = Instance.new("Configuration")
				store.Name = "SurfaceVariants"
				store.Parent = part
				local wetSa = makeSurface("SurfaceAppearance_Wet", merged, set.alphaMode, warnings)
				wetSa:SetAttribute("TextureSet", setName)
				wetSa.Parent = store
				part:SetAttribute("WetState", false)
				CollectionService:AddTag(part, "HasWetVariant")
				report.wetVariants += 1
			end
		end
	end
	if primary then
		model.PrimaryPart = primary
	else
		table.insert(warnings, "no visual LOD0 part found")
	end

	-- 3. Attachments (world CFrames are taken before the model moves).
	local function nearestPart(pos: Vector3, wanted: string?): BasePart?
		local byName = wanted or config.attachParent
		if byName then
			local p = model:FindFirstChild(byName, true)
			if p and p:IsA("BasePart") then
				return p
			end
			table.insert(warnings, "attach parent not found: " .. byName)
		end
		local best, bestD = nil, math.huge
		for _, p in visual do
			local local_ = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			local outside = Vector3.new(
				math.max(math.abs(local_.X) - h.X, 0),
				math.max(math.abs(local_.Y) - h.Y, 0),
				math.max(math.abs(local_.Z) - h.Z, 0)
			)
			local d = outside.Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
		return best
	end
	local function addAttachment(name: string, world: CFrame, wanted: string?)
		local host = nearestPart(world.Position, wanted)
		if not host then
			table.insert(warnings, "no part to host " .. name)
			return
		end
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = host
		a.WorldCFrame = world
		existing[name] = true
		table.insert(report.attachments, name .. " -> " .. host.Name)
	end
	for _, m in markers do
		if not existing[m.name] then
			addAttachment(m.name, m.cf)
		end
		m.inst:Destroy()
	end
	local pivot = model:GetPivot()
	local specs: { AttachmentSpec } = config.attachments or {}
	for _, spec in specs do
		if existing[spec.name] then
			continue
		end
		local p, r = spec.pos, spec.rot or { 0, 0, 0 }
		local cf = CFrame.new(p[1], p[2], p[3])
			* CFrame.fromOrientation(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		addAttachment(spec.name, pivot * cf, spec.part)
	end

	-- 4. Place it.
	local parent: Instance? = nil
	if typeof(config.parent) == "Instance" then
		parent = config.parent :: Instance
	else
		local folderName = (config.parent :: string?) or "LookDev"
		parent = workspace:FindFirstChild(folderName)
		if not parent then
			local f = Instance.new("Folder")
			f.Name = folderName
			f.Parent = workspace
			parent = f
		end
	end
	local target = config.cframe
	if typeof(target) == "CFrame" then
		model:PivotTo(target)
	elseif type(target) == "table" then
		local t = target :: { number }
		model:PivotTo(CFrame.new(t[1], t[2], t[3]) * CFrame.Angles(0, math.rad(t[4] or 0), 0))
	end
	model.Parent = parent
	model:SetAttribute("PackagePending", true) -- convert to a Package by hand; not scriptable
	model:SetAttribute("Tier", tierName)
	model:SetAttribute("ImportedBy", "tools/studio/import_asset.luau")
	CollectionService:AddTag(model, "LookDevAsset")
	report.path = model:GetFullName()
	return report
end

(_G :: any).ImportAsset = importAsset
local pending = (_G :: any).ImportAssetConfig
if type(pending) == "table" then
	(_G :: any).ImportAssetConfig = nil
	return HttpService:JSONEncode(importAsset(pending :: Config))
end
return "import_asset: _G.ImportAsset(config) installed"
