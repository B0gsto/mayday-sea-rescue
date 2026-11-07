--!strict
-- SeaZoneController (docs/29 B, Shared.Calls.SeaZones): which sea you are in, read a few times a second.
--   * the player attribute SeaZone (1..5); the water, fog and light blend by distance in WeatherController
--   * VFX job, state: the pooled buoy line as a soft marker, only the stretch near you (24 buoys, built once, moved
--     only when they fall off the window; slot k is always buoy k % POOL + 1). No curtain (owner 2026-11-07).
--   * VFX job, feedback: one banner pop per crossing (zone name, best rarity gem, a chime); Toast respects Reduce motion
-- The cold open keeps its own look: no line, banner or tint while it runs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local SeaBuoy = require(Client:WaitForChild("Ocean"):WaitForChild("SeaBuoy"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeaZones = require(Shared:WaitForChild("Calls"):WaitForChild("SeaZones"))
local Kit = Client:WaitForChild("UI"):WaitForChild("Kit")
local Style = require(Kit:WaitForChild("Style"))
local Toast = require(Kit:WaitForChild("Toast"))

local SeaZoneController = {}

local CHECK_EVERY = 0.25 -- s: a jet ski covers 20 studs, under a quarter of the buoy spacing
local HIDDEN = CFrame.new(0, -500, 0)
local player = Players.LocalPlayer

local folder: Folder? = nil
local buoys: { SeaBuoy.Buoy } = {}
local shownLine: number? = nil
local slots: { [number]: number } = {} -- buoy index -> the slot it stands on
local zone: number? = nil
local canvas: Frame? = nil

local function buildPool(): Folder
	local f = Instance.new("Folder")
	f.Name = "SeaZoneLine"
	for i = 1, SeaZones.POOL do
		buoys[i] = SeaBuoy.new(f)
	end
	folder = f
	return f
end

local function hideLine()
	if folder then
		folder.Parent = nil
	end
end

local function showLine(line: number, centre: number)
	local f = folder or buildPool()
	f.Parent = Workspace
	if line ~= shownLine then
		shownLine = line
		table.clear(slots)
		for _, buoy in buoys do
			SeaBuoy.tint(buoy, SeaZones.Zones[line + 1].color) -- the colour of the water beyond
		end
	end
	local half = SeaZones.POOL // 2
	local count = SeaZones.slotCount(line)
	for i = -half, half - 1 do
		local k = (centre + i) % count
		local index = k % SeaZones.POOL + 1
		local buoy = buoys[index]
		if slots[index] ~= k then
			slots[index] = k
			local at = SeaZones.slotPoint(line, k)
			buoy.model:PivotTo(if SeaZones.onLand(at) then HIDDEN else CFrame.new(at))
		end
	end
end

local function banner(index: number)
	if not canvas then
		local gui = Instance.new("ScreenGui")
		gui.Name = "SeaZoneFx"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 42
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = player:WaitForChild("PlayerGui")
		canvas = Style.canvas(gui)
	end
	local z = SeaZones.Zones[index]
	Toast.show(canvas :: Frame, z.name, { icon = z.gem, color = z.kit })
	AudioController.play("FX_Chime", nil, 0.6)
end

local function check()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local pos = root.Position
	local coldOpen = player:GetAttribute("ColdOpenActive") == true
	local now = if zone then SeaZones.step(zone, pos) else (SeaZones.zoneAt(pos))
	if zone and now ~= zone and not coldOpen then
		banner(now)
	end
	zone = now
	player:SetAttribute("SeaZone", now)
	local line, centre = SeaZones.lineNear(pos.X, pos.Z)
	if line and not coldOpen and not player:GetAttribute("BuildView") then
		showLine(line, centre)
	else
		hideLine()
	end
end

function SeaZoneController.Start()
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= CHECK_EVERY then
			since = 0
			check()
		end
	end)
end

return SeaZoneController
