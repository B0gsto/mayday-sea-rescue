--!strict
-- Boat/ColdOpenFlow: the cold open's per-player lifecycle, pure and Lune-tested
-- (tests/ColdOpenFlow.spec.luau). OperationService keeps one Entry per player for the session.
--
--   NotStarted --begin--> Running --finish(any reason)--> Finished
--   NotStarted --decide (returning player / ops already done)--> Finished
--
-- There is no edge back: once a cold open has run (whatever its outcome: rescued, timed out,
-- failed, the player left the jet ski or died) it never starts again by itself. Only a Studio
-- dev command may `reset` an entry.
local ColdOpenFlow = {}

export type Phase = "NotStarted" | "Running" | "Finished"
export type Entry = {
	phase: Phase,
	opId: string?,
	reason: string?,
	offCraftSince: number?,
}
-- what the ops tick does for an idle player (no active op, no pending offer)
export type Decision = "Start" | "Offer" | "Wait" | "Abandon"
-- where the player goes once it ends: ride the jet ski home (the client's arrival shot and
-- Vehicle_ArrivalHandoff take over), be put on the station slipway now, or on their next spawn
export type Handover = "Ride" | "Station" | "Respawn"

ColdOpenFlow.LEAVE_GRACE = 15 -- s off the cold-open jet ski before the run counts as abandoned -- tune
ColdOpenFlow.LIFEBOAT = "Lifeboat 17-01"

function ColdOpenFlow.new(): Entry
	return { phase = "NotStarted" }
end

-- `auto`: the cold open is available at all (VehicleService.SpawnColdOpen exists).
-- `completed`: operations this player completed this session.
-- `done`: the persisted ColdOpenDone flag, nil while the profile is still loading.
function ColdOpenFlow.decide(e: Entry, auto: boolean, completed: number, done: boolean?): Decision
	if e.phase == "Finished" then
		return "Offer"
	elseif e.phase == "Running" then
		-- the tick only asks for idle players: a running cold open without its op was lost
		return "Abandon"
	end
	if not auto or completed > 0 or done == true then
		e.phase = "Finished"
		e.reason = "Skipped"
		return "Offer"
	elseif done == nil then
		return "Wait"
	end
	return "Start"
end

-- NotStarted -> Running. False (start nothing) once it has run.
function ColdOpenFlow.begin(e: Entry, opId: string?): boolean
	if e.phase ~= "NotStarted" then
		return false
	end
	e.phase = "Running"
	e.opId = opId
	e.offCraftSince = nil
	return true
end

function ColdOpenFlow.isRunning(e: Entry?): boolean
	return e ~= nil and e.phase == "Running"
end

-- Running -> Finished. True only the first time, when the caller hands the player over.
-- A NotStarted entry is closed too (returns false: nothing to hand over).
function ColdOpenFlow.finish(e: Entry, reason: string): boolean
	if e.phase == "Finished" then
		return false
	end
	local wasRunning = e.phase == "Running"
	e.phase = "Finished"
	e.reason = reason
	e.offCraftSince = nil
	return wasRunning
end

-- Studio dev replay only.
function ColdOpenFlow.reset(e: Entry)
	e.phase = "NotStarted"
	e.opId = nil
	e.reason = nil
	e.offCraftSince = nil
end

-- Called every ops tick while it runs. Returns the abandon reason ("Died", "LeftCraft") or nil.
function ColdOpenFlow.watch(e: Entry, now: number, alive: boolean, onCraft: boolean): string?
	if e.phase ~= "Running" then
		return nil
	end
	if not alive then
		return "Died"
	end
	if onCraft then
		e.offCraftSince = nil
		return nil
	end
	local since = e.offCraftSince or now
	e.offCraftSince = since
	if now - since >= ColdOpenFlow.LEAVE_GRACE then
		return "LeftCraft"
	end
	return nil
end

function ColdOpenFlow.rescued(reason: string): boolean
	return reason == "Complete"
end

-- The closing radio call, a few words (docs/14 F-3): on anything but a rescue the lifeboat has
-- the casualty, and the player is sent home either way.
function ColdOpenFlow.radioFor(reason: string): { from: string, text: string }
	if ColdOpenFlow.rescued(reason) then
		return {
			from = "Gale Isles Coastguard",
			text = "Casualty safe. Good work!",
		}
	end
	return {
		from = ColdOpenFlow.LIFEBOAT,
		text = "We have them. Head home.",
	}
end

function ColdOpenFlow.handover(alive: boolean, onCraft: boolean): Handover
	if not alive then
		return "Respawn"
	elseif onCraft then
		return "Ride"
	end
	return "Station"
end

return ColdOpenFlow
