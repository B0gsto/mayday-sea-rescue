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

local A11yPalette = require(script.Parent.Parent:WaitForChild("A11yPalette"))

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
	Image = "rbxassetid://124660107845917", -- art/map/gale_isles_map.png (2048 px)
	Tiles = {
		{ "rbxassetid://104897677184387", "rbxassetid://77935366130883" }, -- r0c0, r0c1 (north)
		{ "rbxassetid://97250599507171", "rbxassetid://90317176049903" }, -- r1c0, r1c1 (south)
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

	-- Place names on the full map, drawn live by MapController at a fixed screen size (not baked
	-- into the image): a name is skipped when it would touch the legend, the title, the buttons, the
	-- Roblox top bar (GuiService:GetGuiInset) or a name earlier in this list (list order = priority).
	-- kind: region | town | place | water (italic) | street (lowest priority, zoomed in only).
	-- left = text starts at the point (else centred).
	-- tools/world/make_map_image.py --labels reads these rows (keep each on one line).
	Places = {
		{ text = "PORT HAVEN", x = -100, z = -325, kind = "town" },
		{ text = "HAVEN SANDS", x = 1080, z = 210, kind = "town" },
		{ text = "SKERRY ISLE", x = 1800, z = 1660, kind = "town" },
		{ text = "GREAT GALE", x = -1300, z = -1500, kind = "region" },
		{ text = "Calm Bay", x = 0, z = 170, kind = "water" },
		{ text = "Harbour Mouth", x = 0, z = 450, kind = "water" },
		{ text = "Harbour Light", x = 64, z = 322, kind = "place", left = true },
		{ text = "Harbour Hotel", x = 326, z = -133, kind = "place" },
		{ text = "Customs House", x = 58, z = -70, kind = "place" },
		{ text = "Chapel Square", x = 76, z = -200, kind = "place" },
		{ text = "Market Hall", x = 53, z = -239, kind = "place" },
		{ text = "West Cliff", x = -900, z = -40, kind = "place" },
		{ text = "Sandy Point", x = 560, z = 530, kind = "place" },
		{ text = "Haven Head", x = 1560, z = 560, kind = "place" },
		{ text = "Trevose Farm", x = -720, z = -870, kind = "place" },
		{ text = "Penmorvah Farm", x = 1040, z = -1130, kind = "place" },
		{ text = "Skerry Light outpost", x = 1800, z = 1850, kind = "place" },
		{ text = "The Skerries", x = 2060, z = 1380, kind = "water" },
		{ text = "West Ledges", x = -1200, z = 470, kind = "water" },
		{ text = "OPEN SEA", x = 0, z = 1900, kind = "region" },
		{ text = "Gannet Rock outpost >", x = 2150, z = 2440, kind = "water" },
		{ text = "< Tempest Point Light", x = -2150, z = 600, kind = "place" },
		{ text = "Harbour Road", x = -460, z = -30, kind = "street" },
		{ text = "Fore Street", x = -300, z = -160, kind = "street" },
		{ text = "Church Street", x = -300, z = -270, kind = "street" },
		{ text = "Trelawney Road", x = -300, z = -380, kind = "street" },
		{ text = "Bodmin Road", x = -300, z = -490, kind = "street" },
		{ text = "Penhallow Road", x = -540, z = -520, kind = "street" },
		{ text = "Quay Lane", x = -380, z = -520, kind = "street" },
		{ text = "Station Hill", x = -220, z = -520, kind = "street" },
		{ text = "Chapel Hill", x = 20, z = -560, kind = "street" },
		{ text = "Hospital Lane", x = 200, z = -520, kind = "street" },
		{ text = "Eastgate Hill", x = 380, z = -520, kind = "street" },
		{ text = "Tregenna Hill", x = 560, z = -520, kind = "street" },
	} :: { { text: string, x: number, z: number, kind: string, left: boolean? } },

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
		Casualty = {
			label = "Casualty (Mayday)",
			glyph = A11yPalette.symbol("Marker", "Casualty"),
			color = Color3.fromHex("FF3B30"),
		},
		Vessel = {
			label = "Vessel in distress",
			glyph = A11yPalette.symbol("Marker", "Vessel"),
			color = Color3.fromHex("FF8A00"),
		},
		DropOff = {
			label = "Drop-off",
			glyph = A11yPalette.symbol("Marker", "DropOff"),
			color = Color3.fromHex("3EE07A"),
		},
		Waypoint = {
			label = "Your waypoint",
			glyph = A11yPalette.symbol("Marker", "Waypoint"),
			color = Color3.fromHex("FFD60A"),
		},
		Vehicle = {
			label = "Your vehicle",
			glyph = A11yPalette.symbol("Marker", "Vehicle"),
			color = Color3.fromHex("F4F1EA"),
		},
		Crew = {
			label = "Crew",
			glyph = A11yPalette.symbol("Marker", "Crew"),
			color = Color3.fromHex("5AC8FA"),
		},
		-- the NPC rescue boat racing you to the call (client RacerController -> SetBlips("Racer", ...))
		Racer = {
			label = "Rescue boat",
			glyph = A11yPalette.symbol("Marker", "Racer"),
			color = Color3.fromHex("E8332A"),
		},
		Storm = {
			label = "Storm area",
			glyph = A11yPalette.symbol("Marker", "Storm"),
			color = Color3.fromHex("8E5BD8"),
		},
		-- seamarks (SeamarkController -> SetBlips("Seamarks", ...), small dots in the IALA colours)
		SeamarkPort = {
			label = "Port-hand mark",
			glyph = A11yPalette.symbol("Marker", "SeamarkPort"),
			color = Color3.fromHex("E0352B"),
		},
		SeamarkStarboard = {
			label = "Starboard-hand mark",
			glyph = A11yPalette.symbol("Marker", "SeamarkStarboard"),
			color = Color3.fromHex("2FB45A"),
		},
		SeamarkCardinal = {
			label = "Cardinal mark",
			glyph = A11yPalette.symbol("Marker", "SeamarkCardinal"),
			color = Color3.fromHex("F2C230"),
		},
		SeamarkSafe = {
			label = "Safe water mark",
			glyph = A11yPalette.symbol("Marker", "SeamarkSafe"),
			color = Color3.fromHex("F4F1EA"),
		},
		SeamarkDanger = {
			label = "Isolated danger mark",
			glyph = A11yPalette.symbol("Marker", "SeamarkDanger"),
			color = Color3.fromHex("1C1C1C"),
		},
	},

	-- Drop-off pads (map/Build.luau buildDropOffs): the transport step's destinations.
	DropOffs = {
		Hospital = Vector3.new(130, 0, 12),
		Dock = Vector3.new(-125, 0, 92),
	} :: { [string]: Vector3 },

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
