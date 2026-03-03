local BootState = {}

local started = false
local ready = false
local failed = false
local failureReason = nil

function BootState:MarkStarting()
    started = true
    ready = false
    failed = false
    failureReason = nil
end

function BootState:MarkReady()
    started = true
    ready = true
    failed = false
    failureReason = nil
end

function BootState:MarkFailed(reason)
    started = true
    ready = false
    failed = true
    failureReason = reason
end

function BootState:IsStarted()
    return started
end

function BootState:IsReady()
    return ready
end

function BootState:HasFailed()
    return failed
end

function BootState:GetFailureReason()
    return failureReason
end

function BootState:WaitForReady(timeoutSeconds)
    local deadline = nil
    if type(timeoutSeconds) == "number" and timeoutSeconds > 0 then
        deadline = os.clock() + timeoutSeconds
    end

    while not ready do
        if failed then
            return false, failureReason
        end

        if deadline and os.clock() >= deadline then
            return false, "timeout waiting for Helix runtime readiness"
        end

        task.wait()
    end

    return true, nil
end

return BootState
