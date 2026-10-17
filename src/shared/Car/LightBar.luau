--!strict
-- Warning light patterns for light bars and beacons. Pure: which lamps are lit at a time.
-- Lamps are numbered left to right across the bar (driver's view); the left half is 1..n/2.
--   DoubleFlash  UK-style alternating double flash, sides swap at 1.5 Hz (blue lights)
--   QuadFlash    four short flashes per side, faster (a "priority" pattern)
--   Rotator      simulated rotating beacons, 1.5 rev/s (amber beacons; verify against
--                beach patrol vehicles)
--   Steady       all on (work lights)
local LightBar = {}

LightBar.Patterns = { "DoubleFlash", "QuadFlash", "Rotator", "Steady" }

local function flashes(phase: number, count: number, onTime: number, gap: number): boolean
	for i = 0, count - 1 do
		local start = i * (onTime + gap)
		if phase >= start and phase < start + onTime then
			return true
		end
	end
	return false
end

-- Is lamp `index` of `count` lit at time t (seconds)?
function LightBar.isOn(pattern: string, t: number, index: number, count: number): boolean
	local left = index <= count / 2
	if pattern == "Steady" then
		return true
	elseif pattern == "DoubleFlash" then
		local period = 2 / 3
		local phase = t % period
		local half = period / 2
		local sidePhase = if left then phase else (phase - half) % period
		return sidePhase < half and flashes(sidePhase, 2, 0.06, 0.06)
	elseif pattern == "QuadFlash" then
		local period = 0.8
		local phase = t % period
		local half = period / 2
		local sidePhase = if left then phase else (phase - half) % period
		return sidePhase < half and flashes(sidePhase, 4, 0.045, 0.045)
	elseif pattern == "Rotator" then
		local phase = (t * 1.5 + (index - 1) / math.max(count, 1)) % 1
		return phase < 0.3
	end
	return false
end

-- Brightness 0..1 for a rotator lamp (a smooth sweep instead of on/off), others 0 or 1.
function LightBar.brightness(pattern: string, t: number, index: number, count: number): number
	if pattern == "Rotator" then
		local phase = (t * 1.5 + (index - 1) / math.max(count, 1)) % 1
		return math.max(0, math.cos(phase * 2 * math.pi)) ^ 3
	end
	return if LightBar.isOn(pattern, t, index, count) then 1 else 0
end

return LightBar
