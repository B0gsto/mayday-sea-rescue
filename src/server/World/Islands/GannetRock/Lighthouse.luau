--!strict
-- The Gannet Rock light: a 64-stud red-and-white tower you climb. Inside, a 64-step spiral (14 steps a turn round a
-- newel) runs from the door to the lantern floor; a door in the lantern opens onto the railed gallery (bench and
-- telescope facing the archipelago). Same Lighthouse / LighthouseLens / ATT_Light contract as SkerryLight, so
-- StreetController turns the night beam.
--
-- Walls: the granite base band is masonry blocks; above it each painted band is a 32-block shell over a 16-panel
-- inner wall. No cylinders round the stairwell: a cylinder's end cap reads as a ceiling from inside.
local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent:WaitForChild("Kit"))
local StreetFurniture = require(script.Parent.Parent.Parent:WaitForChild("StreetFurniture")) :: any

local Lighthouse = {}

local WHITE = Color3.fromRGB(236, 234, 226)
local RED = Color3.fromRGB(178, 40, 36)
local BLACK = Color3.fromRGB(30, 33, 36)
local GRANITE = Color3.fromRGB(118, 116, 110)
local STONE = Color3.fromRGB(164, 160, 150)
local BRASS = Color3.fromRGB(190, 150, 72)
local WINDOW = Color3.fromRGB(46, 62, 74)

local R_IN = 6.6 -- inner wall apothem
local BAND = 8
local BANDS = 8 -- band 0 granite, 1..7 painted
local PER_TURN = 14
local THETA = 2 * math.pi / PER_TURN
local STEPS = BANDS * BAND -- one stud a step, door floor to lantern floor
local GALLERY_R = 13.2

local function bandRadius(b: number): number
	return 10 - 0.3 * (b - 1)
end

local function at(c: Vector3, a: number, r: number, y: number): Vector3
	return Vector3.new(c.X, y, c.Z) + Kit.dir(a) * r
end

local function telescope(m: Model, foot: Vector3, out: Vector3)
	local head = foot + Vector3.new(0, 3.4, 0)
	for i = 0, 2 do
		local a = i * 2 * math.pi / 3
		Kit.beam(m, "TripodLeg", head, foot + Kit.dir(a) * 1.1, 0.16, BLACK, Enum.Material.Metal)
	end
	Kit.part(
		m,
		"TelescopeHead",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(head),
		BRASS,
		Enum.Material.Metal
	)
	local aim = (out + Vector3.new(0, 0.12, 0)).Unit
	local tube = CFrame.lookAt(head + Vector3.new(0, 0.35, 0), head + Vector3.new(0, 0.35, 0) + aim)
	Kit.part(
		m,
		"Tube",
		Vector3.new(3.4, 0.42, 0.42),
		tube * CFrame.new(0, 0, -0.6) * CFrame.Angles(0, math.pi / 2, 0),
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	Kit.part(
		m,
		"Objective",
		Vector3.new(0.5, 0.56, 0.56),
		tube * CFrame.new(0, 0, -2.3) * CFrame.Angles(0, math.pi / 2, 0),
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	Kit.part(
		m,
		"Eyepiece",
		Vector3.new(0.5, 0.24, 0.24),
		tube * CFrame.new(0, 0, 1.3) * CFrame.Angles(0, math.pi / 2, 0),
		BLACK,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
end

-- base: the yard surface under the tower centre. doorAngle: the way the door faces; viewAngle: where the gallery
-- bench and telescope look. Returns the model and the gallery deck height.
function Lighthouse.build(
	parent: Instance,
	base: Vector3,
	doorAngle: number,
	viewAngle: number
): (Model, number)
	local m = Instance.new("Model")
	m.Name = "GannetLight"
	m:SetAttribute("LightId", "GannetRock")
	local c = base
	local y0 = base.Y + 1 -- the inside floor, on the plinth
	local top = y0 + STEPS

	local plinth = Kit.cyl(m, "Plinth", c, 12.4, base.Y - 2, y0, GRANITE, Enum.Material.Granite)

	-- band 0: granite blocks, the door is the two panels either side of doorAngle
	local n0 = 20
	local phase0 = doorAngle + math.pi / n0
	local function isDoor(i: number): boolean
		return i == 0 or i == n0 - 1
	end
	Kit.ring(
		m,
		"Base",
		c,
		n0,
		R_IN,
		10.8,
		y0,
		y0 + 7,
		GRANITE,
		Enum.Material.Granite,
		phase0,
		isDoor
	)
	Kit.ring(
		m,
		"BaseTop",
		c,
		n0,
		R_IN,
		10.8,
		y0 + 7,
		y0 + BAND,
		GRANITE,
		Enum.Material.Granite,
		phase0
	)
	local out = Kit.dir(doorAngle)
	local side = Vector3.new(-out.Z, 0, out.X)
	for _, s in { -1, 1 } do
		Kit.part(
			m,
			"DoorJamb",
			Vector3.new(1.4, 7.4, 1.1),
			Kit.facing(at(c, doorAngle, 11, y0 + 3.7) + side * (2.6 * s), out),
			STONE,
			Enum.Material.Granite
		)
	end
	Kit.part(
		m,
		"DoorLintel",
		Vector3.new(1.6, 1.3, 6.4),
		Kit.facing(at(c, doorAngle, 11, y0 + 7.6), out),
		STONE,
		Enum.Material.Granite
	)
	Kit.ring(
		m,
		"StringCourse",
		c,
		32,
		9.4,
		10.4,
		y0 + BAND - 0.2,
		y0 + BAND + 0.6,
		STONE,
		Enum.Material.Granite
	)

	-- the spiral: step k tops at y0 + k + 1, starting beside the door and turning anticlockwise seen from above
	local phi0 = doorAngle + 1.5 * THETA
	for k = 0, STEPS - 1 do
		local a = phi0 + k * THETA
		Kit.part(
			m,
			`Step{k + 1}`,
			Vector3.new(5.4, 1.2, 3.3),
			Kit.facing(at(c, a, 3.75, y0 + k + 0.4), Kit.dir(a)),
			STONE,
			Enum.Material.Granite
		)
	end
	Kit.cyl(m, "Newel", c, 1.1, y0, top + 3.6, WHITE, Enum.Material.Plaster)

	-- bands 1..7: painted shell, 16-panel inner wall, one window where the stair passes mid-band
	local n = 16
	for b = 1, BANDS - 1 do
		local r = bandRadius(b)
		local yb = y0 + b * BAND
		-- the top band stops 0.05 under the gallery deck and lantern floor (no shared plane)
		local yt = yb + BAND - (if b == BANDS - 1 then 0.05 else 0)
		local wa = phi0 + (b * BAND + 3) * THETA
		local wi = math.round(wa / (2 * math.pi / n)) % n
		local function isWindow(i: number): boolean
			return i == wi
		end
		-- the painted shell: 32 thin blocks, phased so the window takes out the two inside the inner window panel
		local paint = if b % 2 == 1 then WHITE else RED
		local function shellWindow(j: number): boolean
			return j == (2 * wi - 1) % 32 or j == 2 * wi
		end
		local function shellSolid(j: number): boolean
			return not shellWindow(j)
		end
		local ph = math.pi / 32
		Kit.ring(
			m,
			`Shell{b}_`,
			c,
			32,
			r - 0.6,
			r,
			yb,
			yt,
			paint,
			Enum.Material.Plaster,
			ph,
			shellWindow
		)
		Kit.ring(
			m,
			`ShellSill{b}_`,
			c,
			32,
			r - 0.6,
			r,
			yb,
			yb + 3.15, -- 0.05 under the inner sill's top, 0.1 under the window sill's
			paint,
			Enum.Material.Plaster,
			ph,
			shellSolid
		)
		Kit.ring(
			m,
			`ShellHead{b}_`,
			c,
			32,
			r - 0.6,
			r,
			yb + 6.25, -- 0.05 over the inner head's underside
			yt,
			paint,
			Enum.Material.Plaster,
			ph,
			shellSolid
		)
		Kit.ring(
			m,
			`Wall{b}_`,
			c,
			n,
			R_IN,
			r - 0.6,
			yb,
			yt,
			WHITE,
			Enum.Material.Plaster,
			0,
			isWindow
		)
		local notWindow = function(i: number): boolean
			return i ~= wi
		end
		Kit.ring(
			m,
			`Sill{b}_`,
			c,
			n,
			R_IN,
			r - 0.6,
			yb,
			yb + 3.2,
			WHITE,
			Enum.Material.Plaster,
			0,
			notWindow
		)
		Kit.ring(
			m,
			`Head{b}_`,
			c,
			n,
			R_IN,
			r - 0.6,
			yb + 6.2,
			yt,
			WHITE,
			Enum.Material.Plaster,
			0,
			notWindow
		)
		local a = wi * 2 * math.pi / n
		local pane = Kit.part(
			m,
			`Pane{b}`,
			Vector3.new(0.2, 3, 2.7),
			Kit.facing(at(c, a, R_IN + 0.3, yb + 4.7), Kit.dir(a)),
			Color3.fromRGB(200, 214, 220),
			Enum.Material.Glass
		)
		pane.Transparency = 0.7
		local glass = Kit.part(
			m,
			`Window{b}`,
			Vector3.new(0.3, 3, 4),
			Kit.facing(at(c, a, r - 0.3, yb + 4.7), Kit.dir(a)),
			WINDOW,
			Enum.Material.Glass
		)
		glass.Transparency = 0.25
		glass.CanCollide = false
		Kit.part(
			m,
			`WindowSill{b}`,
			Vector3.new(0.6, 0.3, 2.1),
			Kit.facing(at(c, a, r + 0.15, yb + 3.1), Kit.dir(a)),
			if b % 2 == 1 then STONE else WHITE,
			Enum.Material.Plaster
		).CanCollide =
			false
		if b % 2 == 1 then -- a warm wall lamp every other band, across from the window
			local lamp = Kit.part(
				m,
				`Sconce{b}`,
				Vector3.new(0.5, 0.7, 0.5),
				CFrame.new(at(c, a + math.pi, R_IN - 0.25, yb + 6)),
				BRASS,
				Enum.Material.Metal
			)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 1.4
			light.Color = Color3.fromRGB(255, 212, 160)
			light.Parent = lamp
		end
	end

	-- the lantern floor: a half disc beside the last step (the other half is the stairwell), railed on its far half
	local phiEnd = phi0 + (STEPS - 1) * THETA
	local u = Kit.dir(phiEnd + THETA / 2)
	local v = Kit.dir(phiEnd + THETA / 2 + math.pi / 2)
	local mid = Vector3.new(c.X, top - 0.25, c.Z) -- 0.05 over the gallery deck's top
	Kit.part(
		m,
		"Floor",
		Vector3.new(13, 0.6, 4.5),
		CFrame.fromMatrix(mid + v * 2.25, u, Vector3.yAxis),
		STONE,
		Enum.Material.Granite
	)
	Kit.part(
		m,
		"FloorEdge",
		Vector3.new(9, 0.6, 1.9),
		CFrame.fromMatrix(mid + v * 5.4, u, Vector3.yAxis),
		STONE,
		Enum.Material.Granite
	)
	Kit.beam(
		m,
		"WellRail",
		mid - u * 1.1 + Vector3.new(0, 3.3, 0),
		mid - u * 6.5 + Vector3.new(0, 3.3, 0),
		0.25,
		BLACK,
		Enum.Material.Metal
	)
	Kit.part(
		m,
		"WellPost",
		Vector3.new(0.25, 3.3, 0.25),
		CFrame.new(mid - u * 4 + Vector3.new(0, 1.8, 0)),
		BLACK,
		Enum.Material.Metal
	)

	-- gallery: a granite deck ring on two corbel steps, iron railing
	-- inner face 0.05 behind the tower wall's (no shared plane)
	Kit.ring(
		m,
		"Deck",
		c,
		24,
		R_IN + 0.05,
		GALLERY_R,
		top - 0.8,
		top,
		GRANITE,
		Enum.Material.Granite
	)
	local shellIn = bandRadius(BANDS - 1) - 0.6
	Kit.ring(m, "Corbel", c, 32, shellIn, 9.6, top - 2.8, top - 0.8, STONE, Enum.Material.Granite)
	Kit.ring(m, "Corbel2", c, 32, shellIn, 12, top - 1.5, top - 0.8, STONE, Enum.Material.Granite)
	local rr = GALLERY_R - 0.3
	for i = 0, 23 do
		local a = (i + 0.5) * math.pi / 12
		Kit.part(
			m,
			"RailPost",
			Vector3.new(0.3, 3.6, 0.3),
			CFrame.new(at(c, a, rr, top + 1.8)),
			BLACK,
			Enum.Material.Metal
		)
	end
	Kit.ring(
		m,
		"Rail",
		c,
		24,
		rr - 0.15,
		rr + 0.15,
		top + 3.4,
		top + 3.7,
		BLACK,
		Enum.Material.Metal
	)
	Kit.ring(
		m,
		"MidRail",
		c,
		24,
		rr - 0.1,
		rr + 0.1,
		top + 1.8,
		top + 2,
		BLACK,
		Enum.Material.Metal
	)

	-- lantern room: 10 sides on the wall top, the door side facing the floor half
	local doorL = phiEnd + THETA / 2 + math.pi / 2
	local ap = 7.0
	local function door(i: number): boolean
		return i == 0
	end
	local function notDoor(i: number): boolean
		return i ~= 0
	end
	Kit.ring(
		m,
		"Parapet",
		c,
		10,
		ap - 0.2,
		ap + 0.2,
		top,
		top + 3,
		BLACK,
		Enum.Material.Metal,
		doorL,
		door
	)
	for _, p in
		Kit.ring(
			m,
			"Glazing",
			c,
			10,
			ap - 0.1,
			ap + 0.1,
			top + 3,
			top + 11.5,
			Color3.fromRGB(214, 226, 230),
			Enum.Material.Glass,
			doorL,
			door
		)
	do
		p.Transparency = 0.6
	end
	for _, p in
		Kit.ring(
			m,
			"Transom",
			c,
			10,
			ap - 0.1,
			ap + 0.1,
			top + 8,
			top + 11.5,
			Color3.fromRGB(214, 226, 230),
			Enum.Material.Glass,
			doorL,
			notDoor
		)
	do
		p.Transparency = 0.6
	end
	for i = 0, 9 do
		local a = doorL + (i + 0.5) * math.pi / 5
		Kit.part(
			m,
			"Mullion",
			Vector3.new(0.4, 11.45, 0.4), -- top 0.05 under the glazing's
			CFrame.new(at(c, a, ap / math.cos(math.pi / 10), top + 5.725)),
			BLACK,
			Enum.Material.Metal
		)
	end
	Kit.cyl(m, "Cornice", c, 8.0, top + 11.5, top + 12.3, BLACK, Enum.Material.Metal)
	local dome = { { 7.2, 1.2 }, { 5.9, 1.2 }, { 4.4, 1.1 }, { 2.6, 0.9 } }
	local y = top + 12.3
	for i, d in dome do
		Kit.cyl(m, `Dome{i}`, c, d[1], y, y + d[2], RED, Enum.Material.Metal)
		y += d[2]
	end
	Kit.part(
		m,
		"Ventilator",
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(c.X, y + 0.9, c.Z),
		BLACK,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	Kit.cyl(m, "Finial", c, 0.18, y + 2, y + 4.4, BLACK, Enum.Material.Metal)

	-- the lens on the newel (no collision: you walk round it)
	Kit.cyl(m, "Pedestal", c, 1.5, top + 3.2, top + 3.7, BRASS, Enum.Material.Metal)
	local lens = Kit.part(
		m,
		"Lens",
		Vector3.new(3.6, 3.6, 3.6),
		CFrame.new(c.X, top + 5.6, c.Z),
		Color3.fromRGB(226, 220, 196),
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	lens.CanCollide = false
	lens.Transparency = 0.15
	CollectionService:AddTag(lens, "LighthouseLens")
	local att = Instance.new("Attachment")
	att.Name = "ATT_Light"
	att.Parent = lens

	-- the viewpoint: bench (sitting side out) and telescope on the gallery
	local bench = StreetFurniture.build("M_Road_Bench")
	if bench then
		local p = at(c, viewAngle, 10.4, top)
		bench:PivotTo(CFrame.lookAt(p, p + Kit.dir(viewAngle)))
		bench.Name = "ViewBench"
		bench:SetAttribute("IslandId", "GannetRock")
		CollectionService:AddTag(bench, "Viewpoint")
		bench.Parent = m
	end
	telescope(m, at(c, viewAngle + 0.42, 11.2, top), Kit.dir(viewAngle + 0.42))

	m.PrimaryPart = plinth
	m.WorldPivot = CFrame.new(base)
	CollectionService:AddTag(m, "Lighthouse")
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = parent
	return m, top
end

return Lighthouse
