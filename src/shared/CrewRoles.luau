--!strict
-- CrewRoles: who holds which crew role, from what each player is doing (docs 09 section 4.1).
-- There is no picker: the helm seat, the chart table, the water and the kit tools *are* the
-- choice. Taking one takes the role; another crewmate taking it hands the role over.
--
--   Helm       seated in a boat's DriverSeat
--   Navigator  standing at the chart table (the crew boat's CrewChart)
--   Navigator  holding the search tablet
--   Crew       in the water, or wearing the drysuit from the kit locker (shown as "Swimmer")
--   Medic      carrying the med bag from the boat's kit box
--
-- Pure: no services, Lune-testable (tests/CrewRoles.spec.luau). The server (CrewService) turns
-- seats, tools and the water into State, then calls resolve() once per crew.
export type Role = "Helm" | "Navigator" | "Crew" | "Medic"
export type Tool = "Drysuit" | "MedBag" | "Tablet"

export type State = {
	id: number,
	helm: boolean?, -- in the helm seat
	chart: boolean?, -- standing at the chart table / radar
	water: boolean?, -- in the water
	tablet: boolean?, -- holding the search tablet
	drysuit: boolean?, -- wearing the drysuit
	medbag: boolean?, -- carrying the med bag
}

local CrewRoles = {}

-- Step assignment order (Ops/Types.Role). "Crew" is the ops name for the swimmer role.
local ROLES: { Role } = { "Helm", "Navigator", "Crew", "Medic" }
CrewRoles.Roles = table.freeze(ROLES)
CrewRoles.Labels = table.freeze({
	Helm = "Helm",
	Navigator = "Navigator",
	Crew = "Swimmer",
	Medic = "Medic",
} :: { [string]: string })
CrewRoles.ToolFlag = table.freeze({
	Drysuit = "drysuit",
	MedBag = "medbag",
	Tablet = "tablet",
} :: { [string]: string })

local function clone(state: State): State
	return {
		id = state.id,
		helm = state.helm == true,
		chart = state.chart == true,
		water = state.water == true,
		tablet = state.tablet == true,
		drysuit = state.drysuit == true,
		medbag = state.medbag == true,
	}
end

-- Every role the action state earns, in step order (a swimmer with the med bag holds both).
function CrewRoles.of(state: State): { Role }
	local out: { Role } = {}
	if state.helm == true then
		table.insert(out, "Helm")
	end
	if state.chart == true or state.tablet == true then
		table.insert(out, "Navigator")
	end
	if state.water == true or state.drysuit == true then
		table.insert(out, "Crew")
	end
	if state.medbag == true then
		table.insert(out, "Medic")
	end
	return out
end

-- One helm seat and one of each kit item: the first claim in crew order keeps it, the others
-- keep only the roles their other actions earn. Returns roles by id and the tool holders.
function CrewRoles.resolve(states: { State }): ({ [number]: { Role } }, { [string]: number })
	local clean = {}
	for _, state in states do
		table.insert(clean, clone(state))
	end
	local holders: { [string]: number } = {}
	for _, key in { "helm", "tablet", "drysuit", "medbag" } do
		local holder: number? = nil
		for _, state in clean do
			if (state :: any)[key] == true then
				if holder == nil then
					holder = state.id
				else
					(state :: any)[key] = false
				end
			end
		end
		if holder ~= nil then
			holders[key] = holder
		end
	end
	local roles: { [number]: { Role } } = {}
	for _, state in clean do
		roles[state.id] = CrewRoles.of(state)
	end
	return roles, holders
end

-- Handover: `id` takes the tool, everyone else lets go of that one item.
function CrewRoles.takeTool(states: { State }, id: number, tool: Tool): { State }
	local key = CrewRoles.ToolFlag[tool]
	local out = {}
	for _, state in states do
		local copy = clone(state)
		if key then
			(copy :: any)[key] = state.id == id
		end
		table.insert(out, copy)
	end
	return out
end

-- The holder puts the tool down (or drops the drysuit): the role leaves with it.
function CrewRoles.releaseTool(states: { State }, id: number, tool: Tool): { State }
	local key = CrewRoles.ToolFlag[tool]
	local out = {}
	for _, state in states do
		local copy = clone(state)
		if key and state.id == id then
			(copy :: any)[key] = false
		end
		table.insert(out, copy)
	end
	return out
end

-- Swap seats: only `id` is in the helm seat afterwards.
function CrewRoles.takeHelm(states: { State }, id: number): { State }
	local out = {}
	for _, state in states do
		local copy = clone(state)
		copy.helm = state.id == id
		table.insert(out, copy)
	end
	return out
end

-- The one icon over the head: the first role in step order (Helm, Navigator, Crew, Medic).
function CrewRoles.primary(roles: { Role }): Role?
	for _, role in ROLES do
		if table.find(roles, role) then
			return role :: Role
		end
	end
	return nil
end

function CrewRoles.has(roles: { Role }, role: Role): boolean
	return table.find(roles, role) ~= nil
end

-- Solo plays every role implicitly (docs 09 4.2). OperationService keeps its own solo rule.
function CrewRoles.implicit(): { Role }
	return table.clone(ROLES)
end

return CrewRoles
