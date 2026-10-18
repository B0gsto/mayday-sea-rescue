-- RP-M5 stream B light bars (shared/LightBarFlash + Config/Cosmetics/LightBar): the colour sets stay
-- clear of the docs/05 section 3.2 reserved signal colours, lamp layouts are mirror-symmetric, flash
-- patterns alternate halves at real LED rates, and the siren tones pick the matching pattern.
return function(t)
	local Flash = t.load("src/shared/LightBarFlash.luau")
	local Config = t.load("src/shared/Config/Cosmetics/LightBar.luau")

	local function option(id)
		for _, o in Config.options do
			if o.id == id then
				return o
			end
		end
		return nil
	end

	t.test("default is the free stock lighting and six paid sets exist", function()
		t.expect(Config.default).toBe("Stock")
		local stock = option("Stock")
		t.expect(stock.pass).toBe(nil)
		local paid = 0
		for _, o in Config.options do
			if o.pass then
				paid += 1
				t.expect(o.pass).toBe("LightBars")
				t.expect(Flash.isPattern(o.pattern)).toBe(true)
				for _, c in o.half do
					t.expect(Config.colors[c] ~= nil).toBe(true)
				end
			end
		end
		t.expect(paid).toBe(6)
	end)

	t.test("no colour uses a reserved signal colour", function()
		for name, c in Config.colors do
			local clash = Flash.reservedClash(c)
			if clash then
				error(`{name} clashes with {clash}`)
			end
		end
		t.expect(Flash.reservedClash(Color3.fromRGB(255, 40, 30))).toBe("DistressRed")
		t.expect(Flash.reservedClash(Color3.fromRGB(255, 100, 0))).toBe("HullOrange")
	end)

	t.test("layouts are symmetric and cover every colour of the set", function()
		for _, o in Config.options do
			if o.half then
				for _, n in { 2, 4, 6, 8 } do
					local lamps = Flash.layout(o, n)
					t.expect(#lamps).toBe(n)
					for i = 1, n do
						t.expect(lamps[i].color).toBe(lamps[n + 1 - i].color)
						t.expect(lamps[i].side).toBe(if i <= n / 2 then 1 else 2)
					end
				end
				local seen = {}
				for _, l in Flash.layout(o, 4) do
					seen[l.color] = true
				end
				for _, c in o.half do
					t.expect(seen[c]).toBe(true)
				end
			end
		end
		local beacon = Flash.layout(option("Amber"), 1)
		t.expect(#beacon).toBe(1)
		t.expect(beacon[1].color).toBe("Amber")
		local work = Flash.layout(option("WorkAmber"), 4)
		t.expect(work[2].steady).toBe(true)
		t.expect(work[1].steady).toBe(false)
	end)

	t.test("lamp counts follow the bar width", function()
		t.expect(Flash.lampCount(0.9)).toBe(2)
		t.expect(Flash.lampCount(2.08)).toBe(4)
		t.expect(Flash.lampCount(4.3)).toBe(8)
		t.expect(Flash.lampCount(20)).toBe(8)
	end)

	-- Sample a side over two seconds at 1 ms: flashes per second and whether the halves overlap.
	local function sample(pattern)
		local flashes, prev, overlap = { 0, 0 }, { false, false }, false
		for ms = 0, 1999 do
			local tt = ms / 1000
			local l, r = Flash.sideOn(pattern, tt, 1), Flash.sideOn(pattern, tt, 2)
			if l and r then
				overlap = true
			end
			for s, on in { l, r } do
				if on and not prev[s] then
					flashes[s] += 1
				end
				prev[s] = on
			end
		end
		return flashes, overlap
	end

	t.test("flash patterns alternate halves at real LED rates", function()
		for _, p in { "Alternate", "SlowAlternate", "FastAlternate", "WigWag", "QuadFlash" } do
			local flashes, overlap = sample(p)
			t.expect(overlap).toBe(false)
			t.expect(flashes[1] >= 2 and flashes[1] <= 12).toBe(true) -- 1 to 6 per second
			t.expect(flashes[2] >= 2 and flashes[2] <= 12).toBe(true)
		end
		t.expect((sample("Alternate"))[1]).toBe(6) -- double flash at 1.5 Hz
		t.expect(Flash.sideOn("Steady", 0.42, 2)).toBe(true)
		local inv = { color = "White", side = 1, invert = true, steady = false }
		local norm = { color = "Blue", side = 2, invert = false, steady = false }
		for ms = 0, 700, 7 do
			t.expect(Flash.lampOn("Alternate", ms / 1000, inv))
				.toBe(Flash.lampOn("Alternate", ms / 1000, norm))
		end
	end)

	t.test("siren tones pick their light pattern", function()
		t.expect(Flash.patternFor("Alternate", true, "Wail")).toBe("SlowAlternate")
		t.expect(Flash.patternFor("Alternate", true, "Yelp")).toBe("FastAlternate")
		t.expect(Flash.patternFor("Alternate", true, "HiLo")).toBe("WigWag")
		t.expect(Flash.patternFor("Alternate", true, "Phaser")).toBe("QuadFlash")
		t.expect(Flash.patternFor("QuadFlash", false, "Wail")).toBe("QuadFlash")
		t.expect(Flash.patternFor("Alternate", true, "Unknown")).toBe("Alternate")
		t.expect(Flash.patternFor(nil, false, nil)).toBe("Alternate")
	end)
end
