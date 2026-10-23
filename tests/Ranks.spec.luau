-- Ranks: the docs 03 ladder from Recruit to Admiral by Rep only (docs/16 K7), Service Stars past
-- the top rank, the snapshot fields the HUD and the ceremony read, and the data-only unlocks.
return function(t)
	local Config = t.require("Config/ProgressionConfig") -- the instance Rules requires too
	local Rules = t.load("src/shared/ProgressionRules.luau")

	local function data(rep)
		local d = Rules.defaultData()
		d.rep = rep
		return d
	end

	t.test("the ladder is the docs 03 eight ranks", function()
		local ids = {
			"Recruit",
			"Lifeguard",
			"RescueSwimmer",
			"Coxswain",
			"RescuePilot",
			"Captain",
			"Commodore",
			"Admiral",
		}
		local names = {
			"Recruit",
			"Lifeguard",
			"Rescue Swimmer",
			"Coxswain",
			"Rescue Pilot",
			"Captain",
			"Commodore",
			"Admiral",
		}
		local bands = { 0, 400, 900, 3000, 9000, 22000, 55000, 150000 }
		t.expect(#Config.Ranks).toBe(8)
		for i = 1, 8 do
			t.expect(Config.Ranks[i].id).toBe(ids[i])
			t.expect(Config.Ranks[i].displayName).toBe(names[i])
			t.expect(Config.Ranks[i].rep).toBe(bands[i])
			t.expect(Rules.rankIndexForRep(bands[i])).toBe(i)
			if i > 1 then
				t.expect(Rules.rankIndexForRep(bands[i] - 1)).toBe(i - 1)
			end
		end
		t.expect(Rules.rankIndexForRep(1e9)).toBe(8)
	end)

	t.test("a fresh profile reaches rank 3 on Rep alone (no certification gates)", function()
		for _, rank in Config.Ranks do
			t.expect((rank :: any).cert).toBeNil()
			t.expect((rank :: any).certs).toBeNil()
		end
		local d = Rules.migrate(Rules.defaultData())
		t.expect(Rules.rankIndex(d)).toBe(1)
		d.rep = 400
		t.expect(Rules.rankIndex(d)).toBe(2)
		d.cash = 2500
		t.expect((Rules.canBuyVehicle(d, "RIB"))).toBe(true) -- the RIB opens at Lifeguard
		d.rep = 900
		t.expect(Rules.rankIndex(d)).toBe(3)
		t.expect(Rules.snapshot(d).rankIndex).toBe(3)
		-- an old save with Rep but no certifications is promoted on load
		t.expect(Rules.rankIndex(Rules.migrate({ rep = 3000 }))).toBe(4)
	end)

	t.test("Service Stars start past Admiral", function()
		t.expect(Rules.serviceStarsFromRep(150000)).toBe(0)
		t.expect(Rules.serviceStarsFromRep(179999)).toBe(0)
		t.expect(Rules.serviceStarsFromRep(180000)).toBe(1)
		t.expect(Rules.serviceStarsFromRep(210000)).toBe(2)
		t.expect(Rules.serviceStars(data(200000))).toBe(1)
		local stars, nextRep, progress = Rules.starProgress(data(195000))
		t.expect(stars).toBe(1)
		t.expect(nextRep).toBe(210000)
		t.expect(progress).toBeCloseTo(0.5, 1e-9)
	end)

	t.test("the snapshot carries the star count and the star bar", function()
		local s = Rules.snapshot(data(210000))
		t.expect(s.rank).toBe("Admiral ★2")
		t.expect(s.rankIndex).toBe(8)
		t.expect(s.stars).toBe(2)
		t.expect(s.nextRankRep).toBeNil()
		t.expect(s.nextStarRep).toBe(240000)
		t.expect(s.starProgress).toBe(0)
	end)

	t.test("lifeboat and helicopter are rank-gated data", function()
		local coxswain = data(3000)
		coxswain.cash = 12000
		local ok, _, price = Rules.canBuyVehicle(coxswain, "Lifeboat")
		t.expect(ok).toBe(true)
		t.expect(price).toBe(12000)
		local early = data(3000)
		early.cash = 75000
		local bought, why = Rules.canBuyVehicle(early, "RescueHelicopter")
		t.expect(bought).toBe(false)
		t.expect(why).toBe("Needs Rescue Pilot")
		local pilot = data(9000)
		pilot.cash = 75000
		t.expect((Rules.canBuyVehicle(pilot, "RescueHelicopter"))).toBe(true)
	end)
end
