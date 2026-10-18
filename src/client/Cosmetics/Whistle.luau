--!strict
-- Whistle (RP-M5 E2, a CosmeticsController feature): the Captain's Locker whistle emote. Owners
-- press Y (keyboard), D-pad up (gamepad, on foot and outside a mechanic prompt) or the "Whistle"
-- tap button (touch, stacked over the gauges region): the avatar raises an arm (Roblox's R15 wave
-- animation, cut after 1.4 s; replicates from this client) and the server relays the blast
-- (src/server/Cosmetics/Outfits.luau) to clients within 140 studs, who play the Fox 40 pealess
-- whistle (AudioConfig Emote_Whistle, SFX group) at that player's head, rolled off by 140 studs.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local AvatarCosmetics = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AvatarCosmetics")
)
local HudTheme = require(UI:WaitForChild("HudTheme"))
local Layout = require(UI:WaitForChild("Layout"))

local Whistle = {}

local PASS = "CaptainsLocker"
local ACTION = "Cosmetic_Whistle"
local ANIM = "rbxassetid://507770239" -- Roblox R15 "wave" emote (Animate script), an arm raise

local track: AnimationTrack? = nil
local lastAt: number? = nil

local function humanoidOf(model: Model?): Humanoid?
	return if model then model:FindFirstChildOfClass("Humanoid") else nil
end

local function raiseArm(character: Model)
	local hum = humanoidOf(character)
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	if track then
		track:Stop(0.1)
	end
	local a = Instance.new("Animation")
	a.AnimationId = ANIM
	local ok, t = pcall(function()
		return (animator :: Animator):LoadAnimation(a)
	end)
	if ok and t then
		track = t
		t.Priority = Enum.AnimationPriority.Action
		t:Play(0.15)
		task.delay(AvatarCosmetics.WHISTLE.animSeconds, function()
			if track == t then
				t:Stop(0.3)
			end
		end)
	end
end

local function blast(from: Player)
	local character = from.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local s = AudioController.newSound("Emote_Whistle", head, false)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = AvatarCosmetics.WHISTLE.radius
	s.Volume = 0.9
	s.PlaybackSpeed = 0.97 + math.random() * 0.06
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function Whistle.Start(ctx: any)
	local player: Player = ctx.player
	local button: TextButton? = nil

	local function onFoot(): boolean
		local hum = humanoidOf(player.Character)
		return hum ~= nil and hum.Health > 0 and hum.SeatPart == nil
	end

	local function blow()
		if not ctx.owns(PASS) then
			return
		end
		local now = os.clock()
		if not AvatarCosmetics.whistleReady(lastAt, now) then
			return
		end
		lastAt = now
		local character = player.Character
		if character and onFoot() then
			raiseArm(character)
		end
		ctx.fire("Whistle")
	end

	local function handler(_: string, state: Enum.UserInputState, input: InputObject)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.DPadUp and (not onFoot() or Layout.promptBusy()) then
			return Enum.ContextActionResult.Pass
		end
		blow()
		return Enum.ContextActionResult.Pass
	end

	local bound = false
	local function sync()
		local want = ctx.owns(PASS)
		if want and not bound then
			ContextActionService:BindActionAtPriority(
				ACTION,
				handler,
				false,
				Enum.ContextActionPriority.Low.Value,
				Enum.KeyCode.Y,
				Enum.KeyCode.DPadUp
			)
			bound = true
		elseif not want and bound then
			ContextActionService:UnbindAction(ACTION)
			bound = false
		end
		if button then
			button.Visible = want and UserInputService.TouchEnabled and onFoot()
		end
	end

	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "WhistleButton"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 12
		Layout.prepare(gui)
		gui.Parent = player:WaitForChild("PlayerGui")
		local region = Layout.region(gui, "gauges")
		local b = HudTheme.button(
			"Whistle",
			"Whistle",
			UDim2.fromOffset(104, HudTheme.MinButtonHeight),
			region
		)
		b.BackgroundColor3 = HudTheme.Colors.panelLight
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, 0, 0, -8)
		b.Visible = false
		b.Activated:Connect(blow)
		button = b
		task.spawn(function()
			while gui.Parent do
				sync()
				task.wait(0.5)
			end
		end)
	end

	player:GetAttributeChangedSignal("Pass_" .. PASS):Connect(sync)
	sync()
	ctx.onEvent("Whistle", function(from: any)
		if typeof(from) == "Instance" and from:IsA("Player") then
			blast(from)
		end
	end)
end

return Whistle
