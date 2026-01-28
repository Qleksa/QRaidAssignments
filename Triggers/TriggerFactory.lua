---@diagnostic disable: missing-fields

---@class QRA
local QRA = select(2, ...)

QRA.Triggers = QRA.Triggers or {}

QRA.Triggers.Factory = QRA.Triggers.Factory or {}


---@class Trigger
---@field id string
---@field type string
---@field version number default 1
---@field name string
---@field enabled boolean default true
---@field default boolean is trigger default for boss, false by default
---@field encounterId number
---@field bossName string
---@field counterFormula string
---@field assignments Assignment[]
---@field createdAt integer
---@field time number
---@field repeatInterval number
---@field repeatCount number
---@field spellId number
---@field spellName string
---@field activateIn? string seconds to delay trigger activation with optional interval and repeat count
---@field targetGuid? string
---@field hpThresholds? string
---@field ShouldDelayActivation fun(self: Trigger): boolean
---@field Find fun(self: Trigger): Trigger?, integer?
---@field Save fun(self: Trigger)
---@field Update fun(self: Trigger): boolean
---@field Delete fun(self: Trigger, orphanAssignments:boolean?): boolean
---@field GetIndexKey fun(self: Trigger): string|number|nil
---@field Validate fun(self: Trigger): boolean, string?
---@field GenerateName fun(self: Trigger): string
---@field GetUIFields fun(self: Trigger): table[]

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

local function ParseDelay(delayStr)
    -- Handle x,y,z format: x=initial delay, y=interval, z=repeat count
    local parts = {}
    for part in string.gmatch(delayStr, "[^,]+") do
        table.insert(parts, tonumber(strtrim(part)))
    end

    return parts[1] or 0, parts[2], parts[3]
end

local function GetFields(trigger)
    local t = {}
    for k, v in pairs(trigger) do
        if type(v) ~= "function" then
            t[k] = v
        end
    end
    return t
end

local BaseTriggerMixin = {}

--- Determines if the trigger activation should be delayed
---@param self Trigger
---@return boolean
function BaseTriggerMixin:ShouldDelayActivation()
    if not self.activateIn then
        return false
    end

    return ParseDelay(self.activateIn) > 0
end

--- Finds the trigger in the database
---@param self Trigger
---@return Trigger?, integer? index
function BaseTriggerMixin:Find()
    for i, trigger in ipairs(QRA.DB.triggers) do
    if trigger.id == self.id then
            return trigger, i
        end
    end
    return nil
end

--- Saves the trigger to the database
---@param self Trigger
function BaseTriggerMixin:Save()
    QRA.DB.triggers[self.id] = GetFields(self)
    QRA.Debug("Trigger saved:", self.id)
end

--- Updates the trigger in the database
---@param self Trigger
---@return boolean success
function BaseTriggerMixin:Update()
    local t = QRA.DB.triggers[self.id]
    if t then
        QRA.DB.triggers[self.id] = GetFields(self)
        QRA.Debug("Trigger updated:", self.id)
        return true
    end
    return false
end

--- Deletes the trigger from the database
---@param self Trigger
---@param orphanAssignments boolean? if true, orphan assignments instead of deleting them
---@return boolean success
function BaseTriggerMixin:Delete(orphanAssignments)
    local t = QRA.DB.triggers[self.id]
    if not t then
        return false
    end

    if orphanAssignments ~= nil and orphanAssignments and #self.assignments > 0 then
        QRA.Assignments.OrphanAssignments(self.id, self.assignments)
        QRA.Debug("Assignments orphaned for trigger:", self.id)
        return true
    end

    QRA.DB.triggers[self.id] = nil
    QRA.Debug("Trigger deleted:", self.id)
    return true
end

QRA.Triggers.Factory.BaseTriggerMixin = BaseTriggerMixin

--- Restores a trigger from saved data
---@param trigger Trigger
---@return Trigger
function QRA.Triggers.Factory.Restore(trigger)
    local triggerClass = TriggerMap[trigger.type]

    Mixin(trigger, QRA.Triggers.Factory.BaseTriggerMixin)
    if triggerClass then
        Mixin(trigger, triggerClass)
    end

    return trigger
end

--- Creates a new trigger instance
---@param data table
---@return Trigger|nil, string? error
function QRA.Triggers.Factory.Create(data)
    QRA.Debug("Creating trigger with data:", data)
    local triggerType = type(data.type) == "table" and data.type.event or data.type
    local triggerClass = TriggerMap[triggerType]
    if not triggerClass then
        return nil, "Unknown trigger type: " .. tostring(triggerType)
    end


    ---@type Trigger
    local trigger = {
        id = data.id or GenerateId(),
        type = triggerType,
        version = 1,
        enabled = true,
        default = data.default or true,
        encounterId = data.encounterId,
        bossName = data.bossName,
        counterFormula = data.counterFormula or "*",
        assignments = {},
        createdAt = time()
    }
    Mixin(trigger, QRA.Triggers.Factory.BaseTriggerMixin)
    Mixin(trigger, triggerClass)

    ApplyData(trigger, data)

    local isValid, err = trigger:Validate()
    if not isValid then
        return nil, err
    end

    trigger.name = data.name or trigger:GenerateName()

    return trigger
end
