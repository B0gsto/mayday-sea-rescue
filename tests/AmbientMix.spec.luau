-- AmbientMix: free-roam survivor density by player count and the spawn mix.
return function(t)
	local AmbientMix = t.load("src/shared/Calls/AmbientMix.luau")
	local SeaZones = t.load("src/shared/Calls/SeaZones.luau")

	t.test("the cap grows with the server and stops at six players", function()
		t.expect(AmbientMix.cap(1)).toBe(9)
		t.expect(AmbientMix.cap(6)).toBe(24)
		t.expect(AmbientMix.cap(12)).toBe(24)
		t.expect(AmbientMix.cap(0)).toBe(6)
	end)

	t.test("mostly lone swimmers, some clusters, the odd dinghy", function()
		local solo, people, dinghy = 0, 0, 0
		for i = 0, 99 do
			local s = AmbientMix.pick(i / 100)
			people += s.total
			solo += if s.kind == "Swimmer" and s.total == 1 then 1 else 0
			dinghy += if s.kind == "DriftingCraft" then 1 else 0
			t.expect(s.total >= 1 and s.total <= 3).toBeTruthy()
		end
		t.expect(solo).toBe(60)
		t.expect(dinghy).toBe(15)
		t.expect(people).toBe(150) -- 1.5 survivors per scene
	end)

	t.test("timed spawns cover every sea zone, in open water (docs/29 B)", function()
		local seen = { 0, 0, 0, 0, 0 }
		local state = 0
		local function rng(): number
			state = (state * 48271 + 11) % 2147483647
			return state / 2147483647
		end
		for _ = 1, 4000 do
			local p = AmbientMix.zonePoint(rng)
			if p then
				local i = SeaZones.zoneAt(p)
				seen[i] += 1
			end
		end
		for _, n in seen do
			t.expect(n > 100).toBe(true)
		end
	end)

	t.test("pay grows with the zone, sight spawns at the Bronze share", function()
		local last = 0
		for _, r in { 1400, 2200, 3400, 4600, 6000 } do
			local pay = AmbientMix.payAt(Vector3.new(r, 0, 0))
			t.expect(pay > last).toBe(true)
			t.expect(AmbientMix.payAt(Vector3.new(r, 0, 0), true) < pay).toBe(true)
			last = pay
		end
		t.expect(AmbientMix.payAt(Vector3.new(1400, 0, 0))).toBe(AmbientMix.CASH)
	end)
end
