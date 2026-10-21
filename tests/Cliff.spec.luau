-- Cliff casualty: the Haven Head site, the route read from the world, and the haul rhythm.
return function(t)
	local CliffRules = t.load("src/shared/CliffRules.luau")

	t.test("the ledge sits at the foot of the Haven Head cliff, the anchor above it", function()
		local S = CliffRules.SITE
		t.expect(S.top.Y - S.foot.Y > 80).toBeTruthy()
		t.expect(CliffRules.flatDistance(S.anchor, S.top) < 30).toBeTruthy()
		t.expect(CliffRules.flatDistance(S.foot, S.anchor) < 120).toBeTruthy()
		t.expect(CliffRules.near(S.foot, S.foot, 0.01)).toBe(true)
		t.expect(CliffRules.near(S.foot + Vector3.new(40, 0, 0), S.foot, 34)).toBe(false)
	end)

	t.test("a boat alongside at the foot is the boat route; the top is the line", function()
		local foot = CliffRules.SITE.foot
		t.expect(CliffRules.routeFor(foot, 20)).toBe("boat")
		t.expect(CliffRules.routeFor(foot, nil)).toBe("line")
		t.expect(CliffRules.routeFor(foot, 200)).toBe("line")
		t.expect(CliffRules.routeFor(CliffRules.SITE.top, 20)).toBe("line")
	end)

	t.test("hauling alternates hands; the same hand again does not count", function()
		local h = CliffRules.newHaul(4, false)
		t.expect(CliffRules.pull(h, "L")).toBe(true)
		t.expect(CliffRules.pull(h, "L")).toBe(false)
		t.expect(h.done).toBe(1)
		t.expect(h.wrong).toBe(1)
		t.expect(CliffRules.pull(h, "R")).toBe(true)
		t.expect(CliffRules.pull(h, "L")).toBe(true)
		t.expect(CliffRules.pull(h, "R")).toBe(true)
		t.expect(CliffRules.complete(h)).toBe(true)
		t.expect(CliffRules.haulScore(h) < 1).toBe(true)
	end)

	t.test("a swell slips the line back; the haul still completes", function()
		local h = CliffRules.newHaul(10, true)
		local side = "L"
		for _ = 1, 30 do
			CliffRules.pull(h, side)
			side = if side == "L" then "R" else "L"
			if CliffRules.complete(h) then
				break
			end
		end
		t.expect(CliffRules.complete(h)).toBe(true)
		t.expect(h.slips > 0).toBe(true)
		t.expect(CliffRules.haulScore(h) < 1).toBe(true)
	end)

	t.test("the casualty counts as aboard only inside the boat's deck bounds", function()
		local hull = CFrame.new(10, 1, 20)
		local size = Vector3.new(4, 2, 10)
		t.expect(CliffRules.onDeck(Vector3.new(10, 1, 20), hull, size)).toBe(true)
		t.expect(CliffRules.onDeck(Vector3.new(11.5, 0, 23), hull, size)).toBe(true)
		t.expect(CliffRules.onDeck(Vector3.new(14, 1, 20), hull, size)).toBe(false) -- alongside
		t.expect(CliffRules.onDeck(Vector3.new(10, 1, 26), hull, size)).toBe(false) -- astern
		t.expect(CliffRules.onDeck(Vector3.new(10, 6, 20), hull, size)).toBe(false) -- above the deck

		local turned = CFrame.lookAt(Vector3.new(10, 1, 20), Vector3.new(20, 1, 20))
		t.expect(CliffRules.onDeck(turned:PointToWorldSpace(Vector3.new(0, 0, 4)), turned, size))
			.toBe(true)
		t.expect(CliffRules.onDeck(turned:PointToWorldSpace(Vector3.new(0, 0, 6)), turned, size))
			.toBe(false)
	end)

	t.test("carrying them to the boat scores on time, and a swell costs a quarter", function()
		t.expect(CliffRules.carryScore(0, false)).toBe(1)
		t.expect(CliffRules.carryScore(15, false)).toBeCloseTo(0.5, 1e-6)
		t.expect(CliffRules.carryScore(0, true)).toBeCloseTo(0.75, 1e-6)
		t.expect(CliffRules.carryScore(60, false)).toBe(0)
	end)
end
