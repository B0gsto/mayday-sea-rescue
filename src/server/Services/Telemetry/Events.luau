--!strict
-- Telemetry/Events (RP-A1): the pure side of TelemetryService. It names every analytics event the game
-- sends to Roblox AnalyticsService and decides what goes in it. No services and no requires, so
-- tests/Telemetry.spec.luau runs it under Lune. The spec: docs/research/analytics.md.
--
--   Onboarding funnel (LogOnboardingFunnelStepEvent): fixed step numbers, each logged once per player
--     (Roblox keeps the first; the session tracker below stops repeats in one server)
--   Recurring funnels (LogFunnelStepEvent): TelemetryNames.Funnels, one session id per call / shop
--     visit / vehicle spawn / island / species; stepOf gives the number
--   Economy (LogEconomyEvent): every Cash source and sink, with a Roblox transaction type
--   Custom (LogCustomEvent): the fixed TelemetryNames.Custom list
-- Custom field values are short, low-cardinality strings (kinds, grades, reasons), never names or ids.

export type FunnelStep = { step: number, name: string }
export type Fields = { [string]: string }
export type Custom = { name: string, value: number, fields: Fields }
export type OpFacts = {
	kind: string,
	grade: string?, -- "Gold" | "Silver" | "Bronze" | "Fail"
	reason: string, -- "Complete" | "Timer" | cold-open endings
	helped: boolean, -- this player did a step
	coldOpen: boolean,
	storm: boolean,
	big: boolean,
	rarity: string?, -- "Rare" for the sanctuary's rare palette, else "None"
	saved: number?, -- survivors delivered on this call
}
export type Tracker = { [string]: boolean }
export type Bucket = { tokens: number, at: number }

local Events = {}

Events.CURRENCY = "Cash"
Events.MAX_FIELD = 50 -- characters per custom field value
Events.SHOP_IDLE = 120 -- seconds: a shop step after this long starts a new shop visit
Events.CLIENT_BURST = 8 -- client-reported events per player, then one per CLIENT_REFILL seconds
Events.CLIENT_REFILL = 2

-- The onboarding funnel in the order a new player meets it (docs/24 E, docs/25 J; PT5 2026-10-28).
-- Roblox treats a skipped step as completed, so the numbers MUST follow the real order. Rebuilt
-- 2026-10-29, before launch; after launch only append. Every step is server-side but TabletOpened.
Events.Funnel = {
	{ step = 1, name = "Joined" }, -- PlayerAdded
	{ step = 2, name = "TabletOpened" }, -- the build tablet opened (client reports it)
	{ step = 3, name = "HutPlaced" }, -- the free Rescue Hut (HQ Lv1) site started
	{ step = 4, name = "HutBuilt" }, -- the Hut stands; the cold open waits for it
	{ step = 5, name = "AtSea" }, -- the cold open put them on the jet ski at sea
	{ step = 6, name = "FirstBoard" }, -- the first survivor climbed aboard
	{ step = 7, name = "FirstDelivery" }, -- the first call delivered (the cold open)
	{ step = 8, name = "WorkshopPlaced" }, -- the tutorial Workshop site started (Cash top-up or Robux)
	{ step = 9, name = "WorkshopBuilt" }, -- the Workshop stands: the tutorial spin is handed out
	{ step = 10, name = "FirstSpin" }, -- the tutorial spin used: the Next chip takes over
	{ step = 11, name = "NextBuild" }, -- the first build after the tutorial (the Next chip's)
	{ step = 12, name = "HQ2Placed" }, -- the Rescue Post (HQ Lv2) site started
	{ step = 13, name = "FirstVehicle" }, -- the first vehicle bought with Cash (the RIB: Boathouse, HQ Lv2)
} :: { FunnelStep }

-- cold open step id (OperationService.ColdOpenPlan) -> onboarding step name
Events.ColdOpenSteps = {
	recovery = "FirstBoard", -- the casualty grabs the jet ski
} :: { [string]: string }

-- Values the client may report (Telemetry_Client). Anything else is dropped: a client cannot grow
-- the dashboard's field cardinality.
Events.Devices = { Touch = true, Gamepad = true, Keyboard = true, Console = true, VR = true }
Events.ShopApps = { Store = true, Board = true }
Events.InputContexts = { Foot = true, Boat = true, Swim = true }

local GRADE_VALUE: { [string]: number } = { Gold = 3, Silver = 2, Bronze = 1, Fail = 0 }

function Events.funnelStep(name: string): FunnelStep?
	for _, s in Events.Funnel do
		if s.name == name then
			return s
		end
	end
	return nil
end

-- Onboarding steps a construction start (or finish) completes: the free Hut, the tutorial Workshop,
-- then, once the tutorial's spin is done, the first build (any) and the Rescue Post (HQ Lv2).
function Events.buildSteps(
	key: string,
	level: number,
	finished: boolean,
	tutorialDone: boolean
): { string }
	if key == "HQ" and level == 1 then
		return { if finished then "HutBuilt" else "HutPlaced" }
	elseif key == "Workshop" and level == 1 then
		return { if finished then "WorkshopBuilt" else "WorkshopPlaced" }
	elseif finished or not tutorialDone then
		return {}
	end
	return if key == "HQ" and level == 2 then { "NextBuild", "HQ2Placed" } else { "NextBuild" }
end

-- step number of `name` in a recurring funnel's step list (TelemetryNames.Funnels.X), nil if unknown
function Events.stepOf(steps: { string }?, name: string): number?
	return if steps then table.find(steps, name) else nil
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

-- Token bucket for client-reported events: CLIENT_BURST at once, then one per CLIENT_REFILL s.
function Events.newBucket(now: number): Bucket
	return { tokens = Events.CLIENT_BURST, at = now }
end

function Events.allow(b: Bucket, now: number): boolean
	b.tokens = math.min(Events.CLIENT_BURST, b.tokens + (now - b.at) / Events.CLIENT_REFILL)
	b.at = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Shop visits: MenuOpened always starts a new one; any other step starts one when none is open or
-- the last step was more than SHOP_IDLE seconds ago.
function Events.shopFresh(lastAt: number?, step: number, now: number): boolean
	return step == 1 or lastAt == nil or now - lastAt > Events.SHOP_IDLE
end

-- A client-sent shop item: "Key" or "Vehicle:Upgrade", every part a known config key.
function Events.knownItem(item: any, known: { [string]: boolean }): boolean
	if type(item) ~= "string" or #item == 0 or #item > Events.MAX_FIELD then
		return false
	end
	local parts = string.split(item, ":")
	if #parts > 2 then
		return false
	end
	for _, part in parts do
		if not known[part] then
			return false
		end
	end
	return true
end

-- UTC day number (SessionStart: days since the first session, the gap since the last).
function Events.utcDay(unixTime: number): number
	return math.floor(unixTime / 86400)
end

local function bucket(n: number, edges: { number }, labels: { string }): string
	for i, edge in edges do
		if n < edge then
			return labels[i]
		end
	end
	return labels[#labels]
end

-- days since the first session -> "D0", "D1", "D2-3", "D4-7", "D8-14", "D15-30", "D31+"
function Events.dayBucket(days: number): string
	return bucket(
		days,
		{ 1, 2, 4, 8, 15, 31 },
		{ "D0", "D1", "D2-3", "D4-7", "D8-14", "D15-30", "D31+" }
	)
end

-- days since the last session -> "Same", "1d", "2-3d", "4-7d", "8d+" ("New": no last session)
function Events.gapBucket(days: number?): string
	if days == nil then
		return "New"
	end
	return bucket(days, { 1, 2, 4, 8 }, { "Same", "1d", "2-3d", "4-7d", "8d+" })
end

-- seconds played -> "<1m", "1-5m", "5-10m", "10-20m", "20-40m", "40-60m", "60m+"
function Events.lengthBucket(seconds: number): string
	return bucket(
		seconds,
		{ 60, 300, 600, 1200, 2400, 3600 },
		{ "<1m", "1-5m", "5-10m", "10-20m", "20-40m", "40-60m", "60m+" }
	)
end

-- Award / grant reason -> (Enum.AnalyticsEconomyTransactionType name, item SKU)
--   "Purchase:<key>"           Cash packs and the Starter Kit (CashEffects)   IAP
--   "Streak:*", "Group:*"      the daily crate and its group bonus            TimedReward
--   "Op:<kind>[:...]", others  call payouts, ambient rescues, stickers         Gameplay
-- Streak days past 7 share one SKU (Roblox groups SKUs past 100 into "Other").
function Events.cashSource(reason: string?): (string, string)
	local r = if type(reason) == "string" and reason ~= "" then reason else "Unknown"
	if r:sub(1, 9) == "Purchase:" then
		return "IAP", clip(r:sub(10))
	end
	if r:sub(1, 7) == "Streak:" or r:sub(1, 6) == "Group:" then
		local day = tonumber(r:match("^Streak:Day(%d+)$"))
		return "TimedReward", if day and day > 7 then "Streak:Day8+" else clip(r)
	end
	return "Gameplay", clip(r)
end

-- vehicle / upgrade: what the Cash bought -> (transaction, SKU)
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

-- a call's context field: ColdOpen, Big, Storm or Calm
function Events.callContext(coldOpen: boolean, big: boolean, storm: boolean): string
	if coldOpen then
		return "ColdOpen"
	elseif big then
		return "Big"
	elseif storm then
		return "Storm"
	end
	return "Calm"
end

-- OperationService finish reason -> the call's result: Delivered, Timer (the big call's cap), or
-- Abandoned (died, left the craft, drove away, ...).
function Events.callResult(reason: string): string
	if reason == "Complete" then
		return "Delivered"
	elseif reason == "Timer" then
		return "Timer"
	end
	return "Abandoned"
end

-- The custom events one finished call sends for one player on it.
--   CallEnded (value = survivors saved)  everyone on it: kind, result, context
--   OpGrade   (value 0..3)               helpers only: kind, grade, rarity
function Events.opEvents(f: OpFacts): { Custom }
	local out: { Custom } = {
		{
			name = "CallEnded",
			value = if type(f.saved) == "number" then f.saved else 0,
			fields = Events.fields(
				f.kind,
				Events.callResult(f.reason),
				Events.callContext(f.coldOpen, f.big, f.storm)
			),
		},
	}
	if f.helped then
		local grade = f.grade or "None"
		table.insert(out, {
			name = "OpGrade",
			value = GRADE_VALUE[grade] or 0,
			fields = Events.fields(f.kind, grade, f.rarity or "None"),
		})
	end
	return out
end

-- Whether this finish delivered someone this player helped (onboarding FirstDelivery)
function Events.delivered(f: OpFacts): boolean
	return f.helped and f.reason == "Complete"
end

-- StormJoined: one per player per storm (the storm's StormId), on the turn to Storm or on joining a
-- server mid-storm. Fields: "Great" | "Storm", "Start" | "MidStorm".
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
