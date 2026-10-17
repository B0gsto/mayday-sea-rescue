-- Hull knock (src/shared/Ferry/HullKnock.luau) and the air-pocket dive (src/shared/Ferry/Dive.luau).
return function(t)
	local HullKnock = t.load("src/shared/Ferry/HullKnock.luau")
	local Dive = t.load("src/shared/Ferry/Dive.luau")

	t.test("the pocket compartment is stable and never the bow or engine room", function()
		for _, id in { "O1", "O2", "O17", "O123", "O9999" } do
			local p = HullKnock.pocketCompartment(id)
			t.expect(p).toBe(HullKnock.pocketCompartment(id))
			t.expect(p >= 2 and p <= 4).toBeTruthy()
		end
	end)

	t.test("compartments along the hull round-trip", function()
		for i = 1, HullKnock.Count do
			t.expect(HullKnock.compartmentAt(HullKnock.offsetAlong(i, 60), 60)).toBe(i)
		end
		t.expect(HullKnock.compartmentAt(-999, 60)).toBe(1)
		t.expect(HullKnock.compartmentAt(999, 60)).toBe(HullKnock.Count)
	end)

	t.test("rhythm of three", function()
		t.expect((HullKnock.rhythm({ 0, 0.5, 1.0 }))).toBe(true)
		t.expect((HullKnock.rhythm({ 0, 0.5 }))).toBe(false)
		t.expect((HullKnock.rhythm({ 0, 0.1, 0.2 }))).toBe(false)
		t.expect((HullKnock.rhythm({ 0, 1.5, 3.0 }))).toBe(false)
		t.expect((HullKnock.rhythm({ 0, 0.3, 1.2 }))).toBe(false)
	end)

	t.test("replies: loud over the pocket, faint next door with a direction", function()
		t.expect(HullKnock.reply(3, 3).kind).toBe("Loud")
		local f = HullKnock.reply(4, 3)
		t.expect(f.kind).toBe("Faint")
		t.expect(f.towards).toBe("forward")
		t.expect(HullKnock.reply(2, 3).towards).toBe("aft")
		t.expect(HullKnock.reply(1, 3).kind).toBe("None")
	end)

	t.test("dive: rule of thirds, air rates, pulls", function()
		t.expect(Dive.turnPressure(200, 50)).toBe(150)
		t.expect(Dive.airRate(false, false, false) > Dive.airRate(true, false, false)).toBeTruthy()
		t.expect(Dive.progressRate(true, true, false)).toBe(0)
		t.expect(Dive.progressRate(false, false, false)).toBe(0)
		t.expect(Dive.readPulls({ 0, 0.3 }, 0.5)).toBeNil()
		t.expect(Dive.readPulls({ 0, 0.3 }, 1.5)).toBe(2)
		t.expect(Dive.readPulls({ 0, 0.05, 0.4, 0.8 }, 2)).toBe(3)
		t.expect(Dive.readPulls({}, 2)).toBeNil()
		t.expect(Dive.replyTo(1)).toBe(1)
		t.expect(Dive.grade(2, 0)).toBe("Gold")
		t.expect(Dive.grade(0, 0)).toBe("Fail")
		t.expect(Dive.airQualityRate(2, false) > Dive.airQualityRate(2, true)).toBeTruthy()
	end)
end
