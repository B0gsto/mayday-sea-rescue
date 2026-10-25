-- auto_board (2026-10-21): close and steady with room, they climb aboard; ramming knocks them back.
return function(t)
	local AutoBoard = t.load("src/shared/Ops/Board.luau")

	t.test("close, slow, level and with room: they climb aboard", function()
		t.expect(AutoBoard.ready(5, 3, 5, true)).toBe(true)
		t.expect(AutoBoard.ready(5, 3, 5, false)).toBe(false) -- full craft
		t.expect(AutoBoard.ready(AutoBoard.REACH + 1, 3, 5, true)).toBe(false) -- too far
		t.expect(AutoBoard.ready(5, AutoBoard.STEADY_SPEED + 1, 5, true)).toBe(false) -- moving
		t.expect(AutoBoard.ready(5, 3, AutoBoard.STEADY_TILT + 5, true)).toBe(false) -- big waves
	end)

	t.test("only a fast run on top of them is a bump, and only from KNOCK_RANK up", function()
		local r = AutoBoard.KNOCK_RANK
		t.expect(AutoBoard.rammed(2, AutoBoard.RAM_SPEED + 1, r)).toBe(true)
		t.expect(AutoBoard.rammed(2, 3, r)).toBe(false)
		t.expect(AutoBoard.rammed(AutoBoard.CONTACT + 3, AutoBoard.RAM_SPEED + 5, r)).toBe(false)
		t.expect(AutoBoard.rammed(2, AutoBoard.RAM_SPEED + 1, r - 1)).toBe(false) -- a new player
		t.expect(AutoBoard.rammed(2, AutoBoard.RAM_SPEED + 1, nil)).toBe(false) -- rank not loaded yet
	end)

	t.test("pick-up ring: a craft at full throttle is eased to a boarding speed", function()
		local assist = AutoBoard.assistThrottle
		t.expect(AutoBoard.ASSIST_SPEED < AutoBoard.STEADY_SPEED).toBe(true)
		t.expect(assist(1, 300, 40, 40, 16)).toBe(1) -- far out: the player's throttle
		t.expect(assist(1, 40, 40, 40, 16) < 0).toBe(true) -- closing fast near the ring: brakes
		t.expect(assist(1, 60, 2, 40, 16)).toBe(1) -- passing by, not closing: untouched
		t.expect(assist(1, 5, 30, 30, 16)).toBe(-1) -- inside, far too fast: full brake
		t.expect(assist(1, 5, 0, AutoBoard.ASSIST_SPEED + 2, 16) < 0).toBe(true)
		local slow = assist(1, 5, 0, AutoBoard.ASSIST_SPEED - 1, 16) -- inside, near the speed: part throttle
		t.expect(slow > 0 and slow < 1).toBe(true)
		t.expect(assist(-1, 5, 0, 1, 16)).toBe(-1) -- astern is always the player's
		t.expect(assist(0.3, 5, 0, 1, 16)).toBe(0.3) -- never more than they asked
	end)

	t.test("a jet ski at full throttle reaches the ring edge at <= 8 studs/s", function()
		local B = t.load("src/shared/Boat/Buoyancy.luau")
		local h = t.load("src/shared/Config/VehicleConfig.luau").JetSki
		local grip = 0.7 -- the hull skipping on the chop: thrust and drag both lose grip
		local x, v, dt = 200, h.topSpeed, 1 / 60
		local lag = { 1, 1, 1, 1, 1, 1 } -- 0.1 s from the assist to the water
		while x > AutoBoard.RING do
			table.insert(lag, AutoBoard.assistThrottle(1, x, v, v, h.brakeDecel))
			v += (B.thrust(table.remove(lag, 1), v, 1, h, grip, 1) - B.forwardDecel(v, h, 1) * grip) * dt
			x -= v * dt
		end
		t.expect(v <= 8).toBe(true)
		t.expect(v >= AutoBoard.ASSIST_SPEED - 1).toBe(true) -- not stopped short either
	end)

	t.test("a craft held at the assist speed inside the ring boards them", function()
		t.expect(AutoBoard.ready(AutoBoard.RING - 4, AutoBoard.ASSIST_SPEED, 5, true)).toBe(true)
	end)

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
