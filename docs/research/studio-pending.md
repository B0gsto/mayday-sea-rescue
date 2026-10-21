# Studio checks waiting on the ban (2026-10-20)

The user paused all Studio use at ~14:15. Everything below is written and passes check.sh, but still needs one Studio
look. Run in this order when the ban lifts; one agent, short sessions.

1. ~~**Fresh-profile journey**~~ **Done (G71 round 4):** cold open -> reward (0:35) -> station -> call 2 (5:55) -> gear
   beacon (5:55); call 3, gear purchase, cert and rank-up were not reached (Studio window limit, on-foot route to the
   Chandlery). A board-goal bug was found and fixed (see playtest-first-20-min.md Round 4). `smoke.py ops` still needs a
   run.
2. ~~**Casualty care as world actions**~~ **Partly checked (G71 round 4):** survey/treatment run as world objects with
   the E chip, but the test harness cannot turn a locked first-person camera (MCP/HID mouse moves give no look delta),
   so the hands-on aim could not be driven; the crew fallback finished both. Needs a human keyboard/touch/gamepad pass.
   Calm and triage were not reached.
3. **G50 bug batch (G71 round 4):** starting Cash 0 **confirmed**; idle jet ski held station (no creep/wedge seen);
   no pager during the gear beacon in the following minutes. Still open: a storm already running at cold-open start was
   **not** held (cold open played in a storm); Space during the survey was not exercised (the driver avoided it).
4. **Touch HUD** (G51): minimap top-left, thumbstick and jump zones clear on a small phone, a tall phone and a tablet.
   Also from G41: the phone home screen opened, Season Logbook on a phone, tablet panels, world boards, gamepad focus.
5. **Pets** (G48, G83): petting hearts, bow-sit framing, pen bond pips, life vest; G83 real scale + PetSeat on jet ski and RIB from the chase camera.
6. **Cosmetics** (G38): bay-decor row, title tag, decals and chevrons on both sides.
7. **Lifeboat** (G39): side view, driving at speed, beacon flashes only on a call.
8. **Platform prompts** (G47): rank-up -> favourite offer fires (the prompts themselves only render on the real
   platform).
9. **Events board** (G52) and **winter event** (G56), next-goal 3-goal view, pulse/chime (G58; I / RB),
   **LiveOps fake-message test** (G60).
10. **Persistence round-trip** (G25b): done on the real backend, see below.
11. **Store art** (O4): a 1920x1080 capture path, beacon hidden, art-directed shots, icon.
12. **Accessibility** (G61): settings panel, colour-assist palettes on album/debrief/pips, triage tag shapes, hold-to-tap prompts, reduce-motion effects.
13. **Vehicle upgrades** (G66): Fit stands at Bay 1, upgrade parts on a RIB, handling feel.
14. **Lighthouses** (G67): the crank wheel in view, the relit beam at dusk, the Outer zone opening for calls.
15. **Third-person camera + first-person transition** (G77): on-foot third person, jet-ski chase framing in the cold open, the dolly into a care step and back, reduce-motion fade cut, no clipping near the hull/water.
16. **Winter Frost Fleet** (G84): dev-force (chat /winter) -> snow around the camera, roof/harbour frost, the Frost Fleet call offered and playable.
17. **Bosun hero model** (G82): LP scale and seams on the rig, hero weld alignment up close, the LP/hero swap at ~34 studs, sit/trot/tail/head motion, wet look after a swim.

## Persistence round-trip (item 10) — PASS, 2026-10-20

`tools/persist_check.py` ran against the published test place (universe 10771468869, place 85419402278824,
version 15) through the Open Cloud Luau Execution API, using the game's real `DataService` save path for the fake
profile `Player_-77` (real `DataStoreService` store; fake Player table through the module's `_test` seam).

- **Write session**: loaded, wrote distinctive values into every field (Cash 987,654; Rep 54,321; certifications;
  cert live counts; album stickers; badge counters; streak; pets; cosmetics; vehicle upgrades; lighthouses;
  logbook; gear; vehicles; totals; exercises; awarded badges), saved and released the session lock. The store
  read-back matched the profile exactly (record version 2).
- **Second execution session**: cold load through `DataService`; every field compared **PASS**, including the
  derived rank (Lifeguard, index 2). No mismatches.
- **Open Cloud DataStore read**: entry `PlayerData_v1/Player_-77` ACTIVE with the same values.
- **Cleanup**: test key removed (`RemoveAsync` + Open Cloud DELETE; GET then 404).

No save bugs found; no game source changes. Run: `python3 tools/persist_check.py` (add `--keep` to inspect the key).
