--!strict
-- FireScene (server): the burning motor cruiser of the Vessel Fire operation (docs/09 8.2,
-- docs/13 LU-3). The cruiser itself is RescueService's ordinary disabled-boat scene; this module
-- dresses it: fire and smoke on the stern, two people at the bow, the hull boundary markers the
-- fight mechanic cools. The fire grows while nobody fights it (shared/Ops/FireSpread) and feeds
-- the vessel's condition meter, so an ignored fire is a losing operation. Smoke follows the wind.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FireSpread = require(Shared:WaitForChild("Ops"):WaitForChild("FireSpread"))
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks"))
local Types = require(Shared:WaitForChild("Ops"):WaitForChild("Types"))

local FireScene = {}

export type Fire = {
	state: FireSpread.State,
	model: Model,
	base: Attachment,
	front: Attachment,
	boundary: { Attachment },
	flame: ParticleEmitter,
	frontFlame: ParticleEmitter,
	smoke: ParticleEmitter,
	light: PointLight,
	people: { BasePart },
	loop: RBXScriptConnection?,
	last: number,
	lastPaint: number,
}

local function wind(): number
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	local w = folder and folder:GetAttribute("WindDirection")
	return if type(w) == "number" then w else 0
end

local function key(t: number, v: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(t, v)
end

local function flame(parent: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	Flipbooks.apply(e, "FX_Flare_Head") -- emissive fire loop; stock fire sheet until uploaded
	e.Name = "FireFlames"
	e.Rate = 16
	e.Lifetime = NumberRange.new(0.6, 1.3)
	e.Speed = NumberRange.new(2, 4.5)
	e.SpreadAngle = Vector2.new(20, 20)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, 5, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-80, 80)
	e.Size = NumberSequence.new({ key(0, 4.5), key(1, 1.8) })
	e.Transparency = NumberSequence.new({ key(0, 0.1), key(1, 0.75) })
	e.Color = ColorSequence.new(Color3.fromRGB(255, 176, 70), Color3.fromRGB(255, 84, 18))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

local function smoke(parent: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	Flipbooks.apply(e, "FX_Smoke_Orange") -- the billowing smoke sheet, pushed dark
	e.Name = "FireSmoke"
	e.Rate = 10
	e.Lifetime = NumberRange.new(6, 10)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-18, 18)
	e.Size = NumberSequence.new({ key(0, 3), key(1, 15) })
	e.Transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(46, 46, 52), Color3.fromRGB(96, 96, 104))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Parent = parent
	return e
end

local function attachment(parent: BasePart, name: string, position: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	return a
end

local function person(f: any, model: Instance, offset: CFrame): { BasePart }
	local out: { BasePart } = {}
	local function box(name: string, size: Vector3, color: Color3, at: CFrame): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CFrame = f.cf * offset * at
		p.Parent = model
		table.insert(f.parts, p)
		table.insert(f.offsets, offset * at)
		table.insert(out, p)
		return p
	end
	box("Torso", Vector3.new(1.8, 1.8, 0.9), Color3.fromRGB(40, 70, 120), CFrame.new())
	box("Head", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(224, 180, 145), CFrame.new(0, 1.5, 0)).Shape =
		Enum.PartType.Ball
	box("LifeVest", Vector3.new(2.1, 1.4, 1.2), Color3.fromRGB(250, 200, 40), CFrame.new(0, 0.2, 0))
	return out
end

-- Offered: no rescue casualties in this scene (the two people are not in the water) and the
-- vessel's condition is the fire, not the drift clock.
function FireScene.Task(op: any)
	local scene = op.scene
	scene.pob = 0
	op.pob = 0
	op.radioLine = op.def.radioLine
	local c = scene.casualties and scene.casualties[1]
	if c then
		c.driftScale = 0
	end
end

function FireScene.Spawn(scene: any)
	local boat = scene.boat
	if not boat then
		return
	end
	local model: Model = boat.model
	local hull: BasePart = boat.hull
	local f = boat.floater

	model:SetAttribute("FireActive", true)
	model:SetAttribute("FirePeople", 2)
	CollectionService:AddTag(model, "VesselFire")

	-- the disabled boat's greybox smoke ball becomes the fire's base anchor, not a prop
	local ball = model:FindFirstChild("Smoke")
	if ball and ball:IsA("BasePart") then
		ball.Transparency = 1
		ball.CanQuery = false
	end

	local base = attachment(hull, "FireBase", Vector3.new(0, 1.4, 5.4))
	local front = attachment(hull, "FireFront", Vector3.new(0, 1.4, 2.6))
	local boundary = {
		attachment(hull, "FireBoundary_1", Vector3.new(3.1, 0.8, 5.2)),
		attachment(hull, "FireBoundary_2", Vector3.new(-3.1, 0.8, 5.2)),
		attachment(hull, "FireBoundary_3", Vector3.new(0, 1.8, 6.9)),
		attachment(hull, "FireBoundary_4", Vector3.new(0, 1.8, 3.2)),
	}

	local flameBase = flame(base)
	local flameFront = flame(front)
	flameFront.Rate = 0
	local smokeColumn = smoke(base)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 130, 50)
	light.Range = 34
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = base

	local people = {}
	for _, side in { -1, 1 } do
		for _, part in person(f, model, CFrame.new(side * 1.4, 2.6, -4.8)) do
			table.insert(people, part)
		end
	end

	local fire: Fire = {
		state = FireSpread.new(),
		model = model,
		base = base,
		front = front,
		boundary = boundary,
		flame = flameBase,
		frontFlame = flameFront,
		smoke = smokeColumn,
		light = light,
		people = people,
		loop = nil,
		last = os.clock(),
		lastPaint = 0,
	}
	scene.fire = fire
	FireScene.Apply(scene)
	fire.loop = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = math.min(now - fire.last, 0.5)
		fire.last = now
		FireSpread.tick(fire.state, dt)
		FireScene.Apply(scene)
	end)
end

-- Pushes the fire state into the emitters, the light, the smoke drift and the condition meter.
function FireScene.Apply(scene: any)
	local fire: Fire? = scene.fire
	if not fire then
		return
	end
	local clock = os.clock()
	if clock - fire.lastPaint < 0.2 then -- 5 Hz is plenty for particles and the light
		return
	end
	fire.lastPaint = clock
	local s = fire.state
	fire.flame.Rate = FireSpread.flameRate(s)
	fire.frontFlame.Rate = if s.spread > 0.45 and not s.doused
		then 6 + math.floor(s.spread * 14)
		else 0
	fire.smoke.Rate = FireSpread.smokeRate(s)
	fire.smoke.Acceleration = FireSpread.downwind(wind()) * (2.5 + 5 * s.spread)
		+ Vector3.new(0, 1.2, 0)
	fire.light.Brightness = if s.doused then 0 else 1.2 + s.heat * 2.4
	fire.light.Range = 24 + s.heat * 24
	local c = scene.casualties and scene.casualties[1]
	if c and not c.delivered and not c.takenOver then
		c.condition = math.clamp(100 - 70 * s.spread, 0, 100)
	end
	fire.model:SetAttribute("FireSpread", s.spread)
end

function FireScene.Level(scene: any): number
	local fire: Fire? = scene.fire
	return if fire then fire.state.spread else 1
end

-- The fire_fight step finished: water on the base (0..1) and hull boundary (0..1).
function FireScene.Extinguish(scene: any, metrics: Types.Metrics?)
	local fire: Fire? = scene.fire
	if not fire then
		return
	end
	local m: any = metrics or {}
	local base = if type(m.base) == "number" then m.base else 0.5
	local panels = if type(m.panels) == "number" then m.panels else 0.5
	FireSpread.douse(fire.state, base, panels)
	fire.lastPaint = 0
	FireScene.Apply(scene)
end

-- The crew_off step finished: the two people are aboard the lifeboat.
function FireScene.PeopleOff(scene: any)
	local fire: Fire? = scene.fire
	if not fire then
		return
	end
	for _, p in fire.people do
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
	end
	fire.model:SetAttribute("FirePeople", 0)
end

function FireScene.Cleanup(scene: any)
	local fire: Fire? = scene.fire
	if not fire then
		return
	end
	if fire.loop then
		fire.loop:Disconnect()
		fire.loop = nil
	end
	scene.fire = nil
	fire.model:SetAttribute("FireActive", false)
end

return FireScene
