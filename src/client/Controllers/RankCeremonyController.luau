--!strict
-- RankCeremonyController: the promotion beat (docs 03 section 3, docs 04 the unveil). A rank-up
-- clears the HUD for one clip-worthy beat: the rank badge scales in at screen centre, the nearest
-- NPCs turn and salute, red and green flares arc up, the station bell rings, confetti pops and the
-- camera pulls back in a short orbit (skipped in a fast boat). The badge then flies to the rank
-- bar. Service Stars get the smaller star-and-count beat. Any input skips it; nothing blocks play
-- beyond the beat and the old floating board is gone. The snapshot's rankUp / starUp extras are
-- still the only trigger (ProgressionService), so joining never replays it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local RankBadge = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("RankBadge"))
local RankCeremony = require(Shared:WaitForChild("RankCeremony"))
local RankFx = require(script.Parent.Parent:WaitForChild("FX"):WaitForChild("RankFx"))

local RankCeremonyController = {}
RankCeremonyController.Priority = 95

local player = Players.LocalPlayer

type Beat = {
	kind: string,
	rankIndex: number,
	name: string,
	stars: number?,
	icons: { string },
}

local queue: { Beat } = {}
local busy = false
local stopCurrent: (() -> ())? = nil

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A fast boat keeps its helm view: the camera beat is dropped, the badge and world FX stay.
local function speedNow(): number
	local root = rootPart()
	local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local node: Instance? = seat and seat.Parent
	while node and node ~= Workspace do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			local primary = node.PrimaryPart
			if primary then
				speed = math.max(speed, primary.AssemblyLinearVelocity.Magnitude)
			end
			break
		end
		node = node.Parent
	end
	return speed
end

-- A 1.5 s pull-back orbit around the player, in two eased arcs.
local function cameraBeat(root: BasePart): any?
	if Comfort.reducedMotion() or not RankCeremony.orbitNeeded(speedNow()) then
		return nil
	end
	local ok, mode = pcall(CameraController.GetMode)
	if ok and mode == "Cinematic" then
		return nil
	end
	local subject = root.Parent
	if not subject then
		return nil
	end
	local handle = CameraController.PlayCinematic({
		{
			from = {
				subject = subject,
				offset = Vector3.new(-4, 2.6, 5),
				look = Vector3.new(0, 2.2, 0),
			},
			to = {
				subject = subject,
				offset = Vector3.new(12, 4.2, 12),
				look = Vector3.new(0, 2.2, 0),
			},
			duration = 0.75,
			fov = 55,
			toFov = 50,
		},
		{
			from = {
				subject = subject,
				offset = Vector3.new(12, 4.2, 12),
				look = Vector3.new(0, 2.2, 0),
			},
			to = {
				subject = subject,
				offset = Vector3.new(6, 4.8, -12),
				look = Vector3.new(0, 2.2, 0),
			},
			duration = 0.75,
			fov = 50,
			toFov = 55,
		},
	}, { skippable = false })
	return handle
end

local function bell()
	for i = 0, 2 do
		task.delay(i * 0.55, function()
			AudioController.play("Bell_Buoy", nil, 0.9, 0.75 + i * 0.08)
		end)
	end
	task.delay(1.5, function()
		AudioController.play("Rank_Cheer", nil, 1, 1)
	end)
end

local startedAt = 0

local function play(beat: Beat)
	local root = rootPart()
	if not root then
		return
	end
	local at = root.Position
	local right = root.CFrame.RightVector
	local alive = true
	local cleanups: { () -> () } = {}
	local function finish()
		if not alive then
			return
		end
		alive = false
		local list = cleanups
		cleanups = {}
		for _, f in list do
			pcall(f)
		end
		if stopCurrent == finish then
			stopCurrent = nil
		end
	end
	stopCurrent = finish
	startedAt = os.clock()

	local badge = RankBadge.play({
		kind = beat.kind,
		rankIndex = beat.rankIndex,
		name = beat.name,
		stars = beat.stars,
		icons = beat.icons,
	})
	table.insert(cleanups, badge.stop)

	-- Reduce motion: the badge and salute stay; the arcing flares and confetti pop are skipped.
	if not Comfort.reducedMotion() then
		local stopFlares = RankFx.flares(at + Vector3.new(0, 1.2, 0), right)
		table.insert(cleanups, stopFlares)
		local stopConfetti =
			RankFx.confetti(at + Vector3.new(0, 5, 0), RankCeremony.colour(beat.rankIndex))
		table.insert(cleanups, stopConfetti)
	end
	local stopSalute = RankFx.salute(at)
	table.insert(cleanups, stopSalute)

	if beat.kind == "rank" then
		local camera = cameraBeat(root)
		if camera then
			table.insert(cleanups, camera.stop)
		end
	end

	bell()

	local t = 0
	while alive and t < badge.duration do
		t += task.wait(0.1)
	end
	finish()
end

local function pump()
	if busy or #queue == 0 then
		return
	end
	busy = true
	task.spawn(function()
		while #queue > 0 do
			local beat: Beat? = table.remove(queue, 1)
			if beat then
				play(beat)
			end
		end
		busy = false
	end)
end

local function onData(data: any)
	if type(data) ~= "table" then
		return
	end
	local rankIndex = math.clamp(tonumber(data.rankIndex) or 1, 1, #ProgressionConfig.Ranks)
	if type(data.rankUp) == "table" then
		local index =
			math.clamp(tonumber(data.rankUp.rankIndex) or rankIndex, 1, #ProgressionConfig.Ranks)
		table.insert(queue, {
			kind = "rank",
			rankIndex = index,
			name = tostring(data.rankUp.rank or ProgressionConfig.Ranks[index].displayName),
			icons = RankCeremony.unlockIcons(index),
		})
	end
	if type(data.starUp) == "table" then
		table.insert(queue, {
			kind = "star",
			rankIndex = rankIndex,
			name = "",
			stars = tonumber(data.starUp.stars) or 1,
			icons = {},
		})
	end
	pump()
end

-- Dev board: replays the rank-up beat for a rank (no progress change).
function RankCeremonyController.Replay(rankIndex: number)
	onData({ rankIndex = rankIndex, rankUp = { rankIndex = rankIndex } })
end

function RankCeremonyController.Init()
	Net.event("PlayerDataChanged").OnClientEvent:Connect(onData)
	-- Any input (keyboard, touch, gamepad) skips the beat and drops a queued one.
	-- (not the click that started it: a GUI-handled input or one in the first half second)
	UserInputService.InputBegan:Connect(function(_, gameProcessed: boolean)
		if stopCurrent and not gameProcessed and os.clock() - startedAt > 0.5 then
			table.clear(queue)
			stopCurrent()
		end
	end)
end

return RankCeremonyController
