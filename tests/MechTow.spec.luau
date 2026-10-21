-- Tow mechanics (stream b): the line tension model, the heaving line throw, the procedures.
return function(t)
	local TowLine = t.load("src/shared/Tow/TowLine.luau")
	local Ballistics = t.load("src/client/Mechanics/Tow/Ballistics.luau")
	local Procedures = t.load("src/client/Mechanics/Tow/Procedures.luau")

	-- tows a line behind a hitch moving at `speed` studs/s along -Z for `seconds`
	local function run(line, speed, seconds, env, wobble)
		local hz = -(line.length * 3 + 7)
		local dt = 1 / 60
		local peak = 0
		for i = 1, math.floor(seconds / dt) do
			local v = speed
			if wobble then
				v = speed + wobble * math.sin(i * dt * 2.2)
			end
			hz -= v * dt
			TowLine.step(line, 0, hz, 0, -v, dt, env)
			peak = math.max(peak, line.tension)
		end
		return peak
	end

	t.test("hull speed of a 14-stud (4.7 m) boat is about 5 knots", function()
		local hs = TowLine.hullSpeed(14)
		t.expect(hs / 3 / TowLine.KNOT).toBeCloseTo(5.4, 0.6)
		t.expect(TowLine.safeSpeed(hs, 1) < TowLine.safeSpeed(hs, 0)).toBeTruthy()
	end)

	t.test("a gentle steady tow sits in the green and the hull follows", function()
		local line = TowLine.new({ heading = math.pi, lengthStuds = 60 })
		local safe = TowLine.safeSpeed(TowLine.hullSpeed(14), 0)
		run(line, safe * 0.5, 30, nil, nil)
		t.expect(line.parted).toBe(false)
		t.expect(TowLine.band(line.tension)).toBe("green")
		local _, z = TowLine.hullPosition(line)
		t.expect(z < -50).toBeTruthy()
	end)

	t.test("towing well past hull speed goes red and parts the line", function()
		local line = TowLine.new({ heading = math.pi, lengthStuds = 60 })
		run(line, TowLine.hullSpeed(14) * 1.5, 40, nil, nil)
		t.expect(line.parted).toBe(true)
	end)

	t.test("snatching a slack line spikes the tension; a longer line absorbs it", function()
		local short = TowLine.new({ heading = math.pi, lengthStuds = 30 })
		short.x = 0
		short.z = 0
		-- hitch starts slack, close in, and drives off hard
		local function snatch(line)
			local hz = -line.length * 3 * 0.6
			local peak = 0
			for _ = 1, 240 do
				hz -= 20 / 60
				TowLine.step(line, 0, hz, 0, -20, 1 / 60, nil)
				peak = math.max(peak, line.tension)
			end
			return peak
		end
		local pShort = snatch(short)
		local pLong = snatch(TowLine.new({ heading = math.pi, lengthStuds = 120 }))
		t.expect(pShort > 0.9).toBeTruthy()
		t.expect(pLong < pShort).toBeTruthy()
	end)

	t.test("a slack line reads slack and sags", function()
		local line = TowLine.new({ heading = math.pi, lengthStuds = 60 })
		TowLine.step(line, 0, -20, 0, 0, 1 / 60, nil)
		t.expect(line.slack).toBe(true)
		t.expect(TowLine.sag(60, 20, 0) > 10).toBeTruthy()
		t.expect(TowLine.sag(60, 61, 5000) < 1).toBeTruthy()
	end)

	t.test("no bridle on a weak point sheers the tow", function()
		local good = TowLine.new({ heading = math.pi, lengthStuds = 60, bridle = true })
		local bad = TowLine.new({ heading = math.pi, lengthStuds = 60, bridle = false })
		run(good, 6, 20, nil, nil)
		run(bad, 6, 20, nil, nil)
		t.expect(math.abs(bad.heading - math.pi) + 1e-6 >= math.abs(good.heading - math.pi))
			.toBeTruthy()
	end)

	t.test("step-out length keeps both boats in step", function()
		local len, n = TowLine.recommendedLength(64, 0, 20, 14)
		t.expect(n >= 1).toBeTruthy()
		t.expect(TowLine.inStep(len + 17, 64)).toBeTruthy()
		local storm = TowLine.recommendedLength(64, 1, 20, 14)
		t.expect(storm > len).toBeTruthy()
		t.expect(TowLine.stepError(32, 64)).toBeCloseTo(0.5, 1e-6)
	end)

	t.test("bands", function()
		t.expect(TowLine.band(0)).toBe("slack")
		t.expect(TowLine.band(0.5)).toBe("green")
		t.expect(TowLine.band(0.8)).toBe("amber")
		t.expect(TowLine.band(0.95)).toBe("red")
	end)

	t.test("heaving line: arc lands, wind drifts it, the coil limits range", function()
		local o = Vector3.new(0, 4, 0)
		local v = Ballistics.launchVelocity(0, math.rad(35), Ballistics.speedFor(0.6))
		local calm = Ballistics.simulate(o, v, Vector3.zero, 0, nil, nil)
		t.expect(calm.point.Z < -20).toBeTruthy()
		t.expect(math.abs(calm.point.X) < 0.01).toBeTruthy()
		local windy = Ballistics.simulate(o, v, Vector3.new(15, 0, 0), 0, nil, nil)
		t.expect(windy.point.X > 2).toBeTruthy()
		local far = Ballistics.simulate(
			o,
			Ballistics.launchVelocity(0, math.rad(45), 200),
			Vector3.zero,
			0,
			nil,
			nil
		)
		t.expect(far.outOfLine).toBe(true)
	end)

	t.test("heaving line: judge deck, person and misses", function()
		local deck = { cframe = CFrame.new(0, 1, -40), size = Vector3.new(6, 1, 14) }
		local o = Vector3.new(0, 4, 0)
		local function at(p)
			return { point = p, time = 1, path = {}, outOfLine = false }
		end
		t.expect(Ballistics.judge(at(Vector3.new(0, 1.5, -40)), o, deck, {})).toBe("deck")
		t.expect(
			Ballistics.judge(at(Vector3.new(1, 1.5, -40)), o, deck, { Vector3.new(1, 2, -40) })
		)
			.toBe("person")
		t.expect(Ballistics.judge(at(Vector3.new(0, 0, -20)), o, deck, {})).toBe("short")
		t.expect(Ballistics.judge(at(Vector3.new(30, 0, -40)), o, deck, {})).toBe("wide")
		t.expect(Ballistics.upwindness(Vector3.new(-10, 0, 0), Vector3.zero, Vector3.new(1, 0, 0)))
			.toBeCloseTo(1, 1e-6)
	end)

	t.test("procedures: deterministic scenario, answers, length, contact", function()
		local a = Procedures.roll(Procedures.seedOf("O12"))
		local b = Procedures.roll(Procedures.seedOf("O12"))
		t.expect(a.pob).toBe(b.pob)
		t.expect(a.pob >= 1 and a.pob <= 4).toBeTruthy()
		t.expect(Procedures.answer({ pob = 3 }, "pob")).toBe("3 of us aboard.")
		t.expect(#Procedures.ANSWER_ORDER).toBe(6)
		t.expect(Procedures.rightLength(0.8)).toBe("long")
		t.expect(Procedures.lengthStuds("long")).toBe(120)
		t.expect(Procedures.inRing(Vector3.zero, Vector3.new(30, 0, 0))).toBe(true)
		t.expect(Procedures.contactSpeed(Vector3.new(-3, 0, 0), Vector3.new(1, 0, 0)))
			.toBeCloseTo(3, 1e-6)
	end)
end
