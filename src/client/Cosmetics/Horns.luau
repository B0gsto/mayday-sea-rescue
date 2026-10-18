--!strict
-- Horns (RP-M5 Horn Pack, client). Binds the "Horn" vehicle action (keyboard H, gamepad L3, a tap
-- button on touch) while the local player drives with a Horn Pack horn equipped; a press asks the
-- server (action "Horn"), which answers nearby clients with Cosmetics_Event "Horn"
-- (model, hornId, userId). Each client plays a one-shot 3D Sound on that vehicle (SFX group,
-- RollOffMaxDistance = the horn's range), cut with a short fade after the horn's length. Other
-- players' horns honour Settings "mute horns"; your own always plays.
-- Also exports Horns.hint(text) (a short HudTheme notice), used by Sirens for refusals.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local VehicleSounds = require(Shared:WaitForChild("VehicleSounds"))
local Client = script.Parent.Parent
local AudioController = require(Client:WaitForChild("Controllers"):WaitForChild("AudioController"))
local HudTheme = require(Client:WaitForChild("UI"):WaitForChild("HudTheme"))
local Layout = require(Client:WaitForChild("UI"):WaitForChild("Layout"))

local Horns = {}

local FADE = 0.35 -- s
local MAX_VOICES = 3 -- one vehicle never stacks more than this many horns

---------------------------------------------------------------- hint

local hintLabel: TextLabel? = nil
local hintSerial = 0

function Horns.hint(text: string)
	local player = Players.LocalPlayer
	if not hintLabel then
		local gui = Instance.new("ScreenGui")
		gui.Name = "VehicleSoundHint"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		Layout.prepare(gui)
		gui.Parent = player:WaitForChild("PlayerGui")
		local region = Layout.region(gui, "notice")
		local l = HudTheme.label(
			"Hint",
			"",
			UDim2.new(1, 0, 0, 36),
			HudTheme.BodyFont,
			HudTheme.TextSize.small,
			region
		)
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Position = UDim2.fromScale(0.5, 1)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.fromOffset(0, 36)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.BackgroundColor3 = HudTheme.Colors.panel
		l.BackgroundTransparency = 1
		l.TextTransparency = 1
		HudTheme.corner(l)
		HudTheme.padding(l, 10)
		hintLabel = l
	end
	local l = hintLabel :: TextLabel
	hintSerial += 1
	local serial = hintSerial
	l.Text = text
	l.TextTransparency = 0
	l.BackgroundTransparency = HudTheme.PanelTransparency
	task.delay(2.5, function()
		if serial ~= hintSerial then
			return
		end
		TweenService
			:Create(l, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
			:Play()
	end)
end

---------------------------------------------------------------- playback

local voices: { [Model]: number } = {}

local function emitterOf(model: Model): BasePart?
	local seat = model:FindFirstChild("DriverSeat", true)
	if seat and seat:IsA("BasePart") then
		return seat
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function play(model: Model, option: VehicleSounds.Option)
	local clip = option.clip :: string
	local spec = AudioConfig.Clips[clip]
	local parent = emitterOf(model)
	if not spec or not parent then
		return
	end
	if (voices[model] or 0) >= MAX_VOICES then
		return
	end
	voices[model] = (voices[model] or 0) + 1
	local s = AudioController.newSound(clip, parent, false)
	s.Name = "CosmeticHorn"
	s.Volume = spec.volume
	s.RollOffMinDistance = 25
	s.RollOffMaxDistance = VehicleSounds.range(option, VehicleSounds.HORN_RANGE)
	s:Play()
	local length = if type(option.length) == "number" then option.length else 4
	local function done()
		if s.Parent then
			s:Destroy()
		end
		voices[model] = math.max(0, (voices[model] or 1) - 1)
	end
	s.Ended:Once(done)
	task.delay(length, function()
		if s.Parent and s.IsPlaying then
			local tween = TweenService:Create(s, TweenInfo.new(FADE), { Volume = 0 })
			tween.Completed:Once(done)
			tween:Play()
		end
	end)
	task.delay(length + FADE + 1, function()
		if s.Parent then
			done()
		end
	end)
end

function Horns.Start(ctx: any)
	local player: Player = ctx.player

	local function equippedOption(): VehicleSounds.Option?
		return ctx.Cosmetics.option("Horn", ctx.equipped(player, "Horn"))
	end

	local function label(): string
		local o = equippedOption()
		return if o and type(o.label) == "string" then o.label else "Horn"
	end

	local unbind: (() -> ())? = nil
	local function rebind()
		if unbind then
			unbind()
		end
		unbind = ctx.bindVehicleAction({
			name = "Horn",
			label = label(),
			key = Enum.KeyCode.H,
			gamepad = Enum.KeyCode.ButtonL3,
			callback = function()
				ctx.fire("Horn")
			end,
			visible = function(): boolean
				return VehicleSounds.playable(equippedOption())
			end,
		})
	end
	rebind()
	ctx.onEquipped(player, "Horn", function()
		rebind() -- new touch label; re-binding also puts H / L3 above the car horn
	end)

	ctx.onEvent("Horn", function(model: any, hornId: any, userId: any)
		if typeof(model) ~= "Instance" or not model:IsA("Model") or type(hornId) ~= "string" then
			return
		end
		local isOwn = userId == player.UserId
		if not VehicleSounds.audible(isOwn, ctx.muted("Horns")) then
			return
		end
		local option = ctx.Cosmetics.option("Horn", hornId)
		if option and VehicleSounds.playable(option) then
			play(model, option)
		end
	end)

	ctx.onEvent("CosmeticRefused", function(kind: any, reason: any)
		if kind == "Horn" and type(reason) == "string" then
			local text = VehicleSounds.Reasons[reason]
			if text then
				Horns.hint(text)
			end
		end
	end)
end

return Horns
