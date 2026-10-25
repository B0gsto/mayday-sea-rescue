--!strict
-- DockPieces (docs/23 d.2, WP-4; WP-19b): the placeholder Parts each dock level adds, around the berth frame
-- (Marina.berth: the island's boat berth at sea level, -Z = out of the cove, the craft at x -7..7, the jetty
-- finger at x -17..-9, the jetty at x -27..-17). Each piece stands on its island lot (Marina.LOTS, berth
-- frame): Lv 2 pontoon (beside the berth), lamps, rescue board on the quay; Lv 3 boathouse (its lot) + paint
-- booth arches over the berth; Lv 4 lookout tower (the beach tower lot) + slipway crane on the quay; Lv 5 the
-- station (its lot): lit front, roof beacon, trophy hall wall. Buildings: helipad + hangar on their lots, the
-- sub pen over the sub berth. DockService builds them (everyone sees them); a buy plays the Lego build
-- beat (shared/BuildSeq) client-side. The build station (docs/23 (j) rule 4, WP-14d) stands on the Spare3
-- lot by the spawn, and the Cash-only decorations on the Spare2 / Spare3 spare lots. Named hooks: parts
-- "Flag" take the owner's colour, TextLabels "Count" show the rescue count. Materials stay off the
-- MaterialService remap (no Slate, WoodPlanks, Brick, Concrete).
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(script.Parent:WaitForChild("Marina"))
local UiImages = require(script.Parent:WaitForChild("Config"):WaitForChild("UiImages"))

local DockPieces = {}

local WOOD = Color3.fromRGB(122, 92, 62)
local DARK = Color3.fromRGB(84, 62, 44)
local WHITE = Color3.fromRGB(236, 233, 224)
local STEEL = Color3.fromRGB(190, 194, 198)
local GREY = Color3.fromRGB(70, 76, 82)
local RED = Color3.fromRGB(196, 52, 40)
local ORANGE = Color3.fromRGB(240, 120, 40)
local YELLOW = Color3.fromRGB(242, 190, 40)
local WARM = Color3.fromRGB(255, 214, 150)

local NAVY = Color3.fromRGB(30, 44, 66)
local GOLD = Color3.fromRGB(222, 178, 60)

local M = Enum.Material
local TOP = Marina.DECK_TOP
local LOT = Marina.LOTS
-- the station (Lv 5): half width, half depth, height; the trophy hall is on its front wall, left of the door
local ST = { hw = 26, hd = 15, h = 16 }
local HALL = LOT.Station.cf * CFrame.new(-15.5, 0, -ST.hd - 0.5) -- -Z = out of the wall

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3): BasePart
	local w = Instance.new("WedgePart")
	w.Name = "Gable"
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = M.Wood
	w.Anchored = true
	w.Parent = parent
	return w
end

-- a vertical pole from y0 up h, with an optional top
local function pole(
	parent: Instance,
	b: CFrame,
	x: number,
	z: number,
	y0: number,
	h: number,
	color: Color3
)
	return part(
		parent,
		"Pole",
		Vector3.new(h, 0.4, 0.4),
		b * CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		M.Metal,
		Enum.PartType.Cylinder
	)
end

local function lamp(parent: Instance, b: CFrame, x: number, z: number, y0: number)
	pole(parent, b, x, z, y0, 10, GREY)
	local bulb = part(
		parent,
		"Lamp",
		Vector3.new(1.3, 1.3, 1.3),
		b * CFrame.new(x, y0 + 10.4, z),
		WARM,
		M.Neon,
		Enum.PartType.Ball
	)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 24
	light.Brightness = 1.2
	light.Parent = bulb
end

local function flag(parent: Instance, b: CFrame, x: number, z: number, y0: number, h: number)
	pole(parent, b, x, z, y0, h, STEEL)
	local f = part(
		parent,
		"Flag",
		Vector3.new(0.15, 4, 6.5),
		b * CFrame.new(x, y0 + h - 2.1, z + 3.4),
		WHITE,
		M.Fabric
	)
	f.CanCollide = false
end

-- Lv 2: pontoon (the second berth, past the craft from the jetty), lamps down the jetty and the pontoon, a
-- tall flag, the rescue-count board on the quay
local function level2(m: Model, b: CFrame)
	part(m, "Pontoon", Vector3.new(6, 0.8, 50), b * CFrame.new(16, 1.6, 2), WHITE, M.SmoothPlastic)
	for z = -18, 22, 10 do
		part(m, "Float", Vector3.new(5, 1.4, 4), b * CFrame.new(16, 0.6, z), GREY, M.Metal)
		part(m, "Cleat", Vector3.new(0.5, 0.4, 1.4), b * CFrame.new(13.4, 2.2, z), GREY, M.Metal)
	end
	lamp(m, b, 18.5, -18, 2)
	lamp(m, b, 18.5, 4, 2)
	for _, z in { -4, 20, 45 } do
		lamp(m, b, -26.4, z, TOP)
		lamp(m, b, -17.6, z, TOP)
	end
	flag(m, b, 16, -22, 2, 24)

	-- rescue board on the quay west of the jetty, facing the cove: a life ring and one big number
	local W, H = 12, 7
	local at = b * Marina.ISLAND * CFrame.new(-24, 7, -26)
	for _, dx in { -W / 2 + 0.6, W / 2 - 0.6 } do
		part(m, "BoardPost", Vector3.new(0.6, 9, 0.6), at * CFrame.new(dx, -2.5, 0.5), DARK, M.Wood)
	end
	local board = part(
		m,
		"RescueBoard",
		Vector3.new(W, H, 0.5),
		at,
		Color3.fromRGB(28, 44, 66),
		M.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.2
	gui.Parent = board
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.fromScale(0.06, 0.5)
	ring.Size = UDim2.fromScale(0.27, 0.27 * W / H)
	ring.BackgroundTransparency = 1
	ring.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = ORANGE
	stroke.Thickness = 18
	stroke.Parent = ring
	local count = Instance.new("TextLabel")
	count.Name = "Count"
	count.Position = UDim2.fromScale(0.38, 0.08)
	count.Size = UDim2.fromScale(0.58, 0.84)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.FredokaOne
	count.TextScaled = true
	count.TextColor3 = WHITE
	count.Text = "0"
	count.Parent = gui
end

-- Lv 3 paint booth (DockConfig.PAINT_BOOTH): two gantry arches over the berth's inshore half, posts on the
-- jetty finger and the pontoon, spray heads and a light under each beam, a swatch board over the finger
local SWATCHES = {
	Color3.fromRGB(214, 86, 20),
	Color3.fromRGB(201, 162, 74),
	Color3.fromRGB(79, 98, 117),
	Color3.fromRGB(40, 150, 142),
	Color3.fromRGB(30, 60, 88),
	Color3.fromRGB(236, 233, 224),
	Color3.fromRGB(140, 60, 150),
	Color3.fromRGB(60, 140, 70),
	Color3.fromRGB(36, 38, 42),
	Color3.fromRGB(226, 85, 122),
}
local function paintBooth(m: Model, b: CFrame)
	local booth = Instance.new("Model")
	booth.Name = "PaintBooth"
	booth.Parent = m
	local xw, xe, y0, y1 = -10.4, 13.6, 2, TOP + 13
	for _, z in { 8, 22 } do
		for _, x in { xw, xe } do
			part(
				booth,
				"BoothPost",
				Vector3.new(0.8, y1 - y0, 0.8),
				b * CFrame.new(x, (y0 + y1) / 2, z),
				WHITE,
				M.Metal
			)
		end
		local beam = part(
			booth,
			"BoothBeam",
			Vector3.new(xe - xw + 0.8, 0.8, 0.8),
			b * CFrame.new((xw + xe) / 2, y1, z),
			ORANGE,
			M.Metal
		)
		beam.CanCollide = false
		local strip = part(
			booth,
			"BoothLight",
			Vector3.new(xe - xw - 2, 0.15, 0.4),
			b * CFrame.new((xw + xe) / 2, y1 - 0.5, z),
			WHITE,
			M.Neon
		)
		strip.CanCollide = false
		for x = xw + 4, xe - 3, 5 do
			part(
				booth,
				"SprayHead",
				Vector3.new(0.6, 0.6, 0.6),
				b * CFrame.new(x, y1 - 0.9, z),
				GREY,
				M.Metal
			).CanCollide =
				false
		end
	end
	-- the swatch board: up over the finger edge between the arches (clear above heads), facing the booth
	local board = part(
		booth,
		"SwatchBoard",
		Vector3.new(0.25, 3.6, 12),
		b * CFrame.new(xw + 0.1, TOP + 9, 15),
		GREY,
		M.SmoothPlastic
	)
	board.CanCollide = false
	for i, c in SWATCHES do
		local col, rowN = (i - 1) % 5, (i - 1) // 5
		part(
			booth,
			"Swatch",
			Vector3.new(0.1, 1.2, 1.9),
			b * CFrame.new(xw + 0.3, TOP + 9.8 - rowN * 1.6, 10.2 + col * 2.4),
			c,
			M.SmoothPlastic
		).CanCollide =
			false
	end
end

-- Lv 3: the boathouse on its lot, the roll-up door facing the cove, a clear marked floor spot for the boat
-- board (DockConfig.BOARD_SLOT) by the back wall; the paint booth over the berth
local function level3(m: Model, b: CFrame)
	local L = b * LOT.Boathouse.cf -- -Z = the doors
	local hw, hd, h = 15, 18, 14
	local y = h / 2
	part(m, "Floor", Vector3.new(hw * 2, 0.2, hd * 2), L * CFrame.new(0, 0.1, 0), WOOD, M.Wood)
	part(m, "Wall", Vector3.new(0.8, h, hd * 2), L * CFrame.new(-hw, y, 0), WHITE, M.Wood)
	part(m, "Wall", Vector3.new(0.8, h, hd * 2), L * CFrame.new(hw, y, 0), WHITE, M.Wood)
	part(m, "Wall", Vector3.new(hw * 2, h, 0.8), L * CFrame.new(0, y, hd), WHITE, M.Wood)
	-- front: two pillars, the header and the half-rolled door
	part(m, "Wall", Vector3.new(5, h, 0.8), L * CFrame.new(-hw + 2.5, y, -hd), WHITE, M.Wood)
	part(m, "Wall", Vector3.new(5, h, 0.8), L * CFrame.new(hw - 2.5, y, -hd), WHITE, M.Wood)
	part(m, "Header", Vector3.new(hw * 2, 4, 0.8), L * CFrame.new(0, h - 2, -hd), WHITE, M.Wood)
	local doorW = hw * 2 - 10
	part(m, "Door", Vector3.new(doorW, 4, 0.4), L * CFrame.new(0, h - 6, -hd + 0.1), RED, M.Metal)
	part(
		m,
		"DoorRoll",
		Vector3.new(doorW, 1.8, 1.8),
		L * CFrame.new(0, h - 3.4, -hd - 1.1),
		RED,
		M.Metal,
		Enum.PartType.Cylinder
	)
	-- gabled roof, ridge along the depth
	local run, rise = hw + 0.8, 5
	local angle = math.atan2(rise, run)
	local len = math.sqrt(run * run + rise * rise)
	for _, side in { -1, 1 } do
		part(
			m,
			"Roof",
			Vector3.new(len + 0.4, 0.6, hd * 2 + 2),
			L * CFrame.new(side * run / 2, h + rise / 2, 0) * CFrame.Angles(0, 0, -side * angle),
			RED,
			M.SmoothPlastic
		)
		for _, z in { -hd, hd } do
			wedge(
				m,
				Vector3.new(0.8, rise, run - 0.8),
				L
					* CFrame.new(side * (run - 0.8) / 2, h + rise / 2, z)
					* CFrame.Angles(0, -side * math.pi / 2, 0), -- the wedge is tall at local +Z: toward the ridge
				WHITE
			)
		end
	end
	-- the board slot: an empty floor square outlined in yellow (WP-5 puts the board here)
	local slot = Instance.new("Model")
	slot.Name = "BoardSlot"
	slot.Parent = m
	local s = DockConfig.BOARD_SIZE
	local c = b * DockConfig.BOARD_SLOT
	for _, e in
		{ { 0, -s / 2, s, 0.3 }, { 0, s / 2, s, 0.3 }, { -s / 2, 0, 0.3, s }, { s / 2, 0, 0.3, s } }
	do
		local line = part(
			slot,
			"Line",
			Vector3.new(e[3], 0.06, e[4]),
			c * CFrame.new(e[1], 0.23, e[2]),
			YELLOW,
			M.SmoothPlastic
		)
		line.CanCollide = false
	end
	paintBooth(m, b)
end

-- Lv 4: the lookout tower on the beach tower lot (a ladder up its open side), a slipway crane on the quay
-- swinging over the berth
local function level4(m: Model, b: CFrame)
	local T = b * LOT.LifeguardTower.cf
	local legH, s = 20, 4
	for _, d in { { -s, -s }, { s, -s }, { -s, s }, { s, s } } do
		part(
			m,
			"Leg",
			Vector3.new(0.8, legH, 0.8),
			T * CFrame.new(d[1], legH / 2, d[2]),
			STEEL,
			M.Metal
		)
	end
	for _, yy in { 7, 14 } do
		for _, z in { -s, s } do
			part(
				m,
				"Brace",
				Vector3.new(s * 2 + 0.6, 0.4, 0.4),
				T * CFrame.new(0, yy, z),
				STEEL,
				M.Metal
			)
		end
	end
	part(m, "Platform", Vector3.new(10, 0.8, 10), T * CFrame.new(0, legH + 0.4, 0), WOOD, M.Wood)
	for _, w in { { 0, -4.8, 9.6, 0.2 }, { -4.8, 0, 0.2, 9.6 }, { 4.8, 0, 0.2, 9.6 } } do
		local g = part(
			m,
			"Window",
			Vector3.new(w[3], 3.6, w[4]),
			T * CFrame.new(w[1], legH + 2.6, w[2]),
			Color3.fromRGB(150, 200, 230),
			M.Glass
		)
		g.Transparency = 0.45
	end
	part(
		m,
		"TowerRoof",
		Vector3.new(11, 0.8, 11),
		T * CFrame.new(0, legH + 5, 0),
		RED,
		M.SmoothPlastic
	)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, legH, 2)
	ladder.CFrame = T * CFrame.new(0, legH / 2, s + 1.5)
	ladder.Color = GREY
	ladder.Material = M.Metal
	ladder.Anchored = true
	ladder.Parent = m

	-- crane: mast on the quay starboard of the berth, the boom out over the berth's inshore end
	local mastH = 24
	local base = b * CFrame.new(16, TOP, 66)
	part(m, "CraneBase", Vector3.new(4, 1.2, 4), base * CFrame.new(0, 0.6, 0), GREY, M.Metal)
	part(
		m,
		"Mast",
		Vector3.new(1.6, mastH, 1.6),
		base * CFrame.new(0, mastH / 2, 0),
		YELLOW,
		M.Metal
	)
	local top = (base * CFrame.new(0, mastH - 0.5, 0)).Position
	local tip = (b * CFrame.new(0, TOP + mastH - 0.5, 30)).Position
	local dir = (tip - top).Unit
	part(
		m,
		"Boom",
		Vector3.new(1.2, 1.2, (tip - top).Magnitude + 6),
		CFrame.lookAt((top + tip) / 2 - dir * 3, tip),
		YELLOW,
		M.Metal
	)
	part(
		m,
		"Counterweight",
		Vector3.new(3, 2.4, 3),
		CFrame.lookAt(top - dir * 5, tip) - Vector3.new(0, 1.5, 0),
		GREY,
		M.Metal
	)
	part(
		m,
		"Cable",
		Vector3.new(0.15, 9, 0.15),
		CFrame.new(tip - Vector3.new(0, 4.5, 0)),
		GREY,
		M.Metal
	).CanCollide =
		false
	part(m, "Hook", Vector3.new(1, 1.2, 1), CFrame.new(tip - Vector3.new(0, 9.5, 0)), RED, M.Metal)
end

-- Lv 5: the station on its lot (door toward the bridge and the spawn): a lit front with neon stripes and
-- floodlights, a beacon on the roof, the trophy hall board on the front wall (DockPieces.trophies fills it),
-- light strips down the jetty
local function level5(m: Model, b: CFrame)
	local S = b * LOT.Station.cf -- -Z = the front
	local hw, hd, h = ST.hw, ST.hd, ST.h
	local door = 5
	part(
		m,
		"Floor",
		Vector3.new(hw * 2, 0.2, hd * 2),
		S * CFrame.new(0, 0.1, 0),
		GREY,
		M.SmoothPlastic
	)
	part(
		m,
		"Wall",
		Vector3.new(hw * 2, h, 0.8),
		S * CFrame.new(0, h / 2, hd),
		WHITE,
		M.SmoothPlastic
	)
	for _, x in { -hw, hw } do
		part(
			m,
			"Wall",
			Vector3.new(0.8, h, hd * 2),
			S * CFrame.new(x, h / 2, 0),
			WHITE,
			M.SmoothPlastic
		)
	end
	for _, side in { -1, 1 } do
		part(
			m,
			"StationFront",
			Vector3.new(hw - door, h, 0.8),
			S * CFrame.new(side * (hw + door) / 2, h / 2, -hd),
			WHITE,
			M.SmoothPlastic
		)
	end
	part(
		m,
		"StationFront",
		Vector3.new(door * 2, h - 9, 0.8),
		S * CFrame.new(0, 9 + (h - 9) / 2, -hd),
		WHITE,
		M.SmoothPlastic
	)
	part(
		m,
		"Roof",
		Vector3.new(hw * 2 + 1.5, 0.8, hd * 2 + 1.5),
		S * CFrame.new(0, h + 0.4, 0),
		NAVY,
		M.SmoothPlastic
	)
	part(
		m,
		"Stripe",
		Vector3.new(hw * 2, 0.8, 0.3),
		S * CFrame.new(0, h - 2.5, -hd - 0.5),
		ORANGE,
		M.Neon
	)
	part(
		m,
		"Stripe",
		Vector3.new(hw * 2, 0.4, 0.3),
		S * CFrame.new(0, h - 1.2, -hd - 0.5),
		Color3.fromRGB(40, 90, 200),
		M.Neon
	)
	for _, x in { -hw + 2, -door - 1.5, door + 1.5, hw - 2 } do
		local flood = part(
			m,
			"Floodlight",
			Vector3.new(1.4, 1, 1),
			S * CFrame.new(x, h - 5, -hd - 0.9) * CFrame.Angles(math.rad(-35), 0, 0),
			WARM,
			M.Neon
		)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 70
		spot.Range = 40
		spot.Brightness = 2
		spot.Color = WARM
		spot.Parent = flood
	end
	-- light strips down both edges of the jetty
	local jetty = LOT.Jetty
	for _, dx in { -jetty.size.X / 2 + 0.1, jetty.size.X / 2 - 0.1 } do
		part(
			m,
			"JettyLight",
			Vector3.new(0.2, 0.15, jetty.size.Y),
			b * jetty.cf * CFrame.new(dx, 0.05, 0),
			WARM,
			M.Neon
		).CanCollide =
			false
	end
	-- the trophy hall: a navy backboard and a shelf on the front wall, left of the door
	part(
		m,
		"TrophyBoard",
		Vector3.new(20, 6, 0.2),
		b * HALL * CFrame.new(0, 5, 0),
		NAVY,
		M.SmoothPlastic
	)
	part(
		m,
		"TrophyShelf",
		Vector3.new(20, 0.3, 1.4),
		b * HALL * CFrame.new(0, 2.6, -0.7),
		DARK,
		M.Wood
	)
	-- beacon on the roof: a mast, a lens, a wide light, a beam into the sky
	local top = S * CFrame.new(hw - 6, h + 0.8, hd - 6)
	part(m, "BeaconMast", Vector3.new(1, 8, 1), top * CFrame.new(0, 4, 0), GREY, M.Metal)
	part(m, "BeaconBase", Vector3.new(2.4, 0.8, 2.4), top * CFrame.new(0, 8.4, 0), GREY, M.Metal)
	local lens = part(
		m,
		"Beacon",
		Vector3.new(2.2, 2.2, 2.2),
		top * CFrame.new(0, 9.9, 0),
		Color3.fromRGB(255, 70, 50),
		M.Neon,
		Enum.PartType.Ball
	)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 90, 60)
	glow.Range = 60
	glow.Brightness = 4
	glow.Parent = lens
	local a0 = Instance.new("Attachment")
	a0.Parent = lens
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 220, 0)
	a1.Parent = lens
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 3, 8
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 140, 100))
	beam.Transparency = NumberSequence.new(0.7, 1)
	beam.Parent = lens
end

local LEVELS = { [2] = level2, [3] = level3, [4] = level4, [5] = level5 }

-- WP-10b buildings (WP-19b: on their own lots) ------------------------------------------------------

local HELI = LOT.Helipad.cf * CFrame.new(0, 0.6, 0) -- the helicopter's spot: the pad centre
local PEN = { hx = 8, hz = 20, top = 16 } -- the sub pen gantry round the sub berth (Marina.SUB frame)
local PEN_JETTY = LOT.Jetty.cf.X - LOT.Jetty.size.X / 2 - Marina.SUB.X -- the jetty's edge, sub berth frame

-- In the berth frame: `board` = the vehicle board's rack (models along
-- its X, facing its -Z), `targets[id]` = where that craft spawns (the berth when absent), `hook` = the gantry
-- height the sub hangs from.
DockPieces.Buildings = {
	Hangar = {
		board = LOT.Hangar.cf * CFrame.new(0, 0.2, 9),
		targets = { RescueHelicopter = HELI } :: { [string]: CFrame },
	},
	SubPen = {
		board = Marina.SUB * CFrame.new(PEN_JETTY - 6, TOP, 0) * CFrame.Angles(0, math.pi / 2, 0),
		targets = { Submarine = Marina.SUB } :: { [string]: CFrame },
		hook = PEN.top - 0.5,
	},
}

-- the helipad on its lot (an H, an edge line and lights) and the hangar on its lot, open toward the pad
local function hangar(m: Model, b: CFrame)
	local P = b * LOT.Helipad.cf
	part(m, "Pad", Vector3.new(36, 0.6, 36), P * CFrame.new(0, 0.3, 0), GREY, M.SmoothPlastic)
	for _, e in { { 0, -14, 28, 0.5 }, { 0, 14, 28, 0.5 }, { -14, 0, 0.5, 28 }, { 14, 0, 0.5, 28 } } do
		part(
			m,
			"PadLine",
			Vector3.new(e[3], 0.06, e[4]),
			P * CFrame.new(e[1], 0.63, e[2]),
			YELLOW,
			M.SmoothPlastic
		).CanCollide =
			false
	end
	for _, e in { { -3.6, 0, 1.8, 10.5 }, { 3.6, 0, 1.8, 10.5 }, { 0, 0, 7.2, 1.8 } } do
		part(
			m,
			"H",
			Vector3.new(e[3], 0.08, e[4]),
			P * CFrame.new(e[1], 0.64, e[2]),
			WHITE,
			M.SmoothPlastic
		).CanCollide =
			false
	end
	for _, x in { -17.6, 0, 17.6 } do
		for _, z in { -17.6, 0, 17.6 } do
			if x ~= 0 or z ~= 0 then
				part(
					m,
					"PadLight",
					Vector3.new(0.7, 0.7, 0.7),
					P * CFrame.new(x, 0.85, z),
					Color3.fromRGB(90, 255, 120),
					M.Neon,
					Enum.PartType.Ball
				).CanCollide =
					false
			end
		end
	end
	local H = b * LOT.Hangar.cf -- -Z = the open front, toward the pad
	local hw, hd, h = 17, 14, 14
	part(
		m,
		"Floor",
		Vector3.new(hw * 2, 0.2, hd * 2),
		H * CFrame.new(0, 0.1, 0),
		GREY,
		M.SmoothPlastic
	)
	part(m, "Wall", Vector3.new(hw * 2, h, 0.8), H * CFrame.new(0, h / 2, hd), WHITE, M.Wood)
	for _, x in { -hw, hw } do
		part(m, "Wall", Vector3.new(0.8, h, hd * 2), H * CFrame.new(x, h / 2, 0), WHITE, M.Wood)
	end
	part(m, "Header", Vector3.new(hw * 2, 3, 0.8), H * CFrame.new(0, h - 1.5, -hd), WHITE, M.Wood)
	part(
		m,
		"HangarRoof",
		Vector3.new(hw * 2 + 1.5, 0.8, hd * 2 + 1.5),
		H * CFrame.new(0, h + 0.4, 0),
		RED,
		M.SmoothPlastic
	)
end

-- the sub pen: a steel gantry over a moon-pool collar round the sub berth, a plank from the jetty
local function subPen(m: Model, b: CFrame)
	local P = b * Marina.SUB
	local hx, hz, top = PEN.hx, PEN.hz, PEN.top
	for _, x in { -hx, hx } do
		for _, z in { -hz, hz } do
			part(
				m,
				"Leg",
				Vector3.new(0.8, top + 6, 0.8),
				P * CFrame.new(x, (top - 6) / 2, z),
				GREY,
				M.Metal
			)
		end
		part(
			m,
			"Beam",
			Vector3.new(0.8, 0.8, hz * 2 + 0.8),
			P * CFrame.new(x, top, 0),
			YELLOW,
			M.Metal
		)
	end
	for _, z in { -hz, hz } do
		part(m, "Beam", Vector3.new(hx * 2, 0.8, 0.8), P * CFrame.new(0, top, z), YELLOW, M.Metal)
	end
	part(m, "Trolley", Vector3.new(hx * 2, 1, 1.6), P * CFrame.new(0, top + 0.1, 0), GREY, M.Metal)
	-- the floating collar round the pool, at the waterline
	for _, x in { -hx + 0.6, hx - 0.6 } do
		part(
			m,
			"Collar",
			Vector3.new(1, 1, hz * 2),
			P * CFrame.new(x, 0.3, 0),
			ORANGE,
			M.SmoothPlastic
		)
	end
	for _, z in { -hz + 0.5, hz - 0.5 } do
		part(
			m,
			"Collar",
			Vector3.new(hx * 2 - 2.2, 1, 1),
			P * CFrame.new(0, 0.3, z),
			ORANGE,
			M.SmoothPlastic
		)
	end
	-- a plank from the jetty onto the collar
	part(
		m,
		"Plank",
		Vector3.new(PEN_JETTY - hx + 0.6, 0.4, 3),
		P * CFrame.new((PEN_JETTY + hx - 0.6) / 2, TOP - 0.2, -8),
		WOOD,
		M.Wood
	)
end

-- the quest blueprint lighthouse (DockConfig.Blueprints) on its spare lot: a red and white tower, a gallery and a
-- lit lantern room
local function lighthouse(m: Model, b: CFrame)
	local L = b * LOT[DockConfig.Blueprints.Lighthouse.lot].cf
	local up = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X
	part(m, "Base", Vector3.new(14, 2, 14), L * CFrame.new(0, 1, 0), GREY, M.SmoothPlastic)
	for i = 0, 5 do
		local d = 9 - i * 0.6
		part(
			m,
			"Tower",
			Vector3.new(4, d, d),
			L * CFrame.new(0, 4 + i * 4, 0) * up,
			if i % 2 == 0 then WHITE else RED,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	part(
		m,
		"Gallery",
		Vector3.new(1, 9, 9),
		L * CFrame.new(0, 26.5, 0) * up,
		GREY,
		M.Metal,
		Enum.PartType.Cylinder
	)
	local lantern = part(
		m,
		"Lantern",
		Vector3.new(4, 4.5, 4.5),
		L * CFrame.new(0, 29, 0) * up,
		WARM,
		M.Neon,
		Enum.PartType.Cylinder
	)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = WARM, 30, 2
	light.Parent = lantern
	part(
		m,
		"Cap",
		Vector3.new(1, 6, 6),
		L * CFrame.new(0, 31.6, 0) * up,
		RED,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
end

local BUILDINGS = { Hangar = hangar, SubPen = subPen, Lighthouse = lighthouse }

-- The pieces of building `key` (DockConfig.Buildings) around the berth frame `cf`, as a Model named `key`.
function DockPieces.building(key: string, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = key
	local fn = BUILDINGS[key]
	if fn then
		fn(m, cf)
	end
	return m
end

-- a 1-3 word name on a small plate, its face toward -Z
local function plate(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	text: string
)
	local p = part(parent, name, size, cf, color, M.SmoothPlastic)
	p.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 50
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(250, 246, 236)
	label.Text = text
	label.Parent = gui
end

-- The Lv 5 trophy hall's contents (docs/23 d.2) around the berth CFrame b: a gold cup per name in `cups`
-- (rescue milestones) on the shelf, a plaque per island stamp above it. A Model "Trophies" (not parented).
function DockPieces.trophies(
	b: CFrame,
	cups: { string },
	plaques: { { name: string, colour: Color3 } }
): Model
	local m = Instance.new("Model")
	m.Name = "Trophies"
	local hall = b * HALL
	for i, name in cups do
		local x = -9 + (i - 1) * 2.25
		part(
			m,
			"CupBase",
			Vector3.new(0.9, 0.4, 0.9),
			hall * CFrame.new(x, 2.95, -0.7),
			DARK,
			M.Wood
		)
		part(
			m,
			"CupStem",
			Vector3.new(0.7, 0.3, 0.3),
			hall * CFrame.new(x, 3.5, -0.7) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			M.Metal,
			Enum.PartType.Cylinder
		)
		part(
			m,
			"Cup",
			Vector3.new(1.1, 1.1, 1.1),
			hall * CFrame.new(x, 4.25, -0.7),
			GOLD,
			M.Metal,
			Enum.PartType.Ball
		)
		plate(m, "CupName", Vector3.new(2, 0.5, 0.05), hall * CFrame.new(x, 2.6, -1.42), NAVY, name)
	end
	for i, p in plaques do
		local x = -8.75 + (i - 1) * 2.5
		part(
			m,
			"PlaqueRim",
			Vector3.new(2.3, 1.9, 0.1),
			hall * CFrame.new(x, 6.6, -0.15),
			GOLD,
			M.Metal
		)
		plate(
			m,
			"Plaque",
			Vector3.new(2.1, 1.7, 0.1),
			hall * CFrame.new(x, 6.6, -0.22),
			p.colour,
			p.name
		)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- The pieces dock level n adds, as a Model "Lv<n>" around the berth CFrame b (not parented).
function DockPieces.build(n: number, b: CFrame): Model
	local m = Instance.new("Model")
	m.Name = `Lv{n}`
	local fn = LEVELS[n]
	if fn then
		fn(m, b)
	end
	return m
end

-- WP-14d (docs/23 (j) rule 4): the build station. Bright Lego bricks, a toolbox, a mini crane and the
-- tablet whose SurfaceGui opens the build mode (DockController binds its ProximityPrompt). The tablet's
-- Front face (its screen) looks toward the island spawn; its part is named "Tablet".
local BRICK_RED = Color3.fromRGB(224, 56, 40)
local BRICK_YELLOW = Color3.fromRGB(250, 208, 40)
local BRICK_BLUE = Color3.fromRGB(40, 96, 208)
local BRICK_GREEN = Color3.fromRGB(80, 190, 90)
local BRICK_WHITE = Color3.fromRGB(242, 240, 232)
local BRICK_CYAN = Color3.fromRGB(60, 220, 255)
local BRICK_PINK = Color3.fromRGB(250, 120, 190)
local BRICK_ORANGE = Color3.fromRGB(250, 140, 30)

local function brickStuds(
	parent: Instance,
	at: CFrame,
	width: number,
	depth: number,
	y: number,
	color: Color3
)
	for x = -width / 2 + 2, width / 2 - 2, 4 do
		for z = -depth / 2 + 2, depth / 2 - 2, 4 do
			part(
				parent,
				"Stud",
				Vector3.new(0.5, 0.8, 0.8),
				at * CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2),
				color,
				M.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
	end
end

function DockPieces.buildStation(b: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "BuildStation"
	local at = DockConfig.stationSpot(b)
	local baseY = 0.8

	part(
		m,
		"Base",
		Vector3.new(16, baseY, 12),
		at * CFrame.new(0, baseY / 2, 0),
		BRICK_BLUE,
		M.SmoothPlastic
	)
	part(
		m,
		"BackWall",
		Vector3.new(16, 4, 0.8),
		at * CFrame.new(0, baseY + 2, -5.4),
		BRICK_YELLOW,
		M.SmoothPlastic
	)
	part(
		m,
		"SideWallL",
		Vector3.new(0.8, 2.4, 10),
		at * CFrame.new(-7.4, baseY + 1.2, 0),
		BRICK_WHITE,
		M.SmoothPlastic
	)
	part(
		m,
		"SideWallR",
		Vector3.new(0.8, 2.4, 10),
		at * CFrame.new(7.4, baseY + 1.2, 0),
		BRICK_WHITE,
		M.SmoothPlastic
	)
	brickStuds(m, at, 16, 12, baseY + 0.25, BRICK_BLUE)

	-- toolbox
	part(
		m,
		"Toolbox",
		Vector3.new(4.4, 2, 2.6),
		at * CFrame.new(-4.6, baseY + 1, -2.8),
		BRICK_RED,
		M.SmoothPlastic
	)
	part(
		m,
		"ToolboxLid",
		Vector3.new(4.6, 0.5, 2.8),
		at * CFrame.new(-4.6, baseY + 2.25, -2.8),
		BRICK_WHITE,
		M.SmoothPlastic
	)
	part(
		m,
		"ToolboxHandle",
		Vector3.new(1.8, 0.35, 0.35),
		at * CFrame.new(-4.6, baseY + 2.7, -2.8),
		GREY,
		M.Metal
	)

	-- mini crane
	local crane = at * CFrame.new(4.6, baseY, -2.6)
	part(
		m,
		"CraneBase",
		Vector3.new(3, 0.8, 3),
		crane * CFrame.new(0, 0.4, 0),
		BRICK_ORANGE,
		M.SmoothPlastic
	)
	part(
		m,
		"CraneMast",
		Vector3.new(0.8, 7, 0.8),
		crane * CFrame.new(0, 4.3, 0),
		BRICK_YELLOW,
		M.SmoothPlastic
	)
	part(
		m,
		"CraneJib",
		Vector3.new(0.7, 0.7, 5.5),
		crane * CFrame.new(0, 7.7, 1.8) * CFrame.Angles(math.rad(-18), 0, 0),
		BRICK_YELLOW,
		M.SmoothPlastic
	)
	part(
		m,
		"CraneCable",
		Vector3.new(0.12, 3.2, 0.12),
		crane * CFrame.new(0, 5.4, 4.2),
		GREY,
		M.Metal
	)
	part(
		m,
		"CraneHook",
		Vector3.new(0.9, 0.9, 0.9),
		crane * CFrame.new(0, 3.6, 4.2),
		BRICK_RED,
		M.Metal
	)

	-- tablet on its stand at the spawn-side edge, its screen turned toward the spawn (+Z, Marina.spawn)
	local stand = at * CFrame.new(0, baseY, 3.6)
	local face = stand
		* CFrame.new(0, 5.4, 0)
		* CFrame.Angles(0, math.pi, 0)
		* CFrame.Angles(math.rad(-8), 0, 0)
	part(m, "TabletStand", Vector3.new(2.2, 0.6, 2.2), stand * CFrame.new(0, 0.3, 0), GREY, M.Metal)
	part(m, "TabletPost", Vector3.new(0.6, 3.6, 0.6), stand * CFrame.new(0, 2.4, 0), STEEL, M.Metal)
	local tablet = part(
		m,
		"Tablet",
		Vector3.new(6.4, 4.2, 0.35),
		face,
		Color3.fromRGB(24, 28, 38),
		M.SmoothPlastic
	)
	-- a plain lit screen (no Neon slab, no light): the scene lights it like the rest of the station
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 1
	gui.Parent = tablet
	local screen = Instance.new("Frame")
	screen.Name = "Display"
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.new(1, -28, 1, -28) -- the dark bezel round it
	screen.BackgroundColor3 = Color3.fromRGB(44, 92, 150)
	screen.BorderSizePixel = 0
	screen.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 24)
	round.Parent = screen
	local icon = Instance.new("ImageLabel")
	icon.Name = "BuildIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.BackgroundTransparency = 1
	icon.Image = UiImages.Kit.build
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = screen

	return m
end

-- Decorations (WP-14d): bright Lego set pieces on the spare lots. Each builder draws inside its
-- DockConfig footprint, centred on the spot. `FlagPole` names its cloth "Flag" (DockService recolours it).
local DECOR_BUILDERS: { [string]: (Model, CFrame, DockConfig.Decor) -> () } = {}

DECOR_BUILDERS.FlowerBed = function(m: Model, at: CFrame, d: DockConfig.Decor)
	local w, dep = d.size.X, d.size.Y
	part(
		m,
		"Planter",
		Vector3.new(w, 1, dep),
		at * CFrame.new(0, 0.5, 0),
		BRICK_GREEN,
		M.SmoothPlastic
	)
	part(
		m,
		"Soil",
		Vector3.new(w - 1, 0.4, dep - 1),
		at * CFrame.new(0, 1.1, 0),
		DARK,
		M.SmoothPlastic
	)
	local blooms = { BRICK_RED, BRICK_YELLOW, BRICK_PINK, BRICK_WHITE }
	for i = 1, 6 do
		local x = -2.6 + ((i - 1) % 3) * 2.6
		local z = if i <= 3 then -1.6 else 1.6
		part(
			m,
			"Stem",
			Vector3.new(0.25, 1.4, 0.25),
			at * CFrame.new(x, 1.9, z),
			BRICK_GREEN,
			M.SmoothPlastic
		)
		part(
			m,
			"Bloom",
			Vector3.new(1.1, 1.1, 1.1),
			at * CFrame.new(x, 2.7, z),
			blooms[(i - 1) % #blooms + 1],
			M.SmoothPlastic,
			Enum.PartType.Ball
		)
	end
end

DECOR_BUILDERS.PicnicTable = function(m: Model, at: CFrame, _d: DockConfig.Decor)
	part(
		m,
		"TableTop",
		Vector3.new(6, 0.5, 4),
		at * CFrame.new(0, 2.3, 0),
		BRICK_RED,
		M.SmoothPlastic
	)
	for _, z in { -2.5, 2.5 } do
		part(
			m,
			"Bench",
			Vector3.new(6, 0.5, 1.2),
			at * CFrame.new(0, 1.4, z),
			BRICK_YELLOW,
			M.SmoothPlastic
		)
	end
	for _, x in { -2.2, 2.2 } do
		for _, z in { -1.6, 1.6 } do
			part(m, "Leg", Vector3.new(0.5, 2, 0.5), at * CFrame.new(x, 1, z), GREY, M.Metal)
		end
	end
end

DECOR_BUILDERS.LampRow = function(m: Model, at: CFrame, d: DockConfig.Decor)
	part(m, "Rail", Vector3.new(d.size.X, 0.6, 1.6), at * CFrame.new(0, 0.3, 0), GREY, M.Metal)
	for _, x in { -3, 0, 3 } do
		part(
			m,
			"LampPost",
			Vector3.new(9, 0.5, 0.5),
			at * CFrame.new(x, 4.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
			STEEL,
			M.Metal,
			Enum.PartType.Cylinder
		)
		part(
			m,
			"LampBulb",
			Vector3.new(1.2, 1.2, 1.2),
			at * CFrame.new(x, 9.5, 0),
			WARM,
			M.Neon,
			Enum.PartType.Ball
		)
	end
end

DECOR_BUILDERS.FlagPole = function(m: Model, at: CFrame, _d: DockConfig.Decor)
	part(
		m,
		"PoleBase",
		Vector3.new(3, 0.8, 3),
		at * CFrame.new(0, 0.4, 0),
		BRICK_WHITE,
		M.SmoothPlastic
	)
	part(
		m,
		"Pole",
		Vector3.new(20, 0.5, 0.5),
		at * CFrame.new(0, 10.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
		STEEL,
		M.Metal,
		Enum.PartType.Cylinder
	)
	part(m, "Flag", Vector3.new(0.15, 4.5, 7), at * CFrame.new(0, 17.8, 3.6), WHITE, M.Fabric).CanCollide =
		false
	part(
		m,
		"Finial",
		Vector3.new(1, 1, 1),
		at * CFrame.new(0, 20.8, 0),
		GOLD,
		M.Metal,
		Enum.PartType.Ball
	)
end

DECOR_BUILDERS.Statue = function(m: Model, at: CFrame, _d: DockConfig.Decor)
	part(m, "Plinth", Vector3.new(5, 1.8, 5), at * CFrame.new(0, 0.9, 0), GREY, M.SmoothPlastic)
	part(
		m,
		"PlinthTop",
		Vector3.new(4.2, 0.4, 4.2),
		at * CFrame.new(0, 2, 0),
		BRICK_WHITE,
		M.SmoothPlastic
	)
	part(m, "Legs", Vector3.new(2.6, 2.2, 1.6), at * CFrame.new(0, 3.3, 0), GOLD, M.Metal)
	part(m, "Torso", Vector3.new(3.2, 2.6, 1.8), at * CFrame.new(0, 5.7, 0), GOLD, M.Metal)
	part(m, "Head", Vector3.new(2, 2, 2), at * CFrame.new(0, 8, 0), GOLD, M.Metal)
	for _, x in { -2.1, 2.1 } do
		part(
			m,
			"Arm",
			Vector3.new(0.9, 2.4, 1),
			at * CFrame.new(x, 5.8, 0) * CFrame.Angles(0, 0, math.rad(12 * x)),
			GOLD,
			M.Metal
		)
	end
end

DECOR_BUILDERS.Fountain = function(m: Model, at: CFrame, d: DockConfig.Decor)
	local rim = d.size.X / 2
	part(
		m,
		"Basin",
		Vector3.new(1.2, rim * 2, rim * 2),
		at * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		BRICK_WHITE,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	local water = part(
		m,
		"Water",
		Vector3.new(0.4, rim * 2 - 1.2, rim * 2 - 1.2),
		at * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(80, 190, 255),
		M.Glass,
		Enum.PartType.Cylinder
	)
	water.Transparency = 0.3
	part(
		m,
		"Column",
		Vector3.new(2.6, 1.4, 1.4),
		at * CFrame.new(0, 2.6, 0),
		BRICK_CYAN,
		M.SmoothPlastic
	)
	part(
		m,
		"Bowl",
		Vector3.new(0.6, 3.4, 3.4),
		at * CFrame.new(0, 3.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
		BRICK_WHITE,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	local jet = part(
		m,
		"Jet",
		Vector3.new(3, 0.4, 0.4),
		at * CFrame.new(0, 5.4, 0),
		Color3.fromRGB(150, 230, 255),
		M.Neon,
		Enum.PartType.Cylinder
	)
	jet.Transparency = 0.2
end

-- The Model for decoration `key` (DockConfig.Decorations) on its spare-lot spot in the berth frame `b`.
function DockPieces.decoration(key: string, b: CFrame): Model
	local m = Instance.new("Model")
	m.Name = key
	local d = DockConfig.Decorations[key]
	local at = DockConfig.decorSpot(key, b)
	local fn = DECOR_BUILDERS[key]
	if d and at and fn then
		fn(m, at, d)
	end
	return m
end

return DockPieces
