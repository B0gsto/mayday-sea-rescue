# Real Maritime Search and Rescue Procedures: Research Notes for Game Mechanics

Research date: 2026-10-17. Purpose: source material for realistic mechanics in the Roblox sea rescue game.

## How to read this file

- **[VERIFIED]** The procedure was read in a fetched source. The URL is given.
- **[PARTIAL]** A search snippet or secondary source supports it, but the primary text was not read.
- **[UNVERIFIED]** General maritime knowledge that I did not confirm against a source in this session. Do not ship it as fact until checked against the listed authoritative document.

### Source access problems (important)

Most primary agency sites returned HTTP 403 or 404 to the fetch tool: RNLI (rnli.org safety pages), USCG IAMSAR and Rescue Swimmer manual (media.defense.gov, uscg.mil), Red Cross, NOAA rip current page, gov.uk MAYDAY page, and the IMO MSC.1/Circ.1447 PDF (binary, unreadable). The Canadian Coast Guard search chapter PDF also did not extract. Items that depend on those documents are marked accordingly. Verifying them needs a browser download of the PDFs or manual copy-paste.

---

## 1. MAYDAY / PAN-PAN / SECURITE radio procedure

### 1a. Priority words and sequence [PARTIAL]

- **MAYDAY**: grave and imminent danger. Spoken three times at the start of the call. Source: https://www.safe-skipper.com/sending-distress-signals and https://www.understandupsc.com/mayday/
- **PAN-PAN**: very urgent, but not grave and imminent danger. Spoken three times, then "all stations" three times, then the vessel identity. Source: same sources.
- **SECURITE**: navigation or weather safety message. Three times. Source: https://ialacolreg.com/en/gmdss/gmdss-modulo-11-procedimientos-socorro (IALA GMDSS Module 11).

### 1b. Distress message structure [PARTIAL]

Order of content: distress signal, vessel identity, position, nature of distress, assistance required, additional information (persons on board, etc.), then "over".
- Source: https://www.safe-skipper.com/sending-distress-signals , https://ialacolreg.com/en/gmdss/gmdss-modulo-11-procedimientos-socorro

Step-by-step (as typically taught, consistent across the sources above):
- Confirm the channel. GMDSS: DSC distress alert first (VHF Ch 70 or MF 2187.5 kHz), then the voice call on VHF Ch 16 or MF 2182 kHz. Source: safe-skipper and IALA links above.
- Call "MAYDAY MAYDAY MAYDAY", then "this is" and the vessel name and callsign or MMSI, three times.
- Give position, nature of distress, assistance required, number of persons on board, and any other details.
- End with "over". The station acknowledges, and the coordinator takes over.

### 1c. Coordination centre tasking and silence [PARTIAL]

- If a coast station does not acknowledge a distress call, another capable station must relay. Source: https://www.safe-skipper.com/sending-distress-signals
- The RCC can impose radio silence with "SEELONCE MAYDAY" and lift it with "SEELONCE FEENEE". Source: https://ialacolreg.com/en/gmdss/gmdss-modulo-11-procedimientos-socorro
- **Format of the RCC tasking message to a unit** (e.g. "search area, datum, unit assignment, pattern"): [UNVERIFIED] Check IAMSAR Vol II, search and rescue planning, at https://www.imo.org/ (IAMSAR is a joint IMO/ICAO publication).

### 1d. Phonetic alphabet [UNVERIFIED]

ICAO/ITU alphabet: Alfa, Bravo, Charlie, Delta, Echo, Foxtrot, Golf, Hotel, India, Juliett, Kilo, Lima, Mike, November, Oscar, Papa, Quebec, Romeo, Sierra, Tango, Uniform, Victor, Whiskey, X-ray, Yankee, Zulu. Numbers: spoken digit by digit, with "niner" for 9 (ICAO). Verify in ITU-R M.1171 or the ICAO Annex 10 at https://www.itu.int/ .

### 1e. Lifeboat report: POB, position, ETA [UNVERIFIED]

- Typical lifeboat/casualty report elements: number of persons on board (POB), position, estimated time of arrival (ETA), vessel condition, casualty condition. Check RNLI guidance at https://www.rnli.org/ (blocked in this session).

### Equipment
- VHF radio (fixed or handheld), DSC controller, EPIRB or PLB for satellite alert. Source for GMDSS equipment: IALA links above.

### Crew roles
- Radio operator or skipper sends the call. The coordinator (RCC) takes over. Relaying station may repeat the call.

### Common mistakes and consequences
- Using MAYDAY for a non-grave situation. Consequence: wasted resources, and credibility loss later. [UNVERIFIED consequence, general practice]
- Omitting the position. Consequence: rescue delay. Position is the first thing that can be missed under stress.
- Not saying "over" or stopping transmission. Consequence: channel is blocked and others cannot reach the RCC.

---

## 2. Recovering a person in the water from a boat

### 2a. Manoeuvres: Williamson and Anderson turns [VERIFIED, secondary wiki]

Source: https://en.wikipedia.org/wiki/Man_overboard_rescue_turn (fetched in this session; Wikipedia is secondary, check against an IMO/MCA/USCG publication before relying on it).

**Anderson (single) turn**
- Put the rudder hard over toward the casualty's side, then centre it once the turn is underway.
- Turn about 250 degrees from the original course, keeping speed.
- Stop the turn when the casualty is about 15 degrees off the bow.
- Quickest return to a point just passed. Best when the casualty is still visible. For distant or lost casualties, use Williamson or Scharnow.
- Wind/sea: approach upwind of the person where possible; stop the engines with the casualty well forward of the propellers.

**Williamson turn**
- Rudder full over toward the casualty's side, then full over to the opposite side.
- Deviate 60 degrees from the original course, then centre the rudder when the heading is about 20 degrees short of the reciprocal course.
- Slower than Anderson, but recommended when the casualty is not in sight (search for a person missing). Works in any visibility.
- Approach with the vessel downwind of the person, moving upwind. Stop the engines with the person alongside, forward of the propellers.

Note: a Polish journal analysis (https://bibliotekanauki.pl/articles/135324.pdf) says the Williamson turn is simple and effective in reduced visibility, though slow, and it initially moves the ship away from the casualty. [PARTIAL, search snippet]

### 2b. Approach direction, speed, and handling [PARTIAL / UNVERIFIED]

- Approach so the casualty is in the lee of the vessel, or the vessel is downwind and drifts toward the casualty. Source: Wikipedia link above (downwind approach, moving upwind).
- Speed: slow approach under control. The exact knots figure is [UNVERIFIED]; check the MCA or RNLI manoeuvring guidance.
- Primary IMO text: MSC.1/Circ.1447 "Guidelines for the development of plans and procedures for recovery of persons from the water" (https://wwwcdn.imo.org/localresources/en/OurWork/Safety/Documents/Documents%20relevant%20to%20SAR/MSC.1-CIRC.1447%20Guidelines%20for%20the%20development%20of%20plans%20and%20procedures%20for%20recovery%20of%20persons%20from%20the%20water.pdf). **Downloaded but unreadable in this session. Read it in a browser before relying on any recovery-approach claim.**

### 2c. Throw bags and heaving lines [PARTIAL]

- The Coast Guard boat crew manual has a "Person in the Water Recovery" chapter after Search and Rescue. Source (commercial summary): https://www.uscga-district-7.org/pdf/operations/bcsm_to_bch_crosswalk.pdf . The crosswalk says PIW material moved into the Boat Operations part and that water survival skills are in a separate Rescue and Survival handbook.
- Heaving line / throw bag: the casualty holds the line, the crew pulls them to the boat. Wiki page was not fetchable (404). [UNVERIFIED step detail]
- Throw upwind of the casualty so the line drifts down to them. [UNVERIFIED; check COMDTINST M16114 Boat Crew Seamanship Manual]

### 2d. Rescue swimmers [PARTIAL]

- Rescue swimmer manual (COMDTINST M3710.4C, 2011 version) is referenced at https://media.defense.gov/2021/Oct/08/2002870825/-1/-1/0/2011_RESCUESWIMMERMANUAL_CIM_3710_4C.PDF . **Fetch returned 403; the text was not read.**
- Rescue swimmer role: enter the water with the casualty; keep the casualty's head clear. Details [UNVERIFIED].

### 2e. Parbuckle and horizontal lift for hypothermia [PARTIAL / UNVERIFIED]

- Parbuckle (as a salvage term): rotational leverage to right a sunken vessel. Source: https://en.wikipedia.org/wiki/Parbuckling. **This is a salvage technique (USS Oklahoma, Costa Concordia), not a person-recovery method.** Do not use it as a casualty recovery procedure in the game.
- Horizontal lift for hypothermia: keep the casualty horizontal and move them as little and as gently as possible. Source: https://en.wikipedia.org/wiki/Hypothermia (horizontal positioning is NOT stated in that article; the claim here comes from the Latvian maritime first-aid page in search results, https://daivings.lv/en/first-medical-aid-for-victims-water/). [PARTIAL]

### 2f. Panicking casualty [PARTIAL]

- Victims who are panicking may cling to a rescuer and pull both under. Keep control of the approach. Source: https://en.wikipedia.org/wiki/Drowning

### Equipment
- Throw bag or heaving line, lifebuoy with light, boathook, scoop or ladder, rescue swimmer gear. Mostly [UNVERIFIED] beyond the points above.

### Crew roles
- Helm (approach), lookout (keeps the casualty in sight, calls distance), deck hand (throws line, recovers casualty), rescue swimmer (where fitted). Source for RNLI roles: see section 10.

### Common mistakes and consequences
- Losing sight of the casualty. Consequence: search becomes a longer operation, so use Williamson or Anderson turn. [PARTIAL]
- Approaching from the wrong side of wind and sea. Consequence: propeller or hull strikes the casualty, or casualty is driven under the hull. [UNVERIFIED]
- Throwing a heavy lifebuoy directly at the casualty. Consequence: can injure or stun them. Source: https://en.wikipedia.org/wiki/Drowning
- Rescuer swimming out without a flotation aid. Consequence: rescuers drown. Source: https://en.wikipedia.org/wiki/Drowning

---

## 3. First aid at sea

### 3a. Primary survey (DRABC / ABCDE) [UNVERIFIED]

- Standard UK practice: DRABC (Danger, Response, Airway, Breathing, Circulation). Check RYA / MCA first aid at https://www.rya.org.uk/ (not fetched).
- Hospital ABCDE is the clinical version. Do not mix the two in the game without a note.

### 3b. Cold water shock [PARTIAL]

- Cold shock response, four stages (from source): (1) initial cold shock, first 2–3 minutes, gasp reflex, hyperventilation, fast heart rate; (2) short-term, after 3 minutes, superficial neuromuscular cooling; (3) long-term, after 30 minutes, hypothermia and later collapse; (4) afterdrop around the time of rescue, arrhythmia and unconsciousness. Source: https://en.wikipedia.org/wiki/Cold_shock_response
- Breath-holding: normal 60–90 seconds, but only a few seconds below about 15°C. Same source.
- Cold water shock is a threat below about 15°C. Source (news report quoting RNLI): https://mp.scotsman.com/news/people/cold-water-shock-warning-after-larne-rnli-rescues-stricken-jet-skier-2928828
- RNLI advice to float on the back for about 90 seconds before swimming for shore: [PARTIAL] from a search snippet, not read in full at rnli.org (403). Check https://www.rnli.org/safety .

### 3c. Hypothermia levels and treatment [VERIFIED, secondary wiki]

Source: https://en.wikipedia.org/wiki/Hypothermia

| Stage | Core temp | Signs | Treatment |
|---|---|---|---|
| Mild | 32–35°C | Awake, shivering | Passive rewarming: dry, insulated, warm place; warm drinks |
| Moderate | 28–32°C | Drowsy, not shivering | Active external rewarming: heating blankets, warmed forced air |
| Severe | 20–28°C | Unconscious, not shivering | Remove from cold, manage ABC, move gently; rapid rewarming; CPR if no pulse |
| Profound | below 20°C | No vital signs | Specialist care |

- Give warm, sweetened drinks only to people who are alert and can swallow. No alcohol or caffeine.
- Do not use hot baths, heating pads, or rub arms and legs (the article cites NHS: sudden blood pressure drop, possible cardiac arrest).
- Continue rewarming until core temperature is above 32°C.

### 3d. Drowning and CPR [VERIFIED, secondary wiki]

Source: https://en.wikipedia.org/wiki/Drowning

- Recovery position for an unconscious, breathing casualty: on their side.
- Start with airway and breathing. For a non-breathing adult: tilt head back, 2 rescue breaths, then 30 compressions alternating with 2 breaths. The article's intro says 5 initial breaths, which differs from its first-aid section. Check current resuscitation guidance (Resuscitation Council UK) at https://www.resus.org.uk/ before using numbers in the game.
- Gasping but with a heartbeat: breaths alone may be enough.
- Avoid abdominal thrusts and head-down positioning (delay ventilation, risk vomiting and aspiration).
- Defibrillation only after the victim is out of the water and dry.

### 3e. Oxygen [UNVERIFIED]

- Standard practice is high-flow oxygen for a casualty with breathing problems or trauma, with a non-rebreather mask. Verify with RYA / Resuscitation Council UK guidance. No source fetched.

### 3f. Casualty handover (ATMIST or SBAR) [PARTIAL]

- ATMIST: Age, Time, Mechanism, Injuries, Signs, Treatment. For medical patients the "medical problem" replaces mechanism and injuries. Pre-alert version ATMISTER adds estimated arrival time and requirements. Source: https://www.rcemlearning.co.uk/modules/pre-hospital-communication/lessons/conveying-useful-information/topic/atmister/ (search snippet; full page not fetched). Also https://www.tsgassociates.co.uk/news/item/what-does-atmist-stand-for
- Handover is typically about 60 seconds by one team member, facing the receiving team. Same sources.
- SBAR (Situation, Background, Assessment, Recommendation): [UNVERIFIED] no source fetched in this session. Check NHS/clinical sources before using it.

### Equipment
- Foil blankets or insulated bags, dry clothing, first aid kit, oxygen, AED, pocket mask or bag-valve mask, heat packs. [UNVERIFIED list]

### Crew roles
- Casualty lead (medic / coxswain), second crew (assistant), navigator (keeps the radio and records times). [UNVERIFIED]

### Common mistakes and consequences
- Rubbing or heating limbs. Consequence: cardiac arrest from cold blood returning to the heart (Wikipedia Hypothermia, citing NHS).
- Giving alcohol or hot drinks to an unconscious casualty. Consequence: aspiration. [PARTIAL]
- Head-down positioning or abdominal thrusts in drowning. Consequence: vomiting and aspiration (Wikipedia Drowning).

---

## 4. Towing a disabled vessel

All items UNVERIFIED. No sources were readable for this topic in this session. Recommended primary sources to check: RNLI towing guidance at https://www.rnli.org/ , MCA guidance at https://www.gov.uk/ (search "towing"), USCG Boat Crew Seamanship Manual (COMDTINST M16114), and the IAMSAR Manual Vol III.

- Assessment: check for fire, flooding, fouled propeller, power loss, crew condition, sea state, wind, and tow capacity. [UNVERIFIED]
- Passing the line: heaving line to the disabled vessel, then the tow line is bent on. [UNVERIFIED]
- Bridle: a two-leg attachment to the towing bitts so the tow line does not yaw. [UNVERIFIED]
- Towing speed and line length: typically slow and with enough scope to avoid snatch loads. Exact figures [UNVERIFIED]. The game should use a relative tension meter, not invented knots.
- Snatch load: sudden tension on the tow line, can part the line or damage cleats. [UNVERIFIED]
- Alongside tow in harbour: lashed alongside, fenders out. [UNVERIFIED]
- Releasing: cast-off from the tow vessel, last person to leave the tow line. [UNVERIFIED]

### Common mistakes and consequences
- Snatch loads from a slack-then-taut tow. Consequence: broken line, injured crew. [UNVERIFIED]
- Towing from a single fixed point without a bridle. Consequence: yawing and line failure. [UNVERIFIED]

---

## 5. Sinking vessel and capsized vessel

All items UNVERIFIED. Recommended primary sources: MCA / HM Coastguard guidance at https://www.gov.uk/ , RNLI guidance at https://www.rnli.org/ , and the USCG Boat Crew Seamanship Manual.

- Salvage pumps: portable pumps placed to keep water below the bilge. [UNVERIFIED]
- Plugging leaks: plug or mattress over the hole, then secure. [UNVERIFIED]
- Abandon-ship decision: when the vessel is past recovery and the crew cannot keep it afloat. Crew goes into a life raft or survival craft with the EPIRB. [UNVERIFIED]
- Capsized vessel: check for an air pocket before diving; the hull may trap air. [UNVERIFIED]
- Diver procedures: standby diver, tender on the surface, communication line. [UNVERIFIED]

### Common mistakes and consequences
- Abandoning a vessel that could have been pumped out. Consequence: loss of survival craft and exposure. [UNVERIFIED]
- Diving into an unventilated hull without a tender. Consequence: drowning or asphyxia. [UNVERIFIED]

---

## 6. Vessel fire

All items UNVERIFIED. No sources were fetched for this topic.

- Approach upwind to avoid smoke and heat. [UNVERIFIED]
- Boundary cooling: spray water on the surrounding structure to prevent spread. [UNVERIFIED]
- Foam: applied to the fuel fire at its base. [UNVERIFIED]
- Evacuation: crew muster point, life raft, MOB protocols. [UNVERIFIED]

### Common mistakes and consequences
- Approaching downwind. Consequence: smoke inhalation, flashover. [UNVERIFIED]

---

## 7. Helicopter winching (hoist)

Sources: the search and rescue helicopter Wikipedia page did not load (404). The USCG Rescue Swimmer manual PDF returned 403. The only sources read were the search results below. Everything else is UNVERIFIED.

- Hoist static discharge: a helicopter can build static charge, which discharges when the hook, cable end, or fitting touches the ground or water. A hoist static discharge cable (HSD) was added in a revision of COMDTINST M3710.4C. Sources: https://patents.google.com/patent/US6942177 (patent, background) and https://media.defense.gov/2021/Oct/08/2002870825/-1/-1/0/2011_RESCUESWIMMERMANUAL_CIM_3710_4C.PDF (not read).
- Flight mechanic (USCG) controls the hoist and how the swimmer or litter is raised or lowered. Source: https://www.news.uscg.mil/Doing-Business/Photos/igphoto/2003786988/ (search snippet).
- Hi-line (tag line): [UNVERIFIED] used to control drift of the basket on the ground. Confirm the USCG hoist SOP.
- Double lift versus stretcher: [UNVERIFIED] double lift is two people on one hoist cable; stretcher is a litter. Confirm in helicopter SOP.
- Rotor downwash: a hazard to people on the surface, debris, and small vessels. [UNVERIFIED]
- Winchman role: operates the hoist from the cabin door, talks the swimmer or casualty onto the basket. [UNVERIFIED]

### Common mistakes and consequences
- Touching the cable or basket before it is grounded. Consequence: static shock. [PARTIAL, patent background]
- Hoisting a casualty without a tag line. Consequence: swing and strike on the aircraft or the boat. [UNVERIFIED]

---

## 8. Search planning

Important: the IAMSAR Manual was not read. The search pattern definitions below come from search snippets (flashcards, secondary blogs) and are PARTIAL at best. The Canadian Coast Guard search chapter PDF (https://sms.ccga-gcac.ca/files/library/08_-_Search.pdf) did not extract. Primary: IAMSAR Vol II at https://www.imo.org/ and https://www.icao.int/ .

### 8a. Datum, drift, leeway [PARTIAL / UNVERIFIED]

- Datum: the last known position, or the best estimate of where the search object is. [UNVERIFIED definition, consistent with IAMSAR terminology]
- Drift = leeway (wind effect on the object) plus current (water movement). One flashcard set plots the datum, applies the tidal vector, calculates leeway, and draws an error radius. Source: https://brainscape.com/flashcards/sar-14194884/packs/21548146 (secondary). IAMSAR leeway tables not read.

### 8b. Search patterns [PARTIAL]

- **Expanding square**: legs grow by one track spacing every two legs, starting at the datum. Suited to a single vessel searching for an object with little or no leeway. Source (secondary): https://brainscape.com/flashcards/sp-11234998/packs/19912999
- **Sector**: tracks pass through the datum, covering a circle around it. Suited to a small area with a very reliable datum, and to small targets (person in water, small raft). Source (secondary): as above.
- **Parallel sweep (track line)**: covers large areas where the location is uncertain. Used to divide a large area among several units working at once. Source (secondary): as above; also https://marineinspection.app/blog/maritime-search-rescue-sar-iamsar-procedures-commercial-vessels
- **Creeping line**: not covered by any source read. [UNVERIFIED]

### 8c. Survival time in cold water [PARTIAL]

- Breath-holding 60–90 seconds normally; a few seconds below about 15°C. Source: https://en.wikipedia.org/wiki/Cold_shock_response
- Survival time by water temperature band: NOT FOUND. Do not invent figures. Check IAMSAR Vol III / Vol II, and the cold water survival tables in the RNLI and MCA guidance.

### Common mistakes and consequences
- Using a parallel sweep for a single small target with a reliable datum. Consequence: wasted time. [UNVERIFIED]
- Ignoring leeway for a light object (person in water). Consequence: search area in the wrong place. [PARTIAL]

---

## 9. Lifeguard beach rescue (rip currents)

### 9a. Rip current identification [VERIFIED, secondary wiki]

Source: https://en.wikipedia.org/wiki/Rip_current
- Break in the wave pattern: the water looks flat where breaking lines are on either side.
- Foam "river" streaming out to open water.
- Different colour: murkier or cloudier.
- Foam and debris on the rip move seaward; surrounding breaking-wave foam moves toward shore.

### 9b. Survival steps [VERIFIED, official NOAA page]

Source: https://nhc.noaa.gov/rip-currents/survive.html (NOAA National Hurricane Center)
1. Relax and float. Do not fight the current.
2. Swim parallel to shore, at an angle, until out of the narrow offshore flow.
3. Wave for help. Keep treading water while floating.

### 9c. Rescuer guidance [VERIFIED, official NOAA page]

Source: https://nhc.noaa.gov/rip-currents/survive.html
- Evaluate the situation.
- Alert a lifeguard.
- Throw the person something that floats.
- Call 911.
- Do not enter the water. "Many rip current fatalities occur from someone trying to rescue others."

### 9d. Rescue tube and board technique, rescue signals [UNVERIFIED]

- Rescue tube and board technique: NOT FOUND in any source read. Primary sources to check: USLA (United States Lifesaving Association, https://www.usla.org/) and the RNLI beach safety pages.
- Rescue signals: NOT FOUND. Wikipedia said lifeguards move flags to mark rips. [PARTIAL]

### Common mistakes and consequences
- Swimming straight back to shore against the current. Consequence: exhaustion and drowning. [VERIFIED, NOAA page]
- Entering the water to rescue without a flotation aid. Consequence: rescuers drown. [VERIFIED, NOAA page]

---

## 10. Crew roles

### 10a. RNLI all-weather and inshore lifeboats [PARTIAL]

Source: https://en.wikipedia.org/wiki/Royal_National_Lifeboat_Institution (secondary; RNLI pages blocked)
- Roles named: coxswain, helmsman, mechanic. Navigator role: not described in the page read. [UNVERIFIED role list for helm, navigator, crew, mechanic]
- About 97% of lifeboat crew are volunteers. Crews train at stations and at the Lifeboat College in Poole, including for capsize and helicopter work.
- All-weather lifeboats: self-righting, enclosed wheelhouse, below-deck survivor space, some carry an inflatable Y-boat. Speeds 17–25 knots across five classes (Mersey, Trent, Severn, Tamar, Shannon).
- Inshore lifeboats: inflatable or rigid-hulled inflatable, closer to shore, D-class and B-class, E-class on the Thames.
- Lifeboats are tasked by HM Coastguard. Tasking detail not in the page read.

Primary sources to check: https://www.rnli.org/ (pages returned 403 in this session).

### 10b. USCG helicopter crew [PARTIAL]

- Pilot and co-pilot: [UNVERIFIED] standard roles, confirm in USCG aviation SOP.
- Flight mechanic: controls the hoist and how the swimmer or litter is raised and lowered; also keeps the aircraft airworthy. Source: https://www.news.uscg.mil/Doing-Business/Photos/igphoto/2003786988/ (search snippet).
- Rescue swimmer: enters the water with the casualty. Manual referenced at https://media.defense.gov/2021/Oct/08/2002870825/-1/-1/0/2011_RESCUESWIMMERMANUAL_CIM_3710_4C.PDF (not read).

### Common mistakes and consequences
- Not briefing the casualty before the hoist. Consequence: panic on the basket. [UNVERIFIED]

---

## Gaps and next steps

1. Read the IAMSAR Manual Vol II and III, the MSC.1/Circ.1447 PDF, and the USCG Boat Crew Seamanship Manual and Rescue Swimmer manual in a browser (these returned 403, 404, or unreadable binary). This will confirm sections 2, 4, 5, 6, 7, and 8.
2. Read RNLI safety pages (rnli.org) and MCA/HM Coastguard guidance (gov.uk), which were blocked here.
3. Confirm phonetic alphabet and RCC tasking format in ITU-R and IAMSAR.
4. Confirm DRABC, oxygen, and handover (SBAR) against RYA, Resuscitation Council UK, and NHS sources.
5. Survival time by water temperature: not found. Do not invent figures in the game.
