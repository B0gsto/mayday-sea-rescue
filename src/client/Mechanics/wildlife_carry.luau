--!strict
-- wildlife_carry: get the freed animal aboard with the Person in the Water ways (docs/14 section 3):
-- grab and drag it alongside, throw the line, or stop close and let it come to you. A thin wrapper
-- over PIW/Ways, not a copy, so an animal is recovered exactly like a casualty.
local Step = require(script.Parent.PIW.Step)
local Ways = require(script.Parent.PIW.Ways)

local Mech = {}

function Mech.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "Carry", 96)
	if Step.autoStub(s, { method = "throwbag", score = 0.9 }) then
		return Step.cleanup(s)
	end
	s.panel.Visible = false
	local ok = pcall(Ways.run, s, ctx, "throwbag")
	if not ok then
		Step.finish(s, { metrics = { method = "throwbag", score = 0.5 }, stub = true })
	end
	return Step.cleanup(s)
end

return Mech
