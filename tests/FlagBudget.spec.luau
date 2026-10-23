-- FlagBudget: every retention system's fullest profile flag survives the save sanitiser
-- (ProgressionRules.migrate runs on every save and load), and all of them fit together.
return function(t)
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")
	local SeasonalRules = t.load("src/shared/SeasonalRules.luau")
	local SeasonalEvents = t.load("src/shared/Config/SeasonalEvents.luau")
	local IdleIncome = t.load("src/shared/IdleIncome.luau")
	local PetRules = t.load("src/shared/PetRules.luau")
	local PlatformPrompts = t.load("src/shared/PlatformPrompts.luau")

	local NOW = 1790000000

	local function full(): { [string]: any }
		local halloween = SeasonalRules.newState()
		halloween.candy = 999
		for _, item in SeasonalEvents.Halloween.items do
			halloween.owned[item.flag] = true
		end
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
		return {
			streak = StreakRules.flagTable({ lastDay = 20717, streak = 7, cosmeticDay = 20717 }),
			halloween = SeasonalRules.flagTable(halloween),
			station = IdleIncome.toFlag(
				{ workshop = 5, radio = 5, kennel = 5 },
				{ lastAt = NOW, cash = 50000 }
			),
			pets = PetRules.encode(pets),
			-- leftovers of cut systems (docs/16 C6, C15) still load
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

	t.test("an award never turns Cash or Rep into NaN, inf or a negative", function()
		for _, bad in { 0 / 0, math.huge, -math.huge, -50 } do
			local cash, rep = Rules.applyAward(bad, bad, "Calm", false)
			t.expect({ cash, rep }).toEqual({ 0, 0 })
		end
	end)
end
