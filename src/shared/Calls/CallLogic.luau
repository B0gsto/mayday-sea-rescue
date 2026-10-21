--!strict
-- CallLogic: pure functions for calls (spawn points, rewards, grades, scaling). No services.
-- Tested by tests/Call.spec.luau.
local CallTypes = require(script.Parent.CallTypes)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

export type Rng = () -> number -- uniform in [0, 1)
export type Reward = { cash: number, rep: number, grade: string }

local CallLogic = {}

local P = CallTypes.Payout

local function flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
CallLogic.flatDistance = flatDistance

-- Seconds to cover a straight-line distance at a vehicle's top speed times the cruise factor.
function CallLogic.travelSeconds(distance: number, topSpeed: number): number
	return distance / math.max(topSpeed * CallTypes.CRUISE_FACTOR, 1e-3)
end

-- Is this point open water in the given area (not land, the dock or the breakwater)?
function CallLogic.isWater(pos: Vector3, area: string): boolean
	local A = CallTypes.Areas
	if area == "Inside" then
		local box = A.Inside
		if pos.X < box.minX or pos.X > box.maxX or pos.Z < box.minZ or pos.Z > box.maxZ then
			return false
		end
		local k = A.DockKeepOut
		if pos.X >= k.minX and pos.X <= k.maxX and pos.Z <= k.maxZ then
			return false
		end
		-- the breakwater box has corners outside the sheltered zone circles: keep calls sheltered
		return CallLogic.zoneIdAt(pos) ~= "OpenSea"
	end
	if pos.Z < A.OutsideMinZ then
		return false
	end
	return math.sqrt(pos.X * pos.X + pos.Z * pos.Z) <= GameConfig.MapRadius - A.MapMargin
end

-- A random point in a ring around `center` (uniform by area), at sea level.
function CallLogic.ringPoint(center: Vector3, minR: number, maxR: number, rng: Rng): Vector3
	local angle = rng() * math.pi * 2
	local r = math.sqrt(minR * minR + rng() * (maxR * maxR - minR * minR))
	return Vector3.new(center.X + math.cos(angle) * r, 0, center.Z + math.sin(angle) * r)
end

-- A spawn point for a call in a SpawnZone: in the zone's ring and in open water.
function CallLogic.pickSpawnPoint(zoneId: string, rng: Rng?): Vector3
	local zone = CallTypes.SpawnZones[zoneId]
	assert(zone, `unknown spawn zone {zoneId}`)
	local roll: Rng = rng or (math.random :: any)
	for _ = 1, 60 do
		local p = CallLogic.ringPoint(zone.center, zone.minRadius, zone.maxRadius, roll)
		if CallLogic.isWater(p, zone.area) then
			return p
		end
	end
	return zone.fallback
end

-- `count` points scattered around a centre in open water (big-call victims around the ferry).
function CallLogic.scatterPoints(
	center: Vector3,
	count: number,
	minR: number,
	maxR: number,
	area: string,
	rng: Rng?
): { Vector3 }
	local roll: Rng = rng or (math.random :: any)
	local points = {}
	for i = 1, count do
		local chosen: Vector3? = nil
		for _ = 1, 30 do
			local p = CallLogic.ringPoint(center, minR, maxR, roll)
			if CallLogic.isWater(p, area) then
				chosen = p
				break
			end
		end
		-- fallback: an even spread on the ring's outer edge
		points[i] = chosen
			or Vector3.new(
				center.X + math.cos(i / count * math.pi * 2) * maxR,
				0,
				center.Z + math.sin(i / count * math.pi * 2) * maxR
			)
	end
	return points
end

-- The GameConfig zone id at a point (highest priority wins), or "OpenSea".
function CallLogic.zoneIdAt(pos: Vector3): string
	local best: GameConfig.Zone? = nil
	for _, zone in GameConfig.Zones do
		if flatDistance(pos, zone.center) <= zone.radius then
			if not best or zone.priority > best.priority then
				best = zone
			end
		end
	end
	return if best then best.id else "OpenSea"
end

function CallLogic.zoneDisplayName(zoneId: string): string
	for _, zone in GameConfig.Zones do
		if zone.id == zoneId then
			return zone.displayName
		end
	end
	return GameConfig.OpenSea.displayName
end

-- Speed grade (MVP has no comfort meter, docs 02 section 3).
function CallLogic.grade(elapsed: number, timer: number): string
	local f = elapsed / math.max(timer, 1e-3)
	if f < P.GoldUnder then
		return "Gold"
	elseif f < P.SilverUnder then
		return "Silver"
	end
	return "Bronze"
end

-- Crew bonus: +10% per extra member, capped at +30% (docs 02 section 7).
function CallLogic.crewMultiplier(crewSize: number): number
	local extra = math.max(math.floor(crewSize) - 1, 0)
	return 1 + math.min(extra * P.CrewBonusPerMember, P.CrewBonusMax)
end

-- Full payout for one paid helper on a normal call, before storm multipliers (ProgressionService
-- applies those). tutorialIndex = how many calls the player had finished before this one (0 = first).
function CallLogic.reward(
	kind: string,
	elapsed: number,
	timer: number,
	crewSize: number?,
	tutorialIndex: number?
): Reward
	local spec = CallTypes.Kinds[kind]
	assert(spec, `unknown call kind {kind}`)
	local g = CallLogic.grade(elapsed, timer)
	local crew = CallLogic.crewMultiplier(crewSize or 1)
	local tut = if tutorialIndex then P.Tutorial[tutorialIndex + 1] else nil
	if tut then
		return {
			cash = math.floor(tut.cash * crew + 0.5),
			rep = math.floor(tut.rep * crew + 0.5),
			grade = g,
		}
	end
	local m = spec.weight * P.Grade[g] * crew
	return {
		cash = math.floor(P.BaseCash * m + 0.5),
		rep = math.floor(P.BaseRep * m + 0.5),
		grade = g,
	}
end

-- Preview shown on the call card (Silver, solo).
function CallLogic.previewReward(kind: string, tutorialIndex: number?): Reward
	local spec = CallTypes.Kinds[kind]
	if spec and spec.isBig then
		return {
			cash = math.floor(P.BaseCash * P.BigBonusCash),
			rep = math.floor(P.BaseRep * P.BigBonusRep),
			grade = "Silver",
		}
	end
	return CallLogic.reward(kind, 0.7 * 100, 100, 1, tutorialIndex)
end

-- "You tried" share: the fail-safe and crew members without a role action. Cash only.
function CallLogic.failSafeCash(kind: string): number
	local spec = CallTypes.Kinds[kind]
	local weight = if spec then spec.weight else 1
	return math.floor(P.BaseCash * weight * P.FailSafeShare + 0.5)
end

-- Big call: victims scale with the server, at least one per player and at least the base.
function CallLogic.bigCallVictimCount(playerCount: number, base: number?): number
	local b = base or CallTypes.Kinds.CapsizedFerry.victims
	return math.max(math.floor(playerCount), b, 4)
end

-- Big call: pay for each victim delivered, to the deliverer.
function CallLogic.bigVictimPay(): (number, number)
	return math.floor(P.BaseCash * P.BigVictimShare + 0.5),
		math.floor(P.BaseRep * P.BigVictimShare + 0.5)
end

-- Big call: completion bonus for every helper, scaled by the share saved before the timer.
function CallLogic.bigCompletionBonus(saved: number, total: number): (number, number)
	local share = if total > 0 then math.clamp(saved / total, 0, 1) else 0
	return math.floor(P.BaseCash * P.BigBonusCash * share + 0.5),
		math.floor(P.BaseRep * P.BigBonusRep * share + 0.5)
end

-- Seconds until the next offer for a free player. Storm triples the call rate.
function CallLogic.offerDelay(weatherState: string?, isFirst: boolean?): number
	local base = if isFirst
		then CallTypes.Scheduler.FirstOfferDelay
		else CallTypes.Scheduler.OfferDelay
	if weatherState == "Storm" and not isFirst then
		return base / GameConfig.Storm.CallRateMultiplier
	end
	return base
end

export type KindChoice = { kind: string, zone: string }

-- Choose the next call for a player. completed = calls finished this session.
function CallLogic.chooseCall(
	completed: number,
	weatherState: string?,
	canTow: boolean,
	rng: Rng?,
	openOuter: boolean?
): KindChoice
	local roll: Rng = rng or (math.random :: any)
	local tut = CallTypes.TutorialChain[completed + 1]
	if tut then
		if tut.kind == "Tow" and not canTow then
			return { kind = "DriftingCraft", zone = tut.zone }
		end
		return { kind = tut.kind, zone = tut.zone }
	end
	local total = 0
	for _, k in CallTypes.NormalKinds do
		if k ~= "Tow" or canTow then
			total += CallTypes.KindWeights[k]
		end
	end
	local pick = roll() * total
	local kind = "Swimmer"
	for _, k in CallTypes.NormalKinds do
		if k ~= "Tow" or canTow then
			pick -= CallTypes.KindWeights[k]
			if pick < 0 then
				kind = k
				break
			end
		end
	end
	local spec = CallTypes.Kinds[kind]
	-- the cliff casualty is one fixed ledge, not a water ring (docs/09 section 8.5)
	if kind == "Cliff" then
		return { kind = kind, zone = "HavenHeadCliff" }
	end
	-- a vessel fire is fought at anchor in open water, never in Calm Bay (docs/02 section 3)
	if kind == "VesselFire" then
		return { kind = kind, zone = "Outer" }
	end
	-- storm: beginner storm calls at the harbour mouth (docs 02 section 8)
	if weatherState == "Storm" and table.find(spec.zones, "HarbourMouth") and roll() < 0.6 then
		return { kind = kind, zone = "HarbourMouth" }
	end
	-- the Skerries (Outer) open with the Harbor Light; before it, calls stay in Calm Bay
	if openOuter == false then
		return { kind = kind, zone = "CalmBay" }
	end
	return { kind = kind, zone = if roll() < 0.4 then "CalmBay" else "Outer" }
end

-- Is a world position over a flat drop-off pad (XZ inside the pad's footprint plus a margin)?
function CallLogic.insidePad(
	padCFrame: CFrame,
	padSize: Vector3,
	pos: Vector3,
	margin: number
): boolean
	local localPos = padCFrame:PointToObjectSpace(pos)
	return math.abs(localPos.X) <= padSize.X / 2 + margin
		and math.abs(localPos.Z) <= padSize.Z / 2 + margin
		and math.abs(localPos.Y) <= 25
end

-- Timer for a call in a zone.
function CallLogic.timerFor(kind: string, zoneId: string): number
	local spec = CallTypes.Kinds[kind]
	local zone = CallTypes.SpawnZones[zoneId]
	return math.floor(spec.timer * (if zone then zone.timerMultiplier else 1) + 0.5)
end

return CallLogic
