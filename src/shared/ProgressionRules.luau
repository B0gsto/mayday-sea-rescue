--!strict
-- ProgressionRules: the pure progression math (rank from Rep, storm multipliers, purchase checks,
-- save-data defaults and migration). No services, safe to load in Lune (tests/Progression.spec.luau,
-- tests/Ranks.spec.luau). Server services and HUD both use it so they agree.
local MonetizationConfig = require(script.Parent.Config.MonetizationConfig)
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)
local VehicleUpgrades = require(script.Parent.VehicleUpgrades)

export type PlayerData = {
	version: number,
	cash: number,
	rep: number,
	vehicles: { [string]: boolean },
	-- Fitted vehicle upgrades (docs 03 section 4.1): boat id -> bitmask of VehicleUpgrades levels.
	vehicleUpgrades: { [string]: number },
	totalRescues: number,
	coldOpenDone: boolean, -- the first-session cold open has been played (OperationService)
	-- Small persisted flags and settings (ProgressionService.SetFlag). A value is a boolean, a
	-- number, a short string or a flat table of those (for example `cameraSettings`).
	flags: { [string]: any },
	-- Retired certifications (docs/16 C3): kept as saved, never earned or checked any more.
	certs: { [string]: boolean },
	certLive: { [string]: number },
	exercises: { [string]: string },
	-- Equipped cosmetics, slot -> option id (RP-M5, src/shared/Cosmetics; CosmeticsService checks
	-- ownership, this only keeps short strings).
	cosmetics: { [string]: string },
	-- BadgeService: counted badge progress and badges confirmed awarded (flat string keys).
	badgeCounters: { [string]: number }?,
	badgesAwarded: { [string]: boolean }?,
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

-- The player's rank: Rep only (docs/16 K7, no certification gates).
function Rules.rankIndex(data: PlayerData): number
	return Rules.rankIndexForRep(data.rep)
end

local GRADE_RANK = { Gold = 3, Silver = 2, Bronze = 1, Fail = 0 } :: { [string]: number }

-- True when grade is minGrade or better ("Takeover" and unknown grades never are).
function Rules.gradeAtLeast(grade: string?, minGrade: string): boolean
	local g = if grade then GRADE_RANK[grade] else nil
	local m = GRADE_RANK[minGrade]
	return g ~= nil and m ~= nil and g >= m
end

function Rules.exercisePassed(data: PlayerData, exerciseId: string): boolean
	return data.exercises[exerciseId] ~= nil
end

export type CertStatus = {
	id: string,
	displayName: string,
	earned: boolean,
	exercisePassed: boolean,
	live: number,
	liveNeeded: number,
	liveLabel: string,
	missing: { string }, -- prerequisite certifications not yet held (display names)
	ready: boolean,
}

-- shortcut: certStatus, certForExercise and canStartExercise only serve the retired exercise code
-- still in WP1's files (Ops/Definitions/Exercises, OperationService.StartExercise); drop with it.
function Rules.certStatus(data: PlayerData, certId: string): CertStatus?
	local cert = ProgressionConfig.Certifications[certId]
	if not cert then
		return nil
	end
	local missing = {}
	for _, need in cert.needs do
		if data.certs[need] ~= true then
			local needDef = ProgressionConfig.Certifications[need]
			table.insert(missing, if needDef then needDef.displayName else need)
		end
	end
	local earned = data.certs[certId] == true
	local passed = Rules.exercisePassed(data, cert.exercise)
	local live = if earned
		then cert.live.count
		else math.min(data.certLive[certId] or 0, cert.live.count)
	return {
		id = certId,
		displayName = cert.displayName,
		earned = earned,
		exercisePassed = passed or earned,
		live = live,
		liveNeeded = cert.live.count,
		liveLabel = cert.live.label,
		missing = missing,
		ready = earned or (passed and live >= cert.live.count and #missing == 0),
	}
end

function Rules.certForExercise(exerciseId: string): ProgressionConfig.Certification?
	for _, id in ProgressionConfig.CertOrder do
		local cert = ProgressionConfig.Certifications[id]
		if cert and cert.exercise == exerciseId then
			return cert
		end
	end
	return nil
end

-- Exercises are retired with the station board (docs/16 C3): none may start.
function Rules.canStartExercise(
	_data: PlayerData,
	_exerciseId: string,
	_busy: boolean?
): (boolean, string)
	return false, "Exercises are retired"
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

-- Service Stars: one per ServiceStarStep Rep past the top rank (docs 03 section 3).
function Rules.serviceStarsFromRep(rep: number): number
	local top = ProgressionConfig.Ranks[#ProgressionConfig.Ranks]
	return math.max(0, math.floor((rep - top.rep) / ProgressionConfig.ServiceStarStep))
end

function Rules.serviceStars(data: PlayerData): number
	return Rules.serviceStarsFromRep(data.rep)
end

-- stars, Rep of the next star, 0..1 progress into the current star.
function Rules.starProgress(data: PlayerData): (number, number, number)
	local top = ProgressionConfig.Ranks[#ProgressionConfig.Ranks]
	local stars = Rules.serviceStars(data)
	local base = top.rep + stars * ProgressionConfig.ServiceStarStep
	return stars,
		base + ProgressionConfig.ServiceStarStep,
		math.clamp((data.rep - base) / ProgressionConfig.ServiceStarStep, 0, 1)
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

-- Final whole-number award after multipliers. Negative inputs are clamped to 0. `paid` is the
-- Cash multiplier from boosts and friends, `repMult` the Great Storm Rep bonus; `flat` skips all
-- of them, weather included, for passive rewards.
function Rules.applyAward(
	cash: number,
	rep: number,
	state: string?,
	isGreatStorm: boolean?,
	paid: number?,
	repMult: number?,
	flat: boolean?
): (number, number, number)
	local mult = if flat then 1 else Rules.stormCashMultiplier(state, isGreatStorm) * num(paid, 1)
	-- NaN or inf would poison data.cash and the next load would reset the profile to defaults
	local finalCash = math.floor(math.clamp(num(cash, 0), 0, 1e9) * mult + 0.5)
	local finalRep =
		math.floor(math.clamp(num(rep, 0), 0, 1e9) * (if flat then 1 else num(repMult, 1)) + 0.5)
	return finalCash, finalRep, mult
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
		return false
	end
	return unlock.price <= 0 or data.vehicles[vehicleId] == true
end

-- ok, reason: may this player launch this vehicle? A pass owner skips the rank gate.
function Rules.canUseVehicle(
	data: PlayerData,
	vehicleId: string,
	passOwned: boolean?
): (boolean, string)
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock then
		return false, "Unknown vehicle"
	end
	if passOwned == true then
		return true, "ok"
	end
	if unlock.passOnly then
		return false, "Robux only"
	end
	if Rules.rankIndex(data) < unlock.rankIndex then
		return false, `Needs {ProgressionConfig.Ranks[unlock.rankIndex].displayName}`
	end
	if not Rules.ownsVehicle(data, vehicleId) then
		return false, "Not owned"
	end
	return true, "ok"
end

-- Why a vehicle is rank-locked for this player ("Rank: Lifeguard"), or nil when the rank is there.
function Rules.vehicleLock(data: PlayerData, vehicleId: string): string?
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock or Rules.rankIndex(data) >= unlock.rankIndex then
		return nil
	end
	return `Rank: {ProgressionConfig.Ranks[unlock.rankIndex].displayName}`
end

-- The PlayerData a client can rebuild from a Rules.snapshot (the HUD and the phone apps use it so
-- their gates match the server's): Rep, Cash, owned vehicles and their upgrades.
function Rules.fromSnapshot(snap: { [string]: any }): PlayerData
	local data = Rules.defaultData()
	data.cash = if type(snap.cash) == "number" then snap.cash else 0
	data.rep = if type(snap.rep) == "number" then snap.rep else 0
	data.coldOpenDone = snap.coldOpenDone == true
	if type(snap.vehicles) == "table" then
		data.vehicles = table.clone(snap.vehicles)
	end
	if type(snap.vehicleUpgrades) == "table" then
		data.vehicleUpgrades = table.clone(snap.vehicleUpgrades)
	end
	return data
end

-- ok, reason, price for buying a vehicle.
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
	if Rules.rankIndex(data) < unlock.rankIndex then
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
		vehicles = {},
		vehicleUpgrades = {},
		totalRescues = 0,
		coldOpenDone = false,
		flags = {},
		certs = {},
		certLive = {},
		exercises = {},
		cosmetics = {},
	}
end

local MAX_FLAGS = 32
local MAX_FLAG_FIELDS = 64 -- the album alone holds 48 (41 stickers, 7 sets); tests/FlagBudget.spec.luau

local function flagScalar(value: any): any
	local kind = type(value)
	if kind == "boolean" then
		return value
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		return math.clamp(value, -1e6, 1e6)
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

-- Gear is gone: an Engine Tune owner gets the jet ski Engine upgrade (the same +8%) for level 1 and
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
	if type(raw.flags) == "table" then
		local n = 0
		for name, value in raw.flags do
			if Rules.validFlagName(name) and n < MAX_FLAGS then
				local clean = Rules.sanitizeFlag(value)
				if clean ~= nil then
					data.flags[name] = clean
					n += 1
				end
			end
		end
	end
	if type(raw.certs) == "table" then
		for id, held in raw.certs do
			if type(id) == "string" and ProgressionConfig.Certifications[id] and held == true then
				data.certs[id] = true
			end
		end
	end
	if type(raw.certLive) == "table" then
		for id, n in raw.certLive do
			local cert = if type(id) == "string" then ProgressionConfig.Certifications[id] else nil
			if cert and not data.certs[id] then
				local count = math.clamp(math.floor(num(n, 0)), 0, cert.live.count)
				if count > 0 then
					data.certLive[id] = count
				end
			end
		end
	end
	if type(raw.exercises) == "table" then
		for id, grade in raw.exercises do
			if type(id) == "string" and #id <= 40 and Rules.gradeAtLeast(grade, "Bronze") then
				data.exercises[id] = grade
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
	for _, key in { "badgeCounters", "badgesAwarded" } do
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
	local index = Rules.rankIndex(data)
	local nextRank, progress = Rules.progressToNext(data.rep)
	local stars, nextStarRep, starProgress = Rules.starProgress(data)
	local rankName = ProgressionConfig.Ranks[index].displayName
	return {
		cash = data.cash,
		rep = data.rep,
		rank = if stars > 0 then `{rankName} ★{stars}` else rankName,
		rankIndex = index,
		nextRankRep = if nextRank then nextRank.rep else nil,
		rankProgress = progress,
		stars = stars,
		nextStarRep = nextStarRep,
		starProgress = starProgress,
		-- shortcut: legacy fields for readers in other packages, drop with them (WP10): gear is
		-- always empty (OperationService / OnboardingController call next() on it); certs mirrors
		-- the saved, retired certifications (Lighthouses, Onboarding.certDone).
		gear = {},
		certs = table.clone(data.certs),
		vehicles = table.clone(data.vehicles),
		vehicleUpgrades = table.clone(data.vehicleUpgrades),
		coldOpenDone = data.coldOpenDone,
		flags = Rules.migrate({ flags = data.flags }).flags, -- a deep, clean copy
	}
end

return Rules
