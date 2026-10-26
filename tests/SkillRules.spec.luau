-- SkillRules (docs/24 G): the player + crew tree's data shape (ids, prerequisites, rising prices, layout),
-- the summed effects and the buy reasons.
return function(t)
	local S = t.load("src/shared/SkillRules.luau")

	local function owned(ids: { string })
		local out = {}
		for _, id in ids do
			out[id] = true
		end
		return out
	end

	t.test("the data: unique ids, every need exists, short names and icons", function()
		local seen = {}
		for _, n in S.NODES do
			t.expect(seen[n.id]).toBeNil()
			seen[n.id] = true
			t.expect(table.find(S.BRANCHES, n.branch) ~= nil).toBe(true)
			t.expect(#n.name >= 1 and #n.name <= 20).toBe(true)
			t.expect(#string.split(n.name, " ") <= 3).toBe(true)
			t.expect(type(n.icon)).toBe("string")
			t.expect(n.cash > 0).toBe(true)
			t.expect(type(n.effect.kind)).toBe("string")
			t.expect(n.effect.amount ~= 0).toBe(true)
		end
		for _, n in S.NODES do
			for _, need in n.needs do
				t.expect(S.byId[need] ~= nil).toBe(true)
				t.expect(S.byId[need].branch).toBe(n.branch)
			end
		end
	end)

	t.test("no cycles, and prices rise along every chain", function()
		local state = {}
		local function visit(id)
			t.expect(state[id] ~= "open").toBe(true) -- open again = a cycle
			if state[id] == "done" then
				return
			end
			state[id] = "open"
			local n = S.byId[id]
			for _, need in n.needs do
				t.expect(n.cash > S.byId[need].cash).toBe(true)
				t.expect(n.col > S.byId[need].col).toBe(true)
				visit(need)
			end
			state[id] = "done"
		end
		for _, n in S.NODES do
			visit(n.id)
		end
	end)

	t.test("branches start cheap and the tree reaches its late-game price", function()
		local top = 0
		for _, branch in S.BRANCHES do
			local first, count = math.huge, 0
			for _, n in S.NODES do
				if n.branch == branch then
					count += 1
					if #n.needs == 0 then
						first = math.min(first, n.cash)
					end
					top = math.max(top, n.cash)
				end
			end
			t.expect(count >= 2).toBe(true)
			t.expect(first <= 5000).toBe(true)
		end
		t.expect(top >= 30000).toBe(true) -- the late-game Cash sink
	end)

	t.test("the effects sum every owned node, per kind and per branch slot", function()
		local none = S.effects({})
		for _, kind in S.KINDS do
			t.expect(none[kind]).toBe(0)
		end
		t.expect(none.extraSlots).toEqual({})
		local captain = S.effects(owned({ "CaptSpeed1", "CaptSpeed2", "CaptSpeed3", "CaptReach" }))
		t.expect(captain.speedMult).toBeCloseTo(0.12, 1e-9)
		t.expect(captain.reach).toBe(3)
		t.expect(captain.payBonus).toBe(0)
		local mixed = S.effects(owned({
			"Capture", -- unknown ids are ignored
			"Gather1",
			"Gather2",
			"GatherStall",
			"GatherNight",
		}))
		t.expect(mixed.gatherMult).toBeCloseTo(0.3, 1e-9)
		t.expect(mixed.offlineRate).toBeCloseTo(0.1, 1e-9)
		t.expect(mixed.extraSlots).toEqual({ Gatherer = 1 })
		t.expect(S.effects(owned({ "Crew1", "Crew2", "Crew3" })).workerCapAdd).toBe(15)
	end)

	t.test("canBuy: unknown, owned, needs, cash, then ok", function()
		local none = {}
		t.expect({ S.canBuy(none, "Nope", 1e9) }).toEqual({ false, "Unknown" })
		t.expect({ S.canBuy(owned({ "CaptSpeed1" }), "CaptSpeed1", 1e9) })
			.toEqual({ false, "Owned" })
		t.expect({ S.canBuy(none, "CaptSpeed2", 1e9) }).toEqual({ false, "Needs" })
		local need = S.byId.CaptSpeed1.cash
		t.expect({ S.canBuy(none, "CaptSpeed1", need - 1) }).toEqual({ false, "Cash" })
		t.expect({ S.canBuy(none, "CaptSpeed1", need) }).toEqual({ true, nil })
	end)
end
