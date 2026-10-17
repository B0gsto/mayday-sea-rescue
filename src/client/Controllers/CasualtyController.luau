--!strict
-- CasualtyController: animates the rigged swimmer casualties (tag CasualtyRig, built by the server's
-- Assets/CasualtyAsset + RescueService) on this client, because Bone.Transform doesn't replicate:
--   * the pose named by the model's CasualtyPose attribute (TreadWater | Wave | Panic | Sit, from
--     Shared.Casualty.CasualtyRig), cross-faded over BLEND seconds when it changes; far ones are skipped;
--   * the lifejacket strobe: a small Neon lens + PointLight on the ATT_Strobe bone, flashing at about
--     1 Hz (SOLAS lights: 50-70 flashes a minute) when it's dark, stormy or the light is low
--     (Workspace attribute CasualtyStrobeHold = true holds it lit, for stills).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CasualtyRig = require(Shared:WaitForChild("Casualty"):WaitForChild("CasualtyRig"))

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
	lens: Part?,
	light: PointLight?,
}

local rigs: { [Model]: Rig } = {}
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

local function step()
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
		local t = now + r.phase
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
				b.Transform = cf
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
					or (t * CasualtyController.FLASH_HZ) % 1
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
	RunService.RenderStepped:Connect(step)
end

return CasualtyController
