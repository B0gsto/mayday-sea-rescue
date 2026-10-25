--!strict
-- ScatterController (I1 perf pass): draws the K1 rocks and G1 plants of map/generated/props.json locally.
--   * LOD by camera distance per CELL x CELL cell (nearest point of the cell): LOD0 < LOD1_AT, LOD1 < LOD2_AT,
--     LOD2 out to the draw distance, nothing beyond; rocks switch sooner (TIERS rock1 / rock2 / rockDraw);
--     landmark rocks (rock row column 10 = 1: the scaled-up cliff faces and top ledges of the cliff dressing pass)
--     get their own cells, switch LOD at twice the rock distances and draw out to TIERS cliffDraw;
--   * density by graphics quality (UserGameSettings.SavedQualityLevel; Automatic and touch-only devices use the
--     medium tier; the settings panel's "scatterQuality" override wins over both): rows flagged "seen" by scatter_props.py (roads, paths, beaches, viewpoints) go first;
--   * the server keeps only the rocks' invisible collision hulls (WorldDressingService); these local copies are
--     not replicated and not streamed, so StreamingEnabled has nothing to send for the meshes.
--   * wet state: in a storm (Weather Storm / Clearing) or a wet look-dev shot (Lighting LookDevWet) every cell is
--     rebuilt with each part's SurfaceAppearance_Wet (the templates keep AssetLoader's SurfaceVariants), so the
--     plants darken with the wet sand instead of dissolving into it.
-- Workspace.ScatterLocal attributes: ScatterTier, ScatterRows (drawn), ScatterTris (estimated, drawn now), ScatterWet.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))

local ScatterController = {}
ScatterController.Priority = 150

local CELL = 96
local LOD1_AT = 120
local LOD2_AT = 300
local BUILD_BUDGET = 60 -- rows cloned per frame at most
local TICK = 0.3

-- tier -> plant share kept where seen / elsewhere, plant draw distance, rock LOD1 / LOD2 / draw distances
-- (rocks are 2.5k-9.8k triangle scans: they drop to LOD1 sooner than the plants)
-- RP-P1: Haven Sands at the old medium caps drew about 1.0M scatter triangles; these numbers bring
-- that under about 0.6M without thinning the roads and viewpoints (`seen` rows stay first).
local TIERS = {
	low = {
		seen = 0.45,
		filler = 0.12,
		draw = 240,
		rock1 = 45,
		rock2 = 140,
		rockDraw = 700,
		cliffDraw = 1300,
	},
	medium = {
		seen = 0.8,
		filler = 0.3,
		draw = 360,
		rock1 = 60,
		rock2 = 160,
		rockDraw = 900,
		cliffDraw = 1800,
	},
	high = {
		seen = 1.0,
		filler = 1.0,
		draw = 650,
		rock1 = 80,
		rock2 = 200,
		rockDraw = 1200,
		cliffDraw = 2600,
	},
}

-- LOD0 / LOD1 / LOD2 triangles per asset (assets/review/*_report.json, art/status/K1.csv; rocks 1 / 0.4 / 0.15)
local TRIS: { [string]: { number } } = {
	M_Veg_Grass_Turf_01 = { 1056, 332, 100 },
	M_Veg_Grass_Turf_02 = { 1056, 304, 88 },
	M_Veg_Grass_Marram_01 = { 1016, 432, 112 },
	M_Veg_Grass_Marram_02 = { 1016, 392, 88 },
	M_Veg_Gorse_01 = { 5230, 2178, 1106 },
	M_Veg_Gorse_02 = { 5230, 2178, 1130 },
	M_Veg_Gorse_03 = { 5230, 2054, 1078 },
	M_Veg_Heather_01 = { 1840, 452, 220 },
	M_Veg_Heather_02 = { 1840, 468, 232 },
	M_Veg_Heather_03 = { 1840, 472, 236 },
	M_Veg_SeaThrift_01 = { 752, 196, 88 },
	M_Veg_SeaThrift_02 = { 752, 188, 116 },
	M_Veg_Bracken_01 = { 1472, 660, 424 },
	M_Veg_Bracken_02 = { 1472, 640, 416 },
	M_Veg_Hawthorn_01 = { 1558, 608, 312 },
	M_Veg_Hawthorn_02 = { 1364, 584, 282 },
	M_Veg_Strand_Shells_01 = { 320, 144, 25 },
	M_Veg_Strand_Wrack_01 = { 280, 84, 32 },
	M_Veg_Strand_Driftwood_01 = { 245, 99, 30 },
	M_Veg_Strand_Pebbles_01 = { 310, 147, 75 },
}
local ROCK_TRIS: { [string]: number } = {
	M_Rock_Boulder_01 = 4000,
	M_Rock_Boulder_02 = 2500,
	M_Rock_Boulder_03 = 2500,
	M_Rock_Boulder_04 = 4000,
	M_Rock_Boulder_05 = 6000,
	M_Rock_Boulder_06 = 6000,
	M_Rock_Cliff_01 = 9500,
	M_Rock_Cliff_02 = 8999,
	M_Rock_Cliff_03 = 9500,
	M_Rock_Cliff_04 = 9500,
	M_Rock_Cliff_05 = 9800,
	M_Rock_Ledge_01 = 7799,
	M_Rock_Ledge_02 = 7800,
	M_Rock_Ledge_03 = 5999,
}
for name, t in ROCK_TRIS do
	TRIS[name] = { t, math.floor(t * 0.4), math.floor(t * 0.15) }
end

type Row = { number }
type Item = {
	asset: string,
	cf: CFrame,
	scale: number,
	keep: number,
	seen: boolean,
	rock: boolean,
	landmark: boolean,
}
type Cell =
	{ min: Vector2, max: Vector2, items: { Item }, lod: number, model: Model?, tris: number }

local templates: Folder? = nil
local cells: { Cell } = {}
local holder: Model? = nil
local tier = TIERS.high
local tierName = "high"
local wet = false
local Weather: any = nil

local function wetNow(): boolean
	if Lighting:GetAttribute("LookDevWet") == true then
		return true
	end
	if not Weather then
		return false
	end
	local ok, s = pcall(Weather.getState)
	return ok and (s == "Storm" or s == "Clearing")
end

-- a clone's parts wear their wet (or dry) SurfaceAppearance
local function applyWet(root: Instance)
	if not wet then
		return
	end
	for _, d in root:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local variants = d:FindFirstChild("SurfaceVariants")
		local stored = variants and variants:FindFirstChild("SurfaceAppearance_Wet")
		local active = d:FindFirstChildWhichIsA("SurfaceAppearance")
		if variants and stored and active then
			active.Name = "SurfaceAppearance_Dry"
			active.Parent = variants
			stored.Name = "SurfaceAppearance"
			stored.Parent = d
		end
	end
end

local function hash01(i: number): number
	local x = math.sin(i * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

local function pickTier(): string
	-- Studio perf runs (RP-P1) force a tier through Workspace.PerfQuality; never read outside Studio.
	if RunService:IsStudio() then
		local forced = Workspace:GetAttribute("PerfQuality")
		if forced == "High" or forced == "Medium" or forced == "Low" then
			return string.lower(forced)
		end
	end
	local override = Comfort.get("scatterQuality")
	if override == "High" or override == "Medium" or override == "Low" then
		return string.lower(override)
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	local n = if ok and type(level) == "number" then level else 0
	local name = if n == 0
		then "medium"
		elseif n <= 3 then "low"
		elseif n <= 7 then "medium"
		else "high"
	if
		UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and name == "high"
	then
		name = "medium" -- phones and tablets
	end
	return name
end

local function template(asset: string, lod: number): Model?
	local f = templates
	local m = f and f:FindFirstChild(`{asset}_LOD{lod - 1}`)
	return if m and m:IsA("Model") then m else nil
end

local function itemFor(asset: string, row: Row, rock: boolean, index: number): Item?
	local base = template(asset, 1)
	if not base then
		return nil
	end
	local x, y, z, yaw, tx, tz, s, b =
		row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9]
	s = s or 1
	local minY = (base:GetAttribute("BaseMinY") :: number?) or 0
	local sizeY = (base:GetAttribute("BaseSizeY") :: number?) or 0
	local water = (base:GetAttribute("WaterlineY") :: number?) or 0
	local lift = if b and b < 0 then -water * s else -minY * s - (b or 0) * sizeY * s
	local cf = CFrame.new(x, y + lift, z)
		* CFrame.Angles(math.rad(tx or 0), 0, math.rad(tz or 0))
		* CFrame.Angles(0, math.rad(yaw or 0), 0)
	return {
		asset = asset,
		cf = cf,
		scale = s,
		keep = hash01(index),
		seen = rock or row[10] == 1,
		rock = rock,
		landmark = rock and row[10] == 1,
	}
end

local function wanted(item: Item): boolean
	if item.rock then
		return true
	end
	return item.keep < (if item.seen then tier.seen else tier.filler)
end

-- kind: "p" plants, "r" rocks, "c" landmark rocks (cliff faces)
local function desiredLod(cell: Cell, cam: Vector3, kind: string): number
	local p = Vector2.new(cam.X, cam.Z)
	local q = p:Max(cell.min):Min(cell.max)
	local d = (p - q).Magnitude
	local l1, l2, draw = LOD1_AT, LOD2_AT, tier.draw
	if kind == "r" then
		l1, l2, draw = tier.rock1, tier.rock2, tier.rockDraw
	elseif kind == "c" then
		l1, l2, draw = tier.rock1 * 2, tier.rock2 * 2, tier.cliffDraw
	end
	if d < l1 then
		return 1
	elseif d < l2 then
		return 2
	elseif d < draw then
		return 3
	end
	return 0
end

local function build(cell: Cell, lod: number): number
	if cell.model then
		cell.model:Destroy()
		cell.model = nil
	end
	cell.lod = lod
	cell.tris = 0
	if lod == 0 then
		return 0
	end
	local m = Instance.new("Model")
	m.Name = "Cell"
	local used = 0
	for _, item in cell.items do
		if wanted(item) then
			local t = template(item.asset, lod)
			if t then
				local c = t:Clone()
				if math.abs(item.scale - 1) > 1e-3 then
					c:ScaleTo(item.scale)
				end
				c:PivotTo(item.cf)
				applyWet(c)
				for _, d in c:GetChildren() do
					d.Parent = m
				end
				c:Destroy()
				cell.tris += TRIS[item.asset] and TRIS[item.asset][lod] or 0
				used += 1
			end
		end
	end
	m.Parent = holder
	cell.model = m
	return math.max(used, 1)
end

local function stats()
	local rows, tris = 0, 0
	for _, c in cells do
		if c.model then
			tris += c.tris
			for _, item in c.items do
				if wanted(item) then
					rows += 1
				end
			end
		end
	end
	if holder then
		holder:SetAttribute("ScatterTier", tierName)
		holder:SetAttribute("ScatterRows", rows)
		holder:SetAttribute("ScatterTris", tris)
		holder:SetAttribute("ScatterWet", wet)
	end
end

function ScatterController.Init() end

function ScatterController.Start()
	local data = ReplicatedStorage:WaitForChild("WorldPlacements", 60)
	local folder = ReplicatedStorage:WaitForChild("ScatterTemplates", 180)
	if not (data and data:IsA("ModuleScript") and folder and folder:IsA("Folder")) then
		warn("[Scatter] WorldPlacements / ScatterTemplates missing; no rocks or plants drawn")
		return
	end
	-- The folder arrives before all its templates (and their parts) have replicated: wait for the full set,
	-- or itemFor drops every row whose template is not in yet (whole regions went undrawn).
	local function complete(): boolean
		local count = folder:GetAttribute("Count") :: number?
		local kids = folder:GetChildren()
		if not count or #kids < count then
			return false
		end
		for _, m in kids do
			local want = m:GetAttribute("Parts") :: number?
			if want then
				local n = 0
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						n += 1
					end
				end
				if n < want then
					return false
				end
			end
		end
		return true
	end
	local t0 = os.clock()
	while not complete() and os.clock() - t0 < 60 do
		task.wait(0.2)
	end
	if not complete() then
		warn(
			`[Scatter] only {#folder:GetChildren()} of {folder:GetAttribute("Count")} templates replicated`
		)
	end
	templates = folder
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local wm = shared and shared:FindFirstChild("Weather")
	if wm and wm:IsA("ModuleScript") then
		local ok, mod = pcall(require, wm)
		Weather = if ok then mod else nil
	end
	wet = wetNow()
	local props = (require :: any)(data)
	tierName = pickTier()
	tier = TIERS[tierName]
	local h = Instance.new("Model")
	h.Name = "ScatterLocal"
	h.Parent = Workspace
	holder = h
	local byKey: { [string]: Cell } = {}
	local function add(rows: { Row }, rock: boolean, offset: number)
		for i, row in rows do
			local asset = props.assets[row[1]]
			local item = asset and itemFor(asset, row, rock, i + offset)
			if item then
				local cx, cz = math.floor(row[2] / CELL), math.floor(row[4] / CELL)
				local kind = if item.landmark then "c" elseif rock then "r" else "p"
				local key = `{kind}{cx}_{cz}`
				local found = byKey[key]
				local cell: Cell
				if found then
					cell = found
				else
					cell = {
						min = Vector2.new(cx * CELL, cz * CELL),
						max = Vector2.new((cx + 1) * CELL, (cz + 1) * CELL),
						items = {},
						lod = 0,
						model = nil,
						tris = 0,
					}
					byKey[key] = cell
					table.insert(cells, cell)
				end
				table.insert(cell.items, item)
			end
		end
	end
	add(props.rocks or {}, true, 0)
	add(props.plants or {}, false, 100000)
	local cellKind: { [Cell]: string } = {}
	for key, c in byKey do
		cellKind[c] = string.sub(key, 1, 1)
	end
	local function retier()
		local n = pickTier()
		if n ~= tierName then
			tierName, tier = n, TIERS[n]
			for _, c in cells do
				c.lod = -1 -- rebuild everything at the new density
			end
		end
	end
	pcall(function()
		local gs = UserSettings():GetService("UserGameSettings")
		gs:GetPropertyChangedSignal("SavedQualityLevel"):Connect(retier)
	end)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("PerfQuality"):Connect(retier)
	end
	Comfort.changed:Connect(function(key: string)
		if key == "scatterQuality" then
			retier()
		end
	end)
	print(`[Scatter] {#cells} cells, tier {tierName}`)
	while h.Parent do
		local nowWet = wetNow()
		if nowWet ~= wet then
			wet = nowWet
			for _, c in cells do
				c.lod = -1 -- rebuild everything with the other surface set
			end
		end
		local cam = Workspace.CurrentCamera
		if cam then
			local pos = cam.CFrame.Position
			local work: { { cell: Cell, lod: number, d: number } } = {}
			for _, c in cells do
				local want = desiredLod(c, pos, cellKind[c])
				if want ~= c.lod then
					local mid = (c.min + c.max) / 2
					table.insert(
						work,
						{ cell = c, lod = want, d = (Vector2.new(pos.X, pos.Z) - mid).Magnitude }
					)
				end
			end
			table.sort(work, function(a, b)
				return a.d < b.d
			end)
			local spent = 0
			for _, w in work do
				spent += build(w.cell, w.lod)
				if spent >= BUILD_BUDGET then
					task.wait()
					spent = 0
				end
			end
			if #work > 0 then
				stats()
			end
		end
		task.wait(TICK)
	end
end

return ScatterController
