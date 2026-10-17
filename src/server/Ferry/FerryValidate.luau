--!strict
-- Server-side checks for the ferry mechanics (stream c, CONTRACT.md "Operations v2" > Ferry).
-- Additive and unused until OperationService calls it from serverMetrics (proposal):
--   FerryValidate.apply(op.id, inst.def.id, metrics)
-- It recomputes what the client could fake from shared data both sides agree on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ferry = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry")
local HullKnock = require(Ferry:WaitForChild("HullKnock"))
local Triage = require(Ferry:WaitForChild("Triage"))

local FerryValidate = {}

FerryValidate.MaxRescued = 2 -- two passengers in the air pocket

function FerryValidate.apply(opId: string, stepId: string, metrics: { [string]: any })
	if stepId == "hull_knock" then
		local at = metrics.compartment
		metrics.rightCompartment = type(at) == "number" and at == HullKnock.pocketCompartment(opId)
	elseif stepId == "air_pocket" then
		local r = metrics.rescued
		metrics.rescued = if type(r) == "number"
			then math.clamp(math.floor(r), 0, FerryValidate.MaxRescued)
			else 0
		local m = metrics.signalMistakes
		metrics.signalMistakes = if type(m) == "number" then math.max(0, math.floor(m)) else 3
	elseif stepId == "scene_command" then
		for _, k in { "reportCorrect", "tasksCovered" } do
			local v = metrics[k]
			metrics[k] = if type(v) == "number" then math.clamp(v, 0, 1) else 0
		end
	end
	return metrics
end

-- Condition drift multiplier for a casualty waiting with a tag (proposal for tickOp): an
-- under-triaged casualty declines faster until moved (docs 09 section 7 step 4 failure mode).
function FerryValidate.driftFactor(tag: string?, state: string): number
	local Operations = require(
		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("Operations")
	) :: any
	return Triage.driftFactor(tag, Operations.triageTag(state))
end

return FerryValidate
