--!strict
-- LeaderboardRules: pure leaderboard logic (Lune-tested in tests/Leaderboard.spec.luau) for
-- LeaderboardService: week numbering (Monday 00:00 UTC), store names, rescue credit from one
-- operation, pending-increment batching and the board's row text.

local BadgeConfig = require(script.Parent.Config.BadgeConfig)

export type Entry = { userId: number, value: number }
export type Row = { place: string, name: string, value: string }

local LeaderboardRules = {}

local WEEK = 7 * 86400
local FIRST_MONDAY = 4 * 86400 -- 1970-01-01 was a Thursday; Monday 1970-01-05 00:00 UTC starts week 0

function LeaderboardRules.weekIndex(unix: number): number
	return math.floor((unix - FIRST_MONDAY) / WEEK)
end

-- seconds until the next weekly reset
function LeaderboardRules.secondsToReset(unix: number): number
	local nextStart = (LeaderboardRules.weekIndex(unix) + 1) * WEEK + FIRST_MONDAY
	return nextStart - unix
end

function LeaderboardRules.storeName(board: BadgeConfig.Board, week: number): string
	local base = BadgeConfig.Leaderboard.storePrefix .. board.key
	return if board.weekly then `{base}_W{week}` else base
end

-- people rescued credited to one helper of a finished op: the op's saved count (a crew shares the credit,
-- docs/03 section 9.1 counts crew rescues as everyone's), ferry rescues when it was the big call
function LeaderboardRules.credit(saved: number, big: boolean, helper: boolean): { [string]: number }
	if not helper or saved <= 0 then
		return {}
	end
	local n = math.floor(saved)
	local out: { [string]: number } = { Rescued = n, RescuedAllTime = n }
	if big then
		out.FerryRescued = n
	end
	return out
end

-- adds increments into a pending table { [boardKey]: number } (mutated)
function LeaderboardRules.merge(pending: { [string]: number }, inc: { [string]: number })
	for k, v in inc do
		pending[k] = (pending[k] or 0) + v
	end
end

local function thousands(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
LeaderboardRules.thousands = thousands

-- names: userId -> display text (missing names show as "Crew member"); always `rows` rows, blanks padded
function LeaderboardRules.rows(
	entries: { Entry },
	names: { [number]: string },
	rows: number
): { Row }
	local out: { Row } = {}
	for i = 1, rows do
		local e = entries[i]
		if e then
			table.insert(out, {
				place = `{i}.`,
				name = names[e.userId] or "Crew member",
				value = thousands(e.value),
			})
		else
			table.insert(out, { place = `{i}.`, name = "", value = "" })
		end
	end
	return out
end

-- the board footer: whole days (or hours on the last day) to the weekly reset
function LeaderboardRules.resetText(unix: number): string
	local s = LeaderboardRules.secondsToReset(unix)
	if s >= 86400 then
		local d = math.floor(s / 86400)
		return if d == 1 then "Resets in 1 day" else `Resets in {d} days`
	end
	local h = math.max(1, math.ceil(s / 3600))
	return if h == 1 then "Resets within the hour" else `Resets in {h} hours`
end

return LeaderboardRules
