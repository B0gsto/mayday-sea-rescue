-- Land calls (docs/23 e.3): the follow rule, the site pick and their share of the call pool.
return function(t)
	local LandFollow = t.load("src/shared/Ops/LandFollow.luau")
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")

	local function makeRng(seed: number)
		local s = seed
		return function()
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end
	end

	local O = Vector3.zero
	local function at(x: number): Vector3
		return Vector3.new(x, 0, 0)
	end

	t.test("they wait until you walk into the ring on foot", function()
		local s = LandFollow.new()
		t.expect(LandFollow.step(s, 0.1, O, at(20), false, nil, 0)).toBe("wait")
		t.expect(LandFollow.step(s, 0.1, O, at(6), true, at(6), 0)).toBe("wait") -- seated: not yet
		t.expect(LandFollow.step(s, 0.1, O, at(7), false, nil, 0)).toBe("start")
		t.expect(s.following).toBe(true)
	end)

	t.test("following: move, stop close, climb aboard a craft within range", function()
		local s = LandFollow.new()
		LandFollow.step(s, 0.1, O, at(5), false, nil, 0)
		t.expect(LandFollow.step(s, 0.1, O, at(30), false, nil, 1)).toBe("move")
		t.expect(LandFollow.step(s, 0.1, O, at(4), false, nil, 0)).toBe("idle")
		t.expect(LandFollow.step(s, 0.1, O, at(40), true, at(30), 1)).toBe("shore")
		t.expect(LandFollow.step(s, 0.1, O, at(40), true, nil, 1)).toBe("shore")
		t.expect(LandFollow.step(s, 0.1, O, at(30), true, at(24), 1)).toBe("board")
	end)

	t.test("stuck for 4 s: put behind the player, once", function()
		local s = LandFollow.new()
		LandFollow.step(s, 0.1, O, at(5), false, nil, 0)
		local got = {}
		for _ = 1, 10 do
			table.insert(got, LandFollow.step(s, 0.5, O, at(50), false, nil, 0))
		end
		t.expect(table.find(got, "teleport")).toBe(8)
		t.expect(got[9]).toBe("move")
		for _ = 1, 20 do -- in a craft out of reach: they wait at the shore, never jump into the sea
			t.expect(LandFollow.step(s, 0.5, O, at(80), true, at(80), 0)).toBe("shore")
		end
	end)

	t.test("land sites: real islands, within reach, on land with a beach close by", function()
		for _, site in CallTypes.LandSites do
			t.expect(CallTypes.SpawnZones[site.island] ~= nil).toBe(true)
			t.expect(site.at.Y > 0 and site.beach.Y > 0).toBe(true)
			t.expect(CallLogic.flatDistance(site.at, site.beach) <= 200).toBe(true)
		end
		local rng = makeRng(5)
		for _ = 1, 50 do
			local site = CallLogic.landSite(2000, rng)
			t.expect(site and site.island).toBe("SkerryIsle")
		end
		t.expect(CallLogic.landSite(nil, rng, "WreckReefLedge").id).toBe("WreckReefLedge")
		t.expect(CallLogic.landSite(nil, rng, "Penwyn").island).toBe("Penwyn")
		t.expect(CallLogic.landSite(2000, rng, "Penwyn")).toBeNil()
	end)

	t.test("about 1 call in 5 is a land call after the tutorial chain, never before", function()
		local rng = makeRng(11)
		for completed = 0, #CallTypes.TutorialChain - 1 do
			t.expect(CallLogic.chooseCall(completed, "Calm", rng, 5500).kind ~= "Stranded")
				.toBe(true)
		end
		local land = 0
		for _ = 1, 2000 do
			local c = CallLogic.chooseCall(10, "Calm", rng, 5500)
			if c.kind == "Stranded" then
				land += 1
				t.expect(CallLogic.landSite(nil, rng, c.zone) ~= nil).toBe(true)
			end
		end
		t.expect(land > 300 and land < 500).toBe(true)
		t.expect(Operations.FromCallKind.Stranded).toBe("Stranded")
	end)
end
