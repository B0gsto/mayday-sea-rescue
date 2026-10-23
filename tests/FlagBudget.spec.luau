-- FlagBudget: every retention system's fullest profile flag survives the save sanitiser
-- (ProgressionRules.migrate runs on every save and load), and all of them fit together.
return function(t)
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local ChallengeRules = t.load("src/shared/ChallengeRules.luau")
	local RescueAlbum = t.load("src/shared/RescueAlbum.luau")
	local Variants = t.load("src/shared/Config/RescueVariants.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")
	local SeasonRules = t.load("src/shared/SeasonRules.luau")
	local PetRules = t.load("src/shared/PetRules.luau")
	local StockConfig = t.load("src/shared/Config/StockConfig.luau")
	local PlatformPrompts = t.load("src/shared/PlatformPrompts.luau")

	local NOW = 1790000000

	local function full(): { [string]: any }
		local album = RescueAlbum.newState()
		for kind, list in Variants.Kinds do
			album.paid[kind] = true
			for _, v in list do
				album.owned[v.id] = true
			end
		end
		local challenges = ChallengeRules.newState(1, NOW)
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
		local stock = {}
		for _, item in StockConfig.Items do
			if item.cosmetic then
				stock[item.cosmetic] = true
			end
		end
		return {
			album = RescueAlbum.flagTable(album),
			challenges = ChallengeRules.flagTable(challenges),
			streak = StreakRules.flagTable({ lastDay = 20717, streak = 7, cosmeticDay = 20717 }),
			season = SeasonRules.flagTable({
				id = "S1",
				xp = 99999,
				claimed = 2 ^ 30 - 1,
				seen = 3,
			}),
			pets = PetRules.encode(pets),
			lighthouses = { HarbourLight = true, SkerryLight = true },
			stock = stock,
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

	t.test("an award never turns Cash or Rep into NaN, inf or a negative", function()
		for _, bad in { 0 / 0, math.huge, -math.huge, -50 } do
			local cash, rep = Rules.applyAward(bad, bad, "Calm", false)
			t.expect({ cash, rep }).toEqual({ 0, 0 })
		end
	end)
end
