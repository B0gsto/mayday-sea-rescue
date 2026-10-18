-- Ferry art mapping (src/shared/Ferry/FerryRig.luau): the C2 Gale Queen and liferaft on RescueService's floaters.
return function(t)
	local FerryRig = t.load("src/shared/Ferry/FerryRig.luau")
	local HullKnock = t.load("src/shared/Ferry/HullKnock.luau")
	local AssetIds = t.load("src/shared/Config/AssetIds.luau")
	local ship = AssetIds.Attachments[FerryRig.FERRY]
	local raft = AssetIds.Attachments[FerryRig.RAFT]

	local function near(a: number, b: number, eps: number?): boolean
		return math.abs(a - b) <= (eps or 1e-3)
	end

	t.test("the generated attachments the op needs exist", function()
		for _, n in { "ATT_Waterline", "ATT_Bow", "ATT_Stern", "ATT_AirPocket", "ATT_Masthead" } do
			t.expect(ship[n] ~= nil).toBeTruthy()
		end
		for i = 1, FerryRig.KNOCKS do
			t.expect(ship[FerryRig.knockName(i)] ~= nil).toBeTruthy()
		end
		for _, r in FerryRig.RAFTS do
			t.expect(ship[FerryRig.liferaftName(r.canister)] ~= nil).toBeTruthy()
		end
		t.expect(raft.ATT_Waterline ~= nil and raft.ATT_Painter ~= nil).toBeTruthy()
		for i = 1, FerryRig.RAFT_SEATS do
			t.expect(raft[FerryRig.seatName(i)] ~= nil).toBeTruthy()
		end
		t.expect(FerryRig.knockName(3)).toBe("ATT_Knock_03")
	end)

	t.test(
		"knock marks sit over HullKnock's compartments, on the up side at the 72 degree roll",
		function()
			local mid = FerryRig.midZ(ship)
			for i = 1, FerryRig.KNOCKS do
				local k = ship[FerryRig.knockName(i)]
				local along = k.Z - mid
				t.expect(HullKnock.compartmentAt(along, FerryRig.HULL_LENGTH)).toBe(i)
				t.expect(near(along, HullKnock.offsetAlong(i, FerryRig.HULL_LENGTH), 0.6))
					.toBeTruthy()
				-- above the sea once rolled
				t.expect(FerryRig.rolledHeight(k) > FerryRig.AXIS_ABOVE_SEA * -1).toBeTruthy()
				t.expect(k.X > 0).toBeTruthy()
			end
			-- compartment 1 is the bow (-Z)
			t.expect(ship.ATT_Bow.Z < ship.ATT_Stern.Z).toBeTruthy()
		end
	)

	t.test("ferry offset puts the roll axis at midships on the floater origin", function()
		local off = FerryRig.ferryOffset(ship)
		local axis = FerryRig.hullAxis(ship)
		local p = off * axis.Position
		t.expect(near(p.Magnitude, 0)).toBeTruthy()
		-- the keel pivot is ROLL_AXIS_Y under the axis
		t.expect(near((off * Vector3.zero).Y, -FerryRig.ROLL_AXIS_Y)).toBeTruthy()
	end)

	t.test("rolled frame matches CFrame.Angles(0, 0, TILT)", function()
		local off = FerryRig.ferryOffset(ship)
		local tilt = CFrame.Angles(0, 0, FerryRig.TILT)
		for _, n in { "ATT_Masthead", "ATT_Knock_03", "ATT_Liferaft_01", "ATT_AirPocket" } do
			local w = tilt * (off * ship[n])
			t.expect(near(w.Y, FerryRig.rolledHeight(ship[n]))).toBeTruthy()
			t.expect(near(w.X, FerryRig.rolledAcross(ship[n]))).toBeTruthy()
		end
		-- the masthead lies out over the -X (deck) side, the keel side is up
		t.expect(FerryRig.rolledAcross(ship.ATT_Masthead) < -20).toBeTruthy()
	end)

	t.test(
		"the Damage lines end under the sea; the air pocket is at the trapped water level inside",
		function()
			t.expect(FerryRig.lineEndDepth() > 1).toBeTruthy()
			t.expect(FerryRig.lineEndDepth() < 3).toBeTruthy()
			for pocket = 2, 4 do
				local p = FerryRig.pocketPoint(ship, pocket)
				t.expect(p ~= nil).toBeTruthy()
				if p then
					t.expect(near(p.Z, ship[FerryRig.knockName(pocket)].Z)).toBeTruthy()
					-- trapped air: just above the sea outside, under the hull (inside the footprint)
					local aboveSea = FerryRig.rolledHeight(p) + FerryRig.AXIS_ABOVE_SEA
					t.expect(aboveSea > -1 and aboveSea < 2).toBeTruthy()
					local across = FerryRig.rolledAcross(p)
					t.expect(across > FerryRig.FOOTPRINT.minX and across < FerryRig.FOOTPRINT.maxX)
						.toBeTruthy()
				end
			end
		end
	)

	t.test("part tokens and state visibility", function()
		t.expect(FerryRig.token("M_Veh_GaleQueen_Damage_LOD0")).toBe("Damage")
		t.expect(FerryRig.token("M_Veh_GaleQueen_HullGear_LOD0")).toBe("HullGear")
		t.expect(FerryRig.token("M_Sea_Liferaft_Tubes_LOD0")).toBe("Tubes")
		t.expect(FerryRig.token("Hull")).toBe("Hull")
		t.expect(FerryRig.visibleIn("M_Veh_GaleQueen_Damage_LOD0", "Capsized")).toBe(true)
		t.expect(FerryRig.visibleIn("M_Veh_GaleQueen_GrabLines_LOD0", "Capsized")).toBe(true)
		t.expect(FerryRig.visibleIn("M_Veh_GaleQueen_Undamaged_LOD0", "Capsized")).toBe(false)
		t.expect(FerryRig.visibleIn("M_Veh_GaleQueen_Damage_LOD0", "Upright")).toBe(false)
		t.expect(FerryRig.visibleIn("M_Veh_GaleQueen_GrabLines_LOD0", "Upright")).toBe(false)
		t.expect(FerryRig.visibleIn("M_Veh_GaleQueen_Undamaged_LOD0", "Upright")).toBe(true)
		t.expect(FerryRig.visibleIn("Hull", "Capsized")).toBe(true)
		t.expect(FerryRig.visibleIn("Hull", "Upright")).toBe(true)
	end)

	t.test(
		"raft seats: on the raft floor, facing the centre, waterline at the floater origin",
		function()
			local off = FerryRig.raftOffset(raft)
			t.expect(near((off * raft.ATT_Waterline).Magnitude, 0)).toBeTruthy()
			for i = 1, FerryRig.RAFT_SEATS do
				local cf = FerryRig.seatOffset(raft, i)
				t.expect(cf ~= nil).toBeTruthy()
				if cf then
					local seat = off * raft[FerryRig.seatName(i)]
					t.expect(near(cf.Position.Y - seat.Y, FerryRig.SEAT_TORSO)).toBeTruthy()
					-- inside the tubes (2.97 m over the tubes = 4.45 studs radius)
					t.expect(Vector3.new(cf.Position.X, 0, cf.Position.Z).Magnitude < 4)
						.toBeTruthy()
					local toCentre = Vector3.new(-cf.Position.X, 0, -cf.Position.Z).Unit
					t.expect(cf.LookVector:Dot(toCentre) > 0.99).toBeTruthy()
				end
			end
			t.expect(FerryRig.seatOffset(raft, 7)).toBe(nil)
		end
	)

	t.test(
		"seat assignment: last half of the casualties, alternating rafts, no seat twice",
		function()
			local s4 = FerryRig.assignSeats(4)
			t.expect(s4[1]).toBe(nil)
			t.expect(s4[2]).toBe(nil)
			t.expect(s4[3].raft).toBe(1)
			t.expect(s4[4].raft).toBe(2)
			t.expect(s4[3].seat).toBe(1)
			t.expect(s4[4].seat).toBe(1)
			local s7 = FerryRig.assignSeats(7)
			local n = 0
			for _ in s7 do
				n += 1
			end
			t.expect(n).toBe(3)
			t.expect(s7[7].seat).toBe(4) -- raft 1's second casualty sits opposite the first
			local s40 = FerryRig.assignSeats(40)
			local used = {}
			local total = 0
			for _, s in s40 do
				local key = s.raft * 10 + s.seat
				t.expect(used[key]).toBe(nil)
				used[key] = true
				total += 1
			end
			t.expect(total).toBe(#FerryRig.RAFTS * FerryRig.RAFT_SEATS)
			t.expect(next(FerryRig.assignSeats(1))).toBe(nil)
			t.expect(next(FerryRig.assignSeats(4, 0))).toBe(nil)
		end
	)

	t.test("casualties are pushed clear of the rolled hull", function()
		local f = FerryRig.FOOTPRINT
		local x, z = FerryRig.pushClear(0, 0)
		t.expect(x >= f.maxX or x <= f.minX or z >= f.maxZ or z <= f.minZ).toBeTruthy()
		t.expect(x).toBe(f.maxX + FerryRig.CLEAR_MARGIN) -- nearest side is the keel side
		local x2, z2 = FerryRig.pushClear(-20, 30)
		t.expect(x2).toBe(-20)
		t.expect(z2).toBe(f.maxZ + FerryRig.CLEAR_MARGIN)
		local x3, z3 = FerryRig.pushClear(-50, 0)
		t.expect(x3).toBe(-50)
		t.expect(z3).toBe(0)
		-- the rafts ride clear of the footprint
		for _, r in FerryRig.RAFTS do
			local rx, rz = FerryRig.pushClear(r.x, r.z)
			t.expect(rx).toBe(r.x)
			t.expect(rz).toBe(r.z)
		end
	end)
end
