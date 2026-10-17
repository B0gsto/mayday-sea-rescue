--!strict
-- Ops/Condition: the casualty condition meter (docs/09-rescue-operations.md section 2.2).
-- 0..100, the operation's clock. Pure: the server calls Condition.step every tick with the
-- environment, applies one-off events, and checks Condition.isCritical for the takeover (2.5).
local Types = require(script.Parent.Types)

type CasualtyState = Types.CasualtyState

export type Env = {
	storm: boolean?, -- storm sea state at the scene (kept until handover, docs 09 2.6)
	coldWater: boolean?,
}

local Condition = {}

-- Bands (tune). A value at or above `min` is in the band.
Condition.Bands = table.freeze({
	{ id = "Stable", min = 70, label = "OK" },
	{ id = "Concern", min = 40, label = "Struggling" },
	{ id = "Serious", min = 20, label = "Very cold" },
	{ id = "Critical", min = -math.huge, label = "Needs help now" },
})
Condition.CRITICAL = 20

-- Rates in condition points per second (tune).
Condition.Rates = table.freeze({
	WaterLifejacket = -1 / 5,
	WaterNoLifejacket = -1 / 3,
	OutWetWind = -1 / 10,
	Recovering = 1 / 10, -- surveyed, treated, sheltered
	VesselDrift = -1 / 6, -- disabled vessel drifting toward the rocks until the tow is on
	PanicMult = 1.5,
	StormMult = 1.5,
	ColdWaterMult = 1.25,
	UnsurveyedTreatmentMult = 0.5, -- treatment without a survey halves the decline, never stops it
})

-- One-off events (tune). A client mechanic reports them; the server applies them, capped per step.
Condition.Events = table.freeze({
	wash = -8, -- approached too fast, bow wave over the casualty
	slam = -3, -- hard slam in transport (only hurts a cold casualty)
	wrongHandling = -10, -- upright lift when hypothermic, rubbing limbs; once per casualty
	harmfulTreatment = -10,
})

local HYPOTHERMIC = { VeryCold = true, Unresponsive = true, Exhausted = true }

function Condition.new(
	id: string,
	state: string,
	lifejacket: boolean,
	start: number?
): CasualtyState
	local isVessel = state == "Vessel"
	return {
		id = id,
		state = state,
		condition = start
			or if state == "Alert" or isVessel then 90 elseif state == "Panicking" then 80 else 65,
		lifejacket = lifejacket,
		inWater = not isVessel,
		panicking = state == "Panicking",
		wet = not isVessel,
		sheltered = false,
		surveyed = false,
		treated = false,
		towed = false,
		delivered = false,
		takenOver = false,
		wrongHandled = false,
		tag = nil,
		claimedBy = nil,
	}
end

-- Points per second right now (negative = decline).
function Condition.rate(c: CasualtyState, env: Env?): number
	if c.delivered or c.takenOver then
		return 0
	end
	local e: Env = env or {}
	local R = Condition.Rates
	if c.state == "Vessel" then
		if c.towed then
			return 0
		end
		return R.VesselDrift * (if e.storm then R.StormMult else 1) * (c.driftScale or 1)
	end
	local rate: number
	if c.inWater then
		rate = if c.lifejacket then R.WaterLifejacket else R.WaterNoLifejacket
		if e.coldWater then
			rate *= R.ColdWaterMult
		end
	elseif c.treated and c.surveyed then
		return if c.sheltered then R.Recovering else 0
	elseif c.wet or not c.sheltered then
		rate = R.OutWetWind
	else
		rate = R.OutWetWind * 0.5
	end
	if c.treated and not c.surveyed then
		rate *= R.UnsurveyedTreatmentMult
	end
	if c.panicking then
		rate *= R.PanicMult
	end
	if e.storm then
		rate *= R.StormMult
	end
	return rate * (c.driftScale or 1)
end

-- Advances the meter by dt seconds. Returns the new value.
function Condition.step(c: CasualtyState, dt: number, env: Env?): number
	c.condition = math.clamp(c.condition + Condition.rate(c, env) * dt, 0, 100)
	return c.condition
end

-- Applies a one-off event `count` times. Returns the change.
function Condition.applyEvent(c: CasualtyState, event: string, count: number?): number
	local delta = Condition.Events[event]
	if not delta then
		return 0
	end
	local n = math.max(math.floor(count or 1), 0)
	if event == "slam" and not (HYPOTHERMIC[c.state] or c.condition < 40) then
		return 0 -- slams only cost a cold casualty
	end
	if event == "wrongHandling" then
		if c.wrongHandled then
			return 0
		end
		c.wrongHandled = true
		n = math.min(n, 1)
	end
	local before = c.condition
	c.condition = math.clamp(c.condition + delta * n, 0, 100)
	return c.condition - before
end

function Condition.band(value: number): string
	for _, b in Condition.Bands do
		if value >= b.min then
			return b.id
		end
	end
	return "Critical"
end

function Condition.label(value: number, state: string?): string
	local band = Condition.band(value)
	if band == "Serious" and state ~= "VeryCold" then
		return "Not responding well"
	end
	for _, b in Condition.Bands do
		if b.id == band then
			return b.label
		end
	end
	return "OK"
end

function Condition.isCritical(c: CasualtyState): boolean
	return c.condition < Condition.CRITICAL and not c.delivered and not c.takenOver
end

-- The takeover rule (docs 09 section 2.5): a casualty reaches Critical, or the cap passes.
function Condition.shouldTakeover(
	casualties: { CasualtyState },
	elapsed: number,
	capSeconds: number
): (boolean, string?)
	for _, c in casualties do
		if Condition.isCritical(c) then
			return true, "Critical"
		end
	end
	if elapsed > capSeconds then
		return true, "Cap"
	end
	return false, nil
end

-- Seconds until the meter reaches Critical at the current rate (math.huge when not declining).
function Condition.secondsToCritical(c: CasualtyState, env: Env?): number
	local r = Condition.rate(c, env)
	if r >= 0 then
		return math.huge
	end
	return math.max(c.condition - Condition.CRITICAL, 0) / -r
end

return Condition
