# M_Veh_RIB_Helm
dims_m: 1.2 x 2.77 x 1.12
Reference: Atlantic 85 helm console, wheel, throttles, compass, chartplotter, VHF, grab handles, jockey-pod seats.
- Console footprint about 0.8 m wide x 0.5 m deep, top about 1.2 m above the deck (verify).
- Helm wheel diameter about 0.35 m (verify).
- Seat height about 0.5 m above deck (verify).
- Grab handle diameter about 0.03 m (verify).
- Mass: not sourced (verify).
Sources:
- https://en.wikipedia.org/wiki/Atlantic_85-class_lifeboat (hull reference only; console dims not given)
V2 (2026-10-17): dims_m is the helm sub-assembly envelope in the RIB frame (X across the two crew jockey seats,
Y from the console's front grab rail to the crew seats' bolsters, Z deck to grab-rail top), set by the greybox seat
layout in src/shared/Boat/Builder.luau (helm seat 0.53 m aft of the console, crew pair 1.07 m behind it) and the console
above (0.9 m wide, about 1.1 m tall to the rail). Derived, not sourced (verify against photos on the RIB board).
