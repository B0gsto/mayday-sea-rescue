--!strict
-- VoiceManifest: voice line id (assets/voice/lines.csv) -> Roblox audio asset id.
-- Empty until the ElevenLabs clips are generated and uploaded (assets/voice/tools/voice_pipeline.py
-- should write this file). RadioController plays a stitched line only when every fragment of it
-- has a clip here; otherwise Controllers/VoiceTTS speaks it with Roblox text-to-speech, and it is
-- subtitles only (with the squelch and static) if TTS is off, throttled or fails.
-- Never put toolbox or placeholder ids here: only our own uploaded clips.
--
--   Clips = { CGD_OPEN_HR11 = "rbxassetid://1234567890", ... }
--   Sfx   = { SquelchOpen = "rbxassetid://...", SquelchClose = "rbxassetid://...",
--             Static = "rbxassetid://..." (a seamless 4-8 s loop of VHF hiss),
--             Key = "rbxassetid://..." (the player's press-to-talk click) }
local VoiceManifest = {
	Clips = {} :: { [string]: string },
	Sfx = {} :: { [string]: string },
}

return VoiceManifest
