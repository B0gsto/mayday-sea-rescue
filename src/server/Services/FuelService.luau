--!strict
-- FuelService (docs/31 C, D4): every player's tank, in seconds of full throttle (Boat/Fuel, Fuel.step). The driver
-- burns it from the craft's speed and SeaZones.zoneAt; it fills free at home (a Go back landing, the drop-off zone, the
-- station bay: GoBack.isHome) and on respawn. An empty tank at sea limps, then rides home on its own
-- (VehicleService.FuelHome: no ram cancels it; survivors aboard pay as on any landing). One tank per player: the heli
-- and sub use the boat level's (owner). Nothing burns while anchored (a Go back ride) or during the Deep Spin.
-- HUD: player attributes Fuel, FuelMax (seconds) and FuelBurn (the zone factor here: 0 Shallows, 1, 5, 25).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatLevels = require(Shared:WaitForChild("BoatLevels"))
local Fuel = require(Shared:WaitForChild("Boat"):WaitForChild("Fuel"))
local GoBack = require(Shared:WaitForChild("Boat"):WaitForChild("GoBack"))
local SeaZones = require(Shared:WaitForChild("Calls"):WaitForChild("SeaZones"))

local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

local FuelService = {}

local TICK = 0.1 -- s
local tanks: { [Player]: number } = {} -- nil = full
local homing: { [Player]: true } = {} -- an empty tank's limp and ride are running

local function step(player: Player, dt: number)
	local level = player:GetAttribute("BoatLevel")
	local max = Fuel.tank(level)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local body = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local model = VehicleService.GetVehicle(player)
	local root = model and model.PrimaryPart
	local seat = humanoid and humanoid.SeatPart
	local driving = model ~= nil
		and root ~= nil
		and seat ~= nil
		and seat:IsDescendantOf(model)
		and VehicleService.GetDriver(model) == player
	local pos = if driving and root then root.Position elseif body then body.Position else nil
	local zone = if pos then SeaZones.zoneAt(pos) else 1
	local home = driving and model ~= nil and model:GetAttribute("LandedHome") == true
		or pos ~= nil and GoBack.isHome(pos, player:GetAttribute("BayCFrame"))
	local moving = driving
		and root ~= nil
		and not root.Anchored
		and player:GetAttribute("WheelSpinning") ~= true
	local v = if root then root.AssemblyLinearVelocity else Vector3.zero
	local fuel, empty = Fuel.step(tanks[player] or max, max, {
		home = home,
		driving = moving,
		dt = dt,
		speedFrac = Vector3.new(v.X, 0, v.Z).Magnitude / BoatLevels.row(level).speed,
		zone = zone,
		level = level,
	})
	tanks[player] = fuel
	player:SetAttribute("Fuel", math.round(fuel * 10) / 10)
	player:SetAttribute("FuelMax", max)
	player:SetAttribute("FuelBurn", Fuel.factor(zone, level))
	if empty then
		Telemetry.Custom(
			player,
			"Fuel",
			BoatLevels.level(level),
			"Empty",
			SeaZones.Zones[zone].name
		)
	end
	if fuel <= 0 and moving and not home and not homing[player] then
		homing[player] = true
		task.spawn(function()
			VehicleService.FuelHome(player) -- false (left the helm in the limp): the next tick at the helm tries again
			homing[player] = nil
		end)
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function()
		tanks[player] = nil -- a respawn fills the tank
	end)
end

function FuelService.Init()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		tanks[player] = nil
		homing[player] = nil
	end)
end

function FuelService.Start()
	while true do
		local dt = task.wait(TICK)
		for _, player in Players:GetPlayers() do
			xpcall(step, function(err)
				warn("[FuelService]", err)
			end, player, dt)
		end
	end
end

return FuelService
