local HelixRoot = script.Parent:WaitForChild("Helix")
local RobloxHost = require(
	HelixRoot
		:WaitForChild("Runtime")
		:WaitForChild("Hosts")
		:WaitForChild("RobloxHost")
)

RobloxHost:Start()