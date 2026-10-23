--!strict
-- StreakRules: pure daily streak maths (docs/15 section 1 and hook H5), tested in
-- tests/Streak.spec.luau. A crate is available once per UTC day; days index from the Unix epoch.
--
-- The state lives in data.flags.streak as a flat table (ProgressionRules sanitizes flags that way):
-- d = last claimed UTC day index (0 = never), s = day in the 7-day cycle (0..7), c = the day
-- index of the last day-7 cosmetic grant (0 = none).
--
-- Forgiving (hard rule, docs/15 section 1): one missed day is free (a "calm day"); a longer break
-- drops the streak back three days, never to zero. Away more than 3 days turns the crate into the
-- bigger welcome-back crate once, paying its bonus on top of that day's Cash.

local Config = require(script.Parent.Config.StreakConfig)

export type State = { lastDay: number, streak: number, cosmeticDay: number }

export type Claim = {
	day: number,
	streak: number,
	cash: number,
	welcome: boolean,
	calm: boolean,
	cosmeticDay: number?, -- set on a day-7 claim
	state: State,
}

export type Preview = {
	day: number,
	streak: number,
	cash: number,
	welcome: boolean,
	calm: boolean,
}

local StreakRules = {}

function StreakRules.dayIndex(unix: number): number
	return math.floor(unix / 86400)
end

function StreakRules.secondsToDay(unix: number): number
	return (StreakRules.dayIndex(unix) + 1) * 86400 - unix
end

function StreakRules.newState(): State
	return { lastDay = 0, streak = 0, cosmeticDay = 0 }
end

function StreakRules.fromFlagTable(raw: any): State
	if type(raw) ~= "table" then
		return StreakRules.newState()
	end
	return {
		lastDay = math.max(0, math.floor(tonumber(raw.d) or 0)),
		streak = math.clamp(math.floor(tonumber(raw.s) or 0), 0, Config.WeekDays),
		cosmeticDay = math.max(0, math.floor(tonumber(raw.c) or 0)),
	}
end

function StreakRules.flagTable(state: State): { [string]: any }
	return { d = state.lastDay, s = state.streak, c = state.cosmeticDay }
end

function StreakRules.available(state: State, now: number): boolean
	return state.lastDay < StreakRules.dayIndex(now)
end

-- The tier today's claim takes (1..7) and how the break is treated: welcome-back, calm day.
local function nextDay(state: State, now: number): (number, boolean, boolean)
	local gap = StreakRules.dayIndex(now) - state.lastDay
	if state.lastDay == 0 then
		return 1, false, false
	end
	if gap <= 1 then
		return state.streak % Config.WeekDays + 1, false, false
	end
	if gap == 2 then
		return state.streak % Config.WeekDays + 1, false, true -- exactly one missed day: calm
	end
	return math.max(1, state.streak - 3), gap >= 4, false
end

function StreakRules.preview(state: State, now: number): Preview?
	if not StreakRules.available(state, now) then
		return nil
	end
	local tier, welcome, calm = nextDay(state, now)
	return {
		day = StreakRules.dayIndex(now),
		streak = tier,
		cash = Config.DayCash[tier] + (if welcome then Config.WelcomeCash else 0),
		welcome = welcome,
		calm = calm,
	}
end

function StreakRules.claim(state: State, now: number): Claim?
	local preview = StreakRules.preview(state, now)
	if not preview then
		return nil
	end
	local cosmeticDay: number? = nil
	if preview.streak == Config.WeekDays then
		cosmeticDay = preview.day
	end
	return {
		day = preview.day,
		streak = preview.streak,
		cash = preview.cash,
		welcome = preview.welcome,
		calm = preview.calm,
		cosmeticDay = cosmeticDay,
		state = {
			lastDay = preview.day,
			streak = preview.streak,
			cosmeticDay = cosmeticDay or state.cosmeticDay,
		},
	}
end

return StreakRules
