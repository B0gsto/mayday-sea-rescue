--!strict
-- Raycast suspension maths: one spring-damper per wheel, an anti-roll bar per axle and the
-- textbook weight transfer formulas (used by the tests to check what the rigid body does by
-- itself). Pure, game units (studs, RMU, seconds).
local Suspension = {}

-- Spring rate (force per stud) for a corner's sprung mass at a ride frequency (Hz).
function Suspension.springRate(cornerMass: number, frequencyHz: number): number
	local w = 2 * math.pi * frequencyHz
	return cornerMass * w * w
end

-- Damper rate for a damping ratio (fraction of critical).
function Suspension.damperRate(k: number, cornerMass: number, ratio: number): number
	return 2 * ratio * math.sqrt(k * cornerMass)
end

-- Static sag (studs) of a corner under its share of the weight.
function Suspension.sag(cornerMass: number, k: number, g: number): number
	return cornerMass * g / k
end

Suspension.BUMP_STOP = 0.9 -- fraction of travel where the rubber bump stop starts
Suspension.BUMP_STIFFNESS = 8 -- x the spring rate at the end of travel -- tune

-- Wheel load along the strut. compression: studs (0 = fully extended, travel = bottomed);
-- compressionSpeed: studs/s (positive while compressing). Never pulls the wheel down (>= 0).
function Suspension.force(
	compression: number,
	compressionSpeed: number,
	k: number,
	c: number,
	travel: number
): number
	local f = k * compression + c * compressionSpeed
	local stop = travel * Suspension.BUMP_STOP
	if compression > stop then
		local into = (compression - stop) / math.max(travel - stop, 1e-3)
		f += k * Suspension.BUMP_STIFFNESS * (compression - stop) * (1 + into)
	end
	return math.max(0, f)
end

-- Anti-roll bar: extra load on the more compressed wheel, taken off the other.
function Suspension.antiRoll(
	compressionLeft: number,
	compressionRight: number,
	kBar: number
): (number, number)
	local d = (compressionLeft - compressionRight) * kBar
	return d, -d
end

-- Static axle loads (force) for a mass, gravity, and the fraction of weight on the front axle.
function Suspension.staticAxleLoads(mass: number, g: number, frontWeight: number): (number, number)
	local w = mass * g
	return w * frontWeight, w * (1 - frontWeight)
end

-- Load moved between axles (or sides) by an acceleration: m a h / base.
function Suspension.loadTransfer(
	mass: number,
	accel: number,
	cgHeight: number,
	base: number
): number
	return mass * accel * cgHeight / base
end

return Suspension
