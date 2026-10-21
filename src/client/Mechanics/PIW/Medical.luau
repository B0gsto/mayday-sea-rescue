--!strict
-- PIW/Medical: the casualty's profile, the kit for the tasking, the DR ABCDE primary survey, the
-- treatment that follows from it and the ATMIST handover (docs 09 sections 5.1, 5.5, 5.6, 5.8).
-- The truth comes from the casualty's state and id (the same on every client); the player only
-- ever sees cues. Pure (Lune-tested).
local Units = require(script.Parent.Units)

local Medical = {}

export type Profile = {
	ageBand: string, -- "Child" | "Adult" | "Older adult"
	mechanism: string,
	scrape: boolean,
	minutesBefore: number, -- in the water before the tasking
	notBreathing: boolean, -- needs CPR (drowning, no lifejacket, unresponsive)
	state: string,
	lifejacket: boolean,
}

Medical.Mechanisms = { "Caught in a rip", "Fell off a paddleboard", "Swam too far out" }

function Medical.profile(
	id: string,
	state: string,
	lifejacket: boolean,
	sceneKind: string?
): Profile
	local a = Units.hash01(id, 1)
	local ageBand = if a < 0.25 then "Child" elseif a < 0.8 then "Adult" else "Older adult"
	local mechanism = if sceneKind == "DriftingCraft"
		then "Fell off a paddleboard"
		else Medical.Mechanisms[1 + math.floor(Units.hash01(id, 2) * 3) % 3]
	local cold = state == "VeryCold" or state == "Unresponsive"
	return {
		ageBand = ageBand,
		mechanism = mechanism,
		scrape = Units.hash01(id, 3) < 0.3,
		minutesBefore = if cold or not lifejacket then 20 else 10,
		notBreathing = state == "Unresponsive" and not lifejacket,
		state = state,
		lifejacket = lifejacket,
	}
end

----------------------------------------------------------------------------------------------
-- Kit and launch (docs 09 step 2): the tasking's clues say which kit this casualty needs.

export type KitItem = { id: string, label: string, ribOnly: boolean? }

Medical.Kit = {
	{ id = "throwbag", label = "Throw bag" },
	{ id = "tube", label = "Rescue tube" },
	{ id = "casualtyBag", label = "Casualty bag" },
	{ id = "firstAid", label = "First aid kit" },
	{ id = "oxygen", label = "Oxygen set", ribOnly = true },
	{ id = "strop", label = "Recovery strop / net", ribOnly = true },
	{ id = "lifejacket", label = "Spare lifejacket" },
	{ id = "towline", label = "Tow line" },
	{ id = "fenders", label = "Fenders" },
} :: { KitItem }

function Medical.kitSlots(isJetSki: boolean): number
	return if isJetSki then 3 else 5
end

-- The kit the book calls for, most important first (the jet ski only has the first slots).
function Medical.kitNeeded(state: string, lifejacket: boolean, isJetSki: boolean): { string }
	local need: { string }
	if state == "Alert" then
		need = { "throwbag", "casualtyBag", "firstAid" }
	elseif state == "Panicking" then
		need = { "tube", "casualtyBag", "firstAid" }
	elseif state == "Exhausted" then
		need = { "tube", "casualtyBag", "oxygen", "firstAid" }
	elseif state == "VeryCold" then
		need = { "casualtyBag", "strop", "tube", "oxygen" }
	else
		need = { "tube", "oxygen", "strop", "casualtyBag" }
	end
	if not lifejacket then
		table.insert(need, 2, "lifejacket")
	end
	local out = {}
	for _, id in need do
		local ribOnly = id == "oxygen" or id == "strop"
		if not (isJetSki and ribOnly) then
			table.insert(out, id)
		end
	end
	local slots = Medical.kitSlots(isJetSki)
	while #out > slots do
		table.remove(out)
	end
	return out
end

----------------------------------------------------------------------------------------------
-- Primary survey: DR ABCDE (docs 09 section 5.5).

export type Card =
	{ letter: string, title: string, cue: string, options: { string }, answer: number }

local function cue(p: Profile, letter: string, storm: boolean): (string, { string }, number)
	local s = p.state
	local cold = s == "VeryCold" or s == "Unresponsive"
	if letter == "Danger" then
		local opts = { "Safe to work", "Move them out of the wind first" }
		return if storm
			then "Spray coming over the tubes, the casualty is in the wind"
			else "Boat steady, engine in neutral, sea slight",
			opts,
			if storm then 2 else 1
	elseif letter == "Response" then
		local opts = { "Alert", "Voice", "Pain", "Unresponsive" }
		if s == "Alert" or s == "Panicking" then
			return `"I'm okay... just c-cold." Looks at you when you speak.`, opts, 1
		elseif s == "Exhausted" or s == "VeryCold" then
			return "Eyes closed until you call their name, then a mumble.", opts, 2
		end
		return "No answer to your voice or a firm shoulder squeeze. Eyes closed.", opts, 4
	elseif letter == "Airway" then
		local opts = { "Clear", "Needs opening (head tilt)" }
		if s == "Unresponsive" then
			return "Head slumped forward, a gurgle with each breath.", opts, 2
		end
		return "Talking or coughing up a little seawater; air moving freely.", opts, 1
	elseif letter == "Breathing" then
		local opts = { "Normal", "Fast", "Slow", "Not breathing normally" }
		if p.notBreathing then
			return "No chest rise; one gasp in ten seconds.", opts, 4
		elseif s == "Panicking" or s == "Exhausted" then
			return "Chest rising fast and shallow.", opts, 2
		elseif cold then
			return "Chest rising slowly, long gaps.", opts, 3
		end
		return "Chest rising steadily.", opts, 1
	elseif letter == "Circulation" then
		local opts = { "Normal", "Pale and cold", "Bleeding (small)" }
		if cold or s == "Exhausted" then
			return "Skin pale and cold to touch, lips bluish.", opts, 2
		elseif p.scrape then
			return "Colour good; a small graze on the forearm, oozing.", opts, 3
		end
		return "Colour good, hands warm-ish.", opts, 1
	elseif letter == "Disability" then
		local opts = { "Shivering", "Not shivering, drowsy" }
		if cold then
			return "Not shivering any more; drowsy, speech slurred.", opts, 2
		end
		return "Shivering hard, teeth chattering, knows where they are.", opts, 1
	end
	-- Exposure
	return `Soaked through; {p.minutesBefore} minutes in the water, wind on them.`,
		{ "Wet and cold", "Dry" },
		1
end

Medical.FullSurvey =
	{ "Danger", "Response", "Airway", "Breathing", "Circulation", "Disability", "Exposure" }
Medical.JetSkiSurvey = { "Response", "Breathing", "Disability" } -- no room for more on a sled

local TITLES = {
	Danger = "D  Danger",
	Response = "R  Response (AVPU)",
	Airway = "A  Airway",
	Breathing = "B  Breathing",
	Circulation = "C  Circulation",
	Disability = "D  Disability",
	Exposure = "E  Exposure",
}

function Medical.surveyCards(p: Profile, isJetSki: boolean, storm: boolean): { Card }
	local out = {}
	local letters: { string } = if isJetSki then Medical.JetSkiSurvey else Medical.FullSurvey
	for _, letter in letters do
		local c, opts, answer = cue(p, letter, storm)
		table.insert(
			out,
			{ letter = letter, title = TITLES[letter], cue = c, options = opts, answer = answer }
		)
	end
	return out
end

-- Breaths a minute the casualty shows (breath puffs) for each Breathing answer.
Medical.BREATHS = { 14, 28, 7, 0 }

----------------------------------------------------------------------------------------------
-- Treatment (docs 09 section 5.6). Items are applied in order onto the casualty.

export type Treat = { id: string, label: string, needs: string? }

Medical.Treatments = {
	{ id = "shelter", label = "Shelter from the wind" },
	{ id = "horizontal", label = "Keep them flat" },
	{ id = "casualtyBag", label = "Casualty bag", needs = "casualtyBag" },
	{ id = "hat", label = "Hat on" },
	{ id = "oxygen", label = "Oxygen, 15 L/min mask", needs = "oxygen" },
	{ id = "recovery", label = "Recovery position" },
	{ id = "drink", label = "Warm sweet drink" },
	{ id = "dressing", label = "Dressing on the graze", needs = "firstAid" },
	{ id = "cpr", label = "Start CPR" },
} :: { Treat }

-- What the book calls for, in order (the crew hands the items over while the Medic holds on).
function Medical.treatmentPlan(p: Profile, carried: { [string]: boolean }?): { string }
	local s = p.state
	local has = function(id: string): boolean
		return carried == nil or carried[id] == true
	end
	local need: { string }
	if p.notBreathing then
		need = { "cpr", "recovery", "casualtyBag" }
	elseif s == "Unresponsive" then
		need = { "recovery", "oxygen", "casualtyBag" }
	elseif s == "VeryCold" then
		need = { "horizontal", "shelter", "casualtyBag", "oxygen" }
	elseif s == "Exhausted" then
		need = { "shelter", "casualtyBag", "oxygen" }
	else
		need = { "shelter", "casualtyBag", "hat" }
		if s == "Alert" then
			table.insert(need, "drink")
		end
	end
	if p.scrape and s ~= "Unresponsive" then
		table.insert(need, "dressing") -- after the cold is dealt with
	end
	local out = {}
	for _, id in need do
		if id ~= "oxygen" and id ~= "casualtyBag" or has(id) then
			table.insert(out, id)
		end
	end
	return out
end

----------------------------------------------------------------------------------------------
-- Handover: ATMIST (docs 09 section 5.8).

export type Observed = {
	applied: { string }?, -- treatments in order
	minutesOnScene: number,
}

local function treatmentText(ids: { string }): string
	local names = {}
	for _, id in ids do
		for _, t in Medical.Treatments do
			if t.id == id then
				table.insert(names, (string.gsub(t.label, ", 15 L/min mask", "")))
			end
		end
		if #names >= 3 then
			break
		end
	end
	return if #names == 0 then "Nothing yet" else table.concat(names, ", ")
end

local function signsText(p: Profile): string
	local s = p.state
	if p.notBreathing then
		return "Unresponsive, not breathing normally"
	elseif s == "Unresponsive" then
		return "Unresponsive, breathing slowly"
	elseif s == "VeryCold" then
		return "Responds to voice, not shivering, drowsy"
	elseif s == "Exhausted" then
		return "Responds to voice, breathing fast, shivering"
	end
	return "Alert, breathing normally, shivering"
end

export type Line = { letter: string, title: string, text: string }

-- The ATMIST record the crew reads to the paramedic: the truth from what this crew saw and did.
function Medical.atmist(p: Profile, observed: Observed): { Line }
	local total = p.minutesBefore + observed.minutesOnScene
	local nearest = math.clamp(math.floor(total / 10 + 0.5) * 10, 10, 40)
	return {
		{ letter = "A", title = "Age", text = p.ageBand },
		{ letter = "T", title = "Time", text = `In the water about {nearest} min` },
		{ letter = "M", title = "Mechanism", text = p.mechanism },
		{
			letter = "I",
			title = "Injuries",
			text = if p.scrape then "Scrape on the arm" else "None seen",
		},
		{ letter = "S", title = "Signs", text = signsText(p) },
		{ letter = "T", title = "Treatment", text = treatmentText(observed.applied or {}) },
	}
end

return Medical
