local PersistenceReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "DataStoreService"

function PersistenceReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function PersistenceReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Persistence", SERVICE_NAME, dt)

    local okBudget, budget = pcall(self.Service.GetRequestBudgetForRequestType, self.Service, Enum.DataStoreRequestType.GetAsync)
    if okBudget then
        sample.Data.GetBudget = budget
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function PersistenceReader:ReadSnapshot()
    return self.LastSample
end

function PersistenceReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return PersistenceReader
