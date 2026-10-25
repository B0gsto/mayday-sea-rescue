-- A11yPalette: every state has its own symbol, and every pair of colours in a group differs in
-- relative luminance by at least 1.5:1 (the settings' colour-assist palettes included).
return function(t)
	local Pal = t.load("src/shared/A11yPalette.luau")

	local function channel(v: number): number
		return if v <= 0.04045 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end

	local function luminance(c: Color3): number
		return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
	end

	local function contrast(a: Color3, b: Color3): number
		local la, lb = luminance(a), luminance(b)
		return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
	end

	t.test(
		"every palette mode has unique symbols and a >= 1.5:1 luminance gap per group",
		function()
			for _, mode in Pal.Modes do
				Pal.setMode(mode)
				for group, states in Pal.States do
					local seen = {}
					for _, name in states do
						local state = Pal.state(group, name)
						t.expect(state.symbol ~= "").toBe(true)
						t.expect(seen[state.symbol]).toBeNil()
						seen[state.symbol] = true
					end
					for i = 1, #states do
						for j = i + 1, #states do
							local ratio =
								contrast(Pal.colour(group, states[i]), Pal.colour(group, states[j]))
							t.expect(ratio >= 1.5).toBe(true)
						end
					end
				end
			end
		end
	)

	t.test("triage tags differ in shape as well as colour", function()
		local seen = {}
		for _, tag in Pal.States.Triage do
			local shape = Pal.triageShape(tag)
			t.expect(seen[shape]).toBeNil()
			seen[shape] = true
		end
	end)

	t.test("map markers all carry a different glyph", function()
		local seen = {}
		for _, name in
			{
				"Casualty",
				"Vessel",
				"DropOff",
				"Waypoint",
				"Vehicle",
				"Home",
				"Crew",
				"Racer",
				"Storm",
				"SeamarkPort",
				"SeamarkStarboard",
				"SeamarkCardinal",
				"SeamarkSafe",
				"SeamarkDanger",
			}
		do
			local symbol = Pal.symbol("Marker", name)
			t.expect(symbol ~= "?").toBe(true)
			t.expect(seen[symbol]).toBeNil()
			seen[symbol] = true
		end
	end)

	t.test("an unknown mode falls back to the default palette", function()
		Pal.setMode("Nope")
		t.expect(Pal.mode()).toBe("Default")
		Pal.setMode("Off")
		t.expect(Pal.mode()).toBe("Default")
		t.expect(Pal.symbol("Rarity", "Legendary")).toBe("♛")
	end)
end
