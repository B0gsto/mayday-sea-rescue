--!strict
-- ShantyRadio (server, RP-M5 stream C): the Sea Shanty Radio on the owner's boat or jet ski.
-- Keeps the vehicle model attribute `RadioTrack` (src/shared/ShantyRadio format) so every client
-- near the boat plays the same track from the same point; clients do the audio
-- (src/client/Cosmetics/ShantyRadio.luau).
--   Cosmetics_Action "RadioToggle"   on (next track after the last one heard) / off
--   Cosmetics_Action "RadioNext"     skip to the next track (when on)
-- The station is the player's effective "Radio" cosmetic (Off = no radio; changing it while on
-- retunes, choosing Off switches it off). A track that has played out moves on to the next.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Radio = require(Shared:WaitForChild("ShantyRadio"))

local ShantyRadioServer = {}

local service: any = nil
local lastTrack: { [Player]: number } = {} -- the last track each player's radio played
local on: { [Model]: Player } = {} -- vehicles whose radio is playing -> owner

local function stationOption(player: Player): { [string]: any }?
	local id = service.Equipped(player, "Radio")
	if id == nil or id == service.Cosmetics.default("Radio") then
		return nil
	end
	return service.Cosmetics.option("Radio", id)
end

-- The player's own boat or jet ski (seated in it, else the one they own).
local function radioVehicle(player: Player): Model?
	local model, kind = service.VehicleOf(player)
	if not model or (kind ~= "Boat" and kind ~= "JetSki") then
		return nil
	end
	if model:GetAttribute("Owner") ~= player.UserId then
		return nil
	end
	return model
end

local function stop(model: Model)
	model:SetAttribute(Radio.ATTRIBUTE, nil)
	on[model] = nil
end

local function play(player: Player, model: Model, option: { [string]: any }, after: number?)
	local track = Radio.next(option, after)
	if not track then
		stop(model)
		return
	end
	lastTrack[player] = track.id
	on[model] = player
	model:SetAttribute(
		Radio.ATTRIBUTE,
		Radio.format(option.id, track.id, Workspace:GetServerTimeNow())
	)
end

local function current(model: Model): Radio.State?
	return Radio.parse(model:GetAttribute(Radio.ATTRIBUTE))
end

function ShantyRadioServer.Init(svc: any)
	service = svc
	svc.OnAction("RadioToggle", function(player: Player)
		local model = radioVehicle(player)
		if not model then
			return
		end
		if current(model) then
			stop(model)
			return
		end
		local option = stationOption(player)
		if option then
			play(player, model, option, lastTrack[player])
		end
	end)
	svc.OnAction("RadioNext", function(player: Player)
		local model = radioVehicle(player)
		local state = model and current(model)
		local option = stationOption(player)
		if model and state and option then
			play(player, model, option, state.id)
		end
	end)
	svc.Changed:Connect(function(player: Player, slot: string, _id: string)
		if slot ~= "Radio" then
			return
		end
		for model, owner in on do
			if owner == player then
				local option = stationOption(player)
				if option then
					play(player, model, option, nil)
				else
					stop(model)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTrack[player] = nil
		for model, owner in on do
			if owner == player then
				stop(model)
			end
		end
	end)
end

function ShantyRadioServer.Start()
	while true do
		task.wait(1)
		local now = Workspace:GetServerTimeNow()
		for model, owner in on do
			local state = current(model)
			if not model.Parent or not state then
				on[model] = nil
				continue
			end
			local option = service.Cosmetics.option("Radio", state.station)
			local track = Radio.find(option, state.id)
			if not option or not track then
				stop(model)
			elseif now - state.startedAt >= track.length + Radio.END_SLACK then
				play(owner, model, option, state.id)
			end
		end
	end
end

return ShantyRadioServer
