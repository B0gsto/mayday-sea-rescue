--!strict
-- PIW/Recovery: getting the casualty aboard (docs 09 step 6, section 5.3). Read the casualty,
-- pick the method, then play it:
--   Throw bag (alert, can grip): aim with the wind in mind, hold to charge, release; the bag
--     flies by projectile physics; then haul hand over hand to a steady rhythm.
--   Swimmer (panicking, exhausted): swim out, contact from behind with the tube, tow back.
--   Horizontal lift (very cold, not responding): alongside and parallel, two crew lift flat
--     together; keep the level bar in its band through the lift.
-- Alert and tired casualties finish with the two-person pull aboard on "one, two, three".
-- Result: metrics.method (the first method chosen: "right method first time"), score (0..1);
-- events.wrongHandling when a cold casualty is hauled upright over the sponson.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Record = require(script.Parent.Record)
local Rhythm = require(script.Parent.Rhythm)
local Step = require(script.Parent.Step)
local Swimmer = require(script.Parent.Swimmer)
local Throw = require(script.Parent.Throw)
local Ui = require(script.Parent.Ui)
local Units = require(script.Parent.Units)
local World = require(script.Parent.World)

local Recovery = {}

Recovery.BOOK = {
	Alert = "throwbag",
	Panicking = "swimmer",
	Exhausted = "swimmer",
	VeryCold = "horizontal",
	Unresponsive = "horizontal",
}
Recovery.METHODS = { "throwbag", "swimmer", "horizontal" }
Recovery.LABELS = { "Throw bag", "Swimmer with a tube", "Horizontal lift" }
Recovery.MAX_THROWS = 4

local CUES = {
	Alert = "Waving both arms, calling out. Gripping the lifejacket straps.",
	Panicking = "Splashing, climbing at the water, head back.",
	Exhausted = "Low in the water, mouth near the surface, arms still.",
	VeryCold = 'Not shivering, slow speech: "m-m-my hands..."',
	Unresponsive = "Face up in the lifejacket, eyes closed, no answer.",
}

-- "One, two, three!": press Action on three. Returns timing 0..1 through done.
local function pullAboard(s: Step.S, done: (number) -> ())
	local bag = Ui.bag()
	Ui.add(s.bag, function()
		Ui.clean(bag)
	end)
	local beat = 0.75
	local window = if s.assist then 0.225 else 0.15
	local t0 = os.clock() + 0.6
	local pressed = false
	Ui.hands("grip_sponson")
	local function press()
		if pressed then
			return
		end
		local err = math.abs(os.clock() - (t0 + beat * 2))
		if os.clock() < t0 then
			return
		end
		pressed = true
		local q = if err <= window then 1 else math.clamp(1 - (err - window) / 0.45, 0, 1)
		Ui.hands("lift_aboard")
		s.say(
			if q >= 1
				then "Together! Aboard."
				elseif q > 0.3 then "A bit off, but aboard."
				else "Out of time: a heavy, clumsy lift.",
			2
		)
		Ui.clean(bag)
		done(q)
	end
	Ui.action(bag, s.gui, "Lift", press, function() end)
	local said = 0
	Ui.add(
		bag,
		RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			local n = math.floor(t / beat) + 1
			if t >= 0 and n > said and n <= 3 then
				said = n
				s.say(({ '"One..."', '"Two..."', '"THREE!"' })[n], 0.7)
			end
			if t > beat * 2 + 1 and not pressed then
				pressed = true
				s.say("The crewmate lifts alone: a heavy lift.", 2)
				Ui.clean(bag)
				done(0)
			end
		end)
	)
end

-- Two-hand rhythm over a distance (haul or tow). done(evenness, dips).
local function rhythmDistance(
	s: Step.S,
	title: string,
	distance: number,
	target: number,
	perPull: number,
	dipsOnFast: boolean,
	done: (number, number) -> ()
)
	local bag = Ui.bag()
	Ui.add(s.bag, function()
		Ui.clean(bag)
	end)
	local r = Rhythm.new(target, if s.assist then 0.5 else 0.35, true)
	local d = distance
	local dips = 0
	local lastTap = os.clock()
	local frame = Ui.panel(s.gui, UDim2.fromOffset(420, 84), UDim2.new(0.5, 0, 1, -24))
	Ui.add(bag, frame)
	Ui.text(frame, title, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 8), 18, true)
	local line = Ui.text(frame, "", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 34), 16)
	local hint = Ui.hint(frame, "Left, right, left... steady, not fast.", s.assist)
	hint.Position = UDim2.fromOffset(12, 58)
	local finished = false
	Ui.pads(bag, s.gui, function(hand)
		if finished then
			return
		end
		local res = Rhythm.tap(r, hand, os.clock())
		lastTap = os.clock()
		if res == "good" or res == "first" then
			d -= perPull
		elseif res == "fast" then
			d -= perPull * 0.6
			if dipsOnFast then
				dips += 1
				s.say("Too fast! Their face is going under.", 1.5)
			end
		elseif res == "slow" then
			d -= perPull * 0.8
		end
		Ui.hands(if hand == "L" then "haul_left" else "haul_right")
		if d <= 3 then
			finished = true
			Ui.clean(bag)
			done(Rhythm.evenness(r), dips)
		end
	end)
	Ui.add(
		bag,
		RunService.Heartbeat:Connect(function(dt)
			if os.clock() - lastTap > 1.4 then
				d = math.min(distance + 10, d + 0.8 * dt) -- they drift off while you wait
			end
			line.Text = string.format("%.0f m to go", math.max(0, d) / Units.STUDS_PER_M)
		end)
	)
end

-- The level bar through a two-person horizontal lift. done(fraction in band).
local function horizontalLift(s: Step.S, vehicle: Model?, done: (number) -> ())
	local bag = Ui.bag()
	Ui.add(s.bag, function()
		Ui.clean(bag)
	end)
	local frame = Ui.panel(s.gui, UDim2.fromOffset(460, 110), UDim2.new(0.5, 0, 1, -24))
	Ui.add(bag, frame)
	Ui.text(
		frame,
		"Horizontal lift: shoulders and knees, keep them flat",
		UDim2.new(1, -24, 0, 22),
		UDim2.fromOffset(12, 8),
		17,
		true
	)
	local setLevel = Ui.meter(frame, "Level (keep in the band)", UDim2.fromOffset(12, 36), 436)
	local setProgress = Ui.meter(frame, "Lift (hold Action)", UDim2.fromOffset(12, 70), 436)
	local band = if s.assist then 0.16 else 0.12
	local tilt, progress, inBand, total = 0, 0, 0, 0
	local holding = false
	local input = 0
	local keys = { a = false, d = false }
	local t = 0
	Ui.hands("lift_horizontal")
	Ui.action(bag, s.gui, "Lift", function()
		holding = true
	end, function()
		holding = false
	end)
	Ui.bind(bag, "LevelKeys", function(state, i)
		if i.KeyCode == Enum.KeyCode.Thumbstick1 then
			input = i.Position.X
			return
		end
		local on = state ~= "End"
		if i.KeyCode == Enum.KeyCode.A then
			keys.a = on
		elseif i.KeyCode == Enum.KeyCode.D then
			keys.d = on
		end
	end, Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.Thumbstick1)
	Ui.add(
		bag,
		UserInputService.TouchMoved:Connect(function(i: InputObject)
			input = math.clamp(i.Delta.X / 12, -1, 1)
		end)
	)
	Ui.add(
		bag,
		RunService.Heartbeat:Connect(function(dt)
			t += dt
			local h = World.hull(vehicle)
			local roll = if h then h.cframe.RightVector.Y else 0
			local disturb = roll * 1.6 + math.sin(t * 1.9) * 0.22 + math.sin(t * 3.7 + 1) * 0.12
			local correction = input + (if keys.d then 1 else 0) - (if keys.a then 1 else 0)
			input *= 0.85 -- touch drags decay
			if holding then
				tilt = math.clamp(tilt + (disturb - correction * 0.9) * dt, -0.5, 0.5)
				progress = math.min(1, progress + dt / 4)
				total += dt
				if math.abs(tilt) <= band then
					inBand += dt
				end
			end
			setLevel(0.5 + tilt, 0.5 - band, 0.5 + band)
			setProgress(progress)
			if progress >= 1 then
				Ui.clean(bag)
				s.say("Flat on the deck. Gently does it.", 2)
				done(if total > 0 then inBand / total else 0)
			end
		end)
	)
end

-- The throw bag: aim, charge, fly, judge; then haul. done(score, ok) (ok false: they could not hold).
local function throwBag(
	s: Step.S,
	ctx: { [string]: any },
	victim: Model?,
	canGrip: boolean,
	done: (number, boolean) -> ()
)
	local bag = Ui.bag()
	Ui.add(s.bag, function()
		Ui.clean(bag)
	end)
	local wind = ctx.scene and ctx.scene.windDirection or 0
	local windAccel = Units.windVector(wind)
		* (Throw.WIND_ACCEL * (if ctx.operation.storm then 2 else 1))
	local throws, headHits = 0, 0
	local chargeStart: number? = nil
	local flying = false
	local recoilUntil = 0
	local arc: { Part } = {}
	local frame = Ui.panel(s.gui, UDim2.fromOffset(420, 96), UDim2.new(0.5, 0, 1, -24))
	Ui.add(bag, frame)
	Ui.text(
		frame,
		"Throw bag: beyond them and upwind, never at their head",
		UDim2.new(1, -24, 0, 22),
		UDim2.fromOffset(12, 8),
		16,
		true
	)
	local status = Ui.text(
		frame,
		"Look past them, hold to wind up, release.",
		UDim2.new(1, -24, 0, 20),
		UDim2.fromOffset(12, 34),
		15
	)
	local setPower = Ui.meter(frame, "Power", UDim2.fromOffset(12, 56), 396)
	Ui.hands("hold_throwbag")

	local function origin(): Vector3
		local cf = World.camera().CFrame
		return cf.Position + cf.LookVector * 1 + Vector3.new(0, -0.7, 0)
	end
	local function clearArc()
		for _, p in arc do
			p:Destroy()
		end
		table.clear(arc)
	end
	local function previewArc(power: number)
		clearArc()
		if not s.assist then
			return
		end
		local o = origin()
		local v = Throw.velocity(World.camera().CFrame.LookVector, power)
		local waterY = World.casualtyPos(ctx, victim).Y
		local _, tEnd = Throw.land(o, v, waterY, Workspace.Gravity, windAccel)
		for _, p in Throw.arc(o, v, Workspace.Gravity, windAccel, tEnd, 10) do
			local dot = Instance.new("Part")
			dot.Shape = Enum.PartType.Ball
			dot.Size = Vector3.new(0.18, 0.18, 0.18)
			dot.Position = p
			dot.Color = Color3.fromRGB(240, 240, 235)
			dot.Transparency = 0.5
			dot.Anchored, dot.CanCollide, dot.CanQuery, dot.CastShadow = true, false, false, false
			dot.Parent = World.camera()
			table.insert(arc, dot)
			Ui.add(bag, dot)
		end
	end

	local function release()
		if chargeStart == nil or flying then
			return
		end
		local power = Throw.charge(os.clock() - chargeStart)
		chargeStart = nil
		clearArc()
		flying = true
		throws += 1
		Ui.hands("throw_underarm")
		local o = origin()
		local v = Throw.velocity(World.camera().CFrame.LookVector, power)
		local cas = World.casualtyPos(ctx, victim)
		local landing, tFlight = Throw.land(o, v, cas.Y, Workspace.Gravity, windAccel)
		-- the bag and its line, local only
		local bagPart = Instance.new("Part")
		bagPart.Size = Vector3.new(0.8, 1.1, 0.8)
		bagPart.Color = Color3.fromRGB(200, 30, 30)
		bagPart.Material = Enum.Material.Fabric
		bagPart.Anchored, bagPart.CanCollide, bagPart.CanQuery = true, false, false
		bagPart.Parent = Workspace
		Ui.add(bag, bagPart)
		local linePart = Instance.new("Part")
		linePart.Color = Color3.fromRGB(255, 220, 40) -- floating polypropylene line, yellow
		linePart.Material = Enum.Material.SmoothPlastic
		linePart.Anchored, linePart.CanCollide, linePart.CanQuery = true, false, false
		linePart.Parent = Workspace
		Ui.add(bag, linePart)
		local t = 0
		local conn: RBXScriptConnection? = nil
		conn = RunService.Heartbeat:Connect(function(dt)
			t = math.min(t + dt, tFlight)
			local p = o
				+ v * t
				+ Units.flat(windAccel) * (0.5 * t * t)
				- Vector3.new(0, 0.5 * Workspace.Gravity * t * t, 0)
			if t >= tFlight then
				p = landing
			end
			bagPart.Position = p
			local len = (p - o).Magnitude
			linePart.Size = Vector3.new(0.08, 0.08, math.max(0.1, len))
			linePart.CFrame = CFrame.lookAt((o + p) / 2, p)
			if t >= tFlight and conn then
				conn:Disconnect()
				local a = Throw.assess(o, landing, cas, wind)
				flying = false
				if a.result == "over" then
					if not canGrip then
						s.say("Line's over them, but they can't hold it. Swimmer in!", 3)
						Ui.clean(bag)
						done(0.2, false)
						return
					end
					s.say('Line over them! "Grab the line!" They\'ve got it.', 2.5)
					Ui.hands("take_line")
					local ts = Throw.throwScore(throws, headHits)
					local dist = Units.flatDistance(o, cas)
					Ui.clean(bag)
					rhythmDistance(
						s,
						"Haul hand over hand",
						dist,
						0.6,
						Throw.HAUL_PULL,
						true,
						function(evenness, dips)
							done(Throw.recoveryScore(ts, evenness, dips), true)
						end
					)
					return
				end
				if a.result == "head" then
					headHits += 1
				end
				s.say(({
					head = "Not at their head! Beyond them.",
					short = "Short. Recoil and throw again.",
					downwind = "Downwind of them: the line drifts away.",
					wide = "Wide. Recoil and throw again.",
				} :: { [string]: string })[a.result] or "Missed.", 2.5)
				if throws >= Recovery.MAX_THROWS then
					Ui.clean(bag)
					done(0.1, false)
					return
				end
				recoilUntil = os.clock() + 2.5
				status.Text = "Recoiling the line..."
				Ui.hands("coil_line")
				task.delay(2.5, function()
					bagPart:Destroy()
					linePart:Destroy()
					if status.Parent then
						status.Text = `Throw {throws + 1}: look past them, hold, release.`
					end
				end)
			end
		end)
		Ui.add(bag, conn)
	end

	Ui.action(bag, s.gui, "Throw", function()
		if flying or os.clock() < recoilUntil then
			return
		end
		chargeStart = os.clock()
		Ui.hands("windup_throw")
	end, release)
	Ui.add(
		bag,
		RunService.Heartbeat:Connect(function()
			if chargeStart then
				local power = Throw.charge(os.clock() - chargeStart)
				setPower(power)
				previewArc(power)
			end
		end)
	)
end

-- Runs the whole recovery and calls finish.
function Recovery.run(s: Step.S, ctx: { [string]: any })
	local state = ctx.casualty and ctx.casualty.state or "Alert"
	local victim = World.victim(ctx)
	local vehicle = World.vehicle(ctx)
	local cold = state == "VeryCold" or state == "Unresponsive"
	local wrongHandling = 0
	local first: string? = nil
	local seed = Units.hash01(tostring(ctx.casualty and ctx.casualty.id or ctx.operation.id), 9)

	local function finishWith(score: number)
		local e = Record.get(ctx.operation.id)
		e.method = first
		Step.finish(s, {
			metrics = {
				method = first,
				score = math.floor(math.clamp(score, 0, 1) * 100 + 0.5) / 100,
			},
			events = if wrongHandling > 0 then { wrongHandling = wrongHandling } else nil,
		})
	end

	local runMethod: (string, number) -> ()
	local function swimmerPath(penalty: number)
		Ui.hands("swimmer_entry")
		s.say("Swimmer in the water!", 2)
		local startPanic = if state == "Panicking"
			then (if Record.get(ctx.operation.id).calmed then 25 else 90)
			elseif state == "Exhausted" then 30
			else 15
		Swimmer.contact(s, victim, startPanic, seed, function(res)
			local contact = math.clamp(1 - (res.seconds - 10) / 30, 0, 1) * 0.5
				+ (if res.fromBehind then 0.35 else 0.15)
				+ 0.15
				- 0.25 * res.grabs
			local h = World.hull(vehicle)
			local dist = if h
				then math.max(8, Units.flatDistance(h.position, World.casualtyPos(ctx, victim)))
				else 18
			rhythmDistance(
				s,
				"Tow them back: steady strokes",
				dist,
				0.7,
				1.8,
				false,
				function(evenness)
					if cold then
						-- hauled upright over the sponson by the arms: afterdrop risk
						wrongHandling = 1
						s.say('Medic: "Not upright! Keep them flat!"', 2.5)
					end
					pullAboard(s, function(q)
						finishWith(
							(0.4 * math.clamp(contact, 0, 1) + 0.3 * evenness + 0.3 * q) - penalty
						)
					end)
				end
			)
		end)
	end

	runMethod = function(method: string, penalty: number)
		if method == "throwbag" then
			throwBag(s, ctx, victim, state == "Alert", function(score, ok)
				if ok then
					pullAboard(s, function(q)
						finishWith(score * (0.8 + 0.2 * q) - penalty)
					end)
				else
					swimmerPath(penalty + 0.3)
				end
			end)
		elseif method == "swimmer" then
			swimmerPath(penalty)
		else
			-- horizontal lift: the swimmer brings them alongside, parallel to the boat, first
			local h = World.hull(vehicle)
			local dist = if h
				then Units.flatDistance(h.position, World.casualtyPos(ctx, victim)) - h.beam / 2
				else 4
			local function lift(towEven: number?)
				horizontalLift(s, vehicle, function(level)
					local score = if towEven then 0.25 * towEven + 0.75 * level else level
					if state == "Alert" or state == "Panicking" then
						score *= 0.8 -- a slow lift for someone who could have climbed the line
					end
					finishWith(score - penalty)
				end)
			end
			if dist > 6 then
				Ui.hands("swimmer_entry")
				rhythmDistance(
					s,
					"Swimmer: bring them alongside, parallel",
					dist,
					0.7,
					1.8,
					false,
					function(e)
						lift(e)
					end
				)
			else
				lift(nil)
			end
		end
	end

	local opts = {}
	for i, m in Recovery.METHODS do
		opts[i] = Recovery.LABELS[i]
		if
			m == "horizontal"
			and not Record.carried(ctx.operation.id, "strop")
			and not World.isJetSki(vehicle)
		then
			opts[i] = "Horizontal lift (no strop)"
		end
	end
	local cards: Frame? = nil
	cards = Ui.cards(s.bag, s.gui, {
		title = "How do you get them aboard?",
		cue = CUES[state] or CUES.Alert,
		options = opts,
		answer = table.find(Recovery.METHODS, Recovery.BOOK[state] or "throwbag"),
		assist = s.assist,
	}, function(i)
		if cards then
			cards:Destroy()
		end
		first = Recovery.METHODS[i]
		runMethod(Recovery.METHODS[i], 0)
	end)
	Ui.add(s.bag, cards)
end

function Recovery.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Recovery", 96)
	if
		Step.autoStub(
			s,
			{ method = Recovery.BOOK[ctx.casualty and ctx.casualty.state or "Alert"], score = 0.8 }
		)
	then
		return Step.cleanup(s)
	end
	Step.line(s, "Read the casualty, then pick the recovery.", 54)
	Recovery.run(s, ctx)
	return Step.cleanup(s)
end

return Recovery
