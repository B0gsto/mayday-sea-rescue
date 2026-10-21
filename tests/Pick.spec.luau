-- Pick: sticky body target picking (a bobbing boat must not swap the target under a still
-- pointer) and the gamepad stick cycle.
return function(t)
	local Pick = t.load("src/client/Mechanics/PIW/Pick.luau")
	local function at(x, y): Vector2
		return Vector2.new(x, y)
	end

	t.test("a still pointer keeps its target while the boat bobs", function()
		local aim = at(400, 300)
		local a = { { id = "head", at = at(400, 300) } }
		t.expect(Pick.choose(aim, true, a, nil, 70)).toBe("head")
		-- bobbing moves every target 12 px; the pointer did not move
		local bobbed = { { id = "head", at = at(412, 300) }, { id = "chest", at = at(419, 300) } }
		t.expect(Pick.choose(aim, false, bobbed, "head", 70)).toBe("head")
	end)

	t.test("a clear pointer move chooses the nearer target", function()
		local targets = { { id = "head", at = at(400, 300) }, { id = "chest", at = at(407, 300) } }
		t.expect(Pick.choose(at(407, 300), true, targets, "head", 70)).toBe("chest")
		t.expect(Pick.choose(at(400, 300), true, targets, "chest", 70)).toBe("head")
	end)

	t.test("a fresh pick needs the 44 px hit area", function()
		local targets = { { id = "head", at = at(400, 300) } }
		t.expect(Pick.choose(at(420, 300), true, targets, nil)).toBe("head")
		t.expect(Pick.choose(at(430, 300), true, targets, nil)).toBeNil()
		t.expect(Pick.choose(at(430, 300), true, targets, nil, 100)).toBe("head")
	end)

	t.test("a removed or off-screen target lets go", function()
		local targets = { { id = "chest", at = at(407, 300) } }
		t.expect(Pick.choose(at(400, 300), false, targets, "head", 70)).toBe("chest")
		t.expect(Pick.choose(at(400, 300), false, {}, "head", 70)).toBeNil()
	end)

	t.test("a click or tap picks the target under the pointer within 44 px", function()
		local targets = {
			{ id = "head", at = at(400, 300) },
			{ id = "chest", at = at(500, 300) },
		}
		t.expect(Pick.choose(at(430, 300), true, targets, "chest", Pick.CLICK_HIT)).toBe("head")
		t.expect(Pick.choose(at(470, 300), true, targets, "head", Pick.CLICK_HIT)).toBe("chest")
		t.expect(Pick.choose(at(444, 300), true, targets, nil, Pick.CLICK_HIT)).toBe("head")
		t.expect(Pick.choose(at(446, 300), true, targets, nil, Pick.CLICK_HIT)).toBeNil()
	end)

	t.test("the stick cycles left to right and wraps both ways", function()
		local targets = {
			{ id = "right", at = at(420, 300) },
			{ id = "left", at = at(380, 300) },
			{ id = "mid", at = at(400, 300) },
		}
		t.expect(Pick.cycle(targets, nil, 1)).toBe("left")
		t.expect(Pick.cycle(targets, "left", 1)).toBe("mid")
		t.expect(Pick.cycle(targets, "mid", 1)).toBe("right")
		t.expect(Pick.cycle(targets, "right", 1)).toBe("left")
		t.expect(Pick.cycle(targets, "left", -1)).toBe("right")
		t.expect(Pick.cycle({}, "left", 1)).toBeNil()
	end)
end
