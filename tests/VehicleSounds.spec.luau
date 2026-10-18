-- RP-M5 Horn Pack / Siren Pack (shared/VehicleSounds + Config/Cosmetics Horn, Siren): the real
-- configs validate and point at AudioConfig clips, horn / siren validation, cooldowns, siren
-- attributes and light pattern lookup, loop regions, and muting.
return function(t)
	local VS = t.load("src/shared/VehicleSounds.luau")
	local Horn = t.load("src/shared/Config/Cosmetics/Horn.luau")
	local Siren = t.load("src/shared/Config/Cosmetics/Siren.luau")
	local Audio = t.load("src/shared/Config/AudioConfig.luau")

	local function owns(set)
		return function(key: string): boolean
			return set[key] == true
		end
	end
	local function find(slot, id)
		for _, o in slot.options do
			if o.id == id then
				return o
			end
		end
		return nil
	end
	local function hornReq(over)
		local r = {
			hasVehicle = true,
			isDriver = true,
			kind = "Boat",
			option = find(Horn, "TugHorn"),
			owns = owns({ HornPack = true }),
			now = 10,
			readyAt = 0,
		}
		for k, v in over do
			r[k] = v
		end
		return r
	end

	t.test("Horn config: six pass horns with clips, free default without one", function()
		t.expect(#VS.validate(Horn, false)).toBe(0)
		t.expect(Horn.default).toBe("Standard")
		local pack = 0
		for _, o in Horn.options do
			if o.pass == "HornPack" then
				pack += 1
				t.expect(Audio.Clips[o.clip] ~= nil).toBe(true)
				t.expect(Audio.categoryOf(o.clip)).toBe("SFX")
				t.expect(string.find(Audio.Clips[o.clip].id, "^rbxassetid://%d+$") ~= nil)
					.toBe(true)
			end
		end
		t.expect(pack).toBe(6)
		t.expect(VS.playable(find(Horn, "Standard"))).toBe(false)
	end)

	t.test("Siren config: four tones, each with a known pattern and loop region", function()
		t.expect(#VS.validate(Siren, true)).toBe(0)
		local patterns = {}
		for _, o in Siren.options do
			if o.pass == "SirenPack" then
				t.expect(Audio.Clips[o.clip] ~= nil).toBe(true)
				table.insert(patterns, VS.patternOf(o))
			end
		end
		t.expect(patterns).toEqual({ "Wail", "Yelp", "HiLo", "Phaser" })
	end)

	t.test("validate catches broken options", function()
		local bad = {
			options = {
				{ id = "Free", name = "Free", clip = "Horn_Tug" },
				{ id = "NoClip", name = "x", pass = "SirenPack", label = "x", range = 100 },
				{
					id = "BadPattern",
					name = "x",
					pass = "SirenPack",
					clip = "c",
					label = "x",
					range = 100,
					pattern = "Rainbow",
					loopStart = 2,
					loopEnd = 2.1,
				},
			},
		}
		local problems = VS.validate(bad, true)
		t.expect(#problems >= 5).toBe(true)
	end)

	t.test("checkHorn: driver, kind, pack option, ownership, cooldown", function()
		t.expect(VS.checkHorn(hornReq({}))).toBe(true)
		local function reason(over)
			local _, r = VS.checkHorn(hornReq(over))
			return r
		end
		t.expect(reason({ hasVehicle = false })).toBe("no_vehicle")
		t.expect(reason({ isDriver = false })).toBe("not_driver")
		t.expect(reason({ kind = "Ferry" })).toBe("bad_kind")
		t.expect(reason({ kind = "JetSki" })).toBe("")
		t.expect(reason({ kind = "Car" })).toBe("")
		t.expect(reason({ option = find(Horn, "Standard") })).toBe("no_pack_option")
		t.expect(reason({ owns = owns({}) })).toBe("not_owned")
		t.expect(reason({ readyAt = 12 })).toBe("cooldown")
		t.expect(reason({ readyAt = 10 })).toBe("")
		for _, k in VS.PATTERNS do
			t.expect(type(k)).toBe("string")
		end
		for _, r in
			{
				"no_vehicle",
				"not_driver",
				"bad_kind",
				"no_pack_option",
				"not_owned",
				"cooldown",
				"no_tasking",
			}
		do
			t.expect(type(VS.Reasons[r])).toBe("string")
		end
	end)

	t.test("cooldowns: per key, horn length with a floor", function()
		local cd = VS.newCooldowns()
		t.expect(cd.ready("a", 0)).toBe(true)
		cd.mark("a", 5, VS.hornCooldown(find(Horn, "FerryHorn")))
		t.expect(cd.ready("a", 11.9)).toBe(false)
		t.expect(cd.ready("a", 12)).toBe(true)
		t.expect(cd.ready("b", 6)).toBe(true)
		t.expect(cd.readyAt("a")).toBe(12)
		cd.clear("a")
		t.expect(cd.readyAt("a")).toBe(0)
		t.expect(VS.hornCooldown(find(Horn, "CutterHorn"))).toBe(3)
		t.expect(VS.hornCooldown({ id = "x", name = "x", length = 0.5 })).toBe(VS.MIN_HORN_COOLDOWN)
		t.expect(VS.hornCooldown(nil)).toBe(VS.MIN_HORN_COOLDOWN)
	end)

	t.test("checkSiren: needs a tasking unless the rule is off", function()
		local base = {
			hasVehicle = true,
			isDriver = true,
			kind = "Car",
			option = find(Siren, "Yelp"),
			owns = owns({ SirenPack = true }),
			onTasking = true,
		}
		t.expect(VS.checkSiren(base)).toBe(true)
		base.onTasking = false
		local ok, r = VS.checkSiren(base)
		t.expect(ok).toBe(false)
		t.expect(r).toBe("no_tasking")
		base.requireTasking = false
		t.expect(VS.checkSiren(base)).toBe(true)
		base.owns = owns({ HornPack = true })
		local _, r2 = VS.checkSiren(base)
		t.expect(r2).toBe("not_owned")
	end)

	t.test("siren attributes and pattern lookup", function()
		local tone, pattern = VS.sirenAttributes(find(Siren, "HiLo"))
		t.expect(tone).toBe("HiLo")
		t.expect(pattern).toBe("HiLo")
		local t2, p2 = VS.sirenAttributes(find(Siren, "Phaser"))
		t.expect(t2).toBe("Phaser")
		t.expect(p2).toBe("Phaser")
		local off, offP = VS.sirenAttributes(nil)
		t.expect(off).toBe("")
		t.expect(offP).toBe("")
		local s, sp = VS.sirenAttributes(find(Siren, "Standard"))
		t.expect(s).toBe("")
		t.expect(sp).toBe("")
		t.expect(VS.patternOf({ id = "x", name = "x", pattern = "Strobe" })).toBe("")
	end)

	t.test("ranges clamp, loop regions validate, owners always hear their own", function()
		t.expect(VS.range(find(Horn, "ShipHorn"), 1)).toBe(700)
		t.expect(VS.range({ id = "x", name = "x", range = 5000 }, 1)).toBe(VS.RANGE_MAX)
		t.expect(VS.range(nil, 10)).toBe(VS.RANGE_MIN)
		local a, b = VS.loopRegion(find(Siren, "Wail"))
		t.expect(a).toBe(1.5)
		t.expect(b).toBe(9)
		t.expect(VS.loopRegion({ id = "x", name = "x", loopStart = 3, loopEnd = 3.2 })).toBeNil()
		t.expect(VS.audible(true, true)).toBe(true)
		t.expect(VS.audible(false, true)).toBe(false)
		t.expect(VS.audible(false, false)).toBe(true)
	end)
end
