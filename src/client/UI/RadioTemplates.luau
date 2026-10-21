--!strict
-- RadioTemplates (data): Coastguard messages as fragment templates for RadioStitch
-- (grammar in RadioStitch.luau; ids in assets/voice/lines.csv). Radio.say(templateId, params).
-- Message order follows the real distress format (docs 09 section 3.2): who, where, what, help
-- needed, POB, extra detail; every Coastguard transmission ends with "Over." or "Out.".
--
-- Common params: cs (callsign key HR11/HR21/HR31), place (Stitch.key.place), direction
-- ("SOUTH_OF"), distance (Stitch.key.distance), optype ("PIW1"), casDesc, casKit, casState,
-- windDir ("SOUTH_WEST"), wind ("LIGHT"), pob / n (Stitch.key.number), minutes (Stitch.key.minutes).
export type Template = { voice: string, priority: number, tokens: { string } }

local P = table.freeze({ Chatter = 0, Advice = 1, Reply = 2, Tasking = 3, Distress = 4 })

local T: { [string]: Template } = {
	tasking_piw = {
		voice = "CG",
		priority = P.Distress,
		tokens = {
			"OPEN_{cs}",
			"STEM_LAUNCH_TO",
			"OPTYPE_{optype}_M",
			",",
			"DISTANCE_{distance}_M",
			"DIRECTION_{direction}_M",
			"PLACE_{place}_E",
			"STEM_INFORMANT_BEACH",
			"CAS_DESC_{casDesc}_M",
			",",
			"CAS_KIT_{casKit}_M",
			",",
			"CAS_STATE_{casState}_E",
			"STEM_WIND",
			"WIND_DIR_{windDir}_M",
			",",
			"WIND_STRENGTH_{wind}_E",
			"STEM_OVER",
		},
	},
	tasking_vessel = {
		voice = "CG",
		priority = P.Tasking,
		tokens = {
			"PRIORITY_PANPAN",
			"OPEN_{cs}",
			"STEM_LAUNCH_TO",
			"OPTYPE_{optype}_M",
			",",
			"DIRECTION_{direction}_M",
			"PLACE_{place}_E",
			"STEM_INFORMANT_VESSEL",
			"NUMBER_{pob}_M",
			"STEM_{pobStem}",
			"STEM_WIND",
			"WIND_DIR_{windDir}_M",
			",",
			"WIND_STRENGTH_{wind}_E",
			"STEM_OVER",
		},
	},
	tasking_ferry = {
		voice = "CG",
		priority = P.Distress,
		tokens = {
			"PRIORITY_MAYDAY_RELAY",
			"OPEN_ALL_STATIONS",
			"FERRY_FERRY_CAPSIZE",
			"FERRY_FERRY_DETAIL",
			"FERRY_FERRY_POB",
			"NUMBER_{pob}_E",
			"FERRY_ALL_UNITS_LAUNCH",
			"FERRY_FERRY_REQUEST",
		},
	},
	offer = { voice = "CG", priority = P.Tasking, tokens = { "TASKING_OFFER" } },
	-- replies to the player's transmissions
	ack_datum = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_ROGER_DATUM" },
	},
	ack_launch = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_ACK_LAUNCH" },
	},
	say_again = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_REPEAT_FOLLOWS" },
	},
	confirm_able = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "'Confirm you are able to launch, over.'" },
	},
	nudge = { voice = "CG", priority = P.Reply, tokens = { "SHORT_{cs}", "'Do you copy? Over.'" } },
	sitrep_request = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_SITREP_REQ" },
	},
	roger_out = { voice = "CG", priority = P.Reply, tokens = { "SHORT_{cs}", "TASKING_ROGER_OUT" } },
	copy_eta = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "STEM_COPY_ETA", "MINUTES_{minutes}_E", "STEM_OUT" },
	},
	copy_recovered = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "STEM_COPY", "NUMBER_{n}_M", "STEM_RECOVERED", "STEM_OUT" },
	},
	on_scene = { voice = "CG", priority = P.Reply, tokens = { "SHORT_{cs}", "TASKING_ON_SCENE" } },
	sighted = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_CASUALTY_SIGHTED" },
	},
	lost_sight = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_CASUALTY_LOST_SIGHT" },
	},
	ambulance = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_AMB_SLIPWAY", "STEM_OUT" },
	},
	helo_unavailable = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_HELO_UNAVAILABLE" },
	},
	second_unit = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_SECOND_UNIT", "STEM_OUT" },
	},
	handed_over = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_CASUALTY_HANDED", "STEM_OUT" },
	},
	stand_down = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_STAND_DOWN" },
	},
	return_station = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_RETURN_STATION" },
	},
	ready_tasking = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "TASKING_READY_TASKING" },
	},
	all_accounted = { voice = "CG", priority = P.Tasking, tokens = { "FERRY_ALL_ACCOUNTED" } },
	-- wildlife close-out (H4): the animal is aboard, not a vessel secured
	wildlife_safe = {
		voice = "CG",
		priority = P.Reply,
		tokens = { "SHORT_{cs}", "'Animal safe. Good work. Out.'" },
	},
	-- cliff casualty (docs/09 section 8.5): the crew's sighting and the recovery acknowledgement
	cliff_sighted = {
		voice = "CG",
		priority = P.Reply,
		tokens = {
			"SHORT_{cs}",
			"'Casualty sighted on the ledge. On the line, over.'",
		},
	},
	cliff_recovered = {
		voice = "CG",
		priority = P.Reply,
		tokens = {
			"SHORT_{cs}",
			"'Casualty recovered. Handing over to the ambulance, out.'",
		},
	},
	-- rip-current beach rescue (docs/09 section 8.4): the tasking (voiced from the fragments)
	-- and the beach handover
	tasking_rip = {
		voice = "CG",
		priority = P.Distress,
		tokens = {
			"OPEN_{cs}",
			"STEM_LAUNCH_TO",
			"OPTYPE_{optype}_M",
			",",
			"DIRECTION_{direction}_M",
			"PLACE_{place}_E",
			"STEM_INFORMANT_BEACH",
			"CAS_DESC_{casDesc}_M",
			",",
			"CAS_KIT_{casKit}_M",
			",",
			"CAS_STATE_{casState}_E",
			"STEM_OVER",
		},
	},
	rip_handover = {
		voice = "CG",
		priority = P.Reply,
		tokens = {
			"SHORT_{cs}",
			"'Lifeguards have them on the beach. Well done. Out.'",
		},
	},
	gale_warning = {
		voice = "CG",
		priority = P.Tasking,
		tokens = {
			"PRIORITY_SECURITE",
			"OPEN_ALL_STATIONS",
			"STORM_SECURITE_GALE",
			"STORM_SMALL_CRAFT",
		},
	},
}

return table.freeze({ Priority = P, Templates = table.freeze(T) })
