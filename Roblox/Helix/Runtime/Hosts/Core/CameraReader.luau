local CameraReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "Workspace"

function CameraReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function CameraReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Camera", SERVICE_NAME, dt)

    local cam = self.Service.CurrentCamera
    if cam then
        sample.Data.FieldOfView = cam.FieldOfView
        sample.Data.CameraType = tostring(cam.CameraType)
        sample.Data.Position = cam.CFrame.Position
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function CameraReader:ReadSnapshot()
    return self.LastSample
end

function CameraReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return CameraReader
