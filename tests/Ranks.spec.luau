-- Ranks: the docs 03 ladder from Recruit to Admiral, certification gates, Service Stars past the
-- top rank, the snapshot fields the HUD and the ceremony read, and the data-only unlocks.
return function(t)
	local Config = t.require("Config/ProgressionConfig") -- the instance Rules requires too
	local Rules = t.load("src/shared/ProgressionRules.luau")

	local function data(rep)
		local d = Rules.defaultData()
		d.rep = rep
		return d
	end

	-- the three MVP certifications every rank test needs (rank 2 and 3 gates, Admiral's list)
	local function certified(rep)
		local d = data(rep)
		d.certs.Helm = true
		d.certs.CasualtyCare = true
		d.certs.RescueSwimmer = true
		d.certs.Coxswain = true
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

	t.test("ranks 4 to 8 carry the docs 03 certification gates", function()
		t.expect(Rules.rankCerts(Config.Ranks[4])).toEqual({ "Coxswain" })
		t.expect(Rules.rankCerts(Config.Ranks[5])).toEqual({ "Pilot" })
		t.expect(#Rules.rankCerts(Config.Ranks[6])).toBe(0)
		t.expect(#Rules.rankCerts(Config.Ranks[7])).toBe(0)
		t.expect(Rules.rankCerts(Config.Ranks[8])).toEqual({
			"Helm",
			"CasualtyCare",
			"RescueSwimmer",
			"Coxswain",
			"WinchOperator",
			"Pilot",
		})
	end)

	t.test("the rank gate still waits for every certification the game defines", function()
		t.expect(Rules.rankIndex(data(150000))).toBe(1)
		local d = data(150000)
		d.certs.Helm = true
		t.expect(Rules.rankIndex(d)).toBe(2)
		d.certs.CasualtyCare = true
		d.certs.RescueSwimmer = true
		t.expect(Rules.rankIndex(d)).toBe(3) -- Coxswain certification lands next
		d.certs.Coxswain = true
		t.expect(Rules.rankIndex(d)).toBe(8)
		t.expect(Rules.blockedRank(d)).toBeNil()
	end)

	t.test("the Coxswain certification gates rank 4", function()
		local d = data(3000)
		d.certs.Helm = true
		d.certs.CasualtyCare = true
		d.certs.RescueSwimmer = true
		t.expect(Rules.rankIndex(d)).toBe(3)
		local rank, cert = Rules.blockedRank(d)
		t.expect(rank.id).toBe("Coxswain")
		t.expect(cert).toBe("Coxswain")
		t.expect(Rules.certHint(d)).toBe("Pass Coxswain to be promoted")
		d.certs.Coxswain = true
		t.expect(Rules.rankIndex(d)).toBe(4)
	end)

	t.test("Service Stars start past Admiral", function()
		t.expect(Rules.serviceStarsFromRep(150000)).toBe(0)
		t.expect(Rules.serviceStarsFromRep(179999)).toBe(0)
		t.expect(Rules.serviceStarsFromRep(180000)).toBe(1)
		t.expect(Rules.serviceStarsFromRep(210000)).toBe(2)
		t.expect(Rules.serviceStars(certified(200000))).toBe(1)
		t.expect(Rules.serviceStars(data(200000))).toBe(0) -- Rep alone is not Admiral
		local stars, nextRep, progress = Rules.starProgress(certified(195000))
		t.expect(stars).toBe(1)
		t.expect(nextRep).toBe(210000)
		t.expect(progress).toBeCloseTo(0.5, 1e-9)
	end)

	t.test("the snapshot carries the star count and the star bar", function()
		local s = Rules.snapshot(certified(210000))
		t.expect(s.rank).toBe("Admiral ★2")
		t.expect(s.rankIndex).toBe(8)
		t.expect(s.stars).toBe(2)
		t.expect(s.nextRankRep).toBeNil()
		t.expect(s.nextStarRep).toBe(240000)
		t.expect(s.starProgress).toBe(0)
	end)

	t.test(
		"migration keeps the new ranks and grandfathers their existing certifications",
		function()
			local d = Rules.migrate({
				rep = 3000,
				certs = { Helm = true, CasualtyCare = true, RescueSwimmer = true, Coxswain = true },
			})
			t.expect(Rules.rankIndex(d)).toBe(4)
			local top = Rules.migrate({ rep = 150000 })
			t.expect(top.certs.Helm).toBe(true)
			t.expect(top.certs.CasualtyCare).toBe(true)
			t.expect(top.certs.RescueSwimmer).toBe(true)
			t.expect(top.certs.Coxswain).toBe(true)
			t.expect(Rules.rankIndex(top)).toBe(8)
			t.expect(Rules.serviceStars(top)).toBe(0)
		end
	)

	t.test("lifeboat and helicopter are rank-gated data", function()
		local coxswain = certified(3000)
		coxswain.cash = 12000
		local ok, _, price = Rules.canBuyVehicle(coxswain, "Lifeboat")
		t.expect(ok).toBe(true)
		t.expect(price).toBe(12000)
		local early = certified(3000)
		early.cash = 75000
		local bought, why = Rules.canBuyVehicle(early, "RescueHelicopter")
		t.expect(bought).toBe(false)
		t.expect(why).toBe("Needs Rescue Pilot")
		local pilot = certified(9000)
		pilot.cash = 75000
		t.expect((Rules.canBuyVehicle(pilot, "RescueHelicopter"))).toBe(true)
	end)
end
