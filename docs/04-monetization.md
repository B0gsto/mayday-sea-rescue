# 04 · Monetization

> Older chapter: this predates the 2026-10-25 hub redesign. [`00-design.md`](00-design.md) is the source of truth; the current game is the forest hub, six Lego islands and no town, cars, phone or radio.

This file owns every Robux price. Cash prices and progression live in [`03-progression.md`](03-progression.md). Research references point to [`research/store-page-and-monetization.md`](archive/research/store-page-and-monetization.md) (shortened to "research") and to the source links it records. Prices marked **(tune)** are first guesses; Managed Pricing tests (section 9) will move them.

## 1. Stance

Earn hard, fairly. Mayday sells **speed** (Reputation, Cash, launches), **looks** (cosmetics, Signature vehicles, Sea Chests) and **shared fun** (storms). It never sells **skill**: a rescue goes exactly as well as the crew performs it ([document 09](archive/09-rescue-operations.md)). A player who never pays can still reach every rank, certification, vehicle, zone and badge at the pace in [document 03](03-progression.md); paying gets them there sooner and better dressed. Mayday is PvE, so speed bought by one player never takes anything from another.

Rules for every item:

1. **Sell speed, never skill.** Robux may add or multiply Reputation and Cash (section 4.4). Robux never passes or shortens a certification, raises a step grade, widens a timing window, adds a hint, changes the condition meter or makes an operation step easier. **Every promotion still needs its certification** ([document 03](03-progression.md), section 3.1), so a paying player can be fast but never unqualified at the helm.
2. **Speed up, do not skip.** Paid Rep is capped so it finishes a grind rather than replacing the game: Sea Time Credit covers at most half of each rank's Rep band and Fast-Track only appears in the last quarter (section 4.4). No item jumps a player straight to a rank.
3. **Random items are cosmetic only, with odds shown.** Sea Chests (section 4.5) hold cosmetics only, never Rep, Cash boosts, gear or stats. Every outcome and its odds are on the card before purchase, duplicates are converted to Cash, a pity counter guarantees a rare, and one chest can always be bought with Cash.
4. **Paid vehicles are rank-gated variants.** Signature Vehicles (section 3.4) can be bought at any time but only driven at the free vehicle's rank and certification. They handle exactly like the free vehicle.
5. **State the effect in numbers.** Every product card says exactly what it gives ("Doubles Reputation from operations and challenges for 30 minutes of playtime. Does not change grades or certifications.") before the Roblox prompt opens.
6. **The player opens every prompt.** A purchase prompt opens only after the player walks up to a real item or counter, opens its product card and taps a Buy button that shows the Robux price (section 1.1). The game never pops a prompt by itself.
7. **Nothing priced in the first three operations.** A new player sees no prices and no offers until the tutorial chain is three operations in; until then the Chandlery's priced shelves are curtained off (section 1.1).
8. **Never make free play slower to sell speed.** The free pacing in [document 03](03-progression.md), section 10 is the floor. Tuning may move paid items, never slow the free rates to push them.
9. **No pressure.** No countdown timers, no "last chance", no fake scarcity, no messages that shame a player for saying no.

### 1.1 Where things are sold: no shop button, only shops

There is **no shop button and no store menu on the HUD**. Every pass, product and Cash item is offered at a real place in Port Haven, and the purchase starts from handling a real item or walking up to a counter ([document 02](02-core-loop-and-mechanics.md), section 13). The places are on the map in [document 10](10-world-and-map.md), sections 1.2 and 2.4.

**The purchase flow.** Walk up to an item and interact (a ProximityPrompt: hold E, tap, or press X on gamepad). In first person the player lifts the item and turns it in their hands, and a **product card** appears beside it: what it is, the exact effect in numbers, the price read live from MarketplaceService (section 8), and a **Buy** button showing that price. Only tapping Buy opens the Roblox purchase prompt (rule 5). Owned items show an "Owned" tag on the shelf and are equipped at the station locker or the Chandlery mirror.

| Place | What is offered there | How it is shown |
|---|---|---|
| **Port Haven Chandlery**, gear counter | Gear and gear upgrades (Cash, [document 03](03-progression.md), section 5) | Fins, the radio direction finder, tow ropes and later gear on the shelves behind the counter, each with a paper tag showing level and Cash price |
| Chandlery, uniform racks and mannequins | Captain's Locker, the Storm Chaser uniform, Season Logbook uniforms (as previews) | Mannequins in the window and by the racks wear each set; a full-length mirror lets the player try a set on before buying |
| Chandlery, the dog corner | Bosun's Wardrobe, Water Dog Friends | Coats and bandanas on a low rail; the shop's own Labrador and Portuguese Water Dog asleep in a basket (interact to see them as companions) |
| Chandlery, the livery and fittings wall | Storm Chaser Liveries, Horn Pack, Siren Pack, Light Bars, Wake Trails, the Starter Kit livery | Swatch boards and a scale jet ski model wearing each livery; a horn board with real horns to press and hear; a light bar on the wall cycling its colour sets; framed wake-trail photos |
| Chandlery, the radio shelf | Sea Shanty Radio | A marine VHF-style set on the shelf playing a track when picked up |
| Chandlery, behind the counter | 2x Cash, 2x Reputation, VIP Crew Card, Quick Launch, Starter Kit, the Season Logbook | Framed service cards on the wall for the passes; the season's logbook lying open on the counter, showing both tracks |
| Chandlery, the till | Cash packs, Cash Boost, Crew Boost, Rep Boost, Crew Rep Boost, Sea Time Credit, Challenge Reroll, gifting (section 3.3) | The shopkeeper at the till; every card opened here has the Gift button |
| Chandlery, the tip jar by the till | The 5 R$ row (section 4.6) | A wicker basket of flares, dog treats, stickers and lanterns, and a duck horn on a hook |
| Chandlery, the salvage corner | Sea Chests (section 4.5) | Three washed-up chests on a net-covered pallet; the odds are chalked on a slate above them. The player lifts the lid in first person to open a chest |
| **Station noticeboard** (by the promotion board) | Fast-Track (section 4.4) | A "Fast-Track your promotion" form pinned under the player's next rank, shown only when it is on offer |
| **Harbourmaster's office** (on the quay, next to the Chandlery) | Call the Storm, Call the Great Storm (section 5) | The harbourmaster's desk with a storm barometer; a chalkboard by the door shows the server's storm queue |
| **Boatyard** | Boats (Cash, [document 03](03-progression.md), section 4) and boat upgrades; paid boat liveries shown on boats in the yard; Signature boats (section 3.4) | Boats on stands and in the water with a price board; each Signature boat stands under a canvas hood beside its free sister, hood pulled back to show it; buy, then collect at the pontoon or have it delivered to the bay |
| **Station garage and helipad** | Land vehicles (free, rank-gated), the helicopter (Cash) [L], vehicle upgrades, the Signature helicopter [L] | Vehicles on their marked bays with a board each |
| **Your bay** at the station | Bay upgrades (Cash), rewarded video ads (section 4.3), the Season Logbook's tracks (read and claim) | Boards at each upgrade's spot; the bay terminal |
| **Nell's bait shop** | Challenge Reroll (also at the Chandlery till) | On the challenge board |

**Short walks, including on mobile (tune).** The Chandlery is the building next to the station on the quay: its door is about 30 studs from the station's main door and the spawn and respawn point, and the harbourmaster's office is the next door along (about 60 studs). Every Robux item is sold inside those two buildings (some also elsewhere, as listed above), so a phone player reaches any of them in under 10 seconds of walking. The HUD's "next thing" line and the debrief name the place to go, and tapping either sets a waypoint (never a purchase prompt). Liveries and horns can also be bought at the boatyard and the garage on the vehicle itself, so nobody has to walk back to town to dress a boat.

**Discovery without pop-ups.** Until three operations are done the Chandlery's priced shelves are behind a "Restocking for Reopening Day" curtain and only the Cash gear counter is open (rule 6). After that, Chief Aggie mentions it once on the radio, the window display changes with each season, and new items get a small "New" tag on the shelf. No item ever calls the player over, and no card opens by itself.

## 2. Price anchors from the research

| Anchor | Value | Source |
|---|---|---|
| Typical pass bands | 25 to 99 R$ small perks; 100 to 499 meaningful; 500 to 1,500 game-changing | https://profitable.app/tools/roblox-gamepass-calculator (research, section 3; unverified third-party guide) |
| 2x money passes seen | 110 R$ and 199 R$ | https://www.rolimons.com/gamepass/9418967 (research, section 3; unverified, prices change) |
| Marketplace fee | Creator keeps about 70% | https://profitable.app/tools/roblox-gamepass-calculator (unverified; confirm on the official monetization pages) |
| DevEx rate | $0.0038 per Earned Robux standard; $0.0054 for some purchases by verified U.S. 18+ players | https://create.roblox.com/docs/production/monetization/developer-exchange |
| Firefighting Sim passes | None found | https://rblxstat.com/games/10767634248 ([`research/reference-games.md`](archive/research/reference-games.md) section 1; unverified) |

The price ladder has a step at every budget, so every player with any Robux balance can buy something:

| Band | Items |
|---|---|
| 5 R$ | The tip-jar row (section 4.6): the first-purchase door |
| 19 to 49 R$ | Challenge Reroll, Sea Time Credit, Driftwood Chest, Small Bonus, Cash Boost, Crew Boost, Rep Boost |
| 79 to 149 R$ | Small cosmetic passes, Crew Rep Boost, Captain's Chest, Quick Launch, Surf Patrol jet ski |
| 199 to 349 R$ | 2x Cash, 2x Reputation, VIP Crew Card, Storm Chest, Storm Petrel RIB, Call the Storm |
| 399 to 699 R$ | Gale Queen's Guard lifeboat, Night Hawk helicopter, Harbor Fund, Call the Great Storm, late-rank Fast-Tracks |

Nothing costs more than 699 R$. The heaviest spenders are served by repeat products (boosts, Sea Time, chests, storms), not by one huge price.

### 2.1 Launch prices (user, 2026-10-21)

Launch cheap so more players pay, then raise. These override the list prices below for the live items (the
spec `tests/Monetization.spec.luau` pins them); pack contents (`cashMinutes`, `cashOnce`) are unchanged, so packs
are a better deal at launch. Private servers 25 R$ (section 6.1).

| Item | List | Launch |
|---|---|---|
| Small Bonus | 39 | 10 |
| Cash Boost / Crew Boost | 49 / 49 | 15 / 15 |
| Crew Payroll | 99 | 25 |
| Starter Kit | 99 | 25 |
| Quick Launch | 149 | 49 |
| 2x Cash | 199 | 75 |
| Station Budget / Call the Storm | 249 / 249 | 75 / 49 |
| Harbor Fund | 599 | 149 |
| Call the Great Storm | 699 | 149 |

## 3. Game passes

One-time purchases, permanent. All are [L] unless marked.

| Pass | Price (tune) | What it gives | Why this price and why it is fair |
|---|---|---|---|
| **2x Cash** | 199 R$ | Doubles Cash from operations, big calls and challenges. Does not touch Reputation. | The genre's best-known pass; 199 matches a real 2x listing. Convenience only: rank still gates every vehicle ([document 03](03-progression.md), section 10.2). |
| **2x Reputation** | 349 R$ | Doubles Reputation from operations, big calls, exercises and challenges, permanently. Stacks with Rep Boost (section 4.4) for 4x. Never changes grades, certifications or the Pro bonus band. | The new top seller: it halves the free pacing (Admiral in about three weeks instead of six). Priced above 2x Cash because rank is what players want most. Promotions still need certifications, so it buys speed, not skill. |
| **VIP Crew Card** | 299 R$ | Gold nameplate and radio tag, VIP Gold livery for every vehicle, access to the VIP deck on the station roof, one free daily challenge reroll. | Status and social, the classic VIP bundle. The reroll is a small convenience, also sold separately for 19 R$. |
| **Quick Launch** | 149 R$ | Skips the launch cooldown and the walk to your bay: launch any owned vehicle straight into the seat from anywhere (Spawn in the phone's Vehicles app, a lightning mark on the button). Never affects a casualty's condition, step grades or the order of steps. | Convenience only. Free players reach the same through Slipway upgrades (no cooldown and outpost launches at level 3, [document 03](03-progression.md), section 6). |
| **Bosun's Wardrobe** | 129 R$ | Six bandanas and a dog life jacket (launch contents, decision 2026-10-18: ship what exists; coat colours and the captain's hat may follow as free updates). | Pure cosmetic on the game's most loved character. Small-perk band. |
| **Water Dog Friends** | 199 R$ | Two extra companions to swap with Bosun: a Labrador and a Portuguese Water Dog (both real water working breeds). Same abilities as Bosun. | Cosmetic variety. Abilities are identical, so no advantage. |
| **Storm Chaser Liveries** | 249 R$ | Animated lightning-stripe liveries for every vehicle (new vehicles included), plus a storm-blue uniform. | Premium cosmetic. Shows well in storm screenshots and in the server's top-crews board. |
| **Captain's Locker** | 99 R$ | Uniform set: bright wetsuit, foul-weather coat, three caps, a whistle emote. | Low-price cosmetic for younger players. |
| **Sea Shanty Radio** | 79 R$ | An in-vehicle radio playing the game's own music tracks (cleared catalog or commissioned audio). Other players can mute it. | Social fun, a common genre pass. |
| **Starter Kit** | 99 R$ | 3,000 Cash once, the "Station Orange" livery for the board, jet ski and RIB, a Bosun bandana. Can be bought once, any time. | A gentle first purchase. Always available, no timer. 3,000 Cash is about 30 minutes of Calm Bay play. |

### 3.1 Season Logbook

| | |
|---|---|
| Price | 399 R$ per season (tune; stays in the 299 to 499 band). A developer product bought once per season. [L] |
| What it is | A cosmetic-only reward track for each season (about 8 weeks). Every player earns logbook stamps from normal play (operations, storms, big calls, challenges). The free track pays a cosmetic every few stamps; the paid track adds a cosmetic on every stamp: liveries, uniforms, Bosun coats, horns, wake trails, a season trophy for the bay. |
| Never gives | Cash, Rep, gear, vehicles or anything with stats. |
| Fairness | Buying late unlocks every paid tier already stamped, so there is no reason to rush. The season end date is shown plainly on the logbook page, never as a countdown banner. |

### 3.2 Vehicle cosmetics

Pure cosmetics that show on every owned vehicle. None use the reserved signal colours ([document 05](05-art-direction.md), section 3.2). Other players can mute horns and sirens. [L]

| Pass | Price (tune) | What it gives |
|---|---|---|
| **Horn Pack** | 79 R$ | Six real marine horns (ship, ferry, tug, cutter, ship's whistle, high whistle), on a tap button (launch contents, decision 2026-10-18). |
| **Siren Pack** | 99 R$ | Four siren tones with matching light patterns. |
| **Light Bars** | 129 R$ | Six light bar colour sets for every vehicle. |
| **Wake Trails** | 149 R$ | Five wake trails (sparkle foam, rainbow, bubbles, petals, glow). |

Single horns and trails also come from the Season Logbook and Service Stars ([document 03](03-progression.md), section 3).

### 3.3 Gifting

Every pass and cosmetic card opened in the Chandlery (or at the harbourmaster's desk for storms) has a **Gift** button. The buyer picks a friend in the same server; the friend gets the item and a thank-you note with a Bosun paw print. Items the friend already owns are greyed out. Gifts are developer products that grant the item to the chosen player, because game passes themselves cannot be transferred (verify current Roblox rules for gifting and any age limits before launch). [L]

### 3.4 Signature Vehicles

A premium variant of each vehicle: its own model, hull or paint finish, engine note, horn and a brass bay plaque. Game passes, one per vehicle. [L]

| Signature variant | Free sister | Drivable at | Price (tune) |
|---|---|---|---|
| **Surf Patrol** jet ski: lifeguard yellow, chrome rails, LED strip | Jet ski | Recruit | 149 R$ |
| **Storm Petrel** RIB: matte black hull, orange tubes, twin-outboard look | RIB | Rescue Swimmer (and Helm) | 249 R$ |
| **Gale Queen's Guard** lifeboat: heritage navy and gold, brass fittings | Lifeboat | Coxswain (and the Coxswain certification) | 399 R$ |
| **Night Hawk** helicopter: night-patrol grey, searchlight pod, gold rotor tips | Rescue helicopter | Rescue Pilot (and Pilot) | 499 R$ [P1] |

Rules:

1. **Same handling and stats.** Speed, seats, range, wave handling and grading are identical to the free sister. A Signature vehicle is never needed for anything.
2. **Buy any time, drive at rank.** A Signature vehicle bought early sits in the player's bay under a canvas hood with a plaque: "Unlocks at Coxswain". The HUD's next-thing line names it ("Coxswain: unveil your Gale Queen's Guard").
3. **The unveil.** When the rank and certification arrive, the radio says "Your Storm Petrel is cleared for launch" and the promotion ceremony ends with Chief Aggie pulling the hood off. Skippable, and made to be clipped and shared.
4. **No Cash needed.** Owning the pass grants the Signature vehicle without buying the free sister with Cash, which is a real Cash saving; it is still locked by rank. Vehicle upgrades bought with Cash apply to both.
5. **Signal colours.** Signature finishes never use the reserved signal colours ([document 05](05-art-direction.md), section 3.2).

## 4. Developer products

Consumables that can be bought more than once. All are [L].

### 4.1 Cash packs

Cash packs scale with the player's highest open zone, so a pack bought by a Captain is still worth having. The card always shows the exact Cash number before purchase.

| Pack | Price (tune) | Gives (tune) | Calm Bay example | Storm Front example |
|---|---|---|---|---|
| Small Bonus | 39 R$ | 15 minutes of your top zone's Cash rate | 1,500 | 4,300 |
| Crew Payroll | 99 R$ | 45 minutes | 4,500 | 13,000 |
| Station Budget | 249 R$ | 2.5 hours (+10% value) | 16,500 | 47,600 |
| Harbor Fund | 599 R$ | 7 hours (+20% value) | 50,400 | 145,300 |

Limit: five Cash pack purchases per account per day (tune). Cash packs do not give Reputation, so a pack can bring a vehicle closer but never unlocks one.

### 4.2 Other products

| Product | Price (tune) | What it gives | Limits |
|---|---|---|---|
| **Cash Boost** | 49 R$ | 2x Cash for 30 minutes of playtime (the timer pauses when the player leaves). | Hidden for 2x Cash pass owners; it does not stack with the pass. |
| **Crew Boost** | 49 R$ | +50% Cash for the buyer and everyone in their crew for 20 minutes of playtime (tune). The radio thanks the buyer by name. Cash only. | One active per crew; it stacks with the 2x Cash pass but not with another Crew Boost. |
| **Challenge Reroll** | 19 R$ | Swap one daily challenge for another. | Three per day. |
| **Call the Storm** | 249 R$ | A server-wide storm (section 5). | Server queue and cooldown. |
| **Call the Great Storm** | 699 R$ | A bigger server-wide storm with a guaranteed big call (section 5). | Server queue and cooldown. |

### 4.3 Rewarded video ads

Where Roblox allows them, a player can choose to watch a rewarded video ad from a **Watch for a bonus** button on the bay terminal: +50% Cash for 15 minutes of playtime or one challenge reroll (tune), up to three a day. Never Rep, never during an operation, never shown automatically. The button appears only for players and regions Roblox marks eligible. Verify the current rules before building: viewer age and region eligibility, experience eligibility, the API, and what rewards are allowed. [L]

### 4.4 Reputation products

Speed for the rank grind, inside the caps in section 1 (rules 1 and 2). Every Rep product shows the exact Rep or multiplier on its card. A promotion still waits for its certification ([document 03](03-progression.md), section 3.1): Rep keeps counting, the HUD shows the certification as the next thing.

| Product | Price (tune) | What it gives | Limits |
|---|---|---|---|
| **Rep Boost** | 49 R$ | 2x Reputation for 30 minutes of playtime (the timer pauses when the player leaves). | Stacks with the 2x Reputation pass (4x). Buying another adds 30 minutes, up to 3 hours banked. |
| **Crew Rep Boost** | 79 R$ | +50% Reputation for the buyer and everyone in their crew for 20 minutes of playtime. The radio thanks the buyer by name. | One active per crew; stacks with the pass and Rep Boost. |
| **Sea Time Credit** | 25 R$ | Rep equal to one Silver-grade operation in the player's top open zone (Calm Bay 135, Storm Front about 475, tune). | Paid Sea Time counts toward at most **half of each rank's Rep band** (for example 1,050 of the 2,100 between Rescue Swimmer and Coxswain). When the cap is reached the card says so and greys out until the next rank. |
| **Fast-Track** | By next rank: Rescue Swimmer 49 R$, Coxswain 99 R$, Rescue Pilot 199 R$, Captain 299 R$, Commodore 399 R$, Admiral 699 R$, each Service Star 149 R$ | Fills the rest of the current rank band's Rep instantly. | Offered only once the player has **at least 75% of the band**, so it finishes a grind rather than replacing it. Shown on the station noticeboard under the next rank, never as a pop-up. Not offered for Lifeguard (inside the tutorial chain, rule 7). |

**Rep sources, all stacking (tune):** grade x storm x crew bonus x Pro x (2x Reputation pass) x (Rep Boost 2x) x (Crew Rep Boost +50%). Paid storms still give Rep at the normal rate (section 5, rule 1).

**Fairness checks.** Leaderboards count rescues, never Rep ([document 03](03-progression.md), section 9.1), so paid Rep never tops a board. The free pacing in [document 03](03-progression.md), section 10 does not count on any of these products and must not be slowed to sell them (section 1, rule 8).

### 4.5 Sea Chests (paid random cosmetics)

Washed-up chests in the Chandlery's salvage corner (section 1.1). The player lifts the lid in first person; the item rises out with a glint for its rarity. Cosmetics only: liveries, uniforms, Bosun coats, horns, wake trails, light bars, stickers, chest-only liveries. Never Rep, boosts, Cash (except duplicate refunds), gear or anything with stats. [L]

| Chest | Price (tune) | Common | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| **Driftwood Chest** | 25 R$ **or 2,500 Cash** | 75% (stickers, single horns, bandanas) | 22% (wake colours, uniform pieces) | 3% (light bar sets) | none |
| **Captain's Chest** | 99 R$ | 50% | 38% (liveries, Bosun coats) | 11% (rare light bars, animated stickers) | 1% (an animated livery) |
| **Storm Chest** | 249 R$ | none | 60% | 35% (animated liveries, exclusive wake trails) | 5% (a chest-only animated livery for every vehicle, or a storm-only uniform) |

Rules:

1. **Odds on the card.** Every outcome and its odds, totalling 100%, are on the product card and on the slate above the chests before purchase (section 8).
2. **No duplicates.** A roll never gives an item the player already owns. If every item in a tier is owned, it pays Cash instead (Common 500, Rare 1,500, Epic 4,000, Legendary 10,000, tune), shown in the odds.
3. **Pity counter.** Every 10th Captain's or Storm Chest guarantees Epic or better; the counter shows on the card ("3 of 10").
4. **Unpaid path.** The Driftwood Chest can always be bought with Cash. Where `PolicyService` says paid random items are restricted, the paid chests are hidden and only the Cash Driftwood Chest is shown.
5. **Seasonal pools.** Each season adds new items to the pools and retires none; the odds table updates with them. No limited-time chests, no countdowns (rule 9).
6. **Opening is visible.** Nearby players see the glint and hear the rarity chime; Legendary pulls are named on the radio (buyers can turn this off).

### 4.6 The 5 R$ row

Small, visible items in the tip jar by the Chandlery till (section 1.1). Their job is the **first purchase**: a player who has bought anything is far more likely to buy again, and many players carry a few spare Robux. Each item also shows off the next price up. The creator keeps about 3 R$ per sale, so the row is a conversion tool, not income. Keep it to these five.

| Item | Type | What it gives | Leads to |
|---|---|---|---|
| **Signal Flare** | Developer product | Fire a coloured flare over the harbour; everyone in the server sees it. | Wake Trails, Light Bars |
| **Treat for Bosun** | Developer product | Bosun does a trick (rolls over, or shakes off water on everyone nearby). | Bosun's Wardrobe, Water Dog Friends |
| **Light a Lantern** | Developer product | A lantern with the player's name on the Harbour Light lantern wall until the server closes. | VIP Crew Card |
| **Hull Sticker** | Game pass | One decal (anchor, Bosun paw or lifebuoy) for every vehicle. | Storm Chaser Liveries, Signature Vehicles |
| **Duck Horn** | Game pass | One extra horn sound on the horn button. | Horn Pack |

## 5. Storm Summon (server-wide social event)

The paid storm is our version of an "admin abuse" event: one player pays, the whole server gets the fun, and the buyer gets the credit. It fits pillar 4 (the sea is the opponent) and the discovery signal for intentional co-play (research, section 5, https://create.roblox.com/docs/discovery).

| | Call the Storm (249 R$) | Call the Great Storm (699 R$) |
|---|---|---|
| Length | Standard storm: 60 s warning, 3 min storm, 60 s clearing | 60 s warning, 4 min storm, 60 s clearing with fireworks over Port Haven |
| Big call | Normal storm odds | Guaranteed: Capsized Ferry or Trawler on the Rocks. From [P1], Cruise Ship Aground if the server has not had one in the last hour |
| Cash bonus for everyone | x1.5 | x2 |
| Reputation | Normal rate (no storm bonus) | Normal rate (no storm bonus) |
| Buyer gets | Name on the radio ("Storm called in by @name"), a "Storm Caller" radio title for 24 hours, a thank-you button for others | The same, plus the name on the station board for the rest of the server's life |

Rules (tune):

1. **A paid storm boosts Cash, not Rep.** The extra operations still give normal Rep, but the x1.5 storm bonus applies to Cash only, so one player's purchase never moves the whole server's ranks. Rep is sold per player (section 4.4). Natural storms keep the full bonus.
2. **Queue, never stack.** Summons wait in a server queue. At least 8 minutes between summoned storms, and none within 2 minutes of a natural storm. The natural storm clock is not reset.
3. **Max queue of two.** Storms are summoned at the harbourmaster's office (section 1.1). When the queue is full, the chalkboard and the product card say "Storm queue full, try again soon" and the Buy button greys out. It never takes Robux for a storm that cannot run.
4. **Calm Bay stays sheltered**, so new players are not swamped by someone else's purchase.
5. **Anonymous option.** A buyer can turn off the name announcement.
6. **Works in private servers** with the same rules.
7. **Delivery guarantee.** If the server shuts down before a queued storm runs, the purchase is refunded as a "Storm Ticket" the player can use in any server.

## 6. Private servers and subscription

### 6.1 Private server

**Price: 25 R$ per month at launch (user, 2026-10-21: launch cheap so more players pay, raise later).** [L]

Why: crews of friends are our best players, and a private server lets them run storms together without strangers. 25 R$ is an impulse price for a friend group; raise it once players are paying. Firefighting Sim's description advertises free private servers, though its stats panel says private servers are off ([`research/reference-games.md`](archive/research/reference-games.md) section 1, unverified). We considered free private servers as a marketing hook and decided against it at launch, because 16-player public servers need people in them for big calls to work. If public servers fill well, we revisit free private servers as a marketing beat.

Owner tools: kick, pick the time of day, pick which big call comes next. All progress saves as normal. No free storms.

### 6.2 Subscription idea: Harbor Patrol membership [P1]

| | |
|---|---|
| Price | One of Roblox's monthly subscription price tiers, around the $4.99 level (unverified: subscription price points were not researched) |
| Gives | A daily stipend of 30 minutes' worth of Cash (claimed in game), one exclusive livery per month that stays forever, a "Harbor Patrol" radio tag, one free Call the Storm per month |
| Never gives | Rep, rank, exclusive vehicles, stronger gear |

Subscriptions are regionalized automatically and excluded from price optimization tests (https://create.roblox.com/docs/production/monetization/managed-pricing). We ship it after launch, once we know how many regular players we have.

## 7. What we never sell

| Never for sale | Why |
|---|---|
| Rank jumps and uncapped Rep | Rep is sold only as speed inside the section 4.4 caps (Sea Time to half a band, Fast-Track in the last quarter). No product grants a rank outright. |
| Promotion without certification | Every promotion needs its certification. Rep bought past the threshold waits until the certification is passed. |
| Zone or lighthouse access | Lighthouses need the rank and the mission. |
| Vehicles with better stats | Signature Vehicles handle exactly like their free sisters and are drivable only at the same rank and certification (section 3.4). |
| Rescue success | No "auto-rescue", no skipping a step, no instant finish, no casualty location reveal, no paid takeover rescue. |
| Grades, step results and Pro mode | Grades measure how the crew performed. Nothing paid changes a grade band, a timing window, the condition meter or the Pro bonus. |
| Certifications and exercises | Earned only by passing the exercise and the live operations ([document 09](archive/09-rescue-operations.md), section 11). No paid pass, retake skip or shortcut. |
| Better NPC crew or paid hints | NPC crew are the same for everyone and cannot be upgraded with Robux or Cash; Assist prompts are free and Pro is a free setting. |
| Kit that grades better | Paid cosmetics can change how kit looks, never what it does. Gear upgrades are Cash-only and never widen a grade band ([document 03](03-progression.md), section 1). |
| Random items with stats or progression | Sea Chests hold cosmetics only (section 4.5). No eggs, wheels, spins, luck boosts or random Rep, Cash or gear. |
| Protection or advantage over other players | There is no PvP, and nothing paid can block, push or out-claim another player. |
| Bosun himself | Every player gets Bosun free. Paid dogs are cosmetic swaps. |
| Badges | Every badge is earned by play. |

## 8. Policy compliance notes

| Topic | What the rule says | What we do | Source |
|---|---|---|---|
| **Paid random items** | Random items bought with Robux need every outcome and its odds shown before purchase, totalling 100%; luck boosts must show their effect; restricted users must be blocked or given an unpaid path. | Sea Chests (section 4.5) show every outcome and its odds on the card and the in-world slate, totalling 100%, before purchase. `PolicyService` `ArePaidRandomItemsRestricted` hides the paid chests; the Cash Driftwood Chest is the unpaid path. No luck boosts. Free daily gifts are fixed, not random. Declare paid random items in the maturity questionnaire and re-check the rule (it changes) before launch. | https://create.roblox.com/docs/en-us/production/monetization/paid-random-items |
| **Gambling** | Playable or simulated gambling is not allowed. | No spins, wheels, wagers or chance games. Sea Chests are the only random items: a fixed price, odds shown, no Robux or tradeable value out, duplicates refunded in Cash. | https://create.roblox.com/docs/production/promotion/experience-guidelines |
| **Purchase prompts from the world** | Prompts are opened with MarketplaceService from a client action. | Every prompt follows an explicit Buy tap on a product card opened from a ProximityPrompt, never from walking into a trigger zone (verify current MarketplaceService prompt rules). | https://create.roblox.com/docs/production/monetization |
| **Misleading thumbnails and claims** | Show only mechanics, UI and visuals that exist in game; no subjective claims or ads in text overlays; no real-life footage or voice-over. | Store art is real in-game captures of real calls. No "best rescue game" text. Product cards state exact effects. | https://create.roblox.com/docs/production/promotion/promotional-thumbnails and https://create.roblox.com/docs/en-us/production/publishing/thumbnails |
| **Age and maturity** | The maturity label decides who can play: Minimal and Mild reach Roblox Kids (5 to 8) and Select (9 to 15). Kids and Select have extra publishing requirements. | Target Minimal or Mild. Complete the questionnaire before launch. Read the Kids/Select requirements page (not yet fetched). | https://create.roblox.com/docs/production/promotion/experience-guidelines |
| **Regional pricing** | Passes are regionalized by default (30% to 100% of the default price). Developer products are opt-in and need `GetUsersPriceLevelsAsync` (verify). Hard-coded prices in UI do not update. | Read every price from MarketplaceService at runtime. Opt Cash packs and boosts in only after the price-level check is built. Storm Summons opt in last, since they affect the whole server. | https://create.roblox.com/docs/production/monetization/managed-pricing |
| **Rewarded video ads** | Eligibility, placement and reward rules are set by Roblox (not researched). | Opt-in button only, Cash or reroll rewards only, hidden for ineligible players. | Verify on the Creator Hub ads pages before building |
| **Gifting** | Not researched. | Gift only to players in the same server; exact effect shown before purchase. | Verify on the Creator Hub monetization pages |
| **Paid creator promotion** | Paid posts must be disclosed. | Any paid YouTuber or TikTok deal is disclosed in the post. | Research, section 2 |
| **Pay-to-win** | The research found no official pay-to-win policy text (unverified). | We sell speed (Rep and Cash, capped) and looks, never skill: nothing paid changes grades, timing windows, certifications or the condition meter. | Research, section 3 |
| **Young audience** | No official rule found on under-13 purchases (unverified). | We follow our own section 1 rules (no pop-ups, no timers, odds always shown). Re-check age rules for paid random items and gifting before launch. | Research, section 3 |

## 9. Revenue sanity check

A rough check that the plan can pay for itself, not a forecast. Every input is our assumption.

**Assumptions (all unverified):** average daily playtime per daily player 36 minutes, so daily players = average CCU x 40. Creator keeps 70% of Robux spent. DevEx at the standard $0.0038 (our audience is mostly under 18, so the higher U.S. 18+ rate is ignored). Creator Rewards income is left out because its size is unknown.

| Scenario | Average CCU | Daily players | Robux per daily player | Robux spent per day | Earned Robux per day (70%) | USD per month (x $0.0038, 30 days) |
|---|---|---|---|---|---|---|
| Low | 500 | 20,000 | 0.9 | 18,000 | 12,600 | ~$1,400 |
| Mid | 3,000 | 120,000 | 2.5 | 300,000 | 210,000 | ~$23,900 |
| High | 15,000 | 600,000 | 4.5 | 2,700,000 | 1,890,000 | ~$215,500 |

Robux per daily player rose from 0.5 / 1.5 / 3.0 when Reputation, Signature Vehicles and Sea Chests were added: rank speed is what players in this genre buy most, and repeat products (boosts, Sea Time, chests) let big spenders keep spending.

For scale: Firefighting Sim had 19,225 live CCU when checked (https://rblxstat.com/games/10767634248, 2026-10-17), above our high case. The niche's existing sea rescue games were not verified above a few thousand CCU ([`research/reference-games.md`](archive/research/reference-games.md) section 4), near our mid case.

**Does the mid case hold up from the bottom?** 300,000 R$ a day at 3,000 CCU (about 190 servers of 16) could come from:

| Source | Daily volume | Robux |
|---|---|---|
| Storm Summons | 150 a day at 249 R$ (under one per server per day) | ~37,000 |
| Game passes (incl. 2x Reputation) | 450 sales at an average 200 R$ (0.38% of daily players) | ~90,000 |
| Signature Vehicles | 150 sales at an average 230 R$ | ~35,000 |
| Cash packs, Cash boosts, rerolls | 1,200 sales at an average 60 R$ | ~72,000 |
| Rep Boosts, Sea Time, Fast-Track | 900 sales at an average 50 R$ | ~45,000 |
| Sea Chests | 250 paid opens at an average 80 R$ | ~20,000 |
| The 5 R$ row | 600 sales | ~3,000 |
| **Total** | | **~302,000** |

Not counted: the Season Logbook, vehicle cosmetics, gifts, Crew Boosts, Crew Rep Boosts and ad revenue, which are upside. The 5 R$ row earns almost nothing itself; it is counted for the first purchases it brings. None of these rates look extreme, so the mid case is plausible if we reach 3,000 CCU. The big unknown is CCU, not pricing. That depends on the first three minutes and the store page (research, section 5).

**Follow-ups:** sample live pass prices from three to five top job and simulator games; confirm the 30% fee and the subscription tiers on official pages; run Managed Pricing tests (about three weeks each) after launch, starting with 2x Reputation (249 / 349 / 449), Sea Time Credit and the Captain's Chest. Track conversion of 5 R$ buyers to a second purchase.
