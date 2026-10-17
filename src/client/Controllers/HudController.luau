--!strict
-- HudController: the progression HUD (docs 05 section 9 style, mobile first).
--   Top centre: Cash, rank name and a Rep bar to the next rank, plus "+Cash +Rep" award pops.
--   Rank-up toast with the new unlocks; short notices for failed buys / launches.
--   Right edge: Gear button opening the Gear shop (BuyGear).
--   Bottom right: Launch buttons (RequestVehicle), locked with the rank needed, or Buy (BuyGear).
--   Left: crew chip with a Leave button while in a crew (CrewJoin / CrewLeave echoes).
-- Data arrives as PlayerDataChanged snapshots; the first one is pulled via Progression_GetData.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local UI = script.Parent.Parent:WaitForChild("UI")
local HudLaunch = require(UI:WaitForChild("HudLaunch"))
local HudShop = require(UI:WaitForChild("HudShop"))
local HudTheme = require(UI:WaitForChild("HudTheme"))

local C = HudTheme.Colors
local player = Players.LocalPlayer

local HudController = {}
HudController.Priority = 50

local gui: ScreenGui
local cashLabel: TextLabel
local rankLabel: TextLabel
local repLabel: TextLabel
local repFill: Frame
local awardLabel: TextLabel
local toast: Frame
local toastTitle: TextLabel
local toastBody: TextLabel
local crewChip: Frame
local crewLabel: TextLabel
local shop: HudShop.Shop
local launch: HudLaunch.Launch
local snapshot: { [string]: any }? = nil
local toastSerial = 0
local awardSerial = 0

local function showToast(title: string, body: string, color: Color3, seconds: number)
	toastSerial += 1
	local serial = toastSerial
	toastTitle.Text = title
	toastTitle.TextColor3 = color
	toastBody.Text = body
	toast.Position = UDim2.new(0.5, 0, 0, 60)
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0, 104),
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

local function render(data: { [string]: any })
	snapshot = data
	cashLabel.Text = HudTheme.formatNumber(data.cash or 0)
	rankLabel.Text = data.rank or "Recruit"
	local progress = math.clamp(data.rankProgress or 0, 0, 1)
	TweenService:Create(repFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(progress, 1) }):Play()
	if data.nextRankRep then
		repLabel.Text =
			`{HudTheme.formatNumber(data.rep or 0)} / {HudTheme.formatNumber(data.nextRankRep)} Rep`
	else
		repLabel.Text = `{HudTheme.formatNumber(data.rep or 0)} Rep  (top rank)`
	end
	shop.update(data)
	launch.update(data)
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

local function requestLaunch(vehicleId: string)
	launch.setBusy(vehicleId)
	task.spawn(function()
		local finished = false
		task.delay(10, function()
			if not finished then
				launch.setBusy(nil)
			end
		end)
		local ok, launched, reason = pcall(function()
			return Net.func("RequestVehicle"):InvokeServer(vehicleId)
		end)
		finished = true
		launch.setBusy(nil)
		if not ok then
			notice("Launch bay offline")
		elseif not launched then
			notice(if type(reason) == "string" then reason else "Can't launch now")
		end
	end)
end

local function buildStatus(parent: Instance)
	local status = HudTheme.panel("Status", UDim2.fromOffset(320, 86), parent)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 8)
	HudTheme.padding(status, 10)

	rankLabel = HudTheme.label(
		"Rank",
		"Recruit",
		UDim2.new(0.55, 0, 0, 30),
		HudTheme.HeaderFont,
		24,
		status
	)
	rankLabel.TextColor3 = C.accent

	cashLabel =
		HudTheme.label("Cash", "0", UDim2.new(0.45, -26, 0, 30), HudTheme.HeaderFont, 26, status)
	cashLabel.AnchorPoint = Vector2.new(1, 0)
	cashLabel.Position = UDim2.fromScale(1, 0)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.TextColor3 = C.gold
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.Size = UDim2.fromOffset(20, 20)
	coin.AnchorPoint = Vector2.new(1, 0.5)
	coin.Position = UDim2.new(0.55, 0, 0, 15)
	coin.BackgroundColor3 = C.gold
	HudTheme.corner(coin, 10)
	HudTheme.stroke(coin, C.accent, 2)
	coin.Parent = status

	local bar = Instance.new("Frame")
	bar.Name = "RepBar"
	bar.Position = UDim2.fromOffset(0, 38)
	bar.Size = UDim2.new(1, 0, 0, 26)
	bar.BackgroundColor3 = C.locked
	bar.BorderSizePixel = 0
	HudTheme.corner(bar, 13)
	bar.Parent = status
	repFill = Instance.new("Frame")
	repFill.Name = "Fill"
	repFill.Size = UDim2.fromScale(0, 1)
	repFill.BackgroundColor3 = C.bar
	repFill.BorderSizePixel = 0
	HudTheme.corner(repFill, 13)
	repFill.Parent = bar
	repLabel = HudTheme.label("RepText", "0 Rep", UDim2.fromScale(1, 1), HudTheme.BoldFont, 16, bar)
	repLabel.TextXAlignment = Enum.TextXAlignment.Center
	repLabel.TextStrokeTransparency = 0.6

	awardLabel =
		HudTheme.label("Award", "", UDim2.fromOffset(360, 28), HudTheme.HeaderFont, 20, parent)
	awardLabel.AnchorPoint = Vector2.new(0.5, 0)
	awardLabel.Position = UDim2.new(0.5, 0, 0, 98)
	awardLabel.TextXAlignment = Enum.TextXAlignment.Center
	awardLabel.TextColor3 = C.gold
	awardLabel.TextStrokeTransparency = 0.4
	awardLabel.Visible = false
end

local function buildToast(parent: Instance)
	toast = HudTheme.panel("Toast", UDim2.fromOffset(360, 76), parent)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 104)
	toast.Visible = false
	toast.ZIndex = 5
	HudTheme.padding(toast, 10)
	toastTitle = HudTheme.label("Title", "", UDim2.new(1, 0, 0, 30), HudTheme.HeaderFont, 26, toast)
	toastTitle.TextXAlignment = Enum.TextXAlignment.Center
	toastBody = HudTheme.label("Body", "", UDim2.new(1, 0, 0, 24), HudTheme.BodyFont, 18, toast)
	toastBody.Position = UDim2.fromOffset(0, 32)
	toastBody.TextXAlignment = Enum.TextXAlignment.Center
end

local function buildCrewChip(parent: Instance)
	crewChip = HudTheme.panel("Crew", UDim2.fromOffset(200, 64), parent)
	crewChip.AnchorPoint = Vector2.new(0, 0.5)
	crewChip.Position = UDim2.new(0, 16, 0.45, 0)
	crewChip.Visible = false
	HudTheme.padding(crewChip, 6)
	crewLabel = HudTheme.label(
		"Count",
		"Crew 1/4",
		UDim2.new(1, -96, 1, 0),
		HudTheme.HeaderFont,
		20,
		crewChip
	)
	local leave =
		HudTheme.button("Leave", "Leave", UDim2.fromOffset(90, HudTheme.MinButtonHeight), crewChip)
	leave.AnchorPoint = Vector2.new(1, 0.5)
	leave.Position = UDim2.fromScale(1, 0.5)
	leave.BackgroundColor3 = C.locked
	leave.Activated:Connect(function()
		Net.event("CrewLeave"):FireServer()
	end)
end

function HudController.Init()
	local playerGui = player:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	buildStatus(gui)
	buildToast(gui)
	buildCrewChip(gui)
	shop = HudShop.build(gui, buy)
	launch = HudLaunch.build(gui, requestLaunch, buy)

	local gearButton = HudTheme.button("GearButton", "Gear", UDim2.fromOffset(96, 56), gui)
	gearButton.AnchorPoint = Vector2.new(1, 0.5)
	gearButton.Position = UDim2.new(1, -20, 0.4, 0)
	gearButton.BackgroundColor3 = C.panel
	HudTheme.stroke(gearButton, C.accent, 2)
	gearButton.Activated:Connect(function()
		shop.setOpen(not shop.isOpen())
	end)

	Net.event("PlayerDataChanged").OnClientEvent:Connect(onDataChanged)
	Net.event("CrewJoin").OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.members) == "table" then
			crewLabel.Text = `Crew {#payload.members}/4`
			crewChip.Visible = true
		end
	end)
	Net.event("CrewLeave").OnClientEvent:Connect(function()
		crewChip.Visible = false
	end)

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
