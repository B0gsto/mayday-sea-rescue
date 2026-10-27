-- WorkerRules (docs/23 (o), WP-26; docs/25 E + K1 survivors v2): the six-rarity survivor roll with traits,
-- specials and pity, auto-assignment to the worker buildings, the crew's effects math, the capped offline pay
-- and the save migration (old crew paid back, old rarities remapped, workers kept and cleaned).
return function(t)
	local W = t.load("src/shared/WorkerRules.luau")
	local Rarity = t.load("src/shared/Rarity.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local D = t.load("src/shared/Config/DockConfig.luau")

	local function worker(category, rarity, name, trait, special)
		return {
			category = category,
			rarity = rarity,
			name = name or "Sam",
			trait = trait or "",
			special = special or "",
		}
	end

	t.test(
		"every category has its building in the tree (the Hauler waits until Depot lands)",
		function()
			for _, c in W.CATEGORIES do
				local key = W.buildingOf(c)
				if c == "Hauler" then
					t.expect(key == nil or key == "Depot").toBe(true)
				else
					t.expect(key ~= nil and D.Buildings[key] ~= nil).toBe(true)
				end
			end
		end
	)

	t.test("the six rarity weights are Rarity's tiers and sum to 100", function()
		t.expect(#W.RARITY_WEIGHTS).toBe(Rarity.MYTHIC)
		t.expect(#W.RARITY_MULT).toBe(Rarity.MYTHIC)
		local sum = 0
		for _, weight in W.RARITY_WEIGHTS do
			sum += weight
		end
		t.expect(sum).toBeCloseTo(100, 1e-9)
	end)

	t.test("the roll is deterministic and lands ~62/25/9/3/0.9/0.1 over the categories", function()
		local a = W.roll(12345)
		t.expect(a).toEqual(W.roll(12345))
		local rarity, category = { 0, 0, 0, 0, 0, 0 }, {}
		local N = 20000
		for seed = 1, N do
			local w = W.roll(seed * 7919)
			rarity[w.rarity] += 1
			category[w.category] = (category[w.category] or 0) + 1
			t.expect(type(w.name)).toBe("string")
			if w.rarity >= 2 then
				t.expect(table.find(W.TRAITS, w.trait) ~= nil).toBe(true)
			else
				t.expect(w.trait).toBe("")
			end
			if w.special ~= "" then
				local sp = W.specialById[w.special]
				t.expect(sp ~= nil and sp.rarity == w.rarity).toBe(true)
				t.expect(sp.category == "Any" or sp.category == w.category).toBe(true)
			end
		end
		local want = W.RARITY_WEIGHTS
		local tolerance = { 0.02, 0.02, 0.012, 0.006, 0.003, 0.003 }
		for r = 1, #want do
			t.expect(rarity[r] / N).toBeCloseTo(want[r] / 100, tolerance[r])
		end
		for _, c in W.CATEGORIES do
			t.expect(category[c] / N).toBeCloseTo(1 / #W.CATEGORIES, 0.03)
		end
	end)

	t.test(
		"pity: an Epic by the 40th and a Legendary by the 250th, then the counters reset",
		function()
			local pity = { epic = 39, legendary = 0 }
			local w = W.roll(123, { pity = pity })
			t.expect(w.rarity >= W.EPIC).toBe(true)
			t.expect(pity.epic).toBe(0)
			pity = { epic = 0, legendary = 249 }
			w = W.roll(456, { pity = pity })
			t.expect(w.rarity >= W.LEGENDARY).toBe(true)
			t.expect(pity.legendary).toBe(0)
			-- no counter ever passes its limit: the forced roll resets it
			local p = { epic = 0, legendary = 0 }
			for i = 1, 400 do
				W.roll(i * 104729, { pity = p })
				t.expect(p.epic < W.PITY_EPIC).toBe(true)
				t.expect(p.legendary < W.PITY_LEGENDARY).toBe(true)
			end
		end
	)

	t.test("specials: only on Legendary/Mythic, one of each, from their source", function()
		local all = W.ownedSpecials({
			worker("Builder", 5, nil, "", "Brickbeard"),
			worker("Hauler", 5, nil, "", "BigLou"),
			worker("Rescuer", 5, nil, "", "CaptainMarlow"),
			worker("Medic", 5, nil, "", "DrCoral"),
			worker("Mechanic", 6, nil, "", "Bolt"),
			worker("Gatherer", 6, nil, "", "Pearl"),
			worker("Builder", 6, nil, "", "Nova"),
			worker("Builder", 6, nil, "", "OldBones"),
		})
		local legendaryBuilders, brickbeards, pearls = 0, 0, 0
		for seed = 1, 60000 do
			local w = W.roll(seed * 7919, { owned = all })
			t.expect(w.special).toBe("") -- every special is already owned
		end
		for seed = 1, 60000 do
			local w = W.roll(seed * 65537, { source = "MermaidLagoon" })
			if w.rarity == W.LEGENDARY and w.category == "Builder" then
				legendaryBuilders += 1
				if w.special == "Brickbeard" then
					brickbeards += 1
				end
			end
			if w.special == "Pearl" then
				t.expect(w.rarity).toBe(Rarity.MYTHIC)
				t.expect(w.category).toBe("Gatherer")
				pearls += 1
			end
			t.expect(w.special ~= "Nova" and w.special ~= "OldBones").toBe(true)
		end
		t.expect(legendaryBuilders > 0).toBe(true)
		t.expect(brickbeards > 0).toBe(true)
		t.expect(brickbeards <= legendaryBuilders).toBe(true)
		t.expect(pearls > 0).toBe(true)
		-- Pearl needs a Mermaid Lagoon call: a plain "any" source never gives her
		for seed = 1, 60000 do
			local w = W.roll(seed * 104729, { source = "any" })
			t.expect(w.special ~= "Pearl").toBe(true)
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
		t.expect(place[3]).toBe(1) -- rare first
		t.expect(place[5]).toBe(2) -- then uncommon
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
		local fx = W.effects(W.crew({
			worker("Builder", 1),
			worker("Builder", 2),
			worker("Gatherer", 3),
			worker("Mechanic", 1),
			worker("Medic", 2),
			worker("Rescuer", 1),
		}, owned))
		t.expect(fx.gatherPerMin).toBeCloseTo(W.RARITY_MULT[3] * W.GATHER_PER, 1e-9)
		t.expect(fx.rescuePerTrip).toBeCloseTo(W.RESCUE_PER, 1e-9)
		t.expect(fx.boatScale).toBeCloseTo(1 - W.BOAT_PER, 1e-9)
		t.expect(fx.craftSpeed).toBeCloseTo(1 + W.SPEED_PER, 1e-9)
		t.expect(fx.payBonus).toBeCloseTo(W.RARITY_MULT[2] * W.PAY_PER, 1e-9)
		local max = W.effects({
			units = { Builder = 99, Mechanic = 99, Medic = 99 },
			night = {},
			lucky = 0,
		})
		t.expect(max.boatScale).toBeCloseTo(1 - W.BOAT_CAP, 1e-9)
		t.expect(max.craftSpeed).toBeCloseTo(1 + W.SPEED_CAP, 1e-9)
		t.expect(max.payBonus).toBe(W.PAY_CAP)
	end)

	t.test(
		"traits: Cheerful lifts co-workers, NightOwl and Bolt pay fully away, Lucky recruits",
		function()
			local crew = W.crew({
				worker("Builder", 1, nil, "Cheerful"),
				worker("Builder", 1),
				worker("Gatherer", 1, nil, "NightOwl"),
				worker("Gatherer", 1, nil, "Lucky"),
				worker("Mechanic", 6, nil, "", "Bolt"),
				worker("Rescuer", 5, nil, "", "CaptainMarlow"),
			}, {
				Workshop = true,
				FishShed = true,
				BoatYard = true,
				RescueBoathouse = true,
			})
			t.expect(crew.units.Builder).toBeCloseTo(1 + 1 * (1 + W.CHEERFUL), 1e-9)
			t.expect(crew.night.Gatherer).toBeCloseTo(1, 1e-9)
			t.expect(crew.night.Mechanic).toBeCloseTo(W.RARITY_MULT[6], 1e-9)
			t.expect(crew.units.Rescuer).toBeCloseTo(W.RARITY_MULT[5] * 2, 1e-9) -- Marlow pays x2
			t.expect(crew.lucky).toBe(1)
			local fx = W.effects(crew)
			t.expect(fx.recruitChance).toBeCloseTo(W.RESCUE_RECRUIT + W.LUCKY_RECRUIT, 1e-9)
			t.expect(fx.offlinePerMin).toBeCloseTo(
				(fx.gatherPerMin + fx.rescuePerTrip * 60 / fx.rescuePeriod) * W.OFFLINE_RATE
					+ W.GATHER_PER * (1 - W.OFFLINE_RATE),
				1e-9
			)
			t.expect(W.carryLoads(worker("Builder", 2, nil, "Strong"))).toBe(W.CARRY_LOAD)
			t.expect(W.carryLoads(worker("Builder", 5, nil, "", "Brickbeard")))
				.toBe(W.SPECIAL_CARRY)
			t.expect(W.carryLoads(worker("Hauler", 5, nil, "", "BigLou"))).toBe(W.SPECIAL_CARRY)
			t.expect(W.carryLoads(worker("Builder", 1))).toBe(1)
		end
	)

	t.test("offline pay is a reduced rate, capped at 2 hours", function()
		local fx = W.effects(W.crew({
			worker("Gatherer", 3),
			worker("Rescuer", 3),
		}, { FishShed = true, RescueBoathouse = true }))
		t.expect(W.offlinePay(fx, 600)).toBe(math.floor(fx.offlinePerMin * 10))
		t.expect(W.offlinePay(fx, 10 * 3600)).toBe(W.offlinePay(fx, W.OFFLINE_CAP))
		t.expect(W.offlinePay(fx, -50)).toBe(0)
		t.expect(
			W.offlinePay(W.effects(W.crew({ worker("Builder", 3) }, { Workshop = true })), 3600)
		)
			.toBe(0)
	end)

	t.test("the skill tree raises the effects, caps, slots and roll", function()
		local owned = { Workshop = true, FishShed = true, RescueBoathouse = true }
		local list = {}
		for i = 1, 4 do
			list[i] = worker("Builder", 1)
		end
		t.expect(W.slots(owned, 1)).toBe(W.SLOTS + 1)
		t.expect(W.assign(list, owned, { Builder = 1 })[4]).toBe(4)
		local crew = W.crew({
			worker("Gatherer", 1),
			worker("Rescuer", 1),
		}, owned)
		crew.units.Mechanic, crew.units.Medic = 99, 99
		local fx = W.effects(crew, {
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
			local w = W.roll(seed * 7919, { rareAdd = 0.1 })
			if w.rarity > 1 then
				rare += 1
			end
		end
		t.expect(rare / 4000 > 0.24).toBe(true) -- 34% base + the skill's 10 points
	end)

	t.test(
		"saves: old rarities remap, workers cleaned and capped, old crew paid back once",
		function()
			local raw = {
				cash = 100,
				version = 1,
				crew = { Mechanic = true, Dispatcher = true },
				workers = {
					worker("Medic", 2, "A very long name indeed"),
					{ category = "Builder", rarity = 3, name = "B" },
					{ category = "Hauler", rarity = 1, name = "C" },
					{ category = "Pirate", rarity = 1, name = "junk" },
					"junk",
				},
				lastSeen = 1792800000,
			}
			local data = Rules.migrate(raw)
			t.expect(data.cash).toBe(100 + 12000 + 15000)
			t.expect(#data.workers).toBe(3)
			t.expect(data.workers[1].rarity).toBe(3) -- old rare -> new Rare
			t.expect(data.workers[2].rarity).toBe(5) -- old legendary -> new Legendary
			t.expect(data.workers[3].rarity).toBe(1) -- Hauler kept, waits for the Depot
			t.expect(data.workers[1].trait).toBe("")
			t.expect(#data.workers[1].name <= 16).toBe(true)
			t.expect(data.lastSeen).toBe(1792800000)
			t.expect(data.version).toBe(2)
			t.expect(Rules.migrate(data).cash).toBe(data.cash) -- the save copy pays nothing twice
			-- v2 saves keep the six rarities and traits
			local kept = Rules.migrate({
				version = 2,
				workers = {
					{ category = "Medic", rarity = 2, name = "A", trait = "Speedy" },
					{ category = "Builder", rarity = 6, name = "B", special = "OldBones" },
				},
				pity = { epic = 12, legendary = 250 },
			})
			t.expect(kept.workers[1].rarity).toBe(2)
			t.expect(kept.workers[1].trait).toBe("Speedy")
			t.expect(kept.workers[1].special).toBe("")
			t.expect(kept.workers[2].rarity).toBe(6)
			t.expect(kept.workers[2].special).toBe("OldBones")
			t.expect(kept.pity.epic).toBe(12)
			t.expect(kept.pity.legendary).toBe(W.PITY_LEGENDARY)
			local many = {}
			for i = 1, 50 do
				many[i] = worker("Builder", 1)
			end
			t.expect(#Rules.migrate({ version = 2, workers = many }).workers).toBe(50) -- the Bunkhouse grows to fit them
			t.expect(Rules.snapshot(data).workers[1].category).toBe("Medic")
		end
	)
end
