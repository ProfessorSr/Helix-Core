
----------------------------------------------------------------
-- FILE: Boot
----------------------------------------------------------------

local Registry = require(script.Parent.Registry)

local Boot = {}

function Boot:Initialize()
    Registry:Lock()
end

return Boot
