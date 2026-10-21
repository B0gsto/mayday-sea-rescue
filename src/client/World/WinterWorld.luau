--!strict
-- WinterWorld: the local dressing for the Frost Fleet event (docs/15 H7): snowfall, frosted town
-- roofs, string lights along the quay and the station front, a decorated tree, the snowflake stall
-- with its clock and days left, and the Frost Fleet scene (lit boats iced in, ice floes with a
-- hold-to-break world prompt). Built by WinterController only while the event is live, so it costs
-- nothing the rest of the year.
--
-- All of it is code-built Parts (no new art); the stall prompts are local ProximityPrompts (E / X /
-- tap, hold) and pass the item id to the server's Winter_Buy, which checks the distance and the
-- snowflakes. The ice floes are local too: breaking one only clears the local barrier, the rescue
-- itself stays on the server's big-call flow.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SeasonalEvents = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("SeasonalEvents")
)

local EVENT = SeasonalEvents.Winter
type LightRun = SeasonalEvents.LightRun

local WOOD = Color3.fromRGB(92, 62, 40)
local INK = Color3.fromRGB(242, 236, 218)
local ICE = Color3.fromRGB(198, 228, 242)
local ICE_BLUE = Color3.fromRGB(150, 198, 222)
local DEEP_BLUE = Color3.fromRGB(34, 58, 78)
local SNOW = Color3.fromRGB(244, 248, 250)
local PINE = Color3.fromRGB(38, 82, 54)
local WARM = Color3.fromRGB(255, 218, 142)
local RED = Color3.fromRGB(196, 66, 58)
local GOLD = Color3.fromRGB(226, 182, 90)
local COAL = Color3.fromRGB(38, 36, 38)
local CARROT = Color3.fromRGB(224, 120, 44)

-- 45 flakes/s spread over 220x220 studs is about one per 1000 studs^2: invisible. Keep the box
-- tight around the camera and pay for density there; the tiers and reduce-motion scale the rate.
local SNOW_RATE = { High = 150, Medium = 80, Low = 32 }
local SNOW_BOX = 90 -- studs, the spawn box following the camera
local SNOW_HEIGHT = 46 -- studs above the camera
local MAX_FROST = 240 -- roof caps; the town has fewer roofs, this only stops a runaway scan
local FLOE_PER_BOAT = 3

export type Handlers = { buy: (itemId: string) -> () }

export type World = {
	update: (
		now: number,
		daysLeft: number,
		snowflakes: number,
		owned: { [string]: boolean },
		frostOp: string
	) -> (),
	destroy: () -> (),
	setSnowRate: (tier: string, on: boolean, reduced: boolean?) -> (),
}

local WinterWorld = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
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
	return part(parent, name, size, cf, color, material, Enum.PartType.Ball)
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

---------------------------------------------------------------- snow

local function buildSnow(parent: Instance): (Part, ParticleEmitter)
	local snow = part(
		parent,
		"SnowField",
		Vector3.new(SNOW_BOX, 1, SNOW_BOX),
		CFrame.new(0, SNOW_HEIGHT, 0),
		SNOW,
		Enum.Material.Snow
	)
	snow.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Snowfall"
	emitter.Texture = "rbxasset://textures/particles/SquareParticle.png"
	emitter.Color = ColorSequence.new(SNOW)
	emitter.LightEmission = 0.1
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.26),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	emitter.Transparency = NumberSequence.new(0.1)
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Rate = SNOW_RATE.High
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Acceleration = Vector3.new(1.2, -7, 0.8) -- a light side drift
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Parent = snow
	return snow, emitter
end

---------------------------------------------------------------- frosted roofs

local function frostRoofs(parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "RoofFrost"
	folder.Parent = parent
	local placed = 0
	for _, base in { Workspace:FindFirstChild("Dressing"), Workspace:FindFirstChild("Map") } do
		if not base then
			continue
		end
		for _, d in base:GetDescendants() do
			if placed >= MAX_FROST then
				break
			end
			-- "Roof", "RoofLight", "Roof_Slate": the harbour's shells name them per asset
			if not d:IsA("BasePart") or not string.find(string.lower(d.Name), "roof") then
				continue
			end
			local cap = d:Clone()
			cap.Name = "SnowCap"
			cap.Anchored = true
			cap.CanCollide = false
			cap.CanQuery = false
			cap.CanTouch = false
			cap.CastShadow = false
			cap.Color = SNOW
			cap.Material = Enum.Material.Snow
			cap.Size = cap.Size + Vector3.new(0.14, 0.14, 0.14)
			-- keep only the shape: a cloned light, prompt, decal or texture would double up
			for _, child in cap:GetChildren() do
				if not child:IsA("DataModelMesh") then
					child:Destroy()
				end
			end
			cap.Parent = folder
			placed += 1
		end
	end
	if placed == 0 then
		folder:Destroy() -- update() retries every 2 s until roofs exist
	end
	return placed
end

---------------------------------------------------------------- string lights

local function buildLights(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "StringLights"
	folder.Parent = parent
	local palette = { WARM, RED, GOLD, Color3.fromRGB(150, 210, 236) }
	local runs: { LightRun } = EVENT.lightRuns or {}
	for _, run in runs do
		local a = run.from + Vector3.new(0, run.height or 8, 0)
		local b = run.to + Vector3.new(0, run.height or 8, 0)
		local span = b - a
		local length = span.Magnitude
		if length < 1 then
			continue
		end
		local cable = part(
			folder,
			"Cable",
			Vector3.new(0.1, 0.1, length),
			CFrame.lookAt(a + span / 2, b),
			Color3.fromRGB(48, 52, 56),
			Enum.Material.SmoothPlastic
		)
		cable.Transparency = 0.2
		local count = math.max(2, math.floor(length / (run.spacing or 20)) + 1)
		for i = 1, count do
			local at = a + span * ((i - 1) / (count - 1))
			local bulb = ball(
				folder,
				"Bulb",
				Vector3.new(0.34, 0.5, 0.34),
				CFrame.new(at - Vector3.new(0, 0.4, 0)),
				palette[(i - 1) % #palette + 1],
				Enum.Material.Neon
			)
			if i % 4 == 1 then
				light(bulb, palette[(i - 1) % #palette + 1], 1.4, 30)
			end
		end
	end
end

---------------------------------------------------------------- decorated tree

local function buildTree(parent: Instance)
	local base = EVENT.tree
	if not base then
		return
	end
	local model = Instance.new("Model")
	model.Name = "WinterTree"
	part(
		model,
		"Trunk",
		Vector3.new(1.1, 4, 1.1),
		CFrame.new(base + Vector3.new(0, 2, 0)),
		WOOD,
		Enum.Material.Wood
	)
	local tiers = { { 11, 6.5 }, { 9, 5.2 }, { 7, 3.9 }, { 5, 2.8 } }
	local y = 3.4
	local firstTier: BasePart? = nil
	for i, tier in tiers do
		local height, width = tier[1], tier[2]
		local tierPart = part(
			model,
			`Tier{i}`,
			Vector3.new(width, 1.6, width),
			CFrame.new(base + Vector3.new(0, y, 0)),
			PINE,
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		tierPart.Size = Vector3.new(width, height * 0.5, width)
		firstTier = firstTier or tierPart
		-- bulbs around each tier
		for k = 0, 5 do
			local a = (k / 6) * math.pi * 2 + i * 0.4
			ball(
				model,
				"TreeBulb",
				Vector3.new(0.3, 0.42, 0.3),
				CFrame.new(
					base
						+ Vector3.new(
							math.cos(a) * width * 0.42,
							y - height * 0.16,
							math.sin(a) * width * 0.42
						)
				),
				if k % 2 == 0 then WARM else RED,
				Enum.Material.Neon
			)
		end
		y += height * 0.45
	end
	local star = ball(
		model,
		"Star",
		Vector3.new(1.1, 1.1, 0.4),
		CFrame.new(base + Vector3.new(0, y + 0.6, 0)),
		GOLD,
		Enum.Material.Neon
	)
	light(star, GOLD, 2, 26)
	if firstTier then
		light(firstTier, WARM, 1.2, 30)
	end
	model.Parent = parent
end

---------------------------------------------------------------- stall

type ItemView = {
	id: string,
	item: BasePart,
	prompt: ProximityPrompt,
	light: PointLight,
}

local function miniSnowman(parent: Instance, at: CFrame): BasePart
	local ground = ball(
		parent,
		"SnowmanBase",
		Vector3.new(0.7, 0.7, 0.7),
		at * CFrame.new(0, 0.35, 0),
		SNOW,
		Enum.Material.Snow
	)
	ball(
		parent,
		"SnowmanHead",
		Vector3.new(0.42, 0.42, 0.42),
		at * CFrame.new(0, 0.84, 0),
		SNOW,
		Enum.Material.Snow
	)
	for _, x in { -0.1, 0.1 } do
		ball(
			parent,
			"SnowmanEye",
			Vector3.new(0.07, 0.07, 0.07),
			at * CFrame.new(x, 0.92, -0.2),
			COAL,
			Enum.Material.SmoothPlastic
		)
	end
	ball(
		parent,
		"SnowmanNose",
		Vector3.new(0.14, 0.08, 0.08),
		at * CFrame.new(0, 0.84, -0.24),
		CARROT,
		Enum.Material.SmoothPlastic
	)
	return ground
end

local function buildStall(
	parent: Instance,
	handlers: Handlers
): ({ ItemView }, TextLabel, TextLabel)
	local model = Instance.new("Model")
	model.Name = "SnowflakeStall"
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
		DEEP_BLUE,
		Enum.Material.Fabric
	)
	roof.Transparency = 0.1
	local board = part(
		model,
		"Sign",
		Vector3.new(6.6, 3.1, 0.25),
		facing * CFrame.new(0, 6.3, 0.35),
		DEEP_BLUE,
		Enum.Material.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StallSign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 0.2
	gui.Parent = board
	local panel = frame(gui, "Panel", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), DEEP_BLUE)
	label(
		panel,
		"Title",
		UDim2.fromScale(0.04, 0.04),
		UDim2.fromScale(0.92, 0.26),
		"FROST FLEET",
		32,
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
	inner.BackgroundColor3 = DEEP_BLUE
	inner.BorderSizePixel = 0
	inner.Parent = ring
	for i, angle in { 40, 140 } do
		local hand = Instance.new("Frame")
		hand.Name = `Hand{i}`
		hand.AnchorPoint = Vector2.new(0.5, 1)
		hand.Position = UDim2.fromScale(0.5, 0.5)
		hand.Size = UDim2.fromScale(0.08, 0.4)
		hand.BackgroundColor3 = INK
		hand.BorderSizePixel = 0
		hand.Rotation = angle
		hand.Parent = ring
	end
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

	-- snowflake balance: six spokes round a small hub
	local icon =
		frame(panel, "Snowflake", UDim2.fromScale(0.66, 0.4), UDim2.fromScale(0.18, 0.3), INK)
	icon.BackgroundTransparency = 1
	for i = 0, 5 do
		local spoke = Instance.new("Frame")
		spoke.Name = `Spoke{i}`
		spoke.AnchorPoint = Vector2.new(0.5, 0.5)
		spoke.Position = UDim2.fromScale(0.5, 0.5)
		spoke.Size = UDim2.fromScale(0.08, 0.9)
		spoke.BackgroundColor3 = INK
		spoke.BorderSizePixel = 0
		spoke.Rotation = i * 30
		spoke.Parent = icon
	end
	local count = label(
		panel,
		"SnowflakeCount",
		UDim2.fromScale(0.8, 0.38),
		UDim2.fromScale(0.18, 0.5),
		"0",
		40,
		INK
	)
	label(
		panel,
		"SnowflakeWord",
		UDim2.fromScale(0.65, 0.8),
		UDim2.fromScale(0.33, 0.16),
		"SNOWFLAKES",
		14,
		INK
	)

	-- the three wares on the counter, one world prompt each
	local views: { ItemView } = {}
	local x = -2.2
	for _, item in EVENT.items do
		local at = facing * CFrame.new(x, 3.3, 0.2)
		local ware: BasePart
		if item.flag == "livery" then
			ware = ball(
				model,
				`Ware_{item.id}`,
				Vector3.new(0.9, 0.9, 0.9),
				at * CFrame.new(0, 0.7, 0),
				ICE_BLUE,
				Enum.Material.Neon
			)
			for k = 0, 3 do
				local a = k * math.pi / 2
				ball(
					model,
					`WareBulb_{item.id}`,
					Vector3.new(0.18, 0.18, 0.18),
					at * CFrame.new(math.cos(a) * 0.55, 0.7, math.sin(a) * 0.55),
					WARM,
					Enum.Material.Neon
				)
			end
			part(
				model,
				`WarePost_{item.id}`,
				Vector3.new(0.12, 1.2, 0.12),
				at * CFrame.new(0, 0.25, 0),
				WOOD,
				Enum.Material.Wood
			)
		elseif item.flag == "scarf" then
			ware = ball(
				model,
				`Ware_{item.id}`,
				Vector3.new(0.95, 0.32, 0.95),
				at * CFrame.new(0, 0.9, 0),
				RED,
				Enum.Material.Fabric
			)
		else
			ware = miniSnowman(model, at)
		end
		local wareLight = Instance.new("PointLight")
		wareLight.Color = if item.flag == "scarf" then RED else WARM
		wareLight.Brightness = 0.8
		wareLight.Range = 8
		wareLight.Shadows = false
		wareLight.Parent = ware
		ware.CanQuery = true -- the prompt needs a hit target
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = `Buy{item.id}`
		prompt.ActionText = item.name
		prompt.ObjectText = "Snowflake stall"
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
	return views, days, count
end

---------------------------------------------------------------- Frost Fleet scene

type Boat = {
	victim: Model,
	model: Model,
	floes: { BasePart },
	light: PointLight,
	freed: boolean,
}

local function litBoat(parent: Instance, at: Vector3, index: number): (Model, PointLight)
	local model = Instance.new("Model")
	model.Name = `FrostBoat{index}`
	local hull = part(
		model,
		"Hull",
		Vector3.new(8, 2.6, 18),
		CFrame.new(at + Vector3.new(0, 0.4, 0)),
		Color3.fromRGB(52, 70, 86),
		Enum.Material.WoodPlanks
	)
	part(
		model,
		"Bow",
		Vector3.new(7, 2.2, 4),
		CFrame.new(at + Vector3.new(0, 0.5, -9)),
		Color3.fromRGB(58, 78, 94),
		Enum.Material.WoodPlanks
	)
	part(
		model,
		"Cabin",
		Vector3.new(5, 3.4, 6),
		CFrame.new(at + Vector3.new(0, 3.3, 2)),
		Color3.fromRGB(64, 88, 100),
		Enum.Material.SmoothPlastic
	)
	part(
		model,
		"CabinSnow",
		Vector3.new(5.4, 0.3, 6.4),
		CFrame.new(at + Vector3.new(0, 5.1, 2)),
		SNOW,
		Enum.Material.Snow
	)
	part(
		model,
		"Mast",
		Vector3.new(0.4, 12, 0.4),
		CFrame.new(at + Vector3.new(0, 7, -4)),
		WOOD,
		Enum.Material.Wood
	)
	local top = ball(
		model,
		"TopLantern",
		Vector3.new(1.1, 1.1, 1.1),
		CFrame.new(at + Vector3.new(0, 13, -4)),
		WARM,
		Enum.Material.Neon
	)
	local glow = Instance.new("PointLight")
	glow.Color = WARM
	glow.Brightness = 1.6
	glow.Range = 34
	glow.Shadows = false
	glow.Parent = top
	-- a string of bulbs down each side, the parade read from the quay
	for _, side in { -1, 1 } do
		for i = 0, 5 do
			ball(
				model,
				"Bulb",
				Vector3.new(0.3, 0.42, 0.3),
				CFrame.new(at + Vector3.new(side * 4.1, 2.4, -7 + i * 2.8)),
				if i % 2 == 0 then WARM else RED,
				Enum.Material.Neon
			)
		end
	end
	model.Parent = parent
	model.PrimaryPart = hull
	return model, glow
end

local function iceFloe(parent: Instance, at: Vector3): BasePart
	local floe = part(
		parent,
		"IceFloe",
		Vector3.new(7.5, 1.2, 7.5),
		CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.random() * 3, 0),
		ICE,
		Enum.Material.Ice,
		Enum.PartType.Ball
	)
	floe.Transparency = 0.12
	floe.Reflectance = 0.08
	floe.CanCollide = true
	floe.CanQuery = true
	floe:SetAttribute("FrostFloe", true)
	return floe
end

---------------------------------------------------------------- world

function WinterWorld.build(parent: Instance, handlers: Handlers): World
	local root = Instance.new("Model")
	root.Name = "WinterWorld"
	root.Parent = parent

	local snow, emitter = buildSnow(root)
	buildLights(root)
	buildTree(root)
	local stallRoot = Instance.new("Model")
	stallRoot.Name = "SnowflakeStall"
	stallRoot.Parent = root
	local views, daysLabel, countLabel = buildStall(stallRoot, handlers)

	local fleetFolder = Instance.new("Folder")
	fleetFolder.Name = "FrostFleet"
	fleetFolder.Parent = root
	local boats: { [Model]: Boat } = {}
	local shownDays = -1
	local shownCount = -1
	local fleetOp = ""
	local lastFleetSync = 0
	local roofsDone = false
	local nextFrostAt = 0
	local builtAt = os.clock()
	local function clearFleet()
		for _, boat in boats do
			boat.model:Destroy()
		end
		table.clear(boats)
	end

	local function freeBoat(boat: Boat)
		if boat.freed then
			return
		end
		boat.freed = true
		boat.light.Brightness = 2.4
		local start = boat.model:GetPivot().Position
		task.spawn(function()
			for i = 1, 24 do
				local model = boat.model
				if not model.Parent then
					return
				end
				local at = start + Vector3.new(0, 0.2 * math.sin(i * 0.4), 10 * i)
				model:PivotTo(CFrame.new(at) * CFrame.Angles(0, 0.05 * i, 0))
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						d.Transparency = math.min(1, d.Transparency + 0.035)
					end
				end
				task.wait(0.12)
			end
			boat.model:Destroy()
		end)
	end

	local function breakFloe(boat: Boat, floe: BasePart)
		if floe:GetAttribute("FrostBroken") then
			return
		end
		floe:SetAttribute("FrostBroken", true)
		floe.CanCollide = false
		floe.CanQuery = false
		local prompt = floe:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt:Destroy()
		end
		local tween = TweenService:Create(
			floe,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1, CFrame = floe.CFrame - Vector3.new(0, 2.4, 0) }
		)
		tween:Play()
		table.remove(boat.floes, table.find(boat.floes, floe) or 1)
		if #boat.floes == 0 then
			freeBoat(boat)
		end
	end

	local function addBoat(victim: Model, index: number)
		local rootPart = victim:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") then
			return
		end
		local centre = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
		local side = if index % 2 == 0 then 1 else -1
		local model, glow = litBoat(fleetFolder, centre + Vector3.new(15 * side, 0, -6), index)
		local boat: Boat =
			{ victim = victim, model = model, floes = {}, light = glow, freed = false }
		for k = 0, FLOE_PER_BOAT - 1 do
			local a = (k / FLOE_PER_BOAT) * math.pi * 2
			local floe =
				iceFloe(fleetFolder, centre + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9))
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BreakIce"
			prompt.ActionText = "Break"
			prompt.ObjectText = "Ice"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			prompt.HoldDuration = 1.2
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = floe
			prompt.Triggered:Connect(function()
				breakFloe(boat, floe)
			end)
			table.insert(boat.floes, floe)
		end
		boats[victim] = boat
	end

	local function syncFleet(opId: string)
		if opId ~= fleetOp then
			clearFleet()
			fleetOp = opId
		end
		if opId == "" then
			return
		end
		local props = Workspace:FindFirstChild("CallProps")
		if not props then
			return
		end
		local seen: { [Model]: boolean } = {}
		local index = 0
		for _, child in props:GetChildren() do
			if
				child:IsA("Model")
				and child.Name == "Victim"
				and child:GetAttribute("CallId") == opId
			then
				index += 1
				seen[child] = true
				if not boats[child] then
					addBoat(child, index)
				end
			end
		end
		for victim, boat in boats do
			if not seen[victim] or not boat.victim.Parent then
				boat.model:Destroy()
				boats[victim] = nil
			end
		end
	end

	local function update(
		now: number,
		daysLeft: number,
		snowflakes: number,
		owned: { [string]: boolean },
		frostOp: string
	)
		if daysLeft ~= shownDays then
			shownDays = daysLeft
			daysLabel.Text = tostring(daysLeft)
		end
		if snowflakes ~= shownCount then
			shownCount = snowflakes
			countLabel.Text = tostring(snowflakes)
		end
		for _, view in views do
			local isOwned = owned[view.id] == true
			view.prompt.Enabled = not isOwned
			view.light.Brightness = if isOwned then 0.15 else 0.8
			if isOwned then
				view.item.Color = Color3.fromRGB(70, 120, 132)
			end
		end
		-- frost the harbour once its dressing has swapped in (the greyboxes it replaces go away);
		-- retry if that pass found nothing yet, so a late dressing is still frosted
		if not roofsDone and os.clock() >= nextFrostAt then
			local dressing = Workspace:FindFirstChild("Dressing")
			local ready = (dressing ~= nil and dressing:GetAttribute("DressingReady") == true)
				or os.clock() - builtAt > 20
			if ready then
				nextFrostAt = os.clock() + 2
				roofsDone = frostRoofs(root) > 0 or os.clock() - builtAt > 40
			end
		end
		-- snow follows the camera; the controller sets the rate by tier and reduce-motion
		local camera = Workspace.CurrentCamera
		if camera then
			snow.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, SNOW_HEIGHT, 0))
		end
		if now - lastFleetSync >= 1 then
			lastFleetSync = now
			syncFleet(frostOp)
		end
	end

	local function destroy()
		root:Destroy()
	end

	local function setSnowRate(tier: string, on: boolean, reduced: boolean?)
		local rate = if on then SNOW_RATE[tier] or SNOW_RATE.High else 0
		emitter.Rate = if reduced then rate * 0.4 else rate
	end

	return { update = update, destroy = destroy, setSnowRate = setSnowRate }
end

return WinterWorld
