--!strict
-- radio_ack: the tasking is answered on accept (docs 09 section 3.3/3.4): a beat later the crew
-- voices the acknowledgement by itself. The server grades `elapsed` only (answer within 15 s for
-- Gold). Interface: CONTRACT.md "Operations v2".
local Client = script.Parent.Parent
local Radio = require(Client:WaitForChild("Controllers"):WaitForChild("RadioController"))
local RadioFormat = require(Client:WaitForChild("UI"):WaitForChild("RadioFormat"))

local M = {}

function M.start(_ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local alive = true
	local msg: RadioFormat.Message = {
		order = "toFrom",
		to = "CG",
		from = Radio.callsign(),
		body = "copy_launching",
		proword = "Over",
	}
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
			Radio.say("ack_datum")
		end)
	end
	-- accepting the call (card key, tap or the call board) is the answer: the crew voices it, no
	-- second R prompt and no "I say again" repeats (playtest: two accept paths read as noise)
	task.delay(1, talk)
	return function()
		alive = false
	end
end

return M
