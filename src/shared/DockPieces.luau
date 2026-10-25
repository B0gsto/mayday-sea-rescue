--!strict
-- DockPieces (docs/23 d.2, WP-4): the placeholder Parts each dock level adds, in the berth frame
-- (Marina.berth: -Z = out to sea, the deck at z 27.5..52.5, top y 3; the craft at x -7..7; the jetty
-- finger at x 10..18). DockService builds them on the plot (everyone sees them); DockController builds
-- the next level again as the owner's local ghost. Named hooks: parts "Flag" take the owner's colour,
-- TextLabels "Count" show the rescue count, TextLabels "Owner" the owner's name. The WP-10b buildings
-- (DockPieces.building) sit in their own frame: the garage in Marina.garage(plot), the others in the berth frame. Materials stay off the MaterialService remap (no Slate,
-- WoodPlanks, Brick, Concrete).
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(script.Parent:WaitForChild("Marina"))

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

local M = Enum.Material
local TOP = 3

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
		Vector3.new(h, 0.35, 0.35),
		b * CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		M.Metal,
		Enum.PartType.Cylinder
	)
end

local function lamp(parent: Instance, b: CFrame, x: number, z: number, y0: number)
	pole(parent, b, x, z, y0, 7, GREY)
	local bulb = part(
		parent,
		"Lamp",
		Vector3.new(1, 1, 1),
		b * CFrame.new(x, y0 + 7.3, z),
		WARM,
		M.Neon,
		Enum.PartType.Ball
	)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = bulb
end

local function flag(parent: Instance, b: CFrame, x: number, z: number, y0: number, h: number)
	pole(parent, b, x, z, y0, h, STEEL)
	local f = part(
		parent,
		"Flag",
		Vector3.new(0.15, 3, 5),
		b * CFrame.new(x, y0 + h - 1.6, z + 2.6),
		WHITE,
		M.Fabric
	)
	f.CanCollide = false
end

-- Lv 2: pontoon (the second berth), lamp posts, a tall flag, the rescue-count board
local function level2(m: Model, b: CFrame)
	part(m, "Pontoon", Vector3.new(6, 0.8, 50), b * CFrame.new(-16, 1.6, 2), WHITE, M.SmoothPlastic)
	for z = -18, 22, 10 do
		part(m, "Float", Vector3.new(5, 1.4, 4), b * CFrame.new(-16, 0.6, z), GREY, M.Metal)
		part(m, "Cleat", Vector3.new(0.5, 0.4, 1.4), b * CFrame.new(-13.4, 2.2, z), GREY, M.Metal)
	end
	lamp(m, b, 17.4, -18, TOP)
	lamp(m, b, 17.4, 4, TOP)
	lamp(m, b, -18.5, -18, 2)
	lamp(m, b, -18.5, 4, 2)
	flag(m, b, -16, -22, 2, 18)

	-- rescue board on the deck, facing the sea: a life ring and one big number
	local at = b * CFrame.new(22, TOP + 4.2, 34)
	for _, dx in { -3.2, 3.2 } do
		part(m, "BoardPost", Vector3.new(0.5, 6.4, 0.5), at * CFrame.new(dx, -1, 0.4), DARK, M.Wood)
	end
	local board = part(
		m,
		"RescueBoard",
		Vector3.new(7.6, 4.4, 0.4),
		at,
		Color3.fromRGB(28, 44, 66),
		M.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = board
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.fromScale(0.06, 0.5)
	ring.Size = UDim2.fromScale(0.27, 0.27 * 7.6 / 4.4)
	ring.BackgroundTransparency = 1
	ring.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = ORANGE
	stroke.Thickness = 16
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

-- Lv 3: boathouse on the deck's west side, the roll-up door facing the water, a clear marked floor
-- spot for the boat board (DockConfig.BOARD_SLOT) at the back wall
local function level3(m: Model, b: CFrame)
	local x0, x1, z0, z1, h = -20, -2, 30, 52, 11
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local y = TOP + h / 2
	part(m, "Wall", Vector3.new(0.6, h, z1 - z0), b * CFrame.new(x0, y, cz), WHITE, M.Wood)
	part(m, "Wall", Vector3.new(0.6, h, z1 - z0), b * CFrame.new(x1, y, cz), WHITE, M.Wood)
	part(m, "Wall", Vector3.new(x1 - x0, h, 0.6), b * CFrame.new(cx, y, z1), WHITE, M.Wood)
	-- front: two pillars, the header and the half-rolled door
	part(m, "Wall", Vector3.new(3, h, 0.6), b * CFrame.new(x0 + 1.5, y, z0), WHITE, M.Wood)
	part(m, "Wall", Vector3.new(3, h, 0.6), b * CFrame.new(x1 - 1.5, y, z0), WHITE, M.Wood)
	part(
		m,
		"Header",
		Vector3.new(x1 - x0, 3, 0.6),
		b * CFrame.new(cx, TOP + h - 1.5, z0),
		WHITE,
		M.Wood
	)
	local doorW = x1 - x0 - 6
	part(
		m,
		"Door",
		Vector3.new(doorW, 3, 0.3),
		b * CFrame.new(cx, TOP + h - 4.5, z0 + 0.1),
		RED,
		M.Metal
	)
	part(
		m,
		"DoorRoll",
		Vector3.new(doorW, 1.4, 1.4),
		b * CFrame.new(cx, TOP + h - 2.6, z0 - 0.9),
		RED,
		M.Metal,
		Enum.PartType.Cylinder
	)
	-- gabled roof, ridge along z
	local run, rise = (x1 - x0) / 2 + 0.6, 3.6
	local angle = math.atan2(rise, run)
	local len = math.sqrt(run * run + rise * rise)
	for _, side in { -1, 1 } do
		part(
			m,
			"Roof",
			Vector3.new(len + 0.4, 0.5, z1 - z0 + 1.6),
			b
				* CFrame.new(cx + side * run / 2, TOP + h + rise / 2, cz)
				* CFrame.Angles(0, 0, -side * angle),
			RED,
			M.SmoothPlastic
		)
		for _, z in { z0, z1 } do
			wedge(
				m,
				Vector3.new(0.6, rise, run - 0.6),
				b
					* CFrame.new(cx + side * (run - 0.6) / 2, TOP + h + rise / 2, z)
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
			c * CFrame.new(e[1], 0.03, e[2]),
			YELLOW,
			M.SmoothPlastic
		)
		line.CanCollide = false
	end
end

-- Lv 4: lookout tower at the deck's east end, slipway crane over the berth
local function level4(m: Model, b: CFrame)
	local tx, tz, legH = 24, 47, 14
	for _, d in { { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } } do
		part(
			m,
			"Leg",
			Vector3.new(0.6, legH, 0.6),
			b * CFrame.new(tx + d[1], TOP + legH / 2, tz + d[2]),
			STEEL,
			M.Metal
		)
	end
	for _, yy in { 5, 10 } do
		part(
			m,
			"Brace",
			Vector3.new(5.6, 0.3, 0.3),
			b * CFrame.new(tx, TOP + yy, tz - 2.5),
			STEEL,
			M.Metal
		)
		part(
			m,
			"Brace",
			Vector3.new(5.6, 0.3, 0.3),
			b * CFrame.new(tx, TOP + yy, tz + 2.5),
			STEEL,
			M.Metal
		)
	end
	local floorY = TOP + legH
	part(m, "Platform", Vector3.new(7, 0.6, 7), b * CFrame.new(tx, floorY + 0.3, tz), WOOD, M.Wood)
	for _, w in
		{ { 0, -3.2, 6.4, 0.2 }, { 0, 3.2, 6.4, 0.2 }, { -3.2, 0, 0.2, 6.4 }, { 3.2, 0, 0.2, 6.4 } }
	do
		local g = part(
			m,
			"Window",
			Vector3.new(w[3], 3, w[4]),
			b * CFrame.new(tx + w[1], floorY + 2.1, tz + w[2]),
			Color3.fromRGB(150, 200, 230),
			M.Glass
		)
		g.Transparency = 0.45
	end
	part(
		m,
		"TowerRoof",
		Vector3.new(7.6, 0.6, 7.6),
		b * CFrame.new(tx, floorY + 3.9, tz),
		RED,
		M.SmoothPlastic
	)
	-- crane: mast on the deck edge, boom out over the berth, cable and hook
	local cx, cz, mastH = 4, 32, 16
	part(m, "CraneBase", Vector3.new(3, 1, 3), b * CFrame.new(cx, TOP + 0.5, cz), GREY, M.Metal)
	part(
		m,
		"Mast",
		Vector3.new(1.2, mastH, 1.2),
		b * CFrame.new(cx, TOP + mastH / 2, cz),
		YELLOW,
		M.Metal
	)
	local boomY = TOP + mastH - 0.5
	part(m, "Boom", Vector3.new(1, 1, 28), b * CFrame.new(cx, boomY, cz - 9), YELLOW, M.Metal)
	part(
		m,
		"Counterweight",
		Vector3.new(2.4, 2, 2.4),
		b * CFrame.new(cx, boomY - 1, cz + 4),
		GREY,
		M.Metal
	)
	part(
		m,
		"Cable",
		Vector3.new(0.15, 7, 0.15),
		b * CFrame.new(cx, boomY - 4, cz - 22),
		GREY,
		M.Metal
	).CanCollide =
		false
	part(m, "Hook", Vector3.new(0.8, 1, 0.8), b * CFrame.new(cx, boomY - 8, cz - 22), RED, M.Metal)
end

-- Lv 5: lit station front on the boathouse, a beacon on the tower, light strips along the jetty
local function level5(m: Model, b: CFrame)
	local cx, z0 = -11, 29.4
	part(
		m,
		"StationFront",
		Vector3.new(18.6, 2.4, 0.4),
		b * CFrame.new(cx, TOP + 12, z0),
		WHITE,
		M.SmoothPlastic
	)
	part(
		m,
		"Stripe",
		Vector3.new(18.6, 0.5, 0.45),
		b * CFrame.new(cx, TOP + 10.6, z0),
		ORANGE,
		M.Neon
	)
	part(
		m,
		"Stripe",
		Vector3.new(18.6, 0.3, 0.45),
		b * CFrame.new(cx, TOP + 13.3, z0),
		Color3.fromRGB(40, 90, 200),
		M.Neon
	)
	for _, x in { -18, -4 } do
		local flood = part(
			m,
			"Floodlight",
			Vector3.new(1.2, 0.8, 0.8),
			b * CFrame.new(x, TOP + 9.6, z0 - 0.4) * CFrame.Angles(math.rad(-35), 0, 0),
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
	for _, x in { 10.1, 17.9 } do
		part(
			m,
			"JettyLight",
			Vector3.new(0.2, 0.15, 47),
			b * CFrame.new(x, TOP + 0.05, 3.75),
			WARM,
			M.Neon
		).CanCollide =
			false
	end
	-- beacon on the lookout tower roof (Lv 4): a lens, a wide light, a beam into the sky
	local top = b * CFrame.new(24, TOP + 14 + 4.2, 47)
	part(m, "BeaconBase", Vector3.new(1.6, 0.6, 1.6), top * CFrame.new(0, 0.3, 0), GREY, M.Metal)
	local lens = part(
		m,
		"Beacon",
		Vector3.new(1.4, 1.4, 1.4),
		top * CFrame.new(0, 1.3, 0),
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
	beam.Width0, beam.Width1 = 2.5, 7
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 140, 100))
	beam.Transparency = NumberSequence.new(0.7, 1)
	beam.Parent = lens
end

local LEVELS = { [2] = level2, [3] = level3, [4] = level4, [5] = level5 }

-- WP-10b buildings ------------------------------------------------------------------------------

local G = Marina.GARAGE
local GARAGE_H = 10 -- the CoastguardResponse's light bar clears the door
local PAD_Y = TOP + 11 + 4.6 -- the helipad's top, on posts over the Lv 3 boathouse ridge
local PEN = { x0 = 19.6, x1 = 28.4, z0 = -21, z1 = 1, top = 14 } -- the sub pen gantry, east of the jetty

-- In each building's frame: `buildAt` = the ghost's Build prompt, `board` = the vehicle board's rack (models
-- along its X, facing its -Z), `targets[id]` = where that craft spawns (the berth when absent), `hook` = the
-- gantry height the sub hangs from.
DockPieces.Buildings = {
	Garage = {
		buildAt = CFrame.new(0, 3, 4),
		board = CFrame.new(G.WIDTH / 2 - 2.2, 0, G.DEPTH / 2) * CFrame.Angles(0, math.pi / 2, 0),
		targets = {} :: { [string]: CFrame },
	},
	Hangar = {
		buildAt = CFrame.new(1, TOP + 2.5, 34),
		board = CFrame.new(-11, PAD_Y, 50.4),
		targets = { RescueHelicopter = CFrame.new(-11, PAD_Y, 38) } :: { [string]: CFrame },
	},
	SubPen = {
		buildAt = CFrame.new(14, TOP + 2.5, -10),
		board = CFrame.new(16.5, TOP, -12) * CFrame.Angles(0, -math.pi / 2, 0),
		targets = { Submarine = CFrame.new((PEN.x0 + PEN.x1) / 2, 0, (PEN.z0 + PEN.z1) / 2) } :: { [string]: CFrame },
		hook = PEN.top - 0.5,
	},
}
for _, id in DockConfig.Buildings.Garage.vehicles do
	-- beside the board's lane, nose out of the door
	DockPieces.Buildings.Garage.targets[id] = CFrame.new(-2.6, 0, G.DEPTH / 2)
end

-- the garage bay: walls, a flat roof, the header with the owner's name over a stripe in their colour, the
-- roll-up door's drum (their colour too) and a ceiling light; the floor is DockService's lot
local function garage(m: Model, g: CFrame)
	local w, d, h = G.WIDTH, G.DEPTH, GARAGE_H
	for _, side in { -1, 1 } do
		part(
			m,
			"Wall",
			Vector3.new(0.6, h, d),
			g * CFrame.new(side * (w / 2 - 0.3), h / 2, d / 2),
			WHITE,
			M.SmoothPlastic
		)
	end
	part(
		m,
		"Wall",
		Vector3.new(w, h, 0.6),
		g * CFrame.new(0, h / 2, d - 0.3),
		WHITE,
		M.SmoothPlastic
	)
	part(
		m,
		"Roof",
		Vector3.new(w, 0.6, d + 1),
		g * CFrame.new(0, h + 0.3, d / 2 - 0.5),
		GREY,
		M.Metal
	)
	local header = part(
		m,
		"Header",
		Vector3.new(w, 2.2, 0.6),
		g * CFrame.new(0, h - 1.1, 0.3),
		WHITE,
		M.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = header
	local name = Instance.new("TextLabel")
	name.Name = "Owner"
	name.Size = UDim2.fromScale(1, 1)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(30, 38, 52)
	name.Text = ""
	name.Parent = gui
	part(
		m,
		"Flag",
		Vector3.new(w, 0.5, 0.2),
		g * CFrame.new(0, h - 2.45, 0.1),
		WHITE,
		M.SmoothPlastic
	)
	part(
		m,
		"Flag",
		Vector3.new(w - 1.2, 1.4, 1.4),
		g * CFrame.new(0, h - 1.1, -0.8),
		WHITE,
		M.Metal,
		Enum.PartType.Cylinder
	)
	for _, side in { -1, 1 } do
		part(
			m,
			"DoorRail",
			Vector3.new(0.3, h - 2.2, 0.3),
			g * CFrame.new(side * (w / 2 - 0.75), (h - 2.2) / 2, 0.2),
			GREY,
			M.Metal
		)
	end
	local strip = part(
		m,
		"Light",
		Vector3.new(0.6, 0.2, d - 6),
		g * CFrame.new(0, h - 0.1, d / 2),
		WARM,
		M.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 16
	light.Brightness = 1
	light.Parent = strip
end

-- the helipad on posts over the boathouse roof (an H, an edge line and lights), a small hangar shelter at its
-- back and a ladder up the boathouse's open side
local function hangar(m: Model, b: CFrame)
	local x0, x1, z0, z1 = -20.5, -1.5, 29.5, 52.5
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	for _, x in { x0 + 1, x1 - 1 } do
		for _, z in { z0 + 1, z1 - 1 } do
			part(
				m,
				"Post",
				Vector3.new(0.8, PAD_Y - TOP - 11, 0.8),
				b * CFrame.new(x, (PAD_Y + TOP + 11) / 2, z),
				GREY,
				M.Metal
			)
		end
	end
	part(
		m,
		"Pad",
		Vector3.new(x1 - x0, 0.6, z1 - z0),
		b * CFrame.new(cx, PAD_Y - 0.3, cz),
		GREY,
		M.SmoothPlastic
	)
	local hz = 38
	for _, e in { { 0, -8, 15, 0.4 }, { 0, 8, 15, 0.4 }, { -7.5, 0, 0.4, 16 }, { 7.5, 0, 0.4, 16 } } do
		part(
			m,
			"PadLine",
			Vector3.new(e[3], 0.06, e[4]),
			b * CFrame.new(cx + e[1], PAD_Y + 0.03, hz + e[2]),
			YELLOW,
			M.SmoothPlastic
		).CanCollide =
			false
	end
	for _, e in { { -2.4, 0, 1.2, 7 }, { 2.4, 0, 1.2, 7 }, { 0, 0, 4.8, 1.2 } } do
		part(
			m,
			"H",
			Vector3.new(e[3], 0.08, e[4]),
			b * CFrame.new(cx + e[1], PAD_Y + 0.04, hz + e[2]),
			WHITE,
			M.SmoothPlastic
		).CanCollide =
			false
	end
	for _, x in { x0 + 0.4, cx, x1 - 0.4 } do
		for _, z in { z0 + 0.4, hz, 46 } do
			if x ~= cx or z ~= hz then
				local bulb = part(
					m,
					"PadLight",
					Vector3.new(0.5, 0.5, 0.5),
					b * CFrame.new(x, PAD_Y + 0.25, z),
					Color3.fromRGB(90, 255, 120),
					M.Neon,
					Enum.PartType.Ball
				)
				bulb.CanCollide = false
			end
		end
	end
	-- the hangar shelter: back wall, two side walls, a red roof
	local sz0, sh = 46.5, 7
	part(
		m,
		"Wall",
		Vector3.new(x1 - x0, sh, 0.4),
		b * CFrame.new(cx, PAD_Y + sh / 2, z1 - 0.2),
		WHITE,
		M.Wood
	)
	for _, x in { x0 + 0.2, x1 - 0.2 } do
		part(
			m,
			"Wall",
			Vector3.new(0.4, sh, z1 - sz0),
			b * CFrame.new(x, PAD_Y + sh / 2, (sz0 + z1) / 2),
			WHITE,
			M.Wood
		)
	end
	part(
		m,
		"HangarRoof",
		Vector3.new(x1 - x0 + 0.4, 0.5, z1 - sz0 + 1),
		b * CFrame.new(cx, PAD_Y + sh + 0.25, (sz0 + z1) / 2 - 0.5),
		RED,
		M.SmoothPlastic
	)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, PAD_Y - TOP, 2)
	ladder.CFrame = b * CFrame.new(x1 + 1, (PAD_Y + TOP) / 2, 36)
	ladder.Color = GREY
	ladder.Material = M.Metal
	ladder.Anchored = true
	ladder.Parent = m
end

-- the sub pen: a steel gantry over a moon-pool collar in the water east of the jetty
local function subPen(m: Model, b: CFrame)
	local p = PEN
	local cx, cz = (p.x0 + p.x1) / 2, (p.z0 + p.z1) / 2
	for _, x in { p.x0, p.x1 } do
		for _, z in { p.z0, p.z1 } do
			part(
				m,
				"Leg",
				Vector3.new(0.8, p.top + 6, 0.8),
				b * CFrame.new(x, (p.top - 6) / 2, z),
				GREY,
				M.Metal
			)
		end
		part(
			m,
			"Beam",
			Vector3.new(0.8, 0.8, p.z1 - p.z0 + 0.8),
			b * CFrame.new(x, p.top, cz),
			YELLOW,
			M.Metal
		)
	end
	for _, z in { p.z0, p.z1 } do
		part(
			m,
			"Beam",
			Vector3.new(p.x1 - p.x0, 0.8, 0.8),
			b * CFrame.new(cx, p.top, z),
			YELLOW,
			M.Metal
		)
	end
	part(
		m,
		"Trolley",
		Vector3.new(p.x1 - p.x0, 1, 1.4),
		b * CFrame.new(cx, p.top + 0.1, cz),
		GREY,
		M.Metal
	)
	-- the floating collar round the pool, at the waterline
	for _, x in { p.x0 + 0.6, p.x1 - 0.6 } do
		part(
			m,
			"Collar",
			Vector3.new(1, 1, p.z1 - p.z0),
			b * CFrame.new(x, 0.3, cz),
			ORANGE,
			M.SmoothPlastic
		)
	end
	for _, z in { p.z0 + 0.5, p.z1 - 0.5 } do
		part(
			m,
			"Collar",
			Vector3.new(p.x1 - p.x0 - 2.2, 1, 1),
			b * CFrame.new(cx, 0.3, z),
			ORANGE,
			M.SmoothPlastic
		)
	end
	-- a plank from the jetty onto the collar
	part(
		m,
		"Plank",
		Vector3.new(p.x0 - 18 + 0.6, 0.4, 3),
		b * CFrame.new((18 + p.x0 + 0.6) / 2, TOP - 0.2, -10),
		WOOD,
		M.Wood
	)
end

local BUILDINGS = { Garage = garage, Hangar = hangar, SubPen = subPen }

-- The pieces of building `key` (DockConfig.Buildings) around its frame `cf`, as a Model named `key`.
function DockPieces.building(key: string, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = key
	local fn = BUILDINGS[key]
	if fn then
		fn(m, cf)
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

return DockPieces
