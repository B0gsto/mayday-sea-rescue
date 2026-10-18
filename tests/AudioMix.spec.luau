-- AudioMix and AudioConfig: engine layering by RPM, wind and sea beds by storm, hull impacts,
-- and the config's ids and categories.
return function(t)
	local AudioMix = t.require("Audio/AudioMix")
	local AudioConfig = t.require("Config/AudioConfig")

	t.test("crossfade is equal power", function()
		for i = 0, 10 do
			local a, b = AudioMix.crossfade(i / 10)
			t.expect(a * a + b * b).toBeCloseTo(1, 1e-9)
		end
		local a0, b0 = AudioMix.crossfade(0)
		t.expect(a0).toBeCloseTo(1, 1e-9)
		t.expect(b0).toBeCloseTo(0, 1e-9)
	end)

	t.test("boat rpm idles, follows the throttle and flares when airborne", function()
		t.expect(AudioMix.boatTargetRpm(0, 0, 1)).toBeCloseTo(AudioMix.IDLE_RPM, 1e-9)
		local holeShot = AudioMix.boatTargetRpm(1, 0, 1)
		local flatOut = AudioMix.boatTargetRpm(1, 1, 1)
		t.expect(holeShot > 0.6).toBeTruthy()
		t.expect(flatOut).toBeCloseTo(1, 1e-9)
		local airborne = AudioMix.boatTargetRpm(0.8, 0.5, 0)
		t.expect(airborne > AudioMix.boatTargetRpm(0.8, 0.5, 1)).toBeTruthy()
		t.expect(airborne <= 1).toBeTruthy()
		-- coasting at speed with the throttle shut is near idle
		t.expect(AudioMix.boatTargetRpm(0, 1, 1) < 0.35).toBeTruthy()
	end)

	t.test("rpm rises faster than it falls and never overshoots", function()
		local up = AudioMix.followRpm(0.2, 1, 0.1)
		local down = AudioMix.followRpm(1, 0.2, 0.1)
		t.expect(up - 0.2 > 1 - down).toBeTruthy()
		local r = 0.2
		for _ = 1, 200 do
			r = AudioMix.followRpm(r, 0.9, 1 / 60)
			t.expect(r <= 0.9 + 1e-9).toBeTruthy()
		end
		t.expect(r).toBeCloseTo(0.9, 1e-3)
	end)

	t.test("engine layers hand over from low to high with rising pitch", function()
		local idle = AudioMix.engineLayers(AudioMix.IDLE_RPM, 0)
		local top = AudioMix.engineLayers(1, 1)
		t.expect(idle.low > 0.6 and idle.high < 1e-6).toBeTruthy()
		t.expect(top.high > 0.9 and top.low < 1e-6).toBeTruthy()
		local prev = AudioMix.engineLayers(0, 0.5)
		for i = 1, 20 do
			local l = AudioMix.engineLayers(i / 20, 0.5)
			t.expect(l.lowPitch >= prev.lowPitch).toBeTruthy()
			t.expect(l.highPitch >= prev.highPitch).toBeTruthy()
			t.expect(l.high >= prev.high - 1e-9).toBeTruthy()
			prev = l
		end
	end)

	t.test("car engine: idle layer at idle, load layer and higher pitch near redline", function()
		local i1, l1, p1 = AudioMix.carEngine(750, 750, 4000, 0)
		local i2, l2, p2 = AudioMix.carEngine(3800, 750, 4000, 1)
		t.expect(i1 > l1).toBeTruthy()
		t.expect(l2 > i2).toBeTruthy()
		t.expect(p2 > p1).toBeTruthy()
	end)

	t.test(
		"wind rises with the storm: gale only in a storm, apparent wind adds a breeze",
		function()
			local calm = AudioMix.wind(0, 0)
			local storm = AudioMix.wind(1, 0)
			t.expect(calm.gale).toBe(0)
			t.expect(calm.light > 0.4).toBeTruthy()
			t.expect(storm.gale > 0.9).toBeTruthy()
			t.expect(storm.gale > calm.gale and storm.strong >= 0).toBeTruthy()
			local fast = AudioMix.wind(0, 70)
			t.expect(fast.strong > calm.strong).toBeTruthy()
			t.expect(fast.gale < 0.2).toBeTruthy()
			for i = 0, 20 do
				local w = AudioMix.wind(i / 20, 30)
				for _, v in { w.light, w.strong, w.gale } do
					t.expect(v >= 0 and v <= 1).toBeTruthy()
				end
			end
		end
	)

	t.test(
		"sea beds: harbour lap when sheltered, storm surf in a storm, silent far above",
		function()
			local harbour = AudioMix.sea(0, 1, 1)
			t.expect(harbour.harbour > harbour.open and harbour.storm == 0).toBeTruthy()
			local open = AudioMix.sea(0, 0, 1)
			t.expect(open.open).toBeCloseTo(1, 1e-9)
			local storm = AudioMix.sea(1, 0, 1)
			t.expect(storm.storm).toBeCloseTo(1, 1e-9)
			t.expect(storm.open).toBeCloseTo(0, 1e-9)
			local high = AudioMix.sea(1, 0, AudioMix.nearness(500, 70))
			t.expect(high.storm + high.open + high.harbour).toBe(0)
			t.expect(AudioMix.nearness(-2, 70)).toBe(0)
			t.expect(AudioMix.nearness(35, 70)).toBeCloseTo(0.5, 1e-9)
		end
	)

	t.test(
		"hull: slams above the threshold, louder and lower when harder; water loops by speed",
		function()
			local v0 = AudioMix.slam(2, 4)
			t.expect(v0).toBe(nil)
			local v1, p1 = AudioMix.slam(5, 4)
			local v2, p2 = AudioMix.slam(30, 4)
			t.expect((v2 :: number) > (v1 :: number)).toBeTruthy()
			t.expect((p2 :: number) < (p1 :: number)).toBeTruthy()
			t.expect((v2 :: number) <= 1).toBeTruthy()
			local lap, wash, wake = AudioMix.hullWater(0, 0)
			t.expect(lap).toBe(1)
			t.expect(wash + wake).toBe(0)
			local lap2, _, wake2 = AudioMix.hullWater(0.9, 1)
			t.expect(lap2).toBe(0)
			t.expect(wake2 > 0.9).toBeTruthy()
		end
	)

	t.test("gulls hush and the bell rings faster as the storm builds", function()
		t.expect(AudioMix.gullChance(0)).toBe(1)
		t.expect(AudioMix.gullChance(0.8)).toBe(0)
		t.expect(AudioMix.bellGap(1, 3, 9, 0.5) < AudioMix.bellGap(0, 3, 9, 0.5)).toBeTruthy()
		t.expect(AudioMix.gap(3, 9, 0)).toBe(3)
		t.expect(AudioMix.gap(3, 9, 1)).toBe(9)
	end)

	t.test("config: every clip has an asset id, a volume and a category", function()
		local n = 0
		for name, clip in AudioConfig.Clips do
			n += 1
			t.expect(string.match(clip.id, "^rbxassetid://%d+$") ~= nil).toBeTruthy()
			if clip.fallback then
				t.expect(string.match(clip.fallback, "^rbxassetid://%d+$") ~= nil).toBeTruthy()
			end
			t.expect(clip.source == "RL" or clip.source == "FS").toBeTruthy()
			if clip.source == "FS" then
				t.expect(clip.fallback ~= nil).toBeTruthy() -- uploads need an RL stand-in
			end
			t.expect(clip.volume > 0 and clip.volume <= 1).toBeTruthy()
			t.expect(table.find(AudioConfig.Categories, AudioConfig.categoryOf(name)) ~= nil)
				.toBeTruthy()
		end
		t.expect(n > 30).toBeTruthy()
		t.expect(AudioConfig.categoryOf("Music_Debrief")).toBe("Music")
		t.expect(AudioConfig.categoryOf("Radio_Static")).toBe("Radio")
		t.expect(AudioConfig.categoryOf("Wind_Gale")).toBe("Ambience")
		t.expect(AudioConfig.categoryOf("Eng_RIB_Idle")).toBe("SFX")
		t.expect(AudioConfig.categoryOf("UI_Click")).toBe("SFX")
		for _, cat in AudioConfig.Categories do
			local v = AudioConfig.DefaultVolumes[cat]
			t.expect(v ~= nil and v >= 0 and v <= 1).toBeTruthy()
		end
	end)
end
