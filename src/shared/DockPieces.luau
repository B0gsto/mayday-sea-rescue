--!strict
-- DockPieces (docs/23 d.2, WP-4; WP-19b; the unlock tree, WP-28): the placeholder Parts of every island building
-- (DockConfig.Buildings), around the berth frame (Marina.berth: the island's boat berth at sea level, -Z = out of
-- the cove, the craft at x -7..7, the jetty finger at x -17..-9, the jetty at x -27..-17). Each stands on its
-- island lot (Marina.LOTS, berth frame): the pontoon (beside the berth), lamps, rescue board on the quay; the
-- boathouse (its lot) + paint booth arches over the berth; the lookout tower (the beach tower lot); the slipway
-- crane on the quay; the station (its lot): lit front, roof beacon; the trophy hall wall on its front; the
-- helipad and hangar on their lots; the sub pen over the sub berth; the worker buildings as open work yards
-- (docs/24 C) and the lifeboat slip on their DockConfig spot. DockService builds them (everyone sees them); a buy plays the Lego build
-- beat (shared/BuildSeq) client-side. The build station (docs/23 (j) rule 4, WP-14d) stands on the jetty head
-- (docs/25 J), and the Cash-only decorations on the Spare2 / Spare3 spare lots. Named hooks: parts
-- "Flag" take the owner's colour, TextLabels "Count" show the rescue count. Materials stay off the
-- MaterialService remap (no Slate, WoodPlanks, Brick, Concrete).
local AssetIds = require(script.Parent:WaitForChild("Config"):WaitForChild("AssetIds"))
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(script.Parent:WaitForChild("Marina"))
local RingLayout = require(script.Parent:WaitForChild("Config"):WaitForChild("RingLayout"))
local UiImages = require(script.Parent:WaitForChild("Config"):WaitForChild("UiImages"))

local DockPieces = {}

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
local PLAZA = Color3.fromRGB(196, 160, 110) -- docs/24 C r3: the plaza tiles, darker than the tan paths
local PLAZA_EDGE = Color3.fromRGB(126, 96, 62) -- its dark tile border
local RBROWN = Color3.fromRGB(105, 64, 40) -- reddish brown: wood
local PANE = Color3.fromRGB(150, 205, 240) -- window glass
local INK = Color3.fromRGB(30, 44, 66) -- sign text
local STUDS = "rbxassetid://18878365966" -- a white 4 x 4 stud tile (IslandPlates)

local M = Enum.Material
local TOP = Marina.DECK_TOP
local LOT = Marina.LOTS
-- the station: half width, half depth, height; the trophy hall is on its front wall, left of the door
local ST = { hw = 26, hd = 15, h = 16 }
local HALL = DockConfig.Buildings.TrophyHall.spot -- the trophy wall lot, -Z = its front

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
	bulb:AddTag("NightLamp") -- WorkerController lights it at night only
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
-- slope-brick roofs, a tan path stub from the door to the nearest street (DockPieces.stub, DockPieces.streets).

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
-- `lift` stacks path layers (plaza 0, streets 0.04, building stubs 0.1) so overlapping tops never z-fight.
local function path(parent: Instance, b: CFrame, pts: { Vector2 }, lift: number)
	for k = 1, #pts - 1 do
		local from, to =
			isle(b, pts[k].X, pts[k].Y).Position, isle(b, pts[k + 1].X, pts[k + 1].Y).Position
		local p = brick(
			parent,
			"Path",
			Vector3.new(8, 0.3, (to - from).Magnitude + 8),
			CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, 0.15 + lift + (k % 2) * 0.02, 0), -- no z-fight at corners
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
	local L = b * DockConfig.Buildings.Boathouse.spot -- -Z = the doors
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

-- Level add-ons (docs/25 B): the Workshop's Lv2 saw-bench lean-to / Lv3 boat frame (M_Bld_WorkshopAddons), the
-- Fish Market's Lv2 stalls / Lv3 smokehouse (M_Bld_FishMarketAddons), the Clinic's Lv2 pavilion / Lv3 hospital
-- (M_Bld_ClinicAddons), the Lookout's Lv2 lantern / Lv3 searchlight (M_Bld_LookoutAddons), the Boat Yard's Lv2
-- crane / Lv3 dry dock (M_Bld_BoatYardAddons), the Rescue Boathouse's Lv2 RIB / Lv3 lifeboat berths
-- (M_Bld_RescueBoathouseAddons), the Air Station's Lv2 refuel pad / Lv3 patrol hut (M_Bld_AirStationAddons), the
-- Trophy Hall's Lv2 dome rotunda / Lv3 gold dome + galleries (M_Bld_TrophyHallAddons) and the Sub Pen's Lv2 gantry
-- / Lv3 salvage dock (M_Bld_SubPenAddons): meshes Lv<l>_L<nn>_*
-- and Lv<l>_COL authored in the yard's final (scaled) frame round its ground centre, so they stay 1x (KEEP_1X
-- `name`). False when the level is 1 or the mesh is not loaded (the Lv1 yard stands alone, everything included).
local function addonMesh(m: Model, at: CFrame, n: number, asset: string, name: string): boolean
	local src = if n >= 2 and DockPieces.meshes then DockPieces.meshes(asset) else nil
	if not src then
		return false
	end
	src:PivotTo(at)
	for _, d in src:GetDescendants() do
		if d:IsA("BasePart") and (tonumber(string.match(d.Name, "^Lv(%d)_")) or 2) > n then
			d:Destroy()
		end
	end
	src.Name = name
	src.Parent = m
	return true
end

-- the lookout tower on the beach tower lot: chunky white legs with red cross braces, a stud deck, a glazed cabin
-- with a red slope roof and a flag, a ladder up its open side
local function lookout(m: Model, b: CFrame, level: number?)
	local T = b * DockConfig.Buildings.LookoutTower.spot
	-- Lv2 gallery + roof lantern, Lv3 searchlight + radar (M_Bld_LookoutAddons), clear of the cabin, flag and ladder
	addonMesh(m, T, level or 1, "M_Bld_LookoutAddons", "LookoutMesh")
	local beam = m:FindFirstChild("Lv3_L04_Searchlight", true)
	if beam then -- its drum centre: the night sweep turns round it (WorkerController)
		local a = Instance.new("Attachment")
		a.Name = "SweepPivot"
		a.Parent = beam
		-- looking down the barrel: the tower's front, tilted up 12 degrees (the build's drum tilt)
		a.WorldCFrame = T
			* CFrame.new(AssetIds.Attachments.M_Bld_LookoutAddons.ATT_SearchlightPivot)
			* CFrame.Angles(math.rad(12), 0, 0)
	end
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
	local S = b * DockConfig.Buildings.HQ.spot -- -Z = the front
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

-- the trophy hall: a blue board in a yellow frame, a shelf and a name sign on its lot, framed by two white columns
-- and a gold dome (docs/24 C; DockPieces.trophies fills the board). Lv2 navy dome rotunda + 8 wing plinths, Lv3 gold
-- dome, portico and front galleries + 6 plinths (M_Bld_TrophyHallAddons): the rotunda drum swallows the code dome, so
-- it goes; nothing else gives way. Mesh missing: today's look.
local function trophyHall(m: Model, b: CFrame, level: number?)
	local mesh = addonMesh(m, b * HALL, level or 1, "M_Bld_TrophyHallAddons", "TrophyHallMesh")
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
	if not mesh then
		part(
			m,
			"Dome",
			Vector3.new(14, 5, 5),
			b * HALL * CFrame.new(0, 10.6, -0.6),
			GOLD,
			M.SmoothPlastic,
			Enum.PartType.Ball
		)
	end
	sign(m, Vector3.new(9, 1.6, 0.4), b * HALL * CFrame.new(0, 1.1, -0.1), BRICK_YELLOW, "Trophies")
end

-- WP-10b buildings (WP-19b: on their own lots) ------------------------------------------------------

local AIR = DockConfig.Buildings.AirStation.spot
local HELI = AIR * CFrame.new(38, 0.6, -27) -- the helicopter's spot: the pad centre
local SUB = DockConfig.Buildings.SubPen.spot

-- In the berth frame: `board` = the vehicle board's rack (models along
-- its X, facing its -Z), `targets[id]` = where that craft spawns (the berth when absent), `hook` = the gantry
-- height the sub hangs from.
DockPieces.Buildings = {
	AirStation = {
		board = AIR * CFrame.new(0, 0.2, 9),
		targets = { RescueHelicopter = HELI } :: { [string]: CFrame },
	},
	SubPen = {
		board = SUB * CFrame.new(0, 0.2, 9),
		targets = { Submarine = Marina.SUB } :: { [string]: CFrame },
	},
}

-- the helipad on its lot (an H, an edge line and lights)
local function helipad(m: Model, b: CFrame)
	local P = b * DockConfig.Buildings.AirStation.spot * CFrame.new(38, 0, -27)
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
end

-- the hangar on its lot, open toward the pad
local function hangar(m: Model, b: CFrame)
	local H = b * DockConfig.Buildings.AirStation.spot -- -Z = the open front, toward the pad
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
end

-- the sub pen (docs/24 C, moved to its own harbour lot): a ringed stud deck, a yellow gantry and a white dome cap.
-- The submarine still launches from the old sub berth (Marina.SUB); the board is on this deck. Lv2 gantry + hanging
-- mini-sub + dive rack on the -X plinth rim, Lv3 salvage wet dock behind the pen (M_Bld_SubPenAddons, mesh x -19..12,
-- z -7..37: clear of the code gantry, beams, deck and board, so no Lv1 piece gives way). Mesh missing: today's look.
local function subPen(m: Model, b: CFrame, level: number?)
	local S = b * DockConfig.Buildings.SubPen.spot -- -Z = the front, toward the plaza
	addonMesh(m, S, level or 1, "M_Bld_SubPenAddons", "SubPenMesh")
	local hx, top = 8, 16
	plinth(m, Vector3.new(38, 0.8, 38), S * CFrame.new(0, 0.4, 0), BRICK_WHITE)
	studTop(brick(m, "Deck", Vector3.new(30, 0.8, 30), S * CFrame.new(0, 0.8, 0), GREY))
	-- a round moon pool in the middle (the sub surfaces here in the fiction; the real berth stays Marina.SUB)
	part(
		m,
		"Pool",
		Vector3.new(1, 16, 16),
		S * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(30, 90, 140),
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	).CanCollide =
		false
	-- four gantry legs and a square beam frame over the pool
	for _, x in { -hx - 2, hx + 2 } do
		for _, z in { -hx, hx } do
			brick(
				m,
				"Leg",
				Vector3.new(1.6, top + 6, 1.6),
				S * CFrame.new(x, (top - 6) / 2, z),
				GREY
			)
		end
		brick(m, "Beam", Vector3.new(1.4, 1.4, hx * 2 + 1.6), S * CFrame.new(x, top, 0), YELLOW)
	end
	for _, z in { -hx, hx } do
		brick(m, "Beam", Vector3.new(hx * 2 + 4, 1.4, 1.4), S * CFrame.new(0, top, z), YELLOW)
	end
	brick(m, "Trolley", Vector3.new(hx * 2, 1.4, 2.4), S * CFrame.new(0, top + 0.2, 0), BRICK_RED)
	-- the dome: a yellow ring on the beams and a white cap
	part(
		m,
		"DomeRing",
		Vector3.new(1.2, hx * 2 + 9, hx * 2 + 9),
		S * CFrame.new(0, top + 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		BRICK_YELLOW,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Dome",
		Vector3.new(hx * 2, 8, hx * 2),
		S * CFrame.new(0, top + 4.8, 0),
		BRICK_WHITE,
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	sign(
		m,
		Vector3.new(10, 2.2, 0.4),
		S * CFrame.new(0, 8, -18),
		BRICK_WHITE,
		"Sub Pen",
		UiImages.Kit.lifebuoy
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
}

local function crate(m: Model, at: CFrame, color: Color3)
	studTop(brick(m, "Crate", Vector3.new(2.6, 2, 2.6), at * CFrame.new(0, 1, 0), color))
end

local HUTS: { [string]: Hut } = {
	Workshop = {
		tree = -1,
		roof = BRICK_RED,
		icon = UiImages.Kit.build,
	},
	FishShed = {
		tree = 1,
		roof = BRICK_WHITE,
		icon = UiImages.Kit.cash,
	},
	BoatYard = {
		tree = 1,
		roof = BRICK_BLUE,
		icon = UiImages.Kit.boost,
	},
	RescueBoathouse = {
		tree = 1,
		roof = BRICK_WHITE,
		icon = UiImages.Kit.lifebuoy,
	},
	Clinic = {
		tree = -1,
		roof = BRICK_RED,
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
end

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

-- docs/24 C: the worker buildings are open work yards, so the crew and their props read from the front (-Z).
-- Built at size / scale; DockPieces.building scales the lot's footprint back up.
local function yardSize(def: DockConfig.Building): (number, number)
	return def.size.X / (def.scale or 1), def.size.Y / (def.scale or 1)
end

-- docs/24 C r3: a low white edge wall round each yard pad, with an opening at the front (-Z) where the path
-- comes in; the gate posts take the yard's accent colour (not "Flag": the owner colour stays on the sign).
-- docs/24 C r4: the sea-side (back) edge takes the yard's own material instead of the white wall.
local function yardFence(
	m: Model,
	at: CFrame,
	w: number,
	d: number,
	accent: Color3,
	gap: number?,
	edge: string?
)
	local open = gap or 10
	local z = d / 2 + 1.0
	local y = 0.8 + 1.2
	if edge == "rope" then -- Fish shed: blue rope posts
		for i = 0, 3 do
			brick(
				m,
				"RopePost",
				Vector3.new(1, 3.6, 1),
				at * CFrame.new((i - 1.5) * w / 4, 0.8 + 1.8, z),
				accent
			)
		end
		for i = 0, 2 do
			brick(
				m,
				"Rope",
				Vector3.new(w / 4 - 1, 0.3, 0.3),
				at * CFrame.new((i - 1) * w / 4, 0.8 + 2.9, z),
				accent
			)
		end
	elseif edge == "picket" then -- Clinic: a white picket fence
		for i = 0, 5 do
			brick(
				m,
				"Picket",
				Vector3.new(0.7, 3.2, 0.4),
				at * CFrame.new((i - 2.5) * w / 6, 0.8 + 1.6, z),
				BRICK_WHITE
			)
		end
		brick(
			m,
			"PicketRail",
			Vector3.new(w - 1, 0.5, 0.5),
			at * CFrame.new(0, 0.8 + 1.4, z),
			BRICK_WHITE
		)
	elseif edge == "planks" then -- Boat yard: wooden slipway planks running out to the sea
		for i = -2, 2 do
			studTop(
				brick(
					m,
					"SlipPlank",
					Vector3.new(2.2, 0.5, 5.2),
					at * CFrame.new(i * 3.4, 0.8 + 0.25, z - 2.4),
					RBROWN
				)
			)
		end
	elseif edge == "rack" then -- Workshop: no wall, a tool rack
		for _, x in { -w / 3, w / 3 } do
			brick(m, "RackPost", Vector3.new(0.9, 7, 0.9), at * CFrame.new(x, 0.8 + 3.5, z), RBROWN)
		end
		brick(
			m,
			"RackBar",
			Vector3.new(2 * w / 3 + 1, 0.7, 0.7),
			at * CFrame.new(0, 0.8 + 7, z),
			RBROWN
		)
		brick(
			m,
			"Saw",
			Vector3.new(0.25, 2.4, 1.4),
			at * CFrame.new(-w / 6, 0.8 + 5.6, z - 0.4),
			STEEL
		)
		brick(
			m,
			"Hammer",
			Vector3.new(0.4, 1.4, 0.4),
			at * CFrame.new(w / 6, 0.8 + 6, z - 0.4),
			RBROWN
		)
		brick(
			m,
			"Hammer",
			Vector3.new(1.4, 0.6, 0.6),
			at * CFrame.new(w / 6, 0.8 + 6.7, z - 0.4),
			STEEL
		)
	else
		brick(m, "Fence", Vector3.new(w + 2.7, 2.4, 0.7), at * CFrame.new(0, y, z), BRICK_WHITE)
	end
	for _, s in { -1, 1 } do
		brick(
			m,
			"Fence",
			Vector3.new(0.7, 2.4, d + 2.7),
			at * CFrame.new(s * (w / 2 + 1.0), y, 0),
			BRICK_WHITE
		)
		brick(
			m,
			"Fence",
			Vector3.new((w - open) / 2, 2.4, 0.7),
			at * CFrame.new(s * (w + open) / 4, y, -z),
			BRICK_WHITE
		)
		brick(
			m,
			"GatePost",
			Vector3.new(1.2, 3.4, 1.2),
			at * CFrame.new(s * open / 2, 0.8 + 1.7, -z),
			accent
		)
	end
end

-- a tan path staple on the pad from the gate to the work area (the lane path runs under the plinth)
local function yardPath(m: Model, at: CFrame, d: number)
	local p =
		brick(m, "YardPath", Vector3.new(8, 0.24, 8), at * CFrame.new(0, 0.92, -d / 2 + 3), TAN)
	p.CanCollide = false
	studTop(p)
end

local function barrel(m: Model, at: CFrame)
	part(
		m,
		"Barrel",
		Vector3.new(2.6, 2.3, 2.3),
		at * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		RBROWN,
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)
end

-- crate + barrel clusters at the pad's front corners, clear of the gate: the yard's working edges
local function yardClutter(m: Model, at: CFrame, w: number, d: number)
	for _, s in { -1, 1 } do
		local x, z = s * (w / 2 - 2), -d / 2 + 1.2
		crate(m, at * CFrame.new(x, 0.8, z), if s < 0 then BRICK_ORANGE else BRICK_BLUE)
		barrel(m, at * CFrame.new(x + s * 1.8, 0.8, z + 1.3))
	end
	crate(m, at * CFrame.new(-w / 2 + 2.1, 0.8, -d / 2 + 3.4), BRICK_YELLOW)
end

-- docs/24 C r3: a bloom patch or a rock on the lawn between the yards (called by a built yard only, so the bare
-- plate stays open and inside its part budget)
local ROCK = Color3.fromRGB(150, 149, 152)
local function rock(m: Model, at: CFrame)
	local p = part(
		m,
		"Rock",
		Vector3.new(3.2, 2, 2.6),
		at * CFrame.new(0, 0.9, 0),
		ROCK,
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	p.CanCollide = false
end

-- Builder: an open-air carpentry yard: bench under a low lean-to, timber stacks and a half-built boat frame
local function workshopYard(m: Model, b: CFrame, level: number?)
	local def = DockConfig.Buildings.Workshop
	local at = b * def.spot
	-- the add-ons take the sawhorse's job and stand where the timber stack and the old boat frame were
	local addons = addonMesh(m, at, level or 1, "M_Bld_WorkshopAddons", "WorkshopMesh")
	local w, d = yardSize(def)
	local spec = HUTS.Workshop
	local front = -d / 2
	local wall = def.color or BRICK_YELLOW
	plinth(m, Vector3.new(w + 3, 0.8, d + 3), at * CFrame.new(0, 0.4, 0))
	-- docs/24 C r4: no back wall (a tool rack on the pen's sea edge instead); a low bench on the crew's eye line
	studTop(
		brick(
			m,
			"Bench",
			Vector3.new(15, 0.7, 3.2),
			at * CFrame.new(0, 2.15, front + 5),
			BRICK_WHITE
		)
	)
	for _, x in { -5.2, 5.2 } do
		brick(m, "BenchLeg", Vector3.new(0.8, 1.9, 2.8), at * CFrame.new(x, 0.95, front + 5), DBG)
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
	-- a sawhorse by the front-left post, a plank stack by the front-right, a toolbox on the bench
	local horse = at * CFrame.new(-w / 2 + 1.4, 0, front + 4.1)
	if not addons then
		studTop(
			brick(m, "Sawhorse", Vector3.new(4.4, 0.5, 0.9), horse * CFrame.new(0, 2.6, 0), RBROWN)
		)
		for _, x in { -1.5, 1.5 } do
			brick(
				m,
				"SawhorseLeg",
				Vector3.new(0.45, 2.9, 0.8),
				horse * CFrame.new(x, 1.3, 0) * CFrame.Angles(0, 0, -x * 0.12),
				RBROWN
			)
		end
	end
	for i = 0, 2 do
		studTop(
			brick(
				m,
				"Planks",
				Vector3.new(5.2, 0.4, 1.6),
				at * CFrame.new(w / 2 - 2.2, 0.9 + i * 0.45, front + 2.4),
				RBROWN
			)
		)
	end
	studTop(
		brick(
			m,
			"Toolbox",
			Vector3.new(3, 1.2, 1.6),
			at * CFrame.new(4.4, 3.1, front + 5),
			BRICK_RED
		)
	)
	-- docs/24 C r4: a half-built crate by the front-right, where a Builder hammers
	local half = at * CFrame.new(7.5, 0, 4.4)
	brick(m, "CrateHalf", Vector3.new(3.2, 0.5, 3.2), half * CFrame.new(0, 1.05, 0), RBROWN)
	brick(m, "CrateHalf", Vector3.new(3.2, 1.6, 0.5), half * CFrame.new(0, 1.8, 1.35), RBROWN)
	brick(m, "CrateHalf", Vector3.new(0.5, 1.6, 2.7), half * CFrame.new(-1.35, 1.8, 0), RBROWN)
	-- timber stacks and the half-built boat frame deeper in the yard
	if not addons then
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
	end
	-- docs/24 C r3: the pad reads as a walled yard, and its lawn corner gets the island's colour
	yardFence(m, at, w, d, wall, nil, "rack")
	yardPath(m, at, d)
	yardClutter(m, at, w, d)
	field(m, at * CFrame.new(w / 2 + 5.5, 0, d / 2 + 5), 5, 5, 1)
	lamp(m, at, w / 2 + 9, d / 2 + 1, 0) -- a lamp over the lawn between the workshop and the boat yard
end

-- Gatherer: a fish market on the cove walk: two striped awning stalls, fish crates, drying racks
local function fishMarket(m: Model, b: CFrame, level: number?)
	local def = DockConfig.Buildings.FishShed
	local at = b * def.spot
	-- Lv2 flank stalls, Lv3 smokehouse at the back (M_Bld_FishMarketAddons); the smokehouse stands on the drying rack
	local smokehouse = addonMesh(m, at, level or 1, "M_Bld_FishMarketAddons", "FishMarketMesh")
		and (level or 1) >= 3
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
	-- a hanging line of fish at the back-left: two posts, a bar and five chunky fish
	if not smokehouse then
		local rack = at * CFrame.new(-w / 4, 0, d / 2 - 3)
		for _, x in { -4.6, 4.6 } do
			brick(
				m,
				"RackPost",
				Vector3.new(0.8, 7, 0.8),
				rack * CFrame.new(x, 4.3, 0),
				BRICK_WHITE
			)
		end
		brick(m, "RackBar", Vector3.new(10, 0.8, 0.8), rack * CFrame.new(0, 7.4, 0), BRICK_WHITE)
		for i = -2, 2 do
			brick(
				m,
				"Fish",
				Vector3.new(0.8, 2.2, 1.5),
				rack * CFrame.new(i * 2.1, 5.8, 0),
				if i % 2 == 0 then BRICK_ORANGE else BRICK_WHITE
			)
		end
	end
	-- ice crates of fish at each counter's end, a hanging scale by the right stall
	for _, s in
		{
			at * CFrame.new(-w / 2 + 2.4, 0, front + 8.2),
			at * CFrame.new(w / 2 - 2.4, 0, front + 8.2),
		}
	do
		studTop(
			brick(m, "IceCrate", Vector3.new(3.4, 2, 3.4), s * CFrame.new(0, 1, 0), BRICK_WHITE)
		)
		brick(m, "Ice", Vector3.new(3, 0.6, 3), s * CFrame.new(0, 2.2, 0), BRICK_CYAN)
		brick(m, "Fish", Vector3.new(0.8, 1.3, 2.3), s * CFrame.new(0, 2.8, 0), BRICK_ORANGE)
	end
	local scale = at * CFrame.new(w / 2 - 3, 0, front + 11.2)
	brick(m, "ScalePost", Vector3.new(0.6, 7, 0.6), scale * CFrame.new(0, 3.5, 0), DBG)
	brick(m, "ScaleArm", Vector3.new(0.5, 0.5, 2.8), scale * CFrame.new(0, 7, -1.1), DBG)
	brick(m, "ScalePan", Vector3.new(1.6, 0.4, 1.6), scale * CFrame.new(0, 4.4, -2.2), BRICK_WHITE)
	brick(m, "ScaleHook", Vector3.new(0.3, 2.4, 0.3), scale * CFrame.new(0, 5.8, -2.2), DBG)
	-- docs/24 C r3: a 24-stud pole with a BIG fish board and a flag whose inner edge sits on the pole
	local mast = at * CFrame.new(w / 4, 0, d / 2 - 1.6)
	brick(m, "Mast", Vector3.new(1.4, 24, 1.4), mast * CFrame.new(0, 12.8, 0), BRICK_WHITE)
	sign(
		m,
		Vector3.new(11, 7, 0.7),
		mast * CFrame.new(0, 15.5, -0.9),
		BRICK_WHITE,
		def.name,
		spec.icon,
		true
	)
	local fishFlag =
		brick(m, "Flag", Vector3.new(7.5, 4.2, 0.35), mast * CFrame.new(4.45, 22.6, 0), accent)
	fishFlag.CanCollide = false
	brick(m, "FlagStripe", Vector3.new(7.5, 1, 0.4), mast * CFrame.new(4.45, 21.2, 0), BRICK_WHITE)
	-- docs/24 C r3: the pad reads as a walled fish market; ice-blue crate clusters by the gate
	yardFence(m, at, w, d, accent, nil, "rope")
	yardPath(m, at, d)
	yardClutter(m, at, w, d)
	rock(m, at * CFrame.new(w / 2 + 5, 0, d / 2 + 4))
end

-- Mechanic: a boat up on a cradle under a gantry crane, tool chests beside it
local function boatYard(m: Model, b: CFrame, level: number?)
	local def = DockConfig.Buildings.BoatYard
	local at = b * def.spot
	-- Lv2 portal crane + hoisted engine and a tool bench, Lv3 dry dock on the east side (M_Bld_BoatYardAddons): the
	-- code gantry and tool chests give way to the crane and bench, the east slip planks to the dock's caisson
	local lv = if addonMesh(m, at, level or 1, "M_Bld_BoatYardAddons", "BoatYardMesh")
		then level or 1
		else 1
	local w, d = yardSize(def)
	local spec = HUTS.BoatYard
	plinth(m, Vector3.new(w + 3, 0.8, d + 3), at * CFrame.new(0, 0.4, 0))
	-- docs/24 C r3: the workboat on four chunky cradle legs with yellow feet
	-- docs/24 C r4: level on the cradle, 30% smaller, a wedge bow and a white deck line
	local boat = at * CFrame.new(0, 0, 0)
	for _, z in { -5, 5 } do
		studTop(
			brick(m, "Cradle", Vector3.new(9.4, 1.2, 2.2), boat * CFrame.new(0, 4.8, z), RBROWN)
		)
		for _, x in { -3.6, 3.6 } do
			brick(m, "CradleLeg", Vector3.new(1.6, 3.8, 1.6), boat * CFrame.new(x, 2.6, z), DBG)
			studTop(
				brick(
					m,
					"CradleFoot",
					Vector3.new(2.6, 0.6, 2.6),
					boat * CFrame.new(x, 1.1, z),
					BRICK_YELLOW
				)
			)
		end
	end
	studTop(brick(m, "Hull", Vector3.new(7.4, 3.2, 15), boat * CFrame.new(0, 7.0, 0), BRICK_RED))
	local bow = Instance.new("WedgePart")
	bow.Name = "Bow"
	bow.Size = Vector3.new(7.4, 3.2, 4.4)
	bow.CFrame = boat * CFrame.new(0, 7.0, -9.7) * CFrame.Angles(0, 0, math.pi)
	bow.Color, bow.Material, bow.Anchored = BRICK_RED, M.SmoothPlastic, true
	bow.Parent = m
	-- a white line along the deck edge: the boat reads red and white from the sea and the build camera
	brick(
		m,
		"HullStripe",
		Vector3.new(7.55, 0.7, 15.15),
		boat * CFrame.new(0, 8.25, 0),
		BRICK_WHITE
	)
	brick(m, "Deck", Vector3.new(6.2, 0.5, 12.6), boat * CFrame.new(0, 8.85, 0), DBG)
	brick(m, "Console", Vector3.new(3.2, 2.4, 2.8), boat * CFrame.new(0, 10.3, -2.4), BRICK_WHITE)
	-- a white cabin aft with windows on three sides
	studTop(
		brick(m, "Cabin", Vector3.new(4.6, 3.6, 4.2), boat * CFrame.new(0, 10.9, 3.2), BRICK_WHITE)
	)
	brick(m, "CabinPane", Vector3.new(4, 1.8, 0.25), boat * CFrame.new(0, 10.9, 1.05), PANE)
	for _, x in { -2.35, 2.35 } do
		brick(m, "CabinPane", Vector3.new(0.25, 1.8, 3.4), boat * CFrame.new(x, 10.9, 3.2), PANE)
	end
	brick(m, "CabinRoof", Vector3.new(5.4, 0.4, 5), boat * CFrame.new(0, 12.9, 3.2), BRICK_RED)
	if lv < 2 then
		-- a tall yellow gantry over the boat, its chain and hook down to the deck
		for _, x in { -8.5, 8.5 } do
			brick(m, "Leg", Vector3.new(1.2, 23, 1.2), boat * CFrame.new(x, 12.3, 0), BRICK_YELLOW)
		end
		brick(m, "Beam", Vector3.new(19, 1.2, 1.2), boat * CFrame.new(0, 24.4, 0), BRICK_YELLOW)
		brick(m, "Cable", Vector3.new(0.4, 12.1, 0.4), boat * CFrame.new(0, 17.75, 0), DBG)
		for i = 0, 2 do
			brick(
				m,
				"Chain",
				Vector3.new(0.5, 0.6, 0.5),
				boat * CFrame.new(0, 11.45 - i * 0.6, 0) * CFrame.Angles(0, i * math.pi / 2, 0),
				DBG
			)
		end
		brick(m, "Hook", Vector3.new(1.1, 1.1, 1.1), boat * CFrame.new(0, 9.65, 0), BRICK_ORANGE)
		brick(m, "HookTip", Vector3.new(0.4, 0.9, 0.4), boat * CFrame.new(0, 9.1, 0), BRICK_ORANGE)
	end
	sign(
		m,
		Vector3.new(7, 2, 0.4),
		-- Lv2+: standing on the crane's girder over the dock (scaled: x 14.1, girder top 18.26, girder mid z 5.7)
		if lv < 2 then boat * CFrame.new(0, 24.4, -0.9) else boat * CFrame.new(12.28, 16.88, 4.96),
		BRICK_YELLOW,
		def.name,
		spec.icon
	)
	-- tool chests and a tyre stack beside the hull
	if lv < 2 then
		local tools = at * CFrame.new(w / 2 - 4, 0, -d / 2 + 8)
		studTop(
			brick(
				m,
				"ToolChest",
				Vector3.new(3.6, 2.2, 2),
				tools * CFrame.new(0, 1.1, 0),
				BRICK_RED
			)
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
	end
	-- docs/24 C r3: a wider gate lets the bow out over the path; the pad reads as a yard
	yardFence(m, at, w, d, def.color or BRICK_YELLOW, 12, "planks")
	if lv >= 3 then -- the caisson and pump house stand on the east planks
		for _, p in m:GetChildren() do
			if
				p:IsA("BasePart")
				and p.Name == "SlipPlank"
				and at:PointToObjectSpace(p.Position).X > 1
			then
				p:Destroy()
			end
		end
	end
	yardPath(m, at, d)
	yardClutter(m, at, w, d)
	rock(m, at * CFrame.new(-w / 2 - 5, 0, d / 2 + 4))
end

-- Rescuer: an open slipway shed with the rescue boat, a lifebuoy rack and a tall lifeguard chair
local function rescueBoathouse(m: Model, b: CFrame, level: number?)
	local def = DockConfig.Buildings.RescueBoathouse
	local at = b * def.spot
	-- Lv2 RIB pontoon on the -X side, Lv3 lifeboat berth + shed roof on the +X side (M_Bld_RescueBoathouseAddons); the
	-- middle and the gate stay clear. The lifeguard chair stood where the Lv3 berth's back deck and roof go.
	local lv = if addonMesh(
			m,
			at,
			level or 1,
			"M_Bld_RescueBoathouseAddons",
			"RescueBoathouseMesh"
		)
		then level or 1
		else 1
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
	-- docs/24 C r3: a big lifebuoy rack at the front-left, in view of the cove walk
	local rack = at * CFrame.new(-w / 2 + 2.6, 0, -d / 2 + 3.6)
	for _, x in { -2.2, 2.2 } do
		brick(m, "RackPost", Vector3.new(0.9, 8, 0.9), rack * CFrame.new(x, 4.8, 0), BRICK_WHITE)
	end
	brick(m, "RackBar", Vector3.new(5.6, 0.9, 0.9), rack * CFrame.new(0, 8.6, 0), BRICK_WHITE)
	for _, x in { -1.6, 1.6 } do
		part(
			m,
			"Lifebuoy",
			Vector3.new(1, 3, 3),
			rack * CFrame.new(x, 6.6, -0.55) * CFrame.Angles(0, math.pi / 2, 0),
			BRICK_RED,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		part(
			m,
			"Lifebuoy",
			Vector3.new(1.1, 1.5, 1.5),
			rack * CFrame.new(x, 6.6, -0.65) * CFrame.Angles(0, math.pi / 2, 0),
			BRICK_WHITE,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	-- docs/24 C r3: a boat trailer inside the pen, ready for the slip
	local trailer = at * CFrame.new(-5, 0, d / 2 - 4.6)
	for _, x in { -2.2, 2.2 } do
		studTop(
			brick(
				m,
				"TrailerRail",
				Vector3.new(0.8, 0.7, 10),
				trailer * CFrame.new(x, 1.7, 0),
				BRICK_YELLOW
			)
		)
	end
	brick(
		m,
		"TrailerBeam",
		Vector3.new(5.2, 0.7, 0.8),
		trailer * CFrame.new(0, 1.7, 0),
		BRICK_YELLOW
	)
	brick(m, "TrailerAxle", Vector3.new(6.4, 0.6, 0.6), trailer * CFrame.new(0, 1.3, 0.6), DBG)
	brick(m, "TrailerHitch", Vector3.new(0.8, 0.7, 4.4), trailer * CFrame.new(0, 1.4, -6), DBG)
	for _, x in { -3, 3 } do
		part(
			m,
			"TrailerWheel",
			Vector3.new(0.9, 3, 3),
			trailer * CFrame.new(x, 1.6, 0.6) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(40, 42, 48),
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	-- an oar rack and a fuel can at the back, the slipway's working clutter
	local oars = at * CFrame.new(3.4, 0, d / 2 - 1.6)
	for _, x in { -2.2, 2.2 } do
		brick(m, "OarPost", Vector3.new(0.6, 5, 0.6), oars * CFrame.new(x, 2.5, 0), BRICK_WHITE)
	end
	brick(m, "OarBar", Vector3.new(5, 0.6, 0.6), oars * CFrame.new(0, 5, 0), BRICK_WHITE)
	for _, x in { -0.9, 0.9 } do
		brick(
			m,
			"Oar",
			Vector3.new(0.35, 5.4, 0.35),
			oars * CFrame.new(x, 2.7, -0.4) * CFrame.Angles(0, 0, -x * 0.1),
			RBROWN
		)
	end
	studTop(
		brick(
			m,
			"FuelCan",
			Vector3.new(1.4, 1.8, 1),
			at * CFrame.new(1.4, 0.9, d / 2 - 2.6),
			BRICK_RED
		)
	)
	-- docs/24 C r4: a work table on the right, the third station across the pen
	local table = at * CFrame.new(7, 0, -2.5)
	studTop(
		brick(m, "Table", Vector3.new(5.2, 0.5, 3.2), table * CFrame.new(0, 2.7, 0), BRICK_WHITE)
	)
	for _, x in { -1.8, 1.8 } do
		brick(m, "TableLeg", Vector3.new(0.6, 1.6, 2.4), table * CFrame.new(x, 1.7, 0), DBG)
	end
	if lv < 3 then
		-- the tall lifeguard chair by the front corner: a seat over a narrow tower with a footrest
		local chair = at * CFrame.new(w / 2 - 4, 0, d / 2 - 3.6) -- back-right, clear of the gate clutter
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
		brick(
			m,
			"ChairStep",
			Vector3.new(2, 0.4, 1.2),
			chair * CFrame.new(0, 5.8, -1.7),
			BRICK_WHITE
		)
	end
	sign(
		m,
		Vector3.new(6, 2, 0.4),
		at * CFrame.new(0, 9.4, -d / 2 + 0.2),
		BRICK_WHITE,
		def.name,
		spec.icon
	)
	-- docs/24 C r3: a walled pad, a lamp post between the yards
	yardFence(m, at, w, d, def.color or BRICK_RED)
	yardPath(m, at, d)
	yardClutter(m, at, w, d)
	lamp(m, at, -w / 2 - 5, d / 2 + 4, 0)
end

-- Medic: a white pavilion (open sides) with a big red cross, two beds and a stretcher in view
local function clinic(m: Model, b: CFrame, level: number?)
	local def = DockConfig.Buildings.Clinic
	local at = b * def.spot
	-- Lv2 pavilion on the right flank (on the flagpole's spot), Lv3 hospital + ambulance on the left (on the bloom
	-- patch and the corner tree; DockPieces.building skips the tree on NoTree)
	local lv = if addonMesh(m, at, level or 1, "M_Bld_ClinicAddons", "ClinicMesh")
		then level or 1
		else 1
	if lv >= 3 then
		m:SetAttribute("NoTree", true)
	end
	local w, d = yardSize(def)
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
	-- a red band along the front and back eaves: the white tent reads against the white plate
	for _, z in { -1, 1 } do
		brick(
			m,
			"EaveBand",
			Vector3.new(w + 2, 1.2, 0.6),
			at * CFrame.new(0, 10.4, z * (d / 2 + 2.4)),
			BRICK_RED
		)
	end
	-- the big red cross on the front header: readable from the lane and the build camera
	brick(m, "Header", Vector3.new(9, 4.6, 0.5), at * CFrame.new(0, 8.4, -d / 2 + 0.2), BRICK_WHITE)
	brick(m, "Cross", Vector3.new(1.6, 4.2, 0.5), at * CFrame.new(0, 8.4, -d / 2 - 0.1), BRICK_RED)
	brick(m, "Cross", Vector3.new(4.2, 1.6, 0.5), at * CFrame.new(0, 8.4, -d / 2 - 0.1), BRICK_RED)
	-- and on the front roof slope, for the sea and the build camera
	local slope = top * CFrame.new(0, 1.2, -(d / 4 + 0.2)) * CFrame.Angles(-math.rad(14), 0, 0)
	brick(m, "RoofCross", Vector3.new(1.4, 0.5, 4), slope * CFrame.new(0, 0.55, -1.6), BRICK_RED)
	brick(m, "RoofCross", Vector3.new(4, 0.5, 1.4), slope * CFrame.new(0, 0.55, -1.6), BRICK_RED)
	-- docs/24 C r3: a ground flagpole with a red-cross flag beside the tent, not lost on the ridge
	if lv < 2 then
		studTop(
			brick(
				m,
				"FlagBase",
				Vector3.new(3.4, 0.9, 3.4),
				at * CFrame.new(w / 2 + 4, 0.45, -2),
				LBG
			)
		)
		local mast = at * CFrame.new(w / 2 + 4, 0.8, -2)
		brick(m, "Mast", Vector3.new(1.2, 16, 1.2), mast * CFrame.new(0, 8, 0), BRICK_WHITE)
		brick(m, "ClinicFlag", Vector3.new(6, 4, 0.35), mast * CFrame.new(3.6, 14, 0), BRICK_RED)
		brick(
			m,
			"FlagCross",
			Vector3.new(0.55, 3.2, 0.1),
			mast * CFrame.new(3.6, 14, -0.23),
			BRICK_WHITE
		)
		brick(
			m,
			"FlagCross",
			Vector3.new(3.2, 0.55, 0.1),
			mast * CFrame.new(3.6, 14, -0.23),
			BRICK_WHITE
		)
	end
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
	-- docs/24 C r3: a big stretcher at the open front, with a red cross on the blanket
	local st = at * CFrame.new(0, 0, -d / 2 + 5.5)
	for _, z in { -2.8, 2.8 } do
		brick(m, "StretcherLeg", Vector3.new(3.8, 1.4, 0.6), st * CFrame.new(0, 1.5, z), STEEL)
	end
	for _, x in { -2.6, 2.6 } do
		brick(m, "StretcherRail", Vector3.new(0.6, 0.6, 8), st * CFrame.new(x, 2.2, 0), STEEL)
	end
	brick(m, "Stretcher", Vector3.new(5.4, 0.5, 7.4), st * CFrame.new(0, 2.55, 0), BRICK_WHITE)
	brick(m, "Cross", Vector3.new(0.7, 0.15, 2.6), st * CFrame.new(0, 2.85, 0), BRICK_RED)
	brick(m, "Cross", Vector3.new(2.6, 0.15, 0.7), st * CFrame.new(0, 2.85, 0), BRICK_RED)
	studTop(brick(m, "Pillow", Vector3.new(3, 0.6, 1.6), st * CFrame.new(0, 2.9, 2.5), BRICK_CYAN))
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
	-- a first-aid cabinet between the beds
	brick(m, "Cabinet", Vector3.new(3.6, 4.4, 1.2), at * CFrame.new(0, 3, d / 2 - 0.8), BRICK_WHITE)
	brick(m, "Cross", Vector3.new(0.7, 2.6, 0.15), at * CFrame.new(0, 3.2, d / 2 - 1.5), BRICK_RED)
	brick(m, "Cross", Vector3.new(2.6, 0.7, 0.15), at * CFrame.new(0, 3.2, d / 2 - 1.5), BRICK_RED)
	-- docs/24 C r3: a walled pad and a bloom patch on the lawn beside it
	yardFence(m, at, w, d, def.color or BRICK_RED, nil, "picket")
	yardPath(m, at, d)
	yardClutter(m, at, w, d)
	if lv < 3 then
		field(m, at * CFrame.new(-w / 2 - 5.5, 0, d / 2 + 5), 5, 5, 3)
	end
end

-- the lifeboat slip (Boathouse Lv2) on its own harbour lot: an open shed over a slipway that runs off the plate
-- into the sea. It is kept at 1x inside the boathouse's model and faces +fwd (local -Z).
local function lifeboatSlip(m: Model, b: CFrame)
	local at = b * DockConfig.BOATHOUSE_SLIP -- -Z = toward the sea
	local w, d, h = 22, 50, 11
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
	-- flat from the shed to the plate's edge, then down into the sea
	local edge = 26
	brick(
		m,
		"Slipway",
		Vector3.new(7, 0.6, edge),
		at * CFrame.new(0, 0.3, -d / 2 - edge / 2 + 2),
		TAN
	)
	local from = (at * CFrame.new(0, 0, -d / 2 - edge + 2)).Position
	local to = (at * CFrame.new(0, -Marina.DECK_TOP - 1.5, -d / 2 - edge - 18)).Position
	local mid = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, 0.3, 0)
	brick(m, "Slipway", Vector3.new(7, 0.6, (to - from).Magnitude + 0.6), mid, TAN)
	for _, x in { -2.6, 2.6 } do
		brick(
			m,
			"SlipRail",
			Vector3.new(0.6, 0.6, edge),
			at * CFrame.new(x, 0.9, -d / 2 - edge / 2 + 2),
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
	path(m, b, { Vector2.new(-80, 82), Vector2.new(-80, 70) }, 0.1)
end

-- docs/25 J (owner 2026-10-27): empty start. The fixed set on every plate is only its edge (DockService adds the
-- jetty, its head deck, the berth and the sign); the streets arrive with HQ Lv1 (DockPieces.streets). Island
-- (r, f) points: r = right, f = out toward the cove.
local V = Vector2.new
-- docs/25-visuals.html map: the bridge road, the avenue from the HQ's back to it (past the spawn), the quay
-- promenades either side of the plaza and the two cove walks (the west one on to the quest tablet)
DockPieces.STREETS = {
	{ V(-121, -78), V(121, -78) }, -- the bridge road, bridge to bridge
	{ V(0, -78), V(0, -28) }, -- the avenue, the spawn to the HQ's back
	{ V(-152, 22), V(-44, 22) }, -- the quay promenades
	{ V(44, 22), V(152, 22) },
	{ V(-52, 22), V(-52, 148), V(-96, 148) }, -- the cove walks
	{ V(52, 22), V(52, 148) },
}
DockPieces.PLAZA = { centre = V(0, 17), size = V(80, 26) } -- from the HQ's front to the jetty head (the avenue)
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

-- The bare plate's edge: the cove's side walls, a stud-capped dark grey quay edge, yellow bollards on it, black tyre
-- fenders below. Nothing else stands on the land until the first build.
function DockPieces.base(b: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "IslandSet"
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
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false -- set dressing: no prompts or camera hits
		end
	end
	return m
end

-- The street grid (docs/25 J: it arrives with HQ Lv1): the plaza tiles in front of the HQ, the tan stud paths.
function DockPieces.streets(b: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Streets"
	for _, pts in DockPieces.STREETS do
		path(m, b, pts, 0.04)
	end
	local c, s = DockPieces.PLAZA.centre, DockPieces.PLAZA.size
	local plaza = brick(
		m,
		"Plaza",
		Vector3.new(s.X, 0.3, s.Y),
		isle(b, c.X, c.Y) * CFrame.new(0, 0.15, 0),
		PLAZA
	)
	plaza.CanCollide = false
	studTop(plaza)
	border(plaza, PLAZA_EDGE, 24) -- a 3-stud darker tile border round the plaza
	return m
end

-- The nearest point on the streets (or the plaza) to island point p.
local function nearestStreet(p: Vector2): Vector2
	local best, bestD = p, math.huge
	local function try(q: Vector2)
		local d = (q - p).Magnitude
		if d < bestD then
			best, bestD = q, d
		end
	end
	for _, pts in DockPieces.STREETS do
		for k = 1, #pts - 1 do
			local a, ab = pts[k], pts[k + 1] - pts[k]
			try(a + ab * math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1))
		end
	end
	local c, h = DockPieces.PLAZA.centre, DockPieces.PLAZA.size / 2
	try(V(math.clamp(p.X, c.X - h.X, c.X + h.X), math.clamp(p.Y, c.Y - h.Y, c.Y + h.Y)))
	return best
end

-- docs/25 J: a building's own short path from its door (the spot's -Z side) to the nearest street: out of the door,
-- then one turn onto the street. Returns island (r, f) points.
function DockPieces.stub(spot: CFrame, size: Vector2): { Vector2 }
	local function toIsle(cf: CFrame): Vector2
		local p = Marina.ISLAND:PointToObjectSpace(cf.Position)
		return V(p.X, -p.Z)
	end
	local door = toIsle(spot * CFrame.new(0, 0, -size.Y / 2))
	local out = toIsle(spot * CFrame.new(0, 0, -size.Y / 2 - 6))
	local q = nearestStreet(out)
	local dir = out - door
	local turn = if math.abs(dir.X) > math.abs(dir.Y) then V(q.X, out.Y) else V(out.X, q.Y)
	if (turn - door):Dot(dir) < 0 then
		turn = out -- the street is behind the door: step out first
	end
	local pts = { door }
	for _, pt in { turn, q } do
		if (pt - pts[#pts]).Magnitude > 0.5 then
			table.insert(pts, pt)
		end
	end
	return pts
end

-- Harbour levels: Lv1 is the bare jetty (the plate's fixed jetty), Lv2 the pontoon, Lv3 the crane.
local function harbour(m: Model, b: CFrame, level: number?)
	if (level or 1) >= 2 then
		pontoon(m, b)
	end
	if (level or 1) >= 3 then
		slipCrane(m, b)
	end
end

-- Set by the server (DepotArtService): a static copy of an uploaded building mesh (the walk-in _COL hulls collide,
-- the visual meshes don't); it waits for the first load and is nil if the asset failed (a code-built piece stands in).
DockPieces.meshes = nil :: ((asset: string) -> Model?)?

-- A levelled building mesh (M_Bld_RescueHQ, M_Bld_Bunkhouse) at `at`: meshes named _Lv<l>_L<k>_ (layer k of level l,
-- ConstructionController raises them) and _Lv<l>_Col[NN]_COL; level n = the meshes of levels 1..n. The OwnerColour doors
-- become "Flag"s. Nil when the mesh is not loaded.
local function levelMesh(m: Model, at: CFrame, asset: string, n: number): Model?
	local src = DockPieces.meshes and DockPieces.meshes(asset)
	if not src then
		return nil
	end
	src:PivotTo(at)
	for _, d in src:GetDescendants() do
		if d:IsA("BasePart") then
			local lv, k = string.match(d.Name, "_Lv(%d)_L(%d+)_")
			local l = tonumber(lv or string.match(d.Name, "_Lv(%d)_Col%d*_COL$")) or 1
			if l > n then
				d:Destroy()
			elseif k and string.find(d.Name, "OwnerColour", 1, true) then
				d.Name = "Flag" -- DockService paints it the owner's colour
				-- a textured part ignores Color, so drop the texture for the tint to show
				for _, c in d:GetChildren() do
					if c:IsA("SurfaceAppearance") or c.Name == "SurfaceVariants" then
						c:Destroy()
					end
				end
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			end
		end
	end
	src.Parent = m
	return src
end

-- HQ Lv1 Rescue Hut / Lv2 Rescue Post (M_Bld_RescueHQ); the sign words go on the ATT_Sign_<l> plaques as a ribbon
-- across their lower edge. False when the mesh is not loaded.
local function hqMesh(m: Model, b: CFrame, n: number): boolean
	local src = levelMesh(m, b * DockConfig.Buildings.HQ.spot, "M_Bld_RescueHQ", n)
	if not src then
		return false
	end
	local signs = {}
	for l = 1, n do
		local att = src:FindFirstChild(`ATT_Sign_0{l}`, true)
		if att and att:IsA("Attachment") then
			signs[l] = att.WorldCFrame
		end
	end
	for l, cf in signs do
		local s = sign(
			m,
			Vector3.new(7 - l, 1.1, 0.3),
			cf * CFrame.new(0, -1.1, -0.2),
			BRICK_WHITE,
			DockConfig.Buildings.HQ.name
		)
		s:SetAttribute("BuildLv", l) -- with its plaque's level and layer
		s:SetAttribute("BuildY", if l == 1 then 5 else 6)
	end
	return true
end

-- HQ levels: the Rescue Hut / Post mesh at Lv1/2 (a Lego hut until it loads), today's station from Lv3, then the
-- add-ons on the station's -X side (M_Bld_HQAddons, built in the HQ spot's frame at 1x): the Lv4 walk-in radio wing
-- + lattice mast and the Lv5 beacon tower + bridge (Lv5_L05_Beacon: WorkerController's night lamp). Mesh missing: a
-- radio mast at Lv4 and the gold beacon at Lv5.
local function hq(m: Model, b: CFrame, level: number?)
	local n = level or 1
	if n >= 3 then
		station(m, b)
	elseif not hqMesh(m, b, n) then
		hut(m, b, "HQ")
	end
	local S = b * DockConfig.Buildings.HQ.spot
	if n < 4 or addonMesh(m, S, n, "M_Bld_HQAddons", "HQMesh") then
		return
	end
	part(m, "RadioMast", Vector3.new(1, 26, 1), S * CFrame.new(18, 13, 10), GREY, M.SmoothPlastic)
	part(
		m,
		"RadioDish",
		Vector3.new(0.4, 6, 6),
		S * CFrame.new(18, 25, 10),
		BRICK_WHITE,
		M.SmoothPlastic
	)
	if n >= 5 then
		local lens = part(
			m,
			"GoldBeacon",
			Vector3.new(2.4, 2.4, 2.4),
			S * CFrame.new(-18, 22, 10),
			GOLD,
			M.Neon,
			Enum.PartType.Ball
		)
		local glow = Instance.new("PointLight")
		glow.Color = GOLD
		glow.Range = 40
		glow.Brightness = 2
		glow.Parent = lens
	end
end

-- Bunkhouse Lv1-5 (docs/25 B, J): the walk-in M_Bld_Bunkhouse (hut, floors, loft + hammocks, wing, roof terrace), a
-- Lego cottage until it loads. Kept 1x: authored at its real size (its Lv4 wing overhangs the lot by ~9 on +X).
local function bunkhouse(m: Model, b: CFrame, level: number?)
	local mesh =
		levelMesh(m, b * DockConfig.Buildings.Bunkhouse.spot, "M_Bld_Bunkhouse", level or 1)
	if mesh then
		mesh.Name = "BunkhouseMesh"
	else
		hut(m, b, "Bunkhouse")
	end
end

-- Boathouse Lv2 adds the lifeboat slip on its own harbour lot (kept 1x while the boathouse scales).
local function boathouseLevel(m: Model, b: CFrame, level: number?)
	boathouse(m, b)
	if (level or 1) >= 2 then
		local slip = Instance.new("Model")
		slip.Name = "LifeboatSlip"
		lifeboatSlip(slip, b)
		slip.Parent = m
	end
end

-- Air Station: the hangar and its helipad, both on the air field. Lv2 refuel pad + bowser apron on the hangar's -X side,
-- Lv3 patrol hut in front of it (M_Bld_AirStationAddons, mesh x -63..-19, z -30..21: clear of the plinth and the +X
-- helipad, so no Lv1 piece gives way). Mesh missing: today's look.
local function airStation(m: Model, b: CFrame, level: number?)
	hangar(m, b)
	helipad(m, b)
	addonMesh(m, b * AIR, level or 1, "M_Bld_AirStationAddons", "AirStationMesh")
end

-- The Depot (docs/25 B, D): the uploaded M_Bld_Depot (DockPieces.meshes, set by the server; a hut until it loads),
-- its Lv1..n layers on the lot and its FreightQuay on the plate's west edge at sea level (the export has the quay
-- beside the body, which here would stand the barge on land). Its marks (ATT_*) sit on one invisible part, Marks,
-- in world place; ATT_QuayLoad (deck by the barge) and ATT_QuayLand (plate top at the quay's land end) are ours.
-- Both stay 1x (the mesh is authored at the lot's size).
local DEPOT_SHIFT = CFrame.new(-6, 0, 0) -- the body is authored 6 off the lot centre (its quay was beside it)
local QUAY_AT = Vector2.new(-173, 2) -- island (right, fwd) of the quay centre: past the beach step
local QUAY_X = -18 -- the quay's centre in the export
local function depot(m: Model, b: CFrame, level: number?)
	local src = DockPieces.meshes and DockPieces.meshes("M_Bld_Depot")
	if not src then
		hut(m, b, "Depot")
		return
	end
	local n = level or 1
	local at = b * DockConfig.Buildings.Depot.spot * DEPOT_SHIFT
	local quay = isle(b, QUAY_AT.X, QUAY_AT.Y) * CFrame.new(-QUAY_X, -TOP, 0)
	local root = src:GetPivot()
	local body, pier = Instance.new("Model"), Instance.new("Model")
	body.Name, pier.Name = "DepotMesh", "FreightQuay"
	local marks = part(body, "Marks", Vector3.one, at, WHITE, M.SmoothPlastic)
	marks.Transparency = 1
	marks.CanCollide, marks.CanQuery, marks.CanTouch, marks.CastShadow = false, false, false, false
	local function mark(name: string, world: CFrame)
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = at:ToObjectSpace(world)
		a.Parent = marks
	end
	for _, d in src:GetDescendants() do
		if d:IsA("Attachment") and string.sub(d.Name, 1, 4) == "ATT_" then
			local rel = root:ToObjectSpace(d.WorldCFrame)
			local lv = tonumber(string.match(d.Name, "_Lv(%d)$"))
				or (if d.Name == "ATT_ConveyorEnd" then 3 else 1)
			if d.Name == "ATT_BargeMoor" then
				mark(d.Name, quay * rel)
			elseif lv <= n then
				mark(d.Name, at * rel)
			end
		end
	end
	mark("ATT_QuayLoad", quay * CFrame.new(QUAY_X - 3, 2.2, 0)) -- 3 in from the sea face, on the deck (2.2)
	mark("ATT_QuayLand", quay * CFrame.new(QUAY_X + 15, TOP, 0)) -- on the plate, 2 in from its edge
	for _, d in src:GetChildren() do
		if d:IsA("BasePart") then
			for _, a in d:GetChildren() do
				if a:IsA("Attachment") then
					a:Destroy()
				end
			end
			local rel = root:ToObjectSpace(d.CFrame)
			local lv = tonumber(string.match(d.Name, "^Lv(%d)_"))
			if string.sub(d.Name, 1, 11) == "FreightQuay" then
				d.CFrame = quay * rel
				d.Parent = pier
			elseif lv and lv <= n then
				d.CFrame = at * rel
				d.Parent = body
			end
		end
	end
	src:Destroy()
	pier:SetAttribute("SiteApart", true) -- ConstructionController: not inside the site's fence
	body.Parent, pier.Parent = m, m
end

local BUILDINGS = {
	HQ = hq,
	Depot = depot,
	Bunkhouse = bunkhouse,
	Harbour = harbour,
	Workshop = workshopYard,
	FishShed = fishMarket,
	BoatYard = boatYard,
	RescueBoathouse = rescueBoathouse,
	Clinic = clinic,
	Boathouse = boathouseLevel,
	LookoutTower = lookout,
	TrophyHall = trophyHall,
	AirStation = airStation,
	SubPen = subPen,
	Lighthouse = lighthouse,
} :: { [string]: (Model, CFrame, number?) -> () }

local KEEP_1X = {
	DepotMesh = true,
	WorkshopMesh = true,
	FishMarketMesh = true,
	ClinicMesh = true,
	LookoutMesh = true,
	BoatYardMesh = true,
	RescueBoathouseMesh = true,
	BunkhouseMesh = true,
	FreightQuay = true,
	Path = true,
	Slipway = true,
	SlipRail = true,
	BoardSlot = true,
	PaintBooth = true,
	LifeboatSlip = true,
}
local AFLOAT = { Harbour = true } -- no lot bed: on the water

-- The pieces of building `key` (DockConfig.Buildings, Blueprints) around the berth frame `cf`, as a Model
-- named `key`. A worker building with no builder of its own is a plain Lego hut.
function DockPieces.building(key: string, cf: CFrame, level: number?): Model
	local m = Instance.new("Model")
	m.Name = key
	local fn = BUILDINGS[key]
	if fn then
		fn(m, cf, level)
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
		if #m:GetChildren() > 0 then -- all kept 1x (the Depot's meshes): nothing to scale
			m:ScaleTo(def.scale)
		end
		for _, d in keep do
			d.Parent = m
		end
	end
	local spec = HUTS[key]
	if def and spec and spec.tree and not m:GetAttribute("NoTree") then -- a tree at the back corner (1x, like the plate's trees)
		tree(
			m,
			cf * def.spot * CFrame.new(spec.tree * (def.size.X / 2 + 3), 0, def.size.Y / 2 + 1),
			0.8
		)
	end
	if def and def.spot and def.size and not AFLOAT[key] and key ~= "HQ" then -- the HQ fronts the plaza
		path(m, cf, DockPieces.stub(def.spot, def.size), 0.1)
	end
	if def and def.spot and def.size and not AFLOAT[key] then
		-- WP-25 r7: a darker green bed under the lot (2 studs round it, under the paths): a framed plot, not lawn
		local bed = brick(
			m,
			"LotBed",
			Vector3.new(def.size.X + 4, 0.26, def.size.Y + 4),
			cf
				* def.spot
				* CFrame.new(
					0,
					0.13 - ((table.find(DockConfig.BUILDINGS, key) or 0) % 8) * 0.005,
					0
				), -- overlapping beds: never coplanar
			Color3.fromRGB(75, 151, 75)
		)
		bed.CanCollide, bed.CanQuery = false, false
		studTop(bed)
	end
	return m
end

-- WP-25 r4: owner-colour tile bands across the quay walks (both promenades, both cove walks): one clear carrier part
-- per walk with a SurfaceGui of band frames (few parts). Returns the frames; DockService colours them with the flag.
local QUAY_WALKS = { -- DockPieces.STREETS' quay legs; DockService lays them with the streets
	{ V(-152, 22), V(-44, 22) },
	{ V(44, 22), V(152, 22) },
	{ V(-52, 22), V(-52, 148) },
	{ V(52, 22), V(52, 148) },
}
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

-- The trophy hall's contents (docs/23 d.2, docs/25 B) around the berth CFrame b: a gold cup per name in `cups`
-- (rescue milestones), the first `plinths` of them 1.5x on the add-on mesh's ATT_Plinth_NN (8 at Lv2, 14 at Lv3, 0
-- when the mesh is not shown) and the rest on the shelf, and a plaque per island stamp above the shelf. A Model
-- "Trophies" (not parented).
function DockPieces.trophies(
	b: CFrame,
	cups: { string },
	plaques: { { name: string, colour: Color3 } },
	plinths: number?
): Model
	local m = Instance.new("Model")
	m.Name = "Trophies"
	local hall = b * HALL
	local onPlinths = math.min(plinths or 0, #cups)
	for i, name in cups do
		local at, label, k
		if i <= onPlinths then
			local p: Vector3 =
				AssetIds.Attachments.M_Bld_TrophyHallAddons[string.format("ATT_Plinth_%02d", i)]
			at, k = hall * CFrame.new(p), 1.5
			-- on the pedestal's red front plaque (the Lv3 gallery pedestals are 0.86x)
			label = hall * CFrame.new(p + Vector3.new(0, -1.92, if i > 8 then -1.57 else -1.8))
		else
			at, k = hall * CFrame.new(-9 + (i - onPlinths - 1) * 2.25, 2.8, -0.7), 1
			label = at * CFrame.new(0, -0.2, -0.72)
		end
		part(
			m,
			"CupBase",
			Vector3.new(0.9, 0.4, 0.9) * k,
			at * CFrame.new(0, 0.15 * k, 0),
			DARK,
			M.SmoothPlastic
		)
		part(
			m,
			"CupStem",
			Vector3.new(0.7, 0.3, 0.3) * k,
			at * CFrame.new(0, 0.7 * k, 0) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		part(
			m,
			"Cup",
			Vector3.new(1.1, 1.1, 1.1) * k,
			at * CFrame.new(0, 1.45 * k, 0),
			GOLD,
			M.SmoothPlastic,
			Enum.PartType.Ball
		)
		plate(m, "CupName", Vector3.new(if k > 1 then 1.8 else 2, 0.5, 0.05), label, NAVY, name)
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
