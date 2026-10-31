-- BuildSeq (docs/23 (j), WP-14c): the Lego build beat's drop plan: bottom to top, never overtaking
-- delays, drop heights 6-10, and a total that keeps any dock piece under ~6 s.
return function(t)
	local B = t.load("src/shared/BuildSeq.luau")

	t.test("parts drop bottom to top, ties in index order", function()
		local plan = B.plan({ 30, 10, 20, 10, 5 }, 1)
		t.expect(#plan).toBe(5)
		-- index 1 = y 30 (top), index 4 = y 10 (tied with 2, keeps its order)
		t.expect(plan[1].i).toBe(5)
		t.expect(plan[2].i).toBe(2)
		t.expect(plan[3].i).toBe(4)
		t.expect(plan[4].i).toBe(3)
		t.expect(plan[5].i).toBe(1)
	end)

	t.test("delays never overtake and drop heights stay in 6..10", function()
		for _, n in { 1, 5, 25, 45, 120 } do
			local ys = {}
			for i = 1, n do
				table.insert(ys, (i * 37) % 100)
			end
			local plan = B.plan(ys, n)
			t.expect(#plan).toBe(n)
			for k, s in plan do
				t.expect(s.drop >= B.DROP_MIN and s.drop <= B.DROP_MAX).toBe(true)
				if k > 1 then
					t.expect(s.delay >= plan[k - 1].delay).toBe(true)
				end
			end
			t.expect(plan[1].delay).toBe(0)
		end
	end)

	t.test("a whole building stays in the ~3-6 s window", function()
		for _, n in { 10, 25, 45, 120 } do
			local ys = {}
			for i = 1, n do
				table.insert(ys, i)
			end
			local plan = B.plan(ys, 7)
			local last = plan[#plan]
			-- the last drop (0.45) and squash (0.15) fit inside 6 s
			t.expect(last.delay + 0.6 <= 6).toBe(true)
		end
	end)

	t.test("the same seed gives the same plan", function()
		local ys = { 3, 1, 2, 4 }
		local a, b = B.plan(ys, 42), B.plan(ys, 42)
		for k, s in a do
			t.expect(s.i).toBe(b[k].i)
			t.expect(s.delay).toBeCloseTo(b[k].delay, 1e-9)
			t.expect(s.drop).toBeCloseTo(b[k].drop, 1e-9)
		end
	end)

	t.test("course clicks: one per higher course, >= CLICK_GAP apart, pitch rising", function()
		local ys = {}
		for i = 1, 60 do
			table.insert(ys, math.floor(i / 4)) -- 4 bricks a course
		end
		local clicks = B.clicks(B.plan(ys, 3), ys)
		t.expect(#clicks > 1).toBe(true)
		t.expect(clicks[1].pitch).toBeCloseTo(B.PITCH_LO, 1e-9)
		for k = 2, #clicks do
			t.expect(clicks[k].t - clicks[k - 1].t >= B.CLICK_GAP - 1e-9).toBe(true)
			t.expect(clicks[k].pitch > clicks[k - 1].pitch).toBe(true)
			t.expect(clicks[k].pitch <= B.PITCH_HI + 1e-9).toBe(true)
		end
		t.expect(#B.clicks(B.plan({ 5, 5, 5 }, 1), { 5, 5, 5 })).toBe(1) -- one flat course: one click
	end)

	t.test("unlock icon targets", function()
		local vehicles = {
			RIB = { needs = "Boathouse" },
			Lifeboat = { needs = "LifeboatSlip" },
			RescueHelicopter = { needs = "Hangar" },
			StormRunner = { needs = "Shed", passOnly = true },
		}
		local unlocks = { Quests = { key = "HQ", level = 2 } }
		local function lv(...)
			local levels = {}
			for _, e in { ... } do
				table.insert(levels, { effect = e })
			end
			return { levels = levels }
		end
		t.expect(B.unlockTarget("Boathouse", 1, lv("RIB", "LifeboatSlip"), vehicles, unlocks))
			.toBe("Boat")
		t.expect(B.unlockTarget("Boathouse", 2, lv("RIB", "LifeboatSlip"), vehicles, unlocks))
			.toBe("Boat")
		t.expect(B.unlockTarget("AirStation", 1, lv("Helicopter"), vehicles, unlocks)).toBe("Boat")
		t.expect(B.unlockTarget("Shed", 1, lv("Crane"), vehicles, unlocks)).toBe("Next") -- a Robux-only craft
		t.expect(B.unlockTarget("HQ", 2, lv("HQ", "HQ"), vehicles, unlocks)).toBe("Quests")
		t.expect(B.unlockTarget("FishShed", 2, lv("Fishers", "FishSlots4"), vehicles, unlocks))
			.toBe("Crew")
		t.expect(B.unlockTarget("Bunkhouse", 1, lv("People10"), vehicles, unlocks)).toBe("Crew")
		local yard = lv("Mechanics")
		yard.worker = "Mechanic"
		t.expect(B.unlockTarget("BoatYard", 1, yard, vehicles, unlocks)).toBe("Crew")
		t.expect(B.unlockTarget("Depot", 1, lv("Depot"), vehicles, unlocks)).toBe("Next")
		t.expect(B.unlockTarget("Garden", 1, nil, vehicles, unlocks)).toBe("Next")
	end)

	t.test("span bounds the plan's last delay", function()
		for _, n in { 1, 2, 9, 30, 200 } do
			local ys = {}
			for i = 1, n do
				table.insert(ys, i)
			end
			for seed = 1, 5 do
				local plan = B.plan(ys, seed)
				t.expect(plan[#plan].delay <= B.span(n) + 1e-9).toBe(true)
			end
		end
		t.expect(B.span(1)).toBe(0)
	end)
end
