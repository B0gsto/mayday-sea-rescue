--!strict
-- auto_board (2026-10-21, user: "just get near him ... he gets on whatever you are driving"): drive up
-- to the person in the water; a boat with room within reach takes them at any speed and tilt (docs/24 A),
-- they swim the last bit (PIW_Rescue "arm": the 10 s rule) and climb aboard by themselves (the server's
-- board effect plays the climb in VehicleService.AddSurvivor). Depth comes from the situation, never from text:
--   room    a full craft (SurvivorCount = Capacity: jet ski 1, RIB 3, lifeboat 8) takes nobody: they wait
--           5 m off and wave (PiwRescue); full shows on the craft's seat pips, never on them (docs/20 rule 5)
--   hold    none for a boat; the helicopter winch and the submarine still hover slow and level for Board.HOLD
--   ring    PickupRingController draws the orange pick-up ring, sized to the reach (the helm nudge is all
--           the help it gives: no throttle cut)
-- Their outline shows white in reach, green while they climb, none with no room. Metrics: none (the server
-- times it, elapsed).
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
	local reachAdd = tonumber(Players.LocalPlayer:GetAttribute("SkillReach")) or 0
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
		ring.Enabled = room and gap <= (Board.REACH + reachAdd) * 2
		ring.OutlineColor = if held > 0 then GREEN else WHITE
		local at = h.position
		local id = craft and craft:GetAttribute("VehicleId")
		if
			CraftBoard.ready( -- the server's rule (AmbientRescueService): boats at once, heli winch, sub ring
				id,
				at,
				h.beam / 2,
				cas,
				speed,
				tilt,
				room,
				Simulator.waterHeight(at.X, at.Z, Workspace:GetServerTimeNow()),
				reachAdd
			)
		then
			held += dt
			if held >= CraftBoard.hold(id) then
				Step.finish(s, { metrics = {} })
			end
		else
			held = 0
		end
	end)
	return Step.cleanup(s)
end

return AutoBoard
