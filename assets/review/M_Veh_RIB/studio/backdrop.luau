-- V2 fix pass: neutral grey stand floor + distant cyclorama walls under the lifted RIB (skeg base at y 40), and a
-- spotlight rig for Night (_G.RIBSpot). Everything lives in Workspace.LookDevBackdrop (never saved to the place).
-- stand the imported RIB + helm on the floor keel-down: try the axis rotations about the RIB pivot, keep the one whose
-- bbox is flat (height under 12 studs) with the driver's eye point above the propellers, then sit the bbox on y 40
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
		local cands = { CFrame.new(), CFrame.Angles(math.rad(90), 0, 0), CFrame.Angles(math.rad(-90), 0, 0),
			CFrame.Angles(0, 0, math.rad(90)), CFrame.Angles(0, 0, math.rad(-90)), CFrame.Angles(math.rad(180), 0, 0) }
		-- flattest orientation first (smallest bbox height), then keel-down (eye point above the props)
		local best, bestH = 1, math.huge
		for i, r in cands do
			rib:PivotTo(CFrame.new(base.Position) * r * base.Rotation)
			local _, size = rib:GetBoundingBox()
			if size.Y < bestH - 0.5 then
				best, bestH = i, size.Y
			end
		end
		local rot = cands[best]
		rib:PivotTo(CFrame.new(base.Position) * rot * base.Rotation)
		local eye = rib:FindFirstChild("ATT_EyePoint", true)
		local prop = rib:FindFirstChild("ATT_Prop1", true)
		if eye and prop and eye.WorldPosition.Y < prop.WorldPosition.Y then
			local look = (eye.WorldPosition - prop.WorldPosition) * Vector3.new(1, 0, 1)
			local axis = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, 1)
			rib:PivotTo(CFrame.new(base.Position) * CFrame.fromAxisAngle(axis, math.pi) * rot * base.Rotation)
		end
		standInfo = string.format("stand rotation %d height %.1f on %s", best, bestH, rib:GetFullName())
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
