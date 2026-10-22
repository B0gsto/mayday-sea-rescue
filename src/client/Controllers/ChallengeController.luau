--!strict
-- ChallengeController: the client side of daily and weekly challenges (LU-1).
--   * The player's rolls on the station board (UI/ChallengeBoard): a local SurfaceGui on the panel
--     the server built at the quay spawn (Workspace.StationChallengeBoard).
-- Data arrives as Challenge_State pushes (roll, completion, reroll) and is pulled once through
-- Challenge_Get (RemoteFunction, created by ChallengeService under ReplicatedStorage.Net).
-- Nothing here is interactive: the board shows the challenges, the player just plays.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UI = script.Parent.Parent:WaitForChild("UI")
local Board = require(UI:WaitForChild("ChallengeBoard"))

local ChallengeController = {}
ChallengeController.Priority = 80

local BOARD_NAME = "StationChallengeBoard"

local board: Board.Board? = nil
local pending: Board.View? = nil

local function apply(view: Board.View?)
	if view ~= nil then
		pending = view
	end
	if board and pending then
		board.update(pending)
	end
end

local function mountBoard()
	local model = Workspace:WaitForChild(BOARD_NAME, 60)
	if not model then
		return
	end
	local panel = model:FindFirstChild("Panel")
	if panel and panel:IsA("BasePart") then
		local mounted = Board.mount(panel)
		board = mounted
		if pending then
			mounted.update(pending)
		end
	end
end

function ChallengeController.Start()
	task.spawn(mountBoard)
	local netFolder = ReplicatedStorage:WaitForChild("Net", 30)
	if not netFolder then
		return
	end
	local state = netFolder:WaitForChild("Challenge_State", 30)
	if state and state:IsA("RemoteEvent") then
		state.OnClientEvent:Connect(function(view: any)
			if type(view) == "table" then
				apply(view :: Board.View)
			end
		end)
	end
	local get = netFolder:WaitForChild("Challenge_Get", 30)
	if not get or not get:IsA("RemoteFunction") then
		return
	end
	local ok, view = pcall(function()
		return get:InvokeServer()
	end)
	if ok and type(view) == "table" then
		apply(view :: Board.View)
	end
end

return ChallengeController
