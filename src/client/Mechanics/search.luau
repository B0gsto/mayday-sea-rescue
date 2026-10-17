--!strict
-- search (docs 09 step 4, section 5.2): go to the datum corrected for drift, place the search
-- start (a dan buoy and an orange smoke float go in the water there), run the pattern, scan,
-- and once seen keep eyes on: one crew member points and never looks away. The head shows only
-- on some crests; a lifejacket strobe carries at dusk and in rain; smoke helps by day.
-- From the pattern rank the Navigator may run an expanding square from the start.
-- Metrics: startError (studs from the casualty), lostSight (count). Extra: onPattern (0..1).
-- Controls: place the start with the reticle / mouse on the water + left click (tap the water,
-- A on gamepad); lookout: hold right click (finger on them, RB) with the reticle on them.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Search = require(script.Parent.PIW.Search)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local Units = require(script.Parent.PIW.Units)
local World = require(script.Parent.PIW.World)

local Mech = {}

Mech.EYES_ON_SECONDS = 6 -- crew lookout: this long on them while the helm closes in
Mech.CLOSE = 60 -- studs: close enough for the approach
Mech.SPACING = 40 -- studs, expanding square track spacing (game value)

function Mech.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "Search", 140)
	if Step.autoStub(s, { startError = 20, lostSight = 0 }) then
		return Step.cleanup(s)
	end
	local victim = World.victim(ctx)
	local wind = ctx.scene and ctx.scene.windDirection or 0
	local datum: Vector3 = ctx.operation.position
	local seed = Units.hash01(tostring(ctx.casualty and ctx.casualty.id or ctx.operation.id), 5)
	local storm = ctx.operation.storm == true
	local lifejacket = ctx.casualty and ctx.casualty.lifejacket == true
	local env: Search.SightEnv = {
		storm = storm,
		lowLight = World.lowLight(),
		strobe = lifejacket,
		smoke = false,
	}
	if lifejacket and (storm or env.lowLight) then
		World.strobe(s.bag, victim)
	end
	local info = Step.line(s, "Place the search start down-drift of the datum.", 54)
	local sub = Step.line(s, "", 76)
	local lookout = Search.lookout()
	local startError: number? = nil
	local pattern: { Vector3 }? = nil
	local onPatternTime, patternTime = 0, 0
	local eyesHeld = false
	local touchPos: Vector2? = nil
	local solo = World.isDriver(World.vehicle(ctx))
	local rankIndex = Players.LocalPlayer:GetAttribute("RankIndex")
	local mayPattern = type(rankIndex) == "number" and rankIndex >= Search.PATTERN_RANK_INDEX

	-- Assist: the datum is pinned (a small buoy) and the drift is drawn from it
	local truePos = World.casualtyPos(ctx, victim)
	local drift = Units.flat(truePos - datum)
	if s.assist then
		World.marker(s.bag, datum, wind, false)
		if drift.Magnitude > 4 then
			World.line(
				s.bag,
				datum,
				datum + drift.Unit * math.min(drift.Magnitude * 1.2, 120),
				Color3.fromRGB(230, 230, 220),
				0.3
			)
		end
	end

	local function finishSearch()
		Step.finish(s, {
			metrics = {
				startError = startError or 160,
				lostSight = lookout.lost,
				onPattern = if patternTime > 0
					then math.floor(onPatternTime / patternTime * 100 + 0.5) / 100
					else nil,
			},
		})
	end

	local function placeStart(screen: Vector2?)
		if startError ~= nil then
			return
		end
		local waterY = World.casualtyPos(ctx, victim).Y
		local p = World.screenToWater(screen, waterY)
		if not p then
			s.say("Point at the water to drop the start marker.")
			return
		end
		startError = Search.startError(p, World.casualtyPos(ctx, victim))
		World.marker(s.bag, p, wind, true)
		env.smoke = true
		Ui.hands("drop_marker")
		s.say("Search start marked. Smoke float away.")
		if mayPattern then
			pattern = Search.expandingSquare(p, -Units.windVector(wind), Mech.SPACING, 8)
			if s.assist and pattern then
				for i = 1, #pattern - 1 do
					World.line(
						s.bag,
						pattern[i] + Vector3.new(0, waterY, 0),
						pattern[i + 1] + Vector3.new(0, waterY, 0),
						Color3.fromRGB(255, 200, 120),
						0.25
					)
				end
			end
			info.Text = "Expanding square: first leg into the wind. Lookouts, scan."
		else
			info.Text = "Lookouts: scan the water. Watch the crests."
		end
	end

	-- placing the start: click / tap / A at the reticle
	Ui.bind(s.bag, "SearchPlace", function(state, input)
		if state ~= "Begin" or startError ~= nil then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			placeStart(UserInputService:GetMouseLocation() - GuiService:GetGuiInset())
		else
			placeStart(nil)
		end
	end, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonA)
	Ui.add(
		s.bag,
		UserInputService.TouchTap:Connect(function(positions, processed)
			if not processed and startError == nil and positions[1] then
				placeStart(positions[1])
			end
		end)
	)
	-- lookout: hold right click / RB, or keep a finger on them
	Ui.bind(s.bag, "SearchEyes", function(state)
		eyesHeld = state == "Begin" or (state == "Change" and eyesHeld)
		if state == "End" then
			eyesHeld = false
		end
	end, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR1)
	Ui.add(
		s.bag,
		UserInputService.TouchStarted:Connect(function(input, processed)
			if not processed then
				touchPos = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
	)
	Ui.add(
		s.bag,
		UserInputService.TouchMoved:Connect(function(input)
			touchPos = Vector2.new(input.Position.X, input.Position.Y)
		end)
	)
	Ui.add(
		s.bag,
		UserInputService.TouchEnded:Connect(function()
			touchPos = nil
		end)
	)

	local t = 0
	local wasVisible = true
	Step.heartbeat(s, function(dt)
		t += dt
		local cas = World.casualtyPos(ctx, victim)
		local h = World.hull(World.vehicle(ctx))
		local cf = World.camera().CFrame
		local eye = if h then h.position else cf.Position
		local distance = Units.flatDistance(eye, cas)
		local visible = Search.visible(t, seed, distance, env)
		-- the swell hides their head between crests (local only; the server keeps the model)
		if victim and visible ~= wasVisible then
			wasVisible = visible
			for _, d in victim:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = if visible then 0 else 1
				end
			end
		end
		if pattern and h then
			patternTime += dt
			if Search.distanceToPath(h.position, pattern) <= Search.LEG_TOLERANCE then
				onPatternTime += dt
			end
		end
		if startError == nil then
			sub.Text = if s.assist
				then "Drift arrow from the datum shows where they've gone."
				else "Read the drift from the foam lines."
			return
		end
		local onTarget: boolean
		if touchPos then
			local sp = World.onScreen(cas)
			onTarget = sp ~= nil and (sp - touchPos).Magnitude < 70
		else
			onTarget = eyesHeld and World.lookError(cas) <= Search.ON_TARGET_DEG * 1.6
		end
		local reticleOn = World.lookError(cas) <= Search.ON_TARGET_DEG
		if not lookout.sighted then
			if visible and (reticleOn or (touchPos and onTarget)) then
				lookout.sighted = true
				Ui.hands("point")
				s.say(
					if solo
						then '"Casualty in sight! Marked."'
						else '"Casualty in sight! Keep eyes on!"',
					3
				)
				info.Text = if solo
					then "Close in. The crew keeps pointing."
					else "Keep eyes on: hold right click / RB on them."
			end
			sub.Text = `Range {math.floor(distance / Units.STUDS_PER_M)} m to search area`
			return
		end
		if solo then
			-- solo helm: you marked them, an NPC keeps pointing
			sub.Text = `{math.floor(distance / Units.STUDS_PER_M)} m`
			if distance <= Mech.CLOSE then
				finishSearch()
			end
			return
		end
		local lost = Search.keepEyesOn(
			lookout,
			dt,
			onTarget and visible or (onTarget and lookout.offFor < 1)
		)
		if lost then
			s.say('"Lost them! Where are they?"', 2)
		end
		sub.Text = `Eyes on {math.floor(lookout.onSeconds)} / {Mech.EYES_ON_SECONDS}s`
		if lookout.onSeconds >= Mech.EYES_ON_SECONDS or distance <= Mech.CLOSE then
			finishSearch()
		end
	end)
	Ui.add(s.bag, function()
		if victim then
			for _, d in victim:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
	end)
	Ui.hint(s.panel, "Both arms waving, a strobe, orange smoke: look for real signs.", s.assist)
	return Step.cleanup(s)
end

return Mech
