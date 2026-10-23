--!strict
-- RadioController: the VHF radio. An audio + subtitle queue with priorities and ducking, a radio
-- FX chain on Roblox's audio API, the template stitcher, push-to-talk and the Ops UI.
--
-- FX chain (per transmission): AudioPlayer (A/B, preloading the next fragment) -> AudioEqualizer
-- (band-pass ~300-3000 Hz) -> AudioDistortion (light) -> AudioFader (voice volume) ->
-- AudioDeviceOutput. Static (VoiceManifest.Sfx.Static) runs into the same EQ only while the
-- squelch is open, scaled by Weather.getIntensity(); squelch open/close clicks around each line.
-- Clips come only from src/shared/Config/VoiceManifest.luau; a line with any clip missing is spoken
-- by Roblox text-to-speech (VoiceTTS, into the same EQ), and as subtitles only if that fails or is
-- throttled (with squelch and static). Subtitles are always on.
--
-- API (other controllers and mechanics):
--   Radio.say(templateId, params?, opts?) -> Handle     Coastguard template (UI/RadioTemplates)
--   Radio.play(lineId, opts?) -> Handle                  one fixed lines.csv id ("AGG_DEBRIEF_GOLD")
--   Radio.sayText(from, text, opts?) -> Handle           free text (subtitles; voiced if it matches a line)
--   Radio.transmit(msg: RadioFormat.Message, opts?) -> Handle   the player's reply (player voice)
--   Radio.ptt(onTalk) -> disarm                     arm push-to-talk: hold R / DPadUp / the touch
--                                                   Radio button, release to send (onTalk fires)
--   Radio.callsign(): "HR11"|"HR21"|"HR31"            the player's unit
--   Radio.repeatLast()                                   "I say again" + the last Coastguard line
--   Radio.OnReply: { Connect(self, fn(msg)) }            every player transmission
--   opts = { priority: number?, from: string?, mode: "radio"|"intercom"?, interrupt: boolean?,
--            force: boolean? (skip the 180 s same-line repeat guard) }
--   Handle = { done: boolean, wait: (self) -> (), cancel: (self) -> () }
-- Ops_Radio payloads may carry { template, params } or { lineId } instead of plain text.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local UI = script.Parent.Parent:WaitForChild("UI")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local OpsController = require(script.Parent.OpsController)
local OpsHud = require(UI:WaitForChild("OpsHud"))
local RadioFormat = require(UI:WaitForChild("RadioFormat"))
local RadioLines = require(UI:WaitForChild("RadioLines"))
local RadioPanel = require(UI:WaitForChild("RadioPanel"))
local RadioStitch = require(UI:WaitForChild("RadioStitch"))
local RadioTemplates = require(UI:WaitForChild("RadioTemplates"))
local VoiceCast = require(UI:WaitForChild("VoiceCast"))
local VoiceManifest = require(Shared:WaitForChild("Config"):WaitForChild("VoiceManifest"))
local VoiceTTS = require(script.Parent.VoiceTTS)

-- Radio sfx: our own designed clips (VoiceManifest.Sfx) first, else the licensed stand-ins.
local RADIO_SFX_FALLBACK: { [string]: string } = {
	SquelchOpen = AudioConfig.id("Radio_SquelchOpen"),
	SquelchClose = AudioConfig.id("Radio_SquelchClose"),
	Static = AudioConfig.id("Radio_Static"),
	Key = AudioConfig.id("Radio_Key"),
}
local function radioSfx(name: string): string
	local own = VoiceManifest.Sfx[name]
	return if own and own ~= "" then own else RADIO_SFX_FALLBACK[name] or ""
end
local Weather = require(Shared:WaitForChild("Weather"))

type Line = RadioStitch.Line
export type Handle = { done: boolean, wait: (self: Handle) -> (), cancel: (self: Handle) -> () }
type Entry = {
	line: Line,
	speaker: string,
	mode: string,
	priority: number,
	at: number,
	handle: Handle,
	cancelled: boolean,
	onStart: (() -> ())?,
}

local P = RadioTemplates.Priority
local Radio = {}
Radio.Priority = 90 -- after OpsController (80)
Radio.Priorities = P

local player = Players.LocalPlayer
local queue: { Entry } = {}
local current: Entry? = nil
local panel: RadioPanel.Panel
local lastCoastguard: Line? = nil
local lastTransmitAt = os.clock()
local lastSitrepAsk = 0
-- The same radio/intercom line is voiced at most once per REPEAT_COOLDOWN: re-broadcasts (offer
-- refreshes, server loops) only refresh the subtitle. Player transmissions and "say again" are exempt.
local REPEAT_COOLDOWN = 180
local lastVoicedAt: { [string]: number } = {}

local replyListeners: { (any) -> () } = {}
Radio.OnReply = {
	Connect = function(_self: any, fn: (any) -> ())
		table.insert(replyListeners, fn)
		return {
			Disconnect = function()
				local i = table.find(replyListeners, fn)
				if i then
					table.remove(replyListeners, i)
				end
			end,
		}
	end,
}

---------------------------------------------------------------- audio graph

local fx: {
	folder: Folder,
	eq: AudioEqualizer,
	players: { AudioPlayer },
	static: AudioPlayer,
	staticFader: AudioFader,
	voiceFader: AudioFader,
	click: AudioPlayer,
}? =
	nil

local function wire(a: Instance, b: Instance, parent: Instance)
	local w = Instance.new("Wire")
	w.SourceInstance = a
	w.TargetInstance = b
	w.Parent = parent
end

local function buildAudio()
	local folder = Instance.new("Folder")
	folder.Name = "RadioFX"
	local eq = Instance.new("AudioEqualizer")
	eq.Name = "BandPass"
	eq.LowGain = -40
	eq.MidGain = 2
	eq.HighGain = -40
	eq.MidRange = NumberRange.new(300, 3000)
	eq.Parent = folder
	local dist = Instance.new("AudioDistortion")
	dist.Name = "Grit"
	dist.Level = 0.18
	dist.Parent = folder
	local voiceFader = Instance.new("AudioFader")
	voiceFader.Name = "Voice"
	voiceFader.Volume = 1
	voiceFader.Parent = folder
	local out = Instance.new("AudioDeviceOutput")
	out.Name = "Out"
	out.Parent = folder
	-- Master x Radio volume category; AudioController sets it from the SoundGroups
	local groupLevel = Instance.new("AudioFader")
	groupLevel.Name = "GroupLevel"
	groupLevel.Volume = 1
	groupLevel.Parent = folder
	wire(eq, dist, folder)
	wire(dist, voiceFader, folder)
	wire(voiceFader, groupLevel, folder)
	wire(groupLevel, out, folder)
	local players: { AudioPlayer } = {}
	for i = 1, 2 do
		local ap = Instance.new("AudioPlayer")
		ap.Name = "Fragment" .. i
		ap.Parent = folder
		wire(ap, eq, folder)
		players[i] = ap
	end
	local static = Instance.new("AudioPlayer")
	static.Name = "Static"
	static.Looping = true
	static.Asset = radioSfx("Static")
	static.Parent = folder
	local staticFader = Instance.new("AudioFader")
	staticFader.Name = "StaticLevel"
	staticFader.Volume = 0
	staticFader.Parent = folder
	wire(static, staticFader, folder)
	wire(staticFader, eq, folder)
	local click = Instance.new("AudioPlayer")
	click.Name = "Squelch"
	click.Parent = folder
	wire(click, eq, folder)
	folder.Parent = SoundService
	fx = {
		folder = folder,
		eq = eq,
		players = players,
		static = static,
		staticFader = staticFader,
		voiceFader = voiceFader,
		click = click,
	}
end

local function sfx(name: string)
	local f = fx
	local asset = radioSfx(name)
	if f and asset and asset ~= "" then
		f.click.Asset = asset
		f.click:Play()
	end
end

local function intensity(): number
	local ok, v = pcall(Weather.getIntensity)
	return if ok and type(v) == "number" then math.clamp(v, 0, 1) else 0
end

local squelchOpen = false
local function setSquelch(open: boolean)
	squelchOpen = open
	local f = fx
	if not f then
		return
	end
	if open and f.static.Asset ~= "" and not f.static.IsPlaying then
		f.static:Play()
	elseif not open and f.static.IsPlaying then
		f.static:Stop()
	end
end

-- Ducking: any AudioFader or SoundGroup tagged "RadioDuck" drops while a line plays.
local function duck(on: boolean)
	for _, inst in CollectionService:GetTagged("RadioDuck") do
		local base = inst:GetAttribute("RadioDuckBase")
		if inst:IsA("AudioFader") or inst:IsA("SoundGroup") then
			local target = inst :: any
			if on and base == nil then
				inst:SetAttribute("RadioDuckBase", target.Volume)
				target.Volume *= 0.35
			elseif not on and type(base) == "number" then
				target.Volume = base
				inst:SetAttribute("RadioDuckBase", nil)
			end
		end
	end
end

local function voiceOn(): boolean
	return VoiceTTS.enabled()
end

-- the cast member who speaks a line (lines.csv voice, else from the shown speaker name)
local function castOf(line: Line, speaker: string, mode: string): string
	return if VoiceCast.Cast[line.voice]
		then line.voice
		else VoiceCast.castFor(speaker, if mode == "intercom" then "CREW_FINN" else "CG_DAY")
end

---------------------------------------------------------------- speakers and lines

local SPEAKERS: { [string]: string } = {
	CG_DAY = "Gale Isles Coastguard",
	CG_NIGHT = "Gale Isles Coastguard",
	AGGIE = "Chief Aggie · Port Haven",
	HELI_PILOT = "Rescue Gale One",
	PATROL = "Haven Patrol",
	CREW_FINN = "Finn (crew)",
	CREW_DEE = "Dee (crew)",
	BARNABY = "The Optimist",
	DR_OSEI = "Dr Osei",
}

local function night(): boolean
	local t = Lighting.ClockTime
	return t < 6.5 or t > 19.5
end

local function stitchOpts(): RadioStitch.Options
	local g = player:GetAttribute("RadioVoice")
	return { night = night(), playerVoice = if g == "F" then "F" else "M" }
end

function Radio.callsign(): string
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	local id = model and (model:GetAttribute("VehicleId") or model.Name)
	local s = if type(id) == "string" then string.lower(id) else ""
	if string.find(s, "lifeboat") then
		return "HR31"
	elseif string.find(s, "rib") then
		return "HR21"
	end
	return "HR11"
end

local function newHandle(): Handle
	local h: any = { done = false }
	function h.wait(self: Handle)
		local t0 = os.clock()
		while not self.done and os.clock() - t0 < 60 do
			task.wait(0.05)
		end
	end
	function h.cancel(self: Handle)
		for i, e in queue do
			if e.handle == self then
				table.remove(queue, i)
				break
			end
		end
		local c = current
		if c and c.handle == self then
			c.cancelled = true
		end
		self.done = true
	end
	return h
end

---------------------------------------------------------------- queue

local pump: () -> ()

local function enqueue(line: Line, speaker: string, opts: { [string]: any }?): Handle
	local o: { [string]: any } = opts or {}
	local mode = o.mode or "radio"
	if mode ~= "tx" and not o.force then
		local last = lastVoicedAt[line.text]
		if last and os.clock() - last < REPEAT_COOLDOWN then
			if not current and #queue == 0 then
				panel.show(o.from or speaker, line.text, mode, RadioStitch.readSeconds(line.text))
			end
			if o.onStart then
				task.spawn(o.onStart)
			end
			local h = newHandle()
			h.done = true
			return h
		end
		lastVoicedAt[line.text] = os.clock()
	end
	local e: Entry = {
		line = line,
		speaker = o.from or speaker,
		mode = mode,
		priority = o.priority or P.Reply,
		at = os.clock(),
		handle = newHandle(),
		cancelled = false,
		onStart = o.onStart,
	}
	if string.sub(line.voice, 1, 3) == "CG_" and e.mode ~= "tx" then
		lastCoastguard = line
	end
	if voiceOn() and not RadioStitch.playable(line, VoiceManifest.Clips) then
		VoiceTTS.prefetch(line.text, castOf(line, e.speaker, e.mode))
	end
	-- a much more urgent line cuts in (a MAYDAY over chatter); the interrupted one is re-queued
	local c = current
	if c and (e.priority >= c.priority + 2 or o.interrupt) then
		c.cancelled = true
		if c.priority >= P.Reply then
			table.insert(queue, 1, {
				line = c.line,
				speaker = c.speaker,
				mode = c.mode,
				priority = c.priority,
				at = os.clock(),
				handle = c.handle,
				cancelled = false,
			})
		end
	end
	local pos = #queue + 1
	for i, q in queue do
		if e.priority > q.priority then
			pos = i
			break
		end
	end
	table.insert(queue, pos, e)
	task.defer(pump)
	return e.handle
end

-- Plays the clips back to back (A/B players, the next one preloading). Returns false if cut short.
local function playClips(e: Entry, assets: { string }): boolean
	local f = fx
	if not f then
		return false
	end
	local idx = 1
	f.players[1].Asset = assets[1]
	for i, asset in assets do
		if e.cancelled then
			return false
		end
		local ap = f.players[idx]
		local other = f.players[3 - idx]
		if ap.Asset ~= asset then
			ap.Asset = asset
		end
		local t0 = os.clock()
		while not ap.IsReady and os.clock() - t0 < 3 do
			task.wait()
		end
		if assets[i + 1] then
			other.Asset = assets[i + 1]
		end
		ap.TimePosition = 0
		ap:Play()
		local len = if ap.TimeLength > 0 then ap.TimeLength else 2
		local t1 = os.clock()
		while ap.IsPlaying and os.clock() - t1 < len + 0.5 do
			if e.cancelled then
				ap:Stop()
				return false
			end
			task.wait()
		end
		idx = 3 - idx
	end
	return true
end

-- No clips: text-to-speech through the same radio chain. False leaves it to the subtitle timer.
local function speakTts(e: Entry): boolean
	local f = fx
	return f ~= nil
		and VoiceTTS.say(e.line.text, castOf(e.line, e.speaker, e.mode), {
			into = f.eq,
			channel = "radio",
			cancelled = function()
				return e.cancelled
			end,
		})
end

local function playEntry(e: Entry)
	local line = e.line
	local voiced = voiceOn() and RadioStitch.playable(line, VoiceManifest.Clips)
	local radio = e.mode ~= "intercom"
	local seconds = RadioStitch.readSeconds(line.text)
	if e.onStart then
		task.spawn(e.onStart)
	end
	duck(true)
	if radio then
		setSquelch(true)
		sfx("SquelchOpen")
		task.wait(0.12)
	end
	panel.show(e.speaker, line.text, if e.mode == "tx" then "tx" else e.mode, seconds + 0.5)
	if voiced then
		local assets = {}
		for _, id in line.ids do
			table.insert(assets, VoiceManifest.Clips[id])
		end
		playClips(e, assets)
	elseif not (voiceOn() and speakTts(e)) then
		local t0 = os.clock()
		while os.clock() - t0 < seconds and not e.cancelled do
			task.wait(0.05)
		end
	end
	if radio then
		sfx("SquelchClose")
		setSquelch(false)
	end
	duck(false)
	if not e.cancelled then
		e.handle.done = true
	end
end

pump = function()
	if current then
		return
	end
	while #queue > 0 do
		local e = table.remove(queue, 1) :: Entry
		-- stale chatter is dropped instead of piling up
		if e.priority <= P.Chatter and os.clock() - e.at > 20 then
			e.handle.done = true
			continue
		end
		current = e
		local ok, err = pcall(playEntry, e)
		if not ok then
			warn(`[Radio] playback failed: {err}`)
			e.handle.done = true
		end
		current = nil
		task.wait(0.25) -- a breath between transmissions
	end
end

---------------------------------------------------------------- API

function Radio.say(templateId: string, params: { [string]: any }?, opts: { [string]: any }?): Handle
	local tpl = RadioTemplates.Templates[templateId]
	if not tpl then
		warn(`[Radio] unknown template {templateId}`)
		local h = newHandle()
		h.done = true
		return h
	end
	local p = table.clone(params or {})
	p.cs = p.cs or Radio.callsign()
	local line = RadioStitch.build(tpl.voice, tpl.tokens, p, stitchOpts())
	local o = table.clone(opts or {})
	o.priority = o.priority or tpl.priority
	return enqueue(line, SPEAKERS[line.voice] or "Gale Isles Coastguard", o)
end

function Radio.play(lineId: string, opts: { [string]: any }?): Handle
	local line = RadioStitch.build("CG", { "@" .. lineId }, nil, stitchOpts())
	local pre = string.match(lineId, "^(%u+)_")
	local voice = pre and RadioLines.Voices[pre]
	if voice then
		line.voice = voice
	end
	return enqueue(line, SPEAKERS[line.voice] or line.voice, opts)
end

-- Reverse index: Coastguard text -> suffix, so plain server text can be voiced when it matches.
local cgByText: { [string]: string } = {}
for suffix, text in RadioLines.Coastguard do
	cgByText[string.lower(text)] = suffix
end

function Radio.sayText(from: string, text: string, opts: { [string]: any }?): Handle
	local o = table.clone(opts or {})
	local suffix = if string.find(from, "Coastguard") then cgByText[string.lower(text)] else nil
	local line: Line
	if suffix then
		line = RadioStitch.build("CG", { suffix }, nil, stitchOpts())
	else
		line =
			{ voice = "TEXT", parts = { { text = text } }, text = text, ids = {}, complete = false }
		if string.find(from, "Coastguard") then
			line.voice = if night() then "CG_NIGHT" else "CG_DAY"
		end
	end
	if not o.priority then
		local up = string.upper(text)
		o.priority = if string.find(up, "MAYDAY")
			then P.Distress
			elseif string.find(up, "PAN%-PAN") then P.Tasking
			else P.Reply
	end
	if from == "Crew" then
		o.mode = o.mode or "intercom"
	end
	o.from = from
	return enqueue(line, from, o)
end

function Radio.transmit(msg: RadioFormat.Message, opts: { [string]: any }?): Handle
	local line = RadioStitch.build(
		"PL",
		RadioFormat.tokens(msg),
		RadioFormat.stitchParams(msg),
		stitchOpts()
	)
	local o = table.clone(opts or {})
	o.mode = "tx"
	o.priority = o.priority or P.Reply
	local own = RadioFormat.Callsigns[msg.from]
	lastTransmitAt = os.clock()
	sfx("Key")
	for _, fn in table.clone(replyListeners) do
		task.spawn(fn, msg)
	end
	return enqueue(line, own and own.full or "Haven Rescue", o)
end

function Radio.repeatLast(): Handle?
	local last = lastCoastguard
	if not last then
		return nil
	end
	-- the repeat alone: a separate "I say again." card showed with nothing before it (playtest)
	return enqueue(last, "Gale Isles Coastguard", { priority = P.Reply, force = true })
end

---------------------------------------------------------------- push-to-talk

-- The radio's own binding (R, gamepad DPadUp, a touch "Radio" button) exists only while a
-- mechanic has something to say; the crew voices the right reply on release.
local PTT = "RadioPTT"
local armed: (() -> ())? = nil

function Radio.ptt(onTalk: () -> ()): () -> ()
	armed = onTalk
	local held = false
	ContextActionService:BindAction(PTT, function(_name, inputState)
		if inputState == Enum.UserInputState.Begin then
			held = true
			sfx("Key")
		elseif inputState == Enum.UserInputState.End and held and armed == onTalk then
			held = false
			armed = nil
			ContextActionService:UnbindAction(PTT)
			onTalk()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle(PTT, "Radio")
	ContextActionService:SetPosition(PTT, UDim2.new(1, -170, 1, -230))
	local button = ContextActionService:GetButton(PTT)
	if button then
		button.Size = UDim2.fromOffset(72, 72)
	end
	return function()
		if armed == onTalk then
			armed = nil
			ContextActionService:UnbindAction(PTT)
		end
	end
end

---------------------------------------------------------------- lifecycle

function Radio.Init()
	local pg = player:WaitForChild("PlayerGui")
	panel = RadioPanel.new(pg)
	buildAudio()
	OpsController.OnRadio:Connect(function(r: { [string]: any })
		if type(r.template) == "string" then
			Radio.say(r.template, r.params)
		elseif type(r.lineId) == "string" then
			Radio.play(r.lineId)
		elseif type(r.text) == "string" then
			Radio.sayText(tostring(r.from or "Radio"), r.text)
		end
	end)
	OpsHud.mount(pg, OpsController, Radio)
end

function Radio.Start()
	-- static level follows the storm; signal bars drop; the Coastguard asks for a sitrep when quiet
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local storm = intensity()
		local f = fx
		if f then
			local vol = player:GetAttribute("VoiceVolume")
			f.voiceFader.Volume = if type(vol) == "number" then math.clamp(vol, 0, 2) else 1
			local target = if squelchOpen then 0.06 + 0.5 * storm else 0
			f.staticFader.Volume += (target - f.staticFader.Volume) * 0.5
		end
		panel.setSignal(1 - storm * 0.6)
		local s = OpsController.GetState()
		local now = os.clock()
		if
			s
			and not current
			and #queue == 0
			and now - lastTransmitAt > 150
			and now - lastSitrepAsk > 150
		then
			lastSitrepAsk = now
			Radio.say("sitrep_request")
		end
	end)
end

return Radio
