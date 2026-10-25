-- NewPlayerPace: the first 10 minutes (docs/16 section 4), walked headlessly. A fresh profile does
-- the cold open, stays seated, takes the tutorial calls CallLogic picks (answer -> launch ->
-- auto_board -> transport) with the real payouts, buys the jet ski Engine upgrade at the first
-- free moment after call 2 (B5) and can afford its first island building (the unlock tree's cheapest
-- root, docs/23 (q); was the first rank-up, B7). The clock: the cold open as
-- measured (docs/research/playtest-first-20-min.md Round 4), the next-call delay and capacities
-- from config, and per trip the docs/02 travel budget out and back (CallTypes.TRAVEL_SECONDS,
-- about 4x the real Calm Bay distance at jet-ski cruise). Prints the milestone minutes.
return function(t)
	local ProgressionConfig = t.load("src/shared/Config/ProgressionConfig.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local VehicleUpgrades = t.load("src/shared/VehicleUpgrades.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")
	local Grading = t.load("src/shared/Ops/Grading.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")
	local ColdOpen = t.load("src/shared/Boat/ColdOpen.luau")

	local COLD_OPEN = 0.31 -- min: Round 4, cold open Complete at 0:18.7
	local ANSWER = 10 / 60 -- R / tap (or WP3's seated auto-accept)
	local BOARD = 20 / 60 -- slow down, hold steady, they climb on
	local DROP = 15 / 60 -- climb off at the pad, the debrief rolls
	local TRIP = 2 * CallTypes.TRAVEL_SECONDS / 60 -- out and back
	local BUY_MIN = 1 -- open the phone, Vehicles, buy the Engine
	local ENGINE = (VehicleUpgrades.entry("JetSki", "Engine") :: any).price
	local SEATS = VehicleConfig.JetSki.survivorCapacity
	local FIRST_BUILD = math.huge -- the cheapest building that needs only the jetty
	for _, b in DockConfig.Buildings do
		if #b.needs == 0 then
			FIRST_BUILD = math.min(FIRST_BUILD, b.cash)
		end
	end

	local function run(slow: number)
		local data = Rules.defaultData()
		local now = 0
		local completed = 0 -- OperationService st.completed (the cold open is one)
		local events = {}
		local seen = {}
		local cashAt = {}
		local function mark(label: string)
			if not seen[label] then
				seen[label] = now
				table.insert(events, label)
			end
		end
		local function award(cash: number)
			data.cash += (Rules.applyAward(cash, "Calm", false))
			table.insert(cashAt, { at = now, cash = data.cash })
			if data.cash >= ENGINE then
				mark("upgrade affordable")
			end
			if seen["upgrade bought"] and data.cash >= FIRST_BUILD then
				mark("first build affordable")
			end
		end
		local function pay(kind: string)
			local def = Operations.Defs[Operations.FromCallKind[kind]]
			local tut = if completed < #Grading.Payout.Tutorial then completed else nil
			local reward = Grading.payout(def.weight, "Silver", 1, tut)
			completed += 1
			award(reward.cash)
		end

		now = COLD_OPEN
		pay("Swimmer")
		mark("first reward")
		now += ColdOpen.NEXT_CALL_DELAY / 60 -- still seated on the jet ski (B2)
		while now < 20 do
			now += ANSWER * slow
			mark("call 2 starts")
			local choice = CallLogic.chooseCall(completed, "Calm", function()
				return 0.5
			end)
			local trips = math.ceil((choice.victims or 1) / SEATS)
			now += trips * (TRIP + BOARD + DROP) * slow
			pay(choice.kind)
			if not seen["upgrade bought"] and data.cash >= ENGINE then
				now += BUY_MIN * slow
				local streak = StreakRules.claim(StreakRules.newState(), 1792800000)
				if streak then
					award(streak.cash) -- the daily crate on the way
				end
				data.cash -= ENGINE
				mark("upgrade bought")
			end
			now += CallTypes.Scheduler.OfferDelay / 60
		end
		local cash10 = 0
		for _, row in cashAt do
			if row.at <= 10 then
				cash10 = row.cash
			end
		end
		if seen["upgrade bought"] and seen["upgrade bought"] <= 10 then
			cash10 -= ENGINE
		end
		return {
			at = seen,
			events = events,
			rib = cash10 / ProgressionConfig.Vehicles.RIB.price,
		}
	end

	local scenarios = {
		{ name = "Budget clock", r = run(1) },
		{ name = "Slow new player (x1.3)", r = run(1.3) },
	}
	print("\nNewPlayerPace (minutes from spawn)")
	for _, s in scenarios do
		local parts = {}
		for _, label in s.r.events do
			table.insert(parts, string.format("%s %.1f", label, s.r.at[label]))
		end
		print(
			string.format(
				"  %-24s %s | RIB %d%% at 10:00",
				s.name,
				table.concat(parts, ", "),
				math.floor(s.r.rib * 100 + 0.5)
			)
		)
	end

	local main = scenarios[1].r

	t.test("first reward under 1 minute", function()
		t.expect(main.at["first reward"] < 1).toBe(true)
	end)

	t.test("call 2 starts before 2:00 (docs/16 B2)", function()
		for _, s in scenarios do
			t.expect(s.r.at["call 2 starts"] < 2).toBe(true)
		end
	end)

	t.test("first upgrade bought by 6:00 (B5)", function()
		for _, s in scenarios do
			local at = s.r.at["upgrade bought"]
			t.expect(at ~= nil and at <= 6).toBe(true)
		end
	end)

	t.test(
		"the first island building is affordable by 11:00 (was the first rank-up, B7)",
		function()
			for _, s in scenarios do
				local at = s.r.at["first build affordable"]
				t.expect(at ~= nil and at <= 11).toBe(true)
			end
		end
	)

	t.test("the RIB is in sight at 10 minutes", function()
		t.expect(main.rib >= 0.2).toBe(true)
	end)
end
