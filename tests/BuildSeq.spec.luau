-- BuildSeq (docs/23 (j), WP-14c): the Lego build beat's drop plan: bottom to top, never overtaking
-- delays, drop heights 6-10, and a total that keeps any dock piece under ~6 s.
return function(t)
	local B = t.load("src/shared/BuildSeq.luau")

	t.test("parts drop bottom to top, ties in index order", function()
		local plan = B.plan({ 30, 10, 20, 10, 5 }, 1)
		t.expect(#plan).toBe(5)
		-- index 1 = y 30 (top), index 4 = y 10 (tied with 2, keeps its order)
		t.expect(plan[1].i).toBe(5)
		t.expect(plan[2].i).toBe(2)
		t.expect(plan[3].i).toBe(4)
		t.expect(plan[4].i).toBe(3)
		t.expect(plan[5].i).toBe(1)
	end)

	t.test("delays never overtake and drop heights stay in 6..10", function()
		for _, n in { 1, 5, 25, 45, 120 } do
			local ys = {}
			for i = 1, n do
				table.insert(ys, (i * 37) % 100)
			end
			local plan = B.plan(ys, n)
			t.expect(#plan).toBe(n)
			for k, s in plan do
				t.expect(s.drop >= B.DROP_MIN and s.drop <= B.DROP_MAX).toBe(true)
				if k > 1 then
					t.expect(s.delay >= plan[k - 1].delay).toBe(true)
				end
			end
			t.expect(plan[1].delay).toBe(0)
		end
	end)

	t.test("a whole building stays in the ~3-6 s window", function()
		for _, n in { 10, 25, 45, 120 } do
			local ys = {}
			for i = 1, n do
				table.insert(ys, i)
			end
			local plan = B.plan(ys, 7)
			local last = plan[#plan]
			-- the last drop (0.45) and squash (0.15) fit inside 6 s
			t.expect(last.delay + 0.6 <= 6).toBe(true)
		end
	end)

	t.test("the same seed gives the same plan", function()
		local ys = { 3, 1, 2, 4 }
		local a, b = B.plan(ys, 42), B.plan(ys, 42)
		for k, s in a do
			t.expect(s.i).toBe(b[k].i)
			t.expect(s.delay).toBeCloseTo(b[k].delay, 1e-9)
			t.expect(s.drop).toBeCloseTo(b[k].drop, 1e-9)
		end
	end)
end
