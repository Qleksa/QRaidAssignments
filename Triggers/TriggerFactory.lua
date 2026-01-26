---@class QRA
local QRA = select(2, ...)


---@type table<string, Trigger>
local TriggerMap = {
    ["TIMER"] = QRA.Triggers.Factory.TimeTrigger,
    ["UNIT_SPELLCAST_SUCCEEDED"] = QRA.Triggers.Factory.UnitSpellcastTrigger,
    ["SPELL_CAST_START"] = QRA.Triggers.Factory.SpellTrigger,
    ["SPELL_CAST_SUCCESS"] = QRA.Triggers.Factory.SpellTrigger,
    ["SPELL_AURA_APPLIED"] = QRA.Triggers.Factory.SpellTrigger,
    ["SPELL_AURA_REMOVED"] = QRA.Triggers.Factory.SpellTrigger,
    ["UNIT_HEALTH"] = QRA.Triggers.Factory.UnitHPTrigger,
    ["UNIT_DIED"] = QRA.Triggers.Factory.UnitDiedTrigger,
}

--- Generate ID for new trigger
---@return string ID
local function GenerateId()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local id = ""

    for i = 1, 10 do
        local rand = math.random(1, #chars)
        id = id .. string.sub(chars, rand, rand)
    end

    return id
end

local function ApplyData(trigger, data)
    for k, v in pairs(data) do
        if not trigger[k] then
            trigger[k] = v
        end
    end
end

--- Restores a trigger from saved data
---@param trigger Trigger
---@return Trigger|nil, string? error
function QRA.Triggers.Factory.Restore(trigger)
    local triggerClass = TriggerMap[trigger.type]
    if not triggerClass then
        return nil, "Unknown trigger type: " .. tostring(trigger.type)
    end

    setmetatable(trigger, triggerClass)
    return trigger
end

--- Creates a new trigger instance
---@param data table
---@return Trigger|nil, string? error
function QRA.Triggers.Factory.Create(data)
    QRA.Debug("Creating trigger with data:", data)
    local type = type(data.type) == "table" and data.type.event or data.event
    local triggerClass = TriggerMap[type]
    DevTools_Dump(triggerClass)
    if not triggerClass then
        return nil, "Unknown trigger type: " .. tostring(type)
    end


    ---@type Trigger
    local trigger = setmetatable({
        id = data.id or GenerateId(),
        type = type,
        version = 1,
        enabled = true,
        default = data.default or true,
        encounterId = data.encounterId,
        bossName = data.bossName,
        counterFormula = data.counterFormula or "*",
        assignments = {},
        createdAt = time(),
    }, triggerClass)

    ApplyData(trigger, data)

    local isValid, err = trigger:Validate()
    if not isValid then
        return nil, err
    end

    trigger.name = data.name or trigger:GenerateName()

    return trigger
end
