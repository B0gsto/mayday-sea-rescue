--!strict
-- auto_board (2026-10-21, user: "just get near him ... he gets on whatever you are driving"): drive up
-- to the person in the water and hold the boat close and steady; they swim the last bit (PIW_Rescue
-- "arm": the 10 s rule) and climb aboard by themselves (the server's board effect plays the climb in
-- VehicleService.AddSurvivor). Depth comes from the situation, never from text:
--   room    a full craft (SurvivorCount = Capacity: jet ski 1, RIB 3, lifeboat 8) takes nobody: they wait
--           5 m off and wave (PiwRescue); full shows on the craft's seat pips, never on them (docs/20 rule 5)
--   steady  under STEADY_SPEED and pitching / rolling under STEADY_TILT: big waves make it a skill
--   ramming coming in fast on top of them knocks them back (a "bump" event, PiwRescue pushes them off),
--           from rank KNOCK_RANK up only (docs/23 e.1)
--   ring    PickupRingController draws the orange pick-up ring and eases the craft's throttle inside it
-- Their outline shows white in reach, green while they get ready, none with no room. Metrics: none (the server times
-- it, elapsed); events: bump.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Ops"):WaitForChild("Board"))
local CraftBoard = require(Shared:WaitForChild("Ops"):WaitForChild("CraftBoard"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))

local AutoBoard = {}

local WHITE = Color3.fromRGB(240, 240, 235)
local GREEN = Color3.fromRGB(110, 230, 120)

local function remote(): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild("Net")
	local r = net and net:FindFirstChild("PIW_Rescue")
	return if r and r:IsA("RemoteEvent") then r else nil
end

function AutoBoard.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "AutoBoard")
	s.panel.Visible = false -- the objective chip says it; the world shows the rest
	if Step.autoStub(s, {}) then
		return Step.cleanup(s)
	end
	local opId = ctx.operation.id
	local index = (ctx.casualty and ctx.casualty.index) or ctx.step.casualtyIndex or 1
	local r = remote()
	if r then
		r:FireServer(opId, index, "arm") -- they swim to a stopped boat (PiwWays, the 10 s rule)
	end
	local victim: Model? = World.victim(ctx)
	local ring = Ui.add(s.bag, Instance.new("Highlight"))
	ring.FillTransparency = 1
	ring.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	local held = 0
	local bumps = 0
	local lastBump = -math.huge
	Step.heartbeat(s, function(dt)
		if not (victim and victim.Parent) then
			victim = World.victim(ctx)
			ring.Parent = nil
			if not victim then
				return
			end
		end
		local v = victim :: Model
		if ring.Parent ~= v then
			ring.Adornee = v
			ring.Parent = v
		end
		local h = World.aboardHull(ctx)
		if not h then
			ring.Enabled = false -- on foot or swimming: the boat comes first (the launch step's outline)
			held = 0
			return
		end
		local cas = World.casualtyPos(ctx, v)
		local gap = math.max(0, Units.flatDistance(h.position, cas) - h.beam / 2)
		local speed = Units.flat(h.velocity).Magnitude
		local tilt = math.deg(math.acos(math.clamp(h.cframe.UpVector.Y, -1, 1)))
		local craft = h.root:FindFirstAncestorOfClass("Model")
		local room = Board.hasRoom(craft)
		if
			Board.rammed(gap, speed, Players.LocalPlayer:GetAttribute("RankIndex"))
			and os.clock() - lastBump > Board.BUMP_GAP
		then
			lastBump = os.clock()
			bumps += 1
			held = 0
			Ui.hands("wave_off")
			if r then
				r:FireServer(opId, index, "bump")
			end
		end
		ring.Enabled = room and gap <= Board.REACH * 2
		ring.OutlineColor = if held > 0 then GREEN else WHITE
		local at = h.position
		if
			CraftBoard.ready( -- the server's rule (AmbientRescueService): heli winch, seaplane on the water
				craft and craft:GetAttribute("VehicleId"),
				at,
				h.beam / 2,
				cas,
				speed,
				tilt,
				room,
				Simulator.waterHeight(at.X, at.Z, Workspace:GetServerTimeNow())
			)
		then
			held += dt
			if held >= Board.HOLD then
				Ui.hands("reach_casualty")
				Step.finish(
					s,
					{ metrics = {}, events = if bumps > 0 then { bump = bumps } else nil }
				)
			end
		else
			held = 0
		end
	end)
	return Step.cleanup(s)
end

return AutoBoard
