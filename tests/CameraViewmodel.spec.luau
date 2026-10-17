-- Viewmodel actions: every mechanic action exists and samples to sane, reachable hand targets.
return function(t)
	local A = t.load("src/client/Camera/ViewmodelActions.luau")
	local REACH = 0.93 + 0.81
	local SHOULDER_R = Vector3.new(0.6, -0.75, 0.15)
	local SHOULDER_L = Vector3.new(-0.6, -0.75, 0.15)

	t.test("every action the mechanics streams use is defined", function()
		for _, name in { "throw", "haul", "grab", "radio", "cpr", "knock", "point", "steer" } do
			t.expect(A.Defs[name]).toBeTruthy()
		end
		t.expect(#A.Names).toBe(8)
	end)

	t.test("keys are ordered and span the duration", function()
		for name, def in A.Defs do
			local last = -1
			for _, key in def.keys do
				t.expect(key.t >= last).toBeTruthy()
				last = key.t
			end
			t.expect(def.keys[1].t).toBe(0)
			t.expect(last).toBeCloseTo(def.duration, 1e-9)
			t.expect(name ~= "").toBeTruthy()
		end
	end)

	t.test("hand targets stay within arm's reach (except rest)", function()
		for name, def in A.Defs do
			for i = 0, 20 do
				local r, l, grip = A.sample(def, def.duration * i / 20)
				if r ~= A.REST_R then
					t.expect((r - SHOULDER_R).Magnitude <= REACH + 0.6).toBeTruthy()
				end
				if l ~= A.REST_L then
					t.expect((l - SHOULDER_L).Magnitude <= REACH + 0.6).toBeTruthy()
				end
				t.expect(grip >= 0 and grip <= 1).toBeTruthy()
			end
			t.expect(name).toBeTruthy()
		end
	end)

	t.test("one-shot actions end at rest; loops wrap", function()
		local r = A.sample(A.Defs.throw, 99)
		t.expect(r).toBe(A.REST_R)
		local a = A.sample(A.Defs.cpr, 0.1)
		local b = A.sample(A.Defs.cpr, 0.1 + A.Defs.cpr.duration)
		t.expect((a - b).Magnitude).toBeCloseTo(0, 1e-6)
	end)

	t.test("CPR compresses 5 cm at 100-120 a minute", function()
		local def = A.Defs.cpr
		local perMinute = 60 / def.duration
		t.expect(perMinute >= 100 and perMinute <= 120).toBeTruthy()
		local top = A.sample(def, 0)
		local bottom = A.sample(def, def.duration / 2)
		t.expect(top.Y - bottom.Y).toBeCloseTo(0.15, 0.02)
	end)

	t.test("props: the throw bag leaves the hand at release, the radio shows", function()
		local _, _, _, p0 = A.sample(A.Defs.throw, 0.2)
		local _, _, _, p1 = A.sample(A.Defs.throw, 0.7)
		t.expect(p0).toBe("throwbag")
		t.expect(p1).toBe("")
		local _, _, _, pr = A.sample(A.Defs.radio, 0.8)
		t.expect(pr).toBe("radio")
	end)
end
