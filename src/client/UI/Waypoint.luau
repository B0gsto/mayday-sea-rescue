--!strict
-- Waypoint (playtest 2026-10-23: a new player could not find the second call): the way to the
-- call, in the world. MapController's objective (your craft while you are off it, the offered call,
-- the nearest survivor or vessel, the drop-off once they are aboard) gets a screen marker (no light pillar: user, 2026-10-21): the call-type icon on a disc
-- (KIND below) with its distance under it, pinned to the screen edge with its tip pointing
-- the way while off screen. Close in (NEAR) it never hides: it bobs over the target, tip down, until
-- the goal is done (docs/20 rule 2). The strip shows the same icon and distance (onGoal); the minimap
-- has no pill. Hidden under a panel or the full map, and in cinematics (OpsUiHidden). Mounted by OpsHud.
--   Waypoint.start(ops, map, onGoal)  onGoal(label, glyph, colour, "240 m") or onGoal(nil) each frame
--   Waypoint.metres(studs) -> "240 m" | "1.2 km"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Glyph = require(script.Parent.Glyph)
local HudTheme = require(script.Parent.HudTheme)
local Layout = require(script.Parent.Layout)

local Waypoint = {}

local NAVY = Color3.fromHex("0A1830")
local GREEN = Color3.fromHex("2FA866") -- the strip's "Home" disc
local BEAM = Color3.fromHex("FF6A3D")
local CRAFT = Color3.fromHex("F2671F") -- your boat: orange, the boat glyph

local STUDS_PER_M = 3
local NEAR = 25 * STUDS_PER_M -- studs: this close the marker bobs over the target
local BOB = 8 -- px: how far it bobs
local DISC = 46 -- du

local RED = Color3.fromHex("E8332A")
local AMBER = Color3.fromHex("FFB020")
-- call kind -> Glyph icon and alert colour
local KIND: { [string]: { icon: string, color: Color3 } } = {
	PersonInWater = { icon = "swimmer", color = RED },
	RipCurrent = { icon = "swimmer", color = RED },
	CapsizedFerry = { icon = "boat", color = RED },
	SinkingVessel = { icon = "boat", color = RED },
	VesselFire = { icon = "flare", color = RED },
	Diver = { icon = "cross", color = RED },
	WildlifeRescue = { icon = "ring", color = AMBER },
}
local LIFT = 34 -- px: the disc floats over the target, its tip pointing down at it
local RIM = Vector2.new(0.36, 0.28) -- the pin ellipse's radii, share of the screen (down)
local RIM_UP = 0.24 -- its upward radius: the top band holds the strip
local QUEST = Color3.fromHex("FFC428") -- the quest givers' gold
local SHOWN: { [string]: boolean } = {
	Mayday = true,
	Casualty = true,
	Vessel = true,
	["Drop-off"] = true,
	Craft = true,
	Quest = true,
}
local CALL: { [string]: boolean } = { Mayday = true, Casualty = true, Vessel = true }

function Waypoint.metres(studs: number): string
	local m = studs / STUDS_PER_M
	return if m >= 1000
		then string.format("%.1f km", m / 1000)
		else `{math.floor(m / 10 + 0.5) * 10} m`
end

function Waypoint.start(
	ops: any,
	map: any,
	onGoal: (
		label: string?,
		glyph: string?,
		color: Color3?,
		distance: string?
	) -> ()
)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Waypoint"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- viewport pixels, as WorldToViewportPoint gives them
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Global hid the icon's glyph bars under the disc
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
	local ring = HudTheme.stroke(disc, Color3.new(1, 1, 1), 2.5)
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
	local offerGolden = false
	ops.OnOffer:Connect(function(data: { [string]: any })
		offerKind = data.kind
		offerGolden = data.golden == true
	end)
	-- taking a golden call: a bright fanfare and two gold rings burst off the pin
	local goldenOp: any = nil
	ops.OnState:Connect(function(s: any)
		if type(s) ~= "table" or s.golden ~= true or s.opId == goldenOp then
			return
		end
		goldenOp = s.opId
		AudioController.play("Music_CrateFanfare", nil, 0.8, 1.15)
		AudioController.play("Album_Sparkle", nil, 1.2, 1)
		for k = 0, 1 do
			local burst = Instance.new("Frame")
			burst.Name = "GoldBurst"
			burst.AnchorPoint = Vector2.new(0.5, 0.5)
			burst.Position = UDim2.fromScale(0.5, 0.5)
			burst.Size = UDim2.fromScale(1, 1)
			burst.BackgroundTransparency = 1
			burst.ZIndex = 4
			burst.Parent = mark
			HudTheme.corner(burst, 999)
			local stroke = HudTheme.stroke(burst, QUEST, 6)
			local info = TweenInfo.new(
				0.7,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out,
				0,
				false,
				k * 0.18
			)
			TweenService:Create(burst, info, { Size = UDim2.fromScale(3.2, 3.2) }):Play()
			TweenService:Create(stroke, info, { Transparency = 1, Thickness = 1 }):Play()
			task.delay(1.2, function()
				burst:Destroy()
			end)
		end
	end)

	-- one icon, one meaning (docs/20 rule 9): house = home, boat = your craft, else the call's icon
	local function style(label: string): (string, Color3)
		if label == "Drop-off" then
			return "home", GREEN
		elseif label == "Craft" then
			return "boat", CRAFT
		elseif label == "Quest" then
			return "quest", QUEST
		end
		local s = ops.GetState()
		local kind = if label == "Mayday" then offerKind elseif s then s.kind else nil
		local k = KIND[kind or ""]
		if k then
			return k.icon, k.color
		end
		return if label == "Vessel" then "boat" else "swimmer", BEAM
	end
	local shownGlyph = ""
	local function look(glyph: string, color: Color3, golden: boolean)
		if glyph ~= shownGlyph then
			shownGlyph = glyph
			Glyph.draw(glyph, icon, Color3.new(1, 1, 1))
		end
		disc.BackgroundColor3, tip.BackgroundColor3 = color, color
		-- docs/25 E: a golden call's pin wears a thick pulsing gold ring
		ring.Color = if golden then QUEST else Color3.new(1, 1, 1)
		ring.Thickness = if golden then 4 + 1.5 * math.sin(os.clock() * 6) else 2.5
	end

	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local pos, label, route = map.GetObjective() -- by boat, pos is the next sea leg (the cove mouth first)
		local hidden = not (cam and root) or player:GetAttribute("OpsUiHidden") == true -- a cinematic (the chase camera is Scriptable too)
		local me = if root then root.Position else Vector3.zero

		-- the marker on the objective
		local want = pos ~= nil
			and label ~= nil
			and SHOWN[label] == true
			and not (CALL[label] and player:GetAttribute("TutorialHoldCall") == true) -- the tutorial's build step leads
		local flat = route
			or if pos then Vector3.new(pos.X - me.X, 0, pos.Z - me.Z).Magnitude else 0
		if not (want and root) then
			onGoal(nil)
			mark.Visible = false
			return
		end
		local glyph, color = style(label :: string)
		onGoal(label, glyph, color, Waypoint.metres(flat))
		if hidden or map.IsOpen() or player:GetAttribute("MenuOpen") == true then
			mark.Visible = false
			return
		end
		local s = ops.GetState()
		local golden = CALL[label :: string] == true
			and (if label == "Mayday" then offerGolden else s ~= nil and s.golden == true)
		look(glyph, color, golden)
		local c = cam :: Camera
		local vp = c.ViewportSize
		local p = c:WorldToViewportPoint((pos :: Vector3) + Vector3.new(0, 3, 0))
		-- right there: it bobs over them, tip down, so it reads as "this one" (playtest 2026-10-24 M8, M9)
		local bob = if flat <= NEAR then BOB * math.abs(math.sin(os.clock() * 5)) else 0
		local x, y = p.X, p.Y - LIFT - bob
		local behind = p.Z <= 0
		if behind then
			-- pin it to the side to turn toward: pinned bottom-centre it sat right under the craft and
			-- read as "here", so players drove on away from it (playtest 2026-10-24: 650 m and growing)
			local rel = c.CFrame:PointToObjectSpace(pos :: Vector3)
			x, y = if rel.X < 0 then -vp.X else 2 * vp.X, vp.Y / 2
		end
		-- the marker stays inside a central ellipse, clear of the HUD in the corners and the
		-- speed dock: past it (or behind you) it pins to the rim, its tip pointing the way
		local cx, cy = vp.X / 2, vp.Y / 2
		local dx, dy = x - cx, y - cy
		local ry = vp.Y * (if dy < 0 then RIM_UP else RIM.Y)
		local e = (dx / (vp.X * RIM.X)) ^ 2 + (dy / ry) ^ 2
		local at: Vector2
		if not behind and e <= 1 then
			at = Vector2.new(x, y)
			turn.Rotation = 180
		else
			if e < 1e-6 then -- dead centre behind you: straight down
				dy, e = 1, (1 / (vp.Y * RIM.Y)) ^ 2
			end
			local k = 1 / math.sqrt(e)
			at = Vector2.new(cx + dx * k, cy + dy * k)
			turn.Rotation = math.deg(math.atan2(dx, -dy))
		end
		-- out of the HUD (menu, minimap, wallet, cards): slid in toward the centre, the tip still points the way
		local clear = Vector2.new(DISC, DISC) * fit.Scale * 0.5 + Vector2.new(14, 14) -- strokes and labels hang past the frames
		at = Layout.clearOfHud(at, clear, 34 * fit.Scale) -- the range chip hangs under
		mark.Position = UDim2.fromOffset(at.X, at.Y)
		range.Text = Waypoint.metres(flat)
		mark.Visible = true
	end)
end

return Waypoint
