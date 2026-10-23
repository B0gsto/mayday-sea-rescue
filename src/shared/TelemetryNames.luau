--!strict
-- TelemetryNames (G64): the fixed list of analytics event names. Pure and Lune-tested
-- (tests/TelemetryNames.spec.luau): every name unique, short and inside Roblox's limits. Nothing
-- here sends anything; TelemetryService is still the only caller of AnalyticsService.
--
-- Keep this list small and stable. AnalyticsService allows 100 custom event names per game and
-- slices on custom fields, so a new variant of an existing event should be a field value, not a
-- new name. Funnel step names are a separate list (they belong to the onboarding funnel).
--
-- Limits: custom event name 100 characters (Roblox), custom field value 50 (Events.MAX_FIELD),
-- at most 3 custom fields (Enum.AnalyticsCustomFieldKeys CustomField01..03).

local TelemetryNames = {}

TelemetryNames.MAX_EVENT_NAME = 100
TelemetryNames.MAX_EVENTS = 100
TelemetryNames.MAX_FIELDS = 3
TelemetryNames.MAX_FIELD = 50

-- LogCustomEvent names. One event per concept; the difference lives in a field.
TelemetryNames.Custom = table.freeze({
	"OpStarted", -- an operation was accepted: kind, rarity, context
	"OpGrade", -- a graded rescue step: kind, grade, rarity
	"OpComplete", -- an operation ended for a participant: kind, grade, rarity
	"OpFailed", -- timeout/takeover/failed grade: kind, reason, context
	"ColdOpenEnded", -- why the cold open ended (Complete, Timer, Died, LeftCraft, ...)
	"StormJoined", -- Great Storm / ordinary storm, Start / MidStorm
	"DailyCrate", -- streak day, Daily / Welcome
	"ChallengeDone", -- daily / weekly, challenge id
	"AlbumSticker", -- a new Rescue Album sticker: rarity, variant id
	"PetAdopted", -- species, Rare / Common (the pet that follows you)
	"PetPetted", -- the hold-to-pet action was used (client reports it, once per session)
	"PetTreated", -- species, bond pips after the treat
	"StockBuy", -- Chandlery shelf purchase: Gear / Cosmetic, item key
	"SeasonClaim", -- Season Logbook tier claimed (value = tier)
	"EventJoined", -- GhostLight / GhostShip / FrostFleet, once per event window
	"LiveEvent", -- a LiveOps event was live while the player was in the server
	"FriendBonus", -- friends in the server and the Cash percent they add
	"CrewFlare", -- a crew-up flare was fired
	"PromptShown", -- notify / favorite / invite prompt was shown
	"PhotoMode", -- photo mode was opened (once per session)
} :: { string })

-- LogOnboardingFunnelStepEvent step names, in step order. Roblox treats a skipped step as
-- completed, so the order must match what a player does (docs/research/analytics.md). G64
-- renumbered the funnels once, before launch; append only after launch.
TelemetryNames.Funnel = table.freeze({
	"Joined",
	"ColdOpenStarted",
	"ColdOpenApproach",
	"ColdOpenRecovery",
	"ColdOpenEnded",
	"RewardSeen",
	"ReachedStation",
	"Call2Accepted",
	"FirstOpComplete",
	"Call3Complete",
	"FirstChandleryVisit",
	"FirstUnlock",
	"FirstRank",
	"FirstDailyCrate",
	"Day2Return",
} :: { string })

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
	if #TelemetryNames.Custom > TelemetryNames.MAX_EVENTS then
		return false
	end
	if #TelemetryNames.Funnel > TelemetryNames.MAX_EVENTS then
		return false
	end
	local seen: { [string]: boolean } = {}
	local all = { TelemetryNames.Custom, TelemetryNames.Funnel }
	for _, list in all do
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
