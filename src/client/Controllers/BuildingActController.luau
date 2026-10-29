--!strict
-- BuildingActController (docs/25 J, walk-in buildings): the one thing you do inside a building. DockPieces tags the
-- part "BuildingAct" with attribute Act; this adds its prompt (E / X / tap) and plays the act. A part still hidden
-- by its construction (Transparency 1) has no prompt.
--   Telescope (Lookout Tower): the camera looks through the scope at the nearest survivor in the water (golden ones
--   first), then eases back; no survivor out: a look out to sea.
--   Barge (Depot rack): the same look, at the nearest supply barge (or its mooring when none is out).
--   Build (Workshop bench): build mode. Shop (Fish Market counter): the shop. Crew (Rescue Boathouse console): the
--   crew. Boats (Boat Yard console): your craft board.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraController = require(script.Parent:WaitForChild("CameraController"))
local DockController = require(script.Parent:WaitForChild("DockController"))
local Menu = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Menu"))

local BuildingActController = {}

local TAG = "BuildingAct"
local LABEL = { Telescope = "Look", Barge = "Look" }
local LOOK = 3 -- seconds through the scope
local ZOOM = 0.6 -- seconds to zoom in / out

local busy = false

-- the survivor to look at from `from`: a golden one first, then the nearest
local function target(from: Vector3): Vector3?
	local props = Workspace:FindFirstChild("CallProps")
	local best, bestScore = nil, math.huge
	for _, m in if props then props:GetChildren() else {} do
		if m:IsA("Model") and m:GetAttribute("Survivor") == true then
			local at = m:GetPivot().Position
			local score = (at - from).Magnitude - (if m:GetAttribute("Golden") then 1e6 else 0)
			if score < bestScore then
				best, bestScore = at, score
			end
		end
	end
	return best
end

-- ease the camera from where it is to look from `eye` at `at` (~30 studs fill the view), hold, ease back
local function look(eye: Vector3, at: Vector3)
	local camera = Workspace.CurrentCamera
	eye += (at - eye).Unit * 5 -- out past the window frame / rack
	local from, fov0 = camera.CFrame, camera.FieldOfView
	local view = CFrame.lookAt(eye, at)
	local fov = math.clamp(math.deg(math.atan(30 / (at - eye).Magnitude)) * 2, 6, 40) -- ~30 studs fill the view
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = if t < ZOOM
			then t / ZOOM
			elseif t > LOOK + ZOOM then 1 - (t - LOOK - ZOOM) / ZOOM
			else 1
		k = math.clamp(k, 0, 1)
		k = k * k * (3 - 2 * k)
		if t >= LOOK + 2 * ZOOM then
			conn:Disconnect()
			CameraController.ClearOverride()
			busy = false
			return
		end
		CameraController.SetOverride(from:Lerp(view, k), fov0 + (fov - fov0) * k)
	end)
end

local function telescope(scope: BasePart)
	local eye = scope.Position + Vector3.new(0, 0.6, 0)
	look(eye, target(eye) or (eye + scope.CFrame.RightVector * 300)) -- the tube's axis (a cylinder runs along X)
end

-- from over the depot roof, the nearest barge in sight (DepotController parents it while in view), else its mooring
local function barge(rack: BasePart)
	local eye = rack.Position + Vector3.new(0, 24, 0)
	local best, dist = nil, math.huge
	for _, m in Workspace:GetChildren() do
		if m.Name == "Barge" and m:IsA("Model") then
			local at = m:GetPivot().Position
			if (at - eye).Magnitude < dist then
				best, dist = at, (at - eye).Magnitude
			end
		end
	end
	local moor = rack.Parent and rack.Parent:FindFirstChild("ATT_BargeMoor", true)
	look(
		eye,
		best
			or (
				if moor and moor:IsA("Attachment")
					then moor.WorldPosition
					else eye + rack.CFrame.LookVector * 200
			)
	)
end

local function done()
	busy = false
end

local function board(_: BasePart)
	for _, rack in CollectionService:GetTagged("BoatBoard") do
		if
			rack.Name == "BoatBoard"
			and rack:GetAttribute("Owner") == Players.LocalPlayer.UserId
		then
			Menu.openBoard(rack)
		end
	end
	done()
end

local ACTS: { [string]: (BasePart) -> () } = {
	Telescope = telescope,
	Barge = barge,
	Boats = board,
	Build = function()
		DockController.OpenBuild()
		done()
	end,
	Shop = function()
		Menu.open("Shop")
		done()
	end,
	Crew = function()
		Menu.open("Crew")
		done()
	end,
}

local function add(p: Instance)
	local act = p:GetAttribute("Act")
	if not (p:IsA("BasePart") and type(act) == "string" and ACTS[act]) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuildingAct"
	prompt.ActionText = LABEL[act] or act
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8 + math.max(p.Size.X, p.Size.Z) / 2 -- from its centre: a long rack or counter reaches its ends
	prompt.RequiresLineOfSight = false
	prompt.Enabled = p.Transparency < 1
	-- on a small clear anchor part beside it: a prompt anywhere under an asset MeshPart (the Depot rack) never shows
	local anchor = Instance.new("Part")
	anchor.Name = "ActAnchor"
	anchor.Size = Vector3.one
	anchor.CFrame = p.CFrame
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CastShadow =
		true, false, false, false
	anchor.Parent = p.Parent
	p.Destroying:Connect(function()
		anchor:Destroy()
	end)
	prompt.Parent = anchor
	p:GetPropertyChangedSignal("Transparency"):Connect(function()
		prompt.Enabled = p.Transparency < 1
	end)
	prompt.Triggered:Connect(function()
		if not busy then
			busy = true
			ACTS[act](p)
		end
	end)
end

function BuildingActController.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	for _, p in CollectionService:GetTagged(TAG) do
		add(p)
	end
end

return BuildingActController
