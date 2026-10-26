--!strict
-- DockPieces (docs/23 d.2, WP-4; WP-19b; the unlock tree, WP-28): the placeholder Parts of every island building
-- (DockConfig.Buildings), around the berth frame (Marina.berth: the island's boat berth at sea level, -Z = out of
-- the cove, the craft at x -7..7, the jetty finger at x -17..-9, the jetty at x -27..-17). Each stands on its
-- island lot (Marina.LOTS, berth frame): the pontoon (beside the berth), lamps, rescue board on the quay; the
-- boathouse (its lot) + paint booth arches over the berth; the lookout tower (the beach tower lot); the slipway
-- crane on the quay; the station (its lot): lit front, roof beacon; the trophy hall wall on its front; the
-- helipad and hangar on their lots; the sub pen over the sub berth; the worker buildings as open work yards
-- (docs/24 C) and the lifeboat slip on their DockConfig spot. DockService builds them (everyone sees them); a buy plays the Lego build
-- beat (shared/BuildSeq) client-side. The build station (docs/23 (j) rule 4, WP-14d) stands on the Spare3
-- lot by the spawn, and the Cash-only decorations on the Spare2 / Spare3 spare lots. Named hooks: parts
-- "Flag" take the owner's colour, TextLabels "Count" show the rescue count. Materials stay off the
-- MaterialService remap (no Slate, WoodPlanks, Brick, Concrete).
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(script.Parent:WaitForChild("Marina"))
local RingLayout = require(script.Parent:WaitForChild("Config"):WaitForChild("RingLayout"))
local UiImages = require(script.Parent:WaitForChild("Config"):WaitForChild("UiImages"))

local DockPieces = {}

local WOOD = Color3.fromRGB(105, 64, 40) -- WP-25: Lego reddish brown
local DARK = Color3.fromRGB(84, 62, 44)
local WHITE = Color3.fromRGB(242, 240, 232)
local STEEL = Color3.fromRGB(190, 194, 198)
local GREY = Color3.fromRGB(99, 95, 98) -- WP-25: Lego dark bluish grey
local RED = Color3.fromRGB(224, 56, 40)
local ORANGE = Color3.fromRGB(250, 140, 30)
local YELLOW = Color3.fromRGB(250, 208, 40)
local WARM = Color3.fromRGB(255, 214, 150)

local NAVY = Color3.fromRGB(30, 44, 66)
local GOLD = Color3.fromRGB(222, 178, 60)
-- Lego brick colours (the build station, decor, the WP-28 huts)
local BRICK_RED = Color3.fromRGB(224, 56, 40)
local BRICK_YELLOW = Color3.fromRGB(250, 208, 40)
local BRICK_BLUE = Color3.fromRGB(40, 96, 208)
local BRICK_GREEN = Color3.fromRGB(80, 190, 90)
local BRICK_WHITE = Color3.fromRGB(242, 240, 232)
local BRICK_CYAN = Color3.fromRGB(60, 220, 255)
local BRICK_PINK = Color3.fromRGB(250, 120, 190)
local BRICK_ORANGE = Color3.fromRGB(250, 140, 30)
local LBG = Color3.fromRGB(163, 162, 165) -- Lego light bluish grey: plinths, plates
local DBG = Color3.fromRGB(99, 95, 98) -- dark bluish grey: metal bits
local TAN = Color3.fromRGB(212, 184, 132) -- paths, decks (Lego tan, a shade down: the sun bleaches it)
local RBROWN = Color3.fromRGB(105, 64, 40) -- reddish brown: wood
local PANE = Color3.fromRGB(150, 205, 240) -- window glass
local INK = Color3.fromRGB(30, 44, 66) -- sign text
local STUDS = "rbxassetid://18878365966" -- a white 4 x 4 stud tile (IslandPlates)

local M = Enum.Material
local TOP = Marina.DECK_TOP
local LOT = Marina.LOTS
-- the station: half width, half depth, height; the trophy hall is on its front wall, left of the door
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
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
end

local function lamp(parent: Instance, b: CFrame, x: number, z: number, y0: number)
	pole(parent, b, x, z, y0, 10, DBG)
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

-- WP-25 Lego kit ------------------------------------------------------------------------------------------
-- Every building shares it: SmoothPlastic bricks, chunky 2-stud studs (a tinted Texture) on flat tops, a light
-- grey stud plinth, white window frames, a door in the owner's colour (parts named "Flag" take it), solid
-- slope-brick roofs, tan tile paths to the lanes (DockPieces.base).

local function brick(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3
): BasePart
	return part(parent, name, size, cf, color, M.SmoothPlastic)
end

-- chunky studs on a part's top face (2 studs apart), a shade darker than the part
local function studTop(p: BasePart)
	local t = Instance.new("Texture")
	t.Name = "Studs"
	t.Face = Enum.NormalId.Top
	t.Texture = STUDS
	t.StudsPerTileU, t.StudsPerTileV = 8, 8
	t.Color3 = p.Color:Lerp(Color3.new(0, 0, 0), 0.12)
	t.Transparency = 0.15
	t.Parent = p
end

-- a crisp `px`-pixel border (8 px a stud) round a plate's top face: SurfaceGui frames named "Rim", no parts
local function border(p: BasePart, color: Color3, px: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.LightInfluence = 1
	gui.Parent = p
	for _, e in { { 0, 0, 1, 0 }, { 0, 1, 1, 0 }, { 0, 0, 0, 1 }, { 1, 0, 0, 1 } } do
		local f = Instance.new("Frame")
		f.Name = "Rim"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.AnchorPoint = Vector2.new(e[1], e[2])
		f.Position = UDim2.fromScale(e[1], e[2])
		f.Size = UDim2.new(e[3], if e[3] == 0 then px else 0, e[4], if e[4] == 0 then px else 0)
		f.Parent = gui
	end
	return gui
end

local function plinth(parent: Instance, size: Vector3, cf: CFrame, color: Color3?): BasePart
	local p = brick(parent, "Plinth", size, cf, color or LBG)
	studTop(p)
	return p
end

-- a solid gable roof of two slope bricks on `top` (centre of the wall top), ridge along Z: the triangle shows at
-- the front (-Z) and back
local function gable(
	parent: Instance,
	top: CFrame,
	w: number,
	d: number,
	rise: number,
	color: Color3
)
	for _, side in { -1, 1 } do
		local wdg = Instance.new("WedgePart")
		wdg.Name = "Roof"
		wdg.Size = Vector3.new(d, rise, w / 2)
		wdg.CFrame = top
			* CFrame.new(side * w / 4, rise / 2, 0)
			* CFrame.Angles(0, -side * math.pi / 2, 0)
		wdg.Color = color
		wdg.Material = M.SmoothPlastic
		wdg.Anchored = true
		wdg.Parent = parent
		-- WP-25 r9: a darker eaves trim: the roof's outline reads from the top-down camera on a phone
		brick(
			parent,
			"Eaves",
			Vector3.new(1.4, 0.9, d + 0.4),
			top * CFrame.new(side * (w / 2 + 0.3), 0.15, 0),
			color:Lerp(Color3.new(0, 0, 0), 0.45)
		)
	end
	brick(parent, "Ridge", Vector3.new(1.2, 0.8, d), top * CFrame.new(0, rise + 0.2, 0), color)
end

-- a white-framed window on a wall face (`at` on the face, -Z out of the wall)
local function window(parent: Instance, at: CFrame, w: number, h: number)
	brick(parent, "WindowFrame", Vector3.new(w, h, 0.3), at * CFrame.new(0, 0, -0.15), BRICK_WHITE)
	brick(parent, "Window", Vector3.new(w - 0.8, h - 0.8, 0.3), at * CFrame.new(0, 0, -0.3), PANE)
end

-- a door in the owner's colour in a white frame (`at` = the door's foot on the wall face, -Z out)
local function frontDoor(parent: Instance, at: CFrame, w: number, h: number)
	brick(
		parent,
		"DoorFrame",
		Vector3.new(w + 1, h + 0.6, 0.3),
		at * CFrame.new(0, (h + 0.6) / 2, -0.15),
		BRICK_WHITE
	)
	brick(parent, "Flag", Vector3.new(w, h, 0.3), at * CFrame.new(0, h / 2, -0.3), BRICK_RED)
end

-- a sign brick, its face toward -Z: an optional Kit icon left of 1-3 words (both faces when `both`)
local function sign(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	text: string,
	icon: string?,
	both: boolean?
): BasePart
	local p = brick(parent, "Sign", size, cf, color)
	p.CanCollide = false
	local faces: { Enum.NormalId } = { Enum.NormalId.Front }
	if both then
		table.insert(faces, Enum.NormalId.Back)
	end
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.4
		gui.Parent = p
		local iconW = if icon then size.Y / size.X else 0
		if icon then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = icon
			img.ScaleType = Enum.ScaleType.Fit
			img.Position = UDim2.fromScale(0.03, 0.1)
			img.Size = UDim2.fromScale(iconW * 0.8, 0.8)
			img.Parent = gui
		end
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04 + iconW * 0.8, 0.12)
		label.Size = UDim2.fromScale(0.92 - iconW * 0.8, 0.76)
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = if color == BRICK_WHITE or color == BRICK_YELLOW
			then INK
			else BRICK_WHITE
		label.Text = text
		label.Parent = gui
	end
	return p
end

-- the island frame (right, fwd on the plate top) of the berth frame `b`
local function isle(b: CFrame, r: number, f: number): CFrame
	return b * Marina.ISLAND * CFrame.new(r, 0, -f)
end

-- a tan Lego plate path on the island plate through island (r, f) points, 8 wide, one part per leg (the
-- legs overlap at the corners)
local function path(parent: Instance, b: CFrame, pts: { Vector2 })
	for k = 1, #pts - 1 do
		local from, to =
			isle(b, pts[k].X, pts[k].Y).Position, isle(b, pts[k + 1].X, pts[k + 1].Y).Position
		local p = brick(
			parent,
			"Path",
			Vector3.new(8, 0.3, (to - from).Magnitude + 8),
			CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, 0.15 + (k % 2) * 0.02, 0), -- no z-fight at corners
			TAN -- WP-25 r7: warm tan walks (grey read cold against the plate)
		)
		p.CanCollide, p.CastShadow = false, false
		local t = Instance.new("Texture")
		t.Face = Enum.NormalId.Top
		t.Texture = STUDS
		t.StudsPerTileU, t.StudsPerTileV = 8, 8
		t.Color3 = TAN:Lerp(Color3.new(0, 0, 0), 0.15)
		t.Transparency = 0.1
		t.Parent = p
	end
end

-- the pontoon (the second berth, past the craft from the jetty): a white stud deck on grey floats, lamps down the
-- jetty and the pontoon, a tall flag; the rescue-count board on the quay (a Lego frame, the lifebuoy icon and one
-- big number, on both faces: read from the cove and from the promenade)
local function pontoon(m: Model, b: CFrame)
	studTop(brick(m, "Pontoon", Vector3.new(6, 0.8, 50), b * CFrame.new(16, 1.6, 2), BRICK_WHITE))
	for z = -18, 22, 10 do
		brick(m, "Float", Vector3.new(5, 1.4, 4), b * CFrame.new(16, 0.6, z), DBG)
		brick(m, "Cleat", Vector3.new(0.5, 0.4, 1.4), b * CFrame.new(13.4, 2.2, z), BRICK_YELLOW)
	end
	brick(m, "Edge", Vector3.new(0.4, 0.5, 50), b * CFrame.new(19.1, 1.6, 2), BRICK_BLUE)
	lamp(m, b, 18.5, -18, 2)
	lamp(m, b, 18.5, 4, 2)
	for _, z in { -4, 20, 45 } do
		lamp(m, b, -26.4, z, TOP)
		lamp(m, b, -17.6, z, TOP)
	end
	flag(m, b, 16, -22, 2, 24)

	local W, H = 10, 5
	local at = isle(b, -24, 27.5) * CFrame.new(0, 6, 0)
	for _, dx in { -W / 2 - 0.5, W / 2 + 0.5 } do
		studTop(
			brick(m, "BoardPost", Vector3.new(1, 8.6, 1), at * CFrame.new(dx, -1.7, 0), BRICK_RED)
		)
	end
	brick(
		m,
		"BoardFrame",
		Vector3.new(W + 2, 0.8, 1),
		at * CFrame.new(0, H / 2 + 0.4, 0),
		BRICK_RED
	)
	brick(
		m,
		"BoardFrame",
		Vector3.new(W + 2, 0.8, 1),
		at * CFrame.new(0, -H / 2 - 0.4, 0),
		BRICK_RED
	)
	local board = brick(m, "RescueBoard", Vector3.new(W, H, 0.6), at, BRICK_WHITE)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.4
		gui.Parent = board
		local ring = Instance.new("ImageLabel")
		ring.Name = "Ring"
		ring.BackgroundTransparency = 1
		ring.Image = UiImages.Kit.lifebuoy
		ring.ScaleType = Enum.ScaleType.Fit
		ring.Position = UDim2.fromScale(0.04, 0.08)
		ring.Size = UDim2.fromScale(0.42, 0.84)
		ring.Parent = gui
		local count = Instance.new("TextLabel")
		count.Name = "Count"
		count.Position = UDim2.fromScale(0.46, 0.06)
		count.Size = UDim2.fromScale(0.5, 0.88)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.FredokaOne
		count.TextScaled = true
		count.TextColor3 = BRICK_RED
		count.Text = "0"
		count.Parent = gui
	end
end

-- the boathouse's paint booth (DockConfig.PAINT_BOOTH): two gantry arches over the berth's inshore half, posts on the
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
				Vector3.new(1.4, y1 - y0, 1.4),
				b * CFrame.new(x, (y0 + y1) / 2, z),
				WHITE,
				M.SmoothPlastic
			)
		end
		local beam = part(
			booth,
			"BoothBeam",
			Vector3.new(xe - xw + 1.4, 1.4, 1.4),
			b * CFrame.new((xw + xe) / 2, y1, z),
			NAVY, -- WP-25 r7: navy, calmer over the cove than orange
			M.SmoothPlastic
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
				M.SmoothPlastic
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

-- the boathouse on its lot, the roll-up door facing the cove, a clear marked floor spot for the boat
-- board (DockConfig.BOARD_SLOT) by the back wall; the paint booth over the berth
local function boathouse(m: Model, b: CFrame)
	local L = b * LOT.Boathouse.cf -- -Z = the doors
	local hw, hd, h = 15, 18, 14
	local y = h / 2
	plinth(m, Vector3.new(hw * 2 + 3, 0.4, hd * 2 + 3), L * CFrame.new(0, 0.2, 0))
	brick(m, "Wall", Vector3.new(0.8, h, hd * 2), L * CFrame.new(-hw, y, 0), BRICK_BLUE)
	brick(m, "Wall", Vector3.new(0.8, h, hd * 2), L * CFrame.new(hw, y, 0), BRICK_BLUE)
	brick(m, "Wall", Vector3.new(hw * 2, h, 0.8), L * CFrame.new(0, y, hd), BRICK_BLUE)
	-- front: two white pillars, the header and the half-rolled door
	brick(m, "Wall", Vector3.new(5, h, 0.8), L * CFrame.new(-hw + 2.5, y, -hd), BRICK_WHITE)
	brick(m, "Wall", Vector3.new(5, h, 0.8), L * CFrame.new(hw - 2.5, y, -hd), BRICK_WHITE)
	brick(m, "Header", Vector3.new(hw * 2, 4, 0.8), L * CFrame.new(0, h - 2, -hd), BRICK_WHITE)
	brick(
		m,
		"Course",
		Vector3.new(hw * 2 + 0.4, 1, hd * 2 + 0.4),
		L * CFrame.new(0, h - 0.5, 0),
		BRICK_WHITE
	)
	local doorW = hw * 2 - 10
	brick(m, "Door", Vector3.new(doorW, 4, 0.4), L * CFrame.new(0, h - 6, -hd + 0.1), BRICK_RED)
	part(
		m,
		"DoorRoll",
		Vector3.new(doorW, 1.8, 1.8),
		L * CFrame.new(0, h - 3.4, -hd - 1.1),
		BRICK_RED,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	-- a row of windows down each long wall
	for _, x in { -1, 1 } do
		for _, z in { -9, 0, 9 } do
			window(
				m,
				L * CFrame.new(x * (hw + 0.4), h * 0.55, z) * CFrame.Angles(0, -x * math.pi / 2, 0),
				4.4,
				3.6
			)
		end
	end
	-- the slope-brick roof, ridge along the depth: the gable over the doors
	gable(m, L * CFrame.new(0, h, 0), hw * 2 + 2.4, hd * 2 + 2.4, 7, BRICK_RED)
	sign(
		m,
		Vector3.new(13, 2.6, 0.4),
		L * CFrame.new(0, h + 2.4, -hd - 1.45),
		BRICK_WHITE,
		"Boathouse",
		UiImages.Kit.boat_to_me
	)
	path(m, b, { Vector2.new(55, 62), Vector2.new(62, 62) })
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
			c * CFrame.new(e[1], 0.5, e[2]), -- on the (scaled) plinth
			YELLOW,
			M.SmoothPlastic
		)
		line.CanCollide = false
	end
	paintBooth(m, b)
end

-- the lookout tower on the beach tower lot: chunky white legs with red cross braces, a stud deck, a glazed cabin
-- with a red slope roof and a flag, a ladder up its open side
local function lookout(m: Model, b: CFrame)
	local T = b * LOT.LifeguardTower.cf
	local legH, s = 20, 4
	plinth(m, Vector3.new(11, 0.6, 11), T * CFrame.new(0, 0.3, 0))
	for _, d in { { -s, -s }, { s, -s }, { -s, s }, { s, s } } do
		brick(
			m,
			"Leg",
			Vector3.new(1.4, legH, 1.4),
			T * CFrame.new(d[1], legH / 2, d[2]),
			BRICK_WHITE
		)
	end
	for _, yy in { 7, 14 } do
		for _, z in { -s, s } do
			brick(m, "Brace", Vector3.new(s * 2, 0.8, 0.8), T * CFrame.new(0, yy, z), BRICK_RED)
		end
	end
	studTop(
		brick(
			m,
			"Platform",
			Vector3.new(11, 0.8, 11),
			T * CFrame.new(0, legH + 0.4, 0),
			BRICK_YELLOW
		)
	)
	for _, w in { { 0, -4.8, 9.6, 0.4 }, { -4.8, 0, 0.4, 9.6 }, { 4.8, 0, 0.4, 9.6 } } do
		brick(
			m,
			"CabinWall",
			Vector3.new(w[3], 1.4, w[4]),
			T * CFrame.new(w[1], legH + 1.5, w[2]),
			BRICK_WHITE
		)
		local g = brick(
			m,
			"Window",
			Vector3.new(w[3], 2.8, w[4]),
			T * CFrame.new(w[1], legH + 3.6, w[2]),
			PANE
		)
		g.Transparency = 0.35
	end
	for _, d in { { -s, -s }, { s, -s }, { -s, s }, { s, s } } do
		brick(
			m,
			"CabinPost",
			Vector3.new(1, 4.4, 1),
			T * CFrame.new(d[1] * 1.15, legH + 3, d[2] * 1.15),
			BRICK_WHITE
		)
	end
	gable(m, T * CFrame.new(0, legH + 5.2, 0), 12, 12, 4, BRICK_RED)
	flag(m, T, 0, 0, legH + 9.4, 6)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, legH, 2)
	ladder.CFrame = T * CFrame.new(0, legH / 2, s + 1.5)
	ladder.Color = GREY
	ladder.Material = M.SmoothPlastic
	ladder.Anchored = true
	ladder.Parent = m
	path(m, b, { Vector2.new(110, -79), Vector2.new(118, -51) }) -- from the bridge path to the ladder
end

-- the slipway crane: mast on the quay starboard of the berth, the boom out over the berth's inshore end
local function slipCrane(m: Model, b: CFrame)
	local mastH = 24
	local base = b * CFrame.new(16, TOP, 66)
	studTop(
		brick(m, "CraneBase", Vector3.new(4.4, 1.2, 4.4), base * CFrame.new(0, 0.6, 0), BRICK_RED)
	)
	part(
		m,
		"Mast",
		Vector3.new(1.6, mastH, 1.6),
		base * CFrame.new(0, mastH / 2, 0),
		WHITE,
		M.SmoothPlastic
	)
	local top = (base * CFrame.new(0, mastH - 0.5, 0)).Position
	local tip = (b * CFrame.new(0, TOP + mastH - 0.5, 30)).Position
	local dir = (tip - top).Unit
	part(
		m,
		"Boom",
		Vector3.new(1.2, 1.2, (tip - top).Magnitude + 6),
		CFrame.lookAt((top + tip) / 2 - dir * 3, tip),
		NAVY,
		M.SmoothPlastic
	)
	part(
		m,
		"Counterweight",
		Vector3.new(3, 2.4, 3),
		CFrame.lookAt(top - dir * 5, tip) - Vector3.new(0, 1.5, 0),
		GREY,
		M.SmoothPlastic
	)
	part(
		m,
		"Cable",
		Vector3.new(0.15, 9, 0.15),
		CFrame.new(tip - Vector3.new(0, 4.5, 0)),
		GREY,
		M.SmoothPlastic
	).CanCollide =
		false
	part(
		m,
		"Hook",
		Vector3.new(1, 1.2, 1),
		CFrame.new(tip - Vector3.new(0, 9.5, 0)),
		RED,
		M.SmoothPlastic
	)
end

-- the station on its lot (door toward the spawn): the island's Lego town hall. A stud plinth, white walls on a
-- red base course, a window row, a blue stud roof behind a white parapet, a door in the owner's colour under a
-- sign; the lit front (neon stripes, floodlights), a beacon on the roof, light strips down the jetty
local function station(m: Model, b: CFrame)
	local S = b * LOT.Station.cf -- -Z = the front
	local hw, hd, h = ST.hw, ST.hd, ST.h
	local door = 5
	plinth(m, Vector3.new(hw * 2 + 4, 0.5, hd * 2 + 4), S * CFrame.new(0, 0.25, 0))
	brick(m, "Wall", Vector3.new(hw * 2, h, 0.8), S * CFrame.new(0, h / 2, hd), WHITE)
	for _, x in { -hw, hw } do
		brick(m, "Wall", Vector3.new(0.8, h, hd * 2), S * CFrame.new(x, h / 2, 0), WHITE)
	end
	for _, side in { -1, 1 } do
		brick(
			m,
			"StationFront",
			Vector3.new(hw - door, h, 0.8),
			S * CFrame.new(side * (hw + door) / 2, h / 2, -hd),
			WHITE
		)
	end
	brick(
		m,
		"StationFront",
		Vector3.new(door * 2, h - 9, 0.8),
		S * CFrame.new(0, 9 + (h - 9) / 2, -hd),
		WHITE
	)
	brick(
		m,
		"Flag",
		Vector3.new(door * 2 - 1, 8.5, 0.3),
		S * CFrame.new(0, 4.75, -hd + 0.3),
		BRICK_RED
	) -- the door
	-- the red base course round the walls (a gap for the door)
	brick(
		m,
		"BaseCourse",
		Vector3.new(hw * 2 + 0.6, 1.6, 0.4),
		S * CFrame.new(0, 1.3, hd + 0.5),
		BRICK_RED
	)
	for _, x in { -1, 1 } do
		brick(
			m,
			"BaseCourse",
			Vector3.new(0.4, 1.6, hd * 2 + 0.6),
			S * CFrame.new(x * (hw + 0.5), 1.3, 0),
			BRICK_RED
		)
		brick(
			m,
			"BaseCourse",
			Vector3.new(hw - door - 0.4, 1.6, 0.4),
			S * CFrame.new(x * (hw + door + 0.6) / 2, 1.3, -hd - 0.5),
			BRICK_RED
		)
	end
	-- windows: the front right of the door (the trophy hall is on its left), both sides and the back
	for _, x in { 9, 15, 21 } do
		window(m, S * CFrame.new(x, 7, -hd - 0.4), 4, 5)
	end
	for _, x in { -1, 1 } do
		for _, z in { -8, 0, 8 } do
			window(
				m,
				S * CFrame.new(x * (hw + 0.4), 7, z) * CFrame.Angles(0, -x * math.pi / 2, 0),
				4,
				5
			)
		end
	end
	for _, x in { -18, -9, 0, 9, 18 } do
		window(m, S * CFrame.new(x, 7, hd + 0.4) * CFrame.Angles(0, math.pi, 0), 4, 5)
	end
	-- a white eave course and a blue slope-brick roof, ridge along the long side
	brick(
		m,
		"Course",
		Vector3.new(hw * 2 + 0.6, 1, hd * 2 + 0.6),
		S * CFrame.new(0, h - 0.5, 0),
		BRICK_WHITE
	)
	gable(
		m,
		S * CFrame.new(0, h, 0) * CFrame.Angles(0, math.pi / 2, 0),
		hd * 2 + 3,
		hw * 2 + 3,
		9,
		BRICK_BLUE
	)
	sign(
		m,
		Vector3.new(10, 2.4, 0.4),
		S * CFrame.new(0, 10.6, -hd - 0.65),
		BRICK_WHITE,
		"Station",
		UiImages.Kit.lifebuoy
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
	-- beacon on the ridge: a mast, a lens, a wide light (WP-25: no sky beam)
	local top = S * CFrame.new(hw - 8, h + 5, 0) -- on the ridge
	part(m, "BeaconMast", Vector3.new(1, 8, 1), top * CFrame.new(0, 4, 0), GREY, M.SmoothPlastic)
	part(
		m,
		"BeaconBase",
		Vector3.new(2.4, 0.8, 2.4),
		top * CFrame.new(0, 8.4, 0),
		GREY,
		M.SmoothPlastic
	)
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
	glow.Range = 40
	glow.Brightness = 2
	glow.Parent = lens
end

-- the trophy hall: a blue board in a yellow frame, a shelf and a name sign on the station's front wall, left of
-- the door, framed by two white columns and a gold dome (docs/24 C; DockPieces.trophies fills the board)
local function trophyHall(m: Model, b: CFrame)
	brick(
		m,
		"TrophyFrame",
		Vector3.new(21, 7, 0.2),
		b * HALL * CFrame.new(0, 5, 0.05),
		BRICK_YELLOW
	)
	brick(m, "TrophyBoard", Vector3.new(20, 6, 0.2), b * HALL * CFrame.new(0, 5, 0), BRICK_BLUE)
	studTop(
		brick(
			m,
			"TrophyShelf",
			Vector3.new(20, 0.4, 1.4),
			b * HALL * CFrame.new(0, 2.6, -0.7),
			BRICK_WHITE
		)
	)
	for _, x in { -9.8, 9.8 } do
		part(
			m,
			"Column",
			Vector3.new(9.4, 1.5, 1.5),
			b * HALL * CFrame.new(x, 4.7, -0.5) * CFrame.Angles(0, 0, math.pi / 2),
			BRICK_WHITE,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	brick(m, "Lintel", Vector3.new(21, 1, 1.2), b * HALL * CFrame.new(0, 9.5, -0.4), BRICK_WHITE)
	part(
		m,
		"Dome",
		Vector3.new(14, 5, 5),
		b * HALL * CFrame.new(0, 10.6, -0.6),
		GOLD,
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	sign(m, Vector3.new(9, 1.6, 0.4), b * HALL * CFrame.new(0, 1.1, -0.1), BRICK_YELLOW, "Trophies")
end

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

-- the helipad on its lot (an H, an edge line and lights)
local function helipad(m: Model, b: CFrame)
	local P = b * LOT.Helipad.cf
	studTop(brick(m, "Pad", Vector3.new(36, 0.6, 36), P * CFrame.new(0, 0.3, 0), GREY))
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
	for _, e in { { 0, -18.5, 38, 1 }, { 0, 18.5, 38, 1 }, { -18.5, 0, 1, 36 }, { 18.5, 0, 1, 36 } } do
		studTop(
			brick(
				m,
				"PadRim",
				Vector3.new(e[3], 0.8, e[4]),
				P * CFrame.new(e[1], 0.4, e[2]),
				BRICK_WHITE
			)
		)
	end
	-- a windsock by the pad's corner: a white post, a striped sock of shrinking Lego rings (big: reads from the build camera)
	local ws = P * CFrame.new(22, 0, -22)
	studTop(
		brick(m, "WindsockBase", Vector3.new(3.2, 1, 3.2), ws * CFrame.new(0, 0.5, 0), BRICK_WHITE)
	)
	brick(m, "WindsockPole", Vector3.new(1, 19, 1), ws * CFrame.new(0, 10.5, 0), BRICK_WHITE)
	for k, c in { BRICK_ORANGE, BRICK_WHITE, BRICK_ORANGE } do
		local dia = 4.6 - (k - 1) * 0.9
		part(
			m,
			"Windsock",
			Vector3.new(3.6, dia, dia),
			ws
				* CFrame.new(0, 19, 0)
				* CFrame.Angles(0, math.rad(35), math.rad(-12))
				* CFrame.new(-0.6 - k * 3.6, 0, 0),
			c,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		).CanCollide =
			false
	end
	path(m, b, { Vector2.new(-37, -40), Vector2.new(-65, -40) })
end

-- the hangar on its lot, open toward the pad
local function hangar(m: Model, b: CFrame)
	local H = b * LOT.Hangar.cf -- -Z = the open front, toward the pad
	local hw, hd, h = 17, 14, 14
	plinth(m, Vector3.new(hw * 2 + 3, 0.4, hd * 2 + 3), H * CFrame.new(0, 0.2, 0))
	brick(m, "Wall", Vector3.new(hw * 2, h, 0.8), H * CFrame.new(0, h / 2, hd), WHITE)
	for _, x in { -hw, hw } do
		brick(m, "Wall", Vector3.new(0.8, h, hd * 2), H * CFrame.new(x, h / 2, 0), WHITE)
		for _, z in { -6, 6 } do
			window(
				m,
				H
					* CFrame.new(x * 1.025, h * 0.55, z)
					* CFrame.Angles(0, -math.sign(x) * math.pi / 2, 0),
				5,
				3.6
			)
		end
		brick(
			m,
			"BaseCourse",
			Vector3.new(0.4, 1.6, hd * 2 + 0.4),
			H * CFrame.new(x * 1.03, 1.2, 0),
			BRICK_BLUE
		)
	end
	brick(m, "Header", Vector3.new(hw * 2, 3, 0.8), H * CFrame.new(0, h - 1.5, -hd), BRICK_YELLOW)
	brick(
		m,
		"Course",
		Vector3.new(hw * 2 + 0.6, 1, hd * 2 + 0.6),
		H * CFrame.new(0, h + 0.5, 0),
		BRICK_WHITE
	)
	-- docs/24 C: an arched roof (five chunky slope courses on a circle), not a gable
	local apex, radius = H * CFrame.new(0, h + 9.5, 0), 25
	for i = -2, 2 do
		local a = math.rad(i * 24)
		brick(
			m,
			"ArchRoof",
			Vector3.new(10.6, 1.2, hd * 2 + 3),
			apex
				* CFrame.new(radius * math.sin(a), -radius * (1 - math.cos(a)), 0)
				* CFrame.Angles(0, 0, -a),
			RED
		)
	end
	sign(m, Vector3.new(11, 2.2, 0.4), H * CFrame.new(0, h - 1.5, -hd - 0.6), BRICK_WHITE, "Hangar")
	path(m, b, { Vector2.new(-37, 5), Vector2.new(-88, 5), Vector2.new(-88, 18) })
end

-- the sub pen (docs/24 C): a round moon pool ringed by a stud deck, a yellow gantry and a white dome cap
local function subPen(m: Model, b: CFrame)
	local P = b * Marina.SUB
	local hx, hz, top = PEN.hx, PEN.hz, PEN.top
	-- the round walkway: eight tangent deck segments round the pool
	for i = 0, 7 do
		local a = i * math.pi / 4
		studTop(
			brick(
				m,
				"Walk",
				Vector3.new(9.4, 1, 5.6),
				P * CFrame.new(math.sin(a) * 13, 0.5, math.cos(a) * 13) * CFrame.Angles(0, a, 0),
				BRICK_WHITE
			)
		)
	end
	-- four gantry legs, a square beam frame and the trolley (the hook stays at PEN.top - 0.5)
	for _, x in { -hx - 2, hx + 2 } do
		for _, z in { -hz, hz } do
			brick(
				m,
				"Leg",
				Vector3.new(1.6, top + 6, 1.6),
				P * CFrame.new(x, (top - 6) / 2, z),
				GREY
			)
		end
		brick(m, "Beam", Vector3.new(1.4, 1.4, hz * 2 + 1.6), P * CFrame.new(x, top, 0), YELLOW)
	end
	for _, z in { -hz, hz } do
		brick(m, "Beam", Vector3.new(hx * 2 + 4, 1.4, 1.4), P * CFrame.new(0, top, z), YELLOW)
	end
	brick(m, "Trolley", Vector3.new(hx * 2, 1.4, 2.4), P * CFrame.new(0, top + 0.2, 0), BRICK_RED)
	-- the dome: a yellow ring on the beams and a white cap (a whole ball, its lower half under the ring)
	part(
		m,
		"DomeRing",
		Vector3.new(1.2, hx * 2 + 9, hx * 2 + 9),
		P * CFrame.new(0, top + 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		BRICK_YELLOW,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Dome",
		Vector3.new(hx * 2, 8, hx * 2),
		P * CFrame.new(0, top + 4.8, 0),
		BRICK_WHITE,
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	-- a plank from the jetty onto the walkway
	brick(
		m,
		"Plank",
		Vector3.new(PEN_JETTY - hx - 2.5 + 0.5, 0.4, 3),
		P * CFrame.new((PEN_JETTY + hx + 2.5) / 2, TOP - 0.2, -8),
		WOOD
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
		M.SmoothPlastic,
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

-- WP-25 worker buildings (docs/23 (o), docs/24 C): open Lego work yards on their DockConfig spot (`spot`,
-- `size`, `color` = the owner's accent): a stud plinth, the work furniture and a path stub to the nearest lane
-- (island r, f points). The open front (-Z) is where the crew stands (WorkerService.workSpot).
type Hut = {
	roof: Color3?,
	tree: number?, -- WP-25 r8: a little tree at the back corner on this side (local X sign), clear of the neighbours
	icon: string?,
	path: { Vector2 },
}

local function crate(m: Model, at: CFrame, color: Color3)
	studTop(brick(m, "Crate", Vector3.new(2.6, 2, 2.6), at * CFrame.new(0, 1, 0), color))
end

local HUTS: { [string]: Hut } = {
	Workshop = {
		tree = -1,
		roof = BRICK_RED,
		icon = UiImages.Kit.build,
		path = { Vector2.new(46, -10), Vector2.new(36, -10) },
	},
	FishShed = {
		tree = 1,
		roof = BRICK_WHITE,
		icon = UiImages.Kit.cash,
		path = { Vector2.new(60, 105), Vector2.new(55, 105) },
	},
	BoatYard = {
		tree = 1,
		roof = BRICK_BLUE,
		icon = UiImages.Kit.boost,
		path = { Vector2.new(85, -94), Vector2.new(85, -82) },
	},
	RescueBoathouse = {
		tree = 1,
		roof = BRICK_WHITE,
		icon = UiImages.Kit.lifebuoy,
		path = { Vector2.new(-59, 99), Vector2.new(-54, 99) },
	},
	Clinic = {
		tree = -1,
		roof = BRICK_RED,
		path = { Vector2.new(-85, -93), Vector2.new(-85, -82) },
	},
}

-- a Lego cottage at `at` (on the plate, -Z = the door side), w x d: a stud plinth, the wall brick with a white
-- top course, a door in the owner's colour, windows, a slope-brick gable roof, a chimney; `label` = the gable
-- sign's words (nil: a red cross, the clinic)
local function cottage(
	m: Model,
	at: CFrame,
	w: number,
	d: number,
	wall: Color3,
	roof: Color3,
	label: string?,
	icon: string?
)
	local h, y0 = 12, 0.8
	local rise = math.min(w * 0.36, 9)
	plinth(m, Vector3.new(w + 3, y0, d + 3), at * CFrame.new(0, y0 / 2, 0))
	brick(m, "Wall", Vector3.new(w, h, d), at * CFrame.new(0, y0 + h / 2, 0), wall)
	brick(
		m,
		"Course",
		Vector3.new(w + 0.4, 1, d + 0.4),
		at * CFrame.new(0, y0 + h - 0.5, 0),
		BRICK_WHITE
	)
	frontDoor(m, at * CFrame.new(0, y0, -d / 2), 4, 6.5)
	local wy = y0 + h * 0.55
	for _, x in { -1, 1 } do
		window(m, at * CFrame.new(x * (w / 4 + 1.2), wy, -d / 2), 3.6, 3.6) -- the front, either side of the door
		window(
			m,
			at * CFrame.new(x * w / 2, wy, 0) * CFrame.Angles(0, -x * math.pi / 2, 0),
			4.4,
			3.6
		)
	end
	local top = at * CFrame.new(0, y0 + h, 0)
	gable(m, top, w + 6, d + 3, rise, roof) -- WP-25 r9: wide eaves, a bigger roof from above
	studTop(
		brick(
			m,
			"Chimney",
			Vector3.new(2.4, 4, 2.4),
			top * CFrame.new(w / 4, rise * 0.5 + 1.5, d / 4),
			BRICK_WHITE
		)
	)
	local gableAt = top * CFrame.new(0, rise * 0.32, -d / 2 - 1.75)
	if label then
		sign(m, Vector3.new(w * 0.5, rise * 0.4, 0.4), gableAt, BRICK_WHITE, label, icon)
	else -- a red cross on the gable
		brick(m, "Cross", Vector3.new(1.4, 4.2, 0.4), gableAt, BRICK_RED)
		brick(m, "Cross", Vector3.new(4.2, 1.4, 0.4), gableAt, BRICK_RED)
	end
end

local function hut(m: Model, b: CFrame, key: string)
	local def = DockConfig.Buildings[key]
	local spec = HUTS[key]
	local at = b * def.spot
	local w, d = def.size.X / (def.scale or 1), def.size.Y / (def.scale or 1) -- DockPieces.building scales it up
	cottage(
		m,
		at,
		w,
		d,
		def.color or BRICK_YELLOW,
		spec and spec.roof or BRICK_RED,
		if key == "Clinic" then nil else def.name,
		spec and spec.icon
	)
	if spec then
		path(m, b, spec.path)
	end
end

-- docs/24 C: the worker buildings are open work yards, so the crew and their props read from the front (-Z).
-- Built at size / scale; DockPieces.building scales the lot's footprint back up.
local function yardSize(def: DockConfig.Building): (number, number)
	return def.size.X / (def.scale or 1), def.size.Y / (def.scale or 1)
end

-- Builder: an open-air carpentry yard: bench under a low lean-to, timber stacks and a half-built boat frame
local function workshopYard(m: Model, b: CFrame)
	local def = DockConfig.Buildings.Workshop
	local at = b * def.spot
	local w, d = yardSize(def)
	local spec = HUTS.Workshop
	local front = -d / 2
	local wall = def.color or BRICK_YELLOW
	plinth(m, Vector3.new(w + 3, 0.8, d + 3), at * CFrame.new(0, 0.4, 0))
	brick(m, "Wall", Vector3.new(w, 5, 0.8), at * CFrame.new(0, 3.3, d / 2 - 0.4), wall)
	for _, x in { -1, 1 } do
		brick(
			m,
			"Wall",
			Vector3.new(0.8, 5, 3),
			at * CFrame.new(x * (w / 2 - 0.4), 3.3, d / 2 - 2),
			wall
		)
	end
	-- the bench (the crew faces it from the front edge), with a low lean-to over it
	studTop(
		brick(
			m,
			"Bench",
			Vector3.new(15, 0.7, 3.2),
			at * CFrame.new(0, 3.1, front + 5),
			BRICK_WHITE
		)
	)
	for _, x in { -5.2, 5.2 } do
		brick(m, "BenchLeg", Vector3.new(0.8, 2.8, 2.8), at * CFrame.new(x, 1.4, front + 5), DBG)
	end
	for _, x in { -6, 6 } do
		brick(
			m,
			"Post",
			Vector3.new(0.8, 8.4, 0.8),
			at * CFrame.new(x, 4.6, front + 2.2),
			BRICK_WHITE
		)
	end
	brick(m, "Roof", Vector3.new(13.5, 0.7, 7.2), at * CFrame.new(0, 8.9, front + 4.6), BRICK_GREEN)
	sign(
		m,
		Vector3.new(6, 2, 0.4),
		at * CFrame.new(0, 7.1, front + 2.2),
		BRICK_WHITE,
		def.name,
		spec.icon
	)
	-- timber stacks and the half-built boat frame deeper in the yard
	local tim = at * CFrame.new(w / 2 - 4, 0, 1.5)
	for i = 0, 2 do
		studTop(
			brick(
				m,
				"Timber",
				Vector3.new(7, 1.2, 2),
				tim * CFrame.new(0, 1.4 + i * 1.3, -i * 0.4),
				RBROWN
			)
		)
	end
	local boat = at * CFrame.new(-w / 4, 0, 2.4)
	brick(m, "Keel", Vector3.new(1.2, 1.2, 8.4), boat * CFrame.new(0, 2.6, 0), RBROWN)
	for i = -1, 1 do
		brick(m, "Rib", Vector3.new(5.6, 0.8, 0.8), boat * CFrame.new(0, 2.8, i * 2.8), RBROWN)
	end
	path(m, b, spec.path)
end

-- Gatherer: a fish market on the cove walk: two striped awning stalls, fish crates, drying racks
local function fishMarket(m: Model, b: CFrame)
	local def = DockConfig.Buildings.FishShed
	local at = b * def.spot
	local w, d = yardSize(def)
	local spec = HUTS.FishShed
	local front = -d / 2
	local accent = def.color or BRICK_BLUE
	plinth(m, Vector3.new(w + 3, 0.8, d + 3), at * CFrame.new(0, 0.4, 0))
	for k, x in { -w / 4 - 1, w / 4 + 1 } do
		local s = at * CFrame.new(x, 0, front + 5)
		studTop(
			brick(m, "Counter", Vector3.new(6.4, 2.4, 2.6), s * CFrame.new(0, 1.2, 0), BRICK_WHITE)
		)
		for _, px in { -2.8, 2.8 } do
			brick(m, "Post", Vector3.new(0.6, 7, 0.6), s * CFrame.new(px, 3.5, 0), BRICK_WHITE)
		end
		for i = 1, 3 do -- chunky striped awning, the owner's colour and white
			brick(
				m,
				"Awning",
				Vector3.new(2.3, 0.4, 4.4),
				s * CFrame.new((i - 2) * 2.3, 6.6, 0) * CFrame.Angles(math.rad(-12), 0, 0),
				if (i + k) % 2 == 0 then accent else BRICK_WHITE
			)
		end
		crate(m, s * CFrame.new(-1.4, 0, 2.6), BRICK_WHITE)
	end
	-- crates of fish and a barrel between the stalls
	crate(m, at * CFrame.new(0, 0, front + 6), BRICK_ORANGE)
	part(
		m,
		"Barrel",
		Vector3.new(3, 2.4, 2.4),
		at * CFrame.new(0, 1.5, front + 4.5) * CFrame.Angles(0, 0, math.pi / 2),
		RBROWN,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	-- a drying rack at the back: two posts, a bar and three fish
	local rack = at * CFrame.new(0, 0, d / 2 - 3)
	for _, x in { -4, 4 } do
		brick(m, "RackPost", Vector3.new(0.6, 5, 0.6), rack * CFrame.new(x, 2.5, 0), BRICK_WHITE)
	end
	brick(m, "RackBar", Vector3.new(8.6, 0.6, 0.6), rack * CFrame.new(0, 5, 0), BRICK_WHITE)
	for i = -1, 1 do
		brick(
			m,
			"Fish",
			Vector3.new(0.5, 1.6, 1.1),
			rack * CFrame.new(i * 2.4, 4.1, 0),
			if i == 0 then BRICK_ORANGE else BRICK_WHITE
		)
	end
	sign(
		m,
		Vector3.new(5, 2, 0.4),
		at * CFrame.new(w / 2 - 4, 8.2, front + 5),
		BRICK_WHITE,
		def.name,
		spec.icon
	)
	path(m, b, spec.path)
end

-- Mechanic: a boat up on a cradle under a gantry crane, tool chests beside it
local function boatYard(m: Model, b: CFrame)
	local def = DockConfig.Buildings.BoatYard
	local at = b * def.spot
	local w, d = yardSize(def)
	local spec = HUTS.BoatYard
	plinth(m, Vector3.new(w + 3, 0.8, d + 3), at * CFrame.new(0, 0.4, 0))
	local boat = at * CFrame.new(0, 0, 1)
	for _, z in { -3, 3 } do
		studTop(brick(m, "Cradle", Vector3.new(7, 0.9, 1.4), boat * CFrame.new(0, 1.6, z), RBROWN))
	end
	studTop(brick(m, "Hull", Vector3.new(6, 2.6, 12), boat * CFrame.new(0, 3.3, 0), BRICK_WHITE))
	local bow = Instance.new("WedgePart")
	bow.Name = "Bow"
	bow.Size = Vector3.new(6, 2.6, 2.8)
	bow.CFrame = boat * CFrame.new(0, 3.3, -7.2) * CFrame.Angles(0, math.pi, 0)
	bow.Color, bow.Material, bow.Anchored = BRICK_WHITE, M.SmoothPlastic, true
	bow.Parent = m
	brick(
		m,
		"Stripe",
		Vector3.new(6.1, 0.6, 12),
		boat * CFrame.new(0, 3.4, 0),
		def.color or BRICK_ORANGE
	)
	brick(m, "Deck", Vector3.new(4.4, 0.5, 9), boat * CFrame.new(0, 4.75, 0.5), DBG)
	brick(m, "Console", Vector3.new(2.4, 1.6, 2), boat * CFrame.new(0, 5.6, 2.4), BRICK_WHITE)
	-- the gantry crane over the boat
	for _, x in { -8.5, 8.5 } do
		brick(m, "Leg", Vector3.new(1.2, 14, 1.2), boat * CFrame.new(x, 8.2, 0), DBG)
	end
	brick(m, "Beam", Vector3.new(18.4, 1.2, 1.2), boat * CFrame.new(0, 14.8, 0), BRICK_YELLOW)
	brick(m, "Cable", Vector3.new(0.4, 4, 0.4), boat * CFrame.new(0, 12.4, 0), DBG)
	brick(m, "Hook", Vector3.new(1.4, 1.4, 1.4), boat * CFrame.new(0, 10.2, 0), BRICK_ORANGE)
	sign(
		m,
		Vector3.new(7, 2, 0.4),
		boat * CFrame.new(0, 16.4, 0),
		BRICK_YELLOW,
		def.name,
		spec.icon
	)
	-- tool chests and a tyre stack beside the hull
	local tools = at * CFrame.new(w / 2 - 4, 0, -d / 2 + 8)
	studTop(
		brick(m, "ToolChest", Vector3.new(3.6, 2.2, 2), tools * CFrame.new(0, 1.1, 0), BRICK_RED)
	)
	studTop(
		brick(
			m,
			"ToolChest",
			Vector3.new(2.6, 1.6, 1.8),
			tools * CFrame.new(-0.4, 2.8, 0.6) * CFrame.Angles(0, 0.4, 0),
			BRICK_BLUE
		)
	)
	for i = 0, 1 do
		part(
			m,
			"Tyre",
			Vector3.new(1.2, 2.6, 2.6),
			tools * CFrame.new(3.2, 1.2 + i * 2.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(40, 42, 48),
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	path(m, b, spec.path)
end

-- Rescuer: an open slipway shed with the rescue boat, a lifebuoy rack and a tall lifeguard chair
local function rescueBoathouse(m: Model, b: CFrame)
	local def = DockConfig.Buildings.RescueBoathouse
	local at = b * def.spot
	local w, d = yardSize(def)
	local spec = HUTS.RescueBoathouse
	plinth(m, Vector3.new(w + 3, 0.8, d + 3), at * CFrame.new(0, 0.4, 0))
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			brick(
				m,
				"Post",
				Vector3.new(1, 11, 1),
				at * CFrame.new(x * (w / 2 - 1.2), 6.1, z * (d / 2 - 1.2)),
				BRICK_WHITE
			)
		end
	end
	for _, x in { -1, 1 } do -- two slope bricks, open at the front and sides
		local roof = brick(
			m,
			"Roof",
			Vector3.new(w / 2 + 2.4, 0.8, d + 3),
			at * CFrame.new(x * (w / 4 + 0.6), 12.6, 0),
			def.color or BRICK_RED
		)
		roof.CFrame = roof.CFrame * CFrame.Angles(0, 0, -x * math.rad(9))
	end
	-- the rescue boat on its slip
	local boat = at * CFrame.new(0, 0, -d / 2 + 8.5)
	brick(m, "Hull", Vector3.new(4.4, 2, 10), boat * CFrame.new(0, 2.4, 0), BRICK_WHITE)
	brick(m, "Tube", Vector3.new(4.8, 0.8, 10), boat * CFrame.new(0, 3.3, 0), BRICK_ORANGE)
	brick(m, "Deck", Vector3.new(3.2, 0.5, 8), boat * CFrame.new(0, 3.6, 0), DBG)
	brick(m, "Console", Vector3.new(1.8, 1.4, 1.8), boat * CFrame.new(0, 4.3, 1.6), BRICK_WHITE)
	-- the lifebuoy rack on the back wall
	local rack = at * CFrame.new(-w / 4, 0, d / 2 - 3)
	for _, x in { -2.4, 2.4 } do
		brick(m, "RackPost", Vector3.new(0.7, 6, 0.7), rack * CFrame.new(x, 3, 0), BRICK_WHITE)
	end
	brick(m, "RackBar", Vector3.new(5.4, 0.7, 0.7), rack * CFrame.new(0, 6, 0), BRICK_WHITE)
	for _, x in { -1.5, 1.5 } do
		part(
			m,
			"Lifebuoy",
			Vector3.new(0.7, 2, 2),
			rack * CFrame.new(x, 4.6, -0.6) * CFrame.Angles(0, math.pi / 2, 0),
			BRICK_RED,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		part(
			m,
			"Lifebuoy",
			Vector3.new(0.8, 1, 1),
			rack * CFrame.new(x, 4.6, -0.7) * CFrame.Angles(0, math.pi / 2, 0),
			BRICK_WHITE,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	-- the tall lifeguard chair by the front corner: a seat over a narrow tower with a footrest
	local chair = at * CFrame.new(w / 2 - 4, 0, -d / 2 + 3)
	studTop(
		brick(
			m,
			"ChairBase",
			Vector3.new(3.4, 0.8, 3.4),
			chair * CFrame.new(0, 0.4, 0),
			BRICK_YELLOW
		)
	)
	brick(m, "ChairPost", Vector3.new(1.2, 9, 1.2), chair * CFrame.new(0, 5, 0), BRICK_WHITE)
	studTop(
		brick(
			m,
			"ChairSeat",
			Vector3.new(3.2, 0.6, 3.2),
			chair * CFrame.new(0, 9.8, 0),
			BRICK_YELLOW
		)
	)
	brick(
		m,
		"ChairBack",
		Vector3.new(3.2, 2.6, 0.5),
		chair * CFrame.new(0, 11.4, 1.35),
		BRICK_YELLOW
	)
	brick(m, "ChairStep", Vector3.new(2, 0.4, 1.2), chair * CFrame.new(0, 5.8, -1.7), BRICK_WHITE)
	sign(
		m,
		Vector3.new(6, 2, 0.4),
		at * CFrame.new(0, 9.4, -d / 2 + 0.2),
		BRICK_WHITE,
		def.name,
		spec.icon
	)
	path(m, b, spec.path)
end

-- Medic: a white pavilion (open sides) with a big red cross, two beds and a stretcher in view
local function clinic(m: Model, b: CFrame)
	local def = DockConfig.Buildings.Clinic
	local at = b * def.spot
	local w, d = yardSize(def)
	local spec = HUTS.Clinic
	plinth(m, Vector3.new(w + 3, 0.8, d + 3), at * CFrame.new(0, 0.4, 0))
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			brick(
				m,
				"Post",
				Vector3.new(1, 10, 1),
				at * CFrame.new(x * (w / 2 - 1.2), 5.8, z * (d / 2 - 1.2)),
				BRICK_WHITE
			)
		end
	end
	-- a white tent roof: two slope bricks meeting at the ridge
	local top = at * CFrame.new(0, 10.8, 0)
	for _, z in { -1, 1 } do
		local roof = brick(
			m,
			"Roof",
			Vector3.new(w + 3, 0.8, d / 2 + 5),
			top * CFrame.new(0, 1.2, z * (d / 4 + 0.2)),
			BRICK_WHITE
		)
		roof.CFrame = roof.CFrame * CFrame.Angles(z * math.rad(14), 0, 0)
	end
	-- the big red cross on the front header: readable from the lane and the build camera
	brick(m, "Header", Vector3.new(9, 4.6, 0.5), at * CFrame.new(0, 8.4, -d / 2 + 0.2), BRICK_WHITE)
	brick(m, "Cross", Vector3.new(1.6, 4.2, 0.5), at * CFrame.new(0, 8.4, -d / 2 - 0.1), BRICK_RED)
	brick(m, "Cross", Vector3.new(4.2, 1.6, 0.5), at * CFrame.new(0, 8.4, -d / 2 - 0.1), BRICK_RED)
	-- two beds at the back, made up
	for k, x in { -w / 4, w / 4 } do
		local bed = at * CFrame.new(x, 0, d / 2 - 5.2)
		brick(m, "BedFrame", Vector3.new(4.4, 0.7, 7), bed * CFrame.new(0, 1.4, 0), BRICK_WHITE)
		for _, z in { -2.6, 2.6 } do
			brick(m, "BedLeg", Vector3.new(0.5, 1.2, 0.5), bed * CFrame.new(0, 0.6, z), STEEL)
		end
		studTop(
			brick(m, "Mattress", Vector3.new(4, 0.8, 6), bed * CFrame.new(0, 2.1, 0), BRICK_WHITE)
		)
		brick(
			m,
			"Pillow",
			Vector3.new(3, 0.7, 1.4),
			bed * CFrame.new(0, 2.9, 2.1),
			if k == 1 then BRICK_CYAN else BRICK_PINK
		)
	end
	-- a stretcher between the beds
	local st = at * CFrame.new(0, 0, d / 2 - 4.5)
	for _, z in { -2, 2 } do
		brick(m, "StretcherLeg", Vector3.new(3.4, 1.4, 0.4), st * CFrame.new(0, 0.8, z), STEEL)
	end
	for _, x in { -1.5, 1.5 } do
		brick(m, "StretcherRail", Vector3.new(0.5, 0.5, 6), st * CFrame.new(x, 1.6, 0), STEEL)
	end
	brick(m, "Stretcher", Vector3.new(3.4, 0.4, 5.2), st * CFrame.new(0, 2, 0), BRICK_WHITE)
	-- a medicine crate and an IV stand
	crate(m, at * CFrame.new(-w / 2 + 1.6, 0, d / 2 - 4.5), BRICK_RED)
	brick(m, "IVPost", Vector3.new(0.4, 6, 0.4), at * CFrame.new(w / 2 - 1.8, 3, d / 2 - 6), STEEL)
	brick(
		m,
		"IVBag",
		Vector3.new(1.1, 1.6, 0.8),
		at * CFrame.new(w / 2 - 1.8, 6.4, d / 2 - 6),
		BRICK_CYAN
	)
	path(m, b, spec.path)
end

-- the lifeboat slip on the island's edge: an open shed (white posts, blue slope roof) over a slipway that runs
-- off the plate into the sea, with rails and a winch
local function lifeboatSlip(m: Model, b: CFrame)
	local def = DockConfig.Buildings.LifeboatSlip
	local at = b * def.spot -- -Z = toward the sea
	local D = def.size.Y -- the scaled footprint: the slipway and the path stay 1x (DockPieces.building)
	local w, d = def.size.X / (def.scale or 1), D / (def.scale or 1)
	local h = 11
	plinth(m, Vector3.new(w + 2, 0.8, d), at * CFrame.new(0, 0.4, 0))
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			studTop(
				brick(
					m,
					"Post",
					Vector3.new(1.4, h, 1.4),
					at * CFrame.new(x * (w / 2 - 0.2), 0.8 + h / 2, z * (d / 2 - 0.8)),
					BRICK_WHITE
				)
			)
		end
	end
	local top = at * CFrame.new(0, 0.8 + h, 0)
	brick(m, "Course", Vector3.new(w + 1, 1, d), top * CFrame.new(0, -0.5, 0), BRICK_BLUE)
	gable(m, top, w + 2, d + 2, 5, BRICK_BLUE)
	sign(
		m,
		Vector3.new(w * 0.45, 1.8, 0.4),
		top * CFrame.new(0, 1.6, -d / 2 - 1.25),
		BRICK_WHITE,
		"Lifeboat",
		UiImages.Kit.lifebuoy
	)
	-- the slipway: flat from the shed to the plate's edge (EDGE studs out from the island centre), then down
	-- into the sea
	local slipR = Marina.ISLAND:ToObjectSpace(def.spot).X -- the slip's island-frame right (it faces +right)
	local edge = -(RingLayout.IslandPlate.edge - slipR)
	local flatLen = D / 2 - 2 - edge
	brick(
		m,
		"Slipway",
		Vector3.new(7, 0.6, flatLen),
		at * CFrame.new(0, 0.3, (D / 2 - 2 + edge) / 2),
		TAN
	)
	local from = (at * CFrame.new(0, 0, edge)).Position
	local to = (at * CFrame.new(0, -Marina.DECK_TOP - 1.5, edge - 16)).Position
	local mid = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, 0.3, 0)
	brick(m, "Slipway", Vector3.new(7, 0.6, (to - from).Magnitude + 0.6), mid, TAN)
	for _, x in { -2.6, 2.6 } do
		brick(
			m,
			"SlipRail",
			Vector3.new(0.6, 0.6, flatLen),
			at * CFrame.new(x, 0.9, (D / 2 - 2 + edge) / 2),
			DBG
		)
		brick(
			m,
			"SlipRail",
			Vector3.new(0.6, 0.6, (to - from).Magnitude + 0.6),
			mid * CFrame.new(x, 0.6, 0),
			DBG
		)
	end
	studTop(
		brick(m, "Winch", Vector3.new(3, 2, 2), at * CFrame.new(0, 1.8, d / 2 - 1.5), BRICK_YELLOW)
	)
	path(m, b, { Vector2.new(57, 23), Vector2.new(slipR - D / 2 - 2, 23) })
end

-- WP-25: the fixed set on every island plate, there from the bare start (DockService builds it with the jetty):
-- the tan paths (a loop of lanes round the station's spot from the spawn to the quay promenade, the cove walks, the
-- links to both bridges), a central plaza on the cove axis, Lego trees round the edges, a lifebuoy stand on the
-- quay and a bench by the spawn. Island (r, f) points: r = right, f = out toward the cove.
local V = Vector2.new
DockPieces.PATHS = {
	{ V(-34, -84), V(34, -84) }, -- the back cross, past the spawn
	{ V(0, -84), V(0, -52) }, -- the spawn walk, up to the station's door
	{ V(-34, -84), V(-34, 23) }, -- the lanes either side of the station
	{ V(34, -84), V(34, 23) },
	{ V(-52, 23), V(55, 23) }, -- the quay promenade
	{ V(55, 23), V(55, 104) }, -- the east cove walk (boathouse, fish shed)
	{ V(-52, 23), V(-52, 148), V(-96, 148) }, -- the west cove walk to the quest tablet
	{ V(-34, -84), V(-121, -78) }, -- to the bridges
	{ V(34, -84), V(121, -78) },
}
-- WP-25 r6: five clumps of mixed sizes (island r, f, scale) framing the plate corners and the lower quadrants
local V3 = Vector3.new
local TREES = {
	-- the back-left corner, along the chamfer
	V3(-120, -95, 0.8),
	V3(-115, -122, 1.2),
	V3(-102, -136, 1.5),
	V3(-94, -148, 0.9),
	-- the back-right corner
	V3(116, -124, 1.5),
	V3(103, -137, 1.1),
	V3(108, -150, 0.8),
	-- behind the spawn
	V3(-6, -146, 1.4),
	V3(10, -140, 0.9),
	V3(-20, -138, 0.8),
	-- the east front wing
	V3(140, 94, 1.5),
	V3(148, 80, 0.9),
	V3(128, 110, 1.1),
	V3(114, 124, 0.8),
	-- the west front wing
	V3(-140, 92, 1.4),
	V3(-148, 78, 0.8),
	V3(-127, 106, 1.0),
	V3(-115, 120, 0.8),
}
-- a few flower patches by the spawn (docs/24 C: thin the clutter, keep the colour near the arrival)
local FLOWERS = { V(-8, -64), V(8, -64), V(-6, -94), V(6, -94) }
local LAMPS = { V(-44, 17), V(-20, 17), V(20, 17), V(44, 17) } -- along the promenade's inland side
local LEAF = Color3.fromRGB(40, 127, 70) -- Lego dark green: reads against the plate

-- a 1-part Lego tulip field at `at`, w x d: brown soil, a leafy edge, rows of blooms as SurfaceGui stripes
local ROWS = { BRICK_RED, BRICK_YELLOW, BRICK_PINK, BRICK_WHITE, BRICK_ORANGE }
local function field(m: Model, at: CFrame, w: number, d: number, k: number)
	local soil = brick(m, "Field", Vector3.new(w, 0.6, d), at * CFrame.new(0, 0.3, 0), RBROWN)
	soil.CanCollide = false
	local gui = border(soil, LEAF, 8) -- a leafy edge round the soil
	local along = w >= d -- rows run along the long side
	local n = math.floor((if along then d else w) / 3)
	for i = 0, n - 1 do
		local row = Instance.new("Frame")
		row.BorderSizePixel = 0
		row.BackgroundColor3 = ROWS[(i + k) % #ROWS + 1]
		row.Position = if along
			then UDim2.fromOffset(12, 12 + i * 24)
			else UDim2.fromOffset(12 + i * 24, 12)
		row.Size = if along then UDim2.new(1, -24, 0, 14) else UDim2.new(0, 14, 1, -24)
		row.Parent = gui
	end
end

local function tree(m: Model, at: CFrame, s: number)
	brick(m, "Trunk", Vector3.new(2.4, 6 * s, 2.4), at * CFrame.new(0, 3 * s, 0), RBROWN)
	for i, w in { 12, 8.5, 5 } do -- stacked round plates: a Lego pine, round from the build camera
		part(
			m,
			"Leaves",
			Vector3.new(3.6 * s, w * s, w * s),
			at * CFrame.new(0, (4.2 + i * 3.6) * s, 0) * CFrame.Angles(0, 0, math.pi / 2),
			LEAF, -- dark green: lime discs vanish on the plate (WP-25 AD r3)
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
end

function DockPieces.base(b: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "IslandSet"
	for _, pts in DockPieces.PATHS do
		path(m, b, pts)
	end
	-- docs/24 C: one clear plaza on the cove axis, in front of the station: the jetty -> build station sightline
	local plaza =
		brick(m, "Plaza", Vector3.new(64, 0.3, 30), isle(b, 0, 4) * CFrame.new(0, 0.15, 0), TAN)
	plaza.CanCollide = false
	studTop(plaza)
	for _, t in TREES do
		tree(m, isle(b, t.X, t.Y), t.Z)
	end
	-- a red and white lifebuoy on a white post at the quay, beside the jetty
	local stand = isle(b, 24.5, 28)
	studTop(
		brick(m, "StandBase", Vector3.new(2, 0.8, 2), stand * CFrame.new(0, 0.4, 0), BRICK_WHITE)
	)
	brick(m, "StandPost", Vector3.new(0.8, 5, 0.8), stand * CFrame.new(0, 3, 0), BRICK_WHITE)
	for k = 0, 7 do
		brick(
			m,
			"Lifebuoy",
			Vector3.new(1.3, 0.7, 0.6),
			stand
				* CFrame.new(0, 4.2, -0.7)
				* CFrame.Angles(0, 0, k * math.pi / 4)
				* CFrame.new(0, 1.5, 0),
			if k % 2 == 0 then BRICK_RED else BRICK_WHITE
		)
	end
	-- a bench by the spawn, facing the station
	local bench = isle(b, 12, -80)
	for _, x in { -2, 2 } do
		brick(m, "BenchLeg", Vector3.new(0.8, 1.6, 2), bench * CFrame.new(x, 0.8, 0), DBG)
	end
	studTop(
		brick(m, "BenchSeat", Vector3.new(6, 0.6, 2.4), bench * CFrame.new(0, 1.9, 0), BRICK_BLUE)
	)
	brick(m, "BenchBack", Vector3.new(6, 2, 0.6), bench * CFrame.new(0, 3, 1.1), BRICK_BLUE)
	-- a few flower patches by the spawn
	local blooms = { BRICK_RED, BRICK_YELLOW, BRICK_PINK, BRICK_WHITE }
	for k, f in FLOWERS do
		local at = isle(b, f.X, f.Y)
		part(
			m,
			"Bed",
			Vector3.new(0.6, 6, 6),
			at * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			LEAF,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		for i = 0, 2 do
			local a = (k + i * 2.1)
			part(
				m,
				"Bloom",
				Vector3.new(1.4, 1.4, 1.4),
				at * CFrame.new(math.cos(a) * 1.6, 1.1, math.sin(a) * 1.6),
				blooms[(k + i) % #blooms + 1],
				M.SmoothPlastic,
				Enum.PartType.Ball
			)
		end
	end
	for _, v in LAMPS do
		lamp(m, isle(b, v.X, v.Y), 0, 0, 0)
	end
	-- the bunkhouse on the quay (the crew's hut), its door onto the promenade
	cottage(m, isle(b, 21, 6), 14, 10, RBROWN, BRICK_BLUE, "Bunkhouse", UiImages.Kit.crew)
	-- the cove's side walls: a stud-capped dark grey quay edge, yellow bollards on it, black tyre fenders below
	local notch = RingLayout.IslandPlate.notch
	local edge = RingLayout.IslandPlate.edge
	for _, side in { -1, 1 } do
		local x = side * notch.halfWidth
		local len = edge - notch.head
		studTop(
			brick(
				m,
				"QuayCap",
				Vector3.new(2.2, 0.6, len),
				isle(b, x + side * 1.1, notch.head + len / 2) * CFrame.new(0, 0.3, 0),
				DBG
			)
		)
		for f = notch.head + 14, edge - 6, 22 do
			part(
				m,
				"Bollard",
				Vector3.new(1.2, 1.2, 1.2),
				isle(b, x + side * 1.1, f)
					* CFrame.new(0, 1.2, 0)
					* CFrame.Angles(0, 0, math.pi / 2),
				BRICK_YELLOW,
				M.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			part(
				m,
				"Fender",
				Vector3.new(0.8, 2.4, 2.4),
				isle(b, x - side * 0.4, f + 11) * CFrame.new(0, -1.6, 0),
				Color3.fromRGB(27, 42, 53),
				M.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
	end
	-- WP-25 r9: a chunky red/white Lego flag tower behind the station (10 parts; the red/white lighthouse is the
	-- Spare1 quest reward): the island's landmark from the sea and the other islands at every stage (plate stays flat)
	local lh = isle(b, 19, -68)
	studTop(brick(m, "TowerBase", Vector3.new(16, 2, 16), lh * CFrame.new(0, 1, 0), BRICK_RED))
	for k = 0, 4 do
		brick(
			m,
			"TowerBand",
			Vector3.new(13.5 - k * 0.6, 15.6, 13.5 - k * 0.6),
			lh * CFrame.new(0, 9.8 + k * 15.6, 0),
			if k % 2 == 0 then BRICK_WHITE else BRICK_RED
		)
	end
	studTop(
		brick(m, "Gallery", Vector3.new(14, 1.6, 14), lh * CFrame.new(0, 80.8, 0), BRICK_YELLOW)
	)
	brick(m, "Mast", Vector3.new(2.4, 20, 2.4), lh * CFrame.new(0, 91.6, 0), BRICK_WHITE)
	part(
		m,
		"MastTop",
		Vector3.new(3.6, 3.6, 3.6),
		lh * CFrame.new(0, 103.4, 0),
		BRICK_YELLOW,
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	local pennant =
		brick(m, "MastFlag", Vector3.new(0.5, 16, 26), lh * CFrame.new(0, 92.5, 14.2), BRICK_RED)
	pennant.CanCollide = false
	for _, n in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local d = Instance.new("Decal")
		d.Face = n
		d.Texture = UiImages.Kit.lifebuoy
		d.Parent = pennant
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Path" then
			d.CanQuery = false -- set dressing: no prompts or camera hits
		end
	end
	return m
end

local BUILDINGS = {
	Pontoon = pontoon,
	Workshop = workshopYard,
	FishShed = fishMarket,
	BoatYard = boatYard,
	RescueBoathouse = rescueBoathouse,
	Clinic = clinic,
	Boathouse = boathouse,
	LookoutTower = lookout,
	Crane = slipCrane,
	Station = station,
	TrophyHall = trophyHall,
	Helipad = helipad,
	Hangar = hangar,
	SubPen = subPen,
	LifeboatSlip = lifeboatSlip,
	Lighthouse = lighthouse,
} :: { [string]: (Model, CFrame) -> () }

local KEEP_1X =
	{ Path = true, Slipway = true, SlipRail = true, BoardSlot = true, PaintBooth = true }
local AFLOAT = { Pontoon = true, SubPen = true, TrophyHall = true, Crane = true } -- no lot bed: on the water or a wall

-- The pieces of building `key` (DockConfig.Buildings, Blueprints) around the berth frame `cf`, as a Model
-- named `key`. A worker building with no builder of its own is a plain Lego hut.
function DockPieces.building(key: string, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = key
	local fn = BUILDINGS[key]
	if fn then
		fn(m, cf)
	elseif DockConfig.Buildings[key] then
		hut(m, cf, key)
	end
	local def = DockConfig.Buildings[key]
	if def and def.scale then
		-- WP-25 r8: built at 1x, scaled up round its spot to fill the lot; walks and the slipway keep their size
		-- and ends (they meet the lanes and the sea), the boat board's slot and the paint booth their zones
		local keep = {}
		for _, d in m:GetChildren() do
			if KEEP_1X[d.Name] then
				table.insert(keep, d)
				d.Parent = nil
			end
		end
		m.WorldPivot = cf * def.spot
		m:ScaleTo(def.scale)
		for _, d in keep do
			d.Parent = m
		end
	end
	local spec = HUTS[key]
	if def and spec and spec.tree then -- a tree at the back corner (1x, like the plate's trees)
		tree(
			m,
			cf * def.spot * CFrame.new(spec.tree * (def.size.X / 2 + 3), 0, def.size.Y / 2 + 1),
			0.8
		)
	end
	if def and def.spot and def.size and not AFLOAT[key] then
		-- WP-25 r7: a darker green bed under the lot (2 studs round it, under the paths): a framed plot, not lawn
		local bed = brick(
			m,
			"LotBed",
			Vector3.new(def.size.X + 4, 0.26, def.size.Y + 4),
			cf * def.spot * CFrame.new(0, 0.13, 0),
			Color3.fromRGB(75, 151, 75)
		)
		bed.CanCollide, bed.CanQuery = false, false
		studTop(bed)
	end
	return m
end

-- WP-25 r4/r6/r7: an empty lot's marker (`at` on the plate, its footprint `size`; `b` the berth frame): a low grey
-- Lego stud plate with the build glyph in the middle and a 3-stud rim in the owner's colour (SurfaceGui frames named "Rim": no parts) and a tall
-- "for sale" peg flag with the build glyph at a corner, turned to face the build camera. The flag is named "Flag"
-- (the owner's colour; DockService colours the rim with it). The paper blueprint lies on top.
function DockPieces.lotMarker(b: CFrame, at: CFrame, size: Vector2, price: number?): Model
	local m = Instance.new("Model")
	m.Name = "LotMarker"
	local pad = brick(
		m,
		"LotPad",
		Vector3.new(size.X - 1, 0.4, size.Y - 1),
		at * CFrame.new(0, 0.2, 0),
		LBG -- WP-25 r7: a grey baseplate (white read as a missing texture; tan is the paths now)
	)
	pad.CanCollide = false
	studTop(pad)
	local gui = border(pad, DBG, 24)
	local glyph = Instance.new("ImageLabel") -- the build glyph in the middle: "build here" from the top-down camera
	glyph.BackgroundTransparency = 1
	glyph.Image = UiImages.Kit.build
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromOffset(math.min(size.X, size.Y) * 3.6, math.min(size.X, size.Y) * 3.6) -- 45% (8 px a stud)
	glyph.Parent = gui
	for _, c in { V(0, 0), V(1, 0), V(0, 1), V(1, 1) } do -- 4-stud corner tiles: read from the build camera
		local f = Instance.new("Frame")
		f.Name = "Rim"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = DBG
		f.AnchorPoint = c
		f.Position = UDim2.fromScale(c.X, c.Y)
		f.Size = UDim2.fromOffset(32, 32)
		f.Parent = gui
	end
	local peg = at * CFrame.new(-size.X / 2 + 2.5, 0, -size.Y / 2 + 2.5)
	studTop(brick(m, "LotPeg", Vector3.new(1.2, 13, 1.2), peg * CFrame.new(0, 6.5, 0), BRICK_WHITE))
	local face = CFrame.new(peg.Position) * isle(b, 0, 0).Rotation -- +Z toward the island's back: the build camera
	local f = brick(m, "Flag", Vector3.new(8, 5.2, 0.8), face * CFrame.new(4.6, 10, 0), BRICK_WHITE)
	f.CanCollide = false
	for _, n in { Enum.NormalId.Front, Enum.NormalId.Back } do
		if not price then
			local d = Instance.new("Decal")
			d.Face = n
			d.Texture = UiImages.Kit.build
			d.Parent = f
			continue
		end
		-- WP-25 r8: the build glyph over the lot's price (cash icon + 2.5K): what this lot buys, at a glance
		local sgui = Instance.new("SurfaceGui")
		sgui.Face = n
		sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgui.PixelsPerStud = 30
		sgui.LightInfluence = 0.4
		sgui.Parent = f
		local mark = Instance.new("ImageLabel")
		mark.BackgroundTransparency = 1
		mark.Image = UiImages.Kit.build
		mark.ScaleType = Enum.ScaleType.Fit
		mark.Position = UDim2.fromScale(0, 0.04)
		mark.Size = UDim2.fromScale(1, 0.52)
		mark.Parent = sgui
		local cash = mark:Clone()
		cash.Image = UiImages.Kit.cash
		cash.Position = UDim2.fromScale(0.06, 0.58)
		cash.Size = UDim2.fromScale(0.3, 0.38)
		cash.Parent = sgui
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.36, 0.58)
		label.Size = UDim2.fromScale(0.6, 0.38)
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = BRICK_WHITE -- on any owner colour
		label.TextStrokeTransparency = 0
		label.Text = if price >= 1000 then string.format("%gK", price / 1000) else tostring(price)
		label.Parent = sgui
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	return m
end

-- WP-25 r9: the finish pass used to fill the lawn with garden clusters; docs/24 C opened the island up, so the
-- whole-tree pass adds nothing now (the empty lots still become gardens, DockPieces.lotGarden). Kept because
-- DockService owns the lifecycle of this model.
function DockPieces.finish(_b: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Finish"
	return m
end

-- WP-25 r9: an empty lot once the whole tree is built (`at` on the plate, its footprint `size`): a finished garden,
-- not a for-sale pad: a lot bed, a tan stud patio, tulip beds either side, a white fence with a gate, bushes, a pot
function DockPieces.lotGarden(at: CFrame, size: Vector2): Model
	local m = Instance.new("Model")
	m.Name = "LotGarden"
	local bed = brick(
		m,
		"LotBed",
		Vector3.new(size.X + 4, 0.26, size.Y + 4),
		at * CFrame.new(0, 0.13, 0),
		Color3.fromRGB(75, 151, 75)
	)
	studTop(bed)
	local patio = brick(
		m,
		"Patio",
		Vector3.new(size.X * 0.5, 0.4, size.Y * 0.5),
		at * CFrame.new(0, 0.3, 0),
		TAN
	)
	studTop(patio)
	border(patio, BRICK_WHITE, 10)
	local hx, hz = size.X / 2, size.Y / 2
	for _, x in { -1, 1 } do
		field(
			m,
			at * CFrame.new(x * hx * 0.72, 0, 0),
			size.X * 0.2,
			size.Y * 0.7,
			if x < 0 then 1 else 3
		)
		brick(
			m,
			"Fence",
			Vector3.new(hx - 3, 1.8, 0.7),
			at * CFrame.new(x * (hx + 3) / 2, 0.9, -hz + 0.5),
			BRICK_WHITE
		)
		for _, z in { -1, 1 } do
			part(
				m,
				"Bush",
				Vector3.new(3.6, 3.6, 3.6),
				at * CFrame.new(x * hx * 0.32, 1.8, z * hz * 0.32),
				LEAF,
				M.SmoothPlastic,
				Enum.PartType.Ball
			)
		end
	end
	brick(m, "Fence", Vector3.new(size.X, 1.8, 0.7), at * CFrame.new(0, 0.9, hz - 0.5), BRICK_WHITE)
	part(
		m,
		"Pot",
		Vector3.new(2.6, 4, 4),
		at * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		BRICK_ORANGE,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Bloom",
		Vector3.new(4, 4, 4),
		at * CFrame.new(0, 3.6, 0),
		BRICK_PINK,
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery, d.CanCollide = false, d.Name == "Fence"
		end
	end
	return m
end

-- WP-25 r4: owner-colour tile bands across the quay walks (the promenade, both cove walks): one clear carrier part
-- per walk with a SurfaceGui of band frames (few parts). Returns the frames; DockService colours them with the flag.
local QUAY_WALKS =
	{ { V(-52, 23), V(55, 23) }, { V(55, 23), V(55, 104) }, { V(-52, 23), V(-52, 148) } }
function DockPieces.quayBands(parent: Instance, b: CFrame): { Frame }
	local out = {}
	for _, w in QUAY_WALKS do
		local from, to = isle(b, w[1].X, w[1].Y).Position, isle(b, w[2].X, w[2].Y).Position
		local len = (to - from).Magnitude + 8
		local p = brick(
			parent,
			"Bands",
			Vector3.new(8, 0.05, len),
			CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, 0.37, 0),
			WHITE
		)
		p.Transparency = 1
		p.CanCollide, p.CastShadow, p.CanQuery, p.CanTouch = false, false, false, false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 8
		gui.LightInfluence = 1
		gui.Parent = p
		for z = 4, len - 6, 8 do -- 4-stud tiles, 4 apart
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.Position = UDim2.fromScale(0, z / len)
			f.Size = UDim2.fromScale(1, 4 / len)
			f.Parent = gui
			table.insert(out, f)
		end
	end
	return out
end

-- The trophy hall's contents (docs/23 d.2) around the berth CFrame b: a gold cup per name in `cups`
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
			M.SmoothPlastic
		)
		part(
			m,
			"CupStem",
			Vector3.new(0.7, 0.3, 0.3),
			hall * CFrame.new(x, 3.5, -0.7) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		part(
			m,
			"Cup",
			Vector3.new(1.1, 1.1, 1.1),
			hall * CFrame.new(x, 4.25, -0.7),
			GOLD,
			M.SmoothPlastic,
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
			M.SmoothPlastic
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

-- WP-14d (docs/23 (j) rule 4): the build station. Bright Lego bricks, a toolbox, a mini crane and the
-- tablet whose SurfaceGui opens the build mode (DockController binds its ProximityPrompt). The tablet's
-- Front face (its screen) looks toward the island spawn; its part is named "Tablet".

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
		M.SmoothPlastic
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
		M.SmoothPlastic
	)
	part(
		m,
		"CraneHook",
		Vector3.new(0.9, 0.9, 0.9),
		crane * CFrame.new(0, 3.6, 4.2),
		BRICK_RED,
		M.SmoothPlastic
	)

	-- tablet on its stand at the spawn-side edge, its screen turned toward the spawn (+Z, Marina.spawn)
	local stand = at * CFrame.new(0, baseY, 3.6)
	local face = stand
		* CFrame.new(0, 5.4, 0)
		* CFrame.Angles(0, math.pi, 0)
		* CFrame.Angles(math.rad(-8), 0, 0)
	part(
		m,
		"TabletStand",
		Vector3.new(2.2, 0.6, 2.2),
		stand * CFrame.new(0, 0.3, 0),
		GREY,
		M.SmoothPlastic
	)
	part(
		m,
		"TabletPost",
		Vector3.new(0.6, 3.6, 0.6),
		stand * CFrame.new(0, 2.4, 0),
		STEEL,
		M.SmoothPlastic
	)
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
	screen.BackgroundColor3 = Color3.fromRGB(30, 58, 104) -- WP-25: a calm deep blue, not glaring
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
			part(
				m,
				"Leg",
				Vector3.new(0.5, 2, 0.5),
				at * CFrame.new(x, 1, z),
				GREY,
				M.SmoothPlastic
			)
		end
	end
end

DECOR_BUILDERS.LampRow = function(m: Model, at: CFrame, d: DockConfig.Decor)
	part(
		m,
		"Rail",
		Vector3.new(d.size.X, 0.6, 1.6),
		at * CFrame.new(0, 0.3, 0),
		GREY,
		M.SmoothPlastic
	)
	for _, x in { -3, 0, 3 } do
		part(
			m,
			"LampPost",
			Vector3.new(9, 0.5, 0.5),
			at * CFrame.new(x, 4.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
			STEEL,
			M.SmoothPlastic,
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
		M.SmoothPlastic,
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
		M.SmoothPlastic,
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
			M.SmoothPlastic
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
