--!strict
-- Dialog: NPC talk (CLAUDE.md exception, docs/14 section 2). A name plate, the NPC's short line
-- in a white bubble, and 1-3 numbered reply buttons. Keys 1/2/3, tap, or gamepad select + A.
--   local d = Dialog.new(canvas, { name = "Harbour Master", line = "Storm's coming!",
--       replies = { "On my way!", "Need a boat", "Later" }, onReply = function(i) end })
--   d.close()
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local S = Theme.Size
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

export type Props = {
	name: string,
	line: string?,
	replies: { string },
	color: string?, -- name plate accent (default "orange")
	portrait: string?, -- a UiImages.Kit icon name or an rbxassetid:// image, in a round frame
	onReply: ((number) -> ())?,
}
export type Dialog = { root: Frame, close: () -> () }

local Dialog = {}

function Dialog.new(canvas: Instance, props: Props): Dialog
	assert(#props.replies >= 1 and #props.replies <= 3, "Dialog: 1-3 replies")
	local vp, scale = Style.metrics(canvas)
	local width = math.min(S.dialogWidth, vp.X * 0.94 / scale)
	local action = "KitDialog" .. tostring(math.random(1, 1e9))

	local root = Instance.new("Frame")
	root.Name = "KitDialog"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -S.margin)
	root.Size = UDim2.fromOffset(width, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.ZIndex = 10
	local list = Style.list(root, false, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- bubble with a round portrait and the name plate on its top-left edge
	local inset = if props.portrait then 104 else 0
	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.BackgroundTransparency = 1
	bubble.Size = UDim2.new(1, 0, 0, if props.line then 112 else 44)
	bubble.Parent = root
	if props.line then
		local box = Instance.new("Frame")
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromOffset(0, 24)
		box.Size = UDim2.new(1, 0, 1, -24)
		box.Parent = bubble
		local white = { top = Color3.new(1, 1, 1), bottom = Color3.fromHex("DCE7F5") }
		local _, face = Style.block(box, white, { lip = 6 })
		local t = Style.label(face, props.line, Theme.Text.body + 2, true)
		t.Position = UDim2.fromOffset(20 + inset, 18)
		t.Size = UDim2.new(1, -40 - inset, 1, -22)
		t.TextXAlignment = Enum.TextXAlignment.Left
	end
	if props.portrait then
		local ring = Instance.new("Frame")
		ring.Name = "Portrait"
		ring.BackgroundColor3 = Color3.new(1, 1, 1)
		ring.Position = UDim2.fromOffset(-8, -14)
		ring.Size = UDim2.fromOffset(100, 100)
		ring.ZIndex = 3
		Style.corner(ring, 50)
		Style.stroke(ring, S.border, true)
		Style.gradient(ring, Style.grad(props.color or "orange"))
		ring.Parent = bubble
		local art = Instance.new("Frame")
		art.BackgroundTransparency = 1
		art.Position = UDim2.fromScale(0.12, 0.12)
		art.Size = UDim2.fromScale(0.76, 0.76)
		art.ZIndex = 3
		art.Parent = ring
		if string.find(props.portrait, "://", 1, true) then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = props.portrait
			img.Size = UDim2.fromScale(1, 1)
			img.ZIndex = 3
			img.Parent = art
		else
			Style.icon(art, props.portrait).ZIndex = 3
		end
	end
	local nameSize = TextService:GetTextSize(
		props.name,
		Theme.Text.heading,
		Enum.Font.FredokaOne,
		Vector2.new(2000, 200)
	)
	local plate = Instance.new("Frame")
	plate.Name = "Name"
	plate.BackgroundTransparency = 1
	plate.Position = UDim2.fromOffset(16 + inset * 0.85, -8)
	plate.Size = UDim2.fromOffset(nameSize.X + 52, 52)
	plate.ZIndex = 2
	plate.Parent = bubble
	local grad = Style.grad(props.color or "orange")
	local _, pf = Style.block(plate, grad, { radius = 26, lip = 5, studs = true })
	Style.label(pf, props.name, Theme.Text.heading)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		ContextActionService:UnbindAction(action)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
		Style.pop(root, false)
		task.delay(0.3, function()
			root:Destroy()
		end)
	end
	local function reply(i: number)
		if closed then
			return
		end
		if props.onReply then
			props.onReply(i)
		end
	end

	for i, text in props.replies do
		local b = Style.button(root, UDim2.new(1, -40, 0, S.reply))
		b.Name = "Reply" .. i
		b.LayoutOrder = i
		local _, face = Style.block(
			b,
			Style.grad(if i == 1 then "green" else "blue"),
			{ radius = S.cornerSmall, studs = true }
		)
		local num = Instance.new("Frame")
		num.BackgroundTransparency = 1
		num.AnchorPoint = Vector2.new(0, 0.5)
		num.Position = UDim2.new(0, 8, 0.5, 0)
		num.Size = UDim2.fromOffset(S.reply - 18, S.reply - 18)
		num.Parent = face
		local _, nf = Style.block(num, Theme.Grad.ink, { radius = 8, lip = 3, border = 3 })
		Style.label(nf, tostring(i), Theme.Text.body)
		local t = Style.label(face, text, Theme.Text.body + 2)
		t.TextWrapped = false
		t.Position = UDim2.fromOffset(S.reply, 0)
		t.Size = UDim2.new(1, -S.reply * 2, 1, 0)
		Style.press(b, function()
			reply(i)
		end, S.cornerSmall)
	end

	ContextActionService:BindActionAtPriority(action, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local i = table.find(KEYS, input.KeyCode)
		if i and i <= #props.replies then
			reply(i)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(KEYS))

	root.Parent = canvas
	Style.pop(root, true)
	root.Destroying:Connect(function()
		ContextActionService:UnbindAction(action)
	end)
	return { root = root, close = close }
end

return Dialog
