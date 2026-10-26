-- Kit Theme (WP-23b): viewport scaling, panel fit, the icon bar's columns, price text and the
-- colour-blind buy / close pairs.
return function(t)
	local Theme = t.load("src/client/UI/Kit/Theme.luau")

	t.test("scale is 1 at 1280x720, floors on phones, caps on big screens", function()
		t.expect(Theme.scaleFor(Vector2.new(1280, 720))).toBe(1)
		t.expect(Theme.scaleFor(Vector2.new(390, 844))).toBe(0.7)
		t.expect(Theme.scaleFor(Vector2.new(844, 390))).toBe(0.7)
		t.expect(Theme.scaleFor(Vector2.new(3840, 2160))).toBe(1.6)
		t.expect(Theme.scaleFor(Vector2.new(1920, 1080))).toBe(1.5)
	end)

	t.test("panels keep their design size on desktop and fit inside phones", function()
		local want = Theme.Size.panel
		-- desktop: about half the screen wide (the map opts out with `wide`)
		t.expect(Theme.panelSize(Vector2.new(1280, 720), 1, want)).toEqual(Vector2.new(640, want.Y))
		t.expect(Theme.panelSize(Vector2.new(1280, 720), 1, want, true)).toEqual(want)
		local hd = Theme.panelSize(Vector2.new(1920, 1080), 1.5, Vector2.new(900, 560))
		t.expect(hd.X * 1.5 / 1920).toBeCloseTo(0.5, 0.02)
		for _, vp in { Vector2.new(390, 844), Vector2.new(844, 390) } do
			local s = Theme.scaleFor(vp)
			local px = Theme.panelSize(vp, s, want) * s
			t.expect(px.X <= vp.X * 0.94 + 0.01).toBe(true)
			t.expect(px.Y <= vp.Y * (if Theme.compact(vp, s) then 0.98 else 0.9) + 0.01).toBe(true)
		end
		-- portrait grows to most of the height
		local tall = Theme.panelSize(Vector2.new(390, 844), 0.7, want)
		t.expect(tall.Y * 0.7 >= 844 * 0.78).toBe(true)
	end)

	-- verify 2026-10-26 (fix-f1): landscape phones showed 1.3 Shop cards. Safe areas of 667x375 / 844x390 (with and
	-- without the top bar, notch insets): compact panels (tabs in the title bar, 8 du padding, Kit/Panel) fit 3 cards.
	t.test("short landscape panels are compact and show 3 cards", function()
		local S = Theme.Size
		t.expect(Theme.compact(Vector2.new(1280, 720), 1)).toBe(false)
		t.expect(Theme.compact(Vector2.new(390, 844), 0.7)).toBe(false)
		for _, vp in
			{
				Vector2.new(667, 317),
				Vector2.new(667, 375),
				Vector2.new(844, 332),
				Vector2.new(756, 311),
			}
		do
			local s = Theme.scaleFor(vp)
			t.expect(Theme.compact(vp, s)).toBe(true)
			local h = Theme.panelSize(vp, s, Vector2.new(760, 580)).Y
			-- Kit/Panel: bar half + inner offset, body lip, 8 du padding, list padding
			local list = h - S.titleBar * 0.5 - (S.titleBar * 0.5 + 6) - 8 - 2 * 8 - 12
			t.expect(list >= 3 * S.cardCompact + 2 * 12).toBe(true)
		end
	end)

	t.test("kit touch targets are >= 44 px at the phone floor", function()
		local S = Theme.Size
		for _, du in { S.touch, S.tabOff, S.tab, S.close, S.price.Y, S.reply, S.icon } do
			t.expect(du * Theme.MIN_SCALE >= 44).toBe(true)
		end
	end)

	t.test("the icon bar wraps into columns that fit the height", function()
		local cell = Theme.Size.icon + Theme.Size.iconLabel + Theme.Size.iconGap
		t.expect(Theme.iconColumns(Vector2.new(1280, 720), 1, 7)).toBe(2)
		t.expect(Theme.iconColumns(Vector2.new(390, 844), 0.7, 7)).toBe(1)
		for _, vp in { Vector2.new(1280, 720), Vector2.new(390, 844), Vector2.new(844, 390) } do
			local s = Theme.scaleFor(vp)
			local rows = math.ceil(7 / Theme.iconColumns(vp, s, 7))
			t.expect(rows * cell * s <= vp.Y * 0.86).toBe(true)
		end
	end)

	t.test("price text", function()
		t.expect(Theme.short(99)).toBe("99")
		t.expect(Theme.short(1250)).toBe("1,250")
		t.expect(Theme.short(999999 // 100)).toBe("9,999")
		t.expect(Theme.short(12500)).toBe("12.5K")
		t.expect(Theme.short(25000)).toBe("25K")
		t.expect(Theme.short(3400000)).toBe("3.4M")
	end)

	t.test(
		"red-green modes move buy / close off the red-green axis, apart in brightness",
		function()
			for _, mode in { "Default", "Deuteranopia", "Protanopia", "Tritanopia" } do
				local p = Theme.palette(mode)
				t.expect(p.buy ~= nil and p.close ~= nil).toBe(true)
				local lb, lc = Theme.luminance(p.buy.bottom), Theme.luminance(p.close.bottom)
				t.expect(math.abs(lb - lc) > 0.03).toBe(true)
			end
			local d = Theme.palette("Deuteranopia")
			t.expect(d.buy.bottom.B > d.buy.bottom.R).toBe(true)
			t.expect(Theme.palette("Default").buy).toBe(Theme.Grad.buy)
		end
	)
end
