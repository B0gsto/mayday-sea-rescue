-- GoBack (docs/30 section 1): who may press Go back, and the rate limit.
return function(t)
	local GoBack = t.load("src/shared/Boat/GoBack.luau")
	local ColdOpen = t.load("src/shared/Boat/ColdOpen.luau")

	local bay = CFrame.new(1000, 0, 0)
	local function state(patch)
		local s = {
			driving = true,
			coldOpenDone = true,
			survivors = 0,
			testRide = false,
			at = Vector3.new(0, 0, 0),
			bay = bay,
		}
		for k, v in patch or {} do
			s[k] = v
		end
		return s
	end

	t.test("driving away from home goes, with or without survivors", function()
		t.expect(GoBack.refusal(state())).toBe(nil)
		t.expect(GoBack.refusal(state({ survivors = 3 }))).toBe(nil)
	end)

	t.test("never out of the driver's seat or on a test ride", function()
		t.expect(GoBack.refusal(state({ driving = false }))).toBe("NotDriving")
		t.expect(GoBack.refusal(state({ testRide = true, survivors = 1 }))).toBe("TestRide")
	end)

	t.test("the cold open: only once a survivor is aboard", function()
		t.expect(GoBack.refusal(state({ coldOpenDone = false }))).toBe("ColdOpen")
		t.expect(GoBack.refusal(state({ coldOpenDone = false, survivors = 1 }))).toBe(nil)
	end)

	t.test("nothing to do at home, and no home without a berth", function()
		local near = Vector3.new(1000 - ColdOpen.DROP_RADIUS + 1, 0, 0)
		t.expect(GoBack.refusal(state({ at = near }))).toBe("Home")
		t.expect(GoBack.refusal(state({ bay = false }))).toBe("NoHome")
	end)

	t.test("rate limit: a press outlasts the charge and the landing", function()
		t.expect(GoBack.ready(nil, 5)).toBe(true)
		t.expect(GoBack.ready(5, 5 + GoBack.COOLDOWN - 0.01)).toBe(false)
		t.expect(GoBack.ready(5, 5 + GoBack.COOLDOWN)).toBe(true)
		t.expect(GoBack.COOLDOWN > GoBack.CHARGE + GoBack.LAND_HOLD).toBe(true)
	end)
end
