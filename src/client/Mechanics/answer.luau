--!strict
-- answer: accepting the call (card key, tap, the call board or driving at it) is the answer; the
-- step finishes a beat later by itself. The server grades `elapsed` only (answer within 15 s for
-- Gold). Interface: CONTRACT.md "Operations v2".
local M = {}

function M.start(_ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local alive = true
	task.delay(1, function()
		if alive then
			alive = false
			finish({ metrics = {} })
		end
	end)
	return function()
		alive = false
	end
end

return M
