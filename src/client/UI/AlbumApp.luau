--!strict
-- AlbumApp: the phone's sticker album (docs/21 §3, package C1). One page per island: its name ("?" until
-- sighted), a found/total counter, the round island stamp and the collectible stickers as grey
-- silhouettes until found; a completed page gets a gold border. Tap a sticker for a big view; tap again,
-- gamepad B or Backspace closes it. Touch / mouse tap; keyboard and gamepad use the phone's selection
-- navigation (arrows / d-pad, Return / A).
--   AlbumApp.mount(page: Frame) -> cleanup
--   AlbumApp.icon(image: ImageLabel)   the home-screen tile until UiImages.Phone.Album has art
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DiscoveryRules"))

local Client = script.Parent.Parent
local DiscoveryController =
	require(Client:WaitForChild("Controllers"):WaitForChild("DiscoveryController"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local Sticker = require(script.Parent:WaitForChild("Sticker"))
local Telemetry = require(Client:WaitForChild("Telemetry"))

local AlbumApp = {}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFD06A")
local TEAL = Color3.fromHex("1FB5A8")
local STAMP = 68
local SMALL = 50

-- shortcut: a code-drawn tile, replace with UiImages.Phone.Album once docs/18's icon is uploaded
function AlbumApp.icon(image: ImageLabel)
	image.BackgroundTransparency = 0
	image.BackgroundColor3 = TEAL
	HudTheme.corner(image, 15)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.7, 0.7)
	holder.BackgroundTransparency = 1
	holder.Parent = image
	local f = Sticker.draw(holder, "GannetRock", "Stamp", true)
	local face = f:FindFirstChild("Face")
	if face and face:IsA("Frame") then
		face.BackgroundColor3 = Color3.fromHex("0E7F76")
	end
end

local function button(name: string, size: number, order: number, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(size, size)
	b.LayoutOrder = order
	b.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		scale.Scale = 0.92
	end)
	b.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	b.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	b.SelectionGained:Connect(function()
		scale.Scale = 1.08
	end)
	b.SelectionLost:Connect(function()
		scale.Scale = 1
	end)
	return b
end

function AlbumApp.mount(page: Frame): () -> ()
	Telemetry.shop("AppOpened", "Explore")
	local conns: { RBXScriptConnection } = {}

	local root = Instance.new("ScrollingFrame")
	root.Name = "Album"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ScrollBarThickness = 4
	root.ScrollingDirection = Enum.ScrollingDirection.Y
	root.CanvasSize = UDim2.new()
	root.AutomaticCanvasSize = Enum.AutomaticSize.Y
	root.Selectable = false
	root.Parent = page
	HudTheme.padding(root, 8)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = root

	-- the big view over the page
	local overlay = Instance.new("TextButton")
	overlay.Name = "BigSticker"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.25
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = page
	local big = Instance.new("Frame")
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.45)
	big.Size = UDim2.fromScale(0.75, 0.75)
	big.SizeConstraint = Enum.SizeConstraint.RelativeXX
	big.BackgroundTransparency = 1
	big.ZIndex = 10
	big.Parent = overlay
	local bigName =
		HudTheme.label("Name", "", UDim2.new(1, 0, 0, 30), HudTheme.NumberFont, 26, overlay)
	bigName.AnchorPoint = Vector2.new(0.5, 0)
	bigName.Position = UDim2.fromScale(0.5, 0.45)
	bigName.TextXAlignment = Enum.TextXAlignment.Center
	bigName.ZIndex = 11
	HudTheme.outline(bigName)
	local returnTo: GuiObject? = nil

	local function close()
		if not overlay.Visible then
			return
		end
		overlay.Visible = false
		ContextActionService:UnbindAction("AlbumBack")
		if returnTo and returnTo.Parent and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = returnTo
		end
	end
	local function show(from: GuiObject, islandId: string, stickerId: string, found: boolean)
		for _, c in big:GetChildren() do
			c:Destroy()
		end
		local f = Sticker.draw(big, islandId, stickerId, found)
		for _, d in f:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 11
			end
		end
		bigName.Text = if stickerId == "Stamp" and found then Rules.ById[islandId].name else ""
		bigName.Position = UDim2.new(0.5, 0, 0.45, big.AbsoluteSize.Y / 2 + 12)
		overlay.Visible = true
		returnTo = from
		ContextActionService:BindActionAtPriority(
			"AlbumBack",
			function(_, s)
				if s == Enum.UserInputState.Begin then
					close()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value + 20, -- above the phone's own Back
			Enum.KeyCode.ButtonB,
			Enum.KeyCode.Backspace
		)
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = overlay
		end
	end
	table.insert(conns, overlay.Activated:Connect(close))

	local function build()
		for _, c in root:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local state = DiscoveryController.State()
		for order, isle in Rules.Pages do
			local card = Instance.new("Frame")
			card.Name = isle.id
			card.LayoutOrder = order
			card.Size = UDim2.new(1, -4, 0, STAMP + 48)
			card.Parent = root
			HudTheme.skin(card)
			local done = Rules.complete(state, isle.id)
			if done then
				local edge = card:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
				edge.Color = GOLD
				edge.Thickness = 3
				edge.Transparency = 0
				edge.Parent = card
			end
			local sighted = Rules.has(state, isle.id, Rules.SIGHTED)
			local title = HudTheme.label(
				"Title",
				if sighted then isle.name else "?",
				UDim2.new(1, -70, 0, 26),
				HudTheme.HeaderFont,
				18,
				card
			)
			title.Position = UDim2.fromOffset(12, 6)
			title.TextColor3 = WHITE
			local n, total = Rules.count(state, isle.id)
			local count = HudTheme.label(
				"Count",
				`{n}/{total}`,
				UDim2.fromOffset(56, 26),
				HudTheme.NumberFont,
				18,
				card
			)
			count.AnchorPoint = Vector2.new(1, 0)
			count.Position = UDim2.new(1, -10, 0, 6)
			count.TextXAlignment = Enum.TextXAlignment.Right
			count.TextColor3 = if done then GOLD else HudTheme.Colors.textDim

			local row = Instance.new("Frame")
			row.Name = "Row"
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromOffset(8, 36)
			row.Size = UDim2.new(1, -16, 0, STAMP)
			row.Parent = card
			local h = Instance.new("UIListLayout")
			h.FillDirection = Enum.FillDirection.Horizontal
			h.VerticalAlignment = Enum.VerticalAlignment.Center
			h.Padding = UDim.new(0, 6)
			h.SortOrder = Enum.SortOrder.LayoutOrder
			h.Parent = row
			for i, s in isle.stickers do
				local found = Rules.has(state, isle.id, s.bit)
				local b = button(s.id, if s.kind == "Stamp" then STAMP else SMALL, i, row)
				Sticker.draw(b, isle.id, s.id, found)
				table.insert(
					conns,
					b.Activated:Connect(function()
						show(b, isle.id, s.id, found)
					end)
				)
			end
		end
	end

	table.insert(conns, DiscoveryController.Changed:Connect(build))
	build()

	return function()
		close()
		for _, c in conns do
			c:Disconnect()
		end
		overlay:Destroy()
		root:Destroy()
	end
end

return AlbumApp
