local DomainSchemaAuthority = {}

local _schemas = {}

local TYPE_CHECKS = {
    string = function(value)
        return type(value) == "string"
    end,
    number = function(value)
        return type(value) == "number"
    end,
    boolean = function(value)
        return type(value) == "boolean"
    end,
    table = function(value)
        return type(value) == "table"
    end,
    optional_string = function(value)
        return value == nil or type(value) == "string"
    end,
    optional_number = function(value)
        return value == nil or type(value) == "number"
    end,
    optional_boolean = function(value)
        return value == nil or type(value) == "boolean"
    end,
    optional_table = function(value)
        return value == nil or type(value) == "table"
    end,
}

local function parseDomainFromEventName(eventName)
    if type(eventName) ~= "string" then
        return nil
    end
    local separator = string.find(eventName, ".", 1, true)
    if not separator or separator <= 1 then
        return nil
    end
    return string.sub(eventName, 1, separator - 1)
end

local function validateShape(shape, payload)
    if type(shape) ~= "table" then
        return true
    end
    if type(payload) ~= "table" then
        return false
    end

    for key, expected in pairs(shape) do
        local check = TYPE_CHECKS[expected]
        if not check then
            return false
        end
        if not check(payload[key]) then
            return false
        end
    end

    return true
end

function DomainSchemaAuthority:Initialize()
    _schemas = {
        Input = {
            MoveX = "optional_number",
            MoveY = "optional_number",
            Jump = "optional_boolean",
            Sprint = "optional_boolean",
            Interact = "optional_boolean",
            ActionsDown = "optional_table",
            ActionsPressed = "optional_table",
            ActionsReleased = "optional_table",
        },
        Physics = {
            Tick = "number",
            Count = "number",
            Pairs = "table",
        },
    }
end

function DomainSchemaAuthority:RegisterSchema(domain, shape)
    if type(domain) ~= "string" or domain == "" or type(shape) ~= "table" then
        return false
    end
    _schemas[domain] = shape
    return true
end

function DomainSchemaAuthority:GetSchema(domain)
    return _schemas[domain]
end

function DomainSchemaAuthority:ValidatePayload(domain, payload)
    local shape = _schemas[domain]
    if not shape then
        return true
    end
    return validateShape(shape, payload)
end

function DomainSchemaAuthority:ValidateEvent(eventName, payload)
    local domain = parseDomainFromEventName(eventName)
    if not domain then
        return true
    end
    return self:ValidatePayload(domain, payload)
end

return DomainSchemaAuthority
