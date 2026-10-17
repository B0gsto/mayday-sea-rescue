-- H2 Chandlery look-dev rig (Edit datamodel, after import-setup / import-int / import-props):
--  * neutral grey ground slab (top y 40 = quay level of the shared pivot) + distant cyclorama walls (LookDevBackdrop)
--  * Glass / DoorGlass: SurfaceAppearance off, Material Glass, Transparency 0.6, slight reflectance; DoorGlass welded to Door
--  * interior Glow (lamp shades / bulbs): Neon, warm, no shadow cast, SurfaceAppearance removed (Neon only shows without one)
--  * interior PointLights (~2700 K) just under every ATT_Light_*, exterior gooseneck lamps at ATT_Lamp_*
--  * _G.ChandLights(interior, exterior) switches the practicals; _G.ChandCheck() reports the rig numerically
local CS = game:GetService("CollectionService")
local EXT, INT = "M_Bld_Chandlery_Ext", "M_Bld_Chandlery_Int"
local Y = 40
local old = workspace:FindFirstChild("LookDevBackdrop")
if old then old:Destroy() end
local f = Instance.new("Folder")
f.Name = "LookDevBackdrop"
f.Parent = workspace
local function slab(name: string, size: Vector3, pos: Vector3)
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
slab("Floor", Vector3.new(520, 2, 520), Vector3.new(0, Y - 1.02, 0))
for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
	local size = if d.X ~= 0 then Vector3.new(2, 90, 520) else Vector3.new(520, 90, 2)
	slab("Wall", size, d * 260 + Vector3.new(0, Y + 44, 0))
end

local function model(n: string): Model?
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == n then
			return d
		end
	end
	return nil
end
local ext, int = model(EXT), model(INT)
local function plain(p: BasePart)
	for _, c in p:GetChildren() do
		if c:IsA("SurfaceAppearance") or (c:IsA("Configuration") and c.Name == "SurfaceVariants") then
			c:Destroy()
		end
	end
	CS:RemoveTag(p, "HasWetVariant")
end
local glassN, glowN, weldN = 0, 0, 0
if ext then
	local door, dglass
	for _, p in ext:GetDescendants() do
		if p:IsA("BasePart") and (string.find(p.Name, "_Glass_LOD", 1, true) or string.find(p.Name, "_DoorGlass_LOD", 1, true)) then
			plain(p)
			p.Material = Enum.Material.Glass
			p.Color = Color3.fromRGB(52, 62, 66)
			p.Reflectance = 0.12
			p.CastShadow = false
			if not p:GetAttribute("LodHidden") then
				p.Transparency = 0.6
				glassN += 1
			end
			if p.Name == EXT .. "_DoorGlass_LOD0" then dglass = p end
		elseif p:IsA("BasePart") and p.Name == EXT .. "_Door_LOD0" then
			door = p
		end
	end
	if door and dglass then
		local w = Instance.new("WeldConstraint")
		w.Name = "DoorGlassWeld"
		w.Part0, w.Part1 = door, dglass
		w.Parent = door
		weldN = 1
	end
end
if int then
	for _, p in int:GetDescendants() do
		if p:IsA("BasePart") and string.find(p.Name, "_Glow_LOD", 1, true) then
			plain(p)
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(255, 196, 132)
			p.CastShadow = false
			if not p:GetAttribute("LodHidden") then glowN += 1 end
		end
	end
end

-- practicals: a light Attachment 0.35 studs under each marker (so the shade / bulb mesh does not shadow its own lamp)
local WARM = Color3.fromRGB(255, 177, 110)   -- ~2700 K
local intLights, extLights = {}, {}
local function lamp(a: Attachment, list, bright: number, range: number, drop: number)
	local la = Instance.new("Attachment")
	la.Name = a.Name .. "_Light"
	la.Parent = a.Parent
	la.WorldPosition = a.WorldPosition - Vector3.new(0, drop, 0)
	local l = Instance.new("PointLight")
	l.Name = "LookDevPractical"
	l.Color, l.Brightness, l.Range, l.Shadows = WARM, bright, range, true
	l.Enabled = false
	l.Parent = la
	table.insert(list, l)
end
for _, m in { int, ext } do
	if m then
		for _, a in m:GetDescendants() do
			if a:IsA("Attachment") and string.match(a.Name, "^ATT_Light_%d+$") then
				lamp(a, intLights, 0.55, 15, 0.35)
			elseif a:IsA("Attachment") and string.match(a.Name, "^ATT_Lamp_%d+$") then
				lamp(a, extLights, 1.1, 16, 0.6)
			end
		end
	end
end
_G.ChandLights = function(inside: boolean, outside: boolean): string
	workspace.CurrentCamera.FieldOfView = 40
	for _, l in intLights do l.Enabled = inside end
	for _, l in extLights do l.Enabled = outside end
	return string.format("lights int %d %s, ext %d %s", #intLights, tostring(inside), #extLights, tostring(outside))
end
_G.ChandCheck = function(): string
	local piv = {}
	for _, n in { EXT, INT, "M_Prop_Chandlery" } do
		local mm = model(n)
		piv[#piv + 1] = if mm then string.format("%s %.2f,%.2f,%.2f", n, mm:GetPivot().X, mm:GetPivot().Y, mm:GetPivot().Z) else n .. " MISSING"
	end
	return string.format("chandlery rig: glass visible %d, door weld %d, glow visible %d, interior lights %d, exterior lamps %d; pivots %s",
		glassN, weldN, glowN, #intLights, #extLights, table.concat(piv, " | "))
end
return _G.ChandCheck()
