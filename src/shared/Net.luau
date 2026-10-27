--!strict
-- Net: every remote in the game, declared up front.
--
-- The server calls Net.init() once (server Main does this before any service runs), which creates
-- every remote below under ReplicatedStorage.Net. Clients call Net.init() too (client Main does
-- it), which waits for that folder. Then anyone gets a remote with a typed name:
--
--   Net.event("DogPoint"):FireClient(player, payload)        -- server
--   Net.event("CrewLeave").OnServerEvent:Connect(fn)         -- server
--   Net.func("BuyGear"):InvokeServer("RIB")                  -- client
--
-- Names are string-literal types, so a typo is a luau-lsp error. To add a remote, add its name to
-- EVENTS/FUNCTIONS and to the matching type below (this is the one shared file you must edit).
--
-- Direction and payload (S = server, C = client; payload shapes are owned by the service that fires):
--   VehicleSpawned     S->C  a vehicle was launched from a bay (vehicle model, bay name)
--   CrewJoin           C->S  join a crew / invite accept (S->C echoes crew changes)
--   CrewLeave          C->S  leave the crew (S->C echoes)
--   PlayerDataChanged  S->C  the player's progression snapshot (cash, people rescued, island buildings, vehicles)
--   StormChanged       S->C  one-shot cue when the storm phase changes (siren). The
--                            continuous storm state is NOT sent by remote: it lives in attributes on
--                            ReplicatedStorage.Weather (State, StateStartTime, Intensity,
--                            WindDirection, StormId), so late joiners read it without catch-up.
--   DogPoint           S->C  Bosun points/barks toward a victim (direction or position)
--   Dock_Finish        C->S  finish the running build now (the server prompts the tier by time left)
--   BoardLaunch        C->S  launch a craft from your own craft board (board name, vehicleId; server/Dock/BoatBoard)
--   RequestVehicle     C->S  function: launch a vehicle at a bay (vehicleId, docked?) -> (ok, reasonOrVehicle)
--   BuyGear            C->S  function: buy a vehicle (vehicleId) -> (ok, reason)
--   Spin_Flex          S->C  a Legendary / Mythic wheel win: banner + confetti for everyone
--   Skill_State        S->C  the player's bought skill nodes and Medals (on join and after a buy)
--   Skill_Buy          C->S  function: buy a skill node (id) -> ok, reason
--   Skill_Reset        C->S  function: free reset, refunds every Medal -> ok, refunded
--   Spin_Wheel         S->C  a physical wheel spin: { userId, plot, segment, startTime, duration, prize... }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type EventName =
	"VehicleSpawned"
	| "CrewJoin"
	| "CrewLeave"
	| "PlayerDataChanged"
	| "StormChanged"
	| "DogPoint"
	| "Dock_Finish"
	| "BoardLaunch"
	| "Spin_Flex"
	| "Skill_State"
	| "Spin_Wheel"

export type FunctionName = "RequestVehicle" | "BuyGear" | "Skill_Buy" | "Skill_Reset"

local FOLDER_NAME = "Net"
local WAIT_TIMEOUT = 30

local Net = {}

Net.EVENTS = table.freeze({
	"VehicleSpawned",
	"CrewJoin",
	"CrewLeave",
	"PlayerDataChanged",
	"StormChanged",
	"DogPoint",
	"Dock_Finish",
	"BoardLaunch",
	"Spin_Flex",
	"Skill_State",
	"Spin_Wheel",
} :: { EventName })

Net.FUNCTIONS =
	table.freeze({ "RequestVehicle", "BuyGear", "Skill_Buy", "Skill_Reset" } :: { FunctionName })

local folder: Folder? = nil

local function create(parent: Instance, className: string, name: string)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, `Net.{name} exists as {existing.ClassName}`)
		return
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
end

-- Server: creates ReplicatedStorage.Net and every remote. Client: waits for the folder.
function Net.init(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
		if not f then
			local created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			f = created
		end
		assert(f, "unreachable")
		for _, name in Net.EVENTS do
			create(f, "RemoteEvent", name)
		end
		for _, name in Net.FUNCTIONS do
			create(f, "RemoteFunction", name)
		end
		f.Parent = ReplicatedStorage
		folder = f
		return f
	end
	local f = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	assert(f and f:IsA("Folder"), "Timed out waiting for ReplicatedStorage.Net")
	folder = f
	return f
end

local function get(name: string, className: string): Instance
	local f = Net.init()
	local remote = f:FindFirstChild(name) or f:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote, `Timed out waiting for remote Net.{name}`)
	assert(remote.ClassName == className, `Net.{name} is a {remote.ClassName}, not {className}`)
	return remote
end

function Net.event(name: EventName): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: FunctionName): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return Net
