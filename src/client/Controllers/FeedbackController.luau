--!strict
-- FeedbackController: the sound + short visual for two moments with no other home (publish polish, 2026-10-27).
--   - A survivor joins your crew (WorkerService publishes a fresh recruit with `From`): a cheerful chime, and
--     their name tag pops once their rig is drawn (WorkerController + SurvivorTag).
--   - Medals gained (player attribute `Medals` rises): a medal flips from mid-screen into the Skills button
--     and lands with a tick. Skipped under an open panel (the Skills counter shows it there).
-- Sounds go through AudioController (SFX group), so the settings panel's volume and mute apply.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Glyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Glyph"))

local FeedbackController = {}

local player = Players.LocalPlayer
local TAG = "SurvivorNameTag" -- SurvivorTag's BillboardGui
local MEDAL = 64 -- px

-- The tag springs up to twice its size and settles.
local function pop(tag: BillboardGui)
	local base = tag.Size
	tag.Size = UDim2.new(base.X.Scale * 2, base.X.Offset * 2, base.Y.Scale * 2, base.Y.Offset * 2)
	TweenService:Create(
		tag,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = base }
	):Play()
end

local function joined(cfg: Instance)
	local from = cfg:GetAttribute("From")
	if not (cfg:IsA("Configuration") and typeof(from) == "CFrame") then
		return -- only fresh recruits walk in from the jetty
	end
	if not (cfg.Parent and cfg.Parent.Name == tostring(player.UserId)) then
		return
	end
	AudioController.play("Album_Sparkle", nil, 1.3, 1.12)
	task.delay(0.12, function()
		AudioController.play("Album_Sparkle", nil, 1, 1.5)
	end)
	local name = cfg:GetAttribute("SurvivorName")
	task.spawn(function()
		for _ = 1, 24 do -- the rig shows up when the templates are in and you are in range
			local folder = Workspace:FindFirstChild("WorkersLocal")
			for _, rig in if folder then folder:GetChildren() else {} do
				local tag = rig:FindFirstChild(TAG)
				if
					tag
					and tag:IsA("BillboardGui")
					and rig:IsA("Model")
					and rig:GetAttribute("SurvivorName") == name
					and (rig:GetPivot().Position - from.Position).Magnitude < 80
				then
					pop(tag)
					AudioController.play("UI_FriendPop", rig:GetPivot().Position, 1.5, 1.1)
					return
				end
			end
			task.wait(0.25)
		end
	end)
end

local function flip()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local menu = playerGui and playerGui:FindFirstChild("Menu")
	local target = menu and menu:FindFirstChild("Menu_Skills", true)
	local camera = Workspace.CurrentCamera
	if not (playerGui and menu and target and target:IsA("GuiObject") and camera) then
		AudioController.play("UI_Step", nil, 1, 1.3)
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MedalFlip"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 41
	gui.IgnoreGuiInset = (menu :: ScreenGui).IgnoreGuiInset
	gui.Parent = playerGui
	local start = camera.ViewportSize * Vector2.new(0.5, 0.38)
	local goal = target.AbsolutePosition + target.AbsoluteSize / 2
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(start.X, start.Y)
	holder.Size = UDim2.fromOffset(MEDAL, MEDAL)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local face = Instance.new("Frame") -- its width flips; the holder flies
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.Parent = holder
	Glyph.draw("medal", face, Color3.new(1, 1, 1))
	AudioController.play("Album_Sticker", nil, 0.8, 1.35)
	local reduced = Comfort.reducedMotion()
	if not reduced then
		TweenService:Create(
			face,
			TweenInfo.new(0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true),
			{ Size = UDim2.fromScale(0.08, 1) }
		):Play()
	end
	local fly = TweenService:Create(
		holder,
		TweenInfo.new(
			if reduced then 0.2 else 0.75,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			0,
			false,
			0.35
		),
		{
			Position = UDim2.fromOffset(goal.X, goal.Y),
			Size = UDim2.fromOffset(MEDAL * 0.5, MEDAL * 0.5),
		}
	)
	fly.Completed:Once(function()
		gui:Destroy()
		AudioController.play("UI_Step", nil, 1, 1.3)
		local scale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale") -- one per button
		scale.Parent = target
		scale.Scale = 1.18
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	fly:Play()
end

function FeedbackController.Init() end

function FeedbackController.Start()
	local medals = player:GetAttribute("Medals")
	player:GetAttributeChangedSignal("Medals"):Connect(function()
		local now = player:GetAttribute("Medals")
		if
			type(medals) == "number"
			and type(now) == "number"
			and now > medals
			and player:GetAttribute("MenuOpen") ~= true
		then
			flip()
		end
		medals = now
	end)
	local root = ReplicatedStorage:WaitForChild("Workers")
	root.DescendantAdded:Connect(joined) -- existing workers never carry `From` on a rejoin
end

return FeedbackController
