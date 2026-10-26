-- auto_board (docs/24 A): drive next to them with room and they climb aboard, at any speed and tilt.
return function(t)
	local AutoBoard = t.load("src/shared/Ops/Board.luau")
	local CraftBoard = t.load("src/shared/Ops/CraftBoard.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")

	t.test("within reach with room: they climb aboard", function()
		t.expect(AutoBoard.ready(5, true)).toBe(true)
		t.expect(AutoBoard.ready(5, false)).toBe(false) -- full craft
		t.expect(AutoBoard.ready(AutoBoard.REACH + 1, true)).toBe(false) -- too far
	end)

	t.test("no speed or tilt gate for a boat (docs/24 A)", function()
		local ski = VehicleConfig.JetSki
		local at = Vector3.new(0, 0, 0)
		local swimmer = Vector3.new(0, 0, -(2 + AutoBoard.REACH - 1))
		t.expect(CraftBoard.ready("JetSki", at, 2, swimmer, ski.topSpeed, 40, true, 0)).toBe(true)
		t.expect(CraftBoard.ready("JetSki", at, 2, swimmer, ski.topSpeed, 0, true, 0)).toBe(true)
		t.expect(CraftBoard.hold("JetSki")).toBe(0) -- no hold: they leap aboard
	end)

	t.test("a boat at full speed passing within reach boards the survivor", function()
		local ski = VehicleConfig.JetSki
		local at = Vector3.new(100, 0, 0)
		local survivor = Vector3.new(100, 0, 2 + AutoBoard.REACH - 2) -- alongside, just inside reach
		t.expect(
			CraftBoard.ready("JetSki", at, ski.hullSize.X / 2, survivor, ski.topSpeed, 25, true, 0)
		)
			.toBe(true)
	end)

	t.test("the heli winch and the sub still hold slow and steady", function()
		t.expect(CraftBoard.hold("RescueHelicopter")).toBe(AutoBoard.HOLD)
		t.expect(CraftBoard.hold("Submarine")).toBe(AutoBoard.HOLD)
	end)

	t.test("bigger craft: the ring grows with the beam", function()
		local B = AutoBoard
		t.expect(B.ringFor(2)).toBe(B.REACH + 2) -- a jet ski: the reach from its side
		t.expect(B.ringFor(9)).toBe(B.REACH + 9) -- a lifeboat: wider still
		t.expect(B.ringFor(9) > B.ringFor(2)).toBe(true)
	end)

	t.test(
		"a hands-off helm is nudged onto them; the player's own helm is never changed",
		function()
			local B = AutoBoard
			t.expect(B.nudge(0, 20, 50)).toBe(B.NUDGE)
			t.expect(B.nudge(0, -5, 50) < 0).toBe(true)
			t.expect(B.nudge(0, 0, 50)).toBe(0)
			t.expect(B.nudge(0, B.NUDGE_ANGLE + 5, 50)).toBe(0) -- well off the bow
			t.expect(B.nudge(0, 10, B.OUTER + 1)).toBe(0) -- too far
			t.expect(B.nudge(-1, 20, 50)).toBe(-1) -- steering away stays theirs
		end
	)

	t.test("a mission casualty is the crew's until aboard; free-roam ones are anyone's", function()
		local list = AutoBoard.privateList({ 12, 345 })
		t.expect(AutoBoard.mayAct(list, 12)).toBe(true)
		t.expect(AutoBoard.mayAct(list, 345)).toBe(true)
		t.expect(AutoBoard.mayAct(list, 34)).toBe(false) -- a prefix of another id is not a match
		t.expect(AutoBoard.mayAct(list, 1)).toBe(false)
		t.expect(AutoBoard.mayAct(AutoBoard.privateList({}), 12)).toBe(false)
		t.expect(AutoBoard.mayAct(nil, 12)).toBe(true) -- free-roam / big call: public
	end)

	t.test("big call: a crew takes any survivor that is free or already its own", function()
		t.expect(AutoBoard.mayTake({}, "T1")).toBe(true)
		t.expect(AutoBoard.mayTake({ claimedBy = "T1" }, "T1")).toBe(true)
		t.expect(AutoBoard.mayTake({ claimedBy = "T2" }, "T1")).toBe(false) -- another crew's
		t.expect(AutoBoard.mayTake({ delivered = true }, "T1")).toBe(false)
		t.expect(AutoBoard.mayTake({ takenOver = true }, "T1")).toBe(false) -- the helicopter has them
	end)
end
