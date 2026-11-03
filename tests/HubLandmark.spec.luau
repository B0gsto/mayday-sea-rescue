-- HubLandmark (PERF-BL12): every LAYOUT row is a real kit module inside the lagoon, the door stays walkable, and with no
-- kit nothing is left in the water, not even collision.
return function(t)
	local AssetIds = t.load("src/shared/Config/AssetIds.luau")
	local H = t.load("src/server/World/HubLandmark.luau")
	local LAGOON = 300 -- the plates' inner edges start at ~310

	local function fakeKit(): Model
		local kit = Instance.new("Model")
		kit.WorldPivot = CFrame.identity
		for module, slot in H.SLOTS do
			local p = Instance.new("Part")
			p.Name = module
			p.Size = Vector3.new(2, 2, 2)
			p.CFrame =
				CFrame.new(AssetIds.Attachments.M_Prop_HubKit[`ATT_{slot}`] + Vector3.new(1, 2, 0))
			p.Parent = kit
		end
		return kit
	end

	local function placed(kit: Model?): Instance
		local world = Instance.new("Folder")
		H.build(world, kit)
		return world
	end

	t.test("every row's module is in the kit, at its slot, and inside the lagoon", function()
		local source = t.lune("fs").readFile("art/source/props/M_Prop_HubKit/build.py")
		for _, row in H.LAYOUT do
			local slot = H.SLOTS[row.module]
			t.expect(string.find(source, `("{row.module}", "{slot}",`, 1, true) ~= nil).toBe(true)
			t.expect(AssetIds.Attachments.M_Prop_HubKit[`ATT_{slot}`] ~= nil).toBe(true)
			t.expect(math.sqrt(row.x ^ 2 + row.z ^ 2) <= LAGOON).toBe(true)
		end
	end)

	t.test("no kit: nothing at all is placed", function()
		t.expect(#placed(nil):GetChildren()).toBe(0)
	end)

	t.test("a scaled row lands at its spot; meshes are inert, colliders invisible", function()
		local m = placed(fakeKit()):FindFirstChild("HubLandmark") :: Model
		local cols = 0
		for _, p in m:GetChildren() do
			local col = p.Name == "Col"
			cols += if col then 1 else 0
			t.expect((p :: BasePart).CanCollide).toBe(col)
			t.expect((p :: BasePart).Anchored).toBe(true)
		end
		t.expect(#m:GetChildren() - cols).toBe(#H.LAYOUT)
		local buoy = H.LAYOUT[9] -- the 1.2 buoy: yaw 0, offset (1, 2, 0) from the slot
		local found = false
		for _, p in m:GetChildren() do
			if p.Name == "L04_Buoy" then
				found = found
					or (
							(p :: BasePart).CFrame.Position - Vector3.new(buoy.x + 1.2, 2.4, buoy.z)
						).Magnitude
						< 1e-3
			end
		end
		t.expect(found).toBe(true)
	end)

	t.test("the walk from the ramp through the arch into the room is clear", function()
		local m = placed(fakeKit()):FindFirstChild("HubLandmark") :: Model
		local y0, y1 = 7, 18 -- over the plank floor (6.05), under the arch's crown (18.15)
		for _, p in m:GetChildren() do
			local part = p :: BasePart
			if p.Name == "Col" then
				local c, s = part.CFrame.Position, part.Size / 2
				local hits = math.abs(c.X) - s.X < 5.5 -- a 11-wide lane, z from the beach to the back wall
					and c.Z + s.Z > -40
					and c.Z - s.Z < 11.8
					and c.Y + s.Y > y0
					and c.Y - s.Y < y1
				t.expect(hits).toBe(false)
			end
		end
	end)
end
