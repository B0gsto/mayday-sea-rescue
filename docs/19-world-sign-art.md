# 19 · World sign art

Sign faces for the current world: the forest hub, six player islands, the bridges and the outer islands. One
image per sign, applied as a Decal. No text-heavy Frames.

The old street-name, tide-board, car-park and cliff-warning signs belonged to Port Haven and the roads. They
are cut with the town; do not build them. No `sign_*` ids are referenced in `src/` or `map/` today.

## Style

- Flat, front-on artwork filling the canvas; no perspective, shadow, mock-up background or watermark.
- Painted wood, enamel or weathered metal. Slightly worn, not glossy.
- Chunky readable lettering with a thick outline, matching the simulator UI. Keep words to 1–3.
- New hub and island signs are Lego-like: simple boards, visible bolts, a stud or two, bright paint.
- No real logos, flags or coastguard insignia. The Gale Isles Coastguard mark is invented.
- Transparent not required; the board edge is part of the image.

## Wire

Add each uploaded id to [`19-sign-ids.txt`](19-sign-ids.txt) under the key below. The sign builder is not in
the repo yet; when it lands, it reads that file. Until an id exists, the sign is not built.

## Hub signs

| Key | File | Size | Text / image |
|---|---|---|---|
| `hub_hq` | `sign_hub_hq.png` | 1024×256 | `COASTGUARD` with a small lookout-hut mark |
| `hub_calls` | `sign_hub_calls.png` | 1024×256 | `CALL BOARD` with a pager glyph |
| `hub_shop` | `sign_hub_shop.png` | 1024×256 | `SHOP` with a striped awning mark |
| `hub_harbourmaster` | `sign_hub_harbourmaster.png` | 1024×256 | `HARBOURMASTER` with an anchor |
| `hub_campfire` | `sign_hub_campfire.png` | 1024×512 | `CAMPFIRE` with a flame and two logs |
| `hub_monument` | `sign_hub_monument.png` | 1024×512 | `RESCUERS` with a simple monument silhouette |
| `hub_jetty` | `sign_hub_jetty.png` | 1024×256 | `VISITOR JETTY` with a mooring cleat |
| `hub_quests` | `sign_hub_quests.png` | 512×512 | A red `!` in a speech bubble, no words |
| `hub_ruin` | `sign_hub_ruin.png` | 512×512 | A cracked stone arch, no words |
| `hub_wreck` | `sign_hub_wreck.png` | 512×512 | An overgrown boat bow, no words |

## Player island signs

| Key | File | Size | Text / image |
|---|---|---|---|
| `island_1` … `island_6` | `sign_island_1.png` … `sign_island_6.png` | 1024×256 | `ISLAND 1` … `ISLAND 6`; the owner's name is drawn in code on a blank strip |
| `island_berth` | `sign_island_berth.png` | 512×512 | A boat bow in a berth notch, no words |
| `island_sub` | `sign_island_sub.png` | 512×512 | A periscope and a bubble, no words |
| `island_build` | `sign_island_build.png` | 512×512 | A tablet on a stand with a brick, no words |
| `island_slow` | `sign_island_slow.png` | 512×512 | `SLOW` with a wake mark |
| `island_no_wake` | `sign_island_no_wake.png` | 512×512 | `NO WAKE` with a crossed-out wake |

## Bridge signs

| Key | File | Size | Text / image |
|---|---|---|---|
| `bridge_hub` | `sign_bridge_hub.png` | 1024×256 | `HUB` with an arrow |
| `bridge_island` | `sign_bridge_island.png` | 1024×256 | `ISLANDS` with an arrow |
| `bridge_clearance` | `sign_bridge_clearance.png` | 512×512 | A boat passing under an arch, no words |

## Outer island signs

| Key | File | Size | Text / image |
|---|---|---|---|
| `isle_skerry` | `sign_isle_skerry.png` | 1024×256 | `SKERRY` |
| `isle_puffin` | `sign_isle_puffin.png` | 1024×256 | `PUFFIN ISLE` |
| `isle_penwyn` | `sign_isle_penwyn.png` | 1024×256 | `PENWYN` |
| `isle_wreck` | `sign_isle_wreck.png` | 1024×256 | `WRECK REEF` |
| `isle_arches` | `sign_isle_arches.png` | 1024×256 | `THE ARCHES` |
| `isle_gannet` | `sign_isle_gannet.png` | 1024×256 | `GANNET ROCK` |
| `isle_lagoon` | `sign_isle_lagoon.png` | 1024×256 | `MERMAID LAGOON` |

## Hazard and beacon signs

| Key | File | Size | Text / image |
|---|---|---|---|
| `hazard_rocks` | `sign_hazard_rocks.png` | 512×512 | `ROCKS` with three black rock teeth |
| `hazard_shallows` | `sign_hazard_shallows.png` | 512×512 | `SHALLOWS` with a depth bar |
| `hazard_wreck` | `sign_hazard_wreck.png` | 512×512 | `WRECK` with a hull and mast |
| `beacon` | `sign_beacon.png` | 512×512 | A lighthouse beam, no words |
| `quest_camp` | `sign_quest_camp.png` | 1024×256 | `QUEST CAMP` with a tent |

## Found in the old pass

The old "white rectangles on black posts" at the harbour and station were the backs of traffic signals. That
code is cut with the town; no art is needed.
