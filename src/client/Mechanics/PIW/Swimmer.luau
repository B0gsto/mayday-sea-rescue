--!strict
-- PIW/Swimmer: the rescue swimmer's contact with a casualty (docs 09 sections 5.3, 5.4).
-- Swim out, stop at arm's length, work round behind them, present the rescue tube (never your
-- body) and talk calmly in the lulls of their splashing. A panicking casualty in reach grabs:
-- flick away to duck free and reset. Readability comes from the splashing itself (local spray on
-- the casualty) and their voice; Assist adds a small panic meter.
-- Controls: W/S closer/back, A/D round them (left stick, or the touch arrows); hold Action
-- (left click / A / RT / the Action button) to present the tube; Talk (T / X / the button) cycles
-- the calm lines; flick away: S, stick down, or the Away button.
local UserInputService = game:GetService("UserInputService")

local Care = require(script.Parent.Care)
local InputGlyph =
	require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("InputGlyph"))
local Panic = require(script.Parent.Panic)
local Step = require(script.Parent.Step)
local Ui = require(script.Parent.Ui)

local Swimmer = {}

Swimmer.SWIM_SPEED = 4 -- studs/s, a strong rescue swim
Swimmer.CIRCLE_SPEED = 45 -- deg/s round them
Swimmer.FLICK_WINDOW = 2

export type Result = { seconds: number, grabs: number, fromBehind: boolean }

local WORDS = { '"I\'ve got you."', '"Grab the float."', '"Lie back, I\'ve got you."' }

function Swimmer.contact(
	s: Step.S,
	victim: Model?,
	startPanic: number,
	seed: number,
	done: (Result) -> ()
)
	local bag = Ui.bag()
	Ui.add(s.bag, function()
		Ui.clean(bag)
	end)
	local p = Panic.new(seed, s.assist, startPanic)
	local r = Panic.ARM * 3.2 -- start three body lengths off, in front of them
	local angle = 10
	local move = Vector2.zero
	local keys: { [Enum.KeyCode]: boolean } = {}
	local grabbedAt: number? = nil
	local grabs = 0
	local t0 = os.clock()
	local finished = false
	Ui.hands("swim_out")

	local frame = Ui.panel(s.gui, UDim2.fromOffset(460, 150), UDim2.new(0.5, 0, 1, -24))
	Ui.add(bag, frame)
	local rangeLine =
		Ui.text(frame, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 8), 18, true)
	local cueLine = Ui.text(frame, "", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 32), 16)
	local setPanic = Ui.meter(frame, "Panic", UDim2.fromOffset(12, 56), 200)
	local panicVisible = s.assist
	for _, d in frame:GetChildren() do
		if d:IsA("Frame") and not panicVisible then
			d.Visible = false
		end
	end

	-- local spray on the casualty while they splash (the real cue)
	local spray, sprayPer = Care.spray(bag, victim)

	local function say(i: number)
		if finished or grabbedAt then
			return
		end
		local lull = Panic.say(p, os.clock() - t0)
		s.say(WORDS[i], 1.6)
		Ui.hands("talk_calm")
		if not lull then
			cueLine.Text = "Too loud"
		end
	end
	local function flick()
		if grabbedAt then
			grabbedAt = nil
			r = Panic.ARM * 2
			Ui.hands("duck_free")
			s.say("Ducked free!")
		end
	end

	-- one Talk action (no word picker, CLAUDE.md): cycles the calm lines; timing in a lull is the skill
	local nextWord = 0
	local function talk()
		nextWord = nextWord % #WORDS + 1
		say(nextWord)
	end
	Ui.button(
		frame,
		`Talk {InputGlyph.text(Enum.KeyCode.T, Enum.KeyCode.ButtonX)}`,
		UDim2.fromOffset(140, 44),
		UDim2.fromOffset(12, 100),
		talk
	)
	Ui.bind(bag, "SwimTalk", function(state)
		if state == "Begin" then
			talk()
		end
	end, Enum.KeyCode.T, Enum.KeyCode.ButtonX)
	-- movement
	Ui.bind(bag, "SwimMove", function(state, input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			move = Vector2.new(input.Position.X, input.Position.Y)
			if grabbedAt and input.Position.Y < -0.6 then
				flick()
			end
			return
		end
		keys[input.KeyCode] = state == "Begin"
			or (state == "Change" and keys[input.KeyCode] == true)
		if state == "Begin" and input.KeyCode == Enum.KeyCode.S then
			flick()
		end
	end, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Thumbstick1)
	-- tube
	Ui.action(bag, s.gui, "Tube", function()
		p.tubeOut = true
		Ui.hands("present_tube")
	end, function()
		p.tubeOut = false
	end)
	-- touch arrows
	if Ui.isTouch() then
		local function arrow(text: string, pos: UDim2, key: Enum.KeyCode)
			local b = Ui.button(s.gui, text, UDim2.fromOffset(64, 64), pos, function() end)
			Ui.add(bag, b)
			b.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch then
					keys[key] = true
					if key == Enum.KeyCode.S then
						flick()
					end
				end
			end)
			b.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch then
					keys[key] = false
				end
			end)
		end
		arrow("Closer", UDim2.new(0, 96, 1, -330), Enum.KeyCode.W)
		arrow("Away", UDim2.new(0, 96, 1, -196), Enum.KeyCode.S)
		arrow("Left", UDim2.new(0, 28, 1, -263), Enum.KeyCode.A)
		arrow("Right", UDim2.new(0, 164, 1, -263), Enum.KeyCode.D)
	end

	Step.heartbeat(s, function(dt)
		if finished then
			return
		end
		local t = os.clock() - t0
		local fwd = (if keys[Enum.KeyCode.W] then 1 else 0)
			- (if keys[Enum.KeyCode.S] then 1 else 0)
			+ move.Y
		local side = (if keys[Enum.KeyCode.D] then 1 else 0)
			- (if keys[Enum.KeyCode.A] then 1 else 0)
			+ move.X
		fwd, side = math.clamp(fwd, -1, 1), math.clamp(side, -1, 1)
		local lull = Panic.isLull(p, t)
		if spray then
			spray.Rate = if lull or p.level < Panic.ACCEPT then 0 else sprayPer * p.level / 100
		end
		if grabbedAt then
			cueLine.Text = "Grabbed! Flick away"
			if t - grabbedAt > Swimmer.FLICK_WINDOW then
				flick()
			end
			return
		end
		local rushing = fwd > 0.3 and r < Panic.ARM * 2 and p.level > Panic.GRAB_ABOVE
		Panic.step(p, dt, rushing)
		r = math.clamp(r - fwd * Swimmer.SWIM_SPEED * dt, Panic.ARM * 0.4, Panic.ARM * 4)
		if r < Panic.ARM * 2.5 then
			angle = math.clamp(angle + side * Swimmer.CIRCLE_SPEED * dt, 0, 180)
		end
		if Panic.grabs(p, r, angle) then
			grabs += 1
			grabbedAt = t
			Ui.hands("grabbed")
			return
		end
		setPanic(p.level / 100, 0, Panic.ACCEPT / 100)
		rangeLine.Text = string.format("%.1f lengths", r / Panic.ARM)
			.. (
				if angle >= Panic.BEHIND
					then "  Behind"
					elseif angle > 60 then "  Side"
					else "  Front"
			)
		cueLine.Text = if p.level < Panic.ACCEPT
			then "Calmer"
			elseif lull then "Lull: talk"
			else "Panicking"
		if Panic.accepts(p, r) then
			finished = true
			Ui.hands("clip_tube")
			s.say("Clipped on!", 2.5)
			Ui.clean(bag)
			done({ seconds = t, grabs = grabs, fromBehind = angle >= Panic.BEHIND })
		end
	end)
	Ui.add(
		bag,
		UserInputService.TouchSwipe:Connect(function(direction)
			if direction == Enum.SwipeDirection.Down then
				flick()
			end
		end)
	)
end

return Swimmer
