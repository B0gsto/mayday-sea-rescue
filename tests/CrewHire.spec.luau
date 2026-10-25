-- Crew hire (docs/23 (j), WP-15): the 20-minute lineup rotation on the server clock, the
-- deterministic seeker line from a seed, hire price / daily wage, the dock Lv 5 + Coxswain
-- unlock, and the three effect knobs.
return function(t)
	local C = t.load("src/shared/Crew/CrewHire.luau")

	t.test("a new group lines up every 20 minutes on the server clock", function()
		t.expect(C.ROTATE_SECONDS).toBe(20 * 60)
		t.expect(C.groupIndex(0)).toBe(0)
		t.expect(C.groupIndex(C.ROTATE_SECONDS - 1)).toBe(0)
		t.expect(C.groupIndex(C.ROTATE_SECONDS)).toBe(1)
		t.expect(C.groupIndex(3 * C.ROTATE_SECONDS + 7)).toBe(3)
		t.expect(C.nextGroupAt(10)).toBe(C.ROTATE_SECONDS)
		t.expect(C.nextGroupAt(C.ROTATE_SECONDS + 5)).toBe(2 * C.ROTATE_SECONDS)
	end)

	t.test("the lineup is deterministic per owner and group", function()
		local a = C.lineup(1234, 7)
		t.expect(a).toEqual(C.lineup(1234, 7)) -- same owner, same group: the same line
		local b = C.lineup(1234, 8)
		local same = #a == #b
		for i, seeker in a do
			same = same and b[i] ~= nil and seeker.role == b[i].role and seeker.stars == b[i].stars
		end
		t.expect(same).toBe(false) -- the next group replaces the line
		t.expect(C.lineup(9999, 7)).toEqual(C.lineup(9999, 7))
	end)

	t.test("every role appears and stars stay 1-3", function()
		for seed = 1, 40 do
			for group = 0, 3 do
				local seen = {}
				local line = C.lineup(seed, group)
				t.expect(#line).toBe(C.LINE_SIZE)
				for _, seeker in line do
					seen[seeker.role] = true
					t.expect(C.Roles[seeker.role] ~= nil).toBe(true)
					t.expect(seeker.stars >= 1 and seeker.stars <= 3).toBe(true)
				end
				for _, role in C.Order do
					t.expect(seen[role]).toBe(true)
				end
			end
		end
	end)

	t.test("unlock needs the Station built (no ranks)", function()
		t.expect(C.unlocked({ Station = true })).toBe(true)
		t.expect(C.unlocked({ Boathouse = true, LookoutTower = true })).toBe(false)
		t.expect(C.unlocked({})).toBe(false)
	end)

	t.test("hire costs Cash, one per role", function()
		local price = C.Roles.Mechanic.price
		local ok, why, p = C.canHire("Mechanic", {}, price)
		t.expect(ok).toBe(true)
		t.expect(why).toBe("ok")
		t.expect(p).toBe(price)

		local noCash, whyCash = C.canHire("Mechanic", {}, price - 1)
		t.expect(noCash).toBe(false)
		t.expect(whyCash).toBe("Cash")

		local noRole, whyRole = C.canHire("Mechanic", { Mechanic = true }, 1e9)
		t.expect(noRole).toBe(false)
		t.expect(whyRole).toBe("Hired") -- max one per role

		local noName, whyName = C.canHire("Bosun", {}, 1e9)
		t.expect(noName).toBe(false)
		t.expect(whyName).toBe("Unknown")
	end)

	t.test("the daily wage is a small late-game sink, not a wall", function()
		t.expect(C.dailyWage({})).toBe(0)
		t.expect(C.dailyWage({ Bosun = true })).toBe(0) -- unknown roles never charge
		local full = C.dailyWage({ Mechanic = true, Lifeguard = true, Dispatcher = true })
		t.expect(full)
			.toBe(C.Roles.Mechanic.wage + C.Roles.Lifeguard.wage + C.Roles.Dispatcher.wage)
		-- far below an hour of late-game Cash (docs/23 (i): ~15k/h), so it never blocks play
		t.expect(full <= 2000).toBe(true)
		for _, role in C.Order do
			t.expect(C.Roles[role].wage > 0).toBe(true)
		end
	end)

	t.test("the effect knobs", function()
		t.expect(C.MechanicCooldown).toBeCloseTo(0.7, 1e-6) -- Boat to me (60 s) -30% = 42 s
		t.expect(C.DispatchFactor).toBeCloseTo(0.8, 1e-6) -- offers 20% sooner
		t.expect(C.LifeguardSwimmers).toBe(1)

		t.expect(C.boatToMeScale({})).toBe(1)
		t.expect(C.boatToMeScale({ Mechanic = true })).toBe(C.MechanicCooldown)
		t.expect(C.boatToMeScale({ Lifeguard = true })).toBe(1) -- only its own role

		t.expect(C.offerFactor({})).toBe(1)
		t.expect(C.offerFactor({ Dispatcher = true })).toBe(C.DispatchFactor)

		t.expect(C.extraSwimmers({})).toBe(0)
		t.expect(C.extraSwimmers({ Lifeguard = true })).toBe(C.LifeguardSwimmers)
	end)
end
