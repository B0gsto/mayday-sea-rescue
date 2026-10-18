--!strict
-- OpsHud: wires the operation UI to OpsController's signals (CONTRACT.md "Operations v2", stream d):
-- the tasking pager (OnOffer), the step card and casualty monitor (OnState), the debrief tablet
-- (OnDebrief) and closures (OnClosed). Mounted by RadioController, which also sets
-- OpsController.UseBuiltInUi = false so the greybox UI stays hidden.
-- Placement (UI/Layout): the step card in the "objective" region (top left), the pager and the
-- casualty monitor stacked in the "right" column; the debrief is a centred modal. In the cold
-- open only the step line shows (the right column is hidden).
local Players = game:GetService("Players")

local Layout = require(script.Parent.Layout)
local OpsConditionMonitor = require(script.Parent.OpsConditionMonitor)
local OpsDebrief = require(script.Parent.OpsDebrief)
local OpsStepCard = require(script.Parent.OpsStepCard)
local OpsTaskingCard = require(script.Parent.OpsTaskingCard)

local OpsHud = {}

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
	local monitor = OpsConditionMonitor.new(right)
	Layout.onColdOpen(function(active: boolean)
		right.Visible = not active
		step.setCompact(active)
	end)
	local debrief = OpsDebrief.new(gui)
	local activeOp: string? = nil

	ops.OnOffer:Connect(function(data: { [string]: any })
		-- the debrief never holds up the next tasking for more than 10 seconds
		if debrief.shownFor() >= 10 then
			debrief.hide()
		end
		tasking.show(data, function(opId: string)
			tasking.hide(opId)
			ops.Accept(opId)
		end)
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
		step.update(s, function(key: string)
			ops.TakeStep(key)
		end)
		monitor.update(s.casualties or {}, player:GetAttribute("OpsPro") ~= true)
	end)

	ops.OnDebrief:Connect(function(d: { [string]: any })
		activeOp = nil
		step.hide()
		monitor.hide()
		debrief.show(d)
		local id = if d.takeover then "AGG_DEBRIEF_TAKEOVER" else DEBRIEF_LINE[d.grade]
		if id then
			radio.play(
				id,
				{ priority = radio.Priorities.Advice, from = "Chief Aggie · Port Haven" }
			)
		end
	end)

	ops.OnClosed:Connect(function(c: { [string]: any })
		tasking.hide(c.opId)
		if c.opId == activeOp then
			activeOp = nil
			step.hide()
			monitor.hide()
		end
		if c.message and not c.silent then
			radio.sayText("Gale Isles Coastguard", tostring(c.message))
		end
	end)
end

return OpsHud
