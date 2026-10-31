--!strict
-- PrizeWheelController: the in-world prize wheel (docs/24 D, owner 2026-10-26: the spin happens in the
-- game, not in a UI). DockService places a tagged PrizeWheel on every island; Spin_Wheel animates that
-- island's rotor on every client, ticks the flapper per peg, then pops a Lego capsule and the prize
-- above the wheel. Legendary / Mythic keep the server's Spin_Flex banner + confetti.
-- Paid token buttons are hidden per player when the catalogue (policy / ready) does not offer them.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local PrizeWheel = require(Shared:WaitForChild("PrizeWheel"))
local SpinRules = require(Shared:WaitForChild("SpinRules"))
local WheelMath = require(Shared:WaitForChild("WheelMath"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = UI:WaitForChild("Kit")
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))
local Toast = require(Kit:WaitForChild("Toast"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local M = Enum.Material

local PrizeWheelController = {}
PrizeWheelController.Priority = 72

local wheels: { [number]: Model } = {}
local basePivot: { [number]: CFrame } = {}
local offeredProducts: { [string]: boolean } = {}
local spinning: { [number]: boolean } = {}
local fxCanvas: Frame? = nil

local function rarityColor(rarity: string): Color3
	local row = SpinRules.RARITIES[rarity]
	return if row then Theme.Grad[row.color].top else Color3.fromRGB(160, 168, 180)
end

local function canvas(): Frame
	local old = fxCanvas
	if old and old.Parent then
		return old
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PrizeWheelFx"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 42
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	fxCanvas = Style.canvas(gui)
	return fxCanvas :: Frame
end

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = Workspace
	return p
end

-- docs/26: the win burst, its rarity's colour, sized by rarity (Common 0.4 .. Mythic 1); over the wheel a Legendary
-- or Mythic gets the FX1 jackpot (rays, a pillar, coins; the camera punch only for the spinner)
local function burst(at: Vector3, rarity: string, spinner: number?)
	local scale = 0.4 + 0.12 * math.max(SpinRules.rank(rarity) - 1, 0)
	local jackpot = spinner ~= nil and SpinRules.rank(rarity) >= SpinRules.rank("Legendary")
	VFXKit.play(
		if jackpot then "fx1_wheel_jackpot" else "wheel_win",
		CFrame.new(at),
		{ color = rarityColor(rarity), scale = scale, still = spinner ~= player.UserId }
	)
end

local function confetti(userId: number, rarity: string)
	local winner = Players:GetPlayerByUserId(userId)
	local character = winner and winner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		burst(root.Position + Vector3.new(0, 7, 0), rarity)
	end
end

local VARIANT: { [string]: { color: Color3, material: Enum.Material } } = {
	Golden = { color = Color3.fromRGB(255, 198, 64), material = M.Metal },
	Neon = { color = Color3.fromRGB(70, 255, 220), material = M.Neon },
	Rainbow = { color = Color3.fromRGB(255, 90, 190), material = M.Neon },
	Galaxy = { color = Color3.fromRGB(46, 32, 84), material = M.SmoothPlastic },
}

local FINISH: { [string]: { color: Color3, material: Enum.Material } } = {
	SpinGold = { color = Color3.fromRGB(255, 198, 64), material = M.Metal },
	SpinNeon = { color = Color3.fromRGB(70, 255, 220), material = M.Neon },
	SpinRainbow = { color = Color3.fromRGB(255, 90, 190), material = M.Neon },
	SpinLava = { color = Color3.fromRGB(255, 92, 30), material = M.Neon },
	SpinStars = { color = Color3.fromRGB(255, 238, 150), material = M.Neon },
	SpinFire = { color = Color3.fromRGB(255, 120, 20), material = M.Neon },
	SpinGalaxy = { color = Color3.fromRGB(120, 80, 220), material = M.Neon },
}

-- the prize that floats above the wheel: a pet shape, a spinning finish boat / swatch, a boat or coins
local function prizeAt(payload: any, at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "WheelPrize"
	local kind = payload.kind
	local main: Part
	if kind == "petVariant" then
		local style = VARIANT[payload.variant] or VARIANT.Golden
		main = part("Pet", Vector3.new(2.6, 2.6, 3), CFrame.new(at), style.color, style.material)
		main.Shape = Enum.PartType.Ball
		main.Parent = model
		local head = part(
			"Head",
			Vector3.new(1.8, 1.8, 1.8),
			CFrame.new(at + Vector3.new(0, 1.6, -1.1)),
			style.color,
			style.material
		)
		head.Shape = Enum.PartType.Ball
		head.Parent = model
		for _, x in { -0.7, 0.7 } do
			local ear = part(
				"Ear",
				Vector3.new(0.5, 0.9, 0.5),
				CFrame.new(at + Vector3.new(x, 2.6, -1.1)),
				style.color,
				style.material
			)
			ear.Parent = model
		end
	elseif kind == "finish" or kind == "trail" then
		local style = FINISH[payload.option] or FINISH.SpinGold
		if kind == "trail" then
			main = part(
				"Swatch",
				Vector3.new(0.5, 4, 4),
				CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
				style.color,
				style.material,
				Enum.PartType.Cylinder
			)
		else
			main = part(
				"Hull",
				Vector3.new(4.4, 1.2, 2.2),
				CFrame.new(at),
				style.color,
				style.material
			)
			part(
				"Cabin",
				Vector3.new(1.8, 1.3, 1.4),
				CFrame.new(at + Vector3.new(-0.5, 1.2, 0)),
				style.color,
				style.material
			).Parent =
				model
		end
		main.Parent = model
	elseif kind == "boat" then
		main = part("Hull", Vector3.new(4.6, 1.3, 2.3), CFrame.new(at), Color3.fromRGB(70, 78, 88))
		part(
			"Stripe",
			Vector3.new(4.7, 0.35, 2.4),
			CFrame.new(at + Vector3.new(0, 0.35, 0)),
			Color3.fromRGB(224, 56, 40)
		).Parent =
			model
		part(
			"Cabin",
			Vector3.new(1.8, 1.4, 1.5),
			CFrame.new(at + Vector3.new(-0.6, 1.3, 0)),
			Color3.fromRGB(242, 240, 232)
		).Parent =
			model
		main.Parent = model
	else
		main =
			part("Coin", Vector3.new(0.5, 2.4, 2.4), CFrame.new(at), Color3.fromRGB(255, 208, 80))
		main.Shape = Enum.PartType.Cylinder
		main.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
		main.Parent = model
		for i = 1, 2 do
			part(
				"Coin",
				Vector3.new(0.4, 2.2, 2.2),
				CFrame.new(at + Vector3.new(0.5 * i, 0.7 * i, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(255, 208, 80)
			).Parent =
				model
		end
	end
	model.PrimaryPart = model.PrimaryPart or main

	local gui = Instance.new("BillboardGui")
	gui.Name = "PrizeName"
	gui.Size = UDim2.fromOffset(240, 76)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.Parent = main
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rarityColor(payload.rarity)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Text = payload.name or "Prize"
	label.Parent = gui
	return model
end

local function reveal(payload: any, rotor: Model)
	local at = rotor:GetPivot().Position
	local color = rarityColor(payload.rarity)
	local start = at + Vector3.new(0, 3.5, 0)
	local finish = at + Vector3.new(0, 8.5, 0)

	local capsule = Instance.new("Model")
	capsule.Name = "PrizeCapsule"
	local body =
		part("Body", Vector3.new(2.2, 2.4, 2.2), CFrame.new(start), Color3.fromRGB(242, 240, 232))
	body.Shape = Enum.PartType.Cylinder
	body.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	body.Parent = capsule
	for _, y in { -1.3, 1.3 } do
		local cap = part(
			"Cap",
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(start + Vector3.new(0, y, 0)),
			color,
			M.SmoothPlastic,
			Enum.PartType.Ball
		)
		cap.Parent = capsule
	end
	capsule.PrimaryPart = body

	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local t = math.min((os.clock() - started) / 0.32, 1)
		local p = start:Lerp(finish, 1 - (1 - t) ^ 3)
		capsule:PivotTo(CFrame.new(p))
		if t >= 1 and conn then
			conn:Disconnect()
			conn = nil
			capsule:Destroy()
			burst(finish, payload.rarity, tonumber(payload.userId) or 0)
			if tonumber(payload.userId) == player.UserId then
				player:SetAttribute("SpinRevealed", os.clock()) -- HudController lands the held Cash now
			end
			local jackpot = SpinRules.rank(payload.rarity) >= SpinRules.rank("Legendary") -- FX1 has its own pillar
			if SpinRules.rank(payload.rarity) >= SpinRules.rank("Rare") and not jackpot then
				local beam = part(
					"PrizeBeam",
					Vector3.new(1.6, 36, 1.6),
					CFrame.new(finish + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					color,
					M.Neon,
					Enum.PartType.Cylinder
				)
				beam.Transparency = 0.6
				TweenService:Create(beam, TweenInfo.new(1.8), { Transparency = 1 }):Play()
				task.delay(1.9, function()
					beam:Destroy()
				end)
			end
			local prize = prizeAt(payload, finish)
			-- the capsule pops; Rare and up add a sparkle, Epic and up the fanfare
			local rank = SpinRules.rank(payload.rarity)
			AudioController.play("Album_Sticker", finish, 1, 1.2)
			if rank >= SpinRules.rank("Epic") then
				AudioController.play("Music_CrateFanfare", finish, 1, 1)
			else
				AudioController.play("UI_Pickup", finish, 0.7, 1)
			end
			if rank >= SpinRules.rank("Rare") and not jackpot then
				AudioController.play("Album_Sparkle", finish, 1, 1)
			end
			local spinStart = os.clock()
			local spinConn: RBXScriptConnection? = nil
			spinConn = RunService.Heartbeat:Connect(function()
				local age = os.clock() - spinStart
				local bob = math.sin(age * 3) * 0.35
				prize:PivotTo(
					CFrame.new(finish + Vector3.new(0, bob, 0)) * CFrame.Angles(0, age * 1.6, 0)
				)
				if age > 3 then
					if spinConn then
						spinConn:Disconnect()
						spinConn = nil
					end
					prize:Destroy()
				end
			end)
		end
	end)
end

-- Only the island's owner can spin or buy at its wheel: others get no prompt and no click cursor.
local function mine(inst: Instance): boolean
	local wheel = inst:FindFirstAncestor("PrizeWheel") or inst
	return wheel:GetAttribute("Plot") == player:GetAttribute("DockPlot")
end

-- The odds board: your own island's shows your next spin's odds and pity, others the base odds.
local function paintOdds(wheel: Instance)
	local board = wheel:FindFirstChild("OddsBoard", true)
	if not board then
		return
	end
	local epic, legend =
		player:GetAttribute("SpinPityEpic"), player:GetAttribute("SpinPityLegendary")
	local own = mine(wheel) and type(epic) == "number" and type(legend) == "number"
	PrizeWheel.showOdds(board, if own then { epic = epic, legendary = legend } else nil)
end

local function spin(payload: any)
	if type(payload) ~= "table" or type(payload.plot) ~= "number" then
		return
	end
	local wheel = wheels[payload.plot]
	if not wheel then
		return
	end
	local rotor = wheel:FindFirstChild("Rotor", true)
	if not (rotor and rotor:IsA("Model") and rotor.PrimaryPart) then
		return
	end
	local pivotPart = rotor.PrimaryPart
	basePivot[payload.plot] = basePivot[payload.plot] or rotor:GetPivot()
	local base = basePivot[payload.plot]
	local count = #SpinRules.SEGMENTS
	local want = WheelMath.normalize(WheelMath.spinAngle(payload.segment or 1, count, 0))
	-- from the rotor's real angle: after streaming out and back it sits at the server's pose, not our last stop
	local turned = base:ToObjectSpace(rotor:GetPivot()).RightVector
	local from = math.deg(math.atan2(turned.Y, turned.X))
	local target = from + 5 * 360 + WheelMath.normalize(want - from)
	local start = tonumber(payload.startTime) or Workspace:GetServerTimeNow()
	local duration = math.max(1, tonumber(payload.duration) or 4.5)
	local flapper = wheel:FindFirstChild("Flapper", true) :: BasePart?
	local flapRest = flapper and flapper:GetPivot() -- the art flapper's pivot is its hinge
	local flapAt = -1
	local lastTicks = WheelMath.ticksFor(from, count)
	AudioController.play("Rigging_Creak", pivotPart.Position, 2.5, 1.3) -- the wheel is shoved round
	spinning[payload.plot] = true
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local t = (Workspace:GetServerTimeNow() - start) / duration
		local angle = from + WheelMath.angleAt(math.clamp(t, 0, 1), target - from, 7)
		rotor:PivotTo(base * CFrame.Angles(0, 0, math.rad(angle)))
		local ticks = WheelMath.ticksFor(angle, count)
		if ticks > lastTicks then
			lastTicks = ticks
			flapAt = os.clock()
			AudioController.play("UI_Prompt", pivotPart.Position, 0.45, 1.25 + math.random() * 0.2)
			-- docs/26: streaks fly off the rim where the flapper clicks, along the rim's travel (-X at the top)
			local at = if flapRest
				then (flapRest * CFrame.new(0, -1.6, 0)).Position -- the flapper tip, where the pegs knock it
				else (base * CFrame.new(0, 6.6, 0)).Position
			VFXKit.play(
				"wheel_spin",
				CFrame.fromMatrix(base.Position, -base.RightVector, base.UpVector)
			) -- the rim band
			VFXKit.play("wheel_chips", CFrame.fromMatrix(at, -base.RightVector, base.UpVector))
		end
		if flapper and flapRest then
			local swing = math.max(0, 1 - (os.clock() - flapAt) / 0.14)
			flapper:PivotTo(flapRest * CFrame.Angles(0, 0, math.rad(-16 * swing)))
		end
		if t >= 1 and conn then
			conn:Disconnect()
			conn = nil
			spinning[payload.plot] = nil
			paintOdds(wheel)
			rotor:PivotTo(base * CFrame.Angles(0, 0, math.rad(target)))
			if flapper and flapRest then
				flapper:PivotTo(flapRest)
			end
			reveal(payload, rotor)
		end
	end)
end

local function hidePaid(machine: Instance, index: number, hidden: boolean)
	local key = `Buy{index}`
	for _, name in { key, key .. "Base", `Price{index}` } do
		local p = machine:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			p.Transparency = if hidden then 1 else 0
			p.CanQuery = not hidden
			local gui = p:FindFirstChildOfClass("SurfaceGui")
			if gui then
				gui.Enabled = not hidden
			end
		end
	end
	local cap = machine:FindFirstChild(key, true)
	local prompt = cap and cap:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = not hidden
	end
	local click = cap and cap:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MaxActivationDistance = if hidden or not mine(machine) then 0 else 24
	end
end

local function paintPaid(wheel: Instance)
	local machine = wheel:FindFirstChild("TokenMachine", true)
	if not machine then
		return
	end
	for i, key in { "Spin1", "Spin5", "Spin15" } do
		hidePaid(machine, i, offeredProducts[key] ~= true)
	end
end

local promptRange: { [ProximityPrompt]: number } = {}

local function gate(wheel: Instance)
	local own = mine(wheel)
	for _, d in wheel:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			promptRange[d] = promptRange[d] or d.MaxActivationDistance
			d.MaxActivationDistance = if own then promptRange[d] else 0
		elseif d:IsA("ClickDetector") and d.Parent and d.Parent.Name == "SpinButton" then
			d.MaxActivationDistance = if own then 24 else 0
		end
	end
	paintPaid(wheel) -- the token machine's clicks
	paintOdds(wheel)
end

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local plot = model:GetAttribute("Plot")
	if type(plot) ~= "number" then
		return
	end
	wheels[plot] = model
	local rotor = model:FindFirstChild("Rotor", true)
	-- streaming: without its PrimaryPart the rotor's pivot is not the hub; spin() takes it later
	if rotor and rotor:IsA("Model") and rotor.PrimaryPart then
		basePivot[plot] = rotor:GetPivot()
	end
	gate(model)
	-- streaming: buttons can arrive after the model
	model.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d.Name == "PityEpic" then
			task.defer(gate, model)
		end
	end)
end

local function fetchCatalogue()
	local net = ReplicatedStorage:FindFirstChild("Net")
	local remote = net and net:FindFirstChild("Monetization_GetCatalogue")
	if not (remote and remote:IsA("RemoteFunction")) then
		return
	end
	task.spawn(function()
		local ok, entries = pcall(function()
			return (remote :: RemoteFunction):InvokeServer()
		end)
		if not (ok and type(entries) == "table") then
			return
		end
		local offered: { [string]: boolean } = {}
		for _, entry in entries do
			if
				type(entry) == "table"
				and entry.kind == "Products"
				and type(entry.key) == "string"
			then
				offered[entry.key] = true
			end
		end
		offeredProducts = offered
		for _, wheel in wheels do
			paintPaid(wheel)
		end
	end)
end

function PrizeWheelController.Init()
	Net.event("Spin_Wheel").OnClientEvent:Connect(spin)
	Net.event("Spin_Flex").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.name) ~= "string" then
			return
		end
		Toast.show(
			canvas(),
			`{payload.name} won a {string.upper(payload.rarity)} {payload.prize}!`,
			{
				icon = payload.icon,
				color = if SpinRules.RARITIES[payload.rarity]
					then SpinRules.RARITIES[payload.rarity].color
					else "yellow",
				duration = 6,
			}
		)
		confetti(payload.userId, payload.rarity)
		if tonumber(payload.userId) ~= player.UserId then -- the winner already hears the jackpot at the wheel
			AudioController.play("FX_Chime", nil, 0.6)
		end
	end)

	for _, model in CollectionService:GetTagged("PrizeWheel") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("PrizeWheel"):Connect(register)
	player:GetAttributeChangedSignal("DockPlot"):Connect(function()
		for _, wheel in wheels do
			gate(wheel)
		end
	end)
	-- the pity counters change as the spin starts: repaint after the wheel stops (no spoiler)
	local function repaintOdds()
		for plot, wheel in wheels do
			if not spinning[plot] then
				paintOdds(wheel)
			end
		end
	end
	player:GetAttributeChangedSignal("SpinPityEpic"):Connect(repaintOdds)
	player:GetAttributeChangedSignal("SpinPityLegendary"):Connect(repaintOdds)
	fetchCatalogue()
	-- the catalogue hides paid random items until the server has read the player's policy: ask again then
	player:GetAttributeChangedSignal("PolicyRead"):Connect(fetchCatalogue)
end

return PrizeWheelController
