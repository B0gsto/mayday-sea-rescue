--!strict
-- BoatBoardController (docs/23 d.3, WP-5): the client half of the vehicle boards (server/Dock/BoatBoard: the
-- boat board and the hangar and sub pen boards, all tagged BoatBoard).
-- On your own rack, owned models stay lit; locked ones go dark with a padlock, a Cash chip (coin + price, or
-- the building it still needs: its drawing + name, docs/23 (q)) and an R$ chip (greyed until that building
-- stands: Robux never skips the order). The rack's one BoardOpen prompt opens the board panel
-- (Menu.openBoard: Launch / Buy per craft); a click / tap on a model opens that craft's BoatCard. Other players'
-- racks: prompt off.
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProductShelves = require(Shared:WaitForChild("ProductShelves"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local UiImages = require(Config:WaitForChild("UiImages"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))

local UI = script.Parent.Parent:WaitForChild("UI")
local BuildGlyph = require(UI:WaitForChild("BuildGlyph"))
local Glyph = require(UI:WaitForChild("Glyph"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local Menu = require(UI:WaitForChild("Menu"))

local C = HudTheme.Colors
local TAG = "BoatBoard"
local player = Players.LocalPlayer

local BoatBoardController = {}

local snapshot: { [string]: any }? = nil
local prices: { [number]: number | false } = {} -- pass id -> Robux (false: asked, no answer yet)

local function passId(id: string): number
	local key = Rules.vehiclePass(id)
	local item = if key then MonetizationConfig.GamePasses[key] else nil
	return if item and item.ready then item.id else 0
end

local function usable(id: string): boolean?
	local snap = snapshot
	if not snap then
		return nil
	end
	local key = Rules.vehiclePass(id)
	local pass = key ~= nil and player:GetAttribute("Pass_" .. key) == true
	return (Rules.canUseVehicle(Rules.fromSnapshot(snap), id, pass))
end

local function chip(parent: Instance, name: string, order: number): (Frame, Frame, TextLabel)
	local f = Instance.new("Frame")
	f.Name = name
	f.LayoutOrder = order
	f.Size = UDim2.fromScale(0.47, 1)
	f.BackgroundColor3 = C.panel
	f.BackgroundTransparency = 0.1
	HudTheme.corner(f, 8)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = f
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(0.26, 0.7)
	icon.BackgroundTransparency = 1
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = icon
	icon.Parent = f
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.LayoutOrder = 1
	text.Size = UDim2.fromScale(0.62, 0.7)
	text.BackgroundTransparency = 1
	text.Font = HudTheme.HeaderFont
	text.TextScaled = true
	text.TextColor3 = C.text
	text.Parent = f
	f.Parent = parent
	return f, icon, text
end

-- the padlock and the two price chips over a locked model
local function lockTag(pad: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockTag"
	gui.Size = UDim2.fromScale(4, 2.4)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 40
	local lock = Instance.new("Frame")
	lock.Name = "Padlock"
	lock.AnchorPoint = Vector2.new(0.5, 0)
	lock.Position = UDim2.fromScale(0.5, 0)
	lock.Size = UDim2.fromScale(0.5, 0.5)
	lock.BackgroundTransparency = 1
	Instance.new("UIAspectRatioConstraint").Parent = lock
	lock.Parent = gui
	local shackle = Instance.new("Frame")
	shackle.AnchorPoint = Vector2.new(0.5, 0.5)
	shackle.Position = UDim2.fromScale(0.5, 0.4)
	shackle.Size = UDim2.fromScale(0.4, 0.55)
	shackle.BackgroundTransparency = 1
	HudTheme.corner(shackle, 99)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = C.gold
	stroke.Parent = shackle
	shackle.Parent = lock
	Glyph.bar(lock, Vector2.new(0.66, 0.46), Vector2.new(0.5, 0.72), 0, C.gold, 0.2)
	local row = Instance.new("Frame")
	row.Name = "Chips"
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.fromScale(0.5, 1)
	row.Size = UDim2.fromScale(1, 0.4)
	row.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = row
	row.Parent = gui
	chip(row, "Cash", 0)
	local _, rIcon, rText = chip(row, "Robux", 1)
	rIcon.Visible = false -- the Robux glyph is a font character, in the text
	rText.Size = UDim2.fromScale(0.9, 0.7)
	gui.Parent = pad
	return gui
end

local paintAll: () -> ()

local function price(id: number): number?
	local p = prices[id]
	if p == nil and id > 0 then
		prices[id] = false
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				prices[id] = info.PriceInRobux
				paintAll()
			end
		end)
	end
	return if type(p) == "number" then p else nil
end

local function paintTag(gui: BillboardGui, id: string)
	local unlock = ProgressionConfig.Vehicles[id]
	local snap = snapshot
	local chips = gui:FindFirstChild("Chips") :: Frame
	local cash = chips:FindFirstChild("Cash") :: Frame
	local cashIcon = cash:FindFirstChild("Icon") :: Frame
	local cashText = cash:FindFirstChild("Text") :: TextLabel
	cash.Visible = unlock ~= nil and not unlock.passOnly
	cashIcon:ClearAllChildren()
	Instance.new("UIAspectRatioConstraint").Parent = cashIcon
	local need = if snap then Rules.vehicleLock(Rules.fromSnapshot(snap), id) else nil
	if need then
		-- the building it needs: its Lego drawing and its name
		cash.Visible = true
		BuildGlyph(cashIcon, { kind = "Building", key = need })
		cashText.Text = UnlockTree.needName(need)
	elseif unlock then
		local coin = Instance.new("ImageLabel")
		coin.Size = UDim2.fromScale(1, 1)
		coin.BackgroundTransparency = 1
		coin.Image = UiImages.Hud.Coin
		coin.ScaleType = Enum.ScaleType.Fit
		coin.Parent = cashIcon
		cashText.Text = HudTheme.formatNumber(unlock.price)
	end
	local robux = chips:FindFirstChild("Robux") :: Frame
	local pid = passId(id)
	robux.Visible = Rules.vehiclePass(id) ~= nil
	robux.BackgroundColor3 = if pid > 0 and not need then Color3.fromHex("2F9E5B") else C.locked
	local r = price(pid)
	local rText = robux:FindFirstChild("Text") :: TextLabel
	rText.Text = if r
		then `{ProductShelves.ROBUX} {HudTheme.formatNumber(r)}`
		else ProductShelves.ROBUX
end

local function paintRack(rack: Instance)
	local mine = rack:GetAttribute("Owner") == player.UserId
	local open = rack:FindFirstChild("BoardOpen", true) :: ProximityPrompt?
	if open then
		open.Enabled = mine
	end
	for _, pad in rack:GetChildren() do
		local id = pad:GetAttribute("VehicleId")
		if not (pad:IsA("BasePart") and type(id) == "string") or pad:GetAttribute("Silhouette") then
			continue -- a craft not built yet stays a grey shape
		end
		local have = if mine then usable(id) else nil
		local model = pad:FindFirstChild("Model")
		if model and mine then
			local dim = model:FindFirstChild("Dim") :: Highlight?
			if not dim then
				local h = Instance.new("Highlight")
				h.Name = "Dim"
				h.FillColor = Color3.new(0, 0, 0)
				h.FillTransparency = 0.35
				h.OutlineTransparency = 1
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Parent = model
				dim = h
			end
			(dim :: Highlight).Enabled = have == false
			if not model:FindFirstChild("Open") then
				-- tap / click a model: that craft's own card (the prompt covers gamepad)
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanQuery = true -- local only: the server built it unqueryable
					end
				end
				local click = Instance.new("ClickDetector")
				click.Name = "Open"
				click.MaxActivationDistance = 16
				click.MouseClick:Connect(function()
					Menu.openBoat(id)
				end)
				click.Parent = model
			end
		end
		local tag = pad:FindFirstChild("LockTag") :: BillboardGui?
		if mine and have == false then
			local gui = tag or lockTag(pad)
			gui.Enabled = true
			paintTag(gui, id)
		elseif tag then
			tag.Enabled = false
		end
	end
end

paintAll = function()
	for _, rack in CollectionService:GetTagged(TAG) do
		paintRack(rack)
	end
end

local function watch(rack: Instance)
	paintRack(rack)
	-- pads and models arrive after the rack (built async, or streamed in)
	rack.DescendantAdded:Connect(function(d)
		if d.Name == "Model" or d:IsA("ProximityPrompt") then
			task.defer(paintRack, rack)
		end
	end)
end

local function onTriggered(prompt: ProximityPrompt)
	-- the prompt sits on an attachment in the backboard, not on the rack itself
	local rack = prompt:FindFirstAncestorWhichIsA("Model")
	if
		prompt.Name == "BoardOpen"
		and rack
		and CollectionService:HasTag(rack, TAG)
		and rack:GetAttribute("Owner") == player.UserId
	then
		Menu.openBoard(rack)
	end
end

local function onData(d: any)
	if type(d) == "table" then
		snapshot = d
		paintAll()
	end
end

function BoatBoardController.Init() end

function BoatBoardController.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
	for _, rack in CollectionService:GetTagged(TAG) do
		watch(rack)
	end
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(onData)
	player.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, 5) == "Pass_" then
			paintAll()
		end
	end)
	local getData = Net.init():WaitForChild("Progression_GetData", 30)
	if getData and getData:IsA("RemoteFunction") and not snapshot then
		local ok, d = pcall(function()
			return getData:InvokeServer()
		end)
		if ok and not snapshot then
			onData(d)
		end
	end
end

return BoatBoardController
