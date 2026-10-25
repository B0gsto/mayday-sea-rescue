--!strict
-- launch (docs/16 K1): get aboard your craft. With no boat of your own the free jet ski is put at your
-- bay (RequestVehicle, docked), outlined so it reads from the quay; the step ends once you sit at its
-- helm (walk onto the seat, or its Board prompt from BoatController). No panel and no marker of its own:
-- the strip and the world pin point at your craft (MapController's goal, docs/20). The bays' other
-- prompts go quiet meanwhile: one thing to press. The server times it (elapsed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local World = require(script.Parent.PIW.World)

local Launch = {}

Launch.RETRY = 3 -- s between requests for the free jet ski (cooldown, busy bay)

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
	s.panel.Visible = false -- the strip says it (docs/20 change 9: one "Go", not two)
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
	-- the boatyard upgrade stands and the berths' Launch prompts go quiet while the craft is the next step
	local bays: { Instance } = {}
	local marina = Workspace:FindFirstChild("Marina")
	if marina then
		for _, d in marina:GetDescendants() do
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
	local glow = Ui.add(s.bag, Instance.new("Highlight"))
	glow.FillColor = Color3.fromRGB(255, 140, 40)
	glow.FillTransparency = 0.7
	glow.OutlineColor = Color3.fromRGB(255, 200, 80)
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
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
	end)
	return Step.cleanup(s)
end

return Launch
