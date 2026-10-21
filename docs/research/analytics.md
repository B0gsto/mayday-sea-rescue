# Analytics: what we send, what it answers (G64)

Owner: `src/server/Services/TelemetryService.luau` (the only caller of `AnalyticsService`) and its
pure side `src/server/Services/Telemetry/Events.luau` + `src/shared/TelemetryNames.luau`.
Every event name is on the fixed list (21 custom names, 15 funnel steps); a new variant is a field
value, not a new name. No PII: fields are kinds, grades, rarities, short keys and numbers.

Roblox only records analytics from a **published** game, not from Studio. While building, check the
server log / `ServerStorage.TelemetryDev:Invoke("recent")` in Studio, then publish to the test
universe and read the Creator Dashboard.

## 1. Onboarding funnel (Creator Dashboard > Analytics > Funnels > Onboarding)

One row per player per step. The numbers are in the order a new player meets them (G64 renumbered
the funnel once, before launch, because Roblox counts a skipped step as completed):

| Step | Name | Fires when | Question it answers |
|---|---|---|---|
| 1 | Joined | PlayerAdded | How many sessions start? |
| 2 | ColdOpenStarted | the jet ski cold open begins (spawn attempted) | Does the first rescue load? |
| 3 | ColdOpenApproach | the auto-throttle run-in starts | Does the spawn reach the casualty? |
| 4 | ColdOpenRecovery | the casualty grabs the jet ski | Does the grab/hold work without skill? |
| 5 | ColdOpenEnded | the cold open ends, any reason | **95% finish the cold open** (docs/15 §3) |
| 6 | RewardSeen | the client plays the first reward burst | Is the 1:30 payoff actually seen? |
| 7 | ReachedStation | the client reaches the station beacon | Does the "walk to the station" goal work? |
| 8 | Call2Accepted | the first station call is accepted | Does the call board/beacon lead to a call? |
| 9 | FirstOpComplete | the first station call is rescued (call 2) | Does the reward loop land? |
| 10 | Call3Complete | the second station call is rescued | Does the loop repeat without a tutorial? |
| 11 | FirstChandleryVisit | the gear counter prompt is used | Do they find the shop? |
| 12 | FirstUnlock | first gear or vehicle bought | **70% reach minute 10**; first unlock (~5 min) |
| 13 | FirstRank | first rank-up | Do players reach the first ceremony (~10 min)? |
| 14 | FirstDailyCrate | the first daily crate opens | Is the daily hook discovered on day 1? |
| 15 | Day2Return | first session on a later UTC day | **50% come back the next day** (tune) |

Steps must be logged in this order: Roblox counts a skipped step as completed, so logging an early
event with a later number would mark everything before it done. G64 renumbered the funnel once,
before launch; do not renumber again after launch, append new steps at the end.

Read the funnel top to bottom and compare adjacent steps: the biggest absolute drop is where new
players leave. Step 5→9 is the reward hand-off and first call, 9→13 is the first 10 minutes, 14→15 is
the daily hook.

Targets (docs/15 §3): 95% finish the cold open, 70% reach minute 10, 50% come back the next day.

## 2. Custom events (Creator Dashboard > Analytics > Explore)

| Event | Value | Fields (01, 02, 03) | Question |
|---|---|---|---|
| OpStarted | 1 | kind, rarity, context | Which calls get accepted, by variant rarity? |
| OpGrade | 0-3 | kind, grade, rarity | Which call kinds grade well, and for which rarity? |
| OpComplete | 1 | kind, grade, rarity | Completion rate per kind (join with OpStarted) |
| OpFailed | 1 | kind, reason, context | Why calls are lost: timer, takeover, failed grade |
| ColdOpenEnded | 1 | reason | Cold-open outcomes (Complete, Timer, Died, LeftCraft) |
| StormJoined | 1 | Great/Storm, Start/MidStorm | Do players join the hourly Great Storm? |
| DailyCrate | streak day | Daily/Welcome, crate day | Which streak days retain (day 2-3 vs 6-7)? |
| ChallengeDone | 1 | daily/weekly, challenge id | Which challenges are worth keeping? |
| AlbumSticker | 1 | rarity, variant id | Does the collection hook work (rare stickers)? |
| PetAdopted | 1 | species, Rare/Common | Which animals do players pick to follow them? |
| PetPetted | 1 | none | Is the hold-to-pet interaction used (client-reported)? |
| PetTreated | 1 | species, bond pips | Is the treat/bond loop used? |
| StockBuy | 1 | Gear/Cosmetic, item key | What rotating stock sells? |
| IdleCollect | Cash | none | Is the away-income pot worth returning for? |
| SeasonClaim | tier | none | How far through the 30-tier track do players get? |
| EventJoined | 1 | GhostLight/GhostShip/FrostFleet | Do the timed events bring players in? |
| LiveEvent | 1 | event id | How many players see each LiveOps event? |
| FriendBonus | percent | friend count | Does the friends bonus actually apply? |
| CrewFlare | 1 | none | Is the crew-up flare used (organic growth)? |
| PromptShown | 1 | notify/favorite/invite | Which re-engagement prompt was shown, and how often? |
| PhotoMode | 1 | none | Is photo mode a reason to stay / share? |

Op events carry the **variant rarity** (Common..Legendary) so a rare call can be compared with a
common one; `OpStarted` and `OpComplete` share `kind`+`rarity`, so completion rate = Complete/Started.

## 3. Economy events (Creator Dashboard > Analytics > Economy)

Currency `Cash`; every source is an `extra.award` through `ProgressionService.push`, every sink is
one of the purchase paths below.

| Direction | Transaction | SKU | Sites |
|---|---|---|---|
| Source | IAP | Cash pack / StarterKit key | Monetization/CashEffects |
| Source | Gameplay | `Op:<kind>`, `Op:Share`, `Challenge:<id>`, `Album:<kind>`, `Streak:DayN`, `Season:TierN`, `Station:Idle`, `Logbook:<name>` | Award reasons |
| Source | Onboarding | `Exercise:<kind>` | first exercise pass |
| Sink | Shop | `Gear:<id>`, `Vehicle:<id>`, `Stock:<key>`, `Station:Workshop`, `Treat:FishTreat` | BuyGear, BuyStock, station upgrade, pet treats |

If a new Cash grant does not travel as `extra.award { cash, reason }`, it will not appear. If a new
Cash sink is not one of the four below, add a `CashSpent` line next to the deduction.

Rank promotions also go to `LogProgressionEvent` (path `Rank`, status Complete, level = rank index,
level name = rank display name), so the Progression view shows how far players climb.

## 4. Which dashboard views to read, and when

- **Funnels > Onboarding**: after every playtest and weekly. The first drop from step 1 to 5 is
  load/spawn; 5 to 9 is the first 10 minutes; 14 to 15 is the daily hook.
- **Retention**: D1 and D7 by cohort, and by join day around a seasonal event (Ghost Ship / Frost
  Fleet). This is the number the whole package exists for; the funnel explains *where* D1 leaks.
- **Explore**: put `OpStarted` next to `OpComplete` (kind + rarity breakdown), `DailyCrate` by
  crate day, `ChallengeDone` by id. Use "unique users" for reach and "count" for use.
- **Economy**: sources vs sinks over time; a growing Cash balance means sinks are too weak, a
  falling one means payouts are too tight for the early ranks.
- **Engagement**: session time and sessions per user, sliced by whether `Day2Return` fired.
- **Performance**: frame time / memory on Low tier; a funnel drop at step 2 can also be a load stall.

Custom events aggregate daily, so allow up to 24 h after a published test. Roblox caps custom event
names at 100 (we use 21) and custom fields at three; values are clipped to 50 characters.
