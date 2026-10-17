--!strict
--[[
CasualtyRig (ModuleScript inside M_Chr_Casualty_Swimmer_Rig.rbxm): procedural Bone poses for the skinned swimmer.
Skeleton (R15 skinned-mesh names): Root (feet, pivot) > HumanoidRootNode > LowerTorso > UpperTorso > Head / arms, legs off
LowerTorso. Bind pose: relaxed A-pose, every bone axis-aligned with the model (Y up, front -Z, character's left -X).
Poses write Bone.Transform (local, not replicated: run on the client; an Animator/AnimationController also lives in the
model for authored KeyframeSequence animations, whose Pose names must match the bone names).
API:
  CasualtyRig.apply(model, poseName, t)   -- one frame: "Bind" | "TreadWater" | "Wave" (t = seconds, drives the cycle)
  CasualtyRig.play(model, poseName)       -- RenderStepped loop (client); returns a stop() function that restores Bind
  CasualtyRig.WATERLINE                   -- studs above the pivot where the sea surface sits when treading water
]]
local RunService = game:GetService("RunService")

local CasualtyRig = {}
CasualtyRig.WATERLINE = 4.55 -- lifejacket keeps the shoulders just under, chin above the surface
CasualtyRig.POSES = { "Bind", "TreadWater", "Wave" }

local rad, sin, cos = math.rad, math.sin, math.cos
local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

local function bones(model: Instance): { [string]: Bone }
	local map = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			map[d.Name] = d
		end
	end
	return map
end

-- Angles in degrees about the bone's own axes (= model axes at bind): +X pitches a hanging limb forward (-Z) and tips the
-- torso back; Z abducts (left side negative, right side positive for a hanging limb).
local function treadWater(t: number): { [string]: CFrame }
	local w = 2 * math.pi * 0.55 -- sculling / eggbeater cycle, 0.55 Hz
	local s, c = sin(w * t), cos(w * t)
	local bob = 0.07 * sin(w * t * 0.5)
	return {
		Root = CFrame.new(0, bob, 0) * A(-6 + 2 * s, 0, 0), -- slight forward lean, bobbing at the waterline
		LowerTorso = A(-4, 0, 1.5 * c),
		UpperTorso = A(-6, 2 * s, 0),
		Head = A(14 + 2 * c, -6 * s, 0), -- chin up out of the water, looking around
		LeftUpperArm = A(36, 18 * s, -48),
		LeftLowerArm = A(46 + 8 * c, 0, -10),
		LeftHand = A(0, 0, -18 * s),
		RightUpperArm = A(36, -18 * s, 48),
		RightLowerArm = A(46 + 8 * c, 0, 10),
		RightHand = A(0, 0, 18 * s),
		LeftUpperLeg = A(42 + 14 * s, 0, -14),
		LeftLowerLeg = A(-62 - 14 * c, 0, 0),
		LeftFoot = A(-10 + 12 * s, 0, 0),
		RightUpperLeg = A(42 - 14 * s, 0, 14),
		RightLowerLeg = A(-62 + 14 * c, 0, 0),
		RightFoot = A(-10 - 12 * s, 0, 0),
	}
end

local function wave(t: number): { [string]: CFrame }
	local p = treadWater(t)
	local s = sin(2 * math.pi * 1.4 * t)
	p.RightUpperArm = A(10, 0, 160 + 14 * s) -- right arm overhead, waving for help
	p.RightLowerArm = A(8, 0, 10 * s)
	p.RightHand = A(0, 0, 12 * s)
	p.Head = A(18, 8, 0)
	return p
end

local GENERATORS: { [string]: (number) -> { [string]: CFrame } } = {
	Bind = function()
		return {}
	end,
	TreadWater = treadWater,
	Wave = wave,
}

function CasualtyRig.apply(model: Instance, poseName: string, t: number?)
	local gen = GENERATORS[poseName] or GENERATORS.Bind
	local pose = gen(t or 0)
	for name, b in bones(model) do
		b.Transform = pose[name] or CFrame.identity
	end
end

function CasualtyRig.play(model: Instance, poseName: string): () -> ()
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		CasualtyRig.apply(model, poseName, os.clock() - t0)
	end)
	return function()
		conn:Disconnect()
		CasualtyRig.apply(model, "Bind", 0)
	end
end

return CasualtyRig
