--!strict
-- CallService: retired. Operations v2 (OperationService) is the one source of truth for the radio,
-- offers, steps and pay. This thin shim keeps the old contract API working for existing callers
-- (DogService uses GetVictimPositions) by delegating to OperationService. Don't add logic here.
local OperationService =
	require(script.Parent:WaitForChild("OperationService") :: ModuleScript) :: any

export type CallInfo = {
	id: string,
	kind: string,
	position: Vector3,
	zoneId: string,
	expiresAt: number,
	assignedTo: { Player },
	isBig: boolean,
}

local CallService = {}
CallService.Priority = 75

-- Fires (callInfo, helpers) when an operation finishes (OperationService.OperationCompleted).
CallService.CallCompleted = OperationService.OperationCompleted

function CallService.GetActiveCalls(): { CallInfo }
	return OperationService.GetActiveOperations()
end

function CallService.GetVictimPositions(player: Player): { Vector3 }
	return OperationService.GetVictimPositions(player)
end

function CallService.ForceBigCall()
	OperationService.ForceBigCall()
end

return CallService
