--!strict
-- HudController: the progression HUD (docs 05 section 9 style, mobile first).
--   Placement: UI/Layout regions. Top left ("wallet", under the phone button): Cash with a round
--   "+" that opens the phone's Store app, and the rank with its Rep bar to the next rank. The
--   phone button has its own region (UI/Phone: every menu, the crew's faces and Leave).
--   Top centre ("notice"): "+Cash +Rep" award pops, the rank-up toast with the
--   new unlocks and short notices for failed buys / launches.
--   Cold open (Layout.coldOpen): wallet, rank and pops stay hidden until it ends.
--   No shop or launch buttons (docs 04 section 1.1). Diegetic panels open from map prompts that
--   WorldService adds (attribute Panel on the prompt, read on this client's PromptTriggered):
--     ShopCounter  the Chandlery gear counter (HudShop: BuyGear)
--   Boats, cars and their upgrades are on the phone (VehiclesApp), not a world desk.
--   A panel closes from its X button, or when the player walks away from the prompt.
--   The engine only shows (and so only triggers) a prompt that is on screen; a player standing at
--   the counter but looking past it (or teleported there) pressed E and nothing happened. Fallback:
--   an unprocessed E / ButtonX within a store prompt's range opens the nearest store panel.
--   Stock CoreGui that clashes with the HUD is off: the leaderboard (PlayerList, it sat over the
--   status strip; rank and Cash live there), Backpack (no Tools in the game), Health (casualty
--   and crew condition are the game's own readouts) and the Emotes menu. Chat stays on (crew
--   talk and the TextChatService commands StormService registers).
-- Data arrives as PlayerDataChanged snapshots; the first one is pulled via Progression_GetData.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local UI = script.Parent.Parent:WaitForChild("UI")
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local HudShop = require(UI:WaitForChild("HudShop"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local Layout = require(UI:WaitForChild("Layout"))
local Phone = require(UI:WaitForChild("Phone"))
local Hud = require(Shared:WaitForChild("Config"):WaitForChild("UiImages")).Hud

local C = HudTheme.Colors
local player = Players.LocalPlayer

local HudController = {}
HudController.Priority = 50

local gui: ScreenGui
local PANEL_DISPLAY_ORDER = 35 -- above Ops (15-22) and the radio wheel (30), below Cinematic (50)
local cashLabel: TextLabel
local rankLabel: TextLabel
local repFill: ImageLabel
local coinPop: UIScale
local awardLabel: TextLabel
local toast: Frame
local toastTitle: TextLabel
local toastBody: TextLabel
local statusRegion: Frame
local walletRegion: Frame
local noticeRegion: Frame
local shop: HudShop.Shop
local snapshot: { [string]: any }? = nil
-- the open diegetic panel ("ShopCounter") and where its prompt is
local openPanel: string? = nil
local panelAnchor: Vector3? = nil
local panelRange = 0
local WALK_AWAY_MARGIN = 6 -- studs past the prompt's activation distance
local toastSerial = 0
local awardSerial = 0
local cashShown: number? = nil
local rolls: { [TextLabel]: number } = {}

local function showToast(title: string, body: string, color: Color3, seconds: number)
	toastSerial += 1
	local serial = toastSerial
	toastTitle.Text = title
	toastTitle.TextColor3 = color
	toastBody.Text = body
	toast.Position = UDim2.new(0.5, 0, 0, 30)
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, 0, 0, 38),
	}):Play()
	task.delay(seconds, function()
		if serial == toastSerial then
			toast.Visible = false
		end
	end)
end

local function notice(text: string)
	showToast(text, "", C.text, 2)
end

local function showAward(award: { [string]: any })
	awardSerial += 1
	local serial = awardSerial
	local text = `+{HudTheme.formatNumber(award.cash or 0)} Cash   +{HudTheme.formatNumber(
		award.rep or 0
	)} Rep`
	if type(award.multiplier) == "number" and award.multiplier > 1 then
		text ..= `   (storm x{award.multiplier})`
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
	rankLabel.Text = data.rank or "Recruit"
	local rep = tonumber(data.rep) or 0
	local goal = tonumber(data.nextRankRep) or tonumber(data.nextStarRep)
	local progress = math.clamp(
		tonumber(if data.nextRankRep then data.rankProgress else data.starProgress) or 0,
		0,
		1
	)
	-- Rep past the next rank's line but its certification not passed: a full bar and the exercise
	-- still to do, not "1,209 / 400"
	local certDue = goal ~= nil and data.nextRankRep ~= nil and rep >= goal
	-- certification due: the full bar glows pale gold
	repFill.ImageColor3 = if certDue then Color3.fromHex("FFF4C2") else Color3.new(1, 1, 1)
	TweenService:Create(repFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(progress, 1) }):Play()
	shop.update(data)
end

local function onDataChanged(data: any)
	if type(data) ~= "table" then
		return
	end
	render(data)
	if type(data.award) == "table" then
		showAward(data.award)
	end
	if type(data.rankUp) == "table" then
		local unlocks = data.rankUp.unlocks
		local body = if type(unlocks) == "table"
			then "Unlocked: " .. table.concat(unlocks, ", ")
			else ""
		showToast(`RANK UP!  {data.rankUp.rank}`, body, C.accent, 5)
	end
end

local function buy(itemId: string)
	task.spawn(function()
		local ok, okResult, reason = pcall(function()
			return Net.func("BuyGear"):InvokeServer(itemId)
		end)
		if not ok then
			notice("Shop is closed")
		elseif not okResult then
			notice(tostring(reason or "Can't buy that"))
		end
	end)
end

local function closePanels()
	shop.setOpen(false)
	openPanel = nil
	panelAnchor = nil
end

local function onPromptTriggered(prompt: ProximityPrompt)
	local panel = prompt:GetAttribute("Panel")
	if panel ~= "ShopCounter" then
		return
	end
	local anchor = prompt.Parent
	if not (anchor and anchor:IsA("BasePart")) then
		return
	end
	closePanels()
	openPanel = panel
	panelAnchor = anchor.Position
	panelRange = prompt.MaxActivationDistance + WALK_AWAY_MARGIN
	shop.setOpen(true)
end

-- E / ButtonX that no shown prompt consumed: open the nearest store panel in range (see header).
local storePrompts: { ProximityPrompt } = {}

local function trackStorePrompt(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		local panel = inst:GetAttribute("Panel")
		if panel == "ShopCounter" then
			table.insert(storePrompts, inst)
		end
	end
end

local function onStoreKey(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.E and input.KeyCode ~= Enum.KeyCode.ButtonX then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not (root and root:IsA("BasePart") and humanoid)
		or humanoid.SeatPart
		or humanoid.Health <= 0
	then
		return
	end
	local best: ProximityPrompt? = nil
	local bestDistance = math.huge
	for _, prompt in storePrompts do
		local anchor = prompt.Parent
		if
			prompt.Enabled
			and anchor
			and anchor:IsA("BasePart")
			and anchor:IsDescendantOf(Workspace)
		then
			local distance = (anchor.Position - root.Position).Magnitude
			if distance <= prompt.MaxActivationDistance and distance < bestDistance then
				best, bestDistance = prompt, distance
			end
		end
	end
	if best and not (openPanel == best:GetAttribute("Panel") and shop.isOpen()) then
		onPromptTriggered(best)
	end
end

-- Walking away (or dying) closes the open panel; a closed X clears the tracking.
local function watchPanel()
	if not openPanel then
		return
	end
	local isOpen = shop.isOpen()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not isOpen
		or not panelAnchor
		or not (root and root:IsA("BasePart"))
		or (root.Position - panelAnchor).Magnitude > panelRange
	then
		closePanels()
	end
end

-- Top left (assets/ui/hud/mockup.png): [coin] amount (+) on top, [star] rank over the Rep bar.
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
	-- touch: the region can be shorter than the card (it ends above the thumbstick zone)
	local fit = Instance.new("UIScale")
	fit.Parent = wallet
	local function refit()
		fit.Scale = math.min(1, region.Size.Y.Offset / H)
	end
	region:GetPropertyChangedSignal("Size"):Connect(refit)
	refit()

	local row = Instance.new("Frame")
	row.Name = "CashRow" -- FriendController adds its bonus chip here, after the amount
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(10, 5)
	row.Size = UDim2.new(1, -62, 0, 42)
	row.Parent = wallet
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = row

	local coin = HudTheme.image("Coin", Hud.Coin, UDim2.fromOffset(36, 36), row)
	coin.LayoutOrder = 1
	coinPop = Instance.new("UIScale")
	coinPop.Parent = coin

	cashLabel = HudTheme.label("Cash", "0", UDim2.fromOffset(0, 42), HudTheme.NumberFont, 28, row)
	cashLabel.LayoutOrder = 2
	cashLabel.AutomaticSize = Enum.AutomaticSize.X
	cashLabel.TextTruncate = Enum.TextTruncate.None
	HudTheme.outline(cashLabel)

	-- (+): the Store app on the phone; a 48 du hit area around the 42 du button sprite
	local plus = Instance.new("TextButton")
	plus.Name = "StoreButton"
	plus.Text = ""
	plus.AutoButtonColor = false
	plus.Selectable = true
	plus.BackgroundTransparency = 1
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.new(1, -4, 0, 2)
	plus.Size = UDim2.fromOffset(48, 48)
	plus.Parent = wallet
	local disc = HudTheme.image("Disc", Hud.PlusButton, UDim2.fromOffset(42, 42), plus)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
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
		Phone.openApp("Store")
	end)

	-- the rank over its Rep bar, no numbers (a full pale-gold bar: the exercise is due)
	local star = HudTheme.image("Star", Hud.XpStar, UDim2.fromOffset(36, 36), wallet)
	star.Position = UDim2.fromOffset(10, 52)
	rankLabel =
		HudTheme.label("Rank", "Recruit", UDim2.new(1, -64, 0, 22), HudTheme.LabelFont, 20, wallet)
	rankLabel.Position = UDim2.fromOffset(52, 48)
	HudTheme.outline(rankLabel)

	local track = HudTheme.image(
		"RepBar",
		Hud.BarTrack,
		UDim2.new(1, -64, 0, 18),
		wallet,
		HudTheme.Slice.Bar,
		0.28
	)
	track.Position = UDim2.fromOffset(52, 72)
	repFill =
		HudTheme.image("Fill", Hud.BarFill, UDim2.fromScale(0, 1), track, HudTheme.Slice.Bar, 0.28)
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

local function buildToast(parent: Instance)
	toast = HudTheme.panel("Toast", UDim2.new(1, 0, 0, 68), parent)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 38)
	toast.Visible = false
	toast.ZIndex = 5
	HudTheme.padding(toast, 10)
	HudTheme.skin(toast)
	toastTitle = HudTheme.label("Title", "", UDim2.new(1, 0, 0, 24), HudTheme.HeaderFont, 20, toast)
	toastTitle.TextXAlignment = Enum.TextXAlignment.Center
	toastBody = HudTheme.label("Body", "", UDim2.new(1, 0, 0, 20), HudTheme.BodyFont, 16, toast)
	toastBody.Position = UDim2.fromOffset(0, 26)
	toastBody.TextXAlignment = Enum.TextXAlignment.Center
	toastBody.TextColor3 = C.textDim
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
	buildToast(noticeRegion)
	require(UI:WaitForChild("SettingsPanel")).mount() -- the panel (the phone's Settings app shows it)
	Phone.mount(statusRegion) -- phone button, P / gamepad L1
	shop = HudShop.build(gui, buy)
	-- an open store panel draws (and takes clicks) above the Ops call card / debrief (DisplayOrder
	-- 15-22) so a Buy/Collect click never lands on "Accept - Launch" behind it; below Cinematic (50)
	local setOpen = shop.setOpen
	shop.setOpen = function(value: boolean)
		setOpen(value)
		gui.DisplayOrder = if value then PANEL_DISPLAY_ORDER else 0
	end

	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	for _, inst in Workspace:GetDescendants() do
		trackStorePrompt(inst)
	end
	Workspace.DescendantAdded:Connect(trackStorePrompt)
	UserInputService.InputBegan:Connect(onStoreKey)
	RunService.Heartbeat:Connect(watchPanel)

	Net.event("PlayerDataChanged").OnClientEvent:Connect(onDataChanged)
	Layout.onColdOpen(applyColdOpen)

	-- The "Join crew" prompt is on every multi-seat boat; hide it on our own.
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if
			prompt.Name == "CrewJoinPrompt"
			and prompt:GetAttribute("CrewOwner") == player.UserId
		then
			prompt.Enabled = false
		end
	end)
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
