--!strict
-- Sirens (RP-M5 Siren Pack, client). Binds the "Siren" toggle while the local player drives with a
-- Siren Pack tone equipped: keyboard G everywhere, gamepad DPadDown on boats and jet skis (on cars
-- DPadDown is low range; the car's Blues button, K / DPadRight, sounds the pack tone there), and a
-- tap button on touch. The server sets the vehicle's SirenTone / SirenPattern / SirenBy attributes
-- and tags it "CosmeticSiren" (contract in Config/Cosmetics/Siren.luau); this follows the tag (so
-- vehicles streaming in are picked up) and plays the tone as a looped 3D Sound on the vehicle (SFX group, LoopRegion on the steady part, RollOffMaxDistance = the tone's range).
-- Other players' sirens honour Settings "mute sirens" (re-checked twice a second); your own always
-- plays.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local VehicleSounds = require(Shared:WaitForChild("VehicleSounds"))
local Client = script.Parent.Parent
local AudioController = require(Client:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Horns = require(script.Parent:WaitForChild("Horns"))

local Sirens = {}

local POLL = 0.5 -- s between mute / attribute re-checks
local TAG = "CosmeticSiren"

type Playing = { sound: Sound, tone: string, userId: number, volume: number }

local playing: { [Model]: Playing } = {}
local watched: { [Model]: boolean } = {}

local function emitterOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function stopSound(model: Model)
	local p = playing[model]
	if p then
		p.sound:Stop()
		p.sound:Destroy()
		playing[model] = nil
	end
end

local function startSound(ctx: any, model: Model, tone: string, userId: number)
	local option = ctx.Cosmetics.option("Siren", tone)
	if not VehicleSounds.playable(option) then
		stopSound(model)
		return
	end
	local clip = option.clip :: string
	local spec = AudioConfig.Clips[clip]
	local parent = emitterOf(model)
	if not spec or not parent then
		return
	end
	local current = playing[model]
	if current and current.tone == tone then
		current.userId = userId
		return
	end
	stopSound(model)
	local s = AudioController.newSound(clip, parent, true)
	s.Name = "CosmeticSiren"
	s.Volume = spec.volume
	s.RollOffMinDistance = 30
	s.RollOffMaxDistance = VehicleSounds.range(option, VehicleSounds.SIREN_RANGE)
	local a, b = VehicleSounds.loopRegion(option)
	if a and b then
		s.PlaybackRegionsEnabled = true
		s.LoopRegion = NumberRange.new(a, b)
	end
	s:Play()
	playing[model] = { sound = s, tone = tone, userId = userId, volume = spec.volume }
end

-- the model attributes are the truth; the tag only tells us which models to look at
local function refresh(ctx: any, model: Model)
	local tone = model:GetAttribute("SirenTone")
	if not model.Parent or type(tone) ~= "string" or tone == "" then
		stopSound(model)
		watched[model] = nil
		return
	end
	local by = model:GetAttribute("SirenBy")
	startSound(ctx, model, tone, if type(by) == "number" then by else 0)
end

function Sirens.Start(ctx: any)
	local player: Player = ctx.player

	local function equippedOption(): VehicleSounds.Option?
		return ctx.Cosmetics.option("Siren", ctx.equipped(player, "Siren"))
	end
	local function label(): string
		local o = equippedOption()
		return if o and type(o.label) == "string" then "Siren " .. o.label else "Siren"
	end

	local unbinds: { () -> () } = {}
	local function rebind()
		for _, u in unbinds do
			u()
		end
		table.clear(unbinds)
		local function fire()
			ctx.fire("Siren")
		end
		-- boats and jet skis: G + DPadDown
		table.insert(
			unbinds,
			ctx.bindVehicleAction({
				name = "Siren",
				label = label(),
				key = Enum.KeyCode.G,
				gamepad = Enum.KeyCode.DPadDown,
				callback = fire,
				visible = function(): boolean
					local _, kind = ctx.currentVehicle()
					return kind ~= "Car" and VehicleSounds.playable(equippedOption())
				end,
			})
		)
		-- cars: G only (gamepad uses the car's Blues button)
		table.insert(
			unbinds,
			ctx.bindVehicleAction({
				name = "SirenCar",
				label = label(),
				key = Enum.KeyCode.G,
				callback = fire,
				visible = function(): boolean
					local _, kind = ctx.currentVehicle()
					return kind == "Car" and VehicleSounds.playable(equippedOption())
				end,
			})
		)
	end
	rebind()
	ctx.onEquipped(player, "Siren", rebind)

	local function watch(inst: Instance)
		if inst:IsA("Model") then
			watched[inst] = true
			refresh(ctx, inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst: Instance)
		if inst:IsA("Model") then
			stopSound(inst)
			watched[inst] = nil
		end
	end)
	for _, inst in CollectionService:GetTagged(TAG) do
		watch(inst)
	end

	ctx.onEvent("CosmeticRefused", function(kind: any, reason: any)
		if kind == "Siren" and type(reason) == "string" then
			local text = VehicleSounds.Reasons[reason]
			if text then
				Horns.hint(text)
			end
		end
	end)

	while true do
		task.wait(POLL)
		local muted = ctx.muted("Sirens")
		for model in watched do
			refresh(ctx, model)
		end
		for model, p in playing do
			if not model.Parent or not p.sound.Parent then
				stopSound(model)
				watched[model] = nil
			else
				local isOwn = p.userId == player.UserId
				p.sound.Volume = if VehicleSounds.audible(isOwn, muted) then p.volume else 0
			end
		end
	end
end

return Sirens
