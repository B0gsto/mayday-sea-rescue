-- Build-time greybox map, run by tools/build-map.luau under Lune (NOT shipped as a script).
-- Called as build(game, ctx); ctx.require loads shared modules (GameConfig) through the require shim.
-- Globals: Instance, Vector3, CFrame, Color3, Enum, game, workspace.
-- Lune limits: no physics, no Terrain editing, no Model:PivotTo. New Parts default to Studs
-- surfaces and Anchored = false, so the part() helper sets both.
--
-- Builds Workspace.Map (sea level Y = 0, no water yet: a mesh ocean comes later):
--   OceanFloor   sand base, top at Y = -40 (4 tiles of 2048 studs)
--   PortHaven    land, quay, station, dock with launch bays Bay1..Bay4, hospital, houses, hill
--   DropOffs     DropOff_Hospital, DropOff_Dock (water-level pads, attribute DropOff)
--   Breakwater   two arms enclosing Calm Bay; the 60-stud gap is Harbour Mouth
--   Beach        sloped sand inside the breakwater (east side)
--   HarbourLight lighthouse greybox on the east breakwater head
-- and Workspace.Zones (invisible, non-collide cylinders with attribute Zone = "<id>", from GameConfig).
-- Spawn is on the quay.

local SMOOTH = Enum.SurfaceType.Smooth
local M = Enum.Material

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local COLORS = {
	sand = rgb(214, 196, 150),
	seabed = rgb(150, 140, 110),
	grass = rgb(106, 140, 82),
	concrete = rgb(170, 170, 165),
	stone = rgb(120, 120, 118),
	wood = rgb(120, 90, 60),
	white = rgb(236, 236, 230),
	red = rgb(196, 48, 40),
	roof = rgb(70, 72, 80),
	bay = rgb(255, 200, 40),
	dropoff = rgb(60, 200, 110),
	glass = rgb(255, 240, 180),
}
local HOUSE_COLORS = {
	rgb(226, 120, 96),
	rgb(240, 200, 110),
	rgb(110, 160, 200),
	rgb(150, 200, 160),
	rgb(230, 230, 220),
	rgb(200, 140, 180),
}

local function part(props: { [string]: any }): Part
	local className = props.ClassName or "Part"
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Material = M.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" and key ~= "Attributes" then
			p[key] = value
		end
	end
	if props.Attributes then
		for name, value in props.Attributes do
			p:SetAttribute(name, value)
		end
	end
	p.Parent = props.Parent
	return p
end

-- A box given its min and max corners (handy for greybox layout).
local function box(
	parent: Instance,
	name: string,
	min: Vector3,
	max: Vector3,
	color: Color3,
	material: any?
): Part
	return part({
		Name = name,
		Size = max - min,
		CFrame = CFrame.new((min + max) / 2),
		Color = color,
		Material = material or M.SmoothPlastic,
		Parent = parent,
	})
end

local function folder(parent: Instance, name: string, className: string?): Instance
	local f = Instance.new(className or "Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function buildOceanFloor(map: Instance, floorY: number)
	local model = folder(map, "OceanFloor", "Model")
	local tile = 2048
	for ix = -1, 0 do
		for iz = -1, 0 do
			part({
				Name = "OceanFloor",
				Size = Vector3.new(tile, 4, tile),
				CFrame = CFrame.new((ix + 0.5) * tile, floorY - 2, (iz + 0.5) * tile),
				Color = COLORS.seabed,
				Material = M.Sand,
				Parent = model,
			})
		end
	end
end

local function buildHouse(
	parent: Instance,
	name: string,
	base: Vector3,
	size: Vector3,
	color: Color3
)
	local model = folder(parent, name, "Model")
	box(
		model,
		"Body",
		base - Vector3.new(size.X / 2, 0, size.Z / 2),
		base + Vector3.new(size.X / 2, size.Y, size.Z / 2),
		color
	)
	-- gable roof: two wedges back to back along X
	local roofH = size.X * 0.35
	local top = base.Y + size.Y
	for side = -1, 1, 2 do
		part({
			ClassName = "WedgePart",
			Name = "Roof",
			Size = Vector3.new(size.Z + 1, roofH, size.X / 2 + 0.5),
			CFrame = CFrame.new(base.X + side * (size.X / 4 + 0.25), top + roofH / 2, base.Z)
				* CFrame.Angles(0, side * math.pi / 2, 0),
			Color = COLORS.roof,
			Parent = model,
		})
	end
	box(
		model,
		"Door",
		base + Vector3.new(-1.5, 0, size.Z / 2),
		base + Vector3.new(1.5, 7, size.Z / 2 + 0.2),
		COLORS.wood
	)
end

local function buildPortHaven(map: Instance, landTop: number, floorY: number)
	local town = folder(map, "PortHaven", "Model")
	-- land the town sits on (north of the quay) and a hill behind it
	box(
		town,
		"Land",
		Vector3.new(-600, floorY, -500),
		Vector3.new(600, landTop, -20),
		COLORS.grass,
		M.Grass
	)
	box(
		town,
		"Hill",
		Vector3.new(-600, landTop, -500),
		Vector3.new(600, landTop + 30, -360),
		COLORS.grass,
		M.Grass
	)
	part({
		ClassName = "WedgePart",
		Name = "HillSlope",
		Size = Vector3.new(1200, 30, 60),
		-- tall side toward -Z (the hill), sloping down toward the town
		CFrame = CFrame.new(0, landTop + 15, -330) * CFrame.Angles(0, math.pi, 0),
		Color = COLORS.grass,
		Material = M.Grass,
		Parent = town,
	})

	-- quay: concrete harbour front, z -20..4
	box(
		town,
		"Quay",
		Vector3.new(-180, floorY, -20),
		Vector3.new(180, landTop, 4),
		COLORS.concrete,
		M.Concrete
	)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "QuaySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = SMOOTH
	spawn.BottomSurface = SMOOTH
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(-60, landTop + 0.5, -8)
	spawn.Color = COLORS.white
	spawn.Material = M.SmoothPlastic
	spawn.Parent = town

	-- coast guard station by the dock
	local station = folder(town, "Station", "Model")
	box(
		station,
		"Building",
		Vector3.new(-140, landTop, -90),
		Vector3.new(-80, landTop + 24, -40),
		COLORS.white
	)
	box(
		station,
		"Roof",
		Vector3.new(-142, landTop + 24, -92),
		Vector3.new(-78, landTop + 26, -38),
		COLORS.red
	)
	box(
		station,
		"Doors",
		Vector3.new(-120, landTop, -40),
		Vector3.new(-100, landTop + 14, -39.6),
		COLORS.red
	)
	box(
		station,
		"Tower",
		Vector3.new(-90, landTop + 26, -60),
		Vector3.new(-80, landTop + 40, -50),
		COLORS.white
	)

	-- dock: a pier from the quay out into Calm Bay, deck at Y = 3
	local dock = folder(town, "Dock", "Model")
	box(dock, "Deck", Vector3.new(-118, 2, 4), Vector3.new(-102, 3, 104), COLORS.wood, M.WoodPlanks)
	for z = 14, 104, 18 do
		for _, x in { -117, -103 } do
			part({
				Name = "Piling",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2 - floorY + 2, 1.6, 1.6),
				CFrame = CFrame.new(x, (2 + floorY) / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				Color = COLORS.wood,
				Material = M.Wood,
				Parent = dock,
			})
		end
	end
	-- launch bays on the east side of the dock, on the water, facing out to sea (+Z)
	for i = 1, 4 do
		local z = 4 + i * 22 - 8
		part({
			Name = `Bay{i}`,
			Size = Vector3.new(12, 0.4, 18),
			CFrame = CFrame.new(-95, 0.2, z) * CFrame.Angles(0, math.pi, 0),
			Color = COLORS.bay,
			Transparency = 0.6,
			CanCollide = false,
			CanTouch = false,
			Parent = dock,
			Attributes = { LaunchBay = true, BayIndex = i, AllowedVehicles = "JetSki,RIB" },
		})
		box(
			dock,
			`Bay{i}Bollard`,
			Vector3.new(-102.5, 3, z - 0.5),
			Vector3.new(-101.5, 4.5, z + 0.5),
			COLORS.bay
		)
	end

	-- hospital up from the quay, east side, with an ambulance bay on the quay
	local hospital = folder(town, "Hospital", "Model")
	box(
		hospital,
		"Building",
		Vector3.new(100, landTop, -140),
		Vector3.new(160, landTop + 20, -100),
		COLORS.white
	)
	box(
		hospital,
		"CrossV",
		Vector3.new(127, landTop + 8, -99.8),
		Vector3.new(133, landTop + 18, -99.4),
		COLORS.red
	)
	box(
		hospital,
		"CrossH",
		Vector3.new(125, landTop + 11, -99.8),
		Vector3.new(135, landTop + 15, -99.4),
		COLORS.red
	)
	box(
		hospital,
		"Ambulance",
		Vector3.new(124, landTop, -14),
		Vector3.new(136, landTop + 6, -6),
		COLORS.white
	)

	local houses = folder(town, "Houses")
	local spots = {
		Vector3.new(-40, landTop, -150),
		Vector3.new(10, landTop, -170),
		Vector3.new(60, landTop, -150),
		Vector3.new(-200, landTop, -140),
		Vector3.new(220, landTop, -160),
		Vector3.new(-30, landTop, -250),
	}
	for i, spot in spots do
		buildHouse(
			houses,
			`House{i}`,
			spot,
			Vector3.new(18 + (i % 3) * 4, 12 + (i % 2) * 6, 16),
			HOUSE_COLORS[i]
		)
	end

	return town
end

local function buildDropOffs(map: Instance)
	local drop = folder(map, "DropOffs")
	part({
		Name = "DropOff_Hospital",
		Size = Vector3.new(24, 0.4, 16),
		CFrame = CFrame.new(130, 0.2, 12),
		Color = COLORS.dropoff,
		Transparency = 0.5,
		CanCollide = false,
		Parent = drop,
		Attributes = { DropOff = "Hospital" },
	})
	part({
		Name = "DropOff_Dock",
		Size = Vector3.new(12, 0.4, 20),
		CFrame = CFrame.new(-125, 0.2, 92),
		Color = COLORS.dropoff,
		Transparency = 0.5,
		CanCollide = false,
		Parent = drop,
		Attributes = { DropOff = "Dock" },
	})
end

local function buildBreakwater(map: Instance, floorY: number, mouthHalf: number)
	local wall = folder(map, "Breakwater", "Model")
	local top, w, far = 6, 16, 360
	for side = -1, 1, 2 do
		local tag = if side < 0 then "West" else "East"
		local x = side * 320
		box(
			wall,
			`{tag}Arm`,
			Vector3.new(x - w / 2, floorY, -20),
			Vector3.new(x + w / 2, top, far + w / 2),
			COLORS.stone,
			M.Slate
		)
		local inner, outer = side * mouthHalf, x
		box(
			wall,
			`{tag}Head`,
			Vector3.new(math.min(inner, outer), floorY, far - w / 2),
			Vector3.new(math.max(inner, outer), top, far + w / 2),
			COLORS.stone,
			M.Slate
		)
	end
	return top, far
end

local function buildBeach(map: Instance, landTop: number)
	local beach = folder(map, "Beach", "Model")
	-- sand slopes from the land edge (z = -20, Y = landTop) down under the water toward +Z
	part({
		ClassName = "WedgePart",
		Name = "Sand",
		Size = Vector3.new(128, landTop + 8, 120),
		CFrame = CFrame.new(248, (landTop - 8) / 2, 40) * CFrame.Angles(0, math.pi, 0),
		Color = COLORS.sand,
		Material = M.Sand,
		Parent = beach,
	})
	box(
		beach,
		"LifeguardHut",
		Vector3.new(230, landTop, -60),
		Vector3.new(242, landTop + 9, -50),
		COLORS.red
	)
end

local function buildLighthouse(map: Instance, base: Vector3)
	local lh = folder(map, "HarbourLight", "Model")
	local segment = 10
	for i = 0, 3 do
		part({
			Name = `Tower{i + 1}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segment, 10 - i, 10 - i),
			CFrame = CFrame.new(base + Vector3.new(0, segment * (i + 0.5), 0))
				* CFrame.Angles(0, 0, math.pi / 2),
			Color = if i % 2 == 0 then COLORS.white else COLORS.red,
			Parent = lh,
		})
	end
	local lampY = base.Y + segment * 4
	local lamp = box(
		lh,
		"Lantern",
		base + Vector3.new(-3, segment * 4, -3),
		base + Vector3.new(3, segment * 4 + 6, 3),
		COLORS.glass,
		M.Neon
	)
	lamp.Transparency = 0.2
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2
	light.Color = COLORS.glass
	light.Parent = lamp
	box(
		lh,
		"Cap",
		base + Vector3.new(-4, segment * 4 + 6, -4),
		Vector3.new(base.X + 4, lampY + 8, base.Z + 4),
		COLORS.red
	)
end

local function buildZones(zonesFolder: Instance, zones: { any })
	for _, zone in zones do
		local height = 400
		part({
			Name = zone.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, zone.radius * 2, zone.radius * 2),
			CFrame = CFrame.new(zone.center) * CFrame.Angles(0, 0, math.pi / 2),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = zonesFolder,
			Attributes = {
				Zone = zone.id,
				DisplayName = zone.displayName,
				Radius = zone.radius,
				Shelter = zone.shelter,
				Priority = zone.priority,
			},
		})
	end
end

return function(place: any, ctx: any)
	local GameConfig = ctx.require("Config/GameConfig")
	local ws = place:GetService("Workspace")
	local landTop, floorY = GameConfig.LandTopY, GameConfig.OceanFloorY

	ws:SetAttribute("SeaLevel", GameConfig.SeaLevel)
	local map = folder(ws, "Map")
	buildOceanFloor(map, floorY)
	buildPortHaven(map, landTop, floorY)
	buildDropOffs(map)
	local wallTop, wallFar = buildBreakwater(map, floorY, 30)
	buildBeach(map, landTop)
	buildLighthouse(map, Vector3.new(44, wallTop, wallFar))
	buildZones(folder(ws, "Zones"), GameConfig.Zones)
end
