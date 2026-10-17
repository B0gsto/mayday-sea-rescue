--!strict
-- CallController: shows radio call cards (CallCard), sends CallAccepted, and draws waypoints:
-- a Survivor Yellow beacon + billboard on each victim / disabled boat, then a Waypoint Green one
-- on the drop-off pads once someone is aboard (or the boat is on the tow line).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CallCard = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("CallCard"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local CallController = {}

type Entry = {
	data: { [string]: any },
	card: CallCard.CallCard,
	markers: { Instance },
	joined: boolean,
}

local player = Players.LocalPlayer
local entries: { [string]: Entry } = {}
local container: Frame
local markerFolder: Folder

local C = CallCard.Colors

local function flat(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function myPosition(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local cam = Workspace.CurrentCamera
	return if cam then cam.Focus.Position else nil
end

---------------------------------------------------------------- markers

local function makeMarker(pos: Vector3, color: Color3, caption: string): Part
	local anchor = Instance.new("Part")
	anchor.Name = "CallMarker"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Material = Enum.Material.Neon
	anchor.Color = color
	anchor.Transparency = 0.55
	anchor.Size = Vector3.new(0.8, 90, 0.8) -- a light column readable from far off
	anchor.CFrame = CFrame.new(pos.X, 45, pos.Z)

	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(150, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, -38, 0) -- just above the water
	gui.LightInfluence = 0
	gui.MaxDistance = 5000
	gui.Parent = anchor

	local ring = Instance.new("Frame")
	ring.Name = "Beacon"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0.5, 0, 0, 16)
	ring.Size = UDim2.fromOffset(26, 26)
	ring.BackgroundColor3 = color
	ring.Parent = gui
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Navy
	stroke.Thickness = 3
	stroke.Parent = ring
	TweenService:Create(
		ring,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = UDim2.fromOffset(34, 34) }
	):Play()

	local text = Instance.new("TextLabel")
	text.Name = "Distance"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(0, 34)
	text.Size = UDim2.new(1, 0, 0, 34)
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 17
	text.TextColor3 = C.Text
	text.TextStrokeColor3 = C.Navy
	text.TextStrokeTransparency = 0.2
	text.Text = caption
	text:SetAttribute("Caption", caption)
	text.Parent = gui

	anchor.Parent = markerFolder
	return anchor
end

local function clearMarkers(entry: Entry)
	for _, m in entry.markers do
		m:Destroy()
	end
	table.clear(entry.markers)
end

local function rebuildMarkers(entry: Entry)
	clearMarkers(entry)
	local data = entry.data
	if data.state ~= "Active" or not entry.joined then
		return
	end
	local caption = if data.kind == "Tow" then "BOAT" elseif data.isBig then "SURVIVOR" else "MAYDAY"
	for _, pos in data.targets or {} do
		table.insert(entry.markers, makeMarker(pos, C.Yellow, caption))
	end
	if data.phase == "Return" then
		for _, pos in data.dropOffs or {} do
			table.insert(entry.markers, makeMarker(pos, C.Green, "DROP-OFF"))
		end
	end
end

---------------------------------------------------------------- cards

local function removeEntry(id: string)
	local entry = entries[id]
	if entry then
		clearMarkers(entry)
		entry.card:destroy()
		entries[id] = nil
	end
end

local function nearest(points: { Vector3 }?, from: Vector3): number?
	local best: number? = nil
	local list: { Vector3 } = points or {}
	for _, p in list do
		local d = flat(p, from)
		if not best or d < best then
			best = d
		end
	end
	return best
end

local function refresh(entry: Entry)
	local data = entry.data
	local t = Workspace:GetServerTimeNow()
	local left = if data.state == "Active"
		then data.expiresAt - t
		else (data.offerExpiresAt or t) - t
	local pos = myPosition()
	local distance: number? = nil
	if pos then
		if data.phase == "Return" and (data.towing or #(data.targets or {}) == 0) then
			distance = nearest(data.dropOffs, pos)
		else
			distance = nearest(data.targets, pos) or nearest({ data.position }, pos)
		end
		for _, m in entry.markers do
			local label = m:FindFirstChild("Distance", true)
			if label and label:IsA("TextLabel") and m:IsA("BasePart") then
				label.Text =
					`{label:GetAttribute("Caption")}\n{math.floor(flat(m.Position, pos) + 0.5)} m`
			end
		end
	end
	data.joined = entry.joined
	entry.card:update(data, left, distance)
end

local function upsert(data: { [string]: any }, joined: boolean?)
	local id = data.id
	if type(id) ~= "string" then
		return
	end
	local entry = entries[id]
	if entry then
		entry.data = data
	else
		local newEntry: Entry
		local card = CallCard.new(container, data, function()
			Net.event("CallAccepted"):FireServer(id)
			if newEntry.data.isBig then
				newEntry.joined = true
				rebuildMarkers(newEntry)
			end
		end)
		newEntry = {
			data = data,
			card = card,
			markers = {},
			joined = not data.isBig and data.state == "Active",
		}
		entry = newEntry
		entries[id] = newEntry
	end
	assert(entry, "unreachable")
	if (joined or not data.isBig) and data.state == "Active" then
		entry.joined = true
	end
	rebuildMarkers(entry)
	refresh(entry)
end

local function onCompleted(result: { [string]: any })
	if type(result) ~= "table" then
		return
	end
	removeEntry(result.id)
	local grade = tostring(result.grade or "")
	local title = if grade == "Gold"
			or grade == "Silver"
			or grade == "Bronze"
		then `{string.upper(grade)} RESCUE!`
		elseif grade == "Share" then "CALL DONE"
		else `RESCUE COMPLETE · {grade}`
	local body = `+{result.cash or 0} Cash   +{result.rep or 0} Rep\n{result.message or ""}`
	CallCard.toast(container, title, body, C.Green)
end

local function onFailed(result: { [string]: any })
	if type(result) ~= "table" then
		return
	end
	removeEntry(result.id)
	if result.silent then
		return
	end
	local body = result.message or "The harbour patrol took over."
	if (result.cash or 0) > 0 then
		body ..= `\n+{result.cash} Cash for trying`
	end
	CallCard.toast(container, "CALL OVER", body, C.Yellow)
end

function CallController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CallUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- right side, vertically centred: in thumb reach on phones, clear of Roblox's corner buttons
	container = Instance.new("Frame")
	container.Name = "Cards"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(1, 0.5)
	container.Position = UDim2.new(1, -12, 0.45, 0)
	container.Size = UDim2.fromScale(0.34, 0.8)
	container.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(260, 0)
	limit.MaxSize = Vector2.new(380, math.huge)
	limit.Parent = container
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.Parent = container
	local scale = Instance.new("UIScale")
	scale.Parent = container
	local function rescale()
		local cam = Workspace.CurrentCamera
		local h = if cam then cam.ViewportSize.Y else 720
		scale.Scale = math.clamp(h / 720, 0.75, 1.25)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	markerFolder = Instance.new("Folder")
	markerFolder.Name = "CallMarkers"
	markerFolder.Parent = Workspace

	Net.event("CallOffered").OnClientEvent:Connect(function(data)
		upsert(data, false)
	end)
	-- updates only go to players on the call, so they count as joined (big call helpers too)
	Net.event("CallUpdated").OnClientEvent:Connect(function(data)
		upsert(data, true)
	end)
	Net.event("CallCompleted").OnClientEvent:Connect(onCompleted)
	Net.event("CallFailed").OnClientEvent:Connect(onFailed)
end

function CallController.Start()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 0.2 then
			return
		end
		accum = 0
		for _, entry in entries do
			refresh(entry)
		end
	end)
end

return CallController
