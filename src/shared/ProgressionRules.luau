--!strict
-- ProgressionRules: the pure progression math (rank from Rep, storm multipliers, gear bonuses,
-- purchase checks, save-data defaults and migration). No services, safe to load in Lune
-- (tests/Progression.spec.luau). Server services and HUD both use it so they agree.
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)

export type PlayerData = {
	version: number,
	cash: number,
	rep: number,
	gear: { [string]: number },
	vehicles: { [string]: boolean },
	totalRescues: number,
}

local Rules = {}

-- Index of the highest rank whose Rep threshold is met.
function Rules.rankIndexForRep(rep: number): number
	local index = 1
	for i, rank in ProgressionConfig.Ranks do
		if rep >= rank.rep then
			index = i
		end
	end
	return index
end

function Rules.rankForRep(rep: number): ProgressionConfig.Rank
	return ProgressionConfig.Ranks[Rules.rankIndexForRep(rep)]
end

-- Next rank, plus 0..1 progress from the current threshold to the next. nil next at max rank.
function Rules.progressToNext(rep: number): (ProgressionConfig.Rank?, number)
	local index = Rules.rankIndexForRep(rep)
	local current = ProgressionConfig.Ranks[index]
	local nextRank = ProgressionConfig.Ranks[index + 1]
	if not nextRank then
		return nil, 1
	end
	local span = nextRank.rep - current.rep
	return nextRank, math.clamp((rep - current.rep) / span, 0, 1)
end

-- Cash multiplier for the weather state. Rep is never multiplied (docs 03 section 2).
function Rules.stormCashMultiplier(state: string?, isGreatStorm: boolean?): number
	if state ~= "Storm" then
		return 1
	end
	if isGreatStorm then
		return ProgressionConfig.GreatStormCashMultiplier
	end
	return ProgressionConfig.StormCashMultiplier
end

-- Final whole-number award after multipliers. Negative inputs are clamped to 0.
function Rules.applyAward(
	cash: number,
	rep: number,
	state: string?,
	isGreatStorm: boolean?
): (number, number, number)
	local mult = Rules.stormCashMultiplier(state, isGreatStorm)
	local finalCash = math.floor(math.max(cash, 0) * mult + 0.5)
	local finalRep = math.floor(math.max(rep, 0) + 0.5)
	return finalCash, finalRep, mult
end

-- Multiplier for a stat from every owned gear item (1 when nothing applies).
function Rules.gearBonus(gear: { [string]: number }?, stat: string): number
	local mult = 1
	if not gear then
		return mult
	end
	for id, level in gear do
		local item = ProgressionConfig.Gear[id]
		if item and item.stat == stat and level > 0 then
			local clamped = math.min(math.floor(level), #item.levels)
			mult *= item.levels[clamped]
		end
	end
	return mult
end

function Rules.maxGearLevel(): number
	return #ProgressionConfig.GearLevelPrices
end

-- Price and rank for the next level of a gear item, or nil + reason when it cannot be bought.
function Rules.nextGearLevel(data: PlayerData, gearId: string): (number?, string?)
	local item = ProgressionConfig.Gear[gearId]
	if not item then
		return nil, "Unknown gear"
	end
	local nextLevel = (data.gear[gearId] or 0) + 1
	if nextLevel > math.min(#item.levels, Rules.maxGearLevel()) then
		return nil, "Max level"
	end
	return nextLevel, nil
end

-- ok, reason, price for buying the next level of gear.
function Rules.canBuyGear(data: PlayerData, gearId: string): (boolean, string, number)
	local nextLevel, why = Rules.nextGearLevel(data, gearId)
	if not nextLevel then
		return false, why or "Unavailable", 0
	end
	local price = ProgressionConfig.GearLevelPrices[nextLevel]
	local needRank = ProgressionConfig.GearLevelRank[nextLevel] or 1
	if Rules.rankIndexForRep(data.rep) < needRank then
		return false, `Needs {ProgressionConfig.Ranks[needRank].displayName}`, price
	end
	if data.cash < price then
		return false, "Not enough Cash", price
	end
	return true, "ok", price
end

function Rules.ownsVehicle(data: PlayerData, vehicleId: string): boolean
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock then
		return false
	end
	return unlock.price <= 0 or data.vehicles[vehicleId] == true
end

-- ok, reason: may this player launch this vehicle?
function Rules.canUseVehicle(data: PlayerData, vehicleId: string): (boolean, string)
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock then
		return false, "Unknown vehicle"
	end
	if Rules.rankIndexForRep(data.rep) < unlock.rankIndex then
		return false, `Needs {ProgressionConfig.Ranks[unlock.rankIndex].displayName}`
	end
	if not Rules.ownsVehicle(data, vehicleId) then
		return false, "Not owned"
	end
	return true, "ok"
end

-- ok, reason, price for buying a vehicle.
function Rules.canBuyVehicle(data: PlayerData, vehicleId: string): (boolean, string, number)
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock then
		return false, "Unknown vehicle", 0
	end
	if Rules.ownsVehicle(data, vehicleId) then
		return false, "Already owned", unlock.price
	end
	if Rules.rankIndexForRep(data.rep) < unlock.rankIndex then
		return false, `Needs {ProgressionConfig.Ranks[unlock.rankIndex].displayName}`, unlock.price
	end
	if data.cash < unlock.price then
		return false, "Not enough Cash", unlock.price
	end
	return true, "ok", unlock.price
end

function Rules.defaultData(): PlayerData
	return {
		version = ProgressionConfig.SchemaVersion,
		cash = ProgressionConfig.StartingCash,
		rep = 0,
		gear = {},
		vehicles = {},
		totalRescues = 0,
	}
end

local function num(value: any, default: number): number
	if
		type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
	then
		return value
	end
	return default
end

-- Fills missing fields and upgrades old versions. Accepts anything (corrupt saves included).
function Rules.migrate(raw: any): PlayerData
	local data = Rules.defaultData()
	if type(raw) ~= "table" then
		return data
	end
	data.cash = math.max(0, num(raw.cash, data.cash))
	data.rep = math.max(0, num(raw.rep, 0))
	data.totalRescues = math.max(0, num(raw.totalRescues, 0))
	if type(raw.gear) == "table" then
		for id, level in raw.gear do
			if type(id) == "string" and ProgressionConfig.Gear[id] then
				data.gear[id] = math.clamp(math.floor(num(level, 0)), 0, Rules.maxGearLevel())
			end
		end
	end
	if type(raw.vehicles) == "table" then
		for id, owned in raw.vehicles do
			if type(id) == "string" and ProgressionConfig.Vehicles[id] and owned == true then
				data.vehicles[id] = true
			end
		end
	end
	-- version 1 is current; future migrations go here, keyed on raw.version
	data.version = ProgressionConfig.SchemaVersion
	return data
end

-- What the client sees (PlayerDataChanged and Progression_GetData).
function Rules.snapshot(data: PlayerData): { [string]: any }
	local index = Rules.rankIndexForRep(data.rep)
	local nextRank, progress = Rules.progressToNext(data.rep)
	return {
		cash = data.cash,
		rep = data.rep,
		rank = ProgressionConfig.Ranks[index].displayName,
		rankIndex = index,
		nextRankRep = if nextRank then nextRank.rep else nil,
		rankProgress = progress,
		gear = table.clone(data.gear),
		vehicles = table.clone(data.vehicles),
	}
end

return Rules
