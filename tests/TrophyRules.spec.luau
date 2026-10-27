-- TrophyRules (docs/25 B): the Trophy Hall's plinth order: specials, Epic+ survivors (rarest, best trait, earliest),
-- wheel prizes (rarest first), then the milestone cups.
return function(t)
	local TrophyRules = t.load("src/shared/TrophyRules.luau")
	local SpinRules = t.load("src/shared/SpinRules.luau")

	local function w(name, rarity, trait, special)
		return {
			category = "Medic",
			rarity = rarity,
			name = name,
			trait = trait or "",
			special = special or "",
		}
	end

	local function names(items)
		local out = {}
		for _, it in items do
			table.insert(out, it.name)
		end
		return table.concat(out, ",")
	end

	t.test(
		"specials first, then Epic+ by rarity, best trait, earliest rescue; Rare and below stay off",
		function()
			local items = TrophyRules.items({
				w("Sam", 4, "Speedy"),
				w("Ava", 6, ""),
				w("Leo", 3, "Cheerful"),
				w("Big Lou", 5, "Strong", "BigLou"),
				w("Mia", 4, "Cheerful"),
				w("Finn", 5, "Lucky"),
				w("Isla", 4, "Speedy"),
			}, {}, {})
			t.expect(names(items)).toBe("Big Lou,Ava,Finn,Mia,Sam,Isla")
			t.expect(items[1].kind).toBe("survivor")
			t.expect(items[1].rarity).toBe(5)
			t.expect(items[1].category).toBe("Medic")
		end
	)

	t.test("then the wheel prizes rarest first, then the cups", function()
		local blue = { id = "a", rarity = "Rare", kind = "trail", name = "Blue", icon = "" }
		local galaxy = { id = "b", rarity = "Mythic", kind = "finish", name = "Galaxy", icon = "" }
		local items = TrophyRules.items(
			{ w("Sam", 4) },
			{ blue, galaxy },
			{ "First Rescue", "100 Rescues" }
		)
		t.expect(names(items)).toBe("Sam,Galaxy,Blue,First Rescue,100 Rescues")
		t.expect(items[2].kind).toBe("prize")
		t.expect(items[2].rarity).toBe(6)
		t.expect(items[4].kind).toBe("cup")
		t.expect(items[4].rarity).toBe(0)
	end)

	t.test("wheel prizes: the claimed finishes and trails and the grand boat", function()
		t.expect(#TrophyRules.wheelPrizes({})).toBe(0)
		local galaxy = SpinRules.prize("GalaxyFinish")
		local state = SpinRules.claim(SpinRules.newState(), galaxy)
		local got =
			TrophyRules.wheelPrizes({ spin = SpinRules.encode(state), spinBoat = "StormRunner" })
		t.expect(#got).toBe(2)
		t.expect(got[1].id).toBe("GalaxyFinish")
		t.expect(got[2].id).toBe("GrandBoat")
	end)
end
