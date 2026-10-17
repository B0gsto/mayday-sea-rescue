--!strict
-- Cinematic: third-person, film-style shot lists with letterboxing (2.39:1 bars), slow camera
-- moves eased in and out, a faint handheld drift and optional captions. Skippable (Space, B,
-- tap Skip) once the player has seen that cinematic before (Comfort.hasSeen).
--
--   Cinematic.play(shots, opts?) -> Handle      opts: { id: string?, skippable: boolean?, onDone: (() -> ())? }
--   Cinematic.isPlaying(): boolean
--   Cinematic.update(dt): boolean               (CameraController each frame; true while playing)
--   Cinematic.stop()
--   LocalPlayer attribute CinematicPlaying (bool) while one plays (the Ops UI hides on it)
--   Cinematic.Lists.arrival() / .launch(model) / .storm(subject)   stub shot lists
--
-- Shot = { from: CFrame | Pose, to: (CFrame | Pose)?, duration: number, fov: number?,
--          toFov: number?, caption: string?, handheld: number? }
-- Pose = { subject: Instance (Model or BasePart), offset: Vector3, look: Vector3? } (offset and
--        look are in the subject's yaw frame: X right, Y up, -Z ahead; look defaults to its centre)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraMath = require(script.Parent.CameraMath)
local Comfort = require(script.Parent.Comfort)

export type Pose = { subject: Instance, offset: Vector3, look: Vector3? }
export type Shot = {
	from: any,
	to: any?,
	duration: number,
	fov: number?,
	toFov: number?,
	caption: string?,
	handheld: number?,
}
export type Handle = { stop: () -> (), isDone: () -> boolean }

local Cinematic = {}
-- LocalPlayer attribute (client only) true while a cinematic plays; OpsController hides the Ops
-- UI on it. CinematicId is the id of the last one started.
local PLAYING_ATTRIBUTE = "CinematicPlaying"
Cinematic.PlayingAttribute = PLAYING_ATTRIBUTE

local current: { shots: { Shot }, index: number, t: number, id: string?, onDone: (() -> ())?, done: boolean }? =
	nil
local gui: ScreenGui? = nil
local bars: { Frame } = {}
local captionLabel: TextLabel? = nil
local skipButton: TextButton? = nil
local barAmount = 0
local clock = 0

local function subjectCFrame(subject: Instance): CFrame?
	if subject:IsA("Model") then
		return subject:GetPivot()
	elseif subject:IsA("BasePart") then
		return subject.CFrame
	end
	return nil
end

local function resolve(p: any): CFrame?
	if typeof(p) == "CFrame" then
		return p
	end
	if type(p) == "table" and p.subject then
		local base = subjectCFrame(p.subject)
		if not base or not p.subject.Parent then
			return nil
		end
		local frame = CFrame.new(base.Position) * CameraMath.horizonFrame(base)
		local pos = frame:PointToWorldSpace(p.offset)
		local lookAt = frame:PointToWorldSpace(p.look or Vector3.zero)
		return CFrame.lookAt(pos, lookAt)
	end
	return nil
end

local function ensureGui()
	if gui then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "Cinematic"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 50
	g.Enabled = false
	for i = 1, 2 do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if i == 1 then 0 else 1)
		bar.Position = UDim2.fromScale(0, if i == 1 then 0 else 1)
		bar.Size = UDim2.fromScale(1, 0)
		bar.ZIndex = 2
		bar.Parent = g
		bars[i] = bar
	end
	local cap = Instance.new("TextLabel")
	cap.BackgroundTransparency = 1
	cap.AnchorPoint = Vector2.new(0.5, 1)
	cap.Position = UDim2.fromScale(0.5, 0.86)
	cap.Size = UDim2.fromScale(0.8, 0.05)
	cap.Font = Enum.Font.GothamMedium
	cap.TextScaled = true
	cap.TextColor3 = Color3.fromRGB(235, 235, 230)
	cap.TextTransparency = 1
	cap.Text = ""
	cap.ZIndex = 3
	cap.Parent = g
	captionLabel = cap
	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -24, 1, -18)
	skip.Size = UDim2.fromOffset(110, 34)
	skip.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	skip.BackgroundTransparency = 0.4
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Font = Enum.Font.GothamMedium
	skip.TextSize = 16
	skip.Text = "Skip  [Space]"
	skip.Visible = false
	skip.ZIndex = 4
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = skip
	skip.Parent = g
	skip.Activated:Connect(function()
		Cinematic.stop()
	end)
	skipButton = skip
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current or not (skipButton and skipButton.Visible) then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonB then
			Cinematic.stop()
		end
	end)
end

local function finish()
	local c = current
	current = nil
	Players.LocalPlayer:SetAttribute(PLAYING_ATTRIBUTE, false)
	if c and not c.done then
		c.done = true
		if c.id then
			Comfort.markSeen(c.id)
		end
		if c.onDone then
			task.spawn(c.onDone :: () -> ())
		end
	end
	if skipButton then
		skipButton.Visible = false
	end
end

function Cinematic.play(
	shots: { Shot },
	opts: { id: string?, skippable: boolean?, onDone: (() -> ())? }?
): Handle
	local o: { id: string?, skippable: boolean?, onDone: (() -> ())? } = opts or {}
	ensureGui()
	if current then
		finish()
	end
	local entry = { shots = shots, index = 1, t = 0, id = o.id, onDone = o.onDone, done = false }
	current = entry
	Players.LocalPlayer:SetAttribute(PLAYING_ATTRIBUTE, true)
	Players.LocalPlayer:SetAttribute("CinematicId", o.id or "")
	local skippable = if o.skippable ~= nil
		then o.skippable
		else (o.id ~= nil and Comfort.hasSeen(o.id :: string))
	if skipButton then
		skipButton.Visible = skippable
	end
	return {
		stop = function()
			if current == entry then
				Cinematic.stop()
			end
		end,
		isDone = function()
			return entry.done
		end,
	}
end

function Cinematic.stop()
	finish()
end

function Cinematic.isPlaying(): boolean
	return current ~= nil
end

local function easeInOut(x: number): number
	return 0.5 - 0.5 * math.cos(math.pi * math.clamp(x, 0, 1))
end

-- Drives the letterbox every frame and the camera while a cinematic plays.
function Cinematic.update(dt: number): boolean
	clock += dt
	local playing = current ~= nil
	if gui then
		barAmount = CameraMath.damp(barAmount, if playing then 1 else 0, 0.12, dt)
		gui.Enabled = barAmount > 0.005
		for _, bar in bars do
			bar.Size = UDim2.fromScale(1, 0.12 * barAmount)
		end
	end
	local c = current
	if not c then
		return false
	end
	local shot = c.shots[c.index]
	if not shot then
		finish()
		return false
	end
	c.t += dt
	local k = easeInOut(c.t / math.max(shot.duration, 0.01))
	local a = resolve(shot.from)
	local b = if shot.to then resolve(shot.to) else a
	if not a or not b then
		c.index += 1
		c.t = 0
		return true
	end
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local hh = shot.handheld or 0.25
	local drift = CFrame.Angles(
		math.noise(clock * 0.6, 3.1) * math.rad(0.6) * hh,
		math.noise(clock * 0.5, 8.7) * math.rad(0.6) * hh,
		math.noise(clock * 0.4, 1.9) * math.rad(0.3) * hh
	)
	cam.CFrame = a:Lerp(b, k) * drift
	local f0 = shot.fov or 50
	cam.FieldOfView = f0 + ((shot.toFov or f0) - f0) * k
	if captionLabel then
		captionLabel.Text = shot.caption or ""
		local fade = math.min(c.t / 0.6, (shot.duration - c.t) / 0.6, 1)
		captionLabel.TextTransparency = if shot.caption then 1 - math.clamp(fade, 0, 1) else 1
	end
	if c.t >= shot.duration then
		c.index += 1
		c.t = 0
		if c.index > #c.shots then
			finish()
		end
	end
	return true
end

---------------------------------------------------------------- stub shot lists (map/Build.luau)
-- Port Haven: station building x -140..-80, z -90..-40 (doors face +Z at x -110), the tower at
-- (-85, -55), the dock deck x -118..-102 from z 4 to 104, launch bays at x -95. Harbour Mouth at
-- (0, 0, 420).

local Lists = {}
Cinematic.Lists = Lists

-- After the cold open: coming home to the station.
function Lists.arrival(): { Shot }
	return {
		{
			from = CFrame.lookAt(Vector3.new(60, 16, 190), Vector3.new(-100, 10, 20)),
			to = CFrame.lookAt(Vector3.new(25, 12, 150), Vector3.new(-100, 10, 10)),
			duration = 6,
			fov = 40,
			toFov = 36,
			caption = "Port Haven",
		},
		{
			from = CFrame.lookAt(Vector3.new(-108, 5.5, 112), Vector3.new(-110, 9, -40)),
			to = CFrame.lookAt(Vector3.new(-108, 5.5, 70), Vector3.new(-110, 10, -40)),
			duration = 5,
			fov = 55,
		},
		{
			from = CFrame.lookAt(Vector3.new(-50, 10, -10), Vector3.new(-85, 34, -55)),
			to = CFrame.lookAt(Vector3.new(-45, 30, 5), Vector3.new(-88, 36, -58)),
			duration = 5,
			fov = 45,
			caption = "Port Haven Coast Guard Station",
		},
	}
end

-- Launching from a bay: a low tracking shot off the quarter, then wide from the dock end.
function Lists.launch(model: Model): { Shot }
	return {
		{
			from = {
				subject = model,
				offset = Vector3.new(16, 2.2, 8),
				look = Vector3.new(0, 2, -4),
			},
			to = {
				subject = model,
				offset = Vector3.new(12, 2.6, -10),
				look = Vector3.new(0, 2, -14),
			},
			duration = 3.2,
			fov = 50,
		},
		{
			from = CFrame.lookAt(Vector3.new(-110, 8, 110), model:GetPivot().Position),
			to = {
				subject = model,
				offset = Vector3.new(-24, 10, 34),
				look = Vector3.new(0, 1, -10),
			},
			duration = 3,
			fov = 45,
			toFov = 55,
		},
	}
end

-- The storm rolls in: wide over the bay to the Harbour Mouth, then close on the player.
function Lists.storm(subject: Instance?): { Shot }
	local shots: { Shot } = {
		{
			from = CFrame.lookAt(Vector3.new(-70, 46, 40), Vector3.new(0, 18, 620)),
			to = CFrame.lookAt(Vector3.new(-40, 52, 90), Vector3.new(20, 22, 640)),
			duration = 6,
			fov = 38,
			caption = "A storm is rolling in",
			handheld = 0.5,
		},
	}
	if subject then
		table.insert(shots, {
			from = {
				subject = subject,
				offset = Vector3.new(10, 4, -14),
				look = Vector3.new(0, 3, 0),
			},
			to = { subject = subject, offset = Vector3.new(14, 6, -8), look = Vector3.new(0, 4, 0) },
			duration = 3.5,
			fov = 50,
			handheld = 0.8,
		})
	end
	return shots
end

return Cinematic
