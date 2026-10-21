--!strict
-- IdleIncome: the station crew's capped Cash pot (docs/15 hook H6), pure in Lune
-- (tests/IdleIncome.spec.luau). The pot accrues in real time, online and offline, from the station
-- upgrade levels in StationConfig. A full pot stops filling; nothing is ever lost (fair FOMO,
-- docs/15 section 1).
--
-- The profile flag `station` is a flat table of scalars (ProgressionRules sanitizes flags that way):
--   w = workshop level, r = radio room level, k = kennel level,
--   d = UTC day index of the last accrual anchor, s = seconds into that day (0..86399),
--   c = Cash in the pot.
-- The anchor is split into day + seconds because flag numbers are clamped to +-1e6 and Unix
-- seconds are far past that.
--
-- Clock skew guard: a backwards clock never pays and never goes negative; the pot is always
-- clamped to 0..cap, and elapsed time is never more than real time.

local Config = require(script.Parent.Config.StationConfig)

export type Levels = { workshop: number, radio: number, kennel: number }
export type Pot = { lastAt: number, cash: number }
export type Rates = { rate: number, capHours: number, capCash: number }
export type Preview = {
	cash: number,
	rate: number,
	capHours: number,
	capCash: number,
	fill: number,
	full: boolean,
	secondsToFull: number,
}
export type Claim = { cash: number, pot: Pot }

local DAY = 86400

local IdleIncome = {}

local function level(raw: any): number
	return math.clamp(math.floor(tonumber(raw) or 0), 0, Config.MaxLevel)
end

local function number(raw: any): number
	local n = tonumber(raw) or 0
	if n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return n
end

function IdleIncome.newLevels(): Levels
	return { workshop = 0, radio = 0, kennel = 0 }
end

function IdleIncome.fromFlag(raw: any): (Levels, Pot)
	if type(raw) ~= "table" then
		return IdleIncome.newLevels(), { lastAt = 0, cash = 0 }
	end
	local levels: Levels = {
		workshop = level(raw.w),
		radio = level(raw.r),
		kennel = level(raw.k),
	}
	local day = math.max(0, math.floor(number(raw.d)))
	local seconds = math.clamp(number(raw.s), 0, DAY - 1)
	local lastAt = if day > 0 then day * DAY + seconds else 0
	return levels, { lastAt = lastAt, cash = math.max(0, number(raw.c)) }
end

function IdleIncome.toFlag(levels: Levels, pot: Pot): { [string]: any }
	local lastAt = math.max(0, math.floor(pot.lastAt))
	local day = math.floor(lastAt / DAY)
	return {
		w = level(levels.workshop),
		r = level(levels.radio),
		k = level(levels.kennel),
		d = day,
		s = lastAt - day * DAY,
		c = math.max(0, math.floor(pot.cash)),
	}
end

function IdleIncome.rates(levels: Levels): Rates
	local row = Config.Crew[level(levels.workshop) + 1]
	local rate = row.rate * (1 + Config.RadioRateBonus * level(levels.radio))
	local capHours = row.capHours + Config.KennelCapHoursBonus * level(levels.kennel)
	return { rate = rate, capHours = capHours, capCash = rate * capHours }
end

function IdleIncome.cost(levels: Levels): number?
	local nextLevel = level(levels.workshop) + 1
	if nextLevel > Config.MaxLevel then
		return nil
	end
	return Config.UpgradeCost[nextLevel]
end

-- The pot after real time `now` (Unix seconds). Always re-anchors to now: a full pot does not bank
-- missed time, it just stops filling.
function IdleIncome.accrue(pot: Pot, levels: Levels, now: number): Pot
	local rates = IdleIncome.rates(levels)
	local cash = math.clamp(number(pot.cash), 0, rates.capCash)
	local lastAt = if number(pot.lastAt) > 0 then number(pot.lastAt) else now
	if now < lastAt then
		lastAt = now -- clock skew: never negative, never pays for a backwards jump
	end
	local elapsed = math.max(0, now - lastAt)
	if elapsed > 0 and rates.rate > 0 and cash < rates.capCash then
		cash = math.min(rates.capCash, cash + rates.rate * elapsed / 3600)
	end
	return { lastAt = now, cash = cash }
end

function IdleIncome.preview(pot: Pot, levels: Levels, now: number): Preview
	local accrued = IdleIncome.accrue(pot, levels, now)
	local rates = IdleIncome.rates(levels)
	local secondsToFull = 0
	if rates.rate > 0 and accrued.cash < rates.capCash then
		secondsToFull = (rates.capCash - accrued.cash) / rates.rate * 3600
	end
	return {
		cash = accrued.cash,
		rate = rates.rate,
		capHours = rates.capHours,
		capCash = rates.capCash,
		fill = if rates.capCash > 0 then accrued.cash / rates.capCash else 0,
		full = accrued.cash >= rates.capCash - 1e-6,
		secondsToFull = math.max(0, secondsToFull),
	}
end

-- Collecting pays whole Cash and starts from an empty pot; a sub-Cash fraction is dropped.
function IdleIncome.claim(pot: Pot, levels: Levels, now: number): Claim
	local accrued = IdleIncome.accrue(pot, levels, now)
	local paid = math.max(0, math.floor(accrued.cash))
	return { cash = paid, pot = { lastAt = now, cash = 0 } }
end

-- `2:14` under an hour, `3:59:59` above it; used for the time until the pot is full.
function IdleIncome.formatTime(seconds: number): string
	local whole = math.max(0, math.floor(number(seconds) + 0.5))
	local hours = math.floor(whole / 3600)
	local minutes = math.floor((whole % 3600) / 60)
	local secs = whole % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return IdleIncome
