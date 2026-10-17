-- Ocean spike probe (Edit datamodel): does SurfaceAppearance render on an EditableMesh MeshPart,
-- and do EditableMesh vertex colours multiply it? Builds 3 tiles side by side at y=500:
--   A: EM + vertex colour red, no SA     B: EM + vertex colour red + SA     C: EM, white, + SA
local AssetService = game:GetService("AssetService")
local old = workspace:FindFirstChild("OceanProbe")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "OceanProbe"
folder.Parent = workspace
local out = {}
local function tile(name, x0, colour, withSA)
	local em = AssetService:CreateEditableMesh()
	local n, size = 16, 64
	local vid, cid, uid = {}, {}, {}
	for i = 0, n do
		for j = 0, n do
			local x, z = i * size / n - size / 2, j * size / n - size / 2
			local v = em:AddVertex(Vector3.new(x, math.sin(x * 0.2) * 1.5, z))
			table.insert(vid, v)
			table.insert(cid, em:AddColor(colour, 1))
			table.insert(uid, em:AddUV(Vector2.new(x / 32, z / 32)))
		end
	end
	local side = n + 1
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local a, b, c, d = i * side + j + 1, (i + 1) * side + j + 1, i * side + j + 2, (i + 1) * side + j + 2
			for _, tri in { { a, c, b }, { b, c, d } } do
				local f = em:AddTriangle(vid[tri[1]], vid[tri[2]], vid[tri[3]])
				em:SetFaceColors(f, { cid[tri[1]], cid[tri[2]], cid[tri[3]] })
				em:SetFaceUVs(f, { uid[tri[1]], uid[tri[2]], uid[tri[3]] })
			end
		end
	end
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(em))
	end)
	if not ok then
		table.insert(out, name .. " meshpart failed " .. tostring(part))
		return
	end
	part.Name = name
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.new(1, 1, 1)
	part.CFrame = CFrame.new(x0, 500, 0)
	if withSA then
		local sa = Instance.new("SurfaceAppearance")
		local okSet, err = pcall(function()
			sa.ColorMap = "rbxassetid://138852880441749"
			sa.NormalMap = "rbxassetid://100074060791737"
			sa.RoughnessMap = "rbxassetid://112645743621029"
		end)
		table.insert(out, name .. " SA set " .. tostring(okSet) .. " " .. tostring(err))
		sa.Parent = part
	end
	part.Parent = folder
	table.insert(out, name .. " ok size " .. tostring(part.Size))
end
tile("A", -70, Color3.new(1, 0, 0), false)
tile("B", 0, Color3.new(1, 0, 0), true)
tile("C", 70, Color3.new(1, 1, 1), true)
local L = game:GetService("Lighting")
L.ClockTime = 14
return table.concat(out, " | ")
