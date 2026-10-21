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
	CliffCasualty = require(script.Parent.Definitions.CliffCasualty),
	RipCurrent = require(script.Parent.Definitions.RipCurrent),
	SinkingVessel = require(script.Parent.Definitions.SinkingVessel),
	VesselFire = require(script.Parent.Definitions.VesselFire),
	WildlifeRescue = require(script.Parent.Definitions.WildlifeRescue),
} :: { [string]: OperationDef })

-- The old call kinds (CallLogic.chooseCall, RescueService scenes) -> operation id.
Operations.FromCallKind = table.freeze({
	Swimmer = "PersonInWater",
	DriftingCraft = "PersonInWater",
	Tow = "DisabledVessel",
	CapsizedFerry = "CapsizedFerry",
	Cliff = "CliffCasualty",
	RipCurrent = "RipCurrent",
	Sinking = "SinkingVessel",
	VesselFire = "VesselFire",
	WildlifeRescue = "WildlifeRescue",
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

-- Can this call fail (an NPC takes the casualty, no pay)? Never the cold open or a new player's
-- first station calls (Onboarding.failsafeCall): there the survivor simply waits (2026-10-21).
function Operations.canFail(coldOpen: boolean, firstCalls: boolean): boolean
	return not (coldOpen or firstCalls)
end

-- The casualties a takeover is about: not yet picked up. Aboard a crew's boat (the board effect sets
-- `aboard`) they are rescued; the ride home is only graded.
function Operations.atRisk(casualties: { any }): { any }
	local out = {}
	for _, c in casualties do
		if not c.aboard and not c.delivered then
			table.insert(out, c)
		end
	end
	return out
end

return Operations
