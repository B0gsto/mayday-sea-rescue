--!strict
-- PyroController (FX2): draws distress pyrotechnics with the photoreal flipbooks, client-local.
-- Server or operation code asks for one by tagging an instance (CollectionService), so no remotes:
--   tag "HandFlare"       on a BasePart or Attachment: a red hand flare burns there (attribute
--                         FlareSeconds overrides the 60 s burn; removing the tag puts it out)
--   tag "ParachuteFlare"  on a BasePart: a red parachute rocket fires from its position once
-- API (client code): PyroController.handFlare(at, seconds?) -> stop(), PyroController.parachute(origin)
-- Signals are gameplay cues, so every quality tier draws them (Flipbooks.scale "signal" = 1);
-- the light flicker is slow and small (no rapid flashing).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fx = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fx")
local Flipbooks = require(Fx:WaitForChild("Flipbooks"))
local PyroMath = require(Fx:WaitForChild("PyroMath"))

local DISTRESS_RED = Color3.fromRGB(255, 48, 40) -- docs/05 3.2 Distress Red, as emitted light

local PyroController = {}
PyroController.Priority = 120

local seeds = 0

local function keys(pairs_: { { number } }): NumberSequence
	local k = {}
	for _, p in pairs_ do
		table.insert(k, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(k)
end

local function headEmitter(): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "FlareHead"
	Flipbooks.apply(e, "FX_Flare_Head")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 190)) -- strontium red, less pink
	e.Size = keys({ { 0, 0.9 }, { 1, 1.2 } })
	e.Transparency = keys({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(0.18, 0.3)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.Rate = 30
	e.LockedToPart = true
	e.ZOffset = 0.3
	return e
end

local function sparkEmitter(): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "FlareSparks"
	Flipbooks.apply(e, "FX_Flare_Sparks")
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = NumberSequence.new(1.6)
	e.Transparency = keys({ { 0, 0 }, { 1, 0.6 } })
	e.Lifetime = NumberRange.new(0.5, 0.7)
	e.Speed = NumberRange.new(0)
	e.Rate = 5
	e.ZOffset = 0.2
	return e
end

local function smokeEmitter(): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "FlareSmoke"
	Flipbooks.apply(e, "FX_Flare_Smoke")
	-- the smoke is lit by the flame from inside: a warm red cast near the head
	e.Color = ColorSequence.new(Color3.fromRGB(255, 196, 192), Color3.fromRGB(236, 232, 230))
	e.Size = keys({ { 0, 1.2 }, { 1, 7.5 } })
	e.Transparency = keys({ { 0, 0.15 }, { 0.6, 0.35 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(3.5, 5.5)
	e.Speed = NumberRange.new(2, 3.5)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(1.5, 0.8, 0)
	e.Rotation = NumberRange.new(-15, 15)
	e.Rate = 7
	return e
end

local function light(range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = DISTRESS_RED
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	return l
end

-- Burn a red hand flare at `at` (an Attachment, or a BasePart's centre). Returns stop().
function PyroController.handFlare(at: Instance, seconds: number?): () -> ()
	local attach: Attachment
	local own = false
	if at:IsA("Attachment") then
		attach = at
	else
		attach = Instance.new("Attachment")
		attach.Name = "HandFlareAt"
		attach.Parent = at
		own = true
	end
	seeds += 1
	local seed = seeds
	local head, sparks, smoke = headEmitter(), sparkEmitter(), smokeEmitter()
	local glow = light(PyroMath.HAND.lightRange, PyroMath.HAND.lightBrightness)
	for _, i in { head, sparks, smoke, glow } :: { Instance } do
		i.Parent = attach
	end
	local t0 = os.clock()
	local burn = seconds or PyroMath.HAND.seconds
	local conn: RBXScriptConnection
	local function stop()
		if conn then
			conn:Disconnect()
		end
		head.Enabled, sparks.Enabled, smoke.Enabled = false, false, false
		glow:Destroy()
		task.delay(6, function() -- let the last smoke drift off
			for _, i in { head, sparks, smoke } :: { Instance } do
				i:Destroy()
			end
			if own then
				attach:Destroy()
			end
		end)
	end
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > burn or not attach.Parent then
			stop()
			return
		end
		glow.Brightness = PyroMath.HAND.lightBrightness * PyroMath.flicker(t, seed)
	end)
	return stop
end

-- Fire a red parachute rocket from `origin`: smoke trail on the climb, then the star under its
-- canopy, glowing red over the sea while it drifts down.
function PyroController.parachute(origin: Vector3)
	seeds += 1
	local seed = seeds
	local star = Instance.new("Part")
	star.Name = "ParachuteFlare"
	star.Anchored, star.CanCollide, star.CanQuery, star.CanTouch = true, false, false, false
	star.Transparency = 1
	star.Size = Vector3.new(0.2, 0.2, 0.2)
	star.CFrame = CFrame.new(origin)
	local trail = smokeEmitter()
	trail.Rate = 40
	trail.Lifetime = NumberRange.new(4, 6)
	trail.Speed = NumberRange.new(0.3)
	trail.Size = keys({ { 0, 1.5 }, { 1, 6 } })
	trail.Parent = star
	local glowFx = Instance.new("ParticleEmitter")
	glowFx.Name = "ParachuteGlow"
	Flipbooks.apply(glowFx, "FX_Flare_Parachute")
	glowFx.Color = ColorSequence.new(Color3.new(1, 1, 1))
	glowFx.Size = NumberSequence.new(14)
	glowFx.Transparency = NumberSequence.new(0)
	glowFx.Lifetime = NumberRange.new(0.25)
	glowFx.Speed = NumberRange.new(0)
	glowFx.Rate = 12
	glowFx.LockedToPart = true
	glowFx.Enabled = false
	glowFx.Parent = star
	local glow = light(PyroMath.PARACHUTE.lightRange, PyroMath.PARACHUTE.lightBrightness)
	glow.Enabled = false
	glow.Parent = star
	star.Parent = Workspace.CurrentCamera or Workspace
	local t0 = os.clock()
	local total = PyroMath.parachuteSeconds()
	local drift = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		local h, burning = PyroMath.parachuteHeight(t)
		star.CFrame = CFrame.new(origin + Vector3.new(0, h, 0) + drift * math.max(t - 6, 0))
		trail.Enabled = t < PyroMath.PARACHUTE.climbSeconds
		glowFx.Enabled, glow.Enabled = burning, burning
		if burning then
			glow.Brightness = PyroMath.PARACHUTE.lightBrightness * PyroMath.flicker(t, seed)
		end
		if t > total then
			conn:Disconnect()
			glowFx.Enabled, glow.Enabled = false, false
			task.delay(6, function()
				star:Destroy()
			end)
		end
	end)
end

local burning: { [Instance]: () -> () } = {}

local function onHandTag(inst: Instance)
	if burning[inst] or not (inst:IsA("BasePart") or inst:IsA("Attachment")) then
		return
	end
	local s = inst:GetAttribute("FlareSeconds")
	burning[inst] = PyroController.handFlare(inst, if type(s) == "number" then s else nil)
end

local function offHandTag(inst: Instance)
	local stop = burning[inst]
	if stop then
		burning[inst] = nil
		stop()
	end
end

function PyroController.Init() end

function PyroController.Start()
	for _, inst in CollectionService:GetTagged("HandFlare") do
		onHandTag(inst)
	end
	CollectionService:GetInstanceAddedSignal("HandFlare"):Connect(onHandTag)
	CollectionService:GetInstanceRemovedSignal("HandFlare"):Connect(offHandTag)
	CollectionService:GetInstanceAddedSignal("ParachuteFlare"):Connect(function(inst: Instance)
		if inst:IsA("BasePart") then
			PyroController.parachute(inst.Position)
		end
	end)
end

return PyroController
