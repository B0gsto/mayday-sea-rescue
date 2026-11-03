# M_Prop_LagoonKit (2026-11-03, Opus 5.5, Blender MCP, 5 AD rounds)

Validate PASS. Tris LOD0 39,260, LOD1 12,987, LOD2 2,635. One flat-palette set (T_LagoonKit_Brick; NOR/RGH/MET = the Depot
palette bytes, SHARED_BYTES). AD: Mermaid Lagoon dressing 5.8 -> 8.4 on sheets at r5 (cap); unseen in game. White sand
terrain NOT changed: the sheet used a warm-tan stand-in.

Modules: L01-L34 (build.py MODULES). Attachments: one ATT_<Slot> origin per slot, plus ATT_Lamp (jetty lamp).

Ids: LOD0 78228269224567, LOD1 124768171635748, LOD2 134205432014796; ALB 111083993483904 (Approved).

Layout: build.py LAYOUT (143 rows), copied into src/server/World/Islands/MermaidLagoon/LagoonKit.luau with invisible colliders.

Open: statue still hidden behind palms/roof from the landing at 120 (raise plinth 3-6 studs, shift 2 palms); smooth grey
coral/beach boulders -> stepped studded bricks; white faceted awning, parasols, loungers -> studded stripes/slats; mermaid
eyes 20-25% smaller; cafe inner wall bricks skewed -> running bond.
