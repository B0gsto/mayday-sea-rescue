--!strict
-- BuildingActController (docs/25 J, walk-in buildings): the one thing you do inside a building. DockPieces tags the
-- part "BuildingAct" with attribute Act; this adds its prompt (E / X / tap) and plays the act. A part still hidden
-- by its construction (Transparency 1) has no prompt.
--   Telescope (Lookout Tower): the camera looks through the scope at the nearest survivor in the water (golden ones
--   first), then eases back; no survivor out: a look out to sea.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraController = require(script.Parent:WaitForChild("CameraController"))

local BuildingActController = {}

local TAG = "BuildingAct"
local LABEL = { Telescope = "Look" }
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

local function telescope(scope: BasePart)
	local camera = Workspace.CurrentCamera
	local eye = scope.Position + Vector3.new(0, 0.6, 0)
	local at = target(eye) or (eye + scope.CFrame.RightVector * 300) -- the tube's axis (a cylinder runs along X)
	local from, fov0 = camera.CFrame, camera.FieldOfView
	local view = CFrame.lookAt(eye, at)
	local fov = math.clamp(math.deg(math.atan(30 / (at - eye).Magnitude)) * 2, 6, 40) -- ~30 studs fill the view
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = if t < ZOOM then t / ZOOM elseif t > LOOK + ZOOM then 1 - (t - LOOK - ZOOM) / ZOOM else 1
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

local ACTS: { [string]: (BasePart) -> () } = { Telescope = telescope }

local function add(p: Instance)
	local act = p:GetAttribute("Act")
	if not (p:IsA("BasePart") and type(act) == "string" and ACTS[act]) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuildingAct"
	prompt.ActionText = LABEL[act] or act
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = p.Transparency < 1
	prompt.Parent = p
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
