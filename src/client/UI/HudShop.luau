--!strict
-- HudShop: the Chandlery gear counter panel (docs 04 section 1.1: no shop button on the HUD). It
-- opens only from the "ShopCounter" ProximityPrompt at the Port Haven Chandlery counter (wired by
-- HudController, which also closes it when the player walks away). One row per gear item: name,
-- effect, level pips and a buy button (price, or the rank needed, or MAX). Buying calls the onBuy
-- callback (BuyGear on the server).
-- It also mounts the Robux product cards (UI/ProductCard, RP-M3: Chandlery shelves, the harbourmaster's
-- desk, the BoatDesk Quick Launch card) and forwards the data snapshots to them. One store panel at a
-- time: opening a card closes this counter, and the E that opened a card (HudController's unprocessed-E
-- fallback can see the counter prompt in range too) does not reopen the counter right after.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudTheme = require(script.Parent.HudTheme)
local InputGlyph = require(script.Parent.InputGlyph)
local ProductCard = require(script.Parent.ProductCard)
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))

local C = HudTheme.Colors

export type Shop = {
	frame: Frame,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	update: (snapshot: { [string]: any }) -> (),
}

local HudShop = {}

function HudShop.build(parent: Instance, onBuy: (itemId: string) -> ()): Shop
	local rowHeight = 84
	local count = #ProgressionConfig.GearOrder
	local frame =
		HudTheme.panel("GearCounter", UDim2.fromOffset(400, 70 + count * (rowHeight + 10)), parent)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Visible = false
	HudTheme.padding(frame, 14)

	local title =
		HudTheme.label("Title", "GEAR", UDim2.new(1, -60, 0, 36), HudTheme.HeaderFont, 24, frame)
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

	type Row = { pips: { Frame }, buy: TextButton, info: TextLabel }
	local rows: { [string]: Row } = {}
	for order, id in ProgressionConfig.GearOrder do
		local item = ProgressionConfig.Gear[id]
		local row = Instance.new("Frame")
		row.Name = id
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, rowHeight)
		row.BackgroundColor3 = C.panelLight
		row.BackgroundTransparency = 0.35
		HudTheme.corner(row, 12)
		HudTheme.padding(row, 10)
		row.Parent = list

		HudTheme.label(
			"Name",
			item.displayName,
			UDim2.new(1, -130, 0, 26),
			HudTheme.HeaderFont,
			22,
			row
		)
		local info = HudTheme.label(
			"Info",
			item.description,
			UDim2.new(1, -130, 0, 20),
			HudTheme.BodyFont,
			16,
			row
		)
		info.Position = UDim2.fromOffset(0, 26)
		info.TextColor3 = C.textDim

		local pips: { Frame } = {}
		for level = 1, Rules.maxGearLevel() do
			local pip = Instance.new("Frame")
			pip.Name = `Pip{level}`
			pip.Size = UDim2.fromOffset(22, 10)
			pip.Position = UDim2.fromOffset((level - 1) * 28, 52)
			pip.BorderSizePixel = 0
			pip.BackgroundColor3 = C.locked
			HudTheme.corner(pip, 5)
			pip.Parent = row
			table.insert(pips, pip)
		end

		local buy = HudTheme.button("Buy", "", UDim2.fromOffset(120, HudTheme.MinButtonHeight), row)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.fromScale(1, 0.5)
		buy.TextSize = 18
		buy.Activated:Connect(function()
			onBuy(id)
		end)
		rows[id] = { pips = pips, buy = buy, info = info }
	end

	local CARD_GRACE = 0.3 -- seconds after a product card opens in which the counter stays shut
	local open = false
	local cardOpenedAt = -math.huge
	local card: ProductCard.Card
	local modal: InputGlyph.Modal
	local api: Shop
	local firstBuy = rows[ProgressionConfig.GearOrder[1]]
	local function setOpen(value: boolean)
		if value and os.clock() - cardOpenedAt < CARD_GRACE then
			return
		end
		if value ~= open then
			if value then
				modal.open(if firstBuy then firstBuy.buy else close)
			else
				modal.close()
			end
		end
		open = value
		frame.Visible = value
		if value and card then
			card.close()
		end
	end
	modal = InputGlyph.modal("GearCounter", function()
		api.setOpen(false) -- through the table: HudController wraps setOpen
	end)
	card = ProductCard.mount(function()
		cardOpenedAt = os.clock()
		setOpen(false)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local function update(snapshot: { [string]: any })
		card.setSnapshot(snapshot)
		local data = Rules.defaultData()
		data.cash = snapshot.cash or 0
		data.rep = snapshot.rep or 0
		data.gear = snapshot.gear or {}
		for id, row in rows do
			local level = data.gear[id] or 0
			for i, pip in row.pips do
				pip.BackgroundColor3 = if i <= level then C.accent else C.locked
			end
			local ok, reason, price = Rules.canBuyGear(data, id)
			if reason == "Max level" then
				row.buy.Text = "MAX"
				row.buy.BackgroundColor3 = C.locked
			elseif reason:sub(1, 6) == "Needs " then
				row.buy.Text = reason:sub(7)
				row.buy.BackgroundColor3 = C.locked
			else
				row.buy.Text = HudTheme.formatNumber(price)
				row.buy.BackgroundColor3 = if ok then C.accent else C.locked
			end
		end
	end

	api = {
		frame = frame,
		setOpen = setOpen,
		isOpen = function()
			return open
		end,
		update = update,
	}
	return api
end

return HudShop
