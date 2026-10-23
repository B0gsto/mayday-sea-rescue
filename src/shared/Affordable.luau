--!strict
-- Affordable: the cheapest thing the player can buy with Cash right now (docs/16 B5/B6, K9): an
-- unowned vehicle they have the rank for, or an upgrade on a vehicle they own. The phone's red dot
-- and the Vehicles app's pulsing card read it. Pure and Lune-tested (tests/Affordable.spec.luau).
--   Affordable.cheapest(snapshot, passOwned) -> Pick?   snapshot: a PlayerDataChanged snapshot;
--                                                        passOwned(vehicleId): its vehicle pass is owned
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)
local Rules = require(script.Parent.ProgressionRules)
local VehicleUpgrades = require(script.Parent.VehicleUpgrades)

export type Pick = {
	key: string, -- "RIB" or "JetSki/Engine": stable while this exact item is the pick
	vehicleId: string,
	upgradeId: string?, -- nil: buy the vehicle itself
	price: number,
}

local Affordable = {}

function Affordable.cheapest(
	snapshot: { [string]: any },
	passOwned: (vehicleId: string) -> boolean
): Pick?
	local d = Rules.fromSnapshot(snapshot)
	local best: Pick? = nil
	local function offer(vehicleId: string, upgradeId: string?, price: number)
		if price > 0 and (best == nil or price < best.price) then
			local key = if upgradeId then `{vehicleId}/{upgradeId}` else vehicleId
			best = { key = key, vehicleId = vehicleId, upgradeId = upgradeId, price = price }
		end
	end
	-- upgrades first, in fitting order: on a price tie the boat you already ride wins
	for _, vehicleId in VehicleUpgrades.VehicleOrder do
		local pass = passOwned(vehicleId)
		local owned = Rules.ownsVehicle(d, vehicleId, pass)
		local mask = VehicleUpgrades.mask(d.vehicleUpgrades[vehicleId])
		for _, upgrade in VehicleUpgrades.Vehicles[vehicleId] do
			local ok = VehicleUpgrades.canBuy(
				vehicleId,
				upgrade.id,
				mask,
				d.cash,
				Rules.rankIndex(d),
				owned
			)
			if ok then
				offer(vehicleId, upgrade.id, upgrade.price)
			end
		end
	end
	local ids = {}
	for vehicleId in ProgressionConfig.Vehicles do
		table.insert(ids, vehicleId)
	end
	table.sort(ids) -- pairs order is not stable
	for _, vehicleId in ids do
		local ok, _, price = Rules.canBuyVehicle(d, vehicleId, passOwned(vehicleId))
		if ok then
			offer(vehicleId, nil, price)
		end
	end
	return best
end

return Affordable
