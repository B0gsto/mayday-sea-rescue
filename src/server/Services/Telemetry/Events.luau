--!strict
-- Telemetry/Events (RP-A1): the pure side of TelemetryService. It names every analytics event the game
-- sends to Roblox AnalyticsService and decides what goes in it. No services and no requires, so
-- tests/Telemetry.spec.luau runs it under Lune.
--
--   Onboarding funnel (LogOnboardingFunnelStepEvent): fixed step numbers, each logged once per player
--     (Roblox keeps the first; the session tracker below stops repeats in one server)
--   Economy (LogEconomyEvent): every Cash source (Award, Cash packs, Starter Kit) and sink (gear,
--     vehicles, stock, station upgrades, pet treats)
--   Custom (LogCustomEvent): the fixed TelemetryNames.Custom list (op start/complete/grade, daily
--     crate, challenge, album, pets, live events, prompts, ...)
-- Custom field values are short, low-cardinality strings (kinds, grades, reasons), never names or ids.

export type FunnelStep = { step: number, name: string }
export type Fields = { [string]: string }
export type Custom = { name: string, value: number, fields: Fields }
export type OpFacts = {
	kind: string,
	grade: string?, -- "Gold" | "Silver" | "Bronze" | "Fail" | "Takeover"
	reason: string, -- "Complete" | "Timer" | "Takeover" | cold-open endings
	helped: boolean, -- this player did a step
	coldOpen: boolean,
	exercise: boolean,
	storm: boolean,
	big: boolean,
	rarity: string?, -- the call variant's rarity (Common..Legendary), nil for an exercise
}
export type Tracker = { [string]: boolean }

local Events = {}

Events.CURRENCY = "Cash"
Events.MAX_FIELD = 50 -- characters per custom field value

-- The onboarding funnel in the order a new player meets it (docs/13 RP-A1, docs/15 section 3).
-- Roblox treats a skipped step as completed, so the numbers MUST follow the real order: a step
-- logged before its number would mark every earlier step done. The funnel is not live yet (launch
-- pending, docs/13 U-1), so G64 renumbered the old InProgress steps once, here; do not renumber
-- again after launch, only append.
Events.Funnel = {
	{ step = 1, name = "Joined" },
	{ step = 2, name = "ColdOpenStarted" }, -- the radio tasking is auto-done here (StartColdOpen)
	{ step = 3, name = "ColdOpenApproach" },
	{ step = 4, name = "ColdOpenRecovery" }, -- the casualty holds on
	{ step = 5, name = "ColdOpenEnded" },
	{ step = 6, name = "RewardSeen" }, -- the first reward burst played (client reports it)
	{ step = 7, name = "ReachedStation" },
	{ step = 8, name = "Call2Accepted" },
	{ step = 9, name = "FirstOpComplete" }, -- call 2 complete
	{ step = 10, name = "Call3Complete" },
	{ step = 11, name = "FirstChandleryVisit" },
	{ step = 12, name = "FirstUnlock" }, -- the first gear purchase (docs/15 section 3, about 5 min)
	{ step = 13, name = "FirstRank" },
	{ step = 14, name = "FirstDailyCrate" },
	{ step = 15, name = "Day2Return" }, -- first session on a later UTC day
} :: { FunnelStep }

-- cold open step id (OperationService.ColdOpenPlan) -> funnel step name
Events.ColdOpenSteps = {
	approach = "ColdOpenApproach",
	recovery = "ColdOpenRecovery",
} :: { [string]: string }

local GRADE_VALUE: { [string]: number } =
	{ Gold = 3, Silver = 2, Bronze = 1, Fail = 0, Takeover = 0 }

function Events.funnelStep(name: string): FunnelStep?
	for _, s in Events.Funnel do
		if s.name == name then
			return s
		end
	end
	return nil
end

function Events.newTracker(): Tracker
	return {}
end

-- true the first time `key` is seen on this tracker (one per player per server)
function Events.first(tracker: Tracker, key: string): boolean
	if tracker[key] then
		return false
	end
	tracker[key] = true
	return true
end

local function clip(s: string): string
	return if #s > Events.MAX_FIELD then s:sub(1, Events.MAX_FIELD) else s
end

-- AnalyticsService custom fields (Enum.AnalyticsCustomFieldKeys names), at most three
function Events.fields(a: string?, b: string?, c: string?): Fields
	local out: Fields = {}
	if a then
		out.CustomField01 = clip(a)
	end
	if b then
		out.CustomField02 = clip(b)
	end
	if c then
		out.CustomField03 = clip(c)
	end
	return out
end

-- A LogCustomEvent payload from a name already on the fixed TelemetryNames list plus up to three
-- short field values. `value` defaults to 1 (a counter).
function Events.custom(name: string, value: number?, a: string?, b: string?, c: string?): Custom
	local n = if type(value) == "number" and value == value then value else 1
	return { name = name, value = n, fields = Events.fields(a, b, c) }
end

-- UTC day number for the Day2Return funnel step (one session per day).
function Events.utcDay(unixTime: number): number
	return math.floor(unixTime / 86400)
end

-- True when this session starts on a later UTC day than the last recorded one. A missing or
-- corrupt previous value is not a return (a first session is never Day2Return).
function Events.day2Return(previousDay: any, today: number): boolean
	return type(previousDay) == "number" and previousDay > 0 and today > previousDay
end

-- Award / grant reason -> (Enum.AnalyticsEconomyTransactionType name, item SKU)
--   "Purchase:<key>"   Cash packs and the Starter Kit (CashEffects)   IAP
--   "Op:<kind>[:...]"  operation payouts (OperationService)          Gameplay
--   "Exercise:<kind>"  first exercise pass (RecordTraining)           Onboarding
--   "Logbook: <name>"  exploration finds (ExplorationService)         Gameplay, SKU "Logbook"
function Events.cashSource(reason: string?): (string, string)
	local r = if type(reason) == "string" and reason ~= "" then reason else "Unknown"
	if r:sub(1, 9) == "Purchase:" then
		return "IAP", clip(r:sub(10))
	elseif r:sub(1, 9) == "Exercise:" then
		return "Onboarding", clip(r)
	elseif r:sub(1, 8) == "Logbook:" then
		return "Gameplay", "Logbook"
	end
	return "Gameplay", clip(r)
end

-- BuyGear / BuyStock / station upgrade / pet treat: what the Cash bought -> (transaction, SKU)
function Events.cashSink(kind: string, itemId: string): (string, string)
	return "Shop", clip(`{kind}:{itemId}`)
end

-- Whole Cash for the economy event (nil: nothing to log)
function Events.amount(cash: any): number?
	if type(cash) ~= "number" or cash ~= cash then
		return nil
	end
	local n = math.floor(cash + 0.5)
	return if n > 0 then n else nil
end

local function context(f: OpFacts): string
	if f.coldOpen then
		return "ColdOpen"
	elseif f.exercise then
		return "Exercise"
	elseif f.big then
		return "Big"
	elseif f.storm then
		return "Storm"
	end
	return "Calm"
end

function Events.failed(f: OpFacts): boolean
	return f.reason ~= "Complete" or f.grade == "Fail" or f.grade == "Takeover"
end

-- The custom events one finished operation sends for one player on it.
--   OpComplete (value 1)    everyone on it: kind, grade (or None), rarity
--   OpGrade    (value 0..3) helpers only: kind, grade, rarity
--   OpFailed   (value 1)    everyone on it when it did not end in a graded rescue: kind, reason, context
function Events.opEvents(f: OpFacts): { Custom }
	local out: { Custom } = {}
	local ctx = context(f)
	local grade = f.grade or "None"
	local rarity = f.rarity or "None"
	table.insert(out, {
		name = "OpComplete",
		value = 1,
		fields = Events.fields(f.kind, grade, rarity),
	})
	if f.helped then
		table.insert(out, {
			name = "OpGrade",
			value = GRADE_VALUE[grade] or 0,
			fields = Events.fields(f.kind, grade, rarity),
		})
	end
	if Events.failed(f) then
		local why = if f.reason == "Complete" then `Grade{grade}` else f.reason
		table.insert(
			out,
			{ name = "OpFailed", value = 1, fields = Events.fields(f.kind, why, ctx) }
		)
	end
	return out
end

-- The start of an operation, from TelemetryService's active-operation poll: every participant,
-- once per operation. Fields: kind, rarity, context.
function Events.opStarted(kind: string, rarity: string?, ctx: string): Custom
	return {
		name = "OpStarted",
		value = 1,
		fields = Events.fields(kind, rarity or "None", ctx),
	}
end

-- Whether this finish is the player's first proper operation (the funnel's FirstOpComplete): a
-- station call they helped on, ended as a rescue. The cold open and exercises do not count.
function Events.countsAsFirstOp(f: OpFacts): boolean
	return f.helped and f.reason == "Complete" and not f.coldOpen and not f.exercise
end

-- StormJoined: one per player per storm (the storm's StormId), on the turn to Storm or on joining a
-- server mid-storm. Fields: "Great" | "Storm", "Start" | "MidStorm". (Summoned storms are Robux
-- products: their purchases already show in the Creator Dashboard's monetization pages.)
function Events.stormKey(stormId: any): string
	return `Storm:{tostring(stormId)}`
end

function Events.stormJoined(great: boolean, midStorm: boolean): Custom
	return {
		name = "StormJoined",
		value = 1,
		fields = Events.fields(
			if great then "Great" else "Storm",
			if midStorm then "MidStorm" else "Start"
		),
	}
end

return Events
