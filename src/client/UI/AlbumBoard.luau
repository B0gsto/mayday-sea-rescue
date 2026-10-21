--!strict
-- AlbumBoard: the Rescue Album's stickers on the station board (docs/15 H2). The server builds the
-- board (Workspace.StationAlbumBoard); this local SurfaceGui draws one row per call kind, one
-- sticker slot per variant: a dark silhouette until the player rescues it, then its colour and
-- name inside the rarity frame. No interaction: the album is a display (no choice UI).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local A11yPalette = require(Shared:WaitForChild("A11yPalette"))
local Variants = require(Shared:WaitForChild("Config"):WaitForChild("RescueVariants"))

local PAPER = Color3.fromRGB(20, 34, 42)
local INK = Color3.fromRGB(238, 240, 236)
local DIM = Color3.fromRGB(150, 168, 178)
local GOLD = Color3.fromRGB(227, 167, 47)
local TYPE = Font.new("rbxasset://fonts/families/BuilderSans.json")

local KIND_ICON = {
	PersonInWater = "●",
	DisabledVessel = "▲",
	CliffCasualty = "◣",
	RipCurrent = "≈",
	SinkingVessel = "▼",
	VesselFire = "✦",
	WildlifeRescue = "❋",
}

export type View = { owned: { [string]: boolean }, ownedCount: number, total: number }
export type Board = { update: (view: View?) -> () }

local AlbumBoard = {}

local function label(
	parent: Instance,
	text: string,
	position: UDim2,
	size: UDim2,
	pixels: number,
	colour: Color3,
	bold: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Position = position
	l.Size = size
	l.FontFace =
		Font.new(TYPE.Family, if bold then Enum.FontWeight.Bold else Enum.FontWeight.Medium)
	l.TextSize = pixels
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

function AlbumBoard.mount(panel: BasePart): Board
	local gui = Instance.new("SurfaceGui")
	gui.Name = "AlbumPrint"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 88
	gui.LightInfluence = 0.15
	gui.MaxDistance = 90
	gui.ClipsDescendants = true
	gui.Adornee = panel
	gui.Parent = panel

	local root = Instance.new("Frame")
	root.Name = "Board"
	root.BackgroundColor3 = PAPER
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	local title =
		label(root, "RESCUE ALBUM", UDim2.fromOffset(0, 2), UDim2.new(1, 0, 0, 34), 28, GOLD, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local count = label(root, "", UDim2.new(1, -14, 0, 10), UDim2.fromOffset(88, 26), 22, INK, true)
	count.TextXAlignment = Enum.TextXAlignment.Right
	-- the five rarity colours and their symbols, a legend without words
	local legend = {}
	local x = 16
	for _, rarity in A11yPalette.States.Rarity do
		local dot = Instance.new("Frame")
		dot.Name = "RarityDot"
		dot.BackgroundColor3 = A11yPalette.colour("Rarity", rarity)
		dot.BorderSizePixel = 0
		dot.Position = UDim2.fromOffset(x, 42)
		dot.Size = UDim2.fromOffset(18, 7)
		dot.Parent = root
		local mark =
			label(root, "", UDim2.fromOffset(x + 20, 36), UDim2.fromOffset(16, 16), 13, INK, true)
		mark.Name = "RarityMark"
		table.insert(legend, { dot = dot, mark = mark, rarity = rarity })
		x += 38
	end

	local slots: {
		{
			outer: Frame,
			inner: Frame,
			text: TextLabel,
			mark: TextLabel,
			rarity: string,
			id: string,
			scaled: boolean,
		}
	} =
		{}
	for i, kind in Variants.KindOrder do
		local y = 62 + (i - 1) * 58
		local icon = label(
			root,
			KIND_ICON[kind] or "●",
			UDim2.fromOffset(6, y),
			UDim2.fromOffset(32, 34),
			30,
			GOLD,
			true
		)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		local name = label(
			root,
			Variants.KindLabel[kind] or kind,
			UDim2.fromOffset(2, y + 26),
			UDim2.fromOffset(120, 24),
			20,
			DIM,
			false
		)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.None
		local list: { Variants.Variant } = Variants.Kinds[kind] or {}
		-- a long row (wildlife's ten, the swimmer's twelve) shrinks its stickers to the panel width
		local compact = #list > 6
		local width = if compact then 40 else 70
		local height = if compact then 34 else 40
		local step = if compact then 44 else 78
		local startX = 128
		local room = 586 - startX
		if #list * step > room then
			step = math.floor(room / #list)
			width = math.min(width, step - 4)
		end
		for j, variant in list do
			local outer = Instance.new("Frame")
			outer.Name = variant.id
			outer.BackgroundColor3 = A11yPalette.colour("Rarity", variant.rarity)
			outer.BorderSizePixel = 0
			outer.Position = UDim2.fromOffset(startX + (j - 1) * step, y)
			outer.Size = UDim2.fromOffset(width, height)
			outer.Parent = root
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = outer
			local inner = Instance.new("Frame")
			inner.Name = "Sticker"
			inner.BackgroundColor3 = Color3.fromRGB(14, 24, 30)
			inner.BorderSizePixel = 0
			inner.Position = UDim2.fromOffset(2, 2)
			inner.Size = UDim2.new(1, -4, 1, -4)
			inner.Parent = outer
			local innerCorner = Instance.new("UICorner")
			innerCorner.CornerRadius = UDim.new(0, 4)
			innerCorner.Parent = inner
			local text =
				label(inner, "?", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18, DIM, true)
			text.TextScaled = compact
			local mark =
				label(inner, "", UDim2.new(1, -2, 0, 0), UDim2.fromOffset(14, 13), 12, INK, true)
			mark.Name = "RarityMark"
			mark.AnchorPoint = Vector2.new(1, 0)
			mark.TextXAlignment = Enum.TextXAlignment.Right
			table.insert(slots, {
				outer = outer,
				inner = inner,
				text = text,
				mark = mark,
				rarity = variant.rarity :: string,
				id = variant.id,
				scaled = compact,
			})
		end
	end

	local function applyPalette()
		for _, item in legend do
			item.dot.BackgroundColor3 = A11yPalette.colour("Rarity", item.rarity)
			item.mark.Text = A11yPalette.symbol("Rarity", item.rarity)
		end
		for _, slot in slots do
			slot.outer.BackgroundColor3 = A11yPalette.colour("Rarity", slot.rarity)
			slot.mark.Text = A11yPalette.symbol("Rarity", slot.rarity)
		end
	end

	A11yPalette.onChanged(applyPalette)

	local function update(view: View?)
		local owned = if view then view.owned else {}
		for _, slot in slots do
			local def = Variants.ById(slot.id)
			local has = owned[slot.id] == true
			if def and has then
				slot.inner.BackgroundColor3 = def.accent
				slot.text.Text = def.label
				slot.text.TextColor3 = INK
				slot.text.TextSize = if slot.scaled then 13 else 15
			else
				slot.inner.BackgroundColor3 = Color3.fromRGB(14, 24, 30)
				slot.text.Text = "?"
				slot.text.TextColor3 = Color3.fromRGB(88, 106, 116)
				slot.text.TextSize = if slot.scaled then 16 else 18
			end
		end
		count.Text = if view then `{view.ownedCount}/{view.total}` else "--"
	end

	local board: Board = { update = update }
	update(nil)
	return board
end

return AlbumBoard
