-- Challenges: deterministic daily/weekly rolls, UTC rollover, operation counters, the daily set
-- bonus, weekly stamps, rerolls, reward scaling and the profile flag encoding (LU-1).
return function(t)
	local Rules = t.load("src/shared/ChallengeRules.luau")
	local Config = t.load("src/shared/Config/ChallengeConfig.luau")

	local DAY = 86400
	local NOW = 1790000000 -- 2026-09-21, a Monday, mid-morning UTC

	t.test("UTC day and week keys, and their reset countdowns", function()
		t.expect(Rules.dayIndex(NOW)).toBe(math.floor(NOW / DAY))
		t.expect(Rules.secondsToDay(NOW)).toBe((Rules.dayIndex(NOW) + 1) * DAY - NOW)
		-- 2026-09-21 is a Monday: week 2972 starts at 2026-09-21 00:00 UTC
		local monday = math.floor(NOW / DAY) * DAY
		t.expect(Rules.weekIndex(monday)).toBe(Rules.weekIndex(monday + 6 * DAY))
		t.expect(Rules.weekIndex(monday - 1) ~= Rules.weekIndex(monday)).toBe(true)
		t.expect(Rules.secondsToWeek(monday)).toBe(7 * DAY)
	end)

	t.test(
		"roll is deterministic per player and period, distinct and from the right pool",
		function()
			local a = Rules.roll("daily", Config.DailyCount, 12345)
			local b = Rules.roll("daily", Config.DailyCount, 12345)
			local c = Rules.roll("daily", Config.DailyCount, 12346)
			t.expect(a).toEqual(b)
			t.expect(a == c).toBe(false)
			t.expect(#a).toBe(Config.DailyCount)
			local seen = {}
			for _, id in a do
				t.expect(seen[id]).toBeNil()
				seen[id] = true
				local def = Rules.def(id)
				t.expect(def ~= nil).toBe(true)
				t.expect(def.scope).toBe("daily")
			end
			local w = Rules.roll("weekly", Config.WeeklyCount, 999)
			t.expect(#w).toBe(Config.WeeklyCount)
			for _, id in w do
				t.expect(Rules.def(id).scope).toBe("weekly")
			end
		end
	)

	t.test("a new state rolls 3 daily and 5 weekly, all at zero", function()
		local s = Rules.newState(42, NOW)
		t.expect(#s.daily).toBe(Config.DailyCount)
		t.expect(#s.weekly).toBe(Config.WeeklyCount)
		t.expect(s.rerolls).toBe(0)
		t.expect(s.stamps).toBe(0)
		for _, slot in s.daily do
			t.expect(slot.progress).toBe(0)
		end
	end)

	t.test("rollover replaces the daily set and resets rerolls, keeps stamps", function()
		local s = Rules.newState(42, NOW)
		s.stamps = 3
		s.rerolls = 2
		s.daily[1].progress = 2
		s.dailyBonus = true
		local nextDay = NOW + DAY
		local rolled, changed = Rules.ensure(s, 42, nextDay)
		t.expect(changed).toBe(true)
		t.expect(rolled.day).toBe(Rules.dayIndex(nextDay))
		t.expect(rolled.rerolls).toBe(0)
		t.expect(rolled.dailyBonus).toBe(false)
		t.expect(rolled.stamps).toBe(3)
		for _, slot in rolled.daily do
			t.expect(slot.progress).toBe(0)
		end
	end)

	t.test(
		"operation counters cover ops, kind, storm, big calls, crew, rescues, gold and finds",
		function()
			local snap = {
				kind = "PersonInWater",
				grade = "Gold",
				storm = true,
				isBig = false,
				saved = 3,
				towParted = false,
				steps = {
					{ id = "search", grade = "Gold", userId = 7 },
					{ id = "treatment", grade = "Silver", userId = 7 },
					{ id = "approach", grade = "Gold", userId = 99 },
					{ id = "recovery", grade = "Fail", userId = 7 },
				},
			}
			local counts = Rules.operationCredit(snap, 7, 3)
			t.expect(counts.ops).toBe(1)
			t.expect(counts["op:PersonInWater"]).toBe(1)
			t.expect(counts.stormOps).toBe(1)
			t.expect(counts.crewOps).toBe(1)
			t.expect(counts.rescues).toBe(3)
			t.expect(counts.goldSteps).toBe(1)
			t.expect(counts.finds).toBe(1)
			t.expect(counts.treatments).toBe(1)
			t.expect(counts.tows).toBeNil()
			local takeover =
				Rules.operationCredit({ kind = "PersonInWater", grade = "Takeover" }, 7, 1)
			t.expect(takeover.ops).toBeNil()
			local fail = Rules.operationCredit({ kind = "PersonInWater", grade = "Fail" }, 7, 1)
			t.expect(fail.ops).toBeNil()
		end
	)

	t.test("a clean tow pays only for DisabledVessel with the line intact", function()
		local clean = Rules.operationCredit(
			{ kind = "DisabledVessel", grade = "Silver", towParted = false },
			1,
			1
		)
		t.expect(clean.tows).toBe(1)
		local parted = Rules.operationCredit(
			{ kind = "DisabledVessel", grade = "Silver", towParted = true },
			1,
			1
		)
		t.expect(parted.tows).toBeNil()
		t.expect(parted.ops).toBe(1)
		local piw = Rules.operationCredit({ kind = "PersonInWater", grade = "Silver" }, 1, 1)
		t.expect(piw.tows).toBeNil()
	end)

	t.test("progress caps and each completion is reported once", function()
		local s = Rules.newState(1, NOW)
		s.daily = { { id = "d_rescue", progress = 0 } }
		s.weekly = {}
		local first = Rules.addProgress(s, { rescues = 2 })
		t.expect(#first).toBe(0)
		t.expect(s.daily[1].progress).toBe(2)
		local second = Rules.addProgress(s, { rescues = 5 })
		t.expect(#second).toBe(1)
		t.expect(second[1].id).toBe("d_rescue")
		t.expect(s.daily[1].progress).toBe(3)
		local third = Rules.addProgress(s, { rescues = 5 })
		t.expect(#third).toBe(0)
		t.expect(s.daily[1].progress).toBe(3)
	end)

	t.test("daily set bonus and weekly stamp settle once", function()
		local s = Rules.newState(3, NOW)
		s.daily = {
			{ id = "d_ops", progress = 3 },
			{ id = "d_rescue", progress = 3 },
			{ id = "d_gold", progress = 5 },
		}
		s.weekly = { { id = "w_ops", progress = 10 } }
		local first = Rules.settle(s)
		t.expect(first.dailyBonus).toBe(true)
		t.expect(first.weeklyStamp).toBe(true)
		t.expect(s.stamps).toBe(1)
		local again = Rules.settle(s)
		t.expect(again.dailyBonus).toBe(false)
		t.expect(again.weeklyStamp).toBe(false)
		t.expect(s.stamps).toBe(1)
	end)

	t.test("monthly stamps reset each UTC month and unlock at four", function()
		t.expect(Rules.monthKey(NOW)).toBe("2026-09")
		local first, unlocked = Rules.monthlyStamp(nil, NOW)
		t.expect(first.month).toBe("2026-09")
		t.expect(first.stamps).toBe(1)
		t.expect(unlocked).toBe(false)
		local fourth, hit = Rules.monthlyStamp({ month = "2026-09", stamps = 3 }, NOW)
		t.expect(fourth.stamps).toBe(4)
		t.expect(hit).toBe(true)
		local fifth, hitAgain = Rules.monthlyStamp(fourth, NOW)
		t.expect(fifth.stamps).toBe(5)
		t.expect(hitAgain).toBe(true)
		local nextMonth = NOW + 15 * DAY
		t.expect(Rules.monthKey(nextMonth)).toBe("2026-10")
		local fresh, reset = Rules.monthlyStamp(fourth, nextMonth)
		t.expect(fresh.month).toBe("2026-10")
		t.expect(fresh.stamps).toBe(1)
		t.expect(reset).toBe(false)
	end)

	t.test("reroll swaps the first unfinished daily, not a done one, three times a day", function()
		local s = Rules.newState(5, NOW)
		s.daily = {
			{ id = "d_ops", progress = 3 },
			{ id = "d_rescue", progress = 0 },
			{ id = "d_gold", progress = 0 },
		}
		local before = s.daily[2].id
		local picked = Rules.rerollDaily(s, 5, NOW)
		t.expect(picked ~= nil).toBe(true)
		t.expect(s.daily[1].id).toBe("d_ops")
		t.expect(s.daily[2].id).toBe(picked)
		t.expect(s.daily[2].id ~= before).toBe(true)
		t.expect(s.rerolls).toBe(1)
		Rules.rerollDaily(s, 5, NOW)
		Rules.rerollDaily(s, 5, NOW)
		t.expect(s.rerolls).toBe(3)
		t.expect(Rules.rerollDaily(s, 5, NOW)).toBeNil()
	end)

	t.test("rewards scale with the highest open zone base", function()
		local daily = Rules.def("d_ops")
		local cash, rep = Rules.rewardFor(daily, 1)
		t.expect(cash).toBe(math.floor(550 * 1.4 + 0.5))
		t.expect(rep).toBe(math.floor(135 * 0.9 + 0.5))
		local topCash, topRep = Rules.rewardFor(daily, 3)
		t.expect(topCash).toBe(math.floor(1500 * 1.4 + 0.5))
		t.expect(topRep).toBe(math.floor(280 * 0.9 + 0.5))
		local wkCash, wkRep = Rules.rewardFor(Rules.def("w_ops"), 3)
		t.expect(wkCash).toBe(math.floor(1500 * 4.5 + 0.5))
		t.expect(wkRep).toBe(math.floor(280 * 2.3 + 0.5))
		-- ranks between zone gates keep the last open zone (Rescue Pilot is still Open Sea)
		t.expect((Rules.rewardFor(daily, 5))).toBe(topCash)
		-- Captain and Commodore open Storm Front and Iceberg North
		t.expect((Rules.rewardFor(daily, 6))).toBe(math.floor(2400 * 1.4 + 0.5))
		t.expect((Rules.rewardFor(daily, 7))).toBe(math.floor(3300 * 1.4 + 0.5))
		-- the clamp keeps a bad rank on the last base
		t.expect((Rules.rewardFor(daily, 99))).toBe(math.floor(3300 * 1.4 + 0.5))
	end)

	t.test("profile flag round trip keeps ids, progress, rerolls and stamps", function()
		local s = Rules.newState(77, NOW)
		s.daily[1].progress = 2
		s.weekly[3].progress = 1
		s.rerolls = 1
		s.stamps = 2
		s.dailyBonus = false
		s.weeklyStamp = true
		local flat = Rules.flagTable(s)
		local restored = Rules.fromFlagTable(flat)
		local again, changed = Rules.ensure(restored, 77, NOW)
		t.expect(changed).toBe(false)
		t.expect(again.day).toBe(s.day)
		t.expect(again.week).toBe(s.week)
		t.expect(again.daily[1].id).toBe(s.daily[1].id)
		t.expect(again.daily[1].progress).toBe(2)
		t.expect(again.weekly[3].id).toBe(s.weekly[3].id)
		t.expect(again.weekly[3].progress).toBe(1)
		t.expect(again.rerolls).toBe(1)
		t.expect(again.stamps).toBe(2)
		t.expect(again.weeklyStamp).toBe(true)
		-- all 22 fields fit a sanitized flag (24 scalar fields max)
		local n = 0
		for _ in flat do
			n += 1
		end
		t.expect(n <= 24).toBe(true)
	end)

	t.test("corrupt flags roll a fresh state instead of failing", function()
		local s, changed = Rules.ensure("garbage", 1, NOW)
		t.expect(changed).toBe(true)
		t.expect(#s.daily).toBe(Config.DailyCount)
		local bad = Rules.fromFlagTable({ p = Rules.dayIndex(NOW), w = Rules.weekIndex(NOW) })
		local fixed, again = Rules.ensure(bad, 1, NOW)
		t.expect(again).toBe(true)
		t.expect(#fixed.weekly).toBe(Config.WeeklyCount)
	end)

	t.test("client view carries deduped progress and the reset clocks", function()
		local s = Rules.newState(9, NOW)
		s.daily[1].progress = 99
		local clamped = Rules.ensure(s, 9, NOW)
		local view = Rules.view(clamped, NOW)
		t.expect(#view.daily).toBe(Config.DailyCount)
		t.expect(view.daily[1].progress).toBe(view.daily[1].target)
		t.expect(view.daily[1].done).toBe(true)
		t.expect(view.rerollLimit).toBe(Config.RerollDailyLimit)
		t.expect(view.secondsToDay > 0 and view.secondsToDay <= DAY).toBe(true)
	end)
end
