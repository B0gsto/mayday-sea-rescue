--!strict
-- OpsHud: wires the operation UI to OpsController's signals (CONTRACT.md "Operations v2"):
-- the tasking pager (OnOffer), the objective strip (OnState), the debrief toast (OnDebrief) and
-- closures (OnClosed). Mounted by RadioController.
-- Placement (UI/Layout): the strip in the "objective" region (top left), the pager in the "right"
-- column, the debrief a toast in the "notice" band. In the cold open both are hidden: the
-- minimap's objective pill is the one objective line. A new player (Layout.newPlayer) gets no
-- relay / big-call alert.
-- The world shows the way to a call (docs/16 K2): a red parachute flare goes up over it
-- (PyroController) and again every FLARE_EVERY s until the call is taken or withdrawn; the minimap
-- draws its blip (MapController).
local Players = game:GetService("Players")

local ColdOpenCue = require(script.Parent.ColdOpenCue)
local Layout = require(script.Parent.Layout)
local OpsDebrief = require(script.Parent.OpsDebrief)
local OpsStepCard = require(script.Parent.OpsStepCard)
local OpsTaskingCard = require(script.Parent.OpsTaskingCard)
local PyroController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("PyroController"))

local OpsHud = {}

local NEW_PLAYER_DEBRIEF = 6 -- s: the first calls' debrief stays up a little longer
local FLARE_EVERY = 25 -- s: a parachute flare burns ~40 s, so one is always in the sky
-- first station calls: the casualty keeps the cold open's world cues while you go and get them
local FIND_STEPS = { recovery = true, pickup = true }

local DEBRIEF_LINE: { [string]: string } = {
	Gold = "AGG_DEBRIEF_GOLD",
	Silver = "AGG_DEBRIEF_SILVER",
	Bronze = "AGG_DEBRIEF_BRONZE",
}

function OpsHud.mount(playerGui: Instance, ops: any, radio: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "OpsHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 16
	Layout.prepare(gui)
	gui.Parent = playerGui

	local objective = Layout.region(gui, "objective")
	local right = Layout.region(gui, "right")
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, Layout.GAP)
	stack.Parent = right

	local tasking = OpsTaskingCard.new(right)
	local step = OpsStepCard.new(objective)
	-- cold open: one objective on screen, the minimap's pill ("Drop-off 100 m"), so no step strip
	-- the world shows the goal (docs/14 F-3): dye, pulse ring, smoke and a flare at the casualty
	local stopCue: (() -> ())? = nil
	local function applyColdOpen(_: boolean?)
		local active = Layout.coldOpen()
		right.Visible = not active
		objective.Visible = not active
		if active and not stopCue then
			stopCue = ColdOpenCue.start()
		elseif not active and stopCue then
			stopCue()
			stopCue = nil
		end
	end
	Layout.onColdOpen(applyColdOpen)
	local debrief = OpsDebrief.new(Layout.region(gui, "notice"))
	local activeOp: string? = nil
	local findOp: string? = nil
	local stopFind: (() -> ())? = nil
	local function setFind(opId: string?)
		findOp = opId
		if opId and not stopFind then
			stopFind = ColdOpenCue.start(nil, function()
				return findOp
			end)
		elseif not opId and stopFind then
			stopFind()
			stopFind = nil
		end
	end

	-- the flare over the call: one now, then every FLARE_EVERY s while it stands
	local flareOp: any = nil
	local function flareOver(opId: any, at: Vector3)
		flareOp = opId
		task.spawn(function()
			while flareOp == opId do
				pcall(PyroController.parachute, at)
				task.wait(FLARE_EVERY)
			end
		end)
	end
	local function stopFlare(opId: any)
		if flareOp == opId then
			flareOp = nil
		end
	end

	local lastOfferId: any = nil
	ops.OnOffer:Connect(function(data: { [string]: any })
		-- a re-broadcast of the same offer refreshes the card only, no second radio call
		local fresh = data.opId == nil or data.opId ~= lastOfferId
		lastOfferId = data.opId
		-- a new player sees only their own call: no relay / big-call alert on top of it
		if data.isBig and Layout.newPlayer() then
			return
		end
		-- the debrief never holds up the next tasking for more than 10 seconds
		if debrief.shownFor() >= 10 then
			debrief.hide()
		end
		tasking.show(data, function(opId: string)
			tasking.hide(opId)
			ops.Accept(opId)
		end)
		if not fresh then
			return
		end
		if typeof(data.position) == "Vector3" then
			flareOver(data.opId, data.position)
		end
		if data.isBig then
			radio.sayText(
				"Gale Isles Coastguard",
				tostring(data.radioLine or ""),
				{ priority = radio.Priorities.Distress }
			)
		else
			radio.say("offer")
		end
	end)

	ops.OnState:Connect(function(s: { [string]: any })
		activeOp = s.opId
		tasking.hide(s.opId)
		stopFlare(s.opId) -- taken: the survivor's own cues take over
		step.update(s)
		local mine: { [string]: any }? = nil
		for _, c in s.current or {} do
			if c.trackId == s.myTrack then
				mine = c
			end
		end
		local finding = mine ~= nil and FIND_STEPS[mine.id] == true
		setFind(if finding and Layout.newPlayer() and not Layout.coldOpen() then s.opId else nil)
	end)

	ops.OnDebrief:Connect(function(d: { [string]: any })
		activeOp = nil
		step.hide()
		setFind(nil)
		local fresh = Layout.newPlayer()
		task.spawn(function()
			if fresh then
				-- the first reward burst lands before the toast (OnboardingController's flag)
				task.wait(0.5)
				local t0 = os.clock()
				while
					player:GetAttribute("OnboardingRewardBusy") == true and os.clock() - t0 < 45
				do
					task.wait(0.25)
				end
			end
			debrief.show(d, if fresh then NEW_PLAYER_DEBRIEF else nil)
			local id = if d.takeover then "AGG_DEBRIEF_TAKEOVER" else DEBRIEF_LINE[d.grade]
			if id then
				radio.play(
					id,
					{ priority = radio.Priorities.Advice, from = "Chief Aggie · Port Haven" }
				)
			end
		end)
	end)

	ops.OnClosed:Connect(function(c: { [string]: any })
		tasking.hide(c.opId)
		stopFlare(c.opId)
		if c.opId == activeOp then
			activeOp = nil
			step.hide()
			setFind(nil)
		end
		if c.message and not c.silent then
			radio.sayText("Gale Isles Coastguard", tostring(c.message))
		end
	end)
end

return OpsHud
