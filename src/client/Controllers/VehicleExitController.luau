--!strict
-- VehicleExitController: Space / gamepad A / the on-screen exit button (exit_button.png) gets the
-- player out of any vehicle seat (cars, boats, jet skis), like a default Roblox seat. Bound only
-- while seated in a model with a VehicleId. It unseats directly, so OpsController's jump guard (which eats the default
-- seat jump during operation steps) does not trap the player; the cold open still keeps them aboard.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EXIT_IMAGE = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
).Hud.ExitButton

local ACTION = "VehicleExit"

local player = Players.LocalPlayer

local VehicleExitController = {}

local function inVehicle(seat: BasePart?): boolean
	local node: Instance? = seat
	while node and node.Parent do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return true
		end
		node = node.Parent
	end
	return false
end

local function onExit(
	_: string,
	state: Enum.UserInputState,
	_input: InputObject
): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin or player:GetAttribute("ColdOpenDone") ~= true then
		return Enum.ContextActionResult.Pass
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.SeatPart) then
		return Enum.ContextActionResult.Pass
	end
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	return Enum.ContextActionResult.Sink
end

local function onSeated(active: boolean, seat: BasePart?)
	if active and inVehicle(seat) then
		ContextActionService:BindAction(
			ACTION,
			onExit,
			true,
			Enum.KeyCode.Space,
			Enum.KeyCode.ButtonA
		)
		ContextActionService:SetPosition(ACTION, UDim2.new(1, -95, 1, -285))
		-- touch: the exit sprite over the stock round button (the core script swaps the button's
		-- own Image on press, so the sprite is a child and the stock art goes transparent)
		local button = ContextActionService:GetButton(ACTION)
		if button then
			button.ImageTransparency = 1
			local skin = Instance.new("ImageLabel")
			skin.Name = "Skin"
			skin.BackgroundTransparency = 1
			skin.Size = UDim2.fromScale(1, 1)
			skin.Image = EXIT_IMAGE
			skin.Parent = button
		end
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

local function onCharacter(character: Model)
	ContextActionService:UnbindAction(ACTION)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Seated:Connect(onSeated)
		if humanoid.SeatPart then
			onSeated(true, humanoid.SeatPart)
		end
	end
end

function VehicleExitController.Init() end

function VehicleExitController.Start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return VehicleExitController
