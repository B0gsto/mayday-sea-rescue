--!strict
-- EventClock: the server-clock events (docs/15 H1), pure and shared.
--   GreatStorm  every hour at :00 UTC, 120 s warning then 240 s active (the Great Storm phase)
--   GhostLight  every 3 hours at :30 UTC, 600 s active (night fog and the lost boat)
-- Times are UTC epoch seconds (os.time), so every server and client agrees. A "phase" is
-- "Before" (the warning / countdown), "Active" (the event) or "Idle".

export type EventDef = {
	id: string,
	period: number, -- seconds between starts
	offset: number, -- seconds into the period of a start (:00 or :30)
	warning: number, -- seconds before the start counted as Before
	length: number, -- seconds of Active
}

export type Phase = "Idle" | "Before" | "Active"

export type Current = {
	id: string,
	phase: Phase,
	startAt: number,
	endsAt: number, -- end of Before (the start) or of Active
}

local EventClock = {}

EventClock.Events = table.freeze({
	GreatStorm = table.freeze({
		id = "GreatStorm",
		period = 3600,
		offset = 0,
		warning = 120,
		length = 240,
	}),
	GhostLight = table.freeze({
		id = "GhostLight",
		period = 3 * 3600,
		offset = 30 * 60,
		warning = 0,
		length = 600,
	}),
} :: { [string]: EventDef })

EventClock.Order = table.freeze({ "GreatStorm", "GhostLight" })

-- The scheduled start at or before `now`.
function EventClock.startAt(id: string, now: number): number
	local def = EventClock.Events[id]
	local block = math.floor(now / def.period) * def.period
	local start = block + def.offset
	if start > now then
		start -= def.period
	end
	return start
end

-- The next scheduled start strictly after `now`.
function EventClock.nextStart(id: string, now: number): number
	return EventClock.startAt(id, now) + EventClock.Events[id].period
end

-- The Before or Active window containing `now`: (start, boundary), or nil when Idle.
-- The boundary is the event start in Before and the event end in Active.
function EventClock.window(id: string, now: number): (number?, number?)
	local def = EventClock.Events[id]
	local last = EventClock.startAt(id, now)
	if now < last + def.length then
		return last, last + def.length
	end
	local nextStart = last + def.period
	if now >= nextStart - def.warning then
		return nextStart, nextStart
	end
	return nil, nil
end

function EventClock.phase(id: string, now: number): Phase
	local start = EventClock.window(id, now)
	if start == nil then
		return "Idle"
	end
	return if now < start then "Before" else "Active"
end

-- Seconds left in Before (to the start) or Active (to the end); nil when Idle.
function EventClock.countdown(id: string, now: number): number?
	local _, boundary = EventClock.window(id, now)
	return if boundary then boundary - now else nil
end

function EventClock.isActive(id: string, now: number): boolean
	return EventClock.phase(id, now) == "Active"
end

-- Seasonal windows (docs/15 H7): an inclusive UTC date range, not a periodic event. The seasonal
-- config owns the dates; this only answers live / time left, on the same clock as the events above.
export type Season = { id: string, startAt: number, endsAt: number }

function EventClock.inSeason(season: Season, now: number): boolean
	return now >= season.startAt and now <= season.endsAt
end

function EventClock.seasonEndsIn(season: Season, now: number): number
	return math.max(0, season.endsAt - now)
end

-- The event in Before or Active right now (they never overlap).
function EventClock.current(now: number): Current?
	for _, id in EventClock.Order do
		local start, boundary = EventClock.window(id, now)
		if start and boundary then
			return {
				id = id,
				phase = if now < start then "Before" else "Active",
				startAt = start,
				endsAt = boundary,
			}
		end
	end
	return nil
end

return EventClock
