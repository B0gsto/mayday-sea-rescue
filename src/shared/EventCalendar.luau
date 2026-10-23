--!strict
-- EventCalendar: one list of what is coming, for the harbour events board and the phone (docs/15
-- section 2). Pure and Lune-tested (tests/EventCalendar.spec.luau): it only composes the existing
-- clocks, so every screen shows the same times as the systems that run them.
--
--   Great Storm    EventClock (hourly :00, 120 s warning, 240 s active; during it the row is "NOW")
--   Ghost Light    EventClock (every 3 h at :30)
--   Ghost Ship     SeasonalRules / SeasonalEvents (days left and the witching hour countdown,
--                  shown only from a week before the window opens)
--   Daily crate    StreakRules (seconds to the next UTC day, or ready now)
--   Strongbox      IdleIncome (fill and seconds to full from the station view)
--
-- Rows are icons, a 1-3 word label and numbers only (show, don't tell). No price, no Robux: the
-- board is a planning aid for free, earnable content (docs/15 section 1). Rows sort by soonest.

local EventClock = require(script.Parent.EventClock)
local IdleIncome = require(script.Parent.IdleIncome)
local LiveOps = require(script.Parent.LiveOps)
local SeasonalEvents = require(script.Parent.Config.SeasonalEvents)
local SeasonalRules = require(script.Parent.SeasonalRules)
local StreakRules = require(script.Parent.StreakRules)

export type Icon =
	"storm"
	| "lantern"
	| "pumpkin"
	| "book"
	| "bell"
	| "crate"
	| "strongbox"
	| "spark"
export type Kind = "now" | "clock" | "days" | "percent"

export type Row = {
	id: string,
	icon: Icon,
	label: string, -- 1-3 words
	kind: Kind, -- now (pulsing), clock, days, percent
	seconds: number?, -- clock kind; the sub-clock on a days row; the fill clock on a percent row
	hours: boolean?, -- clock text as h:mm:ss even under an hour (the Great Storm)
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
	halloweenForced: boolean?,
	liveOps: LiveOpsView?,
	stormOff: boolean?, -- no Great Storm row (StormService.ALWAYS_SUNNY)
}

local EventCalendar = {}

EventCalendar.HalloweenLead = 7 * 86400 -- the board shows the Ghost Ship from a week out
EventCalendar.StormLabel = "Great storm"
EventCalendar.GhostLightLabel = "Ghost light"
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

-- Seconds until the next witching hour starts (:45 for 15 minutes by default); 0 while it is on.
function EventCalendar.witchingIn(event: SeasonalEvents.Event, now: number): number
	local window = event.night
	if not window then
		return 0
	end
	local into = now % 3600
	local start = window.witchingMinute * 60
	local span = window.witchingMinutes * 60
	if into >= start and into < start + span then
		return 0
	end
	if into < start then
		return start - into
	end
	return 3600 - into + start
end

local function stormRow(now: number): Row
	if EventClock.phase("GreatStorm", now) == "Active" then
		return {
			id = "GreatStorm",
			icon = "storm",
			label = EventCalendar.StormLabel,
			kind = "now",
		}
	end
	return {
		id = "GreatStorm",
		icon = "storm",
		label = EventCalendar.StormLabel,
		kind = "clock",
		seconds = math.max(0, EventClock.nextStart("GreatStorm", now) - now),
		hours = true,
	}
end

local function halloweenRow(now: number, forced: boolean): Row?
	local event = SeasonalEvents.Halloween
	local live = SeasonalRules.live(event, now, forced)
	local near = now >= event.startUtc - EventCalendar.HalloweenLead and now <= event.endUtc
	if not (live or near) then
		return nil
	end
	local days: number
	if live then
		days = math.max(1, SeasonalRules.daysLeft(event, now))
	else
		days = math.max(1, math.ceil((event.startUtc - now) / 86400))
	end
	return {
		id = "Halloween",
		icon = "pumpkin",
		label = event.name, -- "Ghost Ship"
		kind = "days",
		days = days,
		seconds = if live then EventCalendar.witchingIn(event, now) else nil,
	}
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

-- The soonest first; ties keep the fixed order (great storm, ghost light, ...).
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

	if not o.stormOff then
		add(list, stormRow(now))
	end
	local scheduled = liveOpsRow(now, o.liveOps)
	if scheduled then
		add(list, scheduled)
	end
	add(list, {
		id = "GhostLight",
		icon = "lantern",
		label = EventCalendar.GhostLightLabel,
		kind = "clock",
		seconds = math.max(0, EventClock.nextStart("GhostLight", now) - now),
	})

	local halloween = halloweenRow(now, o.halloweenForced == true)
	if halloween then
		add(list, halloween)
	end

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

-- The two numbers a row draws: the main readout and an optional second one (the witching clock,
-- the time to full). Words stay to the row label, never here.
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
