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

-- kitFit 0..1: the share of the needed kit loaded, minus a little for dead weight.
function Medical.kitFit(picked: { string }, needed: { string }): number
	if #needed == 0 then
		return 1
	end
	local hit, junk = 0, 0
	for _, id in picked do
		if table.find(needed, id) then
			hit += 1
		elseif id == "towline" or id == "fenders" then
			junk += 1
		end
	end
	return math.clamp(hit / #needed - 0.15 * junk, 0, 1)
end

-- The tasking clue line ("about ten minutes, no lifejacket, not answering").
function Medical.kitClue(p: Profile): string
	local parts = { `in the water about {p.minutesBefore} minutes` }
	table.insert(parts, if p.lifejacket then "wearing a lifejacket" else "no lifejacket")
	local s = p.state
	table.insert(
		parts,
		if s == "Alert"
			then "waving, calling for help"
			elseif s == "Panicking" then "splashing, going under"
			elseif s == "Exhausted" then "low in the water, tired"
			elseif s == "VeryCold" then "slow to answer, very cold"
			else "not answering the informant"
	)
	return table.concat(parts, ", ")
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

-- Breaths a minute shown by the chest rise (tap-count cue for the B card).
function Medical.breathRate(p: Profile): number
	local _, _, answer = cue(p, "Breathing", false)
	return ({ 14, 28, 7, 0 })[answer]
end

function Medical.surveyCorrect(cards: { Card }, picks: { [string]: number }): number
	if #cards == 0 then
		return 1
	end
	local right = 0
	for _, c in cards do
		if picks[c.letter] == c.answer then
			right += 1
		end
	end
	return right / #cards
end

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
	{ id = "rub", label = "Rub arms and legs" },
	{ id = "hotpack", label = "Hot packs on bare skin" },
	{ id = "sitUp", label = "Sit them up" },
	{ id = "thrusts", label = "Abdominal thrusts" },
} :: { Treat }

-- What the book calls for, in order; and what is harmful for this casualty.
function Medical.treatmentPlan(
	p: Profile,
	carried: { [string]: boolean }?
): ({ string }, { [string]: boolean })
	local s = p.state
	local has = function(id: string): boolean
		return carried == nil or carried[id] == true
	end
	local need: { string } = {}
	local harmful: { [string]: boolean } = { rub = true, hotpack = true, thrusts = true }
	if p.notBreathing then
		need = { "cpr", "recovery", "casualtyBag" }
		harmful.sitUp, harmful.drink = true, true
	elseif s == "Unresponsive" then
		need = { "recovery", "oxygen", "casualtyBag" }
		harmful.sitUp, harmful.drink = true, true
	elseif s == "VeryCold" then
		need = { "horizontal", "shelter", "casualtyBag", "oxygen" }
		harmful.sitUp, harmful.drink = true, true
	elseif s == "Exhausted" then
		need = { "shelter", "casualtyBag", "oxygen" }
		harmful.drink = true
	else
		need = { "shelter", "casualtyBag", "hat" }
		if s == "Alert" then
			table.insert(need, "drink")
		else
			harmful.drink = true
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
	return out, harmful
end

-- matches 0..1 and the harmful count for an applied sequence. Doing the graze before the cold
-- items, or CPR late, costs order credit.
function Medical.treatmentScore(
	applied: { string },
	need: { string },
	harmful: { [string]: boolean }
): (number, number)
	local hit, bad = 0, 0
	for _, id in applied do
		if harmful[id] then
			bad += 1
		elseif table.find(need, id) then
			hit += 1
		end
	end
	local matches = if #need > 0 then hit / #need else 1
	local d = table.find(applied, "dressing")
	if d then
		for _, id in need do
			local i = table.find(applied, id)
			if id ~= "dressing" and i and i > d then
				matches -= 0.25
				break
			end
		end
	end
	if table.find(need, "cpr") and applied[1] ~= "cpr" then
		matches -= 0.25
	end
	return math.clamp(matches, 0, 1), bad
end

----------------------------------------------------------------------------------------------
-- Handover: ATMIST (docs 09 section 5.8).

export type Observed = {
	findings: { [string]: number }?, -- survey picks
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

local function rotate(options: { string }, answer: string, seed: number): ({ string }, number)
	local opts = table.clone(options)
	if not table.find(opts, answer) then
		opts[1] = answer
	end
	local shift = math.floor(seed * #opts) % #opts
	local out = {}
	for i = 1, #opts do
		out[i] = opts[(i - 1 + shift) % #opts + 1]
	end
	return out, table.find(out, answer) or 1
end

function Medical.atmistCards(p: Profile, id: string, observed: Observed): { Card }
	local total = p.minutesBefore + observed.minutesOnScene
	local nearest = math.clamp(math.floor(total / 10 + 0.5) * 10, 10, 40)
	local cards = {}
	local function add(
		letter: string,
		title: string,
		c: string,
		options: { string },
		answer: string,
		salt: number
	)
		local opts, right = rotate(options, answer, Units.hash01(id, salt))
		table.insert(
			cards,
			{ letter = letter, title = title, cue = c, options = opts, answer = right }
		)
	end
	add("A", "A  Age", "Who you pulled out", { "Child", "Adult", "Older adult" }, p.ageBand, 11)
	add(
		"T",
		"T  Time",
		"Datum time plus your time on scene",
		{ "In the water about 10 min", "about 20 min", "about 30 min", "about 40 min" },
		if nearest == 10 then "In the water about 10 min" else `about {nearest} min`,
		12
	)
	add(
		"M",
		"M  Mechanism",
		"What the informant and the casualty said",
		Medical.Mechanisms,
		p.mechanism,
		13
	)
	add(
		"I",
		"I  Injuries",
		"What your survey found",
		{ "None seen", "Scrape on the arm" },
		if p.scrape then "Scrape on the arm" else "None seen",
		14
	)
	add("S", "S  Signs", "AVPU, breathing, shivering", {
		"Alert, breathing normally, shivering",
		"Responds to voice, not shivering, drowsy",
		"Unresponsive, breathing slowly",
		"Responds to voice, breathing fast, shivering",
	}, signsText(p), 15)
	local done = treatmentText(observed.applied or {})
	add(
		"T2",
		"T  Treatment",
		"What you actually did, in order",
		{ done, "Hot drink, rubbed warm", "Sat them up, oxygen" },
		done,
		16
	)
	return cards
end

return Medical
