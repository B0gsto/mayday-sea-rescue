--!strict
-- Waypoint (playtest 2026-10-23: a new player could not find the second call): the way to the
-- call, in the world. MapController's objective (the offered call, the nearest survivor or vessel,
-- the drop-off once they are aboard) gets a screen marker (no light pillar: user, 2026-10-21): the call-type icon on a disc
-- (OpsTaskingCard.KIND) with its distance under it, pinned to the screen edge with its tip pointing
-- the way while off screen. Hidden in the cold open (ColdOpenCue
-- owns it), under the phone or the full map, and in cinematics (OpsUiHidden). Mounted by OpsHud.
--   Waypoint.start(ops, map, onDistance)  onDistance("240 m" | nil) each frame, for the strip
--   Waypoint.metres(studs) -> "240 m" | "1.2 km"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Glyph = require(script.Parent.Glyph)
local HudTheme = require(script.Parent.HudTheme)
local Layout = require(script.Parent.Layout)
local OpsTaskingCard = require(script.Parent.OpsTaskingCard)

local Waypoint = {}

local NAVY = Color3.fromHex("0A1830")
local GREEN = Color3.fromHex("2FA866") -- the strip's "Home" disc
local BEAM = Color3.fromHex("FF6A3D")
local STUDS_PER_M = 3
local NEAR = 25 * STUDS_PER_M -- studs: this close the survivor is right there, the marker steps aside
local DISC = 46 -- du
local LIFT = 34 -- px: the disc floats over the target, its tip pointing down at it
local RIM = Vector2.new(0.36, 0.28) -- the pin ellipse's radii, share of the screen (down)
local RIM_UP = 0.24 -- its upward radius: the top band holds the strip and the radio
local SHOWN: { [string]: boolean } =
	{ Mayday = true, Casualty = true, Vessel = true, ["Drop-off"] = true }

function Waypoint.metres(studs: number): string
	local m = studs / STUDS_PER_M
	return if m >= 1000
		then string.format("%.1f km", m / 1000)
		else `{math.floor(m / 10 + 0.5) * 10} m`
end

function Waypoint.start(ops: any, map: any, onDistance: (string?) -> ())
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Waypoint"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- viewport pixels, as WorldToViewportPoint gives them
	gui.DisplayOrder = 15
	gui.Parent = playerGui

	local mark = Instance.new("Frame")
	mark.Name = "Mark"
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Size = UDim2.fromOffset(DISC, DISC)
	mark.BackgroundTransparency = 1
	mark.Visible = false
	mark.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Parent = mark
	local function refit(mt: Layout.Metrics)
		fit.Scale = math.clamp(mt.scale, 0.8, 1.3)
	end
	refit(Layout.current())
	Layout.onMetrics(refit)

	-- the tip: a diamond half out of the disc's rim, swung round the centre to point the way
	local turn = Instance.new("Frame")
	turn.Name = "Turn"
	turn.Size = UDim2.fromScale(1, 1)
	turn.BackgroundTransparency = 1
	turn.Parent = mark
	local tip = Instance.new("Frame")
	tip.Name = "Tip"
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.new(0.5, 0, 0, -1)
	tip.Size = UDim2.fromOffset(18, 18)
	tip.Rotation = 45
	tip.BorderSizePixel = 0
	tip.Parent = turn
	HudTheme.corner(tip, 3)
	HudTheme.stroke(tip, Color3.new(1, 1, 1), 2.5)

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.Size = UDim2.fromScale(1, 1)
	disc.BorderSizePixel = 0
	disc.ZIndex = 2
	disc.Parent = mark
	HudTheme.corner(disc, DISC // 2)
	HudTheme.stroke(disc, Color3.new(1, 1, 1), 2.5)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.62, 0.62)
	icon.BackgroundTransparency = 1
	icon.ZIndex = 3
	icon.Parent = disc

	-- the distance on a navy chip under the disc
	local chip = Instance.new("Frame")
	chip.Name = "Range"
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 1, 7)
	chip.Size = UDim2.fromOffset(0, 26)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = NAVY
	chip.BackgroundTransparency = 0.1
	chip.BorderSizePixel = 0
	chip.Parent = mark
	HudTheme.corner(chip, 13)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = chip
	local range = HudTheme.label("Text", "", UDim2.fromScale(0, 1), HudTheme.NumberFont, 18, chip)
	range.AutomaticSize = Enum.AutomaticSize.X
	range.TextTruncate = Enum.TextTruncate.None
	HudTheme.outline(range)

	local offerKind: string? = nil
	ops.OnOffer:Connect(function(data: { [string]: any })
		offerKind = data.kind
	end)

	local shownKey = ""
	local function look(label: string)
		local s = ops.GetState()
		local kind = if label == "Mayday" then offerKind elseif s then s.kind else nil
		local key = `{label}/{kind}`
		if key == shownKey then
			return
		end
		shownKey = key
		local k = OpsTaskingCard.KIND[kind or ""]
		local glyph = if label == "Drop-off"
			then "home"
			elseif k then k.icon
			elseif label == "Vessel" then "boat"
			else "swimmer"
		local color = if label == "Drop-off" then GREEN elseif k then k.color else BEAM
		Glyph.draw(glyph, icon, Color3.new(1, 1, 1))
		disc.BackgroundColor3, tip.BackgroundColor3 = color, color
	end

	local function phoneUp(): boolean
		local phone = playerGui:FindFirstChild("Phone")
		return phone ~= nil and phone:IsA("ScreenGui") and phone.Enabled
	end

	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local pos, label = map.GetObjective()
		local hidden = not (cam and root)
			or Layout.coldOpen()
			or player:GetAttribute("OpsUiHidden") == true -- a cinematic (the chase camera is Scriptable too)
		local me = if root then root.Position else Vector3.zero

		-- the marker on the objective
		local want = pos ~= nil and label ~= nil and SHOWN[label] == true
		local flat = if pos then Vector3.new(pos.X - me.X, 0, pos.Z - me.Z).Magnitude else 0
		onDistance(if want and root then Waypoint.metres(flat) else nil)
		if hidden or not want or flat <= NEAR or map.IsOpen() or phoneUp() then
			mark.Visible = false
			return
		end
		look(label :: string)
		local c = cam :: Camera
		local vp = c.ViewportSize
		local p = c:WorldToViewportPoint((pos :: Vector3) + Vector3.new(0, 3, 0))
		local x, y = p.X, p.Y - LIFT
		local behind = p.Z <= 0
		if behind then -- the projection flips behind the camera
			x, y = vp.X - p.X, vp.Y - p.Y
		end
		-- the marker stays inside a central ellipse, clear of the HUD in the corners and the
		-- speed dock: past it (or behind you) it pins to the rim, its tip pointing the way
		local cx, cy = vp.X / 2, vp.Y / 2
		local dx, dy = x - cx, y - cy
		local ry = vp.Y * (if dy < 0 then RIM_UP else RIM.Y)
		local e = (dx / (vp.X * RIM.X)) ^ 2 + (dy / ry) ^ 2
		if not behind and e <= 1 then
			mark.Position = UDim2.fromOffset(x, y)
			turn.Rotation = 180
		else
			if e < 1e-6 then -- dead centre behind you: straight down
				dy, e = 1, (1 / (vp.Y * RIM.Y)) ^ 2
			end
			local k = 1 / math.sqrt(e)
			mark.Position = UDim2.fromOffset(cx + dx * k, cy + dy * k)
			turn.Rotation = math.deg(math.atan2(dx, -dy))
		end
		range.Text = Waypoint.metres(flat)
		mark.Visible = true
	end)
end

return Waypoint
