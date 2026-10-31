-- TestRide (mon REVIEW #7): a locked Robux-only boat rides 60 s in your bay, once a day per boat, server-checked.
return function(t)
	local R = t.load("src/shared/TestRide.luau")
	local TODAY = R.day(1793000000)

	local function base(over)
		local c = {
			passOnly = true,
			passReady = true,
			owned = false,
			need = nil,
			lastDay = nil,
			today = TODAY,
			sinceAsk = 99,
			riding = false,
			busy = false,
		}
		for k, v in over or {} do
			c[k] = v
		end
		return c
	end

	t.test("a locked Robux-only boat on sale can be ridden", function()
		t.expect((R.check(base()))).toBe(true)
		t.expect((R.check(base({ lastDay = TODAY - 1 })))).toBe(true)
	end)

	t.test(
		"refusals: not tryable, owned, needs a building, rate limit, riding, busy, already today",
		function()
			local cases = {
				{ { passOnly = false }, "NotTryable" },
				{ { passReady = false }, "NotTryable" },
				{ { owned = true }, "Owned" },
				{ { need = "Boathouse" }, "Needs" },
				{ { sinceAsk = R.COOLDOWN - 0.1 }, "Cooldown" },
				{ { riding = true }, "Riding" },
				{ { busy = true }, "Busy" },
				{ { lastDay = TODAY }, "Today" },
			}
			for _, case in cases do
				local ok, why = R.check(base(case[1]))
				t.expect({ ok, why }).toEqual({ false, case[2] })
			end
		end
	)

	t.test("once a UTC day per boat: the flag keeps other boats and drops junk", function()
		t.expect(R.day(86400 * 3 - 1)).toBe(2)
		t.expect(R.day(86400 * 3)).toBe(3)
		local flag = R.mark({ RiptideX = TODAY - 1, junk = "x", [5] = 3 }, "StormRunner", TODAY)
		t.expect(flag).toEqual({ RiptideX = TODAY - 1, StormRunner = TODAY })
		t.expect(R.lastDay(flag, "StormRunner")).toBe(TODAY)
		t.expect(R.lastDay(nil, "StormRunner")).toBeNil()
		t.expect(R.lastDay({ StormRunner = "today" }, "StormRunner")).toBeNil()
	end)

	t.test("no rescue Cash while riding; crew pay, spins and quests still land", function()
		t.expect(R.blocksCash("AmbientRescue")).toBe(true)
		t.expect(R.blocksCash("Op:CapsizedFerry:Casualty")).toBe(true)
		t.expect(R.blocksCash("Workers:Gather")).toBe(false)
		t.expect(R.blocksCash("spin")).toBe(false)
		t.expect(R.blocksCash("Quest:FirstRescue")).toBe(false)
	end)

	t.test("past the ring the boat is set back inside it, on its bearing", function()
		local centre = Vector3.new(100, 0, 100)
		t.expect(R.outside(centre + Vector3.new(R.RADIUS - 1, 50, 0), centre)).toBe(false) -- height ignored
		t.expect(R.outside(centre + Vector3.new(0, 0, R.RADIUS + 1), centre)).toBe(true)
		local back = R.turnBack(Vector3.new(100, 2, 100 + R.RADIUS + 20), centre)
		t.expect(math.abs((back - Vector3.new(100, 2, 100 + R.RADIUS * R.EDGE)).Magnitude) < 1e-6)
			.toBe(true)
		t.expect(R.outside(back, centre)).toBe(false)
	end)
end
