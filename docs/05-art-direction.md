# 05 · Art direction

How Mayday: Sea Rescue looks and moves, and the rules that keep it consistent. The direction is **photoreal**: a grounded, real-world North Atlantic coast, as realistic as Roblox can render. The game design documents (01 to 04) set the names, zones and vehicles. This document sets what they look like and what they may cost. [Document 06](06-tools-and-pipeline.md) covers how assets get into Studio and how the ocean is built.

Marks used here:

| Mark | Meaning |
|---|---|
| **(tune)** | Starting value. Adjust in Studio. |
| **(verify)** | Engine fact our research could not confirm on an official page, or where sources conflict. Test in Studio before art depends on it. |
| **(unverified)** | Claim from a secondary source or general knowledge only. |

Research sources: [`research/photoreal.md`](research/photoreal.md) (the main source for this document), [`research/tools-and-assets.md`](research/tools-and-assets.md) and [`research/store-page-and-monetization.md`](research/store-page-and-monetization.md).

---

## 1. The look in one paragraph

Mayday looks like a real lifeboat station on a real Atlantic coast. Think of a Cornish or Maine harbour town: granite quays, slate roofs, whitewashed and weathered render, a slipway running down into cold green-grey water. The fleet looks like working rescue craft: hull orange paint with salt stains and fender scuffs, wet non-slip decks, stainless fittings that catch the light. The sea is the hero. It is deep, heavy and cold, mostly under a bright overcast sky, sometimes sunlit, sometimes a grey-white storm with spindrift tearing off the crests. Every surface uses physically based materials under Future lighting. Nothing glows unless it is a real light. Survivors, hazards and objectives stay readable through the same tools real rescuers use: hi-vis colours, retroreflective tape, strobes, flares and smoke.

### Why this target, and what it costs

- **The user asked for it.** "Everything needs to be realistic, like mega realistic." This document turns that into rules that a Roblox build can meet.
- **The North Atlantic suits the engine.** Overcast light, grey-green water and haze are kinder to Roblox's fixed specular and lack of custom shaders than tropical sun on clear water. The default weather is bright overcast for that reason.
- **Thumbnails must match the game.** Roblox requires store graphics to match real in-game visuals ([document 07](07-store-page-thumbnails-and-trailer.md), section 1). Photoreal has to be real in Studio, not only in Blender.
- **Honest limits.** Roblox has no custom shaders, fixed specularity per material and conflicting texture caps (research section 2.3 and 3.1). The ocean is the biggest risk and has its own spike (section 7.2). We aim for "the most convincing sea on Roblox", not AAA parity.
- **Roblox Reality is not a plan.** The announced AI photoreal overlay was not shipped at research time (research section 4.5, unverified). Nothing here depends on it.
- **Tone.** Grounded and serious about the sea, all ages, never graphic. No injuries, no blood, no bodies, no drowning shown. The danger is the weather and the water, not gore.

### Five rules that settle arguments

When two rules disagree, the lower number wins.

1. **Readable before pretty.** A survivor, a hazard and the objective must be findable on a phone screenshot (section 9). If realism hides them, we add a real-world cue (strobe, tape, flare), never a game-y glow.
2. **One fidelity level.** Nothing on screen may look less real than its neighbours. One untextured part or default-material prop breaks the whole frame (section 10).
3. **Real scale, real materials.** Every asset is built to real dimensions (section 4.1) and real material values (section 5). Reference photos beat taste.
4. **Judge on the phone, in all four lighting presets.** An asset is approved only after it holds up in Clear, Overcast, Storm and Night on a phone-sized frame at Low quality and at High quality on desktop.
5. **Honest light.** Lighting comes from the sun, sky and real light sources. No baked fake highlights, no decorative emissives.

---

## 2. Reference touchstones

We copy no designs, names, liveries or assets. Each reference lends one quality. Links are in [document 08](08-references.md).

| Reference | What we take | What we leave |
|---|---|---|
| **RNLI footage and photography** (launches, shouts, crew training) | The core look: boat proportions, how crews move on a pitching deck, kit, wet surfaces, spray, slipway launches | Their livery, logos and lettering. Real incidents are never recreated. |
| **"The Finest Hours"** (2016 film) | Night storm palette, searchlights on breaking water, a small boat against huge seas | Its period setting and grim moments |
| **"The Perfect Storm"** (2000 film) | Storm scale, wave faces, spindrift, rain and light under heavy cloud | Disaster tone |
| **Sea of Thieves** (Rare) | **Water motion only:** how swells roll, crest and break, how boats ride them | Its stylized colour, foam shapes and everything else |
| **Real coast photography** (Cornwall, Isles of Scilly, Maine) | Harbour towns, granite and slate, water colour over sand and kelp, overcast light | Postcard grading |
| **Most realistic Roblox games** (to be checked live; research found no verified realistic ocean game, section 1) | The current Roblox ceiling: what Future lighting, SurfaceAppearance and Clouds can do | Mixed fidelity and avatar-in-photoreal mistakes |

The research could not verify CCU or technique for the realistic Roblox games it named (Emergency Response: Liberty County, Greenville, Southwest Florida, Blackhawk Rescue Mission 5 and others) (unverified). Check them live before using them as benchmarks.

---

## 3. Palette

The palette is a **reference palette**: colours sampled from real photographs and real safety standards, used to check albedo maps and screenshots. It is not a set of colours to paint with. All hex values are starting points (tune): re-sample them from the asset's own reference board (section 10.3) and replace these if they differ.

### 3.1 Reference palette

**Water** (surface colour as it appears on screen, not albedo):

| Condition | Hex | Notes |
|---|---|---|
| Deep water, clear day, facing away from sun | `#0E3442` | Deep blue-green. The darkest large area on screen in daylight. |
| Deep water, clear day, mid-tone | `#1C4E5C` | Wave faces lit by sky |
| Deep water, bright overcast (default) | `#34484C` | Grey-green, low saturation |
| Deep water, overcast troughs | `#202E31` | |
| Storm water, faces | `#2B3438` | Near-neutral slate |
| Storm water, troughs | `#151C1F` | |
| Shallows over white sand, sun (Scilly-style) | `#4C9C94` | The brightest, most saturated water. Sheltered bays only. |
| Shallows over kelp and rock | `#24423D` | |
| Harbour water (sheltered, churned) | `#33483F` | Slightly brown-green |
| Night water under moonlight | `#070D12` | Lit mainly by searchlights and nav lights |
| Foam, fresh (overcast) | `#DCE2E1` | Never pure white |
| Foam, decaying streaks | `#9FAAAA` | Lace and streaks behind breaking crests |

**Sky and air:**

| Condition | Hex |
|---|---|
| Clear zenith | `#5E8FC0` |
| Clear horizon haze | `#C9D3D8` |
| Bright overcast | `#B3B9BC` |
| Storm cloud base | `#4A5157` |
| Rain curtain / sea mist | `#8E979B` |

**Land and town:**

| Material | Hex | Material | Hex |
|---|---|---|---|
| Granite, dry | `#8A8781` | Granite, wet | `#4E4C49` |
| Slate roof | `#4B5257` | Whitewashed render | `#E3DFD5` |
| Harbour stone | `#7D756A` | Dry sand | `#CDBB98` |
| Wet sand | `#8C7B62` | Kelp and wrack | `#4B4A26` |
| Lichen (yellow) | `#C9B458` | Coastal grass | `#5E6E3A` |
| Rust | `#8B4A25` | Salt crust | `#D9D6CC` |

### 3.2 Reserved signal colours

These are real safety colours, and in Mayday they carry gameplay meaning. Do not use them for decoration, buildings, cosmetics or props ([document 04](04-monetization.md) relies on this list).

| Signal | Hex (sRGB approximation) | Meaning |
|---|---|---|
| Hull Orange | `#FF6600` | Us: Gale Isles Coastguard vessels and aircraft, superstructure and topsides. |
| Hi-Vis Yellow | `#DFFF00` | Us: crew kit (helmets, jacket panels, lifejacket covers on duty). A fluorescent yellow-green, as in hi-vis workwear. |
| SOLAS Orange | `#FF5A1F` | Someone to rescue: casualty lifejackets, liferafts, lifebuoys and survival suits. |
| Distress Red | `#FF2A1A` (emissive) | A survivor marking their position: hand-held red flares and parachute flares, as in real life. |
| Retroreflective silver | `#D6D9DC` (plus scripted flare-up, section 9) | Tape on lifejackets, liferafts and crew kit. Lights up under a searchlight. |
| Waypoint Green | `#3EE07A` | HUD only: waypoints, drop-off and "ready" states. Never in the 3D world. |

Hull Orange and SOLAS Orange are deliberately close, because they are close in real life. They are separated by context (hull versus person in the water) and by the casualty's strobe and tape. Hi-vis yellow is far from both in hue. Check every pair with a colour-blind simulator (protanopia and deuteranopia) before locking them (tune). Real fluorescent colours look brighter than any albedo can; we mimic that with a small `EmissiveMask` boost on hi-vis and SOLAS panels in low light only (tune, and verify `EmissiveStrength` can be scripted at runtime).

Nav light colours (port red, starboard green, masthead and stern white, blue emergency beacon) follow section 6.3. They are real lights and are not palette colours.

### 3.3 Value and contrast rules

- **Albedo ranges (PBR).** Non-metal albedo stays between sRGB 30 and 240 in value. Fresh foam and whitewash sit near the top, wet rock and black rubber near the bottom; nothing is pure black or pure white. Metals use metalness 1 with bright albedo (sRGB 180 to 250) and no baked shading. A script checks every albedo map for out-of-range pixels ([document 06](06-tools-and-pipeline.md), section 2.1).
- **Saturation ceiling.** Environment materials stay under about 45% HSV saturation (tune). Only the reserved signal colours, real signage and real lights go above it. This is true to life (safety colours are chosen because nature never makes them), and it is what keeps rescue targets readable.
- **Water is the darkest large area in daylight.** Boats, survivors and foam sit on it as lighter or more saturated shapes.
- **Foam is the brightest large area.** It must not bloom. Bloom thresholds (section 6) are set so only the sun, its glints and real lights bloom.
- **Wet is darker and glossier.** Wet surfaces drop albedo value by about 20 to 30% and roughness by about 0.3 (tune). Rain does this to the whole town (section 5.4).
- **Contrast comes from light, not paint.** No painted-in highlights or shadows in albedo maps. Ambient occlusion is a separate effect of the lighting engine, with only a faint cavity bake (under 15%) in albedo for small crevices.

### 3.4 Zone looks

Zone names and scope come from [document 01](01-game-canon.md). Each zone must be nameable from a hidden-UI screenshot (section 10.3).

| Area | Real-world reference | Look |
|---|---|---|
| Port Haven town and harbour | Cornish harbour towns, Maine fishing harbours | Granite quays, slate and render, wet cobbles, fishing boats on moorings, the station and slipway as the focal point |
| Sheltered bay (Calm Bay) | Cornish coves, sandy bays | Pale sand, green-turquoise shallows in sun, swimmers and paddleboarders, low swell |
| Reef zone | Isles of Scilly, Atlantic skerries | Granite ledges and skerries, kelp, grey seals, clear green water over white sand, white water on the rocks |
| Open sea | Western Approaches | Long grey-green swell, nothing but sky and sea, distant shipping |
| Storm front | RNLI storm footage, "The Perfect Storm" | Slate water, spindrift, rain curtains, low cloud, visibility down to a few hundred studs |
| Ice zone (later, if kept) | Labrador and Newfoundland coast | Grey-white bergs and growlers, dark cold water, low sun |

**Open issue for document 01:** a tropical coral reef (turquoise lagoon, sea turtles, coral) does not fit a North Atlantic setting. This bible assumes the reef zone is a cold-water rocky reef. The owner of 01 decides; until then, reef art waits.

---

## 4. Scale, form and vehicles

### 4.1 Real scale

- **Convention: 1 metre = 3 studs** (1 stud is about 0.33 m), chosen so the 5.5-stud avatar mannequin in the Blender template is a 1.8 m adult. Roblox's own physics docs reportedly use 0.28 m per stud (unverified); we scale to the avatar because avatars are the scale players see. Record the decision in the Blender template ([document 06](06-tools-and-pipeline.md), section 2.1).
- **Every asset passes a scale check** against real dimensions taken from its reference board (section 10.3). Allowed deviation: 5% without a note; up to 15% for gameplay (for example cabin room for avatars) with a note in the asset sheet; never more.

Reference dimensions (general knowledge, unverified; confirm each from manufacturer or official class pages on the reference board):

| Subject | Real size | In studs |
|---|---|---|
| Adult | 1.8 m tall | 5.4 |
| D-class style inshore inflatable | about 5 m long, 2 m beam | 15 x 6 |
| Atlantic 85 style RIB | about 8.4 m long, 2.85 m beam | 25 x 8.5 |
| Shannon style all-weather lifeboat | about 13.6 m long, 4.5 m beam | 41 x 13.5 |
| Severn style all-weather lifeboat | about 17 m long, 5.5 m beam | 51 x 16.5 |
| Three-seat PWC (jet ski) | about 3.4 m long, 1.2 m beam | 10 x 3.6 |
| AW189 style SAR helicopter | about 17.6 m overall, 14.6 m rotor | 53 overall, 44 rotor |
| MH-65 style SAR helicopter | about 11.6 m long, 11.9 m rotor | 35 long, 36 rotor |
| Newfoundland dog | 66 to 71 cm at the shoulder, 45 to 68 kg | about 2.1 at the shoulder |
| Lifebuoy ring | about 0.75 m outer diameter | 2.25 |
| Small harbour lighthouse tower | 10 to 25 m | 30 to 75 |

### 4.2 Vehicles

Each vehicle is modelled on a real class type and its proportions, but it is **not a replica**: change details such as console layout, window shapes, fender pattern and mast arrangement so no asset is a one-to-one copy of a specific manufacturer's product. Whether a hull or airframe design needs a licence is a legal question we have not checked (unverified; not legal advice). Aircraft makers in particular may license their designs for games, so the helicopter is a generic blend, not a copy of either reference.

| Game vehicle (names in [01](01-game-canon.md)) | Modelled on | Key features to get right |
|---|---|---|
| RIB inflatable | RNLI D-class and Atlantic 85 style inshore lifeboats | Grey tube collar with rub strakes, rigid hull, console with grab handles, A-frame with lights and radar, outboards |
| Lifeboat | Shannon or Severn style all-weather lifeboats | Self-righting hull, raised wheelhouse with raked windows, mast with lights and radar, deck rails and grab rails, waterjets or props |
| Jet ski | Rescue PWC with a rescue sled | Three-seat hull, rear rescue sled (board) with handles |
| Rescue helicopter | AW189 and MH-65 style SAR helicopters | Twin-engine body, side door with hoist arm, searchlight and FLIR turret, nose radar, enclosed or conventional tail rotor (choose one; do not copy either exactly) |
| Rescue board, hovercraft, patrol cutter (if kept in 01) | Lifeguard boards, rescue hovercraft, coastguard cutters | Same rules: real class, generic details |

**The Gale Isles Coastguard livery (invented, not RNLI or USCG):**

- Hull Orange topsides and superstructure, a dark charcoal hull below the sheer line (`#2B2F33`), a white or light-grey wheelhouse roof and a retroreflective silver band along the sheer.
- "GALE ISLES COASTGUARD" in a plain sans serif, white on orange, and an invented crest: a lighthouse inside a compass rose. Fleet numbers such as "GI-17" on the bow and the helicopter's tail.
- Helicopter: Hull Orange and white with a matte black anti-glare panel ahead of the windscreen, invented registration "GI-R01".
- Not allowed: RNLI flag or lettering, the USCG racing stripe, any real coastguard crest, any real registration, any red cross or white cross symbol (the Red Cross emblem is legally protected), real flags of countries. Moderation and trademark both point the same way.

### 4.3 Buildings, rocks and terrain

- **Buildings** follow real vernacular: granite and slate cottages, a pilot's lookout, a fish market, a chandlery, a boathouse-style lifeboat station with a slipway. Modular kits with real wall thickness, window reveals, gutters, downpipes and weathering streaks.
- **Lighthouses** are real types (round granite towers, white-painted towers, a small pier light), each with its own real light characteristic (section 6.3).
- **Rocks and cliffs** are scan-based (CC0 scans, section 11) or sculpted and baked from scans, with tiling detail and macro variation so no two cliffs repeat.

---

## 5. Materials and budgets

### 5.1 PBR with SurfaceAppearance

- Every mesh asset uses a `SurfaceAppearance` with ColorMap, NormalMap, RoughnessMap and MetalnessMap (research section 3.1). No hero asset uses a default Roblox material.
- Map rules (from the Roblox texture specifications page, research section 3.1): albedo RGB 24-bit; normal RGB 24-bit, **tangent-space, OpenGL convention only**; roughness and metalness single-channel 8-bit greyscale; .png, .jpg, .tga or .bmp. Name maps with `_ALB`, `_NOR`, `_RGH`, `_MET` suffixes.
- **Texture cap: 1024 vs 4096 (verify).** The same official page states both "up to 4096 x 4096" and "up to 1024 x 1024" (research section 3.1). We author masters at 4096 and ship 1024 until Spike 1 ([document 06](06-tools-and-pipeline.md), section 7) confirms the cap, its memory cost and how texture streaming scales it on phones.
- Specularity is fixed per material and there is no IOR control (research section 2.3). Water, glass and wet paint get their look from roughness, normals and the environment, not from tuned specular.
- One material per mesh is commonly reported (unverified); split meshes by material or atlas them.
- `SurfaceAppearance` on `EditableMesh` is not documented (verify). The ocean spike tests it (section 7.2).

### 5.2 MaterialVariants for terrain and parts

- `MaterialService` with custom `MaterialVariant`s for terrain (sand, wet sand, shingle, granite, grass, mud) and for large part-built surfaces (quay stone, cobbles, concrete slipway, tarmac, non-slip deck). Research found no verified page for the API (verify the properties and the terrain override behaviour in Studio).
- Each variant gets full PBR maps from CC0 scans (section 11), with `StudsPerTile` set to hit the texel density in section 5.3.
- **Wet variants.** Every outdoor variant has a wet twin (darker albedo, lower roughness, sharper normals in puddles). The weather controller swaps parts to wet variants in rain (verify that the `MaterialVariant` property can be changed at runtime, and how terrain can switch).
- Break tiling with macro variation: decals of dirt and moss (section 5.5), rotated and scaled variant pairs, and real clutter.

### 5.3 Texel density

The Roblox texture page recommends 256 px for a 5 x 5 stud object, 512 for 10 x 10 and 1024 for 20 x 20, which is about **51 px per stud** (research section 3.1). Default materials use 1024 on an 8 x 8 stud face (128 px per stud).

| Tier | Where | Target |
|---|---|---|
| Hero close-up | Decks, consoles, crew kit, the dog, anything the camera reaches within 10 studs | 100 to 128 px per stud (needs multiple 1024 sets or trim sheets; 2048 if Spike 1 allows) |
| Standard | Hulls, buildings near the harbour, props | 51 px per stud (the Roblox recommendation) |
| Background | Distant town, cliffs beyond 300 studs | 25 px per stud plus tiling detail |

Vary by no more than one tier between neighbouring assets, so fidelity never jumps across a frame.

### 5.4 Wear, grime and wet surfaces

Wear tells the asset's story and follows real causes:

- **Station fleet:** well maintained but hard-used. Edge wear on painted corners (curvature-baked), fender and tube scuffs, salt crust around fittings and the waterline, polished stainless where hands grip.
- **Fishing boats and the harbour:** heavier. Rust bleeding from iron fittings, weed lines at the waterline, flaking paint, oil stains on quays, rope wear on bollards.
- **Wrecks and big-call ships:** heaviest. Fire scorch, oil sheen on the water around them, dents.
- **Wet surfaces.** Decks, hulls, crew kit and the dog have a dry and a wet state. Spray and rain switch to the wet state (lower roughness, darker albedo, a drip particle). Swapping a pre-made wet `SurfaceAppearance` at runtime is our plan; scripts may not be able to edit `SurfaceAppearance` maps directly (verify both).
- No wear without a cause. Random grunge overlays are not allowed.

### 5.5 Decals

- Roblox `Decal` objects carry colour only, with no normal or roughness (unverified). Use them only for flat, matte marks (paint numbers, posters, dirt on walls).
- **PBR decals** (hull lettering, rust streaks, salt stains, the crest) are thin decal meshes with their own `SurfaceAppearance` and `AlphaMode` set to Overlay or Transparency (verify behaviour), offset just off the surface to avoid z-fighting.
- Text and crests are authored as vector art, rendered at 2x and downsampled, so they stay sharp.

### 5.6 Triangle and texture budgets with LOD

The per-MeshPart triangle cap is reported at about 20,000 to 21,000 (vendor sources; verify in the 3D Importer). We split heavy assets into MeshParts of 10,000 triangles or fewer. Budgets are engineering judgment (tune); no official per-scene numbers were found (research section 3.3).

| Asset class | LOD0 total | Max per MeshPart | LOD1 | LOD2 / far | Texture sets (1024 until verified) |
|---|---|---|---|---|---|
| All-weather lifeboat | 60,000 | 10,000 | 25,000 | 6,000 | 5 to 6 (hull, deck, wheelhouse, interior, fittings, decals) |
| RIB / inshore boat | 35,000 | 10,000 | 12,000 | 3,000 | 3 to 4 |
| Jet ski with sled | 20,000 | 10,000 | 8,000 | 2,000 | 2 |
| Rescue helicopter | 60,000 | 10,000 | 25,000 | 6,000 | 5 to 6, plus rotor blur discs |
| Big-call ship (ferry, trawler) | 90,000 | 10,000 | 30,000 | 8,000 | 6 to 8, plus trim sheet |
| NPC person (casualty, crew) | 20,000 | 10,000 | 8,000 | 2,000 | 2 (body, head) plus hair cards |
| Newfoundland dog | 25,000 plus fur cards up to 15,000 | 10,000 | 10,000 | 3,000 | 2 to 3 (body, fur cards, harness) |
| Player crew kit (layered clothing, accessories) | Within Roblox layered clothing and accessory limits (verify) | n/a | n/a | n/a | 1 to 2 per item |
| Hero building (station, lighthouse) | 40,000 | 10,000 | 15,000 | 3,000 | 4 plus trim sheet |
| Building module | 3,000 to 8,000 | 8,000 | 50% | Streamed out or LOD mesh | Shared trim sheet plus MaterialVariants |
| Rock or cliff piece | 5,000 to 15,000 | 10,000 | 40% | 15% | 1 unique plus tiling detail |
| Small prop (buoy, fender, crate, ring) | 500 to 3,000 | 3,000 | 50% | Cull | Shared prop atlas |

**Scene targets (tune):** about 2 million rendered triangles on desktop High; about 500,000 on a mid-range phone at Low. About 80 unique 1024 sets in view on desktop; on phones, texture streaming handles memory (research section 3.3; details unverified).

**LOD tools:**
- `RenderFidelity`: Automatic for most meshes (reported switch distances of 250 and 500 studs come from search snippets only (verify)), Performance for background props, Precise only for the player's own vessel and the dog up close (research section 3.3).
- Custom LOD models (LOD0, LOD1, LOD2) swapped by a client script by camera distance with hysteresis, for vessels and the helicopter.
- `StreamingEnabled` on, with distant town models kept as low-detail stand-ins where the streaming level-of-detail option allows (verify the property and its look).
- The ocean has its own LOD rings ([document 06](06-tools-and-pipeline.md), section 3.1).

---

## 6. Lighting presets

Four presets live as data in `src/shared/LightingPresets` and are blended by the weather controller ([document 06](06-tools-and-pipeline.md), section 3.4). All values are starting points (tune).

### 6.1 Global settings

- Lighting technology: **Future** (the shipping status and the exact setting name are unconfirmed in research; verify in Studio). Do not fall back to ShadowMap on hero scenes; mobile quality tiers drop effects instead ([document 06](06-tools-and-pipeline.md), section 3.5).
- `LightingStyle` Realistic, `EnvironmentDiffuseScale` 1, `EnvironmentSpecularScale` 1 (from the official Future lighting tutorial, research section 4.1).
- `GeographicLatitude` 50 (Cornwall; Maine is about 44) (tune). `GlobalShadows` on.
- `Atmosphere` takes most of its colour from the skybox (research section 4.1), so each preset has its own sky.

### 6.2 Presets

| Property | Clear day | Overcast (default) | Storm | Night |
|---|---|---|---|---|
| `Brightness` | 3.0 | 1.8 | 1.0 | 0.3 |
| `ExposureCompensation` | 0 | +0.2 | +0.3 | +0.5 |
| `Ambient` | `#2E3238` | `#3A3F44` | `#33383D` | `#0B0F15` |
| `OutdoorAmbient` | `#7C8590` | `#8D949A` | `#6A7278` | `#1C2533` |
| `ColorShift_Top` | `#FFF1DC` | `#D8DEE2` | `#A9B2B8` | `#6B7FA0` |
| Atmosphere `Density` / `Offset` | 0.28 / 0.10 | 0.38 / 0.05 | 0.55 / 0 | 0.32 / 0.10 |
| Atmosphere `Haze` / `Glare` | 0.8 / 0.3 | 2.0 / 0 | 3.0 / 0 | 1.0 / 0 |
| Atmosphere `Color` | `#C9D3D8` | `#A9B0B4` | `#6F777D` | `#1A2230` |
| Atmosphere `Decay` | `#6E8AA5` | `#7D858A` | `#4F575D` | `#0C1018` |
| Clouds `Cover` / `Density` | 0.35 / 0.25 | 0.85 / 0.55 | 0.95 / 0.90 | 0.60 / 0.40 |
| Clouds `Color` | `#FFFFFF` | `#C9CED1` | `#5E666C` | `#2A3038` |
| Sky (cubemap) | Clear Atlantic sky with high cirrus | Bright overcast | Heavy storm cloud | Moonlit thin cloud with stars |
| ColorCorrection contrast / saturation | 0.05 / 0 | 0.08 / -0.10 | 0.12 / -0.25 | 0.10 / -0.20 |
| ColorCorrection tint | `#FFFFFF` | `#F2F5F7` | `#E8EEF2` | `#DCE4F0` |
| Bloom intensity / size / threshold | 0.3 / 24 / 1.6 | 0.2 / 24 / 1.8 | 0.25 / 28 / 1.6 | 0.6 / 32 / 1.0 |
| DepthOfField far intensity (gameplay) | 0.05 | 0.10 | 0.20 | 0.10 |
| SunRays intensity | 0.05 | off | off | off |

Post-processing property names and behaviour were not covered by the fetched pages (research section 4.3; verify). DepthOfField in gameplay is only a faint far falloff that sells distance; it never blurs anything the player must read. The cinematic camera may use stronger DepthOfField ([document 07](07-store-page-thumbnails-and-trailer.md), section 5.3).

**Skyboxes:** each preset has a `Sky` built from CC0 HDRIs (Poly Haven, section 11) converted to six cube faces in Blender at the verified texture cap. Photographed skies carry only high cloud; low cloud comes from dynamic `Clouds` so it moves and shades with the weather (research section 4.2). Roblox cannot blend two skyboxes (unverified), so the controller swaps the `Sky` at the peak of a haze ramp, when Atmosphere hides the change.

**Rules:**
- `ClockTime` only moves forward with the day cycle. **A storm never changes it**: the storm look comes from `Brightness`, clouds, atmosphere, sky and colour correction, so the sun never runs backwards when a storm rolls in ([document 02](02-core-loop-and-mechanics.md) relies on this rule). Night is reached by the day cycle, and weather presets blend on top of the time of day.
- Overcast is the default weather. Clear days are a treat; storms come on the storm timer.
- A Roblox staff post mentions a Clouds rendering upgrade; tuned clouds may need retuning after engine updates (research, tools section 4).

### 6.3 Night lights and real light sources

All lights are real fixtures with real colours and positions (general maritime practice; unverified detail).

| Light | Where | Look |
|---|---|---|
| Port sidelight | Port side, red, shines forward and to port | Small emissive lens plus a short-range `PointLight` |
| Starboard sidelight | Starboard side, green, a different shade from Waypoint Green | Same |
| Masthead light | White, forward on the mast | Same |
| Stern light | White, aft | Same |
| Blue emergency beacon | Our vessels on a call | Rotating or flashing blue, under 3 flashes per second |
| Searchlights | Lifeboat wheelhouse roof, RIB A-frame, helicopter turret | `SpotLight` plus a volumetric `Beam` cone; spray and rain lit inside the cone. `SpotLight` range is reported to be capped (around 60 studs, verify), so the far beam is the `Beam` cone plus a scripted brightness pool on the water. |
| Helicopter lights | Red anti-collision beacon, white strobes, nav lights, searchlight, cabin glow | Real flash rates, under 3 flashes per second |
| Lifejacket strobes | Every casualty | White flash about once per second (real lifejacket lights flash roughly 50 to 70 times a minute, unverified) |
| Lighthouses | Each tower | A rotating beam cone and its own real light characteristic (flash pattern), after Trinity House practice ([document 08](08-references.md)) |
| Town | Street lamps, windows, the station floodlights over the slipway | Warm sodium and LED whites, real fixtures only |

Arc limits for sidelights and stern lights are done with lens shrouds in the mesh, not light angles. Flashing never exceeds 3 flashes per second (accessibility).

---

## 7. The ocean and VFX

### 7.1 The deep-water look

Roblox gives creators no custom shaders (research section 2.3), so the sea is built from geometry, materials and particles. The wave physics stays the shared sine-wave function in [document 06](06-tools-and-pipeline.md), section 3.1; the visuals sit on top of it.

| Layer | How |
|---|---|
| Swell shape | A skinned or `EditableMesh` wave grid around the camera, driven by the same summed sines as physics, with a small Gerstner-style sideways offset for sharper crests ([document 06](06-tools-and-pipeline.md), section 3.1). Motion is judged against Sea of Thieves and real footage. |
| Surface detail | `SurfaceAppearance` on the wave mesh: a tiling normal map of wind chop and capillary ripples baked from a Blender ocean sim or a CC0 water scan, roughness low (about 0.05 to 0.12 calm, 0.2 to 0.3 storm), metalness 0 (tune). Whether `SurfaceAppearance` works on `EditableMesh` and whether its UVs can scroll is unknown (verify; spike O1). |
| Reflections | Future lighting environment specular from the skybox on the low-roughness surface. There are no screen-space reflections, so hulls do not reflect (accepted: chop breaks real reflections anyway). Terrain water reflections are not used (no Terrain water, and research says they drop below graphics quality 8). |
| Depth colour | Vertex colour by depth and height from the reference palette (section 3.1), if `EditableMesh` vertex colour holds up; otherwise a per-zone tint of the `SurfaceAppearance` colour. Shallows use a partly transparent water tile over a seabed texture pre-tinted with water colour, so sand and kelp read through the water without depth shaders. |
| Crest foam | Whitening of vertices above a steepness threshold (vertex colour), plus foam-streak decal meshes on the biggest crests and sparse foam particles near the camera |
| Hull foam | A foam ring mesh hugging each hull at the waterline (alpha `SurfaceAppearance`, follows `heightAt`), plus a churn particle at the stern |
| Wakes | A chain of foam ribbon segments (`Beam` between attachments re-placed on `heightAt` each frame) in a Kelvin wake shape, plus a turbulent stern trail; fades over about 6 seconds (tune) |
| Spray | `ParticleEmitter` flipbooks rendered from Blender fluid sims: bow sheets, slam bursts, droplet mist; lit particles (`LightInfluence` 1); real acceleration (about 29.4 studs per second squared at our scale) rather than the default floaty fall |
| Spindrift | In storms, horizontal spray streaks blown off crests in the wind direction; dense near the camera, rarer far out |
| Rain on water | Ring-splash particles and a darker, rougher water state |
| Rocks and shore | Breaking white water and wash particles where waves meet rocks, a foam line on beaches |
| Wet decks | Decks and crew switch to their wet state when spray hits them (section 5.4); green water running off the deck after a slam |

Foam and caustics are baked into textures and flipbooks, never redrawn per frame with `EditableImage` (research section 6).

### 7.2 Honest risk and the ocean spike

**Risk:** the ocean may not reach photoreal on Roblox. We have no Fresnel control, no subsurface glow in crests, no refraction, no depth buffer for shoreline foam, no screen-space reflections, and mesh deformation is CPU-heavy (research section 2). Transparency sorting between water, foam and particles is untested (research section 2.2). The fallback is not stylization: it is more mist, more overcast and more spray, which hide the weaknesses the way real North Atlantic weather does.

**Spike plan** (runs inside spike 2 in [document 06](06-tools-and-pipeline.md), section 7). Each step is judged on a contact sheet of fixed screenshots at 768 px, compared side by side with three reference photos (clear, overcast, storm), by a fresh art-director reviewer who sees only the sheet, this section and the references.

| Spike | Build | Pass | Fail means |
|---|---|---|---|
| O1: still surface | One ocean tile with `SurfaceAppearance` (EditableMesh and skinned versions) in all four presets | No visible normal-map tiling repeat in a 1920 x 1080 frame from deck height; no plastic sheen; colour within one step of the reference palette; no facets on wave silhouettes nearer than 200 studs; the reviewer marks it "could pass for a real photo at phone size" in at least the Overcast and Storm frames | Try the other mesh type; if both fail, more haze and overcast as the default, and re-test |
| O2: motion | A 10-second capture at High and Low tiers | No visible grid snapping, sliding or popping between LOD rings or tiers; foam does not pop; motion reads as heavy and slow like the references | Lower wave count in the visual sum, lengthen LOD blend distances |
| O3: hull and weather | The RIB and lifeboat at speed in Overcast and Storm, with wake, hull foam, spray and spindrift | Hull waterline error under about 0.3 studs ([document 06](06-tools-and-pipeline.md), section 3.1); no hull floating on or sinking through foam; wake follows the waves; the reviewer passes the frame against the storm reference | Fix layer order and transparency; simplify foam |
| O4: phone | The O3 scene on a mid-range phone at Low | Frame time on target ([document 06](06-tools-and-pipeline.md), section 3.5) and the Low contact sheet still passes the O1 colour and tiling checks | Drop effects per the tier table, never physics |

No production ocean art starts until O1 to O4 pass.

### 7.3 Other VFX

All built with `ParticleEmitter`, `Beam` and `Trail`, using flipbooks rendered in Blender from real simulations and lit by scene light. Particle counts scale with quality tier ([document 06](06-tools-and-pipeline.md), section 3.5).

| Effect | Build | Notes |
|---|---|---|
| Rotor downwash | A ring of driven spray and flattened water below the helicopter, radius by altitude | The "helicopter is here" signal |
| Rain | Camera-attached streak particles, splash rings on surfaces, drips from roofs | Off under cover (raycast up) |
| Lightning | Branching `Beam` bolts plus a lighting flash inside clouds | Under 0.15 s, no strobing (accessibility) |
| Red hand flare | A bright emissive flare head, dense pink-red smoke, sparks, a red `PointLight` | Real distress signal from survivors |
| Parachute flare | A slow-falling red light under the cloud base | Big-call distress signal |
| Orange smoke | Dense SOLAS orange smoke from a canister, drifting downwind | Survivors mark position; also shows wind direction |
| Fire and black smoke | On wrecks and burning boats | Hazard |
| Oil sheen | A rainbow-tinted, low-roughness decal mesh on the water | Wreck sites |
| Exhaust | Faint diesel haze from lifeboats and ships | |
| Dog shake-off | Water droplet burst when the dog climbs aboard | |
| Sea mist and fog banks | Low particle banks plus Atmosphere | Storm front, dawn |

---

## 8. Characters and animation

### 8.1 Players

- Players are Roblox avatars. On duty they wear **realistic crew kit**: a drysuit (layered clothing), a crew lifejacket with retroreflective tape and a light (accessory), a helmet with a visor (accessory), gloves and boots, all in PBR with wet states. Kit is applied with a `HumanoidDescription` when a player goes on duty and removed off duty.
- **Mixed fidelity is the top risk.** A blocky or cartoon avatar in photoreal kit looks wrong. Mitigations: R15 only, avatar scale ranges restricted toward realistic proportions in the game's avatar settings (verify which options exist), kit that covers most of the body, a helmet that frames the face, and cameras that keep avatars at working distance. Faces are the player's own; we never mock or replace them. Layered clothing and dynamic heads had no verified method in research (research section 5; verify fit on common body types).
- Kit colours: Hi-Vis Yellow and dark navy for crew, never SOLAS Orange (section 3.2).

### 8.2 NPC casualties and crew

- **Custom realistic rigs:** human NPCs use realistic skinned meshes on an R15-compatible skeleton so they share animations with avatars (verify skinned realistic meshes on R15). Realistic heads with skin PBR; no subsurface scattering exists, so faces stay mostly at working distance, with hoods, hats and wet hair.
- **Variety:** kayakers in buoyancy aids, swimmers, fishermen in oilskins, ferry passengers in SOLAS lifejackets, paddleboarders, lighthouse keepers, station crew. Age, build and skin tone vary.
- **Tone:** casualties are cold, tired and relieved, never injured. No blood, no wounds, no lifeless bodies.

### 8.3 Bosun, the Newfoundland

- A **realistic Newfoundland**: black coat with brown highlights in sun, about 2.1 studs at the shoulder, heavy body, webbed paws, a broad head (section 4.1).
- **Custom quadruped rig** in Blender (spine, tail, ears, jowls, front and back legs); not Mixamo, which is humanoid only (research section 5). RigEdit Lite is listed as a plugin for extra joints (verify).
- **Fur:** sculpted clump normal maps plus layered alpha fur cards on the silhouette (`AlphaMode` Transparency; verify sorting and cost). A wet state with darker, clumped, glossier fur, and a shake-off.
- **Kit:** a real water-rescue-dog harness in Hull Orange with a grab handle and retroreflective tape. No cross symbols.

### 8.4 Animation

- **Feel:** real weight and momentum. Crew brace against roll and pitch, move hand over hand along grab rails, swimmers move slowly and heavily in cold water. No cartoon anticipation or squash.
- **Vehicles:** motion comes from physics and the ocean. Scripted extras: throttle squat, rotor tilt and flex, antenna sway, wiper sweep.
- **Sources** (all unverified; check licences before use and log them):
  - Mixamo: humanoid only; current licence wording is unclear (a 2026 article says limited preview), so re-check Adobe's terms before shipping any clip (research section 5).
  - Licensed mocap libraries: allowed only with a written licence that permits use in a Roblox game.
  - Our own capture: video reference of real tasks keyframed in Blender or the Animation Editor.
  - The dog: keyframed from real Newfoundland water-rescue footage in Blender, or licensed quadruped mocap.
- Roblox R6 and R15 animations do not transfer cleanly (research section 5); author for R15.
- **Camera:** gentle follow lag on boats, real-feeling shake on slams and nearby lightning, a "reduce motion" setting.

---

## 9. Readability and UI

Realism must still play. Every cue below exists in real rescue work, so it reads without breaking the look.

| Must read | Real-world cue | Check (tune) |
|---|---|---|
| A survivor in the water | SOLAS orange lifejacket, retroreflective tape, white strobe, waving arms, splashes, a whistle sound | Found by a reviewer in under 2 seconds on a phone-size Overcast screenshot at 150 studs |
| A survivor at night | Strobe plus tape that flares under a searchlight (scripted: the tape's emissive rises when a searchlight cone covers it and the camera is near the light) | Found in under 3 seconds at 100 studs under the searchlight |
| A survivor's position at long range | Red hand flare, orange smoke, a parachute flare on big calls, and a bearing in the HUD from their beacon | Visible at 600 studs in Overcast |
| Hazards | White water breaking on rocks, real buoyage (cardinal marks, isolated danger marks), surf roar and a bell buoy, fire and black smoke, oil sheen | A reviewer points to the hazard in a hidden-UI screenshot |
| The objective | Station slipway floodlights and leading lights, a crew member waving, plus a small HUD marker | Found in under 3 seconds |
| Our crew and vessels | Hull Orange and Hi-Vis Yellow, blue beacon on calls | Never confused with a survivor in a colour-blind test |

**Rules:**
- The 3D world stays diegetic: no glowing outlines, floating arrows, sparkles or coloured light pillars. Non-diegetic help lives in the HUD only (small markers, bearings, distances in Waypoint Green).
- An accessibility "assist markers" option (outlines on survivors) may exist, off by default; [document 02](02-core-loop-and-mechanics.md) decides.

**UI style:** clean marine electronics, like a chartplotter and VHF radio. Dark translucent panels, thin rules, high-contrast white text, Hull Orange accents, Waypoint Green for go. Fonts: Builder Sans for everything (in the Roblox font list); no cartoon or rounded display fonts. Buttons at least 48 px on phones, primary actions in thumb reach, nothing essential under Roblox's own buttons. The call card is a radio log entry: "MAYDAY", call type, zone, distance, reward, accept. Icons are rendered from the real 3D models under neutral light.

---

## 10. How we avoid slop

Photoreal is unforgiving: one cheap asset ruins the frame. These rules are strict.

### 10.1 Hard rules

- **No mixed fidelity.** Every asset in a frame meets the same texel tier band (section 5.3) and the same wear logic (section 5.4).
- **No untextured parts.** No plain-colour parts, no SmoothPlastic, no part built from default bricks in the final build. Greybox parts are tagged `GREYBOX` and a check fails the build if any remain in a release.
- **No default Roblox materials on hero assets.** Hero assets are vehicles, the dog, NPCs, crew kit, the station, lighthouses and big-call ships. Terrain and large surfaces use our `MaterialVariant`s, never the stock look.
- **Scale accuracy.** Every asset passes the real-dimension check (section 4.1).
- **A reference board per asset.** Before modelling: 10 to 20 real photos covering shape, detail, materials, wear and the asset in wet weather, with real dimensions noted. Stored in `art/reference/<asset>/`.

### 10.2 Store assets and AI

- **Roblox Creator Store:** only vetted, script-stripped meshes, and only where they pass every check here after our own re-texturing. Research shows free models can hide backdoors: strip every script, review, sandbox (`Sandboxed`, limited `Capabilities`) while testing ([`research/tools-and-assets.md`](research/tools-and-assets.md), section 5). In practice this means filler props at most, never hero assets.
- **AI generation:** allowed for reference gathering, mood boards and concept studies. Not allowed: shipping any AI-generated mesh, texture, image, icon, thumbnail or audio untouched. Anything that started as AI output is remodelled or repainted by a person and logged. Cube 3D may be used for greybox blockouts only.
- **Roblox rules:** no Roblox policy specific to AI-made 3D assets was found. Creators stay responsible for AI-generated content they deliver, must be transparent with players and must declare player-triggered AI features in the maturity questionnaire. Mayday plans no player-triggered AI at launch. The Terms reportedly absorbed the AI feature terms on 2026-04-30 (unverified). Re-check before each release.
- **Log:** every asset row records "AI used: none / concept only / assisted" and who reworked it.

### 10.3 Consistency checks

Before an asset is approved:

1. **Reference match:** side by side with its reference board; shape, proportion, material and wear match.
2. **Scale:** real-dimension check passes (section 4.1); also next to the avatar mannequin and the dock lineup.
3. **Albedo and value:** the map checker passes (section 3.3); screenshot colours sit within one step of the reference palette; no signal colour misused.
4. **Silhouette** at 64 px for vehicles, the dog and characters.
5. **Four-preset test:** screenshots in Clear, Overcast, Storm and Night, dry and wet.
6. **Phone test:** device emulator at phone resolution and Low quality.
7. **Budget:** triangles, texture sets and LODs within section 5.6.
8. **Readability** (for survivors, hazards, objectives): the section 9 checks.
9. **Zone test** (environment art): a reviewer names the zone from a hidden-UI screenshot.

### 10.4 The build, render, critique loop

1. **Build** in Blender or Studio.
2. **Render** a fixed set of views: a Blender turntable (4 angles, neutral HDRI, PBR maps applied) plus Studio screenshots in the four presets, dry and wet, with a reference photo in the same sheet. Combine into one contact sheet (Python/Pillow grid), downscaled to 768 px.
3. **Critique** with a fresh reviewer (a person, or a short-lived art-director review agent) who sees only the contact sheet, this document and the asset brief. The reviewer returns a pass or a short list of fixes. The question is "does this look real next to the photo?", not "does it look nice?".
4. **Repeat** until it passes. Hero assets need a pass in all four presets; filler props need Overcast only.

---

## 11. Asset sources and licences

Every asset row in the asset sheet records source, licence, author and date. Confirm each licence on the source's own licence page before use. Anything uploaded to Roblox can be extracted by other people, so licences that forbid redistributing raw files are a risk even when "use in games" is allowed (unverified; read each licence with this in mind).

| Source | Use | Licence status |
|---|---|---|
| Made in Blender by the team (bakes from high-poly to game mesh) | All hero assets, vehicles, the dog, NPCs, kit, station, lighthouses | Owned |
| Poly Haven | Scanned textures, HDRIs for skyboxes and look-dev, some models | CC0 per research (secondary source; confirm on polyhaven.com) |
| ambientCG | PBR materials for terrain `MaterialVariant`s, rock, stone, metal, paint | CC0 per research (confirm on ambientcg.com) |
| Quixel Megascans (now on Fab) | Rocks, cliffs, ground scans | **Unverified for Roblox.** Do not use until Fab's licence terms are checked for use outside Unreal and for upload to a UGC platform. |
| Sketchfab | Specific models | Per model. Only CC0, or CC-BY with credit; never NC (the game earns money) or ND (we modify). Paid store licences unverified for Roblox. |
| Kenney, Quaternius | Greybox blockouts only (their style does not fit photoreal) | CC0 or mostly CC0 (confirm per pack) |
| Commissioned assets | Hero models, the dog, mocap, music | Written work-for-hire with full rights transfer and a no-AI clause; contract in the project drive |
| Roblox Creator Store | Vetted, script-stripped meshes only (section 10.2) | Roblox terms |
| Licensed mocap libraries, Mixamo | Animation | Unverified; written licence or re-checked terms before use (section 8.4) |
| Sound effects | Roblox Creator Store audio (free to use in Roblox); recorded or designed by the team; Freesound CC0 clips only (unverified) | Roblox terms / Owned / CC0 |
| Music | Roblox Creator Store music or commissioned | For off-Roblox marketing, commissioned or cleared music ([document 07](07-store-page-thumbnails-and-trailer.md)) |
| Fonts | Roblox built-in fonts | Roblox |

Credits for every CC0, CC-BY and commissioned asset go in the in-game credits board and the description footer, even where the licence does not require it.
