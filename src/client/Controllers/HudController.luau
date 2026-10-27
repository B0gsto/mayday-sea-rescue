--!strict
-- HudController: the progression HUD (docs 05 section 9 style, mobile first).
--   Placement: UI/Layout regions. "wallet" (desktop: under the menu): Cash, no backing card, with a round "+" that opens the kit
--   Shop. UI/Menu owns the left button bar and the
--   panels (every menu, the crew's faces and Leave).
--   Top centre ("notice"): "+Cash" award pops (with the friends bonus as "+20%").
--   Cold open (Layout.coldOpen): wallet and pops stay hidden until it ends.
--   No world shops (docs/16 C4, C5, K10): vehicles, upgrades and Robux items are in the kit panels
--   (BoatCard, Shop).
--   Stock CoreGui that clashes with the HUD is off: the leaderboard (PlayerList, it sat over the
--   status strip; Cash lives there), Backpack (no Tools in the game), Health (casualty
--   and crew condition are the game's own readouts) and the Emotes menu. Chat stays on (crew
--   talk and the TextChatService commands StormService registers).
-- Data arrives as PlayerDataChanged snapshots; the first one is pulled via Progression_GetData.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local UI = script.Parent.Parent:WaitForChild("UI")
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local Layout = require(UI:WaitForChild("Layout"))
local Menu = require(UI:WaitForChild("Menu"))
local NextChip = require(UI:WaitForChild("NextChip"))
local Hud = require(Shared:WaitForChild("Config"):WaitForChild("UiImages")).Hud

local player = Players.LocalPlayer

local HudController = {}
HudController.Priority = 50

local gui: ScreenGui
local cashLabel: TextLabel
local coinPop: UIScale
local awardLabel: TextLabel
local statusRegion: Frame
local walletRegion: Frame
local noticeRegion: Frame
local snapshot: { [string]: any }? = nil
local awardSerial = 0
local cashShown: number? = nil
local rolls: { [TextLabel]: number } = {}

local function showAward(award: { [string]: any })
	awardSerial += 1
	local serial = awardSerial
	local text = `+{HudTheme.formatNumber(award.cash or 0)} Cash`
	-- the friends bonus shows only here, as "+20%" (docs/16 K10); FriendService sets the percent
	local friends = player:GetAttribute("FriendBonus")
	if typeof(friends) == "number" and friends > 0 and (award.cash or 0) > 0 then
		text ..= `   +{math.floor(friends)}%`
	end
	awardLabel.Text = text
	awardLabel.TextTransparency = 0
	awardLabel.Visible = true
	task.delay(2, function()
		if serial == awardSerial then
			TweenService:Create(awardLabel, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

-- A counter rolls to its new value (docs/15: a payout is a moment, not a jump).
local function roll(label: TextLabel, from: number, to: number, fmt: (number) -> string)
	local serial = (rolls[label] or 0) + 1
	rolls[label] = serial
	if from == to or Comfort.reducedMotion() then
		label.Text = fmt(to)
		return
	end
	task.spawn(function()
		local t = 0
		while t < 1 do
			t = math.min(t + task.wait() / 0.45, 1)
			-- re-check after the wait: a newer roll (or same-value snapshot) already wrote the final text
			if rolls[label] ~= serial then
				return
			end
			label.Text = fmt(from + (to - from) * (1 - (1 - t) ^ 3) + 0.5)
		end
	end)
end

local function render(data: { [string]: any })
	snapshot = data
	local cash = tonumber(data.cash) or 0
	if cashShown and cash > cashShown and not Comfort.reducedMotion() then
		coinPop.Scale = 1.3
		TweenService:Create(coinPop, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end
	roll(cashLabel, cashShown or cash, cash, HudTheme.formatNumber)
	cashShown = cash
end

local function onDataChanged(data: any)
	if type(data) ~= "table" then
		return
	end
	render(data)
	if type(data.award) == "table" then
		showAward(data.award)
	end
end

-- Top left (assets/ui/hud/mockup.png): [coin] amount (+).
local function buildWallet(region: Frame)
	local W, H = Layout.WALLET_WIDTH, Layout.WALLET_HEIGHT
	local wallet = HudTheme.image(
		"Wallet",
		Hud.Panel,
		UDim2.fromOffset(W, H),
		region,
		HudTheme.Slice.Panel,
		0.45
	)
	wallet.ImageTransparency = 1 -- see-through: coin, outlined number and "+" over the world (user, 2026-10-26)
	-- touch: the region can be shorter than the card (it ends above the thumbstick zone)
	local fit = Instance.new("UIScale")
	fit.Parent = wallet

	local row = Instance.new("Frame")
	row.Name = "CashRow" -- FriendController adds its bonus chip here, after the amount
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(10, 5)
	row.Size = UDim2.new(1, -10, 0, 52)
	row.Parent = wallet
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = row

	local coin = HudTheme.image("Coin", Hud.Coin, UDim2.fromOffset(52, 52), row)
	coin.LayoutOrder = 1
	coinPop = Instance.new("UIScale")
	coinPop.Parent = coin

	cashLabel = HudTheme.label("Cash", "0", UDim2.fromOffset(0, 52), HudTheme.NumberFont, 42, row)
	cashLabel.LayoutOrder = 2
	cashLabel.AutomaticSize = Enum.AutomaticSize.X
	cashLabel.TextTruncate = Enum.TextTruncate.None
	-- gold number with a thick dark outline so it pops over the world (user, 2026-10-26)
	cashLabel.TextColor3 = Color3.new(1, 1, 1)
	local gold = Instance.new("UIGradient")
	gold.Rotation = 90
	gold.Color = ColorSequence.new(Color3.fromHex("FFF7B8"), Color3.fromHex("FFB81C"))
	gold.Parent = cashLabel
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromHex("3A1E00")
	edge.Thickness = 3.5
	edge.LineJoinMode = Enum.LineJoinMode.Round
	edge.Parent = cashLabel

	-- (+): the kit Shop; a hit area around the 42 du button sprite, >= 46 px on screen (touch target, refit)
	local plus = Instance.new("TextButton")
	plus.Name = "StoreButton"
	plus.Text = ""
	plus.AutoButtonColor = false
	plus.Selectable = true
	plus.BackgroundTransparency = 1
	plus.LayoutOrder = 4 -- right after the amount (and the friends chip, 3)
	plus.Parent = row
	local function refit()
		fit.Scale = math.min(1, region.Size.Y.Offset / H)
		local side = math.max(58, math.ceil(46 / (Layout.current().scale * fit.Scale)))
		plus.Size = UDim2.fromOffset(side, side)
	end
	region:GetPropertyChangedSignal("Size"):Connect(refit)
	Layout.onMetrics(refit)
	refit()
	local disc = HudTheme.image("Disc", Hud.PlusButton, UDim2.fromOffset(56, 56), plus)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	-- dark ring behind the sprite, the same outline as the Cash number
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(61, 61)
	ring.BackgroundColor3 = Color3.fromHex("3A1E00")
	ring.ZIndex = disc.ZIndex - 1
	ring.Parent = plus -- a sibling: under Sibling ZIndex a child would draw over the sprite
	HudTheme.corner(ring, 999)
	local pop = Instance.new("UIScale")
	pop.Parent = disc
	local function to(scale: number)
		TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = scale })
			:Play()
	end
	plus.MouseEnter:Connect(function()
		to(1.12)
	end)
	plus.MouseLeave:Connect(function()
		to(1)
	end)
	plus.SelectionGained:Connect(function()
		to(1.12)
	end)
	plus.SelectionLost:Connect(function()
		to(1)
	end)
	plus.MouseButton1Down:Connect(function()
		to(0.88)
	end)
	plus.Activated:Connect(function()
		to(1)
		Menu.open("Shop")
	end)
	-- no idle heartbeat on the "+": a looping pulse to sell the shop looks cheap (owner, 2026-10-28)
end

local function buildAward()
	awardLabel =
		HudTheme.label("Award", "", UDim2.new(1, 0, 0, 26), HudTheme.NumberFont, 20, noticeRegion)
	awardLabel.AnchorPoint = Vector2.new(0.5, 0)
	awardLabel.Position = UDim2.fromScale(0.5, 0)
	awardLabel.TextXAlignment = Enum.TextXAlignment.Center
	HudTheme.outline(awardLabel)
	awardLabel.Visible = false
end

local function applyColdOpen(active: boolean)
	statusRegion.Visible = not active
	walletRegion.Visible = not active
	noticeRegion.Visible = not active
end

local function hideCoreGui()
	for _, t in
		{
			Enum.CoreGuiType.PlayerList,
			Enum.CoreGuiType.Backpack,
			Enum.CoreGuiType.Health,
			Enum.CoreGuiType.EmotesMenu,
		}
	do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, false)
	end
end

function HudController.Init()
	hideCoreGui()
	local playerGui = player:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	gui.Parent = playerGui

	statusRegion = Layout.region(gui, "status")
	noticeRegion = Layout.region(gui, "notice")
	walletRegion = Layout.region(gui, "wallet")
	buildWallet(walletRegion)
	buildAward()
	Menu.mount() -- button bar, panel registry, Boat to me
	NextChip.mount(Layout.region(gui, "chips")) -- the permanent next-goal chip (docs/24 E)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(onDataChanged)
	Layout.onColdOpen(applyColdOpen)

	-- The "Join crew" prompt is on every multi-seat boat; hide it on our own. FootOnly prompts (bay
	-- Launch, Talk) hide locally while seated: "E Launch" rode along out of the bay.
	local shown: { [ProximityPrompt]: boolean } = {}
	local seatHidden: { [ProximityPrompt]: boolean } = {}
	local function seated(): boolean
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		return hum ~= nil and hum.SeatPart ~= nil
	end
	local function hideIfSeated(prompt: ProximityPrompt)
		if prompt:GetAttribute("FootOnly") == true and seated() then
			prompt.Enabled = false
			seatHidden[prompt] = true
		end
	end
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if
			prompt.Name == "CrewJoinPrompt"
			and prompt:GetAttribute("CrewOwner") == player.UserId
		then
			prompt.Enabled = false
		end
		shown[prompt] = true
		hideIfSeated(prompt)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		shown[prompt] = nil
	end)
	local function watchSeat(char: Model)
		local hum = char:WaitForChild("Humanoid", 10)
		if not (hum and hum:IsA("Humanoid")) then
			return
		end
		hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
			if hum.SeatPart then
				for p in shown do
					hideIfSeated(p)
				end
			else
				for p in seatHidden do
					p.Enabled = true
				end
				table.clear(seatHidden)
			end
		end)
	end
	player.CharacterAdded:Connect(watchSeat)
	if player.Character then
		task.spawn(watchSeat, player.Character)
	end
end

function HudController.Start()
	if snapshot then
		return
	end
	local getData = Net.init():WaitForChild("Progression_GetData", 30)
	if getData and getData:IsA("RemoteFunction") then
		for _ = 1, 10 do
			local ok, data = pcall(function()
				return getData:InvokeServer()
			end)
			if snapshot then
				return -- a push arrived first
			end
			if ok and type(data) == "table" then
				render(data)
				return
			end
			task.wait(1) -- data still loading
		end
	end
end

return HudController
