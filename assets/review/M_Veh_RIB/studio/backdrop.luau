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
-- fix round 3 (Night blew the orange tubes out to yellow and left a white pool on the floor): a soft practical-level
-- key (Brightness 1.2, narrow range so it falls off before the floor around the hull), plus small nav / light-bar
-- PointLights at the RIB's light attachments with realistic reach (1-3 studs), only on for Night.
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Front
spot.Angle = 40
spot.Range = 34
spot.Brightness = 1.2
spot.Color = Color3.fromRGB(255, 236, 214)
spot.Shadows = true
spot.Enabled = false
spot.Parent = rig
rig.CFrame = CFrame.lookAt(Vector3.new(14, 64, -16), Vector3.new(0, 45.5, 0))
local navSpec = {
	ATT_NavPort = { Color3.fromRGB(255, 40, 30), 0.6, 2.5 },
	ATT_NavStarboard = { Color3.fromRGB(40, 255, 90), 0.6, 2.5 },
	ATT_NavMasthead = { Color3.fromRGB(255, 246, 230), 0.7, 3 },
	ATT_NavStern = { Color3.fromRGB(255, 246, 230), 0.5, 2.5 },
	ATT_Beacon = { Color3.fromRGB(60, 110, 255), 0.8, 3 },
}
local navLights = {}
local function ensureNav()
	if #navLights > 0 then
		return
	end
	for _, d in workspace:GetDescendants() do
		local spec = d:IsA("Attachment") and navSpec[d.Name]
		if spec and not d:FindFirstAncestor("M_Veh_RIB_Helm") then
			local l = Instance.new("PointLight")
			l.Name = "LookDevNav"
			l.Color, l.Brightness, l.Range = spec[1], spec[2], spec[3]
			l.Shadows = false
			l.Enabled = false
			l.Parent = d
			table.insert(navLights, l)
		end
	end
end
_G.RIBSpot = function(on: boolean)
	workspace.CurrentCamera.FieldOfView = 40
	spot.Enabled = on
	ensureNav()
	for _, l in navLights do
		l.Enabled = on
	end
end
return "backdrop ok"
