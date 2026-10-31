# 28: Perfect pass (owner /goal 2026-10-31)

Owner: "With blender refine every asset, create assets for stuff that are built via code ... animations, game design,
feel, look, progression ... from every arrow to every build/vehicle ... art director > 9/10 on everything, no exception."

Bar: a fresh Opus art director scores every item **above 9/10** (9.1+), judged at game camera distance and on a phone.
Owner 2026-10-31: **Opus only** (no DeepSeek, no Sonnet rounds). Rules stay: keep existing assets' look (refine, never redesign), new things Lego-style, Blender via the MCP (one GUI,
heavy slot), asset rounds Sonnet 5.5 high then Opus 5.5 high, UI = Claude SVG (`tools/ui-art/render.py`), VFX per
`docs/26-vfx.md`, no z-fighting, publish checked changes (sibling thread owns publishes; hand it merged commits).

Status lives in the table; one row per item. Sheets: `build/status/2026-10-31/perfect/<item>/`.

| Area | Item | Source | Score | Status |
|---|---|---|---|---|
| UI | every sprite in art/source/ui + UiImages | SVG / PNG | - | wave 1 |
| World | baseline in-game tour | PERF-TOUR2 | 5.0-8.6 (61 items) | done: tour/SCORES.md; Blender lane order below |
| Feel | game feel + progression review | code read | moments 3-8 | done: build/status/2026-10-31/perfect/feel/REVIEW.md (28 items) |
| Feel | REVIEW 5,6,7,9 build feel | PERF-F1o (Opus) | 6-6.5 | building |
| Feel | REVIEW 1,13,22,24 buy a boat, ring, passengers, bob | PERF-F2o (Opus) | 3-6 | building |
| Feel | REVIEW 8,11,15,27 rider, recruit, discovery, neon | PERF-F3o (Opus) | 5-6.5 | building |
| Feel | REVIEW 10,25 wheel + prize audio | sibling thread (M_Prop_PrizeWheel, AD r2 7.5) | 6.5 | theirs |
| Prog | REVIEW 3,12,16 (+17 proposal) | PERF-F4o (Opus) | 4-5 | building |
| Feel | REVIEW 2 haptics | after F1-F3 merge | 0 | queued |
| Anim | workers/NPCs/player sprint | ANIM1 own clips r1-3: 6.6-8.6, none shipped; PERF-ANIM2: TaT + Roblox packs | 8.6 best | building |
| Mon | monetization review | PERF-MON1 | 5.5 overall | done: build/status/2026-10-31/perfect/mon/REVIEW.md |
| Mon | plan 1,4,11,12,13,18,19,20 (Shop Finish/spin bug, effect lines, odds, telemetry, texts, docs) | PERF-MON-A | 5 | building |
| Mon | plan 3,7 purchase payoff + boat test ride | PERF-MON-B | 2.5 | building |
| Mon | plan 15 store icon family | PERF-MON-C | 6.5 | building |
| Mon | owner YES: Starter Kit rework, 5 cosmetics on sale, private servers (other ideas declined) | after MON-A merges | - | queued |
| Anim | player sprint/walk/idle (owner: reuse Tame A Titan clips OK) | PERF-ANIM1 | - | building |
| Mesh | M_Prop_JettyCrane | Blender PERF-BL1 | 7.6 (r2) | r4 in progress |
| Code->mesh | build-site fence/scaffold/crane kit (REVIEW 9) | Blender | 6 | queued |
| Mesh | M_Prop_BuildStation | Blender | 8.3 (r2) | queued |
| Mesh | vehicles: JetSki, RIB, StormRunner, Tidewalker, RiptideX, GildedGull, SupplyBarge | Blender | unscored | queued |
| Mesh | buildings: RescueHQ, HQAddons, Bunkhouse, Depot, Workshop/FishMarket/Clinic/BoatYard/Lookout/RescueBoathouse/TrophyHall/SubPen/AirStation/Boathouse add-ons | Blender | 7.5-8.5 | queued |
| Mesh | Bosun LP, pets (Gull, Otter, Puffin, SealPup, Turtle), sea life | Blender | unscored | queued |
| Code->mesh | DockPieces base kit (plinths, roofs, pads, commons), Heli, Sub, PrizeWheel + PushButton, Bridges, IslandPlates, QuestPontoons, Leaderboard, SkerryLight, ComingSoon board, BayDecor, MermaidLagoon kit, Conveyors | Luau Parts | - | queued |
| VFX | 30 VFXKit presets | flipbooks | suite 8.6 | queued |
| Anim | workers/NPCs (stock R15), Bosun, pets, build sequence, wheel | code / stock | unscored | queued |

## Blender lane order (from the baseline tour, build/status/2026-10-31/perfect/tour/SCORES.md: 61 items, all < 9.1)

One Blender GUI at a time; each step = one Opus agent, rounds to 9.1+, upload, wire, check.sh, commit, close Blender.
1. M_Prop_JettyCrane r7+ (8.7) - running
2. Build-site kit: fence, scaffold, site crane, brick stacks (5.0) - new
3. Rescue board / leaderboard (5.5) + Coming Soon board (6.5) + island name sign (7.0) + Harbour Master beacon (6.5) - new prop kit
4. Sea plates: Freight Wharf (5.8) + Ramp Wharf (6.4) - new kits
5. Idle-crew commons / Hangout (6.2) + decorations (flowers, picnic, lamps, flag, statue, fountain) (6.4) - new kit
6. Rescue helicopter (6.2) - new mesh (code greybox today)
7. HQ L1-L5 (6.4): distinct silhouette per level, door, plaque, inset windows, roof studs
8. Bosun (5.8) + grey seal (5.5) + otter/seal pup/gull/turtle/puffin (7.2-8.4)
9. Hub centre (5.5) + Mermaid Lagoon dressing (5.8) + island plate edge / bridges / conveyors / Skerry light (6.5-7.6)
10. Fish Market, Boat Yard, Rescue Boathouse, Boathouse, Sub Pen, Workshop, Depot, Bunkhouse, Clinic, Air Station, Lookout, Trophy Hall (6.6-8.2)
11. Jetty/harbour L1-3 deck + bollards, plaza/streets/lot pads/plinths, bare start plot (7.0-7.5)
12. Submarine (7.4), Lifeboat (8.3, code-built), boat board, quest pontoons, bay decor (7.0-7.4)
13. Vehicles: RIB 8.6, Tidewalker 8.4, JetSki 8.3, StormRunner 8.2, GildedGull 7.8, RiptideX 7.6, supply barge 7.6
14. Penwyn + Gannet Rock dressing (7.4-7.6)
HUD (7.4-8.1) goes to the UI stream, not Blender.
