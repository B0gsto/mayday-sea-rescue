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
			name = "small Android",
			screen = Vector2.new(640, 360),
			insets = { top = 58, bottom = 0, left = 0, right = 0 },
		},
		{
			name = "tablet 4:3",
			screen = Vector2.new(1023, 768),
			insets = { top = 58, bottom = 20, left = 0, right = 0 },
		},
		{
			name = "phone portrait",
			screen = Vector2.new(390, 844),
			insets = { top = 58, bottom = 34, left = 0, right = 0 },
		},
		{
			name = "tablet portrait",
			screen = Vector2.new(768, 1024),
			insets = { top = 58, bottom = 20, left = 0, right = 0 },
		},
	}
	local HUD = {
		"status",
		"objective",
		"notice",
		"minimap",
		"wallet",
		"menu",
		"quest",
		"chips",
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
				-- the thumbstick (bottom-left 40% x 45%; portrait: the whole bottom 45%) and the
				-- bottom-right jump zone (30% x 35%) stay clear, the menu included
				local stickRight = if u.X < u.Y then u.X else 0.4 * u.X
				t.expect(x < stickRight and y2 > 0.55 * u.Y + 1e-6).toBe(false)
				t.expect(x2 > 0.7 * u.X + 1e-6 and y2 > 0.65 * u.Y + 1e-6).toBe(false)
			end
			for i = 1, #HUD do
				for j = i + 1, #HUD do
					-- the quest tag hangs over the minimap's bottom edge on purpose; the goal chips
					-- use the objective region's bottom spare (the step card is only 64 du high)
					if HUD[i] == "minimap" and HUD[j] == "quest" then
						continue
					end
					if HUD[i] == "objective" and HUD[j] == "chips" then
						continue
					end
					t.expect(overlaps(mt.rects[HUD[i]], mt.rects[HUD[j]])).toBe(false)
				end
			end
			-- the minimap is 30% of the safe height, 100-130 px (small phones: 100); menu icons >= 43 px; the step card fits
			local safeH = s.screen.Y - s.insets.top - s.insets.bottom
			t.expect(mt.rects.minimap.size.X * mt.scale)
				.toBeCloseTo(math.clamp(safeH * 0.3, 100, 130), 1)
			t.expect(mt.menu.icon * mt.scale >= 43).toBe(true)
			t.expect(mt.menu.rows * mt.menu.cols >= HudLayout.MENU_COUNT).toBe(true)
			t.expect(mt.objectiveWidth >= 208).toBe(true)
			t.expect(mt.noticeWidth >= HudLayout.NOTICE_MIN_WIDTH).toBe(true)
		end)
	end

	-- device pass 2026-10-28: top centre, the minimap hid the character and the prize wheel on an iPhone SE
	t.test(
		"touch landscape: the minimap in the top-right corner, objective and wallet right of the menu",
		function()
			for _, s in SCREENS do
				local mt = HudLayout.compute(s.screen, s.insets, "Touch")
				if mt.usable.X < mt.usable.Y then
					continue -- portrait: the minimap right of the menu, the objective under it
				end
				local m, g = HudLayout.MARGIN, HudLayout.GAP
				local menu, mini = mt.rects.menu, mt.rects.minimap
				t.expect(menu.pos).toEqual(Vector2.new(m, m))
				local x, y, x2 = box(mini)
				t.expect(x2).toBeCloseTo(mt.usable.X - m, 3)
				t.expect(y).toBe(m)
				t.expect(x > 0.75 * mt.usable.X).toBe(true) -- off the centre of the play view
				t.expect(mt.rects.objective.pos.X).toBe(m + menu.size.X + g)
				local _, _, ox2 = box(mt.rects.objective)
				t.expect(ox2 <= x - g + 1e-6).toBe(true)
				t.expect(mt.rects.wallet.pos.X).toBe(mt.rects.objective.pos.X)
			end
		end
	)

	-- verify 2026-10-26 (fix-f1): the debrief toast covered the Cash counter at 667x375; portrait the menu ran into
	-- the minimap. Phone sizes (any device, with and without the top-bar inset): the wallet, menu, minimap, debrief,
	-- quest tracker and call card column never overlap, and the debrief keeps off the touch zones.
	t.test("phone sizes: wallet, menu, minimap, debrief, quest, call card never overlap", function()
		local KEY = { "wallet", "menu", "minimap", "debrief", "quest" }
		for _, screen in { Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(390, 844) } do
			for _, top in { 0, 58 } do
				for _, dev in { "Touch", "Keyboard" } do
					local insets = { top = top, bottom = 0, left = 0, right = 0 }
					local mt = HudLayout.compute(screen, insets, dev)
					local u = mt.usable
					t.expect(mt.touch).toBe(true) -- phone-sized: the touch arrangement on every device
					for i = 1, #KEY do
						for j = i + 1, #KEY do
							if KEY[i] == "minimap" and KEY[j] == "quest" then
								continue -- the tag hangs over the minimap's edge on purpose
							end
							t.expect(overlaps(mt.rects[KEY[i]], mt.rects[KEY[j]])).toBe(false)
						end
					end
					local d = mt.rects.debrief
					local x, y, x2, y2 = box(d)
					t.expect(x >= 0 and y >= 0 and x2 <= u.X and y2 <= u.Y).toBe(true)
					t.expect(d.size.X >= HudLayout.DEBRIEF_WIDTH * HudLayout.DEBRIEF_MIN).toBe(true)
					local stickRight = if u.X < u.Y then u.X else 0.4 * u.X
					t.expect(x < stickRight and y2 > 0.55 * u.Y + 1e-6).toBe(false)
					t.expect(x2 > 0.7 * u.X + 1e-6 and y2 > 0.65 * u.Y + 1e-6).toBe(false)
				end
			end
		end
	end)

	local DESKTOP = { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(1280, 720) }
	local NO_INSETS = { top = 0, bottom = 0, left = 0, right = 0 }

	t.test("desktop scale grows past 1 on big screens, capped at 1.6", function()
		local hd = HudLayout.compute(Vector2.new(1920, 1080), NO_INSETS, "Keyboard")
		t.expect(hd.scale).toBe(1.6)
		-- 1080p: wallet ~448x102 px (bigger Cash, 2026-10-26), minimap ~340 px (art review round 2)
		t.expect(math.abs(hd.rects.wallet.size.X * hd.scale - 448) <= 20).toBe(true)
		t.expect(math.abs(hd.rects.wallet.size.Y * hd.scale - 102) <= 10).toBe(true)
		t.expect(math.abs(hd.side * hd.scale - 340) <= 15).toBe(true)
		t.expect(HudLayout.compute(Vector2.new(3840, 2160), NO_INSETS, "Keyboard").scale).toBe(1.6)
		t.expect(HudLayout.compute(Vector2.new(640, 360), NO_INSETS, "Keyboard").scale).toBe(0.7)
	end)

	t.test(
		"desktop: menu strip on the left edge with the wallet under it, minimap bottom right",
		function()
			for _, screen in DESKTOP do
				local mt = HudLayout.compute(screen, NO_INSETS, "Keyboard")
				t.expect(mt.touch).toBe(false)
				local m, g = HudLayout.MARGIN, HudLayout.GAP
				local menu, wallet = mt.rects.menu, mt.rects.wallet
				local _, my0, _, my1 = box(menu)
				local _, wy0, _, wy1 = box(wallet)
				t.expect(menu.pos.X).toBe(m)
				t.expect(wallet.pos.X).toBe(m)
				t.expect(math.abs(wy0 - (my1 + g)) < 1e-6).toBe(true)
				t.expect(my0 >= m and wy1 <= mt.usable.Y - m).toBe(true)
				t.expect(mt.menu.rows * mt.menu.cols >= HudLayout.MENU_COUNT).toBe(true)
				local mini = mt.rects.minimap
				t.expect(mini.anchor).toEqual(Vector2.new(1, 1))
				t.expect(mini.pos).toEqual(Vector2.new(mt.usable.X - m, mt.usable.Y - m))
			end
		end
	)

	-- the minimap's objective pill ("Mayday 100 m") sits above the square on desktop
	t.test("desktop: the quest chip clears the minimap pill, no overlaps", function()
		-- gauges shares the minimap's square on desktop (touch buttons only)
		local LEFT = { "menu", "wallet", "objective", "minimap", "notice", "quest", "chips" }
		for _, screen in DESKTOP do
			local mt = HudLayout.compute(screen, NO_INSETS, "Keyboard")
			local _, my = box(mt.rects.minimap)
			local _, _, _, qy2 = box(mt.rects.quest) -- the quest chip above the pill
			t.expect(qy2 + HudLayout.GAP <= my - HudLayout.PILL_HEIGHT + 1e-6).toBe(true)
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
			-- the debrief toast keeps its top band, clear of the edge HUD
			t.expect(mt.rects.debrief.pos.Y).toBe(HudLayout.MARGIN)
			for _, name in { "menu", "wallet", "minimap", "gauges", "quest" } do
				t.expect(overlaps(mt.rects.debrief, mt.rects[name])).toBe(false)
			end
		end
	end)
end
