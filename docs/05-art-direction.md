# 05 · Art direction

How Mayday: Sea Rescue looks, moves and sounds, and the rules that keep it consistent. The game design documents (01 to 04) set the names, zones and vehicles. This document sets what they look like and what they may cost. [Document 06](06-tools-and-pipeline.md) covers how assets get into Studio.

Marks used here:

| Mark | Meaning |
|---|---|
| **(tune)** | Starting value. Adjust in Studio. |
| **(verify)** | Engine fact our research could not confirm on an official page. Test in Studio before art depends on it. |
| **(unverified)** | Claim from a secondary source or general knowledge only. |

Research sources: [`research/tools-and-assets.md`](research/tools-and-assets.md) and [`research/store-page-and-monetization.md`](research/store-page-and-monetization.md).

---

## 1. The style in one paragraph

Mayday is a heroic toy harbour in rough weather. Boats, aircraft, buildings and people are chunky and slightly oversized, with soft bevels, big readable silhouettes and clean PBR materials: painted metal that looks like painted metal, rubber that looks like rubber, but simplified, never photographic. The ocean is the hero asset. It is a deep, moving teal that turns gold at sunset and steel grey in a storm, and every other colour is chosen to stand out against it. Rescue orange and white mean "us". Safety yellow means "someone needs help". Red means danger. A player should be able to read any screenshot from colour and shape alone, with the interface hidden.

### Why this style

- **The ocean must be readable at a glance.** Wave height is gameplay (boat handling, storm danger), so the water needs strong value contrast between crest, trough and foam. A stylized ocean can exaggerate this; a realistic one hides it.
- **Phones decide.** Most players will see the game on a small screen. Chunky shapes and few, large colour blocks survive at that size. Fine detail does not.
- **Thumbnails must match the game.** Roblox requires store graphics to match real in-game visuals with no enhancement beyond what players see (store research, section 1). So the game itself must look good in Studio, not only in a Blender render.
- **Not low-poly-cheap.** Flat-shaded faceted props read as an asset flip on Roblox. We use bevels, weighted normals and real material response.
- **Not fake-realistic.** Realistic textures on Roblox avatars and blocky physics look uncanny, age badly and cost more memory.
- **Tone.** Heroic, warm, a little funny, never grim. A capsized ferry is exciting, not tragic. Survivors wave, shout and cheer. Nobody is ever shown hurt.

### Five rules that settle arguments

When two rules disagree, the lower number wins.

1. **Silhouette first.** Every vehicle, character and key prop must be recognisable as a black shape at 64 px tall. Detail never rescues a weak shape.
2. **Signal colours belong to gameplay.** Rescue orange, survivor yellow, hazard red and waypoint green (section 3.2) are never used for decoration.
3. **The water is always the darkest large area on screen in daylight.** Boats, survivors and foam sit on top of it as lighter, warmer shapes.
4. **Judge on the phone, in all three lighting presets.** An asset is approved only after it reads in Calm, Storm and Night lighting on a phone-sized frame at low graphics quality.
5. **Simple materials, honest light.** Clean PBR with simplified values. No baked-in fake lighting that fights the dynamic sun or the storm.

---

## 2. Reference touchstones

Inspiration only. We copy no designs, names or assets. Each reference lends one quality.

| Reference | What we take | What we leave |
|---|---|---|
| **Sea of Thieves** (Rare) | The ocean as a character: big, readable swells, foam on crests, colour that shifts with weather and sun. Storms that feel like an event. | Realistic water rendering cost, pirate tone, grimy textures |
| **Overcooked** (Ghost Town Games) | Readability under chaos: chunky props, clear colour-coded stations, a top-down-friendly layout. Co-op panic that is funny, not stressful. | The kitchen theme, fixed camera |
| **Tiny Glade** (Pounce Light) | Warm golden light, soft shadows and a cosy, hand-made town. Port Haven should feel like a place you want to live in. | Pastel low-contrast palette (too soft for gameplay signals) |
| **Zelda: The Wind Waker** (Nintendo) | Stylized open sea with graphic foam shapes and big skies. | Cel shading, cartoon outlines |
| **Stormworks: Build and Rescue** (Geometa) | Proof that sea rescue plus storms is a loop players love. Reference for rescue situations. | Its engineering-sim complexity and visual style |
| **Real RNLI and coast guard footage** | Vehicle proportions, livery, equipment, how crews move. See [document 08](08-references.md). | Real accidents. We never recreate real tragedies. |

[Document 08](08-references.md) has links and more references.

---

## 3. Palette

### 3.1 Core palette

| Name | Hex | Use |
|---|---|---|
| Rescue Orange | `#FF6B1A` | Player vehicles, uniforms, life rings, UI accent. The game's signature colour. |
| Hull White | `#F4F1EA` | Vehicle hulls, station walls, wordmark. Warm, never pure white. |
| Deep Teal | `#0E5E6F` | Open water mid-tone. The main background of the game. |
| Abyss Navy | `#0A2A3B` | Wave troughs, deep water, UI panel base. |
| Shallow Aqua | `#3FC1C0` | Shallows, Calm Bay, wave crest translucency. |
| Foam | `#EAF7F5` | Wave crests, wake, spray. |
| Golden Hour | `#FFC872` | Calm-day sun, window glow, rim light. |
| Sunset Coral | `#FF8C69` | Calm-day sky gradient near the horizon. |
| Storm Steel | `#5B6B7A` | Storm sky, storm water mid-tone. |
| Storm Slate | `#2F3A45` | Storm cloud base, storm water troughs. |
| Rain Grey | `#9AA8B3` | Rain streaks, mist, distant storm haze. |
| Beacon White | `#FFF6E5` | Lighthouse beams, lamps. A warm white, kept far from Survivor Yellow in saturation (it was Beacon Yellow `#FFE27A`, too close to `#FFD23F`). |

### 3.2 Reserved signal colours

These carry gameplay meaning. Do not use them anywhere else.

| Signal | Hex | Meaning |
|---|---|---|
| Rescue Orange | `#FF6B1A` | Us: players, our vehicles, our dog's vest. |
| Survivor Yellow | `#FFD23F` | Someone to rescue: survivor life jackets, survivor beacons. |
| Hazard Red | `#E8322B` | Danger: rocks marker, fire, flares fired by survivors, warnings. |
| Waypoint Green | `#3EE07A` | Where to go: drop-off zones, waypoints, "ready" states. |

Survivor yellow and rescue orange sit close on the colour wheel. Keep them apart by value and context: survivors are always paired with a pulsing beacon icon, players never are. Check both colours with a colour-blind simulator (protanopia and deuteranopia) before locking them (tune).

Survivor Yellow must also read under golden hour, when the warm `ColorShift_Top`, Golden Hour light and Sunset Coral sky push everything toward yellow-orange. Check: a survivor at 150 studs on Calm Bay water in the Calm preset is found by a reviewer in under 2 seconds on a phone-size screenshot (tune). If it fails, raise the life jacket's value contrast (a white reflective band) before changing the hue.

### 3.3 Port Haven and zone palettes

| Area | Key colours | Mood |
|---|---|---|
| Port Haven town | Harbor Blue `#3D6E9E`, Brick `#B5523B`, Sand `#E8D3A2`, Moss `#6E8B4E`, Driftwood `#9C8064` | Lived-in, warm, a little weathered |
| Calm Bay | Shallow Aqua, Golden Hour, Sand | Safe, sunny, tutorial-friendly |
| Coral Reef | Turquoise `#2EC4B6`, Coral Pink `#FF7F8A`, Reef Purple `#7B5EA7` | Bright, playful, slightly dangerous rocks |
| Open Sea | Deep Teal, Abyss Navy, Foam | Big, open, confident |
| Storm Front | Storm Steel, Storm Slate, Foam, flashes of Beacon White | Loud, dramatic, heroic |
| Iceberg North (later) | Ice `#CFEFF7`, Glacier Blue `#7CC4E0`, Abyss Navy | Crisp, cold, quiet |

Each zone must be nameable from a hidden-UI screenshot by colour alone. That is a review check (section 10).

---

## 4. Shape language

- **Vehicles:** big rounded hulls, oversized fenders and light bars, thick masts and antennas. Proportions pushed about 15% toward "toy" (bigger cabins, shorter hulls) (tune). Each vehicle has one unmistakable silhouette feature: the board's flat plank, the jet ski's swept seat, the RIB's grey tube collar, the lifeboat's tall wheelhouse, the hovercraft's fan duct, the helicopter's rotor and tail boom, the cutter's long bow.
- **Buildings:** chunky, slightly leaning, thick window frames, deep roof overhangs that catch warm light. The coast guard station is the tallest and most orange building in town.
- **Lighthouses:** tall, banded (white plus one colour each), readable from any zone. Each has its own band colour and its own flash rhythm when relit, so players learn them as landmarks.
- **Characters:** players are Roblox avatars. Uniforms (rescue orange jackets, white helmets) are layered on top. Survivor NPCs use simple avatars in yellow life jackets with big readable gestures.
- **The Newfoundland dog (Bosun):** big, round and fluffy, black coat with a slight brown highlight, a large head and paws, and an orange vest with a white cross. It must read as a dog, and as this dog, at 64 px.
- **Rocks and icebergs:** big chunky shapes with flat-ish tops and clear bevels, never noisy scans.
- **Bevel rule:** every hard edge has a bevel wide enough to catch a highlight at gameplay distance. No razor edges.

---

## 5. Materials and texture budgets

### 5.1 Material approach

- Clean PBR through `SurfaceAppearance` (colour, normal, roughness, metalness maps) on hero assets.
- Simplified values: large flat colour fields, gentle gradients, ambient occlusion baked into colour at low strength, normal maps for panel lines and rivets only.
- Shared trim sheets and texture atlases for buildings and props, because research suggests one material per mesh (verify).
- Built-in Roblox materials (with custom `MaterialVariant`s where needed) for terrain, rocks and large surfaces.
- No photo-scanned textures on gameplay objects. CC0 scans (Poly Haven, ambientCG) may be used as a base for terrain or rock materials, then simplified and recoloured to the palette.

### 5.2 Budgets

Research found conflicting numbers for the per-MeshPart triangle cap (about 20,000 to 21,000) and texture size (1024 safe, up to 4096 claimed). We design to the safe side (verify both in the 3D Importer).

| Asset | Triangles (total) | Max per MeshPart | Textures |
|---|---|---|---|
| Rescue board | 1,500 | 1,500 | 1 set, 512 |
| Jet ski | 5,000 | 5,000 | 1 set, 1024 |
| RIB inflatable | 7,000 | 7,000 | 1 set, 1024 |
| Lifeboat | 14,000 | 8,000 | 2 sets, 1024 |
| Hovercraft | 12,000 | 8,000 | 2 sets, 1024 |
| Rescue helicopter | 14,000 | 8,000 | 2 sets, 1024 |
| Patrol cutter | 24,000 | 10,000 | 3 sets, 1024 |
| Newfoundland dog (skinned) | 6,000 | 6,000 | 1 set, 1024 |
| Lighthouse | 8,000 | 8,000 | 1 set, 1024 |
| Town building module | 1,000 to 3,000 | 3,000 | Shared trim sheet, 1024 |
| Small prop (buoy, crate, ring) | 200 to 800 | 800 | Shared prop atlas, 1024 |
| Ferry / cruise ship (big calls) | 30,000 | 10,000 | 3 to 4 sets, 1024 |

A "set" is colour plus normal plus roughness plus metalness. Scene target: no more than about 40 unique 1024 texture sets visible at once on mobile (tune). Vehicles show a lower-detail version beyond 300 studs where `RenderFidelity` allows (verify).

---

## 6. Lighting presets

Three presets live as data in `src/shared/LightingPresets` and are tweened by the weather controller ([document 06](06-tools-and-pipeline.md)). Values are starting points (tune). Lighting technology: Future (live on Roblox for years). Fall back to ShadowMap only if night lighthouse beams or boat lights cost too much on mobile.

| Property | Calm (golden hour) | Storm | Night |
|---|---|---|---|
| `ClockTime` | 17.3 | Unchanged (holds the current time) | 21.5 |
| `Brightness` | 2.6 | 1.2 | 0.4 |
| `Ambient` | `#3A3F4A` | `#3A4450` | `#141C28` |
| `OutdoorAmbient` | `#8A7F70` | `#6F7C88` | `#28344A` |
| `ColorShift_Top` | `#FFC872` | `#9AA8B3` | `#4A6A9A` |
| Atmosphere `Density` | 0.30 | 0.55 | 0.35 |
| Atmosphere `Haze` | 1.2 | 2.8 | 1.0 |
| Atmosphere `Color` | `#FFD9A8` | `#9AA8B3` | `#2A3A55` |
| Atmosphere `Glare` | 0.6 | 0 | 0 |
| Clouds `Cover` / `Density` | 0.45 / 0.35 | 0.92 / 0.80 | 0.50 / 0.40 |
| Clouds `Color` | `#FFF1DD` | `#5B6B7A` | `#2F3A45` |
| ColorCorrection saturation | +0.10 | -0.25 | -0.10 |
| ColorCorrection tint | `#FFF4E6` | `#E6F0F7` | `#DDE6FF` |
| Bloom intensity | 0.4 | 0.2 | 0.6 |
| SunRays | on, low | off | off |
| Ocean mesh tint (vertex colours) | Deep Teal | Storm Steel | Abyss Navy |

Rules:
- Golden hour is the default calm state. The day cycle may move through morning and noon, but most play time sits near warm afternoon light (tune).
- `ClockTime` only moves forward with the day cycle. A storm never changes it: the storm look comes from `Brightness`, clouds, atmosphere and colour correction, so the sun never runs backwards when a storm rolls in.
- Storm lighting must still keep survivors readable. Survivor beacons get a small emissive boost during storms.
- Night is for lighthouse play and atmosphere. Boats have working spotlights and nav lights (red port, green starboard; the starboard green is a slightly different shade from Waypoint Green).
- A Roblox staff post mentions a Clouds rendering upgrade; tuned clouds may need retuning after engine updates (research section 4).

---

## 7. VFX list

All effects use built-in `ParticleEmitter`, `Beam` and `Trail`, with flipbook textures rendered in Blender. Particle counts are halved on low graphics quality (tune).

| Effect | Build | Notes |
|---|---|---|
| Bow spray | ParticleEmitter at bow attachment, rate scaled by speed and wave impact | Foam colour, short life, chunky droplets |
| Wake | Trail from stern attachments plus a foam ribbon mesh | Fades over 3 s (tune); wider on jet ski and lifeboat |
| Wave crest foam | Ocean vertex colour by height (no custom shaders exist; [document 06](06-tools-and-pipeline.md), section 3.1) plus sparse ParticleEmitters near the camera | Storm Front only for particles |
| Rotor downwash | Ring of spray particles on the water below the helicopter, radius by altitude | Key "helicopter is here" signal |
| Rain | Camera-attached ParticleEmitter with streak flipbook, plus splash particles on the water | Off under cover (raycast up) |
| Lightning | Jagged `Beam` segments regenerated per strike, plus a Lighting flash | Flash under 0.15 s, no strobing (accessibility) |
| Distant lightning | Cloud flash only, no bolt | Cheap ambience |
| Flare and flare smoke | Hazard Red flare head, Trail plus smoke ParticleEmitter | Survivors fire these to mark position |
| Orange smoke marker | Rescue Orange smoke from a dropped canister | Player tool for marking a pick-up spot |
| Lighthouse beam | Long cone mesh with gradient transparency, rotating | Relight moment gets a one-off flare-up |
| Survivor splash and rescue burst | Water splash plus a small sparkle burst on pick-up | Feedback for the core loop |
| Dog shake-off | Water droplet burst when the dog climbs aboard | Comedy beat |
| Engine exhaust | Faint grey puff on throttle | Lifeboat and cutter only |
| Wind spray | Horizontal spray sheets in storms | Direction follows storm wind |
| Ice fog | Low ground fog particles | Iceberg North, later |

---

## 8. Animation style

- **Feel:** snappy and weighty. Clear anticipation, a solid hold, then a quick release. Slightly exaggerated, never floppy.
- **Vehicles:** motion comes from physics and the ocean (pitch, roll, slam). Add small scripted extras: throttle squat, rotor tilt, antenna wobble, wiper sweep.
- **The dog:** idle pant and tail wag, swim paddle, tow (holding a rope or a survivor's sleeve), shake-off, bark, sit, happy spin. The dog's animations are the main comedy and warmth source; give them extra polish.
- **Survivors:** waving, treading water, cheering when rescued, a dramatic "thank you" bow. Funny, never distressed.
- **Players:** rescue-specific animations (throw ring, pull aboard, winch signal, salute) on R15 avatars.
- **Camera:** gentle follow lag on boats, a light shake on wave slams and lightning (respect a "reduce motion" setting).
- **Tools:** Roblox Animation Editor for avatar animations; Moon Animator for camera paths and cutscenes (verify current status); Blender for the dog rig and vehicle parts ([document 06](06-tools-and-pipeline.md)).

---

## 9. UI style

- **Look:** chunky rounded panels in Abyss Navy at about 90% opacity, a Rescue Orange accent edge, Hull White text. Nautical touches: signal-flag icons, rope borders on rank cards, a compass ribbon at the top of the screen.
- **The call card:** the core UI element. Incoming calls appear as a radio card: "MAYDAY" header, call type icon, zone, distance, reward and a big accept button. Storm big calls get a larger, animated card.
- **Fonts:** a rounded display font for headers (Fredoka One is in the Roblox font list (verify)) and Builder Sans for body text.
- **Mobile first:** buttons at least 48 px on phones, primary actions in thumb reach (bottom right), nothing essential at the screen corners covered by Roblox's own buttons.
- **Icons:** made from in-game 3D models rendered in Blender, plus flat 2D glyphs for small UI icons. One icon style throughout.
- **Text:** short, plain, all ages. Radio chatter adds humour ("Coast Guard, my boat is now a submarine").

---

## 10. How we avoid slop

### 10.1 Free models and store assets

- No Creator Store or Toolbox model with scripts. Research shows free models can hide server-side backdoors. If a mesh is useful, strip every script, review it, and sandbox it (`Sandboxed`, limited `Capabilities`) while testing (research section 5).
- Store assets are allowed only for background filler that will be replaced, and never for hero assets (vehicles, dog, lighthouses, station, big-call ships).
- Every third-party asset is recoloured and re-materialled to our palette so it does not look like a pack.

### 10.2 AI generation

- **Allowed:** concept sketches, mood boards, colour studies and reference gathering. Studio Assistant for scripting help is covered in [document 06](06-tools-and-pipeline.md).
- **Not allowed:** shipping any AI-generated mesh, texture, image, icon, thumbnail or audio untouched. Anything that started as AI output must be remodelled, repainted or rewritten by a person and logged.
- **Roblox rules:** research found no Roblox policy specific to AI-made 3D assets. The generative AI docs say creators stay responsible for AI-generated content they deliver, must be transparent with players, and must declare player-triggered AI features (chat, images, 3D generation) in the content maturity questionnaire. Mayday plans no player-triggered AI at launch. Roblox's Terms reportedly absorbed the AI feature terms on 2026-04-30 (unverified). Re-check the generative AI docs and Terms before each release.
- **Cube 3D** (Roblox's 3D model) may be used for blockout shapes during greybox only, then replaced.
- **Log:** every asset row in the asset sheet records "AI used: none / concept only / assisted" and who reworked it.

### 10.3 Consistency checks

Before an asset is approved:

1. Silhouette test at 64 px (black fill).
2. Palette check: colours sampled from a screenshot fall within the palette or within one step of it; no signal colour misused.
3. Three-preset test: screenshot in Calm, Storm and Night. Survivor art also passes the golden-hour find test (section 3.2).
4. Phone test: device emulator at a phone resolution and low graphics quality.
5. Scale test: next to the standard avatar and the reference lineup (a dock with every vehicle).
6. Budget test: triangles and texture count within section 5.2.
7. Zone test (for environment art): a reviewer names the zone from a hidden-UI screenshot.

### 10.4 The build, render, critique loop

1. **Build** in Blender or Studio.
2. **Render** a fixed set of views: Blender turntable (4 angles) plus Studio screenshots in the three presets. Combine them into one contact sheet image (Python/Pillow grid), downscaled to 768 px.
3. **Critique** with a fresh reviewer (a person, or a short-lived review agent) who sees only the contact sheet, this document and the asset brief. The reviewer returns a pass or a short list of fixes.
4. **Repeat** until it passes. Hero assets need a pass in all three presets; filler props need Calm only.

---

## 11. Asset sources and licenses

Every asset row in the asset sheet records source, license, author and date. Confirm each CC0 license on the source's own license page before use (research used a secondary guide).

| Asset type | Source | License | Notes |
|---|---|---|---|
| Vehicles, dog, lighthouses, station, big-call ships | Made in Blender by the team | Owned | Hero assets. Never sourced elsewhere. |
| Town buildings and props | Made in Blender; Kenney and Quaternius kits as blockout or base | Owned / CC0 | Kit pieces are remodelled and retextured to our style. Confirm Quaternius wording per pack. |
| Terrain and rock materials | ambientCG, Poly Haven | CC0 | Simplified and recoloured to palette |
| HDRIs for Blender look-dev and icon renders | Poly Haven | CC0 | Not shipped in game |
| VFX flipbooks | Rendered in Blender | Owned | 1024 sheets, Grid4x4 or Grid8x8 (verify sizes) |
| UI icons and glyphs | Image editor and Blender renders; Kenney UI packs as a base | Owned / CC0 | One style throughout |
| Sound effects | Roblox Creator Store audio (partner library, free to use in Roblox); recorded or designed by the team | Roblox terms / Owned | Use only audio we have permission for (research section 5). |
| Extra SFX | Freesound, CC0 clips only | CC0 | Check each clip's license (unverified) |
| Music | Roblox Creator Store music, or commissioned | Roblox terms / Work for hire | For off-Roblox marketing, use commissioned music or music cleared for social video ([document 07](07-store-page-thumbnails-and-trailer.md)). |
| Animations | Animation Editor, Moon Animator, Blender | Owned | Mixamo only after re-checking Adobe's terms; avoid by default |
| Fonts | Roblox built-in fonts | Roblox | No external font files |
| Commissioned art or music | Freelancers | Written work-for-hire with full rights transfer and a no-AI clause | Keep the contract in the project drive |

Credits for every CC0 and commissioned asset go in a credits screen and in the game description footer, even where the license does not require it.
