# 07 · Store page, thumbnails and trailer

How Mayday: Sea Rescue presents itself on its Roblox page and on short-form video: icon, thumbnails, the personalization test, the gameplay video, shorts, the description and the name.

Marks: **(verify)** means check the upload dialog or an official page before relying on it. **(unverified)** means secondary source only. **(tune)** means a starting value.

Research source: [`research/store-page-and-monetization.md`](research/store-page-and-monetization.md) (section numbers below refer to it). Visual rules come from [document 05](05-art-direction.md).

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

**What this means for us:** every thumbnail and every second of the video is captured in-game, in the current build, with real lighting presets. No Blender renders on the store page. If a vehicle or zone is not in the live game yet, it does not appear.

---

## 2. Icon

### 2.1 Spec

- Author at 1024 x 1024 PNG, upload at that size (meets the 512 minimum).
- Preview at 150 x 150 and at about 110 x 110 (a third-party article suggests phones show tiles near that size (unverified)) before every upload.
- One large subject, one clear silhouette, high contrast against both light and dark Roblox themes.
- Palette: Rescue Orange and Hull White on Deep Teal. Warm subject on cool background.
- Built from the real game models, posed in Studio or rendered in Blender from the shipped meshes and textures. The icon page asks only that the icon be unique and relevant, but we hold it to the same "matches the game" rule as thumbnails to be safe.
- No text, or the short "MAYDAY" wordmark at most. Small text is unreadable at 150 px.
- Survives the moderation check: no real logos, no real coast guard insignia, no flags of real countries.

### 2.2 Three concepts

| | A: The dog | B: The winch | C: The wave |
|---|---|---|---|
| Subject | The Newfoundland in its orange vest, head and front paws, holding a life ring in its mouth | The rescue helicopter seen from below at an angle, a rescuer on the winch line reaching down | The orange-and-white lifeboat cresting a huge teal wave, bow up |
| Background | Deep Teal water with a single foam crest | Storm Steel sky, a crescent of downwash spray | Storm Slate sky, a lighthouse beam behind, one lightning fork |
| Focal point | The dog's eyes and the ring | The rescuer's outstretched hand | The bow and the wave crest |
| Emotion | Warm, cute, trustworthy | Heroic, tense | Thrilling, bold |
| Strength | Unique on Roblox; reads at tiny sizes; appeals to all ages | Says "rescue" instantly | Says "storms" and "ocean" instantly |
| Risk | May read as a pet game | Busy at 150 px; a helicopter can look like Blackhawk Rescue | Boat-on-wave icons are common |

**Recommendation:** start with A as the main icon (distinct and warm), keep C ready for storm-focused updates. Roblox has no built-in icon split test in our research, so compare icons by swapping them between updates and watching play-through rate, knowing the comparison is rough.

---

## 3. Thumbnails

All captured at 1920 x 1080 in-game with free camera, highest graphics quality, exported under 3 MB. Bottom 15% of the frame kept free of key subjects and text (player-count overlay). Text overlays, when used, are short gameplay descriptions in the UI font, top-left or top-centre.

| # | Name | Composition | Focal point | Text overlay | Emotion |
|---|---|---|---|---|---|
| 1 | Storm rescue | Low angle from the water: the lifeboat climbing a storm wave toward a capsized ferry, lightning fork top right, survivors in yellow on the hull | Lifeboat bow and the survivors | "STORMS HIT EVERY 15 MINUTES" (only while true) | Thrill, heroism |
| 2 | Helicopter winch | Three-quarter view from above: helicopter top left, winch line diagonal to a survivor in the water, downwash ring on the waves | The basket meeting the survivor | None | Tension, competence |
| 3 | Rescue dog | Water-level close shot: the Newfoundland swimming, towing a waving survivor toward an orange RIB | The dog's face | None | Warmth, humour |
| 4 | Squad on the RIB | Three players in orange on a RIB pulling a survivor aboard, call card UI visible on screen | The pull-aboard moment | None (the in-game call card is the text) | Teamwork |
| 5 | Port Haven fleet | Golden-hour wide shot of the station dock with the unlocked vehicles lined up, lighthouse behind | The lineup | "UNLOCK RESCUE VEHICLES" | Aspiration, collection |
| 6 | Relight the lighthouse | Night shot: a player at the top of a lighthouse as the beam sweeps across the bay, town lights below | The beam | None | Wonder, accomplishment |
| 7 | Cruise ship aground | Wide storm shot: a giant cruise ship on rocks, many player boats and a helicopter around it | The scale of the ship versus the boats | "SERVER-WIDE RESCUES" | Spectacle, community |
| 8 | Calm reef | Bright daytime jet ski skimming the Coral Reef with a small survivor beacon ahead | Jet ski and spray | None | Fun, freedom |

Rules:
- Only show vehicles, zones and events that are live. Thumbnails 5 and 7 wait until the fleet and the cruise ship call exist.
- No stretched or artificial effects. "Minor post-processing" means light levels and contrast, not added fire, glow or fake depth of field.
- Add alt text to every thumbnail (supported on the page).
- Faces and bright contrast are common creator advice, not official (unverified); we test it rather than assume it.

---

## 4. Personalization and A/B plan

Roblox's Home page personalization shows each active thumbnail to random user groups and gives the best one more impressions, measured by qualified play-through rate. It needs 2 to 5 active thumbnails. Roblox reports an average +8.5% in qualified play-through rate (research section 1).

| Phase | Active set | Question |
|---|---|---|
| Launch | 1 Storm rescue, 2 Helicopter winch, 3 Rescue dog, 4 Squad on the RIB | Which promise pulls players: action, rescue, warmth or co-op? |
| After 2 weeks or the first update | Keep the top 2; add 2 variants of the winner (different angle or time of day) | What makes the winning idea work? |
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

- Real gameplay from the live build only. Roblox reviews it before distribution, so we treat it as a gameplay preview, not a cinematic trailer.
- Length: 30 seconds target. The limit is not stated on the official pages (verify in the upload dialog before editing to length).
- 1920 x 1080, 60 fps, H.264 MP4 (verify accepted format and size).
- Music: instrumental catalog music from the Roblox Creator Store, or our own commissioned instrumental track. No lyrics, no voice-over, no voice chat.
- Text: only the logo overlay and in-game UI text (call cards, rank-up banners). No claims.
- Budget: 3 uploads per month, rejections count, so review against section 1 before each upload.

### 5.2 Shot list (30 seconds)

| Time | Shot | Camera | UI |
|---|---|---|---|
| 0:00 to 0:02 | Golden-hour Port Haven, the station siren light spins, a call card slides in: "MAYDAY: swimmer in Calm Bay" | Slow push-in on the station | Call card only |
| 0:02 to 0:05 | Player sprints down the dock and jumps onto the RIB; it launches with bow spray | Follow cam, low behind | Hidden |
| 0:05 to 0:08 | RIB cuts across Calm Bay; the dog stands at the bow, ears flapping | Side tracking shot at water level | Hidden |
| 0:08 to 0:10 | The dog dives in, swims to a waving survivor, tows them back; survivor cheers | Close, water level | Hidden |
| 0:10 to 0:12 | Jet ski weaves through Coral Reef rocks | Fast low pass | Hidden |
| 0:12 to 0:14 | Sky shifts from gold to steel grey; storm warning card appears; rain starts | Wide, high, sky dominant | Storm warning card |
| 0:14 to 0:17 | Lifeboat climbs and slams over a huge wave in the Storm Front; lightning | Low angle from the trough | Hidden |
| 0:17 to 0:20 | Helicopter hovers; rescuer winches down to a survivor beside a capsized ferry | Three-quarter from above | Hidden |
| 0:20 to 0:23 | Several players' boats circle the ferry pulling survivors aboard | Wide orbit | Hidden |
| 0:23 to 0:25 | Storm clears; a player relights a lighthouse; the beam sweeps out | Low, looking up at the lamp | Hidden |
| 0:25 to 0:27 | Back at the dock: survivors dropped off, rank-up banner, the crew salutes, the dog shakes off water | Medium, front | Rank-up banner |
| 0:27 to 0:30 | Logo over the harbour at golden hour | Slow pull-back | Logo overlay |

Cut on wave impacts and lightning so the music lines up. Each shot shows something a new player can do in the first session or during the first storm, so the page does not overpromise.

### 5.3 How to capture

- **Cinematic camera:** a dev-only `CinematicCamera` client module ([document 06](06-tools-and-pipeline.md)) plays CFrame keyframe paths with easing, triggered by a dev chat command. It only moves the camera; everything on screen is live gameplay. Moon Animator camera paths are an alternative (verify plugin status). Free camera (Left Shift + P) for quick handheld shots.
- **Capture server:** a private server with 4 to 6 team members playing roles, plus debug flags to force a storm and a big call on cue.
- **Settings:** graphics quality at maximum, window at 1920 x 1080, Roblox core UI hidden through a dev flag (`SetCoreGuiEnabled` off), our HUD hidden except where the shot list keeps it.
- **OBS:** canvas and output 1920 x 1080, 60 fps, recording format MKV (remux to MP4 after), hardware H.264 or HEVC encoder, high-quality constant quality (CQP around 16 to 18) or a high bitrate around 40 to 50 Mbps for the master (tune). Game audio on its own track; no microphone.
- **Edit:** cut in a video editor, add music and the logo, export H.264 MP4 at 1080p60.
- **Check:** compare frames against in-game screenshots; any grading must stay minor.

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
  - "Can we save the cruise ship?": a big call from start to finish, sped up.
  - "Relit": before and after a lighthouse is relit.
  - Dev logs: ocean tech, building the lifeboat in Blender.
- **Rules:** short-form is off-platform, so Roblox thumbnail rules do not apply, but we stay honest: real gameplay, no fake features. Voice-over is fine here.
- **Music:** Roblox Creator Store audio is licensed for use on Roblox; whether it covers off-platform social video is not confirmed (unverified). Use commissioned music or the platform's own licensed sound library for shorts.
- **Paid creators:** any paid or gifted creator post must be disclosed. Undisclosed paid promotion can break platform rules and advertising law.
- **Roblox Moments:** Roblox has tested a 30-second clip feed that lets viewers jump into games (Bloomberg, 2025). Check its status at launch; our shorts already fit that length.

---

## 7. Game description draft

Roblox research (section 5) shows the first 3 minutes decide discovery, so the description promises exactly what the first session delivers.

```
Answer mayday calls and save people at sea! Race out in rescue boats,
jet skis and a helicopter, pull survivors from the waves, and bring them
home to Port Haven.

Every 15 minutes a storm sweeps the Gale Isles. Waves rise, lightning
strikes, and big calls come in: a capsized ferry, a cruise ship on the
rocks. Team up with everyone on the server to save them all.

- Drive the rescue board, jet ski, RIB and lifeboat, then unlock the
  hovercraft, rescue helicopter and patrol cutter
- Rescue with Bosun, your Newfoundland rescue dog
- Explore Calm Bay, Coral Reef, the Open Sea and the Storm Front
- Relight the dark lighthouses of the Gale Isles
- Rank up from Recruit to Admiral

Credits: see the in-game credits board.
```

Notes:
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
