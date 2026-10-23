# Roblox badges: create these on the Creator Hub

Every badge below lives in `src/shared/Config/BadgeConfig.luau` with `id = 0` (off). Create the badge
in the Creator Hub, paste its id into that entry, and the server awards it through `BadgeService`.
Progress counters already run while an id is 0, so a badge switched on later is awarded to players who
already qualify.

Names and descriptions must match the Creator Hub text (the config is the source of truth). "Key" is
the `BadgeConfig.Badges` key; "How to earn" is for this doc only, not the store page.

| Key | Name | Description (store page) | How to earn | Icon concept |
|---|---|---|---|---|
| FirstRescue | First Rescue | Finish your first rescue operation. | Finish any call with a passing grade (not failed or taken over by the NPC boat). | A life ring with a boat hook |
| SmoothRide | Smooth Ride | Bring survivors home with a smooth ride 10 times. | Finish 10 calls with the debrief's smooth-ride icon lit: every one of your rides home graded Gold. | A boat on a flat gold wake |
| RankLifeguard | Lifeguard | Reach the rank of Lifeguard. | Reach rank 2 (400 Rep). | A lifeguard tower and flag |
| RankRescueSwimmer | Rescue Swimmer (rank) | Reach the rank of Rescue Swimmer. | Reach rank 3 (900 Rep). | A rescue swimmer's fins |
| FirstWildlife | First Wildlife Rescue | Free your first animal in a wildlife rescue. | Finish a wildlife call with a passing grade. | A life ring with a paw print in the middle |
| AllWildlife | Sanctuary Five | Rescue all five wildlife species. | Rescue a seal pup, puffin, otter, turtle and gull. | Five animal silhouettes around a life ring |
| FirstPet | First Pet | Adopt your first pet at the sanctuary. | Adopt a recovered animal at the sanctuary pens. | A paw print inside a heart |
| Streak7 | Seven-Day Streak | Open the daily crate seven days in a row. | Open the daily crate at your bay on 7 consecutive UTC days. | Seven lit lanterns in a row |
| Streak30 | Thirty-Day Streak | Open the daily crate thirty days in a row. | Open the daily crate at your bay on 30 consecutive UTC days. | A calendar page with thirty lit lanterns |
| EveryCall | Every Call | Complete every call type once: person in the water, cliff, rip current, sinking boat, boat on fire and wildlife. | Finish each of the 6 call types at least once (drifting dinghies count as person in the water). | Six small icons in a ring |
| LifeboatBought | Lifeboat | Buy the All-Weather Lifeboat. | Buy the Lifeboat in the phone's Vehicles app (12,000 Cash, rank 4). | A lifeboat bow on over a crest |
| RankCoxswain | Coxswain | Reach the rank of Coxswain. | Reach rank 4 (3,000 Rep). | A coxswain's cap over a lifeboat bow |
| Rescue100 | Hundred Rescues | Finish 100 rescues. | Finish 100 calls with a passing grade. | A life ring with 100 on it |
| RankCaptain | Captain | Reach the rank of Captain. | Reach rank 6 (22,000 Rep). | A captain's cap with a gold anchor |
| RankAdmiral | Admiral | Reach the rank of Admiral. | Reach rank 8 (150,000 Rep). | An admiral's shoulder board with four stars |
| FriendCrew | Crew Up | Join a crew with a friend. | Join a Roblox friend's crew, or have one join yours (boat prompt or the phone's Crew app). | Two clasped hands over a boat deck |
| PhotoFirst | First Shot | Take your first photo in photo mode. | Press the shutter in the phone's Camera app. | A camera shutter with a wave inside |
