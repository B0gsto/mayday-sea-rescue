--!strict
-- Procedures: the pure content of the tow mechanics (docs 09 section 6 steps 3, 5, 8, 9).
-- Scenario rolls, the skipper's answer to your horn, the stand-off ring, the tow length for the
-- sea and the contact speed. tests/MechTow.spec.luau.

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
	return {
		pob = rng:NextInteger(1, 4),
		injured = rng:NextNumber() < 0.25,
		lifejackets = rng:NextNumber() < 0.6,
		problem = problems[rng:NextInteger(1, 3)],
		flooding = false,
		anchored = rng:NextNumber() < 0.2,
		trailingRope = rng:NextNumber() < 0.5,
	}
end

function Procedures.seedOf(id: string): number
	local h = 5381
	for i = 1, #id do
		h = (h * 33 + string.byte(id, i)) % 2147483647
	end
	return h
end

-- One of the skipper's answers (pob, injuries, lifejackets, flooding, problem, anchor).
function Procedures.answer(s: Scenario, id: string): string
	if id == "pob" then
		return if s.pob == 1 then "Just me aboard." else `{s.pob} of us aboard.`
	elseif id == "injuries" then
		return if s.injured then "My mate's hit his head." else "No, we're all fine."
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
	end
	return "Came out of Haven this morning."
end

-- Everything the skipper tells you when you sound the horn near her, in the order she says it.
Procedures.ANSWER_ORDER = { "pob", "problem", "injuries", "lifejackets", "flooding", "anchor" }

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

---------------------------------------------------------------- rigging (step 5)

-- Sensible length for the sea: short in a flat calm or confined water, long in a big sea.
function Procedures.rightLength(intensity: number): string
	if intensity >= 0.5 then
		return "long"
	elseif intensity >= 0.15 then
		return "medium"
	end
	return "short"
end

-- The hitch-to-bow length in studs the crew rigs (the tow step's Q/E fine-tunes it).
function Procedures.lengthStuds(choice: string): number
	if choice == "short" then
		return 45 -- 15 m
	elseif choice == "long" then
		return 120 -- 40 m
	end
	return 75 -- 25 m
end

---------------------------------------------------------------- alongside and berth (steps 8, 9)

-- Contact speed (studs/s) along the touching normal from two velocities.
function Procedures.contactSpeed(relVelocity: Vector3, normal: Vector3): number
	local n = Vector3.new(normal.X, 0, normal.Z)
	if n.Magnitude < 1e-4 then
		return Vector3.new(relVelocity.X, 0, relVelocity.Z).Magnitude
	end
	return math.max(0, -relVelocity:Dot(n.Unit))
end

return Procedures
