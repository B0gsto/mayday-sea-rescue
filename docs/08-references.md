# 08 · References

Curated references for the current game: Roblox games to study, blocky/Lego and simulator-UI look references,
real rescue material, and official tech docs. The design is [`00-design.md`](00-design.md); the look is
[`05-art-direction.md`](05-art-direction.md).

Marks: **[R]** seen in the old research notes; **[O]** official site, check the exact page before citing;
**(unverified)** not confirmed. Old research lives in [`archive/research/`](archive/research/) and describes
the Port Haven design; use its links, not its conclusions.

## 1. Roblox games to study

| Game | Link | What to study |
|---|---|---|
| Firefighting Sim (Blackbox Express) | [rblxstat](https://rblxstat.com/games/10767634248) [R] | Call → drive → rescue → rank loop; fast-rising rescue sim. Do not copy its structure. |
| Coast Guard Simulation | [roblox.com](https://www.roblox.com/games/13154329527) [R] | Patrol and rescue job framing; boat handling |
| United Roblox Coast Guard | [roblox.com](https://www.roblox.com/games/18111933024) [R] | SAR roles; avoid formal MilSim tone |
| Shore Watch: Lifeguard Roleplay | [roblox.com](https://www.roblox.com/games/87595363846977) [R] | Rank ladder motivation |
| Pilot Training Rescue Squadron | [roblox.com](https://www.roblox.com/games/470170393) [R] | Mixed air/sea rescue from islands |
| SharkBite 2 | [rowatcher](https://rowatcher.com/games/3365661357/upd-sharkbite-2) [R] | Readable threat on water; avoid PvP danger |
| Build a Boat for Treasure | [rowatcher](https://rowatcher.com/games/210851291/build-a-boat-for-treasure) [R] | Ownership of a personal boat; avoid building as the main loop |

The sea-rescue niche is small and fragmented. The opportunity is a polished, readable rescue game, not a
roleplay server.

## 2. Look and UI references

| Reference | Use |
|---|---|
| Lego | Chunky bricks, plates, studs, bright colours, big flat tops; new hub/outpost/island art |
| Roblox simulator shops | Bright gradient cards, thick dark borders, chunky rounded display font with black outline, red X, big green price buttons, coloured square icon buttons with short labels |
| Roblox blocky/low-poly games | Readable silhouettes, low part counts, strong colour blocking |
| Sea of Thieves (Rare) | Water motion and boat ride only; not its stylized look ([seaofthieves.com](https://www.seaofthieves.com)) [O] |
| The Finest Hours (2016) | Night storm palette, searchlights, small boat against big seas (unverified) |
| The Perfect Storm (2000) | Storm scale, wave faces, spindrift (unverified) |

The game is not photoreal. Do not use photoreal references to justify new PBR sets.

## 3. Real-world rescue

| Subject | Where | Use |
|---|---|---|
| RNLI | [rnli.org](https://rnli.org) [O] | Lifeboat proportions, crew kit, launch footage; never its livery or marks |
| US Coast Guard | [uscg.mil](https://www.uscg.mil) [O] | Cutter and helicopter proportions; never its racing stripe or marks |
| MH-65 Dolphin | uscg.mil (page path unverified) | Compact SAR helicopter: body, hoist, searchlight |
| AW189 | [leonardo.com](https://www.leonardo.com) [O] | Twin-engine SAR helicopter size and door/hoist layout |
| Hoist rescue | uscg.mil, rnli.org (unverified) | Hover, lower, attach, raise; downwash on water |
| Submarine rescue | Manufacturer and naval references (unverified) | Sub pen, dive, seabed pick-up; keep it toy-like |
| Newfoundland dogs | [ncanewfs.org](https://www.ncanewfs.org) [O] | Bosun: webbed feet, water coat, gentle swimmer |
| IAMSAR search patterns | [imo.org](https://www.imo.org) [O] | Expanding square and sector search; call design |
| Beaufort scale | [metoffice.gov.uk](https://www.metoffice.gov.uk) [O] | Storm intensity and sea-state look |
| Lighthouse flash patterns | [trinityhouse.co.uk](https://www.trinityhouse.co.uk) [O] | Beacon rhythms |

No real accident is recreated. No real logo, flag or insignia is used.

## 4. Roblox tech docs

### 4.1 World, terrain and streaming

| Topic | Link |
|---|---|
| Terrain | [create.roblox.com/docs/en-us/parts/terrain](https://create.roblox.com/docs/en-us/parts/terrain) [R] |
| Streaming | [create.roblox.com/docs/workspace/streaming](https://create.roblox.com/docs/workspace/streaming) [O] |
| Model streaming mode | [create.roblox.com/docs/reference/engine/enums/ModelStreamingMode](https://create.roblox.com/docs/reference/engine/enums/ModelStreamingMode) [O] |
| Environment / Atmosphere / Clouds | [create.roblox.com/docs/en-us/environment](https://create.roblox.com/docs/en-us/environment) [R] |
| Lighting | [create.roblox.com/docs/environment/lighting](https://create.roblox.com/docs/environment/lighting) [O] |

### 4.2 Materials, meshes and performance

| Topic | Link |
|---|---|
| SurfaceAppearance | [create.roblox.com/docs/reference/engine/classes/SurfaceAppearance](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance) [R] |
| MaterialVariant | [create.roblox.com/docs/reference/engine/classes/MaterialVariant](https://create.roblox.com/docs/reference/engine/classes/MaterialVariant) [O] |
| Texture specifications | [create.roblox.com/docs/en-us/art/modeling/texture-specifications](https://create.roblox.com/docs/en-us/art/modeling/texture-specifications) [R] |
| EditableMesh | [create.roblox.com/docs/reference/engine/classes/EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh) [O] |
| MicroProfiler | [create.roblox.com/docs/studio/microprofiler](https://create.roblox.com/docs/studio/microprofiler) [O] |
| Memory | [create.roblox.com/docs/studio/memory](https://create.roblox.com/docs/studio/memory) [O] |

### 4.3 UI, input and data

| Topic | Link |
|---|---|
| UI fundamentals | [create.roblox.com/docs/ui](https://create.roblox.com/docs/ui) [O] |
| UIListLayout / UIGridLayout | [create.roblox.com/docs/ui/list-grid-layout](https://create.roblox.com/docs/ui/list-grid-layout) [O] |
| Gamepad | [create.roblox.com/docs/ui/gamepad](https://create.roblox.com/docs/ui/gamepad) [O] |
| DataStore | [create.roblox.com/docs/cloud-services/data-stores](https://create.roblox.com/docs/cloud-services/data-stores) [O] |
| Remote events | [create.roblox.com/docs/scripting/events/remote](https://create.roblox.com/docs/scripting/events/remote) [O] |

### 4.4 Audio

| Topic | Link |
|---|---|
| Audio assets | [create.roblox.com/docs/en-us/audio/assets](https://create.roblox.com/docs/en-us/audio/assets) [R] |
| Audio API | [create.roblox.com/docs/reference/engine/classes/Sound](https://create.roblox.com/docs/reference/engine/classes/Sound) [O] |

### 4.5 Publishing

| Topic | Link |
|---|---|
| Experience icons | [create.roblox.com/docs/production/publishing/experience-icons](https://create.roblox.com/docs/production/publishing/experience-icons) [R] |
| Thumbnails | [create.roblox.com/docs/en-us/production/publishing/thumbnails](https://create.roblox.com/docs/en-us/production/publishing/thumbnails) [R] |
| Discovery | [create.roblox.com/docs/discovery](https://create.roblox.com/docs/discovery) [R] |
| Open Cloud | [create.roblox.com/docs/open-cloud](https://create.roblox.com/docs/open-cloud) [R] |

## 5. Tools

| Tool | Link |
|---|---|
| Roblox Studio | [create.roblox.com/docs/en-us/studio](https://create.roblox.com/docs/en-us/studio) [R] |
| Studio MCP | [create.roblox.com/docs/en-us/studio/mcp](https://create.roblox.com/docs/en-us/studio/mcp) [R] |
| Rojo | [github.com/rojo-rbx/rojo](https://github.com/rojo-rbx/rojo) [O] |
| Rokit | [github.com/rojo-rbx/rokit](https://github.com/rojo-rbx/rokit) [O] |
| Luau LSP | [github.com/JohnnyMorganz/luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) [O] |
| Selene | [github.com/Kampfkarren/selene](https://github.com/Kampfkarren/selene) [O] |
| StyLua | [github.com/JohnnyMorganz/StyLua](https://github.com/JohnnyMorganz/StyLua) [O] |
| Lune | [github.com/lune-org/lune](https://github.com/lune-org/lune) [O] |
| Blender | [blender.org](https://www.blender.org) [O] |
| OBS Studio | [obsproject.com](https://obsproject.com) [O] |
| Krita | [krita.org](https://krita.org) [O] |

## 6. Asset sources

| Source | Link | License |
|---|---|---|
| Poly Haven | [polyhaven.com](https://polyhaven.com) [O] | CC0; confirm on the license page |
| Kenney | [kenney.nl](https://kenney.nl) [O] | CC0; confirm; greybox/props |
| Quaternius | [quaternius.com](https://quaternius.com) [O] | Mostly CC0; confirm each pack |
| ambientCG | [ambientcg.com](https://ambientcg.com) [O] | CC0; confirm |
| Sketchfab | [sketchfab.com](https://sketchfab.com) [O] | CC0 or CC-BY only; never NC/ND; check Roblox terms |
| Freesound | [freesound.org](https://freesound.org) [O] | CC0 only; confirm each clip |

Never use a real coastguard livery, flag, badge or logo. The Gale Isles Coastguard is invented.
