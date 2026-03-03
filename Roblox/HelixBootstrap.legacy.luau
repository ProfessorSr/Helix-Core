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

local GameplayAuthority = require(
    HelixRoot
        :WaitForChild("Core")
        :WaitForChild("Authorities")
        :WaitForChild("GameplayAuthority")
)

local DomainSchemaAuthority = require(
    HelixRoot
        :WaitForChild("Core")
        :WaitForChild("Authorities")
        :WaitForChild("DomainSchemaAuthority")
)

local ReplayCertificationAuthority = require(
    HelixRoot
        :WaitForChild("Core")
        :WaitForChild("Authorities")
        :WaitForChild("ReplayCertificationAuthority")
)

local NetworkingAuthority = require(
    HelixRoot
        :WaitForChild("Core")
        :WaitForChild("Authorities")
        :WaitForChild("NetworkingAuthority")
)

local ProfilerAuthority = require(
    HelixRoot
        :WaitForChild("Core")
        :WaitForChild("Authorities")
        :WaitForChild("ProfilerAuthority")
)

-- Bootstrap ownership: Config only.
HelixConfig:Initialize()
HelixConfig:Lock()

return {
    Kernel = {
        Config = HelixConfig,
        TimeAuthority = TimeAuthority,
        EventAuthority = EventAuthority,
        GameplayAuthority = GameplayAuthority,
        DomainSchemaAuthority = DomainSchemaAuthority,
        ReplayCertificationAuthority = ReplayCertificationAuthority,
        NetworkingAuthority = NetworkingAuthority,
        ProfilerAuthority = ProfilerAuthority,
    },
    RuntimeFolder = HelixRoot:WaitForChild("Runtime"),
}
