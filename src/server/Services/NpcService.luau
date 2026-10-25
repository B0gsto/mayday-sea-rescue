--!strict
-- NpcService: the people standing about the world. For now Chief Aggie (Agnes Brightwater, the
-- retired coxswain) at the top of the station slipway, and two lifeboat crew either side of the ramp.
-- Each is a Roblox R15 character from NpcFactory (docs/12 section 2.9), the block greybox when the
-- build fails. Scenery only: anchored, non-colliding, under Workspace.Npcs.
local Workspace = game:GetService("Workspace")

local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)

local NpcService = {}
NpcService.Priority = 120

local SLIPWAY_WAIT = 30 -- seconds to wait for Workspace.Map.Slipways.StationSlipway
local AGGIE_ONTO_QUAY = 6 -- studs past the ramp's top edge
local CREW_ASIDE = 4.5 -- studs beyond the ramp's side edges (clear of the slipway retaining-wall copings)

local folder: Folder? = nil

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
	NpcFactory.spawn("Aggie", {
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

-- The end of the cold open (docs/14 section 3) --------------------------------------------------

local SHORE_PARTY_LIFE = 120 -- s the blanket scene stays

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

function NpcService.Init()
	local f = Instance.new("Folder")
	f.Name = "Npcs"
	f.Parent = Workspace
	folder = f
end

function NpcService.Start()
	spawnStation()
end

return NpcService
