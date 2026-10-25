-- stage the take outside the capture lock: relaunch and set off for the start (the autopilot binding drives)
_G.TourRestart()
return "prepped " .. tostring(_G.TourPhase())
