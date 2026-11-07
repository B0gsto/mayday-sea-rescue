# 13 · Release plan

The launch view of the boat-upgrade game: what is live, what is landing next, what only the owner can do. Detailed
open work and branch notes: [`NEXT.md`](NEXT.md). Design: [`00-design.md`](00-design.md), [`30-boat-pivot.md`](30-boat-pivot.md),
[`31-layout-and-fuel.md`](31-layout-and-fuel.md).

## 1. Live (2026-11-07)

Launch universe public with ads since 2026-10-29. Latest: **test v109 + launch v41** ("new players start on the boat").

- Cold open on a jet ski; drive near a survivor, they climb aboard; Go back takes you home; level up at the Upgrade
  Station; out again. 50 levels in 5 stages (pivot release v108 / v40, 2026-11-05).
- Sea zones with rarer survivors farther out, rescue runs, pirates, Deep Spin (one spin per trip), six plots on a
  ring of Lego islands, optional island building.
- New-player pass (v41): free Hut at load, first delivery lands in the station bay, Next chip guide, L2-L5 one trip
  each, swim-out walls. Playtest fun 7/10 (v40: 5/10).
- Robux: boat looks, Starter Kit (sale to 2026-11-10), Cash packs and boosts, spins, Finish Now (`04-monetization.md`).

## 2. Landing next (on `t3/release-2`, not published)

Owner asks of 2026-11-07, built and merged into the release branch:

| Change | Where |
|---|---|
| Zone crossings by fog and water colour, no curtain | `SeaZones.lookAt`, `WeatherController` |
| Go back drives home in about 5 s | `Boat/GoBack` (`TURN` + `RUN`), `GoBackController` |
| Upgrade from the helm anywhere | `UI/Panels/Upgrade`, `UpgradeStationController.Buy` |
| No stepping off at sea | `Boat/SeaExit`, `VehicleExitController` |
| Plot spread, sector spots | `docs/31` D1, D3; `Calls/SectorSpots` |
| Fuel: tank per level, burn by zone, refuel home, empty rides home | `Boat/Fuel`, `FuelService`, `UI/FuelGauge` |

Before publishing: `check.sh`, an Opus playtest (fuel at each zone, Go back from far out, upgrade at the helm, step-off
refusals, phone layout), then `publish_studio.py` and `--launch` from fresh main.

## 3. Open after that

- Hydrofoil and Rocket Cutter final art (L31-50 are Part placeholders; concepts at 7.5 / 7.6, `12-asset-list.md`).
- Unverified in Studio since v40: head-on land hits at L40+, L30/L50 through the station gate, piece alignment
  L10/20/30, pirate ram cancelling Go back.
- Zone buoy art and the pirate edge arrow sprite (placeholders).
- Approved, not built: Starter Kit rework, five cosmetics on sale (`04-monetization.md` section 6).
- Paid boat concepts (Star Saucer, Dragonkeel, Quack Attack) not built.

## 4. Owner-only steps

- Raise the Starter Kit price on the Creator Dashboard when the sale ends (2026-11-10 00:00 UTC; test 2036091711,
  launch 2040634962).
- Turn on private servers (dashboard).
- Thumbnails and key art; the Discord social link.
- Re-answer the maturity questionnaire if a new paid random item is added.

## 5. Release routine

Every change that passes `check.sh` and its Opus playtest is published to test, then launch, without asking; the
commit reads `Published vN + launch vM (...)`. After a launch: `tools/trail.py --hours 24` and the six-hourly live
check (`build/liveops/LOG.md`).

## 6. Risks

| Risk | Watch |
|---|---|
| Fuel too tight or too loose | `tests/Pacing.spec.luau` caps trips by the tank; read Fuel Empty telemetry |
| Phone performance | `SessionPerf` per device in `tools/trail.py` |
| L40+ speed | Wall glances, sea edge turn, station gate fit |
| Placeholder late stages | The trailer and store text keep L31-50 out until art ships |
