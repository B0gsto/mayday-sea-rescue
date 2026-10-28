--!strict
-- OnboardingBeacon: the one next goal, shown in the world (docs/15 section 3, "a beacon on the
-- next thing, no text"). A steady ground-level ring (one pop as it appears, never a flashing pulse: owner
-- 2026-10-28) and a diamond high over it (clear of roofs, cranes and
-- name signs: AlwaysOnTop never drew in play, Studio 2026-10-25/26); no light column (user, 2026-10-21). Hidden while a
-- cinematic hides the HUD (OpsUiHidden). Off screen, a pointer sprite on the screen edge points at it, its distance on a chip inside it.
-- Client only. Mounted by OnboardingController (one beacon, moved from goal to goal) and by the
-- launch step (on your boat).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Layout = require(script.Parent:WaitForChild("Layout"))
local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
) :: any
local Weather = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"))

local OnboardingBeacon = {}

export type Beacon = {
	show: (position: Vector3, kind: string) -> (),
	hide: () -> (),
	target: () -> Vector3?,
	destroy: () -> (),
}

-- the HUD palette (assets/ui/hud/mockup.png): the distance chip's navy
local NAVY = Color3.fromHex("0A1830")

local RING = 24 -- studs across the steady ring
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LIFT = 16 -- studs: the diamond over the goal
local EDGE = 36 -- px: the screen-edge pointer's head (32 pt+ on a phone, CLAUDE.md "UI art")

local function surfaceY(p: Vector3): number
	local ok, h = pcall(Weather.heightAt, p)
	return if ok and type(h) == "number" then h else p.Y
end

function OnboardingBeacon.start(): Beacon
	local folder = Instance.new("Folder")
	folder.Name = "OnboardingBeacon"
	folder.Parent = Workspace

	-- the ground ring: art/source/ui/beacon_ring.svg on an invisible flat Part, unlit so it reads at night (no neon)
	local ring = Instance.new("Part")
	ring.Name = "Pulse"
	ring.Size = Vector3.new(8, 0.1, 8)
	ring.Transparency = 1
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.CastShadow = false
	ring.Parent = folder
	local ringGui = Instance.new("SurfaceGui")
	ringGui.Face = Enum.NormalId.Top
	ringGui.LightInfluence = 0
	ringGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	ringGui.PixelsPerStud = 40
	ringGui.Parent = ring
	local ringArt = Instance.new("ImageLabel")
	ringArt.Size = UDim2.fromScale(1, 1)
	ringArt.BackgroundTransparency = 1
	ringArt.Image = UiImages.Markers.BeaconRing
	ringArt.ImageTransparency = 1
	ringArt.Parent = ringGui

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Mark"
	billboard.Size = UDim2.fromOffset(80, 120)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, LIFT, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 1500
	billboard.Adornee = ring
	billboard.Parent = ring

	-- art/source/ui/beacon_mark.svg: the orange gem over a stem that points down at the goal
	local diamond = Instance.new("ImageLabel")
	diamond.Name = "Diamond"
	diamond.Size = UDim2.fromScale(1, 1)
	diamond.BackgroundTransparency = 1
	diamond.Image = UiImages.Markers.BeaconMark
	diamond.ScaleType = Enum.ScaleType.Fit
	diamond.Parent = billboard

	-- the edge arrow: pinned to the screen edge, pointing at the goal while it is off screen
	local edgeGui = Instance.new("ScreenGui")
	edgeGui.Name = "BeaconEdge"
	edgeGui.ResetOnSpawn = false
	edgeGui.IgnoreGuiInset = true
	edgeGui.DisplayOrder = 15
	edgeGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local arrow = Instance.new("ImageLabel")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	-- art/source/ui/edge_pointer.svg: a pin, tip down, its 324 box centred on the head (r 72): spun to the goal
	arrow.Size = UDim2.fromOffset(EDGE * 324 / 144, EDGE * 324 / 144)
	arrow.BackgroundTransparency = 1
	arrow.Image = UiImages.Markers.EdgePointer
	arrow.ScaleType = Enum.ScaleType.Fit
	arrow.Visible = false
	arrow.Parent = edgeGui
	-- the distance, upright, just inside the arrow, on a navy chip
	local range = Instance.new("TextLabel")
	range.Name = "Range"
	range.AnchorPoint = Vector2.new(0.5, 0.5)
	range.Size = UDim2.fromOffset(78, 30)
	range.BackgroundColor3 = NAVY
	range.BackgroundTransparency = 0.1
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0.5, 0)
	chipCorner.Parent = range
	range.Font = Enum.Font.FredokaOne
	range.TextSize = 22 -- 14 pt+ on a phone
	range.TextColor3 = Color3.new(1, 1, 1)
	range.TextStrokeColor3 = Color3.fromHex("06101C")
	range.TextStrokeTransparency = 0.4
	range.Visible = false
	range.Parent = edgeGui

	local at: Vector3? = nil
	local baseY = 0
	local active = false

	local self: any = {}

	function self.show(position: Vector3, kind: string)
		at = position
		active = true
		baseY = if kind == "Call" then surfaceY(position) else position.Y
		ring.CFrame = CFrame.new(Vector3.new(position.X, baseY + 0.12, position.Z))
		ring.Size = Vector3.new(8, 0.1, 8)
		TweenService:Create(ring, POP, { Size = Vector3.new(RING, 0.1, RING) }):Play()
		billboard.Enabled = true
		diamond.Visible = true
		folder.Parent = Workspace
	end

	function self.hide()
		active = false
		at = nil
		ringArt.ImageTransparency = 1
		diamond.Visible = false
		arrow.Visible = false
		range.Visible = false
	end

	function self.target(): Vector3?
		return at
	end

	local conn = RunService.Heartbeat:Connect(function()
		if not active or not at then
			return
		end
		-- not CameraType: the jet ski's chase camera is Scriptable too, so the mark never drew on the water
		local cutscene = Players.LocalPlayer:GetAttribute("OpsUiHidden") == true
		billboard.Enabled = not cutscene
		arrow.Visible = false
		range.Visible = false
		if cutscene then
			ringArt.ImageTransparency = 1
			return
		end
		local cam = Workspace.CurrentCamera :: Camera
		local vp = cam.ViewportSize
		local p, onScreen = cam:WorldToViewportPoint(at + Vector3.new(0, LIFT, 0))
		local margin = 64 -- the pin's tip reaches ~40 px past its head's centre: it stays 16+ in from the edge
		local x, y = p.X, p.Y
		if p.Z <= 0 then -- behind the camera: the projection flips
			x, y, onScreen = vp.X - x, vp.Y - y, false
		end
		if not onScreen or x < margin or x > vp.X - margin or y < margin or y > vp.Y - margin then
			local dx, dy = x - vp.X / 2, y - vp.Y / 2
			if math.abs(dx) + math.abs(dy) < 0.01 then
				dy = 1
			end
			local k = math.min(
				(vp.X / 2 - margin) / math.max(math.abs(dx), 0.01),
				(vp.Y / 2 - margin) / math.max(math.abs(dy), 0.01)
			)
			arrow.Rotation = math.deg(math.atan2(dx, -dy)) + 180 -- the sprite's tip points down
			-- clear of the HUD like UI/Waypoint: pinned left it hid under the menu column (playtest 2026-10-26).
			-- The clearance is the tip's reach (half the sprite box), not the head's: spun toward the menu, the tip
			-- lay on the Map / Pet buttons (pt5 2026-10-28)
			local reach = EDGE * 324 / 288 + 4
			local pin = Layout.clearOfHud(
				Vector2.new(vp.X / 2 + dx * k, vp.Y / 2 + dy * k),
				Vector2.new(reach, reach),
				40
			)
			dx, dy, k = pin.X - vp.X / 2, pin.Y - vp.Y / 2, 1
			arrow.Position = UDim2.fromOffset(pin.X, pin.Y)
			arrow.Visible = true
			local char = Players.LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local d = at - root.Position
				local metres = Vector3.new(d.X, 0, d.Z).Magnitude / 3 -- 3 studs per metre
				-- the chip sits just behind the head, on the side away from the edge
				local len = math.max(math.sqrt(dx * dx + dy * dy) * k, 1)
				local back = EDGE / 2
					+ 8
					+ math.abs(dx * k / len) * 39
					+ math.abs(dy * k / len) * 15
				local inward = back / len
				range.Position = UDim2.fromOffset(
					vp.X / 2 + dx * k * (1 - inward),
					vp.Y / 2 + dy * k * (1 - inward)
				)
				range.Text = if metres >= 1000
					then string.format("%.1f km", metres / 1000)
					else `{math.floor(metres / 10 + 0.5) * 10} m`
				range.Visible = true
			end
		end
		local t = os.clock()
		ringArt.ImageTransparency = 0.15
		ring.CFrame = CFrame.new(Vector3.new(at.X, baseY + 0.12, at.Z))
		diamond.Position = UDim2.fromOffset(0, math.sin(t * 1.8) * 4) -- a slow bob, never a flash
	end)

	function self.destroy()
		conn:Disconnect()
		folder:Destroy()
		edgeGui:Destroy()
	end

	return self :: Beacon
end

return OnboardingBeacon
