--!strict
-- recover_swimmer (docs 09 step 6, sections 5.3, 5.4): the recovery for a panicking, exhausted,
-- very cold or unresponsive casualty. No method picker: drag, throw or let them come (PIW/Ways),
-- else the crew runs the book's method: swimmer with a tube (contact from behind at arm's length,
-- tow back, pull aboard on three) or the horizontal lift (keep them flat; the book for a cold or
-- still casualty). Hauling a cold casualty upright counts wrongHandling.
-- Metrics: method, score (0..1). Shared engine: PIW/Recovery, PIW/Swimmer, PIW/Ways.
-- Controls: swimmer W/S/A/D or left stick (touch arrows), hold Action for the tube, Talk T / X;
-- tow strokes left/right click, pads or LB/RB; level bar A/D, stick or drag while holding Action.
local Recovery = require(script.Parent.PIW.Recovery)

return { start = Recovery.start }
