--!strict
-- Shake (docs/26 "Satisfaction bar"): layered camera shake any effect can call (VFXKit's FX1 punch, the core loop).
--   Shake.add({ magnitude, roughness, time, fadeIn?, pos?, rot? })
--     magnitude  degrees of rotation at full strength
--     roughness  noise speed (8 = a heavy rumble, 20 = a sharp rattle)
--     time       seconds to fade out (eased: strong at once, then a quick settle)
--     fadeIn     seconds to ramp in (0 = a hit)
--     pos        studs of camera-space movement per axis at full strength (default none)
--     rot        per-axis rotation weights (pitch, yaw, roll; default 1, 1, 0.5)
--   Shake.kick(degrees)  an FOV push-in the camera controllers ease back out of
-- Overlapping shakes add, then each axis is soft-limited to 1.25x the strongest live shake (damping), so a pile-up
-- never doubles up. The offset goes on after the camera scripts' step and comes off before their next one, so they
-- never see (or drift by) it. Scaled by the Settings shake slider; nothing at all under Reduce motion.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent:WaitForChild("Comfort"))

export type Spec = {
	magnitude: number,
	roughness: number,
	time: number,
	fadeIn: number?,
	pos: Vector3?,
	rot: Vector3?,
}

type Live = { spec: Spec, born: number, seed: number }

local Shake = {}

local live: { Live } = {}
local applied = CFrame.identity
local bound = false
local seeds = 0

local function step()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local r, p, limit = Vector3.zero, Vector3.zero, 0
	for i = #live, 1, -1 do
		local s = live[i]
		local age = now - s.born
		local spec = s.spec
		if age >= (spec.fadeIn or 0) + spec.time then
			table.remove(live, i)
			continue
		end
		local fadeIn = spec.fadeIn or 0
		local env = if age < fadeIn then age / fadeIn else (1 - (age - fadeIn) / spec.time) ^ 2
		local t = now * spec.roughness
		local n = Vector3.new(
			math.noise(t, s.seed),
			math.noise(t, s.seed + 17.3),
			math.noise(t, s.seed + 41.9)
		) * 2 -- noise is about +-0.5
		local amp = math.rad(spec.magnitude) * env
		r += n * (spec.rot or Vector3.new(1, 1, 0.5)) * amp
		p += n * (spec.pos or Vector3.zero) * env
		limit = math.max(limit, math.rad(spec.magnitude) * 1.25)
	end
	local k = (tonumber(Comfort.get("shake")) or 0.6) * Comfort.motionScale()
	local function soft(v: number): number
		return if limit > 0 then limit * math.tanh(v / limit) else 0
	end
	applied = CFrame.new(p * k) * CFrame.Angles(soft(r.X) * k, soft(r.Y) * k, soft(r.Z) * k)
	camera.CFrame *= applied
end

local function undo()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CFrame *= applied:Inverse()
	end
	applied = CFrame.identity
	if #live == 0 then
		RunService:UnbindFromRenderStep("ShakeUndo")
		RunService:UnbindFromRenderStep("ShakeApply")
		bound = false
	end
end

function Shake.add(spec: Spec)
	if Comfort.reducedMotion() or spec.magnitude <= 0 or spec.time <= 0 then
		return
	end
	seeds += 1
	table.insert(live, { spec = spec, born = os.clock(), seed = seeds * 7.31 })
	if not bound then
		bound = true
		RunService:BindToRenderStep("ShakeUndo", Enum.RenderPriority.First.Value, undo)
		RunService:BindToRenderStep("ShakeApply", Enum.RenderPriority.Camera.Value + 1, step)
	end
end

function Shake.kick(degrees: number)
	local camera = Workspace.CurrentCamera
	if camera and not Comfort.reducedMotion() then
		camera.FieldOfView -= degrees
	end
end

return Shake
