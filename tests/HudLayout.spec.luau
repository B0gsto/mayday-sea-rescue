-- HudLayout (G51, WP-23c): the touch HUD keeps the minimap and objective off the thumbstick and
-- jump zones, with no overlaps, on a 16:9 phone, a 19.5:9 phone with notch insets and a 4:3 tablet;
-- the left menu strip stays narrow and every other left-hand region sits right of it.
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
	local HUD = {
		"status",
		"objective",
		"notice",
		"right",
		"minimap",
		"wallet",
		"menu",
	}

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
				-- bottom-left thumbstick (40% x 45%) and bottom-right jump (30% x 35%) stay clear;
				-- only the narrow menu strip on the very left edge may reach into the stick zone
				if name ~= "menu" then
					t.expect(x < 0.4 * u.X and y2 > 0.55 * u.Y).toBe(false)
				end
				t.expect(x2 > 0.7 * u.X and y2 > 0.65 * u.Y).toBe(false)
			end
			for i = 1, #HUD do
				for j = i + 1, #HUD do
					t.expect(overlaps(mt.rects[HUD[i]], mt.rects[HUD[j]])).toBe(false)
				end
			end
			-- the minimap is the requested ~130 px square; menu icons >= 43 px, the strip < 20% wide
			t.expect(mt.rects.minimap.size.X * mt.scale).toBeCloseTo(130, 1)
			t.expect(mt.menu.icon * mt.scale >= 43).toBe(true)
			t.expect(mt.menu.rows * mt.menu.cols >= HudLayout.MENU_COUNT).toBe(true)
			local _, _, mx2 = box(mt.rects.menu)
			t.expect(mx2 <= 0.2 * u.X).toBe(true)
			t.expect(mt.noticeWidth >= HudLayout.NOTICE_MIN_WIDTH).toBe(true)
		end)
	end

	t.test(
		"touch: the minimap sits right of the menu, objective and wallet right of the minimap",
		function()
			for _, s in SCREENS do
				local mt = HudLayout.compute(s.screen, s.insets, "Touch")
				local m, g = HudLayout.MARGIN, HudLayout.GAP
				local menu, mini = mt.rects.menu, mt.rects.minimap
				t.expect(menu.pos).toEqual(Vector2.new(m, m))
				t.expect(mini.pos.X).toBe(m + menu.size.X + g)
				t.expect(mt.rects.objective.pos.X).toBe(mini.pos.X + mini.size.X + g)
				t.expect(mt.rects.wallet.pos.X).toBe(mt.rects.objective.pos.X)
			end
		end
	)

	local DESKTOP = { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(1280, 720) }
	local NO_INSETS = { top = 0, bottom = 0, left = 0, right = 0 }

	t.test("desktop scale grows past 1 on big screens, capped at 1.6", function()
		local hd = HudLayout.compute(Vector2.new(1920, 1080), NO_INSETS, "Keyboard")
		t.expect(hd.scale).toBe(1.6)
		-- 1080p: wallet ~360x86 px (Cash only, WP-28), minimap ~340 px (art review round 2)
		t.expect(math.abs(hd.rects.wallet.size.X * hd.scale - 370) <= 20).toBe(true)
		t.expect(math.abs(hd.rects.wallet.size.Y * hd.scale - 86) <= 10).toBe(true)
		t.expect(math.abs(hd.side * hd.scale - 340) <= 15).toBe(true)
		t.expect(HudLayout.compute(Vector2.new(3840, 2160), NO_INSETS, "Keyboard").scale).toBe(1.6)
		t.expect(HudLayout.compute(Vector2.new(640, 360), NO_INSETS, "Keyboard").scale).toBe(0.7)
	end)

	t.test(
		"desktop: menu strip on the left edge, wallet and minimap beside it, card top right",
		function()
			for _, screen in DESKTOP do
				local mt = HudLayout.compute(screen, NO_INSETS, "Keyboard")
				t.expect(mt.touch).toBe(false)
				local m, g = HudLayout.MARGIN, HudLayout.GAP
				local menu, wallet, right = mt.rects.menu, mt.rects.wallet, mt.rects.right
				local left = m + menu.size.X + g
				t.expect(menu.anchor).toEqual(Vector2.new(0, 0.5))
				t.expect(menu.pos).toEqual(Vector2.new(m, mt.usable.Y / 2))
				t.expect(menu.size.Y <= mt.usable.Y - 2 * m).toBe(true)
				t.expect(wallet.pos).toEqual(Vector2.new(left, m))
				t.expect(right.anchor).toEqual(Vector2.new(1, 0))
				t.expect(right.pos).toEqual(Vector2.new(mt.usable.X - m, m))
				local mini = mt.rects.minimap
				t.expect(mini.anchor).toEqual(Vector2.new(0, 1))
				t.expect(mini.pos).toEqual(Vector2.new(left, mt.usable.Y - m))
			end
		end
	)

	-- the minimap's objective pill ("Mayday 100 m") sits above the square on desktop
	t.test("desktop left column clears the minimap pill, no overlaps", function()
		local LEFT = { "menu", "wallet", "objective", "minimap", "right", "notice", "gauges" }
		for _, screen in DESKTOP do
			local mt = HudLayout.compute(screen, NO_INSETS, "Keyboard")
			local _, _, _, oy2 = box(mt.rects.objective)
			local _, my = box(mt.rects.minimap)
			t.expect(oy2 + HudLayout.GAP <= my - HudLayout.PILL_HEIGHT + 1e-6).toBe(true)
			t.expect(mt.noticeWidth >= 200).toBe(true)
			for i = 1, #LEFT do
				for j = i + 1, #LEFT do
					t.expect(overlaps(mt.rects[LEFT[i]], mt.rects[LEFT[j]])).toBe(false)
				end
			end
			-- the prompt (mechanic panels) clears the minimap, the gauges and the menu
			for _, name in { "minimap", "gauges", "menu" } do
				t.expect(overlaps(mt.rects.prompt, mt.rects[name])).toBe(false)
			end
		end
	end)
end
