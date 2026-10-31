--!strict
-- SubController (docs/23 (h), WP-8): drives a submarine (a vehicle with attribute Sub = true, see
-- shared/Sub/Builder) from its DriverSeat. Inert until the local player sits in one.
--   Ahead / astern and turn: the VehicleSeat's ThrottleFloat / SteerFloat (W/S/A/D, arrows, gamepad
--   triggers and stick, the touch thumbstick), like the boats.
--   Rise / dive: E / Q, gamepad RB / LB or the D-pad up / down (the triggers drive it; X / Y stay with prompts and
--   the Next chip), two touch buttons with up / down chevrons (no text). On a touch device the
--   drive pad (TouchDriveController) drives it instead: GO / BRAKE, LEFT / RIGHT, the teal rise / dive arrows.
--   Hands-off it holds its depth; at the surface it floats like a slow boat (shared/Sub/Dive).
--   Going under / breaking the surface plays sub_dive / sub_surface (bubbles, splash, sound); while piloting,
--   Ocean/Underwater draws the clearer sub view (thinner fog, less darkening).
-- Every PreSimulation it runs shared/Sub/Rig on the hull it owns, with the drawn ocean height so
-- the hull sits on the waves the player sees. BoatController skips Sub models.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatController = require(script.Parent.BoatController)
local Glyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Glyph"))
local Rig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sub"):WaitForChild("Rig"))
local TouchDriveController = require(script.Parent.TouchDriveController)
local Underwater = require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("Underwater"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local RISE, DIVE = "SubRise", "SubDive"

local SubController = {}

local localPlayer = Players.LocalPlayer
local driving: Model? = nil
local held = { [RISE] = false, [DIVE] = false }
local ocean: any = nil -- OceanController.GetVisualHeight, if it is there
local wasSubmerged: boolean? = nil -- last step's Dive state; nil right after taking the helm (no splash then)

local function subOf(seat: Instance): Model?
	local model = seat.Parent
	return if model and model:IsA("Model") and model:GetAttribute("Sub") == true then model else nil
end

local function onAction(name: string, state: Enum.UserInputState): Enum.ContextActionResult
	held[name] = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

-- a chevron of two bars over the stock touch button, pointing up or down
local function skin(name: string, up: boolean)
	local button = ContextActionService:GetButton(name)
	if not button then
		return
	end
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.6, 0.6)
	icon.Rotation = if up then 0 else 180
	icon.Parent = button
	local white = Color3.new(1, 1, 1)
	Glyph.bar(icon, Vector2.new(0.62, 0.16), Vector2.new(0.32, 0.5), -40, white)
	Glyph.bar(icon, Vector2.new(0.62, 0.16), Vector2.new(0.68, 0.5), 40, white)
end

local function bind(on: boolean)
	if on then
		local touch = not TouchDriveController.on() -- the drive pad has its own rise / dive
		local rise = { Enum.KeyCode.E, Enum.KeyCode.ButtonR1, Enum.KeyCode.DPadUp }
		local dive = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1, Enum.KeyCode.DPadDown }
		ContextActionService:BindAction(RISE, onAction, touch, table.unpack(rise))
		ContextActionService:BindAction(DIVE, onAction, touch, table.unpack(dive))
		if touch then
			ContextActionService:SetPosition(RISE, UDim2.new(1, -170, 1, -215))
			ContextActionService:SetPosition(DIVE, UDim2.new(1, -170, 1, -150))
			skin(RISE, true)
			skin(DIVE, false)
		end
	else
		ContextActionService:UnbindAction(RISE)
		ContextActionService:UnbindAction(DIVE)
		held[RISE], held[DIVE] = false, false
	end
end

local function step(dt: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = if seat
			and seat:IsA("VehicleSeat")
			and seat.Name == "DriverSeat"
		then subOf(seat)
		else nil
	if model ~= driving then
		if driving then
			Rig.clear(driving) -- the server floats it from here
		end
		driving = model
		wasSubmerged = nil
		bind(model ~= nil)
		Underwater.setClear(model ~= nil)
	end
	if not (model and seat and seat:IsA("VehicleSeat")) then
		return
	end
	local root = model.PrimaryPart
	local sea: number? = nil
	if root and ocean and type(ocean.GetVisualHeight) == "function" then
		local ok, h = pcall(ocean.GetVisualHeight, root.Position.X, root.Position.Z)
		sea = if ok and type(h) == "number" then h else nil
	end
	BoatController.EngageControls(seat) -- the default vehicle controls drive the seat's throttle
	local dive = (if held[RISE] then 1 else 0) - (if held[DIVE] then 1 else 0)
	local pad = TouchDriveController -- the touch drive pad, 0 off touch
	local state = Rig.step(
		model,
		math.clamp(seat.ThrottleFloat + pad.throttle(), -1, 1),
		math.clamp(seat.SteerFloat + pad.steer(), -1, 1),
		math.clamp(dive + pad.lift(), -1, 1),
		dt,
		sea
	)
	if state and root and wasSubmerged ~= nil and state.submerged ~= wasSubmerged then
		local at = root.Position
		VFXKit.play(
			if state.submerged then "sub_dive" else "sub_surface",
			CFrame.new(at),
			{ height = math.max((sea or at.Y + 3) - at.Y, 0) } -- the top layers sit on the surface
		)
	end
	wasSubmerged = if state then state.submerged else nil
end

function SubController.Init()
	local module = script.Parent:FindFirstChild("OceanController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, module)
		ocean = if ok then result else nil
	end
end

function SubController.Start()
	RunService.PreSimulation:Connect(step)
end

return SubController
