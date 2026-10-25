-- FlagBudget: every retention system's fullest profile flag survives the save sanitiser
-- (ProgressionRules.migrate runs on every save and load), and all of them fit together.
return function(t)
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")
	local PetRules = t.load("src/shared/PetRules.luau")
	local PlatformPrompts = t.load("src/shared/PlatformPrompts.luau")
	local DiscoveryRules = t.load("src/shared/DiscoveryRules.luau")

	local NOW = 1790000000

	local function full(): { [string]: any }
		local pets = PetRules.newState()
		for i = 1, PetRules.MAX do
			table.insert(pets.entries, {
				id = i,
				species = "Seal",
				rare = true,
				at = NOW,
				bond = PetRules.BOND_MAX,
				adopted = true,
			})
		end
		pets.nextId = PetRules.MAX + 1
		pets.active = 1
		pets.treats = PetRules.TREAT_MAX
		local isles, fog = {}, DiscoveryRules.newFog()
		for _, page in DiscoveryRules.Pages do
			isles[page.id] = 2 ^ (#page.stickers + 2) - 1
		end
		buffer.fill(fog, 0, 1)
		return {
			streak = StreakRules.flagTable({ lastDay = 20717, streak = 7, cosmeticDay = 20717 }),
			pets = PetRules.encode(pets),
			isles = DiscoveryRules.encode(isles),
			fog = DiscoveryRules.encodeFog(fog),
			-- leftovers of cut systems (docs/16 C6, C15; WP-27 the hub fog) still load
			foghub = { f1 = string.rep("_", 64), f2 = string.rep("_", 64) },
			lighthouses = { HarbourLight = true, SkerryLight = true },
			stock = { paint_red = true, decor_signals = true },
			platformPrompts = PlatformPrompts.encode(
				PlatformPrompts.record(
					PlatformPrompts.record(PlatformPrompts.decode(nil), "notify", NOW),
					"favorite",
					NOW
				)
			),
		}
	end

	t.test("the removed station pot flag is dropped on load, the rest kept", function()
		local raw = Rules.defaultData()
		raw.flags = { station = { lv = 1, at = NOW, c = 500 }, notifyOptIn = true }
		local saved = Rules.migrate(raw)
		t.expect(saved.flags.station).toBeNil()
		t.expect(saved.flags.notifyOptIn).toBe(true)
	end)

	t.test("each system's fullest flag round-trips through the save sanitiser", function()
		local flags = full()
		local raw = Rules.defaultData()
		raw.flags = flags
		local saved = Rules.migrate(raw)
		for name, value in flags do
			t.expect({ name, saved.flags[name] }).toEqual({ name, value })
		end
	end)

	t.test("badge progress survives a save", function()
		local raw = Rules.defaultData() :: any
		raw.badgeCounters = { Rescues100 = 42 }
		raw.badgesAwarded = { FirstRescue = true }
		local saved = Rules.migrate(raw) :: any
		t.expect(saved.badgeCounters).toEqual({ Rescues100 = 42 })
		t.expect(saved.badgesAwarded).toEqual({ FirstRescue = true })
	end)

	t.test("an award never turns Cash into NaN, inf or a negative", function()
		for _, bad in { 0 / 0, math.huge, -math.huge, -50 } do
			t.expect((Rules.applyAward(bad, "Calm", false))).toBe(0)
		end
	end)
end
