--!strict
-- PlatformPromptController: shows Roblox's own re-engagement prompts at good moments and never
-- mid-rescue. The timing policy and the asked timestamps live on the server (PlatformPromptService,
-- Shared/PlatformPrompts); this controller only watches the triggers the game already publishes:
--   StreakClaim    player attribute, set when a daily crate opens -> notification opt-in
--   dockBuildings  PlayerDataChanged: a new island building -> favourite, once its Lego build beat has ended
--   CrewOpDone     player attribute, set after a first rescue with 2+ crew -> invite
-- Every platform call is pcall-guarded and platform eligibility is checked before asking, so a
-- device that cannot show a prompt (young account, no invite sheet, Studio) just stays quiet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local PlatformPromptController = {}
PlatformPromptController.Priority = 96

local player = Players.LocalPlayer

local askRemote: RemoteEvent? = nil
local optInConnection: RBXScriptConnection? = nil

local function service(name: string): any?
	local ok, svc = pcall(function()
		return game:GetService(name)
	end)
	return if ok then svc else nil
end

-- Platform can show this prompt at all right now. Favourite is unknown-safe: if the read fails we
-- offer it (the server never offers twice).
local function canPrompt(kind: string): boolean
	if kind == "notify" then
		local svc = service("ExperienceNotificationService")
		if not svc then
			return false
		end
		local ok, can = pcall(function()
			return svc:CanPromptOptInAsync()
		end)
		return ok and can == true
	elseif kind == "favorite" then
		local svc = service("AvatarEditorService")
		if not svc then
			return false
		end
		local ok, favorited = pcall(function()
			return svc:GetFavoriteAsync(game.PlaceId, Enum.AvatarItemType.Asset)
		end)
		return not (ok and favorited == true)
	elseif kind == "invite" then
		local svc = service("SocialService")
		if not svc then
			return false
		end
		local ok, can = pcall(function()
			return svc:CanSendGameInviteAsync(player)
		end)
		return ok and can == true
	end
	return false
end

local function recordOptIn()
	local remote = Net.init():FindFirstChild("PlatformPrompt_OptIn")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer()
	end
end

local function show(kind: string)
	if kind == "notify" then
		local svc = service("ExperienceNotificationService")
		if svc then
			-- No result is exposed: closing the prompt is the only signal we get.
			if optInConnection then
				optInConnection:Disconnect()
				optInConnection = nil
			end
			local ok = pcall(function()
				optInConnection = svc.OptInPromptClosed:Connect(function()
					if optInConnection then
						optInConnection:Disconnect()
						optInConnection = nil
					end
					recordOptIn()
				end)
				svc:PromptOptIn()
			end)
			if not ok and optInConnection then
				optInConnection:Disconnect()
				optInConnection = nil
			end
		end
	elseif kind == "favorite" then
		local svc = service("AvatarEditorService")
		if svc then
			pcall(function()
				svc:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
			end)
		end
	elseif kind == "invite" then
		local svc = service("SocialService")
		if svc then
			pcall(function()
				svc:PromptGameInvite(player)
			end)
		end
	end
end

local function askEvent(): RemoteEvent?
	local remote = askRemote
	if remote then
		return remote
	end
	local found = Net.init():FindFirstChild("PlatformPrompt_Ask")
	if found and found:IsA("RemoteEvent") then
		askRemote = found
	end
	return askRemote
end

function PlatformPromptController.Request(kind: string)
	task.spawn(function()
		if not canPrompt(kind) then
			return
		end
		local remote = askEvent()
		if remote then
			remote:FireServer(kind)
		end
	end)
end

local BUILD_BEAT = 7 -- s: DockService's builders watch for 6 s
local builtCount: number? = nil

local function countOf(owned: any): number
	local n = 0
	if type(owned) == "table" then
		for _ in owned do
			n += 1
		end
	end
	return n
end

function PlatformPromptController.Init()
	player:GetAttributeChangedSignal("StreakClaim"):Connect(function()
		task.delay(4, function()
			PlatformPromptController.Request("notify")
		end)
	end)
	player:GetAttributeChangedSignal("CrewOpDone"):Connect(function()
		if player:GetAttribute("CrewOpDone") == true then
			task.delay(12, function()
				PlatformPromptController.Request("invite")
			end)
		end
	end)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then
			return
		end
		local n = countOf(data.dockBuildings)
		if builtCount and n > builtCount then
			task.delay(BUILD_BEAT, PlatformPromptController.Request, "favorite")
		end
		builtCount = n
	end)
end

function PlatformPromptController.Start()
	local folder = Net.init()
	local ask = folder:WaitForChild("PlatformPrompt_Ask")
	if ask:IsA("RemoteEvent") then
		askRemote = ask
	end
	local offer = folder:WaitForChild("PlatformPrompt_Offer")
	if offer:IsA("RemoteEvent") then
		offer.OnClientEvent:Connect(function(kind: any)
			if type(kind) == "string" then
				show(kind)
			end
		end)
	end
end

return PlatformPromptController
