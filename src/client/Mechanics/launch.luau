--!strict
-- launch (docs/16 K1): get aboard your craft. With no boat of your own the free jet ski is put at your
-- bay (RequestVehicle, docked), outlined with a pulsing marker so it reads from the quay; the step ends
-- once you sit at its helm (walk onto the seat, or its Board prompt from BoatController). The bays'
-- other prompts go quiet meanwhile: one thing to press. The server times it (elapsed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local OnboardingBeacon =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("OnboardingBeacon"))
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Launch = {}

Launch.RETRY = 3 -- s between requests for the free jet ski (cooldown, busy bay)

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

function Launch.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Launch")
	if Step.autoStub(s, {}) then
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
				task.wait(Launch.RETRY)
			end
		end)
	)
	-- the boatyard upgrade stands and the bays' Launch prompts go quiet while the craft is the next step
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
	-- the boat icon and how far it is (the outline on the boat says which one)
	local toBoat =
		Ui.text(s.panel, "", UDim2.fromOffset(150, 34), UDim2.new(1, -162, 0, 48), 20, true)
	toBoat.TextXAlignment = Enum.TextXAlignment.Right
	local glow = Ui.add(s.bag, Instance.new("Highlight"))
	glow.FillColor = Color3.fromRGB(255, 140, 40)
	glow.FillTransparency = 0.7
	glow.OutlineColor = Color3.fromRGB(255, 200, 80)
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	-- a pulsing marker on the boat, and an edge arrow while it is off screen (playtest 2)
	local beacon = OnboardingBeacon.start()
	Ui.add(s.bag, beacon.destroy)
	local outlined: Model? = nil
	Step.heartbeat(s, function()
		mute(Workspace:FindFirstChild("UpgradeStands")) -- rebuilt with the boat: check every frame
		for _, bay in bays do
			mute(bay)
		end
		if World.seated() then
			Ui.hands("cast_off")
			Step.finish(s, { metrics = {} })
			return
		end
		local b = World.vehicle(ctx) or ownBoat()
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
	return Step.cleanup(s)
end

return Launch
