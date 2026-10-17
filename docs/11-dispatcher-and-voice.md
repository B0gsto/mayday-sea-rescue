# 11 · Dispatcher and voice

The voiced radio for *Mayday: Sea Rescue*: who speaks, how calls are stitched from recorded fragments, how the radio sounds and behaves in game, what it costs to generate with ElevenLabs and how lines get from a CSV into Roblox. It builds on [document 09](09-rescue-operations.md), section 3 (radio procedure, the quick-reply wheel), [document 01](01-game-canon.md) (characters and places) and [document 10](10-world-and-map.md) (place names). Research date for every price and limit below: **2026-10-17**.

Files:

| File | What it is |
|---|---|
| `assets/voice/lines.csv` | Every line and fragment (generated, committed). Columns: `id, voice, category, position_variant, text, notes` |
| `assets/voice/tools/build_lines.py` | **Source of truth** for the script. Edit the tables here, then run it to rebuild `lines.csv` |
| `assets/voice/tools/count_chars.py` | Line and character counts (section 4) |
| `assets/voice/tools/voice_pipeline.py` | `generate`, `normalise`, `pack`, `upload` (section 5) |
| `assets/voice/voices.json` | To create once voices are chosen: voice name → ElevenLabs `voice_id` and settings. No secrets |
| `assets/voice/manifest.json` | Written by the pipeline: bank asset IDs and every clip's start and end time |

Voice is **optional and off by default**, as [document 09](09-rescue-operations.md), section 3.5 says: text in the radio log and crackle are always on; the voice toggle and its volume live in settings. Everything here must therefore degrade to subtitles without losing gameplay (section 6).

## 1. The cast

All voices are made with **ElevenLabs Voice Design** (a voice generated from a text description) rather than cloned, so no real person's voice is imitated. Voice Library voices are acceptable only if their library terms allow commercial use (verify per voice). Accents are North Atlantic coast, mixed on purpose: the Gale Isles are invented and their people came from all round that sea.

Settings use the ElevenLabs API names: `stability` (higher is steadier and flatter), `similarity_boost` (closeness to the designed voice), `style` (exaggeration), `speed`. Model: `eleven_multilingual_v2` for everything, because it supports the `previous_text`/`next_text` continuity the fragments rely on (section 2.6). `eleven_v3` (out of alpha in 2026, according to secondary sources) is better at emotion and inline tags such as `[shouting]`; try it only for the FULL caller lines in distress, and check that it accepts `previous_text` before using it for fragments (verify).

| Voice id | Who | Age, sex | Accent | Tone and brief | stability / similarity / style / speed |
|---|---|---|---|---|---|
| `CG_DAY` | **Gale Isles Coastguard, day watch** (watch officer Morag Sinclair, never named on air) | 40s, F | Hebridean Scottish, soft and clear | The calm centre of every call. Unhurried, precise, warm only at the stand-down. Every word lands; no drama even in a MAYDAY RELAY. Slight radio-operator cadence: pauses at commas, crisp final consonants. | 0.72 / 0.80 / 0.05 / 0.95 |
| `CG_NIGHT` | **Gale Isles Coastguard, night watch** (watch officer Tom Penrose) | 50s, M | Cornish, low and even | Deeper, slower, a little gravel. Same procedure words, same calm. Night shift sounds like a man with a flask of tea and all night to get it right. | 0.72 / 0.80 / 0.05 / 0.93 |
| `AGGIE` | **Chief Agnes "Aggie" Brightwater** on the station set | 60s, F | Cornish, broad but clear | Retired coxswain. Warm, dry, never flustered; the joke is in the understatement. Teaches in short sentences. "Kettle's on. Go get them." | 0.55 / 0.80 / 0.20 / 1.0 |
| `CREW_FINN` | NPC crew **Finn** | 20s, M | Galway Irish | Keen, quick, a bit chatty, calm when it matters. Callouts are loud and short. | 0.45 / 0.75 / 0.25 / 1.05 |
| `CREW_DEE` | NPC crew **Dee** | 30s, F | Maine (Down East) | Dry, practical, unimpressed by weather, kind under it. Callouts flat and certain. | 0.50 / 0.75 / 0.20 / 1.0 |
| `PLAYER_M` / `PLAYER_F` | The player character's radio replies (optional, chosen in settings: male, female or off) | 20s to 30s | Light, neutral coastal (soft Northern Irish for M, soft Scottish Lowland for F) | A trained volunteer: clear, slightly quick, procedure first. Must not sound like a hero or a narrator; it is the player's voice and has to fit anyone. | 0.62 / 0.80 / 0.10 / 1.0 |
| `BARNABY` | **Barnaby Puddleford**, *The Optimist* | 60s, M | Devon, rolling | Cheerful, embarrassed, never frightened. The game's light relief. | 0.40 / 0.75 / 0.45 / 1.0 |
| `LOU` | **Captain Lou Marlow**, ferry *Gale Queen* | 50s, M | Newfoundland | Professional under pressure: tight, breathy urgency in the MAYDAY, but in control. Never screams. | 0.40 / 0.80 / 0.35 / 1.05 |
| `HAZEL` | **Hazel Crumb**, ferry ticket booth | 70s, F | Fife Scottish | Chatty, fond, slightly lost with radio buttons. | 0.45 / 0.75 / 0.40 / 1.0 |
| `PATROL` | **Haven Patrol** harbour officer | 40s, M | Maine | Easy-going professional, short transmissions. | 0.65 / 0.80 / 0.10 / 1.0 |
| `INFORMANT_M` | Beach informant (tourist on the phone or pointing) | 30s, M | Dublin Irish | Worried, out of breath, trying to be useful. | 0.35 / 0.75 / 0.40 / 1.1 |
| `PARENT_F` | Worried parent on the phone | 40s, F | Cork Irish | Frightened but holding it together; relief at the end. Never sobbing. | 0.35 / 0.75 / 0.40 / 1.05 |
| `TEEN_M` | Teenage paddleboarder or kayaker | about 16, M | Cornish | Out of breath, embarrassed, then excited. Voiced as 16, never younger. | 0.40 / 0.75 / 0.35 / 1.05 |
| `CASUALTY_M` / `CASUALTY_F` | Casualties in the water, ferry passengers, the two in the air pocket | 30s M / 50s F | Northern Irish / Maine | Tired, cold, scared, then grateful. Realistic but never graphic: no screams of pain, no choking sounds, no death. Cold is shown by short breaths and short words. | 0.30 / 0.75 / 0.45 / 1.0 |
| `DR_OSEI` | **Dr. Priya Osei**, Cottage Hospital | 40s, F | British, Ghanaian heritage, 20 years in Port Haven | Brisk, reassuring, thanks crews precisely. | 0.65 / 0.80 / 0.15 / 1.0 |
| `HELI_PILOT` [L] | Pilot of ***Rescue Gale One*** | 40s, M | Shetland | Clipped, very calm, one-word acknowledgements to the winch operator's conning calls. | 0.75 / 0.80 / 0.05 / 1.0 |

Not voiced yet (text only): Tobias Wick, Vance Sterling, Nell Tackle, Skipper Ingrid Hale and the Tran twins. They are the next voices to add when their content ships ([document 01](01-game-canon.md), section 5).

**Which watch is on.** `CG_DAY` speaks while the server's lighting clock is between 06:00 and 20:00, `CG_NIGHT` otherwise. The switch only happens between calls, never inside one, and plays the matching shift-handover chatter line. Every Coastguard line exists in both voices.

## 2. The stitching grammar

Most Coastguard calls change every time (who, where, how far, how many), so they are built from **fragments** joined at runtime. Fixed story lines (Aggie, callers, the onboarding MAYDAY) are recorded whole.

### 2.1 Position variants

Every fragment is recorded in the sentence position it is used in, because a word at the end of a sentence falls in pitch and a word in the middle does not:

| Variant | Used | Pitch | Example |
|---|---|---|---|
| `S` | Opens a sentence | Fresh onset, continuing | "**Sandy Point**, informant reports…" |
| `M` | Middle | Level, continuing, no final drop | "…south of **Sandy Point**, informant reports…" |
| `E` | Closes a sentence | Falling, full stop | "…three hundred metres south of **Sandy Point**." |
| `FULL` | A whole line | Natural | "Roger, out." |

Places and callsigns have S, M and E; numbers, minutes, letters and casualty states have M and E; directions, distances and descriptors (always mid-sentence) have only M.

### 2.2 The fragment sets

| Set | Category in the CSV | Contents |
|---|---|---|
| **Callsigns** | `callsign` | *Haven Rescue One-One* (jet ski), *Two-One* (RIB), *Three-One* (lifeboat), *Haven Patrol*, *Gale Queen*, *Optimist*, *Port Haven Lifeboat Station*; [L] *Rescue Gale One*, *Rescue Gale Two*, *Northern Dawn*. Each also has a whole call opener ("Haven Rescue Two-One, Haven Rescue Two-One, this is Gale Isles Coastguard.") and a short form ("Two-One, Coastguard.") |
| **Priority words** | `priority` | MAYDAY RELAY, PAN-PAN, SECURITE, SEELONCE MAYDAY, SEELONCE FEENEE, "Received Mayday", the upgrade to Mayday ([document 09](09-rescue-operations.md), section 3.2) |
| **Operation types** | `optype` | One or two persons in the water, engine failure, out of fuel, fouled propeller, aground, drifting without power; [L] capsized dinghy, taking on water, fire, person overboard, parent and child adrift, cut off by the tide, seal in a net, climber on a ledge |
| **Places** | `place` | Every named place in documents 01, 09 and 10. [MVP]: Port Haven, Port Haven harbour, the harbour mouth, the harbour wall, the harbour approaches, the ferry pier, the station slipway, the hospital pontoon, the Cottage Hospital, the fish market quay, the fuel dock, Sandy Point, Harbor Light, Calm Bay, Haven Sands, the Bar (the sandbar), Haven Head, the lifeguard tower. [L]: the Skerries, Skerry Isle, Skerry Light, the Skerry Isle outpost, the kelp beds, the sea caves, the ferry lane, Gannet Rock, Gannet Rock Light, the Gannet Rock outpost, Tempest Point, Tempest Point Light, the cliffs below Tempest Point, Wreckers' Cove, Gull Cove, Kittiwake Cliffs, Long Strand, Westgate slipway, Puffin Isle, the Saltings. ([P1] Northlight and North Quay are left out.) *Harbor Light* keeps the canon spelling as a proper name; all other text uses British "harbour", as document 09 does. *Sandy Point* is used by document 09's onboarding but not yet placed on document 10's map (open issue) |
| **Directions** | `direction` | The eight compass points + "of" ("south-west of"), plus off, just outside, inside, near, at, close to |
| **Distances** | `distance` | Fifty, one hundred, two hundred, three hundred, four hundred, five hundred, eight hundred metres, one kilometre, half a mile; [L] one, two, three, five miles. Metres inside Calm Bay (document 09's example), miles beyond it |
| **Numbers** | `number` | One to forty, M and E (POB counts, manifest tallies: the ferry's 14 plus at least one per player) |
| **Digits** | `digit` | Zero to "niner", for bearings and times, read digit by digit |
| **Minutes** | `minutes` | One to forty minutes (time in the water, ETAs) |
| **Phonetic alphabet** | `phonetic` | Alfa to Zulu, M and E, ICAO spellings (Alfa, Juliett). Used for search sectors, hull compartments, and spelling a name |
| **Casualty** | `cas_desc`, `cas_kit`, `cas_state`, `condition` | An adult, older or teenage swimmer, a paddleboarder, an angler fallen from the rocks, a kayaker, a person swept off the sandbar; no lifejacket, wearing a lifejacket or buoyancy aid, holding on to a board; waving or shouting for help, tiring, struggling, not moving much, no longer answering, caught in a rip; condition read-backs (alert; cold and shivering, talking; drowsy, not shivering; unresponsive, breathing; not breathing normally, CPR in progress). Plain words, nothing graphic |
| **Weather** | `wind_dir`, `wind_strength`, `sea_state` | Wind north … north-west, variable; light, moderate, fresh, strong, gale force, force four to force ten; sea calm, slight, moderate, rough, very rough; visibility good, moderate, poor; showers, heavy rain |
| **Stems** | `stem` | The glue: "Launch to a report of", "Proceed with all speed to", "Position", "Informant on the beach reports", "about", "in the water.", "persons on board.", "Wind", "drifting towards", "Datum is on your chart.", "Last seen … ago.", "search sector", "compartment", "ETA", "bearing … degrees.", "… of … persons accounted for.", "Copy,", "you are On Scene Coordinator.", "Gale warning for the Gale Isles.", "increasing", "imminent.", "Over.", "Out." |
| **Acknowledgements** | `tasking` | Roger; Roger, out (two takes); Copied, out; Say again your ETA / POB; Request situation report; stand-downs (three takes) |

The player voices have their own smaller set: their unit's callsign (E), numbers one to twenty, minutes one to twelve, letters Alfa to Foxtrot, and "Gale Isles Coastguard," (S). Crew have clock bearings ("two o'clock,", M) and ranges ("a hundred metres!", E).

### 2.3 How numbers are spoken

Radio practice, matched to [document 09](09-rescue-operations.md), section 3.4 and the research notes ([research](research/rescue-procedures.md), 1d; verify: ITU-R M.1171):

| Kind | Rule | Example |
|---|---|---|
| POB and counts | Whole number | "fourteen persons on board", "nine of fourteen persons accounted for" |
| Distances | Whole number + unit | "three hundred metres south of Sandy Point", "half a mile east of the harbour mouth" |
| Bearings | Three digits, digit by digit, then "degrees" | "bearing two four zero degrees" |
| Times of day | Four digits, digit by digit | "last seen one four three zero" |
| Durations and ETAs | Whole minutes | "about ten minutes in the water", "ETA four minutes" |
| Nine | "niner" when read as a digit; "nine" in a whole number | "bearing zero niner zero", "nine of fourteen" |
| Letters | ICAO phonetic | "search sector Bravo", "compartment Charlie" |

ElevenLabs text normalisation is turned off (`apply_text_normalization: off`): every number is already written as words in the CSV.

### 2.4 Templates

A template is a list of slots. `{set:value|V}` picks a fragment from a set in variant V; plain names are stems. The server fills the values; the client turns them into clip IDs (`CGD_PLACE_SANDY_POINT_E`, or `CGN_…` at night).

```
PIW_TASKING   = {open:unit} {stem:LAUNCH_TO} {optype:op|M} {distance:d|M} {direction:dir|M} {place:p|E}
                {stem:INFORMANT_BEACH} {cas_desc:who|M} {cas_kit:kit|M} {cas_state:state|E}
                {stem:WIND} {wind_dir:w|M} {wind_strength:f|E} {stem:OVER}
DV_TASKING    = {open:unit} {priority:PANPAN_RECEIVED} {stem:INFORMANT_VESSEL} {optype:op|M}
                {direction:dir|M} {place:p|E} {number:pob|M} {stem:PERSONS_ON_BOARD}
                [{stem:DRIFTING_TOWARDS} {place:hazard|E}] {stem:OVER}
STORM_WARNING = {priority:SECURITE} {open:ALL_STATIONS} {stem:GALE_WARNING} {stem:WARNING_WIND}
                {wind_dir:w|M} {stem:INCREASING} {wind_strength:f|M} {stem:IMMINENT}
                {storm:SEA_ROUGH} {storm:HARBOUR_MOUTH_WARN} {storm:SMALL_CRAFT}
FERRY_RELAY   = {priority:MAYDAY_RELAY} {open:ALL_STATIONS} {priority:MAYDAY_RELAY}
                {ferry:FERRY_CAPSIZE} {ferry:FERRY_POB} {number:manifest|E} {ferry:FERRY_DETAIL}
                {ferry:FERRY_REQUEST} … then {priority:SEELONCE_MAYDAY}, {ferry:ALL_UNITS_LAUNCH}
OSC_ASSIGN    = {callsign:unit|S} {stem:TAKE} {stem:SECTOR} {phonetic:sector|E} {stem:OVER}
TALLY         = {number:found|M} {stem:OF} {number:manifest|M} {stem:ACCOUNTED_FOR}
SITREP_ACK    = {short:unit} {stem:COPY} {number:n|M} {stem:RECOVERED} {condition:c|E} {tasking:AMB_SLIPWAY} {stem:OUT}
PLAYER_ETA    = {frag:COASTGUARD} {callsign:unit|E} {passage:ETA} {minutes:eta|E} {frag_end:OVER}
CREW_SIGHTED  = {callout:CASUALTY} {clock:dir|M} {range:d|E}
```

**Joining.** Between fragments of one phrase: 40 ms; at a comma: 140 ms; at a full stop: 300 ms; between the call opener and the body: 400 ms (tune). Each clip is already trimmed to 40 ms of air on each side (section 5). Subtitles are the same fragments' `text` joined with single spaces, with a capital after each full stop.

### 2.5 Full stitched examples

1. **Person in the Water, standard (day watch).**
   `CGD_OPEN_HR21` + `CGD_STEM_LAUNCH_TO` + `CGD_OPTYPE_PIW1_M` + `CGD_DISTANCE_D200_M` + `CGD_DIRECTION_NORTH_EAST_OF_M` + `CGD_PLACE_HAVEN_SANDS_E` + `CGD_STEM_INFORMANT_BEACH` + `CGD_CAS_DESC_PADDLEBOARDER_M` + `CGD_CAS_KIT_LJ_M` + `CGD_CAS_STATE_TIRING_E` + `CGD_STEM_WIND` + `CGD_WIND_DIR_WEST_M` + `CGD_WIND_STRENGTH_MODERATE_E` + `CGD_STEM_OVER`
   > "Haven Rescue Two-One, Haven Rescue Two-One, this is Gale Isles Coastguard. Launch to a report of one person in the water, two hundred metres north-east of Haven Sands. Informant on the beach reports a paddleboarder, wearing a lifejacket, tiring quickly. Wind west, moderate. Over."
2. **Player acknowledgement and ETA (female player voice).**
   > "Gale Isles Coastguard, Haven Rescue Two-One. ETA four minutes. Over." (`PLF_FRAG_COASTGUARD` + `PLF_CALLSIGN_HR21_E` + `PLF_PASSAGE_ETA` + `PLF_MINUTES_M04_E` + `PLF_FRAG_END_OVER`)
3. **Disabled Vessel (night watch).**
   > "Haven Rescue Three-One, Haven Rescue Three-One, this is Gale Isles Coastguard. Received pan-pan. The vessel reports a motor boat with engine failure, just outside the harbour mouth. Two persons on board, drifting towards the harbour wall. Over."
   Then, if the drift reaches the rocks line: "Be advised, this is now a Mayday situation. The vessel is close to the rocks. Take the crew off, I say again, take the crew off. Over."
4. **Storm warning.**
   > "Securite, securite, securite. All stations, all stations, all stations, this is Gale Isles Coastguard, Gale Isles Coastguard. Gale warning for the Gale Isles. Wind south-west, increasing force eight, imminent. Sea state rough, becoming very rough. Expect breaking seas at the harbour mouth. All small craft are advised to return to harbour or make ready for heavy weather. Out."
5. **Ferry big call, scene work.**
   > "Haven Rescue Two-One, take search sector Bravo. Over." … "Nine of seventeen persons accounted for." … "All persons accounted for. All units, stand down. Good work, everyone. Out." + "Seelonce feenee. Seelonce feenee. Normal working may resume on this channel."
6. **Crew lookout (intercom).** "Casualty, two o'clock, a hundred metres!" (`FIN_CALLOUT_CASUALTY` + `FIN_CLOCK_CLK02_M` + `FIN_RANGE_D100_E`)

### 2.6 Keeping prosody natural

1. **Record in position** (section 2.1). The `notes` column carries `ctx_prev=` and `ctx_next=`, which the pipeline sends as ElevenLabs `previous_text` and `next_text`, so a fragment is spoken as if it sat inside a real sentence ("…three hundred metres south of" before an E place). The context is not spoken, only the fragment.
2. **Fixed seed per line** so a regenerated line stays close to its old take; two takes per line, the better one picked by ear (`picks.json`).
3. **Same settings for all of a voice's fragments**; never mix models inside one voice.
4. **Fragments end on word boundaries with their own punctuation** (E fragments carry the full stop, so they fall).
5. **Coastguard pace is deliberately even**, which hides joins: radio operators really do speak in measured chunks.
6. **The radio filter helps.** Band-limiting and light distortion (section 3.3) mask small timbre jumps between fragments.
7. **Listening test before shipping:** generate 30 random stitched calls per voice with a script and have a reviewer flag bad joins; regenerate those fragments with a different seed or a better context.

## 3. Runtime system

### 3.1 Architecture

- **Server** (`RadioService`): decides every transmission from game state (tasking, sitrep prompts, storm phases, scene board) and sends a **call spec** to the clients concerned: `{templateId, slots, priority, channel, speaker, unit, sceneId, issuedAt}`. The radio log is server-authoritative text, so it works with voice off.
- **Client** (`RadioPlayer`): resolves the template to clip IDs through `manifest.json` (bank asset, start, end), queues and plays them, and shows subtitles. Voice is client-side only, so each player hears it with their own settings and no audio replicates.
- **Playback.** One `AudioPlayer` per loaded bank pair, using `PlaybackRegion` (start and stop time in seconds within the asset) to play one clip from a bank; `Ended` fires when the region finishes, which starts the next fragment. Two players per bank alternate ("ping-pong") so the next clip is already seeked when the last one ends ([AudioPlayer](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer)). Banks are preloaded at join (Coastguard of the current watch, the chosen player voice, crew) and on demand (callers when their operation starts); `IsReady` is checked before a call starts, and if the bank is not ready the call goes text-only (section 6).

### 3.2 Priority queue

There is one radio channel per player (simplex: one speaker at a time, as on marine VHF). Intercom (crew) and 3D voices (casualties, informants) are separate and can overlap the radio.

| Priority | What | Rule |
|---|---|---|
| **P0 Distress** | MAYDAY, MAYDAY RELAY, SEELONCE, the storm SECURITE | Interrupts anything at the next fragment boundary: the current call ends with a squelch tail and "break" gap (400 ms). Never dropped |
| **P1 Own tasking** | Taskings and replies for the player's own unit, sitrep requests | Waits for P0, interrupts P2 and P3 at a boundary. Never dropped; "Say again" replays it from the log |
| **P2 Scene traffic** | Other units' traffic in the same operation, OSC assignments, tallies | Queued; dropped if older than 10 s (the log keeps it) |
| **P3 Chatter** | Free-roam chatter, other units' routine traffic, Hazel | Only when the queue is empty, the player is not in a timed step, and none for 20 s after the last transmission. Dropped if older than 6 s |

The player's own reply (wheel) is queued as P1 and **waits for the Coastguard to finish**; the game never talks over itself. The wheel itself is usable at once, the voice just follows.

### 3.3 Radio effects chain

Built with the audio API instances and `Wire`s ([audio effects](https://create.roblox.com/docs/audio/effects), [AudioFilter](https://create.roblox.com/docs/reference/engine/classes/AudioFilter), [AudioDistortion](https://create.roblox.com/docs/reference/engine/classes/AudioDistortion), [AudioCompressor](https://create.roblox.com/docs/reference/engine/classes/AudioCompressor)):

```
AudioPlayer (voice bank) ─┐
AudioPlayer (static loop) ─┤→ AudioFilter Highpass12dB 300 Hz, Q 0.707
AudioPlayer (squelch sfx) ─┘   → AudioFilter Lowpass12dB 3000 Hz, Q 0.707
                               → AudioFilter Peak 1800 Hz, +3 dB, Q 1.0   (VHF presence)
                               → AudioDistortion Level 0.12 to 0.35       (scaled, below)
                               → AudioCompressor Threshold -20 dB, Ratio 4, Attack 0.005, Release 0.15
                               → AudioFader "RadioVolume" (settings slider)
                               → AudioDeviceOutput   (2D, the player's handset)
                                 or AudioEmitter on the boat's or station's radio set (3D, when off the boat)
```

- **Squelch.** A short open click plus a 120 ms burst of noise before each transmission and a 180 ms "kssh" tail after it (sound effects, not ElevenLabs lines; no roger beep, marine VHF does not use one).
- **Static by distance and storm.** A looping band-passed noise bed plays only while a transmission is open. Its level is `-34 dB + 10 dB × (distance / map radius) + 8 dB in a Storm phase + 4 dB behind Haven Head or a cliff (tune)`; distortion rises with the same factor from 0.12 to 0.35. Speech must stay readable at the worst value: cap the noise at 12 dB below the voice.
- **Station set.** Aggie's lines use the same chain but a wider band (200 to 4000 Hz) and less distortion: a good base-station set.
- **Not filtered:** crew intercom (a light high-pass at 120 Hz and the boat's wind noise only), casualties and informants (3D `AudioEmitter` on the character with distance attenuation), Dr. Osei at the pontoon.

### 3.4 Ducking

The radio bus feeds the **Sidechain** pin of an `AudioCompressor` on the music bus (Threshold -35 dB, Ratio 6, Attack 0.01 s, Release 0.5 s: about -8 dB on music) and of a second compressor on the ambience bus (about -4 dB on sea and wind) ([AudioCompressor](https://create.roblox.com/docs/reference/engine/classes/AudioCompressor) supports sidechain input). The crew intercom bus ducks the radio by about -4 dB the same way, so "Neutral! Neutral now." always cuts through.

### 3.5 Subtitles and the radio log

- Every transmission appears in the radio log (callsign tag, time, text) whether voice is on or off; the current line also shows as a subtitle above the wheel, timed to each fragment's start.
- Speaker colours: Coastguard white, the player's unit blue, Aggie amber, callers grey, crew green (match [document 05](05-art-direction.md) when its UI palette is set).
- The text is the CSV `text`, never the `say=` pronunciation (so "Securite" not "Say-cure-ee-tay").
- Localisation: subtitles go through a `LocalizationTable` keyed by clip ID, so a translated call is assembled from translated fragments. Voice stays English at launch.

### 3.6 Player voice on the reply wheel

- Settings: **Reply voice: Off / Male / Female** (default Off; voice lines master toggle must be on).
- The wheel label stays short ("Copy, launching"); the full stitched line is spoken and logged ("Gale Isles Coastguard, Haven Rescue Two-One. Copy, launching. Over.").
- In co-op only the Navigator/Radio seat speaks on the radio; every client hears that player's choice of voice. The calm words to a panicking casualty ("I've got you", "Grab the float") are spoken by the swimmer as a 3D voice, not on the radio.

### 3.7 Avoiding repetition

- **Takes and alternates.** Frequent lines have alternates in the CSV (`ROGER_OUT` / `ROGER_OUT_2`, three stand-downs, two "eyes on", crew "good job" pairs). The picker never repeats the last pick of a pool (pools of 3 or more: none of the last two).
- **Chatter cooldown.** Each chatter line at most once per 20 minutes per player; at most one chatter exchange every 90 to 150 s, randomised, On watch only.
- **Variety from the grammar.** Places, distances, casualties and wind change every call, so a tasking rarely sounds the same twice.
- **Two watches.** The day and night Coastguard voices halve the repetition across a long session.
- **Debrief tips** come from Aggie only for the weakest step, and the same tip is not voiced twice in a row (text still shows).

## 4. Line counts, characters and cost

Computed by `assets/voice/tools/count_chars.py` on `lines.csv` (2026-10-17). Billable characters are the `say=` override where present, otherwise `text`.

| Scope | Lines | Characters |
|---|---|---|
| [MVP] | 1,570 | 40,455 |
| [L] | 245 | 5,770 |
| **Total** | **1,815** | **46,225** |

| Voice | MVP lines / chars | [L] lines / chars |
|---|---|---|
| CG_DAY | 502 / 11,127 | 94 / 2,066 |
| CG_NIGHT | 502 / 11,127 | 94 / 2,066 |
| AGGIE | 79 / 4,925 | 4 / 285 |
| PLAYER_M | 118 / 2,024 | 16 / 238 |
| PLAYER_F | 118 / 2,024 | 16 / 238 |
| CREW_DEE | 73 / 1,790 | 0 |
| CREW_FINN | 73 / 1,772 | 0 |
| BARNABY | 20 / 1,441 | 0 |
| LOU | 8 / 726 | 1 / 68 |
| HAZEL | 9 / 673 | 0 |
| CASUALTY_M, CASUALTY_F | 19 / 552 each | 0 |
| PATROL | 8 / 528 | 0 |
| DR_OSEI | 9 / 497 | 0 |
| INFORMANT_M | 5 / 277 | 0 |
| PARENT_F | 4 / 196 | 1 / 88 |
| TEEN_M | 4 / 224 | 1 / 42 |
| HELI_PILOT | 0 | 18 / 679 |

The context strings (`previous_text`/`next_text`) add up to 54,564 characters. ElevenLabs bills the `text` field; whether context is billed is not stated on the pricing page (verify on the first batch by comparing the credit counter before and after).

Estimated audio: about **64 minutes** in total at radio pace, including 0.35 s gaps.

**ElevenLabs prices** ([pricing](https://elevenlabs.io/pricing), read 2026-10-17): Free $0, 10,000 credits, **no commercial licence**; Starter $6/month (30,000 credits); **Creator $22/month (121,000 credits**, 192 kbps MP3; first month shown at $11 in a promotion that ends 2026-10-18); Pro $99 (600,000 credits, adds 44.1 kHz PCM/WAV via the API); Scale $299 (1.8M); Business $990 (6M). Multilingual v2 costs **1 credit per character**; Flash/Turbo models 0.5 to 1 credit per character on the API. Audio made **while on a paid plan can be used commercially indefinitely**, even after cancelling; free-plan audio never can ([ElevenLabs help: publishing generated content](https://help.elevenlabs.io/hc/en-us/articles/13313564601361)).

**Credit estimate.**

| Item | Credits |
|---|---|
| All lines, two takes each (46,225 × 2) | 92,450 |
| Reserve for regenerating bad joins and fixes (15%) | 6,934 |
| **Total** | **about 99,400** |

**Recommendation: one month of Creator ($22, or $11 if bought before the 2026-10-18 promotion ends)**, which covers the whole script with two takes and about 21,000 credits left over. Generate everything inside that month, keep the invoice and the generation dates as proof of the commercial licence, then drop to Starter ($6) for later fixes or cancel. Starter alone (30,000) does not cover even one take of the script. Pro is not needed: 192 kbps MP3 is plenty for a band-limited radio voice, which is re-encoded to OGG anyway. If context turns out to be billed, generate one take for fragments and two only for FULL lines (about 75,000 credits plus context: still one Creator month plus a top-up, or two months).

## 5. Production pipeline

```
build_lines.py ─→ lines.csv ─→ generate ─→ build/raw/*.mp3 ─→ pick takes (picks.json)
   ─→ normalise ─→ build/norm/*.wav ─→ pack ─→ build/banks/*.ogg + manifest.json
   ─→ upload (Open Cloud) ─→ manifest.json assetIds ─→ ReplicatedStorage VoiceManifest module
```

1. **Script.** Edit `assets/voice/tools/build_lines.py`, run `python3 -I build_lines.py`, review the diff of `lines.csv`. IDs are stable (`CGD_PLACE_SANDY_POINT_E`), so code and the manifest never break when lines are added.
2. **Voices.** Design each voice in ElevenLabs Voice Design from the brief in section 1, save its `voice_id` and settings into `assets/voice/voices.json` (`{"CG_DAY": {"voice_id": "…", "model_id": "eleven_multilingual_v2", "settings": {"stability": 0.72, "similarity_boost": 0.8, "style": 0.05, "use_speaker_boost": true, "speed": 0.95}}, …}`).
3. **Generate.** `ELEVENLABS_API_KEY=… python3 -I voice_pipeline.py generate --scope MVP --takes 2`. The script reads the key **only from the environment** (never hardcode it or commit it; use a key restricted to text-to-speech). It calls `POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_192` with the `xi-api-key` header, `text` (or `say=`), the voice settings, a fixed seed per line and take, `apply_text_normalization: off`, and `previous_text`/`next_text` from the notes ([API reference](https://elevenlabs.io/docs/api-reference/text-to-speech/convert)). Existing files are skipped, so a crashed run resumes. It retries on 429 and 5xx with backoff.
4. **Pick.** Listen (a batch listening page or a quick script that plays each pair) and write the better take number into `picks.json` (default take 1).
5. **Normalise.** `voice_pipeline.py normalise`: ffmpeg trims edge silence to 40 ms pads, converts to mono 48 kHz, and normalises loudness to **-18 LUFS integrated, -1.5 dBTP** (dialogue under the game's music; `loudnorm`). Clips under 25 characters are too short for an integrated-loudness reading, so they get `dynaudnorm` plus a limiter instead, which keeps fragments level with their neighbours.
6. **Pack into banks.** `voice_pipeline.py pack` joins each voice's clips (per scope) into OGG banks of up to 4 minutes with 0.35 s of silence between clips, and writes every clip's bank, start and end into `manifest.json`. Expect about 35 to 45 banks. Banking exists because of Roblox's upload limits (below): 1,815 single files would take over a year of Open Cloud quota.
7. **Upload.** `ROBLOX_API_KEY=… ROBLOX_CREATOR_ID=… python3 -I voice_pipeline.py upload` posts each bank to `POST https://apis.roblox.com/assets/v1/assets` (multipart `request` JSON with `assetType` "Audio" + `fileContent` as `audio/ogg`, `x-api-key` header), polls the returned operation until `done`, and stores the `assetId` ([Open Cloud assets guide](https://create.roblox.com/docs/cloud/guides/usage-assets)). Grant the experience permission to use the private assets in the Creator Dashboard.
8. **Ship the manifest.** Convert `manifest.json` to a Luau module (`VoiceManifest`) in ReplicatedStorage (a few lines of script, or Rojo's JSON support).

**Regenerating one line.** `voice_pipeline.py generate --only CGD_PLACE_SANDY_POINT_E --force --takes 2`, pick, `normalise`, `pack`, then `upload --bank CG_DAY_MVP_02`. Open Cloud audio assets **cannot be updated in place**, so the bank becomes a new asset ID and the manifest is updated; one fix costs one upload. Batch fixes weekly to save quota.

**Roblox audio limits that matter** ([audio assets](https://create.roblox.com/docs/audio/assets), [Open Cloud assets guide](https://create.roblox.com/docs/cloud/guides/usage-assets), read 2026-10-17):

| Limit | Value |
|---|---|
| Format | One track: .mp3, .ogg, .wav or .flac; mono or stereo (5.1 allowed); 48 kHz or less |
| Size and length | Under 20 MB and at most 7 minutes per asset |
| Quota (audio assets page) | 2,000 free audio imports per 30 days with ID verification, 100 without; daily limits replaced by this monthly one |
| Quota (Open Cloud guide, audio) | **100 uploads per month with ID verification, 10 without**; audio "not available for updating" |
| Moderation | Every upload is moderated; audio starts **private** and is usable only by the owner and experiences granted permission |
| Cost | No upload fee stated |

The two official pages disagree on the quota. Plan for the stricter Open Cloud figure: **ID-verify the uploading account** (or upload as the group with a verified owner), keep the whole MVP at about 40 banks, and leave about 50 uploads a month for fixes. The Studio Asset Manager and Creator Dashboard (2,000 per 30 days) are the manual fallback.

**AI voice policy.** Roblox's [generative AI rules](https://create.roblox.com/docs/generative-AI) cover experiences where players trigger a model's output (text or voice chat with an AI, generations): those must be declared in the Content Maturity questionnaire and labelled. Pre-recorded, AI-made voice acting is not a player-triggered AI interaction, and no Roblox rule found (2026-10-17) requires a separate disclosure for it; the creator is responsible for the content either way, and every upload passes asset moderation. What we do: designed voices only, never an imitation of a real person or a celebrity; a credit in the game description and settings ("Voices made with ElevenLabs"); and Roblox TTS (section 6) reads only our own fixed text, never player-typed text, so it never becomes a player-triggered generation. Recheck the Community Standards and the questionnaire wording at submission (verify).

## 6. Fallbacks

1. **Roblox text-to-speech for truly dynamic text.** `AudioTextToSpeech` exists in the audio API ([class reference](https://create.roblox.com/docs/reference/engine/classes/AudioTextToSpeech); launched as a beta, [DevForum](https://devforum.roblox.com/t/beta-text-to-speech-api-from-text-to-voice-content-instantly/3792085)): `Text` up to **300 characters**, `VoiceId` from a small set of preset voices (about 10 English voices in the beta announcement), `Pitch` (±12 semitones), `Speed` (0.5 to 2), `LoadAsync()` to generate, one Output pin that wires into the same radio chain. Throttles: **1 + 6 × concurrent users requests per minute per experience** on the server, 4 per second per user on the client; more can be bought via Extended Services. `AutoLocalize` translates and voices 11 languages. Quality is clearly below ElevenLabs and it has no North Atlantic accents, so it is used only for: a fragment missing from the manifest (new content before the next voice batch), [L] player-named vessels if they ever get spoken (filtered text only), and possibly voiced Coastguard calls in other languages later (test quality first). Behind the radio filter the quality gap matters less. Preload with `LoadAsync()` when a tasking is issued so it is ready by the time the stitched call reaches that slot.
2. **Subtitles only.** If voice is off, a bank is not ready, or TTS fails or is throttled, the call plays as squelch, static and the subtitle/log text, timed at 14 characters per second so the pacing still feels like a transmission. No gameplay ever depends on hearing a line.
3. **Missing single fragment.** The player skips that fragment's audio (keeping a natural gap) and the subtitle still shows the word, so a call never stalls.

## 7. Open issues

- *Sandy Point* (onboarding, [document 09](09-rescue-operations.md), section 9.1) is not on [document 10](10-world-and-map.md)'s map yet; either add it or change the onboarding to Haven Sands and regenerate the onboarding lines.
- Tobias, Vance, Nell and Ingrid have no voices yet; Chapter 1 (Harbor Light) in the MVP is covered by Aggie and the Coastguard only.
- Verify: whether `previous_text`/`next_text` are billed; whether `eleven_v3` supports them; the true Open Cloud audio quota for the uploading account; AudioPlayer `PlaybackRegion` seek accuracy on low-end mobile (test 30 stitched calls on a phone before committing to banks; fallback: smaller banks or single files for the Coastguard's most common stems).
