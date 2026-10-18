-- RP-M5 Sea Shanty Radio: stations (src/shared/Config/Cosmetics/Radio.luau) and the playlist and
-- sync logic (src/shared/ShantyRadio.luau).
return function(t)
	local R = t.load("src/shared/ShantyRadio.luau")
	local Slot = t.load("src/shared/Config/Cosmetics/Radio.luau")
	local Cos = t.load("src/shared/Cosmetics.luau")

	local function option(id: string)
		for _, o in Slot.options do
			if o.id == id then
				return o
			end
		end
		error("no option " .. id)
	end

	t.test("the slot validates: Off is the free default, stations need SeaShantyRadio", function()
		t.expect(#Cos.build({ Slot }).validate()).toBe(0)
		t.expect(Slot.default).toBe("Off")
		t.expect(option("Off").pass).toBe(nil)
		t.expect(#R.tracks(option("Off"))).toBe(0)
		for _, id in { "Shanties", "Folk" } do
			local o = option(id)
			t.expect(o.pass).toBe("SeaShantyRadio")
			t.expect(#R.tracks(o) >= 6).toBe(true)
		end
	end)

	t.test("tracks are well formed and unique across stations", function()
		local seen = {}
		for _, o in Slot.options do
			for _, tr in R.tracks(o) do
				t.expect(type(tr.id) == "number" and tr.id > 0).toBe(true)
				t.expect(tr.length >= 30 and tr.length <= 600).toBe(true)
				t.expect(type(tr.title) == "string" and #tr.title > 0).toBe(true)
				t.expect(seen[tr.id]).toBe(nil)
				seen[tr.id] = true
			end
		end
	end)

	t.test("next wraps, steps back, and starts at the top for unknown ids", function()
		local o = option("Shanties")
		local list = R.tracks(o)
		t.expect(R.next(o, nil).id).toBe(list[1].id)
		t.expect(R.next(o, 999).id).toBe(list[1].id)
		t.expect(R.next(o, list[1].id).id).toBe(list[2].id)
		t.expect(R.next(o, list[#list].id).id).toBe(list[1].id)
		t.expect(R.next(o, list[1].id, -1).id).toBe(list[#list].id)
		t.expect(R.next(option("Off"), nil)).toBe(nil)
	end)

	t.test("RadioTrack attribute round trip, junk rejected", function()
		local s = R.parse(R.format("Folk", 1842715471, 12345.678))
		t.expect(s.station).toBe("Folk")
		t.expect(s.id).toBe(1842715471)
		t.expect(math.abs(s.startedAt - 12345.678) < 1e-6).toBe(true)
		t.expect(R.parse(nil)).toBe(nil)
		t.expect(R.parse(5)).toBe(nil)
		t.expect(R.parse("Folk:abc:1")).toBe(nil)
		t.expect(R.parse("Folk:1:2:3")).toBe(nil)
	end)

	t.test("position follows server time and ends after the track length", function()
		local s = { station = "Shanties", id = 1, startedAt = 100 }
		t.expect(R.position(s, 60, 100)).toBe(0)
		t.expect(R.position(s, 60, 130)).toBe(30)
		t.expect(R.position(s, 60, 90)).toBe(0)
		t.expect(R.position(s, 60, 160)).toBe(nil)
	end)

	t.test("ducked under the operation music, short range", function()
		t.expect(R.duck(false)).toBe(1)
		t.expect(R.duck(true) < 0.5).toBe(true)
		t.expect(R.ROLL_MAX <= 60 and R.ROLL_MIN < R.ROLL_MAX).toBe(true)
	end)
end
