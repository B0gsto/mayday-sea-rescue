--!strict
-- VehicleUpgrades: the boatyard's per-vehicle upgrades (docs 03 section 4.1). Pure data and maths,
-- Lune-tested (tests/VehicleUpgrades.spec.luau). Each vehicle has three levels:
--   1 Tuned engine  -- +8% top speed
--   2 Storm hull    -- steadier in waves, turns better
--   3 Fit-out       -- +1 casualty seat plus a tow post / searchlight / rescue seat
-- Prices are a share of the vehicle's price (25 / 50 / 100%); the free jet ski uses fixed prices.
-- Owned upgrades persist as a bitmask per vehicle in data.vehicleUpgrades (ProgressionRules).
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)

export type Upgrade = {
	id: string,
	name: string, -- 1-3 words on the stand tag and the next-goal chip
	price: number,
	rankIndex: number,
	effect: string, -- short line on the tag
}

local VehicleUpgrades = {}

VehicleUpgrades.VehicleOrder = { "JetSki", "RIB", "Lifeboat" }
VehicleUpgrades.UpgradeOrder = { "Engine", "Hull", "Fit" }
VehicleUpgrades.MAX_MASK = 7 -- three bits
VehicleUpgrades.SHORT = { JetSki = "Jet ski", RIB = "RIB", Lifeboat = "Lifeboat" }

local FIT = {
	JetSki = { name = "Rescue seat", effect = "+1 casualty seat" },
	RIB = { name = "Tow post", effect = "+1 casualty seat" },
	Lifeboat = { name = "Searchlight", effect = "+1 casualty seat" },
}

local BASE = {
	{ id = "Engine", name = "Tuned engine", share = 0.25, fixed = 300, effect = "+8% top speed" },
	{ id = "Hull", name = "Storm hull", share = 0.5, fixed = 800, effect = "Steady in waves" },
	{ id = "Fit", name = "", share = 1, fixed = 1500, effect = "" },
}

-- vehicle id -> { Upgrade } in fitting order. Prices come from the vehicle price once, at load.
VehicleUpgrades.Vehicles = {} :: { [string]: { Upgrade } }
for _, vehicleId in VehicleUpgrades.VehicleOrder do
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	local fit = FIT[vehicleId]
	local list = {}
	for i, base in BASE do
		list[i] = {
			id = base.id,
			name = if base.id == "Fit" then fit.name else base.name,
			price = if unlock.price > 0
				then math.floor(unlock.price * base.share + 0.5)
				else base.fixed,
			rankIndex = unlock.rankIndex,
			effect = if base.id == "Fit" then fit.effect else base.effect,
		}
	end
	VehicleUpgrades.Vehicles[vehicleId] = list
end

-- Sanitise a stored mask (corrupt saves included).
function VehicleUpgrades.mask(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, VehicleUpgrades.MAX_MASK)
end

function VehicleUpgrades.bit(upgradeId: string): number
	local index = table.find(VehicleUpgrades.UpgradeOrder, upgradeId)
	return if index then 2 ^ (index - 1) else 0
end

function VehicleUpgrades.has(mask: number, upgradeId: string): boolean
	local bit = VehicleUpgrades.bit(upgradeId)
	return bit > 0 and mask % (2 * bit) >= bit
end

function VehicleUpgrades.entry(vehicleId: string, upgradeId: string): Upgrade?
	local upgrades = VehicleUpgrades.Vehicles[vehicleId]
	if not upgrades then
		return nil
	end
	for _, upgrade in upgrades do
		if upgrade.id == upgradeId then
			return upgrade
		end
	end
	return nil
end

-- The next level to fit, or nil when the vehicle is fully upgraded.
function VehicleUpgrades.next(vehicleId: string, mask: number): Upgrade?
	local upgrades = VehicleUpgrades.Vehicles[vehicleId]
	if not upgrades then
		return nil
	end
	for _, upgrade in upgrades do
		if not VehicleUpgrades.has(mask, upgrade.id) then
			return upgrade
		end
	end
	return nil
end

-- ok, reason, price for fitting one upgrade (the three are independent fits, in any order).
function VehicleUpgrades.canBuy(
	vehicleId: string,
	upgradeId: string,
	mask: number,
	cash: number,
	rankIndex: number,
	owned: boolean
): (boolean, string, number)
	local upgrade = VehicleUpgrades.entry(vehicleId, upgradeId)
	if not upgrade then
		return false, "Unknown upgrade", 0
	end
	if not owned then
		return false, "Not owned", upgrade.price
	end
	if VehicleUpgrades.has(mask, upgradeId) then
		return false, "Fitted", upgrade.price
	end
	if rankIndex < upgrade.rankIndex then
		local rank = ProgressionConfig.Ranks[upgrade.rankIndex]
		return false, `Needs {if rank then rank.displayName else upgrade.rankIndex}`, upgrade.price
	end
	if cash < upgrade.price then
		return false, "Need Cash", upgrade.price
	end
	return true, "ok", upgrade.price
end

-- A copy of the boat spec with every fitted upgrade applied (the physics reads this).
function VehicleUpgrades.apply(spec: any, rawMask: any): any
	local mask = VehicleUpgrades.mask(rawMask)
	if mask == 0 then
		return spec
	end
	local out: any = table.clone(spec)
	if VehicleUpgrades.has(mask, "Engine") then
		out.topSpeed *= 1.08
		out.accel *= 1.08
	end
	if VehicleUpgrades.has(mask, "Hull") then
		out.dampingRatio = math.min(0.9, out.dampingRatio + 0.12)
		out.leanFactor *= 0.8
		out.maxLean *= 0.85
		out.turnRate *= 1.05
		out.maxLateralG *= 1.05
		out.lateralGrip = math.min(1, out.lateralGrip + 0.05)
	end
	if VehicleUpgrades.has(mask, "Fit") then
		out.survivorCapacity += 1
		if spec.id == "JetSki" then
			out.pivotSpeed += 1
		elseif spec.id == "RIB" then
			out.lateralGrip = math.min(1, out.lateralGrip + 0.03)
			out.turnRate *= 1.03
		else
			out.turnRate *= 1.03
		end
	end
	return out
end

return VehicleUpgrades
