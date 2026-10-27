-- WorkLoop (docs/25 G): every survivor Job has a 2-3 beat loop, holds are stretched per worker so a crew never moves
-- in step, and night wraps midnight.
return function(t)
	local W = t.load("src/shared/WorkLoop.luau")

	t.test("every job loops 2-3 beats, not one pose", function()
		for _, job in { "Build", "Fish", "Repair", "Heal", "Rescue", "Gather" } do
			local n = #W.BEATS[job]
			t.expect(n >= 2 and n <= 3).toBe(true)
		end
	end)

	t.test("jitter stays in 0.75..1.25 and differs between neighbouring workers", function()
		local seen = {}
		for seed = 1, 40 do
			local j = W.jitter(1234567890 + seed, 1)
			t.expect(j >= 0.75 and j <= 1.25).toBe(true)
			seen[math.floor(j * 100)] = true
		end
		local distinct = 0
		for _ in seen do
			distinct += 1
		end
		t.expect(distinct >= 15).toBe(true)
		t.expect(W.jitter(7, 2)).toBe(W.jitter(7, 2))
	end)

	t.test("night runs from dusk over midnight to dawn", function()
		t.expect(W.isNight(14)).toBe(false)
		t.expect(W.isNight(17.3)).toBe(false)
		t.expect(W.isNight(21.5)).toBe(true)
		t.expect(W.isNight(0)).toBe(true)
		t.expect(W.isNight(6.25)).toBe(false)
	end)

	t.test("home from HOME to dawn, each worker a little late, never early", function()
		t.expect(W.isHome(14, 1)).toBe(false)
		t.expect(W.isHome(W.HOME - 0.01, 1)).toBe(false)
		t.expect(W.isHome(W.HOME + W.LAG + 0.01, 1)).toBe(true)
		t.expect(W.isHome(0.1, 1)).toBe(true) -- wraps midnight
		t.expect(W.isHome(W.DAWN + W.LAG + 0.01, 1)).toBe(false)
		local early, late = 0, 0
		for seed = 1, 40 do
			if W.isHome(W.HOME + W.LAG / 2, seed) then
				early += 1
			else
				late += 1
			end
		end
		t.expect(early > 0 and late > 0).toBe(true) -- a crew trickles, not one step
	end)
end
