-- V2 fix pass: neutral grey stand floor + distant cyclorama walls under the lifted RIB (skeg base at y 40), and a
-- spotlight rig for Night (_G.RIBSpot). Everything lives in Workspace.LookDevBackdrop (never saved to the place).
-- sit the imported RIB + helm (upright from import_asset.luau) on the floor: bbox bottom on y 40, centred
_G.RIBStand = function(): string
	if _G.RIBStood then
		return _G.RIBStood
	end
	local rib, helm
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and string.find(d.Name, "M_Veh_RIB", 1, true) then
			if string.find(d.Name, "Helm", 1, true) then
				helm = helm or d
			elseif d:FindFirstChild("ATT_EyePoint", true) then
				rib = rib or d
			end
		end
	end
	local names = {}
	for _, c in workspace:GetChildren() do
		table.insert(names, c.Name)
	end
	local standInfo = "no rib; workspace: " .. table.concat(names, ",")
	if rib then
		local base = rib:GetPivot()
		local helmRel = helm and base:ToObjectSpace(helm:GetPivot())
		-- import_asset.luau keeps the authored pivot, so the RIB arrives upright (forward -Z); no axis guessing
		local up = base.UpVector
		standInfo = string.format("upright check: pivot up (%.2f, %.2f, %.2f) on %s", up.X, up.Y, up.Z, rib:GetFullName())
		local cf, size = rib:GetBoundingBox()
		local dy = 40 - (cf.Position.Y - size.Y / 2)
		rib:PivotTo(rib:GetPivot() + Vector3.new(-cf.Position.X, dy, -cf.Position.Z))
		if helm and helmRel then
			helm:PivotTo(rib:GetPivot() * helmRel)
		end
	end
	if rib then _G.RIBStood = standInfo end
	return standInfo
end
local old = workspace:FindFirstChild("LookDevBackdrop")
if old then old:Destroy() end
local f = Instance.new("Folder")
f.Name = "LookDevBackdrop"
f.Parent = workspace
local function slab(name, size, pos)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(118, 120, 122)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = f
	return p
end
slab("Floor", Vector3.new(420, 2, 420), Vector3.new(0, 39, 0))
for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
	local size = if d.X ~= 0 then Vector3.new(2, 70, 420) else Vector3.new(420, 70, 2)
	slab("Wall", size, d * 210 + Vector3.new(0, 74, 0))
end
local rig = Instance.new("Part")
rig.Name = "SpotRig"
rig.Anchored = true
rig.CanCollide = false
rig.Transparency = 1
rig.Size = Vector3.new(1, 1, 1)
rig.CFrame = CFrame.lookAt(Vector3.new(16, 62, -18), Vector3.new(0, 43, 0))
rig.Parent = f
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Front
spot.Angle = 55
spot.Range = 60
spot.Brightness = 6
spot.Color = Color3.fromRGB(255, 244, 228)
spot.Shadows = true
spot.Enabled = false
spot.Parent = rig
_G.RIBSpot = function(on: boolean)
	spot.Enabled = on
end
return "backdrop ok"
