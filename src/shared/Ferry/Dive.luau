--!strict
-- Air-pocket dive helpers (docs/09 section 7 step 6). Pure, Lune-tested in
-- tests/MechFerryDive.spec.luau, used by src/client/Mechanics/air_pocket.luau.
--
-- Real practice (verify: diving line-signal standard, e.g. HSE commercial diving ACoP): the diver
-- follows a guideline, a tender on the surface pays the line out and in, a standby diver waits
-- ready. Line signals are pulls: 1 = "all OK?" / "I am OK", 2 = "give slack", 3 = "take in".
-- Air is planned by the rule of thirds: a third in, a third out, a third in reserve. Air in a
-- trapped space goes stale over time, so the job is calm but never slow.

local Dive = {}

Dive.Signals = {
	[1] = { pulls = 1, meaning = "All OK?", reply = "I am OK" },
	[2] = { pulls = 2, meaning = "Give slack", reply = "Slack given" },
	[3] = { pulls = 3, meaning = "Take in", reply = "Taking in" },
}

Dive.StartBar = 200
Dive.ReserveBar = 50
Dive.PullGap = 0.9 -- a pull group ends after this long without a pull
Dive.MinPullSpacing = 0.12 -- pulls closer than this count as one jerk

-- Rule of thirds, worked out at the start of each penetration: the pressure at which the diver
-- must turn for home is the current pressure minus a third of the usable air.
function Dive.turnPressure(currentBar: number, reserveBar: number): number
	return currentBar - math.max(0, currentBar - reserveBar) / 3
end

-- Air use in bar a second: calm breathing on the line, more when off the line (searching,
-- finning hard) or towing a passenger. Trainees breathe a little harder.
function Dive.airRate(onLine: boolean, towing: boolean, trainee: boolean): number
	local r = 1.0
	if not onLine then
		r *= 1.7
	end
	if towing then
		r *= 1.3
	end
	if trainee then
		r *= 1.1
	end
	return r
end

-- Stale air in the pocket: 100 = fresh, below `AirQualityTakeover` the mainland dive team takes
-- over (the fail-safe; everyone stays safe). Anxious survivors breathe faster until calmed.
Dive.AirQualityTakeover = 25
function Dive.airQualityRate(occupants: number, calmed: boolean): number
	return 0.22 * occupants * (if calmed then 1 else 1.6)
end

-- Progress along the guideline a second (0..1 per leg). Off the line the diver stops and feels
-- for it; a tight line (slack not given at the gunwale) stops the diver too.
function Dive.progressRate(onLine: boolean, lineTight: boolean, towing: boolean): number
	if not onLine or lineTight then
		return 0
	end
	return if towing then 0.11 else 0.15
end

-- Groups pull times (ascending) into a signal once `now` is past the last pull by PullGap.
-- Returns the pull count, or nil while the group is still open (or empty).
function Dive.readPulls(times: { number }, now: number): number?
	if #times == 0 then
		return nil
	end
	if now - times[#times] < Dive.PullGap then
		return nil
	end
	local n, last = 0, -math.huge
	for _, t in times do
		if t - last >= Dive.MinPullSpacing then
			n += 1
		end
		last = t
	end
	return n
end

-- The answer a diver gives to a tender's signal: always repeat it back.
function Dive.replyTo(tenderSignal: number): number
	return tenderSignal
end

-- The signal the diver must send at a point in the dive.
Dive.SignalFor = {
	descend = 1, -- "I am OK", going in
	gunwale = 2, -- under the gunwale: "give slack"
	leaving = 3, -- with a passenger: "take in"
}

-- Score for the debrief advisory grade: survivors out and signal mistakes.
function Dive.grade(rescued: number, mistakes: number): string
	if rescued >= 2 and mistakes == 0 then
		return "Gold"
	elseif rescued >= 2 and mistakes <= 1 then
		return "Silver"
	elseif rescued >= 1 then
		return "Bronze"
	end
	return "Fail"
end

-- The air gauge in words, for subtitles and Pro mode (no numbers on screen in Pro).
function Dive.gaugeWord(bar: number, turnBar: number): string
	if bar <= Dive.ReserveBar then
		return "Reserve: head out now"
	elseif bar <= turnBar then
		return "Past turn pressure"
	end
	return "Plenty of air"
end

return Dive
