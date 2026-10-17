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

local RANK = { Gold = 4, Silver = 3, Bronze = 2, Fail = 1 }

-- An eased approach is Silver at best; anything else passes unchanged.
function ColdOpen.capGrade(grade: string, eased: boolean): string
	if eased and (RANK[grade] or 0) > RANK[ColdOpen.EASE_GRADE_CAP] then
		return ColdOpen.EASE_GRADE_CAP
	end
	return grade
end

return ColdOpen
