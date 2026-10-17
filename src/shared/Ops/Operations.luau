--!strict
-- Ops/Operations: the registry of operation definitions, the legacy call-kind mapping, and the
-- per-casualty step plan. Pure (Lune-testable).
local Types = require(script.Parent.Types)

type OperationDef = Types.OperationDef
type StepDef = Types.StepDef

local Operations = {}

Operations.Defs = table.freeze({
	PersonInWater = require(script.Parent.Definitions.PersonInWater),
	DisabledVessel = require(script.Parent.Definitions.DisabledVessel),
	CapsizedFerry = require(script.Parent.Definitions.CapsizedFerry),
} :: { [string]: OperationDef })

-- The old call kinds (CallLogic.chooseCall, RescueService scenes) -> operation id.
Operations.FromCallKind = table.freeze({
	Swimmer = "PersonInWater",
	DriftingCraft = "PersonInWater",
	Tow = "DisabledVessel",
	CapsizedFerry = "CapsizedFerry",
} :: { [string]: string })

function Operations.get(id: string): OperationDef?
	return Operations.Defs[id]
end

-- The steps a track runs for this casualty state (drops `when` steps that don't apply).
function Operations.plan(def: OperationDef, casualtyState: string?): { StepDef }
	local out = {}
	for _, step in def.steps do
		if step.when == nil or step.when == casualtyState then
			table.insert(out, step)
		end
	end
	return out
end

-- Which client mechanic plays this step for this casualty.
function Operations.mechanicFor(step: StepDef, casualtyState: string?): string
	local by = step.mechanicByState
	if by and casualtyState and by[casualtyState] then
		return by[casualtyState]
	end
	return step.mechanicId
end

-- The recovery method the book calls for (docs 09 section 2.3); a recovery mechanic reports
-- metrics.method and the server sets rightMethod from this.
Operations.RecoveryMethod = table.freeze({
	Alert = "throwbag",
	Panicking = "swimmer",
	Exhausted = "swimmer",
	VeryCold = "horizontal",
	Unresponsive = "horizontal",
} :: { [string]: string })

-- Triage sieve truth for a casualty (docs 09 section 7 step 4), simplified for greybox:
-- walking -> Green; breathing but not walking -> Yellow; unresponsive or very cold -> Red.
function Operations.triageTag(state: string): string
	if state == "Unresponsive" or state == "VeryCold" then
		return "Red"
	elseif state == "Exhausted" or state == "Panicking" then
		return "Yellow"
	end
	return "Green"
end

-- Picks a key from a { key = weight } table with a 0..1 roll.
function Operations.roll(weights: { [string]: number }, r: number): string
	local keys = {}
	local total = 0
	for k, w in weights do
		table.insert(keys, k)
		total += w
	end
	table.sort(keys)
	local pick = r * total
	for _, k in keys do
		pick -= weights[k]
		if pick < 0 then
			return k
		end
	end
	return keys[#keys]
end

function Operations.totalWeight(steps: { StepDef }): number
	local w = 0
	for _, s in steps do
		w += s.weight
	end
	return w
end

return Operations
