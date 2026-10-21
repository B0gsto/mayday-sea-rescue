--!strict
-- handover (docs 09 step 10, section 5.8): walk the casualty to the ambulance (the nearest
-- AmbulanceHandover point, else a greybox ambulance beside you) and the crew reads the ATMIST
-- record aloud as subtitles: Age, Time, Mechanism, Injuries, Signs, Treatment, the truth from
-- what this crew saw and did (PIW/Record). After 10 s the paramedic comes to you.
-- No player metric; the server times it (elapsed).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Medical = require(script.Parent.PIW.Medical)
local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)

local Handover = {}

Handover.REACH = 10 -- studs from the rear doors
Handover.FAR = 150 -- an ambulance further than this is not this handover's
Handover.IDLE = 10 -- s before the paramedic walks over
Handover.LINE = 2.6 -- s per ATMIST line

local function rootPart(): BasePart?
	local char = Players.LocalPlayer.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- The rear doors of the nearest tagged ambulance, else a code-built one 25 studs ahead.
local function doors(s: Step.S, from: CFrame): Vector3
	local best, bestD = nil, Handover.FAR
	for _, m in CollectionService:GetTagged("AmbulanceHandover") do
		local a = m:FindFirstChild("HandoverPoint", true)
		if a and a:IsA("Attachment") then
			local d = (a.WorldPosition - from.Position).Magnitude
			if d < bestD then
				best, bestD = a.WorldPosition, d
			end
		end
	end
	if best then
		return best
	end
	local van = Instance.new("Part")
	van.Anchored = true
	van.Size = Vector3.new(7, 8, 16)
	van.Color = Color3.fromRGB(235, 235, 225)
	van.Material = Enum.Material.SmoothPlastic
	van.CFrame = from * CFrame.new(0, 1, -25 - 8)
	van.Parent = Workspace
	Ui.add(s.bag, van)
	return (van.CFrame * CFrame.new(0, -3, 8 + 3)).Position
end

function Handover.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "Handover")
	if Step.autoStub(s) then
		return Step.cleanup(s)
	end
	local e = Record.get(ctx.operation.id)
	local lines = Medical.atmist(Record.profile(ctx), {
		applied = e.applied,
		minutesOnScene = (os.clock() - e.startedAt) / 60,
	})
	local root = rootPart()
	local from = if root then root.CFrame else CFrame.new()
	local target = doors(s, from)
	-- a blue beacon over the rear doors
	local beacon = Instance.new("Part")
	beacon.Anchored, beacon.CanCollide, beacon.CanQuery = true, false, false
	beacon.Shape = Enum.PartType.Ball
	beacon.Size = Vector3.one * 1.2
	beacon.Color = Color3.fromRGB(60, 120, 255)
	beacon.Material = Enum.Material.Neon
	beacon.Position = target + Vector3.new(0, 6, 0)
	beacon.Parent = Workspace
	Ui.add(s.bag, beacon)
	local status = Step.line(s, "")
	Ui.hands("handover")

	local reading = false
	local t0 = os.clock()
	Step.heartbeat(s, function()
		beacon.Transparency = if (os.clock() * 2) % 1 < 0.5 then 0 else 0.7
		local r = rootPart()
		if
			reading
			or not (
				os.clock() - t0 > Handover.IDLE
				or (r and (r.Position - target).Magnitude < Handover.REACH)
			)
		then
			return
		end
		reading = true
		for i, l in lines do
			Ui.add(
				s.bag,
				task.delay((i - 1) * Handover.LINE, function()
					status.Text = `{l.letter} · {l.title}`
					s.say(`Crew: "{l.text}"`, Handover.LINE)
				end)
			)
		end
		Ui.add(
			s.bag,
			task.delay(#lines * Handover.LINE, s.say, '"Thanks, crew. We\'ve got them."', 3)
		)
		Ui.add(s.bag, task.delay(#lines * Handover.LINE + 2, Step.finish, s, { metrics = {} }))
	end)
	return Step.cleanup(s)
end

return Handover
