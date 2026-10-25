--!strict
-- MapConfig: the GTA-style minimap and full map (MapController). Pure data, safe in Lune.
--
-- The map texture is rendered from the terrain bake by tools/world/make_map_image.py (north up, the
-- bake's frame: rows are +Z = south). World -> UV:
--     u = (x - Origin.X) / Extent,  v = (z - Origin.Y) / Extent      (Origin = (originX, originZ))
-- docs/21 archipelago: 4,096 px over 14,336 studs (+-7,168) = 3.5 studs per pixel. Roblox serves images at up to
-- 1024 px, so the game draws 4 x 4 Tiles of 1024 px (row-major from the north-west); Image is unused.
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
	-- art/map/v2/gale_isles_map_r{row}c{col}.png (4 x 4, 1024 px each)
	Tiles = {
		{
			"rbxassetid://95526658035291",
			"rbxassetid://95526658035291",
			"rbxassetid://95526658035291",
			"rbxassetid://95526658035291",
		},
		{
			"rbxassetid://75289648010182",
			"rbxassetid://110253475621165",
			"rbxassetid://70720791673889",
			"rbxassetid://78356896818176",
		},
		{
			"rbxassetid://81980404591265",
			"rbxassetid://111469955975911",
			"rbxassetid://95196954911349",
			"rbxassetid://105398316841725",
		},
		{
			"rbxassetid://112341694227254",
			"rbxassetid://108691236646560",
			"rbxassetid://73085595369325",
			"rbxassetid://100758580068795",
		},
	},
	ImagePixels = 4096,
	Origin = Vector2.new(-7168, -7168), -- world (x, z) of the image's top-left corner
	Extent = 14336, -- studs covered by the image on each side

	-- Minimap view radius (studs from the player to the rim), eased toward the target.
	Zoom = {
		foot = 140,
		boat = { slow = 260, fast = 760, fastSpeed = 110 }, -- studs/s
		easeSeconds = 0.8,
	},
	FullMap = { minRadius = 180, maxRadius = 7000, startRadius = 900 },

	-- Place names on the full map, drawn live by MapController at a fixed screen size (not baked
	-- into the image): a name is skipped when it would touch the legend, the title, the buttons, the
	-- Roblox top bar (GuiService:GetGuiInset) or a name earlier in this list (list order = priority).
	-- kind: region | town | place | water (italic) | street (lowest priority, zoomed in only).
	-- left = text starts at the point (else centred).
	-- tools/world/make_map_image.py --labels reads these rows (keep each on one line).
	Places = {
		{ text = "COASTGUARD HUB", x = 0, z = -120, kind = "town" },
		{ text = "SKERRY ISLE", x = 1800, z = 1660, kind = "town" },
		{ text = "PUFFIN ISLE", x = -2600, z = 3400, kind = "town" },
		{ text = "PENWYN", x = -4800, z = -300, kind = "town" },
		{ text = "WRECK REEF", x = -3800, z = 4200, kind = "town" },
		{ text = "THE ARCHES", x = 5300, z = -200, kind = "town" },
		{ text = "GANNET ROCK", x = 3500, z = 3500, kind = "town" },
		{ text = "MERMAID LAGOON", x = 300, z = 5600, kind = "town" },
		{ text = "Skerry Light outpost", x = 1800, z = 1850, kind = "place" },
		{ text = "The Skerries", x = 2060, z = 1380, kind = "water" },
		{ text = "OPEN SEA", x = 0, z = 1900, kind = "region" },
	} :: { { text: string, x: number, z: number, kind: string, left: boolean? } },

	-- Fixed places (HubLayout.Hub.lots.HQ).
	Blips = {
		{
			id = "Station",
			label = "Coastguard HQ",
			glyph = "S",
			color = Color3.fromHex("FF6B1A"),
			position = Vector3.new(0, 4, 205), -- HubLayout.Hub.lots.HQ (the lookout hut)
			legend = true,
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
		Quest = {
			label = "Your quest",
			glyph = A11yPalette.symbol("Marker", "Quest"),
			color = Color3.fromHex("FFC428"),
		},
		Home = {
			label = "Your dock",
			glyph = A11yPalette.symbol("Marker", "Home"),
			color = Color3.fromHex("FF9F0A"),
		},
		Crew = {
			label = "Crew",
			glyph = A11yPalette.symbol("Marker", "Crew"),
			color = Color3.fromHex("5AC8FA"),
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

	-- Weather has no positional storm yet: while the State is Warning / Storm / Clearing the exposed
	-- open sea south of the hub is shaded. CONTRACT (storm stream): set ReplicatedStorage.Weather
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

-- Minimap view radius for a speed (studs/s) and mode ("foot" | "boat").
function MapConfig.zoomFor(mode: string, speed: number): number
	local z = MapConfig.Zoom
	if mode == "foot" then
		return z.foot
	end
	local spec = z.boat
	local t = math.clamp(speed / spec.fastSpeed, 0, 1)
	t = t * t * (3 - 2 * t)
	return spec.slow + (spec.fast - spec.slow) * t
end

return MapConfig
