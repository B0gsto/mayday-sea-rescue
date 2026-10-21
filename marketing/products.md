# Roblox products (RP-M4 / G59)

Source of truth: `src/shared/Config/MonetizationConfig.luau`, audited against
`docs/04-monetization.md` and `docs/15-retention-and-new-players.md` section 1 on 2026-10-20.
All names and prices match docs/04; no config edit was needed.

Fair-rules check: no item carries a time limit on its Robux price, no item is `paidRandom`,
so no odds table or PolicyService gate is needed yet (Sea Chests are post-launch, RP-M6).

## Catalogue

| name | type | price R$ | ready | effect implemented | icon file | description (store text) |
|---|---|---:|---|---|---|---|
| Small Bonus | Developer product | 39 | yes | yes — `CashEffects` pack, 15 min of top-zone rate | marketing/items/SmallBonus.png | Cash equal to 15 minutes of your top open zone's Cash rate. Cash only, no Reputation. |
| Crew Payroll | Developer product | 99 | yes | yes — `CashEffects` pack, 45 min | marketing/items/CrewPayroll.png | Cash equal to 45 minutes of your top open zone's Cash rate. Cash only, no Reputation. |
| Station Budget | Developer product | 249 | yes | yes — `CashEffects` pack, 2.5 h +10% | marketing/items/StationBudget.png | Cash equal to 2.5 hours of your top open zone's Cash rate, plus 10%. Cash only, no Reputation. |
| Harbor Fund | Developer product | 599 | yes | yes — `CashEffects` pack, 7 h +20% | marketing/items/HarborFund.png | Cash equal to 7 hours of your top open zone's Cash rate, plus 20%. Cash only, no Reputation. |
| Cash Boost | Developer product | 49 | yes | yes — `CashEffects` 2x Cash, 30 min of playtime | marketing/items/CashBoost.png | 2x Cash for 30 minutes of playtime. The timer pauses while you are away. Does not stack with the 2x Cash pass. |
| Crew Boost | Developer product | 49 | yes | yes — `CashEffects` crew-wide +50% Cash, 20 min | marketing/items/CrewBoost.png | +50% Cash for you and everyone in your crew for 20 minutes of playtime. One active per crew. Cash only. |
| Challenge Reroll | Developer product | 19 | no | yes — `ChallengeService` receipt + `rerollDaily`, 3/day | marketing/items/ChallengeReroll.png | Swap one daily challenge for another. Up to three a day. |
| Call the Storm | Developer product | 249 | yes | yes — `StormService` ticket + server queue | marketing/items/CallTheStorm.png | Brings a server-wide storm to the Gale Isles for everyone in the server. Joins the server's storm queue. |
| Call the Great Storm | Developer product | 699 | yes | yes — `StormService` ticket + guaranteed big call | marketing/items/CallTheGreatStorm.png | Brings a bigger server-wide storm with a guaranteed big call for everyone in the server. Joins the server's storm queue. |
| Season Logbook | Developer product | 399 | no | no — paid track is data only, no grant path | marketing/items/SeasonLogbook.png | The paid track of this season's logbook: a cosmetic on every stamp. Cosmetics only. |
| 2x Cash | Game pass | 199 | yes | yes — `CashEffects.multiplier` on every Cash award | marketing/items/DoubleCash.png | Doubles Cash from operations, big calls and challenges. Does not change Reputation or rank. |
| VIP Crew Card | Game pass | 299 | no | partial — badge, VIP Gold livery and roof deck built; free daily reroll missing | marketing/items/VipCrewCard.png | Gold nameplate and radio tag, VIP Gold livery for every vehicle, and the VIP deck on the station roof. |
| Quick Launch | Game pass | 149 | yes | yes — `VehicleService` quick-launch path | marketing/items/QuickLaunch.png | Skip the launch cooldown and launch any owned vehicle straight from the station or an opened outpost. Never affects casualties or grades. |
| Starter Kit | Game pass | 99 | yes | partial — 3,000 Cash and Station Orange livery live; Bosun bandana not shipped | marketing/items/StarterKit.png | 3,000 Cash, paid once. Owners also get the Station Orange livery and a Bosun bandana when they arrive in a later update. |
| Bosun's Wardrobe | Game pass | 129 | no | partial — six bandanas + life jacket built; coat colours and captain's hat not shipped | marketing/items/BosunsWardrobe.png | Six bandanas and a dog life jacket for Bosun. Cosmetic. |
| Water Dog Friends | Game pass | 199 | no | no — swap code exists, but both breeds are Bosun's rig in a recolour; `unfinished` | marketing/items/WaterDogFriends.png | A Labrador and a Portuguese Water Dog to swap with Bosun. Same abilities as Bosun. Cosmetic. |
| Storm Chaser Liveries | Game pass | 249 | no | partial — static storm livery + storm-blue suit; animated lightning stripes not built | marketing/items/StormChaserLiveries.png | A storm-blue livery for every vehicle plus a storm-blue uniform. Cosmetic. |
| Captain's Locker | Game pass | 99 | no | yes — `Outfits` + three caps + whistle emote | marketing/items/CaptainsLocker.png | A bright wetsuit, a foul-weather coat, three caps and a whistle emote. Cosmetic. |
| Sea Shanty Radio | Game pass | 79 | no | yes — `ShantyRadio` server/client, 2 stations, 16 licensed tracks | marketing/items/SeaShantyRadio.png | An in-vehicle radio with two stations of maritime music. Other players can mute it. |
| Horn Pack | Game pass | 79 | no | yes — `Horns`, six recorded marine horns | marketing/items/HornPack.png | Six marine horns for your vehicle. Other players can mute horns. Cosmetic. |
| Siren Pack | Game pass | 99 | no | yes — `Sirens`, four tones with light patterns | marketing/items/SirenPack.png | Four siren tones with matching light patterns for your vehicle. Other players can mute sirens. Cosmetic. |
| Light Bars | Game pass | 129 | no | yes — `LightBars`, six colour sets | marketing/items/LightBars.png | Six light bar colour sets for every vehicle. Cosmetic. |
| Wake Trails | Game pass | 149 | no | yes — five wake looks (long white water, wide fan, deep churn, spray, night glow) | marketing/items/WakeTrails.png | Five wake trails for every owned vehicle. Cosmetic. |

Icons: all 23 exist at 512×512 RGB, made by `tools/make-item-icons.py`; none were missing, so
nothing was regenerated (the tool is safe to re-run with `--only Key` for a single icon).

## Create them (dry run first)

`deploy/state.json` currently targets **Mayday: Sea Rescue (Test)** (universe 10771468869,
place 85419402278824). From the repo root:

```sh
python3 ~/RobloxProjects/tools/deploy.py . 10771468869 85419402278824 --steps monetize --dry-run
```

The dry run makes no network calls and no file writes. It lists all 23 items because its preview
loop ignores `ready`; the real `--steps monetize` run skips every item with `ready = false`.
The 11 `ready` items already exist on the test universe and are adopted by name, so a real run
is idempotent. After U-1, substitute the launch universe and place ids.

## Stay off at launch (`ready = false`)

- **Season Logbook** — the paid track has no grant path; SeasonService reads it as data only.
- **Water Dog Friends** — no real Labrador or Portuguese Water Dog models; both are Bosun's rig
  in a recolour, flagged `unfinished`. Do not sell until the models exist.
- **VIP Crew Card** — its free daily challenge reroll is not built. Selling it would promise
  something the game does not do.
- **Bosun's Wardrobe** — only six bandanas and the life jacket shipped. The config text still
  promises coat colours and a captain's hat; fix the text or ship the art before flipping.
- **Storm Chaser Liveries** — the livery and suit are static storm blue. The advertised
  animated lightning stripes are not built.
- **Wake Trails** — the five looks are realistic water, not the "sparkle foam, rainbow, bubbles,
  petals" in the older docs/04 text; fix the text before flipping.
- **Challenge Reroll, Captain's Locker, Sea Shanty Radio, Horn Pack, Siren Pack, Light Bars** —
  the effects are built, but docs/13 LU-7 scopes 1.0 to the 11 `ready` items. These are safe to
  flip in a later batch, one line each, after the text above is checked.

Not in the config at all (later packages, do not create now): 2x Reputation, Rep Boost, Crew Rep
Boost, Sea Time Credit, Fast-Track and the 5 R$ row (RP-M5), Sea Chests (RP-M6), Signature
Vehicles (RP-M7).

## Group reward: Crew (G68, free)

A free retention hook, not a product: group members get the **Crew** bay pennant and a flat **+10%
Cash** on the daily streak crate. The sign stands beside the harbour noticeboard with the pennant
glyph, "Join crew" and the reward preview; it only appears when the group is configured, and it
never opens a browser window (kids' platforms): the prompt uses Roblox's own
`GroupService:PromptJoinAsync`, with the label alone if that is unavailable.

### Owner steps (once)

1. Create a Roblox group for the experience (`roblox.com/groups`), then upload its emblem/icon
   from the group's Configure page. The in-game sign draws a placeholder pennant, so the group
   icon is for the Roblox group page only.
2. Copy the **numeric group id** (the number in `roblox.com/groups/<id>/...`, or Configure >
   Group Info).
3. Paste it into `src/shared/Config/SocialConfig.luau`:

   ```lua
   GroupId = 1234567, -- 0 turns the sign, the pennant and the crate bonus off
   ```

4. Publish. No Roblox item ids, badges or developer products are involved.

Fair rules (docs/15 section 1): the pennant is kept if the player leaves (nothing is lost), the
bonus is free and only shown at the noticeboard, never as a popup. `GroupId = 0` is the shipped
default so nothing promises a group that does not exist yet.
