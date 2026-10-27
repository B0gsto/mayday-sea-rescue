# 26b · VFX sources: Creator Store textures and look references

Research for `docs/26-vfx.md` (owner, 2026-10-28: Creator Store and web OK for use or inspiration). Rulebook still
wins: Lego toy look, ocean palette, nothing sparkles on buildings, no flashing orange. Store art is a **stopgap or
reference**. Custom Lego flipbooks (studded puffs, brick confetti, coins) remain the target.

## How these were checked (2026-10-28)

- Search: `apis.roblox.com/toolbox-service/v1/marketplace/{13 decals|10 models}` plus a creator filter
  (`creatorTargetId=3529469&creatorType=Group` = **Roblox Resources**, Roblox's official group).
- Each free model was downloaded (Open Cloud asset-delivery) and parsed for `ParticleEmitter.Texture` and
  `FlipbookLayout`.
- Every id below was checked on `economy.roblox.com/v2/assets/<id>/details`: AssetTypeId, creator and IsPublicDomain.
- **Free/public proof.** Roblox never marks raw Images (type 1) public-domain, so the proof is the wrapper: a Roblox
  Resources decal with `IsPublicDomain=true`, or the free, public (`IsPublicDomain=true`) Creator Store model the
  texture ships in. Images load in any experience.
- Risk: a third-party image can be moderated or deleted later. Keep the id list in `VFXKit` presets so a swap is one
  line, and replace store art with our own Lego flipbooks before launch.
- Contact sheet of every candidate (8 per row, in table order "#"): `build/status/2026-10-28/refs/candidates.png`
  (downscaled copy: `candidates_small.png`).

## Verified store textures per moment

Type 1 = Image (use it directly as `ParticleEmitter.Texture`), 13 = Decal. "In model" = the free public model that
proves the texture is free. Thumbs-up counts come from the toolbox.

| Moment | Texture id | # | Type | Creator | Free proof | Flipbook | Quality note |
|---|---|---|---|---|---|---|---|
| Splash crown | **17063077953** | 29 | 1 | GoldenMan_Dev | in model 16354714995 Golden Particle Pack (392 up), also 112672322113504 | 4x4 | Stylized white splash that rises from a ring into a crown. Closest to toy water. |
| Splash crown | 16808075391 | 2 | 1 | Roblox Resources | decal 16808075451 PD=true | none | Soft white-water burst; good as a second layer under the crown. |
| Splash (top-down ring) | 9833123440 | 20 | 1 | LilacBrush | in model 9838221737 "[FREE] Stylized Water Particles" | none | Thick cartoon splash outline seen from above; lies flat on the water. |
| Splash | 243457340 | 14 | 1 | dragonome | in model 645394740 (90 up) | none | Realistic 2015 splash; too photographic for Lego. Reference only. |
| Splash droplets | 16884276033 / 16886163969 | 3, 4 | 1 | Roblox Resources | decals 16884276137 / 16886164025 PD=true | grid (looks 8x8, check in Studio) | Small arcing drop clusters; good secondary droplets. |
| Droplets | **243132757** | 13 | 1 | dragonome | in model 688959832 Rain Particle (Nanonauts) | none | Clean single white teardrop. Tint teal and stretch with speed. |
| Droplets / spray specks | 17082061238 | 0 | 1 | Roblox Resources | decal 17082061265 PD=true | none | Fine speckle cloud; reads as mist at distance. |
| Foam ring | **16811365086** | 1 | 1 | Roblox Resources | decal 16811365121 PD=true | none | "water_splash_ring": a soft foam donut, lay it flat with `Orientation`. Best foam pick. |
| Foam / ripple | 13992057187 | 23 | 1 | Midori8972 | in model 17303689804 Particle Pack (Water Based) | 8x8 | Dotted ripple that expands. Reads busy; second choice. |
| Toy smoke puff | **16664772965** | 31 | 1 | GoldenMan_Dev | in model 16354714995 | 4x4 | Chunky white cartoon puffs that pop and shrink. Nearest to a round toy puff. |
| Toy smoke puff | 16669188960 | 33 | 1 | GoldenMan_Dev | in model 16354714995 | 4x4 | Radial cartoon puff burst; good for a build-finish dust ring. |
| Toy smoke puff | 14595543880 | 35 | 1 | pleasefreepets121 | in model 112672322113504 Euphoric VFX PACK (980 up) | 4x4 | Rounded cauliflower puffs; a little noisy. |
| Cartoon smoke | 149185730 | 17 | 1 | SonicAssets | in model 887580766 "cartoon smoke" | none | Black-outlined doodle cloud. Wrong style (outline); avoid. |
| Dust puff | 14302399641 | 48 | 1 | Roblox (Environment Art library) | in model 14447738661 (Roblox Resources, PD=true) | none | Soft white cloud cluster; neutral dust under bricks. |
| Dust specks | 173642823 | 18 | 1 | gkku | in model 615333766 Dust Particle Effect (873 up) | none | Tiny dark specks; too dirty for Lego. |
| Smoke (realistic) | 8073306083 | 43 | 1 | JaapSuter (Roblox engineer) | in model 10198615035 Rei's Particle Pack (990 up) | 8x8 | Small realistic smoke sheet. Too real; chimney fallback only. |
| Smoke (warm) | 16830667309 | 7 | 1 | Roblox Resources | decal 16830667370 PD=true | none | Tan cumulus; too realistic for toy puffs. |
| Confetti | **241685484** | 10 | 1 | russelnuts | in model 688963157 Confetti Particles (Nanonauts, 855 up) | none | Plain white square. Tint per particle and spin it to fake a flat Lego plate. Stopgap. |
| Spinning coin | none found | - | - | - | - | - | No free coin flipbook on the store (only a Robux bill, 284636558). Build our own. |
| Shockwave ring | **16477162837** | 38 | 1 | IxJoke | in model 112672322113504 / 16354714995 | 4x4 | Thick white ring that grows and thins. Clean and toy-like. |
| Shockwave ring | 14762708319 | 24 | 1 | FalKirus | in model 17303689804 | 4x4 | "ImpactCircle": crisp white rings, solid to thin. Good alternative. |
| Shockwave (burst) | 11536435403 | 36 | 1 | Yuruzuu | in model 112672322113504 | none | Radial streak burst; anime look. Avoid. |
| Soft glow ring | **838367768** | 19 | 1 | Arro_x | in model 10198615035 Rei's Particle Pack | none | Soft-edged ring disc. Good for the slow-breath golden-call pin. |
| Glow dot | 12082081459 | 40 | 1 | ghxstying | in model 112672322113504 | none | Soft radial gradient; a generic glow core. |
| Crisp ring | 1084952073 | 41 | 1 | gkku | in model 112672322113504 | none | Hard outline circle; good for a steady UI-style ring. |
| Rainbow ring | 18309551531 | 6 | 1 | Roblox Resources | decal 18309551552 PD=true | none | Hue ring; tint it to gold for a reward ring. |
| Rain streak | **241868005** | 12 | 1 | m27frogy | in model 483675631 Rain (Particle) (196 up) | none | Thin vertical streak; the classic Roblox rain. Thicken it for toy rain. |
| Sea spray | **6763809313** | 44 | 1 | Snaliel | in model 10198615035 | none | Elongated drop streak; flicks off the bow nicely. |
| Spray (steam) | 10034873151 | 42 | 1 | cathorolokochup | in model 10198615035 | 8x8 | Soft steam sheet; spindrift for storms. |
| Bubbles | **243953162** | 15 | 1 | TheeTatahThailand | in model 5463907036 Bubble effect! | none | Glossy round bubble with a highlight; reads at small size. |
| Bubbles | 254204945 | 16 | 1 | JaysonJeanChannel | in model 272005884 Bubble Particles | none | Cyan rim bubble; more stylized. |
| Bubbles | 109157529833093 | (no thumb) | 1 | Roblox Resources | decal 119008272660841 PD=true | none | Roblox's Custom-Bubble; the thumbnail did not render, so check it in Studio. |

Packs worth opening in Studio for more frames (all `IsPublicDomain=true`, free):
- 16354714995 The Golden Particle Pack (GoldenMan_Dev): the cleanest stylized 4x4 sheets.
- 112672322113504 VFX PACK (Euphoric Games Community, 980 up): 252 textures, mostly anime. Use only the water,
  smoke and ring sheets.
- 10198615035 Rei's Particle Pack (ReiAkaris, 990 up).
- 17303689804 Particle Pack (Water Based).
- 9838221737 Stylized Water Particles (LilacBrush).

## Look-and-feel references

| Game / style | Borrow |
|---|---|
| Pet Simulator 99 (BIG Games) | Coins fly in an arc into the wallet counter, and the counter ticks up with a squash pop: our CashBurst. |
| Bee Swarm Simulator (Onett) | Flat, chunky pickup tokens that bob and spin, readable from far away. Use the same for coins and medals. |
| Adopt Me! (Uplift Games) | Soft rounded UI that bounces in, with one confetti burst on big moments and nothing in between. |
| Grow a Garden | Weather as world state (sky tint, rain, a light change) instead of popups. Fits our Storm. |
| Fisch | Water feel: a bobber splash, ripple rings and rarity-coloured catch reveals, all at a calm pace. |
| SharkBite 2 | Boat wake, bow spray and splash scaled by speed in a bright toon ocean. |
| Build A Boat For Treasure | Toy-block boats on water. Splashes and debris stay blocky and match the brick world. |
| Theme Park Tycoon 2 | The build-placement pop: the piece drops in, squashes, gives one dust ring and settles. |
| LEGO Fortnite / LEGO Star Wars: Skywalker Saga (off-platform) | Brick-shaped build puffs, studs scattering and bouncing, round studded smoke. This is our Lego target. |

## Recommended picks

| Moment | Pick | Fallback |
|---|---|---|
| Splash crown | 17063077953 (4x4) | 16808075391 |
| Droplets | 243132757 | 16884276033 |
| Foam ring | 16811365086 | 13992057187 (8x8) |
| Toy smoke / dust puff | 16664772965 (4x4) | 16669188960 (4x4), 14302399641 |
| Confetti (Lego) | build our own brick/plate flipbook | 241685484, tinted |
| Spinning coin | build our own (no store asset) | none |
| Shockwave ring | 16477162837 (4x4) | 14762708319 (4x4) |
| Soft glow ring | 838367768 | 18309551531, tinted gold |
| Rain streak | 241868005 | none |
| Sea spray | 6763809313 | 17082061238 |
| Bubbles | 243953162 | 109157529833093 |
