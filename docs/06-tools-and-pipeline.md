# 06 · Tools and pipeline

How code and art get built, checked and published. Module ownership and APIs: [`CONTRACT.md`](../CONTRACT.md). The
look: [`05-art-direction.md`](05-art-direction.md).

## 1. Code

Tools pinned in `rokit.toml` (`rokit install`): Rojo, Luau LSP, Selene, StyLua, Lune. Python 3 for publish, uploads,
world generation and telemetry.

- **Check (before every commit):** `~/RobloxProjects/tools/check.sh .` runs the sourcemap, `luau-lsp analyze`,
  selene, `stylua --check` and every Lune spec in `tests/` (including `tests/ZFight.spec.luau`, the coplanar-face
  scan of every island piece). All must pass.
- **Build:** `~/RobloxProjects/tools/build.sh .` writes `build/MaydaySeaRescue.rbxl`.
- **Studio driver:** `python3 tools/studio/smoke.py run` (smoke, with `zfight_scan`), `smoke.py ops`,
  `smoke.py lua Server <file>`; `tools/studio/soak.py`, `perf*.luau`, `walkin_audit.luau`.
- **Playtests (Opus only):** `python3 tools/studio/play.py <cmd>` for fast player-only checks in Studio;
  `tools/roblox/rbx.py` for the real client (needs `tools/roblox/keyd.sh` running).
- **Dev tools in game:** the DEV board (`DevConfig` access), chat `/vfx <name|all>`, `/spin <wedge>`, `ServerStorage.*Dev`
  hooks. They stay on the launch place for live ops.
- **Code builders:** Opus 5.5 agents (owner 2026-10-31: Opus only); Opus reviews. One final sign-off per feature.

## 2. Publish

Every change that passes `check.sh` and its playtest is published to test, then launch, without asking:

```sh
git merge origin/main                               # publish from fresh main
python3 tools/studio/publish_studio.py              # private test place (deploy/target.json, state.json)
python3 tools/studio/publish_studio.py --launch     # launch place (deploy/launch-target.json, state-launch.json)
```

- It publishes from Studio, not an Open Cloud upload: only Studio makes the PBR texture packs. It retries only the
  failed packs and refuses to publish on too many failures.
- Commit `Published vN + launch vM (...)` afterwards; batch changes that land close together.
- After a launch publish: `python3 tools/trail.py --hours 24` (session trails, funnel, per-device `SessionPerf`);
  notes in `build/liveops/LOG.md`.

## 3. Art pipeline

1. **Concept first.** A Claude Artifacts page per asset (top, front, back, left, right, 3/4, phone-size read, game
   colours) plus `spec.json`, scaled ortho references and `BLENDER.md` (`art/concepts/<asset>/`). An Opus art
   director scores it; only an approved concept goes on. The owner sees the first of a new style.
2. **Blender MCP.** Model in a live Blender GUI through the `blender` MCP server (`blender2`, `blender3` for more
   GUIs: `~/RobloxProjects/tools/blender-mcp-open.sh`), checking with multi-angle `look`. Telemetry and asset
   integrations stay off.
3. **Finish** by `art/bench/PROD_BRIEF.md`: save the `.blend` in `art/source/<kind>/<name>/`, keep a `build.py` that
   rebuilds it, then `tools/blender/validate.py`, LODs (`budgets.py`), `zfight_check.py`, `export.py`, upload.
4. **Wire:** `tools/gen_asset_ids.py` writes `src/shared/Config/AssetIds.luau` (a worktree has no FBX: pin existing
   ids). Boat pieces are one entry in `BoatLevels.HullArt`.
5. **Art director:** Opus 5.5, scored out of 10 on a contact sheet; ship above 8; at most 3 rounds (a 4th only if truly
   needed), then ask the owner.

Rules: never redesign finished assets; placeholders (Parts) until art lands; binaries (PNG/FBX/WAV) stay local, never
on GitHub; up to four heavy apps (Studio, Blender GUIs) at once.

## 4. UI art and VFX

- **UI sprites:** hand-authored SVG/HTML in `art/source/ui/`, rendered by
  `python3 tools/ui-art/render.py in.svg out.png [--size W H] [--scale 2]`, uploaded with
  `~/RobloxProjects/tools/assets.py upload . <png> --type Image`, ids in `src/shared/Config/UiImages.luau`.
  Batch generators: `tools/ui-art/kit_icons*.py`, `gems.py`, `critters.py`, `stickers.py`, `pin_variants.py`.
- **Item icons:** `tools/make-item-icons.py` / `item_icons_blender.py`, `tools/upload-item-icons.py`.
- **VFX flipbooks:** `tools/blender/flipbook.py`; texture ids in `shared/Config/VFXTextures`; rules in `26-vfx.md`.

## 5. Repo layout

| Path | What lives there |
|---|---|
| `src/server/Services/` | Services (`Init` / `Start`, optional `Priority`) |
| `src/server/World/` | Islands, plates, bridges, sector spots, hub landmark, dressing |
| `src/server/Ops/`, `src/shared/Ops/` | Calls: scenes, boarding, grading |
| `src/client/Controllers/` | Client controllers |
| `src/client/UI/` | HUD, menu, panels (`Panels/`), kit (`Kit/`) |
| `src/client/Ocean/`, `VFX/`, `Camera/` | Mesh ocean, VFXKit, cameras |
| `src/shared/Boat/` | Boat maths: buoyancy, sim, Go back, fuel, sea exit, sea edge, glance |
| `src/shared/Calls/` | Call positions, sea zones, sector spots, pacing |
| `src/shared/Config/` | Game, ring layout, vehicles, monetization, assets, UI images |
| `map/` | `Build.luau`, terrain, zones |
| `tests/` | Lune specs |
| `tools/` | Studio, publish, Blender, UI art, world, telemetry |
| `art/` | Concepts, sources, bench briefs |
| `marketing/` | Store text, product list, badges, item icons |
| `docs/` | Design docs; `docs/archive/` is history |

## 6. Tech notes

- **Ocean:** one wave function (`Waves.heightAt`) drives the client mesh and every hull.
- **Boats:** one boat per player; `BoatLevels.apply` sets speed, turning, room and scale from the level.
  `Boat/Simulator` + `Boat/Buoyancy`; `Boat/Glance` bounces off walls at speed; `Boat/SeaEdge` turns you back past
  `MapRadius` (7000); `Boat/Fuel` limits range.
- **Streaming:** `StreamingEnabled`, min radius 256, target 512 (`map/Build.luau`); map and zones Persistent.
- **Camera and input:** third person only; every action on keyboard, touch and gamepad.
- **Analytics:** `TelemetryService` is the only `AnalyticsService` caller; funnel names in `TelemetryNames`.
