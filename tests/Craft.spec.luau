-- docs/23 (h), WP-10a: the hangar and sub pen craft are registered (config, ranks, Robux) and each boards
-- people by its own rule (Ops/CraftBoard).
return function(t)
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local ProgressionConfig = t.load("src/shared/Config/ProgressionConfig.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local CraftBoard = t.load("src/shared/Ops/CraftBoard.luau")
	local Board = t.load("src/shared/Ops/Board.luau")

	t.test("registered with rank, Cash and a Robux pass", function()
		local want = {
			RescueHelicopter = { kind = "Heli", rank = 5, price = 75000 },
			Seaplane = { kind = "Plane", rank = 5, price = 60000 },
			Submarine = { kind = "Sub", rank = 4, price = 40000 },
		}
		for _, id in VehicleConfig.CraftOrder do
			local spec = VehicleConfig.get(id)
			t.expect(spec.craft).toBe(want[id].kind)
			t.expect(table.find(VehicleConfig.Order, id)).toBeNil() -- not a boat launch
			local unlock = ProgressionConfig.Vehicles[id]
			t.expect(unlock.rankIndex).toBe(want[id].rank)
			t.expect(unlock.price).toBe(want[id].price)
			t.expect(Rules.vehiclePass(id) ~= nil).toBe(true)
		end
		t.expect(VehicleConfig.RIB.craft).toBeNil()
	end)

	local survivor = Vector3.new(0, 0, 0)
	local function ready(id, at, speed)
		return CraftBoard.ready(id, at, 3, survivor, speed or 0, 0, true, 0)
	end

	t.test("heli: hover inside the ring, under the winch height", function()
		t.expect(ready("RescueHelicopter", Vector3.new(5, 13, 0))).toBe(true)
		t.expect(ready("RescueHelicopter", Vector3.new(5, 60, 0))).toBe(false) -- too high
		t.expect(ready("RescueHelicopter", Vector3.new(20, 13, 0))).toBe(false) -- out of the ring
		t.expect(ready("RescueHelicopter", Vector3.new(5, 13, 0), 30)).toBe(false) -- not steady
	end)

	t.test("seaplane: only sitting on the water", function()
		local floating = 1.5 - 1 -- root centre: half the 3-stud hull over a 1-stud draft
		t.expect(ready("Seaplane", Vector3.new(8, floating, 0))).toBe(true)
		t.expect(ready("Seaplane", Vector3.new(8, 20, 0))).toBe(false) -- airborne
	end)

	t.test("sub: inside its ring at their depth; boats keep Board's rule", function()
		t.expect(ready("Submarine", Vector3.new(6, -2, 0))).toBe(true)
		t.expect(ready("Submarine", Vector3.new(6, -20, 0))).toBe(false)
		t.expect(ready("RIB", Vector3.new(3 + Board.REACH - 1, 0, 0))).toBe(true)
		t.expect(ready("RIB", Vector3.new(3 + Board.REACH + 1, 0, 0))).toBe(false)
	end)

	t.test("a diver on the seabed: only the sub", function()
		local diver = Vector3.new(0, -36, 0)
		local function deep(id, at)
			return CraftBoard.ready(id, at, 3, diver, 0, 0, true, 0)
		end
		t.expect(deep("Submarine", Vector3.new(4, -34, 0))).toBe(true)
		t.expect(deep("Submarine", Vector3.new(4, 0, 0))).toBe(false) -- floating above: out of the ring
		t.expect(deep("RIB", Vector3.new(3, 0, 0))).toBe(false)
		t.expect(deep("RescueHelicopter", Vector3.new(2, 4, 0))).toBe(false)
		t.expect(deep("Seaplane", Vector3.new(4, 0.5, 0))).toBe(false)
	end)
end
