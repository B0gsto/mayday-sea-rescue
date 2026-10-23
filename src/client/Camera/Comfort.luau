--!strict
-- Comfort: the player's settings (camera comfort, graphics override, audio, voice),
-- persisted on the profile.
-- Loaded once from Progression_GetData (flags.cameraSettings) and saved through the
-- Camera_SaveSettings RemoteEvent (ProgressionService stores it with SetFlag; rate limited, so
-- saves are debounced here). Cinematics record "seen_<id>" in the same table.
--
--   Comfort.get(key) / Comfort.set(key, value) / Comfort.all()
--   Comfort.setMany({ [key]: value }) (one save; the Seasick-safe preset uses it)
--   Comfort.changed:Connect(fn(key, value))
--   Comfort.hasSeen(id) / Comfort.markSeen(id)
--   Comfort.load() (yields briefly; CameraController.Start calls it)
--   Comfort.whenReady(fn) calls fn once the stored values are in (or the load gave up)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsRules"))

-- The keys, defaults, ranges and choices live in shared/SettingsRules (comfort, graphics
-- override, audio volumes, voice); this module is the client store.
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
	oceanQuality: string, -- "Auto" | "High" | "Medium" | "Low"
	scatterQuality: string,
	volMaster: number,
	volSfx: number,
	volRadio: number,
	volMusic: number,
	voice: boolean,
	colourAssist: string,
	textSize: number,
	reduceMotion: boolean,
	holdToTap: boolean,
}

local DEFAULTS: Settings = SettingsRules.Defaults :: any
local RANGES: { [string]: { number } } = SettingsRules.Ranges

local Comfort = {}
Comfort.Defaults = DEFAULTS
Comfort.Ranges = RANGES
Comfort.Rules = SettingsRules

local values: { [string]: any } = table.clone(DEFAULTS :: any)
local seen: { [string]: boolean } = {}
local changedEvent = Instance.new("BindableEvent")
Comfort.changed = changedEvent.Event

local saveScheduled = false
local loaded = false

local clean = SettingsRules.clean

function Comfort.get(key: string): any
	return values[key]
end

function Comfort.all(): Settings
	return table.clone(values) :: any
end

-- Reduce motion: the camera shake / bob multiplier and the UI's fade checks read these.
function Comfort.reducedMotion(): boolean
	return values.reduceMotion == true
end

function Comfort.motionScale(): number
	return if values.reduceMotion == true then 0 else 1
end

function Comfort.textScale(): number
	return math.clamp((tonumber(values.textSize) or 100) / 100, 1, 1.5)
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

function Comfort.setMany(changes: { [string]: any })
	for k, v in changes do
		Comfort.set(k, v)
	end
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

local ready = false
local readyEvent = Instance.new("BindableEvent")

function Comfort.whenReady(fn: () -> ())
	if ready then
		task.spawn(fn)
	else
		readyEvent.Event:Once(fn)
	end
end

local function fetch()
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

function Comfort.load()
	if loaded then
		return
	end
	loaded = true
	fetch()
	ready = true
	readyEvent:Fire()
end

return Comfort
