--!strict
-- TelemetryNames (G64): the fixed list of analytics event names. Pure and Lune-tested
-- (tests/TelemetryNames.spec.luau): every name unique, short and inside Roblox's limits. Nothing
-- here sends anything; TelemetryService is still the only caller of AnalyticsService.
-- The spec (what fires where, and why): docs/research/analytics.md.
--
-- Keep this list small and stable. A new variant of an existing event is a field value, not a new
-- name. Limits (create.roblox.com/docs/production/analytics/event-types, 2026-10): 100 custom event
-- names; 10 funnels x 100 steps; 3 custom fields, 8,000 combined values before "Other"; 20 economy
-- transaction types and 100 item SKUs before "Other"; 120 + 20 x CCU events per minute in total.
-- Custom field values are clipped to 50 characters (Events.MAX_FIELD).

local TelemetryNames = {}

TelemetryNames.MAX_EVENT_NAME = 100
TelemetryNames.MAX_EVENTS = 100
TelemetryNames.MAX_FIELDS = 3
TelemetryNames.MAX_FIELD = 50
TelemetryNames.MAX_FUNNELS = 10 -- onboarding included
TelemetryNames.MAX_STEPS = 100

-- LogCustomEvent names. One event per concept; the difference lives in a field.
TelemetryNames.Custom = table.freeze({
	"CallEnded", -- a call ended for a participant (value = survivors saved): kind, result, context
	"OpGrade", -- a graded rescue (helpers only, value 0..3): kind, grade, rarity
	"ColdOpenEnded", -- why the cold open ended (Complete, Timer, Died, LeftCraft, ...)
	"StormJoined", -- Great Storm / ordinary storm, Start / MidStorm
	"DailyCrate", -- streak day, Daily / Welcome
	"PetAdopted", -- legacy (PetService equip): species, Rare / Common; the Companion funnel replaces it
	"CompanionSwitch", -- the companion changed on the phone: from species, to species
	"LiveEvent", -- a LiveOps event was live while the player was in the server
	"FriendBonus", -- friends in the server and the Cash percent they add
	"PromptShown", -- notify / favorite / invite prompt was shown
	"PhotoMode", -- photo mode was opened (once per session)
	"RobuxPrompt", -- a Robux prompt: Products / GamePasses, key, Shown / Purchased / Cancelled
	"BadgeAwarded", -- a Roblox badge was awarded: badge key
	"StickerFound", -- an album sticker: island, slot (Stamp, Critter, View, Bottle, Secret), sticker
	"AlbumPage", -- an island's album page completed: island
	"VehicleDespawned", -- reason (Idle, WrongMedium, Replaced, Left), vehicle, medium
	"VehicleRecovered", -- auto-recovery ran: reason (Flipped, Stuck, WrongMedium), vehicle
	"StuckReset", -- the player was reset out of a stuck spot: device, where (Foot, Boat, Car, Swim)
	"InputDead", -- input held with no response (client-detected): device, where
	"SessionStart", -- value = days since the first session: day bucket, gap bucket, New / Returning
	"SessionEnd", -- value = seconds played: length bucket, device, day bucket
} :: { string })

-- LogOnboardingFunnelStepEvent step names, in step order. Roblox treats a skipped step as
-- completed, so the order must match what a player does. Rebuilt 2026-10-24 (before launch) for the
-- docs/16 + docs/20 first 10 minutes; append only after launch.
TelemetryNames.Funnel = table.freeze({
	"Joined",
	"AtSea",
	"FirstBoard",
	"FirstDelivery",
	"RewardSeen",
	"Call2Accepted",
	"Call2Delivered",
	"Call3Delivered",
	"PhoneOpened",
	"FirstUpgrade",
	"FirstRank",
	"FirstVehicle",
	"Day2Return",
} :: { string })

-- LogFunnelStepEvent (recurring) funnels: name -> step names in order. One session id per call, shop
-- visit, vehicle spawn, island and species (TelemetryService). Append steps only after launch.
TelemetryNames.Funnels = table.freeze({
	Call = table.freeze({ "Offered", "Accepted", "Seated", "Boarded", "Delivered" }),
	Shop = table.freeze({ "PhoneOpened", "AppOpened", "ItemViewed", "BuyTapped", "Bought" }),
	Vehicle = table.freeze({ "Spawned", "Boarded", "Underway" }),
	Explore = table.freeze({ "Sighted", "Reached", "Stamped" }),
	Companion = table.freeze({ "Rescued", "Adopted", "Chosen" }),
} :: { [string]: { string } })

local function index(list: { string }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, name in list do
		out[name] = true
	end
	return out
end

local customSet = index(TelemetryNames.Custom)
local funnelSet = index(TelemetryNames.Funnel)

function TelemetryNames.isCustom(name: string): boolean
	return customSet[name] == true
end

function TelemetryNames.isFunnel(name: string): boolean
	return funnelSet[name] == true
end

-- True when every list passes Roblox's limits. The spec uses this; TelemetryService trusts the
-- constants at runtime (the cost of validating every event is not worth it).
function TelemetryNames.valid(): boolean
	local all = { TelemetryNames.Custom, TelemetryNames.Funnel }
	for _, steps in TelemetryNames.Funnels do
		table.insert(all, steps)
	end
	if #all - 1 > TelemetryNames.MAX_FUNNELS then
		return false
	end
	local seen: { [string]: boolean } = {}
	for i, list in all do
		if #list > (if i == 1 then TelemetryNames.MAX_EVENTS else TelemetryNames.MAX_STEPS) then
			return false
		end
		table.clear(seen)
		for _, name in list do
			if #name == 0 or #name > TelemetryNames.MAX_EVENT_NAME or seen[name] then
				return false
			end
			seen[name] = true
		end
	end
	return true
end

return TelemetryNames
