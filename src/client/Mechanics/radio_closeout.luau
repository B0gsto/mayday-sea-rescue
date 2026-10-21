--!strict
-- radio_closeout: close out with the Coastguard by push-to-talk: hold R / gamepad DPadUp / the
-- touch Radio button, release, and the crew reports the POB you actually have (everyone counted
-- off the vessel, or on a big call the number saved). The server grades `elapsed` only. Silent
-- for 10 s: the Coastguard calls again. Interface: CONTRACT.md "Operations v2".
local Players = game:GetService("Players")

local Client = script.Parent.Parent
local OpsController = require(Client:WaitForChild("Controllers"):WaitForChild("OpsController"))
local Radio = require(Client:WaitForChild("Controllers"):WaitForChild("RadioController"))
local RadioFormat = require(Client:WaitForChild("UI"):WaitForChild("RadioFormat"))

local M = {}

M.REPEAT = 10 -- seconds of silence before the Coastguard calls again

function M.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local wildlife = ctx.operation.kind == "WildlifeRescue"
	local ferry = ctx.operation.kind == "CapsizedFerry" or ctx.operation.isBig == true
	local s = OpsController.GetState()
	local truth = 1
	if s then
		truth = if s.isBig then (s.saved or 0) else #(s.casualties or {})
	end
	truth = math.max(truth, 1)
	local key = if ferry then "n" else "pob"
	local msg: RadioFormat.Message = {
		order = "toFrom",
		to = "CG",
		from = Radio.callsign(),
		body = if wildlife
			then "wildlife_safe"
			elseif ferry then "all_accounted"
			else "vessel_secured",
		proword = "Over",
		params = { [key] = truth, [key .. "N"] = truth },
	}
	local alive = true

	local function talk()
		if not alive then
			return
		end
		alive = false
		local h = Radio.transmit(msg)
		finish({ metrics = {} })
		task.spawn(function()
			h:wait()
			task.wait(0.6)
			Radio.say(
				if wildlife then "wildlife_safe" elseif ferry then "all_accounted" else "stand_down"
			)
		end)
	end
	local disarm = Radio.ptt(talk)
	task.spawn(function()
		while true do
			task.wait(M.REPEAT)
			if not alive then
				return
			end
			Radio.say("nudge")
		end
	end)
	if Players.LocalPlayer:GetAttribute("OpsAutoStub") == true then
		task.delay(1, function()
			disarm()
			talk()
		end)
	end
	return function()
		alive = false
		disarm()
	end
end

return M
