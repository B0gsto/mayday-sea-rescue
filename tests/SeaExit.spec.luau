-- SeaExit: no stepping off the boat at sea, only by land, at home, in a station bay or the shallows (owner 2026-11-07).
return function(t)
	local SeaExit = t.load("src/shared/Boat/SeaExit.luau")
	local UpgradeStation = t.load("src/shared/UpgradeStation.luau")
	local ColdOpen = t.load("src/shared/Boat/ColdOpen.luau")

	local bay = CFrame.new(1000, 0, 0)
	local far = Vector3.new(50000, 0, 50000) -- open sea, far from every island
	local function facts(patch)
		local f = { at = far, bay = bay, landBeside = false, floorY = nil }
		for k, v in patch or {} do
			f[k] = v
		end
		return f
	end

	t.test("open sea keeps the rider aboard", function()
		t.expect(SeaExit.allowed(facts())).toBe(false)
		t.expect(SeaExit.allowed(facts({ floorY = -40 }))).toBe(false)
	end)

	t.test("a deck or shore beside the hull, or the shallows, lets them off", function()
		t.expect(SeaExit.allowed(facts({ landBeside = true }))).toBe(true)
		t.expect(SeaExit.allowed(facts({ floorY = -SeaExit.SHALLOW }))).toBe(true)
	end)

	t.test("home and any island's station bay let them off", function()
		local drop = ColdOpen.dropOff(bay)
		t.expect(SeaExit.allowed(facts({ at = Vector3.new(drop.X, 0, drop.Z) }))).toBe(true)
		t.expect(SeaExit.allowed(facts({ at = UpgradeStation.buttonAt(2) }))).toBe(true)
	end)
end
