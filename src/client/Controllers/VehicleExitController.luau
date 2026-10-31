--!strict
-- VehicleExitController: Space / gamepad A / the on-screen exit button (exit_button.png; driving on touch: the drive
-- pad's step-off button, TouchDriveController -> StepOff) gets the
-- player out of any vehicle seat (boats, jet skis, heli, sub), like a default Roblox seat. Bound only
-- while seated in a model with a VehicleId. It unseats directly, so OpsController's jump guard (which eats the default
-- seat jump during operation steps) does not trap the player; the cold open still keeps them aboard.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Layout"))

local EXIT_IMAGE = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
).Hud.ExitButton

local ACTION = "VehicleExit"

local player = Players.LocalPlayer

local VehicleExitController = {}

local function vehicleOf(seat: BasePart?): Model?
	local node: Instance? = seat
	while node and node.Parent do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end

-- Unseats now. The SeatWeld goes before any PivotTo: the server drops it only once the jump replicates, and
-- pivoting a still-welded character dragged the hull along onto the jetty (live v21: Flipped after a delivery)
local function stepOff(humanoid: Humanoid, seat: BasePart)
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
end

local function reach(vehicle: Model): number
	local size = vehicle:GetExtentsSize()
	return math.min(size.X, size.Z) / 2 + 3
end

-- A deck or shore to stand on beside the hull along one of `dirs`, or nil (only water there).
local function landSpot(
	seat: BasePart,
	vehicle: Model,
	character: Model,
	dirs: { Vector3 },
	skip: Instance?
): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle, character, skip :: Instance }
	params.RespectCanCollide = true
	-- walk out from the hull: a jet ski's berth leaves ~12 studs of water to the jetty finger (PT5: the
	-- one probe at half a beam + 3 found only water, you swam under the jetty)
	local r = reach(vehicle)
	for out = r, r + 12, 2 do
		for _, dir in dirs do
			local p = seat.Position + dir * out
			local hit = workspace:Raycast(p + Vector3.new(0, 12, 0), Vector3.new(0, -24, 0), params)
			if hit and hit.Material ~= Enum.Material.Water then
				-- 2 studs further onto the deck when it goes on: the first hit can be its very edge
				local p2 = p + dir * 2
				local deeper =
					workspace:Raycast(p2 + Vector3.new(0, 12, 0), Vector3.new(0, -24, 0), params)
				if deeper and deeper.Material ~= Enum.Material.Water then
					hit = deeper
				end
				return CFrame.new((hit :: RaycastResult).Position + Vector3.new(0, 3, 0))
			end
		end
	end
	return nil
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
	local seat = humanoid.SeatPart :: BasePart
	local craft = seat.Parent
	if craft and craft:GetAttribute("Airborne") == true then
		return Enum.ContextActionResult.Sink -- flying heli (local attribute): land first
	end
	stepOff(humanoid, seat)
	-- step off over the side: on a deck craft (Lifeboat) the jump left you standing on the seat, and
	-- it (or the passenger seat behind) took you back within seconds; land half a beam + 3 out, on the side
	-- with a deck or shore under it (moored right, the jetty was on the left: you swam under it, playtest
	-- 2026-10-28), else in the water on the right
	local vehicle = vehicleOf(seat)
	if vehicle then
		local body = character :: Model
		local side = seat.Position + seat.CFrame.RightVector * reach(vehicle)
		local at = landSpot(
			seat,
			vehicle,
			body,
			{ seat.CFrame.RightVector, -seat.CFrame.RightVector }
		) or CFrame.new(side.X, seat.Position.Y + 2, side.Z)
		body:PivotTo(at * seat.CFrame.Rotation)
	end
	return Enum.ContextActionResult.Sink
end

local function onSeated(active: boolean, seat: BasePart?)
	if active and vehicleOf(seat) then
		-- a driver on touch steps off from the drive pad (TouchDriveController); passengers keep this button
		local touch = not (Layout.device() == "Touch" and (seat :: BasePart).Name == "DriverSeat")
		ContextActionService:BindAction(
			ACTION,
			onExit,
			touch,
			Enum.KeyCode.Space,
			Enum.KeyCode.ButtonA
		)
		-- touch: the exit sprite over the stock round button (the core script swaps the button's
		-- own Image on press, so the sprite is a child and the stock art goes transparent)
		local button = touch and ContextActionService:GetButton(ACTION)
		if button then
			ContextActionService:SetPosition(ACTION, UDim2.new(1, -95, 1, -285))
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

-- Driven into a shore with nobody aboard (BoatController's wedge): step off onto it toward `dir`, like Space.
-- False when there is only water that way (the push-off frees the hull instead). Playtest 2026-10-30: after the
-- first delivery new players drove at the build-station beacon on land and the push-off bounced them back, again.
function VehicleExitController.Ashore(dir: Vector3): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local vehicle = vehicleOf(seat)
	if
		not (character and humanoid and seat and vehicle)
		or player:GetAttribute("ColdOpenDone") ~= true
	then
		return false
	end
	-- the wedge counts moored hulls too: never step onto one
	local at = landSpot(seat, vehicle, character, { dir }, workspace:FindFirstChild("Vehicles"))
	if not at then
		return false
	end
	stepOff(humanoid, seat)
	character:PivotTo(at * CFrame.lookAlong(Vector3.zero, dir))
	return true
end

-- The drive pad's step-off button: Space's path.
function VehicleExitController.StepOff()
	onExit(ACTION, Enum.UserInputState.Begin, nil :: any)
end

function VehicleExitController.Init() end

function VehicleExitController.Start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return VehicleExitController
