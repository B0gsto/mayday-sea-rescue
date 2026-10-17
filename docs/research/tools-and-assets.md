# Mayday Sea Rescue: Tools, Water, Vehicles, Weather, Assets, Art Style

Research date: 2026-10-17. Sources are linked inline. Items marked (unverified) could not be confirmed against an official page. Many third-party results (vendor blogs, SEO guides) disagreed with each other; those conflicts are called out.

## Key caveats

- Official create.roblox.com pages for the 3D Importer, mesh/texture limits, and Roblox's own boat/vehicle tutorials returned 404 or were not found. Mesh and texture numbers below come from vendor blogs and conflict with each other. Verify in Studio before committing to a pipeline.
- No official 2026 "Future lighting" status was found. Treat lighting claims as (unverified).
- No Roblox policy specific to AI-generated 3D assets was found. The generative-AI docs cover AI features inside experiences, not AI-made content in the asset pipeline.

---

## 1. Dev toolchain (2026)

- **Roblox Studio**: the official editor. Hosts the built-in Assistant and the Studio MCP server. https://create.roblox.com/docs/en-us/studio.md (overview page found via search)
- **Rojo**: syncs files on disk (`.lua`, `default.project.json`) into Studio. Standard for git-based workflows. Common community setup, see https://awesome.ecosyste.ms/projects/github.com%2Fstackfox-labs%2Fluumen (third-party; the official Rojo docs were not fetched).
- **Rokit**: toolchain manager that pins tool versions via `rokit.toml` (Rojo, Wally, Selene, StyLua, luau-lsp). Newer replacement for Aftman. Source: https://docs.rs/crate/rproj/latest (third-party scaffold describing Rokit usage).
- **Wally**: package manager for Luau libraries (`wally.toml`). Same source as above.
- **Luau LSP**: language server for type checking and editor support in VS Code. Same source as above; also cited in CI gate pattern.
- **Selene**: Luau linter (`selene.toml`). Same source as above.
- **StyLua**: Luau code formatter (`stylua.toml`). Same source as above.
- **Lune**: standalone Luau runtime for scripts and tooling outside Roblox. (unverified, not searched for in this pass)
- **Open Cloud API**: REST API for publishing places (Place Publishing API, needs Place ID, Universe ID, and an API key with `universe-places` Write access) and for uploading/updating assets with version control. https://create.roblox.com/docs/cloud/open-cloud/usage-place-publishing and https://create.roblox.com/docs/open-cloud
- **Studio Assistant**: built-in AI helper that edits the data model and scripts, inserts Creator Store assets, and generates materials and meshes. Model choice (Anthropic, OpenAI, Google) via Manage API Keys. Enable beta features under File > Beta Features. https://create.roblox.com/docs/en-us/assistant/guide
- **Studio MCP server (official, built-in)**: enable in Assistant > ... > Manage MCP Servers > "Enable Studio as MCP server". Lets an external MCP client read the instance tree, edit scripts, insert assets, run Luau, and control playtests. Caveats: needs latest Studio; every tool call needs a `studio_id`; the docs warn that connected clients can modify the open place, so connect only trusted clients. https://create.roblox.com/docs/en-us/studio/mcp.md (fetched)
- **Community MCP servers**: boshyxd/robloxstudio-mcp (npm), Weppy Roblox MCP, rbx-mcp. Third-party; not vetted. https://mcpservers.org/servers/hope1026/weppy-roblox-mcp
- **Blender**: used as a DCC for modeling and export. Roblox's Assistant docs mention Blender and other DCC apps in the workflow. https://create.roblox.com/docs/en-us/assistant/guide

Suggested pinning for this project: Rokit for tool versions, Rojo for sync, Wally for libs, Selene + StyLua + luau-lsp in CI. Current version numbers were not verified.

## 2. Water and ocean

- **Terrain water properties** (official, fetched): `WaterColor` (no range listed), `WaterReflectance` 0-1, `WaterTransparency` 0-1, `WaterWaveSize` 0-1, `WaterWaveSpeed` 0-100. Some properties only render during playtest; set Editor Quality Level to highest to preview in edit mode. https://create.roblox.com/docs/en-us/parts/terrain.md (the page is linked from the Terrain docs; fetched successfully)
- **Terrain water limits (DevForum, older)**: wave size is cosmetic for smooth terrain and capped; wave direction has no setting (defaults to +Z). These threads are old and may be outdated. https://devforum.roblox.com/t/terrain-water-limitations/38920 and https://devforum.roblox.com/t/terrain-waterwavedirection/182833
- **Custom ocean via mesh deformation**: the common route for large storm waves. Gerstner waves applied to an EditableMesh or skinned mesh, client-side only to limit server cost. https://devforum.roblox.com/t/making-a-mesh-deformation-ocean/1122587?page=2 and https://devforum.roblox.com/t/dynamic-wave-simulation/2690582
- **Gerstner wave formula with multiple octaves**: a community write-up sums several wave octaves; a third-party summary links back to DevForum. https://www.creation.dev/learn/how-to-create-realistic-ocean-waves-roblox-gerstner-waves (third-party)
- **Terrain-wave sync issue**: a DevForum reply says terrain wave sampling for buoyancy can desync after ~10 minutes because the wave clock is not exposed. Do not depend on terrain wave phase for gameplay. https://devforum.roblox.com/t/how-would-i-make-water-physics/1471143 (reply, date not verified)
- **Buoyancy**: sample several points below the waterline, apply upward force per point using VectorForce; force = displaced volume x water density x gravity. Source: https://devforum.roblox.com/t/calculating-custom-buoyancy/240104 and https://devforum.roblox.com/t/how-would-i-make-water-physics/1471143
- **Mobile performance**: no authoritative source found. Keep the mesh-deformation ocean to a small grid, update at reduced rate, and LOD by distance (unverified; engineering judgment, not sourced).

## 3. Vehicles (boats, jet skis, helicopters)

- **Constraints**: use `VectorForce`, `AlignOrientation`, `LinearVelocity`, `AngularVelocity`. `BodyForce`, `BodyGyro`, `BodyVelocity` are deprecated or legacy; DevForum advises migrating. https://devforum.roblox.com/t/buoyancy-boat-broken/1828224 and https://devforum.roblox.com/t/boat-script-not-working/3530265
- **Known pitfalls**: an `AlignOrientation` used for tilt can fight an `AngularVelocity` with the wrong `RelativeTo`; check frame settings first. https://devforum.roblox.com/t/boat-tiliting-problem/2786650
- **Boat physics reference threads**: https://devforum.roblox.com/t/how-to-make-a-boat/1529508 and https://devforum.roblox.com/t/custom-water-ships/1387577/21 (community; quality varies)
- **Helicopter flight controller**: no source found in this pass (unverified). Typical approach: VectorForce for lift along the rotor axis plus AlignOrientation for attitude, with a PID on climb rate. Build and test in Studio.
- **Jet ski**: no source found (unverified). Likely a VectorForce on the hull plus a lateral-grip force to avoid sliding; tune with planing response.
- **Open-source kits**: A-Chassis (cars) was not verified in this pass. A "vehicle-physics" skill exists at https://playbooks.com/skills/taozhuo/game-dev-skills/vehicle-physics (third-party; not a Roblox kit).

## 4. Weather, storm, lighting

- **Atmosphere**: controls air density, haze, glare, color. **Clouds**: cover, density, color; global wind drives drift. **Sky**: standard. https://create.roblox.com/docs/en-us/environment
- **Clouds rendering upgrade**: a Roblox staff DevForum post says a Clouds rendering upgrade (self-shadowing) and new Sky, Atmosphere, and "Currents" wind controls were on the roadmap. Date not confirmed; creators with tuned clouds may need to retune. https://devforum.roblox.com/t/dynamic-skies-are-getting-cloudy/869476
- **Future lighting**: an old beta thread (c. 2020) and SEO pages. Shipping status in 2026 is (unverified). Do not design around it without checking the Creator Hub release notes.
- **Rain, lightning**: no official Roblox system found. Community option: Advanced Weather System v1.6 (paid, third-party; scheduled rain, snow, lightning, lighting presets). https://builtbybit.com/resources/expansion-quality-update.58747/ Otherwise build with ParticleEmitter for rain and a scripted flash of Lighting/ColorCorrection for lightning (approach is standard; not sourced).

## 5. Assets, audio, animation

**Import pipeline**
- **Formats**: FBX suits rigged/animated models; glTF/GLB suits PBR props. Vendor sources disagree on whether glTF is fully supported; a DevForum post mentions FBX now and glTF "in the future." https://devforum.roblox.com/t/roblox-import-3d-bug/2506325 and https://nilo.io/articles/roblox-studio-3d-import-tips (vendor)
- **Triangle cap**: sources cite ~20,000 to 21,000 triangles per MeshPart; behavior on exceed is disputed (reject with error vs. decimate). Verify in the 3D Importer. https://nilo.io/articles/optimize-model-for-roblox-export (vendor)
- **Texture size**: sources give 1024x1024 as the safe cap on some accounts; others claim up to 4096 or 8K with mobile warnings. Target 1024 for mobile. https://nilo.io/articles/vibe-coding-roblox-assets (vendor, conflicting)
- **Materials**: one material per mesh is commonly cited; use texture atlases for multi-surface props (unverified against official docs). https://nilo.io/articles/roblox-studio-custom-model-import (vendor)
- **Scale**: unit mismatches are the most common import error. Mention in the pipeline checklist.

**Creator Store / Toolbox risk**
- Roblox docs say free models can hide server-side backdoors. Mitigation: set `SandboxedInstance` to Experimental on Workspace, set the model's `Sandboxed` true, limit `Capabilities` (be careful with Network, DataStore, AssetRequire, CapabilityControl, LoadString), and manually review obfuscated scripts. https://create.roblox.com/docs/en-us/scripting/security/third-party-vulnerabilities
- The Toolbox shows a warning when a model contains scripts. https://create.roblox.com/docs/en-us/scripting/security/third-party-vulnerabilities
- Shield Scan (GitHub) scans for backdoor patterns; flagged scripts still need manual review. https://awesome.ecosyste.ms/projects/github.com%2Ftuidevelops%2Fshield-scan
- Rule for this project: do not insert free models with scripts. Pull only meshes and materials, strip scripts.

**CC0 sources**
- **Poly Haven**: CC0 public domain. Source: secondary guide https://app.cinevva.com/guides/game-assets-guide.html (confirm on polyhaven.com license page)
- **Kenney**: CC0 across models, sprites, UI, audio. Same secondary guide. Confirm on kenney.nl.
- **Quaternius**: mostly CC0; some packs labeled "Royalty-Free / CC0" with inconsistent wording. Confirm per pack.
- **ambientCG**: CC0 materials, 1,700+ entries claimed, API available. Confirm on ambientcg.com.

**Audio**
- Roblox docs: Creator Store has 100,000+ free-to-use sound effects and music from partners. Only import audio you have permission to use. https://create.roblox.com/docs/en-us/audio/assets
- Asset privacy keeps imported audio IDs restricted to permitted users. Same page.
- Freesound (CC0 subset): not verified in this pass (unverified). Check each clip's license.

**Animation**
- **Roblox Animation Editor** / **Moon Animator**: no sourced 2026 information found. (unverified)
- **Mixamo**: an Adobe community FAQ (dated, ~2022) says game projects are allowed but raw character/animation files must not be distributed; Mixamo's 2021 Additional Terms prohibit using outputs to train AI. Embedded use in a game appears acceptable; re-check current Adobe terms before shipping. https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400 (forum, dated)

## 6. Art style and AI

- **Visual styles**: no authoritative survey of top 2025-2026 Roblox games was found. A secondary article describes Roblox graphics as a mix of stylized and semi-realistic (unverified; low-quality source).
- **Style cohesion**: vendor guides advise a consistent palette and effects across assets, and testing assets under varied lighting. https://dev.to/vasundhara/how-to-choose-the-right-art-style-for-your-roblox-game-1dj6 (secondary)
- **Homogenization**: one piece warns that many developers using the same AI tool reduces distinctiveness. https://layer.ai/integrations/roblox-studio (vendor; treat as opinion)
- **Recommendation for Mayday**: stylized, readable low-poly with a hand-tuned palette, custom ocean shader, and a few hand-modeled hero assets. Avoid scattering raw generative meshes across the town. "Asset flip" perception comes from unmodified store packs, not from style choice alone (judgment; not sourced).

**Roblox AI policy and tools**
- Roblox generative AI docs: creators must keep AI integrations safe, follow Community Standards, and be transparent to players. Experiences where players trigger model responses (text chat, voice, images, 3D generation, avatar movement) must be declared in the content maturity questionnaire. Creators remain responsible for AI-generated content they deliver. https://create.roblox.com/docs/en-us/generative-AI (last updated 2026-06-11 per search snippet)
- **Cube 3D**: Roblox's generative 3D model, released March 2025; open-sourced on GitHub and HuggingFace; mesh generation in Studio and as an in-experience Lua API (beta). https://corp.roblox.com/newsroom/2025/03/introducing-roblox-cube
- **Terms of Use**: a secondary monitor reports AI feature terms moved into the main Terms effective 2026-04-30. Unverified against Roblox's own page. https://conductatlas.com/change/2026-04-09-roblox-roblox-terms-of-use-267/

---

## Open items to verify in Studio or official docs

1. Current 3D Importer triangle and texture limits (conflicting sources).
2. Whether Future lighting is live for all clients in 2026.
3. Boat/heli/jet-ski physics approach that holds up at scale (no official kit found).
4. Current Mixamo and Quaternius license wording.
5. Roblox policy on AI-made 3D assets in the store (not found).
