--!strict
-- VoiceTTS: NPC voices (people you talk to in person, casualties calling out) with Roblox
-- AudioTextToSpeech (docs/11 section 6). Never pass player-typed text. Cast presets: UI/VoiceCast.
--
--   VoiceTTS.say(text, castId, opts?) -> boolean   yields while speaking; false = not voiced (voice
--                                                  off, throttled, failed): the caller's subtitle carries it
--   VoiceTTS.speak(text, castId, opts?)            the same without yielding
--   VoiceTTS.stop(channel)                         cut what that channel is saying
--   VoiceTTS.enabled() -> boolean                  settings: "Voices" (Master.Radio.Voice) on
--   opts = { at: Instance?     a model or part: 3D from it (AudioEmitter, heard by a camera listener)
--            channel: string?  a new line on a channel cuts the old one (default the castId)
--            cancelled: (() -> boolean)? }
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local VoiceCast = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("VoiceCast"))

local VoiceTTS = {}

local RATE = 3 -- generations per second (the client limit is 4 per user)
local CACHE_MAX = 80
local GROUP = "VoiceTTS" -- AudioInteractionGroup: our emitters reach only our listener

local folder: Folder? = nil
local level: AudioFader? = nil
local listener: AudioListener? = nil
local cache: { [string]: AudioTextToSpeech } = {}
local cacheSize = 0
local loading: { [string]: boolean } = {}
local stamps: { number } = {}
local owner: { [string]: {} } = {}
local playing: { [string]: AudioTextToSpeech } = {}
local warned = false

local function wire(a: Instance, b: Instance, parent: Instance): Wire
	local w = Instance.new("Wire")
	w.SourceInstance = a
	w.TargetInstance = b
	w.Parent = parent
	return w
end

local function vol(path: { string }): number
	local inst: Instance? = SoundService
	for _, n in path do
		inst = inst and inst:FindFirstChild(n)
	end
	return if inst and inst:IsA("SoundGroup") then inst.Volume else 1
end

function VoiceTTS.enabled(): boolean
	return vol({ "Master", "Radio", "Voice" }) > 0
end

local function graph(): (Folder, AudioFader)
	local f, l = folder, level
	if f and l and f.Parent then
		return f, l
	end
	local nf = Instance.new("Folder")
	nf.Name = "VoiceTTS"
	local fader = Instance.new("AudioFader")
	fader.Name = "Level"
	fader.Parent = nf
	local out = Instance.new("AudioDeviceOutput")
	out.Parent = nf
	wire(fader, out, nf)
	nf.Parent = SoundService
	folder, level, listener = nf, fader, nil
	return nf, fader
end

-- the 3D ear: a listener on the camera, wired into the same level fader
local function hearing()
	local f, fader = graph()
	local cam = Workspace.CurrentCamera
	local l: AudioListener = listener or Instance.new("AudioListener")
	if not listener then
		l.Name = "VoiceTTSListener"
		l.AudioInteractionGroup = GROUP
		wire(l, fader, f)
		listener = l
	end
	if cam and l.Parent ~= cam then
		l.Parent = cam
	end
end

local function emitterOn(at: Instance): AudioEmitter?
	local part: Instance? = at
	if at:IsA("Model") then
		part = at:FindFirstChild("Head")
			or at.PrimaryPart
			or at:FindFirstChildWhichIsA("BasePart", true)
	end
	if not (part and (part:IsA("BasePart") or part:IsA("Attachment"))) then
		return nil
	end
	local e = part:FindFirstChild("VoiceEmitter")
	if e and e:IsA("AudioEmitter") then
		return e
	end
	local ne = Instance.new("AudioEmitter")
	ne.Name = "VoiceEmitter"
	ne.AudioInteractionGroup = GROUP
	ne:SetDistanceAttenuation({ [0] = 1, [30] = 0.8, [100] = 0.35, [220] = 0 })
	ne.Parent = part
	return ne
end

local function mixLevel(): number
	return vol({ "Master" }) * vol({ "Master", "Radio" })
end

local function resolve(text: string): { string }
	local line = VoiceCast.spoken(text)
	return if line then VoiceCast.chunks(line) else {}
end

-- One generated clip, cached by voice and text. nil when throttled or failed.
local function load(text: string, castId: string): AudioTextToSpeech?
	local key = castId .. "|" .. text
	local t0 = os.clock()
	while loading[key] and os.clock() - t0 < 8 do
		task.wait(0.05)
	end
	local hit = cache[key]
	if hit and hit.IsLoaded then
		return hit
	end
	local now = os.clock()
	while stamps[1] and now - stamps[1] > 1 do
		table.remove(stamps, 1)
	end
	if #stamps >= RATE then
		return nil
	end
	table.insert(stamps, now)
	local cast = VoiceCast.Cast[castId] or VoiceCast.Cast.PATROL
	local tts = Instance.new("AudioTextToSpeech")
	tts.Text = text
	tts.VoiceId = cast.voice
	tts.Pitch = cast.pitch
	tts.Speed = cast.speed
	tts.Parent = graph()
	loading[key] = true
	local ok, status = pcall(tts.LoadAsync, tts)
	loading[key] = nil
	if not (ok and status == Enum.AssetFetchStatus.Success) then
		if not warned then
			warned = true
			warn(`[VoiceTTS] text-to-speech failed ({status}); subtitles only`)
		end
		tts:Destroy()
		return nil
	end
	if cacheSize >= CACHE_MAX then
		-- shortcut: the whole cache goes when full; an LRU if common lines start re-generating
		local busy = {}
		for _, p in playing do
			busy[p] = true
		end
		for k, old in cache do
			if not busy[old] then
				old:Destroy()
			end
			cache[k] = nil
		end
		cacheSize = 0
	end
	cache[key] = tts
	cacheSize += 1
	return tts
end

function VoiceTTS.stop(channel: string)
	owner[channel] = nil
	local p = playing[channel]
	if p then
		p:Pause()
	end
end

function VoiceTTS.say(text: string, castId: string, opts: { [string]: any }?): boolean
	local o: { [string]: any } = opts or {}
	if not VoiceTTS.enabled() then
		return false
	end
	local pieces, cast = resolve(text), castId
	if #pieces == 0 then
		return false
	end
	local channel: string = o.channel or cast
	VoiceTTS.stop(channel)
	local token = {}
	owner[channel] = token
	local _, fader = graph()
	fader.Volume = mixLevel()
	local target: Instance = fader
	if o.at then
		local e = emitterOn(o.at)
		if e then
			hearing()
			target = e
		end
	end
	local function live(): boolean
		return owner[channel] == token and not (o.cancelled and o.cancelled())
	end
	local spoke = false
	for _, piece in pieces do
		-- shortcut: two channels saying the same cached line at once share one instance (rare)
		local tts = if live() then load(piece, cast) else nil
		if not (tts and live()) then
			break
		end
		local w = wire(tts, target, tts)
		playing[channel] = tts
		local done = false
		local conn = tts.Ended:Connect(function()
			done = true
		end)
		tts.TimePosition = 0
		tts:Play()
		spoke = true
		local len = (if tts.TimeLength > 0 then tts.TimeLength else #piece / 14) + 0.5
		local t0 = os.clock()
		while not done and os.clock() - t0 < len and live() do
			task.wait(0.05)
		end
		conn:Disconnect()
		tts:Pause()
		w:Destroy()
		if playing[channel] == tts then
			playing[channel] = nil
		end
	end
	if owner[channel] == token then
		owner[channel] = nil
	end
	return spoke
end

function VoiceTTS.speak(text: string, castId: string, opts: { [string]: any }?)
	task.spawn(VoiceTTS.say, text, castId, opts)
end

return VoiceTTS
