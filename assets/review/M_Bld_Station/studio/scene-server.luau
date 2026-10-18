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
return "H1 scene (server) ok"
