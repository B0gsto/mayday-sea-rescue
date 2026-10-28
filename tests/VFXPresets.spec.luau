-- VFX presets (docs/26): every preset passes validation (job caps, fields, textures), bad ones fail, and the
-- quality / reduce-motion / distance scaler.
return function(t)
	local Presets = t.load("src/client/VFX/Presets.luau")
	local Textures = t.load("src/shared/Config/VFXTextures.luau")

	t.test("every preset is valid and within its job's particle cap", function()
		local n = 0
		for name, p in Presets.ALL do
			local ok, why = Presets.validate(p, Textures)
			if not ok then
				error(`{name}: {why}`)
			end
			n += 1
		end
		t.expect(n >= 9).toBe(true)
	end)

	t.test("every docs/26 moment has a preset", function()
		for _, name in
			{
				"build_done",
				"hq_levelup",
				"pickup_splash",
				"rescue_done",
				"golden_accept",
				"barge_moor",
				"wheel_spin",
				"wheel_win",
				"chimney_puff",
			}
		do
			t.expect(Presets.ALL[name] ~= nil).toBe(true)
		end
	end)

	t.test("over-cap, missing fields, unknown textures and bright feedback fail", function()
		local function layer(over)
			local l =
				{ tex = "puff_smoke", count = 10, colors = { Color3.new(1, 1, 1) }, size = { 1 } }
			l.lifetime, l.speed = { 1, 2 }, { 1, 2 }
			for k, v in over do
				l[k] = v
			end
			return l
		end
		t.expect(
			(Presets.validate({ job = "feedback", layers = { layer({ count = 41 }) } }, Textures))
		)
			.toBe(false)
		t.expect(
			(Presets.validate({ job = "spectacle", layers = { layer({ count = 120 }) } }, Textures))
		)
			.toBe(true)
		t.expect((Presets.validate({ job = "nope", layers = { layer({}) } }, Textures))).toBe(false)
		t.expect((Presets.validate({ job = "feedback", layers = {} }, Textures))).toBe(false)
		t.expect(
			(
				Presets.validate(
					{ job = "feedback", layers = { layer({ tex = "glitter" }) } },
					Textures
				)
			)
		).toBe(false)
		t.expect(
			(
				Presets.validate(
					{ job = "feedback", layers = { layer({ lifetime = { 2, 1 } }) } },
					Textures
				)
			)
		).toBe(false)
		t.expect(
			(
				Presets.validate(
					{ job = "feedback", layers = { layer({ emission = 0.6 }) } },
					Textures
				)
			)
		)
			.toBe(false)
		t.expect(
			(
				Presets.validate(
					{ job = "feedback", big = true, layers = { layer({ emission = 0.6 }) } },
					Textures
				)
			)
		).toBe(true)
	end)

	t.test("quality scales 0.3 .. 1, Automatic 0.75", function()
		t.expect(Presets.quality(10)).toBeCloseTo(1, 1e-9)
		t.expect(Presets.quality(1)).toBeCloseTo(0.3, 1e-9)
		t.expect(Presets.quality(0)).toBeCloseTo(0.75, 1e-9)
		t.expect(Presets.quality(99)).toBeCloseTo(1, 1e-9)
	end)

	t.test("count: quality, scale and reduce motion; one particle stays", function()
		t.expect(Presets.count(40, 1, 10, false)).toBe(40)
		t.expect(Presets.count(40, 1, 10, true)).toBe(20)
		t.expect(Presets.count(40, 0.5, 1, false)).toBe(6)
		t.expect(Presets.count(1, 1, 1, true)).toBe(1)
		t.expect(Presets.count(0, 1, 10, false)).toBe(0)
		t.expect(Presets.count(10, 0, 10, false)).toBe(0)
	end)

	t.test("distance cull at 250 studs", function()
		t.expect(Presets.visible(250)).toBe(true)
		t.expect(Presets.visible(251)).toBe(false)
	end)

	t.test("duration covers the latest delayed layer", function()
		t.expect(Presets.duration(Presets.ALL.barge_moor)).toBeCloseTo(1.9, 1e-9)
	end)

	t.test("FX1 curves: eased keypoints keep the ends, fit a NumberSequence and ease", function()
		local k = Presets.curve({ 2, 10, 4 }, "out")
		t.expect(#k <= 20).toBe(true)
		t.expect(k[1][1]).toBe(0)
		t.expect(k[1][2]).toBe(2)
		t.expect(k[#k][1]).toBe(1)
		t.expect(k[#k][2]).toBe(4)
		t.expect(k[2][2] > 2 + (10 - 2) * (k[2][1] / 0.5)).toBe(true) -- "out" is ahead of linear
		t.expect(#Presets.curve({ 1, 2 }, nil)).toBe(2)
		local back = Presets.curve({ 0, 1 }, "back")
		local peak = 0
		for _, kv in back do
			peak = math.max(peak, kv[2])
		end
		t.expect(peak > 1).toBe(true) -- overshoots, then settles on 1
		t.expect(Presets.duration(Presets.ALL.fx1_hq_levelup) >= 1.5).toBe(true) -- covers the pillar
	end)
end
