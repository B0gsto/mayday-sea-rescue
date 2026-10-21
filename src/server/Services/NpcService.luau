--!strict
-- NpcService: the people standing about the world. For now Chief Aggie (Agnes Brightwater, the
-- retired coxswain) at the top of the station slipway, where the cold-open handoff turns the
-- player to face her (VehicleService.slipwaySpots), and two lifeboat crew either side of the ramp.
-- Each is a Roblox R15 character from NpcFactory (docs/12 section 2.9), the block greybox when the
-- build fails. Scenery only: anchored, non-colliding, under Workspace.Npcs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TweenService = game:GetService("TweenService")

local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)
local Remotes =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("Remotes"))

local NpcService = {}
NpcService.Priority = 120

local SLIPWAY_WAIT = 30 -- seconds to wait for Workspace.Map.Slipways.StationSlipway
local AGGIE_ONTO_QUAY = 6 -- studs past the ramp's top edge (VehicleService looks 0.6 x 10 studs past it)
local CREW_ASIDE = 4.5 -- studs beyond the ramp's side edges (clear of the slipway retaining-wall copings)

local folder: Folder? = nil
local aggie: Model? = nil

local function ground(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if folder then { folder } else {}
	local hit = Workspace:Raycast(at + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position else at
end

-- Feet CFrame at `at` on the ground, facing `toward` (level).
local function stand(at: Vector3, toward: Vector3): CFrame
	local p = ground(at)
	local look = Vector3.new(toward.X, p.Y, toward.Z)
	if (look - p).Magnitude < 0.1 then
		return CFrame.new(p)
	end
	return CFrame.lookAt(p, look)
end

local function spawnStation()
	local map = Workspace:WaitForChild("Map", SLIPWAY_WAIT)
	local slips = map and map:WaitForChild("Slipways", SLIPWAY_WAIT)
	local ramp = slips and slips:WaitForChild("StationSlipway", SLIPWAY_WAIT)
	if not (ramp and ramp:IsA("BasePart")) then
		warn("[NpcService] no Map.Slipways.StationSlipway: station NPCs not placed")
		return
	end
	local half = ramp.Size / 2
	-- the ramp's local -Z end is its top, at the quay (map/Build.luau)
	local top = (ramp.CFrame * CFrame.new(0, half.Y, -half.Z)).Position
	local up = ramp.CFrame.LookVector -- local -Z: up the ramp, toward the quay
	local flat = Vector3.new(up.X, 0, up.Z).Unit
	local side = ramp.CFrame.RightVector
	local downRamp = top - flat * 10 -- everyone faces down the slipway, toward the water
	aggie = NpcFactory.spawn("Aggie", {
		name = "ChiefAggie",
		pose = "Idle",
		seed = 1,
		cframe = stand(top + flat * AGGIE_ONTO_QUAY, downRamp),
		parent = folder :: Instance?,
	})
	for i, s in { -1, 1 } do
		local at = top + flat * 2 + side * s * (half.X + CREW_ASIDE)
		NpcFactory.spawn("Crew", {
			name = `StationCrew{i}`,
			pose = "Idle",
			seed = i - 1,
			cframe = stand(at, downRamp),
			parent = folder :: Instance?,
		})
	end
end

-- R15 rigs the client ambient crowd clones (AmbientController reads ReplicatedStorage.AmbientNpcTemplates;
-- HumanoidDescription characters can only be built on the server).
local AMBIENT_TEMPLATES: { [string]: number } = { Passenger = 6, Boater = 3, Swimmer = 3 }

local function buildAmbientTemplates()
	local templates = Instance.new("Folder")
	templates.Name = "AmbientNpcTemplates"
	for role, count in AMBIENT_TEMPLATES do
		for i = 1, count do
			local m = NpcFactory.build(role, { name = `{role}{i}`, seed = i - 1 })
			if m then
				m:SetAttribute("NpcRole", role)
				m.Parent = templates
			end
		end
	end
	templates.Parent = ReplicatedStorage -- parented once complete so clients never see a half-built set
end

-- The end of the cold open (docs/14 section 3) --------------------------------------------------

local WALK_ANIM = "rbxassetid://507777826" -- stock R15 walk
local AGGIE_WALK_SPEED = 5 -- studs/s
local AGGIE_STOP = 5 -- studs short of the player
local SHORE_PARTY_LIFE = 120 -- s the blanket scene stays

local function playAnim(model: Model, id: string): AnimationTrack?
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if not ok then
		return nil
	end
	track.Looped = true
	track:Play(0.2)
	return track
end

-- Walks an anchored NPC to `to` (feet level kept), walk animation on the way.
local function walkTo(model: Model, to: Vector3): number
	local from = model:GetPivot()
	local goal = Vector3.new(to.X, from.Position.Y, to.Z)
	local dist = (goal - from.Position).Magnitude
	if dist < 0.5 then
		return 0
	end
	local secs = dist / AGGIE_WALK_SPEED
	local track = playAnim(model, WALK_ANIM)
	if track then
		track:AdjustSpeed(AGGIE_WALK_SPEED / 6.4) -- the clip covers 6.4 studs/s at 1x: no foot sliding
	end
	local v = Instance.new("CFrameValue")
	v.Value = from
	v.Changed:Connect(function(cf)
		model:PivotTo(cf)
	end)
	local tw = TweenService:Create(v, TweenInfo.new(secs, Enum.EasingStyle.Linear), {
		Value = CFrame.lookAt(goal, goal + (goal - from.Position) * Vector3.new(1, 0, 1)),
	})
	tw.Completed:Connect(function()
		v:Destroy()
		if track then
			track:Stop(0.3)
		end
	end)
	tw:Play()
	return secs
end

-- On land a lifeboat crew member wraps the casualty in a blanket (a seated R15 swimmer) at `dry`,
-- facing the water. Scenery for SHORE_PARTY_LIFE s. Never yields.
function NpcService.ShoreHandover(dry: Vector3, water: Vector3)
	task.spawn(function()
		local face = Vector3.new(water.X, dry.Y, water.Z)
		local cas = NpcFactory.spawn("Swimmer", {
			name = "ColdOpenCasualty",
			pose = "Sit",
			seed = 2,
			cframe = stand(dry, face),
			parent = folder :: Instance?,
		})
		local torso = cas:FindFirstChild("UpperTorso") or cas:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			local blanket = Instance.new("Part")
			blanket.Name = "Blanket"
			blanket.Size = torso.Size + Vector3.new(0.6, 0.8, 0.6)
			blanket.Color = Color3.fromRGB(150, 40, 40)
			blanket.Material = Enum.Material.Fabric
			blanket.CanCollide, blanket.CanTouch, blanket.CanQuery = false, false, false
			blanket.Massless = true
			blanket.CFrame = torso.CFrame * CFrame.new(0, -0.2, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = torso, blanket
			weld.Parent = blanket
			blanket.Parent = cas
		end
		local side = (face - dry) * Vector3.new(1, 0, 1)
		side = if side.Magnitude > 1e-3 then side.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
		local medic = NpcFactory.spawn("Crew", {
			name = "ColdOpenMedic",
			pose = "Idle",
			seed = 3,
			cframe = stand(dry + side * 2.5, dry),
			parent = folder :: Instance?,
		})
		task.delay(SHORE_PARTY_LIFE, function()
			cas:Destroy()
			medic:Destroy()
		end)
	end)
end

-- After the arrival handoff stands `player` on the slipway: Chief Aggie walks up, says her line
-- (an Ops_Radio subtitle) and walks back to her spot a little later. Never yields.
function NpcService.MeetAggie(player: Player, at: Vector3, line: { from: string, text: string })
	local a = aggie
	if not (a and a.Parent) then
		Remotes.event("Ops_Radio")
			:FireClient(player, { opId = "", from = line.from, text = line.text })
		return
	end
	local home = a:GetPivot().Position
	local flat = (home - at) * Vector3.new(1, 0, 1)
	local to = if flat.Magnitude > AGGIE_STOP then at + flat.Unit * AGGIE_STOP else home
	local secs = walkTo(a, to)
	task.delay(secs + 0.3, function()
		if player.Parent then
			Remotes.event("Ops_Radio")
				:FireClient(player, { opId = "", from = line.from, text = line.text })
		end
		local wave = playAnim(a, "rbxassetid://507770239")
		task.delay(3, function()
			if wave then
				wave:Stop(0.3)
			end
		end)
		task.delay(20, function()
			if a.Parent then
				walkTo(a, home)
			end
		end)
	end)
end

function NpcService.Init()
	local f = Instance.new("Folder")
	f.Name = "Npcs"
	f.Parent = Workspace
	folder = f
end

function NpcService.Start()
	task.spawn(buildAmbientTemplates)
	spawnStation()
end

return NpcService
