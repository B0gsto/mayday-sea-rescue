--!strict
-- OpsHud: wires the operation UI to OpsController's signals (CONTRACT.md "Operations v2", stream d):
-- the tasking pager (OnOffer), the step card and casualty monitor (OnState), the debrief toast
-- (OnDebrief) and closures (OnClosed). Mounted by RadioController, which also sets
-- OpsController.UseBuiltInUi = false so the greybox UI stays hidden.
-- Placement (UI/Layout): the step card in the "objective" region (top left), the pager and the
-- casualty monitor stacked in the "right" column; the debrief is a toast in the "notice" band. In the cold
-- open only the step line shows (the right column is hidden), and only while no mechanic panel
-- (Layout.promptBusy) repeats it. A new player (Layout.newPlayer) gets no relay / big-call alert
-- and no casualty monitor until a treat step is up (docs/15 section 3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatColdOpen =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Boat"):WaitForChild("ColdOpen"))
local ColdOpenCue = require(script.Parent.ColdOpenCue)
local Layout = require(script.Parent.Layout)
local OpsConditionMonitor = require(script.Parent.OpsConditionMonitor)
local OpsDebrief = require(script.Parent.OpsDebrief)
local OpsStepCard = require(script.Parent.OpsStepCard)
local OpsTaskingCard = require(script.Parent.OpsTaskingCard)

local OpsHud = {}

local NEW_PLAYER_DEBRIEF = 6 -- s: the first calls' debrief stays up a little longer
-- first station calls: the casualty keeps the cold open's world cues while you go and get them
local FIND_STEPS = { passage = true, search = true, approach = true, calm = true, recovery = true }

local DEBRIEF_LINE: { [string]: string } = {
	Gold = "AGG_DEBRIEF_GOLD",
	Silver = "AGG_DEBRIEF_SILVER",
	Bronze = "AGG_DEBRIEF_BRONZE",
}

-- The casualty monitor is a training aid only while a treat step is up for this player.
local function treatStep(s: { [string]: any }): boolean
	for _, c in s.current or {} do
		if c.mechanicId == "treat" and (c.trackId == nil or c.trackId == s.myTrack) then
			return true
		end
	end
	return false
end

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
	local monitor = OpsConditionMonitor.new(right)
	-- cold open: one objective on screen. The compact step line is that objective, except while a
	-- mechanic panel is up (its header already says the same step), so it steps aside then.
	-- the world shows the goal (docs/14 F-3): dye, pulse ring, smoke and a flare at the casualty
	local stopCue: (() -> ())? = nil
	local function applyColdOpen(_: boolean?)
		local active = Layout.coldOpen()
		right.Visible = not active
		step.setCompact(active)
		objective.Visible = not (active and Layout.promptBusy())
		if active and not stopCue then
			stopCue = ColdOpenCue.start(function(held: boolean)
				local words = BoatColdOpen.STEP_SHORT
				step.setLabel(if held then words.home else words.reach)
			end)
		elseif not active and stopCue then
			stopCue()
			stopCue = nil
			step.setLabel(nil)
		end
	end
	Layout.onColdOpen(applyColdOpen)
	Layout.onPromptBusy(applyColdOpen)
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
		elseif data.isBig then
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
		step.update(s, function(key: string)
			ops.TakeStep(key)
		end)
		local vitals = player:GetAttribute("OpsPro") ~= true
		if vitals and Layout.newPlayer() and not treatStep(s) then
			vitals = false
		end
		monitor.update(s.casualties or {}, vitals)
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
		monitor.hide()
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
		if c.opId == activeOp then
			activeOp = nil
			step.hide()
			monitor.hide()
			setFind(nil)
		end
		if c.message and not c.silent then
			radio.sayText("Gale Isles Coastguard", tostring(c.message))
		end
	end)
end

return OpsHud
