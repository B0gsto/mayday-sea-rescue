--!strict
-- panic_calm (docs 09 section 5.4, Panicking casualty) as world actions (docs 14 section 2): come
-- in slow and hold position facing them; keeping still calms them on its own, the calm-hand
-- gesture (hold E / X, or press and hold on them on touch) calms faster, and with the tube within
-- their reach faster still. Rushing in, looking away or staying far off lets the panic climb;
-- inside arm's length while they panic they grab (back off to duck free). Their body shows the
-- panic: thrashing and spray slow to a wave, then treading water; no meter, no numbers. Calm and
-- in reach (or calm for a moment) they take the tube.
-- Metrics: calmSeconds, grabbed (count). Rules: Shared/Ops/CasualtyCare.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(script.Parent.PIW.Care)
local CasualtyCare = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("CasualtyCare")
)
local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local PanicCalm = {}

PanicCalm.DUCK_FREE = 2 -- s a grab holds you before you duck free

function PanicCalm.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "PanicCalm", 96, true)
	if Step.autoStub(s, { calmSeconds = 15, grabbed = 0 }) then
		return Step.cleanup(s)
	end
	s.panel.Visible = false
	local body = Care.body(ctx, s.bag)
	local victim = body.model
	local spray, sprayPer = Care.spray(s.bag, victim)
	local picker = Care.picker(s.bag, body.folder, function() end)
	picker.set("calm", function()
		return body.at("head")
	end, 1.2)

	-- their pose is local body language; if the step ends before they calm, hand it back to the
	-- server's pose (once calm, the server's own pose change follows)
	local serverPose = victim and victim:GetAttribute("CasualtyPose")
	local shownPose: string? = nil
	local calmed = false
	Ui.add(s.bag, function()
		if victim and not calmed and victim:GetAttribute("CasualtyPose") == shownPose then
			victim:SetAttribute("CasualtyPose", serverPose)
		end
	end)

	local level = CasualtyCare.START
	local grabs, calmFor = 0, 0
	local grabbedAt: number? = nil
	local clip: string? = nil
	local t0 = os.clock()

	Step.heartbeat(s, function(dt)
		local t = os.clock() - t0
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local me = if root and root:IsA("BasePart")
			then root.Position
			else World.camera().CFrame.Position
		local speed = if root and root:IsA("BasePart")
			then Units.flat(root.AssemblyLinearVelocity).Magnitude
			else 0
		local them = body.at("chest")
		local dist = Units.flatDistance(me, them)

		if grabbedAt then
			if t - grabbedAt > PanicCalm.DUCK_FREE or dist > CasualtyCare.ARM * 1.5 then
				grabbedAt = nil
				Ui.hands("duck_free")
			end
			return
		end

		-- touching them on touch counts as facing them
		local holding = picker.down() and picker.aimed() == "calm"
		local look = if holding then 0 else World.lookError(them)
		level = CasualtyCare.step(level, CasualtyCare.calmRate(dist, speed, look, holding), dt)
		local want = if holding
			then (if dist <= CasualtyCare.REACH then "present_tube" else "talk_calm")
			else nil
		if want ~= clip then
			clip = want
			if want then
				Ui.hands(want)
			end
		end
		if CasualtyCare.grabs(level, dist) then
			grabs += 1
			grabbedAt = t
			Ui.hands("grabbed")
			return
		end

		-- body language: thrashing and spray slow as they calm
		if spray then
			spray.Rate = if level < CasualtyCare.ACCEPT then 0 else sprayPer * level / 100
		end
		local pose = CasualtyCare.pose(level)
		if victim and pose ~= shownPose then
			shownPose = pose
			victim:SetAttribute("CasualtyPose", pose)
		end

		calmFor = if level < CasualtyCare.ACCEPT then calmFor + dt else 0
		if CasualtyCare.accepts(level, dist, calmFor) then
			calmed = true
			Record.get(ctx.operation.id).calmed = true
			Ui.hands("clip_tube")
			Step.finish(s, {
				metrics = { calmSeconds = math.floor(t * 10 + 0.5) / 10, grabbed = grabs },
			})
		end
	end)
	return Step.cleanup(s)
end

return PanicCalm
