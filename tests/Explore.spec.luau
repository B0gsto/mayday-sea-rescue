-- Explore: the logbook rules (Discovery) and snorkelling / duck dives (Snorkel).
return function(t)
	local Discovery = t.require("Explore/Discovery")
	local Snorkel = t.require("Explore/Snorkel")
	local WATER = { seated = false, inWater = true }
	local BOAT = { seated = true, inWater = false }
	local FOOT = { seated = false, inWater = false }

	t.test(
		"every POI and the Harbour Light history is an entry with a page and a reward",
		function()
			local ids = {}
			for _, e in Discovery.Entries do
				ids[e.id] = true
				t.expect(Discovery.page(e.page) ~= nil).toBe(true)
				t.expect(e.reward > 0).toBe(true)
			end
			for _, id in
				{
					"Morwenna",
					"AdmiraltyAnchor",
					"NedsGully",
					"HavenHead",
					"HavenSandsRockPools",
					"HarbourLightHistory",
				}
			do
				t.expect(ids[id]).toBe(true)
			end
			t.expect(Discovery.get("Morwenna").reward).toBe(250)
			t.expect(Discovery.get("HarbourLightHistory").reward).toBe(150)
			t.expect(Discovery.get("HavenHead").reward).toBe(100)
		end
	)

	t.test("a wreck is reached snorkelling over it, not from a boat or far away", function()
		local m = Discovery.get("Morwenna")
		local above = Vector3.new(m.position.X, -1.5, m.position.Z)
		t.expect(Discovery.reached(m, above, WATER)).toBe(true)
		t.expect(Discovery.reached(m, above, BOAT)).toBe(false)
		t.expect(Discovery.reached(m, above + Vector3.new(150, 0, 0), WATER)).toBe(false)
		-- along the hull (local Z at yaw 28): 40 studs from the middle is still over the wreck
		local a = math.rad(m.yaw)
		local alongHull = above + Vector3.new(math.sin(a), 0, math.cos(a)) * 40
		t.expect(Discovery.reached(m, alongHull, WATER)).toBe(true)
		-- across the hull the same 40 studs is beyond beam/2 + pad
		local acrossHull = above + Vector3.new(math.cos(a), 0, -math.sin(a)) * 40
		t.expect(Discovery.reached(m, acrossHull, WATER)).toBe(false)
	end)

	t.test("the gully follows the terrain's yaw convention along its whole length", function()
		local g = Discovery.get("NedsGully")
		local a = math.rad(g.yaw)
		local p = Vector3.new(g.position.X, -2, g.position.Z)
			+ Vector3.new(math.cos(a), 0, math.sin(a)) * 120
		t.expect(Discovery.reached(g, p, WATER)).toBe(true)
		local off = Vector3.new(g.position.X, -2, g.position.Z)
			+ Vector3.new(-math.sin(a), 0, math.cos(a)) * 80
		t.expect(Discovery.reached(g, off, WATER)).toBe(false)
	end)

	t.test("the viewpoint needs the player on foot at the top", function()
		local v = Discovery.get("HavenHead")
		t.expect(Discovery.reached(v, v.position + Vector3.new(10, 3, 0), FOOT)).toBe(true)
		t.expect(Discovery.reached(v, v.position + Vector3.new(10, 3, 0), BOAT)).toBe(false)
		t.expect(Discovery.reached(v, Vector3.new(v.position.X, 0, v.position.Z), FOOT)).toBe(false)
	end)

	t.test("logging pays once; a page pays only at its launch count", function()
		local found = {}
		local a = Discovery.log(found, "Morwenna")
		t.expect(a.cash).toBe(250)
		t.expect(#a.pages).toBe(0)
		t.expect(Discovery.log(found, "Morwenna")).toBe(nil)
		t.expect(Discovery.log(found, "NoSuchThing")).toBe(nil)
		local got, configured, target = Discovery.pageProgress(found, "Wrecks")
		t.expect(got).toBe(1)
		t.expect(configured >= 1).toBe(true)
		t.expect(target).toBe(7)
		-- every MVP entry together pays a small, finite sum and completes no page yet
		local total = Discovery.totalCash()
		t.expect(total > 0 and total < 15000).toBe(true)
	end)

	t.test("the found set round-trips through profile flags in chunks", function()
		local found = {}
		for _, e in Discovery.Entries do
			found[e.id] = true
		end
		found.Bogus = true
		local flags = Discovery.encode(found)
		for name, chunk in flags do
			t.expect(string.sub(name, 1, 7)).toBe("logbook")
			local n = 0
			for _ in chunk do
				n += 1
			end
			t.expect(n <= Discovery.CHUNK).toBe(true)
		end
		flags.other = { Morwenna = true }
		local back = Discovery.decode(flags)
		t.expect(back.Bogus).toBe(nil)
		for _, e in Discovery.Entries do
			t.expect(back[e.id]).toBe(true)
		end
		t.expect(next(Discovery.decode(nil))).toBe(nil)
	end)

	t.test("swimming starts only in water deeper than wading", function()
		t.expect(Snorkel.shouldSwim(-2, 0, -10, false)).toBe(true)
		t.expect(Snorkel.shouldSwim(-2, 0, -3, false)).toBe(false) -- wading
		t.expect(Snorkel.shouldSwim(1, 0, -10, false)).toBe(false) -- above the surface
		t.expect(Snorkel.shouldSwim(0.5, 0, -10, true)).toBe(true) -- bobbing on a crest keeps swimming
	end)

	t.test(
		"the float spring holds the eye at the surface and dips the mask when looking down",
		function()
			t.expect(Snorkel.verticalVelocity("surface", Snorkel.SURFACE_EYE, 0, -20, 0, 0))
				.toBeCloseTo(0, 1e-9)
			t.expect(Snorkel.verticalVelocity("surface", -3, 0, -20, 0, 0) > 0).toBe(true)
			t.expect(Snorkel.floatEye(-0.9)).toBe(Snorkel.FACE_DOWN_EYE)
			t.expect(Snorkel.floatEye(0)).toBeCloseTo(Snorkel.SURFACE_EYE, 1e-9)
		end
	)

	t.test(
		"a duck dive pushes down, stops at 5 m or the seabed, and surfaces out of breath",
		function()
			t.expect(Snorkel.verticalVelocity("dive", 0.4, 0, -40, 0, 0, 0.1) < 0).toBe(true)
			-- below the depth limit it climbs back
			t.expect(Snorkel.verticalVelocity("dive", -18, 0, -40, -1, 1, 5) > 0).toBe(true)
			-- over a shallow seabed the floor clearance wins
			t.expect(Snorkel.verticalVelocity("dive", -6, 0, -7, -1, 1, 5) > 0).toBe(true)
			-- looking down and swimming forward goes down
			t.expect(Snorkel.verticalVelocity("dive", -6, 0, -40, -0.7, 1, 5) < 0).toBe(true)
			local b = Snorkel.BREATH
			for _ = 1, 300 do
				b = Snorkel.stepBreath(b, true, 0.1)
			end
			t.expect(b).toBe(0)
			t.expect(Snorkel.nextMode("dive", 10, 0, false, false)).toBe("ascend")
			t.expect(Snorkel.nextMode("ascend", 0.1, 0, false, false)).toBe("surface")
			t.expect(Snorkel.nextMode("surface", 0, 2, true, false)).toBe("surface") -- not enough breath
			t.expect(Snorkel.nextMode("surface", 0, Snorkel.BREATH, true, false)).toBe("dive")
			t.expect(Snorkel.stepBreath(0, false, 2) > 0).toBe(true)
			t.expect(Snorkel.speed("surface", 1) > Snorkel.speed("surface", 0)).toBe(true)
		end
	)
end
