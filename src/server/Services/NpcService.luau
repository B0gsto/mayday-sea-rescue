--!strict
-- NpcService: owns Workspace.Npcs (the quest givers, NpcFactory characters, live there too) and the cold open's
-- shore party.
-- Each is a Roblox R15 character from NpcFactory (docs/12 section 2.9), the block greybox when the
-- build fails. Scenery only: anchored, non-colliding, under Workspace.Npcs.
local Workspace = game:GetService("Workspace")

local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)

local NpcService = {}
NpcService.Priority = 120

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

function NpcService.Start() end

return NpcService
