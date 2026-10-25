--!strict
-- LandRescue: a land call's scene (docs/23 e.3, (h) "Land calls"). An orange beach marker where the craft
-- runs ashore, the survivor standing and waving inside an orange ring. Walk into the ring and they follow
-- you on foot (Shared/Ops/LandFollow); sit in any craft within 25 studs and `board` puts them aboard
-- (OperationService spawns the scene's casualty there and runs the normal climb aboard and Home).
-- Player attribute LandCall (Vector3): the survivor, for the pin while you are off your craft.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OpsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops")
local Board = require(OpsFolder:WaitForChild("Board"))
local LandFollow = require(OpsFolder:WaitForChild("LandFollow"))
local NpcFactory = require(script.Parent.Parent:WaitForChild("Npc"):WaitForChild("NpcFactory"))
local Winch =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heli"):WaitForChild("Winch"))

local LandRescue = {}

local ORANGE = Color3.fromRGB(255, 122, 26)
local SEGMENTS = 16
local ANIMS: { [string]: string } = {
	Wave = "rbxassetid://507770239",
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
}

type Scene = {
	folder: Folder,
	ring: Model?,
	model: Model?,
	root: BasePart?,
	hum: Humanoid?,
	height: number,
	tracks: { [string]: AnimationTrack },
	follow: LandFollow.State,
	leader: Player?,
	last: Vector3,
	members: { Player },
}
local live: { [any]: Scene } = {}

local function ground(p: Vector3, ignore: { Instance }, water: boolean?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = not water
	local hit = Workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position else p
end

local function part(parent: Instance, size: Vector3, cf: CFrame, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = ORANGE
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- The pick-up ring on the ground: SEGMENTS neon strips, each sat on the terrain under it.
local function buildRing(parent: Instance, at: Vector3): Model
	local ring = Instance.new("Model")
	ring.Name = "LandRing"
	local r = LandFollow.RING
	local len = 2 * math.pi * r / SEGMENTS + 0.3
	for i = 1, SEGMENTS do
		local a = (i - 0.5) / SEGMENTS * math.pi * 2
		local mid = ground(at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), { parent })
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		part(
			ring,
			Vector3.new(0.6, 0.25, len),
			CFrame.lookAt(mid, mid + tangent) + Vector3.yAxis * 0.15,
			true
		)
	end
	ring.Parent = parent
	return ring
end

-- Where the craft runs ashore: an orange pole and flag with a light.
local function buildMarker(parent: Instance, beach: Vector3)
	local foot = ground(beach, { parent })
	local marker = Instance.new("Model")
	marker.Name = "LandBeachMarker"
	part(marker, Vector3.new(0.6, 12, 0.6), CFrame.new(foot + Vector3.new(0, 6, 0)))
	local flag =
		part(marker, Vector3.new(0.2, 2.6, 4), CFrame.new(foot + Vector3.new(0, 10.6, 2.1)), true)
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 24
	light.Brightness = 2
	light.Parent = flag
	marker.Parent = parent
end

local function play(sc: Scene, name: string)
	for id, track in sc.tracks do
		if id ~= name and track.IsPlaying then
			track:Stop(0.2)
		end
	end
	local track = sc.tracks[name]
	if track and not track.IsPlaying then
		track:Play(0.2)
	end
end

-- The survivor: a stock R15 (NpcFactory) that walks; the greybox fallback has no Humanoid, stays anchored
-- and only hops behind you (LandFollow's stuck rule).
local function spawnSurvivor(sc: Scene, at: Vector3, face: Vector3)
	local flatFace = Vector3.new(face.X, at.Y, face.Z)
	local model, height = NpcFactory.spawn("Passenger", {
		anchored = false,
		name = "LandSurvivor",
		cframe = CFrame.lookAt(at, flatFace),
		parent = sc.folder :: Instance,
	})
	if not sc.folder.Parent then
		model:Destroy() -- the call ended while the rig loaded
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
	end
	sc.model, sc.root, sc.height, sc.last = model, root, height, root.Position
	if not hum then
		root.Anchored = true
		return
	end
	sc.hum = hum
	root.Massless = false
	hum.EvaluateStateMachine = true
	hum.WalkSpeed = 15
	pcall(root.SetNetworkOwner, root, nil) -- the server steers them; a client owner would freeze MoveTo
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	for id, asset in ANIMS do
		local anim = Instance.new("Animation")
		anim.AnimationId = asset
		local ok, track = pcall(animator.LoadAnimation, animator, anim)
		if ok then
			track.Looped = true
			sc.tracks[id] = track
		end
	end
	play(sc, "Wave")
	hum.Running:Connect(function(speed: number)
		if sc.follow.following then
			play(sc, if speed > 0.5 then "Walk" else "Idle")
		end
	end)
end

local function setPin(sc: Scene, at: Vector3?)
	for _, p in sc.members do
		p:SetAttribute("LandCall", at)
	end
end

function LandRescue.Spawn(op: any)
	local site = op.land
	local parent = Workspace:FindFirstChild("CallProps") or Workspace
	local folder = Instance.new("Folder")
	folder.Name = `Land_{op.id}`
	folder.Parent = parent
	local at = ground(site.at, { folder })
	local sc: Scene = {
		folder = folder,
		ring = buildRing(folder, at),
		height = 0,
		tracks = {},
		follow = LandFollow.new(),
		last = at,
		members = table.clone(op.members),
	}
	live[op] = sc
	buildMarker(folder, site.beach)
	setPin(sc, at)
	task.spawn(spawnSurvivor, sc, at, site.beach)
end

local function craftOf(player: Player): Model?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local node: Instance? = hum and hum.SeatPart
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			-- shortcut: Workspace.Vehicles craft only; a car has no survivor seats (VehicleService.AddSurvivor)
			return if node:GetAttribute("LandVehicle") == nil then node else nil
		end
		node = node.Parent
	end
	return nil
end

-- The last dry ground on the way from `from` toward `to` (you, or your craft), at most 120 studs on: where
-- they walk next. They stop at the water's edge.
local function shoreToward(from: Vector3, to: Vector3, ignore: { Instance }): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 1 then
		return from
	end
	local dry = from
	for i = 1, math.min(math.floor(flat.Magnitude / 3), 40) do
		local p = ground(from + flat.Unit * (i * 3), ignore)
		if p.Y < 0.5 then
			break
		end
		dry = p
	end
	return dry
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if hum and hum.Health > 0 and root and root:IsA("BasePart") then root else nil
end

-- One tick (OperationService, 4 Hz). board(player, at) -> true once the casualty is aboard their craft.
function LandRescue.Step(op: any, dt: number, board: (Player, Vector3) -> boolean)
	local sc = live[op]
	local root = sc and sc.root
	if not (sc and root and root.Parent) then
		return
	end
	local pos = root.Position
	local moved = (pos - sc.last).Magnitude
	sc.last = pos
	if sc.leader and not (table.find(op.members, sc.leader) and rootOf(sc.leader)) then
		sc.leader, sc.follow = nil, LandFollow.new() -- they lost you: wait where they are
		if sc.hum then
			sc.hum:MoveTo(pos)
		end
		play(sc, "Wave")
		setPin(sc, pos)
	end
	for _, player in if sc.leader then { sc.leader } else op.members do
		local proot = rootOf(player)
		if not proot then
			continue
		end
		local craft = craftOf(player)
		-- docs/23 (h): a helicopter hovering (or landed) low and steady near them winches them up, no walk
		if craft and craft:HasTag("Heli") and craft.PrimaryPart then
			local c = craft.PrimaryPart
			local v = c.AssemblyLinearVelocity
			if
				Vector2.new(c.Position.X - pos.X, c.Position.Z - pos.Z).Magnitude
					<= LandFollow.BOARD_RANGE
				and c.Position.Y - pos.Y <= Winch.MAX_HEIGHT
				and Vector2.new(v.X, v.Z).Magnitude <= Board.STEADY_SPEED
				and Board.hasRoom(craft)
				and board(player, pos)
			then
				LandRescue.Cleanup(op)
				return
			end
		end
		local action = LandFollow.step(
			sc.follow,
			dt,
			pos,
			proot.Position,
			craft ~= nil,
			if craft then craft:GetPivot().Position else nil,
			moved
		)
		if action == "start" then
			sc.leader = player
			if sc.ring then
				sc.ring:Destroy()
				sc.ring = nil
			end
			play(sc, "Idle")
			setPin(sc, nil)
		elseif action == "board" then
			if Board.hasRoom(craft) and board(player, pos) then
				LandRescue.Cleanup(op)
			end
		elseif action == "move" and sc.hum then
			sc.hum:MoveTo(shoreToward(pos, proot.Position, { sc.folder, proot.Parent :: Instance })) -- never into the sea
		elseif action == "idle" and sc.hum then
			sc.hum:MoveTo(pos)
		elseif action == "shore" and sc.hum and craft then
			sc.hum:MoveTo(shoreToward(pos, craft:GetPivot().Position, { sc.folder, craft }))
		elseif action == "teleport" and sc.model then
			local behind = (proot.CFrame * CFrame.new(0, 0, 5)).Position
			local ignore: { Instance } = { sc.folder, proot.Parent :: Instance }
			if craft then
				table.insert(ignore, craft)
			end
			local feet = ground(behind, ignore, true)
			if feet.Y < 0.5 then
				feet = ground(proot.Position, ignore, true) -- water behind you (a pier's edge): at your feet
			end
			if feet.Y < 0.5 then
				continue -- you are in the water: they wait on the shore
			end
			sc.model:PivotTo(
				CFrame.lookAt(feet, Vector3.new(proot.Position.X, feet.Y, proot.Position.Z))
					+ Vector3.yAxis * sc.height
			)
			sc.last = sc.model:GetPivot().Position
		end
		if sc.leader then
			break
		end
	end
end

function LandRescue.Cleanup(op: any)
	local sc = live[op]
	if sc then
		live[op] = nil
		setPin(sc, nil)
		sc.folder:Destroy()
	end
end

return LandRescue
