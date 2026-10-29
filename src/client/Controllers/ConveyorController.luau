--!strict
-- ConveyorController (convey1): the client side of the belts (src/server/World/Conveyors.luau). Every lane (tag
-- BeltLane, picked up as it streams in) gets its AssemblyLinearVelocity re-applied here: your character is simulated
-- on your client, so the push never waits on replication. The lanes near the camera scroll their chevrons and studs
-- at the belt's own speed (a rider sees the floor hold still under them). One looped hum (Amb_Belt, Ambience group)
-- sits on an emitter moved to the nearest belt point, so a single Sound covers every belt; it stops out of range.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AudioConfig")
)
local AudioController = require(script.Parent:WaitForChild("AudioController"))

local ConveyorController = {}

local TAG = "BeltLane"
local NEAR = 260 -- studs from the camera: lanes that scroll
local HUM_RANGE = 30 -- the hum's rolloff
local SCROLL = -1 -- Texture V runs opposite the lane's LookVector on its Top face

local lanes: { [BasePart]: { Texture } } = {}
local near: { BasePart } = {}
local shift = 0
local speed = 0

local function add(p: Instance)
	if not p:IsA("BasePart") then
		return
	end
	speed = tonumber(p:GetAttribute("BeltSpeed")) or speed
	p.AssemblyLinearVelocity = p.CFrame.LookVector * speed
	local tex = {}
	for _, c in p:GetChildren() do
		if c:IsA("Texture") then
			table.insert(tex, c)
		end
	end
	lanes[p] = tex
end

local function closest(p: BasePart, at: Vector3): Vector3
	local l, h = p.CFrame:PointToObjectSpace(at), p.Size / 2
	return p.CFrame:PointToWorldSpace(
		Vector3.new(
			math.clamp(l.X, -h.X, h.X),
			math.clamp(l.Y, -h.Y, h.Y),
			math.clamp(l.Z, -h.Z, h.Z)
		)
	)
end

function ConveyorController.Init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(p)
		lanes[p :: BasePart] = nil
	end)
	for _, p in CollectionService:GetTagged(TAG) do
		add(p)
	end
end

function ConveyorController.Start()
	RunService.RenderStepped:Connect(function(dt: number)
		shift = (shift + dt * speed) % 8 -- 8: the studs tile; the chevron's 4 divides it
		for _, p in near do
			local tex = lanes[p]
			if tex then
				for _, t in tex do
					t.OffsetStudsV = SCROLL * shift
				end
			end
		end
	end)

	local emitter = Instance.new("Attachment")
	emitter.Name = "BeltHum"
	emitter.Parent = Workspace.Terrain
	local hum = AudioController.newSound("Amb_Belt", emitter, true)
	hum.RollOffMinDistance, hum.RollOffMaxDistance = 6, HUM_RANGE
	hum.Volume = AudioConfig.Clips.Amb_Belt.volume
	local tick = 0
	while true do
		task.wait(0.1)
		local cam = Workspace.CurrentCamera
		if not cam then
			continue
		end
		tick += 1
		if tick % 5 == 1 then -- the scroll list, twice a second
			table.clear(near)
			for p in lanes do
				if
					p.Parent
					and (closest(p, cam.Focus.Position) - cam.Focus.Position).Magnitude < NEAR
				then
					table.insert(near, p)
				end
			end
		end
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local from = if root then root.Position else cam.Focus.Position
		local best, bestD = nil :: Vector3?, HUM_RANGE + 4
		for _, p in near do
			local q = closest(p, from)
			local d = (q - from).Magnitude
			if d < bestD then
				best, bestD = q, d
			end
		end
		if best then
			emitter.WorldPosition = best
			if not hum.IsPlaying then
				hum:Play()
			end
		elseif hum.IsPlaying then
			hum:Stop()
		end
	end
end

return ConveyorController
