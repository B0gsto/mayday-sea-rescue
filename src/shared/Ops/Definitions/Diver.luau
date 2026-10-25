--!strict
-- Diver at a Wreck (docs/23 (h) "Sub pen"). Data only. A diver trapped at a wreck on the seabed inside an
-- orange ring (server/Ops/DiverRescue): dive the submarine into the ring, hold slow and steady, they climb
-- aboard (Ops/CraftBoard: only the sub reaches them), then Home as usual.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "Diver",
	displayName = "Diver at a Wreck",
	weight = 1.4, -- tune
	capSeconds = 780, -- CallTypes Diver timer 600 x the islands' 1.3; the sub runs 40 surfaced (was 14)
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 0.5, Exhausted = 0.5 },
	lifejacketChance = 0,
	sceneKinds = { "Diver" },
	steps = SimpleSteps("Answer the call quickly; their air will not wait."),
}

return def
