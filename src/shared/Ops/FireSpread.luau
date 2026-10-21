--!strict
-- FireSpread: a vessel fire's growth, dousing and smoke plume (docs/09-rescue-operations.md 8.2).
-- Pure (Lune-tested, tests/FireSpread.spec.luau). The server grows the fire while nobody fights
-- it; the fight mechanic reports how much water reached the base and the hull boundary and
-- `douse` turns that into what is left. Wind direction never feeds the flames, only the smoke.
local FireSpread = {}

export type State = {
	heat: number, -- 0..1 flames
	spread: number, -- 0..1 how far along the hull it has spread
	doused: boolean, -- knocked down enough to stop growing
}

FireSpread.HEAT_RATE = 1 / 150 -- heat per second ignored
FireSpread.SPREAD_RATE = 1 / 180 -- spread per second once the fire is established
FireSpread.IGNITE = 0.35 -- heat at which it starts running forward
FireSpread.PANELS = 4 -- hull boundary points next to the fire

function FireSpread.new(): State
	return { heat = 0.3, spread = 0, doused = false }
end

-- Grows ignored fire. Returns the same state for chaining.
function FireSpread.tick(state: State, dt: number): State
	if state.doused then
		return state
	end
	state.heat = math.clamp(state.heat + FireSpread.HEAT_RATE * dt, 0, 1)
	if state.heat >= FireSpread.IGNITE then
		state.spread =
			math.clamp(state.spread + FireSpread.SPREAD_RATE * dt * (0.4 + state.heat), 0, 1)
	end
	return state
end

-- base = share of the fire base kept under the jet (0..1), panels = share of the hull boundary
-- cooled (0..1). Returns the spread left (0..1).
function FireSpread.douse(state: State, base: number, panels: number): number
	local pour = math.clamp(base, 0, 1) * 0.55 + math.clamp(panels, 0, 1) * 0.3
	state.heat = math.clamp(state.heat * (1 - pour), 0, 1)
	state.spread = math.clamp(state.spread * (1 - pour), 0, 1)
	state.doused = state.heat < 0.3 and state.spread < 0.25
	return state.spread
end

function FireSpread.flameRate(state: State): number
	if state.doused then
		return 0
	end
	return math.floor(10 + state.heat * 26)
end

function FireSpread.smokeRate(state: State): number
	if state.doused then
		return 3 -- steam off the wet hull
	end
	return math.floor(8 + state.spread * 16)
end

-- The wind blows toward this (same convention as Weather.WindDirection).
function FireSpread.downwind(windDirection: number): Vector3
	return Vector3.new(math.cos(windDirection), 0, math.sin(windDirection))
end

-- Is `position` in the smoke plume downwind of the fire? Returns the answer and the angle off
-- the plume axis (degrees) for the debrief and the mechanic's warning.
function FireSpread.inPlume(
	windDirection: number,
	firePosition: Vector3,
	position: Vector3,
	halfAngleDeg: number,
	reach: number
): (boolean, number)
	local off = position - firePosition
	off = Vector3.new(off.X, 0, off.Z)
	local distance = off.Magnitude
	if distance < 1 then
		return true, 0
	end
	local dot = off.Unit:Dot(FireSpread.downwind(windDirection))
	local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
	return angle <= halfAngleDeg and distance <= reach, angle
end

-- Is the boat upwind of the fire (the safe side, smoke blows away)?
function FireSpread.upwind(windDirection: number, firePosition: Vector3, position: Vector3): boolean
	local off = position - firePosition
	off = Vector3.new(off.X, 0, off.Z)
	return off.Magnitude > 1 and off.Unit:Dot(FireSpread.downwind(windDirection)) < 0
end

return FireSpread
