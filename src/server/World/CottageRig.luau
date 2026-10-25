--!strict
-- CottageRig: the H3 cottages' (M_Bld_Cottage_01..06, placed on the islands: Penwyn, Gannet Rock) glass, night
-- lights and chimney smoke:
--   * Glass (M_Bld_Cottage_Glass_NN_LODk): Material Glass, Transparency 0.35, so the room backplate behind shows;
--   * GlassLit (M_Bld_Cottage_GlassLit_NN_LODk: lit panes + lantern cores): Transparency 1 by day, warm Neon at
--     night or in a storm;
--   * warm PointLights (no shadows: cheap) at the door lanterns (ATT_Lamp_Door_NN) and in the lit rooms
--     (ATT_Lamp_Window_NN), on with the glow;
--   * a subtle smoke ParticleEmitter per chimney stack (the first ATT_Smoke_NN pot of each stack) in cold
--     weather (anything but a clear day) or a storm, drifting with the wind.
-- Shell attributes RigLights / RigSmoke = false skip the PointLights / the smoke (Penwyn sets them on most terraces).
-- Rules in CottageLights (pure). Re-evaluated on Weather.changed, Lighting WeatherBase, ClockTime and
-- GeographicLatitude changes; no per-frame loop. New attachments go on the PrimaryPart (world-aligned), so apply()
-- works before or after the caller positions the model.
--
--   CottageRig.apply(shell) -> cleanup()
--   CottageRig.check(shell) -> { lights, lightsOn, glowParts, glowOn, glassParts, smoke, smokeOn }   smoke-report counts

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CottageLights = require(script.Parent:WaitForChild("CottageLights"))
local SharedSetsRig = require(script.Parent:WaitForChild("SharedSetsRig"))
local StationRig = require(script.Parent:WaitForChild("StationRig"))
local Weather = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"))

local CottageRig = {}

local RIG_ATTR = "CottageRig" -- on every Instance this module creates
local WARM_2700K = Color3.fromRGB(255, 177, 110)
local ROOM_2400K = Color3.fromRGB(255, 160, 92)
-- lit rooms: a soft warm off-white interior glow, not a saturated lamp (Neon bloom pushed the old amber to yellow);
-- a little see-through so the dark glass behind dims it
local GLOW_ON, GLOW_TRANSPARENCY = Color3.fromRGB(178, 150, 116), 0.25
local GLASS_COLOR = Color3.fromRGB(64, 76, 84)
local GLASS_TRANSPARENCY, GLASS_REFLECTANCE = 0.35, 0.15

local DOOR_LAMP = { brightness = 1.1, range = 14, drop = 0.3, out = 0.4 } -- studs below / in front of the core
local ROOM = { brightness = 0.6, range = 10 }
local SMOKE = { rate = 1.5, wind = 1.6, lift = 0.4 }
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local active: { [Model]: () -> () } = {}

-- strips the PBR look (and the wet swap) so Material / Color show
local function plain(p: BasePart)
	for _, c in p:GetChildren() do
		if
			c:IsA("SurfaceAppearance") or (c:IsA("Configuration") and c.Name == "SurfaceVariants")
		then
			c:Destroy()
		end
	end
	CollectionService:RemoveTag(p, "HasWetVariant")
end

-- the asset's ATT_ markers with this prefix, in name order
local function markers(shell: Model, prefix: string): { Attachment }
	local out: { Attachment } = {}
	for _, d in shell:GetDescendants() do
		if d:IsA("Attachment") and string.sub(d.Name, 1, #prefix) == prefix then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

local function smokeEmitter(): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "ChimneySmoke"
	e.Texture = SMOKE_TEXTURE
	e.Rate = SMOKE.rate
	e.Lifetime = NumberRange.new(6, 9)
	e.Speed = NumberRange.new(1.5, 2.5)
	e.SpreadAngle = Vector2.new(8, 8)
	e.EmissionDirection = Enum.NormalId.Top
	e.Drag = 0.6
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 6),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(0.2, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(178, 175, 170))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Enabled = false
	return e
end

function CottageRig.apply(shell: Model): () -> ()
	local previous = active[shell]
	if previous then
		previous()
	end
	local render = shell:GetAttribute("Render") -- Town: the lot's wall colour; nil = the variant's own
	SharedSetsRig.cottage(shell, if type(render) == "string" then render else nil)
	local created: { Instance } = {}
	local connections: { RBXScriptConnection } = {}
	local lights: { Light } = {}
	local glow: { BasePart } = {}
	local smoke: { ParticleEmitter } = {}

	for _, d in shell:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = CottageLights.kind(d.Name)
			if kind == "glow" then
				plain(d)
				d.CastShadow = false
				d.Reflectance = 0
				table.insert(glow, d)
			elseif kind == "glass" then
				plain(d)
				d.Material = Enum.Material.Glass
				d.Color = GLASS_COLOR
				d.Transparency = GLASS_TRANSPARENCY
				d.Reflectance = GLASS_REFLECTANCE
				d.CastShadow = false
			end
		end
	end

	local host = shell.PrimaryPart
	local pivot = shell:GetPivot()
	local front = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z).Unit -- the asset's front (-Z) faces the look
	local function point(name: string, at: Vector3): Attachment?
		if not host then
			return nil
		end
		local a = Instance.new("Attachment")
		a.Name = name
		a:SetAttribute(RIG_ATTR, true)
		a.Parent = host
		a.WorldCFrame = CFrame.new(at) -- world-aligned: the emitter's Top is up
		table.insert(created, a)
		return a
	end
	local function light(
		name: string,
		at: Vector3,
		color: Color3,
		brightness: number,
		range: number
	)
		local a = point(name, at)
		if not a then
			return
		end
		if shell:GetAttribute("RigLights") == false then
			return -- Town: only a subset of the terraces carry real lights (the Neon panes still glow)
		end
		local pl = Instance.new("PointLight")
		pl.Color = color
		pl.Brightness = brightness
		pl.Range = range
		pl.Shadows = false
		pl:SetAttribute(RIG_ATTR, true)
		pl.Parent = a
		table.insert(lights, pl)
	end

	for _, m in markers(shell, "ATT_Lamp_Door") do
		local at = m.WorldPosition - Vector3.yAxis * DOOR_LAMP.drop + front * DOOR_LAMP.out
		light(`Rig_{m.Name}`, at, WARM_2700K, DOOR_LAMP.brightness, DOOR_LAMP.range)
	end
	for _, m in markers(shell, "ATT_Lamp_Window") do
		light(`Rig_{m.Name}`, m.WorldPosition, ROOM_2400K, ROOM.brightness, ROOM.range)
	end
	local pots = markers(shell, "ATT_Smoke")
	local positions: { Vector3 } = {}
	for _, m in pots do
		table.insert(positions, m.WorldPosition)
	end
	-- the H3 stacks are part of the Walls mesh and render white: a granite sleeve over each, under its pots
	-- (pots stand 0.55 to 0.9 m on the cap: the sleeve tops out about 2.2 studs under the lowest pot top)
	local meshed = shell:FindFirstChildWhichIsA("MeshPart", true) ~= nil -- not the code-built terraces' stacks
	local sleeves: { number } = if meshed then CottageLights.stacks(positions) else {}
	for _, i in sleeves do
		local sum, count, low = Vector3.zero, 0, math.huge
		for _, p in positions do
			if (p - positions[i]).Magnitude < 2.5 then
				sum += p
				count += 1
				low = math.min(low, p.Y)
			end
		end
		local c = sum / count
		local sleeve = Instance.new("Part")
		sleeve.Name = "Rig_StackSleeve"
		sleeve.Anchored = true
		sleeve.CanCollide, sleeve.CanTouch, sleeve.CanQuery = false, false, false
		sleeve.Size = Vector3.new(3.3, 4.8, 2.8)
		sleeve.CFrame = CFrame.new(c.X, low - 2.2 - 2.4, c.Z) * pivot.Rotation
		sleeve.Material = Enum.Material.Granite
		sleeve.Color = Color3.fromRGB(150, 146, 138)
		sleeve:SetAttribute(RIG_ATTR, true)
		sleeve.Parent = shell
		table.insert(created, sleeve)
	end
	local stacks: { number } = if shell:GetAttribute("RigSmoke") == false
		then {}
		else CottageLights.stacks(positions)
	for _, i in stacks do
		local a = point(`Rig_{pots[i].Name}`, positions[i])
		if a then
			local e = smokeEmitter()
			e:SetAttribute(RIG_ATTR, true)
			e.Parent = a
			table.insert(smoke, e)
		end
	end
	if not host then
		warn("[CottageRig] no PrimaryPart on", shell:GetFullName(), "- lights and smoke skipped")
	end

	local lit: boolean? = nil
	local smoking: boolean? = nil
	local function refresh()
		local preset = StationRig.preset()
		local on = CottageLights.lightsOn(preset)
		if on ~= lit then
			lit = on
			for _, l in lights do
				l.Enabled = on
			end
			for _, p in glow do
				p.Transparency = if on then GLOW_TRANSPARENCY else 1
				p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
				local own = p:GetAttribute("Glow")
				p.Color = if typeof(own) == "Color3" then own else GLOW_ON -- big panes (shop windows) carry a dimmer one
			end
		end
		local puff = CottageLights.smokeOn(preset, Weather.getState())
		local wind = Weather.getWindDirection()
		local drift = Vector3.new(math.cos(wind), 0, math.sin(wind)) * SMOKE.wind
			+ Vector3.yAxis * SMOKE.lift
		for _, e in smoke do
			e.Acceleration = drift
			if puff ~= smoking then
				e.Enabled = puff
			end
		end
		smoking = puff
	end
	refresh()
	table.insert(connections, Weather.changed:Connect(refresh))
	table.insert(connections, Lighting:GetAttributeChangedSignal("WeatherBase"):Connect(refresh))
	table.insert(connections, Lighting:GetPropertyChangedSignal("ClockTime"):Connect(refresh))
	table.insert(
		connections,
		Lighting:GetPropertyChangedSignal("GeographicLatitude"):Connect(refresh)
	)

	local done = false
	local function cleanup()
		if done then
			return
		end
		done = true
		if active[shell] == cleanup then
			active[shell] = nil
		end
		for _, c in connections do
			c:Disconnect()
		end
		for _, inst in created do
			inst:Destroy()
		end
		table.clear(created)
	end
	table.insert(connections, shell.Destroying:Connect(cleanup))
	active[shell] = cleanup
	return cleanup
end

function CottageRig.check(shell: Model): { [string]: number }
	local out = {
		lights = 0,
		lightsOn = 0,
		glowParts = 0,
		glowOn = 0,
		glassParts = 0,
		smoke = 0,
		smokeOn = 0,
	}
	for _, d in shell:GetDescendants() do
		if d:IsA("Light") and d:GetAttribute(RIG_ATTR) then
			out.lights += 1
			if d.Enabled then
				out.lightsOn += 1
			end
		elseif d:IsA("ParticleEmitter") and d:GetAttribute(RIG_ATTR) then
			out.smoke += 1
			if d.Enabled then
				out.smokeOn += 1
			end
		elseif d:IsA("BasePart") then
			local kind = CottageLights.kind(d.Name)
			if kind == "glow" then
				out.glowParts += 1
				if d.Transparency < 1 and d.Material == Enum.Material.Neon then
					out.glowOn += 1
				end
			elseif kind == "glass" then
				out.glassParts += 1
			end
		end
	end
	return out
end

return CottageRig
