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

return string.format(
	"lookdev setup (%s): %s; presets %s, skies %s, wet-capable parts %d",
	if isClient then "client" else "edit",
	stats,
	if Presets then "ok" else "MISSING",
	if SkyAssets then "ok" else "MISSING",
	#CollectionService:GetTagged("HasWetVariant")
)
