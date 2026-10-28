-- No z-fighting (tools/studio/zfight_scan.luau): builds every island piece the way DockService and
-- WorldDressingService do (plate, quay edge, streets, every building at every level, decorations, the build
-- station, trophies, bridges) and fails on any visible coplanar overlap. Mesh add-ons are not loaded under Lune
-- (DockPieces.meshes is nil), so their Part stand-ins are checked; the Studio scan covers the meshes.
return function(t)
	local Scan = t.load("tools/studio/zfight_scan.luau")
	local DP = t.load("src/shared/DockPieces.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local Marina = t.load("src/shared/Marina.luau")
	local IslandPlates = t.load("src/server/World/IslandPlates.luau")
	local Bridges = t.load("src/server/World/Bridges.luau")
	DP.scaleTo = function(m: Model, s: number) -- Model:ScaleTo round its WorldPivot (BaseParts are all it moves here)
		local pivot = m.WorldPivot
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local rel = pivot:ToObjectSpace(d.CFrame)
				d.CFrame = pivot * (rel - rel.Position + rel.Position * s)
				d.Size *= s
			end
		end
	end

	local function report(roots: { Instance }): { string }
		local out = {}
		for _, f in Scan.find(Scan.collect(roots)) do
			if f.confidence == "high" then
				table.insert(out, Scan.line(f))
			end
		end
		return out
	end

	local LIST = 2000
	local function expectNone(label: string, roots: { Instance })
		local lines = report(roots)
		if #lines > 0 then
			print(`{label}: {#lines} z-fights`)
			for i = 1, math.min(#lines, LIST) do
				print("  " .. lines[i])
			end
		end
		return #lines
	end

	t.test("the scanner: a flush top shows, a lift or a glued contact does not", function()
		local function block(parent: Instance, size: Vector3, pos: Vector3, color: Color3)
			local p = Instance.new("Part")
			p.Size, p.CFrame, p.Color = size, CFrame.new(pos), color
			p.Parent = parent
		end
		local f = Instance.new("Folder")
		block(f, Vector3.new(4, 1, 4), Vector3.new(0, 0, 0), Color3.new(1, 0, 0))
		block(f, Vector3.new(2, 0.5, 2), Vector3.new(0, 0.25, 0), Color3.new(0, 0, 1)) -- top flush with the red's
		block(f, Vector3.new(2, 1, 2), Vector3.new(0, 1, 0), Color3.new(0, 1, 0)) -- sits on them: covers the middle
		t.expect(#Scan.find(Scan.collect({ f }))).toBe(0)
		block(f, Vector3.new(1, 0.5, 1), Vector3.new(1.5, 0.25, 1.5), Color3.new(1, 1, 0)) -- a flush corner in the open
		t.expect(#Scan.find(Scan.collect({ f }))).toBe(3) -- its top, and the two outer sides it shares with the red
	end)

	local plates = Instance.new("Folder")
	IslandPlates.place(plates)
	local b = Marina.berth(1)
	local ground = { plates, DP.base(b), DP.streets(b) }

	t.test("the plates, quay edges, streets and bridges", function()
		local world = Instance.new("Folder")
		IslandPlates.place(world)
		Bridges.place(world)
		for i = 1, Marina.COUNT do
			DP.base(Marina.berth(i)).Parent = world
			DP.streets(Marina.berth(i)).Parent = world
		end
		t.expect(expectNone("ground", { world })).toBe(0)
	end)

	t.test("every building at every level, on its island", function()
		local n = 0
		for _, key in DockConfig.BUILDINGS do
			local def = DockConfig.Buildings[key]
			for level = 1, if def then #def.levels else 1 do
				local roots = table.clone(ground)
				table.insert(roots, DP.building(key, b, level))
				n += expectNone(`{key} Lv{level}`, roots)
			end
		end
		for key in DockConfig.Blueprints do
			local roots = table.clone(ground)
			table.insert(roots, DP.building(key, b))
			n += expectNone(key, roots)
		end
		t.expect(n).toBe(0)
	end)

	t.test("decorations, the build station and trophies", function()
		local roots = table.clone(ground)
		for key in DockConfig.Decorations do
			table.insert(roots, DP.decoration(key, b))
		end
		table.insert(roots, DP.buildStation(b))
		t.expect(expectNone("decor", roots)).toBe(0)
	end)

	t.test("a fully built island", function()
		local roots = table.clone(ground)
		for _, key in DockConfig.BUILDINGS do
			local def = DockConfig.Buildings[key]
			table.insert(roots, DP.building(key, b, if def then #def.levels else nil))
		end
		for key in DockConfig.Decorations do
			table.insert(roots, DP.decoration(key, b))
		end
		table.insert(roots, DP.buildStation(b))
		t.expect(expectNone("maxed island", roots)).toBe(0)
	end)
end
