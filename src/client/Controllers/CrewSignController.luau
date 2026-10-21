--!strict
-- CrewSignController: the "Join crew" sign beside the harbour noticeboard (G68). Shown only when
-- Shared/Config/SocialConfig.GroupId > 0. Membership is cached by GroupRewardService on join and
-- rechecked when the player walks to the board; Roblox's own group prompt is asked through
-- GroupService:PromptJoinAsync (pcall). No browser links, no popups: the sign is the only place it
-- appears, and if the prompt API is unavailable it stays a plain label with the reward preview.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GroupReward = require(Shared:WaitForChild("GroupReward"))
local SocialConfig = require(Shared:WaitForChild("Config"):WaitForChild("SocialConfig"))

local World = script.Parent.Parent:WaitForChild("World")
local CrewSign = require(World:WaitForChild("CrewSign"))

local CrewSignController = {}
CrewSignController.Priority = 83

local player = Players.LocalPlayer
local sign: CrewSign.Sign? = nil
local checkRemote: RemoteFunction? = nil
local lastCheck = 0

local function groundAt(position: Vector3): CFrame
	local filter = {}
	if player.Character then
		table.insert(filter, player.Character)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(filter, other.Character)
		end
	end
	for _, name in { "HarbourEventBoard", "CrewSign" } do
		local model = Workspace:FindFirstChild(name)
		if model then
			table.insert(filter, model)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	local hit = Workspace:Raycast(
		Vector3.new(position.X, position.Y + 50, position.Z),
		Vector3.new(0, -100, 0),
		params
	)
	return CFrame.new(position.X, if hit then hit.Position.Y else position.Y, position.Z)
end

local function setMember(member: boolean)
	local current = sign
	if current then
		current.setMember(member)
	end
end

local function applyView(view: any)
	if type(view) == "table" then
		setMember(view.member == true)
	end
end

local function recheck()
	local remote = checkRemote
	if not remote or os.clock() - lastCheck < SocialConfig.CheckCooldown then
		return
	end
	lastCheck = os.clock()
	task.spawn(function()
		local ok, view = pcall(function()
			return remote:InvokeServer()
		end)
		if ok then
			applyView(view)
		end
	end)
end

local function nearBoard(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local here = SocialConfig.NoticeboardPosition
	local dx = root.Position.X - here.X
	local dz = root.Position.Z - here.Z
	return dx * dx + dz * dz <= SocialConfig.CheckRange * SocialConfig.CheckRange
end

local function joinGroup()
	local GroupService = game:GetService("GroupService")
	local ok = pcall(function()
		GroupService:PromptJoinAsync(SocialConfig.GroupId)
	end)
	if not ok then
		return -- no prompt on this platform: the sign's label and preview are all that shows
	end
	task.delay(4, recheck)
end

function CrewSignController.Init() end

function CrewSignController.Start()
	if not GroupReward.enabled(SocialConfig.GroupId) then
		return
	end
	local at = groundAt(SocialConfig.NoticeboardPosition)
	local built = CrewSign.build(at * CFrame.new(-11.5, 0, 0)) -- west of the board: the pet yard is east
	sign = built
	built.setMember(player:GetAttribute("GroupCrew") == true)
	built.prompt.Triggered:Connect(joinGroup)
	player:GetAttributeChangedSignal("GroupCrew"):Connect(function()
		setMember(player:GetAttribute("GroupCrew") == true)
	end)

	local folder = ReplicatedStorage:WaitForChild("Net", 30)
	if folder then
		local found = folder:WaitForChild("Group_Check", 20)
		if found and found:IsA("RemoteFunction") then
			checkRemote = found
		end
	end
	recheck()

	while true do
		if nearBoard() then
			recheck()
		end
		task.wait(1)
	end
end

return CrewSignController
