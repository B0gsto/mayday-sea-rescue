--!strict
-- transport (docs 09 step 9, section 5.7): bring them home. The ambulance pad is lit (a blinking blue
-- beacon); no panel in play, the crew braces on every hard landing. Hard slams hurt a cold casualty (the
-- server turns `slam` events into condition, cap 6). The server measures conditionAtEnd when the boat
-- reaches a pad; this client reports when it is home: the boat slow and close to a pad or a
-- shore point (station slipway, Haven Sands), or the player ashore on foot at one (they landed the
-- casualty and walked up; the step used to hang until its timeout then). Controls: drive.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Board =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("Board"))
local BoatColdOpen =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Boat"):WaitForChild("ColdOpen"))

local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Transport = {}

Transport.HARD_SLAM = 9 -- telemetry slam strength felt as a hard landing -- tune
Transport.PAD_RANGE = 60 -- studs from a drop-off pad, slow: alongside

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

local function nearestPad(p: Vector3): (Vector3?, number)
	local best: Vector3?, bestD = nil, math.huge
	for _, pad in pads() do
		local d = Units.flatDistance(pad.Position, p)
		if d < bestD then
			best, bestD = pad.Position, d
		end
	end
	return best, bestD
end

-- Home: by a drop-off pad or at a shore point (where the first mission lands its casualty).
function Transport.isHome(p: Vector3): boolean
	local _, d = nearestPad(p)
	local _, shore = BoatColdOpen.nearestShore(p)
	return d <= Transport.PAD_RANGE or shore <= BoatColdOpen.SHORE_RADIUS
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

-- A code-built blinking blue beacon over the pad.
local function beacon(pad: BasePart): BasePart
	local b = Instance.new("Part")
	b.Name = "TransportBeacon"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * 3
	b.Material = Enum.Material.Neon
	b.Color = Color3.fromRGB(40, 110, 255)
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CastShadow = false
	b.Position = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 8, 0)
	local light = Instance.new("PointLight")
	light.Color = b.Color
	light.Range = 40
	light.Brightness = 4
	light.Parent = b
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
	local state = ctx.casualty and ctx.casualty.state
	local cold = state == "VeryCold" or state == "Unresponsive" or state == "Exhausted"
	local pad = homePad()
	local lamp = if pad then Ui.add(s.bag, beacon(pad)) else nil
	local slams = 0
	-- a full craft (docs/16 B4): survivors still waiting near you show a red ring (no room, come back)
	local rings: { [Model]: Highlight } = {}
	Ui.add(s.bag, function()
		for _, r in rings do
			r:Destroy()
		end
	end)
	local function ringWaiting(h: World.Hull?)
		local craft = h and h.root:FindFirstAncestorOfClass("Model")
		local full = craft ~= nil and not Board.hasRoom(craft)
		local folder = Workspace:FindFirstChild("CallProps")
		for _, m in if folder then folder:GetChildren() else {} do
			local at = m:IsA("Model") and m.Name == "Victim" and m.PrimaryPart
			if not at or m:GetAttribute("CallId") ~= ctx.operation.id then
				continue
			end
			local show = full
				and h ~= nil
				and m:GetAttribute("OnVehicle") == nil
				and Units.flatDistance(h.position, at.Position) <= Board.REACH * 4
			local model = m :: Model
			if show and not rings[model] then
				local ring = Instance.new("Highlight")
				ring.FillTransparency = 1
				ring.OutlineColor = Color3.fromRGB(230, 70, 60)
				ring.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				ring.Parent = model
				rings[model] = ring
			end
			if rings[model] then
				rings[model].Enabled = show
			end
		end
	end

	local function drive()
		Step.heartbeat(s, function()
			if lamp then
				lamp.Transparency = if os.clock() % 0.8 < 0.4 then 0 else 0.9
			end
			local slam = World.slam()
			if slam > Transport.HARD_SLAM then
				slams += 1
				if cold then
					s.say(
						if slams == 1
							then 'Medic: "Easy! They\'re very cold."'
							else 'Medic: "Ease off on the crests!"'
					)
				end
				Ui.hands("brace")
			end
			local h = World.hull(World.vehicle(ctx))
			ringWaiting(h)
			local char = Players.LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local onFoot = hum ~= nil and hum.SeatPart == nil and root ~= nil
			local boatHome = h ~= nil and h.velocity.Magnitude < 8 and Transport.isHome(h.position)
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
