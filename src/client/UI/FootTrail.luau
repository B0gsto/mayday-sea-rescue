--!strict
-- FootTrail: glowing footprints on the ground from the player to a target (the vehicle the phone's
-- Vehicles app just spawned). Not an arrow or a beam: COUNT prints ahead of the player along a
-- PathfindingService route (so it goes round buildings), lighting up one after another and pulsing;
-- the route is re-planned as the player moves. Gone when the player reaches or boards the target,
-- the target goes away, or after TIMEOUT. Client-only, a fixed pool of Neon discs.
--   FootTrail.guide(target)   starts (or replaces) the trail
--   FootTrail.stop()
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StepTrail = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StepTrail"))

local COUNT = 8 -- prints shown ahead of the player
local SPACING = 2.6 -- studs between prints
local STRIDE = 1.1 -- studs between the left and right foot
local REACH = 12 -- studs from the target: arrived
local TIMEOUT = 90
local REPLAN_MOVE = 8 -- studs walked since the last route
local REPLAN_EVERY = 3 -- seconds
local GLOW = Color3.fromRGB(255, 214, 120)
-- one print: discs (offset x right / z forward, diameter) for a right foot; mirrored for the left
local SHAPE = {
	{ 0, 0.55, 0.62 }, -- heel
	{ 0.05, 0.1, 0.58 }, -- arch
	{ 0, -0.38, 0.78 }, -- ball
	{ -0.24, -0.86, 0.3 }, -- big toe
	{ 0.04, -0.92, 0.22 },
	{ 0.26, -0.84, 0.2 },
}

type Print = { discs: { BasePart }, at: Vector3?, bornAt: number }

local player = Players.LocalPlayer
local FootTrail = {}

local folder: Folder? = nil
local prints: { Print } = {}
local steps: { StepTrail.Step } = {}
local token = 0
local conn: RBXScriptConnection? = nil

local function pool(): { Print }
	if folder and folder.Parent then
		return prints
	end
	local f = Instance.new("Folder")
	f.Name = "FootTrail"
	f.Parent = Workspace
	folder = f
	table.clear(prints)
	for _ = 1, COUNT do
		local discs: { BasePart } = {}
		for _, d in SHAPE do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(0.04, d[3], d[3])
			p.Material = Enum.Material.Neon
			p.Color = GLOW
			p.Transparency = 1
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Parent = f
			table.insert(discs, p)
		end
		table.insert(prints, { discs = discs, at = nil, bornAt = 0 })
	end
	return prints
end

function FootTrail.stop()
	token += 1
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(prints)
	table.clear(steps)
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- the route from the player's feet to the target: pathfinding waypoints, else a straight line
local function plan(from: Vector3, to: Vector3): { Vector3 }
	local path =
		PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	-- ClosestNoPath: a boat at the bay is in the water; walk to the nearest dry point and the line on
	if
		ok
		and (path.Status == Enum.PathStatus.Success or path.Status == Enum.PathStatus.ClosestNoPath)
	then
		local points = {}
		for _, w in path:GetWaypoints() do
			table.insert(points, w.Position)
		end
		if #points >= 2 then
			if path.Status == Enum.PathStatus.ClosestNoPath then
				table.insert(points, to)
			end
			return points
		end
	end
	return { from, to }
end

-- lay one footprint flat on whatever is under it
local function place(foot: Print, step: StepTrail.Step, params: RaycastParams)
	local hit = Workspace:Raycast(step.pos + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0), params)
	local at = if hit then hit.Position else step.pos
	local up = if hit then hit.Normal else Vector3.yAxis
	local forward = step.dir - up * step.dir:Dot(up)
	if forward.Magnitude < 1e-3 then
		forward = step.dir
	end
	local frame = CFrame.lookAt(at + up * 0.03, at + up * 0.03 + forward, up)
	local mirror = if step.left then -1 else 1
	for i, d in SHAPE do
		-- the cylinder's axis is X: turn it upright so the disc lies on the ground
		foot.discs[i].CFrame = frame
			* CFrame.new(d[1] * mirror, 0, d[2])
			* CFrame.Angles(0, 0, math.pi / 2)
	end
	if not foot.at or (foot.at - at).Magnitude > 1 then
		foot.bornAt = os.clock()
	end
	foot.at = at
end

function FootTrail.guide(target: Model)
	FootTrail.stop()
	local my = token
	local started = os.clock()
	local plannedFrom: Vector3? = nil
	local plannedAt = -math.huge
	local planning = false
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local nextPlace = 0

	conn = RunService.RenderStepped:Connect(function()
		if token ~= my then
			return
		end
		local root = rootPart()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local gap = if root
			then ((root.Position - target:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude
			else math.huge
		if
			not target.Parent
			or os.clock() - started > TIMEOUT
			or (seat and seat:IsDescendantOf(target))
			or gap < REACH
		then
			FootTrail.stop()
			return
		end
		if not (root and character) then
			return
		end
		local now = os.clock()
		local feet = root.Position - Vector3.new(0, 3, 0)
		if
			not planning
			and (
				not plannedFrom
				or (feet - plannedFrom).Magnitude > REPLAN_MOVE
				or now - plannedAt > REPLAN_EVERY
			)
		then
			planning = true
			plannedFrom, plannedAt = feet, now
			task.spawn(function()
				local points = plan(feet, target:GetPivot().Position)
				if token == my then
					steps = StepTrail.steps(points, 3, SPACING, 40, STRIDE)
					nextPlace = 0
				end
				planning = false
			end)
		end

		local list = pool()
		if now >= nextPlace then
			nextPlace = now + 0.2
			params.FilterDescendantsInstances = { character, target, folder :: Folder }
			-- skip prints already walked past, then light the next COUNT
			local first = 1
			while
				steps[first]
				and (
					(steps[first].pos - feet).Magnitude < 2
					or (steps[first].pos - feet):Dot(steps[first].dir) < 0
				)
			do
				first += 1
			end
			for i, foot in list do
				local step = steps[first + i - 1]
				if step then
					place(foot, step, params)
				else
					foot.at = nil
				end
			end
		end
		-- each print fades in after the one before it, and a pulse runs along the trail
		for i, foot in list do
			local fade = if foot.at
				then math.clamp((now - foot.bornAt - i * 0.12) / 0.35, 0, 1)
				else 0
			local pulse = 0.5 + 0.5 * math.cos(now * 4 - i * 0.7)
			local alpha = 1 - fade * (0.3 + 0.5 * pulse) * (1 - (i - 1) / (COUNT + 2))
			for _, disc in foot.discs do
				disc.Transparency = alpha
			end
		end
	end)
end

return FootTrail
