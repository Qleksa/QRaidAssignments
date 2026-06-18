--[[
    QRaidAssignments - Trigger Type Registry
    Centralized registry for trigger type behaviors and configurations

    Each trigger type defines its own:
    - Index key extraction (how triggers are indexed for fast lookup)
    - Configuration application (which fields to copy from config)
    - Validation (what makes a valid trigger of this type)
    - Name generation (default name when none provided)
    - Required fields (for UI form generation)

    ADDING A NEW TRIGGER TYPE:
    1. Add type constant to QRA.Triggers.Types in Triggers.lua
    2. Register handler here using RegisterType()
    3. Add event handling in Triggers.lua if needed
]]

---@class QRA
local QRA = select(2, ...)

--------------------------------------------------
-- Type Registry Definition
--------------------------------------------------

---@class UIFieldDefinition
---@field name string Field identifier
---@field type string Field type: "spell", "number", "text", "targetGuid", "hpThresholds"
---@field label string Display label
---@field required boolean Whether field is required
---@field configKey string Key in config table
---@field tooltip string|nil Optional tooltip text

---@class TriggerTypeHandler
---@field GetIndexKey fun(trigger: Trigger): any|nil Get the key for indexing this trigger (nil = don't index)
---@field ApplyConfig fun(trigger: Trigger, config: table) Apply type-specific config fields to trigger
---@field Validate fun(config: table): boolean, string|nil Validate configuration, returns (isValid, errorMessage)
---@field GenerateName fun(config: table): string Generate a default display name
---@field ShouldIndex fun(): boolean Whether triggers of this type should be indexed
---@field GetRequiredFields fun(): table Array of required field names for this type
---@field SupportsActivateIn fun(): boolean Whether this type supports the activateIn delay
---@field SupportsCustomName fun(): boolean Whether this type supports custom names
---@field GetUIFields fun(): UIFieldDefinition[] Array of UI field definitions for form generation
---@field GetConfigFromUI fun(inputs: table): table Extract config from UI input widgets
---@field FireTestEvent fun(trigger: Trigger, context: table): boolean Fire a test event for DevMode
---@field GenerateTestConfig fun(): table Generate valid test configuration

---@class QRA_Triggers
QRA.Triggers = QRA.Triggers or {}

---@class QRA_TriggerTypeRegistry
---@field handlers table<string, TriggerTypeHandler> Registered type handlers
QRA.Triggers.TypeRegistry = {
    handlers = {},
}

--------------------------------------------------
-- Registry Methods
--------------------------------------------------

--- Register a trigger type handler
---@param eventType string The event type (e.g., "SPELL_CAST_SUCCESS")
---@param handler TriggerTypeHandler The handler definition
function QRA.Triggers.TypeRegistry:RegisterType(eventType, handler)
    local requiredMethods = {
        "GetIndexKey",
        "ApplyConfig",
        "Validate",
        "GenerateName",
        "ShouldIndex",
        "GetRequiredFields",
    }

    for _, method in ipairs(requiredMethods) do
        if not handler[method] then
            error(string.format("TriggerTypeRegistry: Handler for '%s' missing required method '%s'", eventType, method))
        end
    end

    if handler.SupportsActivateIn == nil then
        handler.SupportsActivateIn = function() return true end
    end

    self.handlers[eventType] = handler
end

--- Get handler for a trigger type
---@param eventType string
---@return TriggerTypeHandler|nil
function QRA.Triggers.TypeRegistry:GetHandler(eventType)
    return self.handlers[eventType]
end

--- Check if a trigger type is registered
---@param eventType string
---@return boolean
function QRA.Triggers.TypeRegistry:IsRegistered(eventType)
    return self.handlers[eventType] ~= nil
end

--- Get all registered type names
---@return table Array of event type strings
function QRA.Triggers.TypeRegistry:GetAllTypes()
    local types = {}
    for eventType, _ in pairs(self.handlers) do
        table.insert(types, eventType)
    end
    return types
end

--------------------------------------------------
-- Convenience Functions (use registry internally)
--------------------------------------------------

--- Get index key for a trigger using the registry
---@param trigger Trigger
---@return any|nil The index key, or nil if shouldn't be indexed
function QRA.Triggers.TypeRegistry.GetIndexKeyForTrigger(trigger)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(trigger.type)
    if handler and handler.ShouldIndex() then
        return handler.GetIndexKey(trigger)
    end
    return nil
end

--- Validate trigger configuration
---@param eventType string
---@param config table
---@return boolean isValid
---@return string|nil errorMessage
function QRA.Triggers.TypeRegistry.ValidateConfig(eventType, config)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(eventType)
    if not handler then
        return false, "Unknown trigger type: " .. tostring(eventType)
    end
    return handler.Validate(config)
end

--- Generate name for a trigger
---@param eventType string
---@param config table
---@return string
function QRA.Triggers.TypeRegistry.GenerateName(eventType, config)
    -- If config has explicit name, use it
    if config.name and config.name ~= "" then
        return config.name
    end

    local handler = QRA.Triggers.TypeRegistry:GetHandler(eventType)
    if handler then
        return handler.GenerateName(config)
    end
    return "Unknown Trigger"
end

--- Apply type-specific configuration to a trigger
---@param trigger Trigger
---@param config table
function QRA.Triggers.TypeRegistry.ApplyConfig(trigger, config)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(trigger.type)
    if handler then
        handler.ApplyConfig(trigger, config)
    end
end

--- Check if trigger type should be indexed
---@param eventType string
---@return boolean
function QRA.Triggers.TypeRegistry.ShouldIndex(eventType)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(eventType)
    return handler and handler.ShouldIndex() or false
end

--- Get UI field definitions for a trigger type
---@param eventType string
---@return UIFieldDefinition[]
function QRA.Triggers.TypeRegistry.GetUIFields(eventType)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(eventType)
    if handler and handler.GetUIFields then
        return handler.GetUIFields()
    end
    return {}
end

--- Extract config from UI inputs for a trigger type
---@param eventType string
---@param inputs table Map of field name to UI widget
---@return table config
function QRA.Triggers.TypeRegistry.GetConfigFromUI(eventType, inputs)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(eventType)
    if handler and handler.GetConfigFromUI then
        return handler.GetConfigFromUI(inputs)
    end
    return {}
end

--- Fire a test event for DevMode
---@param trigger Trigger
---@param context table Context with helpers like GetFakeBossInfo, FireToProcessor
---@return boolean success
function QRA.Triggers.TypeRegistry.FireTestEvent(trigger, context)
    QRA.Debug("TriggerTypeRegistry: Firing test event for type", trigger.type)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(trigger.type)
    if handler and handler.FireTestEvent then
        return handler.FireTestEvent(trigger, context)
    end
    return false
end

--- Generate test configuration for a trigger type
---@param eventType string
---@return table config
function QRA.Triggers.TypeRegistry.GenerateTestConfig(eventType)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(eventType)
    if handler and handler.GenerateTestConfig then
        return handler.GenerateTestConfig()
    end
    return {}
end

--- Check if trigger type supports custom name
---@param eventType string
---@return boolean
function QRA.Triggers.TypeRegistry.SupportsCustomName(eventType)
    local handler = QRA.Triggers.TypeRegistry:GetHandler(eventType)
    if handler and handler.SupportsCustomName then
        return handler.SupportsCustomName()
    end
    -- Default: spell types support custom names
    return true
end

--------------------------------------------------
-- Register Spell-Based Trigger Types
-- These share common behavior for spell ID based triggers
--------------------------------------------------

local function CreateSpellTypeHandler(eventType)
    return {
        GetIndexKey = function(trigger)
            return trigger.spellId
        end,

        ApplyConfig = function(trigger, config)
            trigger.spellId = config.spellId
            trigger.spellName = config.spellName
            trigger.activateIn = config.activateIn
        end,

        Validate = function(config)
            if not config.spellId or config.spellId <= 0 then
                return false, "Valid spell ID required"
            end
            return true
        end,

        GenerateName = function(config)
            local typeInfo = QRA.Triggers.Types[eventType]
            local abbrev = typeInfo and typeInfo.abbreviation or "SPL"
            return string.format("%s %s", abbrev, config.spellName or "Unknown")
        end,

        ShouldIndex = function()
            return true
        end,

        GetRequiredFields = function()
            return {"spellId"}
        end,

        SupportsActivateIn = function()
            return true
        end,

        SupportsCustomName = function()
            return true
        end,

        GetUIFields = function()
            return {
                { name = "name", type = "text", label = "Name", required = false, configKey = "name" },
                { name = "spell", type = "spell", label = "Spell ID", required = true, configKey = "spellId" },
                { name = "counter", type = "counter", label = "Counter", required = false, configKey = "counterFormula" },
                { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false, configKey = "activateIn" },
            }
        end,

        GetConfigFromUI = function(inputs)
            local config = {}
            if inputs.spell then
                local spellData = inputs.spell:GetSpell()
                config.spellId = spellData.spellId
                config.spellName = spellData.spellName
            end
            if inputs.name then
                local name = strtrim(inputs.name:GetText())
                if name ~= "" then config.name = name end
            end
            if inputs.activateIn then
                config.activateIn = inputs.activateIn:GetValue()
            end
            return config
        end,

        FireTestEvent = function(trigger, context)
            if not context.IsEncounterActive() then
                return false
            end
            local sourceGUID, sourceName = context.GetFakeBossInfo("boss1")
            local spellInfo = C_Spell.GetSpellInfo(trigger.spellId)
            local spellName = spellInfo and spellInfo.name or "Unknown Spell"

            local eventData = context.BuildCombatLogPayload(
                eventType,
                sourceGUID, sourceName,
                nil, nil,
                trigger.spellId, spellName
            )
            context.FireToProcessor(eventData)
            context.LogEvent(eventType, {
                spellId = trigger.spellId,
                spellName = spellName,
                sourceUnitId = "boss1",
            })
            return true
        end,

        GenerateTestConfig = function()
            return {
                spellId = 12345,
                spellName = "Test Spell",
                counterFormula = "*",
            }
        end,
    }
end

-- Register all spell-based types
local spellTypes = {
    "SPELL_CAST_SUCCESS",
    "SPELL_CAST_START",
    "SPELL_AURA_APPLIED",
    "SPELL_AURA_REMOVED",
    "UNIT_SPELLCAST_SUCCEEDED",
}

-- Defer registration until Types are defined
local function RegisterSpellTypes()
    for _, typeName in ipairs(spellTypes) do
        local typeInfo = QRA.Triggers.Types[typeName]
        if typeInfo then
            QRA.Triggers.TypeRegistry:RegisterType(typeInfo.event, CreateSpellTypeHandler(typeName))
            if typeName == "UNIT_SPELLCAST_SUCCEEDED" then
                ---@class TriggerTypeHandler
                local handler = QRA.Triggers.TypeRegistry:GetHandler(typeInfo.event)

                ---@param trigger Trigger
                ---@param context QRA_DevMode_EventFirer_RegistryContext
                handler.FireTestEvent = function(trigger, context)
                    if not context.IsEncounterActive() then
                        QRA.Print(QRA.L["DevMode: Start an encounter first"])
                        return false
                    end

                    local spellId = trigger.spellId
                    local unitId = trigger.targetGuid or "boss"
                    local sourceGUID, sourceName = context.GetFakeBossInfo(unitId)

                    local spellName = C_Spell.GetSpellName(spellId) or "Unknown Spell"

                    context.LogEvent("UNIT_SPELLCAST_SUCCEEDED", {
                        spellId = spellId,
                        spellName = spellName,
                        sourceUnitId = unitId,
                    })

                    if QRA.Triggers and QRA.Triggers.ProcessUnitSpellcast(unitId, spellId) then
                        QRA.Debug("EventFirer: Fired UNIT_SPELLCAST_SUCCEEDED", unitId, spellId)
                    end

                    return true
                end

            end
        end
    end
end

--------------------------------------------------
-- Register TIMER Type
--------------------------------------------------

local function RegisterTimerType()
    QRA.Triggers.TypeRegistry:RegisterType(QRA.Triggers.Types.TIMER.event, {
        GetIndexKey = function(trigger)
            return nil -- Timers don't need indexing
        end,

        ApplyConfig = function(trigger, config)
            trigger.time = config.time or 0
            trigger.repeatInterval = config.repeatInterval
            trigger.repeatCount = config.repeatCount
        end,

        Validate = function(config)
            if not config.time or config.time < 0 then
                return false, "Time must be >= 0 seconds"
            end
            if config.repeatInterval then
                if config.repeatInterval <= 0 then
                    return false, "Repeat interval must be > 0 seconds"
                end
            end
            if config.repeatCount and config.repeatCount < 0 then
                return false, "Repeat count must be >= 0"
            end
            return true
        end,

        GenerateName = function(config)
            local timeDisplay = string.format("%ds", config.time or 0)
            if config.repeatInterval and config.repeatInterval > 0 then
                if config.repeatCount and config.repeatCount > 0 then
                    return string.format("%s / %ds x%d", timeDisplay, config.repeatInterval, config.repeatCount)
                end
                return string.format("%s / %ds", timeDisplay, config.repeatInterval)
            end
            return timeDisplay
        end,

        ShouldIndex = function()
            return false -- Timers are started directly, not indexed
        end,

        GetRequiredFields = function()
            return {"time"}
        end,

        SupportsActivateIn = function()
            return false -- Timers have their own timing, activateIn doesn't make sense
        end,

        SupportsCustomName = function()
            return false -- Timer names are auto-generated from time config
        end,

        GetUIFields = function()
            return {
                { name = "time", type = "number", label = "Time (seconds)", required = true, configKey = "time" },
                { name = "interval", type = "number", label = "Interval (seconds)", required = false, configKey = "repeatInterval" },
                { name = "repeatCount", type = "number", label = "Repeat Count", required = false, configKey = "repeatCount" },
            }
        end,

        GetConfigFromUI = function(inputs)
            local config = {}
            if inputs.time then
                config.time = tonumber(inputs.time:GetText()) or 0
            end
            if inputs.interval then
                local intervalValue = tonumber(inputs.interval:GetText())
                config.repeatInterval = (intervalValue and intervalValue > 0) and intervalValue or nil
            end
            if inputs.repeatCount then
                local repeatCountValue = tonumber(inputs.repeatCount:GetText())
                config.repeatCount = (repeatCountValue and repeatCountValue > 0) and math.floor(repeatCountValue) or nil
            end
            config.counterFormula = "1" -- Timer always uses counter 1
            return config
        end,

        FireTestEvent = function(trigger, context)
            if not context.IsEncounterActive() then
                return false
            end
            -- Fire timer trigger assignments directly
            if QRA.Assignments and QRA.Assignments.ExecuteForTrigger then
                QRA.Assignments.ExecuteForTrigger(trigger.id, { time = trigger.time }, 1, trigger)
            end
            context.LogEvent("TIMER", {
                triggerId = trigger.id,
                time = trigger.time,
            })
            return true
        end,

        GenerateTestConfig = function()
            return {
                time = 10,
                counterFormula = "1",
            }
        end,
    })
end

--------------------------------------------------
-- Register UNIT_HEALTH Type
--------------------------------------------------

local function RegisterUnitHealthType()
    QRA.Triggers.TypeRegistry:RegisterType(QRA.Triggers.Types.UNIT_HEALTH.event, {
        GetIndexKey = function(trigger)
            -- Index by NPC ID (numeric) or "boss"
            local npcId = tonumber(trigger.targetGuid)
            return npcId or trigger.targetGuid
        end,

        ApplyConfig = function(trigger, config)
            trigger.targetGuid = config.targetGuid
            trigger.hpThresholds = config.hpThresholds
            trigger.activateIn = config.activateIn
        end,

        Validate = function(config)
            if not config.targetGuid or config.targetGuid == "" then
                return false, "Target unit or NPC ID required"
            end

            -- Validate target format
            local target = config.targetGuid
            if target ~= "boss" then
                local npcId = tonumber(target)
                if not npcId or npcId <= 0 then
                    return false, "Target must be 'boss' or numeric NPC ID"
                end
            end

            if not config.hpThresholds or config.hpThresholds == "" then
                return false, "HP thresholds required (e.g., '25,50,75')"
            end

            -- Validate threshold format
            local hasValid = false
            for threshold in string.gmatch(config.hpThresholds, "[^,]+") do
                local num = tonumber(strtrim(threshold))
                if not num then
                    return false, "Invalid threshold: " .. threshold
                end
                if num < 1 or num > 100 then
                    return false, "Thresholds must be between 1 and 100"
                end
                hasValid = true
            end

            if not hasValid then
                return false, "At least one HP threshold required"
            end

            return true
        end,

        GenerateName = function(config)
            local hpDisplay = config.hpThresholds or ""
            hpDisplay = hpDisplay:gsub("(%d+)", "%1%%")
            return string.format("%s @ %s", config.targetGuid or "unknown", hpDisplay)
        end,

        ShouldIndex = function()
            return true
        end,

        GetRequiredFields = function()
            return {"targetGuid", "hpThresholds"}
        end,

        SupportsActivateIn = function()
            return true
        end,

        SupportsCustomName = function()
            return false -- HP% names are auto-generated from threshold config
        end,

        GetUIFields = function()
            return {
                { name = "targetGuid", type = "targetGuid", label = "Target Unit/NPC ID", required = true, configKey = "targetGuid" },
                { name = "hpThresholds", type = "hpThresholds", label = "HP Thresholds (%)", required = true, configKey = "hpThresholds" },
                { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false, configKey = "activateIn" },
            }
        end,

        GetConfigFromUI = function(inputs)
            local config = {}
            if inputs.targetGuid then
                config.targetGuid = strtrim(inputs.targetGuid:GetText())
            end
            if inputs.hpThresholds then
                config.hpThresholds = strtrim(inputs.hpThresholds:GetText())
            end
            if inputs.activateIn then
                config.activateIn = inputs.activateIn:GetValue()
            end
            return config
        end,

        FireTestEvent = function(trigger, context)
            -- UNIT_HEALTH is fired through the Fake Boss panel by changing HP
            -- Cannot be directly fired as a single event
            QRA.Print(QRA.L["DevMode: Use the Fake Boss panel to change HP"])
            return false
        end,

        GenerateTestConfig = function()
            return {
                targetGuid = "boss1",
                hpThresholds = "50,25",
            }
        end,
    })
end

--------------------------------------------------
-- Register UNIT_DIED Type
--------------------------------------------------

local function RegisterUnitDiedType()
    QRA.Triggers.TypeRegistry:RegisterType(QRA.Triggers.Types.UNIT_DIED.event, {
        GetIndexKey = function(trigger)
            local npcId = tonumber(trigger.targetGuid)
            return npcId or trigger.targetGuid
        end,

        ApplyConfig = function(trigger, config)
            trigger.targetGuid = config.targetGuid
            trigger.activateIn = config.activateIn
        end,

        Validate = function(config)
            if not config.targetGuid or config.targetGuid == "" then
                return false, "Target NPC ID or unit required"
            end
            return true
        end,

        GenerateName = function(config)
            return string.format("NPC Death: %s", config.targetGuid or "unknown")
        end,

        ShouldIndex = function()
            return true
        end,

        GetRequiredFields = function()
            return {"targetGuid"}
        end,

        SupportsActivateIn = function()
            return true
        end,

        SupportsCustomName = function()
            return true
        end,

        GetUIFields = function()
            return {
                { name = "name", type = "text", label = "Name", required = false, configKey = "name" },
                { name = "targetGuid", type = "targetGuid", label = "Target Unit/NPC ID", required = true, configKey = "targetGuid" },
                { name = "counter", type = "counter", label = "Counter", required = false, configKey = "counterFormula" },
                { name = "activateIn", type = "number", label = "Activate In (seconds)", required = false, configKey = "activateIn" },
            }
        end,

        GetConfigFromUI = function(inputs)
            local config = {}
            if inputs.name then
                local name = strtrim(inputs.name:GetText())
                if name ~= "" then config.name = name end
            end
            if inputs.targetGuid then
                config.targetGuid = strtrim(inputs.targetGuid:GetText())
            end
            if inputs.activateIn then
                config.activateIn = inputs.activateIn:GetValue()
            end
            return config
        end,

        FireTestEvent = function(trigger, context)
            if not context.IsEncounterActive() then
                return false
            end
            local destGUID, destName = context.GetFakeBossInfo(trigger.targetGuid or "boss1")

            local eventData = context.BuildCombatLogPayload(
                "UNIT_DIED",
                "", "",
                destGUID, destName
            )
            context.FireToProcessor(eventData)
            context.LogEvent("UNIT_DIED", {
                npcId = trigger.targetGuid,
                name = destName,
            })
            return true
        end,

        GenerateTestConfig = function()
            return {
                targetGuid = "boss1",
                counterFormula = "*",
            }
        end,
    })
end

--------------------------------------------------
-- Register BOSS_EMOTE Type
--------------------------------------------------

local function RegisterBossEmoteType()
    QRA.Triggers.TypeRegistry:RegisterType(QRA.Triggers.Types.BOSS_EMOTE.event, {
        GetIndexKey = function()
            return nil
        end,

        ApplyConfig = function(trigger, config)
            trigger.filter = config.filter
            trigger.bossEventName = config.bossEventName or config.event
            trigger.activateIn = config.activateIn
        end,

        Validate = function()
            return true
        end,

        GenerateName = function(config)
            return config.name or "Boss Emote"
        end,

        ShouldIndex = function()
            return false
        end,

        GetRequiredFields = function()
            return {}
        end,

        SupportsActivateIn = function()
            return true
        end,

        SupportsCustomName = function()
            return true
        end,

        GetUIFields = function()
            return {
                { name = "name",    type = "text",    label = "Name",    required = false, configKey = "name" },
                { name = "counter", type = "counter", label = "Counter", required = false, configKey = "counterFormula" },
            }
        end,

        GetConfigFromUI = function(inputs)
            local config = {}
            if inputs.name then
                local name = strtrim(inputs.name:GetText())
                if name ~= "" then config.name = name end
            end
            return config
        end,

        FireTestEvent = function(trigger, context)
            if not context.IsEncounterActive() then
                return false
            end
            if QRA.Assignments and QRA.Assignments.ExecuteForTrigger then
                QRA.Assignments.ExecuteForTrigger(trigger.id, { text = "Test emote" }, 1, trigger)
            end
            context.LogEvent("BOSS_EMOTE", { triggerId = trigger.id })
            return true
        end,

        GenerateTestConfig = function()
            return {
                name = "Test Emote",
                counterFormula = "1",
            }
        end,
    })
end

--------------------------------------------------
-- Initialize Registry
-- Called after Triggers.Types is defined
--------------------------------------------------

function QRA.Triggers.TypeRegistry.Initialize()
    RegisterSpellTypes()
    RegisterTimerType()
    RegisterUnitHealthType()
    RegisterUnitDiedType()
    RegisterBossEmoteType()

    QRA.Debug("TriggerTypeRegistry: Initialized with", #QRA.Triggers.TypeRegistry:GetAllTypes(), "types")
end
