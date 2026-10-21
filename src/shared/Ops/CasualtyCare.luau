--!strict
-- CasualtyCare: pure rules for the hands-on casualty care steps (docs 14 section 2: no choice UI).
-- The client mechanics (primary_survey, treat, triage, panic_calm) are world actions: look at a
-- body area and hold to check it, grab a kit item and put it on the body, place a coloured tag,
-- keep still facing a panicking swimmer. This module says which area answers what, what sticks
-- where and how fast a swimmer calms. Lune-tested in tests/CasualtyCare.spec.luau.
local CasualtyCare = {}

---------------------------------------------------------------- body areas

-- The body areas the hands can work on, in the order they are offered.
CasualtyCare.AREAS = { "head", "chest", "arm", "hand", "body", "legs" }

-- Primary survey: the area that answers each DR ABCDE letter (Danger is read from the scene).
CasualtyCare.SURVEY_AREA = {
	Response = "head",
	Airway = "head", -- tilt the head
	Breathing = "chest", -- hand on the chest
	Circulation = "arm", -- colour, the graze
	Disability = "body", -- shivering or not
	Exposure = "body",
} :: { [string]: string }

local function ordered(want: { [string]: boolean }): { string }
	local out = {}
	for _, a in CasualtyCare.AREAS do
		if want[a] then
			table.insert(out, a)
		end
	end
	return out
end

-- The areas a survey of these letters needs, each once, head to toe.
function CasualtyCare.surveyAreas(letters: { string }): { string }
	local want = {}
	for _, l in letters do
		local a = CasualtyCare.SURVEY_AREA[l]
		if a then
			want[a] = true
		end
	end
	return ordered(want)
end

-- The letters one area answers (in the survey's own order).
function CasualtyCare.lettersAt(area: string, letters: { string }): { string }
	local out = {}
	for _, l in letters do
		if CasualtyCare.SURVEY_AREA[l] == area then
			table.insert(out, l)
		end
	end
	return out
end

-- The share of the work the player did (the crew does the rest), rounded to 0.01.
function CasualtyCare.share(mine: number, total: number): number
	if total <= 0 then
		return 1
	end
	return math.floor(math.clamp(mine / total, 0, 1) * 100 + 0.5) / 100
end

---------------------------------------------------------------- treatment kit

export type Item = { areas: { string }, needs: string? }

-- Physical items in the open kit box and where on the body each one goes.
CasualtyCare.ITEMS = {
	casualtyBag = { areas = { "body", "chest", "legs" }, needs = "casualtyBag" }, -- foil blanket
	hat = { areas = { "head" } },
	oxygen = { areas = { "head" }, needs = "oxygen" }, -- mask on the face
	dressing = { areas = { "arm", "hand" }, needs = "firstAid" },
	drink = { areas = { "head" } }, -- warm flask to the lips
} :: { [string]: Item }
CasualtyCare.ITEM_ORDER = { "casualtyBag", "hat", "oxygen", "dressing", "drink" }

-- Plan steps done with the hands, not an item: hold on the body (shelter, lay flat, roll over).
CasualtyCare.HANDS = { shelter = true, horizontal = true, recovery = true } :: { [string]: boolean }

-- Every item the crew carries lies in the box, needed or not (a wrong one simply won't stick),
-- and anything the plan calls for (the plan never asks for kit left ashore).
function CasualtyCare.tray(carried: { [string]: boolean }?, plan: { string }?): { string }
	local out = {}
	for _, id in CasualtyCare.ITEM_ORDER do
		local needs = CasualtyCare.ITEMS[id].needs
		if
			needs == nil
			or carried == nil
			or carried[needs] == true
			or (plan ~= nil and table.find(plan, id) ~= nil)
		then
			table.insert(out, id)
		end
	end
	return out
end

-- Does `item` stick on `area` now: needed, not on yet, and a place it belongs. Any order works.
function CasualtyCare.fits(
	item: string,
	area: string,
	plan: { string },
	applied: { string }
): boolean
	local def = CasualtyCare.ITEMS[item]
	return def ~= nil
		and table.find(plan, item) ~= nil
		and table.find(applied, item) == nil
		and table.find(def.areas, area) ~= nil
end

-- The plan steps not done yet, in plan order.
function CasualtyCare.remaining(plan: { string }, applied: { string }): { string }
	local out = {}
	for _, id in plan do
		if table.find(applied, id) == nil then
			table.insert(out, id)
		end
	end
	return out
end

-- The next hands-on step not done yet (shelter / flat / recovery position), or nil.
function CasualtyCare.nextHands(plan: { string }, applied: { string }): string?
	for _, id in CasualtyCare.remaining(plan, applied) do
		if CasualtyCare.HANDS[id] then
			return id
		end
	end
	return nil
end

---------------------------------------------------------------- CPR

-- Kneel at the chest (hold), push on the beat ring, hold at the head for each breath. It never
-- fails: an off-beat push still moves it on, just slower, and nothing ever resets.
CasualtyCare.CPR_KNEEL = 0.6 -- s holding at the chest to kneel
CasualtyCare.CPR_BREATH = 0.8 -- s holding at the head per breath (about one second each)
CasualtyCare.CPR_OFF_BEAT = 0.5 -- progress from a push off the beat (on the beat: 1)

export type Cpr = {
	seq: { string }, -- "B" breath, "C" compression (PIW/Rhythm.cprSequence)
	i: number, -- the prompt being worked on
	credit: number, -- progress on the current compression, 0..1
	onBeat: number,
	compressions: number,
	breathsRight: number,
	breaths: number,
}

function CasualtyCare.cpr(seq: { string }): Cpr
	return {
		seq = seq,
		i = 1,
		credit = 0,
		onBeat = 0,
		compressions = 0,
		breathsRight = 0,
		breaths = 0,
	}
end

-- "C", "B", or nil when done.
function CasualtyCare.cprWants(c: Cpr): string?
	return c.seq[c.i]
end

-- A push on the chest. Ignored unless a compression is wanted.
function CasualtyCare.cprPush(c: Cpr, onBeat: boolean): boolean
	if c.seq[c.i] ~= "C" then
		return false
	end
	c.compressions += 1
	c.onBeat += if onBeat then 1 else 0
	c.credit += if onBeat then 1 else CasualtyCare.CPR_OFF_BEAT
	while c.credit >= 1 and c.seq[c.i] == "C" do
		c.credit -= 1
		c.i += 1
	end
	if c.seq[c.i] ~= "C" then
		c.credit = 0 -- leftover never spills into the breaths
	end
	return true
end

-- A breath held long enough at the head. Ignored unless a breath is wanted.
function CasualtyCare.cprBreath(c: Cpr): boolean
	if c.seq[c.i] ~= "B" then
		return false
	end
	c.breaths += 1
	c.breathsRight += 1
	c.i += 1
	return true
end

-- How far through this run of compressions (0..1), for the bar under the glyph.
function CasualtyCare.cprCycle(c: Cpr): number
	local first, last = c.i, c.i
	while first > 1 and c.seq[first - 1] == "C" do
		first -= 1
	end
	while c.seq[last + 1] == "C" do
		last += 1
	end
	return math.clamp((c.i - first + c.credit) / (last - first + 1), 0, 1)
end

---------------------------------------------------------------- calming a panicking swimmer

CasualtyCare.START = 95 -- panic when the step starts
CasualtyCare.ACCEPT = 30 -- under this they take the tube
CasualtyCare.GRAB = 40 -- over this, a rescuer inside arm's length gets grabbed
CasualtyCare.ARM = 5.4 -- studs, one body length
CasualtyCare.REACH = 14 -- studs: the tube held out from a swimmer or over the sponson reaches them
CasualtyCare.TALK = 40 -- studs: close enough that they see and hear you
CasualtyCare.STILL = 3 -- studs/s: slower than this is holding position (about 2 knots)
CasualtyCare.RUSH = 8 -- studs/s: faster than this close in is rushing them
CasualtyCare.FACING = 40 -- deg between your look and them
CasualtyCare.DRIFT_UP = 1.2 -- per second while nobody is with them
CasualtyCare.SETTLE = 3 -- s calm out of reach before they swim the last bit to you

-- Panic change per second (negative calms). Keeping still and facing them calms on its own;
-- the calm-hand gesture (hold) calms faster, more so with the tube within their reach.
function CasualtyCare.calmRate(
	dist: number,
	speed: number,
	lookDeg: number,
	holding: boolean
): number
	if dist > CasualtyCare.TALK then
		return CasualtyCare.DRIFT_UP
	end
	if speed > CasualtyCare.RUSH and dist < CasualtyCare.TALK / 2 then
		return 6 -- rushing in
	end
	if speed > CasualtyCare.STILL or lookDeg > CasualtyCare.FACING then
		return CasualtyCare.DRIFT_UP
	end
	if not holding then
		return -3
	end
	return if dist <= CasualtyCare.REACH then -10.5 else -7
end

function CasualtyCare.step(level: number, rate: number, dt: number): number
	return math.clamp(level + rate * dt, 0, 100)
end

function CasualtyCare.grabs(level: number, dist: number): boolean
	return level >= CasualtyCare.GRAB and dist < CasualtyCare.ARM
end

-- They take the tube: calm and in reach, or calm for a moment and they swim the last bit.
function CasualtyCare.accepts(level: number, dist: number, calmFor: number): boolean
	return level < CasualtyCare.ACCEPT
		and (dist <= CasualtyCare.REACH or calmFor >= CasualtyCare.SETTLE)
end

-- Body language for a panic level (CasualtyRig poses): thrashing, waving, treading water.
function CasualtyCare.pose(level: number): string
	if level >= 60 then
		return "Panic"
	elseif level >= CasualtyCare.ACCEPT then
		return "Wave"
	end
	return "TreadWater"
end

---------------------------------------------------------------- triage

-- Where the medic's hands find each sieve check.
CasualtyCare.TRIAGE_AREA = {
	walk = "legs", -- ask them to stand
	airway = "head",
	responsive = "head", -- shout and tap the shoulder
	rate = "chest", -- watch the breaths
	refill = "hand", -- press a fingertip
} :: { [string]: string }

-- The checks one area runs, in sieve order.
function CasualtyCare.triageChecks(area: string, sieveOrder: { string }): { string }
	local out = {}
	for _, c in sieveOrder do
		if CasualtyCare.TRIAGE_AREA[c] == area then
			table.insert(out, c)
		end
	end
	return out
end

-- The areas to offer for a list of checks, head to toe.
function CasualtyCare.triageAreas(checks: { string }): { string }
	local want = {}
	for _, c in checks do
		local a = CasualtyCare.TRIAGE_AREA[c]
		if a then
			want[a] = true
		end
	end
	return ordered(want)
end

return CasualtyCare
