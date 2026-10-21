--!strict
-- WinterController: the client side of the Frost Fleet seasonal event (docs/15 H7). Reads
-- ReplicatedStorage.WinterState (WinterService) plus the per-player Winter_State view, builds
-- World/WinterWorld (snow, roof frost, quay/station string lights, the decorated tree, the
-- snowflake stall with its clock and days left, and the iced-in lit boats with hold-to-break ice
-- floes) and keeps the snow off for new players (cold open + first three calls); a Studio dev
-- force skips that hold for capture. Snow scales with the graphics tier and reduce-motion.
-- The stall's world prompts call Winter_Buy; the server checks the distance and the snowflakes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))
local WinterWorld = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WinterWorld"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local SeasonalEvents = require(Shared:WaitForChild("Config"):WaitForChild("SeasonalEvents"))

-- Festive lights read well but stay inside the Halloween budget: High 24, Medium 14, Low 6.
local LIGHT_CAP = { High = 24, Medium = 14, Low = 6 }
local TICK = 0.25

local WinterController = {}
WinterController.Priority = 113 -- after EventController / HalloweenController

local folder: Folder
local state: { [string]: any } = { snowflakes = 0, owned = {} }
local world: WinterWorld.World? = nil
local worldRoot: Instance? = nil
local capLink: RBXScriptConnection? = nil

local function attr(name: string, default: any): any
	local value = folder:GetAttribute(name)
	return if value == nil then default else value
end

-- Studio art capture: the attribute may be set on this client (the command bar defaults to the
-- client while playing), so the client never refuses to dress; the server's chat "/winter" is
-- what starts the call and the money.
local function devForced(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute(SeasonalEvents.DevAttribute) == true
end

local function buy(itemId: string)
	local net = ReplicatedStorage:FindFirstChild("Net")
	local buyFn = net and net:FindFirstChild("Winter_Buy")
	if not buyFn or not buyFn:IsA("RemoteFunction") then
		return
	end
	local ok, granted = pcall(function()
		return buyFn:InvokeServer(itemId)
	end)
	AudioController.play(if ok and granted == true then "UI_Pickup" else "UI_Fail")
end

local function capLights(root: Instance)
	local left = LIGHT_CAP[OceanQuality.current().name] or LIGHT_CAP.High
	for _, d in root:GetDescendants() do
		if d:IsA("PointLight") then
			left -= 1
			if left < 0 then
				d:Destroy()
			end
		end
	end
end

local function build()
	if world then
		return
	end
	world = WinterWorld.build(Workspace, { buy = buy })
	worldRoot = Workspace:FindFirstChild("WinterWorld")
	if worldRoot then
		local root = worldRoot
		capLights(root)
		-- lights added after startup (Frost Fleet boats, late roof caps) count against the cap too
		capLink = root.DescendantAdded:Connect(function(d: Instance)
			if d:IsA("PointLight") then
				capLights(root)
			end
		end)
	end
end

local function close()
	if capLink then
		capLink:Disconnect()
		capLink = nil
	end
	if world then
		world.destroy()
		world = nil
		worldRoot = nil
	end
end

function WinterController.Init()
	OceanQuality.onChanged(function()
		if worldRoot then
			capLights(worldRoot)
		end
	end)
	folder = ReplicatedStorage:WaitForChild("WinterState")
	local net = ReplicatedStorage:WaitForChild("Net")
	local remote = net:WaitForChild("Winter_State", 30) :: RemoteEvent?
	if remote then
		remote.OnClientEvent:Connect(function(view)
			if type(view) == "table" then
				state = view
			end
		end)
	end
	local getFn = net:WaitForChild("Winter_Get", 30) :: RemoteFunction?
	if getFn then
		task.spawn(function()
			local ok, view = pcall(function()
				return getFn:InvokeServer()
			end)
			if ok and type(view) == "table" then
				state = view
			end
		end)
	end
end

function WinterController.Start()
	while true do
		local forced = devForced()
		if attr("Active", false) == true or forced then
			build()
			-- a forced Studio session is for capture: no cold-open hold on the snow
			local onboarding = not forced
				and Onboarding.newPlayerHud(
					Players.LocalPlayer:GetAttribute("ColdOpenDone") == true,
					Players.LocalPlayer:GetAttribute("OpsCompletedTotal") :: number?
				)
			if world then
				world.setSnowRate(
					OceanQuality.current().name,
					not onboarding,
					Comfort.reducedMotion()
				)
				world.update(
					Workspace:GetServerTimeNow(),
					attr("DaysLeft", 0) :: number,
					state.snowflakes or 0,
					state.owned or {},
					attr("FrostFleetOp", "") :: string
				)
			end
		else
			close()
		end
		task.wait(TICK)
	end
end

return WinterController
