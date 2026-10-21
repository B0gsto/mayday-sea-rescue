# 06 · Tools and pipeline

Every tool we use, how photoreal PBR art gets from Blender into Studio, the technical approach for the ocean, vehicles and storms, the mobile performance plan, the repo layout, and a checklist from zero to a playable greybox.

Marks: **(verify)** means research could not confirm it on an official page, or sources conflict; test in Studio first. **(unverified)** means secondary source or general knowledge. **(tune)** means a starting value.

Research sources: [`research/tools-and-assets.md`](research/tools-and-assets.md) and [`research/photoreal.md`](research/photoreal.md). The look itself is set in [document 05](05-art-direction.md).

---

## 1. Tools

### 1.1 Code toolchain (pinned in `rokit.toml`)

| Tool | Version | What it is for |
|---|---|---|
| Rokit | (manager) | Installs and pins every CLI tool below from `rokit.toml`. `rokit install` on a fresh machine. CI uses `CompeyDev/setup-rokit` with the same file. |
| Rojo | 7.7.1 | Syncs `src/` on disk into Studio live (`rojo serve`) and builds place files (`rojo build`). Code lives in git, not in the place file. |
| Wally | 0.3.2 | Luau package manager (`wally.toml`). Installs libraries into `Packages/`. |
| wally-package-types | 1.7.0 | Fixes type exports for Wally packages so Luau LSP sees them. |
| Luau LSP | 1.70.1 | Type checking, autocomplete and go-to-definition in VS Code. Also runs `luau-lsp analyze` in CI. |
| Selene | 0.32.0 | Linter (`selene.toml`, Roblox standard library). |
| StyLua | 2.6.0 | Formatter (`stylua.toml`). CI runs `stylua --check`. |
| Lune | 0.10.5 | Runs Luau outside Roblox: build scripts, Open Cloud uploads, asset manifest generation, and unit tests for pure modules (wave maths, economy tables). |

### 1.2 Engine and services

| Tool | What it is for |
|---|---|
| Roblox Studio | Level building, terrain, lighting, physics tuning, playtests, publishing. Map geometry lives in the place file. |
| Studio Assistant | Built-in AI helper for script drafts and data-model edits. Treat its output like any code review. Not used to generate shipped meshes or textures ([document 05](05-art-direction.md), section 10.2). |
| Studio MCP server | Built in. Enable in Assistant > ... > Manage MCP Servers > "Enable Studio as MCP server". Lets an external MCP client (for example Claude Code) read the instance tree, edit scripts, run Luau and control playtests. Needs the latest Studio, and each call needs a `studio_id`. Connect only trusted clients, because they can modify the open place. Community MCP servers are not vetted; do not use them. |
| Open Cloud | REST APIs. Place Publishing (needs Place ID, Universe ID and an API key with `universe-places` Write) for CI publishing to a test place; Assets API for uploading images, audio and models with versions (check which asset types it accepts (verify)). Keys live in a password manager and CI secrets, never in the repo. |
| Animation Editor | Built-in. Player and NPC animations on R15 rigs. |
| Moon Animator | Studio plugin for cutscenes and camera paths (store intro, trailer shots). Research found no 2026 information (verify it is still maintained before relying on it; the Animation Editor is the fallback). |

### 1.3 Content tools

| Tool | What it is for |
|---|---|
| Blender 5.2 | Modelling, sculpting high-poly sources, UVs, PBR baking with Cycles (albedo, normal, roughness, metalness, AO and curvature masks), the dog and NPC rigs, ocean normal-map and spray simulations, flipbook renders, HDRI-to-cubemap skyboxes, turntables. Runs headless (`/Applications/Blender.app/Contents/MacOS/Blender --background`). |
| Texture painting | Blender texture paint and layered bakes by default. Adobe Substance 3D Painter is optional if a licence is already owned (its terms for game use not checked here (unverified)). |
| Image editor | Map clean-up, decals, UI art, icon finishing. Krita or GIMP (free); Photoshop or Affinity if already owned. |
| Audio editor | Trimming, looping and loudness-matching SFX. Audacity (free) or Reaper. Export OGG or MP3 for Roblox (verify accepted formats in the upload dialog). |
| OBS Studio | Gameplay capture for the video thumbnail and short-form clips ([document 07](07-store-page-thumbnails-and-trailer.md)). |
| Video editor | Cutting the gameplay video and shorts. DaVinci Resolve (free) or similar. |
| Python 3 with Pillow | Contact sheets for the build, render, critique loop ([document 05](05-art-direction.md), section 10.4) and the texture map checker (section 2.1). |
| VS Code | Code editor with the Luau LSP, Selene and StyLua extensions. |

---

## 2. Blender to Studio pipeline (PBR)

Research found the official 3D Importer and mesh-limit pages unavailable, vendor sources disagree, and the official texture page contradicts itself (1024 versus 4096). Every limit in this section is (verify) until Spike 1 (section 7) tests it in a throwaway place.

### 2.1 Steps

1. **Reference first.** Build the asset's reference board in `art/reference/<asset>/`: 10 to 20 real photos and real dimensions ([document 05](05-art-direction.md), section 10.1). No modelling without it.
2. **Start from the template.** `art/blender/_template.blend` holds the unit setup, a 5.5-stud avatar mannequin (a 1.8 m adult), a water plane at Y = 0, a dock with every vehicle's real footprint, a neutral studio HDRI and an overcast sea HDRI, and the reference palette as swatches.
3. **Units.** Model in studs with the project scale of **1 metre = 3 studs** ([document 05](05-art-direction.md), section 4.1): 1 Blender unit = 1 stud. Unit mismatch is the most common import error. Confirm the importer's scale on the first export and record it here.
4. **High-poly source.** Sculpt or subdivide a high-poly model for hulls, fittings, rocks and the dog. Keep it in `art/blender/` as the bake source.
5. **Game mesh.** Retopologise to the LOD0 budget in [document 05](05-art-direction.md), section 5.6. Split into MeshParts of 10,000 triangles or fewer (the cap is reported at about 20,000 (verify)). Weighted normals; bevel any edge the camera can reach.
6. **LODs.** Make LOD1 and LOD2 meshes (decimate plus clean-up) with the same UV layout, so they share texture sets. Name them `_LOD0`, `_LOD1`, `_LOD2`.
7. **Split for gameplay.** Separate objects for parts that move or need their own physics: hull, rotor, tail rotor, winch hook, doors, steering wheel. Origins placed where they rotate.
8. **Collision proxies.** Simple `_COL` meshes (boxes or hulls) for vehicles and big props. In Studio the visual mesh is `CanCollide = false` and the proxy does physics.
9. **Attachments.** Empties named `ATT_FloatPoint_01`, `ATT_Seat_Driver`, `ATT_Spray_Bow`, `ATT_Wake_L`, `ATT_Light_Port`, `ATT_Light_Starboard`, `ATT_Light_Masthead`, `ATT_Searchlight` and so on. A Lune or Studio script converts them on import (verify that empties survive the importer; if not, use tiny marker meshes).
10. **UVs and texel density.** Unwrap to the texel tier in [document 05](05-art-direction.md), section 5.3 (hero 100 to 128 px per stud, standard 51, background 25). Use trim sheets for repeated detail (rails, rub strakes, window frames) and unique sets for hulls and faces of hero assets. One material per mesh is commonly reported (verify); atlas where needed.
11. **Bake.** Cycles bakes from high to low: normal (tangent space, **OpenGL** convention), AO and curvature masks. Build the albedo from scanned or measured base colours plus wear driven by the masks (edge wear, salt, rust streaks; [document 05](05-art-direction.md), section 5.4). Roughness and metalness as separate single-channel greyscale PNGs. Make the wet variant (darker albedo, lower roughness) in the same file.
12. **Master and export maps.** Masters at 4096 in `art/`. Export maps at the verified cap (1024 until Spike 1 says otherwise) to `assets/textures/` as `<asset>_<set>_ALB.png`, `_NOR.png`, `_RGH.png`, `_MET.png`, plus `_wet` versions where needed.
13. **Check maps.** `scripts/tools/check_textures.py` fails if: an albedo pixel falls outside sRGB 30 to 240 on non-metal areas, a normal map looks DirectX-convention (green channel test), roughness or metalness is not single-channel, a map exceeds the verified cap, or a name breaks the suffix rule.
14. **Export mesh.** FBX, selected objects only, transforms applied, no cameras or lights. Rigged models (the dog, NPCs) export with the armature and animations. glTF support was disputed in research (verify); default to FBX.
15. **Import.** Studio 3D Importer: check scale, pivot and orientation in the preview. Add a `SurfaceAppearance` with the four maps (and an `AlphaMode` for decals and fur cards), set `CollisionFidelity` (Box or Hull for props, proxy for vehicles), `RenderFidelity` per [document 05](05-art-direction.md), section 5.6, and `CastShadow` off on tiny parts.
16. **Assemble.** Build the vehicle model in Studio from parts, LOD models, constraints, attachments and real lights ([document 05](05-art-direction.md), section 6.3). Save hero assets as Roblox Packages so updates propagate to every copy.
17. **Review.** Run the checks in [document 05](05-art-direction.md), section 10.3. Contact sheet with the reference photo, critique, repeat.
18. **Record.** `.blend` source in `art/`, exported FBX and PNGs in `assets/`, uploaded asset IDs in `assets/manifest.json`, with source, licence and "AI used" fields. A Lune script generates `src/shared/AssetIds.luau` from the manifest so code never hard-codes IDs.

**Terrain and large surfaces:** `MaterialVariant`s in `MaterialService` built from CC0 scan materials (ambientCG, Poly Haven), each with a wet twin, `StudsPerTile` set for 51 px per stud (verify the API and terrain override in Spike 1).

**Skyboxes:** `scripts/blender/cubemap.py` renders a CC0 HDRI into six `Sky` faces at the verified cap, one set per lighting preset.

### 2.1a Character uploads: moderation rule (mandatory)

Roblox moderates every uploaded mesh **on its own**, without its textures or clothing. On 2026-10-17 two realistic, unclothed body meshes were removed for "Sexual Content", and each removal is a strike on the owner's account. So, from now on:

- **Never upload a bare human body mesh.** Clothing is real geometry, merged into the **same mesh** as the body before export: swimsuit or wetsuit plus lifejacket for the swimmer, oilskins, drysuits, crew kit and so on for the others. Painted-on clothing and clothing in a separate mesh do not count.
- **Loose, real-world clothing, never shrinkwrap.** Roblox sees the untextured clay shape, so a skin-tight suit reads as a bare body. Clothing is offset from the body (about 3 to 6 cm) with real folds, seams, cuffs with thickness and chunky footwear. In clay, waist, hip, buttock, chest and groin curves must not read, and feet must read as boots, not toes and ankles. Lifejackets and kit cover the torso generously.
- **No hidden body inside.** Body geometry exists only where skin shows (head, neck, hands). No inner body-shaped shell under the clothing.
- **No anatomical detail on any skin area.** Exposed skin is limited to the head, neck, hands and (where the outfit really shows them) forearms and lower legs.
- **Base bodies stay local.** `M_Chr_HumanBase_M` and `_F` (and any other naked base) are Blender sources only. They are never exported to `assets/fbx/` and never uploaded, on their own or inside a Model.
- **No skin-body textures on their own.** Do not upload body albedo, normal or roughness maps of a naked base. Upload only the textures of the final clothed character.
- **Proper asset names.** Every upload is named after its asset (`M_Chr_Casualty_Swimmer_LOD0`), never a generic name such as "mesh".
- **Before any character upload:** a clothed-silhouette check (front, side and back renders reviewed by a person or a reviewer agent) and the `validate` character rule must pass.
- If Roblox removes any asset, **stop all character uploads** and tell the owner before doing anything else.

### 2.2 Limits to verify in the first spike

| Item | Research says | Our working rule |
|---|---|---|
| Triangles per MeshPart | About 20,000 to 21,000 (vendor); reject versus auto-decimate disputed | 10,000 or fewer |
| Texture size | Official page states both 1024 and 4096; vendors claim up to 8K with mobile warnings | Ship 1024; test 2048 and 4096 for memory and phone behaviour |
| Texture streaming | Announced on DevForum; details unknown | Test how it downsizes maps on phones |
| Materials per mesh | One, commonly cited | One; use atlases |
| File format | FBX solid; glTF disputed | FBX |
| `SurfaceAppearance` on `EditableMesh` | Not documented | Test; decides the ocean mesh type (section 3.1) |
| Runtime `SurfaceAppearance` changes (swap a child, edit `Color` or `EmissiveStrength`) | Not covered | Test; decides the wet-state method ([document 05](05-art-direction.md), section 5.4) |
| `MaterialVariant` API, terrain overrides and runtime swaps | No verified page | Test; decides wet terrain and quays |
| `RenderFidelity` Automatic switch distances | 250 and 500 studs from snippets only | Measure |
| Streaming level-of-detail for models | Not researched | Test the low-detail stand-in look for the town |
| Layered clothing and accessory limits | Not researched | Test the drysuit and lifejacket on common body types |
| `SpotLight` range cap | Reported around 60 studs (unverified) | Measure; searchlights use a `Beam` cone beyond it |
| Skinned mesh bone count | Not researched | Test with the dog and the ocean grid |
| Empties as attachments | Not researched | Test; fall back to marker meshes |

### 2.3 Texture and LOD tiers

| Tier | Texture sets | LOD rule | Used for |
|---|---|---|---|
| Hero | Unique sets at the verified cap, trim sheets for repeats, wet variants | LOD0, LOD1, LOD2 models swapped by `LodController` with hysteresis; `RenderFidelity` Precise only on the local player's vessel and the dog near the camera | Vehicles, helicopter, the dog, NPCs, crew kit, station, lighthouses, big-call ships |
| Standard | Shared trim sheets and prop atlases | `RenderFidelity` Automatic | Town buildings near the harbour, props, rocks |
| Background | Tiling `MaterialVariant`s plus decals | `RenderFidelity` Performance; streamed-out models use low-detail stand-ins (verify) | Distant town, cliffs, far islands |

On Low quality the hero LOD distances shrink (section 3.5) and LOD0 is never used beyond 60 studs (tune).

### 2.4 Headless automation

- `scripts/blender/export_all.py`: opens each `.blend` in `art/blender/export/`, exports every collection tagged `EXPORT` (with its LODs) to `assets/models/` as FBX.
- `scripts/blender/bake_pbr.py`: bakes normal, AO and curvature from `_HP` to `_LOD0` objects and writes the map set (dry and wet) at master size, then downsizes to the export cap.
- `scripts/blender/turntable.py`: renders 4 angles under the neutral HDRI and the overcast sea HDRI for review.
- `scripts/blender/flipbook.py`: renders a spray, smoke or foam simulation to a 4x4 or 8x8 grid sheet at the verified cap.
- `scripts/blender/ocean_normals.py`: bakes tiling wind-chop normal maps from a Blender ocean modifier for the wave mesh.
- `scripts/blender/cubemap.py`: HDRI to six skybox faces.
- `scripts/tools/check_textures.py`: the map checker (section 2.1, step 13).
- Run with `Blender --background file.blend --python script.py`. At most two Blender or Xcode-class heavy jobs at once on this machine.

---

## 3. Technical approach

### 3.1 The ocean

| | Terrain water | Mesh ocean |
|---|---|---|
| Setup cost | Low; built in | High; custom code and a mesh |
| Look | Reflective in calm water; `WaterColor`, `WaterReflectance`, `WaterTransparency`, `WaterWaveSize`, `WaterWaveSpeed`; reflections drop below graphics quality 8 (research) | Art-directed swells and storm waves with PBR detail |
| Wave size | Cosmetic and capped (verify); no wave direction setting | Any height and direction |
| Gameplay sync | Wave phase is not exposed, and sampling can drift after about 10 minutes (DevForum; verify) | Deterministic: the same function drives visuals and physics |
| Swimming | Built-in Humanoid swimming | Needs a custom swim and float controller |
| Mobile cost | Low | Medium to high; must be budgeted |

**Decision: a mesh ocean everywhere, with one shared wave function. No Terrain water anywhere, including the harbour, and no Terrain fallback tier.** Two water systems would mean two looks, a seam at the breakwater and two swim systems; the harbour mouth storm calls ([document 02](02-core-loop-and-mechanics.md), section 8) also need real waves right next to the harbour. Terrain is still used for land.

**Physics (unchanged by the photoreal direction):**

- **Summed sine waves.** `src/shared/Waves.luau` is a pure function: `heightAt(x, z, t, params)` and `sampleAt(x, z, t, params)` (height plus normal), summing 3 to 5 directional sine waves (tune). A sum of sines gives the exact height at any world point in one cheap evaluation, with no fixed-point solve, which matters with many float points per boat. Time comes from `workspace:GetServerTimeNow()` so every client and the server agree. `params` (amplitude multiplier, wind direction, wave choice) come from the storm state and the zone (the harbour inside the wall is damped; the harbour mouth is not). Unit-tested in Lune.
- **Shallows, beaches and the harbour:** the same function, with wave amplitude damped by a per-zone mask (inside the harbour wall, sandbars, beaches).
- **Swimming:** a custom float controller keeps players, swimmers, survivors and the dog on `heightAt`.
- Physics never reads the visual mesh, and no quality tier changes physics (section 3.5).

**Photoreal visuals over the same function (client only, `OceanRenderer`):**

- **Displacement matches physics.** The visible surface uses the same sines for its height, so a hull's waterline matches what the player sees. Sharper crests come only from a small Gerstner-style sideways offset of the vertices, with steepness kept low enough that the drawn height stays within about 0.3 studs of `heightAt` (tune). Spike 2 measures that error; if it shows on hulls, drop the offset and use plain sines. The open-source JONSWAP ocean (MIT, research section 2.1) is a reference for skinned and `EditableMesh` modes and for the seam problem when actors update separately.
- **Grid and LOD rings.** A near grid around the camera that snaps in whole-wavelength steps (and whole normal-map tiles) so neither the waves nor the surface detail visibly slide. Around it, one or two coarser rings, then a flat far plane with the same `SurfaceAppearance` to the horizon. Ring edges blend amplitude to zero over a band to hide seams. About 8,000 triangles was reported workable for a skinned ocean (research section 2.1); the near grid starts there.
- **Mesh type (spike 2 decides):**
  - A skinned grid with bones moved each frame. Cheaper to update; no per-vertex colour.
  - An `EditableMesh` grid deformed each frame. Allows vertex colour for depth and crest foam, and maybe UV scrolling; CPU-heavy; check memory, size and permission limits and whether it runs on all devices (verify). `SurfaceAppearance` support on it is undocumented (verify).
- **Surface material.** `SurfaceAppearance` with a tiling wind-chop normal map baked in Blender, low roughness (about 0.05 to 0.12 calm, 0.2 to 0.3 storm), metalness 0 ([document 05](05-art-direction.md), section 7.1). Reflections come from the Future lighting environment and the preset skybox.
- **Colour.** Depth and height colour from the reference palette by vertex colour if `EditableMesh` allows; otherwise a per-zone and per-preset tint. Shallows: a partly transparent water tile over a seabed texture pre-tinted with water colour.
- **Foam, wakes and spray.** Crest whitening above a steepness threshold (vertex colour), foam-streak decal meshes, a foam ring mesh per hull, wake ribbons as `Beam` segments re-placed on `heightAt`, and spray and spindrift flipbooks ([document 05](05-art-direction.md), section 7.1). Foam and caustics are baked textures, never per-frame `EditableImage` work (research section 6).
- **Particle physics.** Spray and rain particles use realistic acceleration for our scale (about 29.4 studs per second squared). Default `Workspace.Gravity` (196.2) is about 6.7 g at 3 studs per metre; whether to change it is a gameplay call for [document 02](02-core-loop-and-mechanics.md) (open issue), and boats do not depend on it.

**Spike 2 is judged on look as well as frame time.** It runs the ocean spikes O1 to O4 in [document 05](05-art-direction.md), section 7.2, with pass and fail criteria judged by screenshots against real reference photos, plus the frame budget in section 3.5. A fast ocean that looks flat, plastic, tiled or jittery fails.

### 3.2 Boat buoyancy and handling

- Use modern constraints: `VectorForce`, `AlignOrientation`, `LinearVelocity`, `AngularVelocity`. Do not use deprecated `BodyForce`, `BodyGyro` or `BodyVelocity`.
- **Float points:** 4 to 8 attachments under the hull (more for long hulls). Each frame, per point: `depth = heightAt(point) - point.Y`; upward force = `clamp(depth / draft, 0, 1) * buoyancyPerPoint`, plus a damping force against that point's vertical velocity. This follows the displaced-volume method from the DevForum buoyancy threads.
- **Drag:** linear drag stronger sideways than forward (keel effect); angular drag to stop spinning.
- **Thrust and steering:** a `VectorForce` at the stern for thrust; yaw torque for steering, reduced when the hull is out of the water.
- **Pitfall:** do not use an `AlignOrientation` for tilt alongside an `AngularVelocity` with a mismatched `RelativeTo`; they fight. Let buoyancy produce pitch and roll.
- **Network ownership:** the driver's client owns the boat and simulates it (smooth controls). The server checks speed and position against vehicle limits (top speeds in [document 02](02-core-loop-and-mechanics.md), section 4.1) and resets cheats. Empty boats at the dock are anchored; a drifting empty boat is server-owned with 3 float points.
- **Towed boats:** when a tow line attaches, the server gives network ownership of the towed boat to the player who is towing, so both hulls and the rope simulate on one machine and the line does not jitter. Ownership goes back to the server when the line is released or snaps.
- **Remote hulls snap to local waves (drawing only).** Each client draws other players' boats with their height, pitch and roll recomputed from its own `heightAt` at the boat's replicated X and Z, on a non-colliding visual model. Replication lag then never shows a hull floating above or sunk into the local water. Physics and server checks still use the owner's real position.
- **Victims and NPC boats move by script, not physics.** Swimmers, survivors, Barnaby's *The Optimist*, the ferry, trawlers and the fail-safe lifeboat are anchored or CFrame-driven: the server owns their X, Z and heading, and every client places them on `heightAt`. They cost no physics, cannot be pushed, and look the same on every screen. A victim's boat switches to physics only while it is under tow.
- **Per vehicle:**

| Vehicle | Handling notes |
|---|---|
| Rescue board [L] | Paddled. Slow, very stable, 4 points. Shallows and beach calls. |
| Jet ski | The first vehicle. Fast and twitchy. Lateral grip force to stop sliding; planing lift at speed reduces drag; visual lean. Speed capped for tutorial call 1. |
| RIB inflatable | The workhorse. Light, bouncy in waves, carries 3 crew and 2 survivors. |
| Lifeboat | Heavy, self-righting (strong roll restoring torque), handles storms best. |
| Hovercraft [P1] | No buoyancy. Raycast hover springs at 4 corners; low friction; crosses water, sand and ice. |
| Patrol cutter [P1] | Large, multi-crew stations, heavy damping, 8 points, slow turning. |

### 3.3 Helicopter controller

Research found no sourced reference (unverified approach). In the MVP this is a tech spike only, not a playable vehicle. Plan:

- **Lift:** a `VectorForce` along the rotor axis. A PID controller on climb rate sets lift, so the stick controls climb speed, not raw force.
- **Attitude:** an `AlignOrientation` to a target pitch and roll from the input, with yaw from the tail rotor input. Tilting the rotor turns lift into forward or sideways motion.
- **Hover assist** (default on, always on mobile): holds altitude and slows to a hover when input is released.
- **Winch:** a `RopeConstraint` with the winch enabled, a rescue basket or strop on the end, and winch speed limits. The rescuer rides the line; survivors are welded into the basket on pick-up.
- **Storm effects:** gust forces from the storm wind. Downwash is visual only (spray ring) and never pushes players or boats ([document 02](02-core-loop-and-mechanics.md), section 10).
- **Limits:** soft ceiling, rotor-strike check near cliffs (a bump and a funny radio line, no crash damage) (tune).
- **Station helicopter (NPC) [L]:** the big-call ride-along ([document 02](02-core-loop-and-mechanics.md), section 3.1) uses the same model flown by a server script along a path to a hover point, holding hover by script rather than by the PID controller. Players in its seats only run the winch or jump in.

### 3.4 Storm weather

- **Server-authoritative state machine** in `StormService`: Calm (about 10 minutes) then Warning (1 minute) then Storm (3 minutes) then Clearing (1 minute), so a storm arrives about every 15 minutes (tune). A summoned Great Storm runs a 4-minute Storm phase ([document 04](04-monetization.md), section 5).
- **Replication:** attributes on `ReplicatedStorage.Weather`: `State`, `StateStartTime` (server time), `Intensity`, `WindDirection`, `StormId`, `CalmLook` (Clear or Overcast). Late joiners compute the current blend from the server time, with no catch-up messages.
- **Client `WeatherController`:** blends the four lighting presets ([document 05](05-art-direction.md), section 6): Calm uses Clear or Overcast (Overcast by default), Warning blends toward Storm, Clearing blends back. Night comes from the day cycle, and weather blends on top. It also raises the wave amplitude multiplier (storm front most, the sheltered bay capped by the breakwater), sets ocean roughness and colour, starts rain, spindrift and the storm audio bed, and swaps the `Sky` at the peak of a haze ramp.
- **Wetness:** `WetnessController` switches decks, kit, the dog and town surfaces to their wet state in rain and spray ([document 05](05-art-direction.md), section 5.4), by swapping pre-made wet `SurfaceAppearance`s and `MaterialVariant`s (verify both methods in Spike 1). Surfaces dry slowly after rain stops (tune).
- **Rain:** a camera-attached `ParticleEmitter`; rate scaled by intensity and quality tier; off when a raycast up hits a roof.
- **Lightning:** strike times from a random generator seeded by `StormId`, so all clients see the same strikes. Each strike: a `Beam` bolt, a brief in-cloud brightness and ColorCorrection flash, and thunder delayed by distance. No rapid flashing (accessibility).
- **Big calls [L]:** at Storm start the server picks one big call (Capsized Ferry or Trawler on the Rocks; Cruise Ship Aground from [P1]) and spawns it in a valid zone, with a server-wide call card. The big call has its own 6 to 8 minute timer and keeps local storm waves and rain over its site until it ends; it spawns at least one victim per player on the server ([document 02](02-core-loop-and-mechanics.md), section 3.1).
- **Time of day:** the weather controller never touches `ClockTime`; storms change brightness, clouds, atmosphere, sky and colour only ([document 05](05-art-direction.md), section 6).
- **Clouds:** tween `Clouds.Cover`, `Density` and `Color`. Retune if the Clouds rendering upgrade changes the look.
- A paid third-party weather system exists (Advanced Weather System); we build our own because storms are core gameplay and must share state with the wave function.

### 3.5 Mobile performance plan

**Rule: quality tiers drop effects, never physics.** Every tier runs the full wave function, the same float points, the same buoyancy and the same server checks, so gameplay is identical on every device. Tiers only change what is drawn.

The tier comes from the client's graphics quality level (an official quality-switch API was not verified (research section 6); read the user setting and measured frame time). The controller can step down one tier if frame time stays over budget for 5 seconds, and back up after 30 seconds under budget (tune).

| | High (desktop, high-end phones) | Medium | Low (mid-range phones) |
|---|---|---|---|
| Ocean near grid | 48 x 48, every frame | 32 x 32, 30 Hz | 16 x 16, 20 Hz |
| Ocean rings | 2 rings plus far plane | 1 ring plus far plane | Far plane only |
| Waves in visual sum | 5 | 4 | 3 (the dropped waves are the smallest, under about 0.3 studs each) |
| Crest foam | Vertex foam, streak decals, particles | Vertex foam, streak decals | Vertex foam only |
| Spray, spindrift, rain | Full | Half | Quarter; no spindrift far out |
| Wakes | Full ribbon and hull foam | Shorter ribbon | Short ribbon, hull foam ring kept |
| Hero LOD0 distance | 80 studs | 50 studs | 30 studs (tune) |
| Shadows from lights | Searchlights and station floods | Searchlights only | None from local lights |
| Post (Bloom, DepthOfField, SunRays) | On | Bloom only | Off; ColorCorrection kept so presets still read |
| Wet-state swaps | All surfaces | Vehicles, kit, the dog | Vehicles and the dog |

**Frame targets (tune):** 60 fps on desktop High; 30 fps minimum with 1% lows above 25 fps on a mid-range phone at Low, in a storm, with 6 boats and the helicopter on screen. Test on a real low-end phone, not only the emulator. Mobile numbers are engineering judgment, not sourced.

**RP-P1 measured budget (2026-10-20).** Measured in Studio Play on the dev Mac (desktop renderer, window in front), one 10 s `RunService.Heartbeat` sample per row. **Studio is not a phone:** these numbers compare builds and exercise the Low-tier code path; the phone rule still needs the real-phone run. The Low tier was forced with the Studio-only `Workspace.PerfQuality` attribute (`ScatterController` and `OceanQuality` read it only when `RunService:IsStudio()`); `AmbientController` keeps the profile tier (Studio pins `SavedQualityLevel` to Automatic and refuses to change it), so the Low rows still carry the Medium crowd (10 people, not the Low 5). Weather: the jet-ski rows are in Storm; the town and beach rows in Calm. Tools: `tools/studio/perf.luau` (one snapshot) and `tools/studio/perfRun.luau` (the matrix).

| Spot (Studio, desktop) | Tier | Stream radius | Workspace desc | Parts (all / within radius) | Client memory | Ambient NPC | Scatter tris | Heartbeat avg / p95 |
|---|---|---|---|---|---|---|---|---|
| Port Haven town | before, default | 2,048 | 17,465 | 5,463 / 4,820 | 4,345 MB | 12 | 352,937 | 20.7 / 38.3 ms |
| Port Haven town | after, default | 1,024 | 15,272 | 4,495 / 3,429 | 4,387 MB | 10 | 277,192 | 19.8 / 30.9 ms |
| Port Haven town | after, Low | 1,024 | 14,585 | 4,337 / 3,285 | 4,386 MB | 10 | 188,142 | 19.2 / 22.0 ms |
| Haven Sands | before, default | 2,048 | 25,051 | 7,314 / 6,855 | 4,369 MB | 12 | 1,004,740 | 22.2 / 44.0 ms |
| Haven Sands | after, default | 1,024 | 20,163 | 5,687 / 3,656 | 4,399 MB | 10 | 792,514 | 20.1 / 25.7 ms |
| Haven Sands | after, Low | 1,024 | 16,341 | 4,766 / 2,793 | 4,396 MB | 10 | 492,344 | 17.8 / 20.6 ms |
| Jet ski offshore, storm | before, default | 2,048 | 15,378 | 5,306 / 4,536 | 4,490 MB | 0 | 284,527 | 32.1 / 45.8 ms |
| Jet ski offshore, storm | after, default | 1,024 | 13,539 | 4,295 / 3,195 | 4,373 MB | 0 | 222,199 | 18.9 / 27.8 ms |
| Jet ski offshore, storm | after, Low | 1,024 | 12,979 | 4,156 / 3,079 | 4,353 MB | 0 | 131,902 | 19.0 / 30.6 ms |

**What the numbers say, and what they do not.** The instance budget holds: the after runs keep 2,793 to 3,656 parts inside the 1,024-stud radius and 4.1k to 5.7k workspace parts in all, well under the about 20k ceiling. The memory figure is **not** a phone number: about 4.4 GB total, of which about 1.4 GB `Internal`, 0.74 GB `LuaHeap`, 0.28 GB `Script` and 0.18 GB `GraphicsTexture` are Studio's desktop overhead. The about 1.2 GB on a 3 GB phone target can only be read on a real phone (RP-P1, U-10). Frame time at Low was 17.8 to 19.2 ms average and 20.6 to 30.6 ms p95 in a storm against the 33 ms (30 fps) line; the four Low jet-ski samples spread 18.9 to 29.5 ms average, so this machine's run-to-run noise is about ±20% — confirm on the phone before reading a margin.

**Cuts made (the measured top costs).** The 2,048-stud streaming radius streamed about 40% more parts at Haven Sands than 1,024 (before: 6,855 parts within radius; after: 2,793 at the same spot) and cost frame time in the town. `Workspace.StreamingTargetRadius` is a place property the engine marks **Not Scriptable**: neither the server nor a client can read or set it at run time, so one value serves every tier. It is now 1,024, the docs/10 section 6.7 Low-tier budget (`map/Build.luau` `setupStreaming` only). Scatter was the other cost: Haven Sands drew about 1.0M triangles at medium, so medium now keeps `seen` 0.8 / `filler` 0.3 out to 360 studs (was 1.0 / 0.5 out to 420) and Low 0.45 / 0.12 out to 240. The ocean Low tier drops to a 10 x 10 near patch at 12 Hz (was 12 x 12 at 15 Hz; the docs table's plan was 16 x 16 at 20 Hz). Ambient caps are trimmed about 15% (Low 5 people / 2 cars, Medium 10 / 3, High 18 / 5). The I2a/I2c dressing needs no `ModelStreamingMode` change: their shells and interiors already ship `Atomic`, the loose dressing `Nonatomic`, and the scatter already draws through its three LOD templates; the measured cost was the radius and the scatter triangle count, not those modes.

**RP-P1 round 2 (2026-10-20, the new systems).** Pets and the sanctuary, the stock shelf, the season desk, the album and challenge boards, the Halloween dressing, event FX, friend flares and the NPC town landed after the first pass, so they get a budget too. Measured the same way (`tools/studio/perf2.luau`, one 10 s `Heartbeat` sample per row), with `Workspace.PerfQuality` on Low, Halloween forced through `Workspace.SeasonalEventForce = true` (the event starts 24 October) and a storm from `Storm_DevCommand`. Studio's device emulator is not scriptable from Luau or `smoke.py`, so the viewport stayed desktop: these rows exercise the Low code path, not a phone's GPU, and other agents were loading this Mac (frame times ±20%).

| Spot (Studio, desktop) | Tier | Workspace desc | Parts (all / within 1,024) | Client memory | PointLights (Halloween) | Particles | Scatter tris | Heartbeat avg / p95 |
|---|---|---|---|---|---|---|---|---|
| Jet ski offshore, storm + Halloween | Low | 12,186 | 3,921 / 3,423 | 4,481 MB | 82 (6) | 21 | 113,289 | 16.7 / 17.5 ms |
| Port Haven town + Halloween | High | 19,664 | 5,393 / 4,667 | 4,492 MB | 98 (24) | 18 | 788,053 | 16.7 / 19.1 ms |
| Port Haven town + Halloween | Low | 14,850 | 4,269 / 3,793 | 4,511 MB | 80 (6) | 18 | 186,782 | 16.7 / 19.6 ms |

**Caps added (Low unless stated).** The Halloween dressing lit 24 PointLights (17 pumpkins, 3 ferry lanterns, 3 stall wares); Low keeps 6 and Medium 14, the rest stay Neon, and a mid-event quality drop trims them (`HalloweenController`; the world itself is `HalloweenWorld`'s). A friend flare skips its PointLight and sparks at 8/s instead of 30 (Medium 18). Confetti pops emit 8 particles per colour instead of 26 (Medium 16). The stock shelf's clock SurfaceGui refreshes at 1 Hz instead of every Heartbeat; the album and challenge boards only redraw on a state push. Scatter and ambient keep the round-1 caps (Low 5 people / 2 cars). All other emitters already follow `Flipbooks` tiers.

**Streaming safety for the new props.** The album and challenge boards are now `Persistent` (they were `Atomic`; the client mounts a local SurfaceGui on the panel once, and a streamed-out board came back as new parts with no print). Everything else that is new is built on the client under `Workspace` (sanctuary, stock shelf, boards' print, pumpkins, flares, NPCs), so it is never streamed; the code that follows server props (ghost sheets over streamed victims, pet ground rays) nil-checks and falls back. The town High row touches 19.7k instances only because Studio pins the quality slider, so `AmbientController` keeps the Medium crowd (10 people plus station crew and pets); a real Low phone caps at 5. The 4.5 GB is Studio's desktop overhead, not phone memory; the 1.2 GB phone target still needs U-10.

**Other budgets:** scene triangles and texture sets per [document 05](05-art-direction.md), section 5.6. Profile with the Studio MicroProfiler before and after each hero asset lands.

### 3.6 Camera, viewmodel and cinematics

The rules (which camera where, the hands, comfort defaults) are in [document 02](02-core-loop-and-mechanics.md), sections 11 and 12; the art is in [document 05](05-art-direction.md), section 8.5. `CameraController` owns `Workspace.CurrentCamera` (`CameraType` Scriptable) and picks one mode at a time from the player's state (on foot, seat type, step in progress, cinematic). Its modules live in `src/client/Camera/`:

| Module | Job |
|---|---|
| `FirstPerson` | Locked first person on foot and on the jet ski (`LocalTransparencyModifier` hides the avatar's own head and body, verify per accessory); head position from the character's head or the seat's eye attachment; mouse, touch-drag and right-stick look with per-seat yaw and pitch limits; a Look Back glance on the jet ski. The view follows the vehicle's real motion on the shared wave function, then `Comfort` filters it. |
| `Chase` | Third-person chase for the RIB, larger boats, cars and the helicopter: a spring-damped follow with lag, look-ahead in the direction of travel, terrain and hull collision pull-in, and a toggle to the **helm or cab view** (a first-person anchor at the wheel). Steps that need the hands switch to `FirstPerson` and back. |
| `Viewmodel` | The client-only arms rig (never replicated), parented to the camera and posed per action (`ViewmodelActions`: grip bars, throw, haul, grab, radio, CPR, knock). It sways with a small lag and wave-slam offsets, is hidden in chase view, and swaps the jet ski's close-up console set in for the rider only. Rendered with the world (no separate viewmodel pass exists in Roblox, verify), so it is kept short enough not to clip into nearby geometry. |
| `Comfort` | Horizon stabilisation (blends the camera's roll and some pitch toward level, 0 to 100%), field of view (70° to 100°), head-bob and camera-shake scales. Saved per player in their data; defaults in [document 02](02-core-loop-and-mechanics.md), section 11. |
| `Cinematic` | Plays authored shots (camera path keyframes and focal lengths, a `DepthOfFieldEffect` per shot), hides the HUD, offers hold-to-skip from the second view (seen flags saved per player), and hands control back to the mode the player left. For the arrival it applies a client-side golden-hour lighting override and blends back to the server's preset when the shot ends (verify that client-side `Lighting` changes stay local and are not overwritten mid-shot by the server's weather updates). Cinematics never run during an operation step. |

**Cold-open spawn.** On a first join the server seats the player on a moving jet ski near the Sandy Point datum before the first frame, after streaming that area ([document 10](10-world-and-map.md), section 6.2); `CameraController` starts directly in `FirstPerson` on the seat, so there is no third-person frame at all before the arrival cinematic.

### 3.7 In-world store

No store UI is opened from the HUD ([document 04](04-monetization.md), section 1.1). Each shelf item, mannequin, counter and desk carries a `ProximityPrompt` and a product id attribute; triggering it opens the product card (client UI) with the price read from MarketplaceService at runtime. Only the card's Buy button calls `PromptGamePassPurchase` or `PromptProductPurchase`. The server grants developer products in `ProcessReceipt` and checks pass ownership on join, as for any Roblox purchase (verify current API names before building). Cash items (gear, boats, upgrades) use the same prompts and cards but go through a server remote that checks rank and Cash.

---

## 4. Repo layout

```
MaydaySeaRescue/
  rokit.toml              tool pins
  wally.toml              packages
  default.project.json    Rojo project
  selene.toml  stylua.toml  .luaurc
  src/
    server/               Services: StormService, CallService, RescueService,
                          VehicleService, DataService, LighthouseService
    client/               Controllers: OceanRenderer, BoatController,
                          HeliController, SwimController, WeatherController,
                          WetnessController, LodController, QualityController,
                          CameraController (Camera/: FirstPerson, Chase,
                          Cinematic, Viewmodel, Comfort), UI
    shared/               Waves, LightingPresets, QualityTiers, VehicleConfig,
                          CallTypes, Net (remotes), AssetIds (generated), Types
  tests/                  Lune unit tests for pure shared modules
  scripts/
    lune/                 publish, upload-assets, gen-asset-ids
    blender/              export_all, bake_pbr, turntable, flipbook,
                          ocean_normals, cubemap
    tools/                check_textures.py, contact_sheet.py
  assets/                 export-ready files: models/ textures/ audio/ vfx/ sky/
                          manifest.json (asset IDs, source, licence, AI used)
  art/
    blender/              .blend sources, high-poly and LODs (Git LFS)
    textures/             4096 masters (Git LFS)
    reference/<asset>/    reference board photos and real dimensions
    concept/  palette/
  marketing/
    icon/  thumbnails/  video/  shorts/  captures/
  docs/
  Packages/               Wally output (gitignored)
```

- Rojo manages code and `ReplicatedStorage`/`ServerStorage` content defined in files. The map (terrain, town, zones) lives in the place file built in Studio and is published with Open Cloud.
- Large binaries (`.blend`, texture masters, reference photos, video) go through Git LFS. Reference photos are for internal use only and record their source; they are never uploaded to Roblox.
- CI (GitHub Actions): `rokit install`, `stylua --check`, `selene`, `luau-lsp analyze`, `lune run tests`, `check_textures.py` on changed maps, `rojo build`. Optional: publish to a private test place via Open Cloud on the main branch.

---

## 5. Studio settings to set early

- Workspace: turn `StreamingEnabled` on (large ocean map) and test streaming radius against helicopter altitude (tune). Keep skinned ocean MeshParts in their own Model: the JONSWAP author reports that this fixed a StreamingEnabled lag (research section 2.1).
- Lighting: technology Future, `LightingStyle` Realistic, `EnvironmentDiffuseScale` and `EnvironmentSpecularScale` 1 ([document 05](05-art-direction.md), section 6.1). Research could not confirm Future's status or the exact setting name (verify). No ShadowMap fallback for hero scenes; the quality tiers in section 3.5 carry mobile.
- `MaterialService` set up with the project `MaterialVariant`s before any terrain is painted.
- Editor quality level at maximum when judging art in edit mode; some properties render only in playtest (research, tools section 2).
- `SandboxedInstance` set to Experimental on Workspace while testing any third-party asset (research, tools section 5).
- A dev-only `Settings` folder in `ReplicatedStorage` with flags: show float points, show wave debug grid, force storm, force big call, force lighting preset, force quality tier, show LOD level, hide HUD.

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| The ocean does not reach photoreal | Spikes O1 to O4 with screenshot pass and fail ([document 05](05-art-direction.md), section 7.2); fallback is more overcast, haze and spray, never stylization |
| Mesh ocean too slow on phones | Quality tiers down to a 16 x 16 grid at 20 Hz with a far plane (section 3.5). No Terrain fallback, so this is tested on a low-end phone in spike 2 |
| `EditableMesh` limits block vertex colour or `SurfaceAppearance` | Skinned grid with a fixed tint per zone and preset, plus foam decals and particles (section 3.1) |
| Texture cap is 1024 | Hero texel density from more sets and trim sheets instead of bigger maps ([document 05](05-art-direction.md), section 5.3) |
| Texture memory crashes phones | Texture streaming (verify), shared atlases, LOD tiers, scene budgets |
| `SurfaceAppearance` cannot change at runtime | Pre-made wet variants swapped as children; if that fails, wet look on vehicles and kit only through part swaps |
| Avatars look wrong in a photoreal world | Crew kit coverage, avatar scale limits, camera distance ([document 05](05-art-direction.md), section 8.1) |
| Remote boats look wrong on the water | Remote hulls snapped to local wave height (section 3.2) |
| Client-owned boats exploited | Server sanity checks on speed and position |
| Importer limits differ from research | Spike 1 before any production art |
| Licence problems with scans, mocap or models | Licence recorded per asset; Quixel, Sketchfab paid licences and Mixamo blocked until checked ([document 05](05-art-direction.md), section 11) |
| Moon Animator unavailable | Animation Editor plus a scripted camera path module |
| First person on a rolling jet ski causes motion sickness | Horizon stabilisation on by default, FOV, head-bob and shake settings (section 3.6); playtest the cold open with players prone to sickness |
| Viewmodel arms clip into hulls, casualties or the console | Short arms rig, per-action poses, a near-plane check in playtests (section 3.6) |
| Physics differs between devices | One shared wave function; physics never reads the visual mesh; tiers never touch physics |

---

## 7. Starter checklist: zero to playable greybox

Each step ends with something you can play or see.

1. `rokit install`; `wally install`; open VS Code with Luau LSP, Selene and StyLua extensions.
2. Create `default.project.json`, `selene.toml`, `stylua.toml`, `.luaurc`; `rojo serve` and connect Studio; print "hello" from a server and a client script.
3. Set up CI with the checks in section 4.
4. **Spike 1 (importer and PBR):** export a test cube, a 20,000-triangle mesh, 1024, 2048 and 4096 map sets, an empty and a skinned mesh from Blender. Test every row of section 2.2: the real texture cap and its memory on a phone, `SurfaceAppearance` on `EditableMesh`, runtime `SurfaceAppearance` and `MaterialVariant` swaps, `RenderFidelity` distances, layered clothing fit, `SpotLight` range. Record results in section 2.2 and in [document 05](05-art-direction.md) where it says (verify).
5. Write `Waves.luau` (summed sines) and its Lune tests (height, normal, zone damping, determinism across time values).
6. **Spike 2 (ocean):** skinned grid versus `EditableMesh` grid around the camera with the `SurfaceAppearance` surface. Run ocean spikes O1 to O4 ([document 05](05-art-direction.md), section 7.2): contact sheets against reference photos in all four presets, motion captures, hull and wake integration, and phone frame time at all three tiers (section 3.5). Measure the drawn-height error against `heightAt`. Pick one mesh type on look and speed. If O1 fails for both, apply the fallback before moving on.
7. Greybox the MVP map (about 1,500 studs radius, [document 02](02-core-loop-and-mechanics.md), section 4.1) at real scale: Port Haven harbour with quays, the station and slipway block, the harbour wall and its storm-exposed mouth, the sheltered bay. Land from parts and Terrain; no Terrain water. Greybox parts tagged `GREYBOX`. Other zones come after the MVP.
8. Build the RIB from parts: float points, thrust and steering, driver seat, network ownership. Drive it in calm waves.
9. Add the jet ski variant from the same controller with a different config (the rescue board follows for [L]).
10. Add the swim and float controller; spawn a survivor block that rides `heightAt` by script (not physics).
11. Add the pick-up interaction (approach, hold to pull aboard) and a drop-off zone at the station slipway. First full rescue loop.
12. Add `CallService` with a basic call card UI: random call, waypoint, reward on drop-off.
13. Add `StormService` and `WeatherController` with the four lighting presets, rain and wave amplitude change. Force a storm with the debug flag.
14. **Helicopter tech spike** (not playable in the MVP): greybox helicopter with hover assist and winch; pick a survivor up from the water.
15. After the MVP playtest: add one big call (capsized ferry made of parts) at storm start, with its own timer.
16. Playtest with 4 to 6 people for 30 minutes. Note the first 3 minutes in particular: research shows first-play bounce under 180 seconds hurts discovery.
17. Only then start production art for the RIB, the dog and a survivor casualty (the readability test case), using the pipeline in section 2 and the reference boards. The first production asset sets the fidelity bar that every later asset is checked against.
