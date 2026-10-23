# 15 · Retention, live events and the new player

> Where this chapter and [16 · Launch polish plan](16-launch-polish-plan.md) disagree, docs/16 is the current source of truth (2026-10-23: many systems below were cut for launch).

Goal (user, 2026-10-19): mass appeal for children and adults, heavy focus on retention and the first session, with
time-limited content that brings players back, executed well enough to compete with the top Roblox CCU games.
This chapter adds to docs/03 (progression) and docs/04 (monetization); where they disagree, this one wins.

## 1. Fair FOMO (hard rules)

Many players are children. Time pressure is used for **free, earnable** content only.

- Everything time-limited (event cosmetics, rotating stock, rare calls) can be earned by playing. Robux only buys
  time savers or cosmetics that are always on sale.
- No countdown timer next to a Robux price. No paid random boxes outside docs/04's Sea Chests rules (odds shown,
  PolicyService gated, Cash path).
- Streaks forgive: one missed day is free (a "calm day"), and a broken streak drops back a few days, never to zero.
- Nothing is lost for not playing: no decay, no penalties (docs/03 section 9).
- Show, don't tell (CLAUDE.md): timers are a clock icon + `12:04`, events are a sky / world change plus a 1-3 word
  banner.

## 2. The hooks

| # | Hook | What the player sees | Why it brings them back |
|---|---|---|---|
| H1 | **Server clock events** | Every hour at :00 a Great Storm rolls in on every server (sky darkens 2 min before, sirens, the harbour flags snap); rare calls only happen in it; 2x Rep during it. Every 3 h at :30, a Ghost Light event (night fog, a lost boat with a lantern) | A shared appointment: everyone online at the same time, CCU spikes at the hour |
| H2 | **Rare calls + Rescue Album** | Each casualty type has variants with rarity (Common to Legendary): a kayaker, a lost dog, a seal tangled in net, a pirate-costume swimmer, a celebrity yacht, the "Golden Gull". The album at the station fills with stickers; sets pay out | Collection; "I saw a Legendary call!" moments; kid-friendly |
| H3 | **Rotating Chandlery stock** | Chandlery shelves restock every 10 min on a server-synced clock: gear parts, vehicle trims, decals, bay decor; rare items appear sometimes. Cash only. A clock above the counter | Check-back loop every few minutes, like a seed shop |
| H4 | **Animal sanctuary** | Rescued animals (seal pup, puffin, otter, turtle, gull) recover in pens at your bay and then follow you or ride on your boat as pets; rare colour variants | Pets: a strong child hook and a reason to own a bay |
| H5 | **Daily streak + return gift** | A crate on the station porch each day: day 1 to 7 rising Cash, day 7 a weekly cosmetic; forgiving streak (section 1). Away > 3 days: a welcome-back crate | Daily habit without punishment |
| H6 | **Station crew idle income** | Your bay's crew (radio room, kennel, workshop levels) earns a capped Cash pot while you're away, collected at the bay | Reason to come back and upgrade |
| H7 | **Seasonal event** | Halloween "Ghost Ship" (2026-10-24 to 11-02): a spectral ferry fog event at night, a limited lantern livery and a ghost-dog collar earned by event rescues; then a winter event | Real FOMO, earnable |
| H8 | **Season Logbook** | A 30-tier free track (paid track optional, docs/04) filled by playing anything | Long-term goal across weeks |
| H9 | **Friends** | +10% Cash per friend in the server (cap 3), a "crew up" flare to join a friend's op, friend spawns at your bay | Players invite friends: organic growth |

## 3. The new player (first 15 minutes)

Measured with the TelemetryService funnel (docs/13 RP-A1). Targets: 95% finish the cold open, 70% reach minute 10,
50% come back the next day (tune).

1. **0:00 to 1:30** the cold open: on a jet ski mid-rescue (exists). Must succeed even with no input skill: the
   casualty grabs on, the throw auto-aims after 2 misses.
2. **1:30** first reward burst: Cash counter roll, confetti, Bosun jumps aboard, the jet ski is "yours" (a tag).
3. **2:00 to 5:00** one clear next goal at a time, shown in the world (a beacon on the next thing, no text): the
   station, the call board, the second rescue (an easy PIW in calm water).
4. **5:00** first unlock (gear level 1) + the daily crate opens for the first time.
5. **10:00** first rank / certification ceremony; the RIB shown as the next goal (it unlocks at rank 3, ~30 min, docs/03; Round 5 pace model: rank-up 10.9 min).
6. **Before leaving**: the hourly Great Storm countdown and tomorrow's crate are visible, so the player knows what is
   waiting.

Everything adapts for small children: aim assist, bigger targets on touch, no fail state in the first 3 calls.

## 4. Work packages (G rows in art/bench/QUEUE.md)

G15 server clock + hourly Great Storm (H1) · G16 rare calls + Rescue Album (H2) · G17 rotating Chandlery stock (H3) ·
G18 animal sanctuary + pets (H4) · G19 daily streak crate + welcome-back (H5) · G20 station idle income (H6) ·
G21 Halloween Ghost Ship event (H7) · G22 Season Logbook free track (H8) · G23 friends bonus + crew-up flare (H9) ·
G24 new-player first 15 minutes (section 3) + funnel · G25 full fresh-profile playtest in Studio, fix what breaks.
