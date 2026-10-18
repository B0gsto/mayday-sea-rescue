--!strict
-- ShantyRadio (client, RP-M5 stream C): the Sea Shanty Radio.
-- * Controls (owner aboard their boat or jet ski with a station equipped; CosmeticsController
--   bindVehicleAction, so keyboard, gamepad and a touch button):
--     "Radio"      N / gamepad DPadRight   on / off (each switch-on starts the next track)
--     "RadioNext"  Period (.)              next track, only while it plays
--   M is the map and the D-pad's other directions are the siren and light bar; DPadRight is also
--   the car's blue lights, but the radio is never bound in a car, and the tow line takes it over
--   while towing (bound later, so it wins the ContextActionService stack).
-- * Playback for every vehicle in Workspace.Vehicles with a `RadioTrack` attribute (server-kept,
--   src/shared/ShantyRadio format): one 3D Sound on the vehicle's PrimaryPart, Music category
--   (AudioController.group("Music") = the RadioDuck group, so VHF radio lines duck it), a short
--   InverseTapered roll-off so it is only heard near the boat, started at the shared server-time
--   offset. Ducked further under the operation music cue. Other players' radios are skipped when
--   the local player muted radios (Settings).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Radio = require(Shared:WaitForChild("ShantyRadio"))

local ShantyRadio = {}

local POLL = 0.5

type Playing = { sound: Sound, key: string, part: BasePart }

local playing: { [Model]: Playing } = {}

local function sibling(name: string): any?
	local controllers = script.Parent.Parent:FindFirstChild("Controllers")
	local m = controllers and controllers:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		return if ok then mod else nil
	end
	return nil
end

local function release(model: Model)
	local p = playing[model]
	if p then
		p.sound:Destroy()
		playing[model] = nil
	end
end

function ShantyRadio.Start(ctx: any)
	local me: Player = ctx.player
	local Cosmetics = ctx.Cosmetics
	local Audio = sibling("AudioController")
	local Ops = sibling("OpsController")

	local function myRadioVehicle(): Model?
		local model, kind = ctx.currentVehicle()
		if not model or (kind ~= "Boat" and kind ~= "JetSki") then
			return nil
		end
		if model:GetAttribute("Owner") ~= me.UserId then
			return nil
		end
		return model
	end
	local function hasStation(): boolean
		return ctx.equipped(me, "Radio") ~= Cosmetics.default("Radio")
	end

	ctx.bindVehicleAction({
		name = "Radio",
		label = "Radio",
		key = Enum.KeyCode.N,
		gamepad = Enum.KeyCode.DPadRight,
		callback = function()
			ctx.fire("RadioToggle")
		end,
		visible = function(): boolean
			return hasStation() and myRadioVehicle() ~= nil
		end,
	})
	ctx.bindVehicleAction({
		name = "RadioNext",
		label = "Next track",
		key = Enum.KeyCode.Period,
		callback = function()
			ctx.fire("RadioNext")
		end,
		visible = function(): boolean
			local model = myRadioVehicle()
			return model ~= nil and hasStation() and model:GetAttribute(Radio.ATTRIBUTE) ~= nil
		end,
	})

	local function update()
		local now = Workspace:GetServerTimeNow()
		local duck = Radio.duck(Ops ~= nil and Ops.GetState() ~= nil)
		local seen: { [Model]: boolean } = {}
		local folder = Workspace:FindFirstChild("Vehicles")
		for _, model in (if folder then folder:GetChildren() else {}) :: { Instance } do
			if not model:IsA("Model") then
				continue
			end
			local raw = model:GetAttribute(Radio.ATTRIBUTE)
			local state = Radio.parse(raw)
			local part = model.PrimaryPart
			local mine = model:GetAttribute("Owner") == me.UserId
			if not state or not part or (not mine and ctx.muted("Radios")) then
				continue
			end
			local option = Cosmetics.option("Radio", state.station)
			local track = Radio.find(option, state.id)
			local at = track and Radio.position(state, track.length, now)
			if not track or not at then
				continue
			end
			seen[model] = true
			local p: Playing? = playing[model]
			if p and (p.key ~= raw or p.part ~= part) then
				release(model)
				p = nil
			end
			if not p then
				local s = Instance.new("Sound")
				s.Name = "ShantyRadio"
				s.SoundId = `rbxassetid://{track.id}`
				s.RollOffMode = Enum.RollOffMode.InverseTapered
				s.RollOffMinDistance = Radio.ROLL_MIN
				s.RollOffMaxDistance = Radio.ROLL_MAX
				s.Looped = false
				if Audio then
					s.SoundGroup = Audio.group("Music")
				end
				s.Volume = Radio.VOLUME * duck
				s.TimePosition = at
				s.Parent = part
				s:Play()
				if not s.IsLoaded then -- re-sync once the asset has streamed in
					local started = state.startedAt
					s.Loaded:Once(function()
						s.TimePosition = math.max(0, Workspace:GetServerTimeNow() - started)
					end)
				end
				playing[model] = { sound = s, key = raw :: string, part = part }
			else
				p.sound.Volume = Radio.VOLUME * duck
			end
		end
		for model in playing do
			if not seen[model] then
				release(model)
			end
		end
	end

	while true do
		local ok, err: any = pcall(update)
		if not ok then
			warn("ShantyRadio:", err)
		end
		task.wait(POLL)
	end
end

return ShantyRadio
