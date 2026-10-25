# Photoreal research for Mayday Sea Rescue (Roblox)

Research date: 2026-10-17. Scope: realistic Roblox games, ocean/water, PBR pipeline, lighting, NPCs, performance.
Legend: **[V]** = verified on a fetched primary page or official doc. **[S]** = search snippet or secondary source only. **[U]** = unverified / could not confirm.

---

## 0. Bottom line

- The engine's realism ceiling is set by Future lighting, SurfaceAppearance PBR, and the Clouds object. There are no custom shaders for creators, so realistic water has to be geometry plus material tricks.
- Realistic ocean on Roblox is built from wave-deformed meshes (SkinnedMesh or EditableMesh), foam and spray from particles/decals, and reflections from Water terrain or Glass tricks. No official realistic-ocean template was found.
- Texture limits conflict across Roblox docs. Plan for 1024 px maps per part and verify the current cap in Studio before committing to 2K/4K.
- Roblox Reality (AI photoreal overlay) is announced but not shipped. Do not design around it.

---

## 1. Realistic-looking Roblox games (2025-2026)

| Game | Link | CCU | Realism technique (what is visible / reported) |
|---|---|---|---|
| Emergency Response: Liberty County | https://rowatcher.com/games/903807016/emergency-response-liberty-county | 5,128 (tracker, **undated** snapshot) [S] | Not verified. Tracker-only CCU. Realism technique [U]. |
| Greenville Roleplay (official) | [U] no official Roblox link found in search | [U] | Search returned only unofficial Discord servers (https://discord.com/servers/greenville-roleplay-946885574810284073). Their "online" counts are Discord, not Roblox CCU. |
| Southwest Florida | [U] not found | [U] | Not searched successfully. |
| FRONTLINES, Blackhawk Rescue Mission 5, Dusty Trip | [U] not searched | [U] | Named in brief; not researched. Recheck before relying on them. |
| Corsa Legends (driving) | [S] listed in gamertweak/thespike guides: https://gamertweak.com/best-realistic-games-roblox/ , https://www.thespike.gg/roblox/best-roblox-games/best-realistic-car-games | [U] | Cited for realistic physics and tuning. Visual technique [U]. |
| Water Physics Simulation | https://www.roblox.com/games/6128441278/Water-Physics-Simulation | [U] | Billed as a realistic ship building and sinking sim with buoyancy, icebergs, mines, waves [S, store copy]. Water rendering method [U]. |
| Realistic Sail and Sink Ships | https://www.roblox.com/games/13225157345 | [U] | 40+ ships, endless ocean [S, store copy]. Water method [U]. |
| Shipping Lanes | https://www.roblox.com/de/games/245440965 (localized store page) | [U] | Cargo/tycoon game (oil deliveries, ports) [S]. Water realism not described. The Secondspace article (https://backup.secondspace.no/news/roblox-shipping-lanes) is promotional and unreliable. |
| Pinewood showcases / Paris recreation | [S] https://gamertweak.com/best-realistic-games-roblox/ | [U] | Cited as realistic showcases. No technique data. |

**Not found in this pass:** Any 2025-2026 realistic ocean or storm game with a verified CCU or a published technical breakdown. Recommend a live check on https://www.rolimons.com or https://romonitor.com (CCU) and DevForum showcase search.

---

## 2. Realistic ocean and water

### 2.1 Community techniques

- **Skinned-mesh Gerstner waves.** A plane mesh with bones; a client script moves the bones with Gerstner equations. Author notes the script should run client-side and sync via UTC time. Source: https://devforum.roblox.com/t/1159345 [S]. Beginner walkthrough: https://devforum.roblox.com/t/making-a-skinned-mesh-ocean/1122587 [S]. Author found about 8k triangles workable; high subdivision hurts performance [S].
- **Gerstner Wave Module.** https://devforum.roblox.com/t/gerstner-wave-module/3011006 [S]. A commenter reported an "Unexpected EditableMesh type" error; the thread attributes it to deprecated vertex coloring, suggesting face coloring instead [S, unverified].
- **Dynamic Wave Simulation.** Extension of the Gerstner module with non-preset waves; boats should use three contact points to avoid waves overflowing the hull. https://devforum.roblox.com/t/dynamic-wave-simulation/2690582 [S].
- **JONSWAP Ocean (open source, MIT).** https://devforum.roblox.com/t/jonswap-ocean-liquid/3661760 [V, fetched]. Uses a JONSWAP spectrum to drive displacement. Supports SkinnedMeshParts and EditableMeshParts modes, EditableImage for caustics and a height/color map, and RenderStepped per actor. Limitations stated by its author: no shaders or PBR in Studio, no foam implemented (suggests EditableImage or particles), seam tearing when actors update independently, rough dynamic caustics, LOD suggested but not implemented. A reported StreamingEnabled lag was fixed by putting skinned MeshParts in their own Model. This is the most relevant open-source base for Mayday.
- **Creation.dev Gerstner summary.** https://www.creation.dev/learn/how-to-create-realistic-ocean-waves-roblox-gerstner-waves [S, third-party; verify against DevForum originals].

### 2.2 Materials, reflections, foam, spray

- **Glass-layer wet/reflective look.** A thin Glass part with Reflectance 1 on a surface gives a wet reflective sheen. https://devforum.roblox.com/t/how-to-make-a-wet-floor-effect/892585 [S].
- **Hardcoded specularity.** One developer notes Roblox materials have fixed specularity, so water or diamond IOR (about 1.33 / 2.4) cannot be rendered accurately. Source: https://devforum.roblox.com/t/what-gets-this-realism/958402 [S].
- **Real-time reflections.** Options: ViewportFrame mirror script, mirrored duplicate under a transparent floor, Water terrain. Each has a performance cost; Water terrain reflections are rougher and are disabled below graphics quality 8 [S]. Source: https://devforum.roblox.com/t/how-to-get-a-reflective-surface/491868?page=2 and https://devforum.roblox.com/t/real-time-floor-reflection/2694706 [S].
- **Foam.** No built-in. Options per JONSWAP author: EditableImage-driven foam texture on the wave mesh, or particle emitters [V, from JONSWAP thread].
- **Spray / flipbook.** Particle emitters with flipbook textures; no source with verified settings found in this pass [U].
- **SurfaceAppearance on EditableMesh.** Creator Docs SurfaceAppearance reference lists properties but says nothing about EditableMesh support [V, https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance]. Treat as **[U]**; test in Studio.
- **Transparency sorting.** No verified source found [U]. Test with stacked transparent water layers.
- **Water terrain.** Built-in, but no official realism settings found in this pass [U].

### 2.3 Known limitations (verified or sourced)

- No custom shaders or custom render passes for creators [S, JONSWAP author statement: no shaders in Studio].
- Specularity is fixed per material; no IOR control [S].
- Mesh updates via EditableMesh are CPU-heavy; keep vertex counts modest [S, skinned-mesh thread].

---

## 3. Photoreal pipeline

### 3.1 SurfaceAppearance and texture rules

Source: https://create.roblox.com/docs/en-us/art/modeling/texture-specifications [V, fetched].

- Max resolution: page states both "up to 4096×4096" and "up to 1024×1024 pixel spaces for texture maps." **Conflict [U].** Confirm in Studio. An older snapshot of the page gave 1024 max [S].
- Recommended size by object: 5×5 studs → 256; 10×10 → 512; 20×20 → 1024. Default materials: 1024 on an 8×8-stud face [V].
- Formats: separately uploaded textures must be .png, .jpg, .tga, or .bmp [V].
- Map types: Albedo RGB 24-bit; Normal RGB 24-bit, tangent-space OpenGL only; Roughness, Metalness, Emissive Mask single-channel 8-bit grayscale [V].
- A SurfaceAppearance maps up to four 2D images [S, texture spec summary].
- Naming suffixes (_ALB, _NOR, _RGH, _MET) recommended [S].

SurfaceAppearance properties (Color, ColorMap, NormalMap, MetalnessMap, RoughnessMap, AlphaMode, EmissiveMask, TexturePack, EmissiveStrength, EmissiveTint, ResampleMode) [V, https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance]. The reference page does not describe each property's behavior.

### 3.2 Sources for scans and assets

- Poly Haven (CC0 HDRIs, textures, models): https://polyhaven.com [U, not fetched in this pass; check license page].
- Quixel Megascans / Fab: Roblox use not verified [U]. Check Epic/Fab license terms before uploading.
- Sketchfab: CC licenses vary per model; filter for CC0/CC-BY and check Roblox upload rules [U].
- Blender 5.2 (project standard): use for PBR bakes (Cycles bake to ALB/NOR/RGH/MET) [U, not verified here, but matches Blender install in CLAUDE.md].

### 3.3 Triangle budgets and LOD

- RenderFidelity enum values: Automatic = 0, Precise = 1, Performance = 2 [V, https://create.roblox.com/docs/reference/engine/enums/RenderFidelity]. Distance thresholds for Automatic (250/500 studs) appear in search snippets only [S, not confirmed by fetch]. Re-verify.
- StreamingEnabled: a DevForum thread notes desktop players see only a few hundred to a thousand studs around them [S, community opinion]. Official page not fetched.
- Texture streaming exists (DevForum announcement https://devforum.roblox.com/t/introducing-texture-streaming/4144855 [S]); details [U].
- Triangle budgets per part: no verified official number found [U]. Use the JONSWAP "about 8k triangles workable" note [S] as a rough ocean-mesh anchor only.

### 3.4 MaterialVariants

- No verified source found [U]. Search for "MaterialVariant" in the Creator Hub reference before using.

---

## 4. Lighting, atmosphere, post, clouds

### 4.1 Future lighting and Atmosphere

Source: https://create.roblox.com/docs/tutorials/3D-art/enhancing-outdoor-environments-with-future-lighting [V, fetched]. The tutorial sets:

- Lighting.LightingStyle = Realistic.
- EnvironmentDiffuseScale and EnvironmentSpecularScale = 1 (metal reflections).
- ClockTime = 17 (sun near horizon).
- OutdoorAmbient and Ambient ~ (156, 136, 176).
- Atmosphere: Density (page gives both 0.272 and 0.391 [V, inconsistent]), Haze = 1, Color = (85, 78, 54).
- Campfire PointLight example: Range 48, Shadows on, Brightness 2, Color (255, 179, 73).

Note: the fetched tutorial does not mention Future lighting by name. Confirm the lighting technology setting in Studio (community guide says set to Future, [S] https://www.creation.dev/learn/how-to-make-realistic-lighting-roblox-studio).

The Atmosphere object takes most of its colors from the skybox; the skybox choice matters [S, search snippet of official environment docs: https://create.roblox.com/docs/en-us/environment].

### 4.2 Clouds

Source: https://create.roblox.com/docs/environment/clouds [V, fetched].

- Clouds is a Terrain child; it renders only when parented under Terrain.
- Properties: Cover (0 to 1), Density (low = light/translucent, high = dark/stormy), Color.
- Dynamic clouds drift slowly with global wind. Skybox clouds are not compared on the page.
- Lighting and Atmosphere also affect cloud color.

### 4.3 Post-processing

- ColorCorrection, Bloom, DepthOfField, SunRays: not covered by fetched pages [U]. Check the Creator Hub Lighting and post-processing pages.

### 4.4 Rain, lightning, storm

- No verified official storm/rain guidance found [U]. Plan: particle rain, Clouds Density increase, Atmosphere Haze up, lower ClockTime/brightness, and sound design.

### 4.5 Roblox Reality (AI photoreal overlay)

- Announced around late April 2026 (WCCFTech, Spider's Web, Windows Central coverage) [S]: https://wccftech.com/roblox-reality-ai-photorealistic-engine-dlss5-integrated/amp/ , https://spidersweb.pl/2026/05/roblox-reality-grafika.html
- Architecture per coverage: engine logic stays on cloud servers; a "Super Upsampler" video model on edge GPUs adds photoreal textures, lighting, secondary motion, and fluid detail [S].
- Not real-time at announcement; first iteration targeted late 2026 or early 2027 [S, techspot/thespike summaries: https://www.thespike.gg/roblox/beginner-guides/roblox-reality-details ].
- No official Roblox primary source found in this pass. **[U]** Do not plan around it.

---

## 5. Characters and NPCs

- Mixamo is humanoid-only with preset clips; not a fit for a dog [S, https://viggle.ai/blog/how-to-use-mixamo-animations].
- Mixamo license: 2021 Adobe community reply says free for commercial use; a 2026 Nilo article says it is in limited technology preview. Status **[U]**; check Adobe terms (https://community.adobe.com/questions-696/question-about-license-589172 [S, dated]).
- Roblox uses R6 and R15 rigs; animations do not transfer cleanly between rigs [S].
- Non-humanoid (dog): needs a custom rig. RigEdit Lite is listed as a plugin for extra joints and bones [S, https://www.creation.dev/tools/animation-plugins]. Verify plugin status.
- Layered clothing, dynamic heads, realistic faces: no verified Roblox method found in this pass [U]. The Dexerto article on an NVIDIA DLSS 5 avatar mod (https://www.dexerto.com/roblox/roblox-developer-adds-nvidia-dlss-5-and-gives-avatars-disturbingly-human-faces-3405172/) is a third-party mod, not an official feature.

---

## 6. Performance on mobile

- RenderFidelity Performance (2) trades mesh detail for frame rate [S, robloxapi reference: https://robloxapi.github.io/ref/enum/RenderFidelity.html].
- StreamingEnabled: reduces what loads; community notes trade-off in visible distance [S].
- Texture streaming: see 3.3 [S].
- Quality-level switching: a graphics-setting-based gating exists (Water terrain reflections off below quality 8) [S]. Official quality-switch API not verified [U].
- Realism budget: keep ocean mesh modest (about 8k tris per the author's note [S]); bake foam and caustics into textures rather than per-frame EditableImage updates [V, JONSWAP limitations].

---

## 7. Open items (to verify in Studio before committing)

1. Texture cap: 1024 vs 4096 (texture spec page conflicts) [U].
2. SurfaceAppearance on EditableMesh: supported or not [U].
3. Future lighting technology setting: exact name and location [U].
4. Clouds: confirm skybox vs Terrain Clouds visual quality [U].
5. MaterialVariant API and use for terrain [U].
6. Triangle budget per part and per scene on mobile [U].
7. Realistic-game CCU for Greenville, Southwest Florida, FRONTLINES, Blackhawk Rescue Mission 5, Dusty Trip [U].
8. Mixamo current licence and Roblox policy on third-party animation [U].
9. Post-processing (ColorCorrection, Bloom, SunRays, DoF) settings [U].

---

## 8. Source list

- https://create.roblox.com/docs/en-us/art/modeling/texture-specifications [V]
- https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance [V]
- https://create.roblox.com/docs/tutorials/3D-art/enhancing-outdoor-environments-with-future-lighting [V]
- https://create.roblox.com/docs/environment/clouds [V]
- https://create.roblox.com/docs/reference/engine/enums/RenderFidelity [V]
- https://devforum.roblox.com/t/jonswap-ocean-liquid/3661760 [V]
- https://devforum.roblox.com/t/1159345 [S]
- https://devforum.roblox.com/t/making-a-skinned-mesh-ocean/1122587 [S]
- https://devforum.roblox.com/t/gerstner-wave-module/3011006 [S]
- https://devforum.roblox.com/t/dynamic-wave-simulation/2690582 [S]
- https://devforum.roblox.com/t/what-gets-this-realism/958402 [S]
- https://devforum.roblox.com/t/how-to-make-a-wet-floor-effect/892585 [S]
- https://devforum.roblox.com/t/introducing-texture-streaming/4144855 [S]
- https://www.thespike.gg/roblox/beginner-guides/roblox-reality-details [S]
- https://wccftech.com/roblox-reality-ai-photorealistic-engine-dlss5-integrated/amp/ [S]
- https://www.roblox.com/games/6128441278/Water-Physics-Simulation [S]
- https://www.roblox.com/games/13225157345 [S]
- https://gamertweak.com/best-realistic-games-roblox/ [S]
- https://rowatcher.com/games/903807016/emergency-response-liberty-county [S]
- https://viggle.ai/blog/how-to-use-mixamo-animations [S]
