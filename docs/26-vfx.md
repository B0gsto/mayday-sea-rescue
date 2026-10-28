# 26 · VFX rulebook (Mayday: Sea Rescue)

The game's effects follow the global VFX rules (user CLAUDE.md "VFX (all games)") plus these. Owner rules win.

## Owner bans

- Nothing sparkles on a building, ever (no glitter, shimmer or sparkle particles on buildings or sites).
- No flashing or pulsing orange to present anything (CLAUDE.md "Show, don't tell"). Attention cues: one pop, a steady
  outline, a slow small breath at most, an arrow or a camera focus.
- Steady night lights are fine (lit windows, lamps, beacons); they are lights, not sparkle.

## Look

- Lego toy world: chunky, rounded, flat bright colours, soft shading. Particles read as toy pieces: round studded
  puffs, flat 1x1/1x2 plates and bricks, round tiles, chunky water drops. No realistic smoke or fire.
- Palette: coastguard red, white, navy, sea blue/teal, Lego yellow/gold, warm tan. Water effects use the ocean's own
  blue-teal and white foam.
- Brightness: LightEmission at most 0.3 except the biggest reward moments (HQ level up, Mythic); Brightness 1-2.

## Moments (job -> spec)

| Moment | Job | Spec |
|---|---|---|
| Building / level finished | feedback | bricks snap down, a ring of flat Lego plates bursts out low and lands, one dust puff ring; confetti only above the site, never on the building |
| HQ level up | spectacle | the above plus a tall burst of confetti bricks and a soft gold shockwave ring on the ground |
| Survivor picked up | feedback | a white splash crown + droplets where they leave the water |
| Survivor delivered / rescue done | spectacle (small) | a ring of lifebuoy-coloured plates and a coin burst into the wallet (CashBurst) |
| Golden call | state + spectacle | a steady gold ring on the pin (slow breath), a gold burst on accept, the survivor's steady glow |
| Cash / Medal gain | feedback | coins / medal flip into the counter (UI) |
| Join reward Collect | spectacle | UI/CoinShower: wallet coins pop in across the screen, bob, then stream on curves into the wallet (rising ticks, the counter rolls in step), a till and one soft gold ring at the wallet (~2 s) |
| Barge moors | state | a bow wave and a foam ring at the quay, a soft horn smoke puff |
| Boat wake / spray | state | the existing Ocean/Wake trail + spray, scaled by speed; chunky foam |
| Storm | state | rain streaks, whitecaps, spindrift (docs/05 7) |
| Prize wheel | spectacle | spin streaks on the rim, a win burst sized by rarity |
| Chimneys (smokehouse, cottages) | ambience | a slow puff every few seconds, round studded smoke, near the player only |

## Budgets and tech

- One client module (`VFXKit`) owns presets, pooling and quality scaling: effects are data, called by name.
- Burst with `Emit`, pool emitters, cap particles per effect (feedback <= 40, spectacle <= 120), distance-cull (> 250
  studs: skip) and scale by `UserGameSettings.SavedQualityLevel`.
- Flipbook textures (Blender-rendered sprite sheets, `ParticleEmitter.FlipbookLayout`), uploaded as Images.
- Reduce-motion setting: no camera shake, smaller bursts.

## Test loop

The DEV panel's `vfx <name>` fires any preset in front of the camera; a playtester captures 3-4 frames per effect into a
contact sheet; an Opus art director scores it (ships at 8.5+); then check it on low graphics quality and in gameplay.
