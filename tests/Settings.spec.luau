-- Settings data model (shared/SettingsRules): cleaning, the Seasick-safe preset, the graphics
-- override, the audio mix, and a save/load round trip through ProgressionRules.
return function(t)
	local S = t.load("src/shared/SettingsRules.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")

	t.test("clean clamps numbers and rejects bad keys, types and choices", function()
		t.expect(S.clean("fov", 200)).toBe(95)
		t.expect(S.clean("fov", 10)).toBe(60)
		t.expect(S.clean("fov", 0 / 0)).toBeNil()
		t.expect(S.clean("fov", math.huge)).toBeNil()
		t.expect(S.clean("fov", "80")).toBeNil()
		t.expect(S.clean("volMusic", -1)).toBe(0)
		t.expect(S.clean("volMaster", 0.4)).toBe(0.4)
		t.expect(S.clean("nope", 1)).toBeNil()
		t.expect(S.clean("oceanQuality", "Low")).toBe("Low")
		t.expect(S.clean("oceanQuality", "Ultra")).toBeNil()
		t.expect(S.clean("voice", false)).toBe(false)
		t.expect(S.clean("pro", 1)).toBeNil()
	end)

	t.test(
		"accessibility settings: colour mode choices, text size clamp, motion and tap toggles",
		function()
			t.expect(S.clean("colourAssist", "Deuteranopia")).toBe("Deuteranopia")
			t.expect(S.clean("colourAssist", "Nope")).toBeNil()
			t.expect(S.clean("textSize", 125)).toBe(125)
			t.expect(S.clean("textSize", 400)).toBe(150)
			t.expect(S.clean("reduceMotion", true)).toBe(true)
			t.expect(S.clean("holdToTap", true)).toBe(true)
		end
	)

	t.test("every default is clean and the preset only uses known keys", function()
		for k, v in S.Defaults do
			t.expect(S.clean(k, v)).toBe(v)
		end
		for k, v in S.SEASICK do
			t.expect(S.clean(k, v)).toBe(v)
		end
		for _, k in S.COMFORT_KEYS do
			t.expect(S.Defaults[k] ~= nil).toBe(true)
		end
	end)

	t.test("seasick preset: level horizon, no bob, no FOV kick; detected after apply", function()
		t.expect(S.SEASICK.horizonStab).toBe(1)
		t.expect(S.SEASICK.headBob).toBe(0)
		t.expect(S.SEASICK.speedFov).toBe(false)
		local v = table.clone(S.Defaults)
		t.expect(S.isPreset(v, S.SEASICK)).toBe(false)
		for k, x in S.SEASICK do
			v[k] = x
		end
		t.expect(S.isPreset(v, S.SEASICK)).toBe(true)
		v.shake = 0.5
		t.expect(S.isPreset(v, S.SEASICK)).toBe(false)
	end)

	t.test("quality tier: override wins, Auto follows the slider and device", function()
		t.expect(S.qualityTier("Low", 10, false)).toBe("Low")
		t.expect(S.qualityTier("High", 1, true)).toBe("High")
		t.expect(S.qualityTier("Auto", nil, false)).toBe("High")
		t.expect(S.qualityTier("Auto", nil, true)).toBe("Medium")
		t.expect(S.qualityTier(nil, 2, false)).toBe("Low")
		t.expect(S.qualityTier("Auto", 5, false)).toBe("Medium")
		t.expect(S.qualityTier("Auto", 9, true)).toBe("High")
	end)

	t.test("audio mix: one volume per group; voice off mutes only the voice group", function()
		local v = table.clone(S.Defaults)
		v.volMaster, v.volSfx, v.volRadio, v.volMusic = 0.5, 0.8, 1, 0.4
		local m = S.mix(v)
		t.expect(m.Master).toBe(0.5)
		t.expect(m.SFX).toBe(0.8)
		t.expect(m.Ambience).toBe(0.8)
		t.expect(m.Radio).toBe(1)
		t.expect(m.Music).toBe(0.4)
		t.expect(m.Voice).toBe(1)
		v.voice = false
		v.volMusic = 0 / 0
		m = S.mix(v)
		t.expect(m.Voice).toBe(0)
		t.expect(m.Radio).toBe(1)
		t.expect(m.Music).toBe(1)
	end)

	t.test("all settings plus cinematic flags survive the profile flag sanitiser", function()
		local stored = table.clone(S.Defaults)
		stored.fov = 88
		stored.oceanQuality = "Low"
		stored.voice = false
		stored.seen_arrival = true
		stored.seen_launch = true
		stored.seen_storm = true
		local n = 0
		for _ in stored do
			n += 1
		end
		t.expect(n <= 32).toBe(true)
		local d = Rules.defaultData()
		d.flags.cameraSettings = stored
		local again = Rules.migrate(Rules.migrate(d)).flags.cameraSettings
		for k, v in stored do
			t.expect(again[k]).toBe(v)
		end
	end)
end
