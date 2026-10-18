--!strict
-- NpcService: the people standing about the world. For now Chief Aggie (Agnes Brightwater, the
-- retired coxswain) at the top of the station slipway, where the cold-open handoff turns the
-- player to face her (VehicleService.slipwaySpots), and two lifeboat crew either side of the ramp.
-- Each is a Roblox R15 character from NpcFactory (docs/12 section 2.9), the block greybox when the
-- build fails. Scenery only: anchored, non-colliding, under Workspace.Npcs.
local Workspace = game:GetService("Workspace")

local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)

local NpcService = {}
NpcService.Priority = 120

local SLIPWAY_WAIT = 30 -- seconds to wait for Workspace.Map.Slipways.StationSlipway
local AGGIE_ONTO_QUAY = 6 -- studs past the ramp's top edge (VehicleService looks 0.6 x 10 studs past it)
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
