--!strict
-- Ops/Remotes: the Operations v2 remotes, kept out of Net.luau (CONTRACT.md "Operations v2").
-- They live under ReplicatedStorage.Net with an Ops_ prefix. The server creates them on first
-- use (OperationService.Init); clients wait for them.
--
--   Ops_Offered     S->C  a tasking card { opId, kind, title, radioLine, zoneName, position, isBig,
--                         offerExpiresAt, cash, rep }
--   Ops_Accept      C->S  (opId) accept the tasking (big calls: join with your crew)
--   Ops_State       S->C  the operation snapshot for this player (see OperationService.snapshot)
--   Ops_StepStart   S->C  play a mechanic: the StepContext (CONTRACT.md "Operations v2")
--   Ops_StepResult  C->S  (opId, stepKey, StepResult) a mechanic finished
--   Ops_StepAck     S->C  { opId, stepKey, accepted, grade?, reason? }
--   Ops_Radio       S->C  { opId, from, text } a radio line
--   Ops_Debrief     S->C  the debrief { opId, kind, title, grade, takeover?, steps, condition, cash, rep, tip }
--   Ops_Closed      S->C  { opId, reason, message?, silent? } offer withdrawn or operation closed
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type EventName =
	"Ops_Offered"
	| "Ops_Accept"
	| "Ops_State"
	| "Ops_StepStart"
	| "Ops_StepResult"
	| "Ops_StepAck"
	| "Ops_Radio"
	| "Ops_Debrief"
	| "Ops_Closed"

local Remotes = {}

Remotes.EVENTS = table.freeze({
	"Ops_Offered",
	"Ops_Accept",
	"Ops_State",
	"Ops_StepStart",
	"Ops_StepResult",
	"Ops_StepAck",
	"Ops_Radio",
	"Ops_Debrief",
	"Ops_Closed",
} :: { EventName })

local function folder(): Instance
	local f = ReplicatedStorage:FindFirstChild("Net")
	if f then
		return f
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = "Net"
		created.Parent = ReplicatedStorage
		return created
	end
	local waited = ReplicatedStorage:WaitForChild("Net", 30)
	assert(waited, "Timed out waiting for ReplicatedStorage.Net")
	return waited
end

-- Server: creates every Ops_ remote (idempotent).
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server only")
	local f = folder()
	for _, name in Remotes.EVENTS do
		if not f:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = f
		end
	end
end

function Remotes.event(name: EventName): RemoteEvent
	local f = folder()
	local e = f:FindFirstChild(name)
	if not e and RunService:IsServer() then
		Remotes.init()
		e = f:FindFirstChild(name)
	end
	if not e then
		e = f:WaitForChild(name, 30)
	end
	assert(e and e:IsA("RemoteEvent"), `Timed out waiting for remote Net.{name}`)
	return e
end

return Remotes
