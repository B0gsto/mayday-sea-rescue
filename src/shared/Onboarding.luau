--!strict
-- Onboarding: a new player's first 10 minutes (docs/16 section 4), pure and Lune-tested
-- (tests/Onboarding.spec.luau). No services and no Roblox types.
--
-- No tutorial text: the world shows the one next thing. After the cold open that is always the
-- next tutorial call (CallTypes.TutorialChain entries 2 to 5, beats B2 to B9): while its offer
-- waits, a flare, the beacon and the minimap blip mark it. Nothing walks the player to the station
-- or holds offers back; after the last tutorial call goal() returns nil and the normal mix runs.
--
-- The first calls are fail-safe: condition is held above Critical for the cold open and the next
-- three calls, so a child who just holds the throttle cannot lose anyone.
--
-- docs/24 E, docs/25 J: the tutorial's first beat is the free Rescue Hut (HQ Lv1) from the build stand, then
-- the saved beat (data.tutorialStep) walks the world from the cold open to the next build and the first spin. `beat` is pure and reads only saved facts, so a returning player
-- resumes where the save left them; a save that already has a building or 5+ rescues (made before
-- this tutorial existed) skips to the permanent Next chip. The start set (the jetty, the Hut) never counts. The build tablet tops up a new player's
-- Cash to the Workshop price exactly once; the server clients the first rescued survivor as a Builder.
local Onboarding = {}

Onboarding.WEATHER_HOLD = 300 -- s a running cold open may hold back a new storm (server-wide) -- tune
Onboarding.FAILSAFE_CALLS = 3 -- station calls after the cold open that cannot fail
Onboarding.FAILSAFE_FLOOR = 20 -- condition never reaches Critical on those calls
Onboarding.TUTORIAL_CALLS = 4 -- station calls after the cold open (#CallTypes.TutorialChain - 1)

-- Saved tutorial beats (data.tutorialStep). The step only ever moves forward; facts fill the rest.
Onboarding.STEP_RESCUE = 1 -- the cold open is home; the next call is the goal (not written yet)
Onboarding.STEP_SITE = 2 -- the Workshop site is running
Onboarding.STEP_SPIN = 3 -- the Workshop is done; the one tutorial spin waits in the menu
Onboarding.STEP_DONE = 4 -- the tutorial is over, the Next chip leads from here
Onboarding.SKIP_RESCUES = 5 -- an old save with this many rescues never starts the tutorial
Onboarding.WORKSHOP = "Workshop"
Onboarding.HQ = "HQ" -- the free first build (docs/25 J)
local START = { Harbour = true, HQ = true } -- every new island has the jetty and builds the Hut first

-- Any building beyond the start set: an established save.
local function established(owned: { [string]: boolean }?): boolean
	local map: { [string]: boolean } = owned or {}
	for key, has in map do
		if has == true and not START[key] then
			return true
		end
	end
	return false
end

export type Goal = "Rescue"
export type Beat =
	"BuildHQ"
	| "HQSite"
	| "ColdOpen"
	| "Rescue"
	| "BuildStation"
	| "Build"
	| "Spin"
	| "Done"

export type BeatFacts = {
	coldOpenDone: boolean,
	totalRescues: number,
	step: number?, -- data.tutorialStep (nil = never started)
	owned: { [string]: boolean }, -- data.dockBuildings
	constructionKey: string?, -- the island's running site (plot SiteKey)
}

export type Facts = {
	coldOpenDone: boolean,
	callsCompleted: number, -- station calls since the cold open (0 = call 2 is next)
	offerReady: boolean,
}

-- The one thing to look at now, or nil (no offer up, or the tutorial calls are done).
function Onboarding.goal(f: Facts): Goal?
	if not f.coldOpenDone or f.callsCompleted >= Onboarding.TUTORIAL_CALLS then
		return nil
	end
	return if f.offerReady then "Rescue" else nil
end

-- True on a call that must not fail (the cold open and the first three station calls).
function Onboarding.failsafeCall(completed: number): boolean
	return completed <= Onboarding.FAILSAFE_CALLS
end

-- True while the HUD stays stripped for a new player: the cold open and the first three station
-- calls. `opsCompletedTotal` is the saved count (the cold open is one of them).
function Onboarding.newPlayerHud(coldOpenDone: boolean, opsCompletedTotal: number?): boolean
	if not coldOpenDone then
		return true
	end
	return (opsCompletedTotal or 0) <= Onboarding.FAILSAFE_CALLS
end

-- Holds every casualty on a failsafe call at or above the Critical band. Returns true when it
-- changed a condition. Mutates `casualties` (OperationService calls it after Condition.step).
function Onboarding.protect(casualties: { any }, completed: number): boolean
	if not Onboarding.failsafeCall(completed) then
		return false
	end
	local changed = false
	for _, c in casualties do
		if type(c) == "table" and type(c.condition) == "number" then
			if c.condition < Onboarding.FAILSAFE_FLOOR then
				c.condition = Onboarding.FAILSAFE_FLOOR
				changed = true
			end
		end
	end
	return changed
end

-- The reward burst belongs to a cold open the player actually rescued on.
function Onboarding.rewarded(reason: string?): boolean
	return reason == "Complete"
end

-- Never start the tutorial on an established save (or a save from before docs/24 E): any building or
-- five people home sends them straight to the Next chip. A saved step always wins.
function Onboarding.skip(f: BeatFacts): boolean
	if f.step and f.step >= Onboarding.STEP_RESCUE then
		return false
	end
	return (f.totalRescues or 0) >= Onboarding.SKIP_RESCUES or established(f.owned)
end

-- The one beat to show now (docs/24 E, docs/25 J): the build stand -> the Hut site -> jet ski -> first
-- survivor -> the build tablet -> Workshop site -> Spin -> done. `Build` also runs while the next tutorial call is the actual goal; the
-- controller shows the call marker then.
function Onboarding.beat(f: BeatFacts): Beat
	if f.step and f.step >= Onboarding.STEP_DONE then
		return "Done"
	end
	if Onboarding.skip(f) then
		return "Done"
	end
	if (f.owned or {})[Onboarding.HQ] ~= true then
		return if f.constructionKey == Onboarding.HQ then "HQSite" else "BuildHQ"
	end
	if not f.coldOpenDone then
		return "ColdOpen"
	end
	if (f.owned or {})[Onboarding.WORKSHOP] == true then
		return "Spin"
	end
	if f.constructionKey == Onboarding.WORKSHOP then
		return "Build"
	end
	if (f.totalRescues or 0) >= 1 or (f.step and f.step >= Onboarding.STEP_RESCUE) then
		return "BuildStation"
	end
	return "Rescue"
end

-- The tutorial's first survivor is always a Builder, so the island can show one walking to the
-- build station (docs/24 E beat 2). Only before anyone has been delivered; the random roll returns
-- for everyone else.
function Onboarding.buildersFirst(
	totalRescues: number?,
	step: number?,
	owned: { [string]: boolean }?
): boolean
	if (step or 0) >= Onboarding.STEP_SITE then
		return false
	end
	return (totalRescues or 0) <= 0 and not established(owned)
end

-- Cash the tutorial adds so the Workshop is affordable (0 when it already is): exactly the gap.
function Onboarding.topUp(cash: number, price: number): number
	if price <= 0 then
		return 0
	end
	return math.max(0, math.floor(price - math.max(0, cash)))
end

return Onboarding
