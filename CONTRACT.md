# Greybox build contract

The rules every build stream follows for the first playable. Each stream owns its own files. If you need something from another stream, use the API below. If it isn't there yet, code against it anyway and leave a `-- CONTRACT:` comment. Don't edit another stream's files.

## Shared files (read-only for every stream)

`src/shared/Net.luau`, `src/shared/Waves.luau`, `src/shared/Config/GameConfig.luau`, `src/shared/Config/VehicleConfig.luau`, `src/server/Main.server.luau`, `src/client/Main.client.luau`, `default.project.json`, `map/Build.luau`.

The one exception: stream C may add greybox geometry to `map/Build.luau` (buoys, outposts, extra props).

If you need a new remote, don't edit Net.luau. Create a RemoteEvent in your own service under `ReplicatedStorage.Net` with a name prefixed by your stream (for example `Storm_ForceStorm`), and list it in your summary.

## Module convention

A ModuleScript in `src/server/Services/` or `src/client/Controllers/` exports `Init()` and `Start()`, plus an optional `Priority` number (lower runs first, default 100). Services call each other with `require(script.Parent.OtherService)`, and only inside or after `Init`.

## Streams and their files

| Stream | Owns |
|---|---|
| A Ocean | `src/client/Controllers/OceanController.luau`, `src/client/Ocean/*` |
| B Vehicles | `src/server/Services/VehicleService.luau`, `src/client/Controllers/BoatController.luau`, `src/shared/Boat/*`, `tests/Boat*.spec.luau` |
| C Calls / Ops framework | `src/server/Services/OperationService.luau`, `CallService.luau` (shim), `RescueService.luau`, `src/shared/Calls/*`, `src/shared/Ops/*` (except `Definitions/*` step tuning, see below), `src/client/Controllers/OpsController.luau`, `CallController.luau`, `src/client/Mechanics/Default.luau`, `src/client/UI/Call*`, `tests/Call*.spec.luau`, `tests/Ops.spec.luau` |
| D Storm | `src/server/Services/StormService.luau`, `src/client/Controllers/WeatherController.luau`, `src/shared/Weather.luau`, `src/shared/Config/LightingPresets.luau`, `tests/Weather*.spec.luau` |
| E Progression | `src/server/Services/DataService.luau`, `ProgressionService.luau`, `CrewService.luau`, `DogService.luau`; `src/client/Controllers/HudController.luau`, `DogController.luau`; `src/client/UI/Hud*`; `src/shared/Config/ProgressionConfig.luau`; `src/shared/Dog/*` (BosunMotion, BosunWetness); `tests/Progression*.spec.luau`, `tests/BosunMotion.spec.luau` |

## APIs

### D: `src/shared/Weather.luau` (works on client and server)

The server sets these attributes on `ReplicatedStorage.Weather` (a Folder):

| Attribute | Type | Meaning |
|---|---|---|
| `State` | string | `"Calm"`, `"Warning"`, `"Storm"` or `"Clearing"` |
| `StateStartTime` | number | from `workspace:GetServerTimeNow()` |
| `StateDuration` | number | length of the current state |
| `StormId` | number | which storm this is |
| `WindDirection` | number | radians |
| `IsGreatStorm` | bool | whether this is a summoned Great Storm |

Functions:

- `Weather.getState(): string`
- `Weather.getIntensity(now: number?): number` returns 0 to 1, smooth: it ramps up during Warning, holds at 1 in Storm, and ramps down during Clearing.
- `Weather.getZoneAt(position: Vector3): GameConfig.Zone | { id: "OpenSea", shelter: 0 }`
- `Weather.getWaveParams(position: Vector3, now: number?): Waves.WaveParams` gives the params for that spot's zone shelter, cached per zone and frame.
- `Weather.heightAt(position: Vector3, now: number?): number` is a convenience wrapper.
- `Weather.changed: { Connect: (self, (state: string) -> ()) -> RBXScriptConnection }` (it may wrap a BindableEvent)

### D: StormService (server)

- `StormService.ForceStorm(isGreat: boolean?)`. In Studio, typing `/storm` or `/greatstorm` in chat calls it (dev only).

### B: VehicleService (server)

Each spawned vehicle is a Model with these attributes:

- `VehicleId`, `Owner` (UserId), `Capacity`, `SurvivorCount`

It contains these attachments on the hull root:

- `SurvivorSlot1..n` (seat points)
- `TowHitch` (stern)
- `BowPoint`

Functions and events:

- `VehicleService.GetVehicle(player): Model?`
- `VehicleService.GetDriver(model): Player?`
- `VehicleService.GetOccupants(model): { Player }`
- `VehicleService.AddSurvivor(model, survivorModel): boolean` welds the survivor to the next free slot, or returns false when the boat is full.
- `VehicleService.RemoveSurvivors(model): { Model }`
- `VehicleService.AttachTow(model, targetModel): boolean` uses a RopeConstraint from TowHitch to the target's `BowPoint` and gives the towed model's network ownership to the tower's driver.
- `VehicleService.DetachTow(model)`
- `VehicleService.VehicleSpawned` is a signal with `(player, model)`.

`RequestVehicle` (a RemoteFunction) takes `vehicleId` and checks `ProgressionService.CanUseVehicle`.

### C: OperationService and RescueService (server)

Superseded by "Operations v2" below. `CallService` is a thin shim kept for old callers (`GetActiveCalls`, `GetVictimPositions`, `CallCompleted`, `ForceBigCall`, all delegating to `OperationService`); the `Call*` and `RescueAction` remotes in Net.luau no longer fire. `CallController` is retired; `src/client/UI/CallCard.luau` stays for reuse.

### E: ProgressionService, CrewService and DogService (server)

- `ProgressionService.Award(player, cash: number, rep: number, reason: string)` applies storm multipliers itself: Cash x1.5 in a storm, x2 in a Great Storm, and Rep normal.
- `ProgressionService.GetData(player): { cash, rep, rank, rankIndex, gear: { [string]: number } }`
- `ProgressionService.CanUseVehicle(player, vehicleId): boolean`
- `ProgressionService.GetGearBonus(player, stat: "speed" | "pullTime" | "searchRadius"): number` is a multiplier, 1 by default.
- `DataService` (RP-D1): `Get(player)`, `MarkDirty(player)`, `Save(player, release?, deadline?): boolean`, `OnLoaded(fn)`. `CommitReceipt(player, purchaseId, grantFn(data) -> boolean?): boolean` is the idempotent receipt ledger: it grants at most once per id, rolls back when grantFn errors or returns false, and returns true only after the grant and its ledger entry are saved in one write (true = `PurchaseGranted`, false = `NotProcessedYet`). grantFn must not yield. `HasReceipt(player, id)`, `OnDataStoreError(fn(op, key, err))` (the DataStoreErrors metric hook) and `GetDataStoreErrorCounts()`. The record is `{ version, data, receipts, session }` with migrations in `DataService.Logic.MIGRATIONS`. If another server takes the session lock or a newer record version is found, the player is kicked. Tests: `tests/Data.spec.luau`.
- `CrewService.GetCrew(player): { Player }`
- `CrewService.RecordRoleAction(player, callId)` and `CrewService.HasRoleAction(player, callId): boolean`
- `DogService` keeps Bosun beside each player: the uploaded rigid `M_Chr_Bosun` (by name via AssetLoader, LOD0-2, greybox placeholder until it loads) on an invisible root `Body`, rigged with Motor6Ds Root / Neck / Hips / Ruff that `DogController` drives locally (`Shared.Dog.BosunMotion`); model attributes `Mode` (Follow / Wait / Ride / Swim), `Wetness`, `Wet` (wet SurfaceAppearances via `AssetLoader.setWet`, `Shared.Dog.BosunWetness`). ATT_Mouth rides on BodyHead, ATT_HarnessHandle / ATT_TowRing on Harness. It fires `DogPoint` toward the closest victim from `CallService.GetVictimPositions`.

### A: OceanController (client)

- Draws the mesh ocean from `Weather.getWaveParams`. Its height matches `Waves.heightAt` exactly at the grid vertices.
- `OceanController.GetVisualHeight(x, z): number` is for snapping remote hulls on screen.

## Operations v2

Design: [docs/09-rescue-operations.md](docs/09-rescue-operations.md). An operation is a data-driven chain of steps; the server runs the state machine and grades; the client plays one **mechanic** per step.

### Shared data (`src/shared/Ops/`, pure, Lune-tested in `tests/Ops.spec.luau`)

- `Types.luau`: `Grade` (`"Gold"|"Silver"|"Bronze"|"Fail"`), `Role` (`Helm|Navigator|Crew|Medic`), `GradeBand { metric, gold, silver, bronze, higherIsBetter? }`, `StepDef { id, label, realTerm, role, mechanicId, mechanicByState?, gradeBands, weight, timeoutSec, onFail, npcAllowed?, npcSeconds?, minSeconds?, serverMetrics?, allowedEvents?, when?, perCasualty?, shared?, effect?, tip? }`, `OperationDef`, `CasualtyState`, `StepResult`, `Types.Rules` (NPC x1.4 slower, NPC and stub Silver cap, 3 attempts).
- `Definitions/PersonInWater|DisabledVessel|CapsizedFerry.luau`: the step tables of docs 09 sections 5.1, 6 and 7 as data.
- `Operations.luau`: registry `Defs`, `get`, `plan(def, casualtyState)` (drops `when` steps), `mechanicFor(step, state)`, `RecoveryMethod`, `triageTag`, `FromCallKind` (Swimmer/DriftingCraft -> PersonInWater, Tow -> DisabledVessel).
- `Condition.luau`: the 0-100 meter (docs 09 2.2): `new`, `rate(c, env{storm, coldWater})`, `step(c, dt, env)`, `applyEvent(c, "wash"|"slam"|"wrongHandling"|"harmfulTreatment", n)`, `band`, `label`, `isCritical`, `shouldTakeover(casualties, elapsed, cap)`, `secondsToCritical`. Vessels use it as the drift clock (stops when `towed`).
- `Grading.luau`: `stepGrade(step, metrics, only?)` (worst band; a missing metric grades Bronze), `resolveStep(step, metrics, {npc, stub})`, `operationGrade` (weighted average >= 2.5 Gold, >= 1.7 Silver), `conditionGrade`, `payout(weight, grade, humanCrew, tutorialIndex)` (550 Cash / 135 Rep base, docs 03 section 2), `takeoverPayout`, `shareWithoutStep`, `bigCasualtyPay`, `bigCompletionBonus`, `weakest`.
- `Remotes.luau`: the `Ops_*` remotes (below).

### Mechanic interface (client)

A mechanic is `src/client/Mechanics/<mechanicId>.luau` returning `{ start: (ctx, finish) -> (() -> ())? }`. `OpsController` requires it lazily when the server starts a step with that id; when the file is missing (or fails to load) it uses `Mechanics/Default.luau` (a "Step: <label> [Complete]" card that returns a stub result). `start` must not yield for long; call `finish(result)` exactly once; return a cleanup function, which OpsController calls if the server moves on (takeover, timeout, an NPC took it).

`ctx` (the `Ops_StepStart` payload):

| Field | Contents |
|---|---|
| `operation` | `{ id, kind, title, position, zoneName, storm, isBig }` |
| `step` | `{ key, id, label, realTerm, role, mechanicId, npc, assignee, timeoutAt, npcDoneAt?, trackId, casualtyIndex? }` |
| `casualty` | `{ index, id, state, condition, band, label, lifejacket, inWater, surveyed, treated, delivered, takenOver, tag?, position }` or nil |
| `vehicle` | the player's boat Model, or nil |
| `role` | the step's role |
| `isAssist` | true unless the player's `OpsPro` attribute is true (show hints, wider windows) |
| `attempt` | 1, 2, 3 (retries) |
| `scene` | `{ windDirection, targets: { Vector3 } }` |

`result` = `{ metrics: { [string]: number | boolean }, events: { [name]: count }?, failed: boolean?, stub: boolean?, grade: Grade? }`. Strings in `metrics` are dropped, except `method` (recovery), `tag` (triage, "Red"/"Yellow"/"Green") and the number `pob`, which the server turns into `rightMethod`, `tagRight`, `pobRight`. `grade` is advisory only.

Metrics each mechanic returns (the band metric names in the definitions; lower is better unless marked +):

| mechanicId | Metrics | Events allowed |
|---|---|---|
| `radio_ack` | none (server measures `elapsed`) | |
| `kit_launch` | `kitFit`+ (0..1) | |
| `passage` | `routeRatio` (time / best), `etaError` (fraction) | |
| `search` | `startError` (studs), `lostSight` (count) | |
| `approach` | `overSpeedSec`, `neutralDistance` (studs), `fromDownwind`+ (bool) | `wash` <= 2 |
| `panic_calm` | `calmSeconds`, `grabbed` (count) | |
| `recover_throwbag`, `recover_swimmer` | `method` ("throwbag"/"swimmer"/"horizontal"), `score`+ (0..1) | `wrongHandling` <= 1, ferry pick-up also `wash` |
| `primary_survey` | `correct`+ (fraction right) | |
| `treat` | `matches`+ (0..1), `harmful` (count) | `harmfulTreatment` <= 2, `wrongHandling` <= 1 |
| `transport` | none (server: `conditionAtEnd`; ferry also `priorityOrder`) | `slam` <= 6 |
| `handover` | `correct`+ (cards right of 6) | |
| `assess_vessel` | `ringHeld`+, `questions`+ (fractions), `pob` (number), `hazardSpotted`+ | |
| `heaving_line` | `throws` (count), `hitPerson` (count) | |
| `rig_bridle` | `slackNearStern` (count), `strongPoint`+, `lengthOk`+ | |
| `take_strain` | `peakTension` (0..1+, 1 = red) | |
| `tow` | `amberFraction`, `redEvents` (count), `inStep`+ (fraction) | |
| `alongside`, `berth` | `contactSpeed`, `fendersRight`+, `lineOrderRight`+ / `lineInWater` | |
| `radio_closeout` | `pob` (number) | |
| `scene_command` | `reportCorrect`+, `tasksCovered`+ (fractions) | |
| `triage` | `tag` (string) | |
| `hull_knock` | `rightCompartment`+ | |
| `air_pocket` | `rescued`+ (count), `signalMistakes` (count) | |
| `standby_assist` | `steady`+ (0..1) | |

### Server: `OperationService`

- Offers: the first-call chain, storm rate and offer timing come from `CallLogic`; the Capsized Ferry starts with the storm (`/ferry` in Studio). `/op` and `/tow` start one in Studio.
- Per operation: casualties are rolled from the definition (`states`, `lifejacketChance`); a **track** runs the plan (a normal op has one track: the crew; on the ferry every joining crew gets a track, `shared` steps are done once, `perCasualty` steps loop per claimed casualty).
- Roles: the owner is Helm (alone in a boat also Navigator; alone on the jet ski every role); crewmates take Navigator, Crew, Medic in join order. An empty seat is an **NPC**: the step takes `npcSeconds` x 1.4 and grades Silver, with no credit. `npcAllowed = false` steps (search, approach, recovery, assessment) always go to a human. `Ops_TakeStep` swaps a human into an NPC's step.
- Validation: only the assignee's result for the current step key counts; results faster than `minSeconds` (0.5 s) are rejected and the step restarts; metrics are sanitised (numbers and booleans, clamped, <= 24); `serverMetrics` (`elapsed`, `conditionAtEnd`, `priorityOrder`) and the derived `rightMethod`/`tagRight`/`pobRight` are always the server's; events are capped by `allowedEvents`. The grade is recomputed with `Grading.resolveStep`; stub results are graded on the server metrics they have, capped at Silver.
- `onFail` on timeout or `failed = true`: `retry` (3 attempts, then NPC or skip), `npc`, `skip` (Fail, 0 points), `takeover`, `continue` (Bronze).
- Condition ticks every 0.25 s; at Critical or past `capSeconds` the takeover starts: the radio line, every casualty safe, then a `standby_assist` step; pay is `Grading.takeoverPayout`. Ferry: a Critical casualty is lifted by *Rescue Gale One* and drops out of the pool.
- Effects on success: `board` (RescueService.BoardVictim), `calm`, `survey`, `treat`, `tow` (RescueService.AttachTowFor), `triage`, `deliver` (ferry: RescueService.RemoveVictim and the per-casualty pay). A boat reaching a pad with the casualty (RescueService.OnVictimsDelivered) completes the current `deliver` step with server metrics.
- Pay: `CrewService.RecordRoleAction(player, opId)` for every step a player completes; at the debrief one `ProgressionService.Award` per player (`Op:<kind>`), crew without a step get the 10% share. Storm multipliers stay in ProgressionService (known gap: it applies the weather at award time, not at tasking).
- API: `GetActiveOperations(): { OperationInfo }`, `GetOperationOf(player)`, `GetVictimPositions(player)`, `OperationCompleted` (signal `(info, helpers)`), `ForceBigCall()`, `DevStart(player, kind?)`, `StartColdOpen(player, spawnCFrame?)`; `OperationInfo = { id, kind, position, zoneId, expiresAt, assignedTo, isBig, grade? }`. RescueService hooks (`CanAct`, `Notify`, `OnVictimsDelivered`, ...) are internal.
- **Cold open** (first session, design change 2026-10): `StartColdOpen` asks `VehicleService.SpawnColdOpen(player, cframe): Model?` (CONTRACT for stream B: spawn a jet ski at the CFrame, seat the player, give it forward speed; called in pcall) and starts a PersonInWater 150-250 studs ahead with plan tasking (auto-done, Gold) -> approach -> recovery, Assist on, condition drift x0.5. It is offered automatically to a new player instead of the first tasking once `VehicleService.SpawnColdOpen` exists. `ColdOpenDone` is a player attribute for now; CONTRACT for stream E: persist `coldOpenDone` in the profile, return it from `ProgressionService.GetData`, and add `ProgressionService.SetFlag(player, name, value)`.
- Studio: `ServerStorage.OpsDev` (BindableFunction): `Invoke("timescale", x)`, `("start", kind)`, `("coldopen")`, `("status")`. `python3 tools/studio/smoke.py ops` plays PIW, DisabledVessel and the cold open end to end with the stubs (`OpsAutoStub` attribute).

### PIW server (integration pass A, DONE)

- Scripted victim drift in RescueService (per-call current plus wind, fading ~240 studs from the start) with a wake push from nearby boats via `Wake.pushAt` (cap 12 studs/s).
- `onPattern` (expanding square from the casualty's real position at search start, first leg into the wind) and `destinationRight` (the pad actually reached; a helicopter case must go to `Dock`) are serverMetrics, maths in `src/server/Ops/PiwMetrics.luau`.
- Transport vs pad race: whichever arrives first completes the step; the late client result gets an accepted ack with the pad's grade, no double pay or advance. `OnVictimsDelivered` now also gets the pad name.
- PIW tasking step has a `format` band (Gold 1, Silver 0.6, Bronze 0); PIW has no `radio_closeout`. `tests/Ops.spec.luau` caps test updated.

### Remotes (`src/shared/Ops/Remotes.luau`, under `ReplicatedStorage.Net`)

| Remote | Dir | Payload |
|---|---|---|
| `Ops_Offered` | S->C | `{ opId, kind, title, radioLine, zoneName, position, isBig, offerExpiresAt, cash, rep }` |
| `Ops_Accept` | C->S | `(opId)`; big call: join with your crew |
| `Ops_State` | S->C | snapshot `{ opId, kind, title, isBig, state, zoneName, position, startedAt, capAt, storm, takeover?, myTrack, myRoles, plan[{id,label,realTerm,role}], results[{stepId,grade,by,trackId}], current[step views], casualties[casualty views], saved, total }`, about once a second and on every change |
| `Ops_StepStart` | S->C | the mechanic `ctx` |
| `Ops_StepResult` | C->S | `(opId, stepKey, result)` |
| `Ops_StepAck` | S->C | `{ opId, stepKey, accepted, grade?, reason? }` (`NotCurrent`, `NotYours`, `TooFast`, `Timeout`, `Failed`) |
| `Ops_TakeStep` | C->S | `(opId, stepKey)` swap station |
| `Ops_Radio` | S->C | `{ opId, from, text }` |
| `Ops_Debrief` | S->C | `{ opId, kind, title, grade, stepGrade, reason, takeover?, steps[{id,label,realTerm,grade,weight,by,userId,at}], condition[{t, c[]}], saved, total, cash, rep, tip?, me }` |
| `Ops_Closed` | S->C | `{ opId, reason, message?, silent? }` |
| `Ops_TowLength` | C->S | `(opId, studs)` |
| `Ops_Board` | S->C | `{ opId, osc, npc, assigned, tasksCovered, reportCorrect, board? }` |

### Client: `OpsController`

Discovers mechanics and plays them; draws a greybox offer card, an operation strip and a debrief. API: `OnOffer`, `OnState`, `OnDebrief`, `OnRadio`, `OnClosed` (signals), `Accept(opId)`, `TakeStep(key)`, `GetState()`, `GetMechanic(id)`, and `UseBuiltInUi` (set false when the real UI takes over).

### File ownership for the next parallel streams

Each stream owns only its files; the framework files above stay with the Ops framework owner. A stream that needs a new metric adds it to its own mechanic and asks the owner to add the band to the definition (or edits only its own steps' `gradeBands` in `src/shared/Ops/Definitions/*`, keeping `tests/Ops.spec.luau` green).

| Stream | Owns |
|---|---|
| (a) PIW mechanics | `src/client/Mechanics/{kit_launch,passage,search,approach,panic_calm,recover_throwbag,recover_swimmer,primary_survey,treat,transport,handover,standby_assist}.luau`, `src/client/Mechanics/PIW/*` (helpers), `tests/MechPIW*.spec.luau`; tuning of the PersonInWater definition's bands |
| (b) Tow mechanics | `src/client/Mechanics/{assess_vessel,heaving_line,rig_bridle,take_strain,tow,alongside,berth}.luau`, `src/client/Mechanics/Tow/*`, `tests/MechTow*.spec.luau`; DisabledVessel bands |
| (c) Ferry and triage | `src/client/Mechanics/{scene_command,triage,hull_knock,air_pocket}.luau`, `src/client/Mechanics/Ferry/*`, `tests/MechFerry*.spec.luau`; CapsizedFerry bands |
| (d) Radio wheel, tasking card, debrief UI | `src/client/Mechanics/{radio_ack,radio_closeout}.luau`, `src/client/Controllers/RadioController.luau`, `src/client/UI/Ops*.luau` (tasking card, step card, condition bar, debrief), `src/client/UI/Radio*.luau`; consumes the OpsController signals and sets `UseBuiltInUi = false` |

**Stream (b) tow notes.** `src/shared/Tow/TowLine.luau` (pure, tested in `tests/MechTow.spec.luau`) is the tow physics: an elastic nylon spring-damper line (snatch loads, parts on a spike >= 1.15 or red held 1 s), the towed hull (resistance rising past hull speed, keel, leeway, wave-face surfing, a bow tow point that sheers without a bridle), the step-out length (`recommendedLength`, `inStep`) and the line sag. The towing client runs it in `Mechanics/Tow/Kit` (`Kit.link`): the rope's sag, drips and creak, a `TowLoad` VectorForce on the tug, and the casualty hull drawn at the simulated pose on that client only. Other clients and the server still see RescueService's kinematic leash. DONE (integration pass A): `src/server/Tow/TowMotion.luau` now drives the server `stepTow` (75-stud default); `Ops_TowLength` C->S `(opId, studs)` is live (members only, clamped 30..150, sent by `Kit.setLength`); a parted line calls `OperationService.OnTowParted` (radio, drift restarts, grades from heaving_line on are dropped and heaving_line re-runs); alongside/berth lash the casualty to the tug's starboard side; each tow rolls 1-4 POB, the tasking/radio say it, the boat is built with that many people and `pobRight` checks `op.pob` (the single casualty stays the drift clock). Still open: the client and server lines simulate separately and may disagree on parting; `decisionRight`/`lineOrderRight` have no bands. Original asks: an `Ops_TowLength` C->S remote `(opId, studs)` so the server rope follows the tow length the Crew sets; a server path for a parted line (the client re-passes it now); an alongside mode (the casualty lashed beside the tug instead of trailing it); and a POB per vessel (the radio line says "two aboard", but the server expects `pob = #op.casualties` = 1 and builds one person). `assess_vessel` reports the people it sees aboard. `assess_vessel` also returns `decisionRight` and `berth` returns `lineOrderRight` (no bands yet).

### Ferry mechanics (stream c)

- Pure helpers in `src/shared/Ferry/` (`Triage`, `SceneBoard`, `HullKnock`, `Dive`), tested in `tests/MechFerry*.spec.luau`; client UI helpers in `src/client/Mechanics/Ferry/FerryUi.luau`.
- Extra advisory metrics: `triage` also sends `checks`, `orderFollowed`, `countError`; `hull_knock` sends `compartment` (number), `knocks`, `listens`; `air_pocket` sends `airLeft`, `takeover`; `scene_command` sends `assigned`.
- DONE (integration pass A): all four proposals below are wired. `FerryValidate.apply` runs after serverMetrics on ferry ops; `driftFactor` scales a tagged waiting casualty's decline; `scene_command` goes to a Helm with player attribute `CertCoxswain` or `CertHelm` (Studio bypasses), else the NPC officer; `Ops_Board` S->C `{ opId, osc, npc, assigned, tasksCovered, reportCorrect, board? }` goes to every crew on the op and is also in `Ops_State.board`, shown by `src/client/Mechanics/Ferry/BoardView.luau`. Open: `scene_command.luau` should also send `result.board` (unit -> task id) so a human OSC's board shows names; stream E should grant the Cert attributes.
- `src/server/Ferry/FerryValidate.luau`. Proposals for the Ops framework owner: (1) call `FerryValidate.apply(op.id, inst.def.id, metrics)` in `serverMetrics`, so `rightCompartment` is recomputed from `compartment` with `HullKnock.pocketCompartment(opId)` (the client uses the same function) and `rescued`/`signalMistakes`/fractions are clamped; (2) multiply a waiting ferry casualty's condition decline by `FerryValidate.driftFactor(c.tag, c.state)` (an under-triaged casualty declines faster); (3) give `scene_command` to the first Helm with a Coxswain/Helm certification on scene, else the NPC officer; (4) an `Ops_Board` S->C broadcast of the OSC's assignments so every crew sees the scene board.
- Certification (stream E): `air_pocket` reads the player attribute `CertRescueSwimmer`; without it the player dives as a trainee with NPC Senior Diver Mara Quinn.
- Wind convention used: `WindDirection` is the direction the wind blows toward; downwind = `(cos a, 0, sin a)`.

## Gate

Each stream runs `~/RobloxProjects/tools/check.sh ~/RobloxProjects/MaydaySeaRescue` and `~/RobloxProjects/tools/build.sh ~/RobloxProjects/MaydaySeaRescue`, piped through `tail`, and fixes errors in its own files. If another stream's errors appear, report them; don't fix them. No Studio, and no commits.

## Land vehicles

Design: docs 10 section 3, speeds docs 02 section 4.3. Owner: `src/shared/Car/*`, `src/shared/Config/LandVehicleConfig.luau`, `src/server/Services/LandVehicleService.luau`, `src/client/Controllers/CarController.luau`, `tests/Car*.spec.luau`.

- **Chassis** (`src/shared/Car/`, pure, Lune-tested): `Chassis` (prepare a real-world spec into studs/RMU, `step` per-wheel spring, anti-roll and tyre forces), `Tyre` (surface grip table, wet via `Weather.getIntensity`, magic-formula slip curves, friction ellipse, ABS/TC), `Suspension`, `Drivetrain` (torque curve, converter, six-speed auto, low range, engine braking), `LightBar` (patterns), `Trailer` (launch rule). `Physics` applies them in Roblox (raycasts, `CarForce`/`CarTorque` on the `Chassis` root); `Builder` makes greybox bodies at real dimensions.
- **Vehicles** (`LandVehicleConfig`): `LifeguardPickup` (Recruit), `BeachATV` (Lifeguard), `CoastguardResponse` (Rescue Swimmer, optional `BoatTrailer` carrying a RIB or jet ski), `Ambulance` (parked handover point, tag `AmbulanceHandover`, attribute `HandoverPoint`, attachment `HandoverPoint`).
- **Models** in `Workspace.LandVehicles`, tag `LandVehicle`, collision group `LandVehicle` (doesn't collide with itself). Attributes: `VehicleId`, `Owner`, `LandVehicle`, `CameraMode = "Chase"`, `CockpitView`, `Headlights`, `LightBar`, `Siren`, `Horn`, `CanLaunch`, `Towing`, `TrailerBoat`. `DriverSeat` (VehicleSeat, right-hand drive) holds `EyePoint`. A towing car has an ObjectValue `Trailer`.
- **Server API**: `LandVehicleService.GetVehicle(player)`, `GetTrailer(model)`, `GetDriver(model)`, `Spawn(player, vehicleId, pointId?, withTrailer?)`, `Despawn(player)`, `SetLightBar(model, on)`, `VehicleSpawned` (signal `(player, model)`).
- **Remotes** (under `ReplicatedStorage.Net`): `Land_Request` (RemoteFunction `(vehicleId, pointId?, withTrailer?) -> (ok, reason | Model)`), `Land_Control` (C->S `(action, value)`: `Horn`, `Siren`, `LightBar`, `Headlights`, `Launch`), `Land_Spawned` (S->C `(model)`).
- **Client**: `CarController.GetDriving()`, `CarController.Request(...)`. The player attribute `CarCockpit` (bool, V / R3) asks for the cockpit view.
- **Slipway launch**: once the trailer's `Cradle` is `LaunchDepth` under `Weather.heightAt` and the rig has stopped, `CanLaunch` turns true; `Launch` removes the boat greybox and calls `VehicleService.SpawnSeated(player, boatId, cframe, 0)` in pcall. Recovery onto the trailer is [L].
- DONE (integration pass A): ProgressionConfig.Vehicles has the three cars (`land = true`, `isLandVehicle` helper; Ambulance not drivable yet); LandVehicleService reads `WorldConfig.LandVehicleSpawns` with fallback (WorldConfig does NOT define that list yet: terrain stream, please add it); CameraController chase + cockpit (`CarCockpit`); characters are in collision group `Characters`, which doesn't collide with `LandVehicle` (boats stay Default); Siren/LightBar only during an active operation and switched off when it ends.
- (was) CONTRACT for **stream E**: add `LifeguardPickup` (rank 1), `BeachATV` (rank 2) and `CoastguardResponse` (rank 3), price 0, to `ProgressionConfig.Vehicles`. Until then `CanUseVehicle` answers "Unknown vehicle", and LandVehicleService falls back to `GetData().rankIndex` against the spec's `unlockRank`.
- CONTRACT for the **camera stream**: a chase camera for `CameraMode = "Chase"` land vehicles, plus a cockpit view at `DriverSeat.EyePoint` when `CarCockpit` is true.
- CONTRACT for the **terrain stream**: `WorldConfig.LandVehicleSpawns` (same shape as `LandVehicleConfig.SpawnPoints`) replaces the placeholder points marked TODO.
- Open: no character/vehicle collision group yet (docs 10 says pedestrians are never hit). Sounds are empty TODO constants. Siren and blue lights aren't gated to a tasking yet.

## World and store (integration pass A)

- `GameConfig.MapRadius` = 2500. `WorldService` hides `Workspace.Zones` and `Map.WorldPoints` parts at play time (Transparency 1, no collide/query/touch, adornments removed).
- No HUD shop or launch buttons. Port Haven Chandlery (`map/Build.luau`, `buildChandlery`, x -74..-14, z -78..-42, beside the station: the literal doc-10 offset lands on Harbour Road) has `ShopCounterPrompt` ("Browse gear") opening the counter panel (`HudShop`, BuyGear). The quay boat desk (`buildBoatDesk`) has `BoatDeskPrompt` ("Collect a boat") opening `HudLaunch` (RequestVehicle, rank locks, land vehicles hidden). Panels close with X or past 16 studs. Bay prompts unchanged.
- Hospital: no red cross anywhere (docs/05). It shows a white "H" on blue and a "COTTAGE HOSPITAL" board; first-aid kits will use a green and white cross.

## Map and blips (GTA-style map)

Owner: `src/client/Controllers/MapController.luau`, `src/server/Services/MapService.luau`, `src/shared/Config/MapConfig.luau`, `tools/world/make_map_image.py`, `art/map/*`, `tests/Map.spec.luau`.

- Map texture: `python3 tools/world/make_map_image.py` renders `art/map/gale_isles_map.png` (2048 px) and four 1024 px tiles from the terrain bake + WorldConfig roads; uploaded ids, the world-to-UV transform (`u = (x + 2560) / 5120`, `v = (z + 2560) / 5120`, north up), blips and zoom live in `MapConfig`. Re-render and re-upload after a terrain re-bake.
- Minimap bottom-left (rises above bottom-left panels it would cover), full map on M / gamepad Select / tapping the minimap or the MAP button. Hidden while `CinematicPlaying`; its ScreenGui `MapHud` carries `CinematicKeep`.
- **`ReplicatedStorage` attribute `UseMapWaypoints` (bool, MapService sets true)**: while true, do not draw 3D guidance arrows, beams, waypoint parts or billboards toward casualties / drop-offs; the map shows them. Done: DogController's Bosun arrow (the bark and head turn stay); drop-off pads `Map.DropOffs` are hidden locally (LocalTransparencyModifier). CONTRACT for the owners: RescueService / CasualtyAsset / Casualty / Boat Builder / Camera, check the flag before adding any new guidance marker.
- Player attributes: `MapWaypoint` (Vector3?, the player's own waypoint), `MapOpen` (bool). API: `MapController.SetWaypoint`, `GetWaypoint`, `GetObjective`, `Open`, `Close`, `IsOpen`.
- CONTRACT (storm stream): `ReplicatedStorage.Weather` attributes `StormCenter` (Vector3) + `StormRadius` (number) replace the placeholder open-sea storm area in `MapConfig.StormAreas`.
- CONTRACT (Ops framework): the objective comes from `Ops_State` (`casualties[].position/inWater/delivered`, `current[1].mechanicId`); a `destination` field (`"Dock"`/`"Hospital"`) on the transport step view would let the map point at the chosen pad instead of the nearest one.
