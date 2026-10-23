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
local Onboarding = {}

Onboarding.WEATHER_HOLD = 300 -- s a running cold open may hold back a new storm (server-wide) -- tune
Onboarding.FAILSAFE_CALLS = 3 -- station calls after the cold open that cannot fail
Onboarding.FAILSAFE_FLOOR = 20 -- condition never reaches Critical on those calls
Onboarding.TUTORIAL_CALLS = 4 -- station calls after the cold open (#CallTypes.TutorialChain - 1)

export type Goal = "Rescue"

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

return Onboarding
