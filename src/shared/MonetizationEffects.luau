--!strict
-- MonetizationEffects (RP-M2): the pure math behind the Robux effects (docs/04 sections 3, 4 and 5).
-- No services and no requires (config tables are passed in), so tests/MonetizationEffects.spec.luau
-- runs it under Lune and the client cards can read the same numbers.
--
-- Fairness (docs/04 sections 1 and 7): every effect here is Cash or a server-wide storm. Nothing
-- touches Reputation, rank, grades, timing windows or a casualty's condition.
--
-- Saved state: one flat profile flag `shop` (ProgressionRules flag rules: scalars only, |n| <= 1e6):
--   cashBoost, crewBoost   seconds of boost playtime left (tick only while the player is in a server)
--   packDay, packs         UTC day number and Cash packs bought that day (docs/04 4.1 daily limit)
--   starterKit             true once the Starter Kit's one-time Cash has been paid
--   ticketStorm, ticketGreat  Storm Tickets: a paid storm not yet run (docs/04 section 5 rule 7)
--   anon                   the buyer hides their name from storm announcements (rule 5)
--   callerHour             UTC hour (os.time() // 3600) until which the "Storm Caller" title shows
--   day<PassKey>           day passes: UTC hour (os.time() // 3600) the pass's effect runs until (real time)

local Effects = {}

Effects.DAY_SECONDS = 86400
Effects.BOOST_CAP_SECONDS = 24 * 3600 -- stacked boost time is capped at a day of playtime
Effects.CREW_BOOST_BONUS = 0.5 -- docs/04 4.2: +50% Cash for the crew

-- docs/04 section 5 rules 2 and 3 (tune)
Effects.Summon = {
	QueueMax = 2,
	GapSeconds = 480, -- at least 8 minutes between summoned storms (end of one to start of the next)
	NaturalBuffer = 120, -- none within 2 minutes of a natural storm, before or after it
	Tolerance = 2, -- seconds of tick slack when a storm exactly fills the calm window
	CallerTitleHours = 24,
}

export type Zone = { id: string, rankIndex: number, cashPerHour: number, live: boolean }
export type Shop = { [string]: any }

local function num(v: any): number
	return if type(v) == "number" and v == v then v else 0
end

-- The highest live zone the rank has opened (docs/04 4.1: packs scale with the top open zone).
function Effects.topZone(zones: { Zone }, rankIndex: number): Zone?
	local best: Zone? = nil
	for _, zone in zones do
		if
			zone.live
			and zone.rankIndex <= rankIndex
			and (best == nil or zone.rankIndex > best.rankIndex)
		then
			best = zone
		end
	end
	return best
end

function Effects.cashPerMinute(zones: { Zone }, rankIndex: number): number
	local zone = Effects.topZone(zones, rankIndex)
	return if zone then zone.cashPerHour / 60 else 0
end

-- Same formula as ProductShelves.packCash, so the card shows exactly what the grant pays.
function Effects.packCash(item: any, cashPerMinute: number): number
	if type(item) ~= "table" or type(item.cashMinutes) ~= "number" or cashPerMinute <= 0 then
		return 0
	end
	return math.floor(cashPerMinute * item.cashMinutes * (1 + (item.valueBonus or 0)) + 0.5)
end

function Effects.dayOf(unixTime: number): number
	return math.floor(unixTime / Effects.DAY_SECONDS)
end

function Effects.packsToday(shop: Shop?, day: number): number
	if not shop or shop.packDay ~= day then
		return 0
	end
	return num(shop.packs)
end

-- Counts one Cash pack. A pack is always granted once paid; the limit is enforced on the card.
function Effects.countPack(shop: Shop, day: number)
	shop.packs = Effects.packsToday(shop, day) + 1
	shop.packDay = day
end

function Effects.addBoost(shop: Shop, field: string, seconds: number)
	shop[field] = math.min(Effects.BOOST_CAP_SECONDS, num(shop[field]) + math.max(seconds, 0))
end

-- Day passes (MonetizationConfig Products with dayPassFor / dayPassHours): unix second the pass ends (0 = none).
function Effects.dayPassEnds(shop: Shop?, passKey: string): number
	return if shop then num(shop["day" .. passKey]) * 3600 else 0
end

-- A pass counts while owned or while its day pass runs (the server's OwnsPass and the client's attributes
-- "Pass_<Key>" / "DayPass_<Key>" both read this). dayPassEnds: unix end second (nil / 0 = none).
function Effects.passActive(owned: boolean, dayPassEnds: number?, now: number): boolean
	return owned or num(dayPassEnds) > now
end

-- Adds hours of real time from now, or from the current end when one is running; returns the new end.
-- shortcut: saved as a whole hour (the flag limit is 1e6), so the end rounds up and a buyer gets up to
-- an hour extra; store seconds if the flag rules ever allow bigger numbers.
function Effects.addDayPass(shop: Shop, passKey: string, hours: number, now: number): number
	local from = math.max(Effects.dayPassEnds(shop, passKey), now)
	local hour = math.ceil((from + math.max(hours, 0) * 3600) / 3600)
	shop["day" .. passKey] = hour
	return hour * 3600
end

-- Counts boost time down by dt seconds of playtime; true when anything changed.
function Effects.tickBoosts(shop: Shop, dt: number): boolean
	local changed = false
	for _, field in { "cashBoost", "crewBoost" } do
		local left = num(shop[field])
		if left > 0 then
			local after = math.max(0, left - dt)
			shop[field] = if after > 0 then after else nil
			changed = true
		end
	end
	return changed
end

-- The Cash multiplier from paid items (the storm multiplier is applied separately by ProgressionRules).
-- 2x Cash and Cash Boost do not stack with each other (docs/04 4.2); a Crew Boost adds +50% of the base
-- on top of either. Rep is never multiplied.
function Effects.cashMultiplier(
	ownsDoubleCash: boolean,
	cashBoostLeft: number,
	crewBoostActive: boolean
): number
	local mult = 1
	if ownsDoubleCash or cashBoostLeft > 0 then
		mult += 1
	end
	if crewBoostActive then
		mult += Effects.CREW_BOOST_BONUS
	end
	return mult
end

-- Storm Tickets -------------------------------------------------------------------------------

local TICKET_FIELD = { Storm = "ticketStorm", GreatStorm = "ticketGreat" }

function Effects.ticketField(tier: string): string?
	return TICKET_FIELD[tier]
end

function Effects.tickets(shop: Shop?, tier: string): number
	local field = TICKET_FIELD[tier]
	return if shop and field then num(shop[field]) else 0
end

function Effects.addTicket(shop: Shop, tier: string): boolean
	local field = TICKET_FIELD[tier]
	if not field then
		return false
	end
	shop[field] = Effects.tickets(shop, tier) + 1
	return true
end

function Effects.takeTicket(shop: Shop, tier: string): boolean
	local field = TICKET_FIELD[tier]
	local have = Effects.tickets(shop, tier)
	if not field or have <= 0 then
		return false
	end
	shop[field] = if have > 1 then have - 1 else nil
	return true
end

-- Storm Summon schedule ---------------------------------------------------------------------------

-- Warning + storm + clearing seconds of a summoned storm of this tier (GameConfig.Storm).
function Effects.summonSeconds(tier: string, storm: { [string]: number }): number
	local middle = if tier == "GreatStorm" then storm.GreatStormSeconds else storm.StormSeconds
	return storm.WarningSeconds + middle + storm.ClearingSeconds
end

export type SummonContext = {
	state: string, -- the weather state now
	now: number,
	naturalEnd: number, -- when the last natural storm cleared (-math.huge if none yet)
	naturalWarningAt: number, -- when the next natural storm's warning is due (the natural clock)
	lastSummonEnd: number, -- when the last summoned storm cleared (-math.huge if none yet)
	total: number, -- Effects.summonSeconds of the queue head
}

-- "Wait": not yet. "Start": run it now; the natural clock is untouched. "StartPushNatural": this
-- calm is too short to ever fit the storm with its buffers, so it runs now and the next natural
-- storm moves to its buffer after it (only with a calm shorter than the GameConfig default).
function Effects.summonDecision(ctx: SummonContext): string
	if ctx.state ~= "Calm" then
		return "Wait"
	end
	local rules = Effects.Summon
	local earliest =
		math.max(ctx.naturalEnd + rules.NaturalBuffer, ctx.lastSummonEnd + rules.GapSeconds)
	if ctx.now < earliest then
		return "Wait"
	end
	if ctx.now + ctx.total + rules.NaturalBuffer <= ctx.naturalWarningAt + rules.Tolerance then
		return "Start"
	end
	-- It does not fit before the next natural storm. If no calm of this length could ever hold it,
	-- run it anyway rather than strand a paid storm in the queue; otherwise wait for the next calm.
	local calmLength = ctx.naturalWarningAt - ctx.naturalEnd
	if calmLength + rules.Tolerance < 2 * rules.NaturalBuffer + ctx.total then
		return "StartPushNatural"
	end
	return "Wait"
end

-- Quick Launch (docs/04 section 3): launch an owned vehicle straight into the seat from anywhere, without
-- the walk and the launch cooldown. Never during the cold open; never while seated with someone (planSpawn
-- refuses); rank still gates every vehicle (spawnVehicle).
function Effects.quickLaunchAllowed(ownsPass: boolean, coldOpenDone: boolean): (boolean, string)
	if not ownsPass then
		return false, "NotOwned"
	end
	if not coldOpenDone then
		return false, "ColdOpen"
	end
	return true, "ok"
end

-- Boat to me (docs/23 c.5, WP-11a): the phone's free call waits BOAT_TO_ME_COOLDOWN between uses; the Quick
-- Launch pass skips the wait. -> seconds left (0 = ready). lastAt: the last call's server time (nil: never).
-- cooldown: this player's wait (the hired Mechanic shortens it); nil = the base 60 s.
Effects.BOAT_TO_ME_COOLDOWN = 60 -- s -- tune
function Effects.boatToMeWait(
	ownsPass: boolean,
	lastAt: number?,
	now: number,
	cooldown: number?
): number
	if ownsPass or not lastAt then
		return 0
	end
	return math.max(0, lastAt + (cooldown or Effects.BOAT_TO_ME_COOLDOWN) - now)
end

return Effects
