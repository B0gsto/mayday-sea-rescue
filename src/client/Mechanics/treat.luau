--!strict
-- treat (docs 09 step 8, section 5.6): the kit is physical (docs 14 section 2: no choice UI). An
-- open kit box sits beside the casualty with everything the crew carries: foil blanket, wool hat,
-- oxygen mask, dressing, warm flask. Grab one (look at it, E / X / click, or tap it) and put it on
-- the body where it fits what the survey showed (the blanket on the shivering body, the dressing
-- on the graze, the mask or the hat on the head, the flask to the lips). A wrong item just won't
-- stick: it drops back in the box. Shelter, lying flat and the recovery position are your hands:
-- hold on the body. Any order. After 10 s with nothing done the crew does the next one.
-- When the survey found "Not breathing normally", CPR comes first: 5 rescue breaths, then 30:2
-- (adult) or 15:2 (child) to a 110 a minute beat, all on the body (runCpr below).
-- Metric: matches = share of the plan the player did (CPR quality scales it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AudioConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AudioConfig")
)
local Care = require(script.Parent.PIW.Care)
local CasualtyCare = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("CasualtyCare")
)
local Medical = require(script.Parent.PIW.Medical)
local Record = require(script.Parent.PIW.Record)
local Rhythm = require(script.Parent.PIW.Rhythm)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Treat = {}

Treat.PER_HANDS = 1.5 -- s of holding on the body per hands-on step
Treat.IDLE = 10 -- s with nothing done before the crew does the next one
Treat.CREW_GAP = 1.5 -- s between the crew's steps

-- first-person arm clip per plan step (ViewmodelActions names)
local CLIPS: { [string]: string } = { casualtyBag = "wrap_blanket", cpr = "cpr" }

type Look = { size: Vector3, colour: Color3, material: Enum.Material, shape: Enum.PartType? }

-- how each item looks in the box, and on the body (area, size, offset in the area's frame)
local LOOKS: { [string]: Look } = {
	casualtyBag = {
		size = Vector3.new(1, 0.3, 0.7),
		colour = Color3.fromRGB(226, 186, 92),
		material = Enum.Material.Foil,
	},
	hat = {
		size = Vector3.new(0.9, 0.6, 0.9),
		colour = Color3.fromRGB(40, 52, 96),
		material = Enum.Material.Fabric,
		shape = Enum.PartType.Ball,
	},
	oxygen = {
		size = Vector3.new(0.6, 0.5, 0.35),
		colour = Color3.fromRGB(120, 200, 140),
		material = Enum.Material.Glass,
	},
	dressing = {
		size = Vector3.new(0.7, 0.15, 0.5),
		colour = Color3.fromRGB(245, 245, 240),
		material = Enum.Material.Fabric,
	},
	drink = {
		size = Vector3.new(0.9, 0.4, 0.4),
		colour = Color3.fromRGB(190, 196, 204),
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
	},
}
local ON: { [string]: { area: string, size: Vector3?, offset: CFrame } } = {
	casualtyBag = {
		area = "chest",
		size = Vector3.new(2.8, 4.8, 0.2),
		offset = CFrame.new(0, -1.3, -0.7),
	},
	hat = { area = "head", size = Vector3.new(1.25, 0.7, 1.25), offset = CFrame.new(0, 0.45, 0) },
	oxygen = { area = "head", offset = CFrame.new(0, -0.2, -0.6) },
	dressing = { area = "arm", size = Vector3.new(0.6, 0.8, 0.1), offset = CFrame.new(0, 0, -0.36) },
	drink = {
		area = "head",
		offset = CFrame.new(0, -0.3, -0.8) * CFrame.Angles(0, 0, math.rad(90)),
	},
}
local AREAS = { "head", "chest", "arm", "body" }
local BEAT = Color3.fromRGB(255, 244, 214) -- the ring on the chest
local BREATH = Color3.fromRGB(120, 190, 255) -- the ring at the mouth

-- CPR as world actions (no panel): hold at the chest to kneel, push on the beat ring as it pulses
-- (the chest dips, a soft tick on every beat), and when the ring moves to the mouth, hold there
-- for each breath. Off-beat pushes still count, slower; nothing resets. Calls done(quality 0..1).
local function runCpr(s: Step.S, body: Care.Body, ageBand: string, done: (number) -> ())
	local plan = Rhythm.cprPlan(ageBand)
	local cbag = Ui.bag()
	Ui.add(s.bag, function()
		Ui.clean(cbag)
	end)
	local c = CasualtyCare.cpr(Rhythm.cprSequence(plan))
	local interval = 60 / plan.bpm
	local window = if s.assist then 0.16 else 0.1
	local press = Care.chest(cbag, body)
	local ring = Ui.add(
		cbag,
		Care.part(
			body,
			Vector3.new(0.08, 1.3, 1.3),
			BEAT,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
	)
	local tick = Instance.new("Sound")
	tick.SoundId = AudioConfig.Clips.UI_Prompt.id
	tick.Volume = 0.25
	tick.Parent = ring
	local kneeled, hold, t0, lastBeat = false, 0, os.clock(), -1
	local finished = false
	local function finishCpr()
		if finished then
			return
		end
		finished = true
		Ui.clean(cbag)
		done(Rhythm.cprQuality(c.onBeat, c.compressions, c.breathsRight, c.breaths))
	end
	local function area(): string
		return if kneeled and CasualtyCare.cprWants(c) == "B" then "head" else "chest"
	end
	local picker: Care.Picker
	local function target()
		picker.clear()
		picker.fill(nil)
		if CasualtyCare.cprWants(c) == nil then
			finishCpr()
			return
		end
		local a = area()
		picker.set("@" .. a, function()
			return body.at(a)
		end, 1.2)
	end
	picker = Care.picker(cbag, body.folder, function(id: string)
		if not kneeled or id ~= "@chest" then
			return
		end
		local good = Rhythm.beatError(os.clock(), t0, interval) <= window
		if CasualtyCare.cprPush(c, good) then
			press(if good then 0.35 else 0.15)
			Ui.hands("cpr_compress")
			if CasualtyCare.cprWants(c) ~= "C" then
				target()
			end
		end
	end)
	Step.heartbeat(s, function(dt)
		if finished then
			return
		end
		local a = area()
		local pushing = kneeled and CasualtyCare.cprWants(c) == "C"
		local beats = math.floor((os.clock() - t0) / interval)
		local onBeat = pushing and (os.clock() - t0) / interval - beats < 0.18
		if pushing and beats ~= lastBeat then
			lastBeat = beats
			tick:Play()
		end
		local d = if onBeat then 1.7 else 1.3
		ring.Size = Vector3.new(0.08, d, d)
		ring.Color = if a == "head" then BREATH else BEAT
		ring.Transparency = if onBeat or a == "head" then 0.15 else 0.6
		ring.CFrame = body.cf(a)
			* (if a == "head" then CFrame.new(0, -0.25, -0.75) else CFrame.new(0, 0, -0.6))
			* CFrame.Angles(0, math.rad(90), 0)
		if pushing then
			picker.fill(CasualtyCare.cprCycle(c))
		elseif picker.down() and picker.aimed() == "@" .. a then
			-- letting go pauses the hold, it never resets
			hold += dt / (if kneeled then CasualtyCare.CPR_BREATH else CasualtyCare.CPR_KNEEL)
			picker.fill(hold)
			if hold >= 1 then
				hold = 0
				if not kneeled then
					kneeled = true
					Ui.hands("cpr", { loop = true })
				else
					CasualtyCare.cprBreath(c)
					Ui.hands("cpr_breath")
					press(-0.25)
					if CasualtyCare.cprWants(c) == "C" then
						t0 = os.clock() -- the metronome restarts after the breaths
					end
				end
				target()
			end
		end
	end)
	Ui.add(s.bag, task.delay(80, finishCpr))
	target()
end

function Treat.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "Treat", 96, true)
	if Step.autoStub(s, { matches = 1 }) then
		return Step.cleanup(s)
	end
	s.panel.Visible = false
	local e = Record.get(ctx.operation.id)
	local profile = Record.profile(ctx)
	local carried: { [string]: boolean } = {}
	for _, t in Medical.Treatments do
		if t.needs then
			carried[t.needs] = Record.carried(ctx.operation.id, t.needs)
		end
	end
	local plan = Medical.treatmentPlan(profile, carried)
	-- CPR only when the survey found "Not breathing normally"; it runs as its own rhythm first
	local cpr = plan[1] == "cpr" and e.findings.Breathing == 4
	if plan[1] == "cpr" then
		table.remove(plan, 1)
	end
	local body = Care.body(ctx, s.bag)

	-- what the survey found stays on the body (the crew's findings when nobody surveyed)
	local answers: { [string]: number } = table.clone(e.findings)
	if next(answers) == nil then
		local jet = World.isJetSki(World.vehicle(ctx))
		for _, c in Medical.surveyCards(profile, jet, ctx.operation.storm == true) do
			answers[c.letter] = c.answer
		end
	end
	local clears: { [string]: () -> () } = {}
	for letter, a in answers do
		clears[letter] = Care.finding(s.bag, body, letter, a, nil)
	end

	-- the open kit box beside them, on your side
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart")
		then root.Position
		else World.camera().CFrame.Position
	local chest = body.at("chest")
	local toward = Units.unitOr(from - chest, Vector3.xAxis)
	local side = toward:Cross(Vector3.yAxis)
	local boxAt = chest + toward * 2.6 + side * 1.6 - Vector3.new(0, 1, 0)
	local boxCf = CFrame.lookAt(boxAt, boxAt + side)
	local box = Care.part(body, Vector3.new(3.4, 0.8, 1.6), Color3.fromRGB(200, 70, 30))
	box.CFrame = boxCf
	local tray = CasualtyCare.tray(carried, plan)
	local items: { [string]: Part } = {}
	local slots: { [string]: CFrame } = {}
	for i, id in tray do
		local look = LOOKS[id]
		local p = Care.part(body, look.size, look.colour, look.material, look.shape)
		slots[id] = boxCf * CFrame.new((i - (#tray + 1) / 2) * 0.68, 0.6, 0)
		p.CFrame = slots[id]
		items[id] = p
	end

	local applied: { string } = if cpr then { "cpr" } else {}
	local mine = 0
	local carrying: string? = nil
	local last = os.clock()
	local progress = 0
	local cprQuality = 1
	local ready = false
	local picker: Care.Picker

	local function refresh()
		if s.finished then
			return
		end
		picker.clear()
		if carrying then
			for _, a in AREAS do
				picker.set("@" .. a, function()
					return body.at(a)
				end)
			end
			picker.set("box", function()
				return box.Position + Vector3.new(0, 0.6, 0)
			end, 1.2)
		else
			for id, p in items do
				if not table.find(applied, id) then
					picker.set(id, function()
						return p.Position
					end, 0.9)
				end
			end
			if CasualtyCare.nextHands(plan, applied) then
				picker.set("@body", function()
					return body.at("body")
				end, 1.2)
			end
		end
	end

	local function apply(id: string, byPlayer: boolean)
		table.insert(applied, id)
		mine += if byPlayer then 1 else 0
		last = os.clock()
		Ui.hands(CLIPS[id] or "treat_" .. id)
		local p, on = items[id], ON[id]
		if p and on then
			if on.size then
				p.Size = on.size
			end
			Care.stick(s.bag, body, p, on.area, on.offset)
		elseif id == "shelter" then -- a spray screen on the weather side
			local screen = Care.part(body, Vector3.new(4.5, 2.6, 0.15), Color3.fromRGB(90, 96, 104))
			screen.CFrame = CFrame.lookAt(chest - toward * 2.2, chest) * CFrame.new(0, 0.4, 0)
		end
		if id == "casualtyBag" and clears.Disability then
			clears.Disability() -- wrapped up: the shivering stops
		elseif id == "dressing" and answers.Circulation == 3 then
			clears.Circulation()
		elseif id == "drink" and p then
			Ui.add(
				s.bag,
				task.delay(1.2, function()
					p:Destroy()
				end)
			)
		end
		if #CasualtyCare.remaining(plan, applied) == 0 then
			e.applied = applied
			local share = if #plan > 0 then mine / #plan else 1
			local matches = share * (if cpr then 0.5 + 0.5 * cprQuality else 1)
			Step.finish(s, { metrics = { matches = math.floor(matches * 100 + 0.5) / 100 } })
		elseif carrying == nil then
			refresh()
		end
	end

	local function putBack(id: string)
		local p = items[id]
		if p then
			TweenService
				:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = slots[id] })
				:Play()
		end
	end

	picker = Care.picker(s.bag, body.folder, function(id: string)
		if not ready then
			return
		end
		local held = carrying
		if held == nil then
			if items[id] then
				carrying = id
				Ui.hands("grab")
				last = os.clock()
				refresh()
			end
		elseif id == "box" then
			carrying = nil
			putBack(held)
			refresh()
		elseif string.sub(id, 1, 1) == "@" then
			carrying = nil
			if CasualtyCare.fits(held, string.sub(id, 2), plan, applied) then
				apply(held, true)
			else
				putBack(held) -- it doesn't stick
			end
			refresh()
		end
	end)

	Step.heartbeat(s, function(dt)
		if not ready then
			return
		end
		local held = carrying
		if held then
			items[held].CFrame = World.camera().CFrame * CFrame.new(0.9, -0.8, -2.4)
			last = os.clock()
			return
		end
		local hands = CasualtyCare.nextHands(plan, applied)
		if hands and picker.down() and picker.aimed() == "@body" then
			progress += dt / Treat.PER_HANDS
			picker.fill(progress)
			last = os.clock()
			if progress >= 1 then
				progress = 0
				picker.fill(nil)
				apply(hands, true)
			end
			return
		end
		progress = 0
		picker.fill(nil)
		if os.clock() - last > Treat.IDLE then
			-- the crew does the next one, then the next, briskly
			local id = CasualtyCare.remaining(plan, applied)[1]
			if id then
				apply(id, false)
				last = os.clock() - Treat.IDLE + Treat.CREW_GAP
			end
		end
	end)

	local function begin()
		ready = true
		last = os.clock()
		if #plan == 0 then
			e.applied = applied
			Step.finish(s, { metrics = { matches = if cpr then 0.5 + 0.5 * cprQuality else 1 } })
			return
		end
		refresh()
	end

	if cpr then
		runCpr(s, body, profile.ageBand, function(q)
			cprQuality = q
			Ui.handsStop()
			s.say(if q >= 0.6 then "They cough... they're breathing!" else "Keep going", 3)
			begin()
		end)
	else
		begin()
	end
	return Step.cleanup(s)
end

return Treat
