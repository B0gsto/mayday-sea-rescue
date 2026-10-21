--!strict
-- PrivateCasualtyController (2026-10-21): a personal call's casualty is its crew's only. A Workspace.CallProps
-- model whose PrivateTo attribute (Ops/Board.privateList, set by RescueService) leaves this player out is
-- parented to nil on this client; when the server clears it (they are aboard the crew's boat) it comes back.
-- Cosmetic only: the server already refuses a non-crew board (OperationService.CanAct, ops steps).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Board =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("Board"))

local PrivateCasualtyController = {}

local stash: { [Instance]: Instance } = setmetatable({}, { __mode = "k" }) :: any -- hidden model -> parent
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function apply(m: Instance)
	local mine = Board.mayAct(m:GetAttribute("PrivateTo"), Players.LocalPlayer.UserId)
	if not mine and m.Parent and not stash[m] then
		stash[m] = m.Parent
		m.Parent = nil
	elseif mine and stash[m] then
		local parent = stash[m]
		stash[m] = nil
		if not m.Parent then
			m.Parent = parent
		end
	end
end

local function watch(m: Instance)
	if m:IsA("Model") and not watched[m] then
		watched[m] = true
		m:GetAttributeChangedSignal("PrivateTo"):Connect(function()
			apply(m)
		end)
		task.defer(apply, m) -- not inside ChildAdded: reparenting there warns
	end
end

function PrivateCasualtyController.Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild("CallProps")
		folder.ChildAdded:Connect(watch)
		for _, m in folder:GetChildren() do
			watch(m)
		end
	end)
end

return PrivateCasualtyController
