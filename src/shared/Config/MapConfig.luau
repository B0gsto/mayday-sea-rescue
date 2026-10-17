--!strict
-- MapConfig: the GTA-style minimap and full map (MapController). Pure data, safe in Lune.
--
-- The map texture is rendered from the terrain bake by tools/world/make_map_image.py (north up, the
-- bake's frame: rows are +Z = south). World -> UV:
--     u = (x - Origin.X) / Extent,  v = (z - Origin.Y) / Extent      (Origin = (originX, originZ))
-- 2048 px over 5,120 studs = 2.5 studs per pixel. Roblox serves images at up to 1024 px, so the game
-- draws the four 1024 px Tiles (row-major from the north-west); Image is the whole map (1024 px in game).
--
-- Global flag: ReplicatedStorage attribute UseMapWaypoints (bool, MapController sets it true on the
-- client). Any system that draws 3D guidance arrows / markers should skip them while it is true; the
-- map shows the objective instead (CONTRACT.md "Map and blips").

export type Blip = {
	id: string,
	label: string,
	glyph: string, -- a short text glyph drawn in the badge
	color: Color3,
	position: Vector3?, -- static blips
	legend: boolean?, -- listed in the full map legend
	minimap: boolean?, -- false: full map only
}

local MapConfig = {
	Image = "rbxassetid://95841555674892", -- art/map/gale_isles_map.png (2048 px)
	Tiles = {
		{ "rbxassetid://98400170280559", "rbxassetid://73720441082997" }, -- r0c0, r0c1 (north)
		{ "rbxassetid://89180774749183", "rbxassetid://101112605166784" }, -- r1c0, r1c1 (south)
	},
	ImagePixels = 2048,
	Origin = Vector2.new(-2560, -2560), -- world (x, z) of the image's top-left corner
	Extent = 5120, -- studs covered by the image on each side

	-- Minimap view radius (studs from the player to the rim), eased toward the target.
	Zoom = {
		foot = 140,
		car = { slow = 220, fast = 520, fastSpeed = 90 }, -- studs/s
		boat = { slow = 260, fast = 760, fastSpeed = 110 },
		easeSeconds = 0.8,
	},
	FullMap = { minRadius = 180, maxRadius = 2600, startRadius = 900 },

	-- Fixed places (positions from map/Build.luau and WorldConfig).
	Blips = {
		{
			id = "Station",
			label = "Lifeboat station",
			glyph = "S",
			color = Color3.fromHex("FF6B1A"),
			position = Vector3.new(-165, 4, 0),
			legend = true,
		},
		{
			id = "Chandlery",
			label = "Port Haven Chandlery (gear)",
			glyph = "$",
			color = Color3.fromHex("FFC872"),
			position = Vector3.new(-44, 4, -60),
			legend = true,
		},
		{
			id = "BoatDesk",
			label = "Quay boat desk",
			glyph = "B",
			color = Color3.fromHex("3FC1C0"),
			position = Vector3.new(-95, 4, -10),
			legend = true,
		},
		{
			id = "Hospital",
			label = "Cottage Hospital",
			glyph = "H",
			color = Color3.fromHex("2F7DE1"),
			position = Vector3.new(130, 4, -120),
			legend = true,
			minimap = false,
		},
		{
			id = "HavenSandsCarPark",
			label = "Haven Sands car park",
			glyph = "P",
			color = Color3.fromHex("2F7DE1"),
			position = Vector3.new(880, 14.7, 115),
			legend = true,
		},
		{
			id = "HavenSandsTower",
			label = "Haven Sands lifeguard tower",
			glyph = "T",
			color = Color3.fromHex("E8D44D"),
			position = Vector3.new(1010, 3.8, 250),
			legend = true,
			minimap = false,
		},
	} :: { Blip },

	-- Dynamic blip styles (positions come from the operation, vehicles and players).
	Styles = {
		Casualty = { label = "Casualty (Mayday)", glyph = "!", color = Color3.fromHex("FF3B30") },
		Vessel = { label = "Vessel in distress", glyph = "!", color = Color3.fromHex("FF8A00") },
		DropOff = { label = "Drop-off", glyph = "D", color = Color3.fromHex("3EE07A") },
		Waypoint = { label = "Your waypoint", glyph = "W", color = Color3.fromHex("FFD60A") },
		Vehicle = { label = "Your vehicle", glyph = "V", color = Color3.fromHex("F4F1EA") },
		Crew = { label = "Crew", glyph = "C", color = Color3.fromHex("5AC8FA") },
		Storm = { label = "Storm area", glyph = "", color = Color3.fromHex("8E5BD8") },
	},

	-- Drop-off pads (map/Build.luau buildDropOffs): the transport step's destinations.
	DropOffs = {
		Hospital = Vector3.new(130, 0, 12),
		Dock = Vector3.new(-125, 0, 92),
	},

	-- Weather has no positional storm yet: while the State is Warning / Storm / Clearing the exposed
	-- open sea beyond the breakwater is shaded. CONTRACT (storm stream): set ReplicatedStorage.Weather
	-- attributes StormCenter (Vector3) and StormRadius (number) and the map uses those instead.
	StormAreas = {
		{ center = Vector3.new(0, 0, 1650), radius = 1250 },
	},
}

function MapConfig.worldToUV(x: number, z: number): (number, number)
	return (x - MapConfig.Origin.X) / MapConfig.Extent, (z - MapConfig.Origin.Y) / MapConfig.Extent
end

function MapConfig.uvToWorld(u: number, v: number): (number, number)
	return MapConfig.Origin.X + u * MapConfig.Extent, MapConfig.Origin.Y + v * MapConfig.Extent
end

-- World offset (dx, dz) -> minimap screen offset in studs (+x right, +y down) for a view whose
-- "up" is the horizontal forward vector (fx, fz) (unit).
function MapConfig.toView(dx: number, dz: number, fx: number, fz: number): (number, number)
	-- right = (-fz, fx); screen y down = -(d . forward)
	return dx * -fz + dz * fx, -(dx * fx + dz * fz)
end

-- Clamp a screen offset to a circle of radius r. Returns x, y and whether it was clamped.
function MapConfig.clampToRim(x: number, y: number, r: number): (number, number, boolean)
	local m = math.sqrt(x * x + y * y)
	if m <= r then
		return x, y, false
	end
	return x / m * r, y / m * r, true
end

-- Minimap view radius for a speed (studs/s) and mode ("foot" | "car" | "boat").
function MapConfig.zoomFor(mode: string, speed: number): number
	local z = MapConfig.Zoom
	if mode == "foot" then
		return z.foot
	end
	local spec = if mode == "car" then z.car else z.boat
	local t = math.clamp(speed / spec.fastSpeed, 0, 1)
	t = t * t * (3 - 2 * t)
	return spec.slow + (spec.fast - spec.slow) * t
end

return MapConfig
