--!strict
-- AmbientRescueService (2026-10-21, user: "be able to save random people, not only the ones in a mission"):
-- free-roam swimmers in open water that anyone can pick up. Each one is a mission-less RescueService scene
-- (the same rigged swimmer, drift, waving and VehicleService climb-aboard), boarded by the server with the
-- auto_board rule (Ops/Board.ready: close, slow, level, room aboard; the server reads the boat itself, no
-- client input) and paid on delivery to a pad via the scene's onDelivered hook. Smaller pay than a call.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Ops"):WaitForChild("Board"))
local CallLogic = require(Shared:WaitForChild("Calls"):WaitForChild("CallLogic"))
local CallTypes = require(Shared:WaitForChild("Calls"):WaitForChild("CallTypes"))

local ProgressionService = require(script.Parent.ProgressionService) :: any
local RescueService = require(script.Parent.RescueService) :: any

local AmbientRescueService = {}

AmbientRescueService.CAP = 4 -- free-roam swimmers in the water server-wide -- tune
AmbientRescueService.RESPAWN = 45 -- s between spawns while under the cap -- tune
AmbientRescueService.MAX_AGE = 360 -- s unrescued before they are swept off (a fresh one spawns elsewhere)
AmbientRescueService.CLEAR = 120 -- studs from any player when one appears (no pop-in beside you)
AmbientRescueService.SPACING = 150 -- studs between free-roam swimmers
AmbientRescueService.CASH = 120 -- per survivor delivered (a Silver call pays 550)
AmbientRescueService.REP = 25
AmbientRescueService.ZONES = { "Near", "CalmBay", "CalmBay", "Outer" }

type Scene = { [string]: any }

local scenes: { Scene } = {}
local nextId = 0
local rng = Random.new()

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

local function onDelivered(scene: Scene, count: number, driver: Player?)
	if driver then
		pcall(
			ProgressionService.Award,
			driver,
			AmbientRescueService.CASH * count,
			AmbientRescueService.REP * count,
			"AmbientRescue"
		)
	end
	remove(scene)
end

local function clearSpot(p: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if
			char
			and CallLogic.flatDistance(char:GetPivot().Position, p) < AmbientRescueService.CLEAR
		then
			return false
		end
	end
	for _, s in scenes do
		if CallLogic.flatDistance(s.position, p) < AmbientRescueService.SPACING then
			return false
		end
	end
	return true
end

local function spawnOne(): Scene?
	for _ = 1, 8 do
		local zones = AmbientRescueService.ZONES
		local pos = CallLogic.pickSpawnPoint(zones[rng:NextInteger(1, #zones)], function()
			return rng:NextNumber()
		end)
		if clearSpot(pos) then
			nextId += 1
			local spec = CallTypes.Kinds.Swimmer
			local scene: Scene = {
				id = `AMB{nextId}`, -- never an op id: PIW_Rescue and OperationService.CanAct ignore it
				kind = "Swimmer",
				spec = spec,
				position = pos,
				total = 1,
				victims = {},
				isBig = false,
				opsDriven = true, -- no hold prompt: the server boards them (below)
				ambient = true,
				bornAt = os.clock(),
			}
			scene.onDelivered = function(count: number, driver: Player?)
				onDelivered(scene, count, driver)
			end
			RescueService.SpawnCall(scene)
			table.insert(scenes, scene)
			return scene
		end
	end
	return nil
end

local held: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Server-side auto_board: the same rule the mission mechanic uses, measured from the server's view of the boat.
local function stepBoarding(dt: number)
	local boats: { { player: Player, vehicle: Model, root: BasePart } } = {}
	for _, player in Players:GetPlayers() do
		local v = seatedVehicle(player)
		local root = v and (v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true))
		if v and root then
			table.insert(boats, { player = player, vehicle = v, root = root })
		end
	end
	for _, scene in scenes do
		for i, victim in scene.victims do
			if victim.state ~= "Water" or not victim.root.Parent then
				held[victim] = nil
				continue
			end
			local ready: { player: Player, vehicle: Model, root: BasePart }? = nil
			for _, b in boats do
				local gap = math.max(
					0,
					CallLogic.flatDistance(b.root.Position, victim.root.Position)
						- b.root.Size.X / 2
				)
				local vel = b.root.AssemblyLinearVelocity
				local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
				local tilt = math.deg(math.acos(math.clamp(b.root.CFrame.UpVector.Y, -1, 1)))
				if Board.ready(gap, speed, tilt, Board.hasRoom(b.vehicle)) then
					ready = b
					break
				end
			end
			if not ready then
				held[victim] = nil
				continue
			end
			local t = (held[victim] or 0) + dt
			held[victim] = t
			if t >= Board.HOLD then
				held[victim] = nil
				RescueService.BoardVictim(scene, i, ready.player)
			end
		end
	end
end

local function stepLife()
	local now = os.clock()
	for _, scene in table.clone(scenes) do
		local v = scene.victims[1]
		-- boarding failed (no room after all), or nobody came for them in time
		if
			not v
			or v.state == "Recovered"
			or (v.state == "Water" and now - scene.bornAt > AmbientRescueService.MAX_AGE)
		then
			remove(scene)
		end
	end
	local swimming = 0
	for _, scene in scenes do
		local v = scene.victims[1]
		if v and v.state == "Water" then
			swimming += 1
		end
	end
	if swimming < AmbientRescueService.CAP and #Players:GetPlayers() > 0 then
		spawnOne()
	end
end

function AmbientRescueService.Start()
	local boardAccum, lifeAccum = 0, AmbientRescueService.RESPAWN - 10 -- the first one about 10 s in
	RunService.Heartbeat:Connect(function(dt)
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
