-- H2 Chandlery look-dev rig (Edit datamodel, after import-setup / import-int / import-props / import-stock):
--  * neutral grey ground slab (top y 40 = quay level of the shared pivot) + distant cyclorama walls (LookDevBackdrop)
--  * shopfront Glass / DoorGlass: SurfaceAppearance off, Material Glass, Transparency 0.4, Reflectance 0.2, cool tint;
--    DoorGlass welded to Door
--  * Glow parts (interior lamp glass, stock, exterior M_Bld_Chandlery_Ext_Glow_*): warm Neon while their lamps are on
--  * warm practicals (~2700 K) at every ATT_Light_NN: pendants + holophanes (PointLight + downward SpotLight pool),
--    loft wall lamps, bulkheads (PointLight); a SpotLight from the stock's ATT_Light_Till down onto the counter;
--    warm PointLights just inside the bay (the glow behind the glazing); exterior goosenecks at ATT_Lamp_NN
--  * cool daylight fill (~6500 K): a SurfaceLight across the inside of the bay + a SpotLight under the skylight
--  * light values: DEF below, overlaid key by key by _G.ChandLightSpec (= layout.LIGHTS, written into import-setup.luau
--    by make_import_setup.py when the Ext builder defines it)
--  * _G.ChandLights(interior, exterior, cool?) switches them (cool defaults to "not exterior", i.e. day);
--    _G.ChandCheck() reports the rig numerically
-- Frame: model-local studs = (-bx*3, bz*3, by*3) of layout.py metres; world = pivot (0, 40, 0) + local.
local CS = game:GetService("CollectionService")
local EXT, INT, PROPS, STOCK = "M_Bld_Chandlery_Ext", "M_Bld_Chandlery_Int", "M_Prop_Chandlery", "M_Prop_Chandlery_Stock"
local Y = 40

-- light spec (keep in sync with layout.LIGHTS; colours are RGB 0..255, brightness / range / angle are Roblox units)
local DEF: { [string]: any } = {
	warm = { 255, 177, 110 }, -- ~2700 K practicals
	cool = { 200, 220, 255 }, -- ~6500 K window / skylight fill
	glow_int = { 255, 196, 132 }, -- Neon lamp glass indoors
	glow_ext = { 255, 206, 150 }, -- Neon exterior lamp glass
	glow_off = { 196, 190, 178 }, -- unlit lamp glass
	pendant = { brightness = 0.6, range = 14, drop = 0.35, spot_brightness = 1.4, spot_range = 16, spot_angle = 70 },
	holophane = { brightness = 0.7, range = 14, drop = 0.45, spot_brightness = 1.8, spot_range = 14, spot_angle = 80 },
	wall = { brightness = 0.5, range = 12, drop = 0.3 },
	bulkhead = { brightness = 0.45, range = 11, drop = 0 },
	till = { brightness = 2.2, range = 12, angle = 50 },
	bay_glow = { brightness = 0.8, range = 12 },
	window = { brightness = 0.35, range = 22, angle = 75 },
	skylight = { brightness = 0.6, range = 22, angle = 70 },
	ext_lamp = { brightness = 1.1, range = 16, drop = 0.6, spot_brightness = 1.6, spot_range = 18, spot_angle = 80 },
	glass = { transparency = 0.4, reflectance = 0.2, color = { 96, 112, 120 } },
}
local specSrc = "defaults"
local spec = (_G :: any).ChandLightSpec
if type(spec) == "table" then
	specSrc = "layout.LIGHTS"
	for k, v in spec do
		local d = DEF[k]
		if type(v) == "table" and type(d) == "table" and type(v[1]) ~= "number" then
			for kk, vv in v do -- a per-kind table: overlay key by key
				d[kk] = vv
			end
		elseif type(v) == "table" then
			DEF[k] = v -- a colour triple or a new key
		end
	end
end
local function rgb(t: any, fallback: { number }): Color3
	t = if type(t) == "table" and type(t[1]) == "number" then t else fallback
	return Color3.fromRGB(t[1], t[2], t[3])
end
local WARM, COOL = rgb(DEF.warm, { 255, 177, 110 }), rgb(DEF.cool, { 200, 220, 255 })
local function col(kind: string, base: Color3): Color3
	local c = DEF[kind] and DEF[kind].color
	return if type(c) == "table" then rgb(c, { 255, 177, 110 }) else base
end

-- backdrop
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
local old2 = workspace:FindFirstChild("LookDevChandLights")
if old2 then old2:Destroy() end
local rig = Instance.new("Folder")
rig.Name = "LookDevChandLights"
rig.Parent = workspace

local function model(n: string): Model?
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == n then
			return d
		end
	end
	return nil
end
local ext, int, props, stock = model(EXT), model(INT), model(PROPS), model(STOCK)
local base = int or ext or stock or props
local pivot = if base then base:GetPivot() else CFrame.new(0, Y, 0)
local function plain(p: BasePart)
	for _, c in p:GetChildren() do
		if c:IsA("SurfaceAppearance") or (c:IsA("Configuration") and c.Name == "SurfaceVariants") then
			c:Destroy()
		end
	end
	CS:RemoveTag(p, "HasWetVariant")
end

-- shopfront glass
local glassN, weldN = 0, 0
if ext then
	local door, dglass
	local g = DEF.glass
	for _, p in ext:GetDescendants() do
		if p:IsA("BasePart") and (string.find(p.Name, "_Glass_LOD", 1, true) or string.find(p.Name, "_DoorGlass_LOD", 1, true)) then
			plain(p)
			p.Material = Enum.Material.Glass
			p.Color = rgb(g.color, { 96, 112, 120 })
			p.Reflectance = g.reflectance
			p.CastShadow = false
			if not p:GetAttribute("LodHidden") then
				p.Transparency = g.transparency
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

-- Glow parts: switched between warm Neon (lamp on) and plain unlit glass
local glowInt, glowExt = {}, {}
local glowIntVis, glowExtVis = 0, 0
for _, m in { int, stock, props, ext } do
	if m then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and string.find(p.Name, "_Glow_LOD", 1, true) then
				plain(p)
				p.CastShadow = false
				local outside = m == ext
				table.insert(if outside then glowExt else glowInt, p)
				if not p:GetAttribute("LodHidden") then
					if outside then glowExtVis += 1 else glowIntVis += 1 end
				end
			end
		end
	end
end
local function setGlow(list: { BasePart }, on: boolean, c: Color3)
	for _, p in list do
		p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Color = if on then c else rgb(DEF.glow_off, { 196, 190, 178 })
	end
end

-- light helpers: lights live on Attachments (axis-aligned unless aimed) so Face is in world terms
local intLights: { Light }, extLights: { Light }, coolLights: { Light } = {}, {}, {}
local kinds: { [string]: number } = {}
local function count(k: string)
	kinds[k] = (kinds[k] or 0) + 1
end
local function holder(name: string, parent: Instance, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = parent
	a.WorldCFrame = cf
	return a
end
local function point(a: Attachment, c: Color3, b: number, r: number, shadows: boolean, list: { Light })
	local l = Instance.new("PointLight")
	l.Name = "LookDevPractical"
	l.Color, l.Brightness, l.Range, l.Shadows, l.Enabled = c, b, r, shadows, false
	l.Parent = a
	table.insert(list, l)
	return l
end
local function spot(a: Attachment, c: Color3, b: number, r: number, angle: number, face: Enum.NormalId, list: { Light })
	local l = Instance.new("SpotLight")
	l.Name = "LookDevPool"
	l.Color, l.Brightness, l.Range, l.Angle, l.Face, l.Shadows, l.Enabled = c, b, r, angle, face, true, false
	l.Parent = a
	table.insert(list, l)
	return l
end
-- an invisible anchored carrier part (for SurfaceLights / lights with no host attachment)
local function carrier(name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = rig
	return p
end
local anchor = carrier("LightAnchor", Vector3.new(0.2, 0.2, 0.2), pivot)

-- classify an interior practical from its model-local position (studs; inner faces x +-28.35, z +-16.35,
-- ground-floor beams at y 8.85, loft floor 10.05): loft-level = wall lamp, near a wall = bulkhead, over the counter
-- (x -21.9..-2.1, z 1.8..3.75) = holophane, else enamel pendant
local function kindOf(lp: Vector3): string
	local wallD = math.min(28.35 - math.abs(lp.X), 16.35 - math.abs(lp.Z))
	if lp.Y > 9.5 then
		return "wall"
	elseif wallD < 1.5 then
		return "bulkhead"
	elseif lp.X > -22.5 and lp.X < -1.5 and lp.Z > 1.0 and lp.Z < 4.5 then
		return "holophane"
	end
	return "pendant"
end

for _, m in { int, ext, stock } do
	if m then
		for _, a in m:GetDescendants() do
			if a:IsA("Attachment") and string.match(a.Name, "^ATT_Light_%d+$") then
				local k = kindOf(pivot:PointToObjectSpace(a.WorldPosition))
				local s = DEF[k]
				local la = holder(a.Name .. "_Light", a.Parent :: Instance, CFrame.new(a.WorldPosition - Vector3.new(0, s.drop or 0, 0)))
				point(la, col(k, WARM), s.brightness, s.range, true, intLights)
				count(k)
				if s.spot_brightness then
					spot(la, col(k, WARM), s.spot_brightness, s.spot_range, s.spot_angle, Enum.NormalId.Bottom, intLights)
					count("pool")
				end
			elseif a:IsA("Attachment") and string.match(a.Name, "^ATT_Lamp_%d+$") then
				local s = DEF.ext_lamp
				local la = holder(a.Name .. "_Light", a.Parent :: Instance, CFrame.new(a.WorldPosition - Vector3.new(0, s.drop, 0)))
				point(la, col("ext_lamp", WARM), s.brightness, s.range, true, extLights)
				spot(la, col("ext_lamp", WARM), s.spot_brightness, s.spot_range, s.spot_angle, Enum.NormalId.Bottom, extLights)
				count("ext_lamp")
			end
		end
	end
end

-- till spot: the stock's ATT_Light_Till (fallback: 4.5 studs over the interior ATT_Till), aimed at the till / counter
local function findAtt(m: Model?, n: string): Attachment?
	if not m then return nil end
	for _, a in m:GetDescendants() do
		if a:IsA("Attachment") and a.Name == n then return a end
	end
	return nil
end
local tillSrc = "none"
do
	local src, target = findAtt(stock, "ATT_Light_Till"), findAtt(int, "ATT_Till") or findAtt(stock, "ATT_Till")
	local pos: Vector3? = nil
	if src then
		pos, tillSrc = src.WorldPosition, "stock ATT_Light_Till"
	elseif target then
		pos, tillSrc = target.WorldPosition + Vector3.new(0, 4.5, 0), "fallback over ATT_Till"
	end
	if pos then
		local aim = if target and (target.WorldPosition - pos).Magnitude > 1 then target.WorldPosition else pos - Vector3.new(0, 5, 0)
		local cf = CFrame.lookAt(pos, aim, Vector3.zAxis)
		local s = DEF.till
		spot(holder("Till_Light", anchor, cf), col("till", WARM), s.brightness, s.range, s.angle, Enum.NormalId.Front, intLights)
		count("till")
	end
end

-- warm glow behind the glazing: PointLights high in the bay, between the glass and the bay mannequins
-- (bay: local x 13.8 .. -24, glass z -19.8, inner wall face z -16.35, head y 8.85)
for i, x in { 8.0, -5.1, -18.0 } do
	local s = DEF.bay_glow
	point(holder("BayGlow_" .. i, anchor, pivot * CFrame.new(x, 7.4, -18.3)), col("bay_glow", WARM), s.brightness, s.range, false, intLights)
	count("bay_glow")
end

-- cool daylight fill: one SurfaceLight across the inside of the bay facing into the room (+Z = Back face),
-- and a SpotLight under the back-slope skylight (local x 7.5, z 11.6, roof hole y ~21 .. 22.5) pointing down
do
	local s = DEF.window
	local p = carrier("BayFill", Vector3.new(36, 5.6, 0.2), pivot * CFrame.new(-5.1, 5.6, -16.1))
	local l = Instance.new("SurfaceLight")
	l.Name = "LookDevWindowFill"
	l.Face, l.Color, l.Brightness, l.Range, l.Angle, l.Shadows, l.Enabled =
		Enum.NormalId.Back, col("window", COOL), s.brightness, s.range, s.angle, true, false
	l.Parent = p
	table.insert(coolLights, l)
	count("window")
	local k = DEF.skylight
	spot(holder("SkylightFill", anchor, pivot * CFrame.new(7.5, 20.4, 11.6)), col("skylight", COOL), k.brightness, k.range, k.angle,
		Enum.NormalId.Bottom, coolLights)
	count("skylight")
end

local state = { inside = false, outside = false, cool = false }
_G.ChandLights = function(inside: boolean, outside: boolean, cool: boolean?): string
	workspace.CurrentCamera.FieldOfView = 40
	local c = if cool == nil then not outside else cool
	state.inside, state.outside, state.cool = inside, outside, c
	for _, l in intLights do l.Enabled = inside end
	for _, l in extLights do l.Enabled = outside end
	for _, l in coolLights do l.Enabled = c end
	setGlow(glowInt, inside, rgb(DEF.glow_int, { 255, 196, 132 }))
	setGlow(glowExt, outside, rgb(DEF.glow_ext, { 255, 206, 150 }))
	return string.format("lights int %d %s, ext %d %s, cool %d %s", #intLights, tostring(inside), #extLights,
		tostring(outside), #coolLights, tostring(c))
end
_G.ChandLights(false, false, false)

_G.ChandCheck = function(): string
	local piv = {}
	for _, n in { EXT, INT, PROPS, STOCK } do
		local mm = model(n)
		piv[#piv + 1] = if mm then string.format("%s %.2f,%.2f,%.2f", n, mm:GetPivot().X, mm:GetPivot().Y, mm:GetPivot().Z) else n .. " MISSING"
	end
	local ks = {}
	for _, k in { "pendant", "holophane", "wall", "bulkhead", "pool", "till", "bay_glow", "window", "skylight", "ext_lamp" } do
		ks[#ks + 1] = k .. " " .. (kinds[k] or 0)
	end
	local stockParts = 0
	if stock then
		for _, p in stock:GetDescendants() do
			if p:IsA("MeshPart") and not p:GetAttribute("LodHidden") then stockParts += 1 end
		end
	end
	return string.format(
		"chandlery rig: glass visible %d, door weld %d, glow visible int %d ext %d; lights int %d ext %d cool %d (%s); till %s; stock visible parts %d; spec %s; state in %s out %s cool %s; pivots %s",
		glassN, weldN, glowIntVis, glowExtVis, #intLights, #extLights, #coolLights, table.concat(ks, ", "), tillSrc,
		stockParts, specSrc, tostring(state.inside), tostring(state.outside), tostring(state.cool), table.concat(piv, " | "))
end
return _G.ChandCheck()
