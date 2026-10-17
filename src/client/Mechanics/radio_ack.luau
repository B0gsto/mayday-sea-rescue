--!strict
-- radio_ack: answer the tasking on the radio wheel (docs 09 section 3.3/3.4). The server measures
-- `elapsed` (answer within 15 s for Gold); this mechanic also grades voice procedure as `format`
-- (RadioFormat.grade: callsigns in the right order, the right message, "over" not "out" and never
-- "over and out"). "Say again" repeats the tasking at no cost; "Unable" costs a procedure point
-- and the Coastguard asks you to confirm. Interface: CONTRACT.md "Operations v2".
local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Radio = require(Client:WaitForChild("Controllers"):WaitForChild("RadioController"))
local RadioFormat = require(Client:WaitForChild("UI"):WaitForChild("RadioFormat"))

local M = {}

function M.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local cs = Radio.callsign()
	local expect = RadioFormat.AckExpect(cs)
	local seed = math.floor(os.clock() * 1000) % 100000 + (ctx.attempt or 1)
	local alive = true
	local busy = false
	local mistakes = 0
	local options = RadioFormat.ackOptions(cs, seed)
	local onPick: (opt: any) -> ()

	local function offer()
		if alive and not busy then
			Radio.openWheel(options, onPick, {
				title = `Answer the Coastguard · {ctx.step.realTerm or "Tasking"}`,
				hint = ctx.isAssist == true,
				hintAfter = 5,
			})
		end
	end

	onPick = function(opt: any)
		if not alive or busy then
			return
		end
		busy = true
		local msg: RadioFormat.Message = opt.msg
		local h = Radio.transmit(msg)
		if msg.body == "say_again" then
			h:wait()
			local again = Radio.repeatLast()
			if again then
				again:wait()
			end
			busy = false
			offer()
			return
		end
		if msg.body == "unable" then
			mistakes += 1
			h:wait()
			Radio.say("confirm_able"):wait()
			busy = false
			offer()
			return
		end
		local score, faults = RadioFormat.grade(msg, expect)
		score = math.max(0, score - 0.34 * mistakes)
		alive = false
		finish({
			metrics = { format = score },
			grade = if score >= 1 then "Gold" elseif score >= 0.6 then "Silver" else "Bronze",
		})
		task.spawn(function()
			h:wait()
			task.wait(0.6)
			Radio.say(if msg.body == "roger" then "ack_launch" else "ack_datum")
			-- in Assist the crew says what was off, once, over the intercom
			if ctx.isAssist and faults[1] then
				Radio.sayText(
					"Crew",
					faults[1],
					{ mode = "intercom", priority = Radio.Priorities.Advice }
				)
			end
		end)
	end

	offer()
	-- the Coastguard chases a silent unit (docs 09 section 3.3)
	task.delay(16, function()
		if alive and not busy then
			Radio.say("nudge")
			if not Radio.isWheelOpen() then
				offer()
			end
		end
	end)
	-- smoke runs (tools/studio/smoke.py ops) answer by themselves
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
