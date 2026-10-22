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
	local HUD = { "status", "objective", "notice", "right", "minimap", "wallet", "goal", "phone" }

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
			-- the minimap is the requested ~130 px square, the phone button at least 64 px
			t.expect(mt.rects.minimap.size.X * mt.scale).toBeCloseTo(130, 1)
			t.expect(mt.rects.phone.size.X * mt.scale >= 64).toBe(true)
		end)
	end

	t.test("the touch phone button and wallet sit right of the minimap", function()
		for _, s in SCREENS do
			local mt = HudLayout.compute(s.screen, s.insets, "Touch")
			local mini, phone, wallet = mt.rects.minimap, mt.rects.phone, mt.rects.wallet
			t.expect(phone.pos.X).toBe(mini.pos.X + mini.size.X + HudLayout.GAP)
			t.expect(phone.pos.Y).toBe(mini.pos.Y)
			t.expect(wallet.pos.X).toBe(phone.pos.X)
		end
	end)

	local DESKTOP = { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(1280, 720) }
	local NO_INSETS = { top = 0, bottom = 0, left = 0, right = 0 }

	t.test("desktop scale grows past 1 on big screens, capped at 1.5", function()
		t.expect(HudLayout.compute(Vector2.new(1920, 1080), NO_INSETS, "Keyboard").scale).toBe(1.5)
		t.expect(HudLayout.compute(Vector2.new(3840, 2160), NO_INSETS, "Keyboard").scale).toBe(1.5)
		t.expect(HudLayout.compute(Vector2.new(800, 450), NO_INSETS, "Keyboard").scale).toBe(0.7)
	end)

	t.test("desktop pins the phone top left, the wallet under it, the card top right", function()
		for _, screen in DESKTOP do
			local mt = HudLayout.compute(screen, NO_INSETS, "Keyboard")
			t.expect(mt.touch).toBe(false)
			local m, g = HudLayout.MARGIN, HudLayout.GAP
			local phone, wallet, right = mt.rects.phone, mt.rects.wallet, mt.rects.right
			t.expect(phone.pos).toEqual(Vector2.new(m, m))
			t.expect(wallet.pos).toEqual(Vector2.new(m, m + phone.size.Y + g))
			t.expect(right.anchor).toEqual(Vector2.new(1, 0))
			t.expect(right.pos).toEqual(Vector2.new(mt.usable.X - m, m))
			local mini = mt.rects.minimap
			t.expect(mini.anchor).toEqual(Vector2.new(0, 1))
			t.expect(mini.pos).toEqual(Vector2.new(m, mt.usable.Y - m))
		end
	end)

	-- the minimap's objective pill ("Mayday 100 m") sits above the square on desktop
	t.test("desktop left column clears the minimap pill, no overlaps", function()
		local LEFT = { "phone", "wallet", "objective", "minimap", "right", "notice", "goal" }
		for _, screen in DESKTOP do
			local mt = HudLayout.compute(screen, NO_INSETS, "Keyboard")
			local _, _, _, oy2 = box(mt.rects.objective)
			local _, my = box(mt.rects.minimap)
			t.expect(oy2 + HudLayout.GAP <= my - HudLayout.PILL_HEIGHT + 1e-6).toBe(true)
			for i = 1, #LEFT do
				for j = i + 1, #LEFT do
					t.expect(overlaps(mt.rects[LEFT[i]], mt.rects[LEFT[j]])).toBe(false)
				end
			end
		end
	end)
end
