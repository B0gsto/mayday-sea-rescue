--!strict
-- Portrait (audit P1-9): a survivor's head-and-shoulders render on a rarity card, for the Crew panel, the
-- survivor card and the Album specials. The model is a clone of the same WorkerRigs template the world rig
-- uses (WorkerRules.rigOf), with a collar in their category colour, lit from the front-left.
--   Portrait.back(parent, rarity) -> face    the rarity gradient card + rarity border (Mythic: rainbow)
--   Portrait.render(holder, rig, category, dim?) -> ViewportFrame?   nil while the templates load
--   Portrait.lazy(scroll, slots) -> stop    renders a slot only while it is on screen in `scroll`
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rarity"))
local Style = require(script.Parent:WaitForChild("Kit"):WaitForChild("Style"))
local SurvivorTag = require(script.Parent:WaitForChild("SurvivorTag"))
local WorkerBadge = require(script.Parent:WaitForChild("WorkerBadge"))

local Portrait = {}

export type Slot = {
	holder: GuiObject,
	rig: number,
	category: string,
	dim: boolean?,
	view: ViewportFrame?,
}

local MARGIN = 80 -- px past the scroll edges a slot is built early, so a fast scroll never shows it empty
local DIM = Color3.fromRGB(125, 128, 140) -- waiting on the jetty

function Portrait.back(parent: Instance, rarity: number): Frame
	local tier = Rarity.TIERS[math.clamp(rarity, 1, Rarity.MYTHIC)]
	local _, face = Style.block(parent, Style.grad(tier.kit))
	local ring = Instance.new("Frame")
	ring.Name = "RarityBorder"
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.fromOffset(4, 4)
	ring.Size = UDim2.new(1, -8, 1, -8)
	Style.corner(ring, 10)
	local stroke = Style.stroke(ring, 3, true)
	stroke.Color = tier.color
	if rarity >= Rarity.MYTHIC then
		stroke.Color = Color3.new(1, 1, 1)
		local rainbow = Instance.new("UIGradient") -- static: the tag's rainbow, no per-frame spin
		rainbow.Color = SurvivorTag.RAINBOW
		rainbow.Rotation = 45
		rainbow.Parent = stroke
	end
	ring.Parent = face
	return face
end

function Portrait.render(
	holder: GuiObject,
	rig: number,
	category: string,
	dim: boolean?
): ViewportFrame?
	local rigs = ReplicatedStorage:FindFirstChild("WorkerRigs")
	local tpl = rigs and rigs:FindFirstChild(tostring(rig))
	if not (tpl and tpl:IsA("Model")) then
		return nil
	end
	local model = tpl:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model:PivotTo(CFrame.new())
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not (head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		model:Destroy()
		return nil
	end
	if torso and torso:IsA("BasePart") then -- a collar in their category colour
		local collar = Instance.new("Part")
		collar.Name = "Collar"
		collar.Anchored = true
		collar.Material = Enum.Material.SmoothPlastic
		collar.Color = Style.grad(WorkerBadge.GRAD[category] or "teal").top
		collar.Size = Vector3.new(torso.Size.X * 0.62, 0.32, torso.Size.Z * 1.08)
		collar.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - 0.12, 0)
		collar.Parent = model
	end

	local k = head.Size.Y / 1.2 -- scaled bodies keep the same framing
	local focus = head.Position - Vector3.new(0, 0.45 * k, 0)
	local dir = CFrame.Angles(0, math.rad(20), 0):VectorToWorldSpace(root.CFrame.LookVector) -- three-quarter
	local cam = Instance.new("Camera")
	cam.FieldOfView = 26
	cam.CFrame = CFrame.lookAt(focus + dir * 7.5 * k + Vector3.new(0, 0.5 * k, 0), focus)

	local view = Instance.new("ViewportFrame")
	view.Name = "Portrait"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(190, 190, 200) -- dark rigs read almost black at 150
	view.LightColor = Color3.fromRGB(255, 244, 226)
	view.LightDirection = Vector3.new(0.6, -1, 0) - dir -- a warm key light from above, camera side
	view.ImageColor3 = if dim then DIM else Color3.new(1, 1, 1)
	view.CurrentCamera = cam
	cam.Parent = view
	model.Parent = view
	Style.corner(view, 10)
	view.Parent = holder
	return view
end

-- Builds each slot's viewport while it overlaps `scroll` (plus MARGIN) and destroys it once it leaves:
-- only the visible handful are ever live. Runs on scroll / resize events, never per frame.
function Portrait.lazy(scroll: ScrollingFrame, slots: { Slot }): () -> ()
	local function update()
		local top = scroll.AbsolutePosition.Y - MARGIN
		local bottom = scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y + MARGIN
		for _, s in slots do
			local y = s.holder.AbsolutePosition.Y
			local on = s.holder.Parent ~= nil and y + s.holder.AbsoluteSize.Y > top and y < bottom
			if on and not s.view then
				s.view = Portrait.render(s.holder, s.rig, s.category, s.dim)
			elseif not on and s.view then
				s.view:Destroy()
				s.view = nil
			end
		end
	end
	local conns = {
		scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(update),
		scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
		scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(update),
	}
	task.defer(update) -- after the layouts place the new cards
	return function()
		for _, c in conns do
			c:Disconnect()
		end
	end
end

return Portrait
