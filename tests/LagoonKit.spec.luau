-- LagoonKit (PERF-BL12): every LAYOUT row is a real kit module, the gameplay spots stay on the config's coordinates, walkable
-- and clear of collision, the café's door is open, and a kit that lacks a module places nothing (init.luau's fallback runs).
return function(t)
	local AssetIds = t.load("src/shared/Config/AssetIds.luau")
	local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")
	local L = t.load("src/server/World/Islands/MermaidLagoon/LagoonKit.luau")
	local atts = AssetIds.Attachments[L.ASSET]

	local function fakeKit(skip: string?): Model
		local kit = Instance.new("Model")
		kit.WorldPivot = CFrame.identity
		for module, slot in L.SLOTS do
			if module ~= skip then
				local p = Instance.new("Part")
				p.Name = module
				p.Size = Vector3.new(2, 2, 2)
				p.CFrame = CFrame.new(atts[`ATT_{slot}`] + Vector3.new(1, 2, 0))
				p.Parent = kit
			end
		end
		return kit
	end

	local function placed(ground: number?): Instance
		local root = Instance.new("Folder")
		t.expect(L.build(root, fakeKit(), function()
			return ground
		end, "MermaidLagoon")).toBe(true)
		return root
	end

	local function isSolidAt(root: Instance, pos: Vector3): boolean
		for _, d in root:GetDescendants() do
			if d.Name == "Col" then
				local part = d :: BasePart
				local o = part.CFrame:PointToObjectSpace(pos)
				if
					math.abs(o.X) <= part.Size.X / 2
					and math.abs(o.Y) <= part.Size.Y / 2
					and math.abs(o.Z) <= part.Size.Z / 2
				then
					return true
				end
			end
		end
		return false
	end

	local function island(): any
		for _, row in WorldConfig.Islands do
			if row.id == "MermaidLagoon" then
				return row
			end
		end
		error("no MermaidLagoon")
	end

	local function firstRow(module: string): any
		for _, row in L.LAYOUT do
			if row.module == module then
				return row
			end
		end
		error(`no {module}`)
	end

	t.test("every row's module is in the kit at its slot", function()
		local source = t.lune("fs").readFile("art/source/props/M_Prop_LagoonKit/build.py")
		for _, row in L.LAYOUT do
			local slot = L.SLOTS[row.module]
			t.expect(string.find(source, `("{row.module}", "{slot}",`, 1, true) ~= nil).toBe(true)
			t.expect(atts[`ATT_{slot}`] ~= nil).toBe(true)
		end
	end)

	t.test("the props stand on the config's gameplay points", function()
		local isle = island()
		local function at(module: string, x: number, z: number)
			local row = firstRow(module)
			t.expect(row.x).toBe(x)
			t.expect(row.z).toBe(z)
		end
		at("L03_Jetty", isle.dock.X, isle.dock.Z)
		at("L04_DayMark", isle.landmark.X, isle.landmark.Z)
		at("L06_StampPost", isle.stamp.X, isle.stamp.Z)
		local pad = isle.pads[1]
		at("L07_Cafe", (pad.min.X + pad.max.X) / 2, 4993)
		t.expect(firstRow("L07_Cafe").y).toBe(pad.y)
	end)

	t.test("a kit without a module places nothing", function()
		local root = Instance.new("Folder")
		t.expect(L.build(root, fakeKit("L18_Palm"), function()
			return 14
		end, "MermaidLagoon")).toBe(false)
		t.expect(#root:GetChildren()).toBe(0)
	end)

	t.test("a row whose ground is missing or under water is skipped", function()
		local function check(ground: number?)
			local names = {}
			for _, m in placed(ground):GetChildren() do
				names[m.Name] = true
			end
			t.expect(names.L18_Palm).toBe(nil)
			t.expect(names.StampPost).toBe(nil)
			t.expect(names.Jetty).toBe(true)
			t.expect(names.MermaidStatue).toBe(true)
		end
		check(nil)
		check(0.4)
	end)

	t.test("meshes are inert, colliders invisible; a scaled row lands at its spot", function()
		local root = placed(14)
		local meshes = 0
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				local col = d.Name == "Col"
				meshes += if col then 0 else 1
				t.expect(d.CanCollide).toBe(col)
				t.expect(d.Anchored).toBe(true)
				t.expect(d.CanTouch).toBe(false)
				t.expect(d.Transparency).toBe(if col then 1 else 0)
			end
		end
		t.expect(meshes).toBe(#L.LAYOUT)
		local row = firstRow("L18_Palm") -- offset (1, 2, 0) from the slot, scaled, then yawed
		local want = CFrame.new(row.x, 14, row.z)
			* CFrame.Angles(0, math.rad(row.yaw), 0)
			* Vector3.new(row.scale, 2 * row.scale, 0)
		local found = false
		for _, d in root:GetDescendants() do
			if d.Name == "L18_Palm" and d:IsA("BasePart") then
				found = found or ((d :: BasePart).CFrame.Position - want).Magnitude < 1e-3
			end
		end
		t.expect(found).toBe(true)
	end)

	t.test("the jetty, stairs, terrace and shack floor are underfoot", function()
		local root = placed(14)
		for _, surface in
			{
				Vector3.new(500, 12.4, 4950), -- island.landing
				Vector3.new(500, 7.9, 4937.2), -- a stair tread
				Vector3.new(500, 3.4, 4870), -- deck
				Vector3.new(510, 3.4, 4821), -- T-head
				Vector3.new(405, 16.8, 5010), -- terrace
				Vector3.new(405, 16.8, 4975), -- inside the shack
			}
		do
			t.expect(isSolidAt(root, surface)).toBe(true)
		end
	end)

	t.test("the gameplay spots stand clear", function()
		local root = placed(14)
		local isle = island()
		for _, spot in
			{
				isle.landing,
				isle.dock,
				isle.landing + Vector3.new(-12, 0, 6), -- the quest spots (Quests/Data)
				isle.landing + Vector3.new(14, 0, -4),
				isle.stamp + Vector3.new(0, 0, 3), -- in front of the stamp post's plate
			}
		do
			for h = 0.5, 5.5 do
				t.expect(isSolidAt(root, Vector3.new(spot.X, spot.Y + h, spot.Z))).toBe(false)
			end
		end
	end)

	t.test("the walk from the terrace through the east door into the shack is clear", function()
		local root = placed(14)
		for x = 405, 428 do
			for z = 4971, 4976 do
				for y = 17.5, 24.5 do
					t.expect(isSolidAt(root, Vector3.new(x, y, z))).toBe(false)
				end
			end
		end
	end)

	t.test("the statue and column stand solid", function()
		local root = placed(14)
		local s = firstRow("L01_Statue")
		t.expect(isSolidAt(root, Vector3.new(s.x, 30, s.z))).toBe(true)
		local c = firstRow("L23_ColumnTall")
		t.expect(isSolidAt(root, Vector3.new(c.x, 15, c.z))).toBe(true)
	end)
end
