---@diagnostic disable: undefined-field

---@class QRA
local QRA = select(2, ...)

---@class TriggerFactory
QRA.Triggers.Factory = {}

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
            QRA.Debug("Getting field:", k, v)
            t[k] = v
        end
    end
    return t
end

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
---@field GetIndexKey fun(self: Trigger): string|number|nil
---@field Validate fun(self: Trigger): boolean, string?
---@field GenerateName fun(self: Trigger): string
---@field GetUIFields fun(self: Trigger): table[]
QRA.Triggers.Factory.BaseTrigger = {

    --- Determines if the trigger activation should be delayed
    ---@param self Trigger
    ---@return boolean
    ShouldDelayActivation = function(self)
        if not self.activateIn then
            return false
        end

        return ParseDelay(self.activateIn) > 0
    end,

    --- Finds the trigger in the database
    ---@param self Trigger
    ---@return Trigger?, integer? index
    Find = function (self)
        for i, trigger in ipairs(QRA.DB.triggers) do
            if trigger.id == self.id then
                return trigger, i
            end
        end
        return nil
    end,

    --- Saves the trigger to the database
    ---@param self Trigger
    Save = function(self)
        table.insert(QRA.DB.triggers, GetFields(self))
        QRA.Debug("Trigger saved:", self.id)
    end,

    --- Updates the trigger in the database
    ---@param self Trigger
    ---@return boolean success
    Update = function (self)
        local t, i = self:Find()
        if t then
            QRA.DB.triggers[i] = GetFields(self)
            QRA.Debug("Trigger updated:", self.id)
            return true
        end
        return false
    end,

    --- Deletes the trigger from the database
    ---@param self Trigger
    ---@param orphanAssignments boolean? if true, orphan assignments instead of deleting them
    ---@return boolean success
    Delete = function(self, orphanAssignments)
        local t, i = self:Find()
        if not t then
            QRA.Debug("Trigger not found for deletion:", self.id)
            return false
        end
        
        if orphanAssignments ~= nil and orphanAssignments and #self.assignments > 0 then
            QRA.Assignments.OrphanAssignments(self.id, self.assignments)
            QRA.Debug("Assignments orphaned for trigger:", self.id)
            return true
        end

        table.remove(QRA.DB.triggers, i)
        QRA.Debug("Trigger deleted:", self.id)
        return true
    end,
}
QRA.Triggers.Factory.BaseTrigger.__index = QRA.Triggers.Factory.BaseTrigger

local function TestTriggerCreation()
    local t, err = QRA.Triggers.Factory.Create{
        type = QRA.Triggers.Types.TIMER,
        time = 30,
        repeatInterval = 1,
        repeatCount = 3,
        bossName = "Test Boss",
    }
    QRA.Debug("Creating test trigger...")
    DevTools_Dump(t)
    if not t then
        QRA.Debug("Error creating test trigger: " .. err)
    else
        QRA.Debug("Test trigger created: ", t)
        t:Save()
        t.bossName = "Updated Boss Name"
        t:Update()
        local t1 = t:Find()
        QRA.Debug("Found trigger:", t1)
        t:Delete()
    end
end

local function TestTriggerRestoration()
    local t = QRA.Triggers.GetTriggersByEncounterId(1577)
    for _, trigger in ipairs(t) do
        local restoredTrigger, err = QRA.Triggers.Factory.Restore(trigger)
        if not restoredTrigger then
            QRA.Debug("Error restoring trigger:", err)
        else
            QRA.Debug("Restored trigger:", restoredTrigger)
            QRA.Debug(restoredTrigger:GetIndexKey())
        end
    end
end

function QRA.Triggers.Factory.Initialize()
    QRA.Debug("Triggers V2 module initialized.")

    TestTriggerCreation()
    -- TestTriggerRestoration()
end
