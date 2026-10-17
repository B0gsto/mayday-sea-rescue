--!strict
-- Mechanic "triage" (docs/09 section 7 step 4): the triage sieve on one casualty, then a coloured
-- priority band. The medic holds a laminated sieve card; each check is a real action with its own
-- cue (ask them to walk, open the airway, shout and tap, count breaths over 15 s, press a fingertip
-- and watch the colour come back). Then the band: P1 Immediate (red), P2 Urgent (yellow),
-- P3 Can wait (green). No black tag exists. Several medics can triage different casualties at once
-- (each crew's track claims its own casualty; the server checks the tag against the state).
-- Result metrics: tag ("Red"/"Yellow"/"Green", the server derives tagRight), plus advisory
-- checks, orderFollowed, countError. The server measures elapsed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FerryUi = require(script.Parent:WaitForChild("Ferry"):WaitForChild("FerryUi"))
local Triage =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry"):WaitForChild("Triage"))

local C = FerryUi.Theme.Colors
local CARD = Color3.fromRGB(246, 242, 228) -- laminated card
local INK = Color3.fromRGB(30, 36, 44)

local CHECK_LABELS = {
	walk = "Ask them to walk",
	airway = "Open airway: look, listen, feel",
	responsive = "Shout, tap the shoulder",
	rate = "Count breaths (15 s)",
	refill = "Press a fingertip",
}

local function seedOf(ctx: { [string]: any }): number
	local s = 0
	local id = tostring(ctx.operation.id)
		.. ":"
		.. tostring(ctx.casualty and ctx.casualty.index or 0)
	for i = 1, #id do
		s = (s * 17 + string.byte(id, i)) % 100003
	end
	return s
end

local triage = {}

function triage.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local bin = FerryUi.bin()
	local assist = ctx.isAssist == true
	local cas = ctx.casualty
	local state: string = if cas then cas.state else "Alert"
	local obs = Triage.observe(state, seedOf(ctx))
	local done: { string } = {}
	local countErr = 0
	local busy = false
	local finished = false

	local gui = bin.add(FerryUi.screen("FerryTriage"))
	local card =
		FerryUi.frame(gui, UDim2.fromOffset(560, 380), UDim2.new(0.5, -280, 1, -420), CARD, 0)
	FerryUi.corner(card, 12)
	FerryUi.stroke(card, Color3.fromRGB(200, 60, 40), 4)
	local head = `TRIAGE SIEVE · casualty {if cas then cas.index else "?"}`
	FerryUi.text(
		card,
		head,
		UDim2.new(1, -24, 0, 26),
		UDim2.fromOffset(12, 8),
		22,
		INK,
		FerryUi.Theme.HeaderFont
	)
	local cue =
		FerryUi.text(card, obs.cue, UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 36), 17, INK)
	cue.Font = FerryUi.Theme.BoldFont
	local log =
		FerryUi.text(card, "", UDim2.new(0.5, -18, 0, 190), UDim2.new(0.5, 6, 0, 86), 16, INK)

	local function note(line: string)
		log.Text = if log.Text == "" then line else log.Text .. "\n" .. line
	end

	-- the hint row (Assist): what the sieve says to check next
	local hint = FerryUi.text(
		card,
		"",
		UDim2.new(1, -24, 0, 20),
		UDim2.new(0, 12, 1, -100),
		15,
		Color3.fromRGB(90, 96, 104)
	)
	local function refreshHint()
		if not assist then
			return
		end
		local need = Triage.checksNeeded(obs)
		for _, c in need do
			if not table.find(done, c) then
				hint.Text = `Next on the sieve: {CHECK_LABELS[c]}`
				return
			end
		end
		hint.Text = "The sieve has decided: attach the band."
	end

	local function sound(id: string, v: number?)
		FerryUi.sound(id, if cas then cas.position else nil, v)
	end

	---------------------------------------------------------------- checks

	local function mark(c: string)
		if not table.find(done, c) then
			table.insert(done, c)
		end
		refreshHint()
	end

	local function doWalk()
		FerryUi.playAction("triage_walk_ask")
		if obs.walks then
			note("Walks: yes, steps across to the reception area.")
			FerryUi.subtitle(gui, '"Yes, I can walk. Help the others."')
		else
			note("Walks: no, can't get up.")
			FerryUi.subtitle(gui, "[They try to stand, then sink back down]")
		end
		mark("walk")
	end

	local function doAirway()
		FerryUi.playAction("triage_airway")
		if not obs.airwayOpened then
			note("Airway: head tilt, chin lift... chest rising.")
		else
			note("Breathing: yes, chest rising.")
		end
		mark("airway")
	end

	local function doResponsive()
		FerryUi.playAction("triage_shoulder_tap")
		local lines = {
			Alert = { "Responsive: alert, answers clearly.", "\"I'm here, I'm here.\"" },
			Voice = { "Responsive: answers to voice, slowly.", '"Mm... yes..."' },
			Pain = {
				"Responsive: no words, only stirs at the shoulder tap.",
				"[A small groan, eyes stay shut]",
			},
			Unresponsive = {
				"Responsive: no answer.",
				"[No answer. Breathing quietly in the lifejacket]",
			},
		}
		local l = lines[obs.avpu]
		note(l[1])
		FerryUi.subtitle(gui, l[2])
		mark("responsive")
	end

	-- 15 s of breathing at 3x speed: a chest ring swells on every breath, the medic taps on each.
	local function doRate()
		busy = true
		FerryUi.playAction("triage_count_breaths")
		local panel = FerryUi.frame(
			card,
			UDim2.fromOffset(250, 190),
			UDim2.fromOffset(12, 86),
			Color3.fromRGB(225, 232, 236),
			0
		)
		FerryUi.corner(panel, 10)
		FerryUi.text(
			panel,
			"Watch the chest. Tap SPACE (or the pad) on each rise.",
			UDim2.new(1, -16, 0, 40),
			UDim2.fromOffset(8, 6),
			15,
			INK
		)
		local chest = FerryUi.frame(
			panel,
			UDim2.fromOffset(60, 60),
			UDim2.new(0.5, -30, 0, 58),
			Color3.fromRGB(140, 170, 190),
			0
		)
		FerryUi.corner(chest, 999)
		local clock =
			FerryUi.text(panel, "0 s", UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 1, -48), 16, INK)
		local tally =
			FerryUi.text(panel, "", UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 1, -26), 16, INK)
		local taps = 0
		local function tap()
			taps += 1
			if assist then
				tally.Text = `Counted {taps}`
			end
		end
		local pad = FerryUi.button(
			panel,
			"Rise",
			UDim2.fromOffset(90, 40),
			UDim2.new(1, -98, 0, 70),
			C.panelLight,
			tap
		)
		local conn = FerryUi.keys({ [Enum.KeyCode.Space] = tap, [Enum.KeyCode.ButtonA] = tap })
		local speed = 3
		local rises = Triage.risesIn15(obs.rate)
		local period = 15 / rises
		local t, nextRise = 0, period * 0.5
		local hb: RBXScriptConnection
		hb = RunService.Heartbeat:Connect(function(dt: number)
			t += dt * speed
			clock.Text = `{math.floor(t)} s`
			if t >= nextRise then
				nextRise += period
				sound(FerryUi.Sounds.breathIn, 0.4)
				TweenService:Create(
					chest,
					TweenInfo.new(
						0.25 / speed * 3,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.Out,
						0,
						true
					),
					{
						Size = UDim2.fromOffset(84, 84),
						Position = UDim2.new(0.5, -42, 0, 46),
					}
				):Play()
			end
			if t >= 15 then
				hb:Disconnect()
				conn:Disconnect()
				local est = Triage.estimateRate(taps)
				countErr = Triage.countError(obs.rate, est)
				note(`Breathing rate: {taps} in 15 s, about {est} a minute.`)
				pad:Destroy()
				panel:Destroy()
				busy = false
				mark("rate")
			end
		end)
		bin.add(hb)
		bin.add(conn)
	end

	-- press the fingertip white for a moment, release, watch the pink come back
	local function doRefill()
		busy = true
		FerryUi.playAction("triage_cap_refill")
		local panel = FerryUi.frame(
			card,
			UDim2.fromOffset(250, 190),
			UDim2.fromOffset(12, 86),
			Color3.fromRGB(225, 232, 236),
			0
		)
		FerryUi.corner(panel, 10)
		FerryUi.text(
			panel,
			"Pressing the nail bed... release and count.",
			UDim2.new(1, -16, 0, 40),
			UDim2.fromOffset(8, 6),
			15,
			INK
		)
		local nail = FerryUi.frame(
			panel,
			UDim2.fromOffset(44, 56),
			UDim2.new(0.5, -22, 0, 56),
			Color3.fromRGB(250, 248, 246),
			0
		)
		FerryUi.corner(nail, 18)
		local timer =
			FerryUi.text(panel, "", UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 1, -30), 16, INK)
		local pink = Color3.fromRGB(228, 140, 140)
		task.delay(0.9, function()
			if not panel.Parent then
				return
			end
			TweenService:Create(
				nail,
				TweenInfo.new(obs.refill, Enum.EasingStyle.Linear),
				{ BackgroundColor3 = pink }
			):Play()
			local t0 = os.clock()
			while panel.Parent and os.clock() - t0 < obs.refill + 0.4 do
				if assist then
					timer.Text = string.format("%.1f s", math.min(os.clock() - t0, obs.refill))
				end
				task.wait(0.05)
			end
			if not panel.Parent then
				return
			end
			local word = if obs.refill > Triage.RefillLimit
				then "slow, over 2 seconds"
				else "quick, under 2 seconds"
			note(`Capillary refill: {word}.`)
			panel:Destroy()
			busy = false
			mark("refill")
		end)
		bin.add(panel)
	end

	local actions: { [string]: () -> () } = {
		walk = doWalk,
		airway = doAirway,
		responsive = doResponsive,
		rate = doRate,
		refill = doRefill,
	}

	---------------------------------------------------------------- tags

	local function attach(tag: string)
		if finished or busy then
			return
		end
		finished = true
		FerryUi.playAction("triage_attach_band")
		sound(FerryUi.Sounds.tagSnap, 0.7)
		local d = (Triage.Display :: any)[tag]
		FerryUi.subtitle(gui, `Band on: {d.name}.`, 2)
		card.BackgroundColor3 = d.colour:Lerp(CARD, 0.6)
		task.delay(0.6, function()
			bin.clean()
			finish({
				metrics = {
					tag = tag,
					checks = #done,
					orderFollowed = Triage.orderFollowed(done),
					countError = countErr,
				},
			})
		end)
	end

	for i, c in Triage.Checks do
		FerryUi.button(
			card,
			`{i}  {CHECK_LABELS[c]}`,
			UDim2.fromOffset(250, 34),
			UDim2.fromOffset(12, 86 + (i - 1) * 38),
			C.panelLight,
			function()
				if not busy and not finished then
					actions[c]()
				end
			end
		)
	end
	local tagKeys = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C }
	local tagPads = { Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB }
	local keymap: { [Enum.KeyCode]: () -> () } = {}
	for i, tag in Triage.Tags do
		local d = (Triage.Display :: any)[tag]
		local b = FerryUi.button(
			card,
			`{string.char(string.byte("ZXC", i))}  {d.name}`,
			UDim2.new(1 / 3, -12, 0, 46),
			UDim2.new((i - 1) / 3, 8, 1, -56),
			d.colour,
			function()
				attach(tag)
			end
		)
		b.TextColor3 = if tag == "Yellow" then INK else Color3.new(1, 1, 1)
		keymap[tagKeys[i]] = function()
			attach(tag)
		end
		keymap[tagPads[i]] = keymap[tagKeys[i]]
	end
	for i, c in Triage.Checks do
		keymap[FerryUi.NumberKeys[i]] = function()
			if not busy and not finished then
				actions[c]()
			end
		end
	end
	bin.add(FerryUi.keys(keymap))
	refreshHint()
	if cas then
		FerryUi.ripple(cas.position, 0.5, Color3.fromRGB(255, 200, 120))
	end

	-- smoke runs: play the sieve by the book
	if game:GetService("Players").LocalPlayer:GetAttribute("OpsAutoStub") == true then
		task.delay(1, function()
			attach(Triage.sieve(obs))
		end)
	end

	return function()
		finished = true
		bin.clean()
	end
end

return triage
