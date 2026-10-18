-- RP-M5 cosmetics spine (shared/Cosmetics): the slot configs load and validate, equip rules,
-- sanitising a saved table, owned options, cycling, the pass <-> slot index, and the profile field
-- round trip through ProgressionRules.
return function(t)
	local Cos = t.load("src/shared/Cosmetics.luau")
	local Config = t.load("src/shared/Config/MonetizationConfig.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")

	local function ownsNone(_: string): boolean
		return false
	end
	local function ownsOnly(...)
		local set = {}
		for _, k in { ... } do
			set[k] = true
		end
		return function(key: string): boolean
			return set[key] == true
		end
	end
	local function ownsAll(_: string): boolean
		return true
	end

	local fixture = Cos.build({
		{
			slot = "Horn",
			options = {
				{ id = "Standard", name = "Standard" },
				{ id = "Air", name = "Air horn", pass = "HornPack" },
				{ id = "Ship", name = "Ship horn", pass = "HornPack" },
			},
			default = "Standard",
		},
		{ -- a file returning several slots (DogWear split)
			{
				slot = "DogCoat",
				options = {
					{ id = "None", name = "None" },
					{ id = "Oilskin", name = "Oilskin", pass = "BosunsWardrobe" },
				},
				default = "None",
			},
			{
				slot = "DogBandana",
				options = {
					{ id = "None", name = "None" },
					{ id = "Red", name = "Red", pass = "BosunsWardrobe" },
				},
				default = "None",
			},
		},
		{
			slot = "Livery",
			options = {
				{ id = "Standard", name = "Standard" },
				{ id = "Orange", name = "Station Orange", pass = "StarterKit" },
				{ id = "Storm", name = "Storm Chaser", pass = "StormChaserLiveries" },
			},
			default = "Standard",
		},
	})

	t.test("the real slot configs load, validate and use real game passes", function()
		t.expect(#Cos.validate()).toBe(0)
		local slots = Cos.slots()
		for _, want in
			{ "Horn", "Siren", "LightBar", "Wake", "Radio", "Dog", "Outfit", "Livery", "Badge" }
		do
			t.expect(table.find(slots, want) ~= nil).toBe(true)
		end
		t.expect(table.find(slots, "DogWear") ~= nil or table.find(slots, "DogCoat") ~= nil)
			.toBe(true)
		for _, slot in slots do
			local d = Cos.default(slot)
			t.expect(d ~= nil).toBe(true)
			t.expect(Cos.option(slot, d).pass).toBeNil()
			t.expect(#Cos.passesForSlot(slot) > 0).toBe(true)
			for _, pass in Cos.passesForSlot(slot) do
				t.expect(Config.GamePasses[pass] ~= nil).toBe(true)
			end
		end
		t.expect(Cos.default("Dog")).toBe("Bosun")
		t.expect(Cos.attribute("Horn")).toBe("Cos_Horn")
	end)

	t.test("every pass named by the brief maps to its slots", function()
		local function has(pass, slot)
			t.expect(table.find(Cos.slotsForPass(pass), slot) ~= nil).toBe(true)
		end
		has("HornPack", "Horn")
		has("SirenPack", "Siren")
		has("LightBars", "LightBar")
		has("WakeTrails", "Wake")
		has("SeaShantyRadio", "Radio")
		has("WaterDogFriends", "Dog")
		has("CaptainsLocker", "Outfit")
		has("StormChaserLiveries", "Outfit")
		has("StormChaserLiveries", "Livery")
		has("StarterKit", "Livery")
		has("VipCrewCard", "Livery")
		has("VipCrewCard", "Badge")
		t.expect(#Cos.slotsForPass("DoubleCash")).toBe(0)
		t.expect(#Cos.slotsForPass("BosunsWardrobe") > 0).toBe(true)
	end)

	t.test("a config file may return a list of slots; order follows SLOT_ORDER", function()
		t.expect(#fixture.validate()).toBe(0)
		local slots = fixture.slots()
		t.expect(#slots).toBe(4)
		t.expect(slots[1]).toBe("Livery")
		t.expect(slots[2]).toBe("Horn")
		t.expect(fixture.option("DogCoat", "Oilskin").pass).toBe("BosunsWardrobe")
		t.expect(fixture.slotsForPass("BosunsWardrobe")[1]).toBe("DogCoat")
		t.expect(#fixture.slotsForPass("BosunsWardrobe")).toBe(2)
	end)

	t.test("canEquip: free always, paid only when owned, unknown never", function()
		t.expect(fixture.canEquip("Horn", "Standard", ownsNone)).toBe(true)
		t.expect(fixture.canEquip("Horn", "Air", ownsNone)).toBe(false)
		t.expect(fixture.canEquip("Horn", "Air", ownsOnly("HornPack"))).toBe(true)
		t.expect(fixture.canEquip("Horn", "Nope", ownsAll)).toBe(false)
		t.expect(fixture.canEquip("Nope", "Standard", ownsAll)).toBe(false)
		t.expect(fixture.canEquip("Horn", 5 :: any, ownsAll)).toBe(false)
	end)

	t.test("sanitize fills every slot and falls back to the default when not owned", function()
		local out = fixture.sanitize(
			{ Horn = "Air", Livery = "Storm", Junk = "x", DogCoat = 3 },
			ownsOnly("HornPack")
		)
		t.expect(out.Horn).toBe("Air")
		t.expect(out.Livery).toBe("Standard")
		t.expect(out.DogCoat).toBe("None")
		t.expect(out.DogBandana).toBe("None")
		t.expect(out.Junk).toBeNil()
		local empty = fixture.sanitize(nil, ownsAll)
		t.expect(empty.Horn).toBe("Standard")
		local real = Cos.sanitize("garbage", ownsNone)
		for _, slot in Cos.slots() do
			t.expect(real[slot]).toBe(Cos.default(slot))
		end
	end)

	t.test("ownedOptions and ownsSlot", function()
		t.expect(#fixture.ownedOptions("Horn", ownsNone)).toBe(1)
		t.expect(#fixture.ownedOptions("Horn", ownsOnly("HornPack"))).toBe(3)
		t.expect(#fixture.ownedOptions("Nope", ownsAll)).toBe(0)
		t.expect(fixture.ownsSlot("Livery", ownsNone)).toBe(false)
		t.expect(fixture.ownsSlot("Livery", ownsOnly("StarterKit"))).toBe(true)
		local opts = fixture.ownedOptions("Livery", ownsOnly("StarterKit"))
		t.expect(#opts).toBe(2)
		t.expect(opts[2].id).toBe("Orange")
	end)

	t.test("cycle walks the equippable options and wraps", function()
		local owns = ownsOnly("HornPack")
		t.expect(fixture.cycle("Horn", "Standard", owns, 1)).toBe("Air")
		t.expect(fixture.cycle("Horn", "Ship", owns, 1)).toBe("Standard")
		t.expect(fixture.cycle("Horn", "Standard", owns, -1)).toBe("Ship")
		t.expect(fixture.cycle("Horn", "Lost", owns, 1)).toBe("Standard")
		t.expect(fixture.cycle("Livery", "Standard", ownsOnly("StormChaserLiveries"), 1))
			.toBe("Storm")
		t.expect(fixture.cycle("Nope", "x", owns, 1)).toBeNil()
	end)

	t.test("validate catches bad configs", function()
		local bad = Cos.build({
			{ slot = "A", options = { { id = "x", name = "X", pass = "P" } }, default = "x" },
			{
				slot = "B",
				options = { { id = "y", name = "Y" }, { id = "y", name = "Y2" } },
				default = "z",
			},
			{ slot = "A", options = {}, default = "q" },
			{ nope = true },
		})
		local problems = bad.validate()
		t.expect(#problems >= 4).toBe(true)
	end)

	t.test("the cosmetics profile field survives a save round trip and drops junk", function()
		local d = Rules.defaultData()
		t.expect(type(d.cosmetics)).toBe("table")
		d.cosmetics.Horn = "AirHorn"
		d.cosmetics[5] = "x"
		d.cosmetics.Livery = { nested = true }
		local back = Rules.migrate(d)
		t.expect(back.cosmetics.Horn).toBe("AirHorn")
		t.expect(back.cosmetics[5]).toBeNil()
		t.expect(back.cosmetics.Livery).toBeNil()
		t.expect(type(Rules.migrate({}).cosmetics)).toBe("table")
	end)
end
