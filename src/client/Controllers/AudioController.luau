--!strict
-- AudioController: the soundscape and the volume categories (docs 12 section 4, docs 13 RP-AU1).
--
-- Volume categories: SoundGroups in SoundService. `Master` holds `Music`, `SFX`, `Ambience` and
-- `Radio` (nested groups multiply; `Radio` > `Voice` is the NPC voice level, read by VoiceTTS).
--
-- API:
--   AudioController.setVolume(category, 0..1)   also: player attribute `Volume_<Category>` (number)
--   AudioController.getVolume(category): number
--   AudioController.group(category): SoundGroup  the group to assign a Sound's SoundGroup to
--   AudioController.newSound(clipName, parent?, looped?): Sound   an AudioConfig clip, grouped,
--                                                     falling back to its RL stand-in on a failed load
--   AudioController.play(clipName, at: Vector3?, volume?, pitch?)   one shot (3D when `at` is given)
--
-- What it plays: wind (3 layers by Weather.getIntensity and apparent wind), sea beds (harbour /
-- open / storm by zone shelter and height above the surface), rain on the water, the marina bed,
-- halyards clinking on masts with the wind, a bell buoy off the harbour mouth,
-- gulls (quiet in a storm), underwater bed with a muffle on SFX and Ambience, boat engines (jet ski
-- and RIB, two layers crossfaded by RPM; RPM follows the throttle), hull lap / bow wash / wake and
-- hull slams for the driven boat, ticks for world prompts, awards, completed steps and the debrief,
-- a soft click on every HUD button, and two music cues (operation underway, debrief). Rain loop and thunder in WeatherController; the swim splash and strokes in
-- SwimController; Bosun's bark in DogController.

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local AudioMix = require(Shared:WaitForChild("Audio"):WaitForChild("AudioMix"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local Weather = require(Shared:WaitForChild("Weather"))

type Category = AudioConfig.Category

local MIX = AudioConfig.Mix
local BED_HZ = 20

local AudioController = {}
AudioController.Priority = 20 -- before the controllers that make Sounds

local player = Players.LocalPlayer
local rng = Random.new()

---------------------------------------------------------------- groups and volumes

local groups: { [string]: SoundGroup } = {}
local volumes: { [string]: number } = {}
local muffles: { EqualizerSoundEffect } = {}

local function ensureGroups()
	if groups.Master then
		return
	end
	local found = SoundService:FindFirstChild("Master")
	local master: SoundGroup
	local created: { [string]: boolean } = {}
	if found and found:IsA("SoundGroup") then
		master = found
	else
		master = Instance.new("SoundGroup")
		master.Name = "Master"
		master.Parent = SoundService
		created.Master = true
	end
	groups.Master = master
	for _, cat in AudioConfig.Categories do
		if cat ~= "Master" then
			local existing = master:FindFirstChild(cat)
			local g: SoundGroup
			if existing and existing:IsA("SoundGroup") then
				g = existing
			else
				g = Instance.new("SoundGroup")
				g.Name = cat
				g.Parent = master
				created[cat] = true
			end
			groups[cat] = g
			if cat == "SFX" or cat == "Ambience" then
				local eq = Instance.new("EqualizerSoundEffect")
				eq.Name = "UnderwaterMuffle"
				eq.LowGain = 2
				eq.MidGain = -14
				eq.HighGain = -40
				eq.Enabled = false
				eq.Parent = g
				table.insert(muffles, eq)
			end
		end
	end
	-- defaults only on groups we made; a group the settings panel made keeps its saved level
	for _, cat in AudioConfig.Categories do
		if created[cat] then
			groups[cat].Volume = AudioConfig.DefaultVolumes[cat]
		end
		volumes[cat] = groups[cat].Volume
	end
end

function AudioController.group(category: string): SoundGroup
	ensureGroups()
	return groups[category] or groups.SFX
end

function AudioController.setVolume(category: string, value: number)
	ensureGroups()
	local g = groups[category]
	if not g then
		return
	end
	local v = math.clamp(value, 0, 1)
	volumes[category] = v
	g.Volume = v
end

---------------------------------------------------------------- clips

local resolved: { [string]: string } = {} -- clip name -> the id that loaded (primary or fallback)
local checking: { [string]: boolean } = {}

local function checkClip(name: string, sound: Sound)
	local clip = AudioConfig.Clips[name]
	if not (clip and clip.fallback) or resolved[name] or checking[name] then
		return
	end
	checking[name] = true
	task.spawn(function()
		local ok = false
		pcall(function()
			ContentProvider:PreloadAsync({ sound }, function(_, status)
				ok = status == Enum.AssetFetchStatus.Success
			end)
		end)
		local id = if ok then clip.id else clip.fallback :: string
		resolved[name] = id
		checking[name] = nil
		if not ok then
			-- swap every sound already made from this clip
			for _, s in SoundService:GetDescendants() do
				if s:IsA("Sound") and s:GetAttribute("Clip") == name then
					s.SoundId = id
				end
			end
			for _, s in Workspace:GetDescendants() do
				if s:IsA("Sound") and s:GetAttribute("Clip") == name then
					local playing = s.IsPlaying
					s.SoundId = id
					if playing then
						s:Play()
					end
				end
			end
		end
	end)
end

function AudioController.newSound(name: string, parent: Instance?, looped: boolean?): Sound
	ensureGroups()
	local clip = AudioConfig.Clips[name]
	local s = Instance.new("Sound")
	s.Name = name
	s:SetAttribute("Clip", name)
	s.SoundId = resolved[name] or (if clip then clip.id else "")
	s.Volume = 0
	s.Looped = looped == true
	s.SoundGroup = AudioController.group(AudioConfig.categoryOf(name))
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 300
	s.Parent = parent or SoundService
	if clip then
		checkClip(name, s)
	end
	return s
end

local function baseVolume(name: string): number
	local clip = AudioConfig.Clips[name]
	return if clip then clip.volume else 0
end

-- 3D emitters are Attachments on Terrain (its frame is the world frame); local to this client.
local function emitterAt(at: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = "AudioEmitter"
	a.Position = at
	a.Parent = Workspace.Terrain
	return a
end

function AudioController.play(name: string, at: Vector3?, volume: number?, pitch: number?): Sound?
	local clip = AudioConfig.Clips[name]
	if not clip then
		return nil
	end
	local parent: Instance = if at then emitterAt(at) else SoundService
	local s = AudioController.newSound(name, parent, false)
	s.Volume = clip.volume * (volume or 1)
	s.PlaybackSpeed = pitch or 1
	s.Ended:Once(function()
		if parent ~= SoundService then
			parent:Destroy()
		else
			s:Destroy()
		end
	end)
	s:Play()
	task.delay(30, function()
		if parent ~= SoundService then
			parent:Destroy()
		elseif s.Parent then
			s:Destroy()
		end
	end)
	return s
end

---------------------------------------------------------------- beds

type Bed = { sound: Sound, base: number, level: number, fromStart: boolean? }
local beds: { [string]: Bed } = {}

local function bed(name: string, parent: Instance?): Bed
	local b =
		{ sound = AudioController.newSound(name, parent, true), base = baseVolume(name), level = 0 }
	beds[name] = b
	return b
end

-- Fade a looped bed toward a level (0..1); stops it when silent, starts it when audible.
local function setBed(b: Bed, level: number, dt: number, rate: number?)
	local k = 1 - math.exp(-(rate or 3) * dt)
	b.level += (level - b.level) * k
	local v = b.base * b.level
	b.sound.Volume = v
	if v > 0.003 and not b.sound.IsPlaying then
		b.sound.TimePosition = if b.fromStart then 0 else rng:NextNumber(0, 10) -- desynchronise loops
		b.sound:Play()
	elseif v <= 0.003 and b.sound.IsPlaying then
		b.sound:Stop()
	end
end

---------------------------------------------------------------- boats

type BoatRig = {
	model: Model,
	low: Sound,
	high: Sound,
	lowBase: number,
	highBase: number,
	rpm: number,
	topSpeed: number,
	-- driven boat only
	lap: Bed?,
	wash: Bed?,
	wake: Bed?,
	lastSlam: number,
}

local rigs: { [Model]: BoatRig } = {}
local BoatController: any = nil

local ENGINE_CLIPS: { [string]: { low: string, high: string } } = {
	JetSki = { low = "Eng_JetSki_Low", high = "Eng_JetSki_High" },
	RIB = { low = "Eng_RIB_Idle", high = "Eng_RIB_Plane" },
}

local function destroyRig(model: Model)
	local r = rigs[model]
	if not r then
		return
	end
	r.low:Destroy()
	r.high:Destroy()
	if r.lap then
		for _, b in { r.lap :: Bed, r.wash :: Bed, r.wake :: Bed } do
			b.sound:Destroy()
		end
	end
	rigs[model] = nil
end

local function makeRig(model: Model, id: string): BoatRig?
	local root = model.PrimaryPart
	local clips = ENGINE_CLIPS[id]
	local spec = VehicleConfig.get(id)
	if not (root and clips and spec) then
		return nil
	end
	local low = AudioController.newSound(clips.low, root, true)
	local high = AudioController.newSound(clips.high, root, true)
	for _, s in { low, high } do
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = MIX.engineRange
	end
	local r: BoatRig = {
		model = model,
		low = low,
		high = high,
		lowBase = baseVolume(clips.low),
		highBase = baseVolume(clips.high),
		rpm = AudioMix.IDLE_RPM,
		topSpeed = spec.topSpeed,
		lastSlam = 0,
	}
	rigs[model] = r
	model.Destroying:Once(function()
		destroyRig(model)
	end)
	return r
end

local function hullBed(name: string, parent: Instance): Bed
	local s = AudioController.newSound(name, parent, true)
	s.RollOffMaxDistance = 120
	return { sound = s, base = baseVolume(name), level = 0 }
end

local function scanBoats(camPos: Vector3)
	local folder = Workspace:FindFirstChild("Vehicles")
	local seen: { [Model]: boolean } = {}
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart then
				local id = m:GetAttribute("VehicleId")
				local near = (m.PrimaryPart.Position - camPos).Magnitude < MIX.engineRange + 40
				if type(id) == "string" and ENGINE_CLIPS[id] and near then
					seen[m] = true
					if not rigs[m] then
						makeRig(m, id)
					end
				end
			end
		end
	end
	for m in rigs do
		if not seen[m] then
			destroyRig(m)
		end
	end
end

local function playLayer(s: Sound, volume: number, pitch: number)
	s.Volume = volume
	s.PlaybackSpeed = pitch
	if volume > 0.003 and not s.IsPlaying then
		s.TimePosition = rng:NextNumber(0, 8)
		s:Play()
	elseif volume <= 0.003 and s.IsPlaying then
		s:Stop()
	end
end

local function updateBoats(dt: number, now: number)
	local driven: Model? = if BoatController then BoatController.GetDrivenVehicle() else nil
	for model, r in rigs do
		local root = model.PrimaryPart
		if not root then
			continue
		end
		local vel = root.AssemblyLinearVelocity
		local forward = vel:Dot(root.CFrame.LookVector)
		local speedFrac = forward / math.max(r.topSpeed, 1)
		local throttle, contact = 0, 1
		local tel: any = nil
		if model == driven and BoatController then
			tel = BoatController.GetTelemetry()
			local t = if BoatController.GetThrottle then BoatController.GetThrottle() else nil
			throttle = if type(t) == "number" then t else 0
			if tel then
				speedFrac = tel.speed / math.max(r.topSpeed, 1)
				contact = tel.contact
			end
		else
			-- someone else's boat: infer the throttle from the hull speed (no input replicates)
			throttle = math.clamp(math.abs(speedFrac) * 1.15, 0, 1)
			local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
			if seat and not (seat :: VehicleSeat).Occupant then
				throttle = 0 -- nobody at the helm: idling or drifting
			end
		end
		local target = AudioMix.boatTargetRpm(throttle, speedFrac, contact)
		r.rpm = AudioMix.followRpm(r.rpm, target, dt)
		local l = AudioMix.engineLayers(r.rpm, throttle)
		playLayer(r.low, r.lowBase * l.low, l.lowPitch)
		playLayer(r.high, r.highBase * l.high, l.highPitch)

		if model == driven then
			if not r.lap then
				r.lap = hullBed("Hull_Lap", root)
				r.wash = hullBed("Hull_BowWash", root)
				r.wake = hullBed("Hull_Wake", root)
			end
			local planing = if tel then tel.planing else 0
			local lap, wash, wake = AudioMix.hullWater(speedFrac, planing)
			local storm = math.clamp(Weather.getIntensity(), 0, 1)
			setBed(r.lap :: Bed, lap * (0.6 + 0.4 * storm) * contact, dt)
			setBed(r.wash :: Bed, wash * contact, dt)
			setBed(r.wake :: Bed, wake * contact, dt, 5)
			local slam = if tel then tel.slam else 0
			if now - r.lastSlam > MIX.slamCooldown then
				local vol, pitch = AudioMix.slam(slam, MIX.slamMin)
				if vol then
					r.lastSlam = now
					local at = root.Position
					AudioController.play(
						if vol > 0.7 then "Hull_Slam" else "Hull_Slap",
						at,
						vol,
						pitch
					)
					if vol > 0.6 then
						AudioController.play(
							"Hull_SprayHiss",
							at,
							vol * 0.8,
							rng:NextNumber(0.9, 1.1)
						)
					end
				end
			end
		elseif r.lap then
			for _, b in { r.lap :: Bed, r.wash :: Bed, r.wake :: Bed } do
				b.sound:Destroy()
			end
			r.lap, r.wash, r.wake = nil, nil, nil
		end
	end
end

---------------------------------------------------------------- ambience

local lastCam: Vector3? = nil
local apparent = 0 -- smoothed listener speed, studs/s
local underwater = false
local nextGull = 0
local nextBell = 0
local riggingCarry = 0

local function setUnderwater(on: boolean)
	if on == underwater then
		return
	end
	underwater = on
	for _, eq in muffles do
		eq.Enabled = on
	end
end

local function randomAround(centre: Vector3, minR: number, maxR: number, height: number): Vector3
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(minR, maxR)
	return centre + Vector3.new(math.cos(a) * d, height, math.sin(a) * d)
end

local function updateAmbience(dt: number, now: number, camPos: Vector3)
	local held = Lighting:GetAttribute("LocalStormIntensity")
	local intensity =
		math.clamp(if type(held) == "number" then held else Weather.getIntensity(), 0, 1)
	local surface = Weather.heightAt(camPos)
	local above = camPos.Y - surface
	setUnderwater(above < -0.3)

	if lastCam and dt > 0 then
		local v = (camPos - lastCam).Magnitude / dt
		if v < 200 then -- ignore teleports
			apparent += (v - apparent) * (1 - math.exp(-2 * dt))
		end
	end
	lastCam = camPos

	-- wind (muffled to a rumble underwater by the EQ; quieter there)
	local w = AudioMix.wind(intensity, apparent)
	local wet = if underwater then 0.25 else 1
	setBed(beds.Wind_Light, w.light * wet, dt, 1.5)
	setBed(beds.Wind_Strong, w.strong * wet, dt, 1.5)
	setBed(beds.Wind_Gale, w.gale * wet, dt, 1.5)

	-- sea
	local zone: any = Weather.getZoneAt(camPos)
	local shelter = if zone and type(zone.shelter) == "number" then zone.shelter else 0
	local harbourDist = (Vector3.new(camPos.X, 0, camPos.Z) - Vector3.new(
		AudioConfig.HarbourCentre.X,
		0,
		AudioConfig.HarbourCentre.Z
	)).Magnitude
	if harbourDist < AudioConfig.HarbourRadius then
		shelter = math.max(shelter, 0.8)
	end
	local near = AudioMix.nearness(above, MIX.seaNearHeight)
	local sea = AudioMix.sea(intensity, shelter, if underwater then 0 else near)
	setBed(beds.Wave_Harbour, sea.harbour, dt, 1)
	setBed(beds.Wave_OpenSwell, sea.open, dt, 1)
	setBed(beds.Wave_Storm, sea.storm, dt, 1)
	setBed(beds.Rain_OnWater, if underwater then 0 else intensity * near, dt, 1)
	setBed(beds.Under_Ambience, if underwater then 1 else 0, dt, 6)

	-- marina bed (3D at the harbour centre) and halyards on masts, more with the wind
	local inHarbour = harbourDist < AudioConfig.HarbourRadius + 150
	setBed(beds.Amb_Harbour, if inHarbour and not underwater then 1 - 0.6 * intensity else 0, dt, 1)
	if inHarbour and not underwater then
		riggingCarry += dt * MIX.riggingRate * math.clamp(
			0.25 + w.light * 0.3 + w.strong * 0.7 + w.gale,
			0,
			1.5
		)
		while riggingCarry >= 1 do
			riggingCarry -= 1
			local at = randomAround(AudioConfig.HarbourCentre, 15, 140, 8)
			local pick = rng:NextInteger(1, 4)
			local clip = if pick == 4 then "Rigging_Creak" else `Rigging_Clink_{pick}`
			AudioController.play(clip, at, rng:NextNumber(0.6, 1), rng:NextNumber(0.85, 1.15))
		end
	end

	-- bell buoy, rocked by the swell
	if now >= nextBell then
		nextBell = now
			+ AudioMix.bellGap(intensity, MIX.bellMinGap, MIX.bellMaxGap, rng:NextNumber())
		if (AudioConfig.BellBuoy - camPos).Magnitude < 900 then
			local s = AudioController.play(
				"Bell_Buoy",
				AudioConfig.BellBuoy,
				rng:NextNumber(0.7, 1),
				rng:NextNumber(0.96, 1.03)
			)
			if s then
				s.RollOffMinDistance = 40
				s.RollOffMaxDistance = 900
			end
		end
	end

	-- gulls along the coast, hushed by a storm
	if now >= nextGull then
		nextGull = now + AudioMix.gap(MIX.gullMinGap, MIX.gullMaxGap, rng:NextNumber())
		local coastal = harbourDist < AudioConfig.CoastRadius and above < 120
		if coastal and not underwater and rng:NextNumber() < AudioMix.gullChance(intensity) then
			local at = randomAround(camPos, 25, 90, rng:NextNumber(12, 35))
			local clip = if rng:NextNumber() < 0.2
				then "Gull_Flock"
				else `Gull_Call_{rng:NextInteger(1, 2)}`
			AudioController.play(clip, at, rng:NextNumber(0.6, 1), rng:NextNumber(0.92, 1.08))
		end
	end
end

---------------------------------------------------------------- music

local OpsController: any = nil
local music: { [string]: Bed } = {}
local musicCue: string? = nil
local debriefUntil = 0

local function updateMusic(dt: number, now: number)
	local want: string? = nil
	if now < debriefUntil then
		want = "Music_Debrief"
	elseif OpsController and OpsController.GetState() ~= nil then
		want = "Music_Operation"
	end
	musicCue = want
	local rate = 1 / math.max(MIX.musicFade, 0.1) * 2
	for name, b in music do
		setBed(b, if name == musicCue then 1 else 0, dt, rate)
	end
end

---------------------------------------------------------------- UI clicks

local hooked: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local bounceSerial: { [GuiButton]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastClick = 0

-- A small scale dip on press, so every button answers the hand as well as the ear.
local function pressBounce(b: GuiButton)
	local scale = b:FindFirstChildOfClass("UIScale")
	if not scale then
		local made = Instance.new("UIScale")
		made.Parent = b
		scale = made
	end
	local s = scale :: UIScale
	local stored = b:GetAttribute("PressScale")
	local base: number = if typeof(stored) == "number" then stored else s.Scale
	if typeof(stored) ~= "number" then
		b:SetAttribute("PressScale", base)
	end
	bounceSerial[b] = (bounceSerial[b] or 0) + 1
	local serial = bounceSerial[b]
	TweenService:Create(s, TweenInfo.new(0.06), { Scale = base * 0.9 }):Play()
	task.delay(0.07, function()
		if bounceSerial[b] == serial and s.Parent then
			TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = base })
				:Play()
		end
	end)
end

local function hookButton(b: Instance)
	if not b:IsA("GuiButton") or hooked[b] then
		return
	end
	hooked[b] = true
	b.Activated:Connect(function()
		pressBounce(b)
		local t = os.clock()
		if t - lastClick < 0.05 then
			return
		end
		lastClick = t
		local back = string.find(string.lower(b.Name), "close") ~= nil
			or string.find(string.lower(b.Name), "back") ~= nil
		AudioController.play(
			if back then "UI_Back" else "UI_Click",
			nil,
			1,
			rng:NextNumber(0.97, 1.03)
		)
	end)
end

--- UI ticks: world prompts, awards, completed steps and the debrief (the button clicks are above).
local lastResultOp: string? = nil
local lastResults = 0

local function hookTicks()
	ProximityPromptService.PromptTriggered:Connect(function()
		AudioController.play("UI_Prompt", nil, 1, rng:NextNumber(0.97, 1.05))
	end)
	task.spawn(function()
		local net = ReplicatedStorage:WaitForChild("Net", 30)
		local ev = net and net:WaitForChild("PlayerDataChanged", 30)
		if ev and ev:IsA("RemoteEvent") then
			ev.OnClientEvent:Connect(function(data: any)
				if type(data) == "table" and type(data.award) == "table" then
					AudioController.play("UI_Pickup", nil, 1, rng:NextNumber(0.98, 1.06))
				end
			end)
		end
	end)
end

--------------------------------------------------------------- lifecycle

function AudioController.Init()
	ensureGroups()
	for _, name in
		{
			"Wind_Light",
			"Wind_Strong",
			"Wind_Gale",
			"Wave_Harbour",
			"Wave_OpenSwell",
			"Wave_Storm",
			"Rain_OnWater",
			"Under_Ambience",
		}
	do
		bed(name)
	end
	local harbour = emitterAt(AudioConfig.HarbourCentre)
	harbour.Name = "HarbourBed"
	local hb = bed("Amb_Harbour", harbour)
	hb.sound.RollOffMinDistance = 60
	hb.sound.RollOffMaxDistance = AudioConfig.HarbourRadius + 150
	for _, name in { "Music_Operation", "Music_Debrief" } do
		local b: Bed = {
			sound = AudioController.newSound(name, SoundService, true),
			base = baseVolume(name),
			level = 0,
			fromStart = true,
		}
		music[name] = b
	end
	music.Music_Debrief.sound.Looped = false

	-- settings binding through player attributes, for code that prefers them
	for _, cat in AudioConfig.Categories do
		local attr = `Volume_{cat}`
		local function apply()
			local v = player:GetAttribute(attr)
			if type(v) == "number" then
				AudioController.setVolume(cat, v)
			end
		end
		apply()
		player:GetAttributeChangedSignal(attr):Connect(apply)
	end
end

function AudioController.Start()
	local controllers = script.Parent
	local function sibling(name: string): any
		local m = controllers:FindFirstChild(name)
		if not (m and m:IsA("ModuleScript")) then
			return nil
		end
		local ok, mod = pcall(require :: any, m)
		return if ok then mod else nil
	end
	BoatController = sibling("BoatController")
	OpsController = sibling("OpsController")
	hookTicks()
	if OpsController and OpsController.OnState then
		OpsController.OnState:Connect(function(s: any)
			local n = if type(s.results) == "table" then #s.results else 0
			if s.opId ~= lastResultOp then
				lastResultOp, lastResults = s.opId, n
			elseif n > lastResults then
				AudioController.play("UI_Step")
			end
			lastResults = n
		end)
	end
	if OpsController and OpsController.OnDebrief then
		OpsController.OnDebrief:Connect(function(d: any)
			debriefUntil = os.clock() + 70
			local b = music.Music_Debrief
			if b then
				b.sound.TimePosition = 0
			end
			AudioController.play(if d and d.grade == "Fail" then "UI_Fail" else "UI_Success")
		end)
	end

	local gui = player:WaitForChild("PlayerGui")
	for _, d in gui:GetDescendants() do
		hookButton(d)
	end
	gui.DescendantAdded:Connect(hookButton)

	local acc = 0
	local scanAcc = 1
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		scanAcc += dt
		if scanAcc >= 0.5 then
			scanAcc = 0
			scanBoats(camPos)
		end
		updateBoats(dt, now)
		acc += dt
		if acc >= 1 / BED_HZ then
			local step = acc
			acc = 0
			updateAmbience(step, now, camPos)
			updateMusic(step, now)
		end
	end)
end

return AudioController
