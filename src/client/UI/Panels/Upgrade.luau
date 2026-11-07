--!strict
-- Upgrade panel (owner 2026-11-07: "upgrade while you are on your boat"): the next boat level from the helm, anywhere.
-- Opened by the Next chip (tap, F, gamepad Y) while you drive your own boat away from the Upgrade Station. The boat's
-- 3D portrait, Lv N, the piece it bolts on, speed / room / reach / fuel tank (docs/31 C) with their gains, and one big green Cash button that
-- buys through UpgradeStationController.Buy (Boat_LevelUp). Short of Cash it is grey, reads what is missing and a press
-- shakes it. A buy closes the panel so the level-up moment plays on the boat where it is.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatLevels = require(Shared:WaitForChild("BoatLevels"))
local Net = require(Shared:WaitForChild("Net"))

local UI = script.Parent.Parent
local Controllers = UI.Parent:WaitForChild("Controllers")
local AudioController = require(Controllers:WaitForChild("AudioController"))
local BoatCard = require(UI:WaitForChild("BoatCard"))
local Comfort = require(UI.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Panel = require(UI:WaitForChild("Kit"):WaitForChild("Panel"))
local PriceButton = require(UI:WaitForChild("Kit"):WaitForChild("PriceButton"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local Theme = require(UI:WaitForChild("Kit"):WaitForChild("Theme"))
local UpgradeStationController = require(Controllers:WaitForChild("UpgradeStationController"))

local player = Players.LocalPlayer
local S = Theme.Size

local Upgrade = {}

local GAIN = "#78F082"
local BUTTON = Vector2.new(300, 84)

local function row(parent: Instance, height: number, order: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -8, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

-- One stat tile: icon + the next value and its gain in green.
local function stat(parent: Instance, iconName: string, order: number): TextLabel
	local cell = Instance.new("Frame")
	cell.BackgroundTransparency = 1
	cell.Size = UDim2.new(1 / 4, -9, 1, 0)
	cell.LayoutOrder = order
	cell.Parent = parent
	local _, face = Style.block(cell, Style.grad("blue"), { radius = S.cornerSmall })
	local ic = Instance.new("Frame")
	ic.BackgroundTransparency = 1
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.new(0, 8, 0.5, 0)
	ic.Size = UDim2.fromOffset(56, 56)
	ic.Parent = face
	Style.icon(ic, iconName)
	local label = Style.label(face, "", Theme.Text.heading)
	label.RichText = true
	label.TextWrapped = false
	label.TextScaled = true
	label.Position = UDim2.fromOffset(70, 8)
	label.Size = UDim2.new(1, -78, 1, -16)
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = Theme.Text.heading
	cap.Parent = label
	return label
end

-- 27.6, 28: one decimal, none when whole (the tank grows 0.4 s a level)
local function num(n: number): string
	return (string.gsub(string.format("%.1f", n), "%.0$", ""))
end

local function gain(now: number, nextValue: number): string
	return if nextValue > now
		then `{num(nextValue)} <font color="{GAIN}">+{num(nextValue - now)}</font>`
		else num(nextValue)
end

function Upgrade.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Upgrade",
		icon = "build",
		size = Vector2.new(800, 540),
		onClose = onClose,
	})
	local snap: { [string]: any }? = UpgradeStationController.Snapshot()

	local hero = row(panel.body, 190, 1)
	local well = Instance.new("Frame")
	well.BackgroundTransparency = 1
	well.Size = UDim2.fromOffset(250, 186)
	well.Parent = hero
	local level = Style.label(hero, "", Theme.Text.title)
	level.TextXAlignment = Enum.TextXAlignment.Left
	level.Position = UDim2.fromOffset(266, 16)
	level.Size = UDim2.new(1, -270, 0, 64)
	local piece = Style.label(hero, "", Theme.Text.heading)
	piece.TextXAlignment = Enum.TextXAlignment.Left
	piece.TextYAlignment = Enum.TextYAlignment.Top
	piece.Position = UDim2.fromOffset(266, 88)
	piece.Size = UDim2.new(1, -270, 0, 90)

	local stats = row(panel.body, 84, 2)
	Style.list(stats, true, 12).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local speed = stat(stats, "speed", 1)
	local room = stat(stats, "crew", 2)
	local reach = stat(stats, "lifebuoy", 3)
	local tank = stat(stats, "fuel", 4)

	local buyRow = row(panel.body, BUTTON.Y + 16, 3)
	local short = false
	local price: PriceButton.PriceButton
	price = PriceButton.new(buyRow, {
		price = 0,
		currency = "Cash",
		onActivate = function()
			if UpgradeStationController.Buy() then
				panel.close() -- its onClose tells the Menu
			end
		end,
	})
	price.root.AnchorPoint = Vector2.new(0.5, 0)
	price.root.Position = UDim2.fromScale(0.5, 0)
	price.root.Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y)
	-- grey (Active off) presses come here only: one shake of what is missing, with the station's refusal sound
	price.root.Activated:Connect(function()
		if price.root.Active or not short then
			return
		end
		AudioController.play("UI_Back")
		if Comfort.reducedMotion() then
			return
		end
		price.root.Position = UDim2.fromScale(0.5, 0)
		TweenService:Create(
			price.root,
			TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
			{ Position = UDim2.new(0.5, 16, 0, 0) }
		):Play()
	end)

	local shownHull: string? = nil
	local function refresh()
		local s = snap
		if not s then
			return
		end
		local now = BoatLevels.row(s.boatLevel)
		local nextRow = BoatLevels.nextRow(s.boatLevel)
		local money = tonumber(s.cash) or 0
		local hull = if nextRow then nextRow.hull else now.hull
		if hull ~= shownHull then
			shownHull = hull
			well:ClearAllChildren()
			BoatCard.preview(well, hull).Size = UDim2.fromScale(1, 1)
		end
		if not nextRow then
			level.Text = `Lv {now.level}`
			piece.Text = "Max!"
			speed.Text, room.Text, reach.Text = `{now.speed}`, `{now.room}`, `{now.reach}`
			tank.Text = num(now.tank)
			short = false
			price.setState("owned")
			price.setText("Max")
			return
		end
		level.Text = `Lv {now.level} -> {nextRow.level}`
		piece.Text = nextRow.piece
		speed.Text = gain(now.speed, nextRow.speed)
		room.Text = gain(now.room, nextRow.room)
		reach.Text = gain(now.reach, nextRow.reach)
		tank.Text = gain(now.tank, nextRow.tank)
		local missing = nextRow.price - money
		short = missing > 0
		price.setPrice(nextRow.price)
		price.setState(if short then "disabled" else "buy")
		price.setText(if short then `Need {Theme.short(math.ceil(missing))}` else nil)
	end

	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(raw: any)
		if type(raw) == "table" then
			snap = raw
			if panel.isOpen() then
				refresh()
			end
		end
	end)

	return {
		open = function()
			snap = UpgradeStationController.Snapshot() or snap
			refresh()
			panel.open()
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

-- Driving your own boat (not a heli or sub, which have no BoatLevel): where the panel opens.
function Upgrade.atHelm(): boolean
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local boat = seat and seat.Name == "DriverSeat" and seat:FindFirstAncestorOfClass("Model")
	return boat ~= nil
		and boat:GetAttribute("Owner") == player.UserId
		and boat:GetAttribute("BoatLevel") ~= nil
end

return Upgrade
