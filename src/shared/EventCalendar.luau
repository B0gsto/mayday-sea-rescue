--!strict
-- EventCalendar: one list of what is coming, for the harbour events board and the phone (docs/15
-- section 2). Pure and Lune-tested (tests/EventCalendar.spec.luau): it only composes the existing
-- clocks, so every screen shows the same times as the systems that run them.
--
--   LiveOps        LiveOpsService (the owner-scheduled event)
--   Season 1       SeasonRules (days left)
--   Chandlery      StockRotation (seconds to the next 10-minute window)
--   Daily crate    StreakRules (seconds to the next UTC day, or ready now)
--   Strongbox      IdleIncome (fill and seconds to full from the station view)
--
-- Rows are icons, a 1-3 word label and numbers only (show, don't tell). No price, no Robux: the
-- board is a planning aid for free, earnable content (docs/15 section 1). Rows sort by soonest.

local IdleIncome = require(script.Parent.IdleIncome)
local LiveOps = require(script.Parent.LiveOps)
local SeasonRules = require(script.Parent.SeasonRules)
local StockRotation = require(script.Parent.StockRotation)
local StreakRules = require(script.Parent.StreakRules)

export type Icon = "book" | "bell" | "crate" | "strongbox" | "spark"
export type Kind = "now" | "clock" | "days" | "percent"

export type Row = {
	id: string,
	icon: Icon,
	label: string, -- 1-3 words
	kind: Kind, -- now (pulsing), clock, days, percent
	seconds: number?, -- clock kind; the sub-clock on a days row; the fill clock on a percent row
	hours: boolean?, -- clock text as h:mm:ss even under an hour (LiveOps)
	days: number?, -- days kind
	fraction: number?, -- percent kind, 0..1
	ready: boolean?, -- now kind: ready (a crate) instead of a live event
}

export type StreakView = { available: boolean }

export type StationView = {
	cash: number,
	level: number,
	radio: number?,
	kennel: number?,
}

export type LiveOpsView = {
	event: string,
	startsAt: number,
	endsAt: number,
}

export type Options = {
	streak: StreakView?,
	station: StationView?,
	liveOps: LiveOpsView?,
}

local EventCalendar = {}

EventCalendar.SeasonLabel = "Season 1"
EventCalendar.RestockLabel = "Chandlery"
EventCalendar.CrateLabel = "Daily crate"
EventCalendar.StrongboxLabel = "Strongbox"

-- `0:42:10` with hours, `7:42` under one. Rounded up so a countdown never shows 0:00 early.
function EventCalendar.formatClock(seconds: number, hours: boolean?): string
	local whole = math.max(0, math.floor(seconds + 0.5))
	if hours == true or whole >= 3600 then
		local h = whole // 3600
		local m = (whole % 3600) // 60
		return string.format("%d:%02d:%02d", h, m, whole % 60)
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- LiveOps (G60): the owner-scheduled event from LiveOpsService. Pending shows a countdown (days
-- out to a week), active pulses NOW. Same rule as every row: icon, 1-3 words, no prices.
local function liveOpsRow(now: number, view: LiveOpsView?): Row?
	if not view or view.event == "" then
		return nil
	end
	local def = LiveOps.Events[view.event]
	if not def or now >= view.endsAt then
		return nil
	end
	if now >= view.startsAt then
		return { id = "LiveOps", icon = "spark", label = def.label, kind = "now" }
	end
	local seconds = view.startsAt - now
	if seconds >= 86400 then
		return {
			id = "LiveOps",
			icon = "spark",
			label = def.label,
			kind = "days",
			days = math.max(1, math.ceil(seconds / 86400)),
		}
	end
	return {
		id = "LiveOps",
		icon = "spark",
		label = def.label,
		kind = "clock",
		seconds = seconds,
		hours = true,
	}
end

-- The soonest first; ties keep the fixed order (LiveOps, season, ...).
local function soonest(row: Row): number
	if row.kind == "now" then
		return 0
	end
	if row.seconds ~= nil then
		return row.seconds
	end
	return math.max(0, row.days or 0) * 86400
end

local function add(list: { Row }, row: Row)
	local key = soonest(row)
	table.insert(list, row)
	local i = #list
	while i > 1 and soonest(list[i - 1]) > key do
		list[i] = list[i - 1]
		list[i - 1] = row
		i -= 1
	end
end

function EventCalendar.rows(now: number, opts: Options?): { Row }
	local o: Options = opts or {}
	local list: { Row } = {}

	local scheduled = liveOpsRow(now, o.liveOps)
	if scheduled then
		add(list, scheduled)
	end

	local seasonDays = SeasonRules.daysLeft(now)
	if seasonDays > 0 then
		add(list, {
			id = "Season",
			icon = "book",
			label = EventCalendar.SeasonLabel,
			kind = "days",
			days = seasonDays,
		})
	end

	add(list, {
		id = "Restock",
		icon = "bell",
		label = EventCalendar.RestockLabel,
		kind = "clock",
		seconds = StockRotation.secondsToRestock(now),
	})

	local ready = o.streak ~= nil and o.streak.available == true
	add(list, {
		id = "Crate",
		icon = "crate",
		label = EventCalendar.CrateLabel,
		kind = if ready then "now" else "clock",
		seconds = if ready then nil else StreakRules.secondsToDay(now),
		ready = ready,
	})

	local station = o.station
	if station then
		local levels: IdleIncome.Levels = {
			workshop = station.level,
			radio = station.radio or 0,
			kennel = station.kennel or 0,
		}
		local preview = IdleIncome.preview({ lastAt = now, cash = station.cash }, levels, now)
		add(list, {
			id = "Strongbox",
			icon = "strongbox",
			label = EventCalendar.StrongboxLabel,
			kind = "percent",
			fraction = preview.fill,
			seconds = preview.secondsToFull,
		})
	end

	return list
end

-- The two numbers a row draws: the main readout and an optional second one (the time to full). Words stay to the row label, never here.
function EventCalendar.text(row: Row): (string, string?)
	if row.kind == "now" then
		return if row.ready == true then "✓" else "NOW", nil
	elseif row.kind == "clock" then
		return EventCalendar.formatClock(row.seconds or 0, row.hours), nil
	elseif row.kind == "days" then
		local sub = if row.seconds ~= nil
			then EventCalendar.formatClock(row.seconds :: number, false)
			else nil
		return `{math.max(0, row.days or 0)}d`, sub
	end
	local fraction = math.clamp(row.fraction or 0, 0, 1)
	local sub = if fraction >= 0.999
		then "✓"
		else EventCalendar.formatClock(row.seconds or 0, false)
	return `{math.floor(fraction * 100 + 0.5)}%`, sub
end

return EventCalendar
