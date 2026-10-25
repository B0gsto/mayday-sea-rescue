--!strict
-- Toast: a short pop message (icon + 1-4 words) at the top centre; pops in, holds, pops out.
-- One at a time per canvas (a new toast replaces the old).
--   Toast.show(canvas, "+250", { icon = "cash", color = "green" })   duration 0 = stays
local TextService = game:GetService("TextService")

local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local S = Theme.Size

export type Opts = { icon: string?, color: string?, duration: number? }

local Toast = {}

function Toast.show(canvas: Instance, text: string, opts: Opts?): Frame
	local o: Opts = opts or {}
	local old = canvas:FindFirstChild("KitToast")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Frame")
	root.Name = "KitToast"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 72)
	local textW = TextService:GetTextSize(
		text,
		Theme.Text.title,
		Enum.Font.FredokaOne,
		Vector2.new(2000, 200)
	).X
	local iconW = if o.icon then 64 else 0
	root.Size = UDim2.fromOffset(textW + iconW + (if o.icon then 40 else 56), S.toast)
	root.ZIndex = 20
	local _, face = Style.block(root, Style.grad(o.color or "orange"), { radius = S.toast / 2 })
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.fromScale(1, 1)
	r.Parent = face
	local l = Style.list(r, true, 8)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	if o.icon then
		local ic = Instance.new("Frame")
		ic.BackgroundTransparency = 1
		ic.Size = UDim2.fromOffset(56, 56)
		ic.Parent = r
		Style.icon(ic, o.icon)
	end
	local t = Style.label(r, text, Theme.Text.title)
	t.TextWrapped = false
	t.Size = UDim2.new(0, textW + 4, 1, 0)
	t.LayoutOrder = 1
	root.Parent = canvas
	Style.pop(root, true)
	local d = o.duration or 2.5
	if d > 0 then
		task.delay(d, function()
			if root.Parent then
				Style.tween(root, 0.3, { Position = UDim2.new(0.5, 0, 0, 40) })
				Style.pop(root, false)
				task.delay(0.4, function()
					root:Destroy()
				end)
			end
		end)
	end
	return root
end

return Toast
