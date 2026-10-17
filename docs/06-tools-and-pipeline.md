# 06 · Tools and pipeline

Every tool we use, how art gets from Blender into Studio, the technical approach for the ocean, vehicles and storms, the repo layout, and a checklist from zero to a playable greybox.

Marks: **(verify)** means research could not confirm it on an official page; test in Studio first. **(unverified)** means secondary source or general knowledge. **(tune)** means a starting value.

Research source: [`research/tools-and-assets.md`](research/tools-and-assets.md).

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
| Studio Assistant | Built-in AI helper for script drafts and data-model edits. Treat its output like any code review. Not used to generate shipped meshes ([document 05](05-art-direction.md), section 10.2). |
| Studio MCP server | Built in. Enable in Assistant > ... > Manage MCP Servers > "Enable Studio as MCP server". Lets an external MCP client (for example Claude Code) read the instance tree, edit scripts, run Luau and control playtests. Needs the latest Studio, and each call needs a `studio_id`. Connect only trusted clients, because they can modify the open place. Community MCP servers are not vetted; do not use them. |
| Open Cloud | REST APIs. Place Publishing (needs Place ID, Universe ID and an API key with `universe-places` Write) for CI publishing to a test place; Assets API for uploading images, audio and models with versions (check which asset types it accepts (verify)). Keys live in a password manager and CI secrets, never in the repo. |
| Animation Editor | Built-in. Player and survivor animations on R15 rigs. |
| Moon Animator | Studio plugin for cutscenes and camera paths (store intro, trailer shots). Research found no 2026 information (verify it is still maintained before relying on it; the Animation Editor is the fallback). |

### 1.3 Content tools

| Tool | What it is for |
|---|---|
| Blender 5.2 | Modelling, UVs, texture baking, the dog rig and animations, VFX flipbook renders, icon renders, turntables. Runs headless (`/Applications/Blender.app/Contents/MacOS/Blender --background`) for batch export and review renders. |
| Image editor | Texture paint-over, UI art, icon and thumbnail finishing. Krita or GIMP (free); Photoshop or Affinity if already owned. |
| Audio editor | Trimming, looping and loudness-matching SFX. Audacity (free) or Reaper. Export OGG or MP3 for Roblox (verify accepted formats in the upload dialog). |
| OBS Studio | Gameplay capture for the video thumbnail and short-form clips ([document 07](07-store-page-thumbnails-and-trailer.md)). |
| Video editor | Cutting the gameplay video and shorts. DaVinci Resolve (free) or similar. |
| Python 3 with Pillow | Contact sheets for the build, render, critique loop ([document 05](05-art-direction.md), section 10.4). |
| VS Code | Code editor with the Luau LSP, Selene and StyLua extensions. |

---

## 2. Blender to Studio pipeline

Research found the official 3D Importer and mesh-limit pages unavailable, and vendor sources disagree. Every number in this section is (verify) until tested in a throwaway place. Spike task 1 in section 7 does that test.

### 2.1 Steps

1. **Start from the template.** `art/blender/_template.blend` holds the unit setup, a 5.5-stud avatar mannequin, a water plane at Y = 0, a dock with every vehicle's footprint, and the palette as a material library.
2. **Units.** Model in studs: 1 Blender unit = 1 stud. Unit mismatch is the most common import error. Confirm the importer's scale on the first export and record the export scale here.
3. **Model.** Follow the shape language and triangle budgets in [document 05](05-art-direction.md). Bevel hard edges; use weighted normals. Keep each object under the per-MeshPart cap (about 20,000 triangles reported; we stay under 10,000).
4. **Split for gameplay.** Separate objects for parts that move or need their own physics: hull, rotor, tail rotor, winch hook, doors, steering wheel. Origins placed where they rotate.
5. **Collision proxies.** Add simple `_COL` meshes (boxes or hulls) for big vehicles. In Studio, set the visual mesh to `CanCollide = false` and use the proxy for physics.
6. **Attachments.** Empties named `ATT_FloatPoint_01`, `ATT_Seat_Driver`, `ATT_Spray_Bow`, `ATT_Wake_L`, `ATT_Light_Spot` and so on. They mark where Studio attachments go. A Lune or Studio script converts them on import (verify that empties survive the importer; if not, use tiny marker meshes).
7. **UVs and textures.** Hero assets use their own 1024 set. Buildings and props use the shared trim sheet or prop atlas. One material per mesh is commonly reported (verify).
8. **Bake.** In Blender: bake ambient occlusion and a curvature mask, combine with flat palette colours in the colour map at low strength, bake the normal map from a high-poly bevel pass where needed, and export roughness and metalness as separate greyscale PNGs.
9. **Export.** FBX, selected objects only, transforms applied, no cameras or lights. Rigged models (the dog) export with the armature and animations. glTF support in the importer was disputed in research (verify); default to FBX.
10. **Import.** Studio 3D Importer: check scale, pivot and orientation in the preview. Then add a `SurfaceAppearance` with the four maps, set `CollisionFidelity` (Box or Hull for props, proxy for vehicles), `RenderFidelity`, and `CastShadow` off on tiny parts.
11. **Assemble.** Build the vehicle model in Studio from the parts, constraints and attachments. Save hero assets as Roblox Packages so updates propagate to every copy.
12. **Review.** Run the checks in [document 05](05-art-direction.md), section 10.3. Contact sheet, critique, repeat.
13. **Record.** `.blend` source in `art/`, exported FBX and PNGs in `assets/`, and the uploaded asset IDs in `assets/manifest.json`. A Lune script generates `src/shared/AssetIds.luau` from the manifest so code never hard-codes IDs.

### 2.2 Limits to verify in the first spike

| Item | Research says | Our working rule |
|---|---|---|
| Triangles per MeshPart | About 20,000 to 21,000; reject versus auto-decimate disputed | Stay under 10,000 |
| Texture size | 1024 safe; up to 4096 or more claimed with mobile warnings | 1024 maximum, 512 for small props |
| Materials per mesh | One, commonly cited | One; use atlases |
| File format | FBX solid; glTF disputed | FBX |
| Skinned mesh bone count | Not researched | Test with the dog and the ocean grid (section 3.1) |
| Empties as attachments | Not researched | Test; fall back to marker meshes |

### 2.3 Headless automation

- `scripts/blender/export_all.py`: opens each `.blend` in `art/blender/export/`, exports every collection tagged `EXPORT` to `assets/models/` as FBX.
- `scripts/blender/turntable.py`: renders 4 angles of an asset under a neutral HDRI for review.
- `scripts/blender/flipbook.py`: renders a VFX simulation to a 4x4 or 8x8 grid sheet at 1024.
- Run with `Blender --background file.blend --python script.py`. At most two Blender or Xcode-class heavy jobs at once on this machine.

---

## 3. Technical approach

### 3.1 The ocean

| | Terrain water | Mesh ocean |
|---|---|---|
| Setup cost | Low; built in | High; custom code and a mesh |
| Look | Good in calm water; reflective; `WaterColor`, `WaterReflectance`, `WaterTransparency`, `WaterWaveSize`, `WaterWaveSpeed` | Fully art-directed swells and storm waves |
| Wave size | Cosmetic and capped (verify); no wave direction setting | Any height and direction |
| Gameplay sync | Wave phase is not exposed, and sampling can drift after about 10 minutes (DevForum; verify) | Deterministic: the same function drives visuals and physics |
| Swimming | Built-in Humanoid swimming | Needs a custom swim and float controller |
| Mobile cost | Low | Medium to high; must be budgeted |

**Decision: a mesh ocean everywhere, with one shared wave function. No Terrain water anywhere, including the harbour, and no Terrain fallback tier.** Two water systems would mean two looks, a seam at the breakwater and two swim systems; the harbour mouth storm calls ([document 02](02-core-loop-and-mechanics.md), section 8) also need real waves right next to the harbour. Terrain is still used for land.

- **Physics: summed sine waves.** `src/shared/Waves.luau` is a pure function: `heightAt(x, z, t, params)` and `sampleAt(x, z, t, params)` (height plus normal), summing 3 to 5 directional sine waves (tune). A sum of sines gives the exact height at any world point in one cheap evaluation, with no fixed-point solve, which matters with many float points per boat. Time comes from `workspace:GetServerTimeNow()` so every client and the server agree. `params` (amplitude multiplier, wind direction, wave choice) come from the storm state and the zone (the harbour inside the wall is damped; the harbour mouth is not). Unit-tested in Lune.
- **Visuals match the same function.** The visible surface uses the same sines for its height, so a hull's waterline matches what the player sees. Sharper crests are allowed only as a small Gerstner-style sideways offset of the vertices, with steepness kept low enough that the drawn height at any point stays within about 0.3 studs of `heightAt` (tune). Spike 2 measures that error; if it is visible on hulls, drop the offset and use plain sines.
- **Visual surface (client only):** a square grid mesh around the camera that snaps to the camera position in whole-wavelength steps so it never visibly slides. Two options to spike in week 1:
  - A skinned grid with a bone per vertex group (for example 24 x 24 bones) moved each frame.
  - An `EditableMesh` grid deformed each frame (check current memory, size and permission limits, and whether it is allowed on all devices (verify)).
  Beyond the grid, a flat far plane in Deep Teal reaches the horizon.
- **Shading: no custom shaders.** Roblox has no user shaders, so colour by height (Abyss Navy troughs, Deep Teal, Foam crests) needs per-vertex colours written each update, which only `EditableMesh` offers (verify the vertex colour API and its per-frame cost). A skinned grid cannot recolour per vertex: it would use a fixed texture plus crest foam particles, and a weaker read of wave height. Weigh this in spike 2. Crest foam particles near the camera only.
- **Shallows, beaches and the harbour:** the same mesh, with wave amplitude damped by a per-zone mask (inside the harbour wall, sandbars, beaches). Swimming everywhere uses the custom float controller below.
- **Swimming:** a custom float controller keeps players, swimmers and survivors on `heightAt`. The dog uses the same controller.

**Mobile quality tiers (read from the client's graphics quality level):**

| Tier | Grid | Update rate | Waves in visual sum | Foam particles |
|---|---|---|---|---|
| High | 32 x 32 | Every frame | 5 | On |
| Medium | 24 x 24 | 30 Hz | 4 | Reduced |
| Low | 12 x 12 | 15 Hz | 3 | Off |

There is no lower tier. Physics always uses the full wave function, whatever the visual tier, so gameplay is identical on every device; the waves dropped from lower visual tiers are the smallest ones (tune: under about 0.3 studs each), so hulls still sit visibly on the drawn water. Mobile numbers are engineering judgment, not sourced (tune).

**Spike 2 is judged on look as well as frame time.** Pass means: the target frame budget on a mid-range phone at the Low and Medium tiers, *and* a pass from an art-director review of a contact sheet (Calm, Storm and harbour mouth, each at High and Low tier) against [document 05](05-art-direction.md), including wave readability and the hull waterline error. A fast ocean that looks flat or jittery fails.

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
- **Replication:** attributes on `ReplicatedStorage.Weather`: `State`, `StateStartTime` (server time), `Intensity`, `WindDirection`, `StormId`. Late joiners compute the current blend from the server time, with no catch-up messages.
- **Client `WeatherController`:** tweens lighting from the Calm preset to the Storm preset ([document 05](05-art-direction.md), section 6), raises the wave amplitude multiplier (Storm Front most, Calm Bay capped by the breakwater), starts rain, wind spray and the storm audio bed.
- **Rain:** a camera-attached `ParticleEmitter`; rate scaled by intensity and quality tier; off when a raycast up hits a roof.
- **Lightning:** strike times from a random generator seeded by `StormId`, so all clients see the same strikes. Each strike: a `Beam` bolt, a brief Lighting brightness and ColorCorrection flash, and thunder delayed by distance. No rapid flashing (accessibility).
- **Big calls [L]:** at Storm start the server picks one big call (Capsized Ferry or Trawler on the Rocks; Cruise Ship Aground from [P1]) and spawns it in a valid zone, with a server-wide call card. The big call has its own 6 to 8 minute timer and keeps local storm waves and rain over its site until it ends; it spawns at least one victim per player on the server ([document 02](02-core-loop-and-mechanics.md), section 3.1).
- **Time of day:** the weather controller never touches `ClockTime`; storms change brightness, clouds, atmosphere and colour only ([document 05](05-art-direction.md), section 6).
- **Clouds:** tween `Clouds.Cover`, `Density` and `Color`. Retune if the Clouds rendering upgrade changes the look.
- A paid third-party weather system exists (Advanced Weather System); we build our own because storms are core gameplay and must share state with the wave function.

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
                          CameraController, CinematicCamera (dev only), UI
    shared/               Waves, LightingPresets, VehicleConfig, CallTypes,
                          Net (remotes), AssetIds (generated), Types
  tests/                  Lune unit tests for pure shared modules
  scripts/
    lune/                 publish, upload-assets, gen-asset-ids
    blender/              export_all, turntable, flipbook
  assets/                 export-ready files: models/ textures/ audio/ vfx/
                          manifest.json (asset IDs)
  art/
    blender/              .blend sources (Git LFS)
    concept/  reference/  palette/
  marketing/
    icon/  thumbnails/  video/  shorts/  captures/
  docs/
  Packages/               Wally output (gitignored)
```

- Rojo manages code and `ReplicatedStorage`/`ServerStorage` content defined in files. The map (terrain, town, zones) lives in the place file built in Studio and is published with Open Cloud.
- Large binaries (`.blend`, PNG sources, video) go through Git LFS.
- CI (GitHub Actions): `rokit install`, `stylua --check`, `selene`, `luau-lsp analyze`, `lune run tests`, `rojo build`. Optional: publish to a private test place via Open Cloud on the main branch.

---

## 5. Studio settings to set early

- Workspace: turn `StreamingEnabled` on (large ocean map) and test streaming radius against helicopter altitude (tune).
- `SandboxedInstance` set to Experimental on Workspace while testing any third-party asset (research section 5).
- Lighting technology: Future (live for years); ShadowMap only if mobile frame time needs it.
- A dev-only `Settings` folder in `ReplicatedStorage` with flags: show float points, show wave debug grid, force storm, force big call.

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| Mesh ocean too slow on phones | Quality tiers down to a 12 x 12 grid at 15 Hz (section 3.1). No Terrain fallback, so this is tested on a low-end phone in spike 2 |
| `EditableMesh` limits block colour by height | Skinned grid with a fixed texture and foam particles (section 3.1) |
| Remote boats look wrong on the water | Remote hulls snapped to local wave height (section 3.2) |
| Client-owned boats exploited | Server sanity checks on speed and position |
| Importer limits differ from research | Spike 1 before any production art |
| Moon Animator unavailable | Animation Editor plus a scripted camera path module |
| Physics differs between devices | One shared wave function; physics never reads the visual mesh |

---

## 7. Starter checklist: zero to playable greybox

Each step ends with something you can play or see.

1. `rokit install`; `wally install`; open VS Code with Luau LSP, Selene and StyLua extensions.
2. Create `default.project.json`, `selene.toml`, `stylua.toml`, `.luaurc`; `rojo serve` and connect Studio; print "hello" from a server and a client script.
3. Set up CI with the checks in section 4.
4. **Spike 1 (importer):** export a test cube, a 20,000-triangle mesh, a 1024 and a 2048 texture, an empty and a skinned mesh from Blender. Record the real limits in section 2.2.
5. Write `Waves.luau` (summed sines) and its Lune tests (height, normal, zone damping, determinism across time values).
6. **Spike 2 (ocean):** skinned grid versus `EditableMesh` grid around the camera; measure frame time in the Studio emulator and on a real phone at all three tiers, measure the drawn-height error against `heightAt`, and get an art-director review of the contact sheet (section 3.1). Pick one on look and speed.
7. Greybox the MVP map (about 1,500 studs radius, [document 02](02-core-loop-and-mechanics.md), section 4.1): Port Haven harbour with a dock and the station block, the harbour wall and its storm-exposed mouth, Calm Bay. Land from parts and Terrain; no Terrain water. Reef, open sea and Storm Front areas come after the MVP.
8. Build the RIB from parts: float points, thrust and steering, driver seat, network ownership. Drive it in calm waves.
9. Add the jet ski variant from the same controller with a different config (the rescue board follows for [L]).
10. Add the swim and float controller; spawn a survivor block that rides `heightAt` by script (not physics).
11. Add the pick-up interaction (approach, hold to pull aboard) and a drop-off zone at the dock. First full rescue loop.
12. Add `CallService` with a basic call card UI: random call, waypoint, reward on drop-off.
13. Add `StormService` and `WeatherController` with the three lighting presets, rain and wave amplitude change. Force a storm with the debug flag.
14. **Helicopter tech spike** (not playable in the MVP): greybox helicopter with hover assist and winch; pick a survivor up from the water.
15. After the MVP playtest: add one big call (capsized ferry made of parts) at storm start, with its own timer.
16. Playtest with 4 to 6 people for 30 minutes. Note the first 3 minutes in particular: research shows first-play bounce under 180 seconds hurts discovery.
17. Only then start production art for the RIB and the dog, using the pipeline in section 2.
