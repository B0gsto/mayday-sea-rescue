-- Data: record migrations, the receipt ledger (CommitReceipt idempotency), session locks across
-- servers, request budget and backoff, and the BindToClose deadline. Uses a fake DataStore,
-- clock and players through DataService._test (no Roblox services).
return function(t)
	local function deepCopy(v)
		if type(v) ~= "table" then
			return v
		end
		local out = {}
		for k, x in v do
			out[k] = deepCopy(x)
		end
		return out
	end

	-- A fake DataStore: values round-trip through a copy, like the real serialised store.
	local function fakeStore()
		local s = { values = {}, failNext = 0, calls = 0 }
		function s:UpdateAsync(key, fn)
			self.calls += 1
			if self.failNext > 0 then
				self.failNext -= 1
				error("502: API Services rejected request")
			end
			local result = fn(deepCopy(self.values[key]))
			if result ~= nil then
				self.values[key] = deepCopy(result)
			end
			return result
		end
		return s
	end

	local function fakePlayer(userId)
		local p = { UserId = userId, Name = `P{userId}`, Parent = true, attrs = {}, kicked = nil }
		function p:GetAttribute(name)
			return self.attrs[name]
		end
		function p:SetAttribute(name, value)
			self.attrs[name] = value
		end
		function p:Kick(message)
			self.kicked = message
		end
		return p
	end

	-- A fresh DataService with a fake clock: wait() advances time, spawn() runs inline.
	local function setup(jobId)
		local DS = t.load("src/server/Services/DataService.luau")
		local clock = { t = 1000, waits = 0, warnings = {} }
		local budget = { value = math.huge }
		DS._test.setDeps({
			jobId = function()
				return jobId or "job-A"
			end,
			now = function()
				return math.floor(clock.t)
			end,
			clock = function()
				return clock.t
			end,
			wait = function(s)
				clock.t += s
				clock.waits += 1
			end,
			spawn = function(fn, ...)
				fn(...)
			end,
			random = function()
				return 0.5
			end,
			budget = function()
				return budget.value
			end,
			warn = function(...)
				table.insert(clock.warnings, table.concat({ ... }, " "))
			end,
		})
		local store = fakeStore()
		DS._test.setStore(store)
		return DS, store, clock, budget
	end

	-- Logic -------------------------------------------------------------------------------------

	t.test("every record version below current has a migration step", function()
		local DS = t.load("src/server/Services/DataService.luau")
		for v = 1, DS.Logic.RECORD_VERSION - 1 do
			t.expect(type(DS.Logic.MIGRATIONS[v])).toBe("function")
		end
	end)

	t.test("migrateRecord upgrades v1, fresh and corrupt records", function()
		local L = t.load("src/server/Services/DataService.luau").Logic
		local v1, state = L.migrateRecord({
			version = 1,
			data = { cash = 5 },
			session = { jobId = "x", time = 1 },
		})
		t.expect(state).toBe("ok")
		t.expect(v1.version).toBe(L.RECORD_VERSION)
		t.expect(v1.receipts).toEqual({})
		t.expect(v1.data.cash).toBe(5)
		t.expect(v1.session.jobId).toBe("x")
		local fresh = L.migrateRecord(nil)
		t.expect(fresh.version).toBe(L.RECORD_VERSION)
		local corrupt = L.migrateRecord({
			version = "junk",
			receipts = { ok = 3, [5] = 1, bad = "x" },
			session = 7,
		})
		t.expect(corrupt.receipts).toEqual({ ok = 3 })
		t.expect(corrupt.session).toBeNil()
	end)

	t.test("a record from a newer server is reported, not touched", function()
		local L = t.load("src/server/Services/DataService.luau").Logic
		local rec, state = L.migrateRecord({ version = L.RECORD_VERSION + 1, data = { cash = 9 } })
		t.expect(state).toBe("newer")
		t.expect(rec.version).toBe(L.RECORD_VERSION + 1)
	end)

	t.test("ledger trims to the newest ids", function()
		local L = t.load("src/server/Services/DataService.luau").Logic
		local ledger = {}
		for i = 1, 10 do
			ledger[`r{i}`] = i
		end
		L.trimLedger(ledger, 3)
		t.expect(ledger).toEqual({ r8 = 8, r9 = 9, r10 = 10 })
	end)

	t.test("lock states", function()
		local L = t.load("src/server/Services/DataService.luau").Logic
		t.expect(L.lockState(nil, "A", 100)).toBe("free")
		t.expect(L.lockState({ jobId = "A", time = 0 }, "A", 1e6)).toBe("ours")
		t.expect(L.lockState({ jobId = "B", time = 90 }, "A", 100)).toBe("live")
		t.expect(L.lockState({ jobId = "B", time = 0 }, "A", L.LOCK_STALE_SECONDS + 1))
			.toBe("stale")
	end)

	t.test("backoff doubles, caps and jitters", function()
		local L = t.load("src/server/Services/DataService.luau").Logic
		t.expect(L.backoffDelay(1, 0.5)).toBeCloseTo(1, 1e-9)
		t.expect(L.backoffDelay(2, 0.5)).toBeCloseTo(2, 1e-9)
		t.expect(L.backoffDelay(3, 0.5)).toBeCloseTo(4, 1e-9)
		t.expect(L.backoffDelay(10, 0.5)).toBeCloseTo(8, 1e-9)
		t.expect(L.backoffDelay(1, 0)).toBeCloseTo(0.75, 1e-9)
		t.expect(L.backoffDelay(1, 0.999999) < 1.25).toBeTruthy()
	end)

	t.test("restoreInto rolls back in place and keeps nested identities", function()
		local L = t.load("src/server/Services/DataService.luau").Logic
		local live = { cash = 10, gear = { Fins = 1 } }
		local gearRef = live.gear
		local snap = L.deepCopy(live)
		live.cash = 99
		live.gear.Fins = 3
		live.gear.Mask = 1
		live.extra = true
		L.restoreInto(live, snap)
		t.expect(live).toEqual({ cash = 10, gear = { Fins = 1 } })
		t.expect(live.gear == gearRef).toBeTruthy()
	end)

	-- Load / save / locks -----------------------------------------------------------------------

	t.test("load claims the lock, save writes data, leaving releases it", function()
		local DS, store = setup()
		local p = fakePlayer(1)
		DS._test.playerAdded(p)
		t.expect(p.attrs.DataLoaded).toBe(true)
		local rec = store.values.Player_1
		t.expect(rec.version).toBe(DS.Logic.RECORD_VERSION)
		t.expect(rec.session.jobId).toBe("job-A")
		DS.Get(p).cash = 777
		t.expect(DS.Save(p)).toBe(true)
		t.expect(store.values.Player_1.data.cash).toBe(777)
		DS._test.playerRemoving(p)
		t.expect(store.values.Player_1.session).toBeNil()
		t.expect(DS.Get(p)).toBeNil()
	end)

	t.test("a live lock on another server is waited on, then stolen once", function()
		local DS, store, clock = setup()
		store.values.Player_2 = {
			version = 2,
			data = { cash = 50 },
			receipts = {},
			session = { jobId = "B", time = 1000 },
		}
		local p = fakePlayer(2)
		DS._test.playerAdded(p)
		t.expect(DS.Get(p).cash).toBe(50)
		t.expect(store.values.Player_2.session.jobId).toBe("job-A")
		t.expect(clock.waits >= 5).toBeTruthy()
	end)

	t.test("losing the lock to another server stops saves and kicks", function()
		local DS, store = setup()
		local p = fakePlayer(3)
		DS._test.playerAdded(p)
		store.values.Player_3.session = { jobId = "B", time = 1000 }
		store.values.Player_3.data = { cash = 1234 }
		DS.Get(p).cash = 1
		t.expect(DS.Save(p)).toBe(false)
		t.expect(p.kicked ~= nil).toBeTruthy()
		t.expect(store.values.Player_3.data.cash).toBe(1234)
		t.expect(DS.CommitReceipt(p, "r1", function() end)).toBe(false)
	end)

	t.test("a newer record version kicks instead of loading", function()
		local DS, store = setup()
		store.values.Player_4 = { version = 99, data = { cash = 5 } }
		local p = fakePlayer(4)
		DS._test.playerAdded(p)
		t.expect(DS.Get(p)).toBeNil()
		t.expect(p.kicked ~= nil).toBeTruthy()
		t.expect(store.values.Player_4.version).toBe(99)
	end)

	t.test("a failed load gives a temporary profile that never saves", function()
		local DS, store = setup()
		store.values.Player_5 = { version = 2, data = { cash = 500 }, receipts = {} }
		store.failNext = 100
		local p = fakePlayer(5)
		DS._test.playerAdded(p)
		t.expect(p.attrs.DataTemporary).toBe(true)
		store.failNext = 0
		t.expect(DS.Save(p)).toBe(false)
		t.expect(DS.CommitReceipt(p, "r1", function() end)).toBe(false)
		t.expect(store.values.Player_5.data.cash).toBe(500)
	end)

	t.test("leaving during load releases the claimed lock", function()
		local DS, store = setup()
		local p = fakePlayer(6)
		local real = store.UpdateAsync
		function store:UpdateAsync(key, fn)
			local r = real(self, key, fn)
			p.Parent = nil -- left right after the claim
			return r
		end
		DS._test.playerAdded(p)
		t.expect(DS.Get(p)).toBeNil()
		t.expect(store.values.Player_6.session).toBeNil()
	end)

	t.test("retries with backoff, reports to the DataStoreErrors hook", function()
		local DS, store = setup()
		local seen = {}
		DS.OnDataStoreError(function(op, key, _err)
			table.insert(seen, `{op}:{key}`)
		end)
		local p = fakePlayer(7)
		DS._test.playerAdded(p)
		store.failNext = 2
		t.expect(DS.Save(p)).toBe(true)
		t.expect(#seen).toBe(2)
		t.expect(seen[1]).toBe("save:Player_7")
		t.expect(DS.GetDataStoreErrorCounts().save).toBe(2)
	end)

	t.test("waits for request budget before a request", function()
		local DS, _, clock, budget = setup()
		local p = fakePlayer(8)
		DS._test.playerAdded(p)
		budget.value = 0
		local before = clock.t
		t.expect(DS.Save(p)).toBe(true)
		t.expect(clock.t - before >= 9.9).toBeTruthy() -- waited the budget window, then tried anyway
		budget.value = 5
		before = clock.t
		t.expect(DS.Save(p)).toBe(true)
		t.expect(clock.t).toBe(before)
	end)

	t.test("saveAll (BindToClose) saves everyone and gives up by the deadline", function()
		local DS, store = setup()
		local a, b = fakePlayer(9), fakePlayer(10)
		DS._test.playerAdded(a)
		DS._test.playerAdded(b)
		DS.Get(a).cash = 11
		DS.Get(b).cash = 22
		DS._test.saveAll(24)
		t.expect(store.values.Player_9.data.cash).toBe(11)
		t.expect(store.values.Player_10.session).toBeNil()

		local DS2, store2, clock2 = setup()
		local c = fakePlayer(11)
		DS2._test.playerAdded(c)
		store2.failNext = 1000
		local start = clock2.t
		DS2._test.saveAll(24)
		t.expect(clock2.t - start <= 24.5).toBeTruthy()
	end)

	-- Receipts ----------------------------------------------------------------------------------

	t.test("CommitReceipt grants once and commits grant and receipt together", function()
		local DS, store = setup()
		local p = fakePlayer(20)
		DS._test.playerAdded(p)
		local grants = 0
		local function grant(data)
			grants += 1
			data.cash += 1000
			return true
		end
		t.expect(DS.CommitReceipt(p, "purchase-1", grant)).toBe(true)
		t.expect(DS.CommitReceipt(p, "purchase-1", grant)).toBe(true)
		t.expect(grants).toBe(1)
		local rec = store.values.Player_20
		t.expect(rec.data.cash).toBe(DS.Get(p).cash)
		t.expect(rec.receipts["purchase-1"] ~= nil).toBeTruthy()
		t.expect(DS.HasReceipt(p, "purchase-1")).toBe(true)
	end)

	t.test("a failed save returns NotProcessedYet, the retry saves without re-granting", function()
		local DS, store = setup()
		local p = fakePlayer(21)
		DS._test.playerAdded(p)
		local startCash = DS.Get(p).cash
		local grants = 0
		local function grant(data)
			grants += 1
			data.cash += 100
		end
		store.failNext = 1000
		t.expect(DS.CommitReceipt(p, "purchase-2", grant)).toBe(false)
		t.expect(grants).toBe(1)
		t.expect(store.values.Player_21.receipts["purchase-2"]).toBeNil()
		store.failNext = 0
		t.expect(DS.CommitReceipt(p, "purchase-2", grant)).toBe(true)
		t.expect(grants).toBe(1)
		t.expect(store.values.Player_21.data.cash).toBe(startCash + 100)
	end)

	t.test("a grant that errors or returns false is rolled back and not recorded", function()
		local DS = setup()
		local p = fakePlayer(22)
		DS._test.playerAdded(p)
		local cash = DS.Get(p).cash
		t.expect(DS.CommitReceipt(p, "bad-1", function(data)
			data.cash += 50
			error("boom")
		end)).toBe(false)
		t.expect(DS.Get(p).cash).toBe(cash)
		t.expect(DS.HasReceipt(p, "bad-1")).toBe(false)
		t.expect(DS.CommitReceipt(p, "bad-2", function(data)
			data.cash += 50
			return false
		end)).toBe(false)
		t.expect(DS.Get(p).cash).toBe(cash)
		t.expect(DS.HasReceipt(p, "bad-2")).toBe(false)
	end)

	t.test("the ledger survives a rejoin on another server", function()
		local DS, store = setup()
		local p = fakePlayer(23)
		DS._test.playerAdded(p)
		t.expect(DS.CommitReceipt(p, "purchase-3", function(data)
			data.cash += 10
		end)).toBe(true)
		DS._test.playerRemoving(p)

		local DS2 = setup("job-B")
		DS2._test.setStore(store)
		local again = fakePlayer(23)
		DS2._test.playerAdded(again)
		local grants = 0
		t.expect(DS2.CommitReceipt(again, "purchase-3", function()
			grants += 1
		end)).toBe(true)
		t.expect(grants).toBe(0)
	end)

	t.test("CommitReceipt before load or with a bad id is NotProcessedYet", function()
		local DS = setup()
		local p = fakePlayer(24)
		t.expect(DS.CommitReceipt(p, "x", function() end)).toBe(false)
		DS._test.playerAdded(p)
		t.expect(DS.CommitReceipt(p, "", function() end)).toBe(false)
	end)

	t.test("memory mode commits receipts too", function()
		local DS = t.load("src/server/Services/DataService.luau")
		DS._test.setDeps({
			spawn = function(fn, ...)
				fn(...)
			end,
			warn = function() end,
		})
		local p = fakePlayer(25)
		DS._test.playerAdded(p)
		t.expect(DS.CommitReceipt(p, "m-1", function(data)
			data.cash += 1
		end)).toBe(true)
		t.expect(DS._test.memoryRecord(p).receipts["m-1"] ~= nil).toBeTruthy()
	end)
end
