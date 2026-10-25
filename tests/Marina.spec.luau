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
		"assign gives the lowest free plot, the head only to the Harbour Master, nil when full",
		function()
			t.expect(M.assign({})).toBe(2)
			t.expect(M.assign({}, true)).toBe(M.HEAD)
			t.expect(M.assign({ [1] = true }, true)).toBe(2) -- the head is held: never move its owner
			t.expect(M.assign({ [1] = true, [2] = true, [4] = true })).toBe(3)
			local others = {}
			for i = 2, M.COUNT do
				others[i] = true
			end
			t.expect(M.assign(others)).toBe(M.HEAD) -- a full server hands out the head too
			local full = {}
			for i = 1, M.COUNT do
				full[i] = true
			end
			t.expect(M.assign(full)).toBeNil()
		end
	)

	t.test("Harbour Master: highest rank among Lv 5 docks, ties keep the holder", function()
		t.expect(M.harbourMaster({})).toBeNil()
		t.expect(M.harbourMaster({ { key = "a", rank = 9, level = 4 } })).toBeNil()
		local list = {
			{ key = "a", rank = 3, level = 5 },
			{ key = "b", rank = 5, level = 5 },
			{ key = "c", rank = 7, level = 4 }, -- outranks, but not eligible
			{ key = "d", rank = 5, level = 5 },
		}
		t.expect(M.harbourMaster(list)).toBe("b")
		t.expect(M.harbourMaster(list, "d")).toBe("d")
		t.expect(M.harbourMaster(list, "a")).toBe("b")
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
