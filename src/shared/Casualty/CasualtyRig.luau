--!strict
--[[
CasualtyRig (game copy of art/source/characters/M_Chr_Casualty_Swimmer/CasualtyRig.luau, which ships inside
M_Chr_Casualty_Swimmer_Rig.rbxm; this one adds the Panic and Sit poses): procedural Bone poses for the skinned swimmer.
Skeleton (R15 skinned-mesh names): Root (feet, pivot) > HumanoidRootNode > LowerTorso > UpperTorso > Head / arms, legs off
LowerTorso. Bind pose: relaxed A-pose, every bone axis-aligned with the model (Y up, front -Z, character's left -X).
Poses write Bone.Transform (local, not replicated: run on the client; an Animator/AnimationController also lives in the
model for authored KeyframeSequence animations, whose Pose names must match the bone names).
API:
  CasualtyRig.apply(model, poseName, t)   -- one frame: "Bind" | "TreadWater" | "Wave" | "Panic" | "Sit" (t = seconds, drives the cycle)
  CasualtyRig.play(model, poseName)       -- RenderStepped loop (client); returns a stop() function that restores Bind
  CasualtyRig.WATERLINE                   -- studs above the pivot where the sea surface sits when treading water
]]
local RunService = game:GetService("RunService")

local CasualtyRig = {}
CasualtyRig.WATERLINE = 4.55 -- lifejacket keeps the shoulders just under, chin above the surface
CasualtyRig.POSES = { "Bind", "TreadWater", "Wave", "Panic", "Sit" }
CasualtyRig.HIP_HEIGHT = 2.55 -- studs from the feet (Root) to the hips at bind (Sit lowers the body by this)

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

-- Panicking (docs 09 section 5.4): head thrown back, both arms thrashing at the surface, fast kicks.
local function panic(t: number): { [string]: CFrame }
	local w = 2 * math.pi * 1.6
	local s, c = sin(w * t), cos(w * t)
	local s2 = sin(w * t * 1.37 + 1.1)
	return {
		Root = CFrame.new(0, 0.12 * sin(w * t * 0.5), 0) * A(-4 + 4 * s2, 0, 3 * c),
		LowerTorso = A(-2, 0, 3 * s),
		UpperTorso = A(4 + 3 * c, 6 * s2, 0),
		Head = A(26 + 4 * s, 14 * s2, 0), -- head back, mouth clear of the water
		LeftUpperArm = A(70 + 30 * s, 20 * c, -70 - 25 * c),
		LeftLowerArm = A(30 + 25 * c, 0, -10),
		LeftHand = A(0, 0, -30 * s),
		RightUpperArm = A(70 - 30 * s2, -20 * s, 70 + 25 * s),
		RightLowerArm = A(30 + 25 * s2, 0, 10),
		RightHand = A(0, 0, 30 * c),
		LeftUpperLeg = A(30 + 28 * s, 0, -10),
		LeftLowerLeg = A(-50 - 30 * c, 0, 0),
		LeftFoot = A(-20 + 20 * s, 0, 0),
		RightUpperLeg = A(30 - 28 * s, 0, 10),
		RightLowerLeg = A(-50 + 30 * c, 0, 0),
		RightFoot = A(-20 - 20 * s, 0, 0),
	}
end

-- Recovered: sitting on the deck (legs out in front, knees a little bent, hands in the lap), shivering.
local function sit(t: number): { [string]: CFrame }
	local shiver = 0.6 * sin(2 * math.pi * 7 * t)
	local breathe = 1.5 * sin(2 * math.pi * 0.3 * t)
	return {
		Root = CFrame.new(0, -(CasualtyRig.HIP_HEIGHT - 0.35), 0),
		LowerTorso = A(8, 0, 0),
		UpperTorso = A(-14 + breathe, 0, shiver * 0.5),
		Head = A(-8, 10 * sin(2 * math.pi * 0.08 * t), shiver),
		LeftUpperArm = A(28, 0, -16),
		LeftLowerArm = A(58, 0, 18),
		LeftHand = A(0, 0, 10),
		RightUpperArm = A(28, 0, 16),
		RightLowerArm = A(58, 0, -18),
		RightHand = A(0, 0, -10),
		LeftUpperLeg = A(84, 0, -6),
		LeftLowerLeg = A(-22, 0, 0),
		LeftFoot = A(-15, 0, 0),
		RightUpperLeg = A(84, 0, 6),
		RightLowerLeg = A(-22, 0, 0),
		RightFoot = A(-15, 0, 0),
	}
end

local GENERATORS: { [string]: (number) -> { [string]: CFrame } } = {
	Bind = function()
		return {}
	end,
	TreadWater = treadWater,
	Wave = wave,
	Panic = panic,
	Sit = sit,
}

-- The pose's bone transforms at time t (bones not listed stay at bind = CFrame.identity).
function CasualtyRig.sample(poseName: string, t: number): { [string]: CFrame }
	return (GENERATORS[poseName] or GENERATORS.Bind)(t)
end

-- The model's bones by name (cache it per model and pass it to apply: GetDescendants every frame is slow).
CasualtyRig.bones = bones

function CasualtyRig.apply(
	model: Instance,
	poseName: string,
	t: number?,
	boneMap: { [string]: Bone }?
)
	local gen = GENERATORS[poseName] or GENERATORS.Bind
	local pose = gen(t or 0)
	local map: { [string]: Bone } = boneMap or bones(model)
	for name, b in map do
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
