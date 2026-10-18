--!strict
-- Exercises: the registry of the station's training exercises (docs/09-rescue-operations.md
-- section 9.2) and what the exercise board shows. Each exercise is an ordinary OperationDef built
-- from the live mechanics (Exercise*.luau next to this file), run solo at the station with Chief
-- Aggie and the manikin. The certifications they feed are in ProgressionConfig.Certifications and
-- the pass and reward rules in ProgressionRules.recordExercise. Pure data (Lune-testable).
local Types = require(script.Parent.Parent.Types)

export type Venue = "Slipway" | "Pontoon" | "StationFloor"

export type ExerciseInfo = {
	id: string, -- the OperationDef id
	def: Types.OperationDef,
	certification: string?, -- the certification this is the first half of (nil: the drill)
	optional: boolean, -- shown as optional on the board (the Reopening Day drill)
	cannotFail: boolean, -- every step completes; the run always passes
	vehicle: string?, -- the station's loaner the exercise launches in (nil: on foot)
	venue: Venue, -- where the manikin or the instructor waits (the server picks the spot)
	minutes: number, -- the board's "about N min" (docs 09: 90 s to 3 minutes)
	summary: string, -- one line for the board card
}

local Exercises = {}

local list: { ExerciseInfo } = {
	{
		id = "ExerciseReopeningDay",
		def = require(script.Parent.ExerciseReopeningDay),
		certification = nil,
		optional = true,
		cannotFail = true,
		vehicle = nil,
		venue = "Slipway",
		minutes = 0.5,
		summary = "Throw bag at the manikin off the slipway, aimed with the wind, then the haul.",
	},
	{
		id = "ExerciseBoatHandling",
		def = require(script.Parent.ExerciseBoatHandling),
		certification = "Helm",
		optional = false,
		cannotFail = false,
		vehicle = "JetSki",
		venue = "Pontoon",
		minutes = 3,
		summary = "Buoy from downwind, a man-overboard turn and recovery, alongside the pontoon.",
	},
	{
		id = "ExerciseCasualtyCare",
		def = require(script.Parent.ExerciseCasualtyCare),
		certification = "CasualtyCare",
		optional = false,
		cannotFail = false,
		vehicle = nil,
		venue = "StationFloor",
		minutes = 2.5,
		summary = "DR ABCDE on the manikin, then position, oxygen or CPR, and the ATMIST handover.",
	},
	{
		id = "ExerciseSwimTest",
		def = require(script.Parent.ExerciseSwimTest),
		certification = "RescueSwimmer",
		optional = false,
		cannotFail = false,
		vehicle = nil,
		venue = "Slipway",
		minutes = 2.5,
		summary = "Arm's length, talk down a panicking instructor, break free, tube tow and recovery.",
	},
}

-- Board order: the drill first, then the ladder order of the certifications.
Exercises.Order = table.freeze((function()
	local ids = {}
	for _, e in list do
		table.insert(ids, e.id)
	end
	return ids
end)())

Exercises.Defs = table.freeze((function()
	local byId: { [string]: ExerciseInfo } = {}
	for _, e in list do
		assert(e.def.id == e.id, e.id)
		byId[e.id] = table.freeze(e)
	end
	return byId
end)())

function Exercises.get(id: string): ExerciseInfo?
	return Exercises.Defs[id]
end

-- True for an operation kind that is a training exercise (never a live operation: it pays the
-- first-pass reward, never counts toward a certification's live half, never the tutorial chain).
function Exercises.isExercise(kind: string?): boolean
	return kind ~= nil and Exercises.Defs[kind] ~= nil
end

-- The exercise that is the first half of a certification, if any.
function Exercises.forCertification(certId: string): ExerciseInfo?
	for _, id in Exercises.Order do
		local e = Exercises.Defs[id]
		if e.certification == certId then
			return e
		end
	end
	return nil
end

return Exercises
