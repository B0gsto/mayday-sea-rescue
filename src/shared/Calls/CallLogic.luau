--!strict
-- CallLogic: pure functions for calls (spawn points, rewards, grades, scaling). No services.
-- Tested by tests/Call.spec.luau.
local CallTypes = require(script.Parent.CallTypes)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local RingLayout = require(script.Parent.Parent.Config.RingLayout)
local WorldConfig = require(script.Parent.Parent.Config.WorldConfig)

export type Rng = () -> number -- uniform in [0, 1)
export type Reward = { cash: number, grade: string }

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

-- Where a player's calls count from (docs/23 (p)): their berth (player attribute BayCFrame), else Plot1's berth.
-- At sea level.
function CallLogic.homeOf(bay: any): Vector3
	local p: Vector3 = if typeof(bay) == "CFrame"
		then bay.Position
		elseif typeof(bay) == "Vector3" then bay
		else RingLayout.Islands[1].berths.Boat.Position
	return Vector3.new(p.X, 0, p.Z)
end

-- Straight out of a home's cove: the flat unit from the ring centre to it (every cove opens away from it).
local function outOf(home: Vector3): Vector3
	local d = Vector3.new(home.X - CallTypes.STATION.X, 0, home.Z - CallTypes.STATION.Z)
	return if d.Magnitude > 1 then d.Unit else Vector3.zAxis
end

-- Open water 1,500 studs out from the ring centre on the home's bearing: past its cove, short of the outer islands.
function CallLogic.homeFallback(home: Vector3): Vector3
	return CallTypes.STATION + outOf(home) * 1500
end

-- Flat distance from p to the segment a-b.
local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (ap - ab * t).Magnitude
end

-- Is this point open water (pure map data: outside the ring (no calls in the lagoon, docs/23 (p)), off the six
-- islands and the outer islands, clear of the bridges, inside the map)? area "Outer" also keeps Areas.OuterMin from
-- the ring centre. The server adds its raycasts.
function CallLogic.isWater(pos: Vector3, area: string): boolean
	local A = CallTypes.Areas
	local fromCentre = flatDistance(pos, CallTypes.STATION)
	if
		fromCentre < RingLayout.Ring
		or fromCentre > GameConfig.MapRadius - A.MapMargin
		or (area == "Outer" and fromCentre < A.OuterMin)
	then
		return false
	end
	for _, island in RingLayout.Islands do
		if flatDistance(pos, island.center) < RingLayout.IslandRadius + A.Shore then
			return false
		end
	end
	for _, bridge in RingLayout.Bridges do
		if segmentDistance(pos, bridge.from, bridge.to) < A.BridgeClear then
			return false
		end
	end
	for _, island in WorldConfig.Islands do
		if flatDistance(pos, island.center) < island.radius then
			return false
		end
	end
	return true
end

-- A random point in a ring around `center` (uniform by area), at sea level.
function CallLogic.ringPoint(center: Vector3, minR: number, maxR: number, rng: Rng): Vector3
	local angle = rng() * math.pi * 2
	local r = math.sqrt(minR * minR + rng() * (maxR * maxR - minR * minR))
	return Vector3.new(center.X + math.cos(angle) * r, 0, center.Z + math.sin(angle) * r)
end

-- A spawn point for a call in a SpawnZone: in the zone's ring (cove zones: the cone out of `home`'s cove;
-- fromHome zones: round `home`) and in open water. home: CallLogic.homeOf(BayCFrame). clear: the server's
-- world check (RescueService.ClearWater and a clear sea line from the cove).
function CallLogic.pickSpawnPoint(
	zoneId: string,
	rng: Rng?,
	clear: ((Vector3) -> boolean)?,
	home: Vector3?
): Vector3
	local zone = CallTypes.SpawnZones[zoneId]
	assert(zone, `unknown spawn zone {zoneId}`)
	local roll: Rng = rng or (math.random :: any)
	local h = home or CallLogic.homeOf(nil)
	local out = outOf(h)
	for _ = 1, 60 do
		local p
		if zone.cove then
			local a = (roll() * 2 - 1) * math.rad(CallTypes.COVE_HALF_ANGLE)
			local r = zone.minRadius + roll() * (zone.maxRadius - zone.minRadius)
			local c, s = math.cos(a), math.sin(a)
			p = Vector3.new(h.X + (out.X * c - out.Z * s) * r, 0, h.Z + (out.X * s + out.Z * c) * r)
		else
			p = CallLogic.ringPoint(
				if zone.fromHome then h else zone.center,
				zone.minRadius,
				zone.maxRadius,
				roll
			)
		end
		if CallLogic.isWater(p, zone.area) and (clear == nil or clear(p)) then
			return p
		end
	end
	return zone.fallback or CallLogic.homeFallback(h)
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
			grade = g,
		}
	end
	local m = spec.weight * P.Grade[g] * crew
	return {
		cash = math.floor(P.BaseCash * m + 0.5),
		grade = g,
	}
end

-- Big call: victims scale with the server, at least one per player and at least the base.
function CallLogic.bigCallVictimCount(playerCount: number, base: number?): number
	local b = base or CallTypes.Kinds.CapsizedFerry.victims
	return math.max(math.floor(playerCount), b, 4)
end

-- Big call: pay for each victim delivered, to the deliverer.
function CallLogic.bigVictimPay(): number
	return math.floor(P.BaseCash * P.BigVictimShare + 0.5)
end

-- Big call: completion bonus for every helper, scaled by the share saved before the timer.
function CallLogic.bigCompletionBonus(saved: number, total: number): number
	local share = if total > 0 then math.clamp(saved / total, 0, 1) else 0
	return math.floor(P.BaseCash * P.BigBonusCash * share + 0.5)
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

export type KindChoice = { kind: string, zone: string, victims: number? }

-- How far out a player's calls go (docs/23 (q)): the best CallTypes.CraftReach among the craft they can launch.
function CallLogic.craftReach(owned: { string }): number
	local reach = CallTypes.BASE_REACH
	for _, id in owned do
		reach = math.max(reach, CallTypes.CraftReach[id] or 0)
	end
	return reach
end

-- A distance-tier zone (docs/23 e.2), uniform over every zone the reach covers from `home` (the pool widens):
-- the open-sea rings up to the reach, and every outer island whose centre is within it.
function CallLogic.distanceZone(reach: number?, rng: Rng?, home: Vector3?): string
	local roll: Rng = rng or (math.random :: any)
	local r, h = reach or CallTypes.BASE_REACH, home or CallLogic.homeOf(nil)
	local pool = {}
	for id, zone in CallTypes.SpawnZones do
		if
			(zone.reach and zone.reach <= r)
			or (zone.island and flatDistance(h, zone.center) <= r)
		then
			table.insert(pool, id)
		end
	end
	table.sort(pool) -- pairs order is not stable; a seeded rng must pick the same zone
	return pool[math.floor(roll() * #pool) + 1] or "Offshore"
end

-- A wreck dive site (docs/23 (h)) within `reach` of `home` (nil: any) and, if given, on island `where`
-- (or with that site id). nil when none fits.
function CallLogic.diveSite(
	reach: number?,
	rng: Rng?,
	where: string?,
	home: Vector3?
): CallTypes.DiveSite?
	local roll: Rng = rng or (math.random :: any)
	local h = home or CallLogic.homeOf(nil)
	local pool = {}
	for _, site in CallTypes.DiveSites do
		if
			flatDistance(h, site.at) <= (reach or math.huge)
			and (where == nil or where == site.island or where == site.id)
		then
			table.insert(pool, site)
		end
	end
	return pool[math.floor(roll() * #pool) + 1]
end

-- Pay multiplier for a call this far (flat studs) from your berth: 1 close in, rising with distance.
function CallLogic.distancePay(distance: number): number
	local D = CallTypes.Distance
	return math.clamp(distance / D.PayPerStuds, 1, D.PayMax)
end

-- Pay multiplier for a call at `scene` landed at `at`: distancePay from `home` (your berth), but landed
-- elsewhere it pays for half the round trip sailed (home -> scene -> `at`),
-- never more.
function CallLogic.deliveredPay(scene: Vector3, at: Vector3, home: Vector3?): number
	local h = home or CallLogic.homeOf(nil)
	local out = flatDistance(scene, h)
	if flatDistance(at, h) <= CallTypes.HOME_RADIUS then
		return CallLogic.distancePay(out)
	end
	return CallLogic.distancePay(math.min(out, (out + flatDistance(scene, at)) / 2))
end

-- Choose the next call for a player. completed = calls finished this session; reach = craftReach; sub =
-- they own the submarine (a diver at a wreck now and then, from call DIVER_FROM_CALL on); home = homeOf.
function CallLogic.chooseCall(
	completed: number,
	weatherState: string?,
	rng: Rng?,
	reach: number?,
	sub: boolean?,
	home: Vector3?
): KindChoice
	local roll: Rng = rng or (math.random :: any)
	if sub and completed + 1 >= CallTypes.DIVER_FROM_CALL and roll() < CallTypes.DIVER_CHANCE then
		local site = CallLogic.diveSite(reach or CallTypes.BASE_REACH, roll, nil, home)
		if site then
			return { kind = "Diver", zone = site.island }
		end
	end
	local tut = CallTypes.TutorialChain[completed + 1]
	if tut then
		return {
			kind = tut.kind,
			zone = tut.zone or CallLogic.distanceZone(reach, roll, home),
			victims = tut.victims,
		}
	end
	local total = 0
	for _, k in CallTypes.NormalKinds do
		total += CallTypes.KindWeights[k]
	end
	local pick = roll() * total
	local kind = "Swimmer"
	for _, k in CallTypes.NormalKinds do
		pick -= CallTypes.KindWeights[k]
		if pick < 0 then
			kind = k
			break
		end
	end
	local spec = CallTypes.Kinds[kind]
	-- one-place scenes (the rip off Puffin Isle's beach)
	if #spec.zones == 1 then
		return { kind = kind, zone = spec.zones[1] }
	end
	-- storm: beginner storm calls just off your cove (docs 02 section 8)
	if weatherState == "Storm" and table.find(spec.zones, "HarbourMouth") and roll() < 0.6 then
		return { kind = kind, zone = "HarbourMouth" }
	end
	return { kind = kind, zone = CallLogic.distanceZone(reach, roll, home) }
end

-- Driving at a call (docs/16 K2: a seated player who heads for the flare takes the call): flat
-- speed of at least minSpeed and the course within maxDeg of the bearing to target.
function CallLogic.headingToward(
	from: Vector3,
	velocity: Vector3,
	target: Vector3,
	minSpeed: number,
	maxDeg: number
): boolean
	local vx, vz = velocity.X, velocity.Z
	local tx, tz = target.X - from.X, target.Z - from.Z
	local speed, dist = math.sqrt(vx * vx + vz * vz), math.sqrt(tx * tx + tz * tz)
	if speed < minSpeed or dist < 1 then
		return false
	end
	return (vx * tx + vz * tz) / (speed * dist) >= math.cos(math.rad(maxDeg))
end

return CallLogic
