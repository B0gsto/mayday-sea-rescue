--!strict
-- OnboardingBeacon: the one next goal, shown in the world (docs/15 section 3, "a beacon on the
-- next thing, no text"). A ground-level pulse ring and a diamond high over it (clear of roofs, cranes and
-- name signs: AlwaysOnTop never drew in play, Studio 2026-10-25/26); no light column (user, 2026-10-21). Hidden while a
-- cinematic hides the HUD (OpsUiHidden). Off screen, an arrow on the screen edge points at it.
-- Client only. Mounted by OnboardingController (one beacon, moved from goal to goal) and by the
-- launch step (on your boat).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Weather = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"))

local OnboardingBeacon = {}

export type Beacon = {
	show: (position: Vector3, kind: string) -> (),
	hide: () -> (),
	target: () -> Vector3?,
	destroy: () -> (),
}

-- the HUD palette (assets/ui/hud/mockup.png): rescue orange marks on navy edges
local NAVY = Color3.fromHex("0A1830")
local COLORS: { [string]: Color3 } = {
	Place = Color3.fromHex("F2671F"), -- a spot on land
	Call = Color3.fromRGB(255, 120, 30), -- on the water: the ring sits on the waves
}

local RING_MAX = 40
local LIFT = 16 -- studs: the diamond over the goal

local function surfaceY(p: Vector3): number
	local ok, h = pcall(Weather.heightAt, p)
	return if ok and type(h) == "number" then h else p.Y
end

function OnboardingBeacon.start(): Beacon
	local folder = Instance.new("Folder")
	folder.Name = "OnboardingBeacon"
	folder.Parent = Workspace

	local ring = Instance.new("Part")
	ring.Name = "Pulse"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 8, 8)
	ring.Material = Enum.Material.Neon
	ring.Color = COLORS.Place
	ring.Transparency = 1
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.CastShadow = false
	ring.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Mark"
	billboard.Size = UDim2.fromOffset(80, 120)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, LIFT, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 1500
	billboard.Adornee = ring
	billboard.Parent = ring

	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.3)
	diamond.Size = UDim2.fromOffset(40, 40)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = COLORS.Place
	diamond.BorderSizePixel = 0
	diamond.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = diamond
	local edge = Instance.new("UIStroke")
	edge.Color = NAVY
	edge.Thickness = 3
	edge.Parent = diamond

	local stem = Instance.new("Frame")
	stem.Name = "Stem"
	stem.AnchorPoint = Vector2.new(0.5, 0)
	stem.Position = UDim2.fromScale(0.5, 0.46)
	stem.Size = UDim2.fromOffset(4, 56)
	stem.BackgroundColor3 = COLORS.Place
	stem.BackgroundTransparency = 0.25
	stem.BorderSizePixel = 0
	stem.Parent = billboard

	-- the edge arrow: pinned to the screen edge, pointing at the goal while it is off screen
	local edgeGui = Instance.new("ScreenGui")
	edgeGui.Name = "BeaconEdge"
	edgeGui.ResetOnSpawn = false
	edgeGui.IgnoreGuiInset = true
	edgeGui.DisplayOrder = 15
	edgeGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(96, 96)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▲"
	arrow.TextSize = 96 -- the glyph draws ~30 px (44 drew ~14 px)
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextColor3 = COLORS.Place
	arrow.TextStrokeColor3 = NAVY
	arrow.TextStrokeTransparency = 0
	arrow.Visible = false
	arrow.Parent = edgeGui
	-- the distance, upright, just inside the arrow, on a navy chip
	local range = Instance.new("TextLabel")
	range.Name = "Range"
	range.AnchorPoint = Vector2.new(0.5, 0.5)
	range.Size = UDim2.fromOffset(72, 28)
	range.BackgroundColor3 = NAVY
	range.BackgroundTransparency = 0.1
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0.5, 0)
	chipCorner.Parent = range
	range.Font = Enum.Font.FredokaOne
	range.TextSize = 20
	range.TextColor3 = Color3.new(1, 1, 1)
	range.TextStrokeColor3 = Color3.fromHex("06101C")
	range.TextStrokeTransparency = 0.4
	range.Visible = false
	range.Parent = edgeGui

	local at: Vector3? = nil
	local baseY = 0
	local color = COLORS.Place
	local active = false

	local self: any = {}

	function self.show(position: Vector3, kind: string)
		at = position
		color = COLORS[kind] or COLORS.Place
		active = true
		ring.Color = color
		diamond.BackgroundColor3, stem.BackgroundColor3, arrow.TextColor3 = color, color, color
		baseY = if kind == "Call" then surfaceY(position) else position.Y
		ring.CFrame = CFrame.new(Vector3.new(position.X, baseY + 0.12, position.Z))
			* CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.2
		billboard.Enabled = true
		diamond.Visible, stem.Visible = true, true
		folder.Parent = Workspace
	end

	function self.hide()
		active = false
		at = nil
		ring.Transparency = 1
		diamond.Visible, stem.Visible = false, false
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
			ring.Transparency = 1
			return
		end
		local cam = Workspace.CurrentCamera :: Camera
		local vp = cam.ViewportSize
		local p, onScreen = cam:WorldToViewportPoint(at + Vector3.new(0, LIFT, 0))
		local margin = 48
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
			arrow.Position = UDim2.fromOffset(vp.X / 2 + dx * k, vp.Y / 2 + dy * k)
			arrow.Rotation = math.deg(math.atan2(dx, -dy))
			arrow.Visible = true
			local char = Players.LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local d = at - root.Position
				local metres = Vector3.new(d.X, 0, d.Z).Magnitude / 3 -- 3 studs per metre
				local inward = 40 / math.max(math.sqrt(dx * dx + dy * dy) * k, 1)
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
		local k = (t % 1.6) / 1.6
		ring.Size = Vector3.new(0.1, 8 + k * RING_MAX * 2, 8 + k * RING_MAX * 2)
		ring.Transparency = 0.15 + 0.7 * k
		ring.CFrame = CFrame.new(Vector3.new(at.X, baseY + 0.12, at.Z))
			* CFrame.Angles(0, 0, math.rad(90))
		diamond.Rotation = 45 + math.sin(t * 1.8) * 12
		diamond.BackgroundTransparency = 0.05 + math.sin(t * 3) * 0.05
	end)

	function self.destroy()
		conn:Disconnect()
		folder:Destroy()
		edgeGui:Destroy()
	end

	return self :: Beacon
end

return OnboardingBeacon
