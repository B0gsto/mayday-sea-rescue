-- Marina (docs/23 WP-1): 16 plots, no overlap, clear of the breakwater; assignment and the spawn lock.
return function(t)
	local M = t.load("src/shared/Marina.luau")
	local BayLaunch = t.load("src/shared/Boat/BayLaunch.luau")

	-- a plot's world rectangle (x0, x1, z0, z1): berth + deck, PLOT_X wide
	local function rect(i: number)
		local b = M.berth(i)
		local corners = {
			b * Vector3.new(M.PLOT_X[1], 0, -M.BERTH / 2),
			b * Vector3.new(M.PLOT_X[2], 0, M.BERTH / 2 + M.DECK),
		}
		return math.min(corners[1].X, corners[2].X),
			math.max(corners[1].X, corners[2].X),
			math.min(corners[1].Z, corners[2].Z),
			math.max(corners[1].Z, corners[2].Z)
	end

	t.test("16 plots in two rows of 8, none overlapping, bows out to sea", function()
		t.expect(M.COUNT).toBe(16)
		for i = 1, M.COUNT do
			local ax0, ax1, az0, az1 = rect(i)
			t.expect(math.abs(ax1 - ax0) - (M.DECK + M.BERTH) < 1e-3).toBe(true)
			t.expect(math.abs(az1 - az0) - M.WIDTH < 1e-3).toBe(true)
			-- bow points away from the spine
			local b = M.berth(i)
			t.expect((b.Position.X - M.SPINE_X) * b.LookVector.X > 0).toBe(true)
			for j = i + 1, M.COUNT do
				local bx0, bx1, bz0, bz1 = rect(j)
				local overlap = ax0 < bx1 - 1e-3
					and bx0 < ax1 - 1e-3
					and az0 < bz1 - 1e-3
					and bz0 < az1 - 1e-3
				t.expect(overlap).toBe(false)
			end
		end
	end)

	t.test("plots stay clear of the west breakwater armour and the beach rocks", function()
		for i = 1, M.COUNT do
			local x0, x1, z0 = rect(i)
			t.expect(x1 < -380).toBe(true) -- armour toe ~x -344; cold-open casualty 60 ahead of an east berth
			t.expect(x0 > -620).toBe(true)
			t.expect(z0 >= M.Z0).toBe(true)
		end
	end)

	t.test("the returning player's spot and crate land on the jetty finger", function()
		for _, offset in { BayLaunch.STAND, BayLaunch.CRATE, BayLaunch.SIGN } do
			local p = offset.Position
			t.expect(p.X >= M.JETTY.x0 and p.X <= M.JETTY.x1).toBe(true)
			t.expect(p.Z >= M.JETTY.out and p.Z <= M.BERTH / 2).toBe(true)
		end
	end)

	t.test(
		"16 garage bays in one row along Penhallow Road's west kerb, doors onto the road",
		function()
			local g = M.GARAGE
			for i = 1, M.COUNT do
				local cf = M.garage(i)
				t.expect((cf.LookVector - Vector3.xAxis).Magnitude < 1e-4).toBe(true) -- out of the door, east onto the road
				t.expect(cf.Position.X).toBe(g.X)
				-- the back wall stays clear of the road and the bays tile without gaps or overlap
				t.expect((cf * Vector3.new(0, 0, g.DEPTH)).X < g.X).toBe(true)
				if i > 1 then
					t.expect(
						math.abs((M.garage(i - 1).Position - cf.Position).Magnitude - g.WIDTH)
							< 1e-3
					)
						.toBe(true)
				end
				t.expect(cf.Position.Z + g.WIDTH / 2 <= -41).toBe(true) -- north of Harbour Road (z -26, 30 wide)
			end
		end
	)

	t.test("assign gives the lowest free plot, nil when full", function()
		t.expect(M.assign({})).toBe(1)
		t.expect(M.assign({ [1] = true, [2] = true, [4] = true })).toBe(3)
		local full = {}
		for i = 1, M.COUNT do
			full[i] = true
		end
		t.expect(M.assign(full)).toBeNil()
	end)

	t.test("the spawn lock lets one spawn per berth through until released", function()
		local locks = {}
		t.expect(M.lock(locks, "berth1")).toBe(true)
		t.expect(M.lock(locks, "berth1")).toBe(false) -- a second request in the same moment
		t.expect(M.lock(locks, "berth2")).toBe(true)
		locks.berth1 = nil
		t.expect(M.lock(locks, "berth1")).toBe(true)
	end)
end
