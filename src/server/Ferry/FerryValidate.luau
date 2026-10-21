--!strict
-- Server-side checks for the ferry mechanics (stream c, CONTRACT.md "Operations v2" > Ferry).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ferry = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry")
local Triage = require(Ferry:WaitForChild("Triage"))

local FerryValidate = {}

-- Condition drift multiplier for a casualty waiting with a tag (proposal for tickOp): an
-- under-triaged casualty declines faster until moved (docs 09 section 7 step 4 failure mode).
function FerryValidate.driftFactor(tag: string?, state: string): number
	local Operations = require(
		ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("Operations")
	) :: any
	return Triage.driftFactor(tag, Operations.triageTag(state))
end

return FerryValidate
