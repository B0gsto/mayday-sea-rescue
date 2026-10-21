--!strict
-- AlbumController: the client side of the Rescue Album (docs/15 H2).
--   * Mounts UI/AlbumBoard on the station board the server built (Workspace.StationAlbumBoard).
--   * Pulls Album_Get once, then takes Album_State pushes (a rescued sticker, a completed set).
--   * Album_Flare: a Legendary (or Epic) call appeared somewhere in the server. A star flashes at
--     the top of the screen (an icon, no text) and a short music sting plays; the 60 s gold sky
--     flare and the beam from the spot are server parts everyone sees.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local UI = script.Parent.Parent:WaitForChild("UI")
local Board = require(UI:WaitForChild("AlbumBoard"))
local Layout = require(UI:WaitForChild("Layout"))

local AlbumController = {}
AlbumController.Priority = 86

local BOARD_NAME = "StationAlbumBoard"

local player = Players.LocalPlayer
local board: Board.Board? = nil
local pending: Board.View? = nil
local flareGui: ScreenGui? = nil
local stingSound: Sound? = nil
local ownedCount = 0

local function apply(view: Board.View?)
	if view then
		pending = view
	end
	if board and pending then
		board.update(pending)
	end
end

local function mountBoard()
	local model = Workspace:WaitForChild(BOARD_NAME, 60)
	if not model then
		return
	end
	local panel = model:FindFirstChild("Panel")
	if panel and panel:IsA("BasePart") then
		local mounted = Board.mount(panel)
		board = mounted
		if pending then
			mounted.update(pending)
		end
	end
end

-- A short sting: the heroic cue for a Legendary call, the old debrief cue for Epic; both are
-- stopped early so they stay a sting.
local function sting(legendary: boolean)
	if stingSound and stingSound.Parent then
		stingSound:Stop()
		stingSound:Destroy()
	end
	local sound = AudioController.play(
		if legendary then "Music_Legendary" else "Music_Debrief",
		nil,
		if legendary then 0.8 else 0.6,
		if legendary then 1 else 1.04
	)
	stingSound = sound
	if sound then
		task.delay(7, function()
			if sound.Parent then
				sound:Stop()
				sound:Destroy()
			end
		end)
	end
end

-- The call icon: a star in a dark disc that swells in and fades. Legendary is bigger and gold;
-- Epic is the smaller purple version (no beam). Nothing is written.
local function showFlare(rarity: string?)
	local legendary = rarity ~= "Epic"
	if not flareGui then
		return
	end
	local old = flareGui:FindFirstChild("Legendary") or flareGui:FindFirstChild("Epic")
	if old then
		old:Destroy()
	end
	local size = if legendary then 84 else 60
	local edge = if legendary then Color3.fromRGB(255, 210, 96) else Color3.fromRGB(174, 132, 240)
	local ink = if legendary then Color3.fromRGB(255, 214, 90) else Color3.fromRGB(206, 178, 255)
	local discColour = if legendary then Color3.fromRGB(22, 26, 30) else Color3.fromRGB(26, 20, 36)
	local holder = Instance.new("Frame")
	holder.Name = if legendary then "Legendary" else "Epic"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromScale(0.5, 0.14)
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundColor3 = discColour
	holder.BackgroundTransparency = 0.15
	holder.BorderSizePixel = 0
	holder.Parent = flareGui

	local disc = Instance.new("UICorner")
	disc.CornerRadius = UDim.new(1, 0)
	disc.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = edge
	stroke.Thickness = if legendary then 4 else 3
	stroke.Parent = holder
	local star = Instance.new("TextLabel")
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.TextColor3 = ink
	star.TextScaled = true
	star.Size = UDim2.fromScale(0.62, 0.62)
	star.Position = UDim2.fromScale(0.19, 0.19)
	star.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	star.Parent = holder

	holder.Size = UDim2.fromOffset(10, 10)
	holder.Position = UDim2.fromScale(0.5, 0.14)
	TweenService:Create(
		holder,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(size, size) }
	):Play()
	task.delay(if legendary then 4.2 else 2.2, function()
		if not holder.Parent then
			return
		end
		TweenService:Create(
			holder,
			TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1, Size = UDim2.fromOffset(size + 46, size + 46) }
		):Play()
		TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		TweenService:Create(star, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		task.delay(0.7, function()
			holder:Destroy()
		end)
	end)
end

function AlbumController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AlbumHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
	flareGui = gui
end

function AlbumController.Start()
	task.spawn(mountBoard)
	local netFolder = ReplicatedStorage:WaitForChild("Net", 30)
	if not netFolder then
		return
	end
	local state = netFolder:WaitForChild("Album_State", 30)
	if state and state:IsA("RemoteEvent") then
		state.OnClientEvent:Connect(function(view: any)
			if type(view) == "table" and (tonumber(view.ownedCount) or 0) > ownedCount then
				AudioController.play("Album_Sticker", nil, 1, 1)
				task.delay(0.1, function()
					AudioController.play("Album_Sparkle", nil, 1, 1.04)
				end)
			end
			if type(view) == "table" then
				ownedCount = math.max(ownedCount, tonumber(view.ownedCount) or ownedCount)
				apply(view :: Board.View)
			end
		end)
	end
	local flare = netFolder:WaitForChild("Album_Flare", 30)
	if flare and flare:IsA("RemoteEvent") then
		flare.OnClientEvent:Connect(function(payload: any)
			if type(payload) == "table" then
				local rarity = payload.rarity
				showFlare(if type(rarity) == "string" then rarity else nil)
				sting(rarity == "Legendary")
			end
		end)
	end
	local get = netFolder:WaitForChild("Album_Get", 30)
	if not get or not get:IsA("RemoteFunction") then
		return
	end
	local ok, view = pcall(function()
		return get:InvokeServer()
	end)
	if ok and type(view) == "table" then
		ownedCount = math.max(ownedCount, tonumber(view.ownedCount) or 0)
		apply(view :: Board.View)
	end
end

return AlbumController
