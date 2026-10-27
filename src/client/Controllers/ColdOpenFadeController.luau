--!strict
-- ColdOpenFadeController: the cold open moves a new player from the build stand onto the jet ski in one
-- server step (VehicleService.SpawnColdOpen). The server raises the player attribute ColdOpenFade first and
-- waits FADE before the move; this dips the screen to black for it and back once the attribute clears.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FADE = 0.25 -- s each way (VehicleService COLD_OPEN_FADE waits a little longer)

local ColdOpenFadeController = {}

function ColdOpenFadeController.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ColdOpenFade"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100 -- over every HUD and panel
	gui.Parent = player:WaitForChild("PlayerGui")
	local cover = Instance.new("Frame")
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.Active = false
	cover.Parent = gui
	local info = TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local function paint()
		local on = player:GetAttribute("ColdOpenFade") == true
		TweenService:Create(cover, info, { BackgroundTransparency = if on then 0 else 1 }):Play()
	end
	player:GetAttributeChangedSignal("ColdOpenFade"):Connect(paint)
	paint()
end

return ColdOpenFadeController
