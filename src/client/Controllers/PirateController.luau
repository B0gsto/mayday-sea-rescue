--!strict
-- PirateController (docs/29 D): draws the pirates PirateService steers. Each client moves the anchored boat itself from
-- its attributes: the hunted client at its own hull + the server's Rel, so what it sees is the gap the server hits on at
-- any speed and lag; everyone else from At + Vel. Hovers on the water. Far from a bystander's camera it parks out of
-- sight and costs nothing.
-- Moments (each once, nothing flashes): feedback, pirate_spawn + one horn + one edge arrow pop for the hunted;
-- feedback, pirate_ram where a survivor went in; feedback + reward, pirate_escape + a "+25%" toast on the landing.
-- The wake reuses pickup_wake near the camera, off under Reduce motion.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages")) :: any

local Client = script.Parent.Parent
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Comfort = require(Client:WaitForChild("Camera"):WaitForChild("Comfort"))
local Layout = require(Client:WaitForChild("UI"):WaitForChild("Layout"))
local Style = require(Client:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Style"))
local Toast = require(Client:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Toast"))
local VFXKit = require(Client:WaitForChild("VFX"):WaitForChild("VFXKit"))

local PirateController = {}

local SMOOTH = 10 -- 1/s: how fast the drawn offset follows the published one -- tune
local SNAP = 1500 -- studs of error that are a jump, not lag: 10 Hz steps at 1100 studs/s are about 200
local HOVER = 1.2 -- studs off the water
local CULL = 2500 -- studs from a bystander's camera -- tune
local PARK = CFrame.new(0, -2000, 0)
local WAKE_NEAR = 800 -- studs from the camera
local WAKE_GAP = 0.4 -- s
local STERN = 25 -- studs behind the pivot
local ARROW = 44 -- du
local EDGE = 56 -- px clear of the screen edge

local player = Players.LocalPlayer

type Drawn = {
	model: Model,
	mine: boolean,
	off: Vector3, -- the drawn offset from the anchor
	relative: boolean, -- off is from the own hull, not the world
	published: Vector3?,
	publishedAt: number,
	yaw: number,
	parked: boolean,
	wakeAt: number,
}

local drawn: { [Model]: Drawn } = {}
local arrowGui: ScreenGui? = nil
local arrowMark: Frame? = nil
local arrowTurn: ImageLabel? = nil

-- The edge arrow: the red waypoint pin with a black flag. shortcut: a reused sprite and Frames for the flag, upgrade when
-- real HUD art lands.
local function arrow(): (Frame, ImageLabel)
	if arrowMark and arrowTurn then
		return arrowMark, arrowTurn
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PirateArrow"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 16
	gui.Parent = player:WaitForChild("PlayerGui")
	local mark = Instance.new("Frame")
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Size = UDim2.fromOffset(ARROW, ARROW)
	mark.BackgroundTransparency = 1
	mark.Visible = false
	mark.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Name = "Fit"
	fit.Scale = math.clamp(Layout.current().scale, 0.8, 1.3)
	fit.Parent = mark
	local pin = Instance.new("ImageLabel")
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.Position = UDim2.fromScale(0.5, 0.5)
	pin.Size = UDim2.fromScale(324 / 144, 324 / 144)
	pin.BackgroundTransparency = 1
	pin.ScaleType = Enum.ScaleType.Fit
	pin.Image = UiImages.Markers.Pin.Red
	pin.Parent = mark
	local flag = Instance.new("Frame")
	flag.AnchorPoint = Vector2.new(0.5, 0.5)
	flag.Position = UDim2.fromScale(0.5, 0.5)
	flag.Size = UDim2.fromScale(0.62, 0.46)
	flag.BackgroundColor3 = Color3.fromHex("14121C")
	flag.BorderSizePixel = 0
	flag.ZIndex = 2
	flag.Parent = mark
	local skull = Instance.new("Frame")
	skull.AnchorPoint = Vector2.new(0.5, 0.5)
	skull.Position = UDim2.fromScale(0.5, 0.5)
	skull.Size = UDim2.fromScale(0.36, 0.5)
	skull.BackgroundColor3 = Color3.fromHex("FFF1D6")
	skull.BorderSizePixel = 0
	skull.ZIndex = 3
	skull.Parent = flag
	arrowGui, arrowMark, arrowTurn = gui, mark, pin
	return mark, pin
end

local function popArrow()
	local mark = arrow()
	local fit = mark:FindFirstChild("Fit") :: UIScale
	local full = math.clamp(Layout.current().scale, 0.8, 1.3)
	if Comfort.reducedMotion() then
		fit.Scale = full
		return
	end
	fit.Scale = full * 0.4
	TweenService
		:Create(fit, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = full,
		})
		:Play()
end

local function myHull(): BasePart?
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local craft = seat and seat:FindFirstAncestorOfClass("Model")
	return craft and craft.PrimaryPart
end

local function waterAt(p: Vector3): CFrame
	return CFrame.new(p.X, Simulator.waterHeight(p.X, p.Z, Workspace:GetServerTimeNow()), p.Z)
end

local function onRam(d: Drawn)
	local at = d.model:GetAttribute("Ram")
	if typeof(at) == "Vector3" then
		VFXKit.play("pirate_ram", waterAt(at), { still = not d.mine })
	end
end

local function add(model: Instance)
	if not model:IsA("Model") or drawn[model] then
		return
	end
	local mine = model:GetAttribute("Hunting") == player.UserId
	local at = model:GetAttribute("At")
	local d: Drawn = {
		model = model,
		mine = mine,
		off = Vector3.zero,
		relative = false,
		published = nil,
		publishedAt = 0,
		yaw = 0,
		parked = false,
		wakeAt = 0,
	}
	local hull = if mine then myHull() else nil
	local rel = model:GetAttribute("Rel")
	if hull and typeof(rel) == "Vector3" then
		d.off, d.relative = rel, true
	elseif typeof(at) == "Vector3" then
		d.off = at
	end
	drawn[model] = d
	model:GetAttributeChangedSignal("Ram"):Connect(function()
		onRam(d)
	end)
	if mine then
		if typeof(at) == "Vector3" then
			VFXKit.play("pirate_spawn", waterAt(at), { still = true })
		end
		AudioController.play("Horn_Tug", nil, 0.8, 0.8)
		popArrow()
	end
end

local function drawArrow(pos: Vector3, show: boolean)
	local mark, pin = arrow()
	local cam = Workspace.CurrentCamera
	if not show or not cam or player:GetAttribute("OpsUiHidden") == true then
		mark.Visible = false
		return
	end
	local vp = cam.ViewportSize
	local p = cam:WorldToViewportPoint(pos + Vector3.new(0, 30, 0))
	local x, y = p.X, p.Y
	local onScreen = p.Z > 0 and x >= EDGE and x <= vp.X - EDGE and y >= EDGE and y <= vp.Y - EDGE
	local at: Vector2
	if onScreen then
		at = Vector2.new(x, y - ARROW)
		pin.Rotation = 0 -- tip down, over the boat
	else
		local dir: Vector2
		if p.Z > 0 then
			dir = Vector2.new(x - vp.X / 2, y - vp.Y / 2)
		else
			local rel = cam.CFrame:PointToObjectSpace(pos) -- behind you: to the side you'd turn to
			dir = Vector2.new(rel.X, -rel.Y)
		end
		if dir.Magnitude < 1e-3 then
			dir = Vector2.new(0, 1)
		end
		local k = math.min(
			(vp.X / 2 - EDGE) / math.max(math.abs(dir.X), 1e-3),
			(vp.Y / 2 - EDGE) / math.max(math.abs(dir.Y), 1e-3)
		)
		at = Vector2.new(vp.X / 2, vp.Y / 2) + dir * k
		pin.Rotation = math.deg(math.atan2(dir.Y, dir.X)) - 90 -- the pin's tip is its down
	end
	at = Layout.clearOfHud(at, Vector2.new(ARROW, ARROW) * 0.6)
	mark.Position = UDim2.fromOffset(at.X, at.Y)
	mark.Visible = true
end

local function step(dt: number)
	local anyMine = false
	local camPos = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position
		or Vector3.zero
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local hull = myHull()
	for model, d in drawn do
		local at, vel, rel =
			model:GetAttribute("At"), model:GetAttribute("Vel"), model:GetAttribute("Rel")
		if typeof(at) ~= "Vector3" or typeof(vel) ~= "Vector3" or typeof(rel) ~= "Vector3" then
			continue
		end
		local relative = d.mine and hull ~= nil
		local anchor = if relative
			then Vector3.new((hull :: BasePart).Position.X, 0, (hull :: BasePart).Position.Z)
			else Vector3.zero
		local boatVel = if relative
			then Vector3.new(
				(hull :: BasePart).AssemblyLinearVelocity.X,
				0,
				(hull :: BasePart).AssemblyLinearVelocity.Z
			)
			else Vector3.zero
		local published = if relative then rel else at
		if published ~= d.published then
			d.published, d.publishedAt = published, now
		end
		-- predicted since the last publish (10 Hz); a long gap between them must not throw it off
		local want = published + (vel - boatVel) * math.min(now - d.publishedAt, 0.25)
		-- a change of frame (seated again) or a jump (Go back landed): straight there, never flown across the map
		if relative ~= d.relative or (want - d.off).Magnitude > SNAP then
			d.off, d.relative = want, relative
		end
		d.off += (want - d.off) * (1 - math.exp(-SMOOTH * dt))
		local pos = anchor + d.off
		local far = not d.mine and (pos - Vector3.new(camPos.X, 0, camPos.Z)).Magnitude > CULL
		if far then
			if not d.parked then
				d.parked = true
				model:PivotTo(PARK)
			end
			continue
		end
		d.parked = false
		if vel.Magnitude > 1 then
			d.yaw = math.atan2(-vel.X, -vel.Z)
		end
		local water = Simulator.waterHeight(pos.X, pos.Z, serverNow)
		local cf = CFrame.new(pos.X, water + HOVER, pos.Z)
			* CFrame.Angles(0, d.yaw, 0)
			* CFrame.Angles(math.sin(now * 1.1) * 0.04, 0, math.sin(now * 0.8) * 0.03)
		model:PivotTo(cf)
		if
			now >= d.wakeAt
			and vel.Magnitude > 1
			and not Comfort.reducedMotion()
			and (cf.Position - camPos).Magnitude < WAKE_NEAR
		then
			d.wakeAt = now + WAKE_GAP
			local back = cf.LookVector * -1
			local stern = cf.Position + back * STERN
			VFXKit.play(
				"pickup_wake",
				CFrame.fromMatrix(
					Vector3.new(stern.X, water, stern.Z),
					cf.RightVector,
					(back + Vector3.yAxis * 0.6).Unit
				),
				{ still = true }
			)
		end
		if d.mine then
			anyMine = true
			drawArrow(cf.Position, model:GetAttribute("Phase") == "Hunt")
		end
	end
	if not anyMine and arrowMark then
		arrowMark.Visible = false
	end
end

local canvas: Frame? = nil
local function onBonus()
	arrow()
	canvas = canvas or Style.canvas(arrowGui :: ScreenGui)
	Toast.show(canvas :: Frame, "+25%", { icon = "cash", color = "green" })
	local hull = myHull()
	if hull then
		VFXKit.play("pirate_escape", waterAt(hull.Position))
	end
end

function PirateController.Init() end

function PirateController.Start()
	player:GetAttributeChangedSignal("PirateBonusAt"):Connect(onBonus)
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		local folder = Workspace:WaitForChild("Pirates")
		folder.ChildAdded:Connect(add)
		folder.ChildRemoved:Connect(function(child: Instance)
			if child:IsA("Model") then
				drawn[child] = nil
			end
		end)
		for _, child in folder:GetChildren() do
			add(child)
		end
	end)
end

return PirateController
