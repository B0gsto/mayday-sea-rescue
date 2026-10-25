# 06 · Tools and pipeline

How code, art and the world get built, checked and published. The design is [`00-design.md`](00-design.md).
This file owns the general tech; [`10-world-and-map.md`](10-world-and-map.md) owns the map layout and
[`05-art-direction.md`](05-art-direction.md) owns the look.

## 1. Code toolchain

Pinned in `rokit.toml`. Run `rokit install` once.

| Tool | Use |
|---|---|
| Rojo | Sync `src/`, `map/` and assets into Studio; build the place |
| Luau LSP | Type analysis with Roblox definitions |
| Selene | Lint `src/`, `map/`, `tests/` |
| StyLua | Format |
| Lune | Unit specs in `tests/` |
| Roblox Studio | Play, smoke tests, publish |
| Python 3 | Publish, asset upload, world generation, screenshots |

### 1.1 Checks

```sh
~/RobloxProjects/tools/check.sh .
```

It runs:

1. `rojo sourcemap`
2. `luau-lsp analyze`
3. `selene`
4. `stylua --check`
5. `lune` specs

All five must pass. Run it before every commit.

### 1.2 Build and smoke

```sh
~/RobloxProjects/tools/build.sh .        # writes build/MaydaySeaRescue.rbxl
python3 tools/studio/smoke.py            # real Studio smoke run
python3 tools/studio/soak.py             # longer soak
```

Smoke scripts are the real-client check: they drive the place in Studio, not just the unit specs. Use them
after a gameplay change that touches input, camera, vehicles or UI.

## 2. Publish

```sh
python3 tools/publish.py
```

`publish.py` calls `tools/studio/publish_studio.py` and publishes to the private test experience in
`deploy/target.json`. It publishes **from Studio**, not an Open Cloud place upload: only a Studio publish
creates the texture packs `SurfaceAppearance` / `MaterialVariant` need.

- Normal publish is about **2 minutes**.
- The publisher retries only the texture packs that failed, not all ~455. It honours `429` reset times and
  publishes when failures are at most 1%.
- Do not publish while a map bake or a Blender batch is writing the same assets.
- After publish, check the client log for `fetchTexturePackTextures` or "PBR textures may not be visible".

## 3. Art pipeline

### 3.1 Existing finished art

Keep it. Existing vehicles, station, harbour kit, wildlife, terrain materials and PBR sets are integrated as
they are. Do not re-topology, re-texture or restyle them for the hub pass.

### 3.2 New Blender art

New models (Lego buildings, outposts, props) go through T3 `delegate_task`:

- Provider `opencode`, model `opencode-go/deepseek-v4.1-flash`, variant `max`.
- Follow `art/bench/PROD_BRIEF.md`.
- At most **3** tasks at a time (OpenCode Go rolling limit) and **2** Blender jobs (16 GB machine).
- Queue and status: `art/bench/QUEUE.md`.
- Opus reviews the result; at most three build → render → critique rounds, then ask.

The old photoreal Blender pipeline still applies to existing PBR assets. New Lego pieces can be code-built
Parts or simple Blender models; prefer Parts when the shape is boxes and studs.

### 3.3 New code and placeholder art

Code builders are DeepSeek V4 Pro (`opencode-go/deepseek-v4-pro`, variant `max`) via T3 `delegate_task`,
several in parallel. Opus reviews. Placeholder Parts first; gameplay never waits on art.

### 3.4 Asset ids and UI

- Models/textures: `src/shared/Config/AssetIds.luau`.
- UI sprites: `src/shared/Config/UiImages.luau`.
- New UI icons: `marketing/ui/icons/`, wired by the UI kit.
- Asset diet (WP-16): drop unused ids, merge near-duplicate PBR surfaces, measure phone memory and load.

## 4. Repo layout

| Path | What lives there |
|---|---|
| `src/server/Services/` | Services (`Init`/`Start`, optional `Priority`) |
| `src/server/Ops/` | Rescue operation server logic |
| `src/server/Dock/` | Dock/island build pieces and service helpers |
| `src/server/World/` | Hub, islands, harbour, world dressing |
| `src/server/Npc/` | Quest givers, crew, ambient NPCs |
| `src/client/Controllers/` | Client controllers |
| `src/client/UI/` | Panels; kit planned (WP-23b) |
| `src/client/Mechanics/` | Boarding, care, pick-up |
| `src/client/Ocean/` | Mesh ocean |
| `src/shared/Config/` | World, vehicles, dock, discovery, monetization |
| `src/shared/Ops/` | Boarding, rescue rules, shared operation data |
| `src/shared/Calls/` | Call types, distance, reach |
| `src/shared/Quests/` | Quest data and rules |
| `src/shared/Heli/`, `Sub/`, `Boat/` | Craft controllers and pure maths |
| `map/` | `Build.luau`, terrain, zones |
| `tools/world/` | Terrain and layout generation |
| `tools/studio/` | Smoke, soak, publish, screenshots |
| `tests/` | Lune specs |
| `art/` | Source, reference, bench, lookdev |
| `marketing/` | Store art, thumbnails, UI icons |
| `docs/` | Design docs; `docs/archive/` is history |

Module ownership and APIs are in [`CONTRACT.md`](../CONTRACT.md).

## 5. Technical approach

### 5.1 Ocean

One shared wave function drives the visible mesh and every hull. The client builds the ocean mesh; the server
never simulates the whole sea. `Waves.heightAt` is the source of truth. The ocean follows the camera and must
cover the horizon from a player camera.

### 5.2 Boats

- One controller for jet ski, RIB and lifeboat; premium craft are tuning variants.
- Buoyancy from sampled wave height at hull points; weight and momentum matter.
- Slow-speed control is the core skill: approach, hold steady, pick-up ring.
- Full craft shows seat pips; survivors climb aboard in view.
- No fuel, no damage; a craft can be un-stuck.

### 5.3 Helicopter and submarine

- Helicopter: hover, winch, seats 2; steady hover inside the ring lifts the survivor.
- Submarine: surface and dive; picks up divers on the seabed; 40 surfaced / 22 submerged (tune).
- Both are pure shared modules with Lune specs and a client controller for keyboard, touch and gamepad.

### 5.4 Weather

`Weather.luau` is shared. It exposes state, intensity, wave parameters, height and a changed signal. Storms
raise amplitude, reduce visibility and add rain/spray. The default is sunny; Storm Summon and live events are
products/events, not the base loop.

### 5.5 Camera and input

Third person only. Chase camera with lag; optional higher/lower framing. No first-person viewmodel, no photo
mode. Every action works on keyboard, touch and gamepad. The UI kit draws a selection ring for gamepad.

### 5.6 UI

`src/client/UI/Kit/` is the planned new kit (WP-23b); it does not exist yet. It will hold Panel, IconButton,
Card, PriceButton, Tabs, Toast and counters, be simulator-style and work on all three inputs. When WP-23c
lands, the phone is deleted, not skinned. See [`18-ui-art-requests.md`](18-ui-art-requests.md).

### 5.7 World streaming

`StreamingEnabled` with min `384` and target `1024`. Map and zones are `Persistent`; dock pieces are
`Persistent`. Re-measure after the hub and islands land. The old town mobile numbers are retired.

## 6. Studio settings

Set once per place:

- `Workspace.StreamingEnabled = true`.
- `Workspace.Gravity` at the project value (about 29.4 studs/s²) and retune anything that depends on it.
- `Lighting.Technology = Future` if the current place uses it; keep the existing look.
- `Workspace.ModelStreamingMode = Persistent` for map and zones.
- Collision groups for players, vehicles and casualties.
- No Terrain water; the mesh ocean is the sea.

## 7. Risks

| Risk | Watch |
|---|---|
| Map scale | Hub 800 / ring 1,100 / bridges 50 apex; check the ocean covers the view |
| Streaming | Dock pieces and quest camps must not pop; re-measure on a phone |
| Publish time | Texture packs are the slow part; retry only failures |
| UI kit | Every old screen must move; do not leave phone panels |
| Asset diet | Unused ids and duplicate PBR sets inflate memory and publish time |
| DeepSeek limits | 3 tasks / 2 Blender jobs; queue, do not pile up |
| Stale docs | `docs/00` wins; archive old chapters, do not let them drift back |
