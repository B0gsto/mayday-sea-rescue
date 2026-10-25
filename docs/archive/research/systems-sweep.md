# Systems sweep (G25b)

Automated single-session sweep: `MAYDAY_STUDIO_TAG=mayday-sweep python3 tools/studio/soak.py 12`.
One Studio play session, 6.2 minutes, 0 console errors, 1 expected warning
(`[StormService] Warning for 60s (storm 1, GREAT)`).

Raw log/table: `build/smoke/sweep.txt`.

## Results

| Check | Result | Evidence |
|---|---|---|
| ColdOpen | ok | O2 completed |
| PersonInWater | ok | 14 s, Silver |
| DisabledVessel | ok | 13 s, Silver |
| CapsizedFerry (big op) | ok | 23 s, Gold |
| CliffCasualty | ok | 9 s, Silver |
| RipCurrent | ok | 8 s, Silver |
| SinkingVessel | ok | 9 s, Silver |
| VesselFire | ok | 11 s, Silver |
| WildlifeRescue | ok | 8 s, Silver |
| ExerciseCoxswain | ok | 7 s, Silver |
| GreatStorm (clock event) | ok | Storm + Great, phase Active, rep x2 flag |
| GhostLight (clock event) | ok | DisabledVessel call offered and completed |
| GhostShip (seasonal) | ok | big op O15, completed |
| LegendaryVariant | ok | GoldenGull rescued, album credit |
| StreakCrate | ok | day 7 crate opened |
| StockPurchase | ok | gear slot bought, gear level 1 |
| StationIdle | ok | 1.5 h payout 2400, level 1 |
| SeasonClaim | ok | tier 1 claimed |
| AlbumCredit | ok | Swimmer recorded |
| PetAdopt | ok | ready + equipped at sanctuary |
| CosmeticEquip | ok | Livery StockRed equipped |
| FriendBonus | ok | 3 friends, +30% |
| RankCeremony | ok | rank 4 -> 8, ceremony GUI |
| VehicleLaunch | ok | JetSki requested |
| PersistRoundTrip | SKIP | DataStore unavailable in this Studio place |

## Open issues

1. **Persistence is unverified in Studio.** `DataStoreService` returns "You must publish this
   place to the web" here, so the play stop/start round-trip restarts on a fresh memory-mode
   profile. `soak.py` detects this and prints one `SYSTEM SKIP`. The per-field checks (streak,
   pets, album, season, gear, station, cosmetic) are already in the script and run automatically
   once the probe succeeds; repeat the sweep on a published/test place with API access.
2. **Ghost Ship can hand out a follow-up call** the moment the big op ends. An immediate forced
   Legendary start can then attach to that new call instead of spawning its own. The sweep waits
   for idle and retries (max 2); watch offer pacing after big ops.
3. **Dev-hook range checks are real.** Stock purchase, station collect, streak open and pet equip
   all check the character's position. If the character is still seated after an operation,
   `PivotTo` is undone by the seat; the sweep unseats and waits before teleporting.
4. **StockDev `buy` keeps the in-world counter range**, so scripts must stand at the Chandlery
   counter; the sweep locates the `ShopCounter` prompt and teleports there.
