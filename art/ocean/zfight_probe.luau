-- Ocean z-fight probe (Client datamodel, play mode, mesh ocean): reads the live EditableMeshes of
-- every MeshPart in workspace.ClientOcean and samples the rendered surfaces every 0.5 studs.
--   fight: foam meant to show (all 3 foam-triangle corners lifted above the water) but within
--          0.02 studs of, or under, the water there. Zero means the foam can never fight the sea.
-- Also lists other sea-level surfaces (Parts whose top is within 0.3 of the sea, Terrain water).
local folder = workspace:FindFirstChild("ClientOcean")
if not folder then
	return "no ClientOcean"
end
local function lattice(part: MeshPart)
	local em = part.MeshContent.Object :: EditableMesh?
	if not em then
		return nil
	end
	local pts, cell, half = {}, math.huge, 0
	local xs = {}
	for _, v in em:GetVertices() do
		local p = em:GetPosition(v)
		if math.abs(p.Y) < 9.95 then
			pts[math.round(p.X * 2) * 100000 + math.round(p.Z * 2)] = p.Y
			xs[math.round(p.X * 2)] = true
			half = math.max(half, math.abs(p.X))
		end
	end
	local sorted = {}
	for k in xs do
		table.insert(sorted, k)
	end
	table.sort(sorted)
	for i = 2, #sorted do
		cell = math.min(cell, (sorted[i] - sorted[i - 1]) / 2)
	end
	local function y(x, z)
		return pts[math.round(x * 2) * 100000 + math.round(z * 2)]
	end
	-- Same triangulation as MeshGrid: (v00, v01, v10) and (v10, v01, v11).
	local function at(x: number, z: number): (number?, number?)
		local fi, fj = (x + half) / cell, (z + half) / cell
		local i, j = math.floor(fi), math.floor(fj)
		if fi < 0 or fj < 0 or fi > 2 * half / cell or fj > 2 * half / cell then
			return nil
		end
		i, j =
			math.min(i, math.round(2 * half / cell) - 1),
			math.min(j, math.round(2 * half / cell) - 1)
		local ti, tj = fi - i, fj - j
		local x0, z0 = i * cell - half, j * cell - half
		if
			not (y(x0, z0) and y(x0 + cell, z0) and y(x0, z0 + cell) and y(x0 + cell, z0 + cell))
		then
			return nil -- a hole cell (MeshGrid draws no triangle there even if 3 corners exist)
		end
		local a, b, c, w1, w2
		if ti + tj <= 1 then
			a, b, c = y(x0, z0), y(x0 + cell, z0), y(x0, z0 + cell)
			w1, w2 = ti, tj
		else
			a, b, c = y(x0 + cell, z0 + cell), y(x0, z0 + cell), y(x0 + cell, z0)
			w1, w2 = 1 - ti, 1 - tj
		end
		if not (a and b and c) then
			return nil
		end
		return a + w1 * (b - a) + w2 * (c - a), math.min(a, b, c)
	end
	return { at = at, half = half, cell = cell, y = y }
end
local waters, foams, names = {}, {}, {}
for _, p in folder:GetDescendants() do
	if p:IsA("MeshPart") then
		local l = lattice(p)
		if l then
			table.insert(names, `{p.Name}(c{l.cell} h{l.half})`)
			if p.Name:find("Foam") then
				l.name = p.Name
				table.insert(foams, l)
			elseif p.Name == "OceanNear" or p.Name == "OceanRing" then
				table.insert(waters, if p.Name == "OceanNear" then 1 else #waters + 1, l)
			end
		end
	end
end
local function water(x, z)
	for _, w in waters do
		local h = w.at(x, z)
		if h then
			return h
		end
	end
	return nil
end
local shown, fight, worst, worstAt = 0, 0, 0, ""
for _, f in foams do
	local s = -f.half
	while s <= f.half do
		local u = -f.half
		while u <= f.half do
			local fy = f.at(s, u)
			if fy then
				-- corner lifts of the foam triangle under this sample
				local fi, fj = (s + f.half) / f.cell, (u + f.half) / f.cell
				local i, j = math.floor(fi), math.floor(fj)
				local x0, z0 = i * f.cell - f.half, j * f.cell - f.half
				local corners = if (fi - i) + (fj - j) <= 1
					then { { x0, z0 }, { x0 + f.cell, z0 }, { x0, z0 + f.cell } }
					else {
						{ x0 + f.cell, z0 + f.cell },
						{ x0, z0 + f.cell },
						{ x0 + f.cell, z0 },
					}
				local lifted = true
				for _, c in corners do
					local cy, wy = f.y(c[1], c[2]), water(c[1], c[2])
					if not (cy and wy and cy - wy > 0.03) then
						lifted = false
						break
					end
				end
				local wy = water(s, u)
				if lifted and wy then
					shown += 1
					local gap = fy - wy
					if gap < 0.02 then
						fight += 1
						if gap < worst then
							worst, worstAt = gap, string.format(" at %s (%.1f, %.1f)", f.name, s, u)
						end
					end
				end
			end
			u += 0.5
		end
		s += 0.5
	end
end
-- Other surfaces at sea level near the camera.
local cam = workspace.CurrentCamera.CFrame.Position
local others = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not d:IsDescendantOf(folder) and d.Transparency < 0.95 then
		local top = d.Position.Y + d.Size.Y / 2
		if math.abs(top) < 0.3 and d.Size.X * d.Size.Z > 64 and #others < 8 then
			table.insert(
				others,
				`{d:GetFullName()}({d.Material.Name} top {string.format("%.2f", top)})`
			)
		end
	end
end
local okV, mats = pcall(function()
	local r = Region3.new(
		cam - Vector3.new(256, 0, 256) * Vector3.new(1, 0, 1) - Vector3.new(0, cam.Y + 4, 0),
		cam + Vector3.new(256, 4 - cam.Y, 256)
	):ExpandToGrid(4)
	return workspace.Terrain:ReadVoxels(r, 4)
end)
local waterVox = 0
if okV then
	local size = mats.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if mats[x][y][z] == Enum.Material.Water then
					waterVox += 1
				end
			end
		end
	end
end
return string.format(
	"meshes %s | foam shown %d fight %d (%.2f%%) worst %.3f%s | sea-level parts: %s | terrain water voxels %s",
	table.concat(names, " "),
	shown,
	fight,
	100 * fight / math.max(shown, 1),
	worst,
	worstAt,
	if #others > 0 then table.concat(others, ", ") else "none",
	if okV then tostring(waterVox) else "?"
)
