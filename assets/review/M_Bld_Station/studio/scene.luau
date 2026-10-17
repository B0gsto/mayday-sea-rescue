-- H1 scene: quay slab (top Y 4) under the station, lamps lit for Night, preload every map (3 tries)
local old = workspace:FindFirstChild("H1Scene") if old then old:Destroy() end
local f = Instance.new("Folder") f.Name = "H1Scene" f.Parent = workspace
local q = Instance.new("Part") q.Name = "Quay" q.Anchored = true q.Size = Vector3.new(220, 12, 100)
q.CFrame = CFrame.new(-20, -2, 19) q.Material = Enum.Material.Concrete q.Color = Color3.fromRGB(120, 118, 112) q.Parent = f
for _, d in workspace:GetDescendants() do
	if d:IsA("Attachment") and (d.Name == "ATT_CrewDoor" or d.Name == "ATT_Sign" or d.Name == "ATT_HallBackDoor") then
		local l = Instance.new("PointLight") l.Brightness = 1.2 l.Range = 18 l.Color = Color3.fromRGB(255, 214, 160) l.Parent = d
	end
end
local CP = game:GetService("ContentProvider")
local ids, seen = {}, {}
for _, d in workspace:GetDescendants() do
	if d:IsA("SurfaceAppearance") and string.find(d:GetFullName(), "M_Bld_", 1, true) then
		for _, k in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" } do
			local ok, v = pcall(function() return d[k] end)
			if ok and type(v) == "string" and v ~= "" and not seen[v] then seen[v] = true table.insert(ids, v) end
		end
	end
end
local failed = {}
for attempt = 1, 3 do
	failed = {}
	local list = {}
	for _, id in ids do local dec = Instance.new("Decal") dec.Texture = id table.insert(list, dec) end
	pcall(function() CP:PreloadAsync(list, function(id, s) if s ~= Enum.AssetFetchStatus.Success then table.insert(failed, id) end end) end)
	if #failed == 0 then break end
	task.wait(2)
end
return string.format("H1 scene ok; maps %d, failed %d", #ids, #failed)
