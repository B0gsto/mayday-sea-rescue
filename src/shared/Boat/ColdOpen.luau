--!strict
-- Boat/ColdOpen (stream B): helm rules for the cold open (docs 09 section 9.1), pure and
-- Lune-tested (tests/BoatColdOpen.spec.luau). Used by BoatController (client: the throttle the
-- hull actually gets), OperationService (server: honest grading) and Mechanics/approach.
--
-- 1. Auto-throttle. The jet ski spawns under way and an auto-throttle holds AUTO_SPEED until the
--    first of: AUTO_HOLD seconds, the casualty within HANDOVER_DISTANCE, or any throttle input
--    from the player. Then the throttle is the player's own for good: releasing W coasts (an
--    idling jet creeps at about 2.5 knots). HANDOVER_DISTANCE leaves room to coast from
--    AUTO_SPEED below EASE_TRIGGER before EASE_RADIUS without touching the controls.
-- 2. Assist ease. In Assist, on the approach step, a hull still faster than EASE_TRIGGER inside
--    EASE_RADIUS of the casualty (further out when it is too fast to stop in that: see
--    easeRadius) is braked to EASE_TARGET (under the 3 knot slow mark); the ease lets go once it
--    is that slow, so the player can still creep in or open out.
-- 3. Grade. An eased approach is Silver at best (EASE_GRADE_CAP).
-- 4. Show, don't tell (docs/14 F-3, RP-UX2). The casualty is placed DISTANCE studs dead ahead,
--    on screen at spawn and well inside HANDOVER_DISTANCE (so the auto-throttle hands over at
--    once and an idling jet creeps on toward them). PLAN skips the graded approach: the recovery
--    step (docs/14 section 3 ways: drag, throw, or stop and they swim to you) runs from the
--    first second. The radio says a few words; the world (client UI/ColdOpenCue) does the rest,
--    and pops a flare when the player makes no headway for NUDGE_AFTER seconds (nudge).
local Buoyancy = require(script.Parent.Buoyancy)

local KNOT = 1.543 -- studs/s

local ColdOpen = {}

ColdOpen.AUTO_HOLD = 10 -- s, docs 09 9.1 "auto-throttle held for the first 10 s" -- tune
ColdOpen.AUTO_SPEED = 20 * KNOT -- 30.9 studs/s, about half throttle feel -- tune
ColdOpen.HANDOVER_DISTANCE = 170 -- studs to the casualty: hand the throttle over here -- tune
ColdOpen.INPUT_DEADZONE = 0.05 -- |throttle input| that counts as the player taking over
ColdOpen.AUTO_GAIN = 0.08 -- throttle per stud/s of speed error

ColdOpen.EASE_RADIUS = 60 -- studs, hull centre to casualty -- tune
ColdOpen.EASE_TRIGGER = 5 * KNOT -- 7.7 studs/s: "still fast" -- tune
ColdOpen.EASE_TARGET = 2.5 * KNOT -- 3.9 studs/s: under the 3 knot slow mark -- tune
ColdOpen.EASE_SPAN = 12 -- studs/s over the target for full brake
ColdOpen.EASE_MIN_BRAKE = 0.25
ColdOpen.EASE_BRAKE_SHARE = 0.6 -- of brakeDecel counted on for the stopping distance
ColdOpen.EASE_STOP_MARGIN = 15 -- studs short of the casualty the ease aims to be slow
ColdOpen.EASE_RELEASE_RADIUS = 200 -- studs: an engaged ease lets go this far out
ColdOpen.EASE_GRADE_CAP = "Silver"
-- The server judges from replicated motion (a little behind and coarser): a hull seen past the
-- ease line (within the slack) still clearly over the trigger speed needed an ease.
ColdOpen.SERVER_SPEED_MARGIN = 1.5 -- studs/s
ColdOpen.SERVER_RADIUS_SLACK = 3 -- studs

-- Whether the auto-throttle still holds. elapsed: seconds since the cold open spawn; distance:
-- studs from the hull to the casualty; input: the player's throttle (-1..1).
function ColdOpen.autoActive(elapsed: number, distance: number, input: number): boolean
	return elapsed < ColdOpen.AUTO_HOLD
		and distance > ColdOpen.HANDOVER_DISTANCE
		and math.abs(input) < ColdOpen.INPUT_DEADZONE
end

-- The auto-throttle (0..1): holds `target` (default AUTO_SPEED) on the hull's handling, from the
-- calm-water resistance at that speed plus a proportional term.
function ColdOpen.autoThrottle(handling: any, forwardSpeed: number, target: number?): number
	local want = target or ColdOpen.AUTO_SPEED
	local accel = if type(handling.accel) == "number" and handling.accel > 0
		then handling.accel
		else 1
	local hold = Buoyancy.forwardDecel(want, handling, 1) / accel
	return math.clamp(hold + (want - forwardSpeed) * ColdOpen.AUTO_GAIN, 0, 1)
end

-- Studs from the casualty where the ease engages at `speed`: EASE_RADIUS, or more when the hull
-- could not brake to EASE_TARGET within it (brakeDecel: the hull's studs/s^2 of reverse thrust).
function ColdOpen.easeRadius(speed: number, brakeDecel: number?): number
	local decel = math.max(1, (brakeDecel or 16) * ColdOpen.EASE_BRAKE_SHARE)
	local v, target = math.max(speed, 0), ColdOpen.EASE_TARGET
	local stop = if v > target then (v * v - target * target) / (2 * decel) else 0
	return math.max(ColdOpen.EASE_RADIUS, stop + ColdOpen.EASE_STOP_MARGIN)
end

-- Next ease state (hysteresis). speed: the hull's forward speed (studs/s, negative astern).
-- Engages when faster than EASE_TRIGGER inside easeRadius; once engaged it holds until the hull
-- is down to EASE_TARGET (or is well clear, or Assist / the approach is over).
function ColdOpen.updateEase(
	easing: boolean,
	assist: boolean,
	distance: number,
	speed: number,
	brakeDecel: number?
): boolean
	if not assist then
		return false
	end
	if easing then
		return speed > ColdOpen.EASE_TARGET and distance <= ColdOpen.EASE_RELEASE_RADIUS
	end
	return speed > ColdOpen.EASE_TRIGGER and distance <= ColdOpen.easeRadius(speed, brakeDecel)
end

-- The throttle while easing: reverse thrust (brake) scaled to the excess speed, never forward.
function ColdOpen.easeThrottle(forwardSpeed: number, input: number): number
	local excess = forwardSpeed - ColdOpen.EASE_TARGET
	if excess <= 0 then
		return math.min(input, 0)
	end
	local brake = math.clamp(excess / ColdOpen.EASE_SPAN, ColdOpen.EASE_MIN_BRAKE, 1)
	return math.min(-brake, input)
end

-- Server side: replicated motion that certainly needed an ease (so a client cannot hide one).
-- speed: forward speed, as for updateEase.
function ColdOpen.serverSawEase(
	assist: boolean,
	distance: number,
	speed: number,
	brakeDecel: number?
): boolean
	return assist
		and distance < ColdOpen.easeRadius(speed, brakeDecel) + ColdOpen.SERVER_RADIUS_SLACK
		and speed > ColdOpen.EASE_TRIGGER + ColdOpen.SERVER_SPEED_MARGIN
end

-- 4. Cold open setup (read by OperationService.StartColdOpen) and its world cues.
-- 2026-10-21: recovery is auto_board (close and steady, they climb on the sled), then the ride home
-- (transport): at the slipway they climb off and wave
ColdOpen.PLAN = { "tasking", "recovery", "transport" }
-- Spawn inside the breakwater, facing away from the station slipway (SHORE[1]): the casualty is
-- dead ahead and the way home is a straight, clear run back (Studio raycast checked; outside the
-- Harbour Mouth the breakwater sat across the line home).
ColdOpen.SPAWN = Vector3.new(-140, 0, 200)
ColdOpen.DISTANCE = { 70, 85 } -- studs dead ahead of the spawn: on screen, about 23 m -- tune
ColdOpen.RADIO = "Person in the water. Dead ahead!"
-- compact step line, by PiwMode: before they hold on, then on the way in (UI/ColdOpenCue)
ColdOpen.STEP_SHORT = { reach = "Go to them", home = "Bring them home" }
ColdOpen.NUDGE_AFTER = 10 -- s without headway before the world helps (docs/14 10 s rule)
ColdOpen.NUDGE_PROGRESS = 6 -- studs closer that count as headway
ColdOpen.NUDGE_NEAR = 45 -- studs: close enough that the casualty comes (PiwWays.COME_RANGE)

export type Nudge = { best: number, since: number }

function ColdOpen.newNudge(now: number): Nudge
	return { best = math.huge, since = now }
end

-- True when the world should help now (pop a flare): NUDGE_AFTER s with no headway toward the
-- casualty while still out of NUDGE_NEAR. Then the clock starts again from where they are.
function ColdOpen.nudge(n: Nudge, now: number, distance: number): boolean
	if distance <= ColdOpen.NUDGE_NEAR or distance < n.best - ColdOpen.NUDGE_PROGRESS then
		n.best, n.since = distance, now
		return false
	end
	if now - n.since >= ColdOpen.NUDGE_AFTER then
		n.best, n.since = distance, now
		return true
	end
	return false
end

-- 5. The first mission ends on land (docs/14 section 3). The recovery only completes once the
--    casualty holds on (PiwMode "held") and is within SHORE_RADIUS of a shore point: the station
--    slipway (Map.Slipways.StationSlipway, waterline about z 30) or the Haven Sands slipway
--    (WorldConfig.Slipways.SandsSlipway). `dry` is where the shore party takes them over. `via`:
--    open-water turns the minimap route may go through (ColdOpen.nextHop) where the moored boats or
--    the Dock jetty block the straight line (west of the jetty, its tip, east of it; Studio raycast checked).
export type Shore = { id: string, water: Vector3, dry: Vector3, via: { Vector3 }? }
ColdOpen.SHORE = {
	{
		id = "Station",
		water = Vector3.new(-165, 0, 38),
		dry = Vector3.new(-171, 0, 18),
		via = { Vector3.new(-165, 0, 120), Vector3.new(-112, 0, 130), Vector3.new(-80, 0, 120) },
	},
	{ id = "Sands", water = Vector3.new(1000, 0, 282), dry = Vector3.new(970, 0, 250) },
} :: { Shore }
ColdOpen.SHORE_RADIUS = 40 -- studs, flat, casualty to the shore point (28 left a jet ski stalled on the slip short of it) -- tune
ColdOpen.SHORE_RADIO = { from = "Chief Aggie", text = "Over here!" } -- slow on the way in
ColdOpen.WELCOME = { from = "Chief Aggie", text = "Welcome to the crew." }
ColdOpen.NEXT_CALL_DELAY = 30 -- s after the cold open before the first real call (Aggie's welcome) -- tune

-- The nearest shore point to `pos` (flat) and its distance.
function ColdOpen.nearestShore(pos: Vector3): (any, number)
	local best, bestD = ColdOpen.SHORE[1], math.huge
	for _, s in ColdOpen.SHORE do
		local d = Vector3.new(pos.X - s.water.X, 0, pos.Z - s.water.Z).Magnitude
		if d < bestD then
			best, bestD = s, d
		end
	end
	return best, bestD
end

-- The first point to steer for on the way from `from` to `goal`: the shortest chain of clear
-- sightlines (clear(a, b): nothing solid between, e.g. a raycast) through the `via` turns. `goal`
-- itself when the straight line is clear or no chain is.
function ColdOpen.nextHop(
	from: Vector3,
	goal: Vector3,
	via: { Vector3 },
	clear: (Vector3, Vector3) -> boolean
): Vector3
	local nodes = { from }
	table.move(via, 1, #via, 2, nodes)
	table.insert(nodes, goal)
	local n = #nodes
	local dist, prev, done = { 0 }, {}, {}
	for i = 2, n do
		dist[i] = math.huge
	end
	while true do -- Dijkstra over a handful of nodes; an edge is tested only when it could help
		local u, best = nil, math.huge
		for i = 1, n do
			if not done[i] and dist[i] < best then
				u, best = i, dist[i]
			end
		end
		if not u or u == n then
			break
		end
		done[u] = true
		for v = 2, n do
			local w = dist[u] + (nodes[v] - nodes[u]).Magnitude
			if not done[v] and w < dist[v] and clear(nodes[u], nodes[v]) then
				dist[v], prev[v] = w, u
			end
		end
	end
	if dist[n] == math.huge then
		return goal
	end
	local v = n
	while prev[v] ~= 1 do
		v = prev[v]
	end
	return nodes[v]
end

-- True when the cold open's recovery may complete: held, and at a shore point.
function ColdOpen.landed(mode: any, casualty: Vector3): boolean
	local _, d = ColdOpen.nearestShore(casualty)
	return mode == "held" and d <= ColdOpen.SHORE_RADIUS
end

local RANK = { Gold = 4, Silver = 3, Bronze = 2, Fail = 1 }

-- An eased approach is Silver at best; anything else passes unchanged.
function ColdOpen.capGrade(grade: string, eased: boolean): string
	if eased and (RANK[grade] or 0) > RANK[ColdOpen.EASE_GRADE_CAP] then
		return ColdOpen.EASE_GRADE_CAP
	end
	return grade
end

return ColdOpen
