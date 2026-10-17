--!strict
-- PIW/Panic: a panicking casualty and the swimmer who calms them (docs 09 section 5.4).
-- Real basis: stop at arm's length, present a flotation aid (never your body), talk calmly in the
-- lulls of their splashing, approach from behind. Pure (Lune-tested).
local Units = require(script.Parent.Units)

local Panic = {}

Panic.ARM = Units.BODY_LENGTH -- one body length: inside this with high panic, they grab
Panic.GRAB_ABOVE = 40 -- panic level at which they climb onto a rescuer in reach
Panic.ACCEPT = 30 -- under this they take the presented tube
Panic.CALM_IN_LULL = 22
Panic.SHOUT_PENALTY = 7 -- talking over the splashing: they can't hear you; it reads as shouting
Panic.DRIFT_UP = 1.2 -- per second while nobody calms them
Panic.BEHIND = 115 -- deg from their facing: you are behind them

export type State = { level: number, period: number, lull: number, phase: number, tubeOut: boolean }

-- seed 0..1 varies their rhythm; assist widens the lull window (docs 09 2.7 "wider window").
function Panic.new(seed: number, assist: boolean, start: number?): State
	return {
		level = start or 95,
		period = 2.8 + seed * 1.4,
		lull = (if assist then 1.4 else 1.0),
		phase = seed * 3,
		tubeOut = false,
	}
end

-- Splashing in bursts with a short lull at the end of each burst.
function Panic.isLull(p: State, t: number): boolean
	local x = (t + p.phase) % p.period
	return x >= p.period - p.lull
end

-- A calm line ("I've got you", "Grab the float", "Lie back") said at t.
function Panic.say(p: State, t: number): boolean
	local lull = Panic.isLull(p, t)
	if lull then
		p.level = math.max(0, p.level - Panic.CALM_IN_LULL * (if p.tubeOut then 1.15 else 1))
	else
		p.level = math.min(100, p.level + Panic.SHOUT_PENALTY)
	end
	return lull
end

function Panic.step(p: State, dt: number, rushing: boolean)
	p.level = math.clamp(p.level + (Panic.DRIFT_UP + (if rushing then 6 else 0)) * dt, 0, 100)
end

-- Grab check for a swimmer at `distance` (studs) and `angleFromFacing` (deg, 0 = in front).
function Panic.grabs(p: State, distance: number, angleFromFacing: number): boolean
	if p.level < Panic.GRAB_ABOVE then
		return false
	end
	local reach = if angleFromFacing >= Panic.BEHIND then Panic.ARM * 0.55 else Panic.ARM
	return distance < reach
end

function Panic.accepts(p: State, distance: number): boolean
	return p.tubeOut and p.level < Panic.ACCEPT and distance <= Panic.ARM * 1.6
end

-- 0..1 score for a swimmer contact (recover_swimmer): fast calm, no grabs, approach from behind.
function Panic.contactScore(seconds: number, grabs: number, fromBehind: boolean): number
	local time = math.clamp(1 - (seconds - 12) / 30, 0, 1)
	return math.clamp(
		0.45 * time + 0.35 * (if fromBehind then 1 else 0.4) + 0.2 - 0.25 * grabs,
		0,
		1
	)
end

return Panic
