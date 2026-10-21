--!strict
-- Telemetry (client, G64): the three first-session facts only the client knows (the reward burst
-- played, the station beacon reached, photo mode opened). Everything else is logged on the server;
-- this thin module only forwards a fixed name to TelemetryService over Telemetry_Client, once each.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Telemetry = {}

local sent: { [string]: boolean } = {}

function Telemetry.once(name: string)
	if sent[name] then
		return
	end
	sent[name] = true
	local ok, folder = pcall(Net.init)
	if not ok or not folder then
		return
	end
	local remote = (folder :: Folder):WaitForChild("Telemetry_Client", 10)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(name)
	end
end

return Telemetry
