-- AmbientMix: free-roam survivor density by player count and the spawn mix.
return function(t)
	local AmbientMix = t.load("src/shared/Calls/AmbientMix.luau")

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
end
