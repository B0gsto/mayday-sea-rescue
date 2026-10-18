--!strict
-- ShantyRadio (pure, RP-M5 stream C): playlist and sync logic of the Sea Shanty Radio (stations in
-- src/shared/Config/Cosmetics/Radio.luau). Lune-tested in tests/ShantyRadio.spec.luau.
--
-- The server keeps one vehicle model attribute, `RadioTrack` = "<station>:<assetId>:<serverStart>"
-- (absent = radio off), so everyone near the boat hears the same track at the same point.
--   ShantyRadio.tracks(option): { Track }             a station option's tracks (empty for Off)
--   ShantyRadio.find(option, assetId): (Track?, index?)
--   ShantyRadio.next(option, assetId?, step?): Track?  the next (or previous) track, wrapping; the
--                                                     first when assetId is nil or not on the station
--   ShantyRadio.format(station, assetId, startedAt): string
--   ShantyRadio.parse(value): State?                   nil for anything malformed
--   ShantyRadio.position(state, length, now): number?  seconds into the track, nil once played out
--   ShantyRadio.duck(operationMusic): number           volume multiplier under the operation music

export type Track = { id: number, title: string, artist: string, length: number }
export type State = { station: string, id: number, startedAt: number }

local ShantyRadio = {}

ShantyRadio.ATTRIBUTE = "RadioTrack"
ShantyRadio.VOLUME = 0.5 -- base Sound volume (Music group, then the player's Music slider)
ShantyRadio.ROLL_MIN = 8 -- studs: full level inside this (in the cockpit)
ShantyRadio.ROLL_MAX = 45 -- studs: silent past this, only heard near the boat
ShantyRadio.OPERATION_DUCK = 0.3 -- under the operation music cue
ShantyRadio.END_SLACK = 1 -- s past the catalogue length before the server moves on

function ShantyRadio.tracks(option: { [string]: any }?): { Track }
	local list = option and option.tracks
	return if type(list) == "table" then list :: { Track } else {}
end

function ShantyRadio.find(option: { [string]: any }?, assetId: number?): (Track?, number?)
	if assetId == nil then
		return nil, nil
	end
	for i, track in ShantyRadio.tracks(option) do
		if track.id == assetId then
			return track, i
		end
	end
	return nil, nil
end

function ShantyRadio.next(option: { [string]: any }?, assetId: number?, step: number?): Track?
	local list = ShantyRadio.tracks(option)
	local n = #list
	if n == 0 then
		return nil
	end
	local _, i = ShantyRadio.find(option, assetId)
	if not i then
		return list[1]
	end
	return list[((i - 1 + (step or 1)) % n) + 1]
end

function ShantyRadio.format(station: string, assetId: number, startedAt: number): string
	return string.format("%s:%d:%.3f", station, assetId, startedAt)
end

function ShantyRadio.parse(value: any): State?
	if type(value) ~= "string" then
		return nil
	end
	local station, id, started = string.match(value, "^([%w_]+):(%d+):([%d%.]+)$")
	local idNum, startNum = tonumber(id), tonumber(started)
	if not station or not idNum or not startNum then
		return nil
	end
	return { station = station, id = idNum, startedAt = startNum }
end

function ShantyRadio.position(state: State, length: number, now: number): number?
	local t = math.max(0, now - state.startedAt)
	if length > 0 and t >= length then
		return nil
	end
	return t
end

function ShantyRadio.duck(operationMusic: boolean): number
	return if operationMusic then ShantyRadio.OPERATION_DUCK else 1
end

return ShantyRadio
