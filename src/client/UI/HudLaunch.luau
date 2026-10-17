--!strict
-- HudLaunch: the boatyard collection desk panel (docs 04 section 1.1: no launch buttons on the HUD).
-- It opens only from the "BoatDesk" ProximityPrompt at the desk on the quay (wired by HudController,
-- which also closes it when the player walks away). The bay prompts on the dock still launch too.
-- One row per boat: ready (orange "Collect X", RequestVehicle), rank-locked (grey, "X / Rank: <Rank>")
-- or for sale once the rank is reached ("Buy X / 4,000 Cash", BuyGear). Land vehicles (entries flagged
-- land in ProgressionConfig.Vehicles) are station-yard pool vehicles and never listed here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudTheme = require(script.Parent.HudTheme)
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local C = HudTheme.Colors

export type Launch = {
	frame: Frame,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	update: (snapshot: { [string]: any }) -> (),
	setBusy: (vehicleId: string?) -> (),
}

local HudLaunch = {}

local function isLand(id: string): boolean
	local unlock = (ProgressionConfig.Vehicles :: any)[id]
	return type(unlock) == "table" and unlock.land == true
end

function HudLaunch.build(
	parent: Instance,
	onLaunch: (vehicleId: string) -> (),
	onBuy: (vehicleId: string) -> ()
): Launch
	local ids: { string } = {}
	for _, id in VehicleConfig.Order do
		if not isLand(id) then
			table.insert(ids, id)
		end
	end
	local buttonHeight = 64
	local frame =
		HudTheme.panel("BoatDesk", UDim2.fromOffset(360, 70 + #ids * (buttonHeight + 10)), parent)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Visible = false
	HudTheme.padding(frame, 14)

	local title = HudTheme.label(
		"Title",
		"BOAT COLLECTION",
		UDim2.new(1, -60, 0, 36),
		HudTheme.HeaderFont,
		24,
		frame
	)
	title.TextColor3 = C.accent

	local close = HudTheme.button("Close", "X", UDim2.fromOffset(48, 48), frame)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, -6)
	close.BackgroundColor3 = C.locked

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 50)
	list.Size = UDim2.new(1, 0, 1, -50)
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

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
			list
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

	local open = false
	local function setOpen(value: boolean)
		open = value
		frame.Visible = value
	end
	close.Activated:Connect(function()
		setOpen(false)
	end)

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
				b.Text = "Collecting..."
				b.BackgroundColor3 = C.panelLight
			elseif usable then
				states[id] = "ready"
				b.Text = `Collect {name}`
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

	return {
		frame = frame,
		setOpen = setOpen,
		isOpen = function()
			return open
		end,
		update = update,
		setBusy = setBusy,
	}
end

return HudLaunch
