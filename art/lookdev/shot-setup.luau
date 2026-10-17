--!strict
--# selene: allow(global_usage)
--[==[
art/lookdev/shot-setup.luau: setup for the per-batch Studio look-dev pass (docs/12-asset-list.md 1.4
item 7, 3.3). Based on art/ocean/shot-setup.luau. Runs once through studio-shot.py --setup, in either
  * the Client datamodel (play mode, the ocean flow: --dm Client): measures 3 s of frame stats, unbinds
    the game's CameraController render steps (MaydayCameraPre / MaydayCamera) and locks the camera to
    the workspace attribute ShotCF before the ocean step and last; anchors the character; or
  * the Edit datamodel (default --dm Edit): no game scripts run, the presets are written directly.
Both: hides every ScreenGui (PlayerGui ScreenGuis Enabled = false, new ones too; CoreGui off via
StarterGui:SetCoreGuiEnabled(All, false); in Edit StarterGui.ShowDevelopmentGui = false), and installs
  _G.LookDev.apply(presetName: "Clear" | "Overcast" | "Storm" | "Night" (also "Calm"), wet: boolean?) -> string
  _G.LookDev.shot(cam: {x,y,z}, look: {x,y,z})   sets workspace ShotCF (Client camera lock)
  _G.LookDev.hideBillboards(hide: boolean)       BillboardGuis / SurfaceGuis in workspace off/on
  _G.LookDev.restore()                           undoes the GUI hiding and lighting override
so a shots.json entry can say  "lua": "_G.LookDev.apply('Storm', true)"  (art/lookdev/shots-example.json).

Presets come from ReplicatedStorage.Shared.Config.LightingPresets and skies from the Client's
Ocean.SkyAssets (the same data WeatherController uses). In play mode WeatherController keeps blending at
10 Hz, so apply() (a) sets the Lighting attribute WeatherBase and ClockTime so its own blend agrees for
Clear / Overcast / Night, (b) detaches the Atmosphere, Clouds, Sky and effects it writes to and puts
look-dev copies in their place, and (c) rewrites the Lighting properties every frame at
RenderPriority.Last. For Storm in play mode, also run the server "/storm now" dev command first (as
art/ocean/capture.sh does) if the shot needs rain and lightning; the look itself is forced either way.

What "wet" means: the game has no visual wet-surface state yet (WeatherController only drives lighting
and rain; "wetness" exists only as tyre grip in src/shared/Car). Here wet = the asset's own wet maps:
  1. every part tagged HasWetVariant (made by tools/studio/import_asset.luau) swaps its SurfaceAppearance
     for the stored SurfaceAppearance_Wet (in its "SurfaceVariants" Configuration) and back;
  2. any BasePart whose MaterialVariant "X" has a twin "X_Wet" in MaterialService, and any terrain base
     material override "X" with an "X_Wet" twin (batch B02's wet MaterialVariant library), is swapped;
  3. Lighting attribute LookDevWet = true (for anything that wants to key off it). No lighting tweak:
     the preset alone sets the light, so dry and wet shots differ only in the surfaces.
Repeated apply() calls are idempotent. The setup's return value is the frame-stats line.
]==]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local isClient = RunService:IsClient() and RunService:IsRunning()
local player = Players.LocalPlayer

local LookDev: any = (_G :: any).LookDev
if LookDev and LookDev.restore then
	pcall(LookDev.restore) -- re-running the setup starts clean
end
LookDev = {}
(_G :: any).LookDev = LookDev

--------------------------------------------------------------------------------------------------
-- Data

local function findModule(parent: Instance?, path: { string }): any
	local node = parent
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("ModuleScript") then
		local ok, result = pcall(require, node)
		if ok then
			return result
		end
	end
	return nil
end

local Presets = findModule(ReplicatedStorage, { "Shared", "Config", "LightingPresets" })
local clientRoot: Instance? = if isClient and player
	then player:FindFirstChild("PlayerScripts")
	else StarterPlayer:FindFirstChild("StarterPlayerScripts")
local SkyAssets = findModule(clientRoot, { "Client", "Ocean", "SkyAssets" })

--------------------------------------------------------------------------------------------------
-- Frame stats and camera lock (Client only; same conventions as art/ocean/shot-setup.luau)

local stats = "edit datamodel (no frame stats)"
if isClient then
	local n, total, worst = 0, 0, 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		n += 1
		total += dt
		worst = math.max(worst, dt)
	end)
	task.wait(3)
	conn:Disconnect()
	stats = string.format(
		"frame avg %.2f ms (%.0f fps), worst %.1f ms",
		total / math.max(n, 1) * 1000,
		n / math.max(total, 1e-6),
		worst * 1000
	)
	for _, name in { "MaydayCameraPre", "MaydayCamera" } do
		pcall(function()
			RunService:UnbindFromRenderStep(name)
		end)
	end
	local function lockCamera()
		local cf = workspace:GetAttribute("ShotCF")
		if typeof(cf) == "CFrame" then
			local c = workspace.CurrentCamera
			c.CameraType = Enum.CameraType.Scriptable
			c.CFrame = cf
		end
	end
	for _, name in { "ShotLockA", "ShotLockB" } do
		pcall(function()
			RunService:UnbindFromRenderStep(name)
		end)
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("ShotLockA", Enum.RenderPriority.Camera.Value, lockCamera)
	RunService:BindToRenderStep("ShotLockB", Enum.RenderPriority.Last.Value, lockCamera)
	local char = player and player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrp.Anchored = true
	end
end

function LookDev.shot(cam: { number }, look: { number })
	local cf =
		CFrame.lookAt(Vector3.new(cam[1], cam[2], cam[3]), Vector3.new(look[1], look[2], look[3]))
	workspace:SetAttribute("ShotCF", cf)
end

--------------------------------------------------------------------------------------------------
-- GUI hiding

local guiRestore: { [Instance]: boolean } = {}
local guiConns: { RBXScriptConnection } = {}
local devGuiWas: boolean? = nil

local function hideGui(g: Instance)
	if g:IsA("ScreenGui") or g:IsA("BillboardGui") or g:IsA("SurfaceGui") then
		local layer = g :: LayerCollector
		if guiRestore[layer] == nil then
			guiRestore[layer] = layer.Enabled
		end
		layer.Enabled = false
	end
end

local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if playerGui then
	for _, g in playerGui:GetChildren() do
		hideGui(g)
	end
	table.insert(guiConns, playerGui.ChildAdded:Connect(hideGui))
end
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)
if not isClient then
	pcall(function()
		devGuiWas = StarterGui.ShowDevelopmentGui
		StarterGui.ShowDevelopmentGui = false
	end)
end

local billboardConn: RBXScriptConnection? = nil
function LookDev.hideBillboards(hide: boolean)
	if billboardConn then
		billboardConn:Disconnect()
		billboardConn = nil
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			if hide then
				hideGui(d)
			elseif guiRestore[d] ~= nil then
				(d :: LayerCollector).Enabled = guiRestore[d]
				guiRestore[d] = nil
			end
		end
	end
	if hide then
		billboardConn = workspace.DescendantAdded:Connect(function(d)
			if d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
				hideGui(d)
			end
		end)
	end
end

--------------------------------------------------------------------------------------------------
-- Lighting

local OWN = "LookDev" -- name of every instance this file creates
local detached: { { inst: Instance, parent: Instance } } = {}
local own: { [string]: Instance } = {}
local current: any = nil
local lightStep = "LookDevLight"

-- Replace whatever WeatherController (or the place) uses with look-dev copies, once.
local function ownInstance(parent: Instance, className: string): Instance
	local key = className
	local mine = own[key]
	if mine and mine.Parent then
		return mine
	end
	for _, c in parent:GetChildren() do
		if c.ClassName == className and c.Name ~= OWN then
			table.insert(detached, { inst = c, parent = parent })
			c.Parent = nil
		end
	end
	local created: Instance
	local template = nil
	for _, d in detached do
		if d.inst.ClassName == className then
			template = d.inst
		end
	end
	created = if template then template:Clone() else Instance.new(className :: any)
	created.Name = OWN
	created.Parent = parent
	own[key] = created
	return created
end

local function writeLighting(p: any)
	Lighting.Brightness = p.Brightness
	Lighting.ExposureCompensation = p.ExposureCompensation
	Lighting.Ambient = p.Ambient
	Lighting.OutdoorAmbient = p.OutdoorAmbient
	Lighting.ColorShift_Top = p.ColorShift_Top
	Lighting.EnvironmentDiffuseScale = p.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = p.EnvironmentSpecularScale
	if Lighting.ClockTime ~= p.ClockTime then
		Lighting.ClockTime = p.ClockTime
	end
end

local function applyPreset(name: string, p: any)
	writeLighting(p)
	local atmosphere = ownInstance(Lighting, "Atmosphere") :: Atmosphere
	atmosphere.Density = p.AtmosphereDensity
	atmosphere.Haze = p.AtmosphereHaze
	atmosphere.Color = p.AtmosphereColor
	atmosphere.Decay = p.AtmosphereDecay
	atmosphere.Glare = p.AtmosphereGlare
	atmosphere.Offset = 0.15
	local clouds = ownInstance(workspace.Terrain, "Clouds") :: Clouds
	clouds.Enabled = true
	clouds.Cover = p.CloudsCover
	clouds.Density = p.CloudsDensity
	clouds.Color = p.CloudsColor
	local cc = ownInstance(Lighting, "ColorCorrectionEffect") :: ColorCorrectionEffect
	cc.Enabled = true
	cc.Brightness = 0
	cc.Saturation = p.Saturation
	cc.Contrast = p.Contrast
	cc.TintColor = p.TintColor
	local bloom = ownInstance(Lighting, "BloomEffect") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = p.BloomIntensity
	bloom.Size = p.BloomSize
	bloom.Threshold = p.BloomThreshold
	local rays = ownInstance(Lighting, "SunRaysEffect") :: SunRaysEffect
	rays.Intensity = p.SunRaysIntensity
	rays.Spread = 0.6
	rays.Enabled = p.SunRaysIntensity > 0.001
	local sky = ownInstance(Lighting, "Sky") :: Sky
	local faces = SkyAssets and SkyAssets[name]
	if faces then
		sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = faces.Bk, faces.Dn, faces.Ft
		sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = faces.Lf, faces.Rt, faces.Up
	end
	sky.SunTextureId = "rbxasset://sky/sun.jpg"
	sky.MoonTextureId = "rbxasset://sky/moon.jpg"
	sky.StarCount = 3000
	sky.CelestialBodiesShown = name ~= "Storm" and name ~= "Overcast"
	Lighting:SetAttribute("OceanWaterColor", p.WaterColor)
	Lighting:SetAttribute("OceanHazeColor", p.AtmosphereColor)
	Lighting:SetAttribute("LookDevPreset", name)
	-- WeatherController's own blend: day base + the clock (Night follows the sun).
	Lighting:SetAttribute(
		"WeatherBase",
		if name == "Clear" or name == "Calm" then name else "Overcast"
	)
end

--------------------------------------------------------------------------------------------------
-- Wet swap

local wetVariantRestore: { [BasePart]: string } = {}
local terrainRestore: { [Enum.Material]: string } = {}

local function hasMaterialVariant(name: string): boolean
	return name ~= "" and MaterialService:FindFirstChild(name, true) ~= nil
end

local function setSurfaceWet(part: BasePart, wet: boolean): boolean
	if part:GetAttribute("WetState") == wet then
		return false
	end
	local store = part:FindFirstChild("SurfaceVariants")
	if not store then
		return false
	end
	local active = part:FindFirstChildOfClass("SurfaceAppearance")
	local incoming =
		store:FindFirstChild(if wet then "SurfaceAppearance_Wet" else "SurfaceAppearance_Dry")
	if not (incoming and incoming:IsA("SurfaceAppearance")) then
		return false
	end
	if active then
		active.Name = if wet then "SurfaceAppearance_Dry" else "SurfaceAppearance_Wet"
		active.Parent = store
	end
	incoming.Name = "SurfaceAppearance"
	incoming.Parent = part
	part:SetAttribute("WetState", wet)
	return true
end

local function setWet(wet: boolean): string
	local swapped, variants, terrain = 0, 0, 0
	for _, inst in CollectionService:GetTagged("HasWetVariant") do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local ok, did = pcall(setSurfaceWet, inst, wet)
			if ok and did then
				swapped += 1
			end
		end
	end
	if wet then
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") and d.MaterialVariant ~= "" and wetVariantRestore[d] == nil then
				local twin = d.MaterialVariant .. "_Wet"
				if hasMaterialVariant(twin) then
					wetVariantRestore[d] = d.MaterialVariant
					d.MaterialVariant = twin
					variants += 1
				end
			end
		end
		for _, mat in Enum.Material:GetEnumItems() do
			local ok, override = pcall(function()
				return MaterialService:GetBaseMaterialOverride(mat)
			end)
			if ok and type(override) == "string" and hasMaterialVariant(override .. "_Wet") then
				if terrainRestore[mat] == nil then
					terrainRestore[mat] = override
				end
				pcall(function()
					MaterialService:SetBaseMaterialOverride(mat, override .. "_Wet")
				end)
				terrain += 1
			end
		end
	else
		for part, name in wetVariantRestore do
			part.MaterialVariant = name
			variants += 1
		end
		table.clear(wetVariantRestore)
		for mat, name in terrainRestore do
			pcall(function()
				MaterialService:SetBaseMaterialOverride(mat, name)
			end)
			terrain += 1
		end
		table.clear(terrainRestore)
	end
	Lighting:SetAttribute("LookDevWet", wet)
	return string.format(
		"surfaces %d, material variants %d, terrain overrides %d",
		swapped,
		variants,
		terrain
	)
end

--------------------------------------------------------------------------------------------------
-- API

function LookDev.apply(presetName: string, wet: boolean?): string
	if not Presets then
		return "LookDev: LightingPresets not found (ReplicatedStorage.Shared.Config.LightingPresets)"
	end
	local p = Presets[presetName]
	if type(p) ~= "table" or p.Brightness == nil then
		return "LookDev: unknown preset " .. tostring(presetName)
	end
	current = p
	applyPreset(presetName, p)
	if isClient then
		-- WeatherController writes Lighting.* at 10 Hz and Brightness every frame: write them back last.
		pcall(function()
			RunService:UnbindFromRenderStep(lightStep)
		end)
		RunService:BindToRenderStep(lightStep, Enum.RenderPriority.Last.Value + 1, function()
			if current then
				writeLighting(current)
			end
		end)
	end
	local wetInfo = setWet(wet == true)
	return string.format(
		"LookDev %s %s (%s); sky %s",
		presetName,
		if wet then "wet" else "dry",
		wetInfo,
		if SkyAssets and SkyAssets[presetName] then "set" else "missing"
	)
end

function LookDev.restore()
	local preloadFolder = workspace:FindFirstChild("LookDevPreload")
	if preloadFolder then
		preloadFolder:Destroy()
	end
	pcall(function()
		RunService:UnbindFromRenderStep(lightStep)
	end)
	current = nil
	pcall(setWet, false)
	for _, inst in own do
		inst:Destroy()
	end
	table.clear(own)
	for _, d in detached do
		d.inst.Parent = d.parent
	end
	table.clear(detached)
	Lighting:SetAttribute("WeatherBase", nil)
	Lighting:SetAttribute("LookDevPreset", nil)
	Lighting:SetAttribute("LookDevWet", nil)
	for _, c in guiConns do
		c:Disconnect()
	end
	table.clear(guiConns)
	if billboardConn then
		billboardConn:Disconnect()
		billboardConn = nil
	end
	for g, enabled in guiRestore do
		if g.Parent then
			(g :: LayerCollector).Enabled = enabled
		end
	end
	table.clear(guiRestore)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	if devGuiWas ~= nil then
		pcall(function()
			StarterGui.ShowDevelopmentGui = devGuiWas :: boolean
		end)
	end
	if isClient then
		for _, name in { "ShotLockA", "ShotLockB" } do
			pcall(function()
				RunService:UnbindFromRenderStep(name)
			end)
		end
	end
end

--------------------------------------------------------------------------------------------------
-- Map preload (generalises assets/review/M_Veh_RIB/studio/preload.luau)
--
-- Freshly uploaded maps that are first needed mid-pass (the wet SurfaceAppearance swapped in by
-- apply(_, true), a "_Wet" MaterialVariant) are still downloading / processing at capture time and
-- render flat white. preload() runs before the first capture:
--   1. collects every map id of every SurfaceAppearance in workspace (the active one and the stored
--      SurfaceAppearance_Dry / _Wet in each "SurfaceVariants" Configuration) and of every MaterialVariant
--      in MaterialService (dry and "_Wet" twins), plus the MeshPart TextureIDs;
--   2. pre-creates the stored (not attached) SurfaceAppearances as hidden clones: a 0.05-stud copy of the
--      part, centred inside the original (CastShadow / CanQuery off), wearing the stored SA, so the
--      renderer loads and processes those maps too. They stay until restore();
--   3. ContentProvider:PreloadAsync on all ids (as Decals, the RIB fix) and on the SA / MaterialVariant
--      instances themselves, up to 3 tries per failed id, then waits until every id reports
--      ContentProvider:GetAssetFetchStatus Success (or the timeout) and an extra settle for processing.
-- Returns "preload: N maps (S SAs, V variants, C hidden clones), F failed in T s" and logs failures by id.
-- Runs automatically at the end of this setup unless workspace attribute LookDevNoPreload = true; call
-- _G.LookDev.preload(timeoutSeconds?) again after inserting more assets.

local ContentProvider = game:GetService("ContentProvider")
local MAP_PROPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
local PRELOAD_FOLDER = "LookDevPreload"

local function contentString(inst: Instance, prop: string): string?
	local ok, v = pcall(function()
		return (inst :: any)[prop]
	end)
	if ok and type(v) == "string" and v ~= "" then
		return v
	end
	-- Content-typed twins (ColorMapContent ...) on newer engines
	local ok2, c = pcall(function()
		return (inst :: any)[prop .. "Content"]
	end)
	if ok2 and typeof(c) == "Content" then
		local uri = (c :: any).Uri
		if type(uri) == "string" and uri ~= "" then
			return uri
		end
	end
	return nil
end

function LookDev.preload(timeoutSeconds: number?): string
	local t0 = os.clock()
	local timeout = timeoutSeconds or 120
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(id: string?)
		if
			id
			and not seen[id]
			and (string.find(id, "rbxassetid://", 1, true) or string.find(id, "http", 1, true))
		then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	local instances: { Instance } = {}
	local nSA, nMV, nClones = 0, 0, 0

	local old = workspace:FindFirstChild(PRELOAD_FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = PRELOAD_FOLDER

	for _, d in workspace:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			nSA += 1
			table.insert(instances, d)
			for _, k in MAP_PROPS do
				add(contentString(d, k))
			end
			local holder = d.Parent
			local part = holder and holder.Parent
			if holder and holder.Name == "SurfaceVariants" and part and part:IsA("MeshPart") then
				-- stored, not attached: give it a hidden carrier so the renderer processes it
				local ok = pcall(function()
					local carrier = (part :: MeshPart):Clone()
					carrier:ClearAllChildren()
					for _, tag in CollectionService:GetTags(carrier) do
						CollectionService:RemoveTag(carrier, tag)
					end
					carrier.Name = part.Name .. "_" .. d.Name
					carrier.Anchored = true
					carrier.CanCollide = false
					carrier.CanQuery = false
					carrier.CanTouch = false
					carrier.CastShadow = false
					carrier.Size = Vector3.new(0.05, 0.05, 0.05)
					carrier.CFrame = (part :: MeshPart).CFrame
					d:Clone().Parent = carrier
					carrier.Parent = folder
				end)
				if ok then
					nClones += 1
				end
			end
		elseif d:IsA("MeshPart") then
			add(contentString(d, "TextureID"))
		end
	end
	for _, mv in MaterialService:GetDescendants() do
		if mv:IsA("MaterialVariant") then
			nMV += 1
			table.insert(instances, mv)
			for _, k in MAP_PROPS do
				add(contentString(mv, k))
			end
		end
	end
	folder.Parent = workspace
	table.insert(instances, folder)

	local status: { [string]: Enum.AssetFetchStatus } = {}
	local function preloadIds(list: { string })
		local decals = {}
		for _, id in list do
			local dec = Instance.new("Decal")
			dec.Texture = id
			table.insert(decals, dec)
		end
		pcall(function()
			ContentProvider:PreloadAsync(decals, function(id, st)
				status[id] = st
			end)
		end)
		for _, dec in decals do
			dec:Destroy()
		end
	end
	local done = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(instances)
		end)
		local pending = ids
		for _ = 1, 3 do
			preloadIds(pending)
			local again = {}
			for _, id in pending do
				if status[id] ~= Enum.AssetFetchStatus.Success then
					table.insert(again, id)
				end
			end
			pending = again
			if #pending == 0 or os.clock() - t0 > timeout then
				break
			end
			task.wait(3)
		end
		done = true
	end)
	while not done and os.clock() - t0 < timeout do
		task.wait(0.25)
	end
	-- final word from the fetch cache (also covers ids PreloadAsync never called back for)
	local failed: { string } = {}
	for _, id in ids do
		local ok, st = pcall(function()
			return ContentProvider:GetAssetFetchStatus(id)
		end)
		local s = if ok then st else status[id]
		if s ~= Enum.AssetFetchStatus.Success and status[id] ~= Enum.AssetFetchStatus.Success then
			table.insert(failed, id .. "=" .. tostring(s or status[id] or "no status"))
		end
	end
	if #failed > 0 then
		warn(
			"[LookDev.preload] " .. #failed .. " map(s) not loaded: " .. table.concat(failed, ", ")
		)
	end
	task.wait(2) -- GPU-side processing of the just-fetched maps
	return string.format(
		"preload: %d maps (%d SAs, %d variants, %d hidden clones), %d failed%s in %.1f s%s",
		#ids,
		nSA,
		nMV,
		nClones,
		#failed,
		if #failed > 0 then " [" .. table.concat(failed, ", ") .. "]" else "",
		os.clock() - t0,
		if done then "" else " (TIMEOUT)"
	)
end

local preloadInfo = "preload off (LookDevNoPreload)"
if workspace:GetAttribute("LookDevNoPreload") ~= true then
	local ok, res =
		pcall(LookDev.preload, workspace:GetAttribute("LookDevPreloadTimeout") :: number?)
	preloadInfo = if ok then res else "preload error: " .. tostring(res)
end

return string.format(
	"lookdev setup (%s): %s; presets %s, skies %s, wet-capable parts %d; %s",
	if isClient then "client" else "edit",
	stats,
	if Presets then "ok" else "MISSING",
	if SkyAssets then "ok" else "MISSING",
	#CollectionService:GetTagged("HasWetVariant"),
	preloadInfo
)
