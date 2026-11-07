-- A walker who falls in can always climb out (fresh-player playtest 2026-11-07: three falls into the cove on the way
-- to the build stand, stuck under the jetty). SwimController hauls a swimmer up any wall whose top is within HAUL_MAX
-- of the sea, but only with headroom: a wall that stops short of a trough swimmer's hips lets them float in under its
-- lip, and a pile deck with no wall at all lets them drift under it. So on every island each plate wall (slab body,
-- trim skirt, beach step) and the swim skirts under DockService's jetty, finger and head deck reach DEEP under the sea.
return function(t)
	local Marina = t.load("src/shared/Marina.luau")
	local Waves = t.load("src/shared/Waves.luau")
	local IslandPlates = t.load("src/server/World/IslandPlates.luau")

	local HAUL_MAX = 5.5 -- SwimController: highest ledge above the water
	-- a calm trough swimmer's root floats ~1 under the surface, their hips ~1 under that
	local DEEP = Waves.SEA_LEVEL - Waves.maxAmplitude(Waves.paramsFor(0, 0, 0)) - 2
	local WALLS = { Body = true, Trim = true, Beach = true, SwimSkirt = true }

	local world = Instance.new("Folder")
	IslandPlates.place(world)

	t.test(
		"every water edge reaches under a trough swimmer and tops out within haul reach",
		function()
			local n = 0
			for _, d in world:GetDescendants() do
				if d:IsA("BasePart") and WALLS[d.Name] then
					n += 1
					local y = d.CFrame.Position.Y -- (Lune's Part has no derived Position)
					local bottom, top = y - d.Size.Y / 2, y + d.Size.Y / 2
					if bottom > DEEP or top > Waves.SEA_LEVEL + HAUL_MAX then
						error(
							`{d:GetFullName()}: {bottom} .. {top} (needs bottom <= {DEEP}, top <= {HAUL_MAX})`
						)
					end
				end
			end
			t.expect(n > 0).toBe(true)
		end
	)

	t.test("each island's three pile decks have a swim skirt up to their underside", function()
		for i = 1, Marina.COUNT do
			local plate = world.IslandPlates:FindFirstChild(`Plate{i}`)
			local skirts = plate and plate:FindFirstChild("SwimSkirts")
			t.expect(skirts ~= nil).toBe(true)
			local count = 0
			for _, s in (skirts :: Instance):GetChildren() do
				count += 1
				t.expect(s.Transparency).toBe(1)
				t.expect(s.CFrame.Position.Y + s.Size.Y / 2).toBeCloseTo(Marina.DECK_TOP - 1, 1e-3)
			end
			t.expect(count).toBe(3)
		end
	end)
end
