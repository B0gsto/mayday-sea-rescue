--!strict
-- handover (docs 09 step 10, section 5.8): the ATMIST report to the ambulance crew, one card per
-- letter: Age, Time, Mechanism, Injuries, Signs, Treatment. The right cards are what this crew
-- actually saw and did (the survey and treatment are read back from PIW/Record).
-- Metric: correct (cards right of 6); the server times it (elapsed).
-- Controls: cards 1-4 / tap / A B X Y.
local Medical = require(script.Parent.PIW.Medical)
local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)

local Handover = {}

function Handover.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Handover", 96)
	if Step.autoStub(s, { correct = 6 }) then
		return Step.cleanup(s)
	end
	local e = Record.get(ctx.operation.id)
	local profile = Record.profile(ctx)
	local id = tostring(ctx.casualty and ctx.casualty.id or ctx.operation.id)
	local cards = Medical.atmistCards(profile, id, {
		findings = e.findings,
		applied = e.applied,
		minutesOnScene = (os.clock() - e.startedAt) / 60,
	})
	local status = Step.line(s, 'Paramedic: "Go ahead with your handover."', 54)
	Ui.hands("handover")
	local right, index = 0, 0
	local current: Frame? = nil
	local function nextCard()
		index += 1
		local card = cards[index]
		if not card then
			s.say('"Thanks, crew. We\'ll take it from here."', 3)
			Step.finish(s, { metrics = { correct = right } })
			return
		end
		status.Text = `ATMIST {index} of 6`
		current = Ui.cards(s.bag, s.gui, {
			title = card.title,
			cue = card.cue,
			options = card.options,
			answer = card.answer,
			assist = s.assist,
		}, function(i)
			if i == card.answer then
				right += 1
			end
			if current then
				current:Destroy()
			end
			nextCard()
		end)
		Ui.add(s.bag, current)
	end
	nextCard()
	return Step.cleanup(s)
end

return Handover
