-- MechPIW skills: the pure physics and scoring behind the Person in the Water mechanics
-- (approach, throw bag, rhythm, panic, search, passage). docs/09-rescue-operations.md section 5.
return function(t)
	local Units = t.load("src/client/Mechanics/PIW/Units.luau")
	local Approach = t.load("src/client/Mechanics/PIW/Approach.luau")
	local Throw = t.load("src/client/Mechanics/PIW/Throw.luau")
	local Rhythm = t.load("src/client/Mechanics/PIW/Rhythm.luau")
	local Panic = t.load("src/client/Mechanics/PIW/Panic.luau")
	local Search = t.load("src/client/Mechanics/PIW/Search.luau")
	local Wake = t.load("src/shared/Boat/Wake.luau")

	-- wind 0 blows toward +X; its eye is at -X
	local WIND = 0

	local function run(speed: number, fromX: number, neutralAt: number?)
		-- a boat running along X toward a casualty at the origin
		local s = Approach.new()
		local dir = if fromX > 0 then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)
		local x = fromX
		local dt = 0.1
		while math.abs(x) > 4 do
			local d = math.abs(x)
			local neutral = neutralAt ~= nil and d <= neutralAt
			local pos = Vector3.new(x, 0, 0)
			local push, h = Wake.at(Vector3.zero, {
				position = pos,
				velocity = dir * speed,
				forward = dir,
				length = 15,
				beam = 6,
			})
			Approach.sample(s, dt, {
				distance = d,
				speed = speed,
				forward = dir,
				boatPos = pos,
				casualtyPos = Vector3.zero,
				windDirection = WIND,
				neutral = neutral,
				wakeHeight = h,
				wakePush = push,
			})
			x += dir.X * speed * dt
		end
		return s
	end

	t.test("approach: slow, from downwind, neutral in the window is all Gold", function()
		-- downwind of the casualty is +X; heading -X is into the wind
		local s = run(Approach.SLOW * 0.8, 120, 7)
		local m = Approach.metrics(s)
		t.expect(m.overSpeedSec).toBe(0)
		t.expect(m.fromDownwind).toBe(true)
		t.expect(m.neutralDistance <= 8 and m.neutralDistance >= 3).toBeTruthy()
	end)

	t.test("approach: from upwind is not fromDownwind; fast runs rack up over-speed", function()
		local up = Approach.metrics(run(Approach.SLOW * 0.8, -120, 6))
		t.expect(up.fromDownwind).toBe(false)
		local fast = run(Approach.SLOW * 3, 120, 6)
		t.expect(Approach.metrics(fast).overSpeedSec > 2).toBeTruthy()
	end)

	t.test("approach: a fast hull's wake pushes the casualty away and washes them", function()
		local slow = run(Approach.SLOW * 0.5, 120, 6)
		local fast = run(Approach.SLOW * 4, 120, 6)
		t.expect(fast.washes >= 1).toBeTruthy()
		t.expect(fast.offset.Magnitude > 0).toBeTruthy()
		t.expect(slow.washes).toBe(0)
	end)

	t.test("approach: neutral metric punishes overrunning and never shifting", function()
		t.expect(Approach.neutralMetric(6)).toBe(6)
		t.expect(Approach.neutralMetric(1) > 12).toBeTruthy()
		t.expect(Approach.neutralMetric(nil) >= 20).toBeTruthy()
	end)

	t.test(
		"approach: stop position wants them alongside or at the bow, clear of the prop",
		function()
			local L, B = 16, 6
			t.expect((Approach.stopPosition(Vector3.new(4, 0, -2), L, B))).toBe(true) -- side
			t.expect((Approach.stopPosition(Vector3.new(0, 0, -10), L, B))).toBe(true) -- bow
			local ok, why = Approach.stopPosition(Vector3.new(1, 0, 7.5), L, B)
			t.expect(ok).toBe(false)
			t.expect(why).toBe("astern")
		end
	)

	t.test("throw: projectile range matches the closed form in still air", function()
		local v = Throw.velocity(Vector3.new(0, 0, -1), 1)
		local land, tf = Throw.land(Vector3.zero, v, 0, Units.GRAVITY, Vector3.zero)
		local speed = Throw.MAX_SPEED
		local expected = speed * speed * math.sin(2 * Throw.ANGLE) / Units.GRAVITY
		t.expect(math.abs(land.Z) > 0).toBeTruthy()
		t.expect(math.min(Throw.LINE_LENGTH, expected)).toBeCloseTo(math.abs(land.Z), 0.01)
		t.expect(tf).toBeCloseTo(2 * speed * math.sin(Throw.ANGLE) / Units.GRAVITY, 1e-6)
	end)

	t.test("throw: wind carries the bag downwind and the line snubs at its length", function()
		local v = Throw.velocity(Vector3.new(0, 0, -1), 0.5)
		local still = Throw.land(Vector3.new(0, 3, 0), v, 0, Units.GRAVITY, Vector3.zero)
		local windy = Throw.land(Vector3.new(0, 3, 0), v, 0, Units.GRAVITY, Vector3.new(4, 0, 0))
		t.expect(windy.X > still.X).toBeTruthy()
		local _, _, snubbed =
			Throw.land(Vector3.new(0, 30, 0), Throw.velocity(Vector3.zAxis, 1), 0, 5, Vector3.zero)
		t.expect(snubbed).toBe(true)
	end)

	t.test(
		"throw: beyond and upwind lands over them; at the head, short and downwind miss",
		function()
			local thrower = Vector3.zero
			local cas = Vector3.new(0, 0, -30)
			-- wind toward +X: upwind of the casualty is -X
			t.expect(Throw.assess(thrower, Vector3.new(-3, 0, -38), cas, WIND).result).toBe("over")
			t.expect(Throw.assess(thrower, Vector3.new(0.5, 0, -30.5), cas, WIND).result)
				.toBe("head")
			t.expect(Throw.assess(thrower, Vector3.new(0, 0, -24), cas, WIND).result).toBe("short")
			t.expect(Throw.assess(thrower, Vector3.new(9, 0, -38), cas, WIND).result)
				.toBe("downwind")
			t.expect(Throw.throwScore(1, 0) > Throw.throwScore(2, 0)).toBeTruthy()
			t.expect(Throw.recoveryScore(1, 1, 0)).toBe(1)
		end
	)

	t.test("throw: charge rises to full and sags if held too long", function()
		t.expect(Throw.charge(0)).toBe(0)
		t.expect(Throw.charge(Throw.CHARGE_TIME)).toBe(1)
		t.expect(Throw.charge(Throw.CHARGE_TIME * 1.5) < 1).toBeTruthy()
	end)

	t.test("rhythm: steady alternate hands is even; rushing and same hand are not", function()
		local r = Rhythm.new(0.6, 0.35, true)
		local tt = 0
		for i = 1, 9 do
			Rhythm.tap(r, if i % 2 == 0 then "L" else "R", tt)
			tt += 0.6
		end
		t.expect(Rhythm.evenness(r)).toBe(1)
		t.expect(Rhythm.tap(r, "R", tt)).toBe("hand") -- the last tap (i = 9) was R
		local f = Rhythm.new(0.6, 0.35, true)
		Rhythm.tap(f, "L", 0)
		t.expect(Rhythm.tap(f, "R", 0.1)).toBe("fast")
		t.expect(Rhythm.tap(f, "R", 0.7)).toBe("hand")
	end)

	t.test("rhythm: CPR plans follow the age band and the metronome", function()
		local adult = Rhythm.cprPlan("Adult")
		local child = Rhythm.cprPlan("Child")
		t.expect(adult.compressions).toBe(30)
		t.expect(child.compressions).toBe(15)
		t.expect(adult.initialBreaths).toBe(5)
		t.expect(adult.bpm >= 100 and adult.bpm <= 120).toBeTruthy()
		local seq = Rhythm.cprSequence(adult)
		t.expect(seq[1]).toBe("B")
		t.expect(seq[6]).toBe("C")
		t.expect(#seq).toBe(5 + adult.cycles * 32)
		t.expect(Rhythm.beatError(1.0, 0, 0.5)).toBeCloseTo(0, 1e-9)
		t.expect(Rhythm.beatError(1.25, 0, 0.5)).toBeCloseTo(0.25, 1e-9)
	end)

	t.test(
		"panic: calm words in the lulls bring them under the threshold; shouting doesn't",
		function()
			local p = Panic.new(0.3, false)
			p.tubeOut = true
			local tt = 0
			local said = 0
			while p.level >= Panic.ACCEPT and tt < 40 do
				if Panic.isLull(p, tt) then
					Panic.say(p, tt)
					said += 1
					tt += p.lull -- one line per lull
				else
					tt += 0.1
				end
			end
			t.expect(p.level < Panic.ACCEPT).toBeTruthy()
			t.expect(said <= 6).toBeTruthy()
			local q = Panic.new(0.3, false, 60)
			local before = q.level
			local x = 0
			while Panic.isLull(q, x) do
				x += 0.05
			end
			Panic.say(q, x)
			t.expect(q.level > before).toBeTruthy()
		end
	)

	t.test("panic: they grab in front at arm's length, less so from behind", function()
		local p = Panic.new(0, false, 90)
		t.expect(Panic.grabs(p, Panic.ARM * 0.8, 10)).toBe(true)
		t.expect(Panic.grabs(p, Panic.ARM * 0.8, 150)).toBe(false)
		p.level = 20
		t.expect(Panic.grabs(p, 1, 0)).toBe(false)
		p.tubeOut = true
		t.expect(Panic.accepts(p, Panic.ARM)).toBe(true)
	end)

	t.test("search: start error, drift and the expanding square legs", function()
		t.expect(Search.startError(Vector3.new(30, 5, 40), Vector3.zero)).toBe(50)
		local d = Search.drifted(Vector3.zero, Vector3.new(1, 0, 0), 60)
		t.expect(d.X).toBe(60)
		local pts = Search.expandingSquare(Vector3.zero, Vector3.new(0, 0, -1), 10, 4)
		t.expect(#pts).toBe(5)
		t.expect((pts[2] - pts[1]).Magnitude).toBeCloseTo(10, 1e-6)
		t.expect((pts[3] - pts[2]).Magnitude).toBeCloseTo(10, 1e-6)
		t.expect((pts[4] - pts[3]).Magnitude).toBeCloseTo(20, 1e-6)
		t.expect((pts[3] - pts[2]):Dot(pts[2] - pts[1])).toBeCloseTo(0, 1e-6)
		t.expect(Search.distanceToPath(Vector3.new(3, 0, -5), pts)).toBeCloseTo(3, 1e-6)
	end)

	t.test("search: storms shorten sight; strobes and smoke carry; crests hide them", function()
		local calm = { storm = false, lowLight = false, strobe = false, smoke = false }
		local storm = { storm = true, lowLight = false, strobe = false, smoke = false }
		local strobe = { storm = true, lowLight = false, strobe = true, smoke = false }
		t.expect(Search.sightRange(storm) < Search.sightRange(calm)).toBeTruthy()
		t.expect(Search.sightRange(strobe) > Search.sightRange(calm)).toBeTruthy()
		local shown = 0
		for i = 0, 99 do
			if Search.showsOnCrest(i * 0.1, 0.2, storm) then
				shown += 1
			end
		end
		t.expect(shown > 10 and shown < 90).toBeTruthy()
	end)

	t.test("search: losing sight counts once per lapse past 3 s", function()
		local l = Search.lookout()
		l.sighted = true
		for _ = 1, 50 do
			Search.keepEyesOn(l, 0.1, false)
		end
		t.expect(l.lost).toBe(1)
		Search.keepEyesOn(l, 0.1, true)
		for _ = 1, 20 do
			Search.keepEyesOn(l, 0.1, false)
		end
		t.expect(l.lost).toBe(1)
	end)

	t.test("passage: route ratio", function()
		t.expect(Units.routeRatio(110, 1000, 10)).toBeCloseTo(1.1, 1e-9)
		t.expect(Units.hash01("abc")).toBe(Units.hash01("abc"))
	end)
end
