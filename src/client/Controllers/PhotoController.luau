--!strict
-- PhotoController: mounts photo mode (UI/PhotoMode) at boot so the key / gamepad toggle exists
-- before the phone is ever opened. It runs no remotes; the lens is client-only.
local PhotoMode = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("PhotoMode"))

local PhotoController = {}
PhotoController.Priority = 55

function PhotoController.Init()
	PhotoMode.mount()
end

return PhotoController
