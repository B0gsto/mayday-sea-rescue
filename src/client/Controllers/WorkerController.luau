--!strict
-- WorkerController (WP-26): draws the WorkerBadge billboard (category icon + rarity stars, legendary glow) on
-- every model the server tags "WorkerBadge" (a picked-up survivor, your workers), and plays the offline
-- earnings welcome: a coin burst into the wallet and a Toast when the player attribute WorkerOffline arrives.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UI = script.Parent.Parent:WaitForChild("UI")
local CashBurst = require(UI:WaitForChild("CashBurst"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local Toast = require(UI:WaitForChild("Kit"):WaitForChild("Toast"))
local WorkerBadge = require(UI:WaitForChild("WorkerBadge"))

local WorkerController = {}

local player = Players.LocalPlayer

local function badge(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	-- the rig may stream in after the tag: retry briefly
	task.spawn(function()
		for _ = 1, 20 do
			if inst.Parent == nil or inst:FindFirstChild("WorkerTag") then
				return
			end
			WorkerBadge.billboard(inst)
			task.wait(0.5)
		end
	end)
end

local shown = false -- once a session (the server sets it once)
local function welcome()
	local pay = player:GetAttribute("WorkerOffline")
	if shown or type(pay) ~= "number" or pay <= 0 then
		return
	end
	shown = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkerWelcome"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")
	Toast.show(Style.canvas(gui), `+{pay}`, { icon = "cash", color = "green", duration = 6 })
	local camera = Workspace.CurrentCamera
	if camera then
		CashBurst.playAt(
			gui.Parent :: Instance,
			camera.ViewportSize * Vector2.new(0.5, 0.3),
			pay,
			false
		)
	end
	task.delay(8, function()
		gui:Destroy()
	end)
end

function WorkerController.Start()
	CollectionService:GetInstanceAddedSignal("WorkerBadge"):Connect(badge)
	for _, inst in CollectionService:GetTagged("WorkerBadge") do
		badge(inst)
	end
	player:GetAttributeChangedSignal("WorkerOffline"):Connect(welcome)
	task.delay(4, welcome) -- set before this ran: wait for the HUD to be up
end

return WorkerController
