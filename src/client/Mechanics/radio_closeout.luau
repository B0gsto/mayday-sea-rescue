--!strict
-- radio_closeout: close out with the Coastguard on the radio wheel. Report the POB you actually
-- have (the server turns `pob` into `pobRight`: everyone counted off the vessel, or on a big call
-- the number saved) with correct procedure (`format`, RadioFormat.grade). The Coastguard then
-- stands the unit down. Interface: CONTRACT.md "Operations v2".
local Players = game:GetService("Players")

local Client = script.Parent.Parent
local OpsController = require(Client:WaitForChild("Controllers"):WaitForChild("OpsController"))
local Radio = require(Client:WaitForChild("Controllers"):WaitForChild("RadioController"))
local RadioFormat = require(Client:WaitForChild("UI"):WaitForChild("RadioFormat"))

local M = {}

function M.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local cs = Radio.callsign()
	local ferry = ctx.operation.kind == "CapsizedFerry" or ctx.operation.isBig == true
	local s = OpsController.GetState()
	local truth = 1
	if s then
		truth = if s.isBig then (s.saved or 0) else #(s.casualties or {})
	end
	truth = math.max(truth, 1)
	local seed = math.floor(os.clock() * 1000) % 100000 + (ctx.attempt or 1)
	local options = RadioFormat.closeoutOptions(cs, truth, ferry, seed)
	local expect = RadioFormat.CloseoutExpect(cs, ferry)
	local alive = true

	local function onPick(opt: any)
		if not alive then
			return
		end
		alive = false
		local msg: RadioFormat.Message = opt.msg
		local h = Radio.transmit(msg)
		local score, faults = RadioFormat.grade(msg, expect)
		finish({ metrics = { pob = RadioFormat.pobOf(msg) or 0, format = score } })
		task.spawn(function()
			h:wait()
			task.wait(0.6)
			if RadioFormat.pobOf(msg) == truth then
				Radio.say(if ferry then "all_accounted" else "stand_down")
			else
				Radio.sayText(
					"Gale Isles Coastguard",
					"Count does not match. Confirm all persons are off the vessel, over."
				)
			end
			if ctx.isAssist and faults[1] then
				Radio.sayText(
					"Crew",
					faults[1],
					{ mode = "intercom", priority = Radio.Priorities.Advice }
				)
			end
		end)
	end

	Radio.openWheel(options, onPick, {
		title = if ferry
			then "Account for everyone · report to the Coastguard"
			else "Close out · report POB",
		hint = ctx.isAssist == true,
		hintAfter = 6,
	})
	if Players.LocalPlayer:GetAttribute("OpsAutoStub") == true then
		task.delay(1, function()
			for _, o in options do
				if o.correct and alive then
					Radio.closeWheel()
					onPick(o)
				end
			end
		end)
	end
	return function()
		if alive then
			alive = false
			Radio.closeWheel()
		end
	end
end

return M
