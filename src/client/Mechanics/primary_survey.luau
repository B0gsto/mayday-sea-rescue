--!strict
-- primary_survey (docs 09 step 7, section 5.5): DR ABCDE, "first aid check, the way lifeboat
-- crews do it". One card per letter: read the cue (what you see and hear), pick the finding.
-- For Breathing the Medic watches the chest for 5 s and taps with each rise (the count is the
-- cue). On the jet ski only Response, Breathing and Cold fit. Metric: correct (fraction right);
-- the server times it (elapsed). Controls: cards 1-4 / tap / A B X Y; breath taps left click,
-- Space, a pad, or LB/RB.
local Medical = require(script.Parent.PIW.Medical)
local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local World = require(script.Parent.PIW.World)

local Survey = {}

Survey.WATCH = 5 -- s of watching the chest

function Survey.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Survey", 96)
	if Step.autoStub(s, { correct = 1 }) then
		return Step.cleanup(s)
	end
	local profile = Record.profile(ctx)
	local jet = World.isJetSki(World.vehicle(ctx))
	local cards = Medical.surveyCards(profile, jet, ctx.operation.storm == true)
	local picks: { [string]: number } = {}
	local status = Step.line(s, "First aid check, the way lifeboat crews do it.", 54)
	Ui.hands("survey_check")
	local index = 0
	local current: Frame? = nil

	local nextCard: () -> ()
	local function show(card: Medical.Card, cue: string)
		current = Ui.cards(s.bag, s.gui, {
			title = card.title,
			cue = cue,
			options = card.options,
			answer = card.answer,
			assist = s.assist,
		}, function(i)
			picks[card.letter] = i
			if current then
				current:Destroy()
			end
			nextCard()
		end)
		Ui.add(s.bag, current)
	end

	local function watchChest(card: Medical.Card)
		-- the chest rises at the casualty's real rate; the Medic counts with taps
		local rate = Medical.breathRate(profile)
		local frame = Ui.panel(s.gui, UDim2.fromOffset(420, 120), UDim2.new(0.5, 0, 1, -24))
		Ui.add(s.bag, frame)
		Ui.text(
			frame,
			"B  Breathing: watch the chest, tap with each rise",
			UDim2.new(1, -24, 0, 22),
			UDim2.fromOffset(12, 8),
			17,
			true
		)
		local chest = Instance.new("Frame")
		chest.AnchorPoint = Vector2.new(0.5, 1)
		chest.Position = UDim2.new(0.5, 0, 1, -14)
		chest.Size = UDim2.fromOffset(180, 20)
		chest.BackgroundColor3 = Color3.fromRGB(200, 120, 60) -- the casualty's jacket, rising and falling
		chest.BorderSizePixel = 0
		chest.Parent = frame
		Ui.Theme.corner(chest, 10)
		local counted =
			Ui.text(frame, "Taps: 0", UDim2.fromOffset(120, 20), UDim2.fromOffset(12, 36), 15)
		local taps = 0
		local t0 = os.clock()
		local function tap()
			taps += 1
			counted.Text = `Taps: {taps}`
		end
		local unbind = Ui.bind(
			s.bag,
			"Breath",
			function(state)
				if state == "Begin" then
					tap()
				end
			end,
			Enum.KeyCode.Space,
			Enum.UserInputType.MouseButton1,
			Enum.KeyCode.ButtonL1,
			Enum.KeyCode.ButtonR1
		)
		local tapButton =
			Ui.button(frame, "Rise", UDim2.fromOffset(96, 52), UDim2.new(1, -108, 0, 40), tap)
		tapButton.Visible = Ui.isTouch()
		local conn: RBXScriptConnection? = nil
		conn = game:GetService("RunService").Heartbeat:Connect(function()
			local t = os.clock() - t0
			local rise = if rate > 0 then math.max(0, math.sin(t * rate / 60 * 2 * math.pi)) else 0
			chest.Size = UDim2.fromOffset(180, 20 + 22 * rise)
			if t >= Survey.WATCH then
				if conn then
					conn:Disconnect()
				end
				unbind()
				frame:Destroy()
				local perMinute = taps * 60 / Survey.WATCH
				show(
					card,
					`{card.cue} You counted {taps} in 5 s (about {math.floor(perMinute)} a minute).`
				)
			end
		end)
		Ui.add(s.bag, conn)
	end

	nextCard = function()
		index += 1
		local card = cards[index]
		if not card then
			local e = Record.get(ctx.operation.id)
			e.findings = picks
			e.surveyed = true
			Step.finish(s, {
				metrics = {
					correct = math.floor(Medical.surveyCorrect(cards, picks) * 100 + 0.5) / 100,
				},
			})
			return
		end
		status.Text = `{index} of {#cards}: {card.title}`
		if card.letter == "Breathing" then
			watchChest(card)
		else
			show(card, card.cue)
		end
	end
	nextCard()
	return Step.cleanup(s)
end

return Survey
