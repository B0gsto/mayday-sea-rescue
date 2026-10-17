--!strict
-- PIW/Approach: scoring of the approach to a person in the water (docs 09 section 5.1 step 5).
-- Real procedure: come in from downwind, heading into wind and sea, dead slow (under about
-- 3 knots in the last 30 m), shift to neutral at a few metres and glide, stop with the casualty
-- alongside or at the bow, well forward of the propeller. Pure (Lune-tested).
local Units = require(script.Parent.Units)

local Approach = {}

Approach.FINAL_RUN = 30 * Units.STUDS_PER_M -- 90 studs: the last 30 m
Approach.SLOW = 3 * Units.KNOT -- 4.63 studs/s, the "slow" mark
Approach.NEUTRAL_MIN = 3 -- studs, neutral closer than this means the boat overruns them
Approach.NEUTRAL_MAX = 8
Approach.INTO_WIND = 0.5 -- cos 60 deg: heading within 60 deg of the wind's eye counts as into wind
Approach.WASH_HEIGHT = 0.45 -- studs of wake at the casualty that slops over a head in the water
Approach.WASH_COOLDOWN = 2.5 -- s between counted washes
Approach.CONTACT = 2.2 -- studs from the hull side: the boat is on top of them
Approach.STOP_SPEED = 1.2 -- studs/s, stopped (gliding to a halt)
Approach.MAX_OFFSET = 30 -- studs, the furthest the wake can push them in one run

export type State = {
	overSpeedSec: number,
	finalTime: number,
	intoWindTime: number,
	downwindTime: number,
	neutralAt: number?,
	washes: number,
	washCooldown: number,
	offset: Vector3,
	aborts: number,
	upwindAborts: number,
	minDistance: number,
}

export type Sample = {
	distance: number, -- studs, boat hull centre to casualty
	speed: number, -- studs/s over the ground
	forward: Vector3,
	boatPos: Vector3,
	casualtyPos: Vector3,
	windDirection: number,
	neutral: boolean,
	wakeHeight: number,
	wakePush: Vector3,
}

function Approach.new(): State
	return {
		overSpeedSec = 0,
		finalTime = 0,
		intoWindTime = 0,
		downwindTime = 0,
		neutralAt = nil,
		washes = 0,
		washCooldown = 0,
		offset = Vector3.zero,
		aborts = 0,
		upwindAborts = 0,
		minDistance = math.huge,
	}
end

-- 1 = heading straight into the wind's eye, -1 = running before it.
function Approach.intoWind(forward: Vector3, windDirection: number): number
	return Units.unitOr(forward, Vector3.zAxis):Dot(-Units.windVector(windDirection))
end

-- True when the boat lies downwind of the casualty (so it drifts away from them, not onto them).
function Approach.isDownwindOf(
	boatPos: Vector3,
	casualtyPos: Vector3,
	windDirection: number
): boolean
	return Units.flat(boatPos - casualtyPos):Dot(Units.windVector(windDirection)) > 0
end

-- Returns true when this sample washed over the casualty (an event the server caps at 2).
function Approach.sample(s: State, dt: number, x: Sample): boolean
	s.minDistance = math.min(s.minDistance, x.distance)
	s.washCooldown = math.max(0, s.washCooldown - dt)
	-- the wake pushes them away: a fast approach chases the casualty across the water
	if x.wakePush.Magnitude > 0 then
		local o = s.offset + Units.flat(x.wakePush) * dt
		if o.Magnitude > Approach.MAX_OFFSET then
			o = o.Unit * Approach.MAX_OFFSET
		end
		s.offset = o
	end
	if x.distance <= Approach.FINAL_RUN then
		s.finalTime += dt
		if x.speed > Approach.SLOW then
			s.overSpeedSec += dt
		end
		if Approach.intoWind(x.forward, x.windDirection) >= Approach.INTO_WIND then
			s.intoWindTime += dt
		end
		if Approach.isDownwindOf(x.boatPos, x.casualtyPos, x.windDirection) then
			s.downwindTime += dt
		end
		if x.neutral then
			if s.neutralAt == nil then
				s.neutralAt = x.distance
			end
		elseif x.speed > Approach.STOP_SPEED then
			s.neutralAt = nil -- back in gear: the last shift to neutral is the one that counts
		end
	end
	if x.wakeHeight >= Approach.WASH_HEIGHT and s.washCooldown <= 0 and x.distance < 40 then
		s.washes += 1
		s.washCooldown = Approach.WASH_COOLDOWN
		return true
	end
	return false
end

-- The casualty in the hull's local frame (x starboard, z aft, Roblox -Z forward). Good stop:
-- alongside or at the bow, forward of the aft quarter where the propeller or jet is.
function Approach.stopPosition(localPos: Vector3, length: number, beam: number): (boolean, string)
	local halfL, halfB = length / 2, beam / 2
	local lateral = math.abs(localPos.X) - halfB
	local aft = localPos.Z
	if aft > halfL - length * 0.25 and lateral < 6 then
		return false, "astern" -- near the propeller
	end
	if aft < -(halfL + 7) or lateral > 7 then
		return false, "far"
	end
	return true, if aft < -halfL + length * 0.2 then "bow" else "side"
end

-- An abort ("Abort, go round"): the boat drifted onto them or put them near the propeller.
function Approach.abort(s: State, upwind: boolean)
	s.aborts += 1
	if upwind then
		s.upwindAborts += 1
	end
	s.finalTime, s.intoWindTime, s.downwindTime = 0, 0, 0
	s.neutralAt = nil
	s.minDistance = math.huge
end

-- The metric for the neutral shift: the distance itself inside or beyond the window; closer than
-- the window (overran, or never shifted) reads worse than any honest early shift.
function Approach.neutralMetric(d: number?): number
	if d == nil then
		return 20 -- never out of gear near a swimmer: the Bronze edge
	end
	if d < Approach.NEUTRAL_MIN then
		return 12 + (Approach.NEUTRAL_MIN - d) * 3
	end
	return d
end

function Approach.metrics(s: State): { [string]: number | boolean }
	local t = math.max(s.finalTime, 1e-3)
	local fromDownwind = s.upwindAborts == 0
		and s.intoWindTime / t >= 0.6
		and s.downwindTime / t >= 0.6
	return {
		overSpeedSec = math.floor(s.overSpeedSec * 10 + 0.5) / 10,
		neutralDistance = math.floor(Approach.neutralMetric(s.neutralAt) * 10 + 0.5) / 10,
		fromDownwind = fromDownwind,
	}
end

return Approach
