--!strict
-- UnlockFly (docs/28 feel 6): what a finished level unlocked, shown not told. Its icon pops off the roof as a
-- sticker tile and flies on an arc to the button that now holds something new (Crew, Boat, Quests) or to the Next
-- chip, then pops into it. One pop, no pulse; FX_Pop as it leaves the roof, UI_Step as it lands. Reduce motion: it
-- pops in at the button instead of flying. Client only.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Style = require(script.Parent:WaitForChild("Kit"):WaitForChild("Style"))

local player = Players.LocalPlayer

local ICON = { Crew = "crew", Boat = "boat_to_me", Quests = "quests", Next = "build" }
local GRAD = { Crew = "teal", Boat = "red", Quests = "orange", Next = "blue" } -- the Menu buttons' own colours
local TILE = 72 -- px: over the 32 pt phone minimum at any HUD scale

-- The target on screen (viewport px, the button's centre) and its size; a hidden button falls back to the Next chip.
local function find(target: string): (Vector2?, number)
	local pg = player:FindFirstChild("PlayerGui")
	local menu = pg and pg:FindFirstChild("Menu")
	local obj = if target == "Next"
		then pg and pg:FindFirstChild("NextChip", true)
		else menu and menu:FindFirstChild(`Menu_{target}`, true)
	local gui = obj and obj:FindFirstAncestorWhichIsA("ScreenGui")
	if
		obj
		and gui
		and obj:IsA("GuiObject")
		and obj.Visible
		and gui.Enabled
		and obj.AbsoluteSize.X > 1
	then
		local off = if gui.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
		local size = math.min(obj.AbsoluteSize.X, obj.AbsoluteSize.Y)
		return obj.AbsolutePosition + obj.AbsoluteSize / 2 + off, size
	end
	if target ~= "Next" then
		return find("Next")
	end
	return nil, 0
end

local UnlockFly = {}

-- `roof`: the world point it pops off; `target`: BuildSeq.unlockTarget's "Crew" | "Boat" | "Quests" | "Next".
function UnlockFly.play(roof: Vector3, target: string)
	local cam = Workspace.CurrentCamera
	local to, toSize = find(target)
	local pg = player:FindFirstChild("PlayerGui")
	if not (cam and to and pg) then
		return
	end
	local at, onScreen = cam:WorldToViewportPoint(roof)
	local reduced = Comfort.reducedMotion()
	local from = if reduced
		then to
		elseif onScreen then Vector2.new(at.X, at.Y)
		else cam.ViewportSize / 2
	local gui = Instance.new("ScreenGui")
	gui.Name = "UnlockFly"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 42
	gui.Parent = pg
	local tile = Instance.new("CanvasGroup")
	tile.Name = "Tile"
	tile.BackgroundTransparency = 1
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Size = UDim2.fromOffset(TILE, TILE)
	tile.Position = UDim2.fromOffset(from.X, from.Y)
	tile.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = tile
	local _, face = Style.block(tile, Style.grad(GRAD[target] or "blue"), { radius = 16, lip = 5 })
	local art = Instance.new("Frame")
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.7, 0.7)
	art.Parent = face
	Style.icon(art, ICON[target] or "build")

	local function tween(
		inst: Instance,
		t: number,
		props: { [string]: any },
		style: Enum.EasingStyle?,
		dir: Enum.EasingDirection?
	)
		local tw = TweenService:Create(
			inst,
			TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
			props
		)
		tw:Play()
		return tw
	end
	-- the pop off the roof: anticipation (grows past full with a hop), a short hold so the eye finds it
	AudioController.play("FX_Pop", nil, 0.8, 1.05)
	tween(scale, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
	local rise = from - Vector2.new(0, if reduced then 0 else 44)
	tween(tile, 0.3, { Position = UDim2.fromOffset(rise.X, rise.Y) })
	task.wait(0.55)
	if not reduced then
		-- the flight: a quadratic arc that bows up and away from the target, shrinking to the button's size
		local control = (rise + to) / 2 + Vector2.new(0, -math.max((rise - to).Magnitude * 0.3, 60))
		local t = Instance.new("NumberValue")
		t.Changed:Connect(function(u: number)
			local p = rise:Lerp(control, u):Lerp(control:Lerp(to, u), u)
			tile.Position = UDim2.fromOffset(p.X, p.Y)
		end)
		local fly = 0.6
		tween(t, fly, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		tween(
			scale,
			fly,
			{ Scale = math.clamp(toSize / TILE, 0.5, 1) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		task.wait(fly)
		t:Destroy()
	end
	-- it lands: one pop into the button, then gone
	AudioController.play("UI_Step", nil, 0.8, 1.2)
	tween(scale, 0.22, { Scale = scale.Scale * 1.35 })
	tween(tile, 0.22, { GroupTransparency = 1 })
	task.delay(0.25, gui.Destroy, gui)
end

return UnlockFly
