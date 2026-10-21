--!strict
-- UpgradeService: fits boatyard upgrades to a player's boats (docs 03 section 4.1).
-- Bought from the phone's Vehicles app (VehiclesApp, from anywhere); this service owns the pure rules'
-- checks (owned vehicle, fit order, rank gate, Cash) and the persistence.
-- Fitted levels live in data.vehicleUpgrades[vehicleId] as a VehicleUpgrades bitmask.
-- Remote (ReplicatedStorage.Net, created here): Upgrade_Buy C->S function (vehicleId, upgradeId) -> ok, reason.
-- Studio: ServerStorage.UpgradeDev:Invoke("buy", vehicleId, upgradeId) fits one from anywhere.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local VehicleUpgrades = require(Shared:WaitForChild("VehicleUpgrades"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local VehicleService = require(script.Parent.VehicleService)

local UpgradeService = {}
UpgradeService.Priority = 93

local COOLDOWN = 0.4

local lastUse: { [Player]: number } = {}

local function fit(player: Player, vehicleId: string, upgradeId: string): (boolean, string)
	if type(vehicleId) ~= "string" or type(upgradeId) ~= "string" then
		return false, "Bad request"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local mask = VehicleUpgrades.mask(data.vehicleUpgrades[vehicleId])
	local ok, reason, price = VehicleUpgrades.canBuy(
		vehicleId,
		upgradeId,
		mask,
		data.cash,
		ProgressionRules.rankIndex(data),
		ProgressionRules.ownsVehicle(
			data,
			vehicleId,
			ProgressionService.OwnsVehiclePass(player, vehicleId)
		)
	)
	if not ok then
		return false, reason
	end
	data.cash -= price
	data.vehicleUpgrades[vehicleId] = mask + VehicleUpgrades.bit(upgradeId)
	DataService.MarkDirty(player)
	ProgressionService.Refresh(player, { upgrade = { vehicleId = vehicleId, id = upgradeId } })
	VehicleService.RefreshUpgrades(player, vehicleId)
	task.spawn(DataService.Save, player, false)
	return true, "ok"
end

local function remote(): RemoteFunction
	local folder = Net.init()
	local existing = folder:FindFirstChild("Upgrade_Buy")
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = "Upgrade_Buy"
	created.Parent = folder
	return created
end

function UpgradeService.Init()
	remote().OnServerInvoke = function(
		player: Player,
		vehicleId: any,
		upgradeId: any
	): (boolean, string)
		local now = os.clock()
		if lastUse[player] and now - lastUse[player] < COOLDOWN then
			return false, "Too fast"
		end
		lastUse[player] = now
		if type(vehicleId) ~= "string" or type(upgradeId) ~= "string" then
			return false, "Bad request"
		end
		return fit(player, vehicleId, upgradeId)
	end
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "UpgradeDev"
		dev.OnInvoke = function(cmd: string, vehicleId: any, upgradeId: any): any
			local player = game:GetService("Players"):GetPlayers()[1]
			if not player then
				return nil
			end
			if cmd == "buy" then
				return fit(player, tostring(vehicleId), tostring(upgradeId))
			elseif cmd == "reset" then
				local data = DataService.Get(player)
				if data then
					data.vehicleUpgrades = {}
					DataService.MarkDirty(player)
					ProgressionService.Refresh(player)
				end
			end
			return ProgressionService.GetData(player)
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

return UpgradeService
