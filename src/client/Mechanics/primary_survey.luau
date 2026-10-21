--!strict
-- primary_survey (docs 09 step 7, section 5.5): DR ABCDE as hands on the casualty, no cards
-- (docs 14 section 2). Look over the casualty: the head, chest, arm and body glow as you look at
-- them; hold E / X (touch: press and hold the spot) to check one. What you find shows on the body,
-- never as text: their voice or silence and the head tilted back (Response, Airway), breath puffs
-- at their rate, none when they are not breathing (Breathing), blue lips or a red graze
-- (Circulation), shivering or a still body (Disability, Exposure). Any order. After 5 s idle the
-- next spot pulses; after 10 s the Medic checks it. Jet ski: head, chest, body. Danger is the scene.
-- Metric: correct = share of the areas the player checked (0..1); the server times it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(script.Parent.PIW.Care)
local CasualtyCare = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("CasualtyCare")
)
local Medical = require(script.Parent.PIW.Medical)
local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local World = require(script.Parent.PIW.World)

local Survey = {}

Survey.CHECK = 1 -- s of holding per area
Survey.HINT = 5 -- s idle before the next area pulses
Survey.IDLE = 10 -- s idle before the Medic checks it
Survey.SHOW = 1.5 -- s the last finding shows before the step ends

function Survey.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Survey", 96, true)
	if Step.autoStub(s, { correct = 1 }) then
		return Step.cleanup(s)
	end
	s.panel.Visible = false
	local profile = Record.profile(ctx)
	local jet = World.isJetSki(World.vehicle(ctx))
	local letters: { string } = {}
	local answer: { [string]: number } = {}
	for _, c in Medical.surveyCards(profile, jet, ctx.operation.storm == true) do
		table.insert(letters, c.letter)
		answer[c.letter] = c.answer
	end
	local areas = CasualtyCare.surveyAreas(letters)
	local body = Care.body(ctx, s.bag)
	local checked: { string } = {}
	local mine = 0
	local last = os.clock()
	local holdArea: string?, progress = nil, 0
	local picker = Care.picker(s.bag, body.folder, function() end)

	local function nextArea(): string?
		for _, a in areas do
			if not table.find(checked, a) then
				return a
			end
		end
		return nil
	end

	local function check(area: string, byPlayer: boolean)
		table.insert(checked, area)
		mine += if byPlayer then 1 else 0
		picker.remove(area)
		picker.hint(nil)
		if byPlayer then
			Ui.hands("survey_check")
		end
		for _, letter in CasualtyCare.lettersAt(area, letters) do
			Care.finding(s.bag, body, letter, answer[letter], s.say)
		end
		last = os.clock()
		if nextArea() == nil then
			local e = Record.get(ctx.operation.id)
			for letter, a in answer do
				e.findings[letter] = a
			end
			e.surveyed = true
			local correct = CasualtyCare.share(mine, #areas)
			Ui.add(
				s.bag,
				task.delay(Survey.SHOW, function()
					Step.finish(s, { metrics = { correct = correct } })
				end)
			)
		end
	end

	for _, a in areas do
		picker.set(a, function()
			return body.at(a)
		end)
	end

	Step.heartbeat(s, function(dt)
		if nextArea() == nil then
			return
		end
		local a = picker.aimed()
		if picker.down() and a then
			if a ~= holdArea then
				holdArea, progress = a, 0
			end
			progress += dt / Survey.CHECK
			picker.fill(progress)
			last = os.clock()
			if progress >= 1 then
				holdArea, progress = nil, 0
				picker.fill(nil)
				check(a, true)
			end
			return
		end
		holdArea, progress = nil, 0
		picker.fill(nil)
		local idle = os.clock() - last
		if idle > Survey.IDLE then
			check(nextArea() :: string, false) -- the Medic checks it (nobody gets stuck)
		elseif idle > Survey.HINT then
			picker.hint(nextArea())
		end
	end)
	return Step.cleanup(s)
end

return Survey
