--!strict
-- recover_throwbag (docs 09 step 6, section 5.3): the recovery for a casualty who can grip.
-- The player still reads the casualty and picks the method (right method first time is graded);
-- the throw, haul and two-person pull aboard live in PIW/Recovery.
-- Metrics: method ("throwbag" / "swimmer" / "horizontal"), score (0..1); events wrongHandling.
-- Controls: method cards 1-3; aim with the camera (mouse, drag, right stick); hold left click /
-- the Throw button / A or RT to charge, release to throw; haul with left/right click, the two
-- pads or LB/RB alternately; "Lift" on three.
local Recovery = require(script.Parent.PIW.Recovery)

return { start = Recovery.start }
