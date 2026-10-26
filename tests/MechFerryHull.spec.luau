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
end
