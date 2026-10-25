--!strict
-- SubController (docs/23 (h), WP-8): drives a submarine (a vehicle with attribute Sub = true, see
-- shared/Sub/Builder) from its DriverSeat. Inert until the local player sits in one.
--   Ahead / astern and turn: the VehicleSeat's ThrottleFloat / SteerFloat (W/S/A/D, arrows, gamepad
--   triggers and stick, the touch thumbstick), like the boats.
--   Rise / dive: E / Q, gamepad Y / X, two touch buttons with up / down chevrons (no text).
--   Hands-off it holds its depth; at the surface it floats like a slow boat (shared/Sub/Dive).
-- Every PreSimulation it runs shared/Sub/Rig on the hull it owns, with the drawn ocean height so
-- the hull sits on the waves the player sees. BoatController skips Sub models.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Glyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Glyph"))
local Rig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sub"):WaitForChild("Rig"))

local RISE, DIVE = "SubRise", "SubDive"

local SubController = {}

local localPlayer = Players.LocalPlayer
local driving: Model? = nil
local held = { [RISE] = false, [DIVE] = false }
local ocean: any = nil -- OceanController.GetVisualHeight, if it is there

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
		ContextActionService:BindAction(RISE, onAction, true, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
		ContextActionService:BindAction(DIVE, onAction, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		ContextActionService:SetPosition(RISE, UDim2.new(1, -170, 1, -215))
		ContextActionService:SetPosition(DIVE, UDim2.new(1, -170, 1, -150))
		skin(RISE, true)
		skin(DIVE, false)
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
		bind(model ~= nil)
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
	local dive = (if held[RISE] then 1 else 0) - (if held[DIVE] then 1 else 0)
	Rig.step(model, seat.ThrottleFloat, seat.SteerFloat, dive, dt, sea)
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
