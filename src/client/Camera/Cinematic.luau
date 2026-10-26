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
--   Cinematic.Lists.coldOpen(model) / .launch(model) / .storm(subject)   shot lists
--
-- Shot = { from: CFrame | Pose, to: (CFrame | Pose)?, duration: number, fov: number?,
--          toFov: number?, caption: string?, handheld: number? }
-- Pose = { subject: Instance (Model or BasePart), offset: Vector3, look: Vector3? } (offset and
--        look are in the subject's yaw frame: X right, Y up, -Z ahead; look defaults to its centre)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CameraMath = require(script.Parent.CameraMath)
local Comfort = require(script.Parent.Comfort)
local InputGlyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("InputGlyph"))

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
	skip.Text = "Skip"
	skip.Visible = false
	skip.ZIndex = 4
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = skip
	skip.Parent = g
	skip.Activated:Connect(function()
		Cinematic.stop()
	end)
	InputGlyph.onDevice(function(d)
		skip.Text = if d == "Touch"
			then "Skip"
			else `Skip  {InputGlyph.text(Enum.KeyCode.Space, Enum.KeyCode.ButtonB)}`
	end)
	skipButton = skip
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

-- Bound (and sinking the key) only while Skip shows, so Space skips without also jumping off the seat.
local SKIP_ACTION = "CinematicSkip"
local function bindSkip(on: boolean)
	ContextActionService:UnbindAction(SKIP_ACTION)
	if on then
		ContextActionService:BindActionAtPriority(
			SKIP_ACTION,
			function(_, state)
				if state == Enum.UserInputState.Begin and current then
					Cinematic.stop()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value + 100,
			Enum.KeyCode.Space,
			Enum.KeyCode.ButtonB
		)
	end
end

local playedIds: { [string]: boolean } = {} -- ids started this session

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
	bindSkip(false)
end

function Cinematic.play(
	shots: { Shot },
	opts: {
		id: string?,
		skippable: boolean?,
		onDone: (() -> ())?,
		repeatable: boolean?,
	}?
): Handle
	local o: { id: string?, skippable: boolean?, onDone: (() -> ())?, repeatable: boolean? } = opts
		or {}
	-- a cinematic with an id plays once per session unless it is repeatable (the storm warning):
	-- a second trigger (a late attribute flip, a teleport into range, a respawned vehicle) is a no-op
	if o.id and o.repeatable ~= true and playedIds[o.id :: string] then
		return {
			stop = function() end,
			isDone = function()
				return true
			end,
		}
	end
	-- never cut into a cinematic that is still playing for a repeatable one
	if current and o.repeatable == true then
		return {
			stop = function() end,
			isDone = function()
				return true
			end,
		}
	end
	ensureGui()
	if current then
		finish()
	end
	if o.id then
		playedIds[o.id :: string] = true
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
	bindSkip(skippable)
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

function Cinematic.hasPlayed(id: string): boolean
	return playedIds[id] == true
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
local Lists = {}
Cinematic.Lists = Lists

-- The cold open (about 7 s, skippable): wide over your island from behind it (the jet ski sits in its cove,
-- bow out to sea), a sweep out to the casualty (the craft's ColdOpenTarget), then down behind the jet ski as
-- control comes back.
function Lists.coldOpen(model: Model): { Shot }
	local target = model:GetAttribute("ColdOpenTarget")
	local pivot = model:GetPivot()
	local cas: Vector3 = if typeof(target) == "Vector3" then target else pivot.Position
	local fwd = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z).Unit
	return {
		{
			from = CFrame.lookAt(
				pivot.Position - fwd * 170 + Vector3.new(0, 80, 0),
				pivot.Position + fwd * 60
			),
			to = CFrame.lookAt(
				pivot.Position - fwd * 120 + Vector3.new(0, 55, 0),
				pivot.Position + fwd * 60
			),
			duration = 2.6,
			fov = 42,
		},
		{
			from = CFrame.lookAt(cas + Vector3.new(-60, 40, -70), cas),
			to = CFrame.lookAt(cas + Vector3.new(-26, 14, -30), cas),
			duration = 2.6,
			fov = 48,
			toFov = 40,
		},
		{
			from = {
				subject = model,
				offset = Vector3.new(4, 9, 26),
				look = Vector3.new(0, 2, -20),
			},
			-- Chase's cold-open pose (RIDER_FOCUS, 5 degrees, 19.4 back), so control comes back without a jump
			to = {
				subject = model,
				offset = Vector3.new(0, 8.2, 19.4),
				look = Vector3.new(0, 4.8, -20),
			},
			duration = 1.6,
			fov = 60,
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
			from = CFrame.lookAt(
				model:GetPivot().Position + Vector3.new(-40, 8, 40),
				model:GetPivot().Position
			),
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
			from = CFrame.lookAt(Vector3.new(-70, 60, 300), Vector3.new(0, 18, 640)),
			to = CFrame.lookAt(Vector3.new(-40, 64, 340), Vector3.new(20, 22, 660)),
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
