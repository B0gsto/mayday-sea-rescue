--!strict
-- Drivetrain: engine torque curve, a torque converter, an automatic gearbox with low range and
-- engine braking. Pure. Engine numbers are real-world (rpm, N m); Chassis converts to game units.
local Drivetrain = {}

export type Engine = {
	idleRpm: number,
	stallRpm: number, -- torque converter stall speed: the engine's rpm at full throttle from rest
	redlineRpm: number, -- fuel cut
	torqueCurve: { { number } }, -- { rpm, N m } pairs, ascending rpm
	engineBrakeNm: number, -- drag torque at the redline with the throttle closed
	converterGain: number, -- torque multiplication at stall (about 1.8 to 2.2)
}

export type Gearbox = {
	ratios: { number }, -- forward gears
	reverse: number,
	finalDrive: number,
	lowRange: number, -- transfer case low ratio (1 = none)
	efficiency: number, -- 0..1 driveline efficiency
	shiftUpLight: number, -- rpm to change up at light throttle
	shiftUpFull: number, -- rpm to change up at full throttle
	shiftDown: number, -- rpm to change down when coasting (kickdown raises it)
	shiftTime: number, -- seconds of reduced torque during a change
}

-- Torque (N m) at full throttle for an rpm: linear between the curve points, 0 past the redline.
function Drivetrain.torqueAt(engine: Engine, rpm: number): number
	if rpm >= engine.redlineRpm then
		return 0
	end
	local curve = engine.torqueCurve
	if rpm <= curve[1][1] then
		return curve[1][2]
	end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if rpm <= b[1] then
			local t = (rpm - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return curve[#curve][2]
end

-- Overall ratio engine : wheel for a gear (-1 = reverse, 0 = neutral).
function Drivetrain.ratio(gb: Gearbox, gear: number, low: boolean): number
	local r = 0
	if gear == -1 then
		r = gb.reverse
	elseif gear >= 1 then
		r = gb.ratios[math.min(gear, #gb.ratios)]
	end
	return r * gb.finalDrive * (if low then gb.lowRange else 1)
end

-- Engine rpm and torque converter multiplication from the wheel speed (rad/s), the overall
-- ratio and the throttle. Below the stall speed the converter slips: the engine runs up towards
-- stall and torque is multiplied, fading to 1 as the turbine catches up (lock-up).
function Drivetrain.engineState(
	engine: Engine,
	wheelOmega: number,
	ratio: number,
	throttle: number
): (number, number)
	local coupled = math.abs(wheelOmega) * ratio * 60 / (2 * math.pi)
	local slipRpm = engine.idleRpm + (engine.stallRpm - engine.idleRpm) * math.clamp(throttle, 0, 1)
	local rpm = math.max(coupled, slipRpm, engine.idleRpm)
	local speedRatio = math.clamp(coupled / math.max(slipRpm, 1), 0, 1)
	local mult = 1 + (engine.converterGain - 1) * (1 - speedRatio) * math.clamp(throttle, 0, 1)
	return math.min(rpm, engine.redlineRpm + 200), mult
end

-- Engine torque (N m) at the crank: positive driving, negative engine braking when the throttle
-- is closed and the wheels drive the engine.
function Drivetrain.crankTorque(engine: Engine, rpm: number, throttle: number): number
	if throttle > 0.02 then
		return Drivetrain.torqueAt(engine, rpm) * throttle
	end
	local over = math.clamp((rpm - engine.idleRpm) / (engine.redlineRpm - engine.idleRpm), 0, 1)
	return -engine.engineBrakeNm * over
end

-- The automatic's choice of forward gear for the current wheel speed and throttle. Changes up
-- only when the next gear still sits above the change-down point (no hunting).
function Drivetrain.autoShift(
	gb: Gearbox,
	gear: number,
	wheelOmega: number,
	throttle: number,
	low: boolean
): number
	if gear < 1 then
		return gear
	end
	local t = math.clamp(throttle, 0, 1)
	local function rpmIn(g: number): number
		return math.abs(wheelOmega) * Drivetrain.ratio(gb, g, low) * 60 / (2 * math.pi)
	end
	local up = gb.shiftUpLight + (gb.shiftUpFull - gb.shiftUpLight) * t
	local down = gb.shiftDown + 900 * t * t -- kickdown at a full push
	local rpm = rpmIn(gear)
	if gear < #gb.ratios and rpm > up and rpmIn(gear + 1) > down + 150 then
		return gear + 1
	end
	if gear > 1 and rpm < down and rpmIn(gear - 1) < up - 150 then
		return gear - 1
	end
	return gear
end

return Drivetrain
