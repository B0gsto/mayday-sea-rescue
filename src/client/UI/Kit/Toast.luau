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
	-- the look: art/source/ui/toast.html (des1 2026-10-28): a Lego brick with three studs on top, a gloss band,
	-- the icon big and hanging off the left end, heavy text with a drop shadow
	local h = S.toast
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
	local left = if o.icon then math.round(h * 0.96) else 28
	root.Size = UDim2.fromOffset(left + textW + 30, h)
	root.ZIndex = 20
	local grad = Style.grad(o.color or "orange")
	for i = 1, 3 do -- studs first, so the brick's top edge covers their feet
		local stud = Instance.new("Frame")
		stud.Name = "Stud"
		stud.AnchorPoint = Vector2.new(0.5, 0)
		stud.Position = UDim2.new((i + 0.5) / 4.5, 0, 0, -10)
		stud.Size = UDim2.fromOffset(22, 22)
		stud.BackgroundColor3 = Color3.new(1, 1, 1)
		stud.ZIndex = 0
		Style.corner(stud, 6)
		Style.stroke(stud, S.border, true)
		Style.gradient(stud, grad)
		stud.Parent = root
	end
	local radius = math.round(h * 0.28)
	local _, face = Style.block(root, grad, { radius = radius, shadow = true })
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.65
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.fromOffset(8, 5)
	gloss.Size = UDim2.new(1, -16, 0, math.round(h * 0.25))
	Style.corner(gloss, math.round(h * 0.13))
	gloss.Parent = face
	if o.icon then
		local ic = Instance.new("Frame")
		ic.Name = "IconHolder"
		ic.BackgroundTransparency = 1
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, -math.round(h * 0.23), 0.5, -4)
		ic.Size = UDim2.fromOffset(math.round(h * 1.13), math.round(h * 1.13))
		ic.ZIndex = 3
		ic.Parent = root
		Style.icon(ic, o.icon).ZIndex = 3
	end
	for _, shadow in { true, false } do -- an ink copy 3 du lower is the drop shadow
		local t = Style.label(face, text, Theme.Text.title)
		t.Name = if shadow then "TextShadow" else "Text"
		t.TextWrapped = false
		t.Position = UDim2.fromOffset(left, if shadow then 3 else 0)
		t.Size = UDim2.new(0, textW + 4, 1, 0)
		t.ZIndex = if shadow then 2 else 3 -- over the gloss
		if shadow then
			t.TextColor3 = Theme.Colors.ink
		end
	end
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
