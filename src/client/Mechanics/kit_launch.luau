--!strict
-- kit_launch (docs 09 step 2, Kit and launch; also the "launch" mechanic: the same step, no kit): the station rack holds the kit this tasking needs
-- as colour-coded bags (code-built greybox; oxygen and the strop never go on a jet ski). Grab a
-- bag (E / tap / X, a ProximityPrompt) and it is packed: its tile on the step panel fills and
-- ticks. After 20 s with nothing packed the crew packs the rest. With no boat of your own the free
-- jet ski is put at your bay (RequestVehicle, docked), outlined so it reads from the quay; the step
-- ends only once you sit at its helm (walk onto the seat, or its Board prompt from BoatController).
-- Metric: kitFit = share of the needed bags the player packed; the server times it (elapsed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Medical = require(script.Parent.PIW.Medical)
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local OnboardingBeacon =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("OnboardingBeacon"))
local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local KitLaunch = {}

KitLaunch.IDLE = 20 -- s without a pack before the crew packs the rest
KitLaunch.RETRY = 3 -- s between requests for the free jet ski (cooldown, busy bay)

-- colour by kind: rescue gear orange, flotation yellow, thermal blue, first aid green, oxygen white
local COLOURS: { [string]: Color3 } = {
	throwbag = Color3.fromRGB(235, 120, 30),
	tube = Color3.fromRGB(235, 120, 30),
	strop = Color3.fromRGB(235, 120, 30),
	lifejacket = Color3.fromRGB(250, 200, 40),
	casualtyBag = Color3.fromRGB(40, 90, 200),
	firstAid = Color3.fromRGB(40, 160, 70),
	oxygen = Color3.fromRGB(240, 240, 240),
}
local ICONS: { [string]: string } = {
	throwbag = "🎒",
	tube = "⭕",
	strop = "➰",
	lifejacket = "🦺",
	casualtyBag = "🧣",
	firstAid = "💊",
	oxygen = "💨",
}

local function block(size: Vector3, colour: Color3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = colour
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function rootPart(): BasePart?
	local char = Players.LocalPlayer.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- The player's own craft in Workspace.Vehicles (VehicleService sets Owner = UserId).
local function ownBoat(): Model?
	local folder = Workspace:FindFirstChild("Vehicles")
	for _, m in if folder then folder:GetChildren() else {} do
		if m:IsA("Model") and m:GetAttribute("Owner") == Players.LocalPlayer.UserId then
			return m
		end
	end
	return nil
end

function KitLaunch.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "KitLaunch")
	local boat: Model? = World.vehicle(ctx) or ownBoat()
	-- no boat yet: the free jet ski is coming, so pack for a jet ski
	local jet = boat == nil or World.isJetSki(boat)
	local profile = Record.profile(ctx)
	-- the "launch" mechanic (PersonInWater since 2026-10-21) is this step without the kit
	local needed: { string } = if ctx.step.mechanicId == "launch"
		then {}
		else Medical.kitNeeded(profile.state, profile.lifejacket, jet)
	if Step.autoStub(s, { kitFit = 1 }) then
		return Step.cleanup(s)
	end
	-- the free jet ski at your bay whenever you have no craft (also if it goes mid-step)
	Ui.add(
		s.bag,
		task.spawn(function()
			while not s.finished do
				if World.vehicle(ctx) == nil and ownBoat() == nil then
					pcall(function()
						Net.func("RequestVehicle"):InvokeServer("JetSki", true)
					end)
				end
				task.wait(KitLaunch.RETRY)
			end
		end)
	)
	-- one thing to press at the bay: the boatyard upgrade stands beside Bay 1 (they rebuild the boat)
	-- and the bays' Launch RIB / Lifeboat prompts go quiet while the jet ski is the next step
	local bays: { Instance } = {}
	local map = Workspace:FindFirstChild("Map")
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("LaunchBay") then
				table.insert(bays, d)
			end
		end
	end
	local muted: { [ProximityPrompt]: boolean } = {}
	Ui.add(s.bag, function()
		for p in muted do
			p.Enabled = true
		end
	end)
	local function mute(container: Instance?)
		if not container then
			return
		end
		for _, d in container:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Enabled then
				d.Enabled = false
				muted[d] = true
			end
		end
	end
	Step.heartbeat(s, function()
		mute(Workspace:FindFirstChild("UpgradeStands")) -- rebuilt with the boat: check every frame
		for _, bay in bays do
			mute(bay)
		end
	end)
	local root = rootPart()
	local origin = if root then root.CFrame else CFrame.new(World.casualtyPos(ctx, nil))
	local folder = Ui.add(s.bag, Instance.new("Folder"))
	folder.Name = "KitRack"
	folder.Parent = Workspace
	-- the rack: a grey shelf just ahead of the player
	local rack = origin * CFrame.new(0, -1.5, -6)
	block(Vector3.new(#needed * 2.4 + 1, 0.4, 2), Color3.fromRGB(110, 110, 115), rack, folder)

	-- one tile per bag on the panel: dim until packed, then filled in its colour with a tick
	local tiles: { TextLabel } = {}
	for i, id in needed do
		local t = Ui.text(
			s.panel,
			ICONS[id] or "🎒",
			UDim2.fromOffset(34, 34),
			UDim2.fromOffset(12 + (i - 1) * 40, 48),
			20
		)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.BackgroundTransparency = 0.8
		t.BackgroundColor3 = COLOURS[id] or Color3.fromRGB(150, 150, 150)
		t.TextTransparency = 0.5
		Ui.Theme.corner(t, 8)
		tiles[i] = t
	end
	-- after packing: the boat icon and how far it is (the outline on the boat says which one)
	local toBoat =
		Ui.text(s.panel, "", UDim2.fromOffset(150, 34), UDim2.new(1, -162, 0, 48), 20, true)
	toBoat.TextXAlignment = Enum.TextXAlignment.Right

	local bags: { Part } = {}
	local packed: { [number]: boolean } = {}
	local mine, loaded = 0, 0
	local last = os.clock()
	local launched = false
	local lastGrab = 0

	local function myBoat(): Model?
		local b = boat
		if b and b.Parent then
			return b
		end
		boat = World.vehicle(ctx) or ownBoat()
		return boat
	end

	local function launch()
		launched = true
		local kit = {}
		for _, id in needed do
			kit[id] = true
		end
		Record.get(ctx.operation.id).kit = kit
		local fit = if #needed > 0 then mine / #needed else 1
		fit = math.floor(fit * 100 + 0.5) / 100
		local outlined: Model? = nil
		local glow = Ui.add(s.bag, Instance.new("Highlight"))
		glow.FillColor = Color3.fromRGB(255, 140, 40)
		glow.FillTransparency = 0.7
		glow.OutlineColor = Color3.fromRGB(255, 200, 80)
		glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		-- a pulsing marker on the boat, and an edge arrow while it is off screen (playtest 2)
		local beacon = OnboardingBeacon.start()
		Ui.add(s.bag, beacon.destroy)
		Step.heartbeat(s, function()
			local b = myBoat()
			if World.seated() then
				Ui.hands("cast_off")
				Step.finish(s, { metrics = { kitFit = fit } })
				return
			end
			if b ~= outlined then
				outlined = b
				glow.Adornee = b
				glow.Parent = b
			end
			if b then
				beacon.show(b:GetPivot().Position, "Call")
			else
				beacon.hide()
			end
			local r = rootPart()
			toBoat.Text = if b and r
				then `🚤 {math.floor(
					Units.flatDistance(r.Position, b:GetPivot().Position) / Units.STUDS_PER_M + 0.5
				)} m`
				else "🚤"
		end)
	end

	local function pack(i: number, byPlayer: boolean)
		if packed[i] then
			return
		end
		packed[i] = true
		loaded += 1
		mine += if byPlayer then 1 else 0
		last = os.clock()
		local bag = bags[i]
		local prompt = bag:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:Destroy()
		end
		if byPlayer then
			Ui.hands("stow_kit")
		end
		-- into the player's kit: the bag flies to them and shrinks away
		local r = rootPart()
		local to = if r then r.Position else bag.Position
		local tween = TweenService:Create(
			bag,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(to), Size = bag.Size * 0.2 }
		)
		tween.Completed:Once(function()
			bag:Destroy()
		end)
		tween:Play()
		local tile = tiles[i]
		tile.BackgroundTransparency = 0
		tile.TextTransparency = 0
		tile.Text = `{tile.Text}✓`
		if loaded >= #needed and not launched then
			launch()
		end
	end

	for i, id in needed do
		local bag = block(
			Vector3.new(1.8, 1.4, 1.2),
			COLOURS[id] or Color3.fromRGB(150, 150, 150),
			rack * CFrame.new((i - (#needed + 1) / 2) * 2.4, 0.9, 0),
			folder
		)
		bag.Name = id
		local prompt = Instance.new("ProximityPrompt") -- E / tap / gamepad X
		prompt.ActionText = "Grab"
		local item = Medical.Kit[1]
		for _, k in Medical.Kit do
			if k.id == id then
				item = k
			end
		end
		prompt.ObjectText = item.label
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = bag
		prompt.Triggered:Connect(function()
			-- one press, one bag: the next bag's prompt must not take the same press
			if os.clock() - lastGrab > 0.3 then
				lastGrab = os.clock()
				pack(i, true)
			end
		end)
		bags[i] = bag
	end
	if #needed == 0 then
		launch()
	end

	Step.heartbeat(s, function()
		if launched or os.clock() - last <= KitLaunch.IDLE then
			return
		end
		-- the crew packs the rest, one bag at a time
		last = math.huge
		s.say("Crew: kit aboard", 3)
		local delay = 0
		for i in needed do
			if not packed[i] then
				Ui.add(s.bag, task.delay(delay, pack, i, false))
				delay += 0.4
			end
		end
	end)
	return Step.cleanup(s)
end

return KitLaunch
