--!strict
-- VoiceManifest: NPC voice line id (assets/voice/lines.csv) -> Roblox audio asset id.
-- Empty until the ElevenLabs clips are generated and uploaded (assets/voice/tools/voice_pipeline.py
-- should write this file); until then Controllers/VoiceTTS speaks NPC lines with text-to-speech.
-- Never put toolbox or placeholder ids here: only our own uploaded clips.
--
--   Clips = { AGG_GREET_1 = "rbxassetid://1234567890", ... }
local VoiceManifest = {
	Clips = {} :: { [string]: string },
}

return VoiceManifest
