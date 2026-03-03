local ComponentReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "CollectionService"

function ComponentReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function ComponentReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Component", SERVICE_NAME, dt)

    local okTags, tags = pcall(self.Service.GetAllTags, self.Service)
    if okTags and tags then
        sample.Data.TagCount = #tags
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function ComponentReader:ReadSnapshot()
    return self.LastSample
end

function ComponentReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return ComponentReader
