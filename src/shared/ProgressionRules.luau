--!strict
-- ProgressionRules: the pure progression math (storm multipliers, vehicle checks, save-data defaults and
-- migration). No ranks and no Reputation (docs/23 (q), WP-28): craft unlock through their island building
-- (shared/UnlockTree). No services, safe to load in Lune (tests/Progression.spec.luau). Server services and
-- the HUD both use it so they agree.
local DockConfig = require(script.Parent.Config.DockConfig)
local MonetizationConfig = require(script.Parent.Config.MonetizationConfig)
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)
local UnlockTree = require(script.Parent.UnlockTree)
local VehicleUpgrades = require(script.Parent.VehicleUpgrades)
local WorkerRules = require(script.Parent.WorkerRules)

export type PlayerData = {
	version: number,
	cash: number,
	rep: number, -- retired Reputation (WP-28): kept as saved, never read
	vehicles: { [string]: boolean },
	-- Fitted vehicle upgrades (docs 03 section 4.1): boat id -> bitmask of VehicleUpgrades levels.
	vehicleUpgrades: { [string]: number },
	totalRescues: number, -- people delivered home (badges, leaderboards, the rescue board)
	coldOpenDone: boolean, -- the first-session cold open has been played (OperationService)
	dockLevel: number, -- retired dock level 1..5 (WP-28): kept as saved; migrate maps it onto the tree
	dockBuildings: { [string]: boolean }, -- the unlock tree (DockConfig.Buildings), blueprints and decor
	-- Robux-paid buildings waiting for their prerequisites (UnlockTree.settle builds them once those stand).
	dockPrepaid: { [string]: boolean },
	-- Rescued people working on your island (docs/23 (o), WP-26; WorkerRules, WorkerService), at most WorkerRules.CAP.
	workers: { WorkerRules.Worker },
	lastSeen: number?, -- os.time of the last save (DataService): offline worker earnings count from here
	-- Small persisted flags and settings (ProgressionService.SetFlag). A value is a boolean, a
	-- number, a short string or a flat table of those (for example `cameraSettings`).
	flags: { [string]: any },
	-- Equipped cosmetics, slot -> option id (RP-M5, src/shared/Cosmetics; CosmeticsService checks
	-- ownership, this only keeps short strings).
	cosmetics: { [string]: string },
	-- BadgeService: counted badge progress and badges confirmed awarded (flat string keys).
	badgeCounters: { [string]: number }?,
	badgesAwarded: { [string]: boolean }?,
	-- Retired certifications and exercises (docs/16 C3): kept as saved, never read.
	certs: { [string]: any }?,
	certLive: { [string]: any }?,
	exercises: { [string]: any }?,
}

local Rules = {}

-- Cash multiplier for the weather state (docs 03 section 2).
function Rules.stormCashMultiplier(state: string?, isGreatStorm: boolean?): number
	if state ~= "Storm" then
		return 1
	end
	if isGreatStorm then
		return ProgressionConfig.GreatStormCashMultiplier
	end
	return ProgressionConfig.StormCashMultiplier
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

-- Final whole-number Cash after multipliers -> cash, multiplier. Negative inputs are clamped to 0. `paid` is
-- the Cash multiplier from boosts and friends; `flat` skips all of them, weather included, for passive rewards.
function Rules.applyAward(
	cash: number,
	state: string?,
	isGreatStorm: boolean?,
	paid: number?,
	flat: boolean?
): (number, number)
	local mult = if flat then 1 else Rules.stormCashMultiplier(state, isGreatStorm) * num(paid, 1)
	-- NaN or inf would poison data.cash and the next load would reset the profile to defaults
	return math.floor(math.clamp(num(cash, 0), 0, 1e9) * mult + 0.5), mult
end

-- The GamePasses key that owns this vehicle (MonetizationConfig item with `vehicle` = id), or nil.
function Rules.vehiclePass(vehicleId: string): string?
	for key, item in MonetizationConfig.GamePasses do
		if item.vehicle == vehicleId then
			return key
		end
	end
	return nil
end

-- Owned = free, bought with Cash, or its vehicle pass is owned (`passOwned`: the caller checks the
-- pass; the server reads its own Pass_<Key> attribute). A passOnly vehicle needs the pass.
function Rules.ownsVehicle(data: PlayerData, vehicleId: string, passOwned: boolean?): boolean
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock then
		return false
	end
	if passOwned == true then
		return true
	end
	if unlock.passOnly then
		-- the wheel's grand-prize boat is the one pass-only craft a profile flag may own
		return data.vehicles[vehicleId] == true and data.flags.spinBoat == vehicleId
	end
	return unlock.price <= 0 or data.vehicles[vehicleId] == true
end

-- ok, reason: may this player launch this vehicle? Owning it is enough: the building gate is on the buy
-- (UnlockTree), so a craft bought before WP-28 (or a pass bought on the website) keeps launching.
function Rules.canUseVehicle(
	data: PlayerData,
	vehicleId: string,
	passOwned: boolean?
): (boolean, string)
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock then
		return false, "Unknown vehicle"
	end
	if Rules.ownsVehicle(data, vehicleId, passOwned) then
		return true, "ok"
	end
	return false, if unlock.passOnly then "Robux only" else "Not owned"
end

-- The building a vehicle still needs on this player's island (a DockConfig.Buildings key), or nil.
function Rules.vehicleLock(data: PlayerData, vehicleId: string): string?
	return UnlockTree.craftMissing(vehicleId, data.dockBuildings)
end

-- The PlayerData a client can rebuild from a Rules.snapshot (the HUD and the boards use it so their gates
-- match the server's): Cash, owned vehicles and their upgrades, the island's buildings.
function Rules.fromSnapshot(snap: { [string]: any }): PlayerData
	local data = Rules.defaultData()
	data.cash = if type(snap.cash) == "number" then snap.cash else 0
	data.coldOpenDone = snap.coldOpenDone == true
	data.totalRescues = if type(snap.totalRescues) == "number" then snap.totalRescues else 0
	for _, key in { "vehicles", "vehicleUpgrades", "workers", "dockBuildings" } do
		if type(snap[key]) == "table" then
			(data :: any)[key] = table.clone(snap[key])
		end
	end
	if type(snap.flags) == "table" and type(snap.flags.spinBoat) == "string" then
		data.flags.spinBoat = snap.flags.spinBoat
	end
	return data
end

-- ok, reason, price for buying a vehicle with Cash: its building first (UnlockTree), then the Cash.
function Rules.canBuyVehicle(
	data: PlayerData,
	vehicleId: string,
	passOwned: boolean?
): (boolean, string, number)
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock then
		return false, "Unknown vehicle", 0
	end
	if Rules.ownsVehicle(data, vehicleId, passOwned) then
		return false, "Already owned", unlock.price
	end
	if unlock.passOnly then
		return false, "Robux only", 0
	end
	local need = Rules.vehicleLock(data, vehicleId)
	if need then
		return false, `Needs {DockConfig.Buildings[need].name}`, unlock.price
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
		vehicles = {},
		vehicleUpgrades = {},
		totalRescues = 0,
		coldOpenDone = false,
		dockLevel = 1,
		dockBuildings = {},
		dockPrepaid = {},
		workers = {},
		flags = {},
		cosmetics = {},
	}
end

local MAX_FLAGS = 32
local MAX_FLAG_FIELDS = 64 -- an old (cut) album flag holds 48 (41 stickers, 7 sets); tests/FlagBudget.spec.luau

local function flagScalar(value: any): any
	local kind = type(value)
	if kind == "boolean" then
		return value
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		-- whole ids and timestamps stay exact (1e6 cut flags.group's group id on every save)
		return math.clamp(value, -2 ^ 53, 2 ^ 53)
	elseif kind == "string" then
		return string.sub(value, 1, 64)
	end
	return nil
end

-- Cleans one flag value (scalar, or a flat table of string keys to scalars); nil when invalid.
function Rules.sanitizeFlag(value: any): any
	if type(value) ~= "table" then
		return flagScalar(value)
	end
	local out = {}
	local n = 0
	for k, v in value do
		if type(k) == "string" and #k <= 32 and n < MAX_FLAG_FIELDS then
			local clean = flagScalar(v)
			if clean ~= nil then
				out[k] = clean
				n += 1
			end
		end
	end
	return out
end

function Rules.validFlagName(name: any): boolean
	return type(name) == "string" and #name > 0 and #name <= 32
end

-- Retired purchases paid back on load (docs/16 C4, K8). Gear levels cost 300 / 1,200 / 4,000; the
-- jet ski's third upgrade (a second seat) cost 1,500.
local GEAR_LEVEL_PRICES = { 300, 1200, 4000 }
local JETSKI_FIT_PRICE = 1500

-- Gear is gone: an Engine Tune owner gets the jet ski Engine upgrade (the same +15%) for level 1 and
-- every other level back in Cash; Strong Grip did nothing with auto_board, so all of it comes back.
-- The jet ski holds one (docs/16 section 1): its old seat upgrade comes off and is paid back.
-- Idempotent: a migrated profile has no gear and no jet ski seat bit.
local function payBackRetired(raw: { [string]: any }, data: PlayerData)
	local jet = data.vehicleUpgrades.JetSki or 0
	if VehicleUpgrades.has(jet, "Fit") then
		jet -= VehicleUpgrades.bit("Fit")
		data.cash += JETSKI_FIT_PRICE
	end
	if type(raw.gear) == "table" then
		for id, level in raw.gear do
			if id == "EngineTune" or id == "StrongGrip" then
				for l = 1, math.clamp(math.floor(num(level, 0)), 0, #GEAR_LEVEL_PRICES) do
					if id == "EngineTune" and l == 1 and not VehicleUpgrades.has(jet, "Engine") then
						jet += VehicleUpgrades.bit("Engine")
					else
						data.cash += GEAR_LEVEL_PRICES[l]
					end
				end
			end
		end
	end
	data.vehicleUpgrades.JetSki = (if jet > 0 then jet else nil) :: any
end

local CREW_REFUND = { Mechanic = 12000, Lifeguard = 9000, Dispatcher = 15000 } -- WP-15 hire prices

-- Fills missing fields and upgrades old versions. Accepts anything (corrupt saves included).
Rules.MAX_FLAGS = MAX_FLAGS

function Rules.migrate(raw: any): PlayerData
	local data = Rules.defaultData()
	if type(raw) ~= "table" then
		return data
	end
	data.cash = math.max(0, num(raw.cash, data.cash))
	data.rep = math.max(0, num(raw.rep, 0))
	data.totalRescues = math.max(0, num(raw.totalRescues, 0))
	if type(raw.vehicles) == "table" then
		for id, owned in raw.vehicles do
			if type(id) == "string" and ProgressionConfig.Vehicles[id] and owned == true then
				data.vehicles[id] = true
			end
		end
	end
	if type(raw.vehicleUpgrades) == "table" then
		for id, mask in raw.vehicleUpgrades do
			if type(id) == "string" and VehicleUpgrades.Vehicles[id] then
				local clean = VehicleUpgrades.mask(mask)
				if clean > 0 then
					data.vehicleUpgrades[id] = clean
				end
			end
		end
	end
	payBackRetired(raw, data)
	data.coldOpenDone = raw.coldOpenDone == true
	data.dockLevel = math.clamp(math.floor(num(raw.dockLevel, 1)), 1, 5)
	if type(raw.dockBuildings) == "table" then
		for key, owned in raw.dockBuildings do
			if
				type(key) == "string"
				and owned == true
				and (
					DockConfig.Buildings[key] ~= nil
					or DockConfig.Blueprints[key] ~= nil
					or DockConfig.Decorations[key] ~= nil
				)
			then
				data.dockBuildings[key] = true
			end
		end
	end
	UnlockTree.migrate(data.dockLevel, data.dockBuildings) -- WP-28: old dock levels -> tree items
	if type(raw.dockPrepaid) == "table" then
		for key, paid in raw.dockPrepaid do
			if type(key) == "string" and paid == true and DockConfig.Buildings[key] ~= nil then
				data.dockPrepaid[key] = true
			end
		end
	end
	-- WP-26: the hired crew (WP-15) is gone; what it cost comes back once (saves no longer carry `crew`)
	if type(raw.crew) == "table" then
		for role, hired in raw.crew do
			if hired == true then
				data.cash += CREW_REFUND[role] or 0
			end
		end
	end
	data.workers = WorkerRules.clean(raw.workers)
	local seen = num(raw.lastSeen, 0)
	data.lastSeen = if seen > 0 then seen else nil
	if type(raw.flags) == "table" then
		local n = 0
		for name, value in raw.flags do
			-- "station" was the removed Crew Pay idle-income pot: dropped so it frees its flag slot
			if name ~= "station" and Rules.validFlagName(name) and n < MAX_FLAGS then
				local clean = Rules.sanitizeFlag(value)
				if clean ~= nil then
					data.flags[name] = clean
					n += 1
				end
			end
		end
	end
	if type(raw.cosmetics) == "table" then
		local n = 0
		for slot, id in raw.cosmetics do
			if
				type(slot) == "string"
				and #slot <= 24
				and type(id) == "string"
				and #id <= 40
				and n < 32
			then
				data.cosmetics[slot] = id
				n += 1
			end
		end
	end
	for _, key in { "badgeCounters", "badgesAwarded", "certs", "certLive", "exercises" } do
		if type(raw[key]) == "table" then
			(data :: any)[key] = Rules.sanitizeFlag(raw[key])
		end
	end
	-- version 1 is current; future migrations go here, keyed on raw.version
	data.version = ProgressionConfig.SchemaVersion
	return data
end

-- What the client sees (PlayerDataChanged and Progression_GetData).
function Rules.snapshot(data: PlayerData): { [string]: any }
	return {
		cash = data.cash,
		totalRescues = data.totalRescues,
		dockBuildings = table.clone(data.dockBuildings),
		dockPrepaid = table.clone(data.dockPrepaid),
		vehicles = table.clone(data.vehicles),
		vehicleUpgrades = table.clone(data.vehicleUpgrades),
		workers = table.clone(data.workers),
		coldOpenDone = data.coldOpenDone,
		flags = Rules.migrate({ flags = data.flags }).flags, -- a deep, clean copy
	}
end

return Rules
