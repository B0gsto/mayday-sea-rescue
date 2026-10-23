--!strict
-- NextGoal: the one unlock the HUD nags about (docs/03 section 10 pacing, docs/15 section 3).
-- Pure and Lune-tested (tests/NextGoal.spec.luau). Reads the client's PlayerDataChanged snapshot
-- and returns every live unlock as the numbers close to it, nearest first:
--   rank (or Service Star past Admiral) > vehicle > certification > gear > upgrade
-- The fraction is value / target; the preference order only breaks ties, so the chip shows the
-- goal the player is actually closest to. A goal the rank gate already passed is not listed:
-- a certification the player still lacks is the real next unlock then.
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)
local ProgressionRules = require(script.Parent.ProgressionRules)
local VehicleUpgrades = require(script.Parent.VehicleUpgrades)

export type Kind = "Rank" | "Vehicle" | "Cert" | "Gear" | "Upgrade"
export type Unit = "Rep" | "Cash" | "Steps"

export type Goal = {
	kind: Kind,
	key: string, -- stable while this exact unlock is the goal
	label: string, -- 1-3 words next to the icon
	value: number,
	target: number,
	fraction: number,
	unit: Unit,
}

local NextGoal = {}

NextGoal.LIMIT = 3

local PREFERENCE: { [Kind]: number } = {
	Rank = 1,
	Vehicle = 2,
	Cert = 3,
	Gear = 4,
	Upgrade = 5,
}

local VEHICLE_LABEL = {
	JetSki = "Jet ski",
	RIB = "RIB",
	Lifeboat = "Lifeboat",
	RescueHelicopter = "Helicopter",
}

local function earned(snapshot: { [string]: any }, certId: string): boolean
	local certs = snapshot.certs
	if type(certs) ~= "table" then
		return false
	end
	local status = certs[certId]
	if type(status) == "table" then
		return status.earned == true
	end
	return status == true
end

local function add(
	goals: { Goal },
	kind: Kind,
	key: string,
	label: string,
	value: number,
	target: number,
	unit: Unit
)
	if target <= 0 then
		return
	end
	local clamped = math.clamp(value, 0, target)
	table.insert(goals, {
		kind = kind,
		key = key,
		label = label,
		value = clamped,
		target = target,
		fraction = clamped / target,
		unit = unit,
	})
end

local function rankGoal(goals: { Goal }, snapshot: { [string]: any }, rankIndex: number)
	local rep = tonumber(snapshot.rep) or 0
	local ranks = ProgressionConfig.Ranks
	if rankIndex >= #ranks then
		local stars = tonumber(snapshot.stars) or ProgressionRules.serviceStarsFromRep(rep)
		local top = ranks[#ranks].rep
		local base = top + stars * ProgressionConfig.ServiceStarStep
		add(
			goals,
			"Rank",
			`Star:{stars + 1}`,
			`Star {stars + 1}`,
			rep - base,
			ProgressionConfig.ServiceStarStep,
			"Rep"
		)
		return
	end
	local nextRank = ranks[rankIndex + 1]
	if not nextRank then
		return
	end
	-- a rank whose certification is missing is not the next unlock: the cert goal is
	for _, certId in ProgressionRules.rankCerts(nextRank) do
		if ProgressionConfig.Certifications[certId] ~= nil and not earned(snapshot, certId) then
			return
		end
	end
	add(goals, "Rank", `Rank:{nextRank.id}`, nextRank.displayName, rep, nextRank.rep, "Rep")
end

local function vehicleGoals(goals: { Goal }, snapshot: { [string]: any }, rankIndex: number)
	local cash = tonumber(snapshot.cash) or 0
	local owned = snapshot.vehicles
	for id, unlock in ProgressionConfig.Vehicles do
		if
			unlock.land ~= true
			and unlock.price > 0
			and rankIndex >= unlock.rankIndex
			and not (type(owned) == "table" and owned[id] == true)
		then
			add(
				goals,
				"Vehicle",
				`Vehicle:{id}`,
				VEHICLE_LABEL[id] or id,
				cash,
				unlock.price,
				"Cash"
			)
		end
	end
end

local function certGoals(goals: { Goal }, snapshot: { [string]: any })
	local certs = snapshot.certs
	if type(certs) ~= "table" then
		return
	end
	for _, id in ProgressionConfig.CertOrder do
		local status = certs[id]
		local cert = ProgressionConfig.Certifications[id]
		if type(status) == "table" and status.earned ~= true and cert then
			local open = true
			for _, need in cert.needs do
				if not earned(snapshot, need) then
					open = false
					break
				end
			end
			if open then
				local done = (if status.exercisePassed == true then 1 else 0)
					+ math.max(0, tonumber(status.live) or 0)
				local total = 1 + math.max(0, tonumber(status.liveNeeded) or cert.live.count)
				add(goals, "Cert", `Cert:{id}`, cert.displayName, done, total, "Steps")
			end
		end
	end
end

local function gearGoals(goals: { Goal }, snapshot: { [string]: any }, rankIndex: number)
	local cash = tonumber(snapshot.cash) or 0
	local gear = snapshot.gear
	for _, id in ProgressionConfig.GearOrder do
		local item = ProgressionConfig.Gear[id]
		if item then
			local level = math.clamp(
				if type(gear) == "table" then tonumber(gear[id]) or 0 else 0,
				0,
				#item.levels
			)
			local nextLevel = level + 1
			if
				nextLevel <= #item.levels
				and rankIndex >= ProgressionConfig.GearLevelRank[nextLevel]
			then
				add(
					goals,
					"Gear",
					`Gear:{id}:{nextLevel}`,
					item.displayName,
					cash,
					ProgressionConfig.GearLevelPrices[nextLevel],
					"Cash"
				)
			end
		end
	end
end

local function upgradeGoals(goals: { Goal }, snapshot: { [string]: any }, rankIndex: number)
	local cash = tonumber(snapshot.cash) or 0
	local owned = snapshot.vehicles
	local stored = snapshot.vehicleUpgrades
	if type(owned) ~= "table" then
		return
	end
	for _, vehicleId in VehicleUpgrades.VehicleOrder do
		if owned[vehicleId] == true then
			local mask = if type(stored) == "table"
				then VehicleUpgrades.mask(stored[vehicleId])
				else 0
			local upgrade = VehicleUpgrades.next(vehicleId, mask)
			if upgrade and rankIndex >= upgrade.rankIndex then
				add(
					goals,
					"Upgrade",
					`Upgrade:{vehicleId}:{upgrade.id}`,
					`{VEHICLE_LABEL[vehicleId] or vehicleId} {upgrade.name}`,
					cash,
					upgrade.price,
					"Cash"
				)
			end
		end
	end
end

-- Every live goal, nearest first (fraction; ties by the preference order above).
function NextGoal.goals(snapshot: { [string]: any }, _now: number?): { Goal }
	local goals: { Goal } = {}
	if type(snapshot) ~= "table" then
		return goals
	end
	local rep = tonumber(snapshot.rep) or 0
	local rankIndex = math.clamp(
		tonumber(snapshot.rankIndex) or ProgressionRules.rankIndexForRep(rep),
		1,
		#ProgressionConfig.Ranks
	)
	rankGoal(goals, snapshot, rankIndex)
	vehicleGoals(goals, snapshot, rankIndex)
	certGoals(goals, snapshot)
	gearGoals(goals, snapshot, rankIndex)
	upgradeGoals(goals, snapshot, rankIndex)
	local order: { [string]: number } = {}
	for i, goal in goals do
		order[goal.key] = i
	end
	table.sort(goals, function(a, b)
		if a.fraction ~= b.fraction then
			return a.fraction > b.fraction
		end
		if PREFERENCE[a.kind] ~= PREFERENCE[b.kind] then
			return PREFERENCE[a.kind] < PREFERENCE[b.kind]
		end
		return order[a.key] < order[b.key]
	end)
	return goals
end

function NextGoal.best(snapshot: { [string]: any }, now: number?): Goal?
	return NextGoal.goals(snapshot, now)[1]
end

return NextGoal
