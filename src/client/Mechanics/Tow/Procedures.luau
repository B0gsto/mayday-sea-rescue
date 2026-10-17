--!strict
-- Procedures: the pure decision content of the tow mechanics (docs 09 section 6 steps 3, 5, 8,
-- 9). Scenario rolls, the hail questions and the skipper's answers, the strong-point choice and
-- the casualty crew's work to check, fenders and line order. tests/MechTow.spec.luau.

local Procedures = {}

---------------------------------------------------------------- assessment (step 3)

export type Scenario = {
	pob: number,
	injured: boolean,
	lifejackets: boolean,
	problem: string, -- "engine" | "fuel" | "prop"
	flooding: boolean,
	anchored: boolean,
	trailingRope: boolean, -- a rope over the stern: will foul your propeller (the hazard)
	bow: string, -- "samson" | "cleats" (two bow cleats, needs a bridle)
	crewFault: string, -- the casualty crew's mistake you check: "none" | "rail" | "noTurns" | "chafe"
}

-- Deterministic roll from a seed (the operation id hash) so every crewmate sees the same boat.
function Procedures.roll(seed: number): Scenario
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function nextNumber(): number
		state = (state * 48271) % 2147483647 -- Park-Miller, pure (no Random under Lune)
		return state / 2147483647
	end
	local function nextInt(a: number, b: number): number
		return math.min(b, a + math.floor(nextNumber() * (b - a + 1)))
	end
	local rng = {
		NextInteger = function(_, a: number, b: number): number
			return nextInt(a, b)
		end,
		NextNumber = function(_): number
			return nextNumber()
		end,
	}
	local problems = { "engine", "fuel", "prop" }
	local faults = { "none", "rail", "noTurns", "chafe" }
	return {
		pob = rng:NextInteger(1, 4),
		injured = rng:NextNumber() < 0.25,
		lifejackets = rng:NextNumber() < 0.6,
		problem = problems[rng:NextInteger(1, 3)],
		flooding = false,
		anchored = rng:NextNumber() < 0.2,
		trailingRope = rng:NextNumber() < 0.5,
		bow = if rng:NextNumber() < 0.5 then "samson" else "cleats",
		crewFault = faults[rng:NextInteger(1, 4)],
	}
end

function Procedures.seedOf(id: string): number
	local h = 5381
	for i = 1, #id do
		h = (h * 33 + string.byte(id, i)) % 2147483647
	end
	return h
end

export type Question = { id: string, text: string, key: boolean }

-- What a lifeboat crew asks a disabled vessel (verify: COMDTINST M16114 towing). `key` ones count
-- toward the `questions` metric; small talk costs time only.
Procedures.QUESTIONS = {
	{ id = "pob", text = "How many aboard?", key = true },
	{ id = "injuries", text = "Anyone hurt?", key = true },
	{ id = "lifejackets", text = "Lifejackets on?", key = true },
	{ id = "flooding", text = "Taking on water?", key = true },
	{ id = "problem", text = "What's the problem?", key = true },
	{ id = "anchor", text = "Are you anchored?", key = true },
	{ id = "name", text = "What's her name?", key = false },
	{ id = "from", text = "Where are you from?", key = false },
}

function Procedures.answer(s: Scenario, id: string): string
	if id == "pob" then
		return if s.pob == 1 then "Just me aboard." else `{s.pob} of us aboard.`
	elseif id == "injuries" then
		return if s.injured
			then "My mate's hit his head, he's sitting down."
			else "No, we're all fine."
	elseif id == "lifejackets" then
		return if s.lifejackets then "Yes, all on." else "Er... putting them on now!"
	elseif id == "flooding" then
		return if s.flooding then "Yes, she's filling up!" else "No, she's dry."
	elseif id == "problem" then
		if s.problem == "fuel" then
			return "Ran out of fuel, embarrassingly."
		elseif s.problem == "prop" then
			return "Something wrapped round the prop."
		end
		return "Engine just died. Won't restart."
	elseif id == "anchor" then
		return if s.anchored then "Anchor's down, but it's dragging." else "No, we're drifting."
	elseif id == "name" then
		return "The Optimist."
	end
	return "Came out of Haven this morning."
end

function Procedures.keyCount(): number
	local n = 0
	for _, q in Procedures.QUESTIONS do
		if q.key then
			n += 1
		end
	end
	return n
end

-- Fraction of the key questions asked.
function Procedures.questionScore(asked: { [string]: boolean }): number
	local n, got = 0, 0
	for _, q in Procedures.QUESTIONS do
		if q.key then
			n += 1
			if asked[q.id] then
				got += 1
			end
		end
	end
	return if n > 0 then got / n else 0
end

-- The stand-off ring: far enough not to drift onto them, close enough to talk (studs, tune).
Procedures.RING_MIN = 24
Procedures.RING_MAX = 48
Procedures.RING_SECTORS = 8

-- Which of RING_SECTORS sectors around the casualty a position sits in (1-based).
function Procedures.sector(casualty: Vector3, pos: Vector3): number
	local a = math.atan2(pos.X - casualty.X, pos.Z - casualty.Z) -- -pi..pi
	local f = (a + math.pi) / (2 * math.pi)
	return math.clamp(math.floor(f * Procedures.RING_SECTORS) + 1, 1, Procedures.RING_SECTORS)
end

function Procedures.inRing(casualty: Vector3, pos: Vector3): boolean
	local d = Vector3.new(pos.X - casualty.X, 0, pos.Z - casualty.Z).Magnitude
	return d >= Procedures.RING_MIN and d <= Procedures.RING_MAX
end

-- The stern sector relative to the casualty's heading: a trailing rope is only seen from aft.
function Procedures.canSeeStern(casualtyCF: CFrame, pos: Vector3): boolean
	local loc = casualtyCF:PointToObjectSpace(pos)
	-- hull frame: -Z forward, so the stern is +Z
	return loc.Z > 4 and math.abs(loc.X) < loc.Z * 1.2 + 6
end

-- Decision after assessing: "tow" unless flooding (take the crew off) or drifting onto rocks
-- without an anchor down (tell them to anchor first, then tow).
function Procedures.rightDecision(s: Scenario, rocksClose: boolean): string
	if s.flooding then
		return "evacuate"
	elseif rocksClose and not s.anchored then
		return "anchor"
	end
	return "tow"
end

---------------------------------------------------------------- rigging (step 5)

export type Attach = { id: string, text: string }

Procedures.ATTACH = {
	{ id = "samson", text = "Samson post" },
	{ id = "bridle", text = "Bridle to both cleats" },
	{ id = "cleat", text = "One bow cleat" },
	{ id = "rail", text = "Bow rail" },
}

-- strongPoint (1/0) and whether the tow will sheer: the samson post is a strong central point;
-- with only cleats the bridle shares the load and centres the pull; one cleat or the rail is weak.
function Procedures.attachResult(s: Scenario, choice: string): (boolean, boolean)
	if choice == "samson" then
		return s.bow == "samson", true
	elseif choice == "bridle" then
		return true, true
	end
	return false, false -- one cleat or the rail: weak, tears out at the first snatch
end

Procedures.LENGTHS = { "short", "medium", "long" }

-- Sensible length for the sea: short in a flat calm or confined water, long in a big sea.
function Procedures.rightLength(intensity: number): string
	if intensity >= 0.5 then
		return "long"
	elseif intensity >= 0.15 then
		return "medium"
	end
	return "short"
end

-- The hitch-to-bow length in studs for a choice (before the tow step's fine step-out).
function Procedures.lengthStuds(choice: string): number
	if choice == "short" then
		return 45 -- 15 m
	elseif choice == "long" then
		return 120 -- 40 m
	end
	return 75 -- 25 m
end

-- The casualty crew's work as you see it, and the correct call-back.
function Procedures.faultText(fault: string): (string, string)
	if fault == "rail" then
		return "They've tied it round the guard rail.", "Off the rail: onto the post or the cleats."
	elseif fault == "noTurns" then
		return "One loose turn on the cleat, no hitches.",
			"Round turn and figure-eights, locking hitch."
	elseif fault == "chafe" then
		return "Line runs over the sharp stem fitting.",
			"Lead it through the fairlead, add chafe gear."
	end
	return "Made fast properly, line led fair.", "Looks good: tell them to stand clear of it."
end

---------------------------------------------------------------- alongside and berth (steps 8, 9)

-- Alongside tow: the casualty lashed to one side, the tug's stern aft of the casualty's stern so
-- its rudder and prop still steer the pair. Lines in order: bow line, stern line, then the springs
-- (the springs stop the pair surging fore and aft). (verify: COMDTINST M16114)
Procedures.ALONGSIDE_ORDER = { "bow", "stern", "fwdSpring", "aftSpring" }
Procedures.LINE_TEXT = {
	bow = "Bow line",
	stern = "Stern line",
	fwdSpring = "Forward spring",
	aftSpring = "Back spring",
	breast = "Breast line",
}

-- Fraction of the first n positions that match the real order (1 = right order).
function Procedures.orderScore(given: { string }, right: { string }): number
	local n = #right
	local ok = 0
	for i = 1, n do
		if given[i] == right[i] then
			ok += 1
		end
	end
	return if n > 0 then ok / n else 0
end

-- Fenders go on the side that will touch: the side the casualty lies on.
function Procedures.fendersRight(placedSide: string?, touchingSide: string, count: number): boolean
	return placedSide == touchingSide and count >= 2
end

-- Berth: line order onto the pontoon. With the wind blowing you off, the bow line first holds
-- you on; then the stern line and the springs. Releasing: the casualty is made fast to the
-- pontoon first, then cast off your lashings (springs, stern, bow), then coil your own lines.
Procedures.BERTH_ORDER = { "bow", "stern", "fwdSpring", "aftSpring" }
Procedures.RELEASE_ORDER = { "casualtyFast", "springs", "stern", "bow", "coil" }
Procedures.RELEASE_TEXT = {
	casualtyFast = "Make her fast to the pontoon",
	springs = "Cast off our springs",
	stern = "Cast off our stern line",
	bow = "Cast off our bow line",
	coil = "Coil and stow the tow line",
}

-- Contact speed (studs/s) along the touching normal from two velocities.
function Procedures.contactSpeed(relVelocity: Vector3, normal: Vector3): number
	local n = Vector3.new(normal.X, 0, normal.Z)
	if n.Magnitude < 1e-4 then
		return Vector3.new(relVelocity.X, 0, relVelocity.Z).Magnitude
	end
	return math.max(0, -relVelocity:Dot(n.Unit))
end

return Procedures
