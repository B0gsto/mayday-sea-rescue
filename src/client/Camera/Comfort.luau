--!strict
-- Comfort: the player's camera comfort settings, persisted on the profile.
-- Loaded once from Progression_GetData (flags.cameraSettings) and saved through the
-- Camera_SaveSettings RemoteEvent (ProgressionService stores it with SetFlag; rate limited, so
-- saves are debounced here). Cinematics record "seen_<id>" in the same table.
--
--   Comfort.get(key) / Comfort.set(key, value) / Comfort.all()
--   Comfort.changed:Connect(fn(key, value))
--   Comfort.hasSeen(id) / Comfort.markSeen(id)
--   Comfort.load() (yields briefly; CameraController.Start calls it)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Settings = {
	horizonStab: number, -- 0 hull locked .. 1 horizon locked (vehicle first person)
	fov: number, -- base field of view, degrees
	headBob: number, -- 0 off .. 1 full (on foot)
	motionBlur: boolean, -- off by default
	shake: number, -- camera shake intensity 0..1
	speedFov: boolean, -- the FOV kick at speed
	gLean: number, -- 0..1 head lean in turns and under acceleration
	lensSpray: boolean, -- spray drops on the lens (jet ski)
	sensitivity: number, -- look sensitivity multiplier
}

local DEFAULTS: Settings = {
	horizonStab = 0.65,
	fov = 75,
	headBob = 0.6,
	motionBlur = false,
	shake = 0.6,
	speedFov = true,
	gLean = 0.8,
	lensSpray = true,
	sensitivity = 1,
}

local RANGES: { [string]: { number } } = {
	horizonStab = { 0, 1 },
	fov = { 60, 95 },
	headBob = { 0, 1 },
	shake = { 0, 1 },
	gLean = { 0, 1 },
	sensitivity = { 0.2, 3 },
}

local Comfort = {}
Comfort.Defaults = DEFAULTS
Comfort.Ranges = RANGES

local values: { [string]: any } = table.clone(DEFAULTS :: any)
local seen: { [string]: boolean } = {}
local changedEvent = Instance.new("BindableEvent")
Comfort.changed = changedEvent.Event

local saveScheduled = false
local loaded = false

local function clean(key: string, value: any): any
	local default = (DEFAULTS :: any)[key]
	if default == nil or type(value) ~= type(default) then
		return nil
	end
	if type(value) == "number" then
		if value ~= value then
			return nil
		end
		local range = RANGES[key]
		return if range then math.clamp(value, range[1], range[2]) else value
	end
	return value
end

function Comfort.get(key: string): any
	return values[key]
end

function Comfort.all(): Settings
	return table.clone(values) :: any
end

local function save()
	if saveScheduled then
		return
	end
	saveScheduled = true
	task.delay(3, function()
		saveScheduled = false
		local net = ReplicatedStorage:FindFirstChild("Net")
		local remote = net and net:FindFirstChild("Camera_SaveSettings")
		if remote and remote:IsA("RemoteEvent") then
			local out: { [string]: any } = table.clone(values)
			for id in seen do
				out[`seen_{id}`] = true
			end
			remote:FireServer(out)
		end
	end)
end

function Comfort.set(key: string, value: any)
	local v = clean(key, value)
	if v == nil or values[key] == v then
		return
	end
	values[key] = v
	changedEvent:Fire(key, v)
	save()
end

function Comfort.hasSeen(id: string): boolean
	return seen[id] == true
end

function Comfort.markSeen(id: string)
	if not seen[id] then
		seen[id] = true
		save()
	end
end

function Comfort.isLoaded(): boolean
	return loaded
end

function Comfort.load()
	if loaded then
		return
	end
	loaded = true
	local net = ReplicatedStorage:WaitForChild("Net", 10)
	local fn = net and net:WaitForChild("Progression_GetData", 10)
	if not (fn and fn:IsA("RemoteFunction")) then
		return
	end
	local ok, data = pcall(function()
		return (fn :: RemoteFunction):InvokeServer()
	end)
	local stored = ok
		and type(data) == "table"
		and type(data.flags) == "table"
		and data.flags.cameraSettings
	if type(stored) ~= "table" then
		return
	end
	for k, v in stored do
		if type(k) == "string" then
			local id = string.match(k, "^seen_(.+)$")
			if id and v == true then
				seen[id] = true
			else
				local c = clean(k, v)
				if c ~= nil and values[k] ~= c then
					values[k] = c
					changedEvent:Fire(k, c)
				end
			end
		end
	end
end

return Comfort
