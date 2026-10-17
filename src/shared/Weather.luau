--!strict
-- Weather: read side of the storm, shared by client and server (see CONTRACT.md, stream D).
--
-- The server (StormService) writes attributes on ReplicatedStorage.Weather (a Folder):
--   State, StateStartTime (workspace:GetServerTimeNow()), StateDuration, StormId,
--   WindDirection (radians), IsGreatStorm.
-- This module mirrors them into a local snapshot (no attribute reads in hot paths) and derives
-- everything else from the server clock, so late joiners need no catch-up messages.
--
--   Weather.getState()                     -- "Calm" | "Warning" | "Storm" | "Clearing"
--   Weather.getIntensity(now?)             -- 0..1, smooth ramps in Warning and Clearing
--   Weather.getZoneAt(position)            -- GameConfig zone (highest priority) or OpenSea
--   Weather.getWaveParams(position, now?)  -- Waves params for that zone, cached
--   Weather.heightAt(position, now?)       -- water surface Y there
--   Weather.changed:Connect(fn(state))     -- fires when State changes
--
-- Before the server has created the folder (and in Lune tests, where `game` does not exist)
-- the weather is Calm with intensity 0.

local GameConfig = require(script.Parent.Config.GameConfig)
local Waves = require(script.Parent.Waves)
local WeatherMath = require(script.Parent.WeatherMath)

export type OpenSeaZone = typeof(GameConfig.OpenSea)
export type ZoneResult = GameConfig.Zone | OpenSeaZone

export type Snapshot = {
	State: string,
	StateStartTime: number,
	StateDuration: number,
	StormId: number,
	WindDirection: number,
	IsGreatStorm: boolean,
}

type Signal = { Connect: (self: any, (state: string) -> ()) -> RBXScriptConnection }

local FOLDER_NAME = "Weather"
local HAS_GAME = typeof(game) == "Instance"

local Weather = {}

Weather.FOLDER_NAME = FOLDER_NAME

local snap: Snapshot = {
	State = "Calm",
	StateStartTime = 0,
	StateDuration = 0,
	StormId = 0,
	WindDirection = 0,
	IsGreatStorm = false,
}

local DEFAULTS: Snapshot = table.freeze(table.clone(snap))

-- changed signal: a BindableEvent in Roblox, a tiny Lua signal in Lune.
local fire: (state: string) -> ()
if HAS_GAME then
	local bindable = Instance.new("BindableEvent")
	Weather.changed = (bindable.Event :: any) :: Signal
	fire = function(state: string)
		bindable:Fire(state)
	end
else
	local listeners: { [number]: (string) -> () } = {}
	local nextId = 0
	Weather.changed = (
		{
			Connect = function(_self: any, fn: (string) -> ())
				nextId += 1
				local id = nextId
				listeners[id] = fn
				local connection = { Connected = true }
				function connection.Disconnect(self: any)
					self.Connected = false
					listeners[id] = nil
				end
				return connection
			end,
		} :: any
	) :: Signal
	fire = function(state: string)
		for _, fn in table.clone(listeners) do
			fn(state)
		end
	end
end

local function serverNow(): number
	if HAS_GAME then
		return workspace:GetServerTimeNow()
	end
	return os.clock()
end

local function setField(name: string, value: any): boolean
	local default = (DEFAULTS :: any)[name]
	if default == nil then
		return false
	end
	if value == nil then
		value = default
	elseif typeof(value) ~= typeof(default) then
		return false
	end
	if name == "State" and not WeatherMath.isState(value) then
		return false
	end
	(snap :: any)[name] = value
	return true
end

-- Merges attribute values into the snapshot and fires `changed` if State moved. StormService
-- calls this right after writing the attributes so server-side readers see the change at once;
-- tests call it to fake a server.
function Weather._apply(values: { [string]: any })
	local previous = snap.State
	for name, value in values do
		setField(name, value)
	end
	if snap.State ~= previous then
		fire(snap.State)
	end
end

local function bindFolder(folder: Instance)
	local values: { [string]: any } = {}
	for name in DEFAULTS :: any do
		values[name] = folder:GetAttribute(name)
	end
	Weather._apply(values)
	folder.AttributeChanged:Connect(function(name: string)
		if (DEFAULTS :: any)[name] ~= nil then
			Weather._apply({ [name] = folder:GetAttribute(name) })
		end
	end)
end

if HAS_GAME then
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		bindFolder(existing)
	else
		local connection: RBXScriptConnection
		connection = ReplicatedStorage.ChildAdded:Connect(function(child: Instance)
			if child.Name == FOLDER_NAME and child:IsA("Folder") then
				connection:Disconnect()
				bindFolder(child)
			end
		end)
	end
end

function Weather.getState(): string
	return snap.State
end

-- A copy of the replicated attributes (StormId, WindDirection, IsGreatStorm, timings).
function Weather.getSnapshot(): Snapshot
	return table.clone(snap)
end

function Weather.getWindDirection(): number
	return snap.WindDirection
end

function Weather.isGreatStorm(): boolean
	return snap.IsGreatStorm and snap.State ~= "Calm"
end

-- Seconds since the current state started (server clock).
function Weather.getElapsed(now: number?): number
	return math.max(0, (now or serverNow()) - snap.StateStartTime)
end

function Weather.getIntensity(now: number?): number
	local elapsed = (now or serverNow()) - snap.StateStartTime
	return WeatherMath.intensityFor(snap.State, math.max(0, elapsed), snap.StateDuration)
end

function Weather.getZoneAt(position: Vector3): ZoneResult
	local zone = WeatherMath.zoneAt(GameConfig.Zones :: any, position.X, position.Z)
	if zone then
		return (zone :: any) :: GameConfig.Zone
	end
	return GameConfig.OpenSea
end

-- Wave params per zone. Intensity is quantised to 1/1024 steps, so during a ramp a zone's
-- params rebuild at most about once a frame, and in a steady state never; every caller
-- (physics, victims, the ocean mesh) gets the identical table for the same moment.
type CacheEntry = { q: number, wind: number, params: Waves.WaveParams }
local cache: { [string]: CacheEntry } = {}

function Weather.getWaveParams(position: Vector3, now: number?): Waves.WaveParams
	local zone = Weather.getZoneAt(position)
	local q = WeatherMath.quantize(Weather.getIntensity(now))
	local wind = snap.WindDirection
	local entry = cache[zone.id]
	if entry and entry.q == q and entry.wind == wind then
		return entry.params
	end
	local params = Waves.paramsFor(q, zone.shelter, wind)
	cache[zone.id] = { q = q, wind = wind, params = params }
	return params
end

function Weather.heightAt(position: Vector3, now: number?): number
	local t = now or serverNow()
	return Waves.heightAt(position.X, position.Z, t, Weather.getWaveParams(position, t))
end

return Weather
