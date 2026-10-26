--!strict
-- BeaconController: the lifeboat's blue masthead beacon. The Builder leaves it dark (dark blue
-- glass, PointLight off); this controller flashes it on the server clock only while the local
-- player is on a call and the boat is theirs (owner or seated). Off otherwise. It reads the op
-- state, so there is no server or remote involved: player attribute OpsActiveOp (normal calls),
-- the boat's ColdOpenOpId (the cold open's call) or the last Ops_State from OpsController.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OpsController = require(script.Parent:WaitForChild("OpsController"))

local BeaconController = {}
BeaconController.Priority = 118

local localPlayer = Players.LocalPlayer
local DIM = Color3.fromRGB(24, 42, 72)
local PERIOD = 1.2

type Boat = { model: Model, beacons: { BasePart }, lit: boolean? }
local boats: { [Model]: Boat } = {}
local scanAt = 0

-- double flash: 0.20 s on, 0.14 s off, 0.20 s on, then dark for the rest of the period
local function litAt(now: number): boolean
	local phase = now % PERIOD
	return phase < 0.2 or (phase >= 0.34 and phase < 0.54)
end

local function beaconOn(model: Model): boolean
	if model:GetAttribute("ColdOpenOpId") ~= nil then
		return true
	end
	return OpsController.GetState() ~= nil
end

local function ownedByPlayer(model: Model): boolean
	if model:GetAttribute("Owner") == localPlayer.UserId then
		return true
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat:IsDescendantOf(model)
end

local function setLit(boat: Boat, on: boolean)
	if boat.lit == on then
		return
	end
	boat.lit = on
	for _, part in boat.beacons do
		part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = if on
			then (part:GetAttribute("BeaconColor") :: Color3?) or Color3.fromRGB(40, 110, 255)
			else DIM
		part.Transparency = if on then 0 else 0.08
		local light = part:FindFirstChild("BeaconLight")
		if light and light:IsA("PointLight") then
			light.Enabled = on
		end
	end
end

local function watch(model: Model)
	if boats[model] or model:GetAttribute("VehicleId") ~= "Lifeboat" then
		return
	end
	local beacons = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("LifeboatBeacon") == true then
			table.insert(beacons, d)
		end
	end
	boats[model] = { model = model, beacons = beacons, lit = nil }
end

local function scan()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		for _, d in vehicles:GetChildren() do
			if d:IsA("Model") then
				watch(d)
			end
		end
	end
	for _, d in Workspace:GetChildren() do
		if d:IsA("Model") then
			watch(d)
		end
	end
	for model in boats do
		if not model.Parent then
			boats[model] = nil
		end
	end
end

function BeaconController.Init()
	scan()
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			watch(d)
		end
	end)
end

function BeaconController.Start()
	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		if now >= scanAt then
			scanAt = now + 2
			scan()
		end
		for _, boat in boats do
			local on = ownedByPlayer(boat.model) and beaconOn(boat.model) and litAt(now)
			setLit(boat, on)
		end
	end)
end

return BeaconController
