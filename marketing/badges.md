# Roblox badges: create these on the Creator Hub

Every badge below lives in `src/shared/Config/BadgeConfig.luau` with `id = 0` (off). Create the badge
in the Creator Hub, paste its id into that entry, and the server awards it through `BadgeService`.
Progress counters already run while an id is 0, so a badge switched on later is awarded to players who
already qualify.

Names and descriptions must match the Creator Hub text (the config is the source of truth). "Key" is
the `BadgeConfig.Badges` key; "How to earn" is for this doc only, not the store page.

| Key | Name | Description (store page) | How to earn | Icon concept |
|---|---|---|---|---|
| FirstRescue | First Rescue | Finish your first rescue operation. | Finish any operation with a passing grade. | A life ring with a boat hook |
| CertHelm | Helm | Pass the Helm certification. | Pass the Helm exercise. | A ship's wheel |
| CertCasualtyCare | Casualty Care | Pass the Casualty Care certification. | Pass the Casualty Care exercise. | A first-aid cross on a life ring |
| CertRescueSwimmer | Rescue Swimmer | Pass the Rescue Swimmer certification. | Pass the Rescue Swimmer exercise. | A swimmer pulling a casualty |
| CertCoxswain | Coxswain | Pass the Coxswain certification. | Pass the Coxswain exercise (the "Coxswain certified" badge). | A coxswain's cap over a lifeboat bow |
| Downwind | Downwind | Make 10 approaches graded Gold. | Land 10 Gold approach steps (any calls). | A bow cutting a gold wake |
| TowTruck | Tow Truck | Finish a tow without parting the line. | Complete a disabled-vessel tow with the line intact. | A tow line and cleat |
| StormChaser | Storm Chaser | Finish an operation you were tasked to during a storm. | Complete any call accepted while a storm is running. | A boat on a steep wave |
| RankLifeguard | Lifeguard | Reach the rank of Lifeguard. | Reach rank 2 (Rep + Helm). | A lifeguard tower and flag |
| RankRescueSwimmer | Rescue Swimmer (rank) | Reach the rank of Rescue Swimmer. | Reach rank 3 (Rep + Rescue Swimmer). | A rescue swimmer's fins |
| FerryHero | Ferry Hero | Bring a casualty home from a Capsized Ferry. | Finish a big ferry call with at least one survivor saved. | A ferry with a life ring |
| AirPocket | Air Pocket | Lead a trapped passenger out of the air pocket. | Complete the air-pocket step on a ferry call. | A hand reaching through water |
| FirstWreck | First Wreck | Find the Morwenna in Calm Bay. | Find the Morwenna in the logbook (award hook still pending). | A wreck under a wave |
| FirstWildlife | First Wildlife Rescue | Free your first animal in a wildlife rescue. | Finish a wildlife call with a passing grade. | A life ring with a paw print in the middle |
| AllWildlife | Sanctuary Five | Rescue all five wildlife species. | Rescue a seal pup, puffin, otter, turtle and gull. | Five animal silhouettes around a life ring |
| FirstPet | First Pet | Adopt your first pet at the sanctuary. | Adopt a recovered animal at the sanctuary pens. | A paw print inside a heart |
| LegendaryRescue | Legendary Rescue | Finish a Legendary rarity call. | Finish any Legendary rarity call (the Golden Gull). | A gold star over a rescue boat |
| GoldenGull | Golden Gull | Bring in the Golden Gull. | Rescue the Golden Gull variant. | A golden gull with spread wings |
| AlbumSet | Set Complete | Complete any Rescue Album set. | Collect every sticker of one call kind. | A full page of stickers with one gold frame |
| AlbumComplete | Full Album | Collect every sticker in the Rescue Album. | Collect every sticker in every set. | A closed sticker album with a gold clasp |
| Streak7 | Seven-Day Streak | Open the daily crate seven days in a row. | Claim the porch crate on 7 consecutive UTC days. | Seven lit lanterns in a row |
| Streak30 | Thirty-Day Streak | Open the daily crate thirty days in a row. | Claim the porch crate on 30 consecutive UTC days. | A calendar page with thirty lit lanterns |
| GreatStormRescue | Great Storm Rescue | Finish a rescue during a Great Storm. | Complete any call while the hourly Great Storm is active. | A boat on a huge wave under a dark sky |
| GhostShip | Ghost Ship | Finish a Ghost Ship rescue during Halloween 2026. | Complete a Ghost Ship call during 24 Oct to 2 Nov 2026 (UTC). | A green-glowing ghost ferry in fog |
| SeasonTier10 | Season One: Tier 10 | Reach tier 10 of Season 1. | Earn Season XP to tier 10 (24 Oct to 5 Dec 2026). | A bronze season badge with a 10 |
| SeasonTier30 | Season One: Tier 30 | Reach tier 30 of Season 1. | Earn Season XP to tier 30 (24 Oct to 5 Dec 2026). | A gold season badge with a 30 |
| EveryCall | Every Call | Complete every operation type once: swimmer, tow, ferry, cliff, rip current, sinking, fire and wildlife. | Finish each of the 8 operation kinds at least once. | Eight small icons in a ring |
| LifeboatBought | Lifeboat | Buy the All-Weather Lifeboat. | Buy the Lifeboat from the boat shop (12,000 Cash, rank 4). | A lifeboat bow on over a crest |
| RankAdmiral | Admiral | Reach the rank of Admiral. | Reach rank 8 (all six certifications). | An admiral's shoulder board with four stars |
| FriendCrew | Crew Up | Join a crew with a friend. | Join a crew that contains a Roblox friend. | Two clasped hands over a boat deck |
| PhotoFirst | First Shot | Take your first photo in photo mode. | Take a photo in photo mode (no server remote yet: id stays 0). | A camera shutter with a wave inside |
