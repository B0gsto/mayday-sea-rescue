--!strict
-- Ops/Operations: the registry of operation definitions and the legacy call-kind mapping.
-- Pure (Lune-testable).
local Types = require(script.Parent.Types)

type OperationDef = Types.OperationDef
type StepDef = Types.StepDef

local Operations = {}

Operations.Defs = table.freeze({
	PersonInWater = require(script.Parent.Definitions.PersonInWater),
	CapsizedFerry = require(script.Parent.Definitions.CapsizedFerry),
	RipCurrent = require(script.Parent.Definitions.RipCurrent),
	SinkingVessel = require(script.Parent.Definitions.SinkingVessel),
	VesselFire = require(script.Parent.Definitions.VesselFire),
	WildlifeRescue = require(script.Parent.Definitions.WildlifeRescue),
	Diver = require(script.Parent.Definitions.Diver),
} :: { [string]: OperationDef })

-- The old call kinds (CallLogic.chooseCall, RescueService scenes) -> operation id.
Operations.FromCallKind = table.freeze({
	Swimmer = "PersonInWater",
	DriftingCraft = "PersonInWater",
	CapsizedFerry = "CapsizedFerry",
	RipCurrent = "RipCurrent",
	Sinking = "SinkingVessel",
	VesselFire = "VesselFire",
	WildlifeRescue = "WildlifeRescue",
	Diver = "Diver",
} :: { [string]: string })

function Operations.get(id: string): OperationDef?
	return Operations.Defs[id]
end

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

-- The casualties a slow grade is about: not yet picked up. Aboard a crew's boat (the board effect
-- sets `aboard`) they are rescued; the ride home is only graded.
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
