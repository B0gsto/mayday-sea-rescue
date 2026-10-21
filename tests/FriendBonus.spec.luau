-- FriendBonus (G23, docs/15 H9): +10% Cash per friend in the server, cap +30%.
return function(t)
	local FriendBonus = t.load("src/shared/FriendBonus.luau")

	t.test("friend multiplier is +10% each and capped at +30%", function()
		t.expect(FriendBonus.multiplier(0)).toBe(1)
		t.expect(FriendBonus.multiplier(1)).toBeCloseTo(1.1, 6)
		t.expect(FriendBonus.multiplier(2)).toBeCloseTo(1.2, 6)
		t.expect(FriendBonus.multiplier(3)).toBeCloseTo(1.3, 6)
		t.expect(FriendBonus.multiplier(4)).toBeCloseTo(1.3, 6)
		t.expect(FriendBonus.multiplier(99)).toBeCloseTo(1.3, 6)
	end)

	t.test("bad counts never pay", function()
		t.expect(FriendBonus.multiplier(-2)).toBe(1)
		t.expect(FriendBonus.multiplier(0.9)).toBe(1)
	end)

	t.test("the HUD percent is a whole 0 to 30", function()
		t.expect(FriendBonus.percent(0)).toBe(0)
		t.expect(FriendBonus.percent(1)).toBe(10)
		t.expect(FriendBonus.percent(2)).toBe(20)
		t.expect(FriendBonus.percent(3)).toBe(30)
		t.expect(FriendBonus.percent(7)).toBe(30)
	end)
end
