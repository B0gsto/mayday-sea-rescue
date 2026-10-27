--!strict
-- ChimneyController (docs/26 "Chimneys", ambience): a slow round puff every few seconds from each island cottage's
-- chimney (DockPieces' "Chimney" brick) near you, and from any `ATT_Chimney` attachment (TODO: the smokehouse mesh,
-- M_Bld_FishMarketAddons, has none yet). Hidden bricks (a site still building) stay quiet. Silent on purpose: an
-- ambient puff every few seconds would nag.
local Workspace = game:GetService("Workspace")

local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local ChimneyController = {}

local NEAR = 120 -- studs from the camera
local GAP = { 3, 5 } -- seconds between one chimney's puffs

local chimneys: { [Instance]: number } = {} -- the chimney -> its next puff (os.clock)

local function add(d: Instance)
	if
		(d:IsA("BasePart") and d.Name == "Chimney")
		or (d:IsA("Attachment") and d.Name == "ATT_Chimney")
	then
		chimneys[d] = os.clock() + math.random() * GAP[2]
	end
end

local function top(d: Instance): Vector3?
	if d:IsA("BasePart") then
		if d.Transparency >= 1 or d.LocalTransparencyModifier >= 1 then
			return nil
		end
		return (d.CFrame * CFrame.new(0, d.Size.Y / 2 + 0.4, 0)).Position
	end
	return (d :: Attachment).WorldPosition
end

function ChimneyController.Start()
	local marina = Workspace:WaitForChild("Marina")
	marina.DescendantAdded:Connect(add)
	marina.DescendantRemoving:Connect(function(d)
		chimneys[d] = nil
	end)
	for _, d in marina:GetDescendants() do
		add(d)
	end
	while true do
		task.wait(0.5)
		local camera = Workspace.CurrentCamera
		local now = os.clock()
		for d, due in chimneys do
			if now < due or not camera then
				continue
			end
			chimneys[d] = now + GAP[1] + math.random() * (GAP[2] - GAP[1])
			local at = top(d)
			if at and (at - camera.CFrame.Position).Magnitude <= NEAR then
				VFXKit.play("chimney_puff", CFrame.new(at))
			end
		end
	end
end

return ChimneyController
