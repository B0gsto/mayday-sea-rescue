--!strict
-- Album panel: one card per discovery page. A page shows its found stickers; tapping a card opens
-- a larger page so a small sticker can be read. State comes from DiscoveryController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DiscoveryController = require(
	script.Parent.Parent.Parent:WaitForChild("Controllers"):WaitForChild("DiscoveryController")
)
local Rules = require(Shared:WaitForChild("DiscoveryRules"))
local Sticker = require(script.Parent.Parent:WaitForChild("Sticker"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local S = Theme.Size
local Album = {}

local function fullPage(state: Rules.State, id: string): boolean
	return Rules.complete(state, id)
end

function Album.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Album",
		icon = "album",
		size = Vector2.new(800, 600),
		onClose = onClose,
	})
	local preview: GuiObject? = nil

	local function closePreview()
		if preview then
			local old = preview
			preview = nil
			old:Destroy()
		end
	end

	local function showPage(page: Rules.Page)
		closePreview()
		local shade = Instance.new("TextButton")
		shade.Name = "StickerPreview"
		shade.Text = ""
		shade.AutoButtonColor = false
		shade.BackgroundColor3 = Theme.Colors.shadow
		shade.BackgroundTransparency = 0.35
		shade.Size = UDim2.fromScale(1, 1)
		shade.ZIndex = 8
		shade.Parent = panel.root
		preview = shade
		shade.Activated:Connect(closePreview)

		local card = Instance.new("Frame")
		card.BackgroundTransparency = 1
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.Size = UDim2.fromOffset(620, 400)
		card.ZIndex = 9
		card.Parent = shade
		local _, face = Style.block(card, Style.grad("blue"), { shadow = true, lip = 10 })
		local title = Style.label(face, page.name, Theme.Text.title)
		title.Position = UDim2.fromOffset(24, 8)
		title.Size = UDim2.new(1, -48, 0, 54)
		title.ZIndex = 10
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.5, 0.56)
		row.Size = UDim2.new(1, -40, 1, -100)
		row.ZIndex = 10
		row.Parent = face
		local list = Style.list(row, true, 18)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		for _, s in page.stickers do
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			cell.Size = UDim2.fromOffset(160, 210)
			cell.ZIndex = 10
			cell.Parent = row
			Sticker.draw(
				cell,
				page.id,
				s.id,
				Rules.has(DiscoveryController.State(), page.id, s.bit)
			)
			local name =
				Style.label(cell, if s.id == "Stamp" then page.name else s.id, Theme.Text.small)
			name.Position = UDim2.new(0, 0, 1, -42)
			name.Size = UDim2.new(1, 0, 0, 34)
			name.ZIndex = 10
		end
		local close = Style.button(face, UDim2.fromOffset(S.close, S.close + S.lip))
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, -12, 0, 12)
		close.ZIndex = 11
		local _, xFace = Style.block(close, Style.grad("close"))
		Style.label(xFace, "X", Theme.Text.title).ZIndex = 12
		Style.press(close, closePreview)
	end

	local function rebuild()
		closePreview()
		for _, c in panel.body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local state = DiscoveryController.State()
		local host = Instance.new("Frame")
		host.Name = "Pages"
		host.BackgroundTransparency = 1
		host.Size = UDim2.fromScale(1, 0)
		host.AutomaticSize = Enum.AutomaticSize.Y
		host.Parent = panel.body
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(188, 210)
		grid.CellPadding = UDim2.fromOffset(14, 14)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = host
		for order, page in Rules.Pages do
			local found, total = Rules.count(state, page.id)
			local complete = fullPage(state, page.id)
			local card = Style.button(host, UDim2.fromOffset(188, 210))
			card.Name = "Page_" .. page.id
			card.LayoutOrder = order
			local _, face = Style.block(card, Style.grad(if complete then "yellow" else "blue"))
			local art = Instance.new("Frame")
			art.BackgroundTransparency = 1
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.fromScale(0.5, 0.05)
			art.Size = UDim2.fromOffset(128, 128)
			art.Parent = face
			Sticker.draw(art, page.id, "Stamp", Rules.has(state, page.id, 4))
			local name = Style.label(face, page.name, Theme.Text.small)
			name.Position = UDim2.new(0, 8, 1, -54)
			name.Size = UDim2.new(1, -16, 0, 28)
			name.TextWrapped = false
			local count = Style.label(face, `{found}/{total}`, Theme.Text.small)
			count.Position = UDim2.new(0, 8, 1, -28)
			count.Size = UDim2.new(1, -16, 0, 24)
			Style.press(card, function()
				showPage(page)
			end)
		end
	end

	rebuild()
	DiscoveryController.Changed:Connect(function()
		if panel.isOpen() then
			rebuild()
		end
	end)

	return {
		open = function()
			panel.open()
			rebuild()
		end,
		close = function()
			closePreview()
			panel.close()
		end,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Album
