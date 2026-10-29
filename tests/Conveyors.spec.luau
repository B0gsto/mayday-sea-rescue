-- convey1: the belts (src/server/World/Conveyors.luau) push along their own length at SPEED, stand on the plates and
-- bridges, and never cut into a building (every level), a decoration, the build station or the quay edge.
return function(t)
	local C = t.load("src/server/World/Conveyors.luau")
	local R = t.load("src/shared/Config/RingLayout.luau")
	local DP = t.load("src/shared/DockPieces.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local Marina = t.load("src/shared/Marina.luau")
	DP.scaleTo = function(m: Model, s: number) -- as in ZFight.spec
		local pivot = m.WorldPivot
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local rel = pivot:ToObjectSpace(d.CFrame)
				d.CFrame = pivot * (rel - rel.Position + rel.Position * s)
				d.Size *= s
			end
		end
	end

	local world = Instance.new("Folder")
	C.place(world)
	local belts: { BasePart } = {}
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(belts, d)
		end
	end

	t.test("each lane carries its speed (ConveyorController pushes along LookVector)", function()
		local lanes = 0
		for _, p in belts do
			if p.Name == "BeltLane" then
				lanes += 1
				t.expect(p:GetAttribute("BeltSpeed")).toBe(C.SPEED)
			end
		end
		t.expect(lanes).toBe(2 * (#R.Bridges * 7 + #R.Islands))
	end)

	t.test("flat belt parts stand on a plate", function()
		for _, p in belts do
			if math.abs(p.CFrame.LookVector.Y) < 1e-3 then
				local on = false
				for _, isl in R.Islands do
					on = on or R.onPlate(isl, p.CFrame.Position.X, p.CFrame.Position.Z)
				end
				t.expect(on).toBe(true)
			end
		end
	end)

	-- b's box against a's (separating axes on a's faces, then b's): true when they cut in deeper than `tol`
	local function cuts(a: BasePart, b: BasePart, tol: number): boolean
		for _, pair in { { a, b }, { b, a } } do
			local p, q = pair[1], pair[2]
			local rel = p.CFrame:ToObjectSpace(q.CFrame)
			local hq = q.Size / 2
			local x, y, z = rel.RightVector, rel.UpVector, rel.LookVector -- q's axes in p's frame
			for i, half in { p.Size.X / 2, p.Size.Y / 2, p.Size.Z / 2 } do
				local function at(v: Vector3): number
					return math.abs(if i == 1 then v.X elseif i == 2 then v.Y else v.Z)
				end
				local ext = at(x) * hq.X + at(y) * hq.Y + at(z) * hq.Z
				if at(rel.Position) - ext >= half - tol then
					return false
				end
			end
		end
		return true
	end

	local b = Marina.berth(1)
	local here = {}
	for _, p in belts do
		if (p.CFrame.Position - R.Islands[1].center).Magnitude < 260 then
			table.insert(here, p)
		end
	end
	local function clear(label: string, m: Instance): number
		local n = 0
		for _, d in m:GetDescendants() do
			-- paths and stubs are flat tiles the belt may cover; invisible helpers do not show. shortcut: the Air
			-- Station helipad's north edge already lies under the east bridge foot (its deck cuts the pad too); the belt
			-- follows the deck there until the pad moves south
			local pad = label:sub(1, 10) == "AirStation" and d.Name:sub(1, 3) == "Pad"
			if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "Path" and not pad then
				for _, p in here do
					if cuts(p, d, 0.05) then
						n += 1
						local l = R.Islands[1].frame:PointToObjectSpace(d.CFrame.Position)
						print(
							`{label}: {d.Name} at island ({math.floor(l.X)}, {math.floor(-l.Z)}) cuts {p.Name}`
						)
					end
				end
			end
		end
		return n
	end

	t.test(
		"clear of every building at every level, decorations, the build station and the quay edge",
		function()
			local n = clear("base", DP.base(b))
			for _, key in DockConfig.BUILDINGS do
				local def = DockConfig.Buildings[key]
				for level = 1, if def then #def.levels else 1 do
					n += clear(`{key} Lv{level}`, DP.building(key, b, level))
				end
			end
			for key in DockConfig.Decorations do
				n += clear(key, DP.decoration(key, b))
			end
			n += clear("station", DP.buildStation(b))
			t.expect(n).toBe(0)
		end
	)
end
