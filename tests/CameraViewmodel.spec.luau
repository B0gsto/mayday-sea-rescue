-- Viewmodel actions: every mechanic action exists and samples to sane, reachable hand targets.
return function(t)
	local A = t.load("src/client/Camera/ViewmodelActions.luau")
	local REACH = 0.93 + 0.81
	local SHOULDER_R = Vector3.new(0.6, -0.75, 0.15)
	local SHOULDER_L = Vector3.new(-0.6, -0.75, 0.15)

	-- every name src/client/Mechanics passes to Viewmodel.playAction (Ui.hands, Kit.hands and
	-- the FerryUi aliases); treat_<id> covers the Medical treatment ids
	local USED = {
		"throw",
		"haul",
		"grab",
		"radio",
		"cpr",
		"knock",
		"point",
		"steer",
		"wave_off",
		"reach_casualty",
		"brace",
		"cast_off",
		"clip_tube",
		"coil_line",
		"cpr_breath",
		"cpr_compress",
		"drop_marker",
		"duck",
		"duck_free",
		"fend_off",
		"fenders",
		"grabbed",
		"grip_sponson",
		"hail",
		"handover",
		"haul_in",
		"haul_left",
		"haul_right",
		"hold_throwbag",
		"lift_aboard",
		"lift_horizontal",
		"payout_left",
		"payout_right",
		"present_tube",
		"radio_handset",
		"ready_heaving_line",
		"rig_bridle",
		"stow_kit",
		"survey_check",
		"swim_out",
		"swimmer_entry",
		"take_line",
		"talk_calm",
		"throw_heaving_line",
		"throw_line",
		"throw_underarm",
		"torch",
		"windup_throw",
		-- docs/14 §4 clip list
		"wave",
		"phone",
		"hold_bars",
		"throw_lifebuoy",
		"drag",
		"wrap_blanket",
	}
	for _, id in
		{
			"shelter",
			"horizontal",
			"casualtyBag",
			"hat",
			"oxygen",
			"recovery",
			"drink",
			"dressing",
			"cpr",
			"rub",
			"hotpack",
			"sitUp",
			"thrusts",
		}
	do
		table.insert(USED, "treat_" .. id)
	end

	t.test("every action the mechanics streams use is defined", function()
		for _, name in USED do
			t.expect(A.Defs[name] ~= nil).toBeTruthy()
		end
	end)

	t.test("Names lists every action exactly once", function()
		local seen = {}
		for _, name in A.Names do
			t.expect(A.Defs[name] ~= nil).toBeTruthy()
			t.expect(seen[name]).toBeFalsy()
			seen[name] = true
		end
		for name in A.Defs do
			t.expect(seen[name]).toBeTruthy()
		end
	end)

	t.test("props named by keys are known props", function()
		local known = { [""] = true }
		for _, p in A.Props do
			known[p] = true
		end
		for _, def in A.Defs do
			for _, key in def.keys do
				if key.prop ~= nil then
					t.expect(known[key.prop]).toBeTruthy()
				end
			end
		end
	end)

	t.test("wave_off: open hand raised above the shoulder, waved side to side", function()
		local def = A.Defs.wave_off
		local minX, maxX = math.huge, -math.huge
		for i = 4, 16 do
			local r, _, grip = A.sample(def, def.duration * i / 20)
			t.expect(r.Y > SHOULDER_R.Y + 0.5).toBeTruthy()
			t.expect(grip).toBe(0)
			minX, maxX = math.min(minX, r.X), math.max(maxX, r.X)
		end
		t.expect(maxX - minX > 0.5).toBeTruthy()
		t.expect(A.sample(def, def.duration)).toBe(A.REST_R)
	end)

	t.test("reach_casualty: arm out forward and down, the hand closes at full reach", function()
		local def = A.Defs.reach_casualty
		local r0, _, g0 = A.sample(def, 0.7)
		local r1, _, g1 = A.sample(def, 0.85)
		t.expect(r0.Z < -1.5 and r0.Y < -1.4).toBeTruthy()
		t.expect(g0).toBe(0)
		t.expect(g1).toBe(1)
		t.expect(r1.Y < -1.4).toBeTruthy()
	end)

	t.test("left-hand variants mirror the right", function()
		local r, l = A.sample(A.Defs.haul_right, 0.3)
		local mr, ml = A.sample(A.Defs.haul_left, 0.3)
		t.expect(mr.X).toBeCloseTo(-l.X, 1e-9)
		t.expect(ml.X).toBeCloseTo(-r.X, 1e-9)
		t.expect(ml.Z).toBeCloseTo(r.Z, 1e-9)
	end)

	t.test("low hands are lifted into the frame; high and near ones are left alone", function()
		local tanHalf = math.tan(math.rad(75) / 2)
		local low = Vector3.new(0.1, -1.6, -1.25)
		local fit = A.inView(low, tanHalf)
		t.expect(fit.Y > low.Y).toBe(true)
		t.expect(fit.X).toBe(low.X)
		t.expect(fit.Z).toBe(low.Z)
		t.expect(fit.Y).toBeCloseTo(-0.65 * 1.25 * tanHalf, 1e-6)
		local high = Vector3.new(0.3, 0.2, -1.2)
		t.expect(A.inView(high, tanHalf)).toBe(high)
		local near = Vector3.new(0.1, -1.6, -0.5)
		t.expect(A.inView(near, tanHalf)).toBe(near)
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
		for i = 0, 10 do
			local _, _, _, p = A.sample(A.Defs.phone, A.Defs.phone.duration * i / 10 + 3)
			t.expect(p).toBe("phone")
		end
		local _, _, _, pb = A.sample(A.Defs.throw_lifebuoy, 0.9)
		t.expect(pb).toBe("")
	end)
end
