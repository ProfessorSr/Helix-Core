local TransformReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "Workspace"

function TransformReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function TransformReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Transform", SERVICE_NAME, dt)

    local cam = self.Service.CurrentCamera
    if cam then
        sample.Data.CameraCFrame = cam.CFrame
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function TransformReader:ReadSnapshot()
    return self.LastSample
end

function TransformReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return TransformReader
