--!strict
-- CasualtyController: animates the rigged swimmer casualties (tag CasualtyRig, built by the server's
-- Assets/CasualtyAsset + RescueService) on this client, because Bone.Transform doesn't replicate:
--   * the pose named by the model's CasualtyPose attribute (TreadWater | Wave | Panic | Sit, from
--     Shared.Casualty.CasualtyRig), cross-faded over BLEND seconds when it changes; far ones are skipped;
--   * tiring (2026-10-21): the model's Stamina attribute (0..1, the server's condition meter) slows the
--     motion and lets them sit lower in the water;
--   * the lifejacket strobe: a small Neon lens + PointLight on the ATT_Strobe bone, flashing at about
--     1 Hz (SOLAS lights: 50-70 flashes a minute) when it's dark, stormy or the light is low
--     (Workspace attribute CasualtyStrobeHold = true holds it lit, for stills);
--   * hi-vis aboard: a casualty riding a craft (Victim model attribute OnVehicle) gets a light
--     outline so they read apart from the seat at range (no fill: it read as an orange box);
--   * shouting (VoiceTTS, 3D from the model): the nearest casualty in earshot who is waving,
--     panicking or tiring calls out every few seconds, and says thanks once aboard.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CasualtyRig = require(Shared:WaitForChild("Casualty"):WaitForChild("CasualtyRig"))
local VoiceTTS = require(script.Parent.VoiceTTS)

local CasualtyController = {}

CasualtyController.TAG = "CasualtyRig"
CasualtyController.BLEND = 0.45 -- seconds to cross-fade between poses
CasualtyController.POSE_RANGE = 320 -- studs from the camera: farther casualties keep their last pose
CasualtyController.FLASH_HZ = 1.0
CasualtyController.FLASH_ON = 0.13 -- seconds lit per flash
CasualtyController.STROBE_BRIGHTNESS = 2.2
CasualtyController.STROBE_RANGE = 8 -- studs (a personal locator light: lights the head and the water round it)
CasualtyController.STROBE_COLOR = Color3.fromRGB(235, 242, 255) -- xenon / white LED

type Rig = {
	model: Model,
	bones: { [string]: Bone },
	pose: string,
	from: string?,
	changedAt: number,
	phase: number,
	clock: number,
	lens: Part?,
	light: PointLight?,
}

local rigs: { [Model]: Rig } = {}
local SHOUT_RANGE = 200 -- studs from the camera
-- what the casualty shouts, by what they are doing (lines.csv CSM_/CSF_ CASUALTY_*)
local SHOUTS: { [string]: { string } } = {
	Wave = { "Help! Over here!", "Help! Please!", "Over here! We're over here!" },
	Panic = { "I'm going to go under! Help!", "Don't let go of me!", "Help! Please!" },
	Tired = { "Can't. I can't keep going.", "So cold. I'm so cold." },
	Aboard = {
		"Thank you. Really. Thank you.",
		"Swallowed half the bay. I'm all right.",
		"I'm never swimming past the flags again.",
	},
}
local nextShout = 0

-- a casualty keeps one voice: the random phase picks it
local function shoutLine(r: Rig, kind: string): (string, string)
	local pool = SHOUTS[kind]
	return pool[math.random(#pool)], if r.phase < 10 then "CASUALTY_F" else "CASUALTY_M"
end

-- the rig sits inside the server's Victim model, which carries OnVehicle and Stamina
local function victimAttr(model: Model, name: string): any
	local v = model:GetAttribute(name)
	local parent = model.Parent
	if v == nil and parent and parent:IsA("Model") then
		v = parent:GetAttribute(name)
	end
	return v
end

local function shout(camPos: Vector3)
	local now = os.clock()
	if now < nextShout then
		return
	end
	local best: Rig?, bestD, kind = nil, SHOUT_RANGE, ""
	for model, r in rigs do
		if model.Parent and victimAttr(model, "OnVehicle") == nil and r.pose ~= "Sit" then
			local d = (model:GetPivot().Position - camPos).Magnitude
			local tired = (tonumber(victimAttr(model, "Stamina")) or 1) < 0.4
			local k = if r.pose == "Wave" or r.pose == "Panic"
				then r.pose
				elseif tired then "Tired"
				else nil
			if k and d < bestD then
				best, bestD, kind = r, d, k
			end
		end
	end
	if best then
		nextShout = now + 5 + math.random() * 4
		local text, cast = shoutLine(best, kind)
		VoiceTTS.speak(text, cast, { at = best.model, channel = "casualty" })
	end
end
local strobeFolder: Folder? = nil
local weather: any = nil

local function strobeWanted(now: number): boolean
	if Lighting:GetSunDirection().Y < 0.17 then -- sun under ~10 degrees: dusk, night, dawn
		return true
	end
	if Lighting.ClockTime < 6.5 or Lighting.ClockTime > 18.5 then
		return true
	end
	if weather then
		local ok, intensity = pcall(weather.getIntensity, now)
		if ok and type(intensity) == "number" and intensity >= 0.35 then
			return true
		end
		local okState, state = pcall(weather.getState)
		if okState and (state == "Storm" or state == "GreatStorm") then
			return true
		end
	end
	return false
end

local function makeStrobe(r: Rig)
	if r.lens or not r.bones.ATT_Strobe then
		return
	end
	local folder = strobeFolder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "CasualtyStrobes"
		f.Parent = Workspace
		strobeFolder = f
		folder = f
	end
	local lens = Instance.new("Part")
	lens.Name = "StrobeLens"
	lens.Shape = Enum.PartType.Cylinder
	lens.Size = Vector3.new(0.14, 0.22, 0.22) -- a 6 cm dome on the lifejacket shoulder
	lens.Color = Color3.fromRGB(225, 230, 235)
	lens.Material = Enum.Material.Glass
	lens.Transparency = 0.15
	lens.Anchored = true
	lens.CanCollide = false
	lens.CanTouch = false
	lens.CanQuery = false
	lens.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = CasualtyController.STROBE_COLOR
	light.Brightness = CasualtyController.STROBE_BRIGHTNESS
	light.Range = CasualtyController.STROBE_RANGE
	light.Shadows = false
	light.Enabled = false
	light.Parent = lens
	lens.Parent = folder
	r.lens, r.light = lens, light
end

local function add(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local r: Rig = {
		model = model,
		bones = CasualtyRig.bones(model),
		pose = (model:GetAttribute("CasualtyPose") :: string?) or "TreadWater",
		from = nil,
		changedAt = 0,
		phase = math.random() * 20,
		clock = 0,
		lens = nil,
		light = nil,
	}
	rigs[model] = r
	makeStrobe(r)
end

local function remove(model: Instance)
	local r = rigs[model :: Model]
	if r then
		if r.lens then
			r.lens:Destroy()
		end
		rigs[model :: Model] = nil
	end
end

local function step(dt: number)
	local now = os.clock()
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local dark = strobeWanted(Workspace:GetServerTimeNow())
	for model, r in rigs do
		if not model.Parent then
			continue
		end
		if next(r.bones) == nil or not r.bones.Root then
			r.bones = CasualtyRig.bones(model) -- streamed in late
			makeStrobe(r)
			if not r.bones.Root then
				continue
			end
		end
		local want = model:GetAttribute("CasualtyPose")
		if type(want) == "string" and want ~= r.pose then
			r.from, r.pose, r.changedAt = r.pose, want, now
		end
		local pivot = model:GetPivot().Position
		local stamina = math.clamp(tonumber(model:GetAttribute("Stamina")) or 1, 0, 1)
		r.clock += dt * (0.4 + 0.6 * stamina) -- tired: slower strokes and waves
		local t = r.clock + r.phase
		local sink = if r.pose == "Sit" then 0 else (1 - stamina) * 0.7
		if (pivot - camPos).Magnitude < CasualtyController.POSE_RANGE then
			local target = CasualtyRig.sample(r.pose, t)
			local a = if r.from
				then math.clamp((now - r.changedAt) / CasualtyController.BLEND, 0, 1)
				else 1
			local prev = if r.from and a < 1 then CasualtyRig.sample(r.from :: string, t) else nil
			if a >= 1 then
				r.from = nil
			end
			for name, b in r.bones do
				local cf = target[name] or CFrame.identity
				if prev then
					cf = (prev[name] or CFrame.identity):Lerp(cf, a)
				end
				b.Transform = if name == "Root" and sink > 0
					then CFrame.new(0, -sink, 0) * cf
					else cf
			end
		end
		local lens, light = r.lens, r.light
		if lens and light then
			local att = r.bones.ATT_Strobe
			-- dome axis out of the jacket (the bone's -Z, the casualty's front)
			lens.CFrame = att.TransformedWorldCFrame * CFrame.Angles(0, math.pi / 2, 0)
			local lit = dark
				and model:GetAttribute("Strobe") ~= false
				and (
					Workspace:GetAttribute("CasualtyStrobeHold") == true
					or ((now + r.phase) * CasualtyController.FLASH_HZ) % 1
						< CasualtyController.FLASH_ON * CasualtyController.FLASH_HZ
				)
			if light.Enabled ~= lit then
				light.Enabled = lit
				lens.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
				lens.Color = if lit
					then CasualtyController.STROBE_COLOR
					else Color3.fromRGB(225, 230, 235)
				lens.Transparency = if lit then 0 else 0.15
			end
		end
	end
end

function CasualtyController.Init()
	local ok, w = pcall(require, Shared:WaitForChild("Weather") :: ModuleScript)
	weather = if ok then w else nil
end

function CasualtyController.Start()
	CollectionService:GetInstanceAddedSignal(CasualtyController.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(CasualtyController.TAG):Connect(remove)
	for _, m in CollectionService:GetTagged(CasualtyController.TAG) do
		add(m)
	end
	-- PreSimulation, not RenderStepped: the Animator (PreAnimation) runs after RenderStepped and
	-- resets every Transform to the bind pose, so the casualty floated stiff as a plank.
	RunService.PreSimulation:Connect(step)
	task.spawn(function()
		while true do
			local folder = Workspace:FindFirstChild("CallProps")
			for _, m in if folder then folder:GetChildren() else {} do
				if m.Name == "Victim" then
					local hi = m:FindFirstChild("HiVis")
					if m:GetAttribute("OnVehicle") == nil then
						if hi then
							hi:Destroy()
						end
					elseif not hi then
						local rig = m:FindFirstChild("CasualtyRig")
						local r = rigs[m :: Model] or (rig and rigs[rig :: Model])
						if r then
							local text, cast = shoutLine(r, "Aboard")
							VoiceTTS.speak(text, cast, { at = m, channel = "casualty" })
						end
						local h = Instance.new("Highlight")
						h.Name = "HiVis"
						h.FillTransparency = 1 -- outline only: an orange fill flattened them into a box (playtest 2)
						h.OutlineColor = Color3.fromRGB(255, 225, 120)
						h.OutlineTransparency = 0.1
						h.DepthMode = Enum.HighlightDepthMode.Occluded
						h.Parent = m
					end
				end
			end
			local cam = Workspace.CurrentCamera
			if cam then
				shout(cam.CFrame.Position)
			end
			task.wait(0.5)
		end
	end)
end

return CasualtyController
