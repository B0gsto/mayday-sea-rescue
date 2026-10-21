--!strict
-- NotifyDue: pure timing for the "come back" notifications (G49). The server writes one small
-- profile entry when an opted-in player leaves; tools/notify.py reads it with the Open Cloud
-- DataStores API and sends at most one notification per player per 24 h. No game server runs while
-- the player is offline.
--
-- Entry shape (JSON in the `NotifyDue` DataStore, key = userId):
--   c = UTC second the next daily crate is ready (StreakRules)
--   b = UTC second the station strongbox is full (IdleIncome)
--   l = UTC second we last sent them a notification (updated by the sender)
--
-- The sender picks the crate first when both are due: it repeats daily, while a full strongbox
-- stays due forever and would otherwise starve the crate.

local IdleIncome = require(script.Parent.IdleIncome)
local StreakRules = require(script.Parent.StreakRules)

export type Entry = { c: number, b: number, l: number }
export type Kind = "crate_ready" | "strongbox_full"

local DAY = 86400

local NotifyDue = {}

NotifyDue.STORE = "NotifyDue"
NotifyDue.COOLDOWN = DAY
NotifyDue.KINDS = table.freeze({ "crate_ready", "strongbox_full" })

-- Ready now when today's crate is unclaimed, else the next UTC midnight.
function NotifyDue.nextCrateAt(streakFlag: any, now: number): number
	if StreakRules.available(StreakRules.fromFlagTable(streakFlag), now) then
		return math.floor(now)
	end
	return (StreakRules.dayIndex(now) + 1) * DAY
end

-- A full pot is due now; otherwise when IdleIncome says it fills.
function NotifyDue.strongboxAt(stationFlag: any, now: number): number
	local levels, pot = IdleIncome.fromFlag(stationFlag)
	return math.floor(now + IdleIncome.preview(pot, levels, now).secondsToFull)
end

function NotifyDue.entry(streakFlag: any, stationFlag: any, now: number, lastAt: any): Entry
	return {
		c = NotifyDue.nextCrateAt(streakFlag, now),
		b = NotifyDue.strongboxAt(stationFlag, now),
		l = math.max(0, math.floor(tonumber(lastAt) or 0)),
	}
end

-- Which message a due entry should get; nil when neither is due.
function NotifyDue.kindFor(entry: Entry, now: number): Kind?
	if entry.c <= now then
		return "crate_ready"
	end
	if entry.b <= now then
		return "strongbox_full"
	end
	return nil
end

-- At most one notification per player per 24 h (the fair-rules cap).
function NotifyDue.canSend(entry: Entry, now: number): boolean
	return NotifyDue.kindFor(entry, now) ~= nil and now - entry.l >= DAY
end

return NotifyDue
