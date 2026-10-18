--!strict
-- Mechanic "air_pocket" (docs/09 section 7 step 6): the rescue diver goes under the gunwale of the
-- upturned Gale Queen on a guideline, with a tender on the surface and a standby diver ready.
-- Line signals are pulls (1 all OK, 2 give slack, 3 take in), air is limited (rule of thirds), and
-- the air in the pocket slowly goes stale. Inside, the diver calms the two passengers, fits each
-- with a spare mask and leads them out one at a time. Gentle and tense, never scary: warm torch
-- light, a calm voice, no darkness, no harm. If air runs short the standby diver / mainland dive
-- team takes over and everyone is safe.
-- A certified diver (player attribute CertRescueSwimmer) dives alone; anyone else dives as a
-- trainee with an NPC buddy, Senior Diver Mara Quinn, who leads and prompts (docs 09 section 4.3).
-- Result metrics: rescued (count), signalMistakes (count), airLeft (bar), takeover (bool).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Dive =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry"):WaitForChild("Dive"))
local FerryRig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry"):WaitForChild("FerryRig"))
local FerryUi = require(script.Parent:WaitForChild("Ferry"):WaitForChild("FerryUi"))

local C = FerryUi.Theme.Colors
local WATER_TOP = Color3.fromRGB(28, 96, 112)
local WATER_LOW = Color3.fromRGB(10, 46, 62)
local ROPE = Color3.fromRGB(236, 214, 120)
local TORCH = Color3.fromRGB(255, 236, 196)

type Expect = { n: number, why: string, deadline: number?, onOk: () -> () }

local PASSENGERS = { "Mrs Okafor", "Tom, aged 12" }

local TALK = {
	{ text = "\"I'm from Haven Rescue. You're safe now, I'll take you out.\"", good = true },
	{ text = '"Quick, quick, the air\'s going!"', good = false },
	{ text = '"Stay there and don\'t move."', good = false },
}

local MASK_STEPS =
	{ "Mask over nose and mouth", "Pull the straps snug", "Breathe in: check the seal" }

local air_pocket = {}

function air_pocket.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local bin = FerryUi.bin()
	local player = Players.LocalPlayer
	local assist = ctx.isAssist == true
	local trainee = player:GetAttribute("CertRescueSwimmer") ~= true
	local tolerance = if assist or trainee then 0.075 else 0.05

	local air = Dive.StartBar
	local turnBar = Dive.turnPressure(air, Dive.ReserveBar)
	local quality = 100
	local mistakes, rescued = 0, 0
	local phase: string = "brief" -- brief, in, pocket, out, between, done
	local legProgress = 0
	local lineTight = false
	local towing = false
	local calmed = false
	local trip = 1
	local expect: Expect? = nil
	local pulls: { number } = {}
	local tenderAsked = false
	local gunwaleDone = false
	local t = 0
	local ended = false

	---------------------------------------------------------------- scene (overlay)

	local gui = bin.add(FerryUi.screen("FerryAirPocket", 24))
	local water = FerryUi.frame(gui, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1), 0)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(WATER_TOP, WATER_LOW)
	grad.Parent = water
	water.BackgroundTransparency = 1
	TweenService:Create(water, TweenInfo.new(1.2), { BackgroundTransparency = 0.05 }):Play()

	-- torch pool: a soft warm circle in the middle, transparent at the rim
	local torch =
		FerryUi.frame(water, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.19, 0.17), TORCH, 0.55)
	torch.SizeConstraint = Enum.SizeConstraint.RelativeYY
	torch.AnchorPoint = Vector2.new(0.5, 0)
	torch.Position = UDim2.fromScale(0.5, 0.16)
	FerryUi.corner(torch, 9999)
	local tg = Instance.new("UIGradient")
	tg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	tg.Parent = torch

	-- light shafts from the surface, drifting slowly
	local shafts: { Frame } = {}
	for i = 1, 4 do
		local s = FerryUi.frame(
			water,
			UDim2.new(0, 60, 1.2, 0),
			UDim2.fromScale(i * 0.2, -0.1),
			Color3.fromRGB(170, 230, 230),
			0.88
		)
		s.Rotation = 12
		table.insert(shafts, s)
	end

	-- the guideline
	local rope = FerryUi.frame(water, UDim2.new(0, 6, 1, 0), UDim2.fromScale(0.5, 0), ROPE, 0.05)
	rope.AnchorPoint = Vector2.new(0.5, 0)
	local reticle = FerryUi.frame(
		water,
		UDim2.fromOffset(34, 34),
		UDim2.fromScale(0.5, 0.6),
		Color3.new(1, 1, 1),
		1
	)
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	FerryUi.corner(reticle, 999)
	FerryUi.stroke(reticle, Color3.new(1, 1, 1), 2)

	-- HUD: air gauge, pocket air, signals, progress
	local hud =
		FerryUi.frame(water, UDim2.fromOffset(300, 150), UDim2.new(0, 24, 1, -174), C.panel, 0.35)
	FerryUi.corner(hud)
	local airText = FerryUi.text(
		hud,
		"",
		UDim2.new(1, -20, 0, 22),
		UDim2.fromOffset(10, 8),
		18,
		C.text,
		FerryUi.Theme.BoldFont
	)
	local airBar = FerryUi.frame(hud, UDim2.new(1, -20, 0, 10), UDim2.fromOffset(10, 34), C.bar, 0)
	FerryUi.corner(airBar, 4)
	local qText =
		FerryUi.text(hud, "", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 52), 16, C.text)
	local qBar = FerryUi.frame(hud, UDim2.new(1, -20, 0, 8), UDim2.fromOffset(10, 74), C.gold, 0)
	FerryUi.corner(qBar, 4)
	local pullText =
		FerryUi.text(hud, "", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 90), 16, C.text)
	local legText =
		FerryUi.text(hud, "", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 112), 14, C.textDim)
	local card = FerryUi.frame(
		water,
		UDim2.fromOffset(520, 220),
		UDim2.new(0.5, -260, 0.5, -110),
		C.panel,
		0.15
	)
	FerryUi.corner(card)
	card.Visible = false
	local cardActions: { () -> () } = {}
	local function clearCard()
		table.clear(cardActions)
		for _, ch in card:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
	end
	local function cardButton(text: string, fn: () -> ())
		table.insert(cardActions, fn)
		local k = #cardActions
		FerryUi.button(
			card,
			`{k}  {text}`,
			UDim2.new(1, -24, 0, 44),
			UDim2.fromOffset(12, 44 + (k - 1) * 52),
			C.panelLight,
			fn
		)
	end
	local signalsHelp = FerryUi.text(
		water,
		"Line signals: 1 pull = all OK   2 = give slack   3 = take in      SPACE / Pull to pull",
		UDim2.fromOffset(520, 22),
		UDim2.new(1, -540, 1, -40),
		15,
		C.text
	)
	signalsHelp.Visible = assist or trainee

	local function say(text: string, secs: number?)
		FerryUi.subtitle(gui, text, secs or 3.5)
	end
	local buddy = if trainee then "Mara" else nil
	local function buddySay(text: string)
		if buddy then
			say(`Mara (Senior Diver): {text}`, 4)
		end
	end

	---------------------------------------------------------------- finish

	local function endDive(takeover: boolean, why: string?)
		if ended then
			return
		end
		ended = true
		phase = "done"
		if why then
			say(why, 4)
		end
		TweenService:Create(water, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		task.delay(1.4, function()
			bin.clean()
			finish({
				metrics = {
					rescued = rescued,
					signalMistakes = mistakes,
					airLeft = math.floor(air),
					takeover = takeover,
				},
			})
		end)
	end

	---------------------------------------------------------------- line signals

	local function mistake(what: string)
		mistakes += 1
		FerryUi.sound(FerryUi.Sounds.lineTug, nil, 0.5)
		say(what, 3)
	end

	local function onSignal(n: number)
		pullText.Text = ""
		local e = expect
		if e and n == e.n then
			expect = nil
			FerryUi.sound(FerryUi.Sounds.lineTug, nil, 0.4)
			e.onOk()
			return
		end
		if n == 2 then
			mistake(
				"Tender pays out slack you didn't need: the line goes loose and you lose the feel of it."
			)
			lineTight = true
			task.delay(1.5, function()
				lineTight = false
			end)
		elseif n == 3 then
			mistake("Tender takes in: the line tightens and draws you back a little.")
			legProgress = math.max(0, legProgress - 0.12)
		else
			mistake(`[{n} pulls] The tender isn't sure what you mean and pulls once: "all OK?"`)
		end
	end

	local function pull()
		if phase == "done" or phase == "brief" and not expect then
			return
		end
		FerryUi.playAction("line_pull")
		table.insert(pulls, os.clock())
		pullText.Text = "Pulling: " .. string.rep("| ", #pulls)
	end

	---------------------------------------------------------------- phases

	local startLeg: (dir: string) -> ()
	local enterPocket: () -> ()

	local function tenderCheck()
		tenderAsked = true
		FerryUi.sound(FerryUi.Sounds.lineTug, nil, 0.6)
		say('[One pull on the line from the tender: "All OK?"]', 3)
		if trainee then
			buddySay("Answer it: one pull back.")
		end
		expect = {
			n = 1,
			why = "answer",
			deadline = os.clock() + 5,
			onOk = function()
				say('You pull once: "I am OK."', 2)
			end,
		}
	end

	function startLeg(dir: string)
		phase = dir
		legProgress = 0
		tenderAsked = false
		gunwaleDone = dir ~= "in"
		towing = dir == "out"
		lineTight = false
		if dir == "in" then
			turnBar = Dive.turnPressure(air, Dive.ReserveBar)
			legText.Text = "Follow the guideline in, under the gunwale."
			buddySay(
				if trip == 1
					then "Hand on the line, follow my fins."
					else "Same way back in. Nice and steady."
			)
		else
			legText.Text = `Leading {PASSENGERS[trip]} out along the line.`
		end
	end

	local function askMask(i: number, step: number)
		clearCard()
		FerryUi.text(
			card,
			`Fit the spare mask on {PASSENGERS[i]}`,
			UDim2.new(1, -24, 0, 26),
			UDim2.fromOffset(12, 10),
			20,
			C.text,
			FerryUi.Theme.HeaderFont
		)
		-- the three steps shown out of order; pick the next one
		local order = { 2, 3, 1 }
		for _, idx in order do
			cardButton(MASK_STEPS[idx], function()
				if idx == step then
					FerryUi.playAction("mask_fit_" .. step)
					if step == #MASK_STEPS then
						card.Visible = false
						FerryUi.sound(FerryUi.Sounds.breathIn, nil, 0.5)
						say(`{PASSENGERS[i]} breathes from the mask. Good seal.`, 2.5)
						buddySay("Now three pulls: take in. Then lead them out.")
						expect = {
							n = Dive.SignalFor.leaving,
							why = "leaving",
							onOk = function()
								say(
									"Three pulls: the tender starts taking in. Out you go together.",
									3
								)
								startLeg("out")
							end,
						}
					else
						askMask(i, step + 1)
					end
				else
					say("Not yet: mask first, then straps, then the seal check.", 2.5)
					quality = math.max(0, quality - 2)
				end
			end)
		end
	end

	local function talkCard(i: number)
		card.Visible = true
		clearCard()
		FerryUi.text(
			card,
			`{PASSENGERS[i]} grips the bulkhead, breathing fast.`,
			UDim2.new(1, -24, 0, 26),
			UDim2.fromOffset(12, 10),
			19,
			C.text,
			FerryUi.Theme.HeaderFont
		)
		for _, line in TALK do
			cardButton(line.text, function()
				FerryUi.playAction("calm_hand_on_shoulder")
				if line.good then
					calmed = true
					say(`{PASSENGERS[i]} nods, breathing slows.`, 2.5)
					askMask(i, 1)
				else
					say("Their breathing quickens. Slow down, reassure them.", 2.5)
					quality = math.max(0, quality - 4)
				end
			end)
		end
	end

	function enterPocket()
		phase = "pocket"
		towing = false
		calmed = false
		legText.Text = "In the air pocket."
		FerryUi.playAction("surface_in_pocket")
		-- the hull team on deck sees the diver's bubbles break over the pocket (RescueService AirPocket mark)
		local pocketAt = FerryUi.ferryPoint(ctx.operation.id, "AirPocket")
		local axisAt = FerryUi.ferryPoint(ctx.operation.id, "HullAxis")
		if pocketAt and axisAt then
			local sea = axisAt.Y - FerryRig.AXIS_ABOVE_SEA
			FerryUi.ripple(
				Vector3.new(pocketAt.X, sea, pocketAt.Z),
				0.8,
				Color3.fromRGB(220, 240, 245)
			)
		end
		say(
			if trip == 1
				then "You surface in a pocket of air under the car deck. Torchlight on two faces."
				else `{PASSENGERS[trip]} is waiting, holding on. "You came back!"`,
			3.5
		)
		buddySay("Talk first. Calm them, then the mask.")
		task.delay(1.2, function()
			if phase == "pocket" then
				talkCard(trip)
			end
		end)
	end

	local function reachGunwale()
		lineTight = true
		say("The line snags at the gunwale. Ask the tender for slack.", 3)
		buddySay("Two pulls: give slack.")
		expect = {
			n = Dive.SignalFor.gunwale,
			why = "gunwale",
			onOk = function()
				lineTight = false
				say("Two pulls: slack comes down the line. Under the gunwale you go.", 2.5)
			end,
		}
	end

	local function legDone()
		if phase == "in" then
			enterPocket()
		elseif phase == "out" then
			rescued += 1
			FerryUi.playAction("surface_handover")
			say(
				`You surface by the hull. The crew lift {PASSENGERS[trip]} aboard, wrapped and safe.`,
				3.5
			)
			if trip >= #PASSENGERS then
				endDive(
					false,
					"Both out. The tender takes in the last of the line. Well done, diver."
				)
				return
			end
			trip += 1
			phase = "between"
			task.delay(2.5, function()
				if (phase :: string) ~= "between" then
					return
				end
				if air <= turnBar or air - Dive.ReserveBar < 40 then
					endDive(
						true,
						"Not enough air for another trip: the standby diver goes in for the last one. Everyone is safe."
					)
					return
				end
				say("One pull to tell the tender you're OK and going back in.", 3)
				expect = {
					n = Dive.SignalFor.descend,
					why = "descend",
					onOk = function()
						startLeg("in")
					end,
				}
			end)
		end
	end

	---------------------------------------------------------------- brief

	card.Visible = true
	FerryUi.text(
		card,
		"AIR-POCKET CHECK",
		UDim2.new(1, -24, 0, 28),
		UDim2.fromOffset(12, 10),
		24,
		C.text,
		FerryUi.Theme.HeaderFont
	)
	FerryUi.text(
		card,
		(
			if trainee
				then "You dive as a trainee with Senior Diver Mara Quinn. "
				else "You are the diver. "
		)
			.. "The tender on the hull holds your line; the standby diver is kitted and ready.\n\n"
			.. "Keep a hand on the guideline. Answer every pull. Turn back by the rule of thirds.\n\n"
			.. 'One pull when you\'re ready: "I am OK, going down."',
		UDim2.new(1, -24, 1, -50),
		UDim2.fromOffset(12, 44),
		17,
		C.text
	)
	expect = {
		n = Dive.SignalFor.descend,
		why = "descend",
		onOk = function()
			card.Visible = false
			FerryUi.playAction("dive_descend")
			FerryUi.sound(FerryUi.Sounds.underwaterBed, nil, 0.35)
			startLeg("in")
		end,
	}

	---------------------------------------------------------------- input

	bin.add(FerryUi.keys({
		[Enum.KeyCode.Space] = pull,
		[Enum.KeyCode.ButtonA] = pull,
	}))
	local pullButton = FerryUi.button(
		water,
		"Pull",
		UDim2.fromOffset(120, 64),
		UDim2.new(1, -150, 1, -120),
		C.accent,
		pull
	)
	pullButton.Visible = UserInputService.TouchEnabled
	-- number keys answer the open choice card
	bin.add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not card.Visible then
			return
		end
		local idx = table.find(FerryUi.NumberKeys, input.KeyCode)
		local fn = idx and cardActions[idx]
		if fn then
			fn()
		end
	end))

	---------------------------------------------------------------- loop

	local breathT = 0
	local reticleX = 0.5
	bin.add(RunService.RenderStepped:Connect(function(dt)
		if phase == "done" then
			return
		end
		t += dt
		local now = os.clock()

		-- pulls resolve into a signal after a short gap
		local n = Dive.readPulls(pulls, now)
		if n then
			table.clear(pulls)
			onSignal(n)
		end
		local e = expect
		if e and e.deadline and now > e.deadline then
			expect = nil
			mistake(
				"No answer on the line: the tender pulls again and the standby diver gets ready."
			)
			task.delay(1, function()
				if phase == "in" or phase == "out" then
					tenderCheck()
				end
			end)
		end

		-- the guideline sways with the surge; the reticle follows the pointer
		local lineX = 0.5 + 0.16 * math.sin(t * 0.7) + 0.06 * math.sin(t * 1.9 + 1)
		rope.Position = UDim2.fromScale(lineX, 0)
		local vp = workspace.CurrentCamera.ViewportSize
		local m = UserInputService:GetMouseLocation()
		if vp.X > 0 then
			reticleX = math.clamp(m.X / vp.X, 0, 1)
		end
		reticle.Position = UDim2.fromScale(reticleX, 0.6)
		local onLine = math.abs(reticleX - lineX) <= tolerance
		reticle.BackgroundTransparency = if onLine then 0.6 else 1
		for i, s in shafts do
			s.Position = UDim2.fromScale(i * 0.2 + 0.03 * math.sin(t * 0.3 + i), -0.1)
			s.BackgroundTransparency = 0.86 + 0.06 * math.sin(t * 0.5 + i * 2)
		end

		-- air: breathing all the time underwater, calm in the pocket
		local inWater = phase == "in" or phase == "out"
		local rate = if inWater then Dive.airRate(onLine, towing, trainee) else 0.6
		air = math.max(0, air - rate * dt)
		breathT += dt
		if breathT > 4 then
			breathT = 0
			FerryUi.sound(FerryUi.Sounds.bubbles, nil, 0.25)
		end
		if
			phase == "pocket"
			or (phase == "in" and trip > 1)
			or phase == "out"
			or phase == "between"
		then
			local occupants = #PASSENGERS - rescued - (if phase == "out" then 1 else 0)
			quality = math.max(0, quality - Dive.airQualityRate(occupants, calmed) * dt)
		end

		-- progress along the line
		if inWater then
			legProgress =
				math.min(1, legProgress + Dive.progressRate(onLine, lineTight, towing) * dt)
			if phase == "in" and not tenderAsked and legProgress >= 0.25 and trip == 1 then
				tenderCheck()
			end
			if phase == "in" and not gunwaleDone and legProgress >= 0.5 then
				legProgress = 0.5 -- the line holds the diver at the gunwale until slack is given
				if not expect then
					gunwaleDone = true
					reachGunwale()
				end
			end
			if legProgress >= 1 and not expect then
				legDone()
			end
		end

		-- gauges (Pro: words only, no numbers)
		airBar.Size = UDim2.new((1 * air / Dive.StartBar), -20, 0, 10)
		airBar.BackgroundColor3 = if air <= Dive.ReserveBar
			then C.accent
			elseif air <= turnBar then C.gold
			else C.bar
		airText.Text = if assist
			then `Air {math.floor(air)} bar · turn at {math.floor(turnBar)}`
			else Dive.gaugeWord(air, turnBar)
		qText.Text = "Air in the pocket" .. (if quality < 50 then ": getting stale" else "")
		qBar.Size = UDim2.new(quality / 100, -20, 0, 8)
		if phase == "in" or phase == "out" then
			legText.Text = string.format(
				"%s  %d%%",
				if phase == "in" then "Going in" else "Coming out",
				legProgress * 100
			)
		end

		-- fail-safes, always safe
		if air <= Dive.ReserveBar and phase ~= "out" then
			endDive(
				true,
				"Reserve air: you turn for home and the standby diver takes over. Everyone is safe."
			)
		elseif quality <= Dive.AirQualityTakeover then
			endDive(
				true,
				"The mainland dive team arrives with air for the pocket and brings everyone out safely."
			)
		end
	end))

	if player:GetAttribute("OpsAutoStub") == true then
		task.delay(1, function()
			rescued = #PASSENGERS
			endDive(false)
		end)
	end

	return function()
		ended = true
		phase = "done"
		bin.clean()
	end
end

return air_pocket
