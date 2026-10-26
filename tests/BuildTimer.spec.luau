-- BuildTimer (docs/24 B): work from the Cash price, decor flat, the Builders' rate (rarest BUILDERS, capped units),
-- progress/time-left arithmetic and the board's m:ss text.
return function(t)
	local B = t.load("src/shared/BuildTimer.luau")
	local W = t.load("src/shared/WorkerRules.luau")

	local function worker(category, rarity)
		return { category = category, rarity = rarity or 1, name = "A" }
	end

	t.test("work follows the Cash price, clamped; decor is 8 s", function()
		t.expect(B.work(1000)).toBeCloseTo(20, 1e-9)
		t.expect(B.work(10000)).toBeCloseTo(B.SCALE * 10 ^ B.POW, 1e-9)
		t.expect(B.work(40000)).toBeCloseTo(B.SCALE * 40 ^ B.POW, 1e-9)
		t.expect(B.work(0)).toBe(B.MIN)
		t.expect(B.work(1e9)).toBe(B.MAX)
		t.expect(B.work(40000, true)).toBe(B.DECOR)
	end)

	t.test("the rate is 1 + PER per Builder unit, the rarest BUILDERS only", function()
		t.expect(B.rate(0)).toBe(1)
		t.expect(B.rate(2.5)).toBeCloseTo(1 + B.PER * 2.5, 1e-9)
		t.expect(B.rate(B.BUILDERS) >= 1.6 and B.rate(B.BUILDERS) <= 2.5).toBe(true) -- a full crew ~halves a build
		local many = {}
		for i = 1, 12 do
			many[i] = worker("Builder", if i <= 2 then 3 else 1)
		end
		local picked = B.builders(many)
		t.expect(#picked).toBe(B.BUILDERS)
		t.expect(picked[1]).toBe(1)
		t.expect(picked[2]).toBe(2)
		t.expect(B.units(many)).toBeCloseTo(2 * W.RARITY_MULT[3] + B.BUILDERS - 2, 1e-9)
		local mixed = { worker("Gatherer", 3), worker("Builder", 2), worker("Builder", 1) }
		t.expect(B.builders(mixed)).toEqual({ 2, 3 })
		t.expect(B.rateOf(mixed)).toBeCloseTo(1 + B.PER * 2.5, 1e-9)
	end)

	t.test("the skill tree raises the builder count, rate and base crew", function()
		local many = {}
		for i = 1, 9 do
			many[i] = worker("Builder", 1)
		end
		t.expect(#B.builders(many, B.BUILDERS + 2)).toBe(B.BUILDERS + 2)
		local skill = B.rateOf(many, { max = B.BUILDERS + 2, mult = 1.3, crew = 1 })
		t.expect(skill).toBeCloseTo((1 + B.PER * (B.units(many, B.BUILDERS + 2) + 1)) * 1.3, 1e-9)
		t.expect(B.rateOf(many, { mult = 1.3 })).toBeCloseTo(B.rateOf(many) * 1.3, 1e-9)
	end)

	t.test("the finish tier follows the time left: 1 <= 60 s, 2 <= 300 s, 3 longer", function()
		t.expect(B.finishTier(0)).toBe(1)
		t.expect(B.finishTier(3)).toBe(1)
		t.expect(B.finishTier(60)).toBe(1)
		t.expect(B.finishTier(60.1)).toBe(2)
		t.expect(B.finishTier(300)).toBe(2)
		t.expect(B.finishTier(300.1)).toBe(3)
		t.expect(B.finishTier(B.MAX)).toBe(3)
	end)

	t.test("advance and timeLeft agree, clamped to 0..1", function()
		t.expect(B.advance(0, 2, 5, 20)).toBe(0.5)
		t.expect(B.advance(0.5, 2, 10, 20)).toBe(1)
		t.expect(B.advance(0.9, 1, -5, 20)).toBe(0.9)
		t.expect(B.timeLeft(0.5, 2, 20)).toBe(5)
		t.expect(B.timeLeft(1, 2, 20)).toBe(0)
		t.expect(B.timeLeft(0, 0, 20)).toBe(20 / 1e-3)
		t.expect(B.text(0)).toBe("0:00")
		t.expect(B.text(9.6)).toBe("0:10")
		t.expect(B.text(125)).toBe("2:05")
	end)
end
