--!strict
-- RipFlow (server): the rip-current beach rescue's world glue (docs/09 section 8.4, docs/13 LU-2).
-- The casualty is the ordinary swimmer scene (RescueService) and climbs aboard like any other:
-- nothing is forked here. What is special is the variant (a body-boarder as
-- well as a swimmer) and the current itself (shared/RipCurrent): RescueService drifts casualties
-- with it, the client swims and floats kit with it. OperationService calls Task when the
-- operation is offered (the variant and its radio line) and Spawn after the scene spawns (the
-- rip is the current; the body-boarder's board is tagged for the client view).
local rng = Random.new()

local RipFlow = {}

RipFlow.BOARDER_CHANCE = 0.35 -- the body-boarder variant -- tune

local LINE = {
	Swimmer = "Haven Rescue, Gale Isles Coastguard. Swimmer caught in a rip current off the hub beach, request you launch.",
	BodyBoarder = "Haven Rescue, Gale Isles Coastguard. Body-boarder caught in a rip current off the hub beach, request you launch.",
}

-- Offered: roll the variant; the tasking card and the Coastguard's call both read its line.
function RipFlow.Task(op: any)
	local variant = if rng:NextNumber() < RipFlow.BOARDER_CHANCE then "BodyBoarder" else "Swimmer"
	op.scene.ripVariant = variant
	op.radioLine = LINE[variant]
end

-- Spawned: the rip is the current (the ordinary per-call drift is zeroed) and the body-boarder
-- is tagged on the casualty model (Mechanics/Rip/View rides the board on them).
function RipFlow.Spawn(scene: any)
	scene.driftCurrent = Vector3.zero
	local v = scene.victims and scene.victims[1]
	if scene.ripVariant == "BodyBoarder" and v and v.model then
		v.model:SetAttribute("RipBoard", true)
	end
end

return RipFlow
