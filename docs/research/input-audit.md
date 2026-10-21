# Input audit (G3, RP-C2)

Static audit of every player input path in `src/client/**`, against docs/14 F-2 and docs/09 §2.7:
each action must be reachable with keyboard + mouse, gamepad, and touch. A gap is anything with
only one device path, and a mouse-only click is a bug.

Legend: `fixed` marks a gap closed in this pass.

## Core / HUD

| Action | Keyboard | Gamepad | Touch | Fixed? |
|---|---|---|---|---|
| Look (on foot, helm, chase) | mouse (first person), RMB drag (chase) | right stick | drag anywhere | |
| Walk / jump / climb | WASD, Space | left stick, A | Roblox mobile thumbstick / jump | |
| Drive boat (throttle, steer) | W/S/A/D (VehicleSeat) | left stick, RT/LT | Roblox mobile thumbstick | |
| Boat neutral (out of gear) | release throttle | release RT/LT | release thumbstick | |
| Boat approach mode | Z | Y | on-screen "Approach" | |
| Helm view | V | R3 | on-screen "Helm" | |
| Dive / surface | C | B | on-screen "DIVE" | |
| Whistle (owned) | Y | D-pad up | on-screen "Whistle" | |
| Car throttle / brake / steer | W/S/A/D | left stick, RT/LT | mobile thumbstick | |
| Car handbrake / horn / lights / blues / low range / launch / view | Space/H/J/K/L/B/V | X/L3/D-pad up/right/down/Y/R3 | CAS buttons (all 7) | |
| Phone open / close | P | L1 | HUD phone button | |
| Phone apps | click | D-pad + A (focus set on open) | tap | |
| Settings open / close | gear click | Start, B | gear tap, shade tap | |
| Settings values | drag, −/+ click | D-pad + A on −/+ | drag, tap | |
| Settings list scroll | wheel / drag | D-pad (auto-scroll) | drag | |
| Logbook open / close | J | L3, B | LOG button, tap X | |
| Logbook pages / duty switch | click (mouse freed) | D-pad + A | tap | fixed (Modal) |
| Map open / close | M, Esc | Select, B | MAP button; pad drag | |
| Map pan / zoom / waypoint | drag, wheel, click | stick, triggers, A | drag, pinch, tap | |
| Shop counter open | E (prompt) | X (prompt) | tap prompt | |
| Shop counter rows / close | click (mouse freed) | D-pad + A, B | tap, walk away | fixed (Modal) |
| Boat desk open / rows / close | E, click (mouse freed) | X, D-pad + A, B | tap prompt, tap, walk away | fixed (Modal) |
| Product card open / close | E/F prompt, click, walk away | X/Y prompt, B | tap prompt, tap, walk away | fixed (Modal) |
| Product card pages / buy / launch | click (mouse freed), LB/RB | LB/RB, D-pad + A | tap | fixed (Modal) |
| Exercise board open / start / close | E prompt, click (mouse freed), Esc | X prompt, D-pad + A, B | tap prompt, tap | fixed (Modal) |
| Tasking pager accept | Enter (click needs a free cursor) | D-pad left | tap ACCEPT/JOIN | |
| Step card "Take it" | T | D-pad left | tap | |
| Debrief close | click (mouse freed) | B | tap | fixed (Modal) |
| Cinematic skip | Space | B | Skip button | glyph fixed |
| Radio push-to-talk | hold R | hold D-pad up | hold on-screen "Radio" | |
| Radio repeat last | phone Radio app | phone D-pad + A | tap Radio app | |

## Mechanics

| Action | Keyboard | Gamepad | Touch | Fixed? |
|---|---|---|---|---|
| Kit grab / stow | E prompt | X prompt | tap prompt | |
| Place search start | LMB at reticle | A at reticle | tap the water | |
| Keep eyes on / sighting | look (mouse) | right stick | drag / finger | |
| Throw bag aim / charge (PIW) | hold RMB | hold LT | hold "Throw" | |
| Grab / drag casualty | E | X | tap "Grab" | |
| Swimmer move | WASD | left stick | on-screen arrows | |
| Swimmer talk | T | X | tap "Talk" | |
| Present tube | hold LMB | hold A / RT | hold "Tube" | |
| Flick away | S | stick down | tap "Away" | |
| Two-hand rhythm (haul, tow, pay out) | LMB / RMB | LB / RB | two pads | |
| Hold action (throw / lift) | LMB | A / RT | hold "Action"/"Lift" | |
| Horizontal-lift level | A / D | left stick | drag while holding | |
| Primary survey breaths | Space / LMB | LB / RB | tap "Rise" | |
| CPR compressions / breath | LMB / RMB, Space | LB / RB, Y | pads, "Breath" | |
| Treat hold | E prompt | X prompt | hold prompt | |
| Triage sieve hold | E | X | hold button | |
| Triage breath count | Space | A | tap "Rise" | |
| Hull knock / mark / slide | LMB, F, A/D | A, X, D-pad | Knock, Mark, arrows | |
| Air-pocket pull / hold | Space, E | A, X | Pull, hold button | |
| Air-pocket reticle | mouse | either stick | drag | |
| Heaving line throw | hold LMB | hold A | hold CAS "Throw" | |
| Pay out / haul in (tow rig, alongside) | LMB / RMB | LB / RB | CAS Left / Right | |
| Tow length out / in | E / Q | D-pad right / left | CAS Longer / Shorter | |
| Berth, passage, transport | drive | drive | drive | |
| Handover, standby, scene command | walk / look / automatic | stick / automatic | drag / automatic | |
| Fallback stub step complete | click (mouse freed) | A (focus set) | tap Complete | fixed |

## Notes

- Panels opened on foot were the real mouse lockout: the camera is `LockFirstPerson`, so a panel
  with no `Modal` button could not be clicked. `InputGlyph.modal` now sets `Modal` on its first
  button (shop, boat desk, debrief); the logbook, product card and exercise board set it on their
  close button. Touch and gamepad already worked.
- Glyphs now follow the last device in the cinematic Skip label and the PIW throw/grab chips.
- Capsized Ferry triage card scaled with `Layout` so the 420 du card fits a 390 px landscape phone;
  the air-pocket assist hint was placed off the right edge (negative width) and is now centred.
- Tasking ACCEPT and "Take it" keep a direct key/pad binding rather than freeing the mouse during
  play; a mouse player uses Enter / T. `CallCard` is not mounted anywhere (superseded by
  `OpsTaskingCard`).

No open gaps: every row above has a keyboard/mouse, gamepad and touch path.

## 2026-10-20 phone/tablet pass (G41)

Device simulator (`StudioDeviceSimulatorService`): iPhone 7 landscape 666x374 (usable 666x316,
`Layout` scale 0.70) and iPad 6th generation landscape 1023x767 (scale 0.85). Sizes below are
final pixels (design units x scale). Only the pieces in this pass changed.

| piece | phone | tablet | fix |
|---|---|---|---|
| StreakController / StreakCrate sign | n/a world sign; time 34 px on a 3.6x1.5 stud board | n/a world | none |
| StockController price tags | n/a world tag; name 20 px, price 22 px | n/a world | none |
| SeasonBook (desk + phone app) | fits 546x270; text 14 px; close/claim 44 px | fits 780x386; text 17 px; buttons 54 px | 20 du body text; 63 du close/claim; track below the close |
| AlbumBoard | n/a world print (11-14 px labels) | n/a world | none |
| ChallengeTracker | 20 du text = 14 px; sits above the minimap | 17 px | 16 -> 20 du text; 24 du rows |
| ChallengeBoard | n/a world print (16-18 px rows) | n/a world | none |
| PhotoMode touch sticks | stick 90 px; keys 44-59 px; labels 14 px | keys 54 px | 63 du close/pose/grade; 20 du labels; hide Roblox touch controls while the lens is up |
| FriendController (+% chip, flare) | chip 14 px; flare 44 px in the minimap's top-left | chip 17 px; flare 54 px | chip 12 -> 20 du; flare 52x44 -> 63x63, moved off the MAP corner; DisplayOrder 17 |
| PetController | n/a world prompt (Roblox default touch target) | n/a world | none |
| StationCrew strongbox meter | n/a world board; 20-22 px text, 14 px meter | n/a world | none |
| HalloweenWorld stall | n/a world board; 16-52 px text | n/a world | none |
| RankCeremonyController badge | badge 128 px; name 26 px; unlock row 270 px wide | badge 191 px | none |
| CashBurst | coins now land on the Cash label; +number 34 px | same | target the live Cash label instead of a fixed viewport offset |
| Phone home (7 icons + invite) | 3 columns, 63 du = 44 px cells, 410 du tall (299 px + margin) | same cells, 54 px | 440 -> 410 du; 2 -> 3 columns; invite pill keeps its 42x28 look inside a 63x63 target; home bar 63 du |

Measured at 0.70: no visible text under 14 px and no visible `GuiButton` under 44 px in the
HUD tracker, FriendHud and PhotoMode after the fixes; SeasonBook's 20 du text and 63 du buttons
give the same 14 px / 44 px floors. The minimap itself still sits
in the thumbstick's touch zone (the MAP corner stays clear); moving it above the stick collides
with the objective/call card on short phones, so it was left for a layout decision.

Not captured (the scripted camera missed the world boards, and the phone/Season opens in the last
session were hidden by earlier settings/photo overlays): the open Phone home, SeasonBook on the
phone, and the world pieces above. Static sizes and the HUD/photo shots support the rows, but
these need one more Studio pass. The gamepad focus check was also inconclusive: the test opened
the phone with a mouse, which clears `GuiService.SelectedObject`; a pad-only run is needed.

## Bindings 2026-10-20 (G65)

Full keyboard / gamepad map from `src/client/**` (touch paths omitted; every row also has a tap,
prompt or CAS button). "Context" is when the binding is live. Read this against docs/14 F-2:
keyboard and pad both reach every action.

| Key | Gamepad | Context | Owner |
|---|---|---|---|
| W A S D, Space | Thumbstick1, ButtonA | on foot walk / jump (Roblox core) | Roblox character controls |
| W A S D | Thumbstick1; R2 / L2 | throttle / steer, seated | BoatController, CarController (VehicleSeat) |
| mouse | Thumbstick2 | look | CameraController |
| V | ButtonR3 | helm view, boat or jet ski | CameraController:164 |
| Z | ButtonY | approach mode, driving a boat or jet ski | BoatController:253 |
| V | ButtonR3 | car view, driving a car | CarController:195 |
| Space | ButtonX | car handbrake | CarController:189 |
| H | ButtonL3 | car horn | CarController:190 |
| J | DPadUp | car lights | CarController:191 |
| K | DPadRight | car blues | CarController:192 |
| L | DPadDown | car low range | CarController:193 |
| B | ButtonY | car launch | CarController:194 |
| H | ButtonL3 | cosmetic horn, seated | Cosmetics/Horns.luau:148 |
| G | DPadDown (boats), none (cars) | siren, seated | Cosmetics/Sirens.luau:113,128 |
| L | DPadLeft | light bar, boat or jet ski | Cosmetics/LightBars.luau:169 |
| N | DPadRight | radio next track, seated | Cosmetics/ShantyRadio.luau:71 |
| Period | none | radio next while it plays | Cosmetics/ShantyRadio.luau:83 |
| Y | DPadUp | whistle, CaptainsLocker owners | Cosmetics/Whistle.luau:122 |
| C | ButtonB | dive, swimming | SwimController:172 |
| M | ButtonSelect | map open / close | MapController:1287 |
| Esc, Backspace | none | map close while open | MapController:1294 |
| none | Thumbstick1, A, B, X, Y, R2, L2 | full-map pan / zoom / point / legend / close | MapController:1199 |
| P | ButtonL1 | phone open / close | Phone.luau:522 |
| none | ButtonB | phone back while open | Phone.luau:275 |
| none | ButtonStart | settings open / close | SettingsPanel:753 |
| none | ButtonB | settings back | SettingsPanel:696 |
| J | ButtonL3 | logbook open / close (not while seated) | ExplorationController:82 |
| none | ButtonB | logbook close | ExplorationController:82 |
| Esc | none | Season Logbook close | SeasonController:75 |
| Esc | ButtonB | exercise board close | ExerciseBoardController:179 |
| **I** | **ButtonR1** | next-goal 3-goal view, chip shown | NextGoalController:332 |
| **U** | ButtonY hold | crew-up flare, active operation | FriendController:247,338 |
| Space | ButtonB | cinematic skip | Camera/Cinematic.luau:134 |
| any input | none | rank ceremony skip | RankCeremonyController:235 |
| none | ButtonB | close any open modal (logbook, product card, debrief, phone, settings) | InputGlyph.modal:111 |
| T | DPadLeft | step card "Take it" | OpsStepCard:183 |
| R hold | DPadUp hold | radio PTT while a step arms it | RadioController:539 |
| Return | DPadLeft | tasking pager accept | OpsTaskingCard:19 |
| Return, Space | ButtonA | debrief continue | OpsDebrief:556 |
| E | ButtonX | interact prompts: shops, desks, boards, pets, strongbox, seasonal stalls, VIP ladder, cliff haul, ferry, wildlife | StockController:342, StationCrew:158, StreakCrate:201, HalloweenWorld:575, WinterWorld:577,795, VipDeckAccess:25, FerryUi:399, free_wildlife:99, HudController:246 |
| F | ButtonY | shop product-card prompt | ProductCard:657 |
| none | ButtonL1 / ButtonR1 | product-card pages | ProductCard:483 |
| none | ButtonB | product-card close | ProductCard:482 |
| O (R2 on foot) | ButtonR2 | photo mode open / close | PhotoMode:833 |
| W A S D, Space, LShift, Q, E, M | DPadLeft / Right, either stick | photo mode move / tilt | PhotoMode:318 |
| none | ButtonR1 / L1 / R2 / L2 | photo mode zoom | PhotoMode:335 |
| F | ButtonA | photo shutter | PhotoMode:345 |
| P | ButtonX | photo pose | PhotoMode:353 |
| G | ButtonY | photo grade | PhotoMode:361 |
| O | ButtonB | photo mode close | PhotoMode:779 |
| LMB | ButtonA | place search start (reticle) | search.luau:140 |
| LMB | ButtonA / ButtonR2 | hold action: present tube, lift, throw, spray, free wildlife | PIW/Ui.luau:349 |
| LMB / RMB | ButtonL1 / R1 | two-hand pull (rig bridle, alongside) | rig_bridle.luau:130, alongside.luau:133 |
| H | ButtonL3 | assess-vessel horn | assess_vessel.luau:117 |
| LMB hold | ButtonA hold | heaving line throw | heaving_line.luau:188 |
| E / Q | DPadRight / Left | tow longer / shorter | tow.luau:98 |
| Space | ButtonA | air-pocket pull | air_pocket.luau:401 |
| LMB | ButtonA | hull knock | hull_knock.luau:242 |
| F | ButtonX | hull knock mark | hull_knock.luau:251 |
| A / D | DPadLeft / Right | hull knock slide | hull_knock.luau:300 |
| T | ButtonX | swimmer talk | PIW/Swimmer.luau:104 |
| W A S D | Thumbstick1 | swimmer move | PIW/Swimmer.luau:119 |
| A / D | Thumbstick1 | recovery level | PIW/Recovery.luau:185 |
| RMB | ButtonL2 | throw-bag aim | PIW/Ways.luau:292 |
| E | ButtonX | PIW grab | PIW/Ways.luau:297 |
| E | ButtonX | care picker press / hold | PIW/Care.luau:246 |
| E | ButtonA | sinking pump; bung hold also R2 | Sinking/Save.luau:212,278 |
| E | ButtonX | triage / treat / survey / calm picker | treat.luau, triage.luau, primary_survey.luau, panic_calm.luau |

### Duplicates found and fixes

Fixed this pass (smallest change):

- **Tab** — NextGoal's 3-goal view vs the Roblox player list. NextGoal moved to **I** (free; grepped
  `src/client` and the MapController legend) and its glyph is on the chip.
- **Y** — NextGoal gamepad Y vs boat approach (driving a boat), car launch (driving a car), map
  legend (map open) and photo grade (lens open). Moved to **ButtonR1**, free on foot and in both
  vehicles; only the modal product card (pages) and photo mode (zoom) use RB. In photo mode the
  lens sinks it at `High + 5`; an open product card also pages, and the goal view opens behind it.
- **J** — logbook vs car lights while driving a car. ExplorationController now ignores J while
  seated; pad L3 still opens the logbook anywhere.
- **Y** — whistle (CaptainsLocker) vs crew-up flare on foot in an operation. The flare's keyboard
  hold moved to **U**; its pad hold stays ButtonY, free on foot now that NextGoal left it.

Left as is (different context, or CAS priority resolves it):

- **E** is the one world action key across prompts and step mechanics; steps are mutually exclusive,
  so only one E binding is live at a time. Care picker / PIW grab / ferry / sinking never share a step.
- **P** phone vs photo pose; **G** grade vs siren; **M** map vs photo move: photo mode binds at
  `High + 5` and sinks the lower action while the lens is up.
- **Space** is jump plus air-pocket pull, car handbrake, debrief continue and cinematic skip; the
  latter three run in modes where the character cannot jump.
- **F** photo shutter vs hull-knock mark vs shop prompt: photo mode is a HUD mode, and the shop is
  not open at an operation.
- **H** assess horn deliberately returns `Pass` so an owned cosmetic horn still plays (comment in
  assess_vessel.luau:121).
- **Return** tasking accept vs debrief continue: the pager and debrief never coexist.
- **DPadUp** on foot is whistle (owners) and radio PTT (when a step arms it); both are deliberate
  deliberate presses, and NextGoal no longer uses it.
- **ButtonY hold** for the flare in a moving boat / car also presses approach or launch once; the
  flare needs a 0.9 s hold, so it cannot fire by accident.
- **ButtonB** closes every modal and dives while swimming; no modal is open while swimming.
