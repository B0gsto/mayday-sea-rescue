--!strict
-- Quests panel: the same cards as your quest tablet (UI/QuestTablet.rows / fill: your active quest, then today's
-- offers from the givers moored at your pontoon). A card or its button acts from anywhere: Accept (closes the panel)
-- or Drop; Hand in still needs you beside the giver (or at the tablet).
local Players = game:GetService("Players")

local Panel = require(script.Parent.Parent:WaitForChild("Kit"):WaitForChild("Panel"))
local QuestTablet = require(script.Parent.Parent:WaitForChild("QuestTablet"))

local player = Players.LocalPlayer

local Quests = {}

function Quests.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Quests",
		icon = "quests",
		size = Vector2.new(760, 580),
		onClose = onClose,
	})
	local shown = ""

	local function rebuild()
		local rows, sig = QuestTablet.rows(false)
		if sig == shown then
			return
		end
		shown = sig
		QuestTablet.fill(panel.body, rows, panel.close, function(_, act)
			act()
		end)
	end

	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Quest" and panel.isOpen() then
			rebuild()
		end
	end)

	return {
		open = function()
			panel.open()
			shown = ""
			rebuild()
			task.spawn(function() -- the givers moor and sail off while it is up
				while panel.isOpen() do
					task.wait(0.5)
					rebuild()
				end
			end)
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Quests
