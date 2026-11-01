--!strict
-- Haptics (feel REVIEW item 2): a short rumble on your own key moments. VFXKit.play calls Haptics.fx for every
-- effect; only the presets in PULSES buzz, and never someone else's (`still`). A gamepad gets HapticService
-- motors, a phone a Custom HapticEffect. Off with the Settings "Vibration" toggle or Reduce motion.
--   Haptics.fx(name, opts?)
local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))

-- preset -> { strength 0..1, seconds } -- tune
local PULSES: { [string]: { number } } = {
	survivor_aboard = { 0.35, 0.12 }, -- a survivor boards
	rescue_done = { 0.5, 0.25 }, -- delivered home
	fx1_golden_rescue = { 0.8, 0.4 },
	fx1_build_snap = { 0.45, 0.15 }, -- a build lands
	plate_drop = { 0.5, 0.2 }, -- a sea plate lands
	fx1_hq_levelup = { 0.8, 0.45 }, -- HQ level up
	wheel_win = { 0.3, 0.12 },
	fx1_wheel_jackpot = { 0.9, 0.5 }, -- a rare prize
	bump_splash = { 0.6, 0.15 }, -- hull hits something (scaled by the hit)
	nitro_burst = { 0.4, 0.3 },
}

local Haptics = {}

local serial = 0
local effect: any = nil

local function gamepad(strength: number, seconds: number)
	local pad = Enum.UserInputType.Gamepad1
	if not HapticService:IsVibrationSupported(pad) then
		return
	end
	serial += 1
	local mine = serial
	HapticService:SetMotor(pad, Enum.VibrationMotor.Large, strength)
	HapticService:SetMotor(pad, Enum.VibrationMotor.Small, strength * 0.6)
	task.delay(seconds, function()
		if serial == mine then -- a newer pulse owns the motors now
			HapticService:SetMotor(pad, Enum.VibrationMotor.Large, 0)
			HapticService:SetMotor(pad, Enum.VibrationMotor.Small, 0)
		end
	end)
end

local function phone(strength: number, seconds: number)
	if not effect then
		effect = Instance.new("HapticEffect")
		effect.Type = Enum.HapticEffectType.Custom
		effect.Parent = Workspace
	end
	effect:SetWaveformKeys({ -- a sharp hit that fades out
		FloatCurveKey.new(0, strength, Enum.KeyInterpolationMode.Linear),
		FloatCurveKey.new(seconds * 1000, 0, Enum.KeyInterpolationMode.Linear),
	})
	effect:Play()
end

function Haptics.fx(name: string, opts: { scale: number?, still: boolean? }?)
	local p = PULSES[name]
	if
		not p
		or (opts and opts.still)
		or Comfort.get("haptics") == false
		or Comfort.reducedMotion()
	then
		return
	end
	local strength =
		math.clamp(p[1] * (if name == "bump_splash" and opts then opts.scale or 1 else 1), 0, 1)
	-- pcall: haptics are a nicety; an unsupported device or API must never break the effect that called us
	if UserInputService.GamepadEnabled then
		pcall(gamepad, strength, p[2])
	elseif UserInputService.TouchEnabled then
		pcall(phone, strength, p[2])
	end
end

return Haptics
