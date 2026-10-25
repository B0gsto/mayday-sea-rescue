-- docs/23 (h) "Sub pen", WP-10c: the Diver at a Wreck call's sites and who is offered it.
return function(t)
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")

	local function makeRng(seed: number)
		local s = seed
		return function()
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end
	end

	t.test("dive sites: deep, beside their wreck, off a routable island", function()
		t.expect(#CallTypes.DiveSites).toBe(3)
		for _, site in CallTypes.DiveSites do
			t.expect(site.at.Y <= -25).toBe(true)
			t.expect(CallLogic.flatDistance(site.at, site.wreck) <= 40).toBe(true)
			t.expect(CallTypes.IslandReach[site.island] ~= nil).toBe(true)
			t.expect(CallTypes.SpawnZones[site.island] ~= nil).toBe(true)
			t.expect(table.find(CallTypes.Kinds.Diver.zones, site.island) ~= nil).toBe(true)
		end
		t.expect(CallLogic.diveSite(nil, nil, "GannetStar").id).toBe("GannetStar")
		t.expect(CallLogic.diveSite(nil, nil, "WreckReef").id).toBe("ReefHulk")
		t.expect(CallLogic.diveSite(2000, nil, "WreckReef")).toBeNil()
	end)

	t.test("only sub owners, from call 3, about 1 in 6, within reach", function()
		local rng = makeRng(3)
		local function divers(completed: number, sub: boolean?, reach: number?): number
			local n = 0
			for _ = 1, 600 do
				local c = CallLogic.chooseCall(completed, "Calm", rng, reach or 5500, sub)
				if c.kind == "Diver" then
					n += 1
					t.expect(CallTypes.IslandReach[c.zone] <= (reach or 5500)).toBe(true)
				end
			end
			return n
		end
		t.expect(divers(10, false)).toBe(0)
		t.expect(divers(10, nil)).toBe(0)
		t.expect(divers(0, true)).toBe(0) -- call 1
		t.expect(divers(1, true)).toBe(0) -- call 2
		local share = divers(2, true) / 600 -- call 3
		t.expect(share > 0.1 and share < 0.25).toBe(true)
		share = divers(20, true, 2000) / 600 -- a jet-ski player with a Robux sub: the Skerry wreck only
		t.expect(share > 0.1 and share < 0.25).toBe(true)
	end)
end
