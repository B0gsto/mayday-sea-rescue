--!strict
-- PrizeWheel: the physical prize wheel on every island (docs/24 D, owner 2026-10-26: no Spin UI).
-- DockService places one on each plaza beside the anchor; the client (PrizeWheelController) spins its
-- "Rotor" and ticks the flapper from Spin_Wheel. This module only builds Parts and the world labels.
--
-- The set: a 14-stud Lego wheel (12 rarity segments, rim pegs, hub), a stand with the big red SPIN
-- button and the free-spin sign, the odds board (paid random items must show odds) and the token
-- machine (1 / 5 / 15 Robux spins). Parts: wheel 11 (segments and pegs are SurfaceGui frames on the disc),
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

local RARITY_COLOR: { [string]: Color3 } = {
	Common = GREY,
	Uncommon = GREEN,
	Rare = BLUE,
	Epic = PURPLE,
	Legendary = GOLD,
	Mythic = RAINBOW,
}

local WHEEL_R = 7
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

local function buildWheel(parent: Instance, at: CFrame, onSpin: (Player) -> boolean?)
	local model = Instance.new("Model")
	model.Name = "Wheel"
	model.Parent = parent
	local centre = at * CFrame.new(0, WHEEL_Y, WHEEL_Z)
	local segCount = #SpinRules.SEGMENTS

	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	rotor.Parent = model

	-- one disc part: the 12 rarity segments and the rim pegs are frames in its SurfaceGui (Right face = the
	-- front), not 25 parts; it is the rotor's PrimaryPart, its pivot offset back to `centre`
	local disc = part(
		rotor,
		"Disc",
		Vector3.new(0.5, WHEEL_R * 2 + 0.4, WHEEL_R * 2 + 0.4),
		centre * CFrame.Angles(0, math.pi / 2, 0),
		DARK
	)
	disc.CanCollide = false
	disc.CanQuery = false
	disc.PivotOffset = CFrame.Angles(0, -math.pi / 2, 0)
	local PPS = 20
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0.6
	gui.Parent = disc
	local half = (WHEEL_R + 0.2) * PPS
	-- gui +x = the centre's -X and +y (down) = its -Y, so the 3D angle a sits at (-cos a, -sin a)
	local function polar(a: number, r: number): UDim2
		return UDim2.fromOffset(half - math.cos(a) * r * PPS, half - math.sin(a) * r * PPS)
	end
	for i, rarity in SpinRules.SEGMENTS do
		local a = math.rad((i - 1) * 360 / segCount)
		local seg = Instance.new("Frame")
		seg.Name = `Segment{i}`
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		seg.Position = polar(a, WHEEL_R / 2)
		seg.Size = UDim2.fromOffset((WHEEL_R + 0.2) * PPS, 3.5 * PPS)
		seg.Rotation = math.deg(a)
		seg.BorderSizePixel = 0
		seg.BackgroundColor3 = if rarity == "Mythic"
			then Color3.new(1, 1, 1)
			else segmentColor(rarity)
		seg.ZIndex = i
		seg.Parent = gui
		if rarity == "Mythic" then
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.85, 1)),
				ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.25, 0.85, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 0.85, 1)),
				ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.75, 0.85, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 0.85, 1)),
			})
			gradient.Parent = seg
		end
	end
	for i = 1, segCount do
		local peg = Instance.new("Frame")
		peg.Name = `Peg{i}`
		peg.AnchorPoint = Vector2.new(0.5, 0.5)
		peg.Position = polar(math.rad(i * 360 / segCount), WHEEL_R - 0.3)
		peg.Size = UDim2.fromOffset(0.8 * PPS, 0.8 * PPS)
		peg.BorderSizePixel = 0
		peg.BackgroundColor3 = WHITE
		peg.ZIndex = segCount + 1
		peg.Parent = gui
		Instance.new("UICorner", peg).CornerRadius = UDim.new(0.5, 0)
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
	rotor.PrimaryPart = disc

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
		at * CFrame.new(0, WHEEL_Y + WHEEL_R + 0.3, WHEEL_Z - 0.4),
		RED
	).CanCollide =
		false
	local flapper = Instance.new("WedgePart")
	flapper.Name = "Flapper"
	flapper.Size = Vector3.new(1.2, 2.6, 0.8)
	flapper.CFrame = at
		* CFrame.new(0, WHEEL_Y + WHEEL_R - 1.1, WHEEL_Z - 0.4)
		* CFrame.Angles(0, 0, math.pi)
	flapper.Color = WHITE
	flapper.Material = M.SmoothPlastic
	flapper.Anchored = true
	flapper.CanCollide = false
	flapper.Parent = model

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

	return {
		model = model,
		rotor = rotor,
		hub = hub,
		flapper = flapper,
		count = count,
		spin = spin,
	}
end

local function buildOdds(parent: Instance, at: CFrame)
	local model = Instance.new("Model")
	model.Name = "OddsBoard"
	model.Parent = parent
	local x = 11.5
	part(model, "Post", Vector3.new(1, 10, 1), at * CFrame.new(x, 5, 0), LBG)
	local board = part(model, "Board", Vector3.new(7, 9, 0.6), at * CFrame.new(x, 10, -0.35), WHITE)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = board
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.Parent = gui
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.FredokaOne
	header.TextScaled = true
	header.TextColor3 = INK
	header.Text = "PRIZE ODDS"
	header.Parent = gui
	for _, rarity in SpinRules.RARITY_ORDER do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundTransparency = 1
		row.Parent = gui
		local chip = Instance.new("Frame")
		chip.Size = UDim2.fromOffset(30, 30)
		chip.Position = UDim2.fromOffset(4, 3)
		chip.BackgroundColor3 = PrizeWheel.rarityColor(rarity)
		chip.BorderSizePixel = 0
		chip.Parent = row
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(42, 0)
		label.Size = UDim2.new(1, -46, 1, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = INK
		label.Text = `{rarity}  {SpinRules.RARITIES[rarity].odds}%`
		label.Parent = row
	end
	local pity = Instance.new("TextLabel")
	pity.Size = UDim2.new(1, 0, 0, 30)
	pity.BackgroundTransparency = 1
	pity.Font = Enum.Font.FredokaOne
	pity.TextScaled = true
	pity.TextColor3 = INK
	pity.Text = `Epic+ every {SpinRules.PITY_EPIC}`
	pity.Parent = gui
	return model
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
	local buttons: { [string]: any } = {}
	for i, key in { "Spin1", "Spin5", "Spin15" } do
		local item = MonetizationConfig.Products[key]
		local label = string.gsub(key, "Spin", "")
		local dx = (i - 2) * 2.1
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
		buttons[key] = made
	end
	return { model = model, buttons = buttons }
end

-- The whole set at `at` (stand foot on the plaza, -Z = the jetty). The caller sets Plot and wires
-- the buttons: `onSpin(player)` and `onBuy(player, productKey)` return false to ignore a press.
export type Handlers = {
	spin: (Player) -> boolean?,
	buy: (Player, string) -> boolean?,
}

function PrizeWheel.build(at: CFrame, handlers: Handlers): Model
	local root = Instance.new("Model")
	root.Name = "PrizeWheel"
	root.WorldPivot = at
	local wheel = buildWheel(root, at, handlers.spin)
	buildOdds(root, at)
	local machine = buildMachine(root, at, handlers.buy)
	wheel.model:SetAttribute("Wheel", true)
	machine.model:SetAttribute("Machine", true)
	return root
end

return PrizeWheel
