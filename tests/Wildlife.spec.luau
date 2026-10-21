-- GullPath (G76): ambient gull flight loops bank into the turn and stay near their centre.
return function(t)
	local GullPath = t.load("src/client/Controllers/Wildlife/GullPath.luau")

	local function loop(dir: number, eight: boolean)
		return {
			centre = Vector3.new(10, 40, -20),
			radius = 45,
			speed = 20,
			dir = dir,
			eight = eight,
			phase = 0.7,
			drift = 5,
		}
	end

	t.test("a circling gull banks its inner wing down, both directions", function()
		for _, dir in { 1, -1 } do
			local l = loop(dir, false)
			for _, time in { 0, 3.3, 11.7 } do
				local cf = GullPath.at(l, time)
				local toCentre = l.centre - cf.Position
				local inner = cf.RightVector:Dot(Vector3.new(toCentre.X, 0, toCentre.Z))
				t.expect(inner * cf.RightVector.Y < 0).toBe(true)
				t.expect(math.abs(cf.RightVector.Y) > math.sin(math.rad(10))).toBe(true)
				t.expect(math.abs(cf.RightVector.Y) <= math.sin(math.rad(40)) + 1e-3).toBe(true)
			end
		end
	end)

	t.test("the gull flies along its path and stays inside the loop's box", function()
		for _, eight in { false, true } do
			local l = loop(1, eight)
			for time = 0, 60, 1.7 do
				local p = GullPath.pos(l, time)
				local ahead = GullPath.pos(l, time + 0.1) - p
				t.expect(GullPath.at(l, time).LookVector:Dot(ahead.Unit) > 0.95).toBe(true)
				t.expect(math.abs(p.X - l.centre.X) <= l.radius + 1e-6).toBe(true)
				t.expect(math.abs(p.Z - l.centre.Z) <= l.radius + 1e-6).toBe(true)
				t.expect(math.abs(p.Y - l.centre.Y) <= l.drift + 1e-6).toBe(true)
			end
		end
	end)
end
