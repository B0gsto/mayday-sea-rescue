# 07 · Store page, thumbnails and trailer

> Older chapter: this predates the 2026-10-25 hub redesign. [`00-design.md`](00-design.md) is the source of truth; the current game is the forest hub, six Lego islands and no town, cars, phone or radio.

How Mayday: Sea Rescue presents itself on its Roblox page and on short-form video: icon, thumbnails, the personalization test, the gameplay video, shorts, the description and the name.

Marks: **(verify)** means check the upload dialog or an official page before relying on it. **(unverified)** means secondary source only. **(tune)** means a starting value.

Research source: [`research/store-page-and-monetization.md`](archive/research/store-page-and-monetization.md) (section numbers below refer to it). Visual rules come from [document 05](05-art-direction.md), the current art direction.

---

## 1. Platform rules we design around

| Rule | Source (research section 1) |
|---|---|
| Icon: square, at least 512 x 512, shown as small as about 150 x 150; moderated before display | Experience icons page |
| Thumbnails: up to 10 images or videos; 16:9, ideally 1920 x 1080; .jpg, .gif, .png, .tga, .bmp; other shapes are stretched | Thumbnails page |
| Personalization: 2 to 5 active thumbnails; each under 3 MB | Thumbnails page |
| Keep essential text and elements away from the bottom edge (player-count overlay) | Thumbnails page |
| Graphics must match real in-game visuals; no enhancement beyond what players see | Promotional thumbnails page |
| Do not show mechanics, UI or interactions the game lacks, or a different genre | Thumbnails page |
| Text overlays sparingly, only to describe gameplay; no ads, promotions or subjective claims | Promotional thumbnails page |
| Allowed: varied camera angles, free camera, minor post-processing, curated highlights, in-game UI text, logo overlays, catalog music | Promotional thumbnails page |
| Video: authentic gameplay only; reviewed; 3 uploads per month, rejected uploads still count | Thumbnails pages |
| Video: no real-life footage, external content, voice-over, narration, voice chat or music with lyrics | Promotional thumbnails page |
| Video not shown on Xbox, PlayStation or VR | Thumbnails page |
| Video length, format, resolution and file size limits | Not stated (verify in upload dialog) |
| Free camera in solo playtest: Left Shift + P | Thumbnails page |

**What this means for us:** every thumbnail and every second of the video is a **photoreal in-engine shot**, captured in the current build with the shipped lighting presets ([document 05](05-art-direction.md), section 6). We shoot it like film: a cinematic camera, real lenses, motivated movement, real weather. But nothing is added that players do not see: no Blender renders, no paint-overs, no composited spray, rain, fire or lens effects. If a vehicle, zone or effect is not in the live game yet, it does not appear.

**Honesty check for photoreal:** shots are captured at the highest graphics quality, which is what desktop players on High see. Before upload, capture the same shot at Medium. If the shot's main idea (the spray sheet, the searchlight in rain, the wave face) disappears at Medium, pick a different shot, so the store page never relies on a look most players cannot get.

---

## 2. Icon

### 2.1 Spec

- Author at 1024 x 1024 PNG, upload at that size (meets the 512 minimum).
- Preview at 150 x 150 and at about 110 x 110 (a third-party article suggests phones show tiles near that size (unverified)) before every upload.
- One large subject, one clear silhouette, high contrast against both light and dark Roblox themes.
- Palette: a Hull Orange or SOLAS orange subject against grey-green or slate sea and sky ([document 05](05-art-direction.md), section 3). Warm, saturated subject on a cool, desaturated background, which is also how real rescue photos read.
- Captured in Studio from the shipped models, materials and lighting, with the cinematic camera. The icon page asks only that the icon be unique and relevant, but we hold it to the same "matches the game" rule as thumbnails to be safe. Only crop, exposure and contrast are adjusted.
- No text, or the short "MAYDAY" wordmark at most. Small text is unreadable at 150 px.
- Survives the moderation check: no real logos, no RNLI or USCG marks, no real coast guard insignia, no flags of real countries. Our invented Gale Isles Coastguard livery only ([document 05](05-art-direction.md), section 4.2).

### 2.2 Three concepts

| | A: The dog | B: The winch | C: The wave |
|---|---|---|---|
| Subject | Bosun, the low-poly Newfoundland (faceted black coat, matching the in-game model), head and shoulders out of the water, orange harness, a lifebuoy in his mouth | The rescue helicopter from below at an angle in rain, searchlight on, a crew member on the hoist line reaching down | The all-weather lifeboat punching through a breaking wave, bow up, green water off the deck |
| Background | Overcast grey-green sea, one foam crest, spray drops | Storm cloud base, a ring of downwash spray | Slate storm sky, spindrift, a lighthouse beam behind |
| Focal point | The dog's eyes and the lifebuoy | The outstretched gloved hand | The bow and the crest |
| Emotion | Warm, trustworthy | Heroic, tense | Thrilling, bold |
| Strength | Unique on Roblox; a bold low-poly dog face reads at tiny sizes; all ages | Says "rescue" instantly | Says "storms" and "ocean" instantly; shows off the ocean |
| Risk | May read as a pet game; the dog must match the in-game low-poly Bosun | Busy at 150 px; a helicopter can look like Blackhawk Rescue | Boat-on-wave icons are common; depends on the ocean passing spike O3 |

**Recommendation:** start with A as the main icon (distinct and warm), keep C ready for storm-focused updates. Roblox has no built-in icon split test in our research, so compare icons by swapping them between updates and watching play-through rate, knowing the comparison is rough.

---

## 3. Thumbnails

All captured at 1920 x 1080 in-game with the cinematic camera or free camera. Thumbnails may use frames from the game's own third-person cinematics (arrival, storm, slipway launch, rank-up), which every player sees, as well as capture-camera shots; at least one test thumbnail is a first-person frame (gloved hands on the throw bag or the jet ski bars) to sell the point of view. Shoot at the highest graphics quality, exported under 3 MB. Bottom 15% of the frame kept free of key subjects and text (player-count overlay). Text overlays, when used, are short gameplay descriptions in the UI font (Builder Sans), top-left or top-centre.

Shot language: real camera positions (a chase boat at water level, the helicopter door, a cliff with a long lens, a deck-mounted camera), focal lengths set with `Camera.FieldOfView` (wide about 70, normal about 40, long lens 15 to 25) (tune), and the horizon level unless the boat is rolling.

| # | Name | Composition | Focal point | Text overlay | Emotion |
|---|---|---|---|---|---|
| 1 | Storm rescue | Long lens from a chase boat: the all-weather lifeboat climbing a storm wave toward a capsized ferry, spindrift and rain, survivors in SOLAS orange on the hull with strobes flashing | Lifeboat bow and the survivors | "STORMS HIT EVERY 15 MINUTES" (only while true) | Thrill, heroism |
| 2 | Helicopter winch | From the helicopter door looking down: the hoist line diagonal to a survivor in the water, downwash flattening the sea into a spray ring | The crew member meeting the survivor | None | Tension, competence |
| 3 | Rescue dog | Water-level close shot in overcast light: Bosun swimming, towing a waving survivor toward the jet ski in the sheltered bay | The dog's face | None | Warmth |
| 4 | Squad on the RIB | Three players in drysuits and hi-vis helmets on a RIB pulling a survivor aboard, wet deck, call card UI visible | The pull-aboard moment | None (the in-game call card is the text) | Teamwork |
| 5 | Port Haven fleet | Clear-day wide shot from the quay: the station, slipway and the unlocked vehicles, granite harbour and lighthouse behind | The lineup | "UNLOCK RESCUE VEHICLES" | Aspiration, collection |
| 6 | Relight the lighthouse | Night shot: a player at the lantern gallery as the beam sweeps across the bay through drizzle, town lights below | The beam | None | Wonder, accomplishment |
| 7 | Cruise ship aground | Long-lens storm shot: a cruise ship on rocks, searchlights, boats and a helicopter around it | The scale of the ship versus the boats | "SERVER-WIDE RESCUES" | Spectacle, community |
| 8 | Reef run | Clear-day jet ski skimming green water over white sand between granite skerries, a survivor's orange smoke ahead (zone per [document 01](01-game-canon.md)) | Jet ski and spray | None | Fun, freedom |
| 9 | Harbour mouth storm | Low angle from the water: a jet ski launching off a storm wave in the harbour mouth toward a waving survivor, the harbour wall and Harbor Light behind, rain streaks | The jet ski in the air and the survivor's raised arms | None (thumbnail 1 carries the storm line) | Thrill, "I can do that now" |

Rules:
- Only show vehicles, zones and events that are live. Thumbnail 5 waits until the launch fleet is in; thumbnail 7 waits for the Cruise Ship Aground big call ([P1]).
- **Session-1 content:** thumbnails 3, 8 and 9 show only what a new player does in their first 25-minute session. At least 2 of the active thumbnails must always be session-1 content, so the page never promises only late-game play.
- **Post-processing:** only exposure, contrast and crop in the editor ("minor post-processing"). DepthOfField, Bloom and grading come from the in-engine presets and the cinematic camera, never added afterwards. No added fire, glow, spray, rain or lens flares.
- **No mixed fidelity in frame:** every asset in a thumbnail must have passed the [document 05](05-art-direction.md) checks; greybox or placeholder parts disqualify the shot.
- Add alt text to every thumbnail (supported on the page).
- Faces and bright contrast are common creator advice, not official (unverified); we test it rather than assume it.

---

## 4. Personalization and A/B plan

Roblox's Home page personalization shows each active thumbnail to random user groups and gives the best one more impressions, measured by qualified play-through rate. It needs 2 to 5 active thumbnails. Roblox reports an average +8.5% in qualified play-through rate (research section 1).

| Phase | Active set | Question |
|---|---|---|
| Launch | 1 Storm rescue, 2 Helicopter winch, 3 Rescue dog, 9 Harbour mouth storm (3 and 9 are session-1 content) | Which promise pulls players: big storm action, the helicopter, warmth, or a storm rescue they can do right away? |
| After 2 weeks or the first update | Keep the top 2; add 2 variants of the winner (different angle or time of day); keep 2 session-1 thumbnails in the set | What makes the winning idea work? |
| Each major update | Add 1 to 2 thumbnails showing the new content; keep at least 2 proven ones | Does new content beat the proven set? |

- Keep several thumbnails active; Roblox advises against picking one winner. Change the set only with major updates, then hold it.
- Read the Thumbnail Performance table (impressions, qualified plays, average playtime, qPTR, winning segment) after a few hours, but decide only after several days of data (tune).
- Watch average playtime alongside qPTR. A thumbnail that wins clicks but loses playtime is overselling; drop it.
- The Thumbnail Personalization Open Cloud API is reported as experimental (research section 1); we do this by hand at first.
- The detail page holds up to 10 items: the video first, then the 4 active thumbnails, then up to 5 more (fleet, lighthouse, reef, big call).
- Ads Manager campaigns use the same thumbnails (up to 10, shown evenly), so the best performers become ad creatives.

---

## 5. Gameplay video

### 5.1 Spec

- Real gameplay from the live build only, filmed cinematically. Roblox reviews it before distribution and forbids anything players do not see, so cinematic means camera work, not added effects: every frame is the real game, with the shipped presets.
- Length: 30 seconds target. The limit is not stated on the official pages (verify in the upload dialog before editing to length).
- 1920 x 1080, 60 fps, H.264 MP4 (verify accepted format and size).
- Music: instrumental catalog music from the Roblox Creator Store, or our own commissioned instrumental track. No lyrics, no voice-over, no voice chat. Game audio (sea, wind, engines, radio) carries a lot of the realism; mix it high.
- Text: only the logo overlay and in-game UI text (call cards, rank-up banners). No claims.
- Budget: 3 uploads per month, rejections count, so review against section 1 before each upload.

### 5.2 Shot list (30 seconds)

The trailer is mostly **first-person gameplay** (what a player actually sees: their gloved hands, the jet ski bars, the casualty in the swell), cut with the game's own **third-person cinematics** (arrival, storm rolling in, slipway launch, rank-up, [document 02](02-core-loop-and-mechanics.md), section 12) and a few chase-camera shots. All three are real views a player sees in game, so the honesty rule in section 1 holds. About 16 of the 30 seconds are first person.

| Time | Shot | Camera | UI |
|---|---|---|---|
| 0:00 to 0:03 | Gloved hands on the jet ski bars at speed, spray over the console, the Harbour Mouth ahead; the tasking card slides in: "MAYDAY: person in the water, Sandy Point" | First person (game camera) | Tasking card only |
| 0:03 to 0:05 | Keep eyes on: an orange hood rises on a swell; a flare arcs up from the harbour wall | First person | Lookout reticle |
| 0:05 to 0:08 | The hand reaches down, grabs the lifejacket strap, hand-over-hand haul onto the sled | First person | Hidden |
| 0:08 to 0:11 | The jet ski runs in past the Harbor Light at golden hour; Chief Aggie walks down the slipway | Arrival cinematic (third person) | Hidden |
| 0:11 to 0:13 | Bosun leaps off the footwell and swims to a waving survivor, seen over the bars | First person | Hidden |
| 0:13 to 0:15 | Clouds stack over Tempest Point, the Harbor Light comes on, boats pitch at their moorings | Storm cinematic (third person) | Storm warning card |
| 0:15 to 0:17 | Boathouse doors open, the all-weather lifeboat runs down the slipway and hits the water | Slipway launch cinematic (third person) | Hidden |
| 0:17 to 0:20 | The lifeboat climbs and slams through a huge wave, green water over the bow, spindrift | Chase camera (game) | Hidden |
| 0:20 to 0:22 | From the helicopter door: looking down the hoist line at a capsized ferry in rain | First person (Winch Operator) | Hidden |
| 0:22 to 0:24 | A gloved fist knocks on the upturned hull; taps answer from inside | First person | Hidden |
| 0:24 to 0:26 | Both hands swing a throw bag out to a survivor in SOLAS orange among red flares | First person | Hidden |
| 0:26 to 0:28 | Back at the station: Aggie pins the rank badge, Bosun shakes off water | Rank-up cinematic (third person) | Rank-up banner |
| 0:28 to 0:30 | Logo over the harbour at dusk, the lighthouse beam sweeping | Capture camera, slow pull-back | Logo overlay |

Cut on wave impacts and knocks so the music lines up. The first 13 seconds are the real first session (the cold open and the arrival, [document 09](archive/09-rescue-operations.md), section 9.1); the rest shows what players grow into (storms, the lifeboat, the helicopter, big calls, rank). Lifeboat and helicopter shots need the [L] build; until then, an MVP cut swaps them for the RIB launch and the Capsized Ferry from the RIB.

### 5.3 How to capture

- **First-person shots:** recorded with the shipped first-person camera and viewmodel at the default comfort settings (horizon stabilisation on, FOV 80°), so they match what players see ([document 06](06-tools-and-pipeline.md), section 3.6). Play each beat several times and keep the cleanest take; never add hands or motion in the edit.
- **Game cinematics:** the arrival, storm, slipway launch and rank-up shots are the shipped `Cinematic` module's own shots, triggered on cue by a dev command.
- **Capture camera:** for anything else, the `Cinematic` module in a dev-only mode plays CFrame keyframe paths with easing, triggered by a dev chat command. It sets `FieldOfView` per shot for lens choice, adds a light handheld or boat-mounted sway (tune), and may raise the preset's DepthOfField for a shallow-focus look on close shots. It only moves the camera and focus; everything on screen is live gameplay. Moon Animator camera paths are an alternative (verify plugin status). Free camera (Left Shift + P) for quick handheld shots.
- **Realistic camera rules:** cameras sit where a real camera could be (chase boat, helicopter door, cliff, deck mount, quay). No flying through hulls or waves. Keep the 180-degree rule within a sequence. Let the camera ride the swell at water level instead of floating dead still.
- **Capture server:** a private server with 4 to 6 team members playing roles in full crew kit, plus debug flags to force a storm, a lighting preset at the current time of day and a big call on cue.
- **Settings:** graphics quality at maximum, window at 1920 x 1080, Roblox core UI hidden through a dev flag (`SetCoreGuiEnabled` off), our HUD hidden except where the shot list keeps it.
- **OBS:** canvas and output 1920 x 1080, 60 fps, recording format MKV (remux to MP4 after), hardware H.264 or HEVC encoder, high-quality constant quality (CQP around 16 to 18) or a high bitrate around 40 to 50 Mbps for the master (tune). Game audio on its own track; no microphone. Spray, rain and foam are hard on encoders; check the master for blocking.
- **Edit:** cut in a video editor, add music and the logo, export H.264 MP4 at 1080p60. Grading is limited to exposure, contrast and a light match between shots.
- **Check:** compare frames against in-game screenshots at the same quality level; any grading must stay minor. Run the Medium-quality honesty check from section 1.

---

## 6. Short-form plan (TikTok, YouTube Shorts)

No official Roblox guidance exists for short-form; this plan is our judgment. DevForum advice says a good showcase on shorts can bring strong free attention if the game itself is fun.

- **Format:** 9:16, 1080 x 1920, 60 fps, 10 to 30 seconds. Hook in the first second. Captions burned in, because many viewers watch muted.
- **Capture:** the same OBS setup with a vertical canvas, or a centre crop from 16:9 captures framed with vertical in mind.
- **Cadence:** 3 clips per week to start. A vendor blog suggests 3 to 5 per week (unverified).
- **Series ideas:**
  - "Storm in 3, 2, 1": calm-to-storm transition in one shot.
  - "Dog saves the day": the Newfoundland's best rescues and shake-offs.
  - "Worst captain": funny capsizes and helicopter bumps.
  - "Can we save the ferry?": a big call from start to finish, sped up (the cruise ship from [P1]).
  - "Relit": before and after a lighthouse is relit.
  - Dev logs: the photoreal ocean, building the lifeboat in Blender from real reference.
- **Rules:** short-form is off-platform, so Roblox thumbnail rules do not apply, but we stay honest: real gameplay, no fake features. Voice-over is fine here.
- **Music:** Roblox Creator Store audio is licensed for use on Roblox; whether it covers off-platform social video is not confirmed (unverified). Use commissioned music or the platform's own licensed sound library for shorts.
- **Paid creators:** any paid or gifted creator post must be disclosed. Undisclosed paid promotion can break platform rules and advertising law.
- **Roblox Moments:** Roblox has tested a 30-second clip feed that lets viewers jump into games (Bloomberg, 2025). Check its status at launch; our shorts already fit that length.

---

## 7. Game description draft

Roblox research (section 5) shows the first 3 minutes decide discovery, so the description leads with what the first session delivers and labels the rest as things to unlock.

```
Answer mayday calls and save people at sea! Race out in rescue boats,
jet skis and a helicopter, pull survivors from the waves, and bring them
home to Port Haven.

Every 15 minutes a storm sweeps the Gale Isles. Waves rise, lightning
strikes, and big calls come in: a capsized ferry, a trawler on the
rocks. Team up with everyone on the server to save them all.

- Start on the jet ski, then unlock the RIB, lifeboat and rescue
  helicopter
- Rescue with Bosun, your Newfoundland rescue dog
- Explore Calm Bay, The Skerries, the Open Sea and the Storm Front
- Relight the dark lighthouses of the Gale Isles
- Rank up from Recruit to Admiral

Credits: see the in-game credits board.
```

Notes:
- Zone names in the draft must match [document 01](01-game-canon.md) when it changes (the photoreal bible assumes a cold-water reef, [document 05](05-art-direction.md), section 3.4).
- Rank names and the dog's name (Bosun) come from [`01-game-canon.md`](01-game-canon.md) and [`03-progression.md`](03-progression.md).
- Keep the vehicle list honest at launch: list only what is in the build.
- No emoji walls, no repeated keywords, no "best game" claims. Read the character counter in the dashboard (limit not in our research).

---

## 8. Title and name

**Chosen:** Mayday: Sea Rescue.

Research found no Roblox game called "Mayday" or "Mayday: Sea Rescue". "Coast Guard" and "Sea Rescue" titles already exist (for example "Sea Rescue" by Quentiin and several "Coast Guard" roleplays), so the "Mayday:" prefix is what makes ours distinct. Do a direct title search on roblox.com before publishing.

| Alternative | Note |
|---|---|
| Mayday! Sea Rescue | Exclamation adds urgency; slightly less clean |
| Mayday: Coast Guard Rescue | Clearer job fantasy; "Coast Guard" is crowded |
| Mayday: Storm Rescue | Leads with the storm hook |
| Port Haven Rescue | Ownable but says less about the game |
| Mayday Sea Rescue Simulator | Adds the genre keyword; longer |

Keep the name stable after launch; renaming loses recognition. Add a genre keyword to the description rather than the title if search needs it.
