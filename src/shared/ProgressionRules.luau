--!strict
-- ProgressionRules: the pure progression math (rank from Rep, storm multipliers, gear bonuses,
-- purchase checks, certifications and the rank gate, save-data defaults and migration). No
-- services, safe to load in Lune (tests/Progression.spec.luau, tests/Certs.spec.luau). Server
-- services and HUD both use it so they agree.
local MonetizationConfig = require(script.Parent.Config.MonetizationConfig)
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)
local VehicleUpgrades = require(script.Parent.VehicleUpgrades)

export type PlayerData = {
	version: number,
	cash: number,
	rep: number,
	gear: { [string]: number },
	vehicles: { [string]: boolean },
	-- Fitted vehicle upgrades (docs 03 section 4.1): boat id -> bitmask of VehicleUpgrades levels.
	vehicleUpgrades: { [string]: number },
	totalRescues: number,
	coldOpenDone: boolean, -- the first-session cold open has been played (OperationService)
	-- Small persisted flags and settings (ProgressionService.SetFlag). A value is a boolean, a
	-- number, a short string or a flat table of those (for example `cameraSettings`).
	flags: { [string]: any },
	-- Certifications (docs 03 section 3.1): id -> true once earned. Never lost.
	certs: { [string]: boolean },
	-- Live operations counted toward each unearned certification (capped at its count).
	certLive: { [string]: number },
	-- Exercise id -> best passing grade ("Gold" | "Silver" | "Bronze"); present means passed.
	exercises: { [string]: string },
	-- Equipped cosmetics, slot -> option id (RP-M5, src/shared/Cosmetics; CosmeticsService checks
	-- ownership, this only keeps short strings).
	cosmetics: { [string]: string },
	-- BadgeService: counted badge progress and badges confirmed awarded (flat string keys).
	badgeCounters: { [string]: number }?,
	badgesAwarded: { [string]: boolean }?,
}

-- One step of a finished operation, as the debrief timeline has it (OperationService record()).
export type StepRecord = {
	id: string,
	grade: string,
	userId: number?, -- who did it (nil: an NPC)
	mechanicId: string?, -- the mechanic that played it (Operations.mechanicFor)
	assistEase: boolean?, -- the cold open's Assist ease drove the hull: never counts
}

-- What the debrief shows under the grade ("debrief badges").
export type DebriefBadge = {
	id: string, -- "Cert:Helm", "Exercise:ExerciseSwimTest", "Progress:Helm"
	kind: "cert" | "exercise" | "progress" | "rank",
	title: string,
	text: string,
	badge: string?, -- BadgeConfig key for a Roblox badge award (certifications)
}

export type TrainingResult = {
	kind: string,
	exercise: boolean,
	passed: boolean, -- exercises: this run passed (live operations: false)
	firstPass: boolean, -- exercises: the first pass ever (pays the reward)
	best: string?, -- exercises: the best passing grade after this run
	reward: { cash: number, rep: number }, -- exercises: the first-pass reward (else 0)
	counted: { string }, -- certifications whose live count went up
	earned: { string }, -- certifications earned by this result
	rankBefore: number,
	rankAfter: number, -- gated rank index after the certifications (Rep is awarded separately)
	badges: { DebriefBadge },
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

-- Every certification a rank needs: the single `cert` plus the `certs` list (docs 03 section 3).
function Rules.rankCerts(rank: ProgressionConfig.Rank): { string }
	local ids = {}
	if rank.cert then
		table.insert(ids, rank.cert)
	end
	if rank.certs then
		for _, id in rank.certs do
			table.insert(ids, id)
		end
	end
	return ids
end

-- The first certification gate of `rank` that exists and is not held (nil: the rank may open).
function Rules.rankBlockingCert(rank: ProgressionConfig.Rank, data: PlayerData): string?
	for _, id in Rules.rankCerts(rank) do
		if ProgressionConfig.Certifications[id] ~= nil and data.certs[id] ~= true then
			return id
		end
	end
	return nil
end

local GRADE_RANK = { Gold = 3, Silver = 2, Bronze = 1, Fail = 0 } :: { [string]: number }

-- True when grade is minGrade or better ("Takeover" and unknown grades never are).
function Rules.gradeAtLeast(grade: string?, minGrade: string): boolean
	local g = if grade then GRADE_RANK[grade] else nil
	local m = GRADE_RANK[minGrade]
	return g ~= nil and m ~= nil and g >= m
end

function Rules.hasCert(data: PlayerData, certId: string): boolean
	return data.certs[certId] == true
end

-- The player's rank: the highest rank whose Rep is met with every rank up to it certified
-- (docs 03 section 3: the Rep keeps counting, the promotion waits for the certification).
function Rules.rankIndex(data: PlayerData): number
	local index = 1
	for i, rank in ProgressionConfig.Ranks do
		if data.rep < rank.rep or Rules.rankBlockingCert(rank, data) ~= nil then
			break
		end
		index = i
	end
	return index
end

-- The rank the Rep has reached but a certification holds back, and that certification.
function Rules.blockedRank(data: PlayerData): (ProgressionConfig.Rank?, string?)
	local nextRank = ProgressionConfig.Ranks[Rules.rankIndex(data) + 1]
	if nextRank and data.rep >= nextRank.rep then
		local cert = Rules.rankBlockingCert(nextRank, data)
		if cert then
			return nextRank, cert
		end
	end
	return nil, nil
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
	ready: boolean, -- every condition met (evaluateCerts grants it)
}

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

-- Grants every certification whose conditions are met (prerequisites first, so one result can
-- earn a chain). Returns the newly earned ids in ladder order.
function Rules.evaluateCerts(data: PlayerData): { string }
	local earned = {}
	local changed = true
	while changed do
		changed = false
		for _, id in ProgressionConfig.CertOrder do
			if data.certs[id] ~= true then
				local st = Rules.certStatus(data, id)
				if st and st.ready then
					data.certs[id] = true
					data.certLive[id] = nil
					table.insert(earned, id)
					changed = true
				end
			end
		end
	end
	return earned
end

-- One short line for the HUD's "next thing" about certifications, or nil when none applies:
-- the rank a certification holds back first ("Pass Rescue Swimmer to be promoted"), else the
-- next certification on the ladder ("Casualty Care: 1 of 2 operations").
function Rules.certHint(data: PlayerData): string?
	local blocked, blockingCert = Rules.blockedRank(data)
	if blocked and blockingCert then
		local cert = ProgressionConfig.Certifications[blockingCert]
		local name = if cert then cert.displayName else blockingCert
		return `Pass {name} to be promoted`
	end
	for _, id in ProgressionConfig.CertOrder do
		local st = Rules.certStatus(data, id)
		if st and not st.earned then
			if #st.missing > 0 then
				return `{st.displayName}: needs {table.concat(st.missing, ", ")}`
			elseif not st.exercisePassed then
				return `{st.displayName}: pass the exercise at the station`
			end
			return `{st.displayName}: {st.live} of {st.liveNeeded} {st.liveLabel}`
		end
	end
	return nil
end

-- Does this finished operation count toward the certification's live half for this player?
local function qualifies(
	live: ProgressionConfig.CertLive,
	steps: { StepRecord },
	userId: number
): boolean
	local hits, present = 0, 0
	for _, wanted in live.stepIds do
		local found, good = false, false
		for _, s in steps do
			if s.id == wanted then
				local mechanicOk = live.mechanicIds == nil
				if live.mechanicIds and s.mechanicId then
					mechanicOk = table.find(live.mechanicIds, s.mechanicId) ~= nil
				end
				if mechanicOk then
					found = true
					if
						s.userId == userId
						and s.assistEase ~= true
						and Rules.gradeAtLeast(s.grade, live.minGrade)
					then
						good = true
					end
				end
			end
		end
		if found then
			present += 1
			if good then
				hits += 1
			end
		end
	end
	if live.mode == "all" then
		return present > 0 and hits == present
	end
	return hits > 0
end

local function certBadges(
	data: PlayerData,
	earned: { string },
	counted: { string }
): { DebriefBadge }
	local badges: { DebriefBadge } = {}
	for _, id in earned do
		local cert = ProgressionConfig.Certifications[id]
		table.insert(badges, {
			id = `Cert:{id}`,
			kind = "cert",
			title = `{cert.displayName} certified`,
			text = table.concat(cert.gates, " · "),
			badge = cert.badge,
		})
	end
	for _, id in counted do
		if table.find(earned, id) == nil then
			local st = Rules.certStatus(data, id)
			if st then
				local text = `{st.live} of {st.liveNeeded} {st.liveLabel}`
				if not st.exercisePassed then
					text ..= "; the exercise is still to pass"
				elseif #st.missing > 0 then
					text ..= `; needs {table.concat(st.missing, ", ")}`
				end
				table.insert(badges, {
					id = `Progress:{id}`,
					kind = "progress",
					title = st.displayName,
					text = text,
				})
			end
		end
	end
	return badges
end

local function rankBadge(badges: { DebriefBadge }, before: number, after: number)
	if after > before then
		local rank = ProgressionConfig.Ranks[after]
		table.insert(badges, {
			id = `Rank:{rank.id}`,
			kind = "rank",
			title = `Promoted to {rank.displayName}`,
			text = table.concat(rank.unlocks, " · "),
		})
	end
end

-- A live operation finished: count it toward every unearned certification it qualifies for,
-- then grant what is complete. Exercises never count here (use recordExercise).
function Rules.recordOperation(
	data: PlayerData,
	kind: string,
	steps: { StepRecord },
	userId: number
): TrainingResult
	local before = Rules.rankIndex(data)
	local counted = {}
	for _, id in ProgressionConfig.CertOrder do
		local cert = ProgressionConfig.Certifications[id]
		if data.certs[id] ~= true and qualifies(cert.live, steps, userId) then
			data.certLive[id] = math.min((data.certLive[id] or 0) + 1, cert.live.count)
			table.insert(counted, id)
		end
	end
	local earned = Rules.evaluateCerts(data)
	local after = Rules.rankIndex(data)
	local badges = certBadges(data, earned, counted)
	rankBadge(badges, before, after)
	return {
		kind = kind,
		exercise = false,
		passed = false,
		firstPass = false,
		best = nil,
		reward = { cash = 0, rep = 0 },
		counted = counted,
		earned = earned,
		rankBefore = before,
		rankAfter = after,
		badges = badges,
	}
end

-- An exercise finished with this overall grade. It passes at ExercisePassGrade or better when
-- the player did every step themselves (an NPC finishing one means no pass); a cannotFail
-- exercise (the drill) always passes. The first pass pays the reward; the best grade is kept.
function Rules.recordExercise(
	data: PlayerData,
	exerciseId: string,
	grade: string,
	steps: { StepRecord },
	userId: number,
	cannotFail: boolean?
): TrainingResult
	local before = Rules.rankIndex(data)
	local own = #steps > 0
	for _, s in steps do
		if s.userId ~= userId then
			own = false
		end
	end
	local passed = own
		and (cannotFail == true or Rules.gradeAtLeast(grade, ProgressionConfig.ExercisePassGrade))
	local shown = if Rules.gradeAtLeast(grade, "Bronze") then grade else "Bronze"
	local prior = data.exercises[exerciseId]
	local firstPass = passed and prior == nil
	if passed and (prior == nil or (GRADE_RANK[shown] or 0) > (GRADE_RANK[prior] or 0)) then
		data.exercises[exerciseId] = shown
	end
	local reward = { cash = 0, rep = 0 }
	if firstPass then
		local r = if exerciseId == ProgressionConfig.DrillExercise
			then ProgressionConfig.DrillReward
			else ProgressionConfig.ExerciseReward
		reward = { cash = r.cash, rep = r.rep }
	end
	local earned = Rules.evaluateCerts(data)
	local after = Rules.rankIndex(data)
	local counted = {}
	for _, id in ProgressionConfig.CertOrder do
		local cert = ProgressionConfig.Certifications[id]
		if cert.exercise == exerciseId and firstPass then
			table.insert(counted, id)
		end
	end
	local badges: { DebriefBadge } = {}
	if passed then
		table.insert(badges, {
			id = `Exercise:{exerciseId}`,
			kind = "exercise",
			title = if firstPass then "Exercise passed" else "Exercise passed again",
			text = `Best: {data.exercises[exerciseId]}`,
		})
	end
	for _, b in certBadges(data, earned, counted) do
		table.insert(badges, b)
	end
	rankBadge(badges, before, after)
	return {
		kind = exerciseId,
		exercise = true,
		passed = passed,
		firstPass = firstPass,
		best = data.exercises[exerciseId],
		reward = reward,
		counted = counted,
		earned = earned,
		rankBefore = before,
		rankAfter = after,
		badges = badges,
	}
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

-- Stars only count once the top rank itself is reached (Rep plus the rank's certifications).
function Rules.serviceStars(data: PlayerData): number
	if Rules.rankIndex(data) < #ProgressionConfig.Ranks then
		return 0
	end
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
	if Rules.rankIndex(data) < needRank then
		return false, `Needs {ProgressionConfig.Ranks[needRank].displayName}`, price
	end
	if data.cash < price then
		return false, "Not enough Cash", price
	end
	return true, "ok", price
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

-- Why a vehicle is rank-locked for this player, or nil when the rank is there (RP-C1b): the
-- boat desk shows the same gate the server applies (Rules.canUseVehicle uses the gated rank).
-- "Rank: Lifeguard" when the Rep is short, "Pass Helm" when the Rep is there but the rank's
-- certification is not.
function Rules.vehicleLock(data: PlayerData, vehicleId: string): string?
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	if not unlock or Rules.rankIndex(data) >= unlock.rankIndex then
		return nil
	end
	if Rules.rankIndexForRep(data.rep) >= unlock.rankIndex then
		for i = Rules.rankIndex(data) + 1, unlock.rankIndex do
			local cert = Rules.rankBlockingCert(ProgressionConfig.Ranks[i], data)
			if cert then
				local def = ProgressionConfig.Certifications[cert]
				return `Pass {if def then def.displayName else cert}`
			end
		end
	end
	return `Rank: {ProgressionConfig.Ranks[unlock.rankIndex].displayName}`
end

-- The certification an exercise is the first half of (nil: the drill or an unknown id).
function Rules.certForExercise(exerciseId: string): ProgressionConfig.Certification?
	for _, id in ProgressionConfig.CertOrder do
		local cert = ProgressionConfig.Certifications[id]
		if cert and cert.exercise == exerciseId then
			return cert
		end
	end
	return nil
end

-- ok, reason: may this player start this exercise from the station board (RP-C1b)? Needs the
-- cold open done and every prerequisite certification held (the swim test waits for Casualty
-- Care). `busy` is true while the player is on an operation (OperationService checks it).
-- Repeats are always allowed: only the first pass pays.
function Rules.canStartExercise(
	data: PlayerData,
	exerciseId: string,
	busy: boolean?
): (boolean, string)
	local cert = Rules.certForExercise(exerciseId)
	if not cert and exerciseId ~= ProgressionConfig.DrillExercise then
		return false, "Unknown exercise"
	end
	if not data.coldOpenDone then
		return false, "Finish your first rescue first"
	end
	if busy then
		return false, "Finish the current operation first"
	end
	if cert then
		for _, need in cert.needs do
			if data.certs[need] ~= true then
				local def = ProgressionConfig.Certifications[need]
				return false, `Needs {if def then def.displayName else need}`
			end
		end
	end
	return true, "ok"
end

-- The PlayerData a client can rebuild from a Rules.snapshot (the HUD and the exercise board use
-- it so their gates match the server's): Rep, Cash, owned vehicles, certifications, exercises.
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
	if type(snap.gear) == "table" then
		data.gear = table.clone(snap.gear)
	end
	if type(snap.exercises) == "table" then
		data.exercises = table.clone(snap.exercises)
	end
	if type(snap.certs) == "table" then
		for id, st in snap.certs do
			if type(st) == "table" then
				if st.earned == true then
					data.certs[id] = true
				elseif type(st.live) == "number" then
					data.certLive[id] = st.live
				end
			end
		end
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
		gear = {},
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
	else
		-- a save from before certifications: grandfather the ones its Rep rank already needs, so
		-- nobody is demoted (prerequisites included: Rescue Swimmer brings Casualty Care)
		local function grant(id: string)
			local cert = ProgressionConfig.Certifications[id]
			if cert and not data.certs[id] then
				data.certs[id] = true
				for _, need in cert.needs do
					grant(need)
				end
			end
		end
		for _, rank in ProgressionConfig.Ranks do
			if data.rep >= rank.rep then
				for _, id in Rules.rankCerts(rank) do
					grant(id)
				end
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
	local repIndex = Rules.rankIndexForRep(data.rep)
	if index < repIndex then
		-- the Rep is there, the certification is not: the bar shows full until it is passed
		nextRank, progress = ProgressionConfig.Ranks[index + 1], 1
	end
	local certs = {}
	for _, id in ProgressionConfig.CertOrder do
		local st = Rules.certStatus(data, id)
		if st then
			certs[id] = {
				earned = st.earned,
				exercisePassed = st.exercisePassed,
				live = st.live,
				liveNeeded = st.liveNeeded,
			}
		end
	end
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
		gear = table.clone(data.gear),
		vehicles = table.clone(data.vehicles),
		vehicleUpgrades = table.clone(data.vehicleUpgrades),
		coldOpenDone = data.coldOpenDone,
		flags = Rules.migrate({ flags = data.flags }).flags, -- a deep, clean copy
		certs = certs, -- id -> { earned, exercisePassed, live, liveNeeded }
		exercises = table.clone(data.exercises), -- exercise id -> best grade (the board)
		certHint = Rules.certHint(data),
	}
end

return Rules
