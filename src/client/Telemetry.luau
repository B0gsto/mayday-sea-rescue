--!strict
-- Telemetry (client, G64): the facts only the client knows (the reward burst played, photo mode, the
-- first photo, the device, shop taps, dead input). Everything else is logged on the server; this thin
-- module only forwards a fixed name plus a few short values to TelemetryService over Telemetry_Client,
-- which checks every value against a fixed set and rate limits the remote.
--   Telemetry.once(name)                         once per session
--   Telemetry.send(name, a?, b?, c?, d?)          every time (Device, InputDead)
--   Telemetry.shop(step, app?, item?, currency?)  Shop funnel: PhoneOpened, AppOpened, ItemViewed, BuyTapped
--   Telemetry.stalled(context, stalled, dt)       per frame: InputDead once per 3 s stall (Boat, Car)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Telemetry = {}

local sent: { [string]: boolean } = {}
local stalledFor: { [string]: number } = {}

function Telemetry.send(name: string, a: string?, b: string?, c: string?, d: string?)
	task.spawn(function()
		local ok, folder = pcall(Net.init)
		if not ok or not folder then
			return
		end
		local remote = (folder :: Folder):WaitForChild("Telemetry_Client", 10)
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(name, a, b, c, d)
		end
	end)
end

function Telemetry.once(name: string)
	if sent[name] then
		return
	end
	sent[name] = true
	Telemetry.send(name)
end

-- stalled = input held but nothing moves; sends InputDead once when that lasts 3 s.
function Telemetry.stalled(context: string, stalled: boolean, dt: number)
	local t = if stalled then (stalledFor[context] or 0) + dt else 0
	stalledFor[context] = t
	if t >= 3 and t - dt < 3 then
		Telemetry.send("InputDead", context)
	end
end

function Telemetry.shop(step: string, app: string?, item: string?, currency: string?)
	Telemetry.send("Shop", step, app, item, currency)
end

return Telemetry
