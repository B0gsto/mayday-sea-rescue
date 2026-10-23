-- RP-M5 E2 (shared/AvatarCosmetics + Config/Cosmetics Outfit / Cap / Badge): outfit planning over
-- the player's own look, the badge rules, the whistle cooldown and the roof-deck ladder gate.
return function(t)
	local AC = t.load("src/shared/AvatarCosmetics.luau")
	local Cos = t.load("src/shared/Cosmetics.luau")

	local base = {
		layers = { { id = 11, kind = "Jacket" }, { id = 12, kind = "Pants" } },
		shirt = 101,
		pants = 102,
		hats = { 201, 202 },
	}

	t.test("the free defaults keep the player's own look", function()
		local look = AC.plan(base, Cos.option("Outfit", "Station"), Cos.option("Cap", "None"))
		t.expect(AC.same(look, base)).toBe(true)
		t.expect(AC.same(AC.plan(base, nil, nil), base)).toBe(true)
	end)

	t.test(
		"an outfit replaces layered clothing and the classic shirt / pants, not the hats",
		function()
			local opt = Cos.option("Outfit", "FoulWeather")
			local look = AC.plan(base, opt, nil)
			t.expect(#look.layers).toBe(2)
			t.expect(look.layers[1].kind).toBe("Pants")
			t.expect(look.layers[2].kind).toBe("Jacket")
			t.expect(look.shirt).toBe(101) -- classic clothes stay under the layers
			t.expect(look.pants).toBe(102)
			t.expect(#look.hats).toBe(2)
			t.expect(base.layers[1].id).toBe(11) -- the base is not mutated
			t.expect(AC.same(look, base)).toBe(false)
		end
	)

	t.test("a cap replaces the hats only", function()
		local look = AC.plan(base, nil, Cos.option("Cap", "Skipper"))
		t.expect(#look.hats).toBe(1)
		t.expect(look.hats[1]).toBe(Cos.option("Cap", "Skipper").hat)
		t.expect(#look.layers).toBe(2)
		t.expect(look.shirt).toBe(101)
	end)

	t.test("outfit, cap and badge slots are real, priced and free by default", function()
		t.expect(#Cos.validate()).toBe(0)
		for _, slot in { "Outfit", "Cap", "Badge" } do
			local s = Cos.slot(slot)
			t.expect(s ~= nil).toBe(true)
			t.expect(Cos.option(slot, Cos.default(slot)).pass).toBeNil()
			for _, o in s.options do
				t.expect(o.stub).toBeNil()
			end
		end
		local ownsLocker = function(k: string): boolean
			return k == "CaptainsLocker"
		end
		t.expect(Cos.canEquip("Outfit", "Wetsuit", ownsLocker)).toBe(true)
		t.expect(Cos.canEquip("Outfit", "StormChaser", ownsLocker)).toBe(false)
		t.expect(#Cos.ownedOptions("Cap", ownsLocker)).toBe(4) -- own hat + three caps
		t.expect(table.find(Cos.slotsForPass("StormChaserLiveries"), "Outfit") ~= nil).toBe(true)
		t.expect(table.find(Cos.slotsForPass("VipCrewCard"), "Badge") ~= nil).toBe(true)
		for _, o in Cos.slot("Outfit").options do
			for _, l in o.layers or {} do
				t.expect(type(l.id) == "number" and l.id > 0).toBe(true)
			end
		end
	end)

	t.test("gold badge and radio tag", function()
		t.expect(AC.gold("Gold")).toBe(true)
		t.expect(AC.gold("Off")).toBe(false)
		t.expect(AC.gold(nil)).toBe(false)
		t.expect(AC.radioTag("Gold")).toBe("VIP")
		t.expect(AC.radioTag("Off")).toBeNil()
	end)

	t.test("whistle cooldown", function()
		t.expect(AC.whistleReady(nil, 10)).toBe(true)
		t.expect(AC.whistleReady(10, 11)).toBe(false)
		t.expect(AC.whistleReady(10, 10 + AC.WHISTLE.cooldown)).toBe(true)
	end)
end
