--!strict
-- On Scene Coordinator helpers (docs/09 section 7 step 2). Pure, Lune-tested in
-- tests/MechFerryScene.spec.luau, used by OperationService (sendBoard).
--
-- The scene board is filled automatically (no player picks): one unit per task. Search sectors
-- lie downwind of the hull, because people and liferafts drift downwind of a capsized vessel.
-- Wind convention: `windDirection` (radians) is the way the wind blows toward;
-- downwind = Vector3.new(cos a, 0, sin a) (same as src/client/Ocean/Horizon.luau).

local SceneBoard = {}

function SceneBoard.downwind(windDirection: number): Vector3
	return Vector3.new(math.cos(windDirection), 0, math.sin(windDirection))
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

-- The board for every scene_command, in unit order: one unit per required task, spares to standby.
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

return SceneBoard
