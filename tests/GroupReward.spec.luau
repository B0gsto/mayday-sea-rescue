-- GroupReward (G68): the Crew group flag, cached membership and the flat daily crate bonus.
return function(t)
	local GroupReward = t.load("src/shared/GroupReward.luau")

	t.test("group 0 (or a bad id) is off", function()
		for _, id in { 0, -4, 1.5, "123", math.huge } do
			t.expect(GroupReward.enabled(id)).toBe(false)
		end
		t.expect(GroupReward.enabled(1234567)).toBe(true)
	end)

	t.test("an empty flag has no crew and no member", function()
		for _, raw in { nil, 7, {} } do
			local state = GroupReward.decode(raw)
			t.expect(state.crew).toBe(false)
			t.expect(state.member).toBe(false)
			t.expect(GroupReward.isMember(state, 123)).toBe(false)
			t.expect(GroupReward.earned(state)).toBe(false)
		end
	end)

	t.test("joining earns the pennant and the daily member state", function()
		local state = GroupReward.update(GroupReward.decode(nil), true, 123)
		t.expect(state.crew).toBe(true)
		t.expect(GroupReward.isMember(state, 123)).toBe(true)
		t.expect(GroupReward.earned(state)).toBe(true)
		local saved = GroupReward.decode(GroupReward.encode(state))
		t.expect(saved.crew).toBe(true)
		t.expect(saved.member).toBe(true)
		t.expect(GroupReward.isMember(saved, 123)).toBe(true)
	end)

	t.test("not in the group: no reward, no pennant", function()
		local state = GroupReward.update(GroupReward.decode(nil), false, 123)
		t.expect(state.crew).toBe(false)
		t.expect(state.member).toBe(false)
		t.expect(GroupReward.isMember(state, 123)).toBe(false)
	end)

	t.test("leaving keeps the pennant, drops the member bonus", function()
		local joined = GroupReward.update(GroupReward.decode(nil), true, 123)
		local left = GroupReward.update(joined, false, 123)
		t.expect(left.crew).toBe(true)
		t.expect(GroupReward.isMember(left, 123)).toBe(false)
		t.expect(GroupReward.bonus(left, 200, 0.1, 123)).toBe(0)
	end)

	t.test("a different group id is not a member (stale cache)", function()
		local joined = GroupReward.update(GroupReward.decode(nil), true, 123)
		t.expect(GroupReward.isMember(joined, 999)).toBe(false)
	end)

	t.test("turning the group off clears membership, keeps the pennant", function()
		local joined = GroupReward.update(GroupReward.decode(nil), true, 123)
		local off = GroupReward.update(joined, true, 0)
		t.expect(off.crew).toBe(true)
		t.expect(off.member).toBe(false)
		t.expect(off.groupId).toBe(0)
	end)

	t.test("the daily bonus is a flat 10%, rounded down", function()
		local member = GroupReward.update(GroupReward.decode(nil), true, 123)
		t.expect(GroupReward.bonus(member, 200, 0.1, 123)).toBe(20)
		t.expect(GroupReward.bonus(member, 55, 0.1, 123)).toBe(5)
		t.expect(GroupReward.bonus(member, 9, 0.1, 123)).toBe(0)
		t.expect(GroupReward.bonus(member, 0, 0.1, 123)).toBe(0)
		t.expect(GroupReward.bonus(member, -10, 0.1, 123)).toBe(0)
		t.expect(GroupReward.bonus(member, 200, 0.1, 0)).toBe(0)
		t.expect(GroupReward.bonus(member, 200, 0.1, 999)).toBe(0)
	end)
end
