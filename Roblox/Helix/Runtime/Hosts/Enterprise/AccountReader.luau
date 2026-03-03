local AccountReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "Players"

function AccountReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function AccountReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Account", SERVICE_NAME, dt)

    local players = self.Service:GetPlayers()
    sample.Data.PlayerCount = #players

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function AccountReader:ReadSnapshot()
    return self.LastSample
end

function AccountReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return AccountReader
