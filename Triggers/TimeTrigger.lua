---@class QRA
local QRA = select(2, ...)

---@class TriggerFactory
QRA.Triggers.Factory = QRA.Triggers.Factory or {}

local TimeTriggerMixin = {}

--- Validate the trigger's data
--- @param self Trigger
--- @return boolean, string? error
function TimeTriggerMixin:Validate()
    if not self.time or self.time < 0 then
        return false, "Time must be a non-negative number."
    end

    if self.repeatInterval and self.repeatInterval <= 0 then
        return false, "Repeat interval must be a positive number."
    end

    if self.repeatCount and self.repeatCount <= 0 then
        return false, "Repeat count must be a positive number."
    end

    return true
end

--- Generate trigger name
---@return string
function TimeTriggerMixin:GenerateName()
    local timeDisplay = string.format("%ds", self.time or 0)
    if self.repeatInterval then
        timeDisplay = timeDisplay .. " / " .. self.repeatInterval .. "s"
        if self.repeatCount then
            timeDisplay = timeDisplay .. " x" .. self.repeatCount
        end
    end

    return timeDisplay
end

function TimeTriggerMixin:GetUIFields()
    return {
        { name = "time", type = "number", label = "Time (seconds)", required = true },
        { name = "repeatInterval", type = "number", label = "Repeat Interval (seconds)", required = false },
        { name = "repeatCount", type = "number", label = "Repeat Count", required = false },
    }
end

QRA.Triggers.Factory.TimeTrigger = TimeTriggerMixin
