--!strict
-- SinkingVessel: the flooding maths of a fishing boat taking water (docs/09 section 8.1, LU-3).
-- One pure state stepped by the server scene and readable on the client: water rises while the
-- leak is open; the salvage pump only wins while the player keeps the handle rhythm (effort
-- decays when the beats stop); pushing the bung in is progress that never resets; the hull lists
-- and settles as the bilge fills. The crew leave before she goes. Lune-tested:
-- tests/SinkingVessel.spec.luau.
export type State = {
	flood: number, -- 0..1 of the useful bilge volume; >= 1 = she is gone
	list: number, -- radians of roll toward the leak (slosh included)
	elapsed: number, -- seconds since she was holed
	pump: boolean, -- the salvage pump is aboard and running
	pumpEffort: number, -- 0..1, how well the handle rhythm is being kept
	strokes: number, -- on-beat pump strokes (never falls)
	plug: number, -- 0..1, how far the bung is pushed in (never falls)
	plugging: boolean, -- the player is holding the bung in
	plugged: boolean, -- the leak is plugged or patched
	crew: number, -- people still aboard
	sunk: boolean,
}

export type Actions = {
	pump: boolean?,
	beat: boolean?, -- an on-beat pump stroke this step
	plug: boolean?, -- holding the bung in this step
	plugged: boolean?,
}

local SinkingVessel = {}

-- Tune: about a minute from holed to gone if nobody acts; the pump wins in about 24 strokes
-- (23 s with the lead-in), and pushing the bung in takes 18 s. Both are deliberately forgiving:
-- a missed beat or a released bung only pauses progress, it never resets it.
SinkingVessel.Rates = table.freeze({
	StartFlood = 0.18,
	Inflow = 1 / 55, -- fraction/s through the open leak
	PluggedInflow = 1 / 400, -- a plug still weeps a little
	Pump = 1 / 40, -- fraction/s over the side at full rhythm
	PumpFloor = 0.55, -- share of the pump's pull with hands off the handle
	BeatEffort = 0.45, -- effort per on-beat stroke
	EffortDecay = 0.2, -- effort/s lost between beats
	Beat = 0.9, -- seconds per pump beat
	PumpStrokes = 24, -- on-beat strokes to empty her (client mechanic)
	PlugSeconds = 18, -- seconds of holding to push the bung home
	ListStart = math.rad(2),
	ListMax = math.rad(17),
	Slosh = math.rad(1.6), -- roll wobble at full flood
	SettleMax = 4.5, -- studs the hull drops by the time she is gone
	Abandon = 0.62, -- flood at which the crew should already be off
	Crew = 3,
})

function SinkingVessel.new(flood: number?): State
	local f = math.clamp(flood or SinkingVessel.Rates.StartFlood, 0, 1)
	return {
		flood = f,
		list = SinkingVessel.Rates.ListStart
			+ (SinkingVessel.Rates.ListMax - SinkingVessel.Rates.ListStart) * f,
		elapsed = 0,
		pump = false,
		pumpEffort = 0,
		strokes = 0,
		plug = 0,
		plugging = false,
		plugged = false,
		crew = SinkingVessel.Rates.Crew,
		sunk = f >= 1,
	}
end

-- Inflow at the current leak state, fraction/s.
function SinkingVessel.inflow(state: State): number
	return if state.plugged then SinkingVessel.Rates.PluggedInflow else SinkingVessel.Rates.Inflow
end

-- Net rise (positive) or fall (negative), fraction/s.
function SinkingVessel.net(state: State): number
	local out = 0
	if state.pump then
		local R = SinkingVessel.Rates
		out = R.Pump * (R.PumpFloor + (1 - R.PumpFloor) * math.clamp(state.pumpEffort, 0, 1))
	end
	return SinkingVessel.inflow(state) - out
end

-- One on-beat pump stroke: the hands are on the handle and the effort rises. Never falls.
function SinkingVessel.beat(state: State)
	state.pump = true
	state.strokes += 1
	state.pumpEffort = math.min(1, state.pumpEffort + SinkingVessel.Rates.BeatEffort)
end

-- One time step. The pump and plug states persist until changed; a settled hull stays sunk.
function SinkingVessel.step(state: State, dt: number, actions: Actions?): State
	if dt <= 0 then
		return state
	end
	local R = SinkingVessel.Rates
	state.pumpEffort = math.max(0, state.pumpEffort - R.EffortDecay * dt)
	if actions then
		if actions.pump ~= nil then
			state.pump = actions.pump
		end
		if actions.plug ~= nil then
			state.plugging = actions.plug
		end
		if actions.plugged ~= nil then
			state.plugged = actions.plugged
			if actions.plugged then
				state.plug = 1
			end
		end
		if actions.beat then
			SinkingVessel.beat(state)
		end
	end
	if state.plugging and not state.plugged then
		state.plug = math.min(1, state.plug + dt / R.PlugSeconds)
		if state.plug >= 1 then
			state.plugged = true
			state.plugging = false
		end
	end
	state.flood = math.clamp(state.flood + SinkingVessel.net(state) * dt, 0, 1.25)
	state.elapsed += dt
	state.sunk = state.sunk or state.flood >= 1
	local f = math.clamp(state.flood, 0, 1)
	state.list = R.ListStart
		+ (R.ListMax - R.ListStart) * f
		+ math.sin(state.elapsed * 1.3) * R.Slosh * f
	return state
end

-- Has the rhythm emptied her (the client finishes the step here)?
function SinkingVessel.pumpDone(state: State): boolean
	return state.strokes >= SinkingVessel.Rates.PumpStrokes
end

-- How far the bung is pushed home, 0..1.
function SinkingVessel.plugProgress(state: State): number
	return math.clamp(state.plug, 0, 1)
end

-- Studs the hull has settled below her good waterline.
function SinkingVessel.settle(state: State): number
	return math.clamp(state.flood, 0, 1) * SinkingVessel.Rates.SettleMax
end

function SinkingVessel.waterline(state: State): number
	return math.clamp(state.flood, 0, 1)
end

-- The crew should be off by here (the cabin roof is awash soon after).
function SinkingVessel.abandoned(state: State): boolean
	return state.flood >= SinkingVessel.Rates.Abandon
end

-- Is the water falling (pump or plug winning)?
function SinkingVessel.recovering(state: State): boolean
	return SinkingVessel.net(state) < 0
end

-- Seconds until she is gone at the current rates (math.huge while the water falls).
function SinkingVessel.timeToSink(state: State): number
	local net = SinkingVessel.net(state)
	if net <= 0 then
		return math.huge
	end
	return math.max(1 - state.flood, 0) / net
end

-- Seconds until the crew must be off (math.huge while the water falls).
function SinkingVessel.timeToAbandon(state: State): number
	local net = SinkingVessel.net(state)
	if net <= 0 then
		return math.huge
	end
	return math.max(SinkingVessel.Rates.Abandon - state.flood, 0) / net
end

return SinkingVessel
