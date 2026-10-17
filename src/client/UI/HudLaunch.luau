--!strict
-- HudLaunch: the Launch buttons (bottom right, thumb reach; lifted above the mobile jump button).
-- Per vehicle: ready (orange "Launch X"), rank-locked (grey, "X: needs <Rank>") or for sale once
-- the rank is reached ("Buy X  4,000"). onLaunch / onBuy are wired by HudController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudTheme = require(script.Parent.HudTheme)
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local C = HudTheme.Colors

export type Launch = {
	frame: Frame,
	update: (snapshot: { [string]: any }) -> (),
	setBusy: (vehicleId: string?) -> (),
}

local HudLaunch = {}

function HudLaunch.build(
	parent: Instance,
	onLaunch: (vehicleId: string) -> (),
	onBuy: (vehicleId: string) -> ()
): Launch
	local ids = VehicleConfig.Order
	local buttonHeight = 60
	local frame = Instance.new("Frame")
	frame.Name = "Launch"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(1, 1)
	local bottom = if UserInputService.TouchEnabled then -180 else -20
	frame.Position = UDim2.new(1, -20, 1, bottom)
	frame.Size = UDim2.fromOffset(230, #ids * (buttonHeight + 10))
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	type State = "ready" | "locked" | "buy" | "poor"
	local buttons: { [string]: TextButton } = {}
	local states: { [string]: State } = {}
	local busy: string? = nil

	for order, id in ids do
		local spec = VehicleConfig.get(id)
		local b = HudTheme.button(
			id,
			spec and spec.displayName or id,
			UDim2.new(1, 0, 0, buttonHeight),
			frame
		)
		b.LayoutOrder = order
		HudTheme.stroke(b, C.text, 2)
		buttons[id] = b
		states[id] = "locked"
		b.Activated:Connect(function()
			if busy then
				return
			end
			local state = states[id]
			if state == "ready" then
				onLaunch(id)
			elseif state == "buy" then
				onBuy(id)
			end
		end)
	end

	local lastSnapshot: { [string]: any }? = nil

	local function update(snapshot: { [string]: any })
		lastSnapshot = snapshot
		local data = Rules.defaultData()
		data.cash = snapshot.cash or 0
		data.rep = snapshot.rep or 0
		data.vehicles = snapshot.vehicles or {}
		for id, b in buttons do
			local spec = VehicleConfig.get(id)
			local name = if spec then spec.displayName else id
			local unlock = ProgressionConfig.Vehicles[id]
			local usable = Rules.canUseVehicle(data, id)
			if busy == id then
				b.Text = "Launching..."
				b.BackgroundColor3 = C.panelLight
			elseif usable then
				states[id] = "ready"
				b.Text = `Launch {name}`
				b.BackgroundColor3 = C.accent
			elseif unlock and Rules.rankIndexForRep(data.rep) < unlock.rankIndex then
				states[id] = "locked"
				b.Text = `{name}\nRank: {ProgressionConfig.Ranks[unlock.rankIndex].displayName}`
				b.BackgroundColor3 = C.locked
			elseif unlock then
				local canBuy = Rules.canBuyVehicle(data, id)
				states[id] = if canBuy then "buy" else "poor"
				b.Text = `Buy {name}\n{HudTheme.formatNumber(unlock.price)} Cash`
				b.BackgroundColor3 = if canBuy then C.panelLight else C.locked
			end
			b.TextSize = if b.Text:find("\n") then 17 else 20
		end
	end

	local function setBusy(vehicleId: string?)
		busy = vehicleId
		if lastSnapshot then
			update(lastSnapshot)
		end
	end

	return { frame = frame, update = update, setBusy = setBusy }
end

return HudLaunch
