local EventAuthority = {}

local _subscribers = {}
local _pendingQueue = {}
local _dispatchQueue = {}
local _nextSubscriberId = 1
local _nextEventId = 1
local _lastErrors = {}

function EventAuthority:Initialize()
    _subscribers = {}
    _pendingQueue = {}
    _dispatchQueue = {}
    _nextSubscriberId = 1
    _nextEventId = 1
    _lastErrors = {}
end

function EventAuthority:Subscribe(eventName, handler)
    assert(type(eventName) == "string", "eventName must be a string")
    assert(type(handler) == "function", "handler must be a function")

    local list = _subscribers[eventName]
    if not list then
        list = {}
        _subscribers[eventName] = list
    end

    local subscriberId = _nextSubscriberId
    _nextSubscriberId += 1

    table.insert(list, {
        Id = subscriberId,
        Handler = handler,
    })

    return subscriberId
end

function EventAuthority:Unsubscribe(eventName, subscriberId)
    local list = _subscribers[eventName]
    if not list then
        return false
    end

    for index = #list, 1, -1 do
        local entry = list[index]
        if entry.Id == subscriberId then
            table.remove(list, index)
            if #list == 0 then
                _subscribers[eventName] = nil
            end
            return true
        end
    end

    return false
end

function EventAuthority:Publish(eventName, payload)
    assert(type(eventName) == "string", "eventName must be a string")

    table.insert(_pendingQueue, {
        Id = _nextEventId,
        Name = eventName,
        Payload = payload,
    })

    _nextEventId += 1
end

function EventAuthority:ProcessTick(tickIndex)
    if #_pendingQueue == 0 then
        return 0
    end

    _dispatchQueue = _pendingQueue
    _pendingQueue = {}

    local processed = 0

    for index = 1, #_dispatchQueue do
        local event = _dispatchQueue[index]
        local listeners = _subscribers[event.Name]

        if listeners then
            for listenerIndex = 1, #listeners do
                local listener = listeners[listenerIndex]
                local ok, err = pcall(listener.Handler, event.Payload, {
                    Tick = tickIndex,
                    EventId = event.Id,
                    Name = event.Name,
                })
                if not ok then
                    table.insert(_lastErrors, {
                        Tick = tickIndex,
                        EventId = event.Id,
                        Name = event.Name,
                        SubscriberId = listener.Id,
                        Error = tostring(err),
                    })
                end
            end
        end

        processed += 1
    end

    _dispatchQueue = {}
    return processed
end

function EventAuthority:GetPendingCount()
    return #_pendingQueue
end

function EventAuthority:GetLastErrors()
    return _lastErrors
end

return EventAuthority
