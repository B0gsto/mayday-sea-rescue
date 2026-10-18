--!strict
-- Monetization core logic, pure (no Roblox services) so tests/Monetization.spec.luau runs it in Lune.
-- MonetizationService wires it to MarketplaceService, PolicyService and DataService.
--
--   Core.index(config)                  id -> key maps for Products and GamePasses (id 0 skipped)
--   Core.validate(config)               list of catalogue problems ({} = fine)
--   Core.isForSale(item)                id set and ready ~= false
--   Core.isOffered(item, policy)        for sale, and paid random items only where policy allows them
--   Core.commitSucceeded(result)        normalizes whatever DataService.CommitReceipt returns
--   Core.newFallbackCommit(deps)        session-only ledger used until DataService.CommitReceipt exists
--   Core.newReceiptProcessor(deps)      the ProcessReceipt decision: "PurchaseGranted" | "NotProcessedYet"

local Core = {}

export type Item = {
	id: number,
	name: string,
	description: string,
	price: number,
	order: number,
	ready: boolean?,
	paidRandom: boolean?,
}

export type Catalogue = {
	Products: { [string]: any },
	GamePasses: { [string]: any },
}

export type Index = {
	productKeyById: { [number]: string },
	passKeyById: { [number]: string },
}

export type Policy = { ArePaidRandomItemsRestricted: boolean? }

export type Decision = "PurchaseGranted" | "NotProcessedYet"

-- grant mutates the saved data (it must not yield, and should check everything before it mutates,
-- because an error leaves the receipt unprocessed). afterSaved runs once the save holding the grant
-- and its receipt id has committed; `fresh` is false when the ledger already had the receipt (a retry
-- after a lost PurchaseGranted), so live effects can be idempotent.
export type ProductHandler = {
	grant: (player: any, data: any, receipt: { [string]: any }) -> boolean?, -- false = not granted
	afterSaved: ((player: any, receipt: { [string]: any }, fresh: boolean) -> ())?,
}

export type CommitFn = (player: any, receiptId: string, grantFn: (data: any) -> boolean?) -> any

Core.KINDS = { "Products", "GamePasses" }

function Core.index(config: Catalogue): Index
	local index: Index = { productKeyById = {}, passKeyById = {} }
	for key, item in config.Products do
		if item.id ~= 0 then
			index.productKeyById[item.id] = key
		end
	end
	for key, item in config.GamePasses do
		if item.id ~= 0 then
			index.passKeyById[item.id] = key
		end
	end
	return index
end

function Core.validate(config: Catalogue): { string }
	local problems = {}
	local ids: { [number]: string } = {}
	for _, kind in Core.KINDS do
		local section = (config :: any)[kind]
		if type(section) ~= "table" then
			table.insert(problems, `missing section {kind}`)
			continue
		end
		local names: { [string]: string } = {}
		for key, item in section do
			local where = `{kind}.{key}`
			if type(item.id) ~= "number" or item.id < 0 or item.id % 1 ~= 0 then
				table.insert(problems, `{where}: id must be a whole number >= 0`)
			elseif item.id ~= 0 then
				if ids[item.id] then
					table.insert(problems, `{where}: id {item.id} also used by {ids[item.id]}`)
				end
				ids[item.id] = where
			end
			if type(item.name) ~= "string" or #item.name == 0 or #item.name > 50 then
				table.insert(problems, `{where}: name must be 1 to 50 characters`)
			elseif names[item.name] then
				table.insert(
					problems,
					`{where}: name "{item.name}" also used by {names[item.name]}`
				)
			else
				names[item.name] = where
			end
			if
				type(item.description) ~= "string"
				or #item.description == 0
				or #item.description > 1000
			then
				table.insert(problems, `{where}: description must be 1 to 1000 characters`)
			end
			if type(item.price) ~= "number" or item.price < 1 or item.price % 1 ~= 0 then
				table.insert(problems, `{where}: price must be a whole number of Robux`)
			end
			if type(item.order) ~= "number" then
				table.insert(problems, `{where}: order must be a number`)
			end
			if item.ready ~= nil and type(item.ready) ~= "boolean" then
				table.insert(problems, `{where}: ready must be a boolean`)
			end
		end
	end
	table.sort(problems)
	return problems
end

function Core.isForSale(item: Item?): boolean
	return item ~= nil and item.id ~= 0 and item.ready ~= false
end

-- A paid random item needs a successful policy check that says they are not restricted; every other
-- item only needs to be for sale. A nil policy means the check has not finished or failed.
function Core.isOffered(item: Item?, policy: Policy?): boolean
	if not Core.isForSale(item) then
		return false
	end
	if (item :: Item).paidRandom then
		return policy ~= nil and policy.ArePaidRandomItemsRestricted == false
	end
	return true
end

local SUCCESS_WORDS = {
	["true"] = true,
	ok = true,
	granted = true,
	alreadygranted = true,
	already = true,
	committed = true,
	purchasegranted = true,
}

-- DataService.CommitReceipt (RP-D1) is specified as returning true once the receipt id is in the
-- saved ledger (granted now or before). Accept a boolean, a status string or a ProductPurchaseDecision
-- so either side can land first without a code change here; anything else counts as a failure.
function Core.commitSucceeded(result: any): boolean
	if result == true then
		return true
	end
	if type(result) == "string" then
		return SUCCESS_WORDS[string.lower(result)] == true
	end
	if type(result) == "table" then
		return result.ok == true or result.granted == true
	end
	if result ~= nil and result ~= false then
		local text = tostring(result) -- Enum.ProductPurchaseDecision.PurchaseGranted
		return string.find(text, "PurchaseGranted", 1, true) ~= nil
	end
	return false
end

export type FallbackDeps = {
	getData: (player: any) -> any?,
	isTemporary: (player: any) -> boolean,
	markDirty: (player: any) -> (),
	save: (player: any) -> boolean,
	keyOf: ((player: any) -> any)?, -- ledger key (the service uses UserId, so a rejoin keeps it)
	log: ((message: string) -> ())?,
}

-- Until DataService.CommitReceipt exists: the ledger lives for the session only (granted receipt ids
-- per player), the grant goes into the profile and is saved before we report success. A failed save
-- keeps the grant and the session ledger entry in memory (no double grant on Roblox's retry this
-- session); the next successful save carries both. Cross-session duplicates need the persisted ledger.
function Core.newFallbackCommit(deps: FallbackDeps): (CommitFn, (player: any) -> ())
	local ledger: { [any]: { [string]: boolean } } = {}
	local function commit(player: any, receiptId: string, grantFn: (data: any) -> boolean?): boolean
		local data = deps.getData(player)
		if data == nil or deps.isTemporary(player) then
			return false
		end
		local ledgerKey = if deps.keyOf then deps.keyOf(player) else player
		local seen = ledger[ledgerKey]
		if not seen then
			seen = {}
			ledger[ledgerKey] = seen
		end
		if not seen[receiptId] then
			local ok, err = pcall(function(): boolean?
				return grantFn(data)
			end)
			if not ok or err == false then
				if deps.log then
					deps.log(`grant for receipt {receiptId} failed: {err}`)
				end
				return false
			end
			seen[receiptId] = true
			deps.markDirty(player)
		end
		return deps.save(player) == true
	end
	local function forget(player: any)
		ledger[if deps.keyOf then deps.keyOf(player) else player] = nil
	end
	return commit, forget
end

export type ProcessorDeps = {
	index: Index,
	getPlayer: (userId: number) -> any?,
	waitForData: (player: any) -> boolean,
	commit: CommitFn,
	handlers: { [string]: ProductHandler },
	onGranted: ((player: any, key: string, receipt: { [string]: any }, fresh: boolean) -> ())?,
	log: ((message: string) -> ())?,
}

function Core.newReceiptProcessor(deps: ProcessorDeps): (receipt: { [string]: any }) -> Decision
	local inFlight: { [string]: boolean } = {}
	local function log(message: string)
		if deps.log then
			deps.log(message)
		end
	end
	return function(receipt: { [string]: any }): Decision
		local purchaseId = tostring(receipt.PurchaseId)
		if receipt.PurchaseId == nil or inFlight[purchaseId] then
			return "NotProcessedYet"
		end
		local key = deps.index.productKeyById[receipt.ProductId]
		local handler = if key then deps.handlers[key] else nil
		if not key or not handler then
			log(
				`no handler for product {receipt.ProductId} ({key or "unknown id"}); left unprocessed`
			)
			return "NotProcessedYet"
		end
		local player = deps.getPlayer(receipt.PlayerId)
		if not player then
			return "NotProcessedYet" -- Roblox retries when they next join
		end
		inFlight[purchaseId] = true
		local fresh = false
		local ok, result = pcall(function()
			if not deps.waitForData(player) then
				return false
			end
			return deps.commit(player, purchaseId, function(data: any): boolean?
				local granted = handler.grant(player, data, receipt)
				fresh = granted ~= false
				return granted
			end)
		end)
		inFlight[purchaseId] = nil
		if not ok then
			log(`commit for {key} receipt {purchaseId} errored: {result}`)
			return "NotProcessedYet"
		end
		if not Core.commitSucceeded(result) then
			return "NotProcessedYet"
		end
		local afterSaved = handler.afterSaved
		if afterSaved then
			local afterOk, afterErr = pcall(function()
				afterSaved(player, receipt, fresh)
			end)
			if not afterOk then
				log(`afterSaved for {key} failed: {afterErr}`) -- the save already holds the grant
			end
		end
		if deps.onGranted then
			pcall(deps.onGranted, player, key, receipt, fresh)
		end
		return "PurchaseGranted"
	end
end

return Core
