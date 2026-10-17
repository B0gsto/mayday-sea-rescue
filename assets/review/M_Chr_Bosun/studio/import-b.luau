
local function lod0Box(model: Instance): (Vector3, Vector3)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") and string.find(p.Name, "_LOD0") and not string.find(p.Name, "_COL") then
			local h = p.Size / 2
			for _, sx in {-1, 1} do for _, sy in {-1, 1} do for _, sz in {-1, 1} do
				local w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
				mn = mn:Min(w); mx = mx:Max(w)
			end end end
		end
	end
	return mn, mx
end

local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local A = "M_Chr_Bosun"
local CFG: any = {["name"] = "M_Chr_Bosun", ["source"] = "Workspace/M_Chr_Bosun", ["tier"] = "hero", ["sets"] = {["Fur"] = {["NOR"] = "103748169485793", ["RGH"] = "77028271605241", ["Wet"] = {["RGH"] = "119325078333872", ["NOR"] = "100632999508535", ["ALB"] = "106200218168749"}, ["ALB"] = "72677137767461", ["MET"] = "92191140489137", ["alphaMode"] = "Transparency"}, ["Harness"] = {["Wet"] = {["RGH"] = "139563428363372", ["NOR"] = "123326580701832", ["ALB"] = "100866977192425"}, ["MET"] = "101631640126594", ["RGH"] = "122403920806076", ["NOR"] = "99011034098276", ["ALB"] = "80508447575444"}, ["Body"] = {["Wet"] = {["RGH"] = "107948487145826", ["ALB"] = "133270748415860", ["NOR"] = "102318804896381"}, ["RGH"] = "114876666079129", ["ALB"] = "135572693292701", ["NOR"] = "131093018094688", ["MET"] = "92191140489137"}}}
local IDNAMES: {[string]: string} = {["103748169485793"] = "T_Bosun_Fur_NOR.png", ["77028271605241"] = "T_Bosun_Fur_RGH.png", ["127650751038896"] = "T_Bosun_Fur_RGH_Wet.png", ["136161537490250"] = "T_Bosun_Fur_NOR_Wet.png", ["139563428363372"] = "T_Bosun_Harness_RGH_Wet.png", ["132940714883591"] = "T_Bosun_Fur_ALB.png", ["128729814698779"] = "T_Bosun_Harness_MET.png", ["106200218168749"] = "T_Bosun_Fur_ALB_Wet.png", ["89869746461866"] = "T_Bosun_Body_RGH_Wet.png", ["124715963239143"] = "T_Bosun_Body_ALB_Wet.png", ["114876666079129"] = "T_Bosun_Body_RGH.png", ["123326580701832"] = "T_Bosun_Harness_NOR_Wet.png", ["73590411681709"] = "T_Bosun_Harness_NOR_Wet.png", ["100632999508535"] = "T_Bosun_Fur_NOR_Wet.png", ["107761244501881"] = "T_Bosun_Body_ALB.png", ["124354172288228"] = "T_Bosun_Harness_RGH.png", ["120618846558449"] = "T_Bosun_Harness_NOR.png", ["100866977192425"] = "T_Bosun_Harness_ALB_Wet.png", ["78173250678751"] = "T_Bosun_Body_NOR_Wet.png", ["102318804896381"] = "T_Bosun_Body_NOR_Wet.png", ["76747465814971"] = "T_Bosun_Harness_ALB_Wet.png", ["99011034098276"] = "T_Bosun_Harness_NOR.png", ["133270748415860"] = "T_Bosun_Body_ALB_Wet.png", ["122403920806076"] = "T_Bosun_Harness_RGH.png", ["119325078333872"] = "T_Bosun_Fur_RGH_Wet.png", ["84206738702518"] = "T_Bosun_Body_NOR.png", ["135572693292701"] = "T_Bosun_Body_ALB.png", ["92191140489137"] = "T_Bosun_Body_MET.png", ["133402828268520"] = "T_Bosun_Fur_RGH.png", ["131093018094688"] = "T_Bosun_Body_NOR.png", ["91347224757059"] = "T_Bosun_Harness_RGH_Wet.png", ["130981403101613"] = "T_Bosun_Harness_ALB.png", ["101631640126594"] = "T_Bosun_Harness_MET.png", ["80508447575444"] = "T_Bosun_Harness_ALB.png", ["72677137767461"] = "T_Bosun_Fur_ALB.png", ["133152335720908"] = "T_Bosun_Fur_ALB_Wet.png", ["107948487145826"] = "T_Bosun_Body_RGH_Wet.png", ["102472218436672"] = "T_Bosun_Fur_NOR.png", ["97126455887113"] = "T_Bosun_Body_RGH.png"}
local FUR_WET_ALB = "106200218168749"
local NON_ALB: {[string]: boolean} = {["100632999508535"] = true, ["101631640126594"] = true, ["102318804896381"] = true, ["103748169485793"] = true, ["107948487145826"] = true, ["114876666079129"] = true, ["119325078333872"] = true, ["122403920806076"] = true, ["123326580701832"] = true, ["131093018094688"] = true, ["139563428363372"] = true, ["77028271605241"] = true, ["92191140489137"] = true, ["99011034098276"] = true}
local T = Vector3.new(-46.0, 6.0, -9.0)
local MAPPROPS = {"ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap"}
local function now(): number return DateTime.now().UnixTimestampMillis / 1000 end
local function digits(uri: string?): string return if uri then (string.match(uri, "(%d+)%s*$") or uri) else "" end

-- 0. clean leftovers of an earlier run in this session
local lookDev: Instance = workspace:FindFirstChild("LookDev") or (function()
	local f = Instance.new("Folder"); f.Name = "LookDev"; f.Parent = workspace
	return f
end)()
for _, n in {A, "BosunStage"} do
	local old = lookDev:FindFirstChild(n)
	if old then old:Destroy() end
end

-- 1. partSets by name pattern: M_Chr_Bosun_<Word>_LODn -> the longest set name that prefixes <Word> (Fur*, Body*, Harness*)
local src = workspace:FindFirstChild(A)
assert(src, "Workspace.M_Chr_Bosun not found (run import-a first)")
local partSets, unmatched = {}, {}
for _, p in src:GetDescendants() do
	if p:IsA("MeshPart") then
		local word = string.match(p.Name, "^M_Chr_Bosun_(%w+)_LOD%d$")
		local best: string? = nil
		if word then
			for setName in CFG.sets do
				if string.sub(word, 1, #setName) == setName and (not best or #setName > #best) then best = setName end
			end
		end
		if best then partSets[p.Name] = best elseif not string.find(p.Name, "_COL") then table.insert(unmatched, p.Name) end
	end
end
CFG.partSets = partSets
local report = _G.ImportAsset(CFG)
local found = lookDev:FindFirstChild(A)
assert(found and found:IsA("Model"), "import failed: " .. HttpService:JSONEncode(report))
local model: Model = found

-- 2. neutral stage: grey seamless deck on the quay + two backdrop walls (behind the hero 3/4 and the side camera)
local stage = Instance.new("Folder"); stage.Name = "BosunStage"; stage.Parent = lookDev
local function slab(name: string, size: Vector3, cf: CFrame, grey: number): Part
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf
	p.Material = Enum.Material.SmoothPlastic; p.Color = Color3.new(grey, grey, grey); p.Reflectance = 0
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false; p.CanCollide = true; p.CanTouch = false
	p.Parent = stage
	return p
end
local rpQuay = RaycastParams.new(); rpQuay.FilterType = Enum.RaycastFilterType.Exclude
rpQuay.FilterDescendantsInstances = {lookDev}
local qhit = workspace:Raycast(T + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), rpQuay)
local quayTop = if qhit and math.abs(qhit.Position.Y - T.Y) < 1.5 then qhit.Position.Y else T.Y
local deckTop = quayTop + 0.05 -- just above the terrain (no z-fight)
slab("Deck", Vector3.new(64, 1, 64), CFrame.new(T.X, deckTop - 0.5, T.Z), 0.42)
slab("WallW", Vector3.new(1, 24, 64), CFrame.new(T.X - 8.5, deckTop + 12, T.Z), 0.5)
slab("WallN", Vector3.new(64, 24, 1), CFrame.new(T.X, deckTop + 12, T.Z + 8.5), 0.5)
-- Night practical key: invisible lamp head 3 m (9 studs) up, front-left, warm white, aimed at the chest
local lamp = Instance.new("Part")
lamp.Name = "NightKeyLamp"; lamp.Anchored = true; lamp.Size = Vector3.one * 0.4; lamp.Transparency = 1
lamp.CanCollide = false; lamp.CanQuery = false; lamp.CanTouch = false; lamp.CastShadow = false
lamp.CFrame = CFrame.lookAt(Vector3.new(T.X - 3.5, deckTop + 9, T.Z - 5), Vector3.new(T.X, deckTop + 1.6, T.Z - 0.6))
lamp.Parent = stage
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Front; spot.Angle = 50; spot.Range = 24; spot.Brightness = 4
spot.Color = Color3.fromRGB(255, 228, 192); spot.Shadows = true; spot.Enabled = false
spot.Parent = lamp

-- 3. ground the feet on the deck by raycast and face the mouth to -Z
local mn, mx = lod0Box(model)
local c = (mn + mx) / 2
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = {model}
local hit = workspace:Raycast(Vector3.new(T.X, deckTop + 40, T.Z), Vector3.new(0, -80, 0), rp)
local top = if hit then hit.Position.Y else deckTop
local feet = Vector3.new(c.X, mn.Y, c.Z)
local mouth = model:FindFirstChild("ATT_Mouth", true)
local yaw = 0
if mouth and mouth:IsA("Attachment") then
	local d = mouth.WorldPosition - c
	yaw = math.atan2(-d.X, -d.Z) -- rotation that takes d onto -Z
end
model:PivotTo(CFrame.new(Vector3.new(T.X, top, T.Z)) * CFrame.Angles(0, -yaw, 0) * CFrame.new(-feet) * model:GetPivot())
local mn2, mx2 = lod0Box(model)

-- 4. fur double-sided
local ds = {}
for _, p in model:GetDescendants() do
	if p:IsA("MeshPart") and partSets[p.Name] == "Fur" then
		local ok, err = pcall(function() (p :: any).DoubleSided = true end)
		local okr, val = pcall(function() return (p :: any).DoubleSided end)
		table.insert(ds, p.Name .. "=" .. (if ok then "set" else "fail:" .. tostring(err)) .. "/" .. tostring(okr and val))
	end
end

-- 5. map ids actually on the SurfaceAppearances; Fur wet ALB must be FUR_WET_ALB and never a NOR/RGH/MET id
local function readMap(sa: SurfaceAppearance, prop: string): string?
	local ok, v = pcall(function() return (sa :: any)[prop] end)
	if ok and type(v) == "string" and v ~= "" then return v end
	local ok2, cv = pcall(function() return (sa :: any)[prop .. "Content"] end)
	if ok2 and cv and cv.Uri and cv.Uri ~= "" then return cv.Uri end
	return nil
end
local idCheck = {ok = true, parts = {}}
for _, p in model:GetDescendants() do
	if p:IsA("MeshPart") and partSets[p.Name] then
		local store = p:FindFirstChild("SurfaceVariants")
		local wet = store and store:FindFirstChild("SurfaceAppearance_Wet")
		local dry = p:FindFirstChildOfClass("SurfaceAppearance")
		local row: any = {part = p.Name, set = partSets[p.Name],
			dryAlpha = if dry then dry.AlphaMode.Name else "none", wetAlpha = if wet and wet:IsA("SurfaceAppearance") then wet.AlphaMode.Name else "none"}
		if wet and wet:IsA("SurfaceAppearance") then
			local alb = digits(readMap(wet, "ColorMap"))
			row.wetALB = alb .. " " .. (IDNAMES[alb] or "?")
			if partSets[p.Name] == "Fur" and (alb ~= FUR_WET_ALB or NON_ALB[alb]) then
				idCheck.ok = false; row.error = "Fur wet ALB is " .. alb .. ", expected " .. FUR_WET_ALB
			end
			if partSets[p.Name] == "Fur" and (row.wetAlpha ~= "Transparency" or row.dryAlpha ~= "Transparency") then
				idCheck.ok = false; row.error = (row.error or "") .. " AlphaMode not Transparency"
			end
		elseif partSets[p.Name] == "Fur" and string.match(p.Name, "_LOD0$") then
			idCheck.ok = false; row.error = "no stored wet variant"
		end
		table.insert(idCheck.parts, row)
	end
end

-- 6. preload: every SurfaceAppearance (dry on the parts + wet stored in SurfaceVariants), time-boxed; reports failed ids
local function preload(timeout: number, activeOnly: boolean?): any
	local mdl = lookDev:FindFirstChild(A)
	local sas = {}
	if mdl then
		for _, d in mdl:GetDescendants() do
			if d:IsA("SurfaceAppearance") and (not activeOnly or (d.Parent and d.Parent:IsA("MeshPart"))) then table.insert(sas, d) end
		end
	end
	local statuses: {[string]: string} = {}
	local done, perr = false, nil
	local t0 = now()
	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(sas, function(id: string, st: Enum.AssetFetchStatus) statuses[id] = st.Name end)
		end)
		if not ok then perr = tostring(err) end
		done = true
	end)
	while not done and now() - t0 < timeout do task.wait(0.25) end
	local failed, known, n = {}, {}, 0
	for _, sa in sas do
		for _, prop in MAPPROPS do
			local uri = readMap(sa, prop)
			if uri then
				n += 1
				known[uri] = true
				local okf, fs = pcall(function() return ContentProvider:GetAssetFetchStatus(uri) end)
				local st = statuses[uri] or (if okf then fs.Name else "unknown")
				if st ~= "Success" and not (okf and fs.Name == "Success") then
					local id = digits(uri)
					table.insert(failed, {id = id, file = IDNAMES[id] or "not in manifest", status = st, prop = prop, sa = sa:GetFullName()})
				end
			end
		end
	end
	local other = {} -- ids the engine fetched on its own (e.g. Studio's generated TexturePack for a SurfaceAppearance)
	for id, st in statuses do
		if not known[id] and st ~= "Success" then table.insert(other, id .. "=" .. st) end
	end
	return {allOk = done and perr == nil and #failed == 0 and #other == 0, finished = done, seconds = now() - t0,
		surfaceAppearances = #sas, maps = n, failed = failed, otherFailed = other, error = perr}
end
_G.BosunPreload = preload

-- 7. per-shot driver: preset + wet, identical exposure offset on top of the preset, Night key on, preload of the active maps
_G.BosunShot = function(preset: string, wet: boolean, ev: number): string
	local r = _G.LookDev.apply(preset, wet)
	local base = Lighting.ExposureCompensation
	Lighting.ExposureCompensation = base + ev
	local lampNow = stage:FindFirstChild("NightKeyLamp")
	local key = lampNow and lampNow:FindFirstChildOfClass("SpotLight")
	if key then key.Enabled = preset == "Night" end
	local pr = preload(6, true)
	local bad = {}
	for _, f in pr.failed do table.insert(bad, f.id .. ":" .. f.status) end
	for _, o in pr.otherFailed do table.insert(bad, o) end
	return string.format("%s | EC %.2f%+.2f | key %s | preload %s %.1fs %s", r, base, ev, if key and key.Enabled then "on" else "off",
		if pr.allOk then "ok" else "FAIL", pr.seconds, table.concat(bad, ","))
end

local pre = preload(40, false)
local m2 = if mouth and mouth:IsA("Attachment") then mouth.WorldPosition else Vector3.zero
local atts = {}
for _, d in model:GetDescendants() do
	if d:IsA("Attachment") and string.sub(d.Name, 1, 4) == "ATT_" then
		local w = d.WorldPosition
		table.insert(atts, string.format("%s @ %s (%.2f, %.2f, %.2f)", d.Name, d.Parent and d.Parent.Name or "?", w.X, w.Y, w.Z))
	end
end
return HttpService:JSONEncode({report = report, pre = _G.BosunPre, partSets = partSets, unmatched = unmatched,
	quayHit = if qhit then qhit.Instance:GetFullName() else "none", quayTop = quayTop, deckTop = deckTop,
	feetHit = if hit then hit.Instance:GetFullName() else "none", feetY = mn2.Y, yawDeg = math.deg(yaw),
	bboxMin = {mn2.X, mn2.Y, mn2.Z}, bboxMax = {mx2.X, mx2.Y, mx2.Z}, mouth = {m2.X, m2.Y, m2.Z}, attachments = atts,
	doubleSided = ds, idCheck = idCheck, preload = pre})
