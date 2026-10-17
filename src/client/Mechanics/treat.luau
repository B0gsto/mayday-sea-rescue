--!strict
-- treat (docs 09 step 8, section 5.6): treat what the survey found. Apply kit to the casualty in
-- order: shelter, insulate, oxygen, recovery position, keep a cold casualty flat; never rub limbs
-- or give a drowsy casualty a drink. Kit you did not load is "not carried". CPR is offered only
-- when the survey found "Not breathing normally": 5 rescue breaths, then 30:2 (adult) or 15:2
-- (child) to a 110 a minute metronome, shown as a calm, clothed casualty and a heartbeat bar.
-- Metrics: matches (0..1), harmful (count); events harmfulTreatment, wrongHandling.
-- Controls: click / tap an item, number keys (1-9, 0, -, =), gamepad D-pad + A; Done: Enter / Y.
-- CPR: compressions left/right click, LB/RB or the pads on the beat; breath: Space / Y / Breath.
local RunService = game:GetService("RunService")

local Medical = require(script.Parent.PIW.Medical)
local Record = require(script.Parent.PIW.Record)
local Rhythm = require(script.Parent.PIW.Rhythm)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)

local Treat = {}

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
	Enum.KeyCode.Zero,
	Enum.KeyCode.Minus,
	Enum.KeyCode.Equals,
	Enum.KeyCode.Backspace,
}

-- CPR runner: calls done(quality 0..1).
local function runCpr(s: Step.S, ageBand: string, done: (number) -> ())
	local plan = Rhythm.cprPlan(ageBand)
	local cbag = Ui.bag()
	Ui.add(s.bag, function()
		Ui.clean(cbag)
	end)
	local seq = Rhythm.cprSequence(plan)
	local interval = 60 / plan.bpm
	local window = if s.assist then 0.16 else 0.1
	local frame = Ui.panel(s.gui, UDim2.fromOffset(520, 150), UDim2.new(0.5, 0, 1, -24))
	Ui.add(s.bag, frame)
	Ui.text(
		frame,
		`CPR ({ageBand}): 5 breaths, then {plan.compressions}:2`,
		UDim2.new(1, -24, 0, 22),
		UDim2.fromOffset(12, 8),
		18,
		true
	)
	local prompt = Ui.text(frame, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 34), 17)
	local beat = Instance.new("Frame")
	beat.Size = UDim2.fromOffset(18, 18)
	beat.Position = UDim2.fromOffset(12, 64)
	beat.BackgroundColor3 = Ui.Theme.Colors.text
	beat.BorderSizePixel = 0
	beat.Parent = frame
	Ui.Theme.corner(beat, 9)
	local setDepth =
		Ui.meter(frame, "Push hard and fast, centre of the chest", UDim2.fromOffset(40, 60), 460)
	local i = 1
	local t0 = os.clock()
	local onBeat, compressions, breathsRight, breaths = 0, 0, 0, 0
	local finished = false
	local function finishCpr()
		if finished then
			return
		end
		finished = true
		Ui.clean(cbag)
		frame:Destroy()
		done(Rhythm.cprQuality(onBeat, compressions, breathsRight, breaths))
	end
	local function show()
		local want = seq[i]
		if want == nil then
			finishCpr()
			return
		end
		prompt.Text = if want == "B"
			then `Breath {breaths + 1}: tilt the head, breathe in (Space / Y)`
			else `Compression {compressions + 1}: on the beat`
	end
	local function compress()
		if finished then
			return
		end
		if seq[i] ~= "C" then
			return
		end
		compressions += 1
		if Rhythm.beatError(os.clock(), t0, interval) <= window then
			onBeat += 1
			setDepth(0.85, 0.7, 1)
		else
			setDepth(0.4, 0.7, 1)
		end
		Ui.hands("cpr_compress")
		i += 1
		show()
	end
	local function breathe()
		if finished then
			return
		end
		breaths += 1
		if seq[i] == "B" then
			breathsRight += 1
			Ui.hands("cpr_breath")
			i += 1
			t0 = os.clock() -- the metronome restarts after the breaths
		end
		show()
	end
	Ui.pads(cbag, frame, function()
		compress()
	end)
	Ui.bind(cbag, "CprBreath", function(state)
		if state == "Begin" then
			breathe()
		end
	end, Enum.KeyCode.Space, Enum.KeyCode.ButtonY)
	local breathButton =
		Ui.button(frame, "Breath", UDim2.fromOffset(110, 48), UDim2.new(1, -122, 0, 92), breathe)
	breathButton.Visible = Ui.isTouch()
	local conn = RunService.Heartbeat:Connect(function()
		local phase = ((os.clock() - t0) / interval) % 1
		beat.BackgroundTransparency = if phase < 0.18 then 0 else 0.75
	end)
	Ui.add(cbag, conn)
	Ui.add(s.bag, task.delay(80, finishCpr))
	show()
end

function Treat.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "Treat", 330)
	if Step.autoStub(s, { matches = 1, harmful = 0 }) then
		return Step.cleanup(s)
	end
	local e = Record.get(ctx.operation.id)
	local profile = Record.profile(ctx)
	local carried: { [string]: boolean } = {}
	for _, t in Medical.Treatments do
		if t.needs then
			carried[t.needs] = Record.carried(ctx.operation.id, t.needs)
		end
	end
	local need, harmful = Medical.treatmentPlan(profile, carried)
	-- CPR is only on the table when the survey found "Not breathing normally"
	local offerCpr = e.findings.Breathing == 4
	local items: { Medical.Treat } = {}
	for _, t in Medical.Treatments do
		if t.id ~= "cpr" or offerCpr then
			table.insert(items, t)
		end
	end
	s.panel.Size = UDim2.fromOffset(600, 330)
	local applied: { string } = {}
	local list = Step.line(s, "Applied: nothing yet", 54)
	list.Size = UDim2.new(1, -24, 0, 36)
	local cursor = 1
	local buttons: { TextButton } = {}
	local busy = false
	local cprQuality = 1
	local wrongHandling = 0

	local function refresh()
		local names = {}
		for _, id in applied do
			for _, t in Medical.Treatments do
				if t.id == id then
					table.insert(names, t.label)
				end
			end
		end
		list.Text = "Applied: " .. (if #names > 0 then table.concat(names, ", ") else "nothing yet")
		for i, b in buttons do
			local t = items[i]
			local missing = t.needs ~= nil and not carried[t.needs]
			local used = table.find(applied, t.id) ~= nil
			b.BackgroundColor3 = if missing
				then Ui.Theme.Colors.locked
				elseif used then Ui.Theme.Colors.accent
				else Ui.Theme.Colors.panelLight
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if Ui.isGamepad() and i == cursor then
				if not stroke then
					Ui.Theme.stroke(b, Ui.Theme.Colors.text, 2)
				end
			elseif stroke then
				stroke:Destroy()
			end
		end
	end

	local function apply(i: number)
		local t = items[i]
		if busy or not t or table.find(applied, t.id) then
			return
		end
		if t.needs and not carried[t.needs] then
			s.say(`{t.label}: not carried`)
			return
		end
		table.insert(applied, t.id)
		Ui.hands("treat_" .. t.id)
		if t.id == "sitUp" and (profile.state == "VeryCold" or profile.state == "Unresponsive") then
			wrongHandling = 1
			s.say('Medic: "Lay them back down! Keep them flat."')
		elseif t.id == "rub" then
			s.say('Medic: "Don\'t rub them, it drives the cold in."')
		end
		if t.id == "cpr" then
			busy = true
			runCpr(s, profile.ageBand, function(q)
				cprQuality = q
				busy = false
				s.say(
					if q >= 0.6
						then "They cough... they're breathing!"
						else "Keep going: the ambulance will take over.",
					3
				)
			end)
		end
		refresh()
	end

	for i, t in items do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local key = if i <= 9
			then tostring(i)
			elseif i == 10 then "0"
			elseif i == 11 then "-"
			elseif i == 12 then "="
			else "Bksp"
		local b = Ui.button(
			s.panel,
			`{key}  {t.label}`,
			UDim2.fromOffset(186, 40),
			UDim2.fromOffset(12 + col * 194, 94 + row * 44),
			function()
				apply(i)
			end
		)
		b.TextSize = 15
		buttons[i] = b
	end

	local function done()
		if busy then
			return
		end
		e.applied = applied
		local matches, bad = Medical.treatmentScore(applied, need, harmful)
		if table.find(applied, "cpr") then
			matches *= 0.5 + 0.5 * cprQuality
		end
		local harmfulEvents = bad
			- (if table.find(applied, "sitUp") and wrongHandling > 0 then 1 else 0)
		local events: { [string]: number } = {}
		if harmfulEvents > 0 then
			events.harmfulTreatment = harmfulEvents
		end
		if wrongHandling > 0 then
			events.wrongHandling = wrongHandling
		end
		Step.finish(s, {
			metrics = { matches = math.floor(matches * 100 + 0.5) / 100, harmful = bad },
			events = if next(events) then events else nil,
		})
	end
	local doneButton = Ui.button(
		s.panel,
		"Treatment done  (Enter / Y)",
		UDim2.new(1, -24, 0, 40),
		UDim2.new(0, 12, 1, -48),
		done
	)
	doneButton.BackgroundColor3 = Ui.Theme.Colors.accent
	Ui.bind(
		s.bag,
		"TreatKeys",
		function(state, input)
			if state ~= "Begin" or busy then
				return
			end
			local k = table.find(KEYS, input.KeyCode)
			if k then
				apply(k)
			elseif input.KeyCode == Enum.KeyCode.DPadRight then
				cursor = cursor % #items + 1
			elseif input.KeyCode == Enum.KeyCode.DPadLeft then
				cursor = (cursor - 2) % #items + 1
			elseif input.KeyCode == Enum.KeyCode.DPadDown then
				cursor = math.min(#items, cursor + 3)
			elseif input.KeyCode == Enum.KeyCode.DPadUp then
				cursor = math.max(1, cursor - 3)
			elseif input.KeyCode == Enum.KeyCode.ButtonA then
				apply(cursor)
			elseif
				input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonY
			then
				done()
			end
			refresh()
		end,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
		Enum.KeyCode.Seven,
		Enum.KeyCode.Eight,
		Enum.KeyCode.Nine,
		Enum.KeyCode.Zero,
		Enum.KeyCode.Minus,
		Enum.KeyCode.Equals,
		Enum.KeyCode.Backspace,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.DPadUp,
		Enum.KeyCode.DPadDown,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonY,
		Enum.KeyCode.Return
	)
	if not e.surveyed then
		Ui.hint(s.panel, "No survey yet: you are guessing what is wrong.", s.assist).Position =
			UDim2.new(0, 12, 1, -70)
	end
	refresh()
	return Step.cleanup(s)
end

return Treat
