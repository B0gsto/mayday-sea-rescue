--!strict
-- HalloweenWorld: the local dressing for the Ghost Ship event (docs/15 H7): pumpkin lanterns along
-- the quay and the station front, the spectral ferry sailing its slow loop around Calm Bay, the
-- pumpkin stall with a clock and days left, and white-sheet ghosts over the Ghost Ship casualties.
-- Built by HalloweenController only while the event is live, so it costs nothing the rest of the year.
--
-- All of it is code-built Parts (no new art); the stall prompts are local ProximityPrompts (E / X /
-- tap) and pass the item id to the server's Halloween_Buy, which checks the distance and the candy.

local Workspace = game:GetService("Workspace")

local SeasonalEvents = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("SeasonalEvents")
)

local EVENT = SeasonalEvents.Halloween

local ORANGE = Color3.fromRGB(232, 122, 32)
local STEM = Color3.fromRGB(78, 110, 52)
local FACE = Color3.fromRGB(24, 20, 18)
local WOOD = Color3.fromRGB(92, 62, 40)
local INK = Color3.fromRGB(242, 236, 218)
local PURPLE = Color3.fromRGB(46, 32, 66)
local GREEN = Color3.fromRGB(120, 255, 150)
local SPECTRAL = Color3.fromRGB(84, 220, 140)
local GHOST_WHITE = Color3.fromRGB(232, 240, 238)

export type Handlers = { buy: (itemId: string) -> () }

export type World = {
	update: (
		now: number,
		daysLeft: number,
		candy: number,
		owned: { [string]: boolean },
		ghostOp: string
	) -> (),
	destroy: () -> (),
}

local HalloweenWorld = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(parent, name, size, cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function light(parent: Instance, color: Color3, brightness: number, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
end

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	text: string,
	textSize: number,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

---------------------------------------------------------------- pumpkins

local function pumpkin(parent: Instance, at: Vector3, scale: number?): Model
	local s = scale or 1.25
	local model = Instance.new("Model")
	model.Name = "Pumpkin"
	local body = ball(
		model,
		"Body",
		Vector3.new(1.7, 1.35, 1.7) * s,
		CFrame.new(at + Vector3.new(0, 0.78 * s, 0)),
		ORANGE,
		Enum.Material.SmoothPlastic
	)
	body:SetAttribute("HalloweenPumpkin", true)
	part(
		model,
		"Stem",
		Vector3.new(0.16, 0.42, 0.16) * s,
		CFrame.new(at + Vector3.new(0, 1.65 * s, 0)),
		STEM,
		Enum.Material.Grass
	)
	-- a friendly face: two triangle-ish eyes and a small grin, toward the water (+Z)
	for side = -1, 1, 2 do
		part(
			model,
			"Eye",
			Vector3.new(0.2, 0.26, 0.08) * s,
			CFrame.new(at + Vector3.new(0.34 * side * s, 0.94 * s, 0.82 * s))
				* CFrame.Angles(0, 0, math.rad(12) * side),
			FACE,
			Enum.Material.SmoothPlastic
		)
	end
	part(
		model,
		"Mouth",
		Vector3.new(0.52, 0.1, 0.08) * s,
		CFrame.new(at + Vector3.new(0, 0.62 * s, 0.84 * s)),
		FACE,
		Enum.Material.SmoothPlastic
	)
	light(body, Color3.fromRGB(255, 168, 80), 2.2 * s, 22 * s)
	model.Parent = parent
	model.PrimaryPart = body
	return model
end

---------------------------------------------------------------- spectral ferry

local function ghostFigure(parent: Instance, cf: CFrame, scale: number?): Model
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Ghost"
	local body = part(
		model,
		"Sheet",
		Vector3.new(1.5, 2.7, 1.1) * s,
		cf * CFrame.new(0, 1.35 * s, 0),
		GHOST_WHITE,
		Enum.Material.ForceField
	)
	body.Transparency = 0.35
	ball(
		model,
		"Head",
		Vector3.new(1.1, 1.1, 1.1) * s,
		cf * CFrame.new(0, 2.75 * s, 0),
		GHOST_WHITE,
		Enum.Material.ForceField
	).Transparency =
		0.35
	for side = -1, 1, 2 do
		ball(
			model,
			"Eye",
			Vector3.new(0.16, 0.22, 0.1) * s,
			cf * CFrame.new(0.22 * side * s, 2.82 * s, -0.52 * s),
			FACE,
			Enum.Material.SmoothPlastic
		)
	end
	model.Parent = parent
	model.PrimaryPart = body
	return model
end

local function buildFerry(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "SpectralFerry"
	local hull =
		part(model, "Hull", Vector3.new(22, 5, 62), CFrame.identity, SPECTRAL, Enum.Material.Neon)
	hull.Transparency = 0.45
	local bow = part(
		model,
		"Bow",
		Vector3.new(18, 5, 10),
		CFrame.new(0, 0, -35),
		SPECTRAL,
		Enum.Material.Neon
	)
	bow.Transparency = 0.5
	local nose = part(
		model,
		"Nose",
		Vector3.new(10, 4.2, 6),
		CFrame.new(0, 0, -42),
		SPECTRAL,
		Enum.Material.Neon
	)
	nose.Transparency = 0.55
	part(
		model,
		"Waterline",
		Vector3.new(22.4, 0.5, 62.4),
		CFrame.new(0, -2.3, 0),
		Color3.fromRGB(30, 110, 70),
		Enum.Material.Neon
	).Transparency =
		0.3
	part(
		model,
		"Deck",
		Vector3.new(20, 0.5, 60),
		CFrame.new(0, 2.75, 0),
		Color3.fromRGB(38, 96, 66),
		Enum.Material.SmoothPlastic
	).Transparency =
		0.25
	local cabin = part(
		model,
		"Cabin",
		Vector3.new(14, 8, 20),
		CFrame.new(0, 6.5, 10),
		SPECTRAL,
		Enum.Material.Neon
	)
	cabin.Transparency = 0.55
	part(
		model,
		"CabinRoof",
		Vector3.new(16, 0.6, 22),
		CFrame.new(0, 10.8, 10),
		Color3.fromRGB(48, 120, 84),
		Enum.Material.Neon
	).Transparency =
		0.55
	part(
		model,
		"Funnel",
		Vector3.new(3, 8, 3),
		CFrame.new(0, 12, 17),
		Color3.fromRGB(48, 74, 58),
		Enum.Material.Metal
	).Transparency =
		0.3
	-- a tall mast and a big stern lantern make her readable from the quay
	part(
		model,
		"Mast",
		Vector3.new(0.5, 24, 0.5),
		CFrame.new(0, 14, -6),
		Color3.fromRGB(40, 70, 54),
		Enum.Material.Metal
	)
	local mastLantern = ball(
		model,
		"MastLantern",
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(0, 27, -6),
		GREEN,
		Enum.Material.Neon
	)
	light(mastLantern, GREEN, 4, 46)
	-- railings and portholes
	for side = -1, 1, 2 do
		for z = -26, 26, 4 do
			part(
				model,
				"Rail",
				Vector3.new(0.16, 3, 0.16),
				CFrame.new(10.6 * side, 4.5, z),
				Color3.fromRGB(70, 150, 100),
				Enum.Material.Neon
			)
		end
		part(
			model,
			"RailTop",
			Vector3.new(0.18, 0.18, 60),
			CFrame.new(10.6 * side, 6, 0),
			Color3.fromRGB(70, 150, 100),
			Enum.Material.Neon
		)
		for i = -2, 2 do
			ball(
				model,
				"Porthole",
				Vector3.new(0.6, 0.6, 0.6),
				CFrame.new(7.1 * side, 6.4, 10 + i * 3.4),
				GREEN,
				Enum.Material.Neon
			)
		end
	end
	for _, z in { -24, 24 } do
		local lantern = ball(
			model,
			"GhostLantern",
			Vector3.new(1.8, 1.8, 1.8),
			CFrame.new(0, 8.5, z),
			GREEN,
			Enum.Material.Neon
		)
		light(lantern, GREEN, 3, 34)
		part(
			model,
			"LanternPost",
			Vector3.new(0.2, 5.5, 0.2),
			CFrame.new(0, 5.8, z),
			Color3.fromRGB(40, 60, 48),
			Enum.Material.Metal
		)
	end
	local crew = {
		CFrame.new(-3, 3, -14),
		CFrame.new(2, 3, -5),
		CFrame.new(-1, 3, 20),
		CFrame.new(4, 3, 2),
	}
	for _, cf in crew do
		ghostFigure(model, cf, 0.8)
	end
	model.PrimaryPart = hull
	model.Parent = parent
	return model
end

---------------------------------------------------------------- stall

type ItemView = {
	id: string,
	item: Part,
	prompt: ProximityPrompt,
	light: PointLight,
}

local function buildStall(
	parent: Instance,
	handlers: Handlers
): ({ ItemView }, TextLabel, TextLabel)
	local model = Instance.new("Model")
	model.Name = "PumpkinStall"
	local base = EVENT.stallPosition
	local facing = CFrame.new(base) * CFrame.Angles(0, EVENT.stallFacing, 0)
	part(
		model,
		"Counter",
		Vector3.new(7, 3, 3.2),
		facing * CFrame.new(0, 1.5, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	part(
		model,
		"CounterTop",
		Vector3.new(7.4, 0.3, 3.6),
		facing * CFrame.new(0, 3.15, 0),
		Color3.fromRGB(120, 84, 54),
		Enum.Material.Wood
	)
	for side = -1, 1, 2 do
		part(
			model,
			"Post",
			Vector3.new(0.24, 5.4, 0.24),
			facing * CFrame.new(3.1 * side, 5.7, 1.4),
			WOOD,
			Enum.Material.Wood
		)
	end
	local roof = part(
		model,
		"Canopy",
		Vector3.new(7.8, 0.35, 4.2),
		facing * CFrame.new(0, 8.4, 0.2),
		Color3.fromRGB(70, 44, 90),
		Enum.Material.Fabric
	)
	roof.Transparency = 0.15
	local board = part(
		model,
		"Sign",
		Vector3.new(6.6, 3.1, 0.25),
		facing * CFrame.new(0, 6.3, 0.35),
		PURPLE,
		Enum.Material.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StallSign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 0.2
	gui.Parent = board
	local panel = frame(gui, "Panel", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), PURPLE)
	label(
		panel,
		"Title",
		UDim2.fromScale(0.04, 0.04),
		UDim2.fromScale(0.92, 0.26),
		"GHOST SHIP",
		34,
		INK
	)

	-- clock icon: a ring with two hands, then the days left
	local clockFrame =
		frame(panel, "Clock", UDim2.fromScale(0.08, 0.38), UDim2.fromScale(0.24, 0.5), INK)
	clockFrame.BackgroundTransparency = 1
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.86, 0.86)
	ring.BackgroundColor3 = INK
	ring.BorderSizePixel = 0
	ring.Parent = clockFrame
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.76, 0.76)
	inner.BackgroundColor3 = PURPLE
	inner.BorderSizePixel = 0
	inner.Parent = ring
	local hourHand = Instance.new("Frame")
	hourHand.Name = "Hour"
	hourHand.AnchorPoint = Vector2.new(0.5, 1)
	hourHand.Position = UDim2.fromScale(0.5, 0.5)
	hourHand.Size = UDim2.fromScale(0.08, 0.34)
	hourHand.BackgroundColor3 = INK
	hourHand.BorderSizePixel = 0
	hourHand.Rotation = 40
	hourHand.Parent = ring
	local minuteHand = Instance.new("Frame")
	minuteHand.Name = "Minute"
	minuteHand.AnchorPoint = Vector2.new(0.5, 1)
	minuteHand.Position = UDim2.fromScale(0.5, 0.5)
	minuteHand.Size = UDim2.fromScale(0.06, 0.44)
	minuteHand.BackgroundColor3 = INK
	minuteHand.BorderSizePixel = 0
	minuteHand.Rotation = 140
	minuteHand.Parent = ring
	local days = label(
		panel,
		"Days",
		UDim2.fromScale(0.33, 0.34),
		UDim2.fromScale(0.28, 0.56),
		"10",
		52,
		INK
	)
	label(
		panel,
		"DaysWord",
		UDim2.fromScale(0.33, 0.8),
		UDim2.fromScale(0.28, 0.16),
		"DAYS",
		16,
		INK
	)

	-- candy lantern balance
	local candyIcon =
		frame(panel, "Candy", UDim2.fromScale(0.66, 0.4), UDim2.fromScale(0.16, 0.3), ORANGE)
	candyIcon.BackgroundTransparency = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = candyIcon
	frame(candyIcon, "Stem", UDim2.fromScale(0.42, -0.16), UDim2.fromScale(0.16, 0.22), STEM)
	local candy = label(
		panel,
		"CandyCount",
		UDim2.fromScale(0.8, 0.38),
		UDim2.fromScale(0.18, 0.5),
		"0",
		40,
		INK
	)
	label(
		panel,
		"CandyWord",
		UDim2.fromScale(0.68, 0.8),
		UDim2.fromScale(0.3, 0.16),
		"CANDY",
		16,
		INK
	)

	-- the three wares on the counter, one world prompt each
	local views: { ItemView } = {}
	local x = -2.2
	for _, item in EVENT.items do
		local at = facing * CFrame.new(x, 3.3, 0.2)
		local ware: Part
		if item.flag == "livery" then
			ware = ball(
				model,
				`Ware_{item.id}`,
				Vector3.new(0.9, 0.9, 0.9),
				at * CFrame.new(0, 0.7, 0),
				GREEN,
				Enum.Material.Neon
			)
			part(
				model,
				`WarePost_{item.id}`,
				Vector3.new(0.12, 1.2, 0.12),
				at * CFrame.new(0, 0.25, 0),
				WOOD,
				Enum.Material.Wood
			)
		elseif item.flag == "collar" then
			ware = ball(
				model,
				`Ware_{item.id}`,
				Vector3.new(0.95, 0.32, 0.95),
				at * CFrame.new(0, 0.9, 0),
				GREEN,
				Enum.Material.Neon
			)
		else
			ware = pumpkin(model, at.Position, 0.55).PrimaryPart :: Part
		end
		local wareLight = Instance.new("PointLight")
		wareLight.Color = GREEN
		wareLight.Brightness = 0.8
		wareLight.Range = 8
		wareLight.Shadows = false
		wareLight.Parent = ware
		ware.CanQuery = true -- the prompt needs a hit target
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = `Buy{item.id}`
		prompt.ActionText = item.name
		prompt.ObjectText = "Pumpkin stall"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = ware
		prompt.Triggered:Connect(function()
			handlers.buy(item.id)
		end)
		table.insert(views, { id = item.id, item = ware, prompt = prompt, light = wareLight })
		x += 2.2
	end
	model.Parent = parent
	return views, days, candy
end

---------------------------------------------------------------- sheets over the Ghost Ship casualties

type Sheet = { root: BasePart, model: Model }

local function sheetFor(root: BasePart, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "GhostSheet"
	local body = part(
		model,
		"Sheet",
		Vector3.new(2.4, 3.4, 1.6),
		root.CFrame * CFrame.new(0, 0.9, 0),
		GHOST_WHITE,
		Enum.Material.ForceField
	)
	body.Transparency = 0.4
	for side = -1, 1, 2 do
		ball(
			model,
			"Eye",
			Vector3.new(0.22, 0.3, 0.12),
			root.CFrame * CFrame.new(0.38 * side, 1.4, -0.82),
			FACE,
			Enum.Material.SmoothPlastic
		)
	end
	model.Parent = parent
	return model
end

---------------------------------------------------------------- world

function HalloweenWorld.build(parent: Instance, handlers: Handlers): World
	local root = Instance.new("Model")
	root.Name = "HalloweenWorld"
	root.Parent = parent

	local spots: { Vector3 } = EVENT.pumpkins or {}
	for _, spot in spots do
		pumpkin(root, spot)
	end
	local ferry = buildFerry(root)
	local ferryDef = EVENT.ferry
	local stallRoot = Instance.new("Model")
	stallRoot.Name = "HalloweenStall"
	stallRoot.Parent = root
	local views, daysLabel, candyLabel = buildStall(stallRoot, handlers)
	local sheetsFolder = Instance.new("Folder")
	sheetsFolder.Name = "GhostSheets"
	sheetsFolder.Parent = root
	local sheets: { [Model]: Sheet } = {}
	local shownDays = -1
	local shownCandy = -1

	local function syncSheets(ghostOp: string)
		local props = Workspace:FindFirstChild("CallProps")
		local seen: { [Model]: boolean } = {}
		if props and ghostOp ~= "" then
			for _, child in props:GetChildren() do
				if
					child:IsA("Model")
					and child.Name == "Victim"
					and child:GetAttribute("CallId") == ghostOp
				then
					local rootPart = child:FindFirstChild("HumanoidRootPart")
					if rootPart and rootPart:IsA("BasePart") then
						seen[child] = true
						if not sheets[child] then
							sheets[child] =
								{ root = rootPart, model = sheetFor(rootPart, sheetsFolder) }
						end
					end
				end
			end
		end
		for victim, sheet in sheets do
			if not seen[victim] or not sheet.root.Parent then
				sheet.model:Destroy()
				sheets[victim] = nil
			end
		end
	end

	local function update(
		now: number,
		daysLeft: number,
		candy: number,
		owned: { [string]: boolean },
		ghostOp: string
	)
		if ferryDef then
			local angle = now * ferryDef.speed
			local pos = ferryDef.center
				+ Vector3.new(math.sin(angle), 0, math.cos(angle)) * ferryDef.radius
			local tangent = Vector3.new(math.cos(angle), 0, -math.sin(angle))
			local bob = math.sin(now * 0.7) * 0.25
			local at = Vector3.new(pos.X, 1 + bob, pos.Z)
			ferry:PivotTo(CFrame.lookAt(at, at + tangent))
		end
		if daysLeft ~= shownDays then
			shownDays = daysLeft
			daysLabel.Text = tostring(daysLeft)
		end
		if candy ~= shownCandy then
			shownCandy = candy
			candyLabel.Text = tostring(candy)
		end
		for _, view in views do
			local isOwned = owned[view.id] == true
			view.prompt.Enabled = not isOwned
			view.light.Brightness = if isOwned then 0.15 else 0.8
			if isOwned then
				view.item.Color = Color3.fromRGB(70, 120, 82)
			end
		end
		for _, sheet in sheets do
			sheet.model:PivotTo(sheet.root.CFrame * CFrame.new(0, 0.9, 0))
		end
		syncSheets(ghostOp)
	end

	local function destroy()
		root:Destroy()
	end

	return { update = update, destroy = destroy }
end

return HalloweenWorld
