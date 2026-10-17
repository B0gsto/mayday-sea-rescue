-- Spike 1 Studio probe, Edit datamodel. Lays out the inserted M_Spike1_* models under workspace.Spike1 at Y = 300,
-- builds one SurfaceAppearance per texture size on clones of the test plane, reads EditableImage / EditableMesh
-- data, and returns JSON: model facts, quality settings, and the capture list (world cam / look per shot).
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local ServerStorage = game:GetService("ServerStorage")

local IDS = {
	["1024"] = { ALB = 133497070455294, NOR = 71516326342804, RGH = 106584681481305, MET = 108926989495989 },
	["2048"] = { ALB = 113981166754593, NOR = 76902494683852, RGH = 114094302637870, MET = 118576858914698 },
	["4096"] = { ALB = 77900366731410, NOR = 79130005892903, RGH = 128068413526739, MET = 134209066827654 },
}
local MAPS = { ALB = "ColorMap", NOR = "NormalMap", RGH = "RoughnessMap", MET = "MetalnessMap" }
local out = { errors = {} }
local function v3(v) return { math.round(v.X * 1000) / 1000, math.round(v.Y * 1000) / 1000, math.round(v.Z * 1000) / 1000 } end
local function err(k, e) out.errors[k] = tostring(e) end

-- graphics quality
out.quality = {}
for _, k in { "QualityLevel", "EditQualityLevel", "MeshPartDetailLevel", "GraphicsMode" } do
	local ok, v = pcall(function() return tostring((settings().Rendering :: any)[k]) end)
	out.quality[k] = if ok then v else "err " .. tostring(v)
end
pcall(function() out.quality.SavedQualityLevel = tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel) end)
local okq, eq = pcall(function() (settings().Rendering :: any).EditQualityLevel = Enum.QualityLevel.Level21 end)
out.quality.setEditLevel21 = if okq then "ok" else tostring(eq)
pcall(function() out.quality.EditQualityLevelAfter = tostring((settings().Rendering :: any).EditQualityLevel) end)

local function loadEM(mp)
	local ok, em = pcall(function() return AssetService:CreateEditableMeshAsync(mp.MeshContent) end)
	if not ok then
		local e1 = em
		ok, em = pcall(function() return AssetService:CreateEditableMeshAsync(Content.fromUri(mp.MeshId)) end)
		if not ok then return nil, tostring(e1) .. " | " .. tostring(em) end
	end
	return em, nil
end

local folder = workspace:FindFirstChild("Spike1") or Instance.new("Folder")
folder.Name = "Spike1"
folder.Parent = workspace
local models = {}
for _, c in workspace:GetChildren() do
	if string.match(c.Name, "^M_Spike1_") then models[c.Name] = c end
end

out.models = {}
for name, m in models do
	local mp = if m:IsA("MeshPart") then m else m:FindFirstChildWhichIsA("MeshPart", true)
	local info: any = { class = m.ClassName }
	if m:IsA("Model") then
		local cf, size = m:GetBoundingBox()
		info.bboxSize = v3(size)
		info.pivotMinusBBoxCenter = v3(m.WorldPivot.Position - cf.Position)
		info.worldPivotRot = v3(Vector3.new(m.WorldPivot:ToOrientation()) * (180 / math.pi))
	end
	local hist, atts = {}, {}
	for _, d in m:GetDescendants() do
		hist[d.ClassName] = (hist[d.ClassName] or 0) + 1
		if string.sub(d.Name, 1, 4) == "ATT_" then table.insert(atts, d.ClassName .. ":" .. d.Name) end
	end
	info.classes, info.attNames = hist, atts
	if mp then
		info.part, info.size, info.meshSize = mp.Name, v3(mp.Size), v3(mp.MeshSize)
		info.pos, info.orientation, info.pivotOffset = v3(mp.Position), v3(mp.Orientation), v3(mp.PivotOffset.Position)
		info.hasSkinned, info.renderFidelity = mp.HasSkinnedMesh, tostring(mp.RenderFidelity)
		info.hasSA = mp:FindFirstChildOfClass("SurfaceAppearance") ~= nil
		local em, e = loadEM(mp)
		if em then
			info.emFaces, info.emVerts = #em:GetFaces(), #em:GetVertices()
			pcall(function() info.emBones = #(em :: any):GetBones() end)
			em:Destroy()
		else
			info.emErr = e
		end
	end
	out.models[name] = info
end

-- layout
local function place(name, pos)
	local m = models[name]
	if not m then return nil end
	m.Parent = folder
	local cf, _ = m:GetBoundingBox()
	m:PivotTo(m.WorldPivot + (pos - cf.Position))
	return m
end
place("M_Spike1_ScaleCube", Vector3.new(-60, 300, 0))
place("M_Spike1_RefBox", Vector3.new(-55, 300, 0))
local x = -60
for _, n in { "M_Spike1_Tris09990", "M_Spike1_Tris19990", "M_Spike1_Tris20500", "M_Spike1_Tris21500", "M_Spike1_Tris30000" } do
	place(n, Vector3.new(x, 300, 40))
	x += 15
end
place("M_Spike1_Tentacle20", Vector3.new(-20, 300, 0))
place("M_Spike1_Tentacle40", Vector3.new(-30, 300, 0))

local function setMaps(sa, set)
	for k, prop in MAPS do
		local ok, e = pcall(function() (sa :: any)[prop] = "rbxassetid://" .. set[k] end)
		if not ok then
			err("edit_" .. prop, e)
			pcall(function() (sa :: any)[prop .. "Content"] = Content.fromAssetId(set[k]) end)
		end
	end
end
local function makeSA(set)
	local sa = Instance.new("SurfaceAppearance")
	setMaps(sa, set)
	return sa
end

local planeSrc = models["M_Spike1_TexPlane"]
local planes, sas = {}, {}
for i, size in { "1024", "2048", "4096", "Import" } do
	local m = if i == 4 then planeSrc else planeSrc:Clone()
	m.Name = "Plane" .. size
	m.Parent = folder
	local cf, _ = m:GetBoundingBox()
	m:PivotTo(m.WorldPivot + (Vector3.new((i - 1) * 20, 300, 0) - cf.Position))
	local mp = m:FindFirstChildWhichIsA("MeshPart", true)
	mp.Anchored = true
	if i <= 3 then
		for _, c in mp:GetChildren() do
			if c:IsA("SurfaceAppearance") then c:Destroy() end
		end
		local sa = makeSA(IDS[size])
		sa.Parent = mp
		table.insert(sas, sa)
		planes[size] = mp
	end
end
out.saMapsRead = {}
for size, mp in planes do
	local sa = mp:FindFirstChildOfClass("SurfaceAppearance")
	out.saMapsRead[size] = { sa.ColorMap, sa.NormalMap, sa.RoughnessMap, sa.MetalnessMap }
end
-- AlphaMode writable in Edit?
out.alphaModes = {}
for _, am in Enum.AlphaMode:GetEnumItems() do
	local ok, e = pcall(function() sas[1].AlphaMode = am end)
	out.alphaModes[am.Name] = if ok then "ok" else tostring(e)
end
sas[1].AlphaMode = Enum.AlphaMode.Overlay

-- EditableMesh-backed MeshPart with the 1024 maps
local emInfo: any = {}
do
	local em, e = loadEM(planes["1024"])
	if em then
		local ok, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(em)) end)
		if ok then
			part.Name = "PlaneEM"
			part.Anchored = true
			part.Size = planes["1024"].Size
			part.CFrame = planes["1024"].CFrame + Vector3.new(60, 0, 0)
			local okSA, eSA = pcall(function() makeSA(IDS["1024"]).Parent = part end)
			emInfo.saParent = if okSA then "ok" else tostring(eSA)
			part.Parent = folder
			planes["EM"] = part
		else
			emInfo.createErr = tostring(part)
		end
	else
		emInfo.loadErr = e
	end
end
out.editableMeshPart = emInfo

-- EditableImage sizes
out.editableImage = {}
for size, set in IDS do
	for _, k in { "ALB", "NOR" } do
		local ok, ei = pcall(function() return AssetService:CreateEditableImageAsync(Content.fromAssetId(set[k])) end)
		out.editableImage[size .. "_" .. k] = if ok then tostring(ei.Size) else "err " .. tostring(ei)
		if ok then ei:Destroy() end
	end
end

local okP, eP = pcall(function() ContentProvider:PreloadAsync(sas) end)
out.preload = if okP then "ok" else tostring(eP)

-- UV -> world for the planes (barycentric in UV space over the mesh faces)
local planeEM, eUV = loadEM(planes["1024"])
local function uvToWorld(mp, u, v)
	local em = planeEM
	local verts = em:GetVertices()
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, id in verts do
		local p = em:GetPosition(id)
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local c, ext = (lo + hi) / 2, hi - lo
	local scale = Vector3.new(
		if ext.X > 1e-6 then mp.Size.X / ext.X else 1,
		if ext.Y > 1e-6 then mp.Size.Y / ext.Y else 1,
		if ext.Z > 1e-6 then mp.Size.Z / ext.Z else 1
	)
	for _, f in em:GetFaces() do
		local fv, fu = em:GetFaceVertices(f), em:GetFaceUVs(f)
		local t1, t2, t3 = em:GetUV(fu[1]), em:GetUV(fu[2]), em:GetUV(fu[3])
		local d = (t2.Y - t3.Y) * (t1.X - t3.X) + (t3.X - t2.X) * (t1.Y - t3.Y)
		local a = ((t2.Y - t3.Y) * (u - t3.X) + (t3.X - t2.X) * (v - t3.Y)) / d
		local b = ((t3.Y - t1.Y) * (u - t3.X) + (t1.X - t3.X) * (v - t3.Y)) / d
		local g = 1 - a - b
		if a >= -1e-6 and b >= -1e-6 and g >= -1e-6 then
			local p1, p2, p3 = em:GetPosition(fv[1]), em:GetPosition(fv[2]), em:GetPosition(fv[3])
			local p = (p1 * a + p2 * b + p3 * g - c) * scale
			local n = (p2 - p1):Cross(p3 - p1).Unit
			local okN, fn = pcall(function() return em:GetNormal(em:GetFaceNormals(f)[1]) end)
			if okN and fn then n = fn end
			return mp.CFrame:PointToWorldSpace(p), mp.CFrame:VectorToWorldSpace(n).Unit
		end
	end
	return nil, nil
end

out.shots = {}
out.uvCorners = {}
if planeEM then
	for _, f in planeEM:GetFaces() do
		for i, uvId in planeEM:GetFaceUVs(f) do
			local t = planeEM:GetUV(uvId)
			table.insert(out.uvCorners, { t.X, t.Y, v3(planeEM:GetPosition(planeEM:GetFaceVertices(f)[i])) })
		end
	end
	local ZONES = { { "z1px", 1 / 6, 0.5 }, { "z2px", 0.5, 0.5 }, { "z4px", 5 / 6, 0.5 } }
	local D, FOV = 6, 10
	for _, size in { "1024", "2048", "4096", "EM" } do
		local mp = planes[size]
		if mp then
			for _, z in ZONES do
				local p, n = uvToWorld(mp, z[2], z[3])
				if p then
					local cam = p + n * D + Vector3.new(0, 0, 0.02)
					table.insert(out.shots, { name = "tex" .. size .. "_" .. z[1], cam = v3(cam), look = v3(p), fov = FOV, dist = D })
				end
			end
			local pc, n = uvToWorld(mp, 0.5, 0.5)
			if pc then
				table.insert(out.shots, { name = "over" .. size, cam = v3(pc + n * 24 + Vector3.new(0, 0, 0.05)), look = v3(pc), fov = 30, dist = 24 })
			end
		end
	end
	out.planeNormal = v3(select(2, uvToWorld(planes["1024"], 0.5, 0.5)))
	planeEM:Destroy()
else
	err("uv", eUV)
end

-- tentacles
out.tentacles = {}
for _, n in { "M_Spike1_Tentacle20", "M_Spike1_Tentacle40" } do
	local m = models[n]
	if m then
		local mp = m:FindFirstChildWhichIsA("MeshPart", true)
		local bones = {}
		for _, d in mp:GetDescendants() do
			if d:IsA("Bone") then table.insert(bones, d.Name) end
		end
		local cf, size = m:GetBoundingBox()
		out.tentacles[n] = { bones = #bones, first = bones[1], center = v3(cf.Position), size = v3(size) }
	end
end

-- wet-swap alternative for the play-mode probe: 1024 maps with a red tint
local alt = makeSA(IDS["1024"])
alt.Name = "Spike1Alt"
pcall(function() alt.Color = Color3.new(1, 0.15, 0.15) end)
alt.Parent = ServerStorage

task.wait(4)
return HttpService:JSONEncode(out)
