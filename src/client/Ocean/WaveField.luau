--!strict
-- WaveField: the client ocean's view of the shared wave function.
-- Height = Waves.heightAt(x, z, t, Weather.getWaveParams(position, t)), the same call physics and
-- the server use, so the drawn surface matches gameplay exactly at the grid vertices.
--
-- Weather (stream D) is loaded defensively: if src/shared/Weather is missing or errors, the ocean
-- falls back to calm open-sea params and retries every few seconds, so it never stops drawing.
-- CONTRACT: Weather.getWaveParams(position: Vector3, now: number?): Waves.WaveParams

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Waves = require(Shared:WaitForChild("Waves"))
local WeatherMath = require(Shared:WaitForChild("WeatherMath"))

type WeatherApi = {
	getWaveParams: (position: Vector3, now: number?) -> Waves.WaveParams,
	getZoneAt: (position: Vector3) -> any,
	getWindDirection: () -> number,
}

local RETRY_SECONDS = 3

local WaveField = {}

local weather: WeatherApi? = nil
local weatherOk = false -- valid for the current frame (set by beginFrame)
local nextRetry = 0
local warned = false
local calmParams = Waves.paramsFor(0, 0, 0)
local frameParams: Waves.WaveParams = calmParams -- params at the camera for the current frame
local overrides: { [string]: { q: number, wind: number, params: Waves.WaveParams } } = {}
local heldIntensity: number? = nil -- WeatherController's LocalStormIntensity, read once a frame

-- WeatherController's held storm intensity (the cold open, then a 5 s blend back). Absent on the
-- server and in tests: use the shared weather exactly then.
local function paramsAt(x: number, z: number, t: number): Waves.WaveParams
	local api = weather
	if not api then
		return calmParams
	end
	local intensity = heldIntensity
	if intensity == nil then
		return api.getWaveParams(Vector3.new(x, Waves.SEA_LEVEL, z), t)
	end
	local at = Vector3.new(x, Waves.SEA_LEVEL, z)
	local zone = api.getZoneAt(at)
	local q = WeatherMath.quantize(math.clamp(intensity, 0, 1))
	local wind = api.getWindDirection() -- getSnapshot clones a table: not per sample
	local entry = overrides[zone.id]
	if entry and entry.q == q and entry.wind == wind then
		return entry.params
	end
	local params = Waves.paramsFor(q, zone.shelter, wind)
	overrides[zone.id] = { q = q, wind = wind, params = params }
	return params
end

local function tryLoadWeather()
	local module = Shared:FindFirstChild("Weather")
	if not (module and module:IsA("ModuleScript")) then
		if not warned then
			warned = true
			warn("[Ocean] ReplicatedStorage.Shared.Weather not found; drawing calm sea until it is")
		end
		return
	end
	local ok, result = pcall(require :: any, module)
	if ok and type(result) == "table" and type(result.getWaveParams) == "function" then
		weather = result :: WeatherApi
	elseif not warned then
		warned = true
		warn(`[Ocean] Weather module failed to load ({result}); drawing calm sea`)
	end
end

-- Call once per update before sampling. One pcall per frame guards the per-vertex calls below.
function WaveField.beginFrame(t: number, at: Vector3?)
	if weather == nil and os.clock() >= nextRetry then
		nextRetry = os.clock() + RETRY_SECONDS
		tryLoadWeather()
	end
	local held = Lighting:GetAttribute("LocalStormIntensity")
	heldIntensity = if type(held) == "number" then held else nil
	local api = weather
	if api then
		local p = at or Vector3.zero
		local ok, result = pcall(paramsAt, p.X, p.Z, t)
		weatherOk = ok
		frameParams = if ok then result else calmParams
		local err = result
		if not ok and not warned then
			warned = true
			warn(`[Ocean] Weather.getWaveParams failed ({err}); drawing calm sea`)
		end
	else
		weatherOk = false
		frameParams = calmParams
	end
end

-- Effective storm intensity (0..1, after zone shelter) at the frame's sample point.
function WaveField.intensity(): number
	return frameParams.intensity
end

-- Sum of wave amplitudes at the frame's sample point (crest height bound, studs).
function WaveField.maxAmplitude(): number
	return Waves.maxAmplitude(frameParams)
end

-- Unit wind direction (the first, largest wave travels along the wind).
function WaveField.windDirection(): (number, number)
	return frameParams.dirX[1], frameParams.dirZ[1]
end

-- World Y of the water at (x, z) at time t. Allocation-free (Vector3 is a value type in Luau);
-- cost is one zone lookup (cached params per zone and frame in Weather) plus Waves.COUNT sines.
function WaveField.heightAt(x: number, z: number, t: number): number
	if weatherOk then
		return Waves.heightAt(x, z, t, paramsAt(x, z, t))
	end
	return Waves.heightAt(x, z, t, calmParams)
end

-- Height plus slope (dY/dX, dY/dZ), for the Part fallback's tile tilt.
function WaveField.gradientAt(x: number, z: number, t: number): (number, number, number)
	if weatherOk then
		return Waves.gradientAt(x, z, t, paramsAt(x, z, t))
	end
	return Waves.gradientAt(x, z, t, calmParams)
end

WaveField.SEA_LEVEL = Waves.SEA_LEVEL

return WaveField
