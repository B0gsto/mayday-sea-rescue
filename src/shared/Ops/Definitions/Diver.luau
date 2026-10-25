--!strict
-- Diver at a Wreck (docs/23 (h) "Sub pen"). Data only. A diver trapped at a wreck on the seabed inside an
-- orange ring (server/Ops/DiverRescue): dive the submarine into the ring, hold slow and steady, they climb
-- aboard (Ops/CraftBoard: only the sub reaches them), then Home as usual.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "Diver",
	displayName = "Diver at a Wreck",
	radioLine = "Haven Rescue, Gale Isles Coastguard. Diver trapped at a wreck, one casualty. Over.",
	weight = 1.4, -- tune
	capSeconds = 1000,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 0.5, Exhausted = 0.5 },
	lifejacketChance = 0,
	takeoverAsset = "Rescue Gale One",
	sceneKinds = { "Diver" },
	steps = SimpleSteps("Answer the Coastguard quickly; their air will not wait."),
}

return def
