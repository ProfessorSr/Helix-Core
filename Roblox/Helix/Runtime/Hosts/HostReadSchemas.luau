local HostReadSchemas = {}

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
    table = function(value)
        return type(value) == "table"
    end,
    any = function(_value)
        return true
    end,
    optional_any = function(_value)
        return true
    end,
}

local TOP_LEVEL_SCHEMA = {
    SnapshotVersion = "number",
    HostId = "string",
    Domain = "string",
    Service = "string",
    Dt = "optional_number",
    Tick = "optional_number",
    Signature = "optional_string",
    Diff = "optional_table",
    Data = "table",
}

local DATA_SCHEMAS_BY_DOMAIN = {
    Account = { PlayerCount = "number" },
    Animation = { ProviderReady = "boolean" },
    Asset = { RequestQueueSize = "number" },
    Audio = {
        MasterVolume = "optional_number",
        BusMaster = "optional_number",
        BusMusic = "optional_number",
        BusSFX = "optional_number",
        BusAmbience = "optional_number",
        AmbientReverb = "optional_any",
        RespectFilteringEnabled = "optional_boolean",
    },
    Camera = {
        FieldOfView = "optional_number",
        CameraType = "optional_string",
        Position = "optional_any",
    },
    Component = { TagCount = "optional_number" },
    Event = {
        IsServer = "boolean",
        IsStudio = "boolean",
    },
    Input = {
        KeyboardEnabled = "boolean",
        MouseEnabled = "boolean",
        TouchEnabled = "boolean",
        LastInputType = "string",
        KeysDown = "optional_table",
        KeyCount = "number",
    },
    Networking = { ChildCount = "optional_number" },
    Persistence = { GetBudget = "optional_number" },
    Physics = { CollisionGroupCount = "optional_number" },
    Policy = { PolicyServiceReady = "boolean" },
    Replication = { ChildCount = "optional_number" },
    Scripting = { ScriptContextReady = "boolean" },
    Security = {
        HttpEnabled = "boolean",
        GenerateGUID = "string",
    },
    SimulationControl = {
        IsServer = "boolean",
        IsStudio = "boolean",
    },
    StateSync = { ChildCount = "optional_number" },
    StepDebugger = { MemoryMB = "optional_number" },
    Telemetry = { MessageCount = "number" },
    Time = {
        IsServer = "boolean",
        IsStudio = "boolean",
    },
    TimeScale = {
        IsServer = "boolean",
        IsStudio = "boolean",
    },
    Transform = { CameraCFrame = "optional_any" },
    UI = { ChildCount = "optional_number" },
    World = {
        Gravity = "number",
        FallenPartsDestroyHeight = "number",
    },
}

function HostReadSchemas.GetDomainSchema(domain)
    return {
        Domain = domain,
        Fields = TOP_LEVEL_SCHEMA,
        Data = DATA_SCHEMAS_BY_DOMAIN[domain],
    }
end

function HostReadSchemas.ValidateSnapshot(schema, snapshot)
    if type(snapshot) ~= "table" then
        return false
    end

    if type(schema) ~= "table" or type(schema.Fields) ~= "table" then
        return false
    end

    if schema.Domain and snapshot.Domain ~= schema.Domain then
        return false
    end

    for field, expectedType in pairs(schema.Fields) do
        local checker = TYPE_CHECKS[expectedType]
        if not checker then
            return false
        end

        if not checker(snapshot[field]) then
            return false
        end
    end

    for field in pairs(snapshot) do
        if schema.Fields[field] == nil then
            return false
        end
    end

    if schema.Data then
        local data = snapshot.Data
        if type(data) ~= "table" then
            return false
        end

        for field, expectedType in pairs(schema.Data) do
            local checker = TYPE_CHECKS[expectedType]
            if not checker then
                return false
            end

            if not checker(data[field]) then
                return false
            end
        end

        for field in pairs(data) do
            if schema.Data[field] == nil then
                return false
            end
        end
    end

    return true
end

return HostReadSchemas
