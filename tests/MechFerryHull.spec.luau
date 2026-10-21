-- Hull knock (src/shared/Ferry/HullKnock.luau).
return function(t)
	local HullKnock = t.load("src/shared/Ferry/HullKnock.luau")

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
end
