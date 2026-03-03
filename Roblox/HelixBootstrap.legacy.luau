local HelixRoot = script.Parent:WaitForChild("Helix")

-- Authorities
local HelixConfig = require(
    HelixRoot
        :WaitForChild("Core")
        :WaitForChild("HelixConfig")
)

local TimeAuthority = require(
    HelixRoot
        :WaitForChild("Core")
        :WaitForChild("Authorities")
        :WaitForChild("TimeAuthority")
)

-- Runtime Host
local RobloxHost = require(
    HelixRoot
        :WaitForChild("Runtime")
        :WaitForChild("Hosts")
        :WaitForChild("RobloxHost")
)

-- Initialize configuration BEFORE host start
HelixConfig:Initialize()
TimeAuthority:Initialize()
HelixConfig:Lock()
TimeAuthority:Lock()

-- Start runtime host
RobloxHost:Start()
