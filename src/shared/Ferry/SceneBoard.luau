--!strict
-- On Scene Coordinator helpers (docs/09 section 7 step 2). Pure, Lune-tested in
-- tests/MechFerryScene.spec.luau, used by src/client/Mechanics/scene_command.luau.
--
-- METHANE (verify: JESIP): Major incident declared, Exact location, Type of incident, Hazards,
-- Access, Number of casualties, Emergency services present and required. The OSC sends it first,
-- then assigns every unit a task on the scene board. Search sectors lie downwind of the hull,
-- because people and liferafts drift downwind of a capsized vessel.
-- Wind convention: `windDirection` (radians) is the way the wind blows toward;
-- downwind = Vector3.new(cos a, 0, sin a) (same as src/client/Ocean/Horizon.luau).

local SceneBoard = {}

export type Facts = {
	zoneName: string,
	bearing: string, -- "south-west of the harbour mouth" etc.
	casualties: number, -- the manifest estimate
	storm: boolean,
}

export type Line = {
	key: string,
	letter: string,
	label: string,
	options: { string },
	answer: number, -- index into options
}

local COMPASS =
	{ "east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east" }

-- Compass word for a flat offset (+X east, +Z south, the Roblox map convention used in docs 02).
function SceneBoard.compass(offset: Vector3): string
	local a = math.atan2(offset.Z, offset.X) -- 0 = east, +pi/2 = south
	local i = math.floor((a / (math.pi / 4)) + 0.5) % 8
	return COMPASS[i + 1]
end

function SceneBoard.downwind(windDirection: number): Vector3
	return Vector3.new(math.cos(windDirection), 0, math.sin(windDirection))
end

-- Rounds a casualty count the way an OSC estimates it on the radio.
function SceneBoard.estimate(n: number): string
	if n <= 10 then
		return `about {n}`
	end
	return `about {math.floor(n / 5 + 0.5) * 5}`
end

-- The seven METHANE lines with 3 options each; `rot` (0..2 per line, from a seed) shuffles where
-- the right answer sits so the cards can't be learnt by position.
function SceneBoard.methane(f: Facts, seed: number): { Line }
	local n = f.casualties
	local lines: { { key: string, letter: string, label: string, right: string, wrong: { string } } } =
		{
			{
				key = "major",
				letter = "M",
				label = "Major incident",
				right = "Major incident declared",
				wrong = { "Not a major incident", "Standby, not yet known" },
			},
			{
				key = "location",
				letter = "E",
				label = "Exact location",
				right = `{f.zoneName}, {f.bearing}`,
				wrong = { `{f.zoneName}, inside the harbour wall`, "Somewhere off the Gale Isles" },
			},
			{
				key = "type",
				letter = "T",
				label = "Type of incident",
				right = "Passenger ferry capsized, people in the water",
				wrong = { "Fishing boat aground", "Yacht dismasted, crew safe" },
			},
			{
				key = "hazards",
				letter = "H",
				label = "Hazards",
				right = if f.storm
					then "Storm seas, debris, ropes, fuel on the water"
					else "Debris, ropes, fuel on the water",
				wrong = { "None", "Fog only" },
			},
			{
				key = "access",
				letter = "A",
				label = "Access",
				right = "Approach from downwind, lee side of the hull",
				wrong = { "Approach from upwind at speed", "No access, wait for daylight" },
			},
			{
				key = "number",
				letter = "N",
				label = "Number of casualties",
				right = SceneBoard.estimate(n),
				wrong = {
					SceneBoard.estimate(math.max(1, math.floor(n / 3))),
					SceneBoard.estimate(n * 3),
				},
			},
			{
				key = "services",
				letter = "E",
				label = "Emergency services",
				right = "Lifeboats on scene, Rescue Gale One requested",
				wrong = { "None needed", "Police only" },
			},
		}
	local out: { Line } = {}
	for i, l in lines do
		local rot = (seed + i * 7) % 3
		local opts = { l.right, l.wrong[1], l.wrong[2] }
		local shuffled = {}
		for j = 1, 3 do
			shuffled[j] = opts[((j - 1 + rot) % 3) + 1]
		end
		table.insert(out, {
			key = l.key,
			letter = l.letter,
			label = l.label,
			options = shuffled,
			answer = table.find(shuffled, l.right) :: number,
		})
	end
	return out
end

-- Fraction of METHANE lines answered right. `answers[i]` is the option index for line i.
function SceneBoard.reportScore(lines: { Line }, answers: { [number]: number }): number
	if #lines == 0 then
		return 0
	end
	local right = 0
	for i, l in lines do
		if answers[i] == l.answer then
			right += 1
		end
	end
	return right / #lines
end

-- The tasks the OSC must cover (helicopter lifts are NPC-run in the MVP, docs 09 section 7).
SceneBoard.Tasks = {
	{ id = "sectorA", label = "Search sector A", short = "Sector A", required = true },
	{ id = "sectorB", label = "Search sector B", short = "Sector B", required = true },
	{ id = "sectorC", label = "Search sector C", short = "Sector C", required = true },
	{ id = "reception", label = "Casualty reception boat", short = "Reception", required = true },
	{ id = "hull", label = "Hull team", short = "Hull team", required = true },
	{ id = "standby", label = "Standby, upwind of the hull", short = "Standby", required = false },
}

-- Centre of each search sector: three boxes fanned downwind of the hull, B straight downwind.
function SceneBoard.sectorCentres(
	hull: Vector3,
	windDirection: number,
	range: number
): { [string]: Vector3 }
	local d = SceneBoard.downwind(windDirection)
	local side = Vector3.new(-d.Z, 0, d.X)
	return {
		sectorA = hull + d * range + side * range * 0.75,
		sectorB = hull + d * range * 1.15,
		sectorC = hull + d * range - side * range * 0.75,
		reception = hull + d * range * 0.35 + side * range * 0.2,
		hull = hull,
		standby = hull - d * range * 0.5,
	}
end

-- Fraction of the required tasks with at least one unit. `assign[unitId] = taskId`.
function SceneBoard.tasksCovered(assign: { [string]: string }): number
	local covered: { [string]: boolean } = {}
	for _, taskId in assign do
		covered[taskId] = true
	end
	local need, have = 0, 0
	for _, t in SceneBoard.Tasks do
		if t.required then
			need += 1
			if covered[t.id] then
				have += 1
			end
		end
	end
	return if need == 0 then 1 else have / need
end

-- The units the NPC Coastguard officer would assign, in order, when nobody takes command or
-- when the OSC asks for the fill-in: one unit per required task, spare units to standby.
function SceneBoard.autoAssign(unitIds: { string }): { [string]: string }
	local out: { [string]: string } = {}
	local required = {}
	for _, t in SceneBoard.Tasks do
		if t.required then
			table.insert(required, t.id)
		end
	end
	for i, u in unitIds do
		out[u] = required[i] or "standby"
	end
	return out
end

-- The radio lines of the sitrep, in order, from the chosen answers.
function SceneBoard.sitrep(
	callsign: string,
	lines: { Line },
	answers: { [number]: number }
): { string }
	local out = {
		`Gale Isles Coastguard, {callsign}, on scene, assuming On Scene Coordinator. METHANE follows.`,
	}
	for i, l in lines do
		local pick = answers[i]
		local text = if pick then l.options[pick] else "unknown"
		table.insert(out, `{l.letter}: {text}.`)
	end
	table.insert(out, `{callsign}, over.`)
	return out
end

return SceneBoard
