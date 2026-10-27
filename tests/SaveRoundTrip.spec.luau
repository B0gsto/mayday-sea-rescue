-- SaveRoundTrip: a full late-game profile and an old pre-hub-cut one go through DataService's real save and load
-- (Save -> UpdateAsync -> JSON -> a new server's load) and come back with everything gameplay reads. The fake
-- store rejects what a real DataStore rejects (NaN/inf, mixed or sparse tables, bad UTF-8, > 4 MB).
return function(t)
	local serde = t.lune("serde")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local ProgressionConfig = t.load("src/shared/Config/ProgressionConfig.luau")
	local VehicleUpgrades = t.load("src/shared/VehicleUpgrades.luau")
	local WorkerRules = t.load("src/shared/WorkerRules.luau")
	local UnlockTree = t.load("src/shared/UnlockTree.luau")
	local DiscoveryRules = t.load("src/shared/DiscoveryRules.luau")
	local QuestRules = t.load("src/shared/Quests/Rules.luau")
	local QuestData = t.load("src/shared/Quests/Data.luau")
	local PetRules = t.load("src/shared/PetRules.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")

	local NOW = 1790000000
	local MAX_BYTES = 4 * 1024 * 1024

	local function storable(v: any, path: string)
		local kind = type(v)
		if kind == "number" then
			assert(v == v and math.abs(v) ~= math.huge, `{path}: NaN or inf`)
		elseif kind == "string" then
			assert(utf8.len(v) ~= nil, `{path}: invalid UTF-8`)
		elseif kind == "table" then
			local n, strings = 0, 0
			for key, x in v do
				n += 1
				if type(key) == "string" then
					strings += 1
				else
					assert(type(key) == "number", `{path}: {type(key)} key`)
				end
				storable(x, `{path}.{key}`)
			end
			assert(strings == 0 or strings == n, `{path}: mixed keys`)
			assert(strings > 0 or #v == n, `{path}: sparse array`)
		else
			assert(kind == "boolean", `{path}: a {kind} can't be stored`)
		end
	end

	-- Values are stored as JSON, like the real DataStore.
	local function jsonStore()
		local s = { values = {}, bytes = 0 }
		function s:UpdateAsync(key, fn)
			local old = self.values[key]
			local result = fn(if old then serde.decode("json", old) else nil)
			if result ~= nil then
				storable(result, key)
				local json = serde.encode("json", result)
				assert(#json < MAX_BYTES, `{key}: {#json} bytes`)
				self.values[key] = json
				self.bytes = #json
			end
			return result
		end
		function s:read(key)
			return serde.decode("json", self.values[key])
		end
		return s
	end

	local function fakePlayer(userId)
		local p = { UserId = userId, Name = `P{userId}`, Parent = true, attrs = {} }
		function p:GetAttribute(name)
			return self.attrs[name]
		end
		function p:SetAttribute(name, value)
			self.attrs[name] = value
		end
		function p:Kick() end
		return p
	end

	local function server(store, jobId)
		local DS = t.load("src/server/Services/DataService.luau")
		DS._test.setDeps({
			jobId = function()
				return jobId
			end,
			now = function()
				return NOW
			end,
			clock = function()
				return 0
			end,
			wait = function() end,
			spawn = function(fn, ...)
				fn(...)
			end,
			warn = function(...)
				error(table.concat({ ... }, " "))
			end,
		})
		DS._test.setStore(store)
		return DS
	end

	-- every system at its fullest, as the services write it
	local function lateGame(data)
		data.cash = 987654321
		data.totalRescues = 4321
		data.coldOpenDone = true
		data.dock = { levels = {}, prepaid = {} }
		for key, b in DockConfig.Buildings do
			data.dock.levels[key] = #b.levels
		end
		-- one Robux building still waiting for its last level
		data.dock.levels.Harbour = 2
		data.dock.prepaid.Harbour = 3
		data.dockBuildings = UnlockTree.ownedSet(data.dock.levels)
		data.dockPrepaid = { Harbour = true }
		for _, rows in { DockConfig.Blueprints, DockConfig.Decorations } do
			for key in rows do
				data.dockBuildings[key] = true
			end
		end
		for id, v in ProgressionConfig.Vehicles do
			if not v.passOnly and v.price > 0 then
				data.vehicles[id] = true
			end
		end
		data.vehicleUpgrades.RIB = VehicleUpgrades.MAX_MASK
		data.construction = { key = "Clinic", level = 1, progress = 0.42, rate = 2.1, at = NOW }
		data.depot = { stock = 37.5, at = NOW }
		data.vehicleUpgrades.JetSki = VehicleUpgrades.bit("Engine") + VehicleUpgrades.bit("Hull")
		for i = 1, WorkerRules.CAP do
			table.insert(data.workers, {
				category = WorkerRules.CATEGORIES[1 + i % #WorkerRules.CATEGORIES],
				rarity = 1 + i % 3,
				name = `Worker{i}`,
				trait = "",
				special = "",
			})
		end
		-- quests: Keeper Ives' chain on its last step (handed back next), every other quest done once
		local q = QuestRules.new()
		for id in QuestData.byId do
			q.done[id] = id ~= "Lamp3" or nil
		end
		for npc in QuestData.npcById do
			q.last[npc] = NOW // 86400
		end
		q.active, q.stage = "Lamp3", "back"
		local isles, fog = {}, DiscoveryRules.newFog()
		for _, page in DiscoveryRules.Pages do
			isles[page.id] = 2 ^ (#page.stickers + 2) - 1
		end
		buffer.fill(fog, 0, 1)
		local pets = PetRules.newState()
		for i = 1, PetRules.MAX do
			table.insert(pets.entries, {
				id = i,
				species = "Seal",
				rare = true,
				at = NOW,
				bond = PetRules.BOND_MAX,
				adopted = true,
			})
		end
		pets.nextId, pets.active, pets.treats = PetRules.MAX + 1, 1, PetRules.TREAT_MAX
		data.flags = {
			quest = QuestRules.encode(q),
			isles = DiscoveryRules.encode(isles),
			fog = DiscoveryRules.encodeFog(fog),
			foghub = { f1 = string.rep("_", 64), f2 = string.rep("A", 64) },
			pets = PetRules.encode(pets),
			streak = StreakRules.flagTable({ lastDay = 20717, streak = 7, cosmeticDay = 20717 }),
			shop = {
				starterKit = true,
				callerHour = NOW // 3600,
				packs = 2,
				packDay = NOW // 86400,
			},
			cameraSettings = { fov = 70, shake = false },
			lastVehicle = "RIB",
			monthlyLivery = "2026-10",
			cosmeticAuto = true,
			notifyOptIn = true,
			opsCompleted = 812,
			group = { c = true, m = true, g = 548313786 },
		}
		data.cosmetics = { livery = "liv_storm", hat = "hat_cap" }
		data.badgeCounters = { Rescue100 = 100, ["seen:AllWildlife:Seal"] = 1 }
		data.badgesAwarded = { FirstRescue = true }
		return q, fog
	end

	t.test("a late-game profile comes back the same after a save and a rejoin elsewhere", function()
		local store = jsonStore()
		local A = server(store, "job-A")
		local p = fakePlayer(1)
		A._test.playerAdded(p)
		local q, fog = lateGame(A.Get(p))
		for i = 1, 3 do
			t.expect(A.CommitReceipt(p, `receipt-{i}`, function(data)
				data.cash += 100
			end)).toBe(true)
		end
		local expected = A.Logic.deepCopy(A.Get(p))
		expected.lastSeen = NOW
		A._test.playerRemoving(p)
		t.expect(store.bytes < 64 * 1024).toBeTruthy() -- far from the 4 MB limit

		local B = server(store, "job-B")
		local again = fakePlayer(1)
		B._test.playerAdded(again)
		local got = B.Get(again)
		t.expect(got).toEqual(expected)
		t.expect(got.cash).toBe(987654621)
		t.expect(#got.workers).toBe(WorkerRules.CAP)
		local quest = QuestRules.decode(got.flags.quest)
		t.expect(quest.active).toBe("Lamp3")
		t.expect(quest.stage).toBe("back")
		t.expect(quest.done).toEqual(q.done)
		t.expect(quest.last).toEqual(q.last)
		t.expect(buffer.tostring(DiscoveryRules.decodeFog(got.flags.fog)))
			.toBe(buffer.tostring(fog))
		for i = 1, 3 do
			t.expect(B.HasReceipt(again, `receipt-{i}`)).toBe(true)
		end
		-- a retried receipt never grants twice after the rejoin
		t.expect(B.CommitReceipt(again, "receipt-1", function()
			error("granted twice")
		end)).toBe(true)
	end)

	t.test(
		"a pre-hub-cut profile (dock levels, crew, gear) moves onto the tree keeping Cash and rescues",
		function()
			local store = jsonStore()
			store.values.Player_2 = serde.encode("json", {
				data = {
					version = 1,
					cash = 50000,
					rep = 900,
					rank = 7,
					totalRescues = 321,
					coldOpenDone = true,
					dockLevel = 4,
					dockBuildings = { Workshop = true, OldFuelDepot = true },
					vehicles = { RIB = true, Truck = true },
					vehicleUpgrades = { JetSki = VehicleUpgrades.bit("Fit") },
					crew = { Mechanic = true },
					gear = { EngineTune = 2 },
					certs = { Swim = true },
					flags = { station = { lv = 1, at = NOW, c = 500 }, notifyOptIn = true },
				},
			})
			local A = server(store, "job-A")
			local p = fakePlayer(2)
			A._test.playerAdded(p)
			local data = A.Get(p)
			-- 50,000 + Mechanic 12,000 + gear level 2 (1,200; level 1 became the Engine upgrade) + jet ski seat 1,500
			t.expect(data.cash).toBe(66300)
			t.expect(data.totalRescues).toBe(321)
			t.expect(data.coldOpenDone).toBe(true)
			for n = 2, 4 do
				for _, key in DockConfig.LEVEL_ITEMS[n] do
					t.expect({ key, data.dockBuildings[key] }).toEqual({ key, true })
				end
			end
			t.expect(data.dockBuildings.OldFuelDepot).toBeNil()
			t.expect(data.vehicles).toEqual({ RIB = true })
			t.expect(data.vehicleUpgrades).toEqual({ JetSki = VehicleUpgrades.bit("Engine") })
			t.expect(data.flags).toEqual({ notifyOptIn = true })
			A._test.playerRemoving(p)

			local saved = store:read("Player_2")
			t.expect(saved.version).toBe(A.Logic.RECORD_VERSION)
			t.expect(saved.data.crew).toBeNil()
			t.expect(saved.data.gear).toBeNil()

			-- the refunds land once: a second rejoin keeps the same Cash
			local B = server(store, "job-B")
			local again = fakePlayer(2)
			B._test.playerAdded(again)
			t.expect(B.Get(again).cash).toBe(66300)
			t.expect(B.Get(again).dockBuildings).toEqual(data.dockBuildings)
		end
	)
end
