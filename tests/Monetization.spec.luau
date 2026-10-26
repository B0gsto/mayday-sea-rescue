-- Monetization core: the docs/04 catalogue, the deploy.py config shape, the policy gate and
-- idempotent receipt processing (grant once, only after the save commits).
return function(t)
	local Config = t.load("src/shared/Config/MonetizationConfig.luau")
	local Core = t.load("src/server/Services/Monetization/Core.luau")

	-- docs/04 sections 3, 3.1, 3.2, 4.1 and 4.2
	-- docs/04 section 2.1: launch prices (user, 2026-10-21); unbuilt items keep their list price
	local DOC_PRICES = {
		GamePasses = {
			DoubleCash = 75,
			VipCrewCard = 299,
			QuickLaunch = 49,
			BosunsWardrobe = 129,
			WaterDogFriends = 199,
			StormChaserLiveries = 249,
			CaptainsLocker = 99,
			SeaShantyRadio = 79,
			StarterKit = 25,
			HornPack = 79,
			SirenPack = 99,
			LightBars = 129,
			WakeTrails = 149,
			-- vehicle passes (user 2026-10-21): proposed, not in docs/04 yet
			RIBPass = 49,
			LifeboatPass = 129,
			BeachATVPass = 25,
			CoastguardResponsePass = 49,
			StormRunnerPass = 199,
			TidewalkerPass = 249,
			RiptideXPass = 129,
			GildedGullPass = 199,
			HarbourGTPass = 179,
			LighthouseCruiserPass = 149,
			-- docs/23 (h) craft
			RescueHelicopterPass = 399,
			SeaplanePass = 299,
			SubmarinePass = 249,
		},
		Products = {
			SmallBonus = 10,
			CrewPayroll = 25,
			StationBudget = 75,
			HarborFund = 149,
			CashBoost = 15,
			CrewBoost = 15,
			FinishNow1 = 9, -- owner 2026-10-26: tiers by the running site's time left
			FinishNow2 = 25,
			FinishNow3 = 49,
			CallTheStorm = 49,
			CallTheGreatStorm = 149,
			DayDoubleCash = 15, -- day passes: proposed, not in docs/04 yet
			DayQuickLaunch = 10,
			-- island buildings (the old dock-level keys, WP-28): pontoon, boathouse, lookout tower, station
			DockLevel2 = 35,
			DockLevel3 = 35,
			DockLevel4 = 75,
			DockLevel5 = 199,
			DockGarage = 75, -- docs/23 h (WP-10b), prices docs/23 (i)
			DockHangar = 149,
			DockSubPen = 149,
			-- the rest of the tree and the decor (WP-28): docs/23 (i) price table
			DockWorkshop = 15,
			DockFishShed = 35,
			DockBoatYard = 75,
			DockLifeboatSlip = 99,
			DockCrane = 99,
			DockHelipad = 99,
			DockRescueBoathouse = 99,
			DockTrophyHall = 149,
			DockClinic = 199,
			DecorFlowerBed = 35,
			DecorPicnicTable = 49,
			DecorLampRow = 75,
			DecorFlagPole = 99,
			DecorStatue = 199,
			DecorFountain = 199,
			CrewHire = 99, -- docs/23 (j) WP-15, proposed
		},
	}

	local function catalogue(products, passes)
		return { Products = products or {}, GamePasses = passes or {} }
	end
	local function item(id, name, extra)
		local it = { id = id, name = name, description = "Does a thing.", price = 49, order = 1 }
		for k, v in extra or {} do
			it[k] = v
		end
		return it
	end

	t.test("catalogue matches the docs/04 items and prices", function()
		for kind, prices in DOC_PRICES do
			for key, price in prices do
				local it = Config[kind][key]
				t.expect(it ~= nil).toBe(true)
				t.expect(it.price).toBe(price)
			end
			for key in Config[kind] do
				t.expect(prices[key] ~= nil).toBe(true) -- nothing sold that docs/04 does not list
			end
		end
		t.expect(Config.CashPackDailyLimit).toBe(5)
		t.expect(Config.Products.SmallBonus.cashMinutes).toBe(15)
		t.expect(Config.Products.HarborFund.cashMinutes).toBe(420)
		t.expect(Config.Products.HarborFund.valueBonus).toBe(0.2)
		t.expect(Config.Products.CashBoost.boostMinutes).toBe(30)
		t.expect(Config.Products.CrewBoost.cashMultiplier).toBe(1.5)
		t.expect(Config.GamePasses.DoubleCash.cashMultiplier).toBe(2)
		t.expect(Config.GamePasses.StarterKit.cashOnce).toBe(3000)
		for _, key in Config.CashPacks do
			t.expect(Config.Products[key] ~= nil).toBe(true)
		end
		for _, key in { "FinishNow1", "FinishNow2", "FinishNow3" } do
			t.expect(Config.Products[key].ready).toBe(false) -- the owner creates them on Roblox
			t.expect(Config.Products[key].id).toBe(0)
		end
	end)

	t.test("the catalogue validates and nothing is a paid random item", function()
		t.expect(Core.validate(Config)).toEqual({})
		for _, kind in Core.KINDS do
			for _, it in Config[kind] do
				t.expect(it.paidRandom == true).toBe(false)
			end
		end
	end)

	t.test("validate catches duplicate ids and names, bad prices and missing fields", function()
		local problems = Core.validate(catalogue({
			A = item(5, "Same"),
			B = item(5, "Same"),
			C = item(0, "Free", { price = 0 }),
			D = item(0, "", { description = "" }),
		}, { P = item(-1, "Pass", { ready = "yes" }) }))
		local text = table.concat(problems, "\n")
		t.expect(string.find(text, "id 5 also used", 1, true) ~= nil).toBe(true)
		t.expect(string.find(text, "also used by", 1, true) ~= nil).toBe(true)
		t.expect(string.find(text, "Products.C: price", 1, true) ~= nil).toBe(true)
		t.expect(string.find(text, "Products.D: name", 1, true) ~= nil).toBe(true)
		t.expect(string.find(text, "Products.D: description", 1, true) ~= nil).toBe(true)
		t.expect(string.find(text, "GamePasses.P: id", 1, true) ~= nil).toBe(true)
		t.expect(string.find(text, "GamePasses.P: ready", 1, true) ~= nil).toBe(true)
		t.expect(#Core.validate({ Products = {} } :: any) > 0).toBe(true)
	end)

	t.test("source keeps the shape deploy.py rewrites (id first, tab-indented sections)", function()
		local fs = t.lune("fs")
		local src = fs.readFile(t.gameDir .. "/src/shared/Config/MonetizationConfig.luau")
		for _, kind in Core.KINDS do
			local open = string.find(src, "\n\t" .. kind .. " = {", 1, true)
			t.expect(open ~= nil).toBe(true)
			for key in Config[kind] do
				local found = string.match(src, "\n\t\t" .. key .. " = {\n\t\t\tid = (%d+),")
				t.expect(found ~= nil).toBe(true)
				t.expect(tonumber(found)).toBe(Config[kind][key].id)
			end
		end
		-- dump-monetization.luau serializes it to JSON
		local serde = t.lune("serde")
		local json =
			serde.encode("json", { Products = Config.Products, GamePasses = Config.GamePasses })
		t.expect(string.find(json, "Harbor Fund", 1, true) ~= nil).toBe(true)
	end)

	t.test("id 0 and ready = false are never for sale; paid random items need a policy", function()
		t.expect(Core.isForSale(item(0, "x"))).toBe(false)
		t.expect(Core.isForSale(item(7, "x", { ready = false }))).toBe(false)
		t.expect(Core.isForSale(item(7, "x"))).toBe(true)
		t.expect(Core.isForSale(nil)).toBe(false)
		local random = item(8, "r", { paidRandom = true })
		t.expect(Core.isOffered(random, nil)).toBe(false)
		t.expect(Core.isOffered(random, { ArePaidRandomItemsRestricted = true })).toBe(false)
		t.expect(Core.isOffered(random, { ArePaidRandomItemsRestricted = false })).toBe(true)
		t.expect(Core.isOffered(item(7, "x"), nil)).toBe(true)
		for _, kind in Core.KINDS do
			for _, it in Config[kind] do
				if it.id == 0 then
					t.expect(Core.isOffered(it, { ArePaidRandomItemsRestricted = false }))
						.toBe(false)
				end
			end
		end
		local index =
			Core.index(catalogue({ A = item(11, "a"), Z = item(0, "z") }, { P = item(12, "p") }))
		t.expect(index.productKeyById[11]).toBe("A")
		t.expect(index.passKeyById[12]).toBe("P")
		t.expect(index.productKeyById[0]).toBeNil()
	end)

	t.test("commit results from either DataService shape are understood", function()
		t.expect(Core.commitSucceeded(true)).toBe(true)
		t.expect(Core.commitSucceeded("Granted")).toBe(true)
		t.expect(Core.commitSucceeded("AlreadyGranted")).toBe(true)
		t.expect(Core.commitSucceeded({ ok = true })).toBe(true)
		t.expect(Core.commitSucceeded(false)).toBe(false)
		t.expect(Core.commitSucceeded(nil)).toBe(false)
		t.expect(Core.commitSucceeded("SaveFailed")).toBe(false)
		t.expect(Core.commitSucceeded({ ok = false })).toBe(false)
	end)

	-- A stand-in for RP-D1's DataService.CommitReceipt: the ledger is persisted with the profile.
	local function fakeDataService()
		local ds = { saveOk = true, saves = 0, stored = {}, live = {} }
		function ds.load(player)
			local saved = ds.stored[player.UserId]
			local data = { cash = 0, receipts = {} }
			if saved then
				data.cash = saved.cash
				data.receipts = table.clone(saved.receipts)
			end
			ds.live[player] = data
		end
		function ds.CommitReceipt(player, id, grantFn)
			local data = ds.live[player]
			if not data then
				return false
			end
			if not data.receipts[id] then
				local ok = pcall(grantFn, data)
				if not ok then
					return false
				end
				data.receipts[id] = true
			end
			ds.saves += 1
			if not ds.saveOk then
				return false
			end
			ds.stored[player.UserId] = { cash = data.cash, receipts = table.clone(data.receipts) }
			return true
		end
		return ds
	end

	local CASH_ID = 101
	local function processor(ds, players, opts)
		opts = opts or {}
		local after = {}
		local handlers = {
			Cash = {
				grant = function(_player, data, _receipt)
					if opts.failGrant then
						error("no room")
					end
					data.cash += 1000
				end,
				afterSaved = function(_player, receipt, fresh)
					table.insert(after, { id = receipt.PurchaseId, fresh = fresh })
				end,
			},
		}
		local process = Core.newReceiptProcessor({
			index = Core.index(
				catalogue({ Cash = item(CASH_ID, "Cash"), NoHandler = item(102, "None") })
			),
			getPlayer = function(userId)
				return players[userId]
			end,
			waitForData = function(player)
				return ds.live[player] ~= nil
			end,
			commit = opts.commit or ds.CommitReceipt,
			handlers = handlers,
			log = function() end,
		})
		return process, after
	end

	local function receipt(purchaseId, productId, playerId)
		return {
			PurchaseId = purchaseId,
			ProductId = productId or CASH_ID,
			PlayerId = playerId or 1,
		}
	end

	t.test("a receipt is granted once, after the save, and retries never double-grant", function()
		local ds = fakeDataService()
		local player = { UserId = 1 }
		ds.load(player)
		local process, after = processor(ds, { [1] = player })
		t.expect(process(receipt("p1"))).toBe("PurchaseGranted")
		t.expect(ds.live[player].cash).toBe(1000)
		t.expect(process(receipt("p1"))).toBe("PurchaseGranted") -- Roblox retried: already in the ledger
		t.expect(ds.live[player].cash).toBe(1000)
		t.expect(#after).toBe(2)
		t.expect(after[1].fresh).toBe(true)
		t.expect(after[2].fresh).toBe(false)
		t.expect(process(receipt("p2"))).toBe("PurchaseGranted")
		t.expect(ds.live[player].cash).toBe(2000)
		-- rejoin on a new server: the persisted ledger still blocks p1
		ds.live[player] = nil
		ds.load(player)
		local process2 = processor(ds, { [1] = player })
		t.expect(process2(receipt("p1"))).toBe("PurchaseGranted")
		t.expect(ds.live[player].cash).toBe(2000)
	end)

	t.test("every failure path returns NotProcessedYet", function()
		local ds = fakeDataService()
		local player = { UserId = 1 }
		local process = processor(ds, { [1] = player })
		t.expect(process(receipt("a"))).toBe("NotProcessedYet") -- data not loaded
		ds.load(player)
		t.expect(process(receipt("b", CASH_ID, 99))).toBe("NotProcessedYet") -- player not in server
		t.expect(process(receipt("c", 555))).toBe("NotProcessedYet") -- unknown product id
		t.expect(process(receipt("d", 102))).toBe("NotProcessedYet") -- product without a handler
		t.expect(process({ ProductId = CASH_ID, PlayerId = 1 })).toBe("NotProcessedYet") -- no purchase id
		ds.saveOk = false
		t.expect(process(receipt("e"))).toBe("NotProcessedYet") -- save failed
		t.expect(ds.stored[1]).toBeNil()
		ds.saveOk = true
		t.expect(process(receipt("e"))).toBe("PurchaseGranted") -- retry saves the grant held in memory
		t.expect(ds.live[player].cash).toBe(1000)
		t.expect(ds.stored[1].cash).toBe(1000)
		local failing = processor(ds, { [1] = player }, { failGrant = true })
		t.expect(failing(receipt("f"))).toBe("NotProcessedYet")
		t.expect(ds.live[player].receipts.f).toBeNil()
		local erroring = processor(ds, { [1] = player }, {
			commit = function()
				error("DataStore down")
			end,
		})
		t.expect(erroring(receipt("g"))).toBe("NotProcessedYet")
	end)

	t.test("a receipt already being processed is not processed twice at once", function()
		local ds = fakeDataService()
		local player = { UserId = 1 }
		ds.load(player)
		local process
		local inner
		process = processor(ds, { [1] = player }, {
			commit = function(p, id, grantFn)
				inner = process(receipt(id))
				return ds.CommitReceipt(p, id, grantFn)
			end,
		})
		t.expect(process(receipt("x"))).toBe("PurchaseGranted")
		t.expect(inner).toBe("NotProcessedYet")
		t.expect(ds.live[player].cash).toBe(1000)
	end)

	t.test(
		"the fallback ledger grants once per session and only reports a committed save",
		function()
			local data = { cash = 0 }
			local state = { saveOk = true, temporary = false, dirty = 0 }
			local player = { UserId = 7 }
			local commit = Core.newFallbackCommit({
				getData = function(p)
					return if p == player then data else nil
				end,
				isTemporary = function()
					return state.temporary
				end,
				markDirty = function()
					state.dirty += 1
				end,
				save = function()
					return state.saveOk
				end,
				keyOf = function(p)
					return p.UserId
				end,
			})
			local function grant(d)
				d.cash += 500
			end
			state.saveOk = false
			t.expect(commit(player, "r1", grant)).toBe(false)
			t.expect(data.cash).toBe(500) -- held in memory for the next save
			state.saveOk = true
			t.expect(commit(player, "r1", grant)).toBe(true)
			t.expect(data.cash).toBe(500)
			t.expect(commit({ UserId = 7 }, "r1", grant)).toBe(false) -- unknown player object: no data
			state.temporary = true
			t.expect(commit(player, "r2", grant)).toBe(false) -- never grant onto a temporary profile
			state.temporary = false
			t.expect(commit(player, "r3", function()
				error("bad")
			end)).toBe(false)
			t.expect(commit(player, "r3", grant)).toBe(true) -- the failed attempt was not recorded
			t.expect(data.cash).toBe(1000)
			t.expect(state.dirty).toBe(2)
		end
	)
end
