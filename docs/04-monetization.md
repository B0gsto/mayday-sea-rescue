# 04 · Monetization

Last rewrite: 2026-10-25. This file owns what is sold, where, and why it is fair. Cash pacing and the unlock tree are
in `docs/03-progression.md`; the loop is `docs/02-core-loop-and-mechanics.md`; the canon is `docs/00-design.md`.
All prices are Robux and **tune** until the live listing says otherwise.

## 1. Stance

Mayday sells **time, looks and shared fun**, never skill.

- A purchase can save a wait, build a building, own a boat or change a colour. It cannot buy a better grade, a
  farther call or a survivor.
- No ranks (docs/23 (q)). **Robux skips the Cash, never the order:** a building or craft can be bought with Robux
  only once its prerequisites stand (the buy button is greyed with "Needs: X" until then; the server grant checks
  it too).
- Every building, call and free craft is earnable with Cash. The four premium boats are Robux alternatives on the
  RIB's reach; they need the boathouse.
- The player opens every prompt. There are no pop-ups, no countdowns, no "buy before you lose it" offers and no
  offers during a call.
- No paid random at launch. Sea Chests are planned, cosmetics only, with odds shown.
- Nothing is sold to children through pressure. The shop is a left-column button; in-world counters and the build
  tablet are the only other places to buy.

## 2. The catalogue at a glance

| Kind | What it does | Price |
|---|---|---:|
| **2x Cash** (pass) | Doubles Cash from rescues forever | 75 |
| **Quick Launch** (pass) | Removes the Boat to me wait; launches owned craft | 49 |
| **Starter Kit** (pass) | 3,000 Cash once; livery and Bosun bandana later | 25 |
| **VIP Crew Card** (pass, in progress) | Gold nameplate and gold livery | 299 |
| **RIB / Lifeboat / Submarine / Helicopter** (passes) | Own the craft once its building stands | 49 / 129 / 249 / 399 |
| **Storm Runner / Tidewalker / Riptide X / Gilded Gull** (passes) | Premium boats, Robux only | 199 / 249 / 129 / 199 |
| **Cosmetics** (passes, in progress) | Bosun, friends, liveries, outfits, horns, sirens, lights, wakes | 79–249 |
| **Cash packs** | Minutes of Cash | 10 / 25 / 75 / 149 |
| **Cash Boost** | 2x Cash for 30 minutes of play | 15 |
| **Crew Boost** | +50% Cash for you and your crew, 20 minutes | 15 |
| **Day 2x Cash / Day Quick Launch** | A pass effect for 24 real hours | 15 / 10 |
| **Island buildings** (every tree building) | Builds it now, no Cash (prerequisites first) | 15–199 |
| **Decorations** | Places it now, no Cash | 35–199 |
| **Storm Summons** (in progress) | A server-wide storm; weather is currently always sunny | 49 / 149 |
| **Sea Chests** (planned) | Cosmetic-only random chest, odds shown | — |

## 3. Where it is sold

| Place | Sells |
|---|---|
| **Shop** (left column) | Passes, Cash packs, boosts, day passes, cosmetics. |
| **Market stall** (hub) | The shop counter; same catalogue, in-world. |
| **The build station / tablet** (your island) | Island buildings (Robux button once the prerequisites stand). |
| **The boat board** (boathouse) | Choosing an owned craft; pass-owned craft appear here. |
| **The harbourmaster's shack** (hub) | Storm Summons, when storms ship. |
| **The paint booth** (boathouse) | Liveries and vehicle cosmetics. |

- A purchase card shows the exact effect, the exact price from `MarketplaceService`, and the owned state. No
  hard-coded prices in the UI.
- Buildings skip the Cash, never their prerequisites. Workers' buildings, the crane, the helipad and decor are Cash
  only for now (no product yet).
- Craft passes own the craft; the Shop and the boat board grey the button with "Needs: X" until its building
  stands. A pass bought elsewhere (the website) still launches. Reach = the best craft you can launch.

## 4. Passes

### 4.1 Always-on passes

| Pass | Price | Effect | Fairness |
|---|---:|---|---|
| **2x Cash** | 75 | 2x Cash from every rescue. | Does not stack with Cash Boost; the higher applies. |
| **Quick Launch** | 49 | No Boat to me wait; launch an owned craft straight into the seat. | Never changes survivors, timers or grades. |
| **Starter Kit** | 25 | 3,000 Cash once; Station Orange livery and a Bosun bandana in a later update. | The Cash is about 12 minutes of play, not a shortcut up the ladder. |
| **VIP Crew Card** (in progress) | 299 | Gold nameplate, gold livery for every vehicle. | Cosmetic only. No extra seats, pay or reach. |

### 4.2 Craft passes

| Pass | Price | Craft | Fairness |
|---|---:|---|---|
| **RIB** | 49 | RIB, 3 seats | Same handling as the earned RIB; no extra reach. |
| **Lifeboat** | 129 | Lifeboat, 4 seats / 8 survivors | Same handling; no extra reach. |
| **Submarine** | 249 | Submarine, 2 seats | The only diver craft; needs the sub pen. |
| **Rescue Helicopter** | 399 | Helicopter, 2 seats, winch | No hangar needed to use it; the hangar is still the island flex. |

### 4.3 Premium boats

| Pass | Price | Boat | Seats |
|---|---:|---|---|
| **Storm Runner** | 199 | Offshore powerboat | 3 |
| **Tidewalker** | 249 | Luxury catamaran | 6 |
| **Riptide X** | 129 | Sport jet ski | 1 |
| **Gilded Gull** | 199 | Gold luxe jet ski | 1 |

Premium boats are Robux only. They are variants of the free fleet, not a tier above it: same controls, same
pick-up rule, same reach cap, same grade. The store never claims a handling advantage.

### 4.4 Cosmetics (in progress)

| Pass | Price | What |
|---|---:|---|
| **Bosun's Wardrobe** | 129 | Coat colours, bandanas, life jacket, tiny captain's hat. |
| **Water Dog Friends** | 199 | A Labrador and a Portuguese Water Dog for Bosun's slot. |
| **Storm Chaser Liveries** | 249 | Animated lightning-stripe liveries and a storm-blue uniform. |
| **Captain's Locker** | 99 | Wetsuit, foul-weather coat, caps, whistle emote. |
| **Sea Shanty Radio** | 79 | In-vehicle radio playing the game's own music; others can mute. |
| **Horn Pack** | 79 | Six horns on a tap button; others can mute. |
| **Siren Pack** | 99 | Four siren tones with light patterns; others can mute. |
| **Light Bars** | 129 | Six light-bar colour sets. |
| **Wake Trails** | 149 | Five wake trails. |

Cosmetics never change seats, speed, reach, pay or grade. Every sound can be muted by other players. No cosmetic
is required to read a call.

## 5. Products

### 5.1 Cash packs

| Pack | Price | Cash at launch rate | Bonus | Daily limit |
|---|---:|---:|---:|---:|
| **Small Bonus** | 10 | 1,500 (15 min) | — | 5 per account per day |
| **Crew Payroll** | 25 | 4,500 (45 min) | — | 5 per account per day |
| **Station Budget** | 75 | 16,500 (2.5 h) | +10% | 5 per account per day |
| **Harbor Fund** | 149 | 50,400 (7 h) | +20% | 5 per account per day |

- Packs pay Cash only. The card shows the exact Cash before purchase.
- The launch rate is the Calm-water rate (6,000 Cash/hour). Packs pay the best live zone's rate (only Calm water at
  launch). At launch the pack rate is below the play rate; retune any tier that would make a pack faster
  than playing.
- The daily limit is five pack purchases per account, shared across the four packs.
- Cash packs are the only direct Cash purchase; the Starter Kit includes a one-time Cash grant. There is no Cash
  trading, gifting or auction.

### 5.2 Boosts and day passes

| Item | Price | Effect | Duration |
|---|---:|---|---|
| **Cash Boost** | 15 | 2x Cash | 30 minutes of playtime; pauses while away. |
| **Crew Boost** | 15 | +50% Cash for you and your crew | 20 minutes of playtime; one active per crew. |
| **Day 2x Cash** | 15 | The 2x Cash pass effect | 24 real hours; the clock runs while away. |
| **Day Quick Launch** | 10 | The Quick Launch effect | 24 real hours; buying again adds a day. |

- Cash Boost and the 2x Cash pass do not stack; the higher multiplier applies.
- Crew Boost benefits the whole crew.
- A day pass is a rental, clearly labelled. No Day VIP until the VIP pass itself is ready.
- Boosts never apply to quests, Album finds, the streak crate or Cash packs.

### 5.3 Island buildings and decorations

Every Cash item on the island has a Robux product that skips the Cash, never `needs` (sold at the build tablet
only): the 15 tree buildings at 15–199 R$ and the six decorations at 35–199 R$. Price = the smallest price point at
least 1.3x the Cash packs' price for the same Cash; the full table (Cash, R$, packs) is docs/23 (i) item 10. The
pontoon, boathouse, lookout tower and station keep the old dock levels' keys and ids (`DockLevel2..5`).

## 6. Fairness rules

1. **Never sell skill.** Grades, timers, survivor counts and call reach are earned.
2. **Never sell the order.** Robux skips the Cash of a building or craft whose prerequisites stand, nothing more.
3. **No ranks.** There is nothing to promote and nothing to skip but Cash (docs/23 (q)).
4. **Packs are a convenience, not a better hourly rate.** Retune any tier where a pack would out-earn play.
5. **No pressure.** No countdown, no pop-up, no offer during a call, no offer on the call card.
6. **Random is cosmetic.** Sea Chests are the only random purchase, and they are planned, odds-shown and
   cosmetic-only.
7. **A free player can be top of the server.** The whole tree, the beacon and the rescuer monument are open to
   everyone; only looks and time are sold.
8. **State the number.** Every multiplier is written on the card: 2x, +50%, +10%, 24 hours.

## 7. Platform policy

| Rule | How Mayday follows it |
|---|---|
| **Paid random items** | Cosmetic only, odds shown, no cash-out. Sea Chests are not live yet. |
| **Gambling** | No casino, no wagering, no loot box with Cash value. |
| **Purchase pressure** | The player opens the shop or the world counter. No automatic prompt, no countdown, no "last chance". |
| **Price display** | Live `MarketplaceService` price on every card; no hard-coded Robux. |
| **Regional pricing** | Roblox handles currency and regional price; the card shows the local price. |
| **Honest store art** | Screenshots and trailers show the live game, not a concept. See `docs/07-store-page-thumbnails-and-trailer.md`. |
| **Data and grants** | Purchases are verified server-side; one grant per receipt; no client-side Cash. |
| **Refunds and support** | Purchases use the standard Roblox flow; refunds follow Roblox policy. |

## 8. What is not sold

- Grades, call reach, survivor counts, faster timers, better RNG, a skip of the unlock order.
- Certifications, gear, upgrades, fuel, repairs, crew skill, challenge rerolls.
- 2x Rep, Rep Boost, Sea Time, Fast-Track, Signature vehicles, Season Logbook.
- Cars, ATVs, seaplanes, the garage or any retired vehicle.
- Private servers, gifting, ads, subscriptions, a 5-Robux starter row.
- Anything that changes another player's call, island or payout.

## 9. Price ceiling and review

- No item costs more than 399 Robux. The top of the ladder is the helicopter and VIP; each is a
  clear, visible thing, not a stat.
- Prices are reviewed with the pacing sim and the live conversion data. A price change updates this file, the
  config and the store card together.
- The old product list (2x Rep, Rep Boost, Sea Time, Fast-Track, Signature, Season Logbook, private servers,
  gifting, cars, seaplane, ATV) is retired and must not reappear in the shop.
