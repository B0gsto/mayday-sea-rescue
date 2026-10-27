-- WorkerRules (docs/23 (o), WP-26): the survivor roll, auto-assignment to the worker buildings, the effects math,
-- the capped offline pay and the save migration (old crew paid back, workers kept and cleaned).
return function(t)
	local W = t.load("src/shared/WorkerRules.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local D = t.load("src/shared/Config/DockConfig.luau")

	local function worker(category, rarity, name)
		return { category = category, rarity = rarity, name = name or "Sam" }
	end

	t.test("every category has its building in the tree", function()
		for _, c in W.CATEGORIES do
			local key = W.buildingOf(c)
			t.expect(key ~= nil and D.Buildings[key] ~= nil).toBe(true)
		end
	end)

	t.test("the roll is deterministic and lands ~80/17/3 over the five categories", function()
		local a = { W.roll(12345) }
		t.expect(a).toEqual({ W.roll(12345) })
		local rarity, category = { 0, 0, 0 }, {}
		local N = 20000
		for seed = 1, N do
			local c, r, name = W.roll(seed * 7919)
			rarity[r] += 1
			category[c] = (category[c] or 0) + 1
			t.expect(type(name)).toBe("string")
		end
		t.expect(rarity[1] / N).toBeCloseTo(0.8, 0.02)
		t.expect(rarity[2] / N).toBeCloseTo(0.17, 0.02)
		t.expect(rarity[3] / N).toBeCloseTo(0.03, 0.01)
		for _, c in W.CATEGORIES do
			t.expect(category[c] / N).toBeCloseTo(0.2, 0.02)
		end
	end)

	t.test("best rarity fills the slots; no building or a full one: idle on the jetty", function()
		local list = {
			worker("Builder", 1, "A"),
			worker("Builder", 1, "B"),
			worker("Builder", 3, "C"),
			worker("Builder", 1, "D"),
			worker("Builder", 2, "E"),
			worker("Gatherer", 3, "F"),
		}
		local place = W.assign(list, { Workshop = true })
		t.expect(place[3]).toBe(1) -- legendary first
		t.expect(place[5]).toBe(2) -- then rare
		t.expect(place[1]).toBe(3) -- then the earliest common
		t.expect(place[2]).toBeNil()
		t.expect(place[4]).toBeNil()
		t.expect(place[6]).toBeNil() -- no fish shed yet
		local more = W.assign(list, { Workshop = true, Station = true })
		t.expect(W.slots({ Station = true })).toBe(W.SLOTS + W.STATION_SLOTS)
		t.expect(more[2] ~= nil and more[4] ~= nil).toBe(true)
	end)

	t.test(
		"at the cap only a rarer worker stays, taking the first of the lowest rarity's place",
		function()
			local list = {}
			for i = 1, W.CAP do
				list[i] = worker("Builder", if i == 1 then 2 else 1, `W{i}`)
			end
			t.expect(W.admit(list, worker("Medic", 1, "X"))).toBeNil()
			t.expect(W.admit(list, worker("Medic", 2, "Y"))).toBe(2)
			t.expect(list[2].name).toBe("Y")
			t.expect(#list).toBe(W.CAP)
			local short = {}
			t.expect(W.admit(short, worker("Medic", 1))).toBe(1)
		end
	)

	t.test("effects: rarity multiplies, every effect is capped", function()
		local owned = {
			Workshop = true,
			FishShed = true,
			BoatYard = true,
			Clinic = true,
			RescueBoathouse = true,
		}
		local fx = W.effects(W.units({
			worker("Builder", 1),
			worker("Builder", 2),
			worker("Gatherer", 3),
			worker("Mechanic", 1),
			worker("Medic", 2),
			worker("Rescuer", 1),
		}, owned))
		t.expect(fx.gatherPerMin).toBeCloseTo(2.5 * W.GATHER_PER, 1e-9)
		t.expect(fx.rescuePerTrip).toBeCloseTo(W.RESCUE_PER, 1e-9)
		t.expect(fx.boatScale).toBeCloseTo(1 - W.BOAT_PER, 1e-9)
		t.expect(fx.craftSpeed).toBeCloseTo(1 + W.SPEED_PER, 1e-9)
		t.expect(fx.payBonus).toBeCloseTo(1.5 * W.PAY_PER, 1e-9)
		local max = W.effects({ Builder = 99, Mechanic = 99, Medic = 99 })
		t.expect(max.boatScale).toBeCloseTo(1 - W.BOAT_CAP, 1e-9)
		t.expect(max.craftSpeed).toBeCloseTo(1 + W.SPEED_CAP, 1e-9)
		t.expect(max.payBonus).toBe(W.PAY_CAP)
	end)

	t.test("offline pay is a reduced rate, capped at 2 hours", function()
		local fx = W.effects({ Gatherer = 3, Rescuer = 3 })
		local perMin = 3 * W.GATHER_PER + 3 * W.RESCUE_PER * 60 / W.RESCUE_PERIOD
		t.expect(W.offlinePay(fx, 600)).toBe(math.floor(perMin * 10 * W.OFFLINE_RATE))
		t.expect(W.offlinePay(fx, 10 * 3600)).toBe(W.offlinePay(fx, W.OFFLINE_CAP))
		t.expect(W.offlinePay(fx, -50)).toBe(0)
		t.expect(W.offlinePay(W.effects({ Builder = 3 }), 3600)).toBe(0)
	end)

	t.test("the skill tree raises the effects, caps, slots and roll", function()
		local owned = { Workshop = true }
		local list = {}
		for i = 1, 4 do
			list[i] = worker("Builder", 1)
		end
		t.expect(W.slots(owned, 1)).toBe(W.SLOTS + 1)
		t.expect(W.assign(list, owned, { Builder = 1 })[4]).toBe(4)
		local fx = W.effects({ Gatherer = 1, Rescuer = 1, Mechanic = 99, Medic = 99 }, {
			gatherMult = 0.15,
			tripPayMult = 0.25,
			tripScale = 0.15,
			recruitChance = 0.05,
			offlineRate = 0.1,
			speedCapAdd = 0.05,
			boatCapAdd = 0.1,
			medicCapAdd = 0.1,
			medicPerUnit = 0.05,
		})
		t.expect(fx.gatherPerMin).toBeCloseTo(W.GATHER_PER * 1.15, 1e-9)
		t.expect(fx.rescuePerTrip).toBeCloseTo(W.RESCUE_PER * 1.25, 1e-9)
		t.expect(fx.craftSpeed).toBeCloseTo(1 + W.SPEED_CAP + 0.05, 1e-9)
		t.expect(fx.boatScale).toBeCloseTo(1 - W.BOAT_CAP - 0.1, 1e-9)
		t.expect(fx.payBonus).toBeCloseTo(W.PAY_CAP + 0.1, 1e-9)
		t.expect(fx.rescuePeriod).toBeCloseTo(W.RESCUE_PERIOD * 0.85, 1e-9)
		t.expect(fx.recruitChance).toBeCloseTo(W.RESCUE_RECRUIT + 0.05, 1e-9)
		t.expect(fx.offlineRate).toBeCloseTo(W.OFFLINE_RATE + 0.1, 1e-9)
		local rare = 0
		for seed = 1, 4000 do
			local _, rarity = W.roll(seed * 7919, 0.1)
			if rarity > 1 then
				rare += 1
			end
		end
		t.expect(rare / 4000 > 0.24).toBe(true) -- 20% base + the skill's 10 points
	end)

	t.test("saves: workers cleaned and capped, old crew paid back once", function()
		local raw = {
			cash = 100,
			crew = { Mechanic = true, Dispatcher = true },
			workers = { worker("Medic", 9, "A very long name indeed"), worker("Pirate", 1), "junk" },
			lastSeen = 1792800000,
		}
		local data = Rules.migrate(raw)
		t.expect(data.cash).toBe(100 + 12000 + 15000)
		t.expect(#data.workers).toBe(1)
		t.expect(data.workers[1].rarity).toBe(3)
		t.expect(#data.workers[1].name <= 16).toBe(true)
		t.expect(data.lastSeen).toBe(1792800000)
		t.expect(Rules.migrate(data).cash).toBe(data.cash) -- the save copy pays nothing twice
		local many = {}
		for i = 1, 50 do
			many[i] = worker("Builder", 1)
		end
		t.expect(#Rules.migrate({ workers = many }).workers).toBe(50) -- the Bunkhouse grows to fit them
		t.expect(Rules.snapshot(data).workers[1].category).toBe("Medic")
	end)
end
