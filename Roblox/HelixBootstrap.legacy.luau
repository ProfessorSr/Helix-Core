local HelixRoot = script.Parent:WaitForChild("Helix")

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

local EventAuthority = require(
    HelixRoot
        :WaitForChild("Core")
        :WaitForChild("Authorities")
        :WaitForChild("EventAuthority")
)

-- Bootstrap ownership: Config only.
HelixConfig:Initialize()
HelixConfig:Lock()

return {
    Kernel = {
        Config = HelixConfig,
        TimeAuthority = TimeAuthority,
        EventAuthority = EventAuthority,
    },
    RuntimeFolder = HelixRoot:WaitForChild("Runtime"),
}
