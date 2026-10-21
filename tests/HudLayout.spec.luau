-- HudLayout (G51): the touch HUD keeps the minimap and objective off the thumbstick and jump
-- zones, with no overlaps, on a 16:9 phone, a 19.5:9 phone with notch insets and a 4:3 tablet.
return function(t)
	local HudLayout = t.load("src/shared/HudLayout.luau")

	local SCREENS = {
		{
			name = "phone 16:9",
			screen = Vector2.new(666, 374),
			insets = { top = 58, bottom = 0, left = 0, right = 0 },
		},
		{
			name = "phone 19.5:9 (notch)",
			screen = Vector2.new(844, 390),
			insets = { top = 58, bottom = 21, left = 44, right = 44 },
		},
		{
			name = "tablet 4:3",
			screen = Vector2.new(1023, 768),
			insets = { top = 58, bottom = 20, left = 0, right = 0 },
		},
	}
	local HUD =
		{ "status", "objective", "notice", "right", "minimap", "challenge", "goal", "phone" }

	local function box(rect)
		local x = rect.pos.X - rect.anchor.X * rect.size.X
		local y = rect.pos.Y - rect.anchor.Y * rect.size.Y
		return x, y, x + rect.size.X, y + rect.size.Y
	end

	local function overlaps(a, b)
		local ax, ay, ax2, ay2 = box(a)
		local bx, by, bx2, by2 = box(b)
		return ax < bx2 and bx < ax2 and ay < by2 and by < ay2
	end

	for _, s in SCREENS do
		t.test(s.name .. ": touch HUD fits the safe area", function()
			local mt = HudLayout.compute(s.screen, s.insets, "Touch")
			t.expect(mt.touch).toBe(true)
			local u = mt.usable
			for _, name in HUD do
				local x, y, x2, y2 = box(mt.rects[name])
				t.expect(x >= -1e-6 and y >= -1e-6).toBe(true)
				t.expect(x2 <= u.X + 1e-6 and y2 <= u.Y + 1e-6).toBe(true)
				-- bottom-left thumbstick (40% x 45%) and bottom-right jump (30% x 35%) stay clear
				t.expect(x < 0.4 * u.X and y2 > 0.55 * u.Y).toBe(false)
				t.expect(x2 > 0.7 * u.X and y2 > 0.65 * u.Y).toBe(false)
			end
			for i = 1, #HUD do
				for j = i + 1, #HUD do
					t.expect(overlaps(mt.rects[HUD[i]], mt.rects[HUD[j]])).toBe(false)
				end
			end
			-- the minimap is the requested ~110 px square, the challenge icon a 44 px target
			t.expect(mt.rects.minimap.size.X * mt.scale).toBeCloseTo(110, 1)
			t.expect(mt.rects.challenge.size.X * mt.scale).toBeCloseTo(44, 1)
		end)
	end

	t.test("the touch challenge icon sits under the minimap", function()
		for _, s in SCREENS do
			local mt = HudLayout.compute(s.screen, s.insets, "Touch")
			local mini, icon = mt.rects.minimap, mt.rects.challenge
			t.expect(icon.pos.Y >= mini.pos.Y + mini.size.Y).toBe(true)
			t.expect(icon.pos.X).toBe(mini.pos.X)
		end
	end)

	t.test("desktop keeps today's layout", function()
		local mt = HudLayout.compute(
			Vector2.new(1366, 768),
			{ top = 0, bottom = 0, left = 0, right = 0 },
			"Keyboard"
		)
		t.expect(mt.touch).toBe(false)
		local mini = mt.rects.minimap
		local m, g = HudLayout.MARGIN, HudLayout.GAP
		t.expect(mini.anchor).toEqual(Vector2.new(0, 1))
		t.expect(mini.pos).toEqual(Vector2.new(m, mt.usable.Y - m))
		t.expect(mt.rects.status.anchor).toEqual(Vector2.new(1, 0))
		t.expect(mt.rects.challenge.pos.Y)
			.toBe(mt.usable.Y - m - mini.size.Y - HudLayout.PILL_HEIGHT - g - mt.rects.challenge.size.Y)
	end)

	-- the minimap's objective pill ("Mayday 100 m") sits above the square on desktop
	t.test("desktop challenge card clears the minimap pill and the objective", function()
		for _, screen in { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(1280, 720) } do
			local mt =
				HudLayout.compute(screen, { top = 0, bottom = 0, left = 0, right = 0 }, "Keyboard")
			local _, _, _, cy2 = box(mt.rects.challenge)
			local _, my = box(mt.rects.minimap)
			t.expect(cy2 + HudLayout.GAP <= my - HudLayout.PILL_HEIGHT + 1e-6).toBe(true)
			t.expect(overlaps(mt.rects.challenge, mt.rects.objective)).toBe(false)
		end
	end)
end
