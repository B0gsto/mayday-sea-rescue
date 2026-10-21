--!strict
-- Net: every remote in the game, declared up front.
--
-- The server calls Net.init() once (server Main does this before any service runs), which creates
-- every remote below under ReplicatedStorage.Net. Clients call Net.init() too (client Main does
-- it), which waits for that folder. Then anyone gets a remote with a typed name:
--
--   Net.event("CallOffered"):FireClient(player, call)        -- server
--   Net.event("CallAccepted").OnServerEvent:Connect(fn)      -- server
--   Net.func("BuyGear"):InvokeServer("Fins")                 -- client
--
-- Names are string-literal types, so a typo is a luau-lsp error. To add a remote, add its name to
-- EVENTS/FUNCTIONS and to the matching type below (this is the one shared file you must edit).
--
-- Direction and payload (S = server, C = client; payload shapes are owned by the service that fires):
--   CallOffered        S->C  a call card is offered to a player or crew
--   CallAccepted       C->S  player accepts an offered call (callId)
--   CallUpdated        S->C  call progress (victims found, comfort, timer)
--   CallCompleted      S->C  call delivered: grade and payout
--   CallFailed         S->C  call failed or released
--   VehicleSpawned     S->C  a vehicle was launched from a bay (vehicle model, bay name)
--   RescueAction       C->S  hold-to-pull aboard, attach/detach tow, right the boat ({action, target})
--   CrewJoin           C->S  join a crew / invite accept (S->C echoes crew changes)
--   CrewLeave          C->S  leave the crew (S->C echoes)
--   PlayerDataChanged  S->C  a changed slice of the player's saved data (cash, rep, rank, gear)
--   StormChanged       S->C  one-shot cue when the storm phase changes (siren, radio line). The
--                            continuous storm state is NOT sent by remote: it lives in attributes on
--                            ReplicatedStorage.Weather (State, StateStartTime, Intensity,
--                            WindDirection, StormId), so late joiners read it without catch-up.
--   DogPoint           S->C  Bosun points/barks toward a victim (direction or position)
--   RequestVehicle     C->S  function: launch a vehicle at a bay (vehicleId, docked?) -> (ok, reasonOrVehicle)
--   BuyGear            C->S  function: buy or upgrade gear -> (ok, reason)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type EventName =
	"CallOffered"
	| "CallAccepted"
	| "CallUpdated"
	| "CallCompleted"
	| "CallFailed"
	| "VehicleSpawned"
	| "RescueAction"
	| "CrewJoin"
	| "CrewLeave"
	| "PlayerDataChanged"
	| "StormChanged"
	| "DogPoint"

export type FunctionName = "RequestVehicle" | "BuyGear"

local FOLDER_NAME = "Net"
local WAIT_TIMEOUT = 30

local Net = {}

Net.EVENTS = table.freeze({
	"CallOffered",
	"CallAccepted",
	"CallUpdated",
	"CallCompleted",
	"CallFailed",
	"VehicleSpawned",
	"RescueAction",
	"CrewJoin",
	"CrewLeave",
	"PlayerDataChanged",
	"StormChanged",
	"DogPoint",
} :: { EventName })

Net.FUNCTIONS = table.freeze({ "RequestVehicle", "BuyGear" } :: { FunctionName })

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
