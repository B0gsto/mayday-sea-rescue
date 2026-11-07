# 04 · Monetization

What Robux buys in the boat-upgrade game. Ids and prices: `src/shared/Config/MonetizationConfig.luau` (`id = 0` or
`ready = false` = not for sale). Store text and icons: `marketing/products.md`. Live prices can differ from config
(check `GetProductInfo`).

## 1. Stance

- Robux buys looks and time, never levels. Boat levels (docs/30) are Cash only, at the Upgrade Station or the
  on-boat panel (`UpgradeService`).
- Every Robux boat is a look: the boat you wear takes your level's speed, room and fuel tank (`BoatLevels.apply`).
- One random purchase: Deep Spin spins, odds and pity shown, PolicyService gate.
- Prompts open only from the Shop, the boat board, the wheel's token machine, the build sign and the HUD sale button.

## 2. Passes

| Pass | R$ | What it does |
|---|---:|---|
| Starter Kit | 25 | 3,000 Cash once, Station Orange livery. HUD "SALE" button until 2026-11-10 00:00 UTC (`saleEndsUtc`) |
| 2x Cash | 75 | Doubles Cash awards (`CashEffects`; all multipliers together capped at x5) |
| Quick Launch | 49 | No Boat to me wait |
| RIB / Lifeboat | 49 / 129 | That hull as your boat's look. A pass from before the ladder lifted the old save's level once (`applyPassFloor`) |
| Storm Runner / Tidewalker / Riptide X / Gilded Gull | 199 / 249 / 129 / 199 | Premium boat looks |
| Rescue Helicopter / Submarine | 399 / 249 | Own the craft; they use the boat level's fuel tank |

Not for sale: VIP Crew Card, Bosun's Wardrobe, Water Dog Friends, Storm Chaser Liveries, Captain's Locker, Sea Shanty
Radio, Horn Pack, Siren Pack, Light Bars, Wake Trails, Beach ATV, Coastguard Response, Harbour GT, Lighthouse
Cruiser, Seaplane.

## 3. Products

| Product | R$ | What it does |
|---|---:|---|
| Small Bonus / Crew Payroll / Station Budget / Harbor Fund | 10 / 25 / 75 / 149 | Cash: 15 min / 45 min / 2.5 h +10% / 7 h +20% of your rate |
| Cash Boost | 15 | 2x Cash for 30 min of playtime |
| Crew Boost | 15 | +50% Cash for your crew, 20 min |
| Day 2x Cash / Day Quick Launch | 15 / 10 | The pass for 24 h |
| One / Five / Fifteen Spins | 49 / 199 / 499 | Deep Spin spins (`paidRandom`) |
| Finish Now 1 / 2 / 3 | 9 / 25 / 49 | Finish the running island build; the server picks the tier by time left (`BuildTimer.finishTier`) |
| Island buildings (`Dock*`) and decor (`Decor*`) | 15-199 | Skip a building's Cash once its prerequisites stand (the island is optional since the pivot) |

Off: Call the Storm / Great Storm (always sunny), Dock Garage, Crew Hire.

## 4. Deep Spin (paid random)

| Rarity | Odds | Prizes | Owned duplicate pays |
|---|---:|---|---:|
| Common | 50% | Cash | 150 |
| Uncommon | 25% | Cash | 400 |
| Rare | 15% | Golden Pet, Gold Chrome finish, Rainbow Wake | 600 |
| Epic | 7% | Neon Pet, Neon Glow finish, Fire Wake | 1,500 |
| Legendary | 2.5% | Rainbow Pet, Lava finish, Star Wake | 4,000 |
| Mythic | 0.5% | Galaxy Pet, Galaxy finish, the Storm Runner look | 10,000 |

- Rules in `SpinRules`: pity Epic+ every 10 spins, Legendary+ every 50; free spins 1 a UTC day and 1 per 10 rescued.
- One spin per trip: the wheel dives to the Deep, reveals, and surfaces on its own (`Controllers/DeepSpin`).
- Sold only at the wheel's token machine beside the odds board. It hides and refuses where
  `ArePaidRandomItemsRestricted` is not false or the check failed; a receipt bought while offered is always granted.

## 5. Fair rules

1. Never sell levels, grades, call reach, survivor counts or the unlock order.
2. Packs never out-earn play per hour.
3. No offer during a call or in a prompt the player did not open. The Starter Kit sale button is the one countdown.
4. Random is shown and capped: odds and pity on the board, duplicates pay Cash, nothing cashes out.
5. Purchases are verified server-side, one grant per receipt (`DataService.CommitReceipt`).
6. No item over 499 R$; no pass over 399.

## 6. Approved, not built

Owner 2026-10-31: Starter Kit rework (49 R$: 10,000 Cash, Station Orange livery, bandana, 24 h 2x Cash, the first card
for players who own nothing); five cosmetics on sale (Captain's Locker 99, Shanty Radio 79, Horn 79, Siren 99, Light
Bars 129) after an icon pass; private servers on (a Creator Dashboard setting). After the sale ends the owner raises
the Starter Kit price on the dashboard (test 2036091711, launch 2040634962); match `price` in config.
