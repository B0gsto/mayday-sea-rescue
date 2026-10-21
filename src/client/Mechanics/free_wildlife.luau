--!strict
-- free_wildlife: hold to free a tangled animal (docs/15 H4). The net, oil slick or line is the
-- Entanglement Part the server built on the animal; hold the action (mouse / A / RT / touch, or E)
-- and it fades as the hold fills. No menu, no choice: the species picks the verb (Cut / Wipe /
-- Free) and the world shows what is caught. Grade: the server measures how long it took.
local Players = game:GetService("Players")

local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local World = require(script.Parent.PIW.World)

local Mech = {}

Mech.HOLD = 4.0 -- seconds of holding to work the animal free -- tune
Mech.REACH = 16 -- studs from the animal

local function playerPos(): Vector3?
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum then
		return nil
	end
	local seat = hum.SeatPart
	local node: Instance? = seat
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node:GetPivot().Position
		end
		node = node.Parent
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

function Mech.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "Free", 130)
	if Step.autoStub(s, { freed = 1 }) then
		return Step.cleanup(s)
	end

	local victim = World.victim(ctx)
	local verb = "Cut"
	if victim then
		verb = tostring(victim:GetAttribute("WildlifeVerb") or "Cut")
	end
	local meter = Ui.meter(s.panel, verb, UDim2.fromOffset(12, 62), 436)
	local status = Ui.text(s.panel, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 102), 15)
	status.TextColor3 = Ui.Theme.Colors.textDim
	local entanglement: BasePart? = nil
	local progress = 0
	local holding = false
	local lastFar = -math.huge

	local function findEntanglement(): BasePart?
		if entanglement and entanglement.Parent then
			return entanglement
		end
		if not victim or not victim.Parent then
			victim = World.victim(ctx)
		end
		local found = victim and victim:FindFirstChild("Entanglement", true)
		entanglement = if found and found:IsA("BasePart") then found else nil
		return entanglement
	end

	local function inReach(): boolean
		local at = playerPos()
		if not at then
			return false
		end
		return (World.casualtyPos(ctx, victim) - at).Magnitude <= Mech.REACH
	end

	local function begin()
		if not inReach() then
			local now = os.clock()
			if now - lastFar > 2 then
				lastFar = now
				s.say("Come closer", 1.5)
			end
			return
		end
		holding = true
		Ui.hands("grip_sponson")
	end

	local function stop()
		holding = false
		Ui.handsStop()
	end

	Ui.action(s.bag, s.gui, verb, begin, stop)
	Ui.bind(s.bag, "FreeKey", function(state)
		if state == "Begin" then
			begin()
		elseif state == "End" then
			stop()
		end
	end, Enum.KeyCode.E)
	Ui.add(s.bag, function()
		Ui.handsStop()
	end)

	Step.heartbeat(s, function(dt)
		local part = findEntanglement()
		if part then
			-- a gentle pulse on the net while the player has not started
			if progress <= 0 and not holding then
				part.Transparency = 0.3 + math.sin(os.clock() * 3) * 0.12
			end
		end
		if holding then
			if not inReach() then
				holding = false
				Ui.handsStop()
			else
				progress = math.min(1, progress + dt / Mech.HOLD)
				if part then
					part.Transparency = math.min(1, 0.3 + progress * 0.7)
				end
				meter(progress)
				if progress >= 1 then
					if part then
						part.Transparency = 1
					end
					Step.finish(s, { metrics = { freed = 1 } })
				end
			end
		end
	end)
	return Step.cleanup(s)
end

return Mech
