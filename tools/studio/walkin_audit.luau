-- Walk-in audit (docs/25 J): builds every dock building at every level on the first player's plot (in
-- workspace.WalkinAudit, one level at a time) and reports, per building/level: the mesh in use (or the code
-- fallback), solid box colliders (a CanCollide part over 35% of the lot and taller than 4), how many of a 5x5
-- grid of interior floor spots an R15 fits in and reaches by path from in front of the lot, and the prompts /
-- click detectors inside. Run during a Studio play test (one player in):
--   python3 tools/studio/smoke.py lua Server tools/studio/walkin_audit.luau
--   (echo 'WA_ARGS = { key = "Clinic", level = 2, keep = true }'; cat tools/studio/walkin_audit.luau) \
--     | python3 tools/studio/smoke.py lua Server -    -- one building/level; keep = leave it standing for shots
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared.Config.DockConfig)
local DockPieces = require(Shared.DockPieces)
local DockService = require(ServerScriptService.Server.Services.DockService)
local AssetLoader = require(ServerScriptService.Server.Assets.AssetLoader)
DockPieces.meshes = DockPieces.meshes
	or function(asset: string): Model?
		return AssetLoader.cloneStatic(asset, "LOD0", true)
	end

local args = (getfenv() :: any).WA_ARGS or {}
local player = Players:GetPlayers()[1]
assert(player, "no player")
local berth = DockService.GetBerth(player)
assert(berth, "no plot")
local frame = berth.CFrame -- the berth frame (DockService plot.frame = Marina.berth = the berth part)

local root = workspace:FindFirstChild("WalkinAudit") or Instance.new("Folder")
root.Name = "WalkinAudit"
root.Parent = workspace
root:ClearAllChildren()

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { player.Character :: Instance }

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { player.Character :: Instance }
overlap.RespectCanCollide = true

-- the floor top under a point (from 40 up), or nil
local function floor(p: Vector3): Vector3?
	local hit = workspace:Raycast(p + Vector3.new(0, 1.5, 0), Vector3.new(0, -12, 0), params)
	return hit and hit.Position
end

local function audit(key: string, level: number, keep: boolean): string
	local def = DockConfig.Buildings[key]
	local m = DockPieces.building(key, frame, level)
	m.Parent = root
	task.wait(1.5) -- the navmesh catches up
	local at = frame * def.spot
	local w, d = def.size.X, def.size.Y
	local area = w * d
	local mesh, boxes, prompts = {}, {}, {}
	for _, c in m:GetChildren() do
		if string.find(c.Name, "Mesh$") or c.Name == "FreightQuay" then
			table.insert(mesh, c.Name)
		end
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide and p.Size.Y > 4 then
			local s = p.Size
			local face = math.max(s.X * s.Z, s.X * s.Y, s.Y * s.Z)
			if math.min(s.X, s.Y, s.Z) > 4 and face > 0.35 * area then
				table.insert(boxes, `{p.Name}({math.floor(s.X)}x{math.floor(s.Y)}x{math.floor(s.Z)})`)
			end
		elseif p:IsA("ProximityPrompt") then
			table.insert(prompts, `prompt:{p.ActionText}`)
		elseif p:IsA("ClickDetector") then
			table.insert(prompts, `click:{p.Parent and p.Parent.Name}`)
		end
	end
	-- the start: 8 in front of the lot's front edge (-Z), on the ground
	local start = floor((at * CFrame.new(0, 3, -d / 2 - 8)).Position)
	local clear, reach = 0, 0
	local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true })
	for i = -2, 2 do
		for j = -2, 2 do
			local top = floor((at * CFrame.new(i * w * 0.18, 3, j * d * 0.18)).Position)
			if top then
				local body = CFrame.new(top + Vector3.new(0, 2.8, 0))
				if #workspace:GetPartBoundsInBox(body, Vector3.new(2, 4.6, 1.2), overlap) == 0 then
					clear += 1
					if start then
						local ok = pcall(function()
							path:ComputeAsync(start, top)
						end)
						if ok and path.Status == Enum.PathStatus.Success then
							reach += 1
						end
					end
				end
			end
		end
	end
	if not keep then
		m:Destroy()
	end
	return string.format(
		"%-15s L%d mesh=%s box=%s fit=%d/25 reach=%d/%d acts=%s",
		key,
		level,
		if #mesh > 0 then table.concat(mesh, "+") else "CODE",
		if #boxes > 0 then table.concat(boxes, ",") else "-",
		clear,
		reach,
		clear,
		if #prompts > 0 then table.concat(prompts, ",") else "-"
	)
end

-- hide the plot's own copies while auditing (a fresh profile has only the Harbour)
local out = {}
for _, key in DockConfig.BUILDINGS do
	if key ~= "Harbour" and (args.key == nil or args.key == key) then
		for l = 1, #DockConfig.Buildings[key].levels do
			if args.level == nil or args.level == l then
				table.insert(out, audit(key, l, args.keep == true))
			end
		end
	end
end
print(table.concat(out, "\n"))
