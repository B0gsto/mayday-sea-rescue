--!strict
-- DataService: loads and saves each player's progression data, plus the purchase receipt ledger.
--
-- Record shape in the DataStore (key Player_<UserId>):
--   { version = RECORD_VERSION, data = PlayerData, receipts = { [purchaseId] = os.time() },
--     session = { jobId, time }? }
-- `version` is the record schema; Logic.MIGRATIONS[v] upgrades a v record to v + 1 (the PlayerData
-- fields themselves are sanitised by ProgressionRules.migrate). A record written by a newer server
-- (version > RECORD_VERSION) is never overwritten: the player is asked to rejoin.
--
-- Session lock: every write goes through UpdateAsync. Load claims the lock (waiting while another
-- live server holds it, stealing it once stale); a save only writes while this server still owns
-- the lock, otherwise the player is kicked (prevents dupes across servers). Leaving releases it.
-- Requests wait for UpdateAsync request budget, retry with jittered exponential backoff inside a
-- deadline, and report failures to the DataStoreErrors hook. Saves of one player are serialised.
-- Autosave every 60 s (also refreshes the lock); BindToClose saves everyone in parallel, capped
-- at 24 s. In Studio without API access (or any DataStore failure at startup) it uses memory.
--
-- API (server):
--   DataService.Get(player): PlayerData?          loaded data (mutate it, then MarkDirty)
--   DataService.MarkDirty(player)
--   DataService.Save(player, release: boolean?, deadline: number?): boolean   deadline is os.clock()
--   DataService.CommitReceipt(player, id: string, grantFn: (PlayerData) -> boolean?): boolean
--       Idempotent purchase grant for ProcessReceipt. If `id` (the receipt PurchaseId) is not in the
--       ledger, runs grantFn(data) (synchronous, must not yield; return false or error = not granted,
--       data is rolled back), records the id, and saves right away. Returns true only once the grant
--       and its ledger entry are committed in the same DataStore write (-> PurchaseGranted); false
--       means NotProcessedYet. A retry with the same id never grants twice; it only retries the save.
--   DataService.HasReceipt(player, id): boolean   in the ledger (committed or awaiting save)
--   DataService.OnLoaded(fn(player, data))         also calls fn for already-loaded players
--   DataService.OnDataStoreError(fn(op, key, err)): () -> ()   metric hook; returns a disconnect
--   DataService.GetDataStoreErrorCounts(): { [op]: number }   ops: load, save, release
--   DataService.IsMemoryMode(): boolean
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(Shared:WaitForChild("ProgressionRules"))

type PlayerData = Rules.PlayerData
type Session = { jobId: string, time: number }
type Ledger = { [string]: number }
export type Record = { version: number, data: any, receipts: Ledger, session: Session? }

local STORE_NAME = "PlayerData_v1"
local RECORD_VERSION = 2
local AUTOSAVE_SECONDS = 60
local LOCK_STALE_SECONDS = 180 -- a lock older than this (no autosave refresh) is abandoned
local LOAD_LOCK_WAITS = 5 -- times to wait for another server's lock before stealing it
local LOCK_WAIT_SECONDS = 5
local RETRIES = 4
local BACKOFF_BASE = 1
local BACKOFF_MAX = 8
local BUDGET_WAIT_MAX = 10 -- seconds to wait for request budget before trying anyway (queued)
local SAVE_DEADLINE = 45 -- a normal save gives up after this many seconds
local CLOSE_DEADLINE = 24 -- BindToClose: the server is killed at 30 s
local RECEIPT_LEDGER_MAX = 200 -- newest receipt ids kept on the profile

local KICK_LOCK_LOST = "Your Mayday save was opened on another server. Please rejoin."
local KICK_NEWER =
	"Your save is from a newer version of Mayday. Please rejoin to get an updated server."

-- ---------------------------------------------------------------------------------------------
-- Pure logic (tests/Data.spec.luau)

local Logic = {}
Logic.RECORD_VERSION = RECORD_VERSION
Logic.LOCK_STALE_SECONDS = LOCK_STALE_SECONDS
Logic.RECEIPT_LEDGER_MAX = RECEIPT_LEDGER_MAX

-- MIGRATIONS[v] upgrades a version-v record in place to v + 1. Never edit a shipped step; add one.
Logic.MIGRATIONS = {
	-- 1 -> 2: the purchase receipt ledger
	[1] = function(record: any)
		if type(record.receipts) ~= "table" then
			record.receipts = {}
		end
	end,
} :: { [number]: (any) -> () }

function Logic.trimLedger(ledger: Ledger, max: number?)
	local limit = max or RECEIPT_LEDGER_MAX
	local ids = {}
	for id in ledger do
		table.insert(ids, id)
	end
	if #ids <= limit then
		return
	end
	table.sort(ids, function(a, b)
		if ledger[a] ~= ledger[b] then
			return ledger[a] > ledger[b]
		end
		return a < b
	end)
	for i = limit + 1, #ids do
		ledger[ids[i]] = nil
	end
end

function Logic.cleanLedger(raw: any): Ledger
	local ledger: Ledger = {}
	if type(raw) == "table" then
		for id, at in raw do
			if
				type(id) == "string"
				and #id > 0
				and #id <= 128
				and type(at) == "number"
				and at == at
			then
				ledger[id] = at
			end
		end
	end
	Logic.trimLedger(ledger)
	return ledger
end

-- Upgrades any stored value (nil, corrupt, old) to a current record, in place when it is a table.
-- Returns the record and "ok", or the untouched record and "newer" when a newer server wrote it.
function Logic.migrateRecord(old: any): (Record, "ok" | "newer")
	local record: any = if type(old) == "table" then old else {}
	local version = if type(record.version) == "number"
		then math.max(1, math.floor(record.version))
		else 1
	if version > RECORD_VERSION then
		return record, "newer"
	end
	while version < RECORD_VERSION do
		local step = Logic.MIGRATIONS[version]
		assert(step, `DataService: no migration from record version {version}`)
		step(record)
		version += 1
	end
	record.version = version
	record.receipts = Logic.cleanLedger(record.receipts)
	if type(record.session) ~= "table" then
		record.session = nil
	end
	return record :: Record, "ok"
end

-- "free" (nobody), "ours", "live" (another server, recently refreshed) or "stale" (abandoned).
function Logic.lockState(
	session: any,
	jobId: string,
	now: number
): "free" | "ours" | "live" | "stale"
	if type(session) ~= "table" then
		return "free"
	end
	if session.jobId == jobId then
		return "ours"
	end
	if type(session.time) == "number" and now - session.time < LOCK_STALE_SECONDS then
		return "live"
	end
	return "stale"
end

-- Jittered exponential backoff after failed attempt `attempt` (1-based); `rand` is in [0, 1).
function Logic.backoffDelay(attempt: number, rand: number): number
	local base = math.min(BACKOFF_BASE * 2 ^ (attempt - 1), BACKOFF_MAX)
	return base * (0.75 + 0.5 * rand)
end

function Logic.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[k] = Logic.deepCopy(v)
	end
	return (out :: any) :: T
end

-- Restores `target` to `snapshot` in place, keeping nested table identities where both have one.
function Logic.restoreInto(target: { [any]: any }, snapshot: { [any]: any })
	for k in target do
		if snapshot[k] == nil then
			target[k] = nil
		end
	end
	for k, v in snapshot do
		if type(v) == "table" and type(target[k]) == "table" then
			Logic.restoreInto(target[k], v)
		else
			target[k] = Logic.deepCopy(v)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Dependencies (real ones set in Init; tests swap them with DataService._test.setDeps)

type Deps = {
	jobId: () -> string,
	now: () -> number,
	clock: () -> number,
	wait: (number) -> (),
	spawn: (fn: (...any) -> ...any, ...any) -> (),
	random: () -> number,
	budget: () -> number, -- UpdateAsync request budget
	warn: (...any) -> (),
}

local deps: Deps = {
	jobId = function()
		return game.JobId
	end,
	now = os.time,
	clock = os.clock,
	wait = function(seconds: number)
		task.wait(seconds)
	end,
	spawn = function(fn, ...)
		task.spawn(fn, ...)
	end,
	random = math.random,
	budget = function()
		return math.huge
	end,
	warn = warn,
} :: any

-- ---------------------------------------------------------------------------------------------
-- State

local DataService = {}
DataService.Priority = 20
DataService.Logic = Logic

local store: any = nil -- a DataStore (or a test fake)
local memoryMode = false
local memoryStore: { [string]: any } = {}
local closing = false

local loaded: { [Player]: PlayerData } = {}
local receipts: { [Player]: Ledger } = {} -- committed and pending ids
local pending: { [Player]: { [string]: boolean } } = {} -- in the ledger, not yet written
local dirty: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local released: { [Player]: boolean } = {}
local lockLost: { [Player]: boolean } = {}
local savesInFlight = 0

local loadedEvent: BindableEvent? = nil
local errorHooks: { (string, string, string) -> () } = {}
local errorCounts: { [string]: number } = {}

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function usingStore(): boolean
	return store ~= nil and not memoryMode
end

local function reportError(op: string, key: string, err: any)
	errorCounts[op] = (errorCounts[op] or 0) + 1
	local message = tostring(err)
	for _, hook in table.clone(errorHooks) do
		local ok, hookErr = pcall(hook :: any, op, key, message)
		if not ok then
			deps.warn(`[DataService] DataStoreErrors hook failed: {hookErr}`)
		end
	end
end

-- Runs one DataStore request with budget checks and jittered backoff, within `deadline` (clock).
local function request<T>(op: string, key: string, deadline: number, fn: () -> T): (boolean, T?)
	local lastErr: any = nil
	for attempt = 1, RETRIES do
		local budgetUntil = math.min(deadline, deps.clock() + BUDGET_WAIT_MAX)
		while deps.budget() < 1 and deps.clock() < budgetUntil do
			deps.wait(0.5)
		end
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		reportError(op, key, result)
		if attempt == RETRIES then
			break
		end
		local delay = Logic.backoffDelay(attempt, deps.random())
		if deps.clock() + delay > deadline then
			break
		end
		deps.wait(delay)
	end
	deps.warn(`[DataService] {op} {key} failed: {lastErr}`)
	return false, nil
end

local function kick(player: Player, message: string)
	pcall(function()
		player:Kick(message)
	end)
end

-- ---------------------------------------------------------------------------------------------
-- Load

type LoadOutcome = { status: "ok" | "locked" | "newer", record: Record? }

local function tryClaim(key: string, steal: boolean, deadline: number): (boolean, LoadOutcome?)
	return request("load", key, deadline, function(): LoadOutcome
		local outcome: LoadOutcome = { status = "ok", record = nil }
		store:UpdateAsync(key, function(old: any): any
			local record, state = Logic.migrateRecord(old)
			if state == "newer" then
				outcome.status = "newer"
				return nil
			end
			local jobId = deps.jobId()
			local now = deps.now()
			if not steal and Logic.lockState(record.session, jobId, now) == "live" then
				outcome.status = "locked"
				return nil -- abort the write
			end
			outcome.status = "ok"
			outcome.record = Logic.deepCopy(record)
			record.session = { jobId = jobId, time = now }
			return record
		end)
		return outcome
	end)
end

local function releaseLock(key: string)
	request("release", key, deps.clock() + SAVE_DEADLINE, function()
		store:UpdateAsync(key, function(old: any): any
			local record, state = Logic.migrateRecord(old)
			if
				state ~= "ok"
				or Logic.lockState(record.session, deps.jobId(), deps.now()) ~= "ours"
			then
				return nil
			end
			record.session = nil
			return record
		end)
		return true
	end)
end

-- Returns "ok" with the record, "failed" (DataStore down) or "newer".
local function loadRecord(player: Player): ("ok" | "failed" | "newer", Record?)
	local key = keyFor(player)
	if not usingStore() then
		local record, state = Logic.migrateRecord(Logic.deepCopy(memoryStore[key]))
		return if state == "ok" then "ok" else "newer", record
	end
	for waitIndex = 0, LOAD_LOCK_WAITS do
		local steal = waitIndex == LOAD_LOCK_WAITS
		local ok, outcome = tryClaim(key, steal, deps.clock() + SAVE_DEADLINE)
		if not ok or not outcome then
			return "failed", nil
		end
		if outcome.status == "ok" then
			return "ok", outcome.record
		elseif outcome.status == "newer" then
			return "newer", nil
		end
		if not player.Parent then
			return "failed", nil
		end
		deps.wait(LOCK_WAIT_SECONDS) -- another server is still saving this player (server hop)
	end
	return "failed", nil
end

local function forget(player: Player)
	loaded[player] = nil
	receipts[player] = nil
	pending[player] = nil
	dirty[player] = nil
	released[player] = nil
	lockLost[player] = nil
end

local function onPlayerAdded(player: Player)
	if loaded[player] then
		return
	end
	local status, record = loadRecord(player)
	if not player.Parent then
		if status == "ok" and usingStore() then
			releaseLock(keyFor(player)) -- left while loading: do not hold the lock for 3 minutes
		end
		return
	end
	if status == "newer" then
		deps.warn(`[DataService] {player.Name} has a newer record version; not loading`)
		kick(player, KICK_NEWER)
		return
	end
	local data: PlayerData
	if status == "ok" and record then
		data = Rules.migrate(record.data)
		receipts[player] = record.receipts
	else
		-- Play on with fresh data but never save it over a real record we could not read.
		deps.warn(`[DataService] could not load {player.Name}; using a temporary profile`)
		data = Rules.defaultData()
		receipts[player] = {}
		player:SetAttribute("DataTemporary", true)
	end
	pending[player] = {}
	loaded[player] = data
	player:SetAttribute("DataLoaded", true)
	if loadedEvent then
		loadedEvent:Fire(player, data)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Save

local function canSave(player: Player): boolean
	return loaded[player] ~= nil
		and not released[player]
		and not lockLost[player]
		and not player:GetAttribute("DataTemporary")
end

function DataService.Save(player: Player, release: boolean?, deadline: number?): boolean
	if not canSave(player) then
		return false
	end
	local until_ = deadline or (deps.clock() + SAVE_DEADLINE)
	savesInFlight += 1
	while saving[player] do -- one save per player at a time, so an older copy never lands last
		if deps.clock() >= until_ then
			savesInFlight -= 1
			return false
		end
		deps.wait(0.05)
	end
	if not canSave(player) then
		savesInFlight -= 1
		return false
	end
	saving[player] = true
	local key = keyFor(player)
	local data = loaded[player]
	local copy = Rules.migrate(data) -- a clean copy, never the live table
	copy.lastSeen = deps.now() -- offline worker earnings count from the last save (WorkerService)
	local ledger: Ledger = table.clone(receipts[player] or {})
	local committing: { [string]: boolean } = table.clone(pending[player] or {})
	dirty[player] = nil -- changes made while this save runs mark it dirty again

	local status: "ok" | "lost" | "newer" | "failed" = "failed"
	if not usingStore() then
		memoryStore[key] =
			{ version = RECORD_VERSION, data = Logic.deepCopy(copy), receipts = ledger }
		status = "ok"
	else
		local ok, result = request("save", key, until_, function(): "ok" | "lost" | "newer"
			local outcome: "ok" | "lost" | "newer" = "ok"
			store:UpdateAsync(key, function(old: any): any
				local record, state = Logic.migrateRecord(old)
				if state == "newer" then
					outcome = "newer"
					return nil
				end
				local jobId = deps.jobId()
				local now = deps.now()
				if Logic.lockState(record.session, jobId, now) ~= "ours" then
					outcome = "lost"
					return nil -- another server claimed (or released) it after we lost the lock
				end
				outcome = "ok"
				for id, at in ledger do
					record.receipts[id] = at
				end
				Logic.trimLedger(record.receipts)
				record.data = copy
				record.session = if release then nil else { jobId = jobId, time = now }
				return record
			end)
			return outcome
		end)
		if ok and result then
			status = result :: any
		end
	end
	saving[player] = nil
	savesInFlight -= 1

	if status == "ok" then
		local waiting = pending[player]
		if waiting then
			for id in committing do
				waiting[id] = nil
			end
		end
		if release then
			released[player] = true
		end
		return true
	end
	dirty[player] = true
	if status == "lost" or status == "newer" then
		lockLost[player] = true
		deps.warn(`[DataService] {key}: session lock lost ({status}); kicking {player.Name}`)
		kick(player, if status == "newer" then KICK_NEWER else KICK_LOCK_LOST)
	end
	return false
end

function DataService.CommitReceipt(
	player: Player,
	id: string,
	grantFn: (PlayerData) -> boolean?
): boolean
	if type(id) ~= "string" or id == "" or #id > 128 then
		return false
	end
	local data = loaded[player]
	local ledger = receipts[player]
	local waiting = pending[player]
	if not data or not ledger or not waiting or not canSave(player) then
		return false -- not loaded, temporary profile or leaving: Roblox retries later
	end
	if memoryMode and not game:GetService("RunService"):IsStudio() then
		return false -- a live server without DataStores: a grant would never persist, Roblox retries later
	end
	if ledger[id] == nil then
		local snapshot = Logic.deepCopy(data)
		local ok, granted = pcall(grantFn, data)
		if not ok or granted == false then
			Logic.restoreInto(data :: any, snapshot :: any)
			if not ok then
				deps.warn(`[DataService] grant for receipt {id} ({player.Name}) failed: {granted}`)
			end
			return false
		end
		ledger[id] = deps.now()
		waiting[id] = true
		Logic.trimLedger(ledger)
		ledger[id] = ledger[id] or deps.now() -- the new id always stays
		dirty[player] = true
	end
	if not waiting[id] then
		return true -- granted and committed earlier
	end
	DataService.Save(player, false) -- save right after a grant
	return pending[player] ~= nil and not pending[player][id]
end

function DataService.HasReceipt(player: Player, id: string): boolean
	local ledger = receipts[player]
	return ledger ~= nil and ledger[id] ~= nil
end

local function onPlayerRemoving(player: Player)
	if loaded[player] then
		DataService.Save(player, true)
	end
	forget(player)
end

-- Saves everyone in parallel and waits until all saves finish or `seconds` pass.
local function saveAll(seconds: number)
	closing = true
	local deadline = deps.clock() + seconds
	for player in loaded do
		if canSave(player) then
			deps.spawn(DataService.Save, player, true, deadline)
		end
	end
	while savesInFlight > 0 and deps.clock() < deadline do
		deps.wait(0.1)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Public

function DataService.Get(player: Player): PlayerData?
	return loaded[player]
end

function DataService.MarkDirty(player: Player)
	if loaded[player] then
		dirty[player] = true
	end
end

function DataService.OnLoaded(fn: (Player, PlayerData) -> ()): RBXScriptConnection
	if not loadedEvent then
		loadedEvent = Instance.new("BindableEvent")
	end
	local connection = (loadedEvent :: BindableEvent).Event:Connect(fn)
	for player, data in loaded do
		task.spawn(fn, player, data)
	end
	return connection
end

function DataService.OnDataStoreError(fn: (op: string, key: string, err: string) -> ()): () -> ()
	table.insert(errorHooks, fn)
	return function()
		local index = table.find(errorHooks, fn)
		if index then
			table.remove(errorHooks, index)
		end
	end
end

function DataService.GetDataStoreErrorCounts(): { [string]: number }
	return table.clone(errorCounts)
end

-- Test seam (tests/Data.spec.luau): fake store, clock and players. Not for game code.
DataService._test = {
	setDeps = function(overrides: { [string]: any })
		for k, v in overrides do
			(deps :: any)[k] = v
		end
	end,
	setStore = function(fake: any)
		store = fake
		memoryMode = false
	end,
	playerAdded = onPlayerAdded,
	playerRemoving = onPlayerRemoving,
	saveAll = saveAll,
	isDirty = function(player: Player): boolean
		return dirty[player] == true
	end,
	memoryRecord = function(player: Player): any
		return memoryStore[keyFor(player)]
	end,
}

function DataService.Init()
	local DataStoreService = game:GetService("DataStoreService")
	local Players = game:GetService("Players")
	if not loadedEvent then
		loadedEvent = Instance.new("BindableEvent")
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		deps.budget = function()
			return DataStoreService:GetRequestBudgetForRequestType(
				Enum.DataStoreRequestType.UpdateAsync
			)
		end
	else
		memoryMode = true
		warn(`[DataService] DataStores unavailable ({result}); using memory`)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	game:BindToClose(function()
		saveAll(CLOSE_DEADLINE)
	end)
end

function DataService.Start()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	-- Probe once: Studio without "Enable Studio Access to API Services" errors on the first request.
	if store and RunService:IsStudio() then
		local ok, err = pcall(function()
			store:GetAsync("__probe")
		end)
		if not ok then
			memoryMode = true
			warn(`[DataService] Studio has no DataStore access ({err}); using memory`)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	if RunService:IsStudio() then
		-- Studio: ServerStorage.DataDev:Invoke("rejoin") saves the first player as if leaving, loads them again
		-- through the same path and returns (before, the stored record (memory mode), after)
		local dev = Instance.new("BindableFunction")
		dev.Name = "DataDev"
		dev.OnInvoke = function(cmd: string): ...any
			local player = Players:GetPlayers()[1]
			if cmd ~= "rejoin" or not player or not loaded[player] then
				return nil
			end
			local before = Rules.migrate(loaded[player])
			onPlayerRemoving(player)
			local record = Logic.deepCopy(memoryStore[keyFor(player)])
			onPlayerAdded(player)
			return before, record, loaded[player]
		end
		dev.Parent = game:GetService("ServerStorage")
	end
	while true do
		task.wait(AUTOSAVE_SECONDS)
		if closing then
			break
		end
		-- also refreshes the session lock, so save even when clean; staggered to spread the budget
		local players = {}
		for player in loaded do
			table.insert(players, player)
		end
		local gap = math.min(1, (AUTOSAVE_SECONDS * 0.5) / math.max(1, #players))
		for _, player in players do
			if canSave(player) then
				task.spawn(DataService.Save, player, false)
				task.wait(gap)
			end
		end
	end
end

return DataService
