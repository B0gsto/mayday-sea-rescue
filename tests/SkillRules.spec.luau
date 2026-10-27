-- SkillRules (docs/25 F, K3): the radial tree's expansion (keystones + generated minor dots),
-- sectors/angles, prices, the chained minor paths, the summed effects and the buy rules, plus the
-- once-only Cash refund of the old tree and the Medals save field.
return function(t)
	local S = t.load("src/shared/SkillRules.luau")
	local P = t.load("src/shared/ProgressionRules.luau")

	local function owned(ids: { string })
		local out = {}
		for _, id in ids do
			out[id] = true
		end
		return out
	end

	local BRIDGE_ANGLES = { 0, 90, 180, 270 }

	local function containsAngle(list: { number }, angle: number): boolean
		for _, a in list do
			if math.abs(a - angle) < 1e-9 then
				return true
			end
		end
		return false
	end

	t.test("nodes(): keystones and their expanded minors, unique ids, every need exists", function()
		local nodes = S.nodes()
		t.expect(nodes).toBe(S.NODES)
		t.expect(#nodes > 0).toBe(true)
		local seen = {}
		local keystones, minors = 0, 0
		for _, n in nodes do
			t.expect(seen[n.id]).toBeNil()
			seen[n.id] = true
			t.expect(S.byId[n.id] == n).toBe(true)
			t.expect(table.find(S.SECTORS, n.sector) ~= nil).toBe(true)
			t.expect(#n.name >= 1 and #n.name <= 20).toBe(true)
			t.expect(#string.split(n.name, " ") <= 3).toBe(true)
			t.expect(type(n.icon)).toBe("string")
			t.expect(n.medals >= 1).toBe(true)
			t.expect(type(n.effect.kind)).toBe("string")
			t.expect(n.effect.amount ~= 0).toBe(true)
			t.expect(n.ring > 0 and n.ring <= 5).toBe(true)
			local focusOk = n.focus == "Captain"
				or n.focus == "Any"
				or table.find(S.FOCUS_CATEGORIES, n.focus) ~= nil
			t.expect(focusOk).toBe(true)
			if n.keystone then
				keystones += 1
				t.expect(n.minor ~= nil).toBe(true)
				local minor = n.minor :: any
				t.expect(minor.count >= 2 and minor.count <= 4).toBe(true)
				t.expect(type(minor.kind)).toBe("string")
				t.expect(minor.amount ~= 0).toBe(true)
			else
				minors += 1
				t.expect(n.minor).toBeNil()
			end
		end
		for _, n in nodes do
			for _, need in n.needs do
				t.expect(S.byId[need] ~= nil).toBe(true)
			end
		end
		-- 8 buyable keystones per sector + 5 rim + 4 bridges
		t.expect(keystones).toBe(4 * 8 + 5 + 4)
		t.expect(minors > 0).toBe(true)
	end)

	t.test("the four sectors hold every keystone inside their 72 degrees", function()
		for _, n in S.nodes() do
			if n.sector == "Bridge" then
				if n.keystone then
					t.expect(n.ring).toBe(2.75)
					t.expect(containsAngle(BRIDGE_ANGLES, n.angle)).toBe(true)
				else
					local near = false
					for _, a in BRIDGE_ANGLES do
						local off = (n.angle - a + 540) % 360 - 180
						near = near or math.abs(off) <= 36 + 1e-9
					end
					t.expect(near).toBe(true)
				end
			else
				local centre = S.SECTOR_ANGLE[n.sector]
				local offset = (n.angle - centre + 540) % 360 - 180
				t.expect(math.abs(offset) <= 36 + 1e-9).toBe(true)
			end
		end
		local seenSectors = {}
		for _, n in S.nodes() do
			if n.sector ~= "Bridge" then
				seenSectors[n.sector] = true
			end
		end
		t.expect(seenSectors.Captain).toBe(true)
		t.expect(seenSectors.Rescue).toBe(true)
		t.expect(seenSectors.Crew).toBe(true)
		t.expect(seenSectors.Industry).toBe(true)
	end)

	t.test("each bridge links two neighbouring sectors", function()
		local bridges = 0
		for _, n in S.nodes() do
			if n.sector == "Bridge" and n.keystone then
				bridges += 1
				local sectors = {}
				for _, need in n.needs do
					local other = S.byId[need]
					t.expect(other ~= nil).toBe(true)
					if other and other.sector ~= "Bridge" then
						sectors[other.sector] = true
					end
				end
				local list = {}
				for sector in sectors do
					table.insert(list, sector)
				end
				t.expect(#list >= 2).toBe(true)
				table.sort(list)
				local a, b = S.SECTOR_ANGLE[list[1]], S.SECTOR_ANGLE[list[2]]
				local gap = math.abs((a - b + 540) % 360 - 180)
				t.expect(gap).toBe(90)
			end
		end
		t.expect(bridges).toBe(4)
	end)

	t.test("prices: minors 1, keystones 3 (rings 1-2) / 5 (rings 3-4), bridges 4", function()
		for _, n in S.nodes() do
			if not n.keystone then
				t.expect(n.medals).toBe(S.MINOR_MEDALS)
			elseif n.sector == "Bridge" then
				t.expect(n.medals).toBe(S.BRIDGE_MEDALS)
			elseif n.ring <= 2 then
				t.expect(n.medals).toBe(3)
			else
				t.expect(n.medals).toBe(5)
			end
		end
		-- the whole buyable tree is roughly the docs' 250 Medal track
		local total = 0
		for _, n in S.nodes() do
			if not n.soon then
				total += n.medals
			end
		end
		t.expect(total >= 200 and total <= 300).toBe(true)
	end)

	t.test("minor dots chain from the first need to the keystone", function()
		for _, k in S.nodes() do
			local minor = k.minor
			if k.keystone and minor then
				local from = if #k.needs > 0 then S.byId[k.needs[1]] else nil
				local fromRing = if from then from.ring else 0
				local fromAngle = if from then from.angle else k.angle
				local previous = if from then from.id else nil
				local expectedCount = math.clamp(math.ceil(k.ring), 2, 4)
				t.expect(minor.count).toBe(expectedCount)
				for i = 1, minor.count do
					local id = `{k.id}_m{i}`
					local m = S.byId[id]
					t.expect(m ~= nil).toBe(true)
					if m then
						t.expect(m.needs).toEqual(if previous then { previous } else {})
						t.expect(m.keystone).toBe(false)
						t.expect(m.soon).toBe(k.soon)
						t.expect(m.focus).toBe(k.focus)
						t.expect(m.sector).toBe(k.sector)
						t.expect(m.medals).toBe(1)
						t.expect(m.effect.kind).toBe(minor.kind)
						t.expect(m.effect.amount).toBe(minor.amount)
						local f = i / (minor.count + 1)
						t.expect(m.ring).toBeCloseTo(fromRing + (k.ring - fromRing) * f, 1e-9)
						local d = (k.angle - fromAngle + 540) % 360 - 180
						t.expect(m.angle).toBeCloseTo((fromAngle + d * f) % 360, 1e-9)
					end
					previous = id
				end
			end
		end
	end)

	t.test("canBuy: any one need, Medals, rim nodes refuse", function()
		t.expect({ S.canBuy({}, "Nope", 1e9) }).toEqual({ false, "Unknown" })
		t.expect({ S.canBuy({}, "Throttle", 2) }).toEqual({ false, "Medals" })
		t.expect({ S.canBuy({}, "Throttle", 3) }).toEqual({ true, nil })
		t.expect({ S.canBuy(owned({ "Throttle" }), "Throttle", 1e9) }).toEqual({ false, "Owned" })
		t.expect({ S.canBuy({}, "Nitro", 1e9) }).toEqual({ false, "Needs" })
		-- any one owned: Nitro needs LongReach or Grip
		t.expect({ S.canBuy(owned({ "LongReach" }), "Nitro", 1e9) }).toEqual({ true, nil })
		t.expect({ S.canBuy(owned({ "Grip" }), "Nitro", 1e9) }).toEqual({ true, nil })
		-- bridges cross sectors the same way
		t.expect({ S.canBuy(owned({ "Recruiter" }), "WelcomeHome", 4) }).toEqual({ true, nil })
		-- rim nodes are shown but never bought, even with every need owned
		local all = {}
		for _, n in S.nodes() do
			if not n.soon then
				all[n.id] = true
			end
		end
		t.expect({ S.canBuy(all, "StormRider", 1e9) }).toEqual({ false, "Soon" })
	end)

	t.test(
		"effects: totals for the readers, extra slots per K1 category, unknown ignored",
		function()
			local none = S.effects({})
			for _, kind in S.KINDS do
				t.expect(none[kind]).toBe(0)
			end
			t.expect(none.extraSlots).toEqual({})
			local captain = S.effects(owned({ "Throttle", "Fins", "LongReach", "Grip" }))
			t.expect(captain.speedMult).toBeCloseTo(0.04, 1e-9)
			t.expect(captain.swimMult).toBeCloseTo(0.2, 1e-9)
			t.expect(captain.reach).toBe(3)
			t.expect(captain.grip).toBeCloseTo(0.25, 1e-9)
			local mixed = S.effects(owned({
				"Ghost", -- unknown ids are ignored
				"FreshCatch",
				"MarketDay",
				"FreshCatch_m1",
			}))
			t.expect(mixed.gatherMult).toBeCloseTo(0.15 + 0.02, 1e-9)
			t.expect(mixed.extraSlots).toEqual({ Gatherer = 1 })
			t.expect(S.effects(owned({ "Bunks", "BigFamily" })).workerCapAdd).toBe(15)
		end
	)

	t.test("refund: the free reset hands back every owned node's Medals", function()
		t.expect(S.refund({})).toBe(0)
		local ids = { "Throttle", "Throttle_m1", "WelcomeHome" }
		local sum = 0
		for _, id in ids do
			sum += S.byId[id].medals
		end
		t.expect(S.refund(owned(ids))).toBe(sum)
	end)

	t.test("Medal earn helpers: 1 per 2 people rescued, a 1-3 daily chest", function()
		t.expect(S.rescueMedals(0, 1)).toBe(0)
		t.expect(S.rescueMedals(0, 2)).toBe(1)
		t.expect(S.rescueMedals(1, 3)).toBe(1)
		t.expect(S.rescueMedals(2, 4)).toBe(1)
		t.expect(S.rescueMedals(3, 3)).toBe(0)
		for streak = 0, 10 do
			local n = S.chestMedals(streak)
			t.expect(n >= 1 and n <= 3).toBe(true)
		end
		t.expect(S.chestMedals(1)).toBe(1)
		t.expect(S.chestMedals(2)).toBe(2)
		t.expect(S.chestMedals(3)).toBe(3)
		t.expect(S.chestMedals(4)).toBe(1)
	end)

	t.test("migration: old Cash nodes refund once and clear, new ids and Medals stay", function()
		local d = P.migrate({
			cash = 100,
			medals = 7,
			skills = { CaptSpeed1 = true, BuildBase = true, Throttle = true, Nope = true },
		})
		t.expect(d.cash).toBe(100 + 1000 + 6000)
		t.expect(d.medals).toBe(7)
		t.expect(d.skills.Throttle).toBe(true)
		t.expect(d.skills.CaptSpeed1).toBeNil()
		t.expect(d.skills.BuildBase).toBeNil()
		t.expect(d.skills.Nope).toBeNil()
		-- idempotent: migrate runs again whenever the profile is saved
		local again = P.migrate(d)
		t.expect(again.cash).toBe(d.cash)
		t.expect(again.skills.Throttle).toBe(true)
		-- a corrupt medals field resets
		t.expect(P.migrate({ medals = -3 }).medals).toBe(0)
		t.expect(P.migrate({ medals = "x" }).medals).toBe(0)
	end)
end
