--!strict
-- panic_calm (docs 09 section 5.4, Panicking casualty): the swimmer stops at arm's length, works
-- round behind them, presents the rescue tube and talks calmly in the lulls of their splashing
-- until they take the tube. Inside arm's length with high panic they grab: flick away and reset.
-- Metrics: calmSeconds, grabbed (count). Engine and controls: PIW/Swimmer.
local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Swimmer = require(script.Parent.PIW.Swimmer)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local PanicCalm = {}

function PanicCalm.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "PanicCalm", 96)
	if Step.autoStub(s, { calmSeconds = 15, grabbed = 0 }) then
		return Step.cleanup(s)
	end
	Step.line(s, "Arm's length. Offer the tube, never your hand.", 54)
	local seed = Units.hash01(tostring(ctx.casualty and ctx.casualty.id or ctx.operation.id), 9)
	Swimmer.contact(s, World.victim(ctx), 95, seed, function(res)
		Record.get(ctx.operation.id).calmed = true
		Step.finish(s, {
			metrics = { calmSeconds = math.floor(res.seconds * 10 + 0.5) / 10, grabbed = res.grabs },
		})
	end)
	return Step.cleanup(s)
end

return PanicCalm
