--!strict
-- transport (docs 09 step 9, section 5.7): bring them home. The ambulance pad has a steady blue pin; no panel in play, the crew braces on every hard landing. Hard slams hurt a cold casualty (the
-- server turns `slam` events into condition, cap 6). The server measures conditionAtEnd when the boat
-- reaches home; this client reports when it is home: the boat (any speed) or the player on foot (they landed
-- the casualty and walked up) inside a drop-off zone (Transport.isHome). Controls: drive.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BoatColdOpen =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Boat"):WaitForChild("ColdOpen"))
local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
)

local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local World = require(script.Parent.PIW.World)

local Transport = {}

Transport.HARD_SLAM = 9 -- telemetry slam strength felt as a hard landing -- tune

local function pads(): { BasePart }
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("DropOffs")
	local out = {}
	for _, pad in if folder then folder:GetChildren() else {} do
		if pad:IsA("BasePart") and pad:GetAttribute("DropOff") ~= nil then
			table.insert(out, pad)
		end
	end
	return out
end

-- Home: your own berth's drop-off zone only (docs/23 (p)): the server's rule, OperationService isHome.
function Transport.isHome(p: Vector3): boolean
	return BoatColdOpen.atDropOff(p, Players.LocalPlayer:GetAttribute("BayCFrame"))
end

-- The ambulance at the hospital pontoon, else the station.
local function homePad(): BasePart?
	local dock, hospital
	for _, pad in pads() do
		local name = pad:GetAttribute("DropOff")
		if name == "Dock" then
			dock = pad
		elseif name == "Hospital" then
			hospital = pad
		end
	end
	return hospital or dock
end

-- A steady pin over the pad (art/source/ui/transport_pin.svg: rescue blue, a white cross): no glow, no blink.
local function beacon(pad: BasePart): BasePart
	local b = Instance.new("Part")
	b.Name = "TransportBeacon"
	b.Size = Vector3.one
	b.Transparency = 1
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.Position = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 8, 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Pin"
	gui.Size = UDim2.fromOffset(60, 81) -- 32 pt+ on a phone, the sprite's tip at the anchor
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.LightInfluence = 0
	gui.MaxDistance = 1500
	gui.Parent = b
	local pin = Instance.new("ImageLabel")
	pin.Size = UDim2.fromScale(1, 1)
	pin.BackgroundTransparency = 1
	pin.Image = UiImages.Markers.TransportPin
	pin.ScaleType = Enum.ScaleType.Fit
	pin.Parent = gui
	b.Parent = Workspace
	return b
end

function Transport.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Transport", 72)
	-- no bar in play: the minimap pill counts the drop-off distance down, the medic calls the slams
	s.panel.Visible = false
	if Step.autoStub(s) then
		return Step.cleanup(s)
	end
	local pad = homePad()
	if pad then
		Ui.add(s.bag, beacon(pad))
	end
	local slams = 0
	local function drive()
		Step.heartbeat(s, function()
			local slam = World.slam()
			if slam > Transport.HARD_SLAM then
				slams += 1
			end
			local h = World.hull(World.vehicle(ctx))
			local char = Players.LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local onFoot = hum ~= nil and hum.SeatPart == nil and root ~= nil
			-- home lands them at any speed (at full throttle the jet ski crossed the ring and piled onto the slip)
			local boatHome = h ~= nil and Transport.isHome(h.position)
			local walkedHome = onFoot and root ~= nil and Transport.isHome(root.Position)
			if boatHome or walkedHome then
				Step.finish(s, {
					metrics = {},
					events = if slams > 0 then { slam = slams } else nil,
				})
			end
		end)
	end

	drive()
	return Step.cleanup(s)
end

return Transport
