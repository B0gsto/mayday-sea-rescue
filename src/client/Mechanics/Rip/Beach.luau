--!strict
-- rip_beach (docs/09 section 8.4): get them to the sand. The casualty holds on and comes with
-- you — the rescue ways already got them out of the rip — so walk, swim or drive them to the
-- Haven Sands waterline, below the lifeguard tower's flags. A lifeguard / passer-by takes over
-- on the sand (the server's shore handover). No choice is offered and nothing is explained: the
-- flags and the tower say where the beach is. Metric: none client side; the server times it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PIW = script.Parent.Parent:WaitForChild("PIW")
local Radio =
	require(script.Parent.Parent.Parent:WaitForChild("Controllers"):WaitForChild("RadioController"))
local RipCurrent = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RipCurrent"))
local Step = require(PIW:WaitForChild("Step"))
local Units = require(PIW:WaitForChild("Units"))
local World = require(PIW:WaitForChild("World"))

local Beach = {}

Beach.REACH = 32 -- studs, flat: the casualty at the waterline is ashore enough -- tune

function Beach.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "Beach", 96)
	if Step.autoStub(s) then
		return Step.cleanup(s)
	end
	local victim = World.victim(ctx)
	local line = Step.line(s, "Lifeguard", 54)
	Step.heartbeat(s, function()
		if not (victim and victim.Parent) then
			victim = World.victim(ctx)
		end
		local cas = World.casualtyPos(ctx, victim)
		local shore = RipCurrent.Shore
		local d = math.min(Units.flatDistance(cas, shore.water), Units.flatDistance(cas, shore.dry))
		line.Text = `Lifeguard · {math.floor(d / Units.STUDS_PER_M + 0.5)} m`
		local ashore = (ctx.casualty and ctx.casualty.delivered == true) or d <= Beach.REACH
		-- hold the handover a beat (and never report in the sanity window: TooFast restarts)
		if ashore and Step.elapsed(s) > 0.8 then
			Radio.say("rip_handover")
			Step.finish(s, { metrics = {} })
		end
	end)
	return Step.cleanup(s)
end

return Beach
