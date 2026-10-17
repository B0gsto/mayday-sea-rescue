#!/usr/bin/env python3
"""Build assets/voice/lines.csv: every voice line and stitching fragment.

This file is the source of truth for the voice script (docs/11-dispatcher-and-voice.md).
Edit the tables here, run `python3 -I build_lines.py`, commit both files.

Columns: id, voice, category, position_variant, text, notes
  position_variant: FULL (whole line), S (opens a sentence), M (mid-sentence,
  continuing pitch), E (closes a sentence, falling pitch).
  notes: scope tag ([MVP] or [L]), then optional
    ctx_prev=... | ctx_next=...  (sent to ElevenLabs as previous_text / next_text)
    say=...                      (pronunciation override; subtitle keeps `text`)
"""
import csv
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "lines.csv")

rows = []
seen = set()


def slug(s):
    return re.sub(r"[^A-Z0-9]+", "_", s.upper()).strip("_")[:40]


def add(id_, voice, cat, pos, text, notes="[MVP]"):
    if id_ in seen:
        raise SystemExit("duplicate id " + id_)
    seen.add(id_)
    rows.append([id_, voice, cat, pos, text, notes])


def lines(voice, prefix, cat, items, scope="[MVP]"):
    """items: list of (key, text) or (key, text, extra_notes)."""
    for it in items:
        key, text = it[0], it[1]
        extra = it[2] if len(it) > 2 else ""
        sc = "[L]" if "[L]" in extra else scope
        extra = extra.replace("[L]", "").strip()
        add(f"{prefix}_{cat.upper()}_{key}", voice, cat, "FULL", text, (sc + " " + extra).strip())


def frags(voice, prefix, cat, items, variants, scope="[MVP]"):
    """Stitching fragments. items: (key, text[, scope]). Context per variant."""
    ctx = {
        "S": "ctx_next=, informant reports one person in the water.",
        "M": "ctx_prev=Launch to a position | ctx_next=, informant reports an adult swimmer.",
        "E": "ctx_prev=Launch to a position three hundred metres south of",
    }
    for it in items:
        key, text = it[0], it[1]
        sc = it[2] if len(it) > 2 else scope
        for v in variants:
            t = text
            if v == "S":
                t = t[0].upper() + t[1:]
            if v == "E" and not t.endswith((".", "?", "!")):
                t = t + "."
            add(f"{prefix}_{cat.upper()}_{key}_{v}", voice, cat, v, t, f"{sc} {ctx[v]}")


# ---------------------------------------------------------------- shared tables
CALLSIGNS = [
    ("HR11", "Haven Rescue One-One", "[MVP]"),
    ("HR21", "Haven Rescue Two-One", "[MVP]"),
    ("HR31", "Haven Rescue Three-One", "[MVP]"),
    ("HPATROL", "Haven Patrol", "[MVP]"),
    ("GALEQUEEN", "Gale Queen", "[MVP]"),
    ("OPTIMIST", "Optimist", "[MVP]"),
    ("STATION", "Port Haven Lifeboat Station", "[MVP]"),
    ("RGALE1", "Rescue Gale One", "[L]"),
    ("RGALE2", "Rescue Gale Two", "[L]"),
    ("NDAWN", "Northern Dawn", "[L]"),
]

PLACES = [  # every named place in docs 01-03 and 09; [MVP] = Calm Bay map
    ("PORT_HAVEN", "Port Haven", "[MVP]"),
    ("HARBOUR", "Port Haven harbour", "[MVP]"),
    ("HARBOUR_MOUTH", "the harbour mouth", "[MVP]"),
    ("HARBOUR_WALL", "the harbour wall", "[MVP]"),
    ("APPROACHES", "the harbour approaches", "[MVP]"),
    ("FERRY_PIER", "the ferry pier", "[MVP]"),
    ("SLIPWAY", "the station slipway", "[MVP]"),
    ("HOSPITAL_PONTOON", "the hospital pontoon", "[MVP]"),
    ("FISH_QUAY", "the fish market quay", "[MVP]"),
    ("SANDY_POINT", "Sandy Point", "[MVP]"),
    ("HARBOR_LIGHT", "Harbor Light", "[MVP]"),
    ("CALM_BAY", "Calm Bay", "[MVP]"),
    ("HAVEN_SANDS", "Haven Sands", "[MVP]"),
    ("THE_BAR", "the Bar", "[MVP] the sandbar off Haven Sands"),
    ("HAVEN_HEAD", "Haven Head", "[MVP]"),
    ("FUEL_DOCK", "the fuel dock", "[MVP]"),
    ("COTTAGE_HOSPITAL", "the Cottage Hospital", "[MVP]"),
    ("LIFEGUARD_TOWER", "the lifeguard tower", "[MVP]"),
    ("THE_SKERRIES", "the Skerries", "[L]"),
    ("SKERRY_ISLE", "Skerry Isle", "[L]"),
    ("SKERRY_LIGHT", "Skerry Light", "[L]"),
    ("SKERRY_OUTPOST", "the Skerry Isle outpost", "[L]"),
    ("KELP_BEDS", "the kelp beds", "[L]"),
    ("SEA_CAVES", "the sea caves", "[L]"),
    ("FERRY_LANE", "the ferry lane", "[L]"),
    ("GANNET_ROCK", "Gannet Rock", "[L]"),
    ("GANNET_LIGHT", "Gannet Rock Light", "[L]"),
    ("GANNET_OUTPOST", "the Gannet Rock outpost", "[L]"),
    ("TEMPEST_POINT", "Tempest Point", "[L]"),
    ("TEMPEST_LIGHT", "Tempest Point Light", "[L]"),
    ("TEMPEST_CLIFFS", "the cliffs below Tempest Point", "[L]"),
    ("WRECKERS_COVE", "Wreckers' Cove", "[L]"),
    ("GULL_COVE", "Gull Cove", "[L]"),
    ("KITTIWAKE", "Kittiwake Cliffs", "[L]"),
    ("LONG_STRAND", "Long Strand", "[L]"),
    ("WESTGATE", "Westgate slipway", "[L]"),
    ("PUFFIN_ISLE", "Puffin Isle", "[L]"),
    ("SALTINGS", "the Saltings", "[L]"),
]

DIRECTIONS = [(slug(d), d) for d in [
    "north of", "north-east of", "east of", "south-east of", "south of",
    "south-west of", "west of", "north-west of", "off", "just outside", "inside",
    "near", "at", "close to"]]

DISTANCES = [
    ("D50", "fifty metres", "[MVP]"), ("D100", "one hundred metres", "[MVP]"),
    ("D200", "two hundred metres", "[MVP]"), ("D300", "three hundred metres", "[MVP]"),
    ("D400", "four hundred metres", "[MVP]"), ("D500", "five hundred metres", "[MVP]"),
    ("D800", "eight hundred metres", "[MVP]"), ("D1K", "one kilometre", "[MVP]"),
    ("NMHALF", "half a mile", "[MVP]"), ("NM1", "one mile", "[L]"),
    ("NM2", "two miles", "[L]"), ("NM3", "three miles", "[L]"), ("NM5", "five miles", "[L]"),
]

NUMWORDS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
            "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
            "sixteen", "seventeen", "eighteen", "nineteen", "twenty"]
TENS = {20: "twenty", 30: "thirty", 40: "forty"}


def numword(n):
    if n <= 20:
        return NUMWORDS[n]
    t, u = (n // 10) * 10, n % 10
    return TENS[t] + ("-" + NUMWORDS[u] if u else "")


NUMBERS = [(f"N{n:02d}", numword(n)) for n in range(1, 41)]
DIGITS = [(f"G{i}", w) for i, w in enumerate(
    ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "niner"])]
PHONETIC = [(w.upper().replace("-", ""), w) for w in [
    "Alfa", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India",
    "Juliett", "Kilo", "Lima", "Mike", "November", "Oscar", "Papa", "Quebec", "Romeo",
    "Sierra", "Tango", "Uniform", "Victor", "Whiskey", "X-ray", "Yankee", "Zulu"]]
MINUTES = [("M01", "one minute")] + [(f"M{n:02d}", numword(n) + " minutes")
                                    for n in [2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 40]]
WIND_DIRS = [(slug(d), d) for d in [
    "north", "north-east", "east", "south-east", "south", "south-west", "west",
    "north-west", "variable"]]
WIND_STRENGTH = [(slug(d), d) for d in [
    "light", "moderate", "fresh", "strong", "gale force", "force four", "force five",
    "force six", "force seven", "force eight", "force nine", "force ten"]]

OPTYPES = [
    ("PIW1", "one person in the water", "[MVP]"),
    ("PIW2", "two persons in the water", "[MVP]"),
    ("ENGINE", "a motor boat with engine failure", "[MVP]"),
    ("NOFUEL", "a motor boat out of fuel", "[MVP]"),
    ("PROP", "a yacht with a fouled propeller", "[MVP]"),
    ("AGROUND", "a small boat aground", "[MVP]"),
    ("DRIFTING", "a small boat drifting without power", "[MVP]"),
    ("CAPSIZE_DINGHY", "a capsized dinghy", "[L]"),
    ("SINKING", "a vessel taking on water", "[L]"),
    ("FIRE", "a vessel on fire", "[L]"),
    ("MOB", "a person overboard from the ferry", "[L]"),
    ("BOARD_ADRIFT", "a parent and child on a paddleboard drifting offshore", "[L]"),
    ("CUT_OFF", "walkers cut off by the tide", "[L]"),
    ("WILDLIFE", "a seal tangled in a net", "[L]"),
    ("CLIFF", "a climber stuck on a ledge", "[L]"),
]

CASUALTY_DESC = [
    ("ADULT_SWIMMER", "an adult swimmer"), ("OLDER_SWIMMER", "an older swimmer"),
    ("TEEN_SWIMMER", "a teenage swimmer"), ("PADDLEBOARDER", "a paddleboarder"),
    ("ANGLER", "an angler who has fallen from the rocks"), ("KAYAKER", "a kayaker"),
    ("WADER", "a person swept off the sandbar"),
]
CASUALTY_KIT = [("NO_LJ", "no lifejacket"), ("LJ", "wearing a lifejacket"),
                ("BUOYANCY_AID", "wearing a buoyancy aid"), ("CLINGING", "holding on to a board")]
CASUALTY_STATE = [
    ("WAVING", "waving for help"), ("SHOUTING", "shouting for help"),
    ("TIRING", "tiring quickly"), ("STRUGGLING", "struggling to stay afloat"),
    ("NOT_MOVING", "floating, not moving much"), ("SILENT", "no longer answering"),
    ("CAUGHT_RIP", "caught in a rip current"),
]

# ---------------------------------------------------------------- Coastguard
CG_FIXED = {
    "open": [
        ("ALL_STATIONS", "All stations, all stations, all stations, this is Gale Isles Coastguard, Gale Isles Coastguard."),
        ("THIS_IS", "This is Gale Isles Coastguard."),
        ("CG_SHORT", "Coastguard."),
    ],
    "priority": [
        ("MAYDAY_RELAY", "Mayday relay, Mayday relay, Mayday relay."),
        ("PANPAN", "Pan-pan, pan-pan, pan-pan.", "say=Pahn-pahn, pahn-pahn, pahn-pahn."),
        ("SECURITE", "Securite, securite, securite.", "say=Say-cure-ee-tay, say-cure-ee-tay, say-cure-ee-tay."),
        ("SEELONCE_MAYDAY", "Seelonce Mayday. Seelonce Mayday. All stations, this channel is now reserved for distress traffic only.", "say=See-lonce Mayday. See-lonce Mayday. All stations, this channel is now reserved for distress traffic only."),
        ("SEELONCE_FEENEE", "Seelonce feenee. Seelonce feenee. Normal working may resume on this channel.", "say=See-lonce fee-nay. See-lonce fee-nay. Normal working may resume on this channel."),
        ("MAYDAY_RECEIVED", "Received Mayday."),
        ("PANPAN_RECEIVED", "Received pan-pan.", "say=Received pahn-pahn."),
        ("UPGRADE_MAYDAY", "Be advised, this is now a Mayday situation."),
    ],
    "stem": [
        ("LAUNCH_TO", "Launch to a report of", "pos=M ctx_next=one person in the water"),
        ("PROCEED_TO", "Proceed with all speed to", "pos=M ctx_next=the harbour mouth"),
        ("POSITION", "Position", "pos=S ctx_next=three hundred metres south of Sandy Point."),
        ("INFORMANT_BEACH", "Informant on the beach reports", "pos=S ctx_next=an adult swimmer, no lifejacket"),
        ("INFORMANT_PIER", "Informant on the pier reports", "pos=S ctx_next=an adult swimmer, no lifejacket"),
        ("INFORMANT_VESSEL", "The vessel reports", "pos=S ctx_next=two persons on board"),
        ("ABOUT", "about", "pos=M ctx_next=ten minutes in the water"),
        ("IN_THE_WATER", "in the water.", "pos=E ctx_prev=about ten minutes"),
        ("PERSONS_ON_BOARD", "persons on board.", "pos=E ctx_prev=The vessel reports two"),
        ("PERSON_ON_BOARD", "person on board.", "pos=E ctx_prev=The vessel reports one"),
        ("WIND", "Wind", "pos=S ctx_next=south-west, light."),
        ("DRIFTING_TOWARDS", "drifting towards", "pos=M ctx_next=the harbour wall."),
        ("DATUM_ON_CHART", "Datum is on your chart."),
        ("DATUM_TIME", "Last seen", "pos=S ctx_next=five minutes ago."),
        ("AGO", "ago.", "pos=E ctx_prev=Last seen five minutes"),
        ("OVER", "Over.", "pos=E"),
        ("OUT", "Out.", "pos=E"),
        ("SECTOR", "search sector", "pos=M ctx_next=Bravo."),
        ("COMPARTMENT", "compartment", "pos=M ctx_next=Charlie."),
        ("ETA", "ETA", "pos=M ctx_next=five minutes."),
        ("BEARING", "bearing", "pos=M ctx_next=two four zero degrees"),
        ("DEGREES", "degrees.", "pos=E ctx_prev=bearing two four zero"),
        ("OF", "of", "pos=M ctx_next=fourteen persons accounted for."),
        ("ACCOUNTED_FOR", "persons accounted for.", "pos=E ctx_prev=nine of fourteen"),
        ("RECOVERED", "recovered.", "pos=E ctx_prev=Copy, two"),
        ("COPY", "Copy,", "pos=S ctx_next=two recovered."),
        ("COPY_ETA", "Copy your ETA,", "pos=S ctx_next=five minutes."),
        ("YOU_ARE_OSC", "you are On Scene Coordinator.", "pos=E ctx_prev=Haven Rescue Two-One,"),
        ("TAKE", "take", "pos=M ctx_next=search sector Bravo."),
        ("GALE_WARNING", "Gale warning for the Gale Isles.", ""),
        ("WARNING_WIND", "Wind", "pos=S ctx_next=south-west, gale force eight, imminent."),
        ("IMMINENT", "imminent.", "pos=E ctx_prev=south-west, force eight,"),
        ("INCREASING", "increasing", "pos=M ctx_next=force eight"),
    ],
    "tasking": [
        ("SITREP_REQ", "Request situation report, over."),
        ("SITREP_REQ_2", "Coastguard, are you receiving? Request situation report, over."),
        ("SAY_AGAIN_ETA", "Say again your ETA, over."),
        ("SAY_AGAIN_POB", "Say again your POB, over."),
        ("CONFIRM_POB", "Confirm all persons are off the vessel, over."),
        ("ROGER_OUT", "Roger, out."),
        ("ROGER_OUT_2", "Roger. Out."),
        ("ROGER", "Roger."),
        ("COPIED_OUT", "Copied. Out."),
        ("ROGER_DATUM", "Roger. Datum is on your chart. Out."),
        ("ACK_LAUNCH", "Roger, launching. Keep me informed. Out."),
        ("UNABLE_ACK", "Roger, unable. Tasking another unit. Out."),
        ("REPEAT_FOLLOWS", "I say again."),
        ("AMB_SLIPWAY", "Ambulance is requested to the station slipway. They will meet you there."),
        ("AMB_WAITING", "Be advised, the ambulance is at the slipway and waiting."),
        ("HOSPITAL_READY", "Doctor Osei's team is standing by at the hospital pontoon."),
        ("HELO_REQ_ACK", "Roger, requesting Rescue Gale One. Continue with casualty care.", "[L]"),
        ("HELO_UNAVAILABLE", "Rescue Gale One is unavailable. Continue to the slipway. Ambulance is on its way."),
        ("SECOND_UNIT", "Roger, tasking Haven Patrol to assist you."),
        ("HAVEN_PATROL_TAKEOVER", "Haven Patrol is on scene and taking over the tow. Stand by to assist."),
        ("TAKE_CREW_OFF", "The vessel is close to the rocks. Take the crew off, I say again, take the crew off. Over."),
        ("ANCHOR_ADVICE", "Advise the skipper to anchor if he can, then pass the tow."),
        ("HARBOURMASTER_INFORMED", "Harbourmaster is informed. Berth on the fish market quay."),
        ("CASUALTY_HANDED", "Roger, casualty handed over."),
        ("STAND_DOWN", "Stand down. Good work. Out."),
        ("STAND_DOWN_2", "You are stood down. Good work today. Out."),
        ("STAND_DOWN_3", "Stand down, and thank you. That was well done. Out."),
        ("RETURN_STATION", "Roger, return to station. Out."),
        ("READY_TASKING", "Roger, you are available for tasking. Out."),
        ("CASUALTY_LOST_SIGHT", "Roger, lost sight. Search down-drift of the datum. Over."),
        ("CASUALTY_SIGHTED", "Roger, casualty sighted. Out."),
        ("ON_SCENE", "Roger, on scene. Out."),
        ("FALSE_ALARM", "Be advised, informant now reports the swimmer is back on the beach. Stand down. Out."),
        ("DRIFT_WARNING", "Be advised, current is setting north-east at about one knot."),
        ("INFORMANT_POINTING", "Informant is on the beach and pointing to the casualty."),
        ("AREA_EDGE", "Haven Rescue, Gale Isles Coastguard. You are leaving the Gale Isles area. Turn back. Over."),
        ("OFFER", "Haven Rescue, Coastguard. Tasking available. Details on your radio panel. Over."),
        ("OFFER_DECLINED", "Roger, unable. Passing it to another unit. Out."),
        ("OFFDUTY_INVITE", "All off-duty units, the storm is coming in. Join if you are able. Out."),
        ("RADIO_DISCIPLINE", "All stations, keep this channel clear for the operation."),
    ],
    "ferry": [
        ("FERRY_CAPSIZE", "Passenger ferry Gale Queen has capsized at the harbour approaches, half a mile east of the harbour mouth."),
        ("FERRY_DETAIL", "Persons in the water, wearing lifejackets. One liferaft deployed. Persons on the upturned hull."),
        ("FERRY_REQUEST", "All vessels in the vicinity, keep a sharp lookout, assist if able and report to Gale Isles Coastguard. Over."),
        ("FERRY_POB", "Persons on board, according to the manifest:", "pos=S ctx_next=fourteen."),
        ("ALL_UNITS_LAUNCH", "All Haven Rescue units, launch, launch, launch to the Gale Queen."),
        ("NO_OSC", "No unit on scene yet. Gale Isles Coastguard has scene command until the first unit arrives."),
        ("METHANE_ACK", "Copy your METHANE. Major incident declared. Assign units on the scene board."),
        ("SECTOR_UNCOVERED", "On Scene Coordinator, Coastguard. Search sector is uncovered. Over."),
        ("AIR_POCKET_ACK", "Copy, tapping from inside the hull. Mainland dive team is on standby."),
        ("REDS_FIRST", "Reminder, red tags go first. Doctor Osei is receiving at the slipway."),
        ("RAFT_ADVICE", "Take survivors off the liferaft one at a time, from its lee side."),
        ("MANIFEST_MISMATCH", "Count does not match the manifest. Continue search. Over."),
        ("ALL_ACCOUNTED", "All persons accounted for. All units, stand down. Good work, everyone. Out."),
        ("FERRY_HELO", "Rescue Gale One is on task to the Gale Queen.", "[L]"),
        ("FERRY_HELO_NONE", "No helicopter available. Boats only. Move the red tags by the fastest boat."),
    ],
    "storm": [
        ("SECURITE_GALE", "Gale warning for the Gale Isles, issued by Gale Isles Coastguard."),
        ("SMALL_CRAFT", "All small craft are advised to return to harbour or make ready for heavy weather. Out."),
        ("SEA_ROUGH", "Sea state rough, becoming very rough."),
        ("VIS_POOR", "Visibility poor in heavy rain."),
        ("HARBOUR_MOUTH_WARN", "Expect breaking seas at the harbour mouth."),
        ("STORM_ON", "All stations, the storm is now over the Gale Isles. Taskings will be frequent. Stay on this channel."),
        ("STORM_CLEARING", "All stations, the storm is clearing to the east. Operations already running stay in storm conditions until handover."),
        ("WARNING_CANCEL", "The gale warning for the Gale Isles is cancelled. Out."),
        ("STORM_SUMMARY", "All stations, the storm has passed. Thank you to every crew who went out in it."),
        ("NAVWARN_DEBRIS", "Navigational warning. Debris reported in the water near the harbour mouth. Keep a good lookout. Out."),
        ("NAVWARN_BUOY", "Navigational warning. A large buoy is adrift near the ferry pier. Vessels keep clear. Out."),
        ("FOG", "Fog bank reported at Gannet Rock. Visibility under two hundred metres. Out.", "[L]"),
    ],
    "sea_state": [
        ("SEA_CALM", "Sea calm."), ("SEA_SLIGHT", "Sea slight."), ("SEA_MODERATE", "Sea moderate."),
        ("SEA_ROUGH_E", "Sea rough."), ("SEA_VROUGH", "Sea very rough."),
        ("VIS_GOOD", "Visibility good."), ("VIS_MOD", "Visibility moderate."), ("VIS_POOR_E", "Visibility poor."),
        ("RAIN", "Showers."), ("HEAVY_RAIN", "Heavy rain."),
    ],
    "chatter": [
        ("RADIO_CHECK_REPLY", "Haven Patrol, Coastguard, loud and clear. Out."),
        ("FERRY_ACK", "Gale Queen, Coastguard, roger, good passage. Out."),
        ("FERRY_ARRIVED_ACK", "Gale Queen, Coastguard, roger, alongside. Out."),
        ("INSHORE_FORECAST", "All stations, Gale Isles Coastguard. Inshore forecast follows. Wind south-west, three to four. Sea slight. Fair. Visibility good. Out."),
        ("TIDE", "All stations, high water at Port Haven this afternoon. Expect the sandbar to cover quickly. Out."),
        ("FLAGS", "All stations, lifeguard flags are up on Haven Sands. Please swim between the red and yellow flags. Out."),
        ("TEST_SIREN", "All stations, the station siren will be tested at noon. This is a test only. Out."),
        ("OPTIMIST_CHECK", "Optimist, Coastguard. Barnaby, is that you on channel sixteen again? Over."),
        ("OPTIMIST_REPLY", "Optimist, Coastguard. Glad to hear it. Mind the sandbar. Out."),
        ("HAZEL_REPLY_1", "Hazel, Coastguard, roger. We'll ask a unit to take a look. Out."),
        ("HAZEL_REPLY_2", "Hazel, this channel is for working traffic, but thank you. Out."),
        ("HAZEL_REPLY_3", "Roger, Hazel. One cat on one buoy. Tasking the nearest unit. Out."),
        ("SHIFT_HANDOVER_DAY", "All stations, Gale Isles Coastguard. Day watch has the net. Good morning. Out."),
        ("SHIFT_HANDOVER_NIGHT", "All stations, Gale Isles Coastguard. Night watch has the net. Out."),
        ("LOG_FIND", "Coastguard copies. Logged on the chart. Out."),
        ("HAZARD_LOG", "Coastguard copies your hazard report. Navigational warning to follow. Out."),
        ("KAYAK_GROUP", "Skerries Dive Shop, Coastguard, roger, six kayaks out to the sea caves, back by four. Out.", "[L]"),
        ("NDAWN_ACK", "Northern Dawn, Coastguard, roger, fishing at Gannet Rock. Out.", "[L]"),
        ("TOBIAS_LIGHT", "All stations, Harbor Light is lit and showing. Mariners take note. Out."),
        ("LIGHT_RELIT_L", "All stations, Skerry Light is lit and showing again. Out.", "[L]"),
    ],
    "onboarding": [
        ("FIRST_MAYDAY", "Haven Rescue One-One, Haven Rescue One-One, this is Gale Isles Coastguard. Launch to a report of one person in the water, three hundred metres south of Sandy Point. Informant on the beach reports an adult swimmer, no lifejacket, waving for help. Wind south-west, light. Over."),
        ("FIRST_ACK", "One-One, Coastguard, roger. Datum is on your chart. Out."),
        ("FIRST_SITREP_ACK", "Roger, one recovered. Ambulance is waiting at the slipway. Out."),
        ("FIRST_STAND_DOWN", "One-One, Coastguard. Casualty handed over. Welcome back to the water, Port Haven. Good work. Out."),
        ("NUDGE", "One-One, Coastguard, do you copy? Over."),
    ],
}

CG_HELO = [  # Coastguard to helicopter [L]
    ("HELO_TASK", "Rescue Gale One, Gale Isles Coastguard. Tasking, one casualty for winching. Over."),
    ("HELO_ACK", "Rescue Gale One, Coastguard, roger. Out."),
]


def coastguard(voice, p):
    for cat, items in CG_FIXED.items():
        for it in items:
            key, text = it[0], it[1]
            extra = it[2] if len(it) > 2 else ""
            scope = "[L]" if extra.startswith("[L]") else "[MVP]"
            extra = extra.replace("[L]", "").strip()
            pos = "FULL"
            m = re.match(r"pos=(\w)\s*", extra)
            if m:
                pos, extra = m.group(1), extra[m.end():]
            add(f"{p}_{cat.upper()}_{key}", voice, cat, pos, text, (scope + " " + extra).strip())
    for key, text in CG_HELO:
        add(f"{p}_HELO_{key}", voice, "helo", "FULL", text, "[L]")
    for key, cs, sc in CALLSIGNS:
        add(f"{p}_OPEN_{key}", voice, "callsign", "S", f"{cs}, {cs}, this is Gale Isles Coastguard.", sc)
    for key, short in [("HR11", "One-One"), ("HR21", "Two-One"), ("HR31", "Three-One"), ("RGALE1", "Rescue Gale One"), ("RGALE2", "Rescue Gale Two")]:
        sc = "[L]" if key.startswith("RG") else "[MVP]"
        add(f"{p}_SHORT_{key}", voice, "callsign", "S", f"{short}, Coastguard.", sc)
    frags(voice, p, "callsign", CALLSIGNS, "SME")
    frags(voice, p, "place", PLACES, "SME")
    frags(voice, p, "direction", DIRECTIONS, "M")
    frags(voice, p, "distance", DISTANCES, "M")
    frags(voice, p, "number", NUMBERS, "ME")
    frags(voice, p, "digit", DIGITS, "ME")
    frags(voice, p, "phonetic", PHONETIC, "ME")
    frags(voice, p, "minutes", MINUTES, "ME")
    frags(voice, p, "wind_dir", WIND_DIRS, "M")
    frags(voice, p, "wind_strength", WIND_STRENGTH, "ME")
    frags(voice, p, "optype", OPTYPES, "M")
    frags(voice, p, "cas_desc", CASUALTY_DESC, "M")
    frags(voice, p, "cas_kit", CASUALTY_KIT, "M")
    frags(voice, p, "cas_state", CASUALTY_STATE, "ME")
    frags(voice, p, "condition", [
        ("ALERT", "casualty alert"), ("COLD_TALKING", "casualty cold and shivering, talking"),
        ("DROWSY", "casualty drowsy, not shivering"), ("UNRESP_BREATHING", "casualty unresponsive, breathing"),
        ("CPR", "casualty not breathing normally, CPR in progress")], "E")


coastguard("CG_DAY", "CGD")
coastguard("CG_NIGHT", "CGN")

# ---------------------------------------------------------------- Player replies
PLAYER = [
    ("tasking", [
        ("COPY_LAUNCHING", "Copy, launching."), ("SAY_AGAIN", "Say again, over."),
        ("UNABLE", "Unable, over."), ("WILCO", "Wilco, over."), ("ROGER", "Roger, over."),
    ]),
    ("launch", [("LAUNCHED", "Launched,", "pos=M ctx_next=two POB."), ("POB", "POB.", "pos=E ctx_prev=Launched, two")]),
    ("passage", [("ETA", "ETA", "pos=M ctx_next=four minutes. Over.")]),
    ("on_scene", [
        ("ON_SCENE", "On scene, over."), ("SIGHTED", "Casualty sighted, over."),
        ("SEARCHING", "Searching, no contact yet, over."), ("LOST_SIGHT", "Lost sight of the casualty, searching, over."),
    ]),
    ("sitrep", [
        ("RECOVERED", "recovered.", "pos=E ctx_prev=One"), ("REQ_AMB", "Request ambulance at the slipway, over."),
        ("REQ_HELO", "Request Rescue Gale One, over.", "[L]"), ("REQ_HELO_MVP", "Request helicopter, over."),
        ("REQ_SECOND", "Request a second unit, over."), ("COND_ALERT", "Casualty alert and talking."),
        ("COND_COLD", "Casualty cold and shivering."), ("COND_DROWSY", "Casualty drowsy, not shivering."),
        ("COND_UNRESP", "Casualty unresponsive, breathing."), ("COND_CPR", "Casualty not breathing normally, starting CPR."),
        ("VESSEL_TOW", "Taking the vessel in tow, over."), ("VESSEL_CREW_OFF", "Taking the crew off, over."),
        ("VESSEL_ANCHOR", "Vessel is anchoring, then we pass the tow, over."),
        ("TOW_ESTABLISHED", "Tow established, making for the harbour, over."), ("TOW_PARTED", "Tow has parted, re-passing, over."),
        ("ALONGSIDE", "Alongside the casualty vessel, over."),
    ]),
    ("transport", [
        ("RETURNING_TO", "Returning to", "pos=M ctx_next=the station slipway, ETA five minutes."),
        ("DEST_SLIPWAY", "the station slipway,", "pos=M ctx_prev=Returning to"),
        ("DEST_HOSPITAL", "the hospital pontoon,", "pos=M ctx_prev=Returning to"),
        ("DEST_FISH_QUAY", "the fish market quay,", "pos=M ctx_prev=Returning to"),
        ("DEST_SKERRY", "the Skerry Isle outpost,", "pos=M ctx_prev=Returning to [L]"),
        ("DEST_GANNET", "the Gannet Rock outpost,", "pos=M ctx_prev=Returning to [L]"),
    ]),
    ("handover", [
        ("HANDED_OVER", "Casualty handed over, over."), ("RETURNING_STATION", "Returning to station, over."),
        ("READY", "Ready for tasking, over."), ("VESSEL_SECURED", "Vessel secured alongside, all persons safe, over."),
    ]),
    ("calm", [  # panic mechanic: swimmer to casualty, not radio
        ("GOT_YOU", "I've got you."), ("GRAB_FLOAT", "Grab the float."), ("LIE_BACK", "Lie back, I've got you."),
        ("BREATHE", "Breathe. Nice and slow."), ("NEARLY_THERE", "Nearly there. You're doing well."),
        ("LOOK_AT_ME", "Look at me. You're safe now."),
    ]),
    ("ferry", [
        ("METHANE_FOLLOWS", "METHANE report follows.", "say=Meth-ane report follows."),
        ("M_MAJOR", "Major incident declared."), ("E_LOCATION", "Exact location, the harbour approaches."),
        ("T_TYPE", "Type, capsized passenger ferry."), ("H_HAZARDS", "Hazards, debris and ropes in the water, heavy swell."),
        ("A_ACCESS", "Access, approach from the lee of the hull."), ("N_NUMBER", "Number of casualties,", "pos=M ctx_next=fourteen."),
        ("E_SERVICES", "Emergency services, ambulance to the slipway, all lifeboat units."),
        ("RECEPTION_READY", "Casualty reception boat ready, send yellows to me, over."),
        ("TAPPING", "Tapping from inside the hull,", "pos=M ctx_next=compartment Charlie, over."),
        ("COMPARTMENT", "compartment", "pos=M ctx_next=Charlie"),
        ("ALL_ACCOUNTED", "All persons accounted for, over."), ("CONTINUE_SEARCH", "Continuing search, over."),
        ("TAKING_SECTOR", "Taking search sector", "pos=M ctx_next=Bravo, over."),
    ]),
    ("conning", [  # helicopter winch operator [L]
        ("LEFT_FIVE", "Left five."), ("RIGHT_FIVE", "Right five."), ("FORWARD_FIVE", "Forward five."),
        ("BACK_FIVE", "Back five."), ("DOWN_THREE", "Down three."), ("UP_TWO", "Up two."),
        ("STEADY", "Steady."), ("HOLD", "Hold."), ("WINCHMAN_OUT", "Winchman going out."),
        ("HOOK_EARTHED", "Hook earthed."), ("LIFT", "Lift, lift."), ("CLEAR_DECK", "Winchman clear of the deck."),
    ]),
    ("frag", [("COASTGUARD", "Gale Isles Coastguard,", "pos=S ctx_next=Haven Rescue Two-One.")]),
    ("frag_end", [("OVER", "Over.", "pos=E")]),
]


def player(voice, p):
    for cat, items in PLAYER:
        scope_cat = "[L]" if cat == "conning" else "[MVP]"
        for it in items:
            key, text = it[0], it[1]
            extra = it[2] if len(it) > 2 else ""
            scope = "[L]" if ("[L]" in extra or scope_cat == "[L]") else "[MVP]"
            extra = extra.replace("[L]", "").strip()
            pos = "FULL"
            m = re.match(r"pos=(\w)\s*", extra)
            if m:
                pos, extra = m.group(1), extra[m.end():]
            add(f"{p}_{cat.upper()}_{key}", voice, cat, pos, text, (scope + " optional voice " + extra).strip())
    for key, cs in [("HR11", "Haven Rescue One-One"), ("HR21", "Haven Rescue Two-One"), ("HR31", "Haven Rescue Three-One")]:
        add(f"{p}_CALLSIGN_{key}_E", voice, "callsign", "E", cs + ".", "[MVP] ctx_prev=Gale Isles Coastguard,")
    add(f"{p}_CALLSIGN_RGALE2_E", voice, "callsign", "E", "Rescue Gale Two.", "[L] ctx_prev=Gale Isles Coastguard,")
    frags(voice, p, "number", NUMBERS[:20], "ME")
    frags(voice, p, "minutes", MINUTES[:12], "E")
    frags(voice, p, "phonetic", PHONETIC[:6], "E")


player("PLAYER_M", "PLM")
player("PLAYER_F", "PLF")

# ---------------------------------------------------------------- Chief Aggie
lines("AGGIE", "AGG", "onboarding", [
    ("DRILL_OPEN", "Quick drill before the paint dries, Recruit."),
    ("MANIKIN", "That's a training manikin. It won't mind if you miss. The wind will, though."),
    ("AIM_UPWIND", "Throw beyond it and upwind. Let the line drift down onto it."),
    ("CHARGE", "Hold to wind up, let go to throw."),
    ("HAUL", "Now haul. Hand over hand. Steady, not fast."),
    ("HAUL_FAST", "Easy. Too fast and you'll pull their face under."),
    ("DRILL_DONE", "Lovely. That's the drill. Now we wait for the kettle."),
    ("REAL_ONE", "That's a real one. Answer them, Recruit. Tell them you're going."),
    ("KIT_READY", "Throw bag and thermal blanket, already aboard. The jet ski's yours. Go."),
    ("INFORMANT", "See the fellow on the beach waving? He's pointing right at them."),
    ("EYES_ON", "Eyes on them. Don't look away, not for a second."),
    ("APPROACH", "Come in from downwind. Slow right down. Neutral before you reach them."),
    ("THROW", "Same as the drill. Beyond them, upwind."),
    ("SLED", "Onto the sled, lying flat. Good."),
    ("SURVEY", "Ask them something. Are they breathing easy? Are they shivering?"),
    ("BLANKET", "Blanket on. Out of the wind is half the battle."),
    ("RIDE_HOME", "Easy on the way back. Every bump hurts when you're cold."),
    ("HANDOVER", "Ambulance is at the slipway. Tell them what you found and what you did."),
    ("FIRST_RESCUE", "Your first rescue. Not bad for a Tuesday."),
    ("BOSUN_JOINS", "And this great lump is Bosun. He's decided he's yours."),
    ("BOSUN_JOINS_2", "He'll find them before you do. Let him."),
    ("CATCHPHRASE", "Kettle's on. Go get them."),
    ("OP2_INTRO", "Barnaby's stuck again. Take the loaner RIB. The crew know the tow; you learn it."),
    ("OP3_INTRO", "Tired swimmer, well out. You'll go in the water this time, as a trainee. Float first, always."),
    ("NOTHING_FOR_SALE", "Three rescues. You're one of us now, Recruit."),
])
lines("AGGIE", "AGG", "advice", [
    ("STORM_COMING", "Storm's coming, Recruit. The harbour mouth will get lively. Take the RIB if you've got it."),
    ("STORM_COMING_2", "Weather's turning. Batten down, then go out. In that order."),
    ("STORM_ON", "That's the storm. The bay will hold. The harbour mouth won't."),
    ("STORM_CLEAR", "There's the sun. Come in, get dry, tell me how it went."),
    ("FERRY_BIG", "That's the Gale Queen. Everyone goes. Listen to the scene board and do your one job well."),
    ("FERRY_DONE", "Every last one of them. I'm proud of this station tonight."),
    ("HELO_ADVICE", "That one needs lifting. Ask for the helicopter. Don't be a hero.", "[L]"),
    ("HELO_WASTE", "You don't call a helicopter for a cold swimmer who's chatting. Next time, the slipway."),
    ("KIT_TIP", "Ten minutes in the water and no lifejacket? Take the casualty bag."),
    ("RIB_TIP", "Not answering? Take the RIB. You'll want two of you for that lift."),
    ("TOW_TIP", "Forget the bridle and you'll know about it at the first snatch."),
    ("IDLE_1", "Cocoa's hot if anyone wants it."),
    ("IDLE_2", "Quiet out there. I don't trust quiet."),
    ("IDLE_3", "Tobias says the Harbor Light lamp is sulking again. He talks to it, you know."),
    ("IDLE_4", "Mind Bosun near the slipway. He shakes."),
    ("VANCE", "That's Vance Sterling taking photos again. Smile, Recruit, then get on with it."),
    ("CERT_STEP", "That's one step of the certification done. One more and I'll sign it off."),
    ("CERT_DONE", "Signed off. You've earned that."),
    ("RANK_UP", "New rank, new responsibilities. Same kettle."),
    ("HARBOR_LIGHT_1", "Tobias needs a lift out to the Harbor Light. Be gentle, he gets seasick."),
    ("HARBOR_LIGHT_2", "Look at that. First light on the isles in years. That's your doing."),
])
lines("AGGIE", "AGG", "debrief", [
    ("APPROACH_FAST", "You came in hot. Slower on the last bit and they don't get a faceful of wash."),
    ("APPROACH_UPWIND", "You came in from upwind and the boat drifted onto them. Downwind, always."),
    ("LOST_SIGHT", "You lost sight of them. Once you see them, you don't look away."),
    ("WRONG_METHOD", "Wrong lift for a cold casualty. Keep them flat."),
    ("SURVEY_SKIP", "You skipped the survey. That's how you miss the thing that matters."),
    ("HARMFUL", "No rubbing their arms. It doesn't warm them, it hurts them."),
    ("NO_DRINK", "No drinks for a drowsy casualty. Only when they're fully alert."),
    ("SLAMS", "Too many slams on the way home. Quarter the waves and ease off on the crests."),
    ("ETA_OFF", "Your ETA was well out. Look at the chart before you answer."),
    ("RADIO_SLOW", "Answer the Coastguard quickly. They can't see you, they can only hear you."),
    ("ATMIST", "Your handover was muddled. Age, time, mechanism, injuries, signs, treatment. In that order."),
    ("TENSION", "The line was red too often. Ease off when the tow surfs towards you."),
    ("LINE_PROP", "Slack line near your stern. That's how propellers get eaten."),
    ("GOLD", "Gold. Textbook. Don't let it go to your head."),
    ("GOLD_2", "That's how it's done. Kettle's on."),
    ("SILVER", "Good work. One step to tidy up, and that's gold."),
    ("BRONZE", "They're safe, and that's what counts. Now let's make it cleaner."),
    ("TAKEOVER", "Haven Patrol had to take it. No shame in that. Next time, we do it ourselves."),
])
lines("AGGIE", "AGG", "explore", [
    ("FIND_GENERIC", "Now that's a find. Mark it on the chart and I'll tell Tobias."),
    ("FIND_GENERIC_2", "Good eyes, Recruit. That goes in the station log."),
    ("FIND_WRECK", "That's an old wreck. Plenty of those since the Long Storm. Keep clear of her at low water."),
    ("FIND_SEALS", "Grey seals hauled out. Give them room, they bite harder than Bosun."),
    ("FIND_CAVE", "A sea cave. Lovely to look at, a trap on a rising tide. Remember where it is.", "[L]"),
    ("FIND_LIGHTHOUSE", "That's one of Tobias's lights. Dark for years. Not for much longer."),
    ("FIND_LENS", "A piece of the Skerry lens. Bring it home carefully, Tobias will cry.", "[L]"),
    ("FIND_BUOY", "An old mooring buoy, adrift. Report it, someone could hit that at night."),
    ("FIND_BOTTLE", "A message in a bottle? Read it on the way back. If it's a mayday, I'll want to know."),
    ("FIND_ROCK", "That rock's not on the chart. It is now. Well spotted."),
    ("FIND_OUTPOST", "That's the outpost. Free delivery dock, and somebody keeps the kettle warm.", "[L]"),
    ("FIND_SANDBAR", "The sandbar moves with every storm. Barnaby finds it with his keel. You found it with your eyes."),
    ("FIND_MORWENNA", "That's the Morwenna. Went down in the Long Storm. Everyone got off her, thank goodness."),
    ("FIND_ANCHOR", "An Admiralty anchor. That's older than the station. Older than me, nearly."),
    ("FIND_KELP_GULLY", "Old Ned's kelp gully. He swore the best lobsters live down there. He was right."),
    ("FIND_HAVEN_HEAD", "Haven Head. Best view on the island. You can see weather coming an hour out."),
    ("FIND_ROCK_POOLS", "The rock pools under Haven Head. Look, don't take. The crabs live there."),
    ("FIND_HARBOR_LIGHT_HISTORY", "Harbor Light. Tobias kept it for thirty years. Ask him about the night the lamp went out."),
    ("FIND_ALL_ZONE", "You've found everything in the bay worth finding. Show off."),
])

# ---------------------------------------------------------------- NPC crew (intercom, not radio)
CREW_COMMON = [
    ("callout", [
        ("EYES_ON", "Eyes on! I've got them."), ("EYES_ON_2", "Got them! Keep coming."),
        ("LOST", "Lost them! Lost them behind the swell."), ("REGAINED", "Got them again!"),
        ("POINTING", "I'm pointing, follow my arm."), ("SLOW", "Slow, slow."), ("SLOWER", "Slower, you're too fast."),
        ("NEUTRAL", "Neutral! Neutral now."), ("ABORT", "Abort, go round. We're upwind of them."),
        ("TWENTY", "Twenty."), ("TEN", "Ten."), ("FIVE", "Five."), ("ALONGSIDE", "Alongside. Good."),
        ("WASH", "Mind your wash."), ("BIG_SET", "Big set coming, ease off."), ("HOLD_ON", "Hold on!"),
        ("CASUALTY", "Casualty,", "pos=S ctx_next=two o'clock, a hundred metres!"),
        ("TAPPING", "Tapping! I hear tapping, this compartment!"),
    ]),
    ("deck", [
        ("LIFT_COUNT", "Ready? One, two, three, lift!"), ("LEVEL", "Keep them level. Flat, flat."),
        ("PARBUCKLE", "Net's over. Roll them up, steady."), ("SLED_FLAT", "Lie flat. Hold the handles. Good."),
        ("LINE_PROP", "Slack line near the prop!"), ("TENSION_HIGH", "Tension's high, ease off!"),
        ("TENSION_SLACK", "Line's slack, take it up gently."), ("BRIDLE_ON", "Bridle's on. Both cleats."),
        ("LINE_ACROSS", "Line's across their deck."), ("LINE_MISS", "Missed. Coiling, give me a second."),
        ("FENDERS", "Fenders out, port side."), ("KNIFE", "Line's round the prop. Knife, I'm on it."),
        ("CLEARED", "Prop's clear."), ("ROCKS", "Rocks downwind, watch our drift."),
        ("TRAILING_ROPE", "Rope trailing off their stern, careful."),
    ]),
    ("medic", [
        ("SHIVERING", "They're shivering hard, but talking."), ("DROWSY", "Not shivering, and drowsy. Gently with them."),
        ("BREATHING_OK", "Breathing's fine."), ("BREATHING_FAST", "Breathing's fast."),
        ("NOT_BREATHING", "Not breathing normally. Starting CPR. Call it in."),
        ("BREATHING_AGAIN", "They're breathing. Onto their side."), ("BAG_ON", "Casualty bag on."),
        ("OXYGEN", "Oxygen's on."), ("GREEN", "This one's walking. Green."), ("YELLOW", "Can't walk, breathing fine. Yellow."),
        ("RED", "Breathing too fast. Red, red."),
    ]),
    ("offer", [
        ("TAKE_HELM", "Want me to take the helm?"), ("TAKE_IT", "I can take this one if you like."),
        ("SWAP", "Swap with me? I'll steer."), ("YOURS", "All yours."), ("KIT_PACKED", "Kit's aboard."),
    ]),
    ("chatter", []),
]
CREW_CHATTER = {
    "CREW_FINN": [
        ("C1", "My nan says the Gale Isles have more weather than people."),
        ("C2", "Bosun's been eating my sandwiches again."),
        ("C3", "Glad the station's open. Proper glad."),
        ("C4", "Did you see Vance's jet ski? It's gold. Actual gold paint."),
        ("C5", "First storm I ever went out in, I was sick twice. Worth it."),
        ("C6", "Nice and flat today. Too flat. Something'll happen."),
        ("GOOD_JOB", "Nice one! That was clean."), ("GOOD_JOB_2", "Textbook, that."),
    ],
    "CREW_DEE": [
        ("C1", "Coffee's cold. Story of my life."),
        ("C2", "I've towed The Optimist so often she should pay rent."),
        ("C3", "Look at that sky. Not long now."),
        ("C4", "The trick with a tow is patience. Most people don't have it."),
        ("C5", "Chief Aggie rowed out in weather like this when she was my age. Rowed."),
        ("C6", "Keep your eyes moving. The sea hides people between the crests."),
        ("GOOD_JOB", "Good. That's how you do it."), ("GOOD_JOB_2", "Not bad. Not bad at all."),
    ],
}
CLOCK = [(f"CLK{n:02d}", numword(n) + " o'clock") for n in range(1, 13)]
for voice, p in [("CREW_FINN", "FIN"), ("CREW_DEE", "DEE")]:
    for cat, items in CREW_COMMON:
        items = items or CREW_CHATTER[voice]
        for it in items:
            key, text = it[0], it[1]
            extra = it[2] if len(it) > 2 else ""
            pos = "FULL"
            m = re.match(r"pos=(\w)\s*", extra)
            if m:
                pos, extra = m.group(1), extra[m.end():]
            add(f"{p}_{cat.upper()}_{key}", voice, cat, pos, text, ("[MVP] intercom, no radio FX " + extra).strip())
    for key, text in CLOCK:
        add(f"{p}_CLOCK_{key}_M", voice, "clock", "M", text + ",", "[MVP] ctx_prev=Casualty, | ctx_next=a hundred metres!")
    for key, text in [("D50", "fifty metres!"), ("D100", "a hundred metres!"), ("D200", "two hundred metres!"), ("D300", "three hundred!")]:
        add(f"{p}_RANGE_{key}_E", voice, "range", "E", text, "[MVP] ctx_prev=Casualty, two o'clock,")

# ---------------------------------------------------------------- callers and townsfolk
lines("BARNABY", "BAR", "caller", [
    ("PANPAN_ENGINE", "Pan-pan, pan-pan, pan-pan. All stations, this is the Optimist, the Optimist. Engine's packed up just past the harbour mouth. Two of us aboard, both fine, both wearing lifejackets. Drifting a bit. Over.", "say=Pahn-pahn, pahn-pahn, pahn-pahn. All stations, this is the Optimist, the Optimist. Engine's packed up just past the harbour mouth. Two of us aboard, both fine, both wearing lifejackets. Drifting a bit. Over."),
    ("PANPAN_FUEL", "Pan-pan, pan-pan, pan-pan. This is the Optimist. Bit embarrassing, this. I've run out of fuel off Sandy Point. One aboard, that's me. Over.", "say=Pahn-pahn, pahn-pahn, pahn-pahn. This is the Optimist. Bit embarrassing, this. I've run out of fuel off Sandy Point. One aboard, that's me. Over."),
    ("PANPAN_AGROUND", "Gale Isles Coastguard, the Optimist. Just a little stuck again! On the sandbar, tide's coming in. One aboard. Over."),
    ("PANPAN_PROP", "Coastguard, the Optimist. Caught a lobster pot line round the propeller. Not mine, I promise. Two aboard. Over."),
    ("PANPAN_ASLEEP", "Coastguard, the Optimist. I, er, nodded off. I'm not entirely sure where I am. I can see a lighthouse. Over."),
    ("WORRIED", "She's drifting towards the harbour wall now, Coastguard. Getting closer. Over."),
    ("ROCKS", "Rocks are getting awfully close, Coastguard! Over!"),
    ("LIFEJACKETS", "Lifejackets on, yes. Always. The Chief would have my hide."),
    ("ANCHOR_OK", "Anchor's down! Holding, I think. Holding."),
    ("ANCHOR_FAIL", "Anchor's dragging. Sorry. Sorry!"),
    ("LINE_GOT", "Got your line! Hauling now."),
    ("LINE_FAST", "Made fast on the samson post. Like the Chief taught me."),
    ("SEASICK", "Bit bouncy back here, lads."),
    ("THANKS", "Thank you, thank you. Pints are on me. Well, cocoa."),
    ("THANKS_2", "Just a little stuck again, Chief! Not anymore, though."),
    ("THANKS_3", "I'll get that engine looked at. Properly this time."),
    ("CHATTER_1", "Coastguard, the Optimist, just out for mackerel. Not stuck. Yet. Out."),
    ("CHATTER_2", "Lovely morning for it, Coastguard. Engine's purring. Touch wood. Out."),
    ("RADIO_CHECK", "Coastguard, the Optimist, radio check, over."),
    ("CREW_OFF", "Leaving her? Right. Right you are. Coming across."),
])
lines("LOU", "LOU", "caller", [
    ("MAYDAY", "Mayday, Mayday, Mayday. This is Gale Queen, Gale Queen, Gale Queen. We are listing heavily at the harbour approaches. We are going over. Passengers in lifejackets. Abandoning ship. Over."),
    ("MAYDAY_2", "Coastguard, Gale Queen. She's on her side. People in the water, raft's away. Over."),
    ("CAPTAIN_RAFT", "This is the captain, I'm on the raft with six. We're all right. Get the ones in the water first."),
    ("CAPTAIN_COUNT", "Manifest's in my pocket. Fourteen souls, and me. I've counted eight so far."),
    ("CAPTAIN_THANKS", "Thank you. All of you. I won't forget this."),
    ("DEPART", "Gale Isles Coastguard, Gale Queen, departing Port Haven ferry pier for Skerry Isle, forty-two persons on board. Over."),
    ("ARRIVE", "Coastguard, Gale Queen, alongside the ferry pier. Out."),
    ("WEATHER", "Coastguard, Gale Queen, holding in harbour until the weather clears. Out."),
    ("SECURITE_FOG", "Coastguard, Gale Queen, sounding fog signals in the ferry lane. Out.", "[L]"),
])
lines("HAZEL", "HAZ", "caller", [
    ("CAT", "Coastguard? It's Hazel at the ferry booth. There's a cat on the green buoy and it looks ever so cross."),
    ("BALL", "Hello, Coastguard, Hazel here. A little girl's lost her beach ball. It's heading for the harbour mouth at quite a lick."),
    ("GOSSIP", "Did you hear Vance Sterling's having a marina drawn up? Over my dead body. Sorry. Over."),
    ("GOSSIP_2", "Barnaby's gone out again. I'm only saying."),
    ("SWIMMER", "Coastguard, Hazel. There's someone a long way out past the flags and I don't like it."),
    ("STORM", "Oh, look at that sky. I'm shutting the booth."),
    ("THANKS", "Oh, you're a treasure. Both of you. And the dog."),
    ("DUCKS", "Coastguard, there's a family of ducks in the ferry lane. Should somebody tell the ferry?"),
    ("SORRY", "Is this the right button? Oh, it's on. Sorry, Coastguard."),
])
lines("PATROL", "PAT", "caller", [
    ("RADIO_CHECK", "Gale Isles Coastguard, Haven Patrol, radio check, over."),
    ("HARBOUR_SECURE", "Coastguard, Haven Patrol, harbour secure, ferry pier clear. Out."),
    ("ON_SCENE_TOW", "Coastguard, Haven Patrol, on scene. Taking the tow. Out."),
    ("ASSIST", "Haven Rescue, Haven Patrol, I'm on your port side. Tell me what you need."),
    ("COVER_SECTOR", "Haven Patrol, taking the empty search sector."),
    ("SPEED_WARNING", "Haven Patrol to all vessels, five knots inside the harbour wall, please."),
    ("PATROL_CHATTER", "Coastguard, Haven Patrol, a jet ski's doing doughnuts by the pier. I'll have a word. Out."),
    ("RECEPTION", "Haven Patrol, I'm the reception boat on the north side. Send greens to me."),
])
lines("INFORMANT_M", "INF", "caller", [
    ("WAVE", "Over there! Out past the rocks! Can you see the arm?"),
    ("WAVE_2", "There! Just there! Left of the buoy!"),
    ("PHONE_PATCH", "Hello? Coastguard? There's a swimmer off Sandy Point and he's waving. He's not waving hello."),
    ("STILL_THERE", "He's still there, I can see him. Hurry."),
    ("THANKS", "Thank you. I didn't know what to do. I just kept pointing."),
])
lines("PARENT_F", "PAR", "caller", [
    ("PHONE_PATCH", "Coastguard, please, it's my husband. He swam out to the buoy and he's not coming back in."),
    ("PHONE_PATCH_2", "My son's on his paddleboard and the wind's taking him out. He's got his buoyancy aid on.", "[L]"),
    ("BEACH", "He's there! The orange cap!"),
    ("RELIEF", "Oh, thank you. Thank you so much."),
    ("ASK", "Is he all right? Please tell me he's all right."),
])
lines("TEEN_M", "TEN", "caller", [
    ("IN_WATER", "I can't get back on the board! The wind keeps taking it!"),
    ("IN_WATER_2", "I'm okay, I'm okay. Just really tired."),
    ("PHONE", "Hi, um, Coastguard? My mate fell off his kayak by the harbour wall and his kayak's floated off."),
    ("THANKS", "That was so cool. Sorry. Thank you."),
    ("KAYAK", "Kayak's upside down. I'm holding on to it.", "[L]"),
])
CAS = [
    ("HELP", "Help! Over here!"), ("HELP_2", "Help! Please!"), ("TIRED", "Can't. I can't keep going."),
    ("COLD", "So cold. I'm so cold."), ("PANIC", "I'm going to go under! Help!"),
    ("CALMER", "Okay. Okay. I've got it."), ("GRAB", "Don't let go of me!"),
    ("RESP_ALERT", "Yes. I'm okay. Just cold."), ("RESP_VOICE", "Mm. Wha... yeah."),
    ("THANKS", "Thank you. Really. Thank you."), ("FLAGS", "I'm never swimming past the flags again."),
    ("RIP", "It just pulled me out. I couldn't swim against it."), ("COUGH_OK", "Swallowed half the bay. I'm all right."),
    ("PAX_HERE", "Over here! We're over here!"), ("PAX_HULL", "We're on the hull! Two of us!"),
    ("AIR_POCKET", "Is someone there? We're in here! There's two of us!"), ("AIR_POCKET_2", "Please hurry. It's dark in here."),
    ("AIR_CALM", "Okay. I'll follow you. Don't let go."), ("RAFT", "Kids first. Take the kids first."),
]
for voice, p in [("CASUALTY_M", "CSM"), ("CASUALTY_F", "CSF")]:
    for key, text in CAS:
        add(f"{p}_CASUALTY_{key}", voice, "casualty", "FULL", text, "[MVP] 3D emitter in the water or on deck, no radio FX")
lines("DR_OSEI", "OSE", "handover", [
    ("THANKS", "Thank you, Haven Rescue. We'll take it from here."),
    ("THANKS_2", "Lovely handover. Clear and in order. Thank you."),
    ("THANKS_3", "Good work keeping them flat. That matters."),
    ("RECEIVE", "Bring them up. Gently now."),
    ("FERRY_REDS", "Reds to me first. Greens to the blankets by the wall."),
    ("FERRY_DONE", "That's the last of them. Every one breathing. Well done, all of you."),
    ("TIP_COLD", "A cold casualty is a fragile casualty. Flat, gentle, warm."),
    ("TIP_ATMIST", "Give me age, time, mechanism, injuries, signs and treatment, and I can start before they're off the boat."),
    ("MUDDLED", "Let's take that again. What did you do, in order?"),
])
lines("HELI_PILOT", "HEL", "helo", [
    ("AIRBORNE", "Gale Isles Coastguard, Rescue Gale One, airborne from Port Haven. ETA four minutes. Over."),
    ("ON_SCENE", "Rescue Gale One on scene. Visual on the casualty."),
    ("RUNNING_IN", "Running in. Winch operator, you have the con."),
    ("LEFT_ACK", "Left."), ("RIGHT_ACK", "Right."), ("FWD_ACK", "Forward."), ("BACK_ACK", "Back."),
    ("STEADY_ACK", "Steady."), ("HOLDING", "Holding."), ("GUST", "Gust! Holding her."),
    ("FUEL", "Fifteen minutes of fuel on scene. Let's be quick."),
    ("CALL_EARLIER", "Call it a bit earlier for me. She takes a second to answer."),
    ("CASUALTY_ABOARD", "Casualty aboard. Transiting to the hospital pontoon."),
    ("CLEAR", "Rescue Gale One clearing the scene. Good work down there."),
    ("DOWNWASH", "All vessels, keep clear, my downwash will flatten you."),
    ("DECK_BRIEF", "Hold your course and speed, wind on your port bow, clear the deck, no hats."),
    ("RTB", "Rescue Gale One returning to base."),
    ("FERRY_LIFTS", "Rescue Gale One, ready for the red tags. Send me the first."),
], scope="[L]")

# ---------------------------------------------------------------- write
rows.sort(key=lambda r: (r[1], r[0]))
with open(OUT, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["id", "voice", "category", "position_variant", "text", "notes"])
    w.writerows(rows)
print(f"wrote {len(rows)} rows to {OUT}")
