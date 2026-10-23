--!strict
-- Onboarding: the new player's first 15 minutes (docs/15 section 3), pure and Lune-tested
-- (tests/Onboarding.spec.luau). No services and no Roblox types.
--
-- The world shows one goal at a time, in this order: the station, the call board, the second
-- rescue (the first station call), then the first gear at about 5 minutes and the first
-- certification exercise at about 10. A goal only moves on when the player has done the thing;
-- `seconds` is time since the cold open ended, so a slow first rescue never rushes the pacing.
--
-- The first calls are fail-safe: condition is held above Critical for the cold open and the next
-- three calls, so a child who just holds the throttle cannot lose anyone. The casualty still comes
-- to the player on its own (PiwWays) and the throw bag aims itself after two misses (Ways).
local Onboarding = {}

Onboarding.GEAR_AT = 300 -- s after the cold open: the first gear beacon -- tune
-- s after the cold open: the certification exercise beacon. 360, not 600: with ~5 min calls the
-- gear lands at ~6:30 and a later beacon left the player idle; the exercise now ends near 10:00
-- (tests/NewPlayerPace.spec.luau) -- tune
Onboarding.CERT_AT = 360
Onboarding.WEATHER_HOLD = 300 -- s a running cold open may hold back a new storm (server-wide) -- tune
Onboarding.FAILSAFE_CALLS = 3 -- station calls after the cold open that cannot fail
Onboarding.FAILSAFE_FLOOR = 20 -- condition never reaches Critical on those calls
Onboarding.AUTO_AIM_MISSES = 2 -- throw misses before the bag aims itself (Assist only)
Onboarding.TOUCH = { throw = 160, grab = 160 } -- px, phone touch buttons (bigger than the 130 default)
Onboarding.REACH = {
	Station = 34,
	CallBoard = 11,
	Gear = 12,
	Cert = 10,
} -- studs, flat

export type Goal = "Station" | "CallBoard" | "Rescue" | "Gear" | "Cert"

export type Facts = {
	coldOpenDone: boolean,
	stationReached: boolean,
	boardReached: boolean,
	callsCompleted: number, -- station calls since the cold open (0 = the second rescue is next)
	offerReady: boolean,
	gearOwned: boolean,
	certEarned: boolean,
	seconds: number,
}

-- The one thing to look at now, or nil once the first session's goals are done.
function Onboarding.goal(f: Facts): Goal?
	if not f.coldOpenDone then
		return nil
	end
	if not f.stationReached then
		return "Station"
	end
	if not f.boardReached then
		return "CallBoard"
	end
	if f.callsCompleted < 1 then
		return "Rescue"
	end
	-- no Gear or Cert goal: the Chandlery counter and the exercise board are gone (docs/16 B5, B7)
	return if f.offerReady then "Rescue" else nil
end

-- The certification goal is done once a certification is earned or its exercise passed (the live
-- half then comes from calls, which a held Cert beacon would block). `certs` is the snapshot's
-- id -> { earned, exercisePassed } (ProgressionRules.snapshot).
function Onboarding.certDone(certs: { [string]: any }?): boolean
	if not certs then
		return false
	end
	for _, c in certs do
		if type(c) == "table" and (c.earned == true or c.exercisePassed == true) then
			return true
		end
	end
	return false
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

-- New taskings wait while the beacon points at another goal (docs/15 "one next thing"). "Rescue"
-- means an offer is already the goal, and nil means the first session's goals are done.
function Onboarding.holdsOffers(goal: string?): boolean
	return goal ~= nil and goal ~= "Rescue"
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

-- Assist turns the bag onto a landing the casualty can reach after two misses.
function Onboarding.throwAssist(misses: number, assist: boolean): boolean
	return assist and misses >= Onboarding.AUTO_AIM_MISSES
end

-- The reward burst belongs to a cold open the player actually rescued on.
function Onboarding.rewarded(reason: string?): boolean
	return reason == "Complete"
end

-- A short, text-free label for the beacon colour choice (client maps these to colours).
function Onboarding.goalKind(goal: Goal): "Place" | "Call" | "Gear" | "Cert"
	if goal == "Gear" then
		return "Gear"
	elseif goal == "Cert" then
		return "Cert"
	elseif goal == "Rescue" then
		return "Call"
	end
	return "Place"
end

return Onboarding
