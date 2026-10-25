# 14 · Playtest feedback and design direction

User playtest notes and decisions from 2026-10-18 (private test place 85419402278824, v13). Section 1 logs problems that are **not fixed yet**. Sections 2 to 6 are design direction. Where they conflict with earlier chapters, this chapter wins, and the conflicts are listed in section 7.

## 1. Playtest issues (logged, not fixed)

| # | Issue | Expected |
|---|---|---|
| F-1 | **Too much text in the UI.** Several panels and prompts explain themselves in sentences. | Icons, pictures and short labels. A player who doesn't read still knows what to do (section 2). |
| F-2 | **Some UI needs a mouse.** Some elements can only be used by clicking, with no keyboard, touch or gamepad path. | Every element works with mouse, touch and gamepad (docs/09 §2.7). Audit every panel. |
| F-3 | **The first mission is ambiguous.** In the cold open it isn't clear what the player is meant to do. | The goal reads from the world in a few seconds: the casualty waving, the boat pointing at them, one obvious next action (docs/09 §9.1). |
| F-4 | **Pressing Space in the water sinks the character to the seabed.** | Space keeps the swimmer at the surface or swims up. A swimmer never ends up on the bottom by accident. |
| F-5 | **The body looks wrong when looking down in first person.** | Hide the body in first person; show only the arms during actions (section 4). |

## 2. Principle: show, don't tell

- The game explains itself through the world, animation and simple icons, not text. Text is the last resort.
- **More than one way works.** A step can be solved in several ways. None of them is spelled out in text; the player finds them by trying.
- **Nobody gets stuck.** If the player does nothing useful, the world helps after a short time (section 3, the 10 s rule).
- UI rules:
  - Short labels or icons only. No paragraph tutorials.
  - Show the key or button glyph for the device in use (keyboard, touch, gamepad).
  - Every action reachable on every device.
  - **No choice UI (rule, user 2026-10-18).** No menus, cards or lists where the player picks an option (press 1 / 2 / 3, choose a method, pick a kit). The player only does actions in the world: grab, throw, drive, pull, knock, hold. What to do reads from the world, and more than one action works. A key or button glyph next to a world action is fine; a menu of options is not.

## 3. Saving a person in the water: several ways

Any of these works. The UI never lists them.

| Way | What the player does | What they see |
|---|---|---|
| **Drag** | Swims or drives close, grabs the casualty and drags them to the boat or the shore | The casualty takes hold and is pulled along |
| **Throw** | Holds right click (mobile: hold Action; gamepad: hold LT, tune) to aim, releases to throw | While aiming, an arc and a ghost of the object to throw (throw bag line or lifebuoy) show where it lands. The casualty grabs it and climbs or is pulled in |
| **They come to you** | Gets close and stops | Within 10 s at most, the casualty swims to the player by themselves |

**The 10 s rule** (interpretation of the user's note, tune): once the player is close to the casualty (or a throw has landed near them), the casualty swims to the player within 10 seconds at most. This stops new players getting stuck and makes the cold open (F-3) impossible to fail in a confusing way.

**The first mission ends on land (user, 2026-10-18).** The cold open is not finished when the casualty holds on. The player brings them to land (the station slipway or Haven Sands): the casualty holds on to the jet ski, or is dragged or swum in. On land someone takes them over (a medic or a passer-by wraps them in a blanket), then the player **meets Chief Aggie**, who walks up, and the story continues from there (the station, the first real call). No text cards: the shore is marked in the world (flare smoke or a waving figure on the slipway), and Aggie's welcome is a short spoken line.

The deeper methods in docs/09 §5.3 (horizontal lift, parbuckle net, panic handling) stay as later and Pro content. The first missions use the three ways above.

## 4. Characters: simple Roblox characters only

> **Decision 2026-10-18 (user):** all characters are simple Roblox characters (R15 with HumanoidDescription clothing and accessories), not built in Blender.

- This extends the 2026-10-17 decision in docs/12 §2.9 to **every** human character, including the Person in the Water casualty. `M_Chr_Casualty_Swimmer` is replaced by a dressed R15 character with a lifejacket accessory.
- Human Blender character batches (CH1, CH2, CH3, CH5 human clips) are cancelled, not paused. Animations use Roblox animations on R15.
- **Bosun the dog too (decision 2026-10-18, user).** Bosun becomes a simple form, not the Blender fur model: fur cards are too heavy on phones. A simple low-poly dog with no fur cards, one small texture set or plain materials, a simple Motor6D rig and Roblox animations. The CH6 and CH7 Blender work (`M_Chr_Bosun`, fur atlas, `RIG_Bosun`) stops; the source files stay in `art/source` but are not shipped.
- **First-person arms: simple too (decision 2026-10-18, user).** Simple arms and gloves, no Blender hero viewmodel. What matters is **many animations for many situations**, not mesh detail.
- **No body in first person.** The player's body looking down looks wrong (F-5), so first person hides the body. The arms appear **only while an action animation plays** and are hidden otherwise. Clip list (tune): wave, use the phone, hold the bars, throw (bag, lifebuoy), haul a line, grab a casualty, drag, wrap the blanket, CPR, radio handset, point, knock on a hull, climb a ladder.

## 5. A living town: many NPCs

Port Haven should feel lived in, with many simple NPCs doing ordinary things, as in real life:

- Cars driving the roads (using the existing road ribbons and `LandVehicleConfig`).
- People walking, jogging, walking a dog, cycling.
- Older residents standing or sitting in front of their own houses, chatting over the fence.
- Fishermen on the quay, people at the Chandlery, kids and families on Haven Sands, tourists taking photos at the Harbour Light.
- Routines follow the weather and time: people go indoors when a storm comes, beaches empty, lights come on at night.

Notes for building it:
- Same simple R15 characters as section 4 (`NpcFactory`, `NpcOutfits`).
- Run the ambient crowd on the client where possible and cap counts per quality tier, inside the docs/10 §6.7 budget (about 20k streamed instances).
- NPCs never block roads, the slipway or the quay ladders.

## 6. The mobile phone

The player carries a phone:

- Opening it (one key, one touch button, one gamepad button) shows the phone in hand and **frees the mouse cursor**, so the player can click things on it. Closing it locks the camera again.
- Simple app icons with little or no text. Candidates (tune): map, call log or radio log, logbook, crew, settings, camera (photo mode later).
- Everything on it is self-explanatory, like a real phone.
- **No shop on the phone.** Purchases stay at in-world counters (docs/04 §1.1). The phone may only point the way to the Chandlery on the map.

## 7. Conflicts with earlier chapters

| Earlier rule | Change |
|---|---|
| docs/09 §2.7: hold right click = Lookout (keep eyes on) | Right click becomes throw aim (section 3). Lookout moves to another input, or happens on its own when the casualty is on screen |
| docs/09 §9.1 cold open: sled recovery with a two-hand rhythm | Rebuild with the section 3 ways and the 10 s rule. Fix F-3 here |
| docs/05 §8.2 and docs/12 §2.9: realistic skinned human meshes | Superseded by section 4 |
| docs/12 §2.9: Person in the Water uses `M_Chr_Casualty_Swimmer` | Replaced by a dressed R15 character |
| docs/05 §8.5 and docs/12 §2.9: detailed hero viewmodel arms in Blender (CH4), always visible | Simple arms shown only during action animations; body hidden in first person (section 4) |
| docs/05 §8.3 and docs/12 §2.9: Bosun as a realistic fur model with a custom Blender rig (CH6, CH7) | Simple low-poly dog, no fur cards (section 4) |

## 8. Work packages

Added to the release plan (docs/13 §2.7).

| ID | Deliverable |
|---|---|
| RP-UX1 | UI audit and fix: cut text to icons and short labels (F-1); keyboard, touch and gamepad paths on every element (F-2) |
| RP-UX2 | Cold open rework: clear goal from the world, section 3 rescue ways, 10 s rule (F-3) |
| RP-UX3 | Swimming fix: Space never sinks the swimmer (F-4) |
| RP-R1 | Rescue variants for Person in the Water: drag, throw with aim arc and ghost, swim to the player within 10 s |
| RP-CH1 | Replace `M_Chr_Casualty_Swimmer` with a dressed R15 casualty; R15 animations for tread water, wave, grab and climb |
| RP-DOG1 | Simple Bosun: low-poly dog with no fur cards, simple rig, Roblox animations; the harness and the Bosun's Wardrobe cosmetics refit to it |
| RP-ARMS1 | First person: hide the body; simple arms shown only during actions; the clip set in section 4 on keyboard, touch and gamepad triggers (F-5) |
| RP-NPC1 | Living town: ambient walkers, joggers, dog walkers, residents at their houses, traffic, weather and time routines, per-tier caps |
| RP-PH1 | The phone: open and close, free cursor, app icons (map, log, logbook, crew, settings) |
