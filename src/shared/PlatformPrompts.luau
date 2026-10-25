--!strict
-- PlatformPrompts: pure policy for Roblox's own re-engagement prompts (docs/15 hooks, fair rules).
-- Three prompts, at good moments only: notifications after a daily crate, favourite after the first
-- island building, invite after the first crew rescue. Never on an operation, never in the first 3 minutes
-- of a session, never two prompts within 10 minutes. Asked timestamps live in the profile
-- (data.flags.platformPrompts) so a decline is respected across sessions.
local PlatformPrompts = {}

PlatformPrompts.MIN_SESSION = 180 -- s before any prompt
PlatformPrompts.GAP = 600 -- s between any two prompts
PlatformPrompts.NOTIFY_RETRY = 7 * 86400 -- a declined notification opt-in is re-offered weekly
PlatformPrompts.KINDS = table.freeze({ "notify", "favorite", "invite" })

export type Kind = "notify" | "favorite" | "invite"

export type State = {
	notify: number?,
	favorite: number?,
	invite: number?,
	last: number?,
}

-- The save sanitiser clamps one flag field to +/-1e6 (ProgressionRules), so an epoch timestamp
-- cannot be stored. Each ask is two small fields instead: UTC day index + second of that day.
local DAY = 86400

function PlatformPrompts.isKind(kind: any): boolean
	return type(kind) == "string" and table.find(PlatformPrompts.KINDS, kind) ~= nil
end

local function stamp(value: any): number?
	if
		type(value) == "number"
		and value == value
		and value >= 0
		and math.abs(value) < math.huge
	then
		return math.floor(value)
	end
	return nil
end

local function unpackAt(raw: any, dayKey: string, secondKey: string): number?
	local day = stamp(raw[dayKey])
	if not day then
		return nil
	end
	return day * DAY + (stamp(raw[secondKey]) or 0)
end

local function packAt(out: { [string]: number }, at: number?, dayKey: string, secondKey: string)
	if not at then
		return
	end
	out[dayKey] = math.floor(at / DAY)
	out[secondKey] = at % DAY
end

-- Flat table in the save (one flag, eight small scalar fields), like every other retention flag.
function PlatformPrompts.decode(raw: any): State
	if type(raw) ~= "table" then
		return {}
	end
	return {
		notify = unpackAt(raw, "nd", "ns"),
		favorite = unpackAt(raw, "fd", "fs"),
		invite = unpackAt(raw, "id", "is"),
		last = unpackAt(raw, "ld", "ls"),
	}
end

function PlatformPrompts.encode(state: State): { [string]: number }
	local out: { [string]: number } = {}
	packAt(out, state.notify, "nd", "ns")
	packAt(out, state.favorite, "fd", "fs")
	packAt(out, state.invite, "id", "is")
	packAt(out, state.last, "ld", "ls")
	return out
end

-- true when `kind` may be offered now; the second value is the wait reason ("" when allowed).
function PlatformPrompts.allowed(
	kind: Kind,
	state: State,
	now: number,
	sessionSeconds: number,
	onOp: boolean
): (boolean, string)
	if onOp then
		return false, "op"
	end
	if sessionSeconds < PlatformPrompts.MIN_SESSION then
		return false, "session"
	end
	local last = state.last
	if last and now - last < PlatformPrompts.GAP then
		return false, "gap"
	end
	local asked = state[kind]
	if not asked then
		return true, ""
	end
	if kind == "notify" and now - asked >= PlatformPrompts.NOTIFY_RETRY then
		return true, ""
	end
	return false, "asked"
end

-- Marks `kind` as asked (offered), starting the global gap. Returns a new state.
function PlatformPrompts.record(state: State, kind: Kind, now: number): State
	local out: State = {
		notify = state.notify,
		favorite = state.favorite,
		invite = state.invite,
		last = now,
	}
	out[kind] = now
	return out
end

return PlatformPrompts
