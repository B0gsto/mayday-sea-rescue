-- FX1 / FX2: the flipbook sheet table (src/shared/Fx/Flipbooks.luau), the docs/06 3.5 particle
-- budgets per quality tier, and the distress pyrotechnics timing (src/shared/Fx/PyroMath.luau).
return function(t)
	local Flipbooks = t.load("src/shared/Fx/Flipbooks.luau")
	local PyroMath = t.load("src/shared/Fx/PyroMath.luau")
	local AssetIds = t.load("src/shared/Config/AssetIds.luau")

	local LAYOUTS = { None = true, Grid4x4 = true, Grid8x8 = true }
	local MODES = { Loop = true, OneShot = true, PingPong = true, Random = true }

	t.test("every sheet is a valid FX name with a Roblox flipbook layout and mode", function()
		local n = 0
		for name, s in Flipbooks.SHEETS do
			n += 1
			t.expect(string.match(name, "^FX_%u%w*_%u%w*$") ~= nil).toBe(true)
			t.expect(LAYOUTS[s.layout]).toBe(true)
			t.expect(MODES[s.mode]).toBe(true)
			t.expect(s.fps >= 0).toBe(true)
			t.expect(string.sub(s.fallback, 1, 10)).toBe("rbxasset:/")
			if s.mode == "OneShot" then
				t.expect(s.startRandom).toBe(false) -- a one-shot sim always starts at its first frame
			end
		end
		t.expect(n).toBe(18)
	end)

	t.test("only the flame, sparks and parachute star are emissive", function()
		for name, s in Flipbooks.SHEETS do
			local flame = name == "FX_Flare_Head"
				or name == "FX_Flare_Sparks"
				or name == "FX_Flare_Parachute"
			t.expect(s.emissive).toBe(flame)
		end
	end)

	t.test("uploaded ids resolve, and every uploaded FX image is a known sheet", function()
		local fx = AssetIds.Fx or {}
		for name, id in fx do
			t.expect(Flipbooks.SHEETS[name] ~= nil).toBe(true)
			t.expect(string.match(id, "^rbxassetid://%d+$") ~= nil).toBe(true)
			t.expect(Flipbooks.id(name)).toBe(id)
			t.expect(Flipbooks.uploaded(name)).toBe(true)
		end
		for name, s in Flipbooks.SHEETS do
			if not fx[name] then
				t.expect(Flipbooks.id(name)).toBe(s.fallback)
			end
		end
	end)

	t.test(
		"tier budgets follow docs/06 3.5 (Full / Half / Quarter, no spindrift or crest foam on Low)",
		function()
			t.expect(Flipbooks.scale("spray", "High")).toBe(1)
			t.expect(Flipbooks.scale("spray", "Medium")).toBe(0.5)
			t.expect(Flipbooks.scale("spray", "Low")).toBe(0.25)
			t.expect(Flipbooks.scale("rain", "Low")).toBe(0.25)
			t.expect(Flipbooks.scale("spindrift", "Low")).toBe(0)
			t.expect(Flipbooks.scale("crestFoam", "Medium")).toBe(0)
			t.expect(Flipbooks.scale("crestFoam", "High")).toBe(1)
			for _, tier in { "High", "Medium", "Low" } do
				t.expect(Flipbooks.scale("signal", tier)).toBe(1) -- smoke and flares are cues: never dropped
				for kind, row in Flipbooks.SCALE do
					t.expect(row[tier] <= row.High).toBe(true)
					t.expect(Flipbooks.scale(kind, tier) >= 0).toBe(true)
				end
			end
			t.expect(Flipbooks.scale("spray", "Unknown")).toBe(1) -- unknown tier reads as High
			t.expect(Flipbooks.rate("rain", 900, "Low")).toBe(225)
			t.expect(Flipbooks.rate("spray", 7, "Medium")).toBe(3)
		end
	)

	t.test("parachute rocket: climbs to 300 m, burns 40 s falling at 5 m/s, then is out", function()
		local P = PyroMath.PARACHUTE
		t.expect(P.apogee).toBe(900)
		local h0, b0 = PyroMath.parachuteHeight(0)
		t.expect(h0).toBe(0)
		t.expect(b0).toBe(false)
		local hc = PyroMath.parachuteHeight(P.climbSeconds * 0.5)
		t.expect(hc > P.apogee * 0.5).toBe(true) -- ease-out climb
		local ha, ba = PyroMath.parachuteHeight(P.climbSeconds + 0.01)
		t.expect(math.abs(ha - P.apogee) < 1).toBe(true)
		t.expect(ba).toBe(true)
		local h10 = PyroMath.parachuteHeight(P.climbSeconds + 10)
		t.expect(h10).toBeCloseTo(P.apogee - 150, 0.001)
		local _, bEnd = PyroMath.parachuteHeight(P.climbSeconds + P.burnSeconds + 0.1)
		t.expect(bEnd).toBe(false)
		t.expect(PyroMath.parachuteSeconds()).toBe(P.climbSeconds + P.burnSeconds)
	end)

	t.test("flicker stays in a gentle band (no strobing)", function()
		for i = 0, 400 do
			local f = PyroMath.flicker(i * 0.05, 3)
			t.expect(f >= 0.75 and f <= 1.15).toBe(true)
		end
		t.expect(PyroMath.HAND.seconds).toBe(60)
	end)
end
