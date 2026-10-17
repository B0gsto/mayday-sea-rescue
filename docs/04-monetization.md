# 04 · Monetization

This file owns every Robux price. Cash prices and progression live in [`03-progression.md`](03-progression.md). Research references point to [`research/store-page-and-monetization.md`](research/store-page-and-monetization.md) (shortened to "research") and to the source links it records. Prices marked **(tune)** are first guesses; Managed Pricing tests (section 9) will move them.

## 1. Stance

Fair, cosmetic or convenience first. A player who never pays can reach every rank, vehicle, zone and badge at the pace in [document 03](03-progression.md).

Rules for every item:

1. **Never sell Reputation directly.** No Robux item adds Rep, multiplies it or skips a rank gate. Mayday is PvE, so convenience that saves time (Cash, launches, boosts) is fair: it never takes anything from another player.
2. **No paid random items at launch.** Every purchase gives exactly what it says.
3. **Paid vehicles do not exist.** Rank gates every vehicle and zone, and Reputation is never sold. Robux only shortens the Cash grind (Cash packs, 2x Cash, which can speed up stat upgrades) and buys cosmetics.
4. **State the effect in numbers.** Every product card says exactly what it gives ("Doubles Cash from calls and challenges. Does not affect Reputation.") before the Roblox prompt opens.
5. **The player opens every prompt.** A purchase prompt opens only after the player taps a button that shows the Robux price. The game never pops a prompt by itself.
6. **Nothing priced in the first three calls.** A new player sees no shop, no prices and no offers until the tutorial chain is three calls in.
7. **No pressure.** No countdown timers, no "last chance", no fake scarcity, no messages that shame a player for saying no.

## 2. Price anchors from the research

| Anchor | Value | Source |
|---|---|---|
| Typical pass bands | 25 to 99 R$ small perks; 100 to 499 meaningful; 500 to 1,500 game-changing | https://profitable.app/tools/roblox-gamepass-calculator (research, section 3; unverified third-party guide) |
| 2x money passes seen | 110 R$ and 199 R$ | https://www.rolimons.com/gamepass/9418967 (research, section 3; unverified, prices change) |
| Marketplace fee | Creator keeps about 70% | https://profitable.app/tools/roblox-gamepass-calculator (unverified; confirm on the official monetization pages) |
| DevEx rate | $0.0038 per Earned Robux standard; $0.0054 for some purchases by verified U.S. 18+ players | https://create.roblox.com/docs/production/monetization/developer-exchange |
| Firefighting Sim passes | None found | https://rblxstat.com/games/10767634248 ([`research/reference-games.md`](research/reference-games.md) section 1; unverified) |

We keep every single item between 19 and 699 R$. Only two items sit in the 500 to 1,500 "game-changing" band, the Harbor Fund Cash pack (599 R$) and Call the Great Storm (699 R$), and neither changes the game: one is Cash that play also earns, the other is a server-wide event everyone shares. Nothing costs more than 699 R$.

## 3. Game passes

One-time purchases, permanent. All are [L] unless marked.

| Pass | Price (tune) | What it gives | Why this price and why it is fair |
|---|---|---|---|
| **2x Cash** | 199 R$ | Doubles Cash from calls, big calls and challenges. Does not touch Reputation. | The genre's best-known pass; 199 matches a real 2x listing. Convenience only: rank still gates every vehicle ([document 03](03-progression.md), section 10.2). |
| **VIP Crew Card** | 299 R$ | Gold nameplate and radio tag, VIP Gold livery for every vehicle, access to the VIP deck on the station roof, one free daily challenge reroll. | Status and social, the classic VIP bundle. The reroll is a small convenience, also sold separately for 19 R$. |
| **Quick Launch** | 149 R$ | Skips the launch cooldown and the walk to your bay: launch any owned vehicle straight from the station or an outpost you have opened. Never affects call timers or grades. | Convenience only. Free players reach the same through Slipway upgrades (no cooldown and outpost launches at level 3, [document 03](03-progression.md), section 6). |
| **Bosun's Wardrobe** | 129 R$ | Three Newfoundland coat colours (Landseer black-and-white, brown, grey), six bandanas, a dog life jacket, a tiny captain's hat. | Pure cosmetic on the game's most loved character. Small-perk band. |
| **Water Dog Friends** | 199 R$ | Two extra companions to swap with Bosun: a Labrador and a Portuguese Water Dog (both real water working breeds). Same abilities as Bosun. | Cosmetic variety. Abilities are identical, so no advantage. |
| **Storm Chaser Liveries** | 249 R$ | Animated lightning-stripe liveries for every vehicle (new vehicles included), plus a storm-blue uniform. | Premium cosmetic. Shows well in storm screenshots and in the server's top-crews board. |
| **Captain's Locker** | 99 R$ | Uniform set: bright wetsuit, foul-weather coat, three caps, a whistle emote. | Low-price cosmetic for younger players. |
| **Sea Shanty Radio** | 79 R$ | An in-vehicle radio playing the game's own music tracks (cleared catalog or commissioned audio). Other players can mute it. | Social fun, a common genre pass. |
| **Starter Kit** | 99 R$ | 3,000 Cash once, the "Station Orange" livery for the board, jet ski and RIB, a Bosun bandana. Can be bought once, any time. | A gentle first purchase. Always available, no timer. 3,000 Cash is about 30 minutes of Calm Bay play. |

### 3.1 Season Logbook

| | |
|---|---|
| Price | 399 R$ per season (tune; stays in the 299 to 499 band). A developer product bought once per season. [L] |
| What it is | A cosmetic-only reward track for each season (about 8 weeks). Every player earns logbook stamps from normal play (calls, storms, big calls, challenges). The free track pays a cosmetic every few stamps; the paid track adds a cosmetic on every stamp: liveries, uniforms, Bosun coats, horns, wake trails, a season trophy for the bay. |
| Never gives | Cash, Rep, gear, vehicles or anything with stats. |
| Fairness | Buying late unlocks every paid tier already stamped, so there is no reason to rush. The season end date is shown plainly on the logbook page, never as a countdown banner. |

### 3.2 Vehicle cosmetics

Pure cosmetics that show on every owned vehicle. None use the reserved signal colours ([document 05](05-art-direction.md), section 3.2). Other players can mute horns and sirens. [L]

| Pass | Price (tune) | What it gives |
|---|---|---|
| **Horn Pack** | 79 R$ | Six horns (foghorn, ferry whistle, duck honk, shanty riff, and two more), on a tap button. |
| **Siren Pack** | 99 R$ | Four siren tones with matching light patterns. |
| **Light Bars** | 129 R$ | Six light bar colour sets for every vehicle. |
| **Wake Trails** | 149 R$ | Five wake trails (sparkle foam, rainbow, bubbles, petals, glow). |

Single horns and trails also come from the Season Logbook and Service Stars ([document 03](03-progression.md), section 3).

### 3.3 Gifting

Every pass and cosmetic card has a **Gift** button. The buyer picks a friend in the same server; the friend gets the item and a thank-you note with a Bosun paw print. Items the friend already owns are greyed out. Gifts are developer products that grant the item to the chosen player, because game passes themselves cannot be transferred (verify current Roblox rules for gifting and any age limits before launch). [L]

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

Where Roblox allows them, a player can choose to watch a rewarded video ad from a **Watch for a bonus** button on the bay terminal: +50% Cash for 15 minutes of playtime or one challenge reroll (tune), up to three a day. Never Rep, never during a call, never shown automatically. The button appears only for players and regions Roblox marks eligible. Verify the current rules before building: viewer age and region eligibility, experience eligibility, the API, and what rewards are allowed. [L]

## 5. Storm Summon (server-wide social event)

The paid storm is our version of an "admin abuse" event: one player pays, the whole server gets the fun, and the buyer gets the credit. It fits pillar 2 (the sea is the opponent) and the discovery signal for intentional co-play (research, section 5, https://create.roblox.com/docs/discovery.md).

| | Call the Storm (249 R$) | Call the Great Storm (699 R$) |
|---|---|---|
| Length | Standard storm: 60 s warning, 3 min storm, 60 s clearing | 60 s warning, 4 min storm, 60 s clearing with fireworks over Port Haven |
| Big call | Normal storm odds | Guaranteed: Capsized Ferry or Trawler on the Rocks. From [P1], Cruise Ship Aground if the server has not had one in the last hour |
| Cash bonus for everyone | x1.5 | x2 |
| Reputation | Normal rate (no storm bonus) | Normal rate (no storm bonus) |
| Buyer gets | Name on the radio ("Storm called in by @name"), a "Storm Caller" radio title for 24 hours, a thank-you button for others | The same, plus the name on the station board for the rest of the server's life |

Rules (tune):

1. **Rep is never boosted by a paid storm.** The extra calls still give normal Rep, but the x1.5 storm bonus applies to Cash only. This keeps "never sell Reputation" strict. Natural storms keep the full bonus.
2. **Queue, never stack.** Summons wait in a server queue. At least 8 minutes between summoned storms, and none within 2 minutes of a natural storm. The natural storm clock is not reset.
3. **Max queue of two.** When the queue is full, the button greys out with "Storm queue full, try again soon". It never takes Robux for a storm that cannot run.
4. **Calm Bay stays sheltered**, so new players are not swamped by someone else's purchase.
5. **Anonymous option.** A buyer can turn off the name announcement.
6. **Works in private servers** with the same rules.
7. **Delivery guarantee.** If the server shuts down before a queued storm runs, the purchase is refunded as a "Storm Ticket" the player can use in any server.

## 6. Private servers and subscription

### 6.1 Private server

**Price: 99 R$ per month (tune).** [L]

Why: crews of friends are our best players, and a private server lets them run storms together without strangers. 99 R$ is low enough to be easy for a friend group. Firefighting Sim's description advertises free private servers, though its stats panel says private servers are off ([`research/reference-games.md`](research/reference-games.md) section 1, unverified). We considered free private servers as a marketing hook and decided against it at launch, because 16-player public servers need people in them for big calls to work. If public servers fill well, we revisit free private servers as a marketing beat.

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
| Reputation, ranks, rank skips | Rank is the proof a player did the work. Canon rule. |
| Zone or lighthouse access | Lighthouses need the rank and the mission. |
| Vehicles with better stats | Every vehicle is gated by rank, which Robux cannot buy. Robux only shortens the Cash grind toward vehicles and upgrades, and buys cosmetics. |
| Rescue success | No "auto-rescue", no skipping a mini-task, no instant finish, no victim location reveal. |
| Paid random items | No crates, eggs, wheels or luck boosts at launch. |
| Protection or advantage over other players | There is no PvP, and nothing paid can block, push or out-claim another player. |
| Bosun himself | Every player gets Bosun free. Paid dogs are cosmetic swaps. |
| Badges | Every badge is earned by play. |

## 8. Policy compliance notes

| Topic | What the rule says | What we do | Source |
|---|---|---|---|
| **Paid random items** | Random items bought with Robux need every outcome and its odds shown before purchase, totalling 100%; luck boosts must show their effect; restricted users must be blocked or given an unpaid path. | None at launch. If ever added, follow the full rule and use PolicyService `ArePaidRandomItemsRestricted`. Free daily gifts are fixed, not random. | https://create.roblox.com/docs/en-us/production/monetization/paid-random-items |
| **Gambling** | Playable or simulated gambling is not allowed. | No spins, no wagers, no chance games of any kind. | https://create.roblox.com/docs/production/promotion/experience-guidelines |
| **Misleading thumbnails and claims** | Show only mechanics, UI and visuals that exist in game; no subjective claims or ads in text overlays; no real-life footage or voice-over. | Store art is real in-game captures of real calls. No "best rescue game" text. Product cards state exact effects. | https://create.roblox.com/docs/production/promotion/promotional-thumbnails and https://create.roblox.com/docs/en-us/production/publishing/thumbnails |
| **Age and maturity** | The maturity label decides who can play: Minimal and Mild reach Roblox Kids (5 to 8) and Select (9 to 15). Kids and Select have extra publishing requirements. | Target Minimal or Mild. Complete the questionnaire before launch. Read the Kids/Select requirements page (not yet fetched). | https://create.roblox.com/docs/production/promotion/experience-guidelines |
| **Regional pricing** | Passes are regionalized by default (30% to 100% of the default price). Developer products are opt-in and need `GetUsersPriceLevelsAsync` (verify). Hard-coded prices in UI do not update. | Read every price from MarketplaceService at runtime. Opt Cash packs and boosts in only after the price-level check is built. Storm Summons opt in last, since they affect the whole server. | https://create.roblox.com/docs/production/monetization/managed-pricing |
| **Rewarded video ads** | Eligibility, placement and reward rules are set by Roblox (not researched). | Opt-in button only, Cash or reroll rewards only, hidden for ineligible players. | Verify on the Creator Hub ads pages before building |
| **Gifting** | Not researched. | Gift only to players in the same server; exact effect shown before purchase. | Verify on the Creator Hub monetization pages |
| **Paid creator promotion** | Paid posts must be disclosed. | Any paid YouTuber or TikTok deal is disclosed in the post. | Research, section 2 |
| **Pay-to-win** | The research found no official pay-to-win policy text (unverified). | Everything we sell stays cosmetic or convenience-only. Nothing paid changes rank, Reputation, call timers or grades. | Research, section 3 |
| **Young audience** | No official rule found on under-13 purchases (unverified). | We follow our own section 1 rules, which are stricter than the platform's. | Research, section 3 |

## 9. Revenue sanity check

A rough check that the plan can pay for itself, not a forecast. Every input is our assumption.

**Assumptions (all unverified):** average daily playtime per daily player 36 minutes, so daily players = average CCU x 40. Creator keeps 70% of Robux spent. DevEx at the standard $0.0038 (our audience is mostly under 18, so the higher U.S. 18+ rate is ignored). Creator Rewards income is left out because its size is unknown.

| Scenario | Average CCU | Daily players | Robux per daily player | Robux spent per day | Earned Robux per day (70%) | USD per month (x $0.0038, 30 days) |
|---|---|---|---|---|---|---|
| Low | 500 | 20,000 | 0.5 | 10,000 | 7,000 | ~$800 |
| Mid | 3,000 | 120,000 | 1.5 | 180,000 | 126,000 | ~$14,400 |
| High | 15,000 | 600,000 | 3.0 | 1,800,000 | 1,260,000 | ~$143,600 |

For scale: Firefighting Sim had 19,225 live CCU when checked (https://rblxstat.com/games/10767634248, 2026-10-17), above our high case. The niche's existing sea rescue games were not verified above a few thousand CCU ([`research/reference-games.md`](research/reference-games.md) section 4), near our mid case.

**Does the mid case hold up from the bottom?** 180,000 R$ a day at 3,000 CCU (about 190 servers of 16) could come from:

| Source | Daily volume | Robux |
|---|---|---|
| Storm Summons | 150 a day at 249 R$ (under one per server per day) | ~37,000 |
| Game passes | 400 sales at an average 180 R$ (0.33% of daily players) | ~72,000 |
| Cash packs, boosts, rerolls | 1,200 sales at an average 60 R$ | ~72,000 |
| **Total** | | **~181,000** |

Not counted: the Season Logbook, vehicle cosmetics, gifts, Crew Boosts and ad revenue, which are upside. None of these rates look extreme, so the mid case is plausible if we reach 3,000 CCU. The big unknown is CCU, not pricing. That depends on the first three minutes and the store page (research, section 5).

**Follow-ups:** sample live pass prices from three to five top job and simulator games; confirm the 30% fee and the subscription tiers on official pages; run Managed Pricing tests (about three weeks each) after launch.
