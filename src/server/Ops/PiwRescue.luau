--!strict
-- PiwRescue: the server half of a survivor answering the boat that comes for them (docs/14 section 3;
-- client: src/client/Mechanics/auto_board.luau). Remote Net.PIW_Rescue, C->S (opId, casualtyIndex, action):
--   "arm"    the recovery step started: the casualty now answers this rescuer (10 s rule)
--   "bump"   auto_board: the boat ran into them (checked: fast and close), they are knocked back (from
--            rank Board.KNOCK_RANK up)
-- A full craft (docs/20 change 8) takes nobody: they tread water WAIT_GAP off and wave (mode "wait")
-- instead of clinging to its side, and come in once there is a seat again.
-- RescueService's drift step asks `velocity` for each victim and moves the floater with it.
-- The victim model's PiwMode attribute (idle | swim | held | wait) tells the clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Board =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("Board"))
local PiwWays = require(script.Parent.PiwWays)

local PiwRescue = {}

PiwRescue.REMOTE = "PIW_Rescue"
PiwRescue.MIN_INTERVAL = 0.2 -- s between a player's events
-- The cold open (docs/16 B0): the player drives up to them, so the come-anyway clock (PiwWays
-- COME_DEADLINE) starts this much later; before, they swam over during the opening shot. -- tune
PiwRescue.COLD_OPEN_GRACE = 30
PiwRescue.WAIT_GAP = 15 -- studs (5 m) a swimmer keeps from a full craft -- tune

type Engaged = { player: Player, ways: PiwWays.State, bumpUntil: number?, bumpVel: Vector3? }

local engaged: { [any]: Engaged } = setmetatable({}, { __mode = "k" }) :: any -- victim -> rescuer
local lastEvent: { [Player]: number } = {}

-- The rescuer's position: the boat they sit in, else their character. (position, speed, onBoat, boat)
local function rescuerOf(player: Player): (Vector3?, number, boolean, Model?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		return nil, 0, false
	end
	local node: Instance? = hum.SeatPart
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			local root = node.PrimaryPart
			local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
			return node:GetPivot().Position, speed, true, node :: Model
		end
		node = node.Parent
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position, hrp.AssemblyLinearVelocity.Magnitude, false
	end
	return nil, 0, false
end

local function setMode(victim: any, mode: string)
	if victim.model and victim.model:GetAttribute("PiwMode") ~= mode then
		victim.model:SetAttribute("PiwMode", mode)
	end
end

-- The victim's flat velocity this tick while it answers a rescuer, else nil (normal drift).
function PiwRescue.velocity(victim: any, dt: number): Vector3?
	local e = engaged[victim]
	if not e then
		return nil
	end
	if victim.state ~= "Water" or not e.player.Parent then
		engaged[victim] = nil
		return nil
	end
	if e.bumpUntil and Workspace:GetServerTimeNow() < e.bumpUntil then
		return e.bumpVel
	end
	local pos, speed, onBoat, boat = rescuerOf(e.player)
	if not pos then
		return Vector3.zero -- respawning: they tread water and wait
	end
	local f = victim.floater
	if boat and not Board.hasRoom(boat) then
		-- no seat: back off to WAIT_GAP and wave; a fresh start once a seat frees up
		e.ways = PiwWays.new()
		e.ways.since = Workspace:GetServerTimeNow()
		setMode(victim, "wait")
		local away = Vector3.new(f.x - pos.X, 0, f.z - pos.Z)
		local short = PiwRescue.WAIT_GAP - away.Magnitude
		return if short > 0 and away.Magnitude > 1e-3
			then away.Unit * math.min(PiwWays.SWIM_SPEED * 2, short / math.max(dt, 1e-3))
			else Vector3.zero
	end
	local vel = PiwWays.step(
		e.ways,
		Workspace:GetServerTimeNow(),
		Vector3.new(f.x, 0, f.z),
		pos,
		speed,
		onBoat,
		dt
	)
	setMode(victim, e.ways.mode)
	return vel
end

local function onEvent(
	player: Player,
	liveCalls: { [any]: boolean },
	canAct: (any, Player) -> boolean,
	opId: any,
	index: any,
	action: any
)
	if type(opId) ~= "string" or type(index) ~= "number" or type(action) ~= "string" then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now - (lastEvent[player] or 0) < PiwRescue.MIN_INTERVAL then
		return
	end
	lastEvent[player] = now
	local call: any = nil
	for c in liveCalls do
		if c.id == opId then
			call = c
			break
		end
	end
	local victim = call and type(call.victims) == "table" and call.victims[index]
	if not victim or victim.state ~= "Water" or victim.floater.parent then
		return
	end
	local ok, allowed = pcall(canAct, call, player)
	if not ok or not allowed then
		return
	end
	local e = engaged[victim]
	if action == "arm" then
		if not e or e.player ~= player then
			local ways = PiwWays.new()
			-- the idle clock: they come anyway COME_DEADLINE after the arm
			ways.since = now
				+ (
					if player:GetAttribute("ColdOpenActive") == true
						then PiwRescue.COLD_OPEN_GRACE
						else 0
				)
			engaged[victim] = { player = player, ways = ways }
			setMode(victim, "idle")
		end
		return
	end
	if not e or e.player ~= player then
		return -- not armed by this rescuer
	end
	local pos, speed, onBoat = rescuerOf(player)
	if not pos then
		return
	end
	local cas = Vector3.new(victim.floater.x, 0, victim.floater.z)
	if action == "bump" and Board.knocks(player:GetAttribute("RankIndex")) then
		local away = cas - Vector3.new(pos.X, 0, pos.Z)
		if onBoat and speed > PiwWays.STOPPED and away.Magnitude < 16 and away.Magnitude > 1e-3 then
			e.bumpUntil = now + 0.8
			e.bumpVel = away.Unit * 10
			e.ways = PiwWays.new()
			e.ways.since = now
		end
	end
	setMode(victim, e.ways.mode)
end

function PiwRescue.start(liveCalls: { [any]: boolean }, canAct: (any, Player) -> boolean)
	local net = ReplicatedStorage:FindFirstChild("Net")
	if not net then
		net = Instance.new("Folder")
		net.Name = "Net"
		net.Parent = ReplicatedStorage
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = PiwRescue.REMOTE
	remote.Parent = net
	remote.OnServerEvent:Connect(function(player, opId, index, action)
		onEvent(player, liveCalls, canAct, opId, index, action)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastEvent[player] = nil
	end)
end

return PiwRescue
