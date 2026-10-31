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
| World | baseline in-game tour (buildings Lv1-3, vehicles, props, code-built pieces) | PERF-TOUR2 (Studio) | - | running |
| Feel | game feel + progression review | code read | moments 3-8 | done: build/status/2026-10-31/perfect/feel/REVIEW.md (28 items) |
| Feel | REVIEW 5,6,7,9 build feel | PERF-F1o (Opus) | 6-6.5 | building |
| Feel | REVIEW 1,13,22,24 buy a boat, ring, passengers, bob | PERF-F2o (Opus) | 3-6 | building |
| Feel | REVIEW 8,11,15,27 rider, recruit, discovery, neon | PERF-F3o (Opus) | 5-6.5 | building |
| Feel | REVIEW 10,25 wheel + prize audio | sibling thread (M_Prop_PrizeWheel, AD r2 7.5) | 6.5 | theirs |
| Prog | REVIEW 3,12,16 (+17 proposal) | PERF-F4o (Opus) | 4-5 | building |
| Feel | REVIEW 2 haptics | after F1-F3 merge | 0 | queued |
| Anim | workers/NPCs | PERF-ANIM1 (Opus) | 4-5 | building; next ANIM2: rider, pets, NPC talk, leisure |
| Mesh | M_Prop_JettyCrane | Blender PERF-BL1 | 7.6 (r2) | r4 in progress |
| Code->mesh | build-site fence/scaffold/crane kit (REVIEW 9) | Blender | 6 | queued |
| Mesh | M_Prop_BuildStation | Blender | 8.3 (r2) | queued |
| Mesh | vehicles: JetSki, RIB, StormRunner, Tidewalker, RiptideX, GildedGull, SupplyBarge | Blender | unscored | queued |
| Mesh | buildings: RescueHQ, HQAddons, Bunkhouse, Depot, Workshop/FishMarket/Clinic/BoatYard/Lookout/RescueBoathouse/TrophyHall/SubPen/AirStation/Boathouse add-ons | Blender | 7.5-8.5 | queued |
| Mesh | Bosun LP, pets (Gull, Otter, Puffin, SealPup, Turtle), sea life | Blender | unscored | queued |
| Code->mesh | DockPieces base kit (plinths, roofs, pads, commons), Heli, Sub, PrizeWheel + PushButton, Bridges, IslandPlates, QuestPontoons, Leaderboard, SkerryLight, ComingSoon board, BayDecor, MermaidLagoon kit, Conveyors | Luau Parts | - | queued |
| VFX | 30 VFXKit presets | flipbooks | suite 8.6 | queued |
| Anim | workers/NPCs (stock R15), Bosun, pets, build sequence, wheel | code / stock | unscored | queued |
