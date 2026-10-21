--!strict
-- ChallengeRules: pure daily/weekly challenge logic (docs/03 section 9, LU-1), tested in
-- tests/Challenges.spec.luau. ChallengeService owns the profile field and the OperationCompleted
-- crediting; this module owns the roll, the counters, rerolls, rewards and the persisted encoding.
--
-- A profile's state lives in data.flags.challenges as a flat table of scalars (ProgressionRules
-- sanitizes flags that way): p/w = UTC day and week index, d1..d3/dp1..dp3 = daily ids and progress,
-- w1..w5/wp1..wp5 = weekly ids and progress, r = rerolls used today, s = weekly stamps,
-- b/t = the daily set bonus and the weekly stamp already paid. Unfinished challenges expire.
--
-- Monthly stamps live beside it in data.flags.challengeMonth ({ month = "YYYY-MM", stamps = n }),
-- so the challenges flag stays inside ProgressionRules' 24-field cap; the fourth stamp sets
-- data.flags.monthlyLivery to that month key (ChallengeService; visuals are another package's).

local Config = require(script.Parent.Config.ChallengeConfig)

export type ChallengeDef = Config.ChallengeDef

export type Slot = { id: string, progress: number }

export type State = {
	day: number,
	week: number,
	daily: { Slot },
	weekly: { Slot },
	rerolls: number,
	stamps: number,
	dailyBonus: boolean,
	weeklyStamp: boolean,
}

export type Counts = { [string]: number }

export type Settled = {
	dailyBonus: boolean,
	weeklyStamp: boolean,
}

export type Month = { month: string, stamps: number }

export type SlotView = { id: string, progress: number, target: number, done: boolean }

export type View = {
	daily: { SlotView },
	weekly: { SlotView },
	rerolls: number,
	rerollLimit: number,
	stamps: number,
	dailyBonus: boolean,
	secondsToDay: number,
	secondsToWeek: number,
}

local WEEK = 7 * 86400
local FIRST_MONDAY = 4 * 86400 -- 1970-01-01 was a Thursday; Monday 1970-01-05 starts week 0

local BY_ID: { [string]: ChallengeDef } = {}
for _, def in Config.Pool do
	BY_ID[def.id] = def
end

local ChallengeRules = {}

function ChallengeRules.dayIndex(unix: number): number
	return math.floor(unix / 86400)
end

function ChallengeRules.weekIndex(unix: number): number
	return math.floor((unix - FIRST_MONDAY) / WEEK)
end

function ChallengeRules.secondsToDay(unix: number): number
	return (ChallengeRules.dayIndex(unix) + 1) * 86400 - unix
end

function ChallengeRules.secondsToWeek(unix: number): number
	return (ChallengeRules.weekIndex(unix) + 1) * WEEK + FIRST_MONDAY - unix
end

-- The UTC calendar month, e.g. "2026-09".
function ChallengeRules.monthKey(unix: number): string
	return os.date("!%Y-%m", unix) :: string
end

-- A month's weekly stamps from data.flags.challengeMonth; a new month starts at zero.
function ChallengeRules.monthly(raw: any, now: number): Month
	local month = ChallengeRules.monthKey(now)
	if type(raw) ~= "table" or raw.month ~= month then
		return { month = month, stamps = 0 }
	end
	return { month = month, stamps = math.max(0, math.floor(tonumber(raw.stamps) or 0)) }
end

-- Adds one weekly stamp to this month; true once the month holds four (that month's livery).
function ChallengeRules.monthlyStamp(raw: any, now: number): (Month, boolean)
	local month = ChallengeRules.monthly(raw, now)
	month.stamps += 1
	return month, month.stamps >= 4
end

function ChallengeRules.def(id: any): ChallengeDef?
	return if type(id) == "string" then BY_ID[id] else nil
end

local function poolFor(scope: string): { ChallengeDef }
	local out: { ChallengeDef } = {}
	for _, def in Config.Pool do
		if def.scope == scope then
			table.insert(out, def)
		end
	end
	table.sort(out, function(a: ChallengeDef, b: ChallengeDef): boolean
		return a.id < b.id
	end)
	return out
end

local DAILY_POOL = poolFor("daily")
local WEEKLY_POOL = poolFor("weekly")

local function nextSeed(seed: number): number
	return (seed * 48271) % 2147483647
end

local function seedFor(userId: number, period: number, salt: number): number
	local s = (math.abs(math.floor(userId)) % 2147483647) + period * 7717 + salt * 104729
	return s % 2147483646 + 1
end

-- A deterministic sample of `count` ids from the scope's pool (same player, period and salt:
-- the same challenges on every server).
function ChallengeRules.roll(scope: string, count: number, seed: number): { string }
	local arr = if scope == "weekly" then table.clone(WEEKLY_POOL) else table.clone(DAILY_POOL)
	local s = seed
	for i = #arr, 2, -1 do
		s = nextSeed(s)
		local j = s % i + 1
		arr[i], arr[j] = arr[j], arr[i]
	end
	local out = {}
	for i = 1, math.min(count, #arr) do
		out[i] = arr[i].id
	end
	return out
end

local function slotsFrom(ids: { string }): { Slot }
	local out = {}
	for _, id in ids do
		table.insert(out, { id = id, progress = 0 })
	end
	return out
end

function ChallengeRules.newState(userId: number, now: number): State
	local day, week = ChallengeRules.dayIndex(now), ChallengeRules.weekIndex(now)
	local daily = ChallengeRules.roll("daily", Config.DailyCount, seedFor(userId, day, 1))
	local weekly = ChallengeRules.roll("weekly", Config.WeeklyCount, seedFor(userId, week, 2))
	return {
		day = day,
		week = week,
		daily = slotsFrom(daily),
		weekly = slotsFrom(weekly),
		rerolls = 0,
		stamps = 0,
		dailyBonus = false,
		weeklyStamp = false,
	}
end

local function cleanProgress(value: any): Slot?
	if type(value) ~= "table" or type(value.id) ~= "string" then
		return nil
	end
	local def = BY_ID[value.id]
	if not def then
		return nil
	end
	local progress = tonumber(value.progress) or 0
	return { id = value.id, progress = math.clamp(math.floor(progress), 0, def.target) }
end

local function cleanSlots(raw: any, scope: string, wanted: number): { Slot }?
	if type(raw) ~= "table" or #raw ~= wanted then
		return nil
	end
	local out: { Slot } = {}
	for _, value in raw do
		local slot = cleanProgress(value)
		if not slot or BY_ID[slot.id].scope ~= scope then
			return nil
		end
		table.insert(out, slot)
	end
	return out
end

-- Accepts a previous State (or its persisted flag table via fromFlagTable), rolls anything missing
-- or stale, and returns the state plus whether it differs from the input.
function ChallengeRules.ensure(raw: any, userId: number, now: number): (State, boolean)
	local day, week = ChallengeRules.dayIndex(now), ChallengeRules.weekIndex(now)
	if type(raw) ~= "table" then
		return ChallengeRules.newState(userId, now), true
	end
	local dayChanged = tonumber(raw.day) ~= day
	local weekChanged = tonumber(raw.week) ~= week
	local daily = if dayChanged then nil else cleanSlots(raw.daily, "daily", Config.DailyCount)
	local weekly = if weekChanged then nil else cleanSlots(raw.weekly, "weekly", Config.WeeklyCount)
	local state: State = {
		day = day,
		week = week,
		daily = daily or {},
		weekly = weekly or {},
		rerolls = if dayChanged then 0 else math.max(0, math.floor(tonumber(raw.rerolls) or 0)),
		stamps = math.max(0, math.floor(tonumber(raw.stamps) or 0)),
		dailyBonus = if dayChanged then false else raw.dailyBonus == true,
		weeklyStamp = if weekChanged then false else raw.weeklyStamp == true,
	}
	if not daily then
		state.daily = ChallengeRules.newState(userId, now).daily
		state.rerolls = 0
		state.dailyBonus = false
	end
	if not weekly then
		state.weekly = ChallengeRules.newState(userId, now).weekly
		state.weeklyStamp = false
	end
	return state, dayChanged or weekChanged or daily == nil or weekly == nil
end

-- Flat flag table for data.flags.challenges (ProgressionRules.sanitizeFlag takes flat scalars).
function ChallengeRules.flagTable(state: State): { [string]: any }
	local out: { [string]: any } = {
		p = state.day,
		w = state.week,
		r = state.rerolls,
		s = state.stamps,
		b = state.dailyBonus,
		t = state.weeklyStamp,
	}
	for i, slot in state.daily do
		out[`d{i}`] = slot.id
		out[`dp{i}`] = slot.progress
	end
	for i, slot in state.weekly do
		out[`w{i}`] = slot.id
		out[`wp{i}`] = slot.progress
	end
	return out
end

function ChallengeRules.fromFlagTable(raw: any): any
	if type(raw) ~= "table" then
		return nil
	end
	local daily, weekly = {}, {}
	for i = 1, Config.DailyCount do
		local id = raw[`d{i}`]
		if type(id) == "string" then
			table.insert(daily, { id = id, progress = tonumber(raw[`dp{i}`]) or 0 })
		end
	end
	for i = 1, Config.WeeklyCount do
		local id = raw[`w{i}`]
		if type(id) == "string" then
			table.insert(weekly, { id = id, progress = tonumber(raw[`wp{i}`]) or 0 })
		end
	end
	return {
		day = tonumber(raw.p) or 0,
		week = tonumber(raw.w) or 0,
		daily = daily,
		weekly = weekly,
		rerolls = tonumber(raw.r) or 0,
		stamps = tonumber(raw.s) or 0,
		dailyBonus = raw.b == true or raw.b == 1,
		weeklyStamp = raw.t == true or raw.t == 1,
	}
end

-- A completed operation's counters for one helper. The caller only calls this for helpers.
function ChallengeRules.operationCredit(snap: any, userId: number, crewSize: number): Counts
	local out: Counts = {}
	if type(snap) ~= "table" then
		return out
	end
	local grade = snap.grade
	if grade == "Fail" or grade == "Takeover" then
		return out
	end
	out.ops = 1
	if type(snap.kind) == "string" then
		out[`op:{snap.kind}`] = 1
	end
	if snap.storm == true then
		out.stormOps = 1
	end
	if snap.isBig == true then
		out.bigCalls = 1
	end
	if crewSize >= 2 then
		out.crewOps = 1
	end
	if snap.kind == "DisabledVessel" and snap.towParted ~= true then
		out.tows = 1
	end
	local saved = tonumber(snap.saved) or 0
	if saved > 0 then
		out.rescues = math.floor(saved)
	end
	if type(snap.steps) == "table" then
		for _, step in snap.steps do
			if type(step) == "table" and step.userId == userId and step.grade ~= "Fail" then
				if step.grade == "Gold" then
					out.goldSteps = (out.goldSteps or 0) + 1
				end
				if step.id == "search" then
					out.finds = (out.finds or 0) + 1
				elseif step.id == "treatment" then
					out.treatments = (out.treatments or 0) + 1
				end
			end
		end
	end
	return out
end

function ChallengeRules.slotDone(slot: Slot): boolean
	local def = BY_ID[slot.id]
	return def ~= nil and slot.progress >= def.target
end

function ChallengeRules.allDone(slots: { Slot }): boolean
	if #slots == 0 then
		return false
	end
	for _, slot in slots do
		if not ChallengeRules.slotDone(slot) then
			return false
		end
	end
	return true
end

-- Adds counters (mutates state); returns the definitions completed by this call, once each.
function ChallengeRules.addProgress(state: State, counts: Counts): { ChallengeDef }
	local newly: { ChallengeDef } = {}
	local function credit(slots: { Slot })
		for _, slot in slots do
			local def = BY_ID[slot.id]
			if not def then
				continue
			end
			local amount = counts[def.stat]
			if type(amount) == "number" and amount > 0 then
				local before = slot.progress
				slot.progress = math.min(def.target, slot.progress + math.floor(amount))
				if before < def.target and slot.progress >= def.target then
					table.insert(newly, def)
				end
			end
		end
	end
	credit(state.daily)
	credit(state.weekly)
	return newly
end

-- Marks the daily set bonus and the weekly stamp once each (mutates state).
function ChallengeRules.settle(state: State): Settled
	local out: Settled = { dailyBonus = false, weeklyStamp = false }
	if not state.dailyBonus and ChallengeRules.allDone(state.daily) then
		state.dailyBonus = true
		out.dailyBonus = true
	end
	if not state.weeklyStamp and ChallengeRules.allDone(state.weekly) then
		state.weeklyStamp = true
		state.stamps += 1
		out.weeklyStamp = true
	end
	return out
end

-- Swaps the first unfinished daily challenge for another from the pool (mutates state). Returns the
-- new id, or nil when every daily challenge is done or nothing is left to swap in.
function ChallengeRules.rerollDaily(state: State, userId: number, now: number): string?
	if state.rerolls >= Config.RerollDailyLimit then
		return nil
	end
	local index: number? = nil
	for i, slot in state.daily do
		if not ChallengeRules.slotDone(slot) then
			index = i
			break
		end
	end
	if not index then
		return nil
	end
	local current: { [string]: boolean } = {}
	for _, slot in state.daily do
		current[slot.id] = true
	end
	local candidates: { ChallengeDef } = {}
	for _, def in DAILY_POOL do
		if not current[def.id] then
			table.insert(candidates, def)
		end
	end
	if #candidates == 0 then
		return nil
	end
	local s = nextSeed(seedFor(userId, ChallengeRules.dayIndex(now), 100 + state.rerolls))
	local picked = candidates[s % #candidates + 1]
	state.daily[index] = { id = picked.id, progress = 0 }
	state.rerolls += 1
	state.dailyBonus = false -- a swapped-in challenge is not done yet
	return picked.id
end

function ChallengeRules.rewardFor(def: ChallengeDef, rankIndex: number): (number, number)
	local bases = Config.ZoneBase
	local rank = math.max(1, math.floor(rankIndex))
	local base = bases[1]
	for _, row in bases do
		if rank >= row.rank then
			base = row
		end
	end
	local mult = if def.scope == "weekly" then Config.WeeklyReward else Config.DailyReward
	return math.floor(base.cash * mult.cash + 0.5), math.floor(base.rep * mult.rep + 0.5)
end

local function viewOf(slots: { Slot }): { SlotView }
	local out: { SlotView } = {}
	for _, slot in slots do
		local def = BY_ID[slot.id]
		table.insert(out, {
			id = slot.id,
			progress = slot.progress,
			target = def.target,
			done = slot.progress >= def.target,
		})
	end
	return out
end

function ChallengeRules.view(state: State, now: number): View
	return {
		daily = viewOf(state.daily),
		weekly = viewOf(state.weekly),
		rerolls = state.rerolls,
		rerollLimit = Config.RerollDailyLimit,
		stamps = state.stamps,
		dailyBonus = state.dailyBonus,
		secondsToDay = ChallengeRules.secondsToDay(now),
		secondsToWeek = ChallengeRules.secondsToWeek(now),
	}
end

return ChallengeRules
