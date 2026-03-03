print("I am God")
local HelixRoot = script.Parent:WaitForChild("Helix")

local RuntimeEntrypoint = require(
    HelixRoot
        :WaitForChild("Runtime")
        :WaitForChild("RuntimeEntrypoint")
)

RuntimeEntrypoint:Start()
