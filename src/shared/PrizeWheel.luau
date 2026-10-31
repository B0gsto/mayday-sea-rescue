--!strict
-- PrizeWheel: the physical prize wheel on every island (docs/24 D, owner 2026-10-26: no Spin UI).
-- DockService places one on each plaza beside the anchor; the client (PrizeWheelController) spins its
-- "Rotor" and ticks the flapper from Spin_Wheel. This module only builds Parts and the world labels.
--
-- The set: a 14-stud Lego wheel (12 rarity segments, rim pegs, hub), a stand with the big red SPIN
-- button and the free-spin sign, the odds board (paid random items must show odds) and the token
-- machine (1 / 5 / 15 Robux spins). Parts: wheel 23 (rim, 12 wedge segments, hub; pegs are rim SurfaceGui frames),
-- odds board 2, token machine 13.
local MonetizationConfig =
	require(script.Parent:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local PushButton = require(script.Parent:WaitForChild("PushButton"))
local SpinRules = require(script.Parent:WaitForChild("SpinRules"))

local M = Enum.Material

local GREY = Color3.fromRGB(150, 152, 160)
local GREEN = Color3.fromRGB(80, 190, 90)
local BLUE = Color3.fromRGB(40, 110, 220)
local PURPLE = Color3.fromRGB(150, 80, 210)
local GOLD = Color3.fromRGB(250, 200, 60)
local RAINBOW = Color3.fromRGB(255, 80, 190)
local RED = Color3.fromRGB(224, 56, 40)
local WHITE = Color3.fromRGB(242, 240, 232)
local DARK = Color3.fromRGB(60, 64, 70)
local LBG = Color3.fromRGB(163, 162, 165)
local INK = Color3.fromRGB(30, 44, 66)
local SUB = Color3.fromRGB(92, 98, 110) -- small print that still reads on the white board

local RARITY_COLOR: { [string]: Color3 } = {
	Common = GREY,
	Uncommon = GREEN,
	Rare = BLUE,
	Epic = PURPLE,
	Legendary = GOLD,
	Mythic = RAINBOW,
}

local WHEEL_R = 7
local SEG_R = 5.6 -- segment radius: the saw-tooth tips (SEG_R / cos 30°) stay inside the rim pegs
local WHEEL_Y = 10
local WHEEL_Z = -3.6

local PrizeWheel = {}

function PrizeWheel.rarityColor(rarity: string): Color3
	return RARITY_COLOR[rarity] or GREY
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local STUDS = "rbxassetid://18878365966"

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

-- a flat world label on the front (-Z) face of a part
local function faceLabel(p: BasePart, text: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or WHITE
	label.Text = text
	label.Parent = gui
	return label
end

local function segmentColor(rarity: string): Color3
	if rarity == "Common" then
		return GREY
	elseif rarity == "Uncommon" then
		return GREEN
	elseif rarity == "Rare" then
		return BLUE
	elseif rarity == "Epic" then
		return PURPLE
	elseif rarity == "Legendary" then
		return GOLD
	end
	return RAINBOW
end

-- The old code-built wheel (Parts): the stand-in until M_Prop_PrizeWheel loads. Returns the hub and the flapper.
local function codeParts(
	model: Model,
	rotor: Model,
	at: CFrame,
	centre: CFrame
): (BasePart, BasePart)
	local segCount = #SpinRules.SEGMENTS

	-- the round rim: one cylinder facing -Z, the rotor's PrimaryPart (pivot offset back to `centre`); its
	-- SurfaceGui (Right face = the front) carries the white pegs outside the segments' saw-tooth tips
	local rim = part(
		rotor,
		"Rim",
		Vector3.new(0.4, WHEEL_R * 2 + 0.4, WHEEL_R * 2 + 0.4),
		centre * CFrame.Angles(0, math.pi / 2, 0),
		INK, -- dark: the gold Legendary segment and the saw-tooth read against it
		nil,
		Enum.PartType.Cylinder
	)
	rim.CanCollide = false
	rim.CanQuery = false
	rim.PivotOffset = CFrame.Angles(0, -math.pi / 2, 0)
	local PPS = 20
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0.6
	gui.Parent = rim
	local half = (WHEEL_R + 0.2) * PPS
	-- gui +x = the centre's -X and +y (down) = its -Y, so the 3D angle a sits at (-cos a, -sin a)
	local function polar(a: number, r: number): UDim2
		return UDim2.fromOffset(half - math.cos(a) * r * PPS, half - math.sin(a) * r * PPS)
	end
	for i = 1, segCount do
		local peg = Instance.new("Frame")
		peg.Name = `Peg{i}`
		peg.AnchorPoint = Vector2.new(0.5, 0.5)
		peg.Position = polar(math.rad((i - 0.5) * 360 / segCount), WHEEL_R - 0.3)
		peg.Size = UDim2.fromOffset(0.5 * PPS, 0.5 * PPS)
		peg.BorderSizePixel = 0
		peg.BackgroundColor3 = WHITE
		peg.Parent = gui
		Instance.new("UICorner", peg).CornerRadius = UDim.new(0.5, 0)
	end

	-- 12 segments, one WedgePart each (WheelMath: segment i centred at (i-1)*30° CCW from +X in the
	-- centre's XY). The wedge's right angle sits at the slice's start radius r, one leg back to the hub,
	-- the other square to it up to the slice's end edge: slices tile, the tips make a small saw-tooth.
	local step = 2 * math.pi / segCount
	local r = SEG_R
	local tooth = r * math.tan(step)
	for i, rarity in SpinRules.SEGMENTS do
		local start = (i - 1.5) * step
		local u = Vector3.new(math.cos(start), math.sin(start), 0) -- the start radius (wedge +Z)
		local t = Vector3.new(-math.sin(start), math.cos(start), 0) -- square to it (wedge +Y)
		local corner = u * r
		local seg = Instance.new("WedgePart")
		seg.Name = `Segment{i}`
		seg.Size = Vector3.new(0.4, tooth, r)
		seg.CFrame = centre
			* CFrame.fromMatrix(
				corner + t * (tooth / 2) - u * (r / 2) + Vector3.new(0, 0, -0.35),
				Vector3.new(0, 0, -1),
				t
			)
		seg.Color = segmentColor(rarity)
		seg.Material = if rarity == "Mythic" then M.Neon else M.SmoothPlastic
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.Parent = rotor
	end

	local hub = part(
		rotor,
		"Hub",
		Vector3.new(0.9, 3.2, 3.2),
		centre * CFrame.new(0, 0, -0.5) * CFrame.Angles(0, math.pi / 2, 0),
		GOLD,
		M.Neon,
		Enum.PartType.Cylinder
	)
	hub.CanCollide = false
	hub.CanQuery = false
	rotor.PrimaryPart = rim

	-- stand ---------------------------------------------------------------------------------------
	local base = part(model, "Base", Vector3.new(16, 1.2, 6), at * CFrame.new(0, 0.6, 0), RED)
	studTop(base)
	for _, x in { -WHEEL_R + 0.2, WHEEL_R - 0.2 } do
		local post = part(
			model,
			"Post",
			Vector3.new(1.5, WHEEL_Y + 1.4, 1.5),
			at * CFrame.new(x, (WHEEL_Y + 1.4) / 2, WHEEL_Z + 1.1),
			WHITE
		)
		post.CanCollide = false
	end
	part(
		model,
		"PointerArm",
		Vector3.new(1.4, 1.4, 3.4),
		at * CFrame.new(0, WHEEL_Y + WHEEL_R + 0.9, WHEEL_Z + 0.6),
		WHITE
	).CanCollide =
		false
	part(
		model,
		"PointerHousing",
		Vector3.new(1.8, 1.5, 1.2),
		at * CFrame.new(0, WHEEL_Y + WHEEL_R + 0.3, WHEEL_Z - 1.0),
		RED
	).CanCollide =
		false
	local flapper = Instance.new("WedgePart")
	flapper.Name = "Flapper"
	flapper.Size = Vector3.new(1.2, 2.6, 0.8)
	flapper.CFrame = at
		* CFrame.new(0, WHEEL_Y + WHEEL_R - 1.1, WHEEL_Z - 0.95) -- in front of the segments
		* CFrame.Angles(0, 0, math.pi)
	flapper.Color = WHITE
	flapper.Material = M.SmoothPlastic
	flapper.Anchored = true
	flapper.CanCollide = false
	flapper.Parent = model

	return hub, flapper
end

local function artPart(art: Model, prefix: string): BasePart?
	for _, d in art:GetChildren() do
		if d:IsA("BasePart") and string.find(d.Name, `^{prefix}`) then
			return d
		end
	end
	return nil
end

-- M_Prop_PrizeWheel (Blender, origin = `at`, hub = WHEEL_Y / WHEEL_Z): the Rotor keeps its PrimaryPart pivoted on the
-- hub, the Flapper pivots on its hinge (art/source/props/M_Prop_PrizeWheel/build.py HINGE), the base plate is the collider.
local HINGE = Vector3.new(0, 17.9, -4.82)

local function meshParts(
	model: Model,
	rotor: Model,
	at: CFrame,
	centre: CFrame,
	art: Model
): (BasePart?, BasePart?)
	local stand, rot, flap =
		artPart(art, "L01_Stand"), artPart(art, "L02_Rotor"), artPart(art, "L03_Flapper")
	if not (stand and rot and flap) then
		return nil, nil
	end
	art:PivotTo(at)
	rot.PivotOffset = rot.CFrame:ToObjectSpace(centre)
	flap.PivotOffset = flap.CFrame:ToObjectSpace(at * CFrame.new(HINGE))
	for _, p in { stand, rot, flap } do
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	rot.Parent = rotor
	rotor.PrimaryPart = rot
	stand.Name = "Stand"
	stand.Parent = model
	flap.Name = "Flapper"
	flap.Parent = model
	local hull = artPart(art, "Col01_COL")
	if hull then
		hull.Parent = model
	end
	art:Destroy()
	return rot, flap
end

local function buildWheel(parent: Instance, at: CFrame, onSpin: (Player) -> boolean?, art: Model?)
	local model = Instance.new("Model")
	model.Name = "Wheel"
	model.Parent = parent
	local centre = at * CFrame.new(0, WHEEL_Y, WHEEL_Z)

	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	rotor.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- streams whole, so it spins whole
	rotor.Parent = model

	local hub: BasePart?, flapper: BasePart?
	if art then
		hub, flapper = meshParts(model, rotor, at, centre, art)
	end
	if not (hub and flapper) then
		hub, flapper = codeParts(model, rotor, at, centre)
	end

	local sign = part(
		model,
		"FreeSign",
		Vector3.new(4.4, 1.9, 0.3),
		at * CFrame.new(-4.6, 2.1, -3.05),
		WHITE
	)
	sign.CanCollide = false
	local count = faceLabel(sign, "SPINS 0", INK)
	count.Name = "FreeCount"

	local spin = PushButton.build(model, "SpinButton", at * CFrame.new(4.6, 2.1, -3.05), {
		text = "SPIN",
		objectText = "",
		color = RED,
		width = 2.8,
		onPress = onSpin,
	})
	spin.prompt.HoldDuration = 0 -- a tap spins (the only E prompt at the wheel)

	return {
		model = model,
		rotor = rotor,
		hub = hub,
		flapper = flapper,
		count = count,
		spin = spin,
	}
end

local function boardText(
	parent: Instance,
	name: string,
	height: number,
	x: number,
	color: Color3,
	align: Enum.TextXAlignment?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(x, 0)
	label.Size = UDim2.new(1, -x - 4, 0, height)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.TextColor3 = color
	label.Parent = parent
	return label
end

-- Fills the odds board from SpinRules.nextOdds: `pity` = the viewer's own counters (next-spin odds
-- and spins left to each guarantee), nil = the base odds and the guarantee rule.
function PrizeWheel.showOdds(board: Instance, pity: SpinRules.Pity?)
	local odds = SpinRules.nextOdds(pity)
	for _, rarity in SpinRules.RARITY_ORDER do
		local row = board:FindFirstChild(`Row{rarity}`, true)
		if row then
			local each = odds[rarity] / math.max(1, #SpinRules.prizesOf(rarity :: SpinRules.Rarity))
			local main = row:FindFirstChild("Odds") :: TextLabel
			local sub = row:FindFirstChild("Each") :: TextLabel
			main.Text = `{rarity}  {SpinRules.percent(odds[rarity])}%`
			sub.Text = `each {SpinRules.percent(each)}%`
		end
	end
	local epic = board:FindFirstChild("PityEpic", true) :: TextLabel?
	local legend = board:FindFirstChild("PityLegendary", true) :: TextLabel?
	if epic and legend then
		if pity then
			epic.Text = `Epic+ in {math.max(1, SpinRules.PITY_EPIC - pity.epic)}`
			legend.Text = `Legendary+ in {math.max(1, SpinRules.PITY_LEGENDARY - pity.legendary)}`
		else
			epic.Text = `Epic+ every {SpinRules.PITY_EPIC}`
			legend.Text = `Legendary+ every {SpinRules.PITY_LEGENDARY}`
		end
	end
end

local function buildOdds(parent: Instance, at: CFrame)
	local model = Instance.new("Model")
	model.Name = "OddsBoard"
	model.Parent = parent
	local x = 11.5
	part(model, "Post", Vector3.new(1, 10, 1), at * CFrame.new(x, 5, 0), LBG)
	local board =
		part(model, "Board", Vector3.new(7, 10.5, 0.6), at * CFrame.new(x, 10.75, -0.35), WHITE)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = board
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 1)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local function line(name: string, height: number, color: Color3, order: number): TextLabel
		local label = boardText(gui, name, height, 0, color)
		label.Size = UDim2.new(1, 0, 0, height)
		label.LayoutOrder = order
		return label
	end
	line("Header", 32, INK, 0).Text = "PRIZE ODDS"
	for i, rarity in SpinRules.RARITY_ORDER do
		local row = Instance.new("Frame")
		row.Name = `Row{rarity}`
		row.Size = UDim2.new(1, 0, 0, 46)
		row.BackgroundTransparency = 1
		row.LayoutOrder = i
		row.Parent = gui
		local chip = Instance.new("Frame")
		chip.Size = UDim2.fromOffset(26, 26)
		chip.Position = UDim2.fromOffset(8, 1)
		chip.BackgroundColor3 = PrizeWheel.rarityColor(rarity)
		chip.BorderSizePixel = 0
		chip.Parent = row
		boardText(row, "Odds", 28, 42, INK, Enum.TextXAlignment.Left)
		local each = boardText(row, "Each", 18, 42, SUB, Enum.TextXAlignment.Left)
		each.Position = UDim2.fromOffset(42, 28)
	end
	line("PityEpic", 24, PURPLE, 10)
	line("PityLegendary", 24, Color3.fromRGB(200, 150, 20), 11)
	line("Owned", 22, INK, 12).Text = "Owned → Cash"
	line("Rounded", 16, SUB, 13).Text = "% rounded"
	PrizeWheel.showOdds(model, nil)
	return model
end

-- The machine's screen: the base odds as six rarity chips, readable where the R$ buttons are.
local function screenOdds(screen: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Odds"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = screen
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -8, 1, -8)
	panel.BackgroundColor3 = INK
	panel.BorderSizePixel = 0
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
	local title = boardText(panel, "Title", 20, 0, WHITE)
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Text = "ODDS"
	local odds = SpinRules.nextOdds(nil)
	for i, rarity in SpinRules.RARITY_ORDER do
		local chip = Instance.new("Frame")
		chip.Name = rarity
		chip.Position = UDim2.new(((i - 1) % 3) / 3, 3, 0, 22 + math.floor((i - 1) / 3) * 27)
		chip.Size = UDim2.new(1 / 3, -6, 0, 25)
		chip.BackgroundColor3 = PrizeWheel.rarityColor(rarity)
		chip.BorderSizePixel = 0
		chip.Parent = panel
		Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 5)
		local text = boardText(chip, "Text", 25, 0, WHITE)
		text.Size = UDim2.fromScale(1, 1)
		text.Text = `{SpinRules.percent(odds[rarity])}%`
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 1.5
		stroke.Parent = text
	end
end

local function buildMachine(parent: Instance, at: CFrame, onBuy: (Player, string) -> boolean?)
	local model = Instance.new("Model")
	model.Name = "TokenMachine"
	model.Parent = parent
	local x = -11.5
	local frame = at * CFrame.new(x, 0, 0)
	local base = part(model, "Base", Vector3.new(6.6, 1, 5), frame * CFrame.new(0, 0.5, 0), DARK)
	studTop(base)
	part(model, "Body", Vector3.new(6, 7, 3.6), frame * CFrame.new(0, 4.5, 0), RED)
	local top =
		part(model, "Sign", Vector3.new(5.2, 1.5, 0.3), frame * CFrame.new(0, 8.4, -1.95), WHITE)
	top.CanCollide = false
	faceLabel(top, "SPINS", INK)
	local screen = part(
		model,
		"Screen",
		Vector3.new(4.6, 2.1, 0.2),
		frame * CFrame.new(0, 6.4, -1.9),
		Color3.fromRGB(60, 220, 255),
		M.Neon
	)
	screen.CanCollide = false
	screenOdds(screen)
	local buttons: { [string]: any } = {}
	for i, key in { "Spin1", "Spin5", "Spin15" } do
		local item = MonetizationConfig.Products[key]
		local label = string.gsub(key, "Spin", "")
		local dx = (i - 2) * 2.05 -- the outer buttons 0.05 inside the body's sides (no shared plane)
		local plate = part(
			model,
			`Price{i}`,
			Vector3.new(1.9, 0.9, 0.2),
			frame * CFrame.new(dx, 2.9, -1.95),
			WHITE
		)
		plate.CanCollide = false
		local price = faceLabel(plate, `R$ {if item then item.price else 0}`, INK)
		price.Name = "Text"
		plate:SetAttribute("Product", key)
		local made = PushButton.build(model, `Buy{i}`, frame * CFrame.new(dx, 4.5, -1.85), {
			text = label,
			objectText = `R$ {if item then item.price else 0}`,
			color = if i == 1 then BLUE elseif i == 2 then GREEN else GOLD,
			width = 1.8,
			onPress = function(player: Player)
				return if onBuy then onBuy(player, key) else false
			end,
		})
		made.cap:SetAttribute("Product", key)
		-- R and close range: the paid buttons never take the SPIN button's E
		made.prompt.KeyboardKeyCode = Enum.KeyCode.R
		made.prompt.MaxActivationDistance = 8
		-- the nearest cap's prompt billboard covers all three caps: a clickable one took every click / tap (a hold
		-- that never completed); not clickable, clicks and taps reach the cap's own ClickDetector
		made.prompt.ClickablePrompt = false
		buttons[key] = made
	end
	return { model = model, buttons = buttons }
end

-- The whole set at `at` (stand foot on the plaza, -Z = the jetty). The caller sets Plot and wires
-- the buttons: `onSpin(player)` and `onBuy(player, productKey)` return false to ignore a press. `art` is the
-- M_Prop_PrizeWheel mesh clone (nil: the code-built Parts).
export type Handlers = {
	spin: (Player) -> boolean?,
	buy: (Player, string) -> boolean?,
}

function PrizeWheel.build(at: CFrame, handlers: Handlers, art: Model?): Model
	local root = Instance.new("Model")
	root.Name = "PrizeWheel"
	root.WorldPivot = at
	local wheel = buildWheel(root, at, handlers.spin, art)
	buildOdds(root, at)
	local machine = buildMachine(root, at, handlers.buy)
	wheel.model:SetAttribute("Wheel", true)
	machine.model:SetAttribute("Machine", true)
	return root
end

return PrizeWheel
