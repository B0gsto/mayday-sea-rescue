-- NearLife (life1): the life round the player: spawn points, perch tops, bow-riding dolphins.
return function(t)
	local NearLife = t.load("src/client/Controllers/Wildlife/NearLife.luau")

	t.test("around puts a point at the distance, turned off the heading", function()
		local p = NearLife.around(Vector3.new(10, 5, 10), Vector3.new(0, 0, -2), 0, 30)
		t.expect((p - Vector3.new(10, 0, -20)).Magnitude < 1e-4).toBeTruthy()
		local q = NearLife.around(Vector3.zero, Vector3.zero, math.pi / 2, 10) -- no heading: still 10 off
		t.expect(math.abs(q.Magnitude - 10) < 1e-4).toBeTruthy()
	end)

	t.test("toward never overshoots", function()
		t.expect(NearLife.toward(Vector3.zero, Vector3.new(3, 0, 0), 5)).toBe(Vector3.new(3, 0, 0))
		t.expect(NearLife.toward(Vector3.zero, Vector3.new(30, 0, 0), 5)).toBe(Vector3.new(5, 0, 0))
	end)

	t.test("perch tops: narrow named posts above the sea, laid cylinders too", function()
		local top = NearLife.perchTop("Pile", CFrame.new(0, 2, 0), Vector3.new(1.5, 6, 1.5))
		t.expect(top).toBe(Vector3.new(0, 5, 0))
		local laid = NearLife.perchTop(
			"Piling",
			CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(6, 1.5, 1.5)
		)
		t.expect(laid ~= nil and math.abs(laid.Y - 5) < 1e-3).toBeTruthy()
		t.expect(NearLife.perchTop("Deck", CFrame.new(0, 2, 0), Vector3.new(1, 6, 1))).toBe(nil)
		t.expect(NearLife.perchTop("BollardCap", CFrame.new(0, 2, 0), Vector3.new(8, 2, 8)))
			.toBe(nil) -- too wide
		t.expect(NearLife.perchTop("Pile", CFrame.new(0, -4, 0), Vector3.new(1, 6, 1))).toBe(nil) -- under water
	end)

	t.test("bow riders swim in deep and wide, hold beside the bow, peel away down", function()
		for i = 1, 2 do
			local start, ride, gone =
				NearLife.bow(i, 0, 0), NearLife.bow(i, NearLife.ARRIVE, 0), NearLife.bow(i, 10, 1)
			t.expect(math.abs(start.X) > 30 and start.Z < 0 and start.Y < -4).toBeTruthy()
			t.expect(
				math.abs(math.abs(ride.X) - 6) < 1e-4
					and ride.Z > 0
					and math.abs(ride.Y + 0.9) < 1e-4
			)
				.toBeTruthy()
			t.expect(math.abs(gone.X) > 30 and gone.Y < -4).toBeTruthy()
			t.expect((ride.X < 0) == (i == 1)).toBeTruthy() -- port and starboard
		end
	end)
end
