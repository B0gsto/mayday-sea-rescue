-- SectorSpots (docs/31 B.2): each spot sits on its bearing in its sea zone with a lit mark, and its hub-kit dressing
-- stays inside it without pieces overlapping; with no kit nothing is placed.
return function(t)
	local AssetIds = t.load("src/shared/Config/AssetIds.luau")
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local Marks = t.load("src/shared/SeamarkRules.luau").Marks
	local SeaZones = t.load("src/shared/Calls/SeaZones.luau")
	local Spots = t.load("src/shared/Calls/SectorSpots.luau").Spots
	local H = t.load("src/server/World/HubLandmark.luau")
	local S = t.load("src/server/World/SectorSpots.luau")

	-- footprint half-widths at scale 1 (art/source/props/M_Prop_HubKit/build.py)
	local HALF = {
		L01_Atoll = 49,
		L06_RockB = 18,
		L05_RockA = 15,
		L03_Wreck = 17,
		L04_Buoy = 4,
		L07_Raft = 8,
	}

	t.test(
		"each spot: on its bearing, in its zone, open water round it, a lit mark in front",
		function()
			for _, spot in Spots do
				local c = spot.center
				t.expect(math.abs((math.deg(math.atan2(c.Z, c.X)) % 360) - spot.bearing) < 0.5)
					.toBe(true)
				local _, zone = SeaZones.zoneAt(c)
				t.expect(zone.id).toBe(spot.zone)
				t.expect(CallLogic.isWater(c, "Outer")).toBe(false) -- its own rocks
				t.expect(CallLogic.isWater(c * (1 - (spot.radius + 80) / c.Magnitude), "Outer"))
					.toBe(true)
				local lit = false
				for _, m in Marks do
					local d = Vector3.new(m.x, 0, m.z) - c
					lit = lit
						or (m.name == spot.name and d.Magnitude < 250 and d.Magnitude > spot.radius)
				end
				t.expect(lit).toBe(true)
			end
		end
	)

	t.test("dressing rows: real kit modules, inside the spot, no two pieces overlap", function()
		for _, spot in Spots do
			local rows = S.LAYOUTS[spot.id]
			t.expect(rows ~= nil).toBe(true)
			for i, a in rows do
				t.expect(H.SLOTS[a.module] ~= nil).toBe(true)
				t.expect(math.sqrt(a.x ^ 2 + a.z ^ 2) <= spot.radius).toBe(true)
				for j = i + 1, #rows do
					local b = rows[j]
					if HALF[a.module] and HALF[b.module] then
						local gap = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
						t.expect(gap >= HALF[a.module] * a.scale + HALF[b.module] * b.scale)
							.toBe(true)
					end
				end
			end
		end
	end)

	local function fakeKit(): Model
		local kit = Instance.new("Model")
		kit.WorldPivot = CFrame.identity
		for module, slot in H.SLOTS do
			local p = Instance.new("Part")
			p.Name = module
			p.Size = Vector3.new(2, 2, 2)
			p.CFrame = CFrame.new(AssetIds.Attachments.M_Prop_HubKit[`ATT_{slot}`])
			p.Parent = kit
		end
		return kit
	end

	t.test("built at each spot, rocks and wreck solid, nothing without a kit", function()
		local world = Instance.new("Folder")
		S.build(world, nil)
		t.expect(#world:GetChildren()).toBe(0)
		S.build(world, fakeKit())
		for _, spot in Spots do
			local m = world:FindFirstChild(spot.id) :: Model
			t.expect(m ~= nil).toBe(true)
			local cols, solids = 0, 0
			for _, p in m:GetChildren() do
				local part = p :: BasePart
				local d = part.CFrame.Position - spot.center
				t.expect(Vector2.new(d.X, d.Z).Magnitude <= spot.radius + 60).toBe(true)
				cols += if p.Name == "Col" then 1 else 0
				solids += if p.Name == "L05_RockA"
						or p.Name == "L06_RockB"
						or p.Name == "L03_Wreck"
					then 1
					else 0
			end
			t.expect(cols >= solids and solids > 0).toBe(true)
		end
	end)
end
