--!strict
-- StationRig: the H1/H2 lifeboat station's night lights (art/source/buildings/M_Bld_Station/build.py, H2):
-- the swan-neck door lamp (ATT_Lamp_Door, a warm PointLight), the two gable floodlights (ATT_Lamp_Flood_01 / _02,
-- SpotLights aimed down onto the quay, towards the sea), the H3 eaves wash lights (ATT_Lamp_Wash_01..04, SpotLights
-- down the side walls), the H3 sign light (ATT_Lamp_Sign, aimed at ATT_Sign) and the GlassLit mesh (watch-room panes, door lamp and
-- flood lenses) as warm Neon, plus the hall's lifeboat on its trailer (a static display at ATT_BoatHall).
-- The lights are on only at night or in a storm (ChandleryRig.preset(): "Night" when
-- the sun is below the horizon or WeatherBase is Night, "Storm" while Shared.Weather says so), off by day.
-- Re-evaluated on Weather.changed, Lighting WeatherBase and Lighting.ClockTime changes; no per-frame loop.
--
-- Input: the M_Bld_Station clone from Server.Assets.AssetLoader (ATT_* markers are Attachments on its
-- PrimaryPart). New light Attachments go on the PrimaryPart, so apply() works before or after the caller
-- anchors and positions the model (moved rigidly, yaw only).
--
--   StationRig.apply(shell) -> cleanup()
--   StationRig.check(shell) -> { lights, lightsOn, glowParts, glowOn }   smoke-report counts

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local ChandleryRig = require(script.Parent:WaitForChild("ChandleryRig"))
local Weather = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"))

local StationRig = {}

local RIG_ATTR = "StationRig" -- on every Instance this module creates
local WARM_2700K = Color3.fromRGB(255, 177, 110)
local FLOOD_3500K = Color3.fromRGB(255, 214, 170)
local GLOW_ON = Color3.fromRGB(255, 190, 122)
local GLOW_OFF = Color3.fromRGB(58, 66, 72) -- dark glass by day

local DOOR_LAMP = { brightness = 1.2, range = 16, drop = 0.4 }
local FLOOD = { brightness = 2.2, range = 48, angle = 75, tilt = 55 } -- tilt: degrees below the horizontal
local WASH = { brightness = 0.9, range = 30, angle = 80, out = 0.3 } -- out: outward lean of the beam off the wall
local SIGN = { brightness = 1.4, range = 14, angle = 60 }
-- hall lifeboat on M_Veh_BoatTrailer_RIB (studs, trailer frame): keel on ATT_Cradle's bed height, bow at ATT_BowEye
local HALL_BOAT = { cradleY = 2.905, bowZ = 6.2, shift = 2.5 }

local active: { [Model]: () -> () } = {}

local function isOn(): boolean
	local preset = ChandleryRig.preset()
	return preset == "Night" or preset == "Storm"
end

local function isGlow(name: string): boolean
	return string.find(name, "_GlassLit_LOD", 1, true) ~= nil
end

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

local function marker(shell: Model, name: string): Attachment?
	local a = shell:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a else nil
end

function StationRig.apply(shell: Model): () -> ()
	local previous = active[shell]
	if previous then
		previous()
	end
	local created: { Instance } = {}
	local connections: { RBXScriptConnection } = {}
	local lights: { Light } = {}
	local glow: { BasePart } = {}

	for _, d in shell:GetDescendants() do
		if d:IsA("BasePart") and isGlow(d.Name) then
			plain(d)
			d.CastShadow = false
			table.insert(glow, d)
		end
	end

	local host = shell.PrimaryPart
	local pivot = shell:GetPivot()
	local seaward = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z).Unit -- the front faces the pivot's look
	local function light(name: string, at: Vector3, look: Vector3, l: Light)
		if not host then
			return
		end
		local a = Instance.new("Attachment")
		a.Name = name
		a:SetAttribute(RIG_ATTR, true)
		a.Parent = host
		a.WorldCFrame = CFrame.lookAt(at, at + look)
		l:SetAttribute(RIG_ATTR, true)
		l.Parent = a
		table.insert(created, a)
		table.insert(lights, l)
	end

	local door = marker(shell, "ATT_Lamp_Door")
	if door then
		local pl = Instance.new("PointLight")
		pl.Color = WARM_2700K
		pl.Brightness = DOOR_LAMP.brightness
		pl.Range = DOOR_LAMP.range
		pl.Shadows = true
		light("Rig_Lamp_Door", door.WorldPosition - Vector3.yAxis * DOOR_LAMP.drop, seaward, pl)
	end
	local tilt = math.rad(FLOOD.tilt)
	local aim = seaward * math.cos(tilt) - Vector3.yAxis * math.sin(tilt)
	for i = 1, 2 do
		local f = marker(shell, string.format("ATT_Lamp_Flood_%02d", i))
		if f then
			local sl = Instance.new("SpotLight")
			sl.Color = FLOOD_3500K
			sl.Brightness = FLOOD.brightness
			sl.Range = FLOOD.range
			sl.Angle = FLOOD.angle
			sl.Face = Enum.NormalId.Front
			sl.Shadows = true
			light(string.format("Rig_Lamp_Flood_%02d", i), f.WorldPosition, aim, sl)
		end
	end
	-- H3 eaves wash lights (ATT_Lamp_Wash_01..04, on the long side walls): beams straight down the wall,
	-- leaning a little out from it
	for i = 1, 4 do
		local w = marker(shell, string.format("ATT_Lamp_Wash_%02d", i))
		if w then
			local lx = pivot:PointToObjectSpace(w.WorldPosition).X
			local out = pivot:VectorToWorldSpace(Vector3.new(if lx < 0 then -1 else 1, 0, 0))
			local sl = Instance.new("SpotLight")
			sl.Color = WARM_2700K
			sl.Brightness = WASH.brightness
			sl.Range = WASH.range
			sl.Angle = WASH.angle
			sl.Face = Enum.NormalId.Front
			sl.Shadows = true
			light(
				string.format("Rig_Lamp_Wash_%02d", i),
				w.WorldPosition,
				out * WASH.out - Vector3.yAxis,
				sl
			)
		end
	end
	-- H3 sign light above the name board (ATT_Lamp_Sign), aimed at the board centre (ATT_Sign)
	local signLamp, board = marker(shell, "ATT_Lamp_Sign"), marker(shell, "ATT_Sign")
	if signLamp then
		local sl = Instance.new("SpotLight")
		sl.Color = WARM_2700K
		sl.Brightness = SIGN.brightness
		sl.Range = SIGN.range
		sl.Angle = SIGN.angle
		sl.Face = Enum.NormalId.Front
		sl.Shadows = false
		local target = if board
			then board.WorldPosition
			else signLamp.WorldPosition + seaward - Vector3.yAxis * 2
		light("Rig_Lamp_Sign", signLamp.WorldPosition, target - signLamp.WorldPosition, sl)
	end
	if not host then
		warn("[StationRig] no PrimaryPart on", shell:GetFullName(), "- lights skipped")
	end
	local done = false
	-- the station's lifeboat on its launch trailer in the boat hall, bow to the roller bay door: the hall reads
	-- as the boathouse (static display, collides; launches still go from the BoatDesk and the slipway)
	local hall = marker(shell, "ATT_BoatHall")
	if hall then
		task.spawn(function()
			local trailer = AssetLoader.cloneStatic("M_Veh_BoatTrailer_RIB", "LOD0")
			local boat = AssetLoader.cloneStatic("M_Veh_RIB", "LOD0")
			if done or not (trailer and boat) or not shell.Parent then
				if trailer then
					trailer:Destroy()
				end
				if boat then
					boat:Destroy()
				end
				return
			end
			-- coupler (-Z) to the door; the 26-stud hull overhangs the stern, so the pair moves 2.5 studs forward to centre
			local at = CFrame.lookAt(hall.WorldPosition, hall.WorldPosition + seaward)
				* CFrame.new(0, 0, -HALL_BOAT.shift)
			trailer:PivotTo(at)
			boat:PivotTo(at * CFrame.new(0, HALL_BOAT.cradleY, HALL_BOAT.bowZ))
			for _, m in { trailer, boat } do
				m.Name = "Hall" .. m.Name
				m:SetAttribute(RIG_ATTR, true)
				m.Parent = shell.Parent
				table.insert(created, m)
			end
		end)
	end

	local state: boolean? = nil
	local function refresh()
		local on = isOn()
		if on == state then
			return
		end
		state = on
		for _, l in lights do
			l.Enabled = on
		end
		for _, p in glow do
			p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			p.Color = if on then GLOW_ON else GLOW_OFF
			p.Reflectance = if on then 0 else 0.15
		end
	end
	refresh()
	table.insert(connections, Weather.changed:Connect(refresh))
	table.insert(connections, Lighting:GetAttributeChangedSignal("WeatherBase"):Connect(refresh))
	table.insert(connections, Lighting:GetPropertyChangedSignal("ClockTime"):Connect(refresh))
	table.insert(
		connections,
		Lighting:GetPropertyChangedSignal("GeographicLatitude"):Connect(refresh)
	)

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

function StationRig.check(shell: Model): { [string]: number }
	local out = { lights = 0, lightsOn = 0, glowParts = 0, glowOn = 0 }
	for _, d in shell:GetDescendants() do
		if d:IsA("Light") and d:GetAttribute(RIG_ATTR) then
			out.lights += 1
			if d.Enabled then
				out.lightsOn += 1
			end
		elseif d:IsA("BasePart") and isGlow(d.Name) then
			out.glowParts += 1
			if d.Material == Enum.Material.Neon then
				out.glowOn += 1
			end
		end
	end
	return out
end

return StationRig
