--!strict
--[[
CasualtyRig: procedural poses for the Person in the Water casualty, a dressed R15 character (docs/14 section 4,
built by src/server/Assets/CasualtyAsset from NpcFactory + NpcOutfits "Swimmer"). Poses write Motor6D.Transform (local,
not replicated: run on the client in PreSimulation, after the Animator, which plays no tracks on this rig).
Joint keys: "Root" = the Root motor (HumanoidRootPart > LowerTorso: lean, bob, the Sit drop), every other key is the
motor's Part1 name (UpperTorso = Waist, Head = Neck, LeftUpperArm = LeftShoulder, ...). R15 C0s are axis-aligned with the
model (Y up, front -Z, character's left -X), so the angles below read in model axes. Markers (ATT_Strobe, ATT_Whistle)
are Bones on the UpperTorso part and come back in the same map (their Transform stays identity).
API:
  CasualtyRig.apply(model, poseName, t)   -- one frame: "Bind" | "TreadWater" | "Wave" | "Panic" | "Sit" | "Hold" | "Climb"
  CasualtyRig.play(model, poseName)       -- PreSimulation loop (after the Animator) (client); returns a stop() function that restores Bind
  CasualtyRig.sample(poseName, t)         -- pure: the joint transforms at time t (Lune-tested)
  CasualtyRig.motorize(model)             -- server: swap the rig's AnimationConstraint joints for Motor6Ds
]]
local CasualtyRig = {}
CasualtyRig.POSES = { "Bind", "TreadWater", "Wave", "Panic", "Sit", "Hold", "Climb" }
CasualtyRig.HIP_HEIGHT = 2.55 -- studs the Sit pose drops the body (Root motor) to put the hips on the seat (tune)

local rad, sin, cos = math.rad, math.sin, math.cos
local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

-- The rig's joints by pose key (see the header) plus its marker Bones.
local function bones(model: Instance): { [string]: Bone }
	local map: { [string]: any } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then
			map[if d.Name == "Root" then "Root" else d.Part1.Name] = d
		elseif d:IsA("Bone") then
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

-- Holding on (a throw line, the lifebuoy, the rescuer or the sled): leaning in, both arms reaching up and forward
-- with the elbows bent, hands gripping above the surface, kicking. (Arms straight out at the waterline read as a
-- flat plank from the helm.)
local function hold(t: number): { [string]: CFrame }
	local p = treadWater(t)
	local s = sin(2 * math.pi * 0.9 * t)
	p.Root = CFrame.new(0, 0.05 * s, 0) * A(-14, 0, 0)
	p.LeftUpperArm = A(118 + 4 * s, -10, -12)
	p.LeftLowerArm = A(38, 0, 10)
	p.LeftHand = A(-20, 0, 0)
	p.RightUpperArm = A(118 - 4 * s, 10, 12)
	p.RightLowerArm = A(38, 0, -10)
	p.RightHand = A(-20, 0, 0)
	p.Head = A(16, 0, 0)
	return p
end

-- Climbing (a ladder or the side): hand over hand overhead, knees stepping up in turn.
local function climb(t: number): { [string]: CFrame }
	local w = 2 * math.pi * 0.7
	local s = sin(w * t)
	return {
		Root = A(-8, 0, 0), -- chest to the ladder
		UpperTorso = A(-4, 3 * s, 0),
		Head = A(18, 0, 0), -- looking up the ladder
		LeftUpperArm = A(150 + 20 * s, 0, -10),
		LeftLowerArm = A(25 - 15 * s, 0, 0),
		RightUpperArm = A(150 - 20 * s, 0, 10),
		RightLowerArm = A(25 + 15 * s, 0, 0),
		LeftUpperLeg = A(45 + 35 * s, 0, -4),
		LeftLowerLeg = A(-50 - 30 * s, 0, 0),
		RightUpperLeg = A(45 - 35 * s, 0, 4),
		RightLowerLeg = A(-50 + 30 * s, 0, 0),
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
	Hold = hold,
	Climb = climb,
}

-- Roblox's avatar joint upgrade builds R15 rigs with AnimationConstraint + BallSocketConstraint
-- joints, not Motor6Ds: bones() found nothing to pose and the unanchored limbs hung or flopped flat.
-- Swaps each AnimationConstraint for a rigid Motor6D (C0 / C1 = its rig attachments). Server side,
-- once, before the rig is parented.
function CasualtyRig.motorize(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if a0 and a1 and p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local m = Instance.new("Motor6D")
				m.Name = d.Name
				m.Part0 = p0
				m.Part1 = p1
				m.C0 = a0.CFrame
				m.C1 = a1.CFrame
				m.Parent = p1
				d:Destroy()
			end
		elseif d:IsA("BallSocketConstraint") then
			d:Destroy()
		end
	end
end

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
	local conn = game:GetService("RunService").PreSimulation:Connect(function()
		CasualtyRig.apply(model, poseName, os.clock() - t0)
	end)
	return function()
		conn:Disconnect()
		CasualtyRig.apply(model, "Bind", 0)
	end
end

return CasualtyRig
