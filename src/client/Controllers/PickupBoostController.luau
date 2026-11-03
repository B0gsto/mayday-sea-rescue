--!strict
-- PickupBoostController (docs/29 C): the pick-up boost's wake on your own craft. The speed itself is the craft
-- handling's (PickupBoostUntil on the craft); this reads the same stamp on the player. VFX: pickup_boost + a small
-- nitro_ring once, with the sound; pickup_wake while it lasts, off under Reduce motion. On the water under the stern,
-- so every craft reads. A cluster boarding at once gets one burst.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Simulator =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Boat"):WaitForChild("Simulator"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local PickupBoostController = {}

local WAKE_GAP = 0.3 -- s between pickup_wake bursts -- tune
local BURST_GAP = 1 -- s: a survivor within this of the last gets no second burst -- tune

local player = Players.LocalPlayer
local playing = 0 -- the latest boost's stamp: a new pick-up takes the wake over

local function stern(): (CFrame?, CFrame?)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local craft = seat and seat:FindFirstAncestorOfClass("Model")
	local root = craft and craft.PrimaryPart
	if not (craft and root) then
		return nil, nil
	end
	local back = -root.CFrame.LookVector
	local at = root.Position + back * craft:GetExtentsSize().Z * 0.45
	local water = Simulator.waterHeight(at.X, at.Z, Workspace:GetServerTimeNow())
	local pos = Vector3.new(at.X, water, at.Z)
	local up = (back + Vector3.yAxis * 0.6).Unit -- the emitters fire along the up axis
	return CFrame.fromMatrix(pos, root.CFrame.RightVector, up), CFrame.new(pos)
end

local function onBoost()
	local stamp = player:GetAttribute("PickupBoostUntil")
	if type(stamp) ~= "number" then
		return
	end
	local fresh = stamp - playing > BURST_GAP
	playing = stamp
	local jet, flat = stern()
	if jet and flat and fresh then
		VFXKit.play("pickup_boost", jet)
		VFXKit.play("nitro_ring", flat, { scale = 0.7, still = true })
	end
	if Comfort.reducedMotion() then
		return
	end
	while playing == stamp and Workspace:GetServerTimeNow() < stamp do
		task.wait(WAKE_GAP)
		local spray = stern()
		if spray and playing == stamp then
			VFXKit.play("pickup_wake", spray, { still = true })
		end
	end
end

function PickupBoostController.Init() end

function PickupBoostController.Start()
	player:GetAttributeChangedSignal("PickupBoostUntil"):Connect(onBoost)
end

return PickupBoostController
