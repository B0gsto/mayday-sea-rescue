--!strict
-- Studio-only dev hook for the UI Kit style guide (UI/Kit/StyleGuide): set the Workspace attribute
-- KitStyleGuide to "shop" | "settings" | "dialog" to show that page, "" to hide it.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KitStyleGuide = {}

function KitStyleGuide.Start()
	if not RunService:IsStudio() then
		return
	end
	local function apply()
		local page = Workspace:GetAttribute("KitStyleGuide")
		if type(page) == "string" then
			local StyleGuide = require(
				script.Parent.Parent
					:WaitForChild("UI")
					:WaitForChild("Kit")
					:WaitForChild("StyleGuide")
			) :: any
			StyleGuide.show(if page == "" then nil else page)
		end
	end
	Workspace:GetAttributeChangedSignal("KitStyleGuide"):Connect(apply)
	apply()
end

return KitStyleGuide
