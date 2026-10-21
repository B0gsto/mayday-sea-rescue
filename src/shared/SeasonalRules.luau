--!strict
-- SeasonalRules: the Halloween "Ghost Ship" window, Candy Lanterns and the pumpkin stall (docs/15
-- hook H7). Pure and shared (Lune-tested in tests/Seasonal.spec.luau): no services, no Robux, every
-- reward is earned by playing (docs/15 section 1).
--
-- The window runs on EventClock's UTC clock (EventClock.inSeason) so a dev EventClockOffset and the
-- server-clock events agree. Player state lives in the profile flag data.flags.halloween as a flat
-- table: { candy = <number>, livery = true, collar = true, decor = true }.

local EventClock = require(script.Parent.EventClock)
local SeasonalEvents = require(script.Parent.Config.SeasonalEvents)

export type Item = SeasonalEvents.Item
export type Event = SeasonalEvents.Event
export type State = { candy: number, owned: { [string]: boolean } }

local MAX_CANDY = 9999

local SeasonalRules = {}

SeasonalRules.MAX_CANDY = MAX_CANDY

function SeasonalRules.live(event: Event, now: number, forced: boolean?): boolean
	return forced == true
		or EventClock.inSeason(
			{ id = event.id, startAt = event.startUtc, endsAt = event.endUtc },
			now
		)
end

-- Whole days shown on the stall clock: 10 on the first day, 1 on the last, 0 once it is over.
function SeasonalRules.daysLeft(event: Event, now: number): number
	if now > event.endUtc then
		return 0
	end
	return math.max(1, math.ceil((event.endUtc - now) / 86400))
end

-- The nightly window: true during the 15 minutes starting at the configured minute past each hour
-- (the witching hour, :45 by default). The Ghost Ship call itself is the other night window.
function SeasonalRules.witching(event: Event, now: number): boolean
	local window = event.night
	if not window then
		return false
	end
	local minute = math.floor((now % 3600) / 60)
	return minute >= window.witchingMinute
		and minute < window.witchingMinute + window.witchingMinutes
end

-- Night + fog for this player: a Ghost Ship call is up, or it is the witching hour. A player in
-- onboarding (the cold open and first three calls) never gets the forced night.
function SeasonalRules.night(
	event: Event,
	now: number,
	ghostShip: boolean,
	onboarding: boolean
): boolean
	if onboarding then
		return false
	end
	return ghostShip or SeasonalRules.witching(event, now)
end

function SeasonalRules.candyFor(event: Event, eventRescue: boolean): number
	return if eventRescue then event.candyEventRescue else event.candyAnyRescue
end

function SeasonalRules.item(event: Event, id: string): Item?
	for _, item in event.items do
		if item.id == id then
			return item
		end
	end
	return nil
end

function SeasonalRules.newState(): State
	return { candy = 0, owned = {} }
end

-- Accepts a saved flag (or anything corrupt) and returns a clean state. `event` picks the item
-- flags; omitting it keeps the Halloween flag shape (the first event).
function SeasonalRules.fromFlag(value: any, event: Event?): State
	local state = SeasonalRules.newState()
	if type(value) ~= "table" then
		return state
	end
	local candy = tonumber(value.candy)
	if candy and candy == candy then
		state.candy = math.clamp(math.floor(candy), 0, MAX_CANDY)
	end
	for _, item in (event or SeasonalEvents.Halloween).items do
		if value[item.flag] == true then
			state.owned[item.flag] = true
		end
	end
	return state
end

-- The flat flag table ProgressionService.SetFlag persists (scalars only).
function SeasonalRules.flagTable(state: State): { [string]: any }
	local flag: { [string]: any } = { candy = math.clamp(state.candy, 0, MAX_CANDY) }
	for key, owned in state.owned do
		if owned then
			flag[key] = true
		end
	end
	return flag
end

function SeasonalRules.reward(state: State, amount: number): State
	return {
		candy = math.clamp(state.candy + math.max(0, math.floor(amount)), 0, MAX_CANDY),
		owned = state.owned,
	}
end

function SeasonalRules.canBuy(event: Event, state: State, id: string): (boolean, string?)
	local item = SeasonalRules.item(event, id)
	if not item then
		return false, "Unknown"
	end
	if state.owned[item.flag] then
		return false, "Owned"
	end
	if state.candy < item.price then
		return false, "Need candy"
	end
	return true, nil
end

-- Returns the state after the purchase, or nil and the reason.
function SeasonalRules.buy(event: Event, state: State, id: string): (State?, string?)
	local ok, reason = SeasonalRules.canBuy(event, state, id)
	if not ok then
		return nil, reason
	end
	local item = SeasonalRules.item(event, id) :: Item
	local owned = table.clone(state.owned)
	owned[item.flag] = true
	return { candy = state.candy - item.price, owned = owned }, nil
end

return SeasonalRules
