local HostCommandSchemas = {}

local function isInstance(value)
    return typeof(value) == "Instance"
end

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
    any = function(_value)
        return true
    end,
    instance = isInstance,
}

local SCHEMAS_BY_DOMAIN = {
    Camera = {
        SetFieldOfView = { Value = "number" },
        SetCameraType = { Value = "any" },
        SetCFrame = { Value = "any" },
        SetPose = {
            PX = "number",
            PY = "number",
            PZ = "number",
            LX = "number",
            LY = "number",
            LZ = "number",
        },
    },
    Audio = {
        SetVolume = { Value = "number" },
        SetAmbientReverb = { Value = "any" },
        SetBusLevel = { Bus = "string", Value = "number" },
    },
    Physics = {
        SetGravity = { Value = "number" },
        SetFallenPartsDestroyHeight = { Value = "number" },
    },
    World = {
        SetGravity = { Value = "number" },
        SetFallenPartsDestroyHeight = { Value = "number" },
    },
    Transform = {
        SetAttribute = { Key = "string", Value = "any" },
        BindEntityInstance = { EntityId = "number", Instance = "instance" },
        UnbindEntityInstance = { EntityId = "number" },
        SetEntityTransform = {
            EntityId = "number",
            PX = "number",
            PY = "number",
            PZ = "number",
        },
    },
    Networking = {
        SetReplicationAttribute = { Key = "string", Value = "any" },
    },
    Replication = {
        SetReplicationAttribute = { Key = "string", Value = "any" },
    },
    StateSync = {
        SetReplicationAttribute = { Key = "string", Value = "any" },
    },
    Component = {
        Tag = { Instance = "instance", Tag = "string" },
        Untag = { Instance = "instance", Tag = "string" },
        SetServiceAttribute = { Key = "string", Value = "any" },
    },
    UI = {
        SetCoreGuiEnabled = { GuiType = "any", Enabled = "boolean" },
        SetAttribute = { Key = "string", Value = "any" },
    },
    TimeScale = {
        SetTimeScale = { Value = "number" },
    },
    Time = {
        SetTimeAttribute = { Key = "string", Value = "any" },
    },
    Scripting = {
        SetScriptTimeout = { Value = "number" },
    },
}

local DEFAULT_SCHEMA = {
    SetAttribute = { Key = "string", Value = "any" },
}

function HostCommandSchemas.GetDomainSchemas(domain)
    return SCHEMAS_BY_DOMAIN[domain] or DEFAULT_SCHEMA
end

function HostCommandSchemas.ValidatePayload(schemas, command, payload)
    if type(payload) ~= "table" then
        return false
    end

    local schema = schemas[command]
    if not schema then
        return false
    end

    for field, expectedType in pairs(schema) do
        local checker = TYPE_CHECKS[expectedType]
        if not checker then
            return false
        end

        if not checker(payload[field]) then
            return false
        end
    end

    return true
end

return HostCommandSchemas
