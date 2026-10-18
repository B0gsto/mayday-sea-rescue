--!strict
-- SettingsService: the server side of the settings panel's Assist / Pro switch (docs 09 section
-- 9.3). The client fires Settings_SetPro(want: boolean) after its saved settings load and on
-- every change; the server owns the player's "OpsPro" attribute (OperationService, OpsHud,
-- OpsDebrief and BoatController read it; nil or false = Assist).
--   * Pro -> Assist applies at once, even mid-operation (the Pro bonus is lost).
--   * Assist -> Pro waits until the player is not in an operation and the cold open is done
--     (a 2 s sweep applies a pending Pro request then, and after the cold open forced Assist).
-- Remote: Settings_SetPro (own RemoteEvent under ReplicatedStorage.Net, C->S, rate limited).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsRules"))

local SettingsService = {}
SettingsService.Priority = 120

local SWEEP = 2
local MIN_INTERVAL = 0.25

local wanted: { [Player]: boolean } = {}
local lastCall: { [Player]: number } = {}

local function inOperation(player: Player): boolean
	local ok, result = pcall(function()
		local OperationService = require(script.Parent:WaitForChild("OperationService")) :: any
		return OperationService.GetOperationOf(player) ~= nil
	end)
	return ok and result == true
end

local function apply(player: Player)
	local want = wanted[player] == true
	local current = player:GetAttribute("OpsPro") == true
	local pro = SettingsRules.resolvePro(
		want,
		current,
		want and not current and inOperation(player),
		player:GetAttribute("ColdOpenDone") == true
	)
	if pro ~= current then
		player:SetAttribute("OpsPro", pro)
	end
end

function SettingsService.Init()
	local net = ReplicatedStorage:FindFirstChild("Net")
	if not net then
		local folder = Instance.new("Folder")
		folder.Name = "Net"
		folder.Parent = ReplicatedStorage
		net = folder
	end
	assert(net, "unreachable")
	local remote = net:FindFirstChild("Settings_SetPro") :: RemoteEvent?
	if not remote then
		local created = Instance.new("RemoteEvent")
		created.Name = "Settings_SetPro"
		created.Parent = net
		remote = created
	end
	assert(remote, "unreachable");
	(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, want: any)
		local t = os.clock()
		if type(want) ~= "boolean" or t - (lastCall[player] or -math.huge) < MIN_INTERVAL then
			return
		end
		lastCall[player] = t
		wanted[player] = want
		apply(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		wanted[player] = nil
		lastCall[player] = nil
	end)
end

function SettingsService.Start()
	while true do
		task.wait(SWEEP)
		for player, want in wanted do
			if want and player.Parent then
				apply(player)
			end
		end
	end
end

return SettingsService
