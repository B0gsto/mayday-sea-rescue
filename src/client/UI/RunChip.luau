--!strict
-- RunChip (docs/29 C): the rescue run's x and its seconds left, in the HudLayout "run" slot. Hidden at x1 and on the
-- new player's bare HUD. One pop when the x rises; nothing flashes, the seconds just turn red near the end.
-- Reads RescueRunService's RunMult / RunEndsAt (server time).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Style = require(script.Parent:WaitForChild("Kit"):WaitForChild("Style"))

local player = Players.LocalPlayer

local RunChip = {}

local LOW = 15 -- s left: the seconds turn red -- tune
local RED = Color3.fromHex("FF3B3B")
local INK = Color3.fromHex("23283D")

function RunChip.mount(region: Frame)
	local root = Instance.new("Frame")
	root.Name = "RunChip"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = region
	local _, face = Style.block(root, Style.grad("yellow"))

	local iconBox = Instance.new("Frame")
	iconBox.BackgroundTransparency = 1
	iconBox.Position = UDim2.new(0, 4, 0.5, -15)
	iconBox.Size = UDim2.fromOffset(30, 30)
	iconBox.Parent = face
	Style.icon(iconBox, "boost")

	local mult = Style.label(face, "", 24, true)
	mult.Name = "Mult"
	mult.Position = UDim2.fromOffset(36, 0)
	mult.Size = UDim2.new(0, 62, 1, 0)
	mult.TextXAlignment = Enum.TextXAlignment.Left

	local seconds = Style.label(face, "", 20, true)
	seconds.Name = "Seconds"
	seconds.Position = UDim2.new(1, -42, 0, 0)
	seconds.Size = UDim2.new(0, 38, 1, 0)
	seconds.TextXAlignment = Enum.TextXAlignment.Right

	local shown: number? = nil
	task.spawn(function()
		while region.Parent do
			local m = player:GetAttribute("RunMult")
			local ends = player:GetAttribute("RunEndsAt")
			local left = if type(ends) == "number" then ends - Workspace:GetServerTimeNow() else 0
			local on = type(m) == "number"
				and left > 0
				and not Layout.coldOpen()
				and not Layout.newPlayer()
			if not on then
				if shown then
					Style.pop(root, false)
				end
				shown = nil
			elseif m ~= shown then
				local rising = shown == nil or (m :: number) > shown
				shown = m :: number
				mult.Text = "x" .. tostring(m)
				if rising then
					if Comfort.reducedMotion() then
						root.Visible = true
					else
						Style.pop(root, true)
					end
				end
			end
			if on then
				seconds.Text = `{math.ceil(left)}s`
				seconds.TextColor3 = if left <= LOW then RED else INK
			end
			task.wait(0.25)
		end
	end)
end

return RunChip
