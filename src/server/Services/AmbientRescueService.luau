--!strict
-- AmbientRescueService (2026-10-21, user: "be able to save random people, not only the ones in a mission"):
-- free-roam swimmers in open water that anyone can pick up. Each one is a mission-less RescueService scene
-- (the same rigged swimmer, drift, waving and VehicleService climb-aboard), boarded by the server with the
-- auto_board rule (Ops/Board.ready: a boat with room within reach takes them at any speed, docs/24 A; the
-- server reads the boat itself, no client input) and paid on delivery to a pad via the scene's onDelivered
-- hook. Smaller pay than a call.
-- sea1 (owner 2026-10-29, "too empty"): Shared.Calls.AmbientMix sets the density: a cap that grows with the
-- server (9 with one player, 24 with six), a lone swimmer, a cluster of 2-3 or a capsized dinghy of two, and
-- IN_SIGHT scenes kept within SIGHT of every player driving at sea (spawned SIGHT_MIN+ out, ahead of the bow).
-- Timed spawns go to the Outer ring or, FAR of the time, off an outer island. Nothing spawns in the lagoon or
-- within HOME_CLEAR of a berth (the coves are the missions'). K13 (docs/16): MOUTH_WANT are always in view off each
-- player's cove mouth. At the cap the oldest scene nobody is near makes way. A cold-open player gets no spawns
-- near them and boards nobody free-roam (their own swimmer comes first). Sight spawns are the added density: they
-- pay the lower tier (AmbientMix.CASH x the Bronze grade); timed and cove-mouth ones pay CASH.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AmbientMix = require(Shared:WaitForChild("Calls"):WaitForChild("AmbientMix"))
local Board = require(Shared:WaitForChild("Ops"):WaitForChild("Board"))
local CallLogic = require(Shared:WaitForChild("Calls"):WaitForChild("CallLogic"))
local CallTypes = require(Shared:WaitForChild("Calls"):WaitForChild("CallTypes"))
local CraftBoard = require(Shared:WaitForChild("Ops"):WaitForChild("CraftBoard"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))

local ProgressionService = require(script.Parent.ProgressionService) :: any
local RescueService = require(script.Parent.RescueService) :: any

local AmbientRescueService = {}

AmbientRescueService.RESPAWN = 20 -- s between timed spawns while under the cap -- tune
AmbientRescueService.MAX_AGE = 360 -- s unrescued before they are swept off (a fresh one spawns elsewhere)
AmbientRescueService.CLEAR = 120 -- studs from any player when one appears (no pop-in beside you)
AmbientRescueService.SPACING = 150 -- studs between free-roam scenes
-- Playtest 2026-10-31 (pta 6): spread 130-570 out, the cove-mouth swimmer sat past the lifebuoy pip's range from
-- the island and nothing drew a new player out. Now two, in a band just past HOME_CLEAR (320-520 from the berth).
AmbientRescueService.MOUTH_OUT = 380 -- studs straight out from a player's berth: just past their cove -- tune
AmbientRescueService.MOUTH_VIEW = 160 -- studs from that point: in view from the island -- tune
AmbientRescueService.MOUTH_WANT = 2 -- swimming scenes kept there -- tune
AmbientRescueService.SIGHT_CHECK = 3 -- s

type Scene = { [string]: any }

local scenes: { Scene } = {}
local nextId = 0
local rng = Random.new()
local FAR_ZONES: { string } = {}
for _, island in WorldConfig.Islands do
	table.insert(FAR_ZONES, island.id)
end

-- The boat the player sits in (seated only: a parked craft never picks anyone up).
local function seatedVehicle(player: Player): Model?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local node: Instance? = hum and hum.Health > 0 and hum.SeatPart or nil
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function remove(scene: Scene)
	local i = table.find(scenes, scene)
	if i then
		table.remove(scenes, i)
	end
	RescueService.Cleanup(scene)
end

local function count(scene: Scene, state: string): number
	local n = 0
	for _, v in scene.victims do
		n += if v.state == state then 1 else 0
	end
	return n
end

local function onDelivered(scene: Scene, n: number, driver: Player?)
	if driver then
		pcall(ProgressionService.Award, driver, scene.pay * n, "AmbientRescue")
	end
	if count(scene, "Water") + count(scene, "Aboard") == 0 then
		remove(scene) -- a cluster stays until its last survivor is home
	end
end

local function playersClear(p: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if
			char
			and CallLogic.flatDistance(char:GetPivot().Position, p) < AmbientRescueService.CLEAR
		then
			return false
		end
	end
	return true
end

-- Off every berth by HOME_CLEAR (the coves are the missions' and the cold open's).
local function homesClear(p: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local bay = player:GetAttribute("BayCFrame")
		if
			typeof(bay) == "CFrame"
			and CallLogic.flatDistance(CallLogic.homeOf(bay), p) < AmbientMix.HOME_CLEAR
		then
			return false
		end
	end
	return true
end

local function clearSpot(p: Vector3): boolean
	if
		not playersClear(p)
		or not homesClear(p)
		or not RescueService.ClearWater(p, RescueService.CLEAR_SPAWN)
	then
		return false
	end
	for _, s in scenes do
		if CallLogic.flatDistance(s.position, p) < AmbientRescueService.SPACING then
			return false
		end
	end
	return true
end

local function roll(): number
	return rng:NextNumber()
end

-- extra: a sight spawn (sea1's added density) pays the Bronze grade share of CASH, the lower tier (ECON1)
local function spawnAt(pos: Vector3, extra: boolean?): Scene
	nextId += 1
	local mix = AmbientMix.pick(roll())
	local scene: Scene = {
		id = `AMB{nextId}`, -- never an op id: PIW_Rescue and OperationService.CanAct ignore it
		kind = mix.kind,
		spec = CallTypes.Kinds[mix.kind],
		position = pos,
		total = mix.total,
		victims = {},
		isBig = false,
		opsDriven = true, -- no hold prompt: the server boards them (below)
		ambient = true,
		bornAt = os.clock(),
		pay = math.floor(AmbientMix.CASH * (if extra then CallTypes.Payout.Grade.Bronze else 1)),
	}
	scene.onDelivered = function(n: number, driver: Player?)
		onDelivered(scene, n, driver)
	end
	RescueService.SpawnCall(scene)
	table.insert(scenes, scene)
	return scene
end

local function spawnOne(): Scene?
	for _ = 1, 8 do
		local zone = if roll() < AmbientMix.FAR
			then FAR_ZONES[rng:NextInteger(1, #FAR_ZONES)]
			else "Outer"
		local pos = CallLogic.pickSpawnPoint(zone, roll)
		if clearSpot(pos) then
			return spawnAt(pos)
		end
	end
	return nil
end

local function swimmingScenes(): { Scene }
	local out = {}
	for _, scene in scenes do
		if count(scene, "Water") > 0 then
			table.insert(out, scene)
		end
	end
	return out
end

type Eye =
	{ at: Vector3, view: number, want: number, ahead: Vector3?, area: string, extra: boolean }

-- Where the server keeps survivors in view: off each cove mouth (K13), and round every player driving at sea.
local function eyes(): { Eye }
	local out: { Eye } = {}
	for _, player in Players:GetPlayers() do
		local bay = player:GetAttribute("BayCFrame")
		if player:GetAttribute("ColdOpenActive") == true or typeof(bay) ~= "CFrame" then
			continue
		end
		local home = CallLogic.homeOf(bay)
		local out1 = (home - CallTypes.STATION).Unit * AmbientRescueService.MOUTH_OUT
		table.insert(out, {
			at = home + out1,
			view = AmbientRescueService.MOUTH_VIEW,
			want = AmbientRescueService.MOUTH_WANT,
			area = "Open",
			extra = false,
		})
		local v = seatedVehicle(player)
		local at = v and v:GetPivot()
		if at and CallLogic.isWater(at.Position, "Open") then
			table.insert(out, {
				at = Vector3.new(at.Position.X, 0, at.Position.Z),
				view = AmbientMix.SIGHT,
				want = AmbientMix.IN_SIGHT,
				ahead = Vector3.new(at.LookVector.X, 0, at.LookVector.Z),
				area = "Open",
				extra = true,
			})
		end
	end
	return out
end

local function inView(scene: Scene, e: Eye): boolean
	return CallLogic.flatDistance(scene.position, e.at) <= e.view
end

-- A spot for an eye: in its view ring, mostly ahead of the bow for a boat.
local function sightSpot(e: Eye): Vector3?
	for _ = 1, 16 do
		local p
		if e.ahead and e.ahead.Magnitude > 0.1 then
			local a = (roll() * 2 - 1) * math.rad(70)
			local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(e.ahead.Unit)
			local r = AmbientMix.SIGHT_MIN + roll() * (e.view - 40 - AmbientMix.SIGHT_MIN)
			p = e.at + d * r
		else
			p = CallLogic.ringPoint(e.at, 40, e.view - 20, roll)
		end
		if CallLogic.isWater(p, e.area) and clearSpot(p) then
			return p
		end
	end
	return nil
end

local function stepSight()
	local list = eyes()
	local swimming = swimmingScenes()
	for _, e in list do
		local seen = 0
		for _, scene in swimming do
			seen += if inView(scene, e) then 1 else 0
		end
		if seen >= e.want then
			continue
		end
		local pos = sightSpot(e)
		if not pos then
			continue
		end
		if #swimming >= AmbientMix.cap(#Players:GetPlayers()) then
			-- make way: the oldest scene out of every view, nobody near, nobody aboard
			local oldest: Scene? = nil
			for _, scene in swimming do
				local watched = false
				for _, o in list do
					watched = watched or inView(scene, o)
				end
				if
					not watched
					and count(scene, "Aboard") == 0
					and playersClear(scene.position)
					and (not oldest or scene.bornAt < oldest.bornAt)
				then
					oldest = scene
				end
			end
			if not oldest then
				return
			end
			remove(oldest)
			table.remove(swimming, table.find(swimming, oldest) :: number)
		end
		table.insert(swimming, spawnAt(pos, e.extra))
		return -- one spawn per check: the sea fills over a few seconds, never in one frame
	end
end

-- Free-roam swimmers still in the water (Bosun's guide points at the nearest: DogService).
function AmbientRescueService.SwimmerPositions(): { Vector3 }
	local out = {}
	for _, scene in scenes do
		for _, p in RescueService.GetTargets(scene) do
			table.insert(out, p)
		end
	end
	return out
end

local held: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any

export type Boat = { player: Player, vehicle: Model, root: BasePart }

-- Every boat a player sits in this tick.
function AmbientRescueService.SeatedBoats(): { Boat }
	local boats: { Boat } = {}
	for _, player in Players:GetPlayers() do
		local v = seatedVehicle(player)
		local root = v and (v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true))
		if v and root then
			table.insert(boats, { player = player, vehicle = v, root = root })
		end
	end
	return boats
end

-- Server-side auto_board for one RescueService scene, measured from the server's view of the boat: a
-- boat with room within reach takes them at once (docs/24 A); the heli winch and the sub still hold
-- steady for Board.HOLD. Free-roam swimmers and every mission (OperationService) use this one rule.
-- may(player, index) filters who may take whom; board(index, player) does the boarding (default:
-- RescueService.BoardVictim).
function AmbientRescueService.StepBoarding(
	scene: Scene,
	dt: number,
	boats: { Boat },
	may: ((Player, number) -> boolean)?,
	board: ((number, Player) -> ())?
)
	for i, victim in scene.victims or {} do
		if victim.state ~= "Water" or not victim.root.Parent then
			held[victim] = nil
			continue
		end
		local ready: Boat? = nil
		local hold = Board.HOLD
		for _, b in boats do
			local at = b.root.Position
			local vel = b.root.AssemblyLinearVelocity
			local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
			local tilt = math.deg(math.acos(math.clamp(b.root.CFrame.UpVector.Y, -1, 1)))
			local id = b.vehicle:GetAttribute("VehicleId")
			if
				CraftBoard.ready( -- boats any speed and tilt; heli winch, sub ring
					id,
					at,
					b.root.Size.X / 2,
					victim.root.Position,
					speed,
					tilt,
					Board.hasRoom(b.vehicle),
					Simulator.waterHeight(at.X, at.Z, Workspace:GetServerTimeNow()),
					tonumber(b.player:GetAttribute("SkillReach")) or 0
				) and (may == nil or may(b.player, i))
			then
				ready = b
				hold = CraftBoard.hold(id)
				break
			end
		end
		if not ready then
			held[victim] = nil
			continue
		end
		local t = (held[victim] or 0) + dt
		held[victim] = t
		if t >= hold then
			held[victim] = nil
			if board then
				board(i, ready.player)
			else
				RescueService.BoardVictim(scene, i, ready.player)
			end
		end
	end
end

local function notColdOpen(player: Player): boolean
	return player:GetAttribute("ColdOpenActive") ~= true
end

local function stepBoarding(dt: number)
	local boats = AmbientRescueService.SeatedBoats()
	for _, scene in scenes do
		AmbientRescueService.StepBoarding(scene, dt, boats, notColdOpen)
	end
end

local function stepLife()
	local now = os.clock()
	for _, scene in table.clone(scenes) do
		local water, aboard = count(scene, "Water"), count(scene, "Aboard")
		-- boarding failed (no room after all), or nobody came for them in time
		if
			water + aboard == 0
			or (aboard == 0 and now - scene.bornAt > AmbientRescueService.MAX_AGE)
		then
			remove(scene)
		end
	end
	if #swimmingScenes() < AmbientMix.cap(#Players:GetPlayers()) and #Players:GetPlayers() > 0 then
		spawnOne()
	end
end

function AmbientRescueService.Start()
	local boardAccum, lifeAccum = 0, AmbientRescueService.RESPAWN - 10 -- the first one about 10 s in
	local sightAccum = 0
	RunService.Heartbeat:Connect(function(dt)
		sightAccum += dt
		if sightAccum >= AmbientRescueService.SIGHT_CHECK then
			sightAccum = 0
			stepSight()
		end
		boardAccum += dt
		if boardAccum >= 0.1 then
			stepBoarding(boardAccum)
			boardAccum = 0
		end
		lifeAccum += dt
		if lifeAccum >= AmbientRescueService.RESPAWN then
			lifeAccum = 0
			stepLife()
		end
	end)
end

return AmbientRescueService
