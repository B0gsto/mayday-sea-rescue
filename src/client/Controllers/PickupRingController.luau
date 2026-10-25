--!strict
-- PickupRingController (docs/23 e.1, WP-2): "slow down here" reads from the water. Every survivor still in the
-- water (Workspace.CallProps "Victim" with Survivor and no OnVehicle; PrivateCasualtyController already unparents
-- other crews' casualties) gets an orange ring of Board.RING on the water: missions, free-roam and big calls alike.
-- It dims grey while the craft you sit in is full (the seat pips say why) and goes once they are aboard. They
-- wave on their own (RescueService "Wave" pose with a boat in sight, CasualtyController).
-- Assist(craft, throttle, brakeDecel): BoatController runs the driven hull's throttle through it, so a craft with
-- room slows itself to Board.ASSIST_SPEED by the nearest ring (Board.assistThrottle) and keys, stick and
-- touch all get the same docking assist; out of the ring the player's throttle is untouched.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Ops"):WaitForChild("Board"))
local Weather = require(Shared:WaitForChild("Weather"))

local PickupRingController = {}

local ORANGE = Color3.fromRGB(255, 140, 30)
local GREY = Color3.fromRGB(150, 150, 150)
local BAND = 1.4 -- studs wide: reads from far -- tune

local rings: { [Model]: CylinderHandleAdornment } = {}
local folder: Folder? = nil

local function seatedCraft(): Model?
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local node: Instance? = hum and hum.SeatPart
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function waiting(m: Instance): boolean
	return m:IsA("Model")
		and m.Name == "Victim"
		and m:GetAttribute("Survivor") == true
		and m:GetAttribute("OnVehicle") == nil
		and m.PrimaryPart ~= nil
end

local function newRing(): CylinderHandleAdornment
	local p = Instance.new("Part")
	p.Name = "PickupRing"
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = folder
	local band = Instance.new("CylinderHandleAdornment")
	band.Adornee = p
	band.Height = 0.1
	band.Radius = Board.RING
	band.InnerRadius = Board.RING - BAND
	band.CFrame = CFrame.Angles(math.pi / 2, 0, 0) -- the cylinder's axis (Z) up
	band.Parent = p
	return band
end

local function step()
	local props = Workspace:FindFirstChild("CallProps")
	local craft = seatedCraft()
	local full = craft ~= nil and not Board.hasRoom(craft)
	local seen: { [Model]: boolean } = {}
	for _, m in if props then props:GetChildren() else {} do
		if waiting(m) then
			local v = m :: Model
			seen[v] = true
			local band = rings[v] or newRing()
			rings[v] = band
			local at = (v.PrimaryPart :: BasePart).Position
			local ok, h = pcall(Weather.heightAt, at)
			local anchor = band.Adornee :: BasePart
			anchor.CFrame =
				CFrame.new(at.X, (if ok and type(h) == "number" then h else at.Y) + 0.15, at.Z)
			band.Color3 = if full then GREY else ORANGE
			band.Transparency = if full then 0.7 else 0.15
		end
	end
	for v, band in rings do
		if not seen[v] then
			(band.Adornee :: Instance):Destroy()
			rings[v] = nil
		end
	end
end

-- The throttle the driven craft gets near the nearest waiting survivor (unchanged with no room or none near).
function PickupRingController.Assist(craft: Model, input: number, brakeDecel: number?): number
	local root = craft.PrimaryPart
	if not root or not Board.hasRoom(craft) then
		return input
	end
	local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
	local best: Vector3? = nil
	for v in rings do
		local p = v.PrimaryPart
		if p and v.Parent then
			local d = Vector3.new(p.Position.X, 0, p.Position.Z) - pos
			if not best or d.Magnitude < (best :: Vector3).Magnitude then
				best = d
			end
		end
	end
	if not best then
		return input
	end
	local to = best :: Vector3
	local dist = to.Magnitude
	local vel = root.AssemblyLinearVelocity
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local forward = if flatLook.Magnitude > 1e-3 then vel:Dot(flatLook.Unit) else 0
	local closing = if dist > 0.5 then vel:Dot(to.Unit) else forward
	return Board.assistThrottle(input, dist, closing, forward, brakeDecel or 16)
end

function PickupRingController.Init() end

function PickupRingController.Start()
	local f = Instance.new("Folder")
	f.Name = "PickupRings"
	f.Parent = Workspace
	folder = f
	RunService.Heartbeat:Connect(step)
end

return PickupRingController
