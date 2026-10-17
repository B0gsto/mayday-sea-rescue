--!strict
-- WaveField: the client ocean's view of the shared wave function.
-- Height = Waves.heightAt(x, z, t, Weather.getWaveParams(position, t)), the same call physics and
-- the server use, so the drawn surface matches gameplay exactly at the grid vertices.
--
-- Weather (stream D) is loaded defensively: if src/shared/Weather is missing or errors, the ocean
-- falls back to calm open-sea params and retries every few seconds, so it never stops drawing.
-- CONTRACT: Weather.getWaveParams(position: Vector3, now: number?): Waves.WaveParams

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Waves = require(Shared:WaitForChild("Waves"))

type WeatherApi = {
	getWaveParams: (position: Vector3, now: number?) -> Waves.WaveParams,
}

local RETRY_SECONDS = 3

local WaveField = {}

local weather: WeatherApi? = nil
local weatherOk = false -- valid for the current frame (set by beginFrame)
local nextRetry = 0
local warned = false
local calmParams = Waves.paramsFor(0, 0, 0)

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
function WaveField.beginFrame(t: number)
	if weather == nil and os.clock() >= nextRetry then
		nextRetry = os.clock() + RETRY_SECONDS
		tryLoadWeather()
	end
	local api = weather
	if api then
		local ok, err = pcall(api.getWaveParams, Vector3.zero, t)
		weatherOk = ok
		if not ok and not warned then
			warned = true
			warn(`[Ocean] Weather.getWaveParams failed ({err}); drawing calm sea`)
		end
	else
		weatherOk = false
	end
end

-- World Y of the water at (x, z) at time t. Allocation-free (Vector3 is a value type in Luau);
-- cost is one zone lookup (cached params per zone and frame in Weather) plus Waves.COUNT sines.
function WaveField.heightAt(x: number, z: number, t: number): number
	local api = weather
	if weatherOk and api then
		return Waves.heightAt(x, z, t, api.getWaveParams(Vector3.new(x, Waves.SEA_LEVEL, z), t))
	end
	return Waves.heightAt(x, z, t, calmParams)
end

-- Height plus slope (dY/dX, dY/dZ), for the Part fallback's tile tilt.
function WaveField.gradientAt(x: number, z: number, t: number): (number, number, number)
	local api = weather
	if weatherOk and api then
		local params = api.getWaveParams(Vector3.new(x, Waves.SEA_LEVEL, z), t)
		return Waves.gradientAt(x, z, t, params)
	end
	return Waves.gradientAt(x, z, t, calmParams)
end

WaveField.SEA_LEVEL = Waves.SEA_LEVEL

return WaveField
