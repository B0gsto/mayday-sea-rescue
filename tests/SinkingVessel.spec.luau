-- Sinking vessel: the flooding, pump rhythm, bung, list and abandon maths.
return function(t)
	local S = t.load("src/shared/SinkingVessel.luau")

	t.test("a holed boat starts part-flooded, listing and not yet gone", function()
		local s = S.new()
		t.expect(s.flood).toBe(S.Rates.StartFlood)
		t.expect(s.sunk).toBe(false)
		t.expect(s.crew).toBe(S.Rates.Crew)
		t.expect(s.pumpEffort).toBe(0)
		t.expect(s.strokes).toBe(0)
		t.expect(s.plug).toBe(0)
		t.expect(s.list > 0).toBeTruthy()
		t.expect(S.timeToSink(s) > 0).toBeTruthy()
		t.expect(S.abandoned(s)).toBe(false)
	end)

	t.test("the water rises while the leak is open", function()
		local s = S.new(0.2)
		local before = s.flood
		S.step(s, 10)
		t.expect(s.flood > before).toBeTruthy()
		t.expect(S.settle(s) > 0).toBeTruthy()
		t.expect(s.list > S.Rates.ListStart).toBeTruthy()
	end)

	t.test("an idle pump barely holds her; the rhythm makes the water fall", function()
		local idle = S.new(0.4)
		S.step(idle, 10, { pump = true })
		t.expect(idle.flood > 0.4).toBeTruthy() -- hands off: she still gains a little
		t.expect(idle.pumpEffort).toBe(0)

		local worked = S.new(0.4)
		for _ = 1, S.Rates.PumpStrokes do
			S.step(worked, S.Rates.Beat, { pump = true, beat = true })
		end
		t.expect(worked.flood < 0.4).toBeTruthy()
		t.expect(S.recovering(worked)).toBe(true)
		t.expect(S.timeToSink(worked)).toBe(math.huge)
		t.expect(S.pumpDone(worked)).toBe(true)
		t.expect(worked.strokes).toBe(S.Rates.PumpStrokes)
	end)

	t.test("the rhythm takes 20 to 40 s and effort fades when the beats stop", function()
		t.expect(S.Rates.PumpStrokes * S.Rates.Beat >= 18).toBeTruthy()
		t.expect(S.Rates.PumpStrokes * S.Rates.Beat <= 30).toBeTruthy()

		local s = S.new(0.4)
		for _ = 1, 3 do
			S.step(s, S.Rates.Beat, { pump = true, beat = true })
		end
		t.expect(s.pumpEffort > 0.6).toBe(true)
		S.step(s, 6, { pump = true })
		t.expect(s.pumpEffort).toBe(0)
		t.expect(s.strokes).toBe(3) -- the progress itself never resets
	end)

	t.test("a plug nearly stops the water", function()
		local open = S.new(0.5)
		S.step(open, 10)
		local leakRise = open.flood - 0.5

		local plugged = S.new(0.5)
		S.step(plugged, 10, { plugged = true })
		t.expect(plugged.flood - 0.5 < leakRise * 0.2).toBeTruthy()
		t.expect(S.recovering(plugged)).toBe(false) -- plugging slows her; only the pump makes it fall
	end)

	t.test("holding the bung never resets: release keeps what is done", function()
		local s = S.new(0.2)
		S.step(s, 6, { plug = true })
		local held = S.plugProgress(s)
		t.expect(held > 0.3).toBeTruthy()
		t.expect(held < 1).toBeTruthy()

		S.step(s, 4, { plug = false })
		t.expect(S.plugProgress(s)).toBeCloseTo(held, 1e-9) -- paused, not reset

		S.step(s, 30, { plug = true })
		t.expect(S.plugProgress(s)).toBe(1)
		t.expect(s.plugged).toBe(true)
		t.expect(s.plugging).toBe(false)
	end)

	t.test("pumping an open leak wins; a plug alone just slows her", function()
		local both = S.new(0.4)
		for _ = 1, 8 do
			S.step(both, S.Rates.Beat, { pump = true, beat = true })
		end
		t.expect(both.flood < 0.4).toBeTruthy()

		local plugOnly = S.new(0.4)
		S.step(plugOnly, 20, { plugged = true })
		t.expect(plugOnly.flood > 0.4).toBeTruthy()
		t.expect(plugOnly.flood < 1).toBeTruthy()
	end)

	t.test(
		"left alone she sinks at about the inflow time, and the crew should be off first",
		function()
			local s = S.new(0.2)
			local sinkIn = S.timeToSink(s)
			local offIn = S.timeToAbandon(s)
			t.expect(offIn < sinkIn).toBeTruthy()
			S.step(s, sinkIn + 1)
			t.expect(s.sunk).toBe(true)
			t.expect(S.abandoned(s)).toBe(true)
		end
	)

	t.test("the list grows with the flood and settles to a cap", function()
		local s = S.new(1)
		S.step(s, 0.1)
		t.expect(math.abs(s.list) <= S.Rates.ListMax + S.Rates.Slosh + 1e-6).toBeTruthy()
		local calm = S.new(0)
		S.step(calm, 0.1)
		t.expect(math.abs(calm.list) < S.Rates.ListMax).toBeTruthy()
	end)
end
