--!strict
-- LiveOps: owner-triggered live events across every server at once (docs/15 section 1 fair rules;
-- marketing/liveops.md). Pure and Lune-tested (tests/LiveOps.spec.luau): the message rules, the
-- pending/active window and which multipliers apply. The services only publish and read state.
--
--   GoldenHour     2x Cash and Rep from live awards (ProgressionService.Award's multiplier path;
--                  flat/passive awards stay flat)
--   CalmSeas       no new storms for the hour (kid-friendly, relaxed)
--
-- Messages carry { event, startsAt (UTC epoch seconds), duration (seconds), nonce }. The owner tool
-- also sends { event = "Cancel" } to clear the schedule. Fair rules: every benefit is free and
-- earnable by playing; nothing is sold (docs/15 section 1).
--
-- Rules: ignore unknown events, duplicate/old nonces (the service tracks those), startsAt more than
-- 7 days ahead, durations outside 1 minute..3 hours, and events already over. Only one LiveOps
-- event runs at a time; each multiplier is capped at x2 by LiveOps itself (the storm still stacks,
-- as it does for every other Cash multiplier).

export type EventId = "GoldenHour" | "CalmSeas"
export type Phase = "Idle" | "Pending" | "Active"

export type Message = {
	event: string,
	startsAt: number,
	duration: number,
	nonce: string,
}

export type State = {
	event: string,
	startsAt: number,
	duration: number,
	nonce: string,
}

export type EventDef = {
	id: string,
	label: string, -- 1-3 words on the board and the HUD chip
	icon: string, -- the client's drawn chip icon
	tint: Color3, -- the sky tint while active
	duration: number, -- the owner tool's default length, seconds
}

export type Multipliers = {
	cash: number,
	rep: number,
}

local LiveOps = {}

LiveOps.Topic = "LiveOps"
LiveOps.Map = "LiveOpsActive"
LiveOps.Key = "active"

LiveOps.MaxDuration = 3 * 3600 -- 3 h
LiveOps.MinDuration = 60 -- 1 min
LiveOps.MaxLead = 7 * 86400 -- 7 days ahead
LiveOps.MaxNonce = 64

-- The LiveOps contribution caps: one event at a time, so 2 is the ceiling for each benefit.
LiveOps.MaxCash = 2
LiveOps.MaxRep = 2

LiveOps.Events = table.freeze({
	GoldenHour = table.freeze({
		id = "GoldenHour",
		label = "Golden hour",
		icon = "sun",
		tint = Color3.fromRGB(255, 214, 150),
		duration = 60 * 60,
	}),
	CalmSeas = table.freeze({
		id = "CalmSeas",
		label = "Calm seas",
		icon = "wave",
		tint = Color3.fromRGB(176, 224, 240),
		duration = 60 * 60,
	}),
} :: { [string]: EventDef })

LiveOps.Order = table.freeze({ "GoldenHour", "CalmSeas" })

local function whole(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0
end

local function finite(value: number): boolean
	return value == value and value > -1e12 and value < 1e12
end

-- Whether a message may run: event, nonce, duration and lead time (docs/15: 7 days, 3 h).
-- Returns ok plus a short reason for logs. `"Cancel"` is the owner tool's clear command.
function LiveOps.validate(message: any, now: number): (boolean, string)
	if type(message) ~= "table" then
		return false, "shape"
	end
	local nonce = message.nonce
	if type(nonce) ~= "string" or nonce == "" or #nonce > LiveOps.MaxNonce then
		return false, "nonce"
	end
	local event = message.event
	if event == "Cancel" then
		return true, "cancel"
	end
	if type(event) ~= "string" or not LiveOps.Events[event] then
		return false, "event"
	end
	local startsAt, duration = message.startsAt, message.duration
	if not whole(startsAt) or not whole(duration) or not finite(startsAt) then
		return false, "number"
	end
	if duration < LiveOps.MinDuration or duration > LiveOps.MaxDuration then
		return false, "duration"
	end
	if startsAt - now > LiveOps.MaxLead then
		return false, "ahead"
	end
	if startsAt + duration <= now then
		return false, "over"
	end
	return true, "ok"
end

function LiveOps.fromMessage(message: Message): State
	return {
		event = message.event,
		startsAt = message.startsAt,
		duration = message.duration,
		nonce = message.nonce,
	}
end

function LiveOps.empty(): State
	return { event = "", startsAt = 0, duration = 0, nonce = "" }
end

function LiveOps.phase(state: State?, now: number): Phase
	if not state or state.event == "" or state.duration <= 0 then
		return "Idle"
	end
	if now < state.startsAt then
		return "Pending"
	end
	if now < state.startsAt + state.duration then
		return "Active"
	end
	return "Idle"
end

-- Seconds to the start while Pending, to the end while Active; nil when Idle.
function LiveOps.countdown(state: State?, now: number): number?
	local phase = LiveOps.phase(state, now)
	if phase == "Pending" then
		return (state :: State).startsAt - now
	elseif phase == "Active" then
		return (state :: State).startsAt + (state :: State).duration - now
	end
	return nil
end

function LiveOps.endsAt(state: State): number
	return state.startsAt + state.duration
end

function LiveOps.isActive(state: State?, id: string, now: number): boolean
	return state ~= nil and state.event == id and LiveOps.phase(state, now) == "Active"
end

-- The active event's multiplier contribution, 1 by default; never above the caps.
function LiveOps.multipliers(state: State?, now: number): Multipliers
	local out: Multipliers = { cash = 1, rep = 1 }
	if not state or LiveOps.phase(state, now) ~= "Active" then
		return out
	end
	if state.event == "GoldenHour" then
		out.cash = LiveOps.MaxCash
		out.rep = LiveOps.MaxRep
	end
	out.cash = math.min(out.cash, LiveOps.MaxCash)
	out.rep = math.min(out.rep, LiveOps.MaxRep)
	return out
end

-- A late or duplicated message must not replace a newer schedule (old nonces / old startsAt).
-- Cancel always wins; a new event may replace an ended or pending one only when it starts no
-- earlier than the schedule it replaces.
function LiveOps.supersedes(current: State?, message: Message, now: number): boolean
	if message.event == "Cancel" then
		return true
	end
	if not current or LiveOps.phase(current, now) == "Idle" then
		return true
	end
	return message.startsAt >= current.startsAt
end

return LiveOps
