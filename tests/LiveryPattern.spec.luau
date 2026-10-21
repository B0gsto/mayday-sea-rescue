-- G38 livery patterns: the code-made trim plan for each scheme (hull sides, tubes, deck).
return function(t)
	local P = t.load("src/shared/LiveryPattern.luau")

	local size = Vector3.new(8.7, 2.8, 25.2)

	t.test("every known pattern lays trim on both hull sides", function()
		for _, pattern in { "band", "twin", "stripes", "chevron", "glow", "lights" } do
			local specs = P.plan(pattern, "hull", size)
			t.expect(#specs >= 2).toBe(true)
			local left, right = 0, 0
			for _, s in specs do
				t.expect(math.abs(s.offset.X) > size.X / 2).toBe(true)
				if s.offset.X > 0 then
					right += 1
				else
					left += 1
				end
			end
			t.expect(left).toBe(right)
		end
	end)

	t.test("patterns are distinct: stripes, chevrons and glow differ", function()
		local stripes = P.plan("stripes", "hull", size)
		local chevrons = P.plan("chevron", "hull", size)
		local glow = P.plan("glow", "hull", size)
		t.expect(#stripes).toBe(6)
		t.expect(#chevrons).toBe(8)
		local yaws = 0
		for _, s in chevrons do
			if s.yaw ~= 0 then
				yaws += 1
			end
		end
		t.expect(yaws).toBe(8)
		local glows = 0
		for _, s in glow do
			if s.glow then
				glows += 1
			end
		end
		t.expect(glows).toBe(#glow)
	end)

	t.test("the deck gets a readable stripe / chevron plan", function()
		t.expect(#P.plan("band", "deck", size)).toBe(1)
		t.expect(#P.plan("stripes", "deck", size)).toBe(3)
		t.expect(#P.plan("chevron", "deck", size)).toBe(4)
		local tube = P.plan("glow", "tube", size)
		t.expect(#tube).toBe(2)
		t.expect(tube[1].glow).toBe(true)
	end)

	t.test("the festive lights pattern is a string of glowing dashes", function()
		t.expect(P.known("lights")).toBe(true)
		local hull = P.plan("lights", "hull", size)
		t.expect(#hull).toBe(28) -- two rows of seven on each side
		for _, s in hull do
			t.expect(s.glow).toBe(true)
			t.expect(s.size.Z > 0 and s.size.Z < size.Z / 2).toBe(true)
		end
		local deck = P.plan("lights", "deck", size)
		t.expect(#deck).toBe(10)
		for _, s in deck do
			t.expect(s.glow).toBe(true)
		end
	end)

	t.test("unknown patterns fall back to a band, nothing is trusted", function()
		t.expect(P.known("nope")).toBe(false)
		t.expect(#P.plan("nope", "hull", size)).toBe(#P.plan("band", "hull", size))
		t.expect(#P.plan(nil, "hull", size)).toBe(2)
	end)

	t.test("all plate sizes are positive", function()
		for _, surface in { "hull", "tube", "deck" } do
			for _, pattern in { "band", "twin", "stripes", "chevron", "glow", "lights" } do
				for _, s in P.plan(pattern, surface, size) do
					t.expect(s.size.X > 0 and s.size.Y > 0 and s.size.Z > 0).toBe(true)
				end
			end
		end
	end)
end
