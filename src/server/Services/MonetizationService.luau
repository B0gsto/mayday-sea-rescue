--!strict
-- MonetizationService: Robux Developer Products and Game Passes (docs/04, release plan RP-M1).
--
-- * The one ProcessReceipt callback for the place. Each receipt is granted exactly once: the grant and
--   the receipt id go into the player's profile together through DataService.CommitReceipt (the receipt
--   ledger, RP-D1), and only after that save commits do we return PurchaseGranted. Any failure returns
--   NotProcessedYet, so Roblox retries (also on the next join) and nobody pays without getting the item.
--   If DataService.CommitReceipt is missing, a session-only ledger plus DataService.Save stands in.
-- * Game pass ownership: UserOwnsGamePassAsync on join (with retries), cached per player, updated by
--   PromptGamePassPurchaseFinished, mirrored to the client as player attributes "Pass_<Key>" = true.
-- * PolicyService gate: the policy is read on join; paid random items (none at launch) are only offered
--   where the policy says they are allowed (docs/04 section 8).
-- * id = 0 or ready = false: not for sale. Nothing is offered, no handler is bound.
-- * Day passes (Products with dayPassFor): the end hour is saved in flag shop.day<PassKey>
--   (MonetizationEffects) and mirrored as the player attribute "DayPass_<PassKey>" = unix end second.
--
-- API (server; call the registration functions in your Init):
--   MonetizationService.OnProduct(key, grant(player, data, receipt), afterSaved(player, receipt, fresh)?)
--       grant mutates the saved PlayerData; it must not yield; return false (or error) = not granted
--       (DataService rolls the data back). Check before mutating: the fallback ledger cannot roll back.
--       afterSaved runs in its own thread once the save holding the grant has committed.
--   MonetizationService.OnPassOwned(key, fn(player, isNewPurchase))   also fires on join for owners
--   MonetizationService.OwnsPass(player, key): boolean              owned, or a day pass for it is running
--   MonetizationService.PassesChecked(player): boolean / WaitForPasses(player, timeout?): boolean
--   MonetizationService.GetPolicy(player): Policy?                     nil until checked (or failed)
--   MonetizationService.IsOffered(player, kind, key): boolean          kind = "Products" | "GamePasses"
--   MonetizationService.GetCatalogue(player): { CatalogueEntry }       what this player may be offered
--   MonetizationService.SetPassOwnedForTesting(player, key)            Studio only (effects with id 0)
-- Remotes (created here under ReplicatedStorage.Net):
--   Monetization_GetCatalogue  C->S function -> { {kind, key, id, name, owned} }
--   Monetization_Purchased     S->C {kind, key, name} after a pass purchase or a committed product grant
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Core = require(script.Parent:WaitForChild("Monetization"):WaitForChild("Core"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Effects = require(Shared:WaitForChild("MonetizationEffects"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

type PlayerData = Rules.PlayerData
export type Kind = "Products" | "GamePasses"
export type Policy = { [string]: any }
export type CatalogueEntry = {
	kind: Kind,
	key: string,
	id: number,
	name: string,
	order: number,
	owned: boolean?,
}

local DATA_WAIT_SECONDS = 20
local PASS_CHECK_ATTEMPTS = 3
local POLICY_ATTEMPTS = 3

local MonetizationService = {}
MonetizationService.Priority = 30 -- after DataService (20)

local index = Core.index(MonetizationConfig)
local handlers: { [string]: Core.ProductHandler } = {}
local passCallbacks: { [string]: { (Player, boolean) -> () } } = {}
local ownedPasses: { [Player]: { [string]: boolean } } = {}
local passesChecked: { [Player]: boolean } = {}
local policies: { [Player]: Policy } = {}
local purchasedRemote: RemoteEvent? = nil

local function log(message: string)
	warn(`[Monetization] {message}`)
end

local fallbackCommit = Core.newFallbackCommit({
	getData = function(player: any)
		return DataService.Get(player)
	end,
	isTemporary = function(player: any)
		return (player :: Player):GetAttribute("DataTemporary") == true
	end,
	markDirty = function(player: any)
		DataService.MarkDirty(player)
	end,
	save = function(player: any)
		return DataService.Save(player, false)
	end,
	keyOf = function(player: any)
		return (player :: Player).UserId -- kept for the server's life: a rejoin cannot re-grant
	end,
	log = log,
})
local warnedFallback = false

-- Adapter: DataService.CommitReceipt(player, id, grantFn) from RP-D1 when it exists, else the fallback.
-- Looked up on every call so RP-M1 and RP-D1 can land in either order.
local function commitReceipt(player: any, receiptId: string, grantFn: (data: any) -> boolean?): any
	local commit = (DataService :: any).CommitReceipt
	if type(commit) == "function" then
		return commit(player, receiptId, grantFn)
	end
	if not warnedFallback then
		warnedFallback = true
		log("DataService.CommitReceipt missing: using the session-only receipt ledger")
	end
	return fallbackCommit(player, receiptId, grantFn)
end

local function waitForData(player: any): boolean
	local deadline = os.clock() + DATA_WAIT_SECONDS
	while (player :: Player).Parent and DataService.Get(player) == nil and os.clock() < deadline do
		task.wait(0.25)
	end
	return (player :: Player).Parent ~= nil and DataService.Get(player) ~= nil
end

local function itemFor(kind: Kind, key: string): any
	return (MonetizationConfig :: any)[kind][key]
end

local function firePurchased(player: Player, kind: Kind, key: string)
	local item = itemFor(kind, key)
	if purchasedRemote and item and player.Parent then
		purchasedRemote:FireClient(player, { kind = kind, key = key, name = item.name })
	end
end

local processReceipt = Core.newReceiptProcessor({
	index = index,
	getPlayer = function(userId: number)
		return Players:GetPlayerByUserId(userId)
	end,
	waitForData = waitForData,
	commit = commitReceipt,
	handlers = handlers,
	onGranted = function(player: any, key: string, _receipt, fresh: boolean)
		if fresh then
			firePurchased(player, "Products", key)
		end
	end,
	log = log,
})

function MonetizationService.OnProduct(
	key: string,
	grant: (
		player: Player,
		data: PlayerData,
		receipt: { [string]: any }
	) -> boolean?,
	afterSaved: ((
		player: Player,
		receipt: { [string]: any },
		fresh: boolean
	) -> ())?
)
	assert(
		MonetizationConfig.Products[key],
		`Unknown product "{key}" (add it to MonetizationConfig.Products)`
	)
	local after = afterSaved
	handlers[key] = {
		grant = grant :: any,
		afterSaved = if after
			then function(player: any, receipt: { [string]: any }, fresh: boolean)
				task.spawn(after, player, receipt, fresh)
			end
			else nil,
	}
end

local function noPasses(): boolean
	return Effects.devNoPasses(RunService:IsStudio(), workspace:GetAttribute("DevNoPasses"))
end

local function grantPass(player: Player, key: string, isNewPurchase: boolean)
	local owned = ownedPasses[player]
	if not owned or owned[key] or MonetizationConfig.GamePasses[key].ready == false then
		return -- a retired pass (ready = false) is never owned, even if bought back when it sold
	end
	if noPasses() and not isNewPurchase then
		return -- DevNoPasses: the account's real passes stay unowned; a (test) purchase still grants
	end
	owned[key] = true
	player:SetAttribute("Pass_" .. key, true)
	local callbacks = passCallbacks[key]
	if callbacks then
		for _, callback in callbacks do
			task.spawn(callback, player, isNewPurchase)
		end
	end
	if isNewPurchase then
		firePurchased(player, "GamePasses", key)
	end
end

function MonetizationService.OnPassOwned(key: string, callback: (Player, boolean) -> ())
	assert(
		MonetizationConfig.GamePasses[key],
		`Unknown game pass "{key}" (add it to MonetizationConfig.GamePasses)`
	)
	local list = passCallbacks[key] or {}
	passCallbacks[key] = list
	table.insert(list, callback)
	for player, owned in ownedPasses do
		if owned[key] then
			task.spawn(callback, player, false)
		end
	end
end

local function shopOf(data: PlayerData?): Effects.Shop?
	local shop = data and data.flags.shop
	return if type(shop) == "table" then shop else nil
end

function MonetizationService.OwnsPass(player: Player, key: string): boolean
	local owned = ownedPasses[player]
	return Effects.passActive(
		owned ~= nil and owned[key] == true,
		if noPasses() then 0 else Effects.dayPassEnds(shopOf(DataService.Get(player)), key),
		os.time()
	)
end

local function publishDayPasses(player: Player, data: PlayerData)
	for _, item in MonetizationConfig.Products do
		local passKey = item.dayPassFor
		if passKey then
			local ends = if noPasses() then 0 else Effects.dayPassEnds(shopOf(data), passKey)
			player:SetAttribute("DayPass_" .. passKey, if ends > os.time() then ends else nil)
		end
	end
end

function MonetizationService.PassesChecked(player: Player): boolean
	return passesChecked[player] == true
end

function MonetizationService.WaitForPasses(player: Player, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 10)
	while player.Parent and not passesChecked[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	return passesChecked[player] == true
end

function MonetizationService.GetPolicy(player: Player): Policy?
	return policies[player]
end

function MonetizationService.GetCatalogue(player: Player): { CatalogueEntry }
	local entries: { CatalogueEntry } = {}
	for _, kind: Kind in { "GamePasses" :: Kind, "Products" :: Kind } do
		for key, item in (MonetizationConfig :: any)[kind] do
			if Core.isOffered(item, policies[player] :: any) then
				table.insert(entries, {
					kind = kind,
					key = key,
					id = item.id,
					name = item.name,
					order = item.order,
					owned = if kind
							== "GamePasses" -- bought for good (a day pass is not "owned")
						then ownedPasses[player] ~= nil and ownedPasses[player][key] == true
						else nil,
				})
			end
		end
	end
	table.sort(entries, function(a: CatalogueEntry, b: CatalogueEntry)
		if a.kind ~= b.kind then
			return a.kind < b.kind
		end
		return a.order < b.order
	end)
	return entries
end

-- devBoard: DevService on a live server (it checks DevConfig): in memory only, no purchase event.
function MonetizationService.SetPassOwnedForTesting(player: Player, key: string, devBoard: boolean?)
	assert(RunService:IsStudio() or devBoard == true, "SetPassOwnedForTesting is Studio only")
	assert(MonetizationConfig.GamePasses[key], `Unknown game pass "{key}"`)
	grantPass(player, key, devBoard ~= true)
end

local function checkPasses(player: Player)
	if ownedPasses[player] then
		return
	end
	ownedPasses[player] = {}
	passesChecked[player] = false
	local pending = 0
	local function done()
		pending -= 1
		if pending == 0 and passesChecked[player] ~= nil then
			passesChecked[player] = true
			player:SetAttribute("PassesChecked", true)
		end
	end
	for key, item in MonetizationConfig.GamePasses do
		if item.id == 0 or item.ready == false then
			continue
		end
		if RunService:IsStudio() and key == "StarterKit" then
			-- The dev's account owns the game's own passes: auto-granting the Starter Kit would
			-- put its 3,000 Cash on every fresh Studio profile. Test it with SetPassOwnedForTesting.
			continue
		end
		pending += 1
		task.spawn(function()
			for attempt = 1, PASS_CHECK_ATTEMPTS do
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.id)
				end)
				if ok then
					if owns and player.Parent then
						grantPass(player, key, false)
					end
					break
				end
				log(`pass check {key} for {player.Name} failed (attempt {attempt}): {owns}`)
				task.wait(2 * attempt)
			end
			done()
		end)
	end
	if pending == 0 then
		passesChecked[player] = true
		player:SetAttribute("PassesChecked", true)
	end
end

local function checkPolicy(player: Player)
	for attempt = 1, POLICY_ATTEMPTS do
		local ok, result = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(result) == "table" then
			if player.Parent then
				policies[player] = result
				player:SetAttribute("PolicyRead", true) -- clients re-read the catalogue (the wheel's spin packs)
			end
			return
		end
		log(`policy check for {player.Name} failed (attempt {attempt}): {result}`)
		task.wait(2 * attempt)
	end
	-- left nil: paid random items stay hidden for this player (docs/04 section 8)
end

local function onPlayerAdded(player: Player)
	task.spawn(checkPolicy, player)
	checkPasses(player)
end

local function getOrCreate(netFolder: Instance, name: string, className: string): Instance
	local existing = netFolder:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = netFolder
	return created
end

function MonetizationService.Init()
	for _, problem in Core.validate(MonetizationConfig) do
		log(`config: {problem}`)
	end
	local netFolder = Net.init()
	purchasedRemote = getOrCreate(netFolder, "Monetization_Purchased", "RemoteEvent") :: RemoteEvent
	local catalogue =
		getOrCreate(netFolder, "Monetization_GetCatalogue", "RemoteFunction") :: RemoteFunction
	catalogue.OnServerInvoke = function(player: Player)
		return MonetizationService.GetCatalogue(player)
	end
	for key, item in MonetizationConfig.Products do
		local passKey, hours = item.dayPassFor, item.dayPassHours
		if passKey and hours and item.ready ~= false then
			assert(MonetizationConfig.GamePasses[passKey], `{key}: unknown dayPassFor "{passKey}"`)
			MonetizationService.OnProduct(key, function(_player, data)
				local shop = shopOf(data) or {}
				data.flags.shop = shop
				Effects.addDayPass(shop, passKey, hours, os.time())
				return true
			end, function(player)
				local data = DataService.Get(player)
				if data then
					publishDayPasses(player, data)
				end
			end)
		end
	end
	DataService.OnLoaded(publishDayPasses)
end

function MonetizationService.Start()
	-- Set here, after every service's Init has registered its OnProduct handlers.
	MarketplaceService.ProcessReceipt = function(receipt: any): Enum.ProductPurchaseDecision
		return if processReceipt(receipt) == "PurchaseGranted"
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local key = index.passKeyById[passId]
			if key then
				Telemetry.RobuxPrompt(player, "GamePasses", key, purchased)
			end
			if purchased and key and player.Parent then
				grantPass(player, key, true)
			end
		end
	)
	-- analytics only: the grant stays in ProcessReceipt
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, purchased: boolean)
			local player = Players:GetPlayerByUserId(userId)
			local key = index.productKeyById[productId]
			if player and key then
				Telemetry.RobuxPrompt(player, "Products", key, purchased)
			end
		end
	)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		ownedPasses[player] = nil
		passesChecked[player] = nil
		policies[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	-- DevNoPasses flipped mid-session (smoke.py lua): drop or re-check every player's passes
	workspace:GetAttributeChangedSignal("DevNoPasses"):Connect(function()
		for _, player in Players:GetPlayers() do
			for key in MonetizationConfig.GamePasses do
				player:SetAttribute("Pass_" .. key, nil)
			end
			ownedPasses[player] = nil
			checkPasses(player)
			local data = DataService.Get(player)
			if data then
				publishDayPasses(player, data)
			end
		end
	end)
end

return MonetizationService
