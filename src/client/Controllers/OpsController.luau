--!strict
-- OpsController: the client side of operations v2 (CONTRACT.md "Operations v2").
-- Discovers step mechanics in src/client/Mechanics/<mechanicId>.luau (Mechanics/Default when one is
-- missing), plays the one the server starts for this player (Ops_StepStart), and submits its
-- result (Ops_StepResult). The HUD (UI/OpsHud, mounted by RadioController) draws everything from
-- the signals below.
--
-- Taking a call (docs/16 K2): the pager's key or tap accepts, and so does driving at it: seated
-- at a craft's helm, moving at AUTO_SPEED or more with the course within AUTO_CONE of the call for
-- AUTO_HOLD s (shared/Calls/CallLogic.headingToward). Big calls (join) take the key only.
--
-- API for other controllers:
--   OpsController.OnOffer / OnState / OnDebrief / OnRadio / OnClosed : { Connect(self, fn) }
--   OpsController.Accept(opId)            accept a tasking (big call: join)
--   OpsController.GetState(): snapshot?   the last Ops_State
--   OpsController.GetMechanic(mechanicId) the module that would play it (Default if missing)
-- While a cinematic plays (LocalPlayer attribute CinematicPlaying) the Ops ScreenGuis are hidden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CallLogic = require(Shared:WaitForChild("Calls"):WaitForChild("CallLogic"))
local Remotes = require(Shared:WaitForChild("Ops"):WaitForChild("Remotes"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

type Mechanic = {
	start: (ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()) -> (() -> ())?,
}

local OpsController = {}
OpsController.Priority = 80

local AUTO_SPEED = 10 -- studs/s: really driving, not drifting at the pier
local AUTO_CONE = 35 -- degrees either side of the bearing to the call
local AUTO_HOLD = 0.75 -- s on course before it counts

local function signal()
	local list: { (any) -> () } = {}
	return {
		Connect = function(_self: any, fn: (any) -> ())
			table.insert(list, fn)
			return {
				Disconnect = function()
					local i = table.find(list, fn)
					if i then
						table.remove(list, i)
					end
				end,
			}
		end,
		Fire = function(_self: any, data: any)
			for _, fn in table.clone(list) do
				task.spawn(fn, data)
			end
		end,
	}
end

OpsController.OnOffer = signal()
OpsController.OnState = signal()
OpsController.OnDebrief = signal()
OpsController.OnRadio = signal()
OpsController.OnClosed = signal()

local player = Players.LocalPlayer
local state: { [string]: any }? = nil
local running: { key: string, opId: string, cleanup: (() -> ())? }? = nil
local mechanicsFolder: Instance? = nil
local cache: { [string]: Mechanic } = {}

---------------------------------------------------------------- mechanics

function OpsController.GetMechanic(mechanicId: string): Mechanic
	local cached = cache[mechanicId]
	if cached then
		return cached
	end
	local folder = mechanicsFolder
	local mod = folder and folder:FindFirstChild(mechanicId)
	local chosen: Mechanic? = nil
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and type(result) == "table" and type((result :: any).start) == "function" then
			chosen = result :: any
		else
			warn(`[OpsController] mechanic {mechanicId} failed to load, using the stub: {result}`)
		end
	end
	if not chosen then
		local default =
			assert(folder and folder:FindFirstChild("Default"), "Mechanics/Default missing")
		chosen = (require :: any)(default) :: Mechanic
	end
	assert(chosen, "unreachable")
	cache[mechanicId] = chosen
	return chosen
end

local function cancelRunning()
	local r = running
	running = nil
	if r and r.cleanup then
		pcall(r.cleanup)
	end
end

local function onStepStart(ctx: { [string]: any })
	cancelRunning()
	local key: string = ctx.step.key
	local opId: string = ctx.operation.id
	local entry = { key = key, opId = opId, cleanup = nil :: (() -> ())? }
	running = entry
	local sent = false
	local function finish(result: { [string]: any })
		if sent or running ~= entry then
			return
		end
		sent = true
		running = nil
		Remotes.event("Ops_StepResult"):FireServer(opId, key, result)
	end
	local mechanic = OpsController.GetMechanic(ctx.step.mechanicId)
	local ok, cleanup = pcall(mechanic.start, ctx, finish)
	if not ok then
		warn(`[OpsController] mechanic {ctx.step.mechanicId} errored: {cleanup}`)
		finish({ metrics = {}, failed = true })
		return
	end
	if running == entry then
		entry.cleanup = cleanup
	end
end

---------------------------------------------------------------- taking a call

local pending: { opId: string, position: Vector3 }? = nil -- the solo offer driving can take
local onCourse = 0

-- The craft whose helm the player holds, or nil (on foot, a passenger, in a car).
local function helmSeat(): VehicleSeat?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat.Parent
	if not (seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" and model) then
		return nil
	end
	local id = model:GetAttribute("VehicleId")
	return if type(id) == "string" and VehicleConfig.get(id) then seat else nil
end

local function watchCourse(dt: number)
	local offer = pending
	local seat = offer and helmSeat()
	if
		offer
		and seat
		and CallLogic.headingToward(
			seat.Position,
			seat.AssemblyLinearVelocity,
			offer.position,
			AUTO_SPEED,
			AUTO_CONE
		)
	then
		onCourse += dt
		if onCourse >= AUTO_HOLD then
			OpsController.Accept(offer.opId)
		end
	else
		onCourse = 0
	end
end

---------------------------------------------------------------- API

---------------------------------------------------------------- cinematics hide the Ops UI
-- While the LocalPlayer attribute CinematicPlaying is true (Camera/Cinematic sets it), every Ops
-- ScreenGui is disabled and afterwards only the ones that were enabled (or that opened mid-shot,
-- e.g. a debrief arriving) come back. Every game ScreenGui counts (see KEEP_GUIS). HIDE_ONLY guis follow
-- held input and are never re-opened. LocalPlayer attribute OpsUiHidden mirrors the state.
local HIDE_ONLY: { [string]: boolean } = {}
type Hidden = { wanted: boolean, conn: RBXScriptConnection? }
local hidden: { [ScreenGui]: Hidden } = {}
local cinematicOn = false

-- The integration-C play test still showed a PIW mechanic panel and the HUD over the arrival
-- shot: every game ScreenGui hides during a cinematic except the cinematic's own and the
-- Studio Freecam (or one with attribute CinematicKeep = true).
local KEEP_GUIS: { [string]: boolean } = { Cinematic = true, Freecam = true }

local function isOpsGui(g: Instance): boolean
	return g:IsA("ScreenGui") and not KEEP_GUIS[g.Name] and g:GetAttribute("CinematicKeep") ~= true
end

local function hideGui(g: ScreenGui)
	if hidden[g] then
		return
	end
	local entry: Hidden = { wanted = g.Enabled and not HIDE_ONLY[g.Name], conn = nil }
	hidden[g] = entry
	g.Enabled = false
	entry.conn = g:GetPropertyChangedSignal("Enabled"):Connect(function()
		if g.Enabled and cinematicOn then
			entry.wanted = not HIDE_ONLY[g.Name] -- opened mid-shot: show it after
			g.Enabled = false
		end
	end)
end

local function restoreGuis()
	for g, entry in hidden do
		if entry.conn then
			entry.conn:Disconnect()
		end
		if g.Parent then
			g.Enabled = entry.wanted
		end
	end
	table.clear(hidden)
end

local function watchCinematics(playerGui: Instance)
	local function apply()
		local on = player:GetAttribute("CinematicPlaying") == true
		if on == cinematicOn then
			return
		end
		cinematicOn = on
		if on then
			for _, g in playerGui:GetChildren() do
				if isOpsGui(g) then
					hideGui(g :: ScreenGui)
				end
			end
		else
			restoreGuis()
		end
		player:SetAttribute("OpsUiHidden", on)
	end
	player:GetAttributeChangedSignal("CinematicPlaying"):Connect(apply)
	playerGui.ChildAdded:Connect(function(g)
		if cinematicOn and isOpsGui(g) then
			hideGui(g :: ScreenGui)
		end
	end)
	apply()
end

function OpsController.Accept(opId: string)
	if pending and pending.opId == opId then
		pending = nil
	end
	Remotes.event("Ops_Accept"):FireServer(opId)
end

function OpsController.GetState(): { [string]: any }?
	return state
end

function OpsController.Init()
	-- Space jumps a seated character out of the seat (Roblox default): hop off and swim, the seat takes
	-- you back when you swim into it. Not in the cold open, and never with a survivor riding behind you
	-- (they'd be left at sea): then Space stays in the seat and buzzes, so it never reads as broken
	-- (playtest 2026-10-24). A mechanic's own Space taps come through CAS first.
	local lastBuzz = 0
	RunService.Stepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if not (seat and humanoid.Jump) then
			return
		end
		local craft = seat.Parent
		local carrying = craft ~= nil and (tonumber(craft:GetAttribute("SurvivorCount")) or 0) > 0
		if carrying or player:GetAttribute("ColdOpenDone") ~= true then
			humanoid.Jump = false
			if os.clock() - lastBuzz > 1 then
				lastBuzz = os.clock()
				AudioController.play("UI_Fail", nil, 0.5)
			end
		end
	end)
	mechanicsFolder = script.Parent.Parent:WaitForChild("Mechanics", 10)
	RunService.Heartbeat:Connect(watchCourse)
	watchCinematics(player:WaitForChild("PlayerGui"))
	-- the rip off Haven Sands (docs/09 section 8.4): its channel shows near the beach, and a rip
	-- tasking speaks its radio line (Mechanics/Rip/View; required through any so its require of
	-- RadioController does not type as a cycle through this controller)
	local RipView = (require :: any)(
		script.Parent.Parent:WaitForChild("Mechanics"):WaitForChild("Rip"):WaitForChild("View")
	)
	RipView.start()

	Remotes.event("Ops_Offered").OnClientEvent:Connect(function(data)
		OpsController.OnOffer:Fire(data)
		if not data.isBig and typeof(data.position) == "Vector3" then
			pending = { opId = data.opId, position = data.position }
			onCourse = 0
		end
		if player:GetAttribute("OpsAutoStub") == true then
			task.delay(1, OpsController.Accept, data.opId)
		end
	end)
	Remotes.event("Ops_State").OnClientEvent:Connect(function(s)
		state = s
		RipView.sync(s)
		if pending and pending.opId == s.opId then
			pending = nil
		end
		-- the server moved on (takeover, NPC took it, another unit): drop the running mechanic
		local r = running
		if r and r.opId == s.opId then
			local still = false
			for _, c in s.current do
				still = still or (c.key == r.key and not c.npc)
			end
			if not still then
				cancelRunning()
			end
		end
		OpsController.OnState:Fire(s)
	end)
	Remotes.event("Ops_StepStart").OnClientEvent:Connect(onStepStart)
	Remotes.event("Ops_StepAck").OnClientEvent:Connect(function(ack)
		if not ack.accepted then
			warn(`[OpsController] step {ack.stepKey} not accepted: {ack.reason}`)
		end
	end)
	Remotes.event("Ops_Radio").OnClientEvent:Connect(function(r)
		OpsController.OnRadio:Fire(r)
	end)
	Remotes.event("Ops_Debrief").OnClientEvent:Connect(function(d)
		cancelRunning()
		state = nil
		OpsController.OnDebrief:Fire(d)
	end)
	Remotes.event("Ops_Closed").OnClientEvent:Connect(function(c)
		if pending and pending.opId == c.opId then
			pending = nil
		end
		-- a closed op (abandoned, expired, taken over) takes its mechanic panel with it
		if running and running.opId == c.opId then
			cancelRunning()
		end
		OpsController.OnClosed:Fire(c)
	end)
end

return OpsController
