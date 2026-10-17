# Mayday Sea Rescue: Store Page and Monetization Research

Research date: 2026-10-17. Sources are Roblox Creator Hub (create.roblox.com/docs) and DevForum unless noted. Items marked (unverified) have no primary source or were only found on third-party sites.

---

## 1. Store page assets

**Experience icon**
- Square, at least 512 x 512 px, so it displays sharply across the site and app. Icons shrink to about 150 x 150 px in some places, so preview at that size. Source: https://create.roblox.com/docs/production/publishing/experience-icons (also https://create.roblox.com/docs/production/promotion/game-icons)
- Upload path: Configure > Places > start place (star) > Icon, media type Image. Icon images go through moderation before public display. Source: https://create.roblox.com/docs/production/promotion/game-icons
- Best practice: make the icon unique and relevant to what players will find; ambiguous art confuses players. Source: https://create.roblox.com/docs/production/promotion/game-icons

**Thumbnails (images)**
- Up to 10 images or videos per game detail page. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- 16:9, ideally 1920 x 1080 px. Non-16:9 uploads are stretched to fit. Formats: .jpg, .gif, .png, .tga, .bmp. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Home page personalization uploads: keep under 3 MB and 1920 x 1080. Source: same page, and https://create.roblox.com/docs/production/promotion/promotional-thumbnails
- Thumbnails can be reordered, deleted, and given alt text. Source: https://create.roblox.com/docs/production/promotion/promotional-thumbnails
- Auto-generated thumbnail is free, taken from Studio's camera at the last publish. Source: https://create.roblox.com/docs/production/promotion/promotional-thumbnails

**Thumbnails (video)**
- Free, monthly quota of 3 uploads. Rejected videos still count against the quota. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Must be authentic gameplay footage, reviewed before distribution. Approved videos appear first on the detail page and can also show on the Home page. Source: https://create.roblox.com/docs/production/promotion/promotional-thumbnails
- Not supported on Xbox, PlayStation, or VR headsets. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Length limit, file format, resolution, file size, and age/ID requirements: not stated on the thumbnail pages (unverified; check the upload dialog).

**Personalization and A/B testing**
- Needs 2 to 5 active thumbnails. Personalization starts only with 2 or more active. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Algorithm shows each thumbnail to a random user group, then gives the winner more impressions per group while keeping minimal traffic for others. Metric: qualified play-through rate. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Reported results: average +8.5% qualified play-through rate, some games +50%. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Keep several thumbnails active rather than picking one winner. Test new thumbnails with major updates, then hold them until the next update. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Thumbnail Performance table fills in "after a few hours" (impressions, qualified plays, average playtime, qPTR, winning segment). Source: same page.
- Thumbnail Personalization API endpoints are experimental; a 2026 DevForum recap says OpenCloud APIs cover Analytics, Events, Experiments, and Thumbnails. Source: https://devforum.roblox.com/t/weekly-recap-august-24%E2%80%9328-2026-persistent-leaderboards-opencloud-apis/4836039 (summary from search result; not fetched)

**Thumbnail design advice (from official page)**
- Use sharp, high-quality images that show what players can expect. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails and https://create.roblox.com/docs/production/promotion/promotional-thumbnails
- Keep essential text and elements away from the bottom edge, where the player-count metadata covers them. Source: same pages.
- Use theme and color to communicate tone. Source: https://create.roblox.com/docs/production/promotion/promotional-thumbnails
- Faces, bright contrast, and action shots: common creator advice, not in official docs (unverified).

**Misleading-thumbnail and content rules (official)**
- Do not show mechanics, UI, or interactions the game lacks, or market it as a different genre (example given: a roleplay game marketed as racing). Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Graphics must match real in-game visuals. No enhancements beyond what players see. Source: https://create.roblox.com/docs/production/promotion/promotional-thumbnails
- No real-life footage, external content, voice-overs, narration, voice chat, or music with lyrics. Source: same.
- Text overlays sparingly, only to describe gameplay. No ads, promotions, or subjective claims. Source: same.
- Allowed: varied camera angles, free camera, minor post-processing, curated highlights, in-game UI text, logo overlays, catalog music. Source: https://create.roblox.com/docs/production/promotion/promotional-thumbnails
- Free camera in solo playtest: Left Shift + P (for capturing screenshots). Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails

**Practical implication for Mayday:** a sea rescue game's thumbnails must show real boat, sea, and rescue gameplay from Studio/in-game camera. Stylized or exaggerated lighting that changes fidelity is a risk.

---

## 2. Trailers, video, and marketing

**Gameplay capture**
- Video thumbnails must be real gameplay footage captured in-game (see section 1). Source: https://create.roblox.com/docs/production/promotion/promotional-thumbnails
- Built-in free camera and curated highlight sequences are allowed. Source: same page.
- Voice-over and narration are not allowed in thumbnail video. Source: https://create.roblox.com/docs/en-us/production/publishing/thumbnails
- Length limits for video thumbnails: not stated (unverified).

**Cinematic camera plugins and trailer workflow:** no official Roblox guidance found (unverified). Plan: capture in Studio/in-game with free camera, then edit externally.

**Short-form (TikTok / YouTube Shorts) marketing**
- No official Roblox or platform guide found. Search results were community posts and vendor blogs (unverified).
- DevForum community advice: shorts and TikTok with a good showcase can produce strong free attention without a large following; the game itself must be fun. Source: https://devforum.roblox.com/t/what-is-the-best-method-to-promote-my-game/4016948
- Vendor blog suggests 3 to 5 clips per week from real gameplay. Opinion from a clipping-tool vendor (unverified). Source: https://blog.eklipse.gg/blog/page/5 (not verified in detail)
- Roblox is testing a TikTok-style app ("Roblox Moments") where players share 30-second clips and tap to join games. Source: https://www.bloomberg.com/news/articles/2025-09-05/roblox-tests-tiktok-like-app-so-players-can-share-game-action
- A 2026 report says 35% to 45% of new sessions for 10k+ CCU games trace to creator interactions. Unverified; no primary source found.
- Paid creator posts must be disclosed. Undisclosed paid promotion can break platform rules and advertising laws. Source: https://devforum.roblox.com/t/10k-robuxeasysocial-media-marketers-for-building-game-needed/3876825 (the post itself is an example of what to avoid)

**Roblox Ads Manager (official)**
- Eligibility: 13+ with a verified email. Group-owned games supported. Source: https://create.roblox.com/docs/production/promotion/ads-manager
- Creatives: up to 10 thumbnails in a campaign, shown evenly across players, 16:9 display. Source: same.
- Goals: Plays, Earnings (Limited), Engagement. One goal per campaign. Source: same.
- Bidding is automatic. You set a budget and duration; Roblox calculates the bid. Source: same. (The earlier search summary about manual CPM max bids was not supported by the official page.)
- Budgets: daily or lifetime. Payment by card or ad credits (personal or group). Auto-reload available. Source: same.
- Minimum credit purchase: 1 credit. First-time card users are charged $5 at submission. Source: same.
- Engagement campaigns have a higher cost per play because the audience is smaller. Source: same.
- Give campaigns several days; if no progress after 3 to 5 days, fix onboarding first. Source: same.
- Moderation: ads usually within 24 hours; asset library up to 48 hours. Source: same.
- Cost per play or CPM figures: not published on the official page. Third-party rewarded-video CPM ranges of $5 to $15 are unverified and about a different product. Source: https://rolearn.dev/insights/rewarded-video-ads-new-revenue-stream (not verified in detail)
- Sponsored Items (paid in Robux, a different product) define CPC as Robux spent divided by clicks. Source: https://create.roblox.com/docs/en-us/marketplace/sponsor-items

**Recommended starting budget:** no verified figure. Test with a small daily budget (unverified suggestion: low tens of USD per week) and measure cost per play.

---

## 3. Monetization (2026)

**Game passes vs developer products**
- Passes: one-time purchase for permanent perks (e.g., VIP, 2x). Developer products: consumables that can be bought repeatedly (currency, boosts). Source: https://rowatcher.com/news/developer-products-vs-game-passes-you-re-using-both-wrong (third-party; official create.roblox.com monetization pages could not be fetched, so the wording is unverified against Roblox docs)
- A 30% marketplace fee applies to passes and developer products (creator receives 70% of price). Source: third-party calculator https://profitable.app/tools/roblox-gamepass-calculator (unverified; check the official monetization docs before publishing prices)

**Typical price points (unverified; one third-party guide)**
- 25 to 99 Robux for small perks; 100 to 499 for meaningful upgrades; 500 to 1,500 for game-changing passes; 1,500+ for endgame passes. Source: https://profitable.app/tools/roblox-gamepass-calculator (unverified)
- Example real listings (mixed games, not a single simulator): "2x Millionaire Simulator" pass 110 Robux; "Double Money" 199 Robux. Source: https://www.rolimons.com/gamepass/9418967 (unverified; prices change)
- Super VIP pass 20 Robux in a different game (Robloxaville). Source: https://roblox.fandom.com/wiki/Player:Playrobot/Robloxaville (unverified; not a simulator)

**Premium Payouts: deprecated**
- Engagement-Based Payouts (Premium Payouts) was deprecated effective 2025-07-24. Source: https://create.roblox.com/docs/production/monetization/premium-payouts (fetched; the page confirms deprecation)
- Replaced by Creator Rewards (called "Daily Engagement Rewards" in the DevForum announcement). Creators were auto-enrolled. Source: https://devforum.roblox.com/t/creator-rewards-is-live/3838257
- Earnings are credited after a 60-day holding period. Source: search summary of Creator Rewards DevForum posts (unverified exact wording). Developers reported lower income after the change. Source: https://devforum.roblox.com/t/shorten-the-hold-period-of-engagement-payouts-or-restore-the-old-premium-payouts-system/3956591
- Audience Expansion Reward: 35% revenue share on the first $100 of Robux purchases by new or returning users in the first two months (replaces Creator Affiliate). Source: unverified, from search summary only.

**Subscriptions in experiences**
- Subscriptions are regionalized automatically and excluded from price optimization tests. Source: https://create.roblox.com/docs/production/monetization/managed-pricing (fetched)
- Subscription price points and example pass lineups: not researched (unverified).

**Regional pricing and price optimization (Managed Pricing)**
- Single opt-in system combining price optimization and regional pricing. Source: https://create.roblox.com/docs/production/monetization/managed-pricing (fetched)
- Regional prices bound to 30% to 100% of the default price, based on purchasing power, exchange rates, and local spending. Source: same.
- New games and items are enrolled by default; individual items can opt out. Source: same.
- Passes are regionalized by default. Developer products are opt-in per product, and require GetUsersPriceLevelsAsync to prevent gifting/trading arbitrage between price levels. Source: https://create.roblox.com/docs/en-us/production/monetization/regional-pricing (search summary; fetched excerpt limited)
- Hard-coded prices in the UI do not update. Fix them before opting in. Source: https://create.roblox.com/docs/production/monetization/managed-pricing
- Price optimization tests run about 3 weeks, with an email when done. Source: https://create.roblox.com/docs/en-us/production/monetization/price-optimization (search summary)
- Roblox DevForum reports +4% to +10% overall Robux spend and +43% to +52% pass purchases in discounted regions. Roblox-reported, not independently verified. Source: DevForum Managed Pricing post https://devforum.roblox.com/t/managed-pricing-one-system-for-better-pricing-and-earnings-growth/4684738 (from search summary)

**DevEx (official, fetched)**
- Standard rate: $0.0038 USD per Earned Robux ($114 for 30,000). Source: https://create.roblox.com/docs/production/monetization/developer-exchange
- Higher rate: 0.0054 for certain Earned Robux from eligible games, when purchases are made by U.S. players verified as 18+ (applies to developer products, passes, subscriptions, private servers). Source: same.
- Before 2025-09-05 10:00 PT the rate was 0.0035. Source: same.
- Minimum: 30,000 Earned Robux. Creators must be 13+. Need a verified email, DevEx Portal account, and W-8/W-9 on file. Source: same.
- Correction to third-party claims: the official page does not require Roblox Premium for DevEx. Third-party sites still list $0.0035 as current; disregard.

**Paid random items (official, fetched)**
- Applies to random items bought with Robux or Robux-purchasable currency. Covers capsules (prize wheels, eggs, chests), enhancements, combinations, and probability modifiers (luck boosts, pity systems). Source: https://create.roblox.com/docs/en-us/production/monetization/paid-random-items
- Disclose every outcome and its numerical odds before purchase, as percentages that total exactly 100%. Source: same.
- Too many outcomes: a clickable pop-up with a descriptive label. A bare "(i)" icon is not sufficient. Source: same.
- Luck-boosting items must explain their numeric effect and update the odds while active. Source: same.
- Gameplay-earned randomness without Robux or paid currency needs no odds disclosure. Source: same.
- Restricted users (PolicyService ArePaidRandomItemsRestricted): hide, replace, block, or give an unpaid path. Trading restricted for IsPaidItemTradingAllowed = false. Source: same, and https://create.roblox.com/docs/production/promotion/experience-guidelines
- Paid random items must be disclosed in the maturity questionnaire. Source: https://create.roblox.com/docs/production/promotion/experience-guidelines (fetched)

**Gambling and pay-to-win**
- Gambling is exchanging real money, Robux, or items for a game of chance. Playable gambling, including simulated gambling, is not allowed. Depicting unplayable casinos is allowed. Source: https://create.roblox.com/docs/production/promotion/experience-guidelines (fetched)
- No official pay-to-win policy text found. Treat as unverified; keep paid advantages cosmetic or convenience-based to be safe.

**Age guidance and under-13 purchases**
- Maturity label determines age access: Minimal and Mild for Roblox Kids (5-8) and Select (9-15); Moderate for Select and 16+; Restricted for age-verified 18+. Source: https://create.roblox.com/docs/production/promotion/experience-guidelines (fetched)
- Kids and Select audiences need extra publishing requirements (separate page, not fetched).
- Official docs do not address purchase restrictions for under-13 users in general (unverified). Paid random item restrictions depend on PolicyService, not age alone.
- Experiences without a completed questionnaire: the two official pages disagree (treated as 13+ vs Moderate). Complete the questionnaire. Source: https://create.roblox.com/docs/production/promotion/content-maturity (search summary)
- The questionnaire uses the most mature content a player could encounter; account must be at least 30 days old. Source: https://create.roblox.com/docs/en-us/production/promotion/content-maturity (search summary)

---

## 4. Pass lineups in simulator / job games

- No verified, complete lineup for a single simulator found. Examples found: 2x money pass at 110 and 199 Robux; Super VIP at 20 Robux (different game). Sources: see section 3 (unverified).
- Common categories (genre knowledge, unverified): VIP (perks and chat tag), 2x cash or money, faster or exclusive vehicle, extra slots or storage, boombox or radio, auto-collect.
- Recommended research next step: open the store pages of 3 to 5 top simulator and rescue or job games in the Roblox catalog and record pass names, prices, and perks. Rolimons (https://www.rolimons.com) tracks price history.

---

## 5. Retention and engagement norms

**Discovery signals (official, fetched)**
- Main signals for the Recommended for You sort: play-through rate, first-play bounce rate, play days per user, playtime per user. Source: https://create.roblox.com/docs/discovery.md
- Important signals: intentional co-play days, qualified play sessions per user, spend days per user, Robux spent per user. Source: same.
- Measured across windows Day 1, Day 2-7, and Day 8-28. Source: same, and https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox (search summary)
- First-play bounce bands: under 60 seconds and 61 to 180 seconds (negative signal). Source: https://create.roblox.com/docs/discovery.md
- Playtime counts up to 60 minutes per user, per game, per day. Source: same.
- Signals use per-user averages, so small games with engaged players are not penalized. Source: same.
- Signals come only from users who joined organically from the sort. Source: same.
- Benchmarks shown in Creator Analytics do not affect the algorithm. Their numeric values are not published on the docs page. Source: same.
- Qualified play-through rate (qPTR) is engaging plays divided by impressions from Recommended for You (search summary of Roblox docs; the discovery page itself uses "play-through rate"). Source: https://create.roblox.com/docs/discovery

**Retention targets**
- No official D1, D7, or session-length targets found. Numbers from third-party blogs are not verified. (unverified)
- Recommendation: set internal targets from the Creator Analytics benchmark overlay after launch, and track first-play bounce (target: fewer players leaving before 180 seconds).

**Key takeaway for Mayday**
- The first 3 minutes decide discovery: fast onboarding into a rescue, a clear first win, and no long tutorial walls. Playtime and co-play matter more than raw visits.

---

## Open questions / follow-ups

- Confirm current pass and product price norms by sampling live simulator stores.
- Confirm the 30% marketplace fee and the 60-day holding period on official monetization pages (not fetched).
- Get the official Roblox trailer or Shorts guidance, if any exists.
- Check the Creator Analytics benchmark values after launch.
