--!strict
-- DataService: loads and saves each player's progression data.
--
-- Session-safe pattern: every write goes through UpdateAsync and the record carries a session
-- lock { jobId, time }. Load claims the lock (waiting while another live server holds it, then
-- stealing a stale one); saves refuse to overwrite a record another server has claimed; leaving
-- releases it. Autosave refreshes the lock. Retries with backoff on every request.
-- In Studio without API access (or any DataStore failure at startup) it falls back to memory.
--
-- API (server):
--   DataService.Get(player): PlayerData?          loaded data (mutate it, then MarkDirty)
--   DataService.MarkDirty(player)
--   DataService.Save(player, release: boolean?)
--   DataService.OnLoaded(fn(player, data))         also calls fn for already-loaded players
--   DataService.IsMemoryMode(): boolean
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(Shared:WaitForChild("ProgressionRules"))

type PlayerData = Rules.PlayerData

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_SECONDS = 60
local LOCK_STALE_SECONDS = 180 -- a lock older than this (no autosave refresh) is abandoned
local LOAD_LOCK_WAITS = 5 -- times to wait for another server's lock before stealing it
local RETRIES = 4

local DataService = {}
DataService.Priority = 20

local store: DataStore? = nil
local memoryMode = false
local memoryStore: { [string]: any } = {}

local loaded: { [Player]: PlayerData } = {}
local dirty: { [Player]: boolean } = {}
local loadedEvent = Instance.new("BindableEvent")

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function withRetries<T>(label: string, fn: () -> T): (boolean, T?)
	local lastErr: any = nil
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(math.min(2 ^ attempt, 10))
	end
	warn(`[DataService] {label} failed after {RETRIES} tries: {lastErr}`)
	return false, nil
end

type LoadOutcome = { status: "ok" | "locked", raw: any }

-- One locked load attempt: claims the session lock unless a live server holds it.
local function tryClaim(ds: DataStore, key: string, steal: boolean): LoadOutcome
	local outcome: LoadOutcome = { status = "ok", raw = nil }
	ds:UpdateAsync(key, function(old: any)
		local record = if type(old) == "table" then old else {}
		local session = record.session
		local now = os.time()
		if
			not steal
			and type(session) == "table"
			and session.jobId ~= game.JobId
			and type(session.time) == "number"
			and now - session.time < LOCK_STALE_SECONDS
		then
			outcome.status = "locked"
			return nil -- abort the write
		end
		outcome.status = "ok"
		outcome.raw = record.data
		record.session = { jobId = game.JobId, time = now }
		record.version = record.version or 1
		return record
	end)
	return outcome
end

local function loadRaw(player: Player): (boolean, any)
	local key = keyFor(player)
	if memoryMode or not store then
		return true, memoryStore[key]
	end
	local ds = store :: DataStore
	for wait = 0, LOAD_LOCK_WAITS do
		local steal = wait == LOAD_LOCK_WAITS
		local ok, outcome = withRetries(`load {key}`, function()
			return tryClaim(ds, key, steal)
		end)
		if not ok or not outcome then
			return false, nil
		end
		if outcome.status == "ok" then
			return true, outcome.raw
		end
		if not player.Parent then
			return false, nil
		end
		task.wait(5) -- another server is still saving this player (server hop)
	end
	return false, nil
end

function DataService.Save(player: Player, release: boolean?): boolean
	local data = loaded[player]
	if not data then
		return false
	end
	local key = keyFor(player)
	local copy = Rules.migrate(data) -- a clean copy, never the live table
	if memoryMode or not store then
		memoryStore[key] = copy
		dirty[player] = nil
		return true
	end
	local ds = store :: DataStore
	local ok = withRetries(`save {key}`, function()
		ds:UpdateAsync(key, function(old: any)
			local record = if type(old) == "table" then old else {}
			local session = record.session
			if type(session) == "table" and session.jobId ~= game.JobId then
				warn(`[DataService] {key} is claimed by another server; not overwriting`)
				return nil
			end
			record.data = copy
			record.version = copy.version
			record.session = if release then nil else { jobId = game.JobId, time = os.time() }
			return record
		end)
		return true
	end)
	if ok then
		dirty[player] = nil
	end
	return ok
end

local function onPlayerAdded(player: Player)
	if loaded[player] then
		return
	end
	local ok, raw = loadRaw(player)
	if not player.Parent then
		return
	end
	local data = Rules.migrate(raw)
	if not ok then
		-- Play on with fresh data but never save it over a real record we could not read.
		warn(`[DataService] could not load {player.Name}; using a temporary profile`)
		data = Rules.defaultData()
		player:SetAttribute("DataTemporary", true)
	end
	loaded[player] = data
	player:SetAttribute("DataLoaded", true)
	loadedEvent:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	if loaded[player] and not player:GetAttribute("DataTemporary") then
		DataService.Save(player, true)
	end
	loaded[player] = nil
	dirty[player] = nil
end

function DataService.Get(player: Player): PlayerData?
	return loaded[player]
end

function DataService.MarkDirty(player: Player)
	if loaded[player] then
		dirty[player] = true
	end
end

function DataService.IsMemoryMode(): boolean
	return memoryMode
end

function DataService.OnLoaded(fn: (Player, PlayerData) -> ()): RBXScriptConnection
	local connection = loadedEvent.Event:Connect(fn)
	for player, data in loaded do
		task.spawn(fn, player, data)
	end
	return connection
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		memoryMode = true
		warn(`[DataService] DataStores unavailable ({result}); using memory`)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	game:BindToClose(function()
		local threads = 0
		for player in loaded do
			if not player:GetAttribute("DataTemporary") then
				threads += 1
				task.spawn(function()
					DataService.Save(player, true)
					threads -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while threads > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService.Start()
	-- Probe once: Studio without "Enable Studio Access to API Services" errors on the first request.
	if store and RunService:IsStudio() then
		local ds = store :: DataStore
		local ok, err = pcall(function()
			ds:GetAsync("__probe")
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
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player in loaded do
			if not player:GetAttribute("DataTemporary") then
				-- also refreshes the session lock, so save even when clean
				task.spawn(DataService.Save, player, false)
			end
		end
	end
end

return DataService
